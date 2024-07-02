function [pt_lon,pt_lat]=convertRowCol2LatLon(pt_row, pt_col, R)
%%-------------------------------------------------------------------------
% This function converts row and column indices of a pixel into latitude 
% and longitude coordinates.
% 
% Input:
%   pt_row: Row index of the input pixel.
%   pt_col: Column index of the input pixel.
%   R: Spatial referencing object associated with the raster image.
% 
% Output:
%   pt_lon: Longitude (in degrees) of the input pixel.
%   pt_lat: Latitude (in degrees) of the input pixel.
%
% Author: Kexin Song
% 20240701 ks : Replaced 'pixcenters()' with 'worldGrid()'
%%-------------------------------------------------------------------------

    %% Convert row/col to X/Y
    [X, Y] = worldGrid(R);
    pt_x = X(pt_row, pt_col);
    pt_y = Y(pt_row, pt_col);

    
    %% Covert X/Y to lat/lon
    [pt_lat,pt_lon] = projinv(R.ProjectedCRS,pt_x,pt_y);
    fprintf('The lat/lon of input point is: %f,%f.\n', pt_lat, pt_lon);

end

