function runTIF_coefficient_pixel(folderpath_input,folderpath_output, folderpath_geotiff, tilename,varargin)
% For calibration use.
% Conduct Time-series based Image Fusing (TIF) and export parameters, 
% i.e. slope and intercept.
%   
% ks 20230816: add slope, intercept, and rsuqred for obs pairs<4.
% ks 20231109: test weight functions (1/sqrt(d), 1/d, 1/d^2).
% ks 20231212: add lines to correct cloud mask issue (T10SFG) 251-255 to
% 0-4.

warning('off','all')
close all;
addpath('/home/kes20012/COLD_v2/CCD');
addpath(fullfile(pwd, 'Fusion'));
band_plot = 4;  % band number for visulization


if ~exist('folderpath_input', 'var')
    folderpath_HLS = pwd;
end

if ~exist('folderpath_output', 'var')
    folderpath_output = pwd;
end

if ~exist('folderpath_geotiff', 'var')
    folderpath_geotiff = pwd;
end


p = inputParser;
addParameter(p,'task', 1);                      % 1st task
addParameter(p,'ntasks', 1);                    % single task to compute
addParameter(p,'msg', true);                    % display info
addParameter(p,'hide_date',[]);


addParameter(p,'analysis_scale','30to10');
addParameter(p,'trainingdata_split',0.8);

addParameter(p,'t_threshold',16);               % default observation-matching threshold is +- 16 day(s).
addParameter(p,'regress_method','robustfit');   % default linear regression method is 'robustfit'. others are 'linear', 'multi-variable-robustfit', 'multi-variable-linear'.
addParameter(p,'maxK',2);                       % default value for the maximum K-means cluster is 2.    
addParameter(p,'wfun','Fair');                  % default is "Fair". Options: Fair, Cauchy, Sqrt

addParameter(p,'match_method','first');         % default observation-matching method is use the first value.
addParameter(p,'resampledL30',false);           % default is using the original L30.

addParameter(p,'do_plot',true);
addParameter(p,'save_figure',true);


% request user's input
parse(p,varargin{:});
task = p.Results.task;
ntasks = p.Results.ntasks;
msg = p.Results.msg;
hide_date = p.Results.hide_date;
analysis_scale = p.Results.analysis_scale;
trainingdata_split = p.Results.trainingdata_split;

t_threshold = p.Results.t_threshold;
regress_method = p.Results.regress_method;
maxK = p.Results.maxK;
wfun = p.Results.wfun;

match_method = p.Results.match_method;
resampledL30 = p.Results.resampledL30;

do_plot = p.Results.do_plot;
save_figure = p.Results.save_figure;

%% Define processing bands
if strcmp(analysis_scale,'30to10')
    bands = [1,2,3];
else
    bands = [4,5,6];
end

%% Set paths and folders
if ~isfolder(folderpath_output)
    mkdir(folderpath_output)
end

%% Constants:
% band codes for Landsat and Sentinel-2 
band_codes_L = [1,2,3,4,5,6];
band_codes_S = [1,2,3,10,8,9];
% time series range for developing the TIF model
daterange =[datenum(2013,1,1), datenum(2021,12,31)];

%% load metadata.mat for having the basic info of the dataset that is in proccess
load(fullfile(folderpath_input,'S2_metadata.mat'));
metadata_S = metadata;
load(fullfile(folderpath_input, 'HLS_metadata.mat'));
metadata_L = metadata;

%%  Access all time series data
sampleTS = dir(fullfile(folderpath_input, ['T*',analysis_scale,'.mat']));

%% Check unprocessed data before parallel to save computation time (optional, recommend to add to skip completed data)
unprocessed_ids = [];
for i = 1:length(sampleTS)
    parts = split(sampleTS(i).name,'_');
    row_col = sscanf(parts{3},'r%05dc%05d');
    row = row_col(1);col = row_col(2);
    filepath_rcg = fullfile(folderpath_output, sprintf('TIF_%s_r%05dc%05d.mat', hide_date, row, col)); 
    if ~isfile(filepath_rcg) %&& ~isfile(filepath_rcg_part)
        unprocessed_ids = [unprocessed_ids,i];
    end
end
% exit if all rows have been processed
if isempty(unprocessed_ids)
    fprintf('Finished TIF for all pixels!\n\r');
    return;
else
    sampleTS = sampleTS(unprocessed_ids);
    fprintf('Need #%d cores to process pixels in optimal.\n', length(sampleTS));
end

