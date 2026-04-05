function protocols = NormalizeHuGaDBProtocolSelection(value)
% NormalizeHuGaDBProtocolSelection  Canonicalize HuGaDB session protocol filters.

    if nargin < 1 || isempty(value)
        protocols = {};
        return;
    end

    if ischar(value) || isstring(value)
        raw = cellstr(string(value));
    elseif iscell(value)
        raw = cellfun(@(x) char(string(x)), value, 'UniformOutput', false);
    else
        error('NormalizeHuGaDBProtocolSelection: expected char, string, or cell array.');
    end

    protocols = {};
    for i = 1:numel(raw)
        tok = lower(strtrim(char(string(raw{i}))));
        if isempty(tok) || strcmp(tok, 'all') || strcmp(tok, '*')
            protocols = {};
            return;
        end
        switch tok
            case {'single', 'single_activity', 'singleactivity'}
                canon = 'single_activity';
            case {'multi', 'sequence', 'multi_activity', 'multi_activity_sequence', 'streaming'}
                canon = 'multi_activity_sequence';
            otherwise
                canon = tok;
        end
        protocols{end + 1} = canon; %#ok<AGROW>
    end

    protocols = unique(protocols, 'stable');
end
