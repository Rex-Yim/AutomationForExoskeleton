function ids = NormalizeHuGaDBSubjectIds(idsIn)
%% NormalizeHuGaDBSubjectIds — canonicalize subject IDs to two-digit strings

    if nargin < 1 || isempty(idsIn)
        ids = {};
        return;
    end

    if isnumeric(idsIn)
        rawIds = string(idsIn(:));
    elseif ischar(idsIn)
        rawIds = string({idsIn});
    elseif isstring(idsIn)
        rawIds = idsIn(:);
    elseif iscell(idsIn)
        rawIds = string(idsIn(:));
    else
        error('AutomationForExoskeleton:NormalizeHuGaDBSubjectIds:InvalidType', ...
            'Unsupported subject-id container type: %s.', class(idsIn));
    end

    ids = cell(size(rawIds));
    for i = 1:numel(rawIds)
        token = char(strtrim(rawIds(i)));
        digits = regexp(token, '\d+', 'match', 'once');
        if isempty(digits)
            error('AutomationForExoskeleton:NormalizeHuGaDBSubjectIds:InvalidValue', ...
                'Subject ID "%s" does not contain digits.', token);
        end
        ids{i} = sprintf('%02d', str2double(digits));
    end

    ids = unique(ids, 'stable');
end
