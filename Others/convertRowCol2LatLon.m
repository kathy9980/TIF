function [pt_lon,pt_lat]=convertRowCol2LatLon(pt_row, pt_col, folderpath_img)
% This fuction will convert row/col in to lat/lon
% Input:
%   pt_row: row index of the input pixel.
%   pt_col: column index of the input pixel.
%   folderpath_img: directory of the raster image.
% Output:
%   pt_lon: longitude (in deg) of the input pixel.
%   pt_lat: latitude (in deg) of the input pixel.

[~,R] = readgeoraster(folderpath_img);

%% Convert row/col to X/Y
pro = R.ProjectedCRS;
% [X,Y] = pixcenters(R,size(img));  % ks: this function was removed.
[X,Y] = worldGrid(R);
pt_x = X(pt_col);
pt_y = Y(pt_row);  


%% Covert X/Y to lat/lon
[pt_lat,pt_lon] = projinv(pro,pt_x,pt_y);
fprintf('The lat/lon of input point is: %f,%f.\n', pt_lat, pt_lon);

end

