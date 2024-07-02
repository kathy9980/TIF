function TIF_coefficient = runTIFSinglePixel(data,L8_metadata,S2_metadata,varargin)
%%-------------------------------------------------------------------------
% runTIFSinglePixel()conducts Time-series based Image Fusing (TIF) algorithm and export coefficients. 
% 
% This function performs Time-series based Image Fusing (TIF) using input 
% time series data from Landsat and Sentinel-2. It matches clear observations 
% between the two datasets, performs k-means clustering, and builds weighted 
% linear models to derive the relationship between them. The function outputs 
% the TIF coefficients, including slopes, intercepts, number of observation
% pairs, R-squared values, and optionally plots the time series and saves the results.
%
% Inputs:
%   - data: Struct containing Landsat and Sentinel-2 time series data.
%   - L8_metadata: Struct containing Landsat metadata.
%   - S2_metadata: Struct containing Sentinel-2 metadata.
%   - varargin: Additional optional parameters for various processing options.
%
% Outputs:
%   - TIF_coefficient: Struct containing the calculated TIF coefficients for 
%     each spectral band.
%
% Example usage:
%   TIF_coefficient = runTIFSinglePixel(data, L8_metadata, S2_metadata, 'task', 1, 'ntasks', 1, 'msg', true);
%
% Author: Kexin Song (kexin.song@uconn.edu)
% Date: 2024/07/01
%
% ks 20230816: add slope, intercept, and rsuqred for obs pairs<4.
% ks 20231109: test weight functions (1/sqrt(d), 1/d, 1/d^2).
% ks 20231212: add lines to correct cloud mask issue (T10SFG) 251-255 to
% 0-4.
%%-------------------------------------------------------------------------
warning('off','all')
close all;
addpath(fullfile(pwd, 'Fusion'));
band_plot = 4;  % band number for visulization


if ~exist('data', 'var')
    warning('Please input Landsat and Sentinel-2 time series!\r');
    return;
end

if ~exist('S2_metadata', 'var')
    warning('Please input Sentinel-2 metadata!\r');
    return;
end

if ~exist('L8_metadata', 'var')
    warning('Please input L8 metadata!\r');
    return;
end


p = inputParser;
addParameter(p,'task', 1);                      % 1st task
addParameter(p,'ntasks', 1);                    % single task to compute
addParameter(p,'msg', true);                    % display info

addParameter(p,'t_threshold',16);               % default observation-matching threshold is +- 16 day(s).
addParameter(p,'regress_method','robustfit');   % default linear regression method is 'robustfit'. others are 'linear', 'multi-variable-robustfit', 'multi-variable-linear'.
addParameter(p,'maxK',2);                       % default value for the maximum K-means cluster is 2.    
addParameter(p,'wfun','Fair');                  % default is "Fair". Options: Fair, Cauchy, Sqrt

addParameter(p,'do_plot',false);
addParameter(p,'save_figure',false);


% request user's input
parse(p,varargin{:});
task = p.Results.task;
ntasks = p.Results.ntasks;
msg = p.Results.msg;

t_threshold = p.Results.t_threshold;
regress_method = p.Results.regress_method;
maxK = p.Results.maxK;
wfun = p.Results.wfun;

do_plot = p.Results.do_plot;
save_figure = p.Results.save_figure;

%% Set paths and folders
folderpath_output = fullfile('Examples/Results');
if ~isfolder(folderpath_output)
    mkdir(folderpath_output)
end

%% Constants:
% band codes for Landsat and Sentinel-2 
band_codes_L = [1,2,3,4,5,6];
band_codes_S = [1,2,3,10,8,9];
% time series range for developing the TIF model
daterange =[datenum(2013,1,1), datenum(2021,12,31)];

%% load metadata for having the basic info of the dataset that is in proccess
metadata_S = S2_metadata.metadata;
metadata_L = L8_metadata.metadata;

%% Access time series data
sampleTS = data.data;

%% Report log of TIF only for the first first task (optional)  ks: need update
% if task == 1 && i_task == 1
%     reportTIFLog(folderpath_output, ntasks, folderpath_ClbSamples,...
%         analysis_scale, hide_date, regress_method, match_method, t_threshold, resampledL30, ...
%         Rsquared_t, spatial_info,w);
% end

