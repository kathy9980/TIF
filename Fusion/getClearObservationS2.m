function [clrx_S2, clry_S2] = getClearObservationS2(sdate,line_t,nbands,i_ids) 
        idrange = line_t(:,nbands*(i_ids-1)+1)>0&line_t(:,nbands*(i_ids-1)+1)<10000&...
            line_t(:,nbands*(i_ids-1)+2)>0&line_t(:,nbands*(i_ids-1)+2)<10000&...
            line_t(:,nbands*(i_ids-1)+3)>0&line_t(:,nbands*(i_ids-1)+3)<10000&...
            line_t(:,nbands*(i_ids-1)+4)>0&line_t(:,nbands*(i_ids-1)+4)<10000&...
            line_t(:,nbands*(i_ids-1)+5)>0&line_t(:,nbands*(i_ids-1)+5)<10000&...
            line_t(:,nbands*(i_ids-1)+6)>0&line_t(:,nbands*(i_ids-1)+6)<10000&...
            line_t(:,nbands*(i_ids-1)+7)>0&line_t(:,nbands*(i_ids-1)+7)<10000&...
            line_t(:,nbands*(i_ids-1)+8)>0&line_t(:,nbands*(i_ids-1)+8)<10000&...
            line_t(:,nbands*(i_ids-1)+9)>0&line_t(:,nbands*(i_ids-1)+9)<10000&...
            line_t(:,nbands*(i_ids-1)+10)>0&line_t(:,nbands*(i_ids-1)+10)<10000;
        % cloud mask
        line_m = line_t(:,nbands*i_ids);  
        % # of clear observatons based on cloud mask values (0 or 1)
        idclr = line_m < 2;
        % clear and within physical range pixels
        idgood = idclr & idrange;
        
        % get clear Sentinel-2
        clrx_S2 = sdate(idgood);
        clry_S2 = line_t(idgood,(nbands*(i_ids-1)+1):(nbands*(i_ids-1)+nbands-1));
        clry_S2 = double(clry_S2);
end