function [clrx_L30, clry_L30] = getClearObservationL30(sdate,line_t,nbands,i_ids)
        idrange = line_t(:,nbands*(i_ids-1)+1)>0&line_t(:,nbands*(i_ids-1)+1)<10000&...
            line_t(:,nbands*(i_ids-1)+2)>0&line_t(:,nbands*(i_ids-1)+2)<10000&...
            line_t(:,nbands*(i_ids-1)+3)>0&line_t(:,nbands*(i_ids-1)+3)<10000&...
            line_t(:,nbands*(i_ids-1)+4)>0&line_t(:,nbands*(i_ids-1)+4)<10000&...
            line_t(:,nbands*(i_ids-1)+5)>0&line_t(:,nbands*(i_ids-1)+5)<10000&...
            line_t(:,nbands*(i_ids-1)+6)>0&line_t(:,nbands*(i_ids-1)+6)<10000;
        % cloud mask
        line_m = line_t(:,nbands*i_ids);  
        % # of clear observatonsbased on cloud mask values
        idclr = line_m < 2;
        % clear and within physical range pixels
        idgood = idclr & idrange;
        
        % get clear L30
        clrx_L30 = sdate(idgood);
        clry_L30 = line_t(idgood,nbands*(i_ids-1)+1:nbands*(i_ids-1)+nbands-1);
        clry_L30 = double(clry_L30);
end


