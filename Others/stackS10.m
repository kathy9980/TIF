function [] = stackS10(varargin)
% This function is for stacking L30 surface reflectance to a geotiff.


addpath('/home/kes20012/COLD_v2/GRIDobj');
addpath('/home/kes20012/MatlabS2FusionSingleImage/SpecTrans');

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
% hv_name = '10SFG';
% hv_name = '13TCF';
% hv_name = '14SPJ';
hv_name = '15RXQ';
% hv_name = '18TXM';
folderpath = '/scratch/zhz18039/kes20012/ImageFusion/';
nrows = 10980;
ncols = 10980;

% s1 = 10980; s2 = 10980; nbands = 7; % six spectral bands +QA
%% load S10 surface reflectance and stack as (b2,b3,b4,b8,b11,b12)
FolderPathS10 = dir(fullfile(folderpath,'S10',['T',hv_name,'_S2*']));

for iS10 = 1:length(FolderPathS10)

    folderpathS10 = fullfile(FolderPathS10(iS10).folder,FolderPathS10(iS10).name);
    dayofyear = FolderPathS10(iS10).name(end-22:end-16);
    fprintf('Stacking %s S10 for %s. \r', hv_name, dayofyear);

    dirS10 = dir(fullfile(folderpathS10,'*B*10m.tif'));
    k=1;
    nbands = 7;
    S10 = zeros(nrows,ncols,nbands);
    for i_img = 1 : length(dirS10)
         if contains(dirS10(i_img).name, '_B02_')||...
                contains(dirS10(i_img).name, '_B03_')||...
                contains(dirS10(i_img).name, '_B04_')||...
                contains(dirS10(i_img).name, '_B8A_')||...
                contains(dirS10(i_img).name, '_B11_')||...
                contains(dirS10(i_img).name, '_B12_')
            S10(:,:,k) = imread(fullfile(dirS10(i_img).folder,dirS10(i_img).name));
            k = k+1;
         end
    end
    % adjust bands order
    band8a = S10(:,:,6);
    band11 = S10(:,:,4);
    band12 = S10(:,:,5);
    
    S10(:,:,4) = band8a;
    S10(:,:,5) = band11;
    S10(:,:,6) = band12;
    clear band8a
    clear band11
    clear band12
    % read QA band
    dirQA = dir(fullfile(folderpathS10,'*Fmask*10m.tif'));
    S10msk = imread(fullfile(dirQA(1).folder,dirQA(1).name));
    S10(:,:,end) = S10msk;
    S10 = double(S10);

    %% Add georeference for the test image (choose one: 10 m or 30 m)
    dirExtent10 = dir(fullfile(folderpathS10,'*Fmask*10m.tif'));   % 10 m
    imgPathLike = fullfile(dirExtent10(1).folder, dirExtent10(1).name);
    imgGridobjLike10 = GRIDobj(imgPathLike);

    %% Save S10 (optional)
    imgGridobjLike10.Z = uint16(S10); % unit16
    imgGridobjLike10.name = ['S10 surface reflectance 10m'];
    filename = ['S10_',dayofyear,'.tif'];
    GRIDobj2geotiff(imgGridobjLike10, fullfile(folderpath,'stack',hv_name,filename));
end   % end of iS10

fprintf('Finish stacking %s S10. \r', hv_name);

end

