function [clrx_L,prediction,clrx_S,clry_S] = predictClearSurfaceReflectanceTS(data, TIF_coefficient, varargin)
%%----------------------------------------------------------------------------------------
% Function to predict TIF (Time-series-based Image Fusion) reflectance values 
% for given Landsat data using TIF coefficients and specified bands.
%
% Inputs:
% - clry_L: A vector containing the clear Landsat reflectance values.
% - TIF_coefficient: A structure array containing TIF coefficients for different clusters.
% - bands: A vector specifying the bands for which predictions are required.
% - varargin: Additional optional parameters (multi_variable).
%
% Output:
% - prediction: A vector containing the predicted reflectance values for the specified bands.
%%------------------------------------------------------------------------------------------
    
    addpath(fullfile(pwd, 'Fusion'));
    bands = 1:6;

    % Parse optional input parameters
    p = inputParser;
    addParameter(p,'multi_variable', false);    
    parse(p,varargin{:});
    multi_variable = p.Results.multi_variable;
    

    % Find clear observations
    sdate_S  = data.data.sdate_S;
    line_t_S = data.data.line_t_S;
    sdate_L = data.data.sdate_L;
    line_t_L = data.data.line_t_L;
    [clrx_S,clry_S] = getClearObservationS2(sdate_S,line_t_S,size(line_t_S,2),1);
    [clrx_L,clry_L] = getClearObservationL30(sdate_L,line_t_L,size(line_t_L,2),1);


    % Initialize the prediction vector with NaN values
    prediction = NaN(size(clry_L));

    for i = 1:size(clry_L,1)
        % Extract the first 6 elements of clry_L as the value
        value = clry_L(i,1:6);
        k = length(TIF_coefficient);
        d = zeros(1, k);
    
        % Determine the appropriate TIF cluster based on Euclidean distance
        if k>1 % if more than one TIF outcomes, determine which TIF to use based on the TIF_par.Centroid
           for j = 1:k
               tmp = TIF_coefficient(j).Centroid;
               point = tmp(:,1)';
               d(j) = pdist([value;point],'euclidean');
           end
           cluster = find(d==min(d),1);  % return only one value when there are same d
        else
           cluster = 1;
        end   % end of if ik>1
    
       
    
        % Calculate the TIF prediction for each band
        if multi_variable
            for band_id = 1: length(bands)
                band = bands(band_id);
                if TIF_coefficient(cluster).QA 
                    try
                        slope_iband = TIF_coefficient(cluster).Slopes(band,:);
                    catch
                        slope_iband = TIF_coefficient(cluster).Slopes(1,:);
                    end
                    a = value;
                    b = slope_iband';
                    pred = a*b+TIF_coefficient(cluster).Intercepts(band);
                    prediction(i,band_id) = pred;
                end
            end   % end of band_id
        else
            if TIF_coefficient(cluster).QA 
                prediction(i,:) = value.*TIF_coefficient(cluster).Slopes+TIF_coefficient(cluster).Intercepts;
            end
        end  % end of if multi_variable
    end % end of i
end   % end of func