function stackL30(varargin)
% This function is for stacking L30 surface reflectance to a geotiff.


addpath('/home/kes20012/COLD_v2/GRIDobj');
addpath('/home/kes20012/MatlabS2FusionSingleImage/SpecTrans');
addpath('/home/kes20012/HLS stack code');

%% input parameters
p = inputParser;
addParameter(p,'task', 1);        % 1st task
addParameter(p,'ntasks', 1);      % single task to compute
addParameter(p,'msg', true);      % default: display info

% request user's input
parse(p,varargin{:});
task = p.Results.task;
ntasks = p.Results.ntasks;
msg = p.Results.msg;

%% add path and constants
hv_name = '15RXQ';
folderpath = '/scratch/zhz18039/kes20012/ImageFusion/';
nrows = 3660;
ncols = 3660;
nbands = 7;
L30 = zeros(nrows,ncols,nbands);

% load HLS v1.4 L30 surface reflectance here and stack as (b2,b3,b4,b5,b6,b7)
FolderPathL30 = dir(fullfile(folderpath,'L30','HLSv1.4',['HLS.L30.*',hv_name,'*.hdf']));

for iL30 = 1:length(FolderPathL30)
    
    folderpathL30 = fullfile(FolderPathL30(iL30).folder,FolderPathL30(iL30).name);
    dayofyear = FolderPathL30(iL30).name(end-15:end-9);
    fprintf('Stacking %s L30 for %s. \r', hv_name, dayofyear);

    pixEdge = [nrows, ncols];
    pixLoc = [1 1];
    img = readL30(folderpathL30,pixLoc, pixEdge);
    L30(:,:,1) = img.Blue;
    L30(:,:,2) = img.Green; 
    L30(:,:,3) = img.Red; 
    L30(:,:,4) = img.NIRN; 
    L30(:,:,5) = img.SWIR1; 
    L30(:,:,6) = img.SWIR2;
    
    cfmask = zeros(nrows,ncols);
    cfmask0 = img.QA;
    cfmask(bitget(cfmask0,6) == 1) = 1;   % 1: clear water 
    cfmask(bitget(cfmask0,5) == 1) = 3;   % 3: snow
    cfmask(bitget(cfmask0,4) == 1) = 2;   % 2: cloud shadow
    cfmask(bitget(cfmask0,2) == 1) = 4;   % 4: cloud
    cfmask(bitget(cfmask0,1) == 1) = 4;   % 4: cirrus
    clear cfmask0;
    L30(:,:,7) = cfmask;  
    L30 = double(L30);
    
    %% Add georeference for the test image (choose one: 10 m or 30 m)
    % dirExtent30 = dir(fullfile('/shared/cn451/Kexin/COLDHLSResults/18TYM/CCDCMap/','accuchangemap*.tif'));  % 30 m
    % imgPathLike = fullfile(dirExtent30(1).folder, dirExtent30(1).name);
    % imgGridobjLike30 = GRIDobj(imgPathLike);
    
    load(fullfile('/shared/cn450/Kexin/COLDHLSResults/',hv_name,'StackData10','metadata.mat'));
    imgGridobjLike30 = metadata.GRIDobj;
    
    %% Save L30 (optional)
    imgGridobjLike30.Z = uint16(L30); % unit16
    imgGridobjLike30.name = ['L30 surface reflectance 30m'];
    filename = ['L30_',dayofyear,'.tif'];
    GRIDobj2geotiff(imgGridobjLike30, fullfile(folderpath,'stack',hv_name,filename));
end  % end of iL30

fprintf('Finish stacking %s L30. \r', hv_name);

end

