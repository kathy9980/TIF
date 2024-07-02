function [clrx_M, line_t_M]=mergeL10S10TimeSeries(clrx_S,clry_S,clrx_L,clry_L)
    
    
    band_codes_L = [1,2,3,4,5,6];
    band_codes_S = [1,2,3,10,8,9];
    nbands = 6;
    nbands_S = 10;
    
    %% Create two arrays to hold merged clrx and line_t
    clrx_M = union(clrx_L,clrx_S,'sorted');
    line_t_M = zeros(size(clrx_M,1),nbands);

    %% Merge clry_S and the clry_L (the prediction) to get clry_M 
    % add L10 predictions
    [~,ia,ib] = intersect(clrx_M,clrx_L);
    line_t_M(ia,:) = clry_L(ib,:);
    clear clry_L;

    % add S10 values (do this at the last to replace any
    % observations obtained on the same day of L30)
    [~,ia,ib] = intersect(clrx_M,clrx_S);
    line_t_M(ia,:) = clry_S(ib,band_codes_S);  %1:metadata_L.nbands-1
    clear clry_S;

end