%% read time series data
tic
if msg
    fprintf('\nProcessing pixel row=%d, col=%d.\n', sampleTS.ir,sampleTS.ic);
end
      
%% Load time series data from SAMPLES
sdate_S = sampleTS.sdate_S;
sdate_L = sampleTS.sdate_L;
line_t_S = sampleTS.line_t_S;
line_t_L = sampleTS.line_t_L;
ir = sampleTS.ir;
ic = sampleTS.ic;
% Create an array to save the merged sdate 
sdate_M = union(sdate_L,sdate_S,'sorted');


%% Create a structure to save TIF coefficient for each spectral band
TIF_coefficient = [];
TIF_coefficient.row = ir;
TIF_coefficient.col = ic;
TIF_coefficient.NumofObs = zeros(1,1);

% Correct Fmask values (251-255) to (0-4), we need this step for some tiles, such as 'T10SFG'
if max(unique(line_t_S(:,end)))>250
    cloud_mask = line_t_S(:,end);
    ind = cloud_mask>250;
    cloud_mask(ind) = 255-cloud_mask(ind);
    line_t_S(ind,end) = cloud_mask(ind);
end
% Access clear observations
[clrx_S,clry_S] = getClearObservationS2(sdate_S,line_t_S,metadata_S.nbands,1);
[clrx_L,clry_L] = getClearObservationL30(sdate_L,line_t_L,metadata_L.nbands,1);

%% Plot raw time series (optional)
if do_plot
    % access georeference info
    R = metadata_S.GRIDobj.georef.SpatialRef;
    [pt_lon,pt_lat] = convertRowCol2LatLon(ir,ic,R);
    plotTimeSeries(clrx_S,clry_S,clrx_L,clry_L,band_plot,pt_lat,pt_lon,'plot_pred',false);
end

%% N-fold cross validation 
N=1;     % 20240628 ks: change N>1 to run multiple times
for cross_validation = 1:N
    if msg
        fprintf('Run TIF # %d...\n',cross_validation);
    end
    %% match clear observations, i.e. X-Y pairs
    % t_threshold matching
    [X,Y,d] = match_obs(clrx_L,clrx_S,clry_L,clry_S,band_codes_L,band_codes_S,t_threshold,[],'first');

    %% k-means of [X,Y]
    try
        %---- step 1. determinte the optimal clusters for k-means using gap statistics 
        evaluation = evalclusters([X(:,:),Y(:,:)],"kmeans","gap","KList",1:maxK);
        %---- step 2. perform kmean clustering to seperate matched obs pair
        if isnan(evaluation.OptimalK)
            % if eavaluation fails, assign k to 1.
            k = 1;   
            idx = ones([length(X),1]);
        else
            k = evaluation.OptimalK;
            idx = evaluation.OptimalY;  
        end
    catch
        k = 1;   
        idx = ones([length(X),1]);
    end
    if msg
        fprintf('    The optimal k-cluster is: %d.\r',k);
    end

    %% Build reflectance relationship for each pixel, each cluster, each band
    % One homogenous group
    TIF_coefficient_k1 = build_weighted_linear_mdl(X,Y,band_codes_L,regress_method,'ir',ir,'ic',ic,'doplot',do_plot,'Band_plot',band_plot,'d',d,'wfun',wfun); 
    % use k-means groups
    TIF_coefficient_iN = build_weighted_linear_mdl(X,Y,band_codes_L,regress_method,'ir',ir,'ic',ic,'doplot',do_plot,'Band_plot',band_plot,'cluster',idx,'d',d,'wfun',wfun); 
    
    %% Compare Rsquareds of the regression results
    if length(TIF_coefficient_iN)>1 
        Rsquared_mean = [];
        for iTIF = 1:length(TIF_coefficient_iN)
            Rsquared = TIF_coefficient_iN(iTIF).Rsquared;
            Rsquared_mean = [Rsquared_mean,Rsquared];
        end
        Rsquared_mean = mean(Rsquared_mean,"omitnan");
        if Rsquared_mean < mean(TIF_coefficient_k1.Rsquared)
            TIF_coefficient_iN = TIF_coefficient_k1;
            if msg
                fprintf("    Use one-group regression since row/col %d/%d clustered regression's R2 is lower than one-group R2!\n",ir,ic);
            end
        else
            if msg
                fprintf('    Use clustered TIF coefficient!\r');
            end
        end
    end   % end if(TIF_coefficient_iN)>1

    % add clrx_L to TIF_coefficient cluster.
    TIF_coefficient = TIF_coefficient_iN;
    for i = 1:length(TIF_coefficient)
        TIF_coefficient(i).cluster = [clrx_L,TIF_coefficient(i).cluster];
    end

    
    if startsWith(regress_method, 'multi-variable') 
        multivariable = true;
    else
        multivariable = false;
    end

    %% Plot new time series (optional)
    cluster = TIF_coefficient(1).cluster;
    TIF_cluster = cluster(:,2);
    if do_plot
        plotTimeSeries(clrx_S,clry_S,clrx_L,clry_L,band_plot,pt_lat,pt_lon,'plot_pred',true,'TIF_coefficient',TIF_coefficient,'cluster',TIF_cluster,'test_dates',[],'multivariable',multivariable);  
    end

    %% Save figures
    if save_figure
        folderpath_figures = fullfile(folderpath_output,'TimeSeriesPlot');
        if ~exist(folderpath_figures)
            mkdir(folderpath_figures);
        end
        plotname = sprintf('TIFplot_%s_r%05dc%05d_Band%01d.png',tilename,ir,ic,band_plot);
        exportgraphics(gcf, fullfile(folderpath_figures,string(plotname)),'Resolution',1000);
        fprintf('    Plot saved!\r');
    end


    %% Save sdate and TIF coefficients which contains Slopes, Intercepts, Rsquared, and Num of observation pairs
    if msg
        fprintf('    Export TIF parameters...\r');
    end
    filepath_sdate = fullfile(folderpath_output,sprintf('sdate_r%05dc%05d.mat',ir,ic));
    save(filepath_sdate,'sdate_M');
    filepath_TIFoutput = fullfile(folderpath_output, sprintf('TIF_coefficient_r%05dc%05d.mat',ir,ic));
    save([filepath_TIFoutput, '.part'] ,'TIF_coefficient'); % save as .part
    if ~isempty(TIF_coefficient)
        movefile([filepath_TIFoutput, '.part'], filepath_TIFoutput);
    end

    clear line_t_S;
    clear line_t_L;
    % clear TIF_coefficient;
    % close all;
if msg
    fprintf('Run time %.4f s.\n',toc);
end
   
end  % end of cross validation
% end  % end of itask
end  % end of runTIF_coefficient_pixel func


% 
% function prediction = predict_TIF_reflectance(clry_L, TIF_coefficient, bands, multi_variable)
%     value = clry_L(1:6);
%     k = length(TIF_coefficient);
%     % determine TIF cluster
%     if k>1 % if more than one TIF outcomes, determine which TIF to use based on the TIF_coefficient.Centroid
%        for j = 1:k
%            tmp = TIF_coefficient(j).Centroid;
%            point = tmp(:,1)';
%            d(j) = pdist([value;point],'euclidean');
%        end
%        cluster = find(d==min(d),1);  % return only one value when there are same d
%     else
%        cluster = 1;
%     end   % end of if ik>1
% 
%     % calculate TIFprediction
%     prediction = NaN(length(bands),1);
%     if multi_variable
%         for band_id = 1: length(bands)
%             band = bands(band_id);
%             if TIF_coefficient(cluster).QA 
%                 try
%                     slope_iband = TIF_coefficient(cluster).Slopes(band,:);
%                 catch
%                     slope_iband = TIF_coefficient(cluster).Slopes(1,:);
%                 end
%                 a = clry_L;
%                 b = slope_iband';
%                 pred = a*b+TIF_coefficient(cluster).Intercepts(band);
%                 prediction(band_id) = pred;
%             end
%         end   % end of band_id
%     else
%         if TIF_coefficient(cluster).QA 
%             prediction = clry_L.*TIF_coefficient(cluster).Slopes+TIF_coefficient(cluster).Intercepts;
%         end
%     end  % end of if multi_variable
% end   % end of func


function RMSE = CalRMSE(Ref, Pred)
    dif(:) = Ref(:) - Pred(:);
    dif(:) = dif(:).^2;
    RMSE = sqrt(mean2(dif(:)));      
end

function [AAD, AD] = CalBias(Ref, Pred)
% AAD: absolute average difference
% AD: average difference
    AAD = mean(abs(Pred-Ref));
    AD = mean(Pred-Ref);

end