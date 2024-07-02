function plot10mHLSTimeSeries(clrx_S,clry_S,clrx_L,prediction,band_plot)
%PLOT10MHLSTIMESERIES Plots the time series of 10 m Harmonized Landsat and Sentinel-2 data
%   This function visualizes the time series of the 10 m Harmonized Landsat 
%   and Sentinel-2 (HLS) data for a specified spectral band. 
%
%   Input:
%       clrx_S    - Time series of Sentinel-2 observations (in MATLAB datenum format).
%       clry_S    - Reflectance values of Sentinel-2 observations.
%       clrx_L    - Time series of Landsat 8 observations (in MATLAB datenum format).
%       prediction- Predicted 10 m surface reflectance values from TIF.
%       band_plot - (Optional) The spectral band to plot. Defaults to NNIR (band 4).
%
%   Example usage:
%       plot10mHLSTimeSeries(clrx_S, clry_S, clrx_L, prediction, 6);


    figure("Name",'10 m Harmonized Landsat and Sentinel-2 Time Series');
    set(gcf,'Position',[50 50 1100 300]);
    set(gca,'FontSize',16);
    set(gcf, 'Color', 'w');

    if ~exist('band_plot','var')
        band_plot = 4;
        warning('No specified band for plotting, use NNIR instead'); 
    end


    % band codes for Landsat and Sentinel-2 
    band_codes_L = [1,2,3,4,5,6];
    band_codes_S = [1,2,3,10,8,9];
    
    % plot 10 m HLS time series with different colors
    p1 = plot(clrx_S,clry_S(:,band_codes_S(band_plot)), 'o','MarkerEdgeColor','#f78b8b','MarkerFaceColor','#f78b8b', 'Markersize', 4,'DisplayName', 'S10');
    hold on;
    p2 = plot(clrx_L,prediction(:,band_codes_L(band_plot)), 'o', 'MarkerEdgeColor','#0F0F11','MarkerFaceColor','#0F0F11', 'Markersize', 4,'DisplayName', 'prediction');

    % add legend
    legend()

    % set x-axis range
    xlim([datenum('2013-01-01'),datenum('2022-12-31')]);
    datetick('x', 10, 'keeplimits');
    ax.FontSize = 16;

    % set y-axis range
    ylim([0,max(clry_S(:,band_plot))+500]);
    ylabel(['Band ',num2str(band_plot)],'FontSize',16);
    
    fontname(gcf,"Lucida Bright")


    

end
