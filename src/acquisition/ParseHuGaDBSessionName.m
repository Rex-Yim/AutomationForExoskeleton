function meta = ParseHuGaDBSessionName(sessionName)
%% ParseHuGaDBSessionName — derive HuGaDB subject/session IDs from a name or path

    raw = char(string(sessionName));
    [~, rawStem, ~] = fileparts(raw);
    rawStem = regexprep(rawStem, '^s_', '');

    tokens = regexp(rawStem, '^HuGaDB_v(\d+)_([a-z_]+)_(\d{2})_(\d{2})$', 'tokens', 'once');
    if ~isempty(tokens)
        meta = struct();
        meta.fileStem = rawStem;
        meta.filenameVersion = tokens{1};
        meta.activityType = tokens{2};
        meta.subjectId = tokens{3};
        meta.sessionId = tokens{4};
        return;
    end

    tokens = regexp(rawStem, 'HuGaDB_v[1234]_.+_(\d{2})_(\d{2})$', 'tokens', 'once');
    if isempty(tokens)
        tokens = regexp(rawStem, '(\d{2})_(\d{2})$', 'tokens', 'once');
    end

    if isempty(tokens)
        error('AutomationForExoskeleton:ParseHuGaDBSessionName:InvalidName', ...
            'Could not parse HuGaDB subject/session from "%s".', raw);
    end

    meta = struct();
    meta.fileStem = rawStem;
    meta.filenameVersion = '';
    meta.activityType = '';
    meta.subjectId = tokens{1};
    meta.sessionId = tokens{2};
end
