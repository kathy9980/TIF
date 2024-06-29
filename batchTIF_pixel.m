function batchTIF_pixel(varargin)
%%----------------------------------------------------
% Perform Time-sereis-based Image Fusion (TIF) calibration in batch (for individual pixels).
% 
% The TIF output includes 
%       slope, 
%       intercept,
%       Rsquared, 
%       Number of valid observation pairs. 
% We can build time series using these information.  
%
% Created by Kexin Song (kexin.song@uconn.edu)


%%----------------------------------------------------
    warning('off','all')   
    addpath(fullfile(pwd));
    addpath(fullfile(pwd, 'Fusion'));
    addpath(fullfile(pwd, 'Others'));
    addpath(fullfile(pwd, 'Calibration'));
    addpath('/home/kes20012/COLD_v2/CCD');

    p = inputParser;
    addParameter(p,'task', 1);                      % 1st task
    addParameter(p,'ntasks', 1);                    % single task to compute
    addParameter(p,'ARDTiles',[]);
    addParameter(p,'hide_date',[]);                 % the hidden fine-resolution image (Sentinel-2) acquisition date.
    addParameter(p,'analysis_scale','30to10');      % default is 30 m to 10 m. Another is 60 m to 20 m for NNIR, SWIR1, and SWIR2.
    addParameter(p,'trainingdata_split',1);         % default is 1. change to 0.8 for calibration. 80% of 1-day match data will be used for training, the other 20% for testing calibration results.
    addParameter(p,'weight_function','Fair');       % the function used to assign weight to each observation pair. Options: Fair, Cauchy, Sqrt

    %% major calibration parameters (4)
    addParameter(p,'t',16)                          %  temporal threshold for matching observations, default value is 16.
    addParameter(p,'multi_variable',false);         %  default is false. perform per-band regression. set 'true' to include six spectral bands to build one regresion model.
    addParameter(p,'regress_method','robustfit');   %  default is 'robustfit'. Another is 'linear' using OLS.
    addParameter(p,'maxK',2);                       %  default is 2. 
    
    %% other parameters (not for calibration)
    addParameter(p,'match_method','first');         % default is the observation-matching method is use the first value. 
    addParameter(p,'resampledL30',false);           % default is don't use resampled L30 to build linear regression.
    
    %% request user's input
    parse(p,varargin{:});
    task = p.Results.task;
    ntasks = p.Results.ntasks;
    ARDTiles = p.Results.ARDTiles;
%     ARDTiles = {ARDTiles};
%     hide_date = p.Results.hide_date;
%     hide_date = {hide_date};
    % sample_type = p.Results.sample_type;
    analysis_scale = p.Results.analysis_scale;
    trainingdata_split = p.Results.trainingdata_split;
    weight_function = p.Results.weight_function;

    t = p.Results.t;
    regress_method = p.Results.regress_method;
    match_method = p.Results.match_method;
    resampledL30 = p.Results.resampledL30;
    maxK = p.Results.maxK;
    multi_variable = p.Results.multi_variable;

%%-----------------------------------------------------------

    %% Assign tiles and hide dates
    % Tiles = {'10SFG'};
    % hide_date = {'2021-07-20'};

    Tiles = {'18TXM'};
    hide_date = {'2021-06-18'};
    do_plot = false;
    save_figure = false;

    fprintf('Analysis scale: %s.\n', analysis_scale);  
    if multi_variable
        regress_method = ['multi-variable-' regress_method];
    end

    %% Set up direcotry
    directory = '/Users/kexinsong/Library/CloudStorage/OneDrive-UniversityofConnecticut/Documents/ImageFusion/TIF';
    
    %% Loop by temporal thresholds
    T = 16; % 1:16
    for i = 1:length(T)
        t = T(i);
        fprintf('Processing temporal window: %d days.\n', t);
        fprintf('Add weight function: "%s".\n', weight_function);
        
        %% Loop by ARD tiles
        for iARD = 1:length(Tiles)
            hv_name = Tiles{iARD};
            fprintf('\nStart t=%d day, % s, maxK=%d, %s.\n', t, regress_method, maxK, hv_name);
            
            %% Access input files (time series of saved samples) 
            folderpath_input = fullfile(directory,'Input',['T',hv_name]);
            folderpath_output  = fullfile(directory,'Output',['T',hv_name]);
            folderpath_geotiff = fullfile(directory,'Mask',['T',hv_name]);

            %% Create TIF output folders
            folderpath_output = fullfile(folderpath_output,hv_name,...
                    ['TIFParameter','_k=',int2str(maxK),'_t=',int2str(t),'day_',regress_method,'_',analysis_scale,'_addweight',weight_function,'_forplot']); 
            if ~isfolder(folderpath_output)
                mkdir(folderpath_output);
            end

            %% TIF function starts here...
            runTIF_par_pixel(folderpath_input,folderpath_output,folderpath_geotiff, hv_name,...
                'analysis_scale',analysis_scale,'trainingdata_split',trainingdata_split,...
                'wfun',weight_function, 'task', task ,'ntasks', ntasks, 'msg',true,'t_threshold',t,'regress_method',regress_method,...
                'match_method',match_method,'resampledL30',resampledL30,'maxK',maxK,...
                'hide_date',hide_date{1},'do_plot',false,'save_figure',false); 

        end  % end of iARD
    end  % end of i=1:length(T)
end   % end of func