%% Assign job for each task 
num_stacks = length(sampleTS);
tasks_per = ceil(num_stacks/ntasks);
start_i = (task-1)*tasks_per + 1;
end_i = min(task*tasks_per, num_stacks);
% Parallel starts here ...
% Locate to a certain task, one task for one pixel
for i_task = start_i:end_i

    %% report log of TIF only for the first first task (optional)  ks: need update
    % if task == 1 && i_task == 1
    %     reportTIFLog(folderpath_output, ntasks, folderpath_ClbSamples,...
    %         analysis_scale, hide_date, regress_method, match_method, t_threshold, resampledL30, ...
    %         Rsquared_t, spatial_info,w);
    % end
  
    %% read time series data
    tic
    load(fullfile(sampleTS(i_task).folder,sampleTS(i_task).name));
    if msg
        fprintf('\nProcessing pixel %s at task# %d/%d.\n', sampleTS(i_task).name, task, ntasks);
    end
          
    %% Load time series data from SAMPLES
    sdate_S = SAMPLES.sdate_S;
    sdate_L = SAMPLES.sdate_L;
    line_t_S = SAMPLES.line_t_S;
    line_t_L = SAMPLES.line_t_L;
    ir = SAMPLES.ir;
    ic = SAMPLES.ic;
    % Create an array to save the merged sdate 
    sdate_M = union(sdate_L,sdate_S,'sorted');
    % % Initialize a VideoWriter object to produce TIF animation (optional)
    % videoName = fullfile('/scratch/zhz18039/kes20012/',sprintf('TIFcalibration_r%05dc%05d_Band%d.avi',ir,ic,band_plot));
    % writerObj = VideoWriter(videoName, 'Motion JPEG AVI');
    % writerObj.FrameRate = 1/3; % Set frame rate (frames per second)
    % % Open the VideoWriter object for writing
    % open(writerObj);

    %% Create a structure to save TIF parameters
    TIF_coefficient = [];
    TIF_coefficient.row = ir;
    TIF_coefficient.col = ic;
    TIF_coefficient.NumofObs = zeros(1,1);
    
    % Correct Fmask values (251-255) to (0-4), we need this step for T10SFG
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
        changemask = dir(fullfile(folderpath_geotiff,'T*change_mask.tif'));
        [pt_lon,pt_lat] = convertRowCol2LatLon(ir,ic,fullfile(changemask(1).folder,changemask(1).name));
        plotTimeSeries(clrx_S,clry_S,clrx_L,clry_L,band_plot,pt_lat,pt_lon);
    end
   
    %% N-fold cross validation 
    N=1;                     % 20240628 ks: change N>1 to run multiple times
    cross_RMSE = NaN(N,1);   % 20231212 ks: replace zeros with NaN array 
    cross_AAD = NaN(N,1); 
    for cross_validation = 1:N
        if msg
            fprintf('Cross validation # %d...\n',cross_validation);
        end
        %% match clear observations, i.e. X-Y pairs
        % same-day matching to hidh testing Y for further analysis
        try
            [X1,Y1,~] = match_obs(clrx_L,clrx_S,clry_L,clry_S,band_codes_L,band_codes_S,1,hide_date,match_method);   
        catch
            fprintf('Please check! No clear obs for %s. \n',sampleTS(i_task).name);
            break;
        end
    
        n = length(find(~isnan(X1(:,4))));
        k = round(n*(1-trainingdata_split));
        p = randperm(n,k);
        % split X-Y pairs to training (80%) and validation (20%) 
        valid_ind = find(~isnan(X1(:,4)));
        test_ind = valid_ind(p);
        % t_threshold matching
        [X,Y,d] = match_obs(clrx_L,clrx_S,clry_L,clry_S,band_codes_L,band_codes_S,t_threshold,hide_date,match_method);
        X(test_ind,:) = NaN;
        Y(test_ind,:) = NaN;
        d(test_ind,:) = NaN;
    
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
        % use k-means groups
        TIF_coefficient_iN = build_weighted_linear_mdl(X,Y,band_codes_L,regress_method,'ir',ir,'ic',ic,'doplot',do_plot,'Band_plot',band_plot,'cluster',idx,'d',d,'wfun',wfun); 
        % One homogenous group
        TIF_coefficient_k1 = build_weighted_linear_mdl(X,Y,band_codes_L,regress_method,'ir',ir,'ic',ic,'doplot',do_plot,'Band_plot',band_plot,'d',d,'wfun',wfun); 
        
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
            plotTimeSeries(clrx_S,clry_S,clrx_L,clry_L,band_plot,pt_lat,pt_lon,'plot_pred',true,'TIF_coefficient',TIF_coefficient,'cluster',TIF_cluster,'test_dates',hide_date,'multivariable',multivariable);  
        end
        % %% Capture frame
        % frameData = getframe(gcf); % Capture current figure as frame
        % writeVideo(writerObj, frameData); % Write frame to video
        % close all;

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
        filepath_sdate = fullfile(folderpath_output,'sdate.mat');
        save(filepath_sdate,'sdate_M');
        filepath_TIFoutput = fullfile(folderpath_output, sprintf('TIF_coefficient_r%05dc%05d.mat',ir,ic));
        save([filepath_TIFoutput, '.part'] ,'TIF_coefficient'); % save as .part
        if ~isempty(TIF_coefficient)
            movefile([filepath_TIFoutput, '.part'], filepath_TIFoutput);
        end

        clear line_t_S;
        clear line_t_L;
        clear TIF_coefficient;
        close all;
    if msg
        fprintf('Run time %.4f s.\n',toc);
    end
       
    end  % end of cross validation
end  % end of itask
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