function datestring_new = convertDate(datestring,format)
    switch format
        case 'YYYYdoy'
            YYYYdoy = date2doy(datestring);
            datestring_new = YYYYdoy;
        case 'YYYYmmdd'
            YYYYmmdd = removeDashInDate(datestring);
            datestring_new = YYYYmmdd;
        case 'YYYY-mm-dd'
            if length(datestring)==8
                datestring_new = addDashInDate(datestring);
            else
                error('Invalid input date string!\r');
            end
    
    end
end



function YYYYdoy = date2doy(YYYYmmdd)
% convert YYYY-mm-dd string to YYYYdoy
    dt = datetime(YYYYmmdd);
    yr = year(dt);
    doy = day(dt,'dayofyear');
    YYYYdoy = strcat(int2str(yr),sprintf('%03d',doy));
end


function YYYYmmdd = removeDashInDate(YYYYmmdd)
% convert YYYY-mm-dd string to YYYYmmdd

    dt = datetime(YYYYmmdd);
    yr = year(dt);
    m = month(dt);
    d = day(dt);
    YYYYmmdd = strcat(int2str(yr),sprintf('%02d',m),sprintf('%02d',d));
end

function YYYYmmdd = addDashInDate(YYYYmmdd)
% convert YYYYmmdd string to YYYY-mm-dd

    yr = YYYYmmdd(1:4);
    m = YYYYmmdd(5:6);
    d = YYYYmmdd(7:8);
    YYYYmmdd = [yr,'-',m,'-',d];
    
end