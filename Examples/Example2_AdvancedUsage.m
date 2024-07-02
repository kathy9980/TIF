%%---------------------------------------------------------
% Example 1. Advanced  Example
% This example demonstrates the advanced usage of the TIF algorithm with 
% user-defined options and parameters for runTIFSinglePixel().
%
%
%
% 2024/07/01 created by Kexin Song (kexin.song@uconn.edu)
%%---------------------------------------------------------

close all; % Close all open figures

%% Add the TIF functions to your MATLAB path
% Ensure the path to the TIF functions is correctly set before running the script
addpath(genpath('/Users/kexinsong/Library/CloudStorage/OneDrive-UniversityofConnecticut/Documents/ImageFusion/TIF'));
% addpath(genpath('path_to_TIF_functions')); 

%% Load example data
% Load data required for running the TIF algorithm
% Replace 'Examples/Data/T18TXM_r03007c09955.mat' with the path to your data file
data = load('Examples/Data/T18TXM_r03007c09955.mat');

%% Load metadata for Landsat 8 and Sentinel-2
% These metadata files contain necessary information about the satellite images
L8_metadata = load('Examples/Data/L8_metadata.mat');
S2_metadata = load('Examples/Data/S2_metadata.mat');

%% Initialize the TIF algorithm with default options
% This function calculates the TIF coefficients for the given data
TIF_coefficient = runTIFSinglePixel(data, L8_metadata, S2_metadata,...
    't_threshold',1,'maxK',1,'regress_method','robustfit','wfun','Fair',...
    'msg', true,'do_plot', true,'save_figure',false);

%% Apply the coefficient to obtain clear Landsat observations at 10 m grids
% This function uses the TIF coefficients to predict clear surface reflectance time series
[clrx_L, prediction, clrx_S, clry_S] = predictClearSurfaceReflectanceTS(data, TIF_coefficient);

%% Produce the advanced results by merging clear Sentinel-2 observations and the prediction
% This function merges Landsat and Sentinel-2 time series data to produce a harmonized dataset
[clrx_HLS, HLS_10m] = mergeL10S10TimeSeries(clrx_S, clry_S, clrx_L, prediction);

%% Plot the prediction 10 m HLS time series (e.g., the NNIR band)
% Specify the band to plot (1-Blue, 2-Green, 3-Red, 4-NNIR, 5-SWIR1, 6-SWIR2)
band_plot = 6; 
plot10mHLSTimeSeries(clrx_S, clry_S, clrx_L, prediction, band_plot);

% End of the script


