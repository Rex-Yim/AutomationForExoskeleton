function out = HuGaDBGyroCorruptionMatrix(action, arg1, arg2)
% HuGaDBGyroCorruptionMatrix  Official HuGaDB README gyro corruption table helpers.
%
%   map = HuGaDBGyroCorruptionMatrix('load', csvPath)
%       Returns containers.Map: lower(filename) -> 1x6 logical (RF,RS,RT,LF,LS,LT).
%
%   M = HuGaDBGyroCorruptionMatrix('applyRaw', M, gmask)
%       Zeros gyro columns (per IMU) in raw integer matrix M for slots where gmask is true.

    switch lower(strtrim(char(string(action))))
        case 'load'
            out = loadCorruptionMap(arg1);
        case 'applyraw'
            out = applyRawMask(arg1, arg2);
        otherwise
            error('HuGaDBGyroCorruptionMatrix: unknown action "%s".', action);
    end
end

function corruptMap = loadCorruptionMap(csvPath)
    corruptMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    if ~isfile(csvPath)
        return;
    end
    C = readcell(csvPath);
    if size(C, 2) < 7
        return;
    end
    % Columns: file, right_foot, left_foot, right_shank, left_shank, right_thigh, left_thigh
    % CSV col 2 = right_foot = slot 1 (RF)
    % CSV col 3 = left_foot = slot 4 (LF)
    % CSV col 4 = right_shank = slot 2 (RS)
    % CSV col 5 = left_shank = slot 5 (LS)
    % CSV col 6 = right_thigh = slot 3 (RT)
    % CSV col 7 = left_thigh = slot 6 (LT)
    slotFromCsvCol = [1, 4, 2, 5, 3, 6];
    for r = 2:size(C, 1)
        fn0 = C{r, 1};
        if isempty(fn0) || (isstring(fn0) && isscalar(fn0) && ismissing(fn0))
            continue;
        end
        fn = char(strtrim(string(fn0)));
        if isempty(fn)
            continue;
        end
        key = lower(fn);
        gmask = false(1, 6);
        for c = 1:6
            v = C{r, 1 + c};
            if ismissing(v)
                bad = false;
            elseif isempty(v) || (isnumeric(v) && isscalar(v) && isnan(v))
                bad = false;
            else
                bad = strcmpi(strtrim(char(string(v))), 'Corrupted');
            end
            gmask(slotFromCsvCol(c)) = bad;
        end
        corruptMap(key) = gmask;
    end
end

function M = applyRawMask(M, gmask)
    if isempty(M) || nargin < 2 || isempty(gmask)
        return;
    end
    gmask = logical(gmask(:)).';
    if numel(gmask) ~= 6
        error('applyRawMask: gmask must have 6 elements.');
    end
    for s = 0:5
        if s + 1 <= numel(gmask) && gmask(s + 1)
            c0 = s * 6 + 1;
            M(:, c0 + 3:c0 + 5) = 0;
        end
    end
end
