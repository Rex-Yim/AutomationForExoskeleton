function tag = DefaultBinaryLstmArtifactTag(inclU, inclH, includeHuSubjects, excludeHuSubjects, protocolSelection)
% DefaultBinaryLstmArtifactTag — dataset tag for binary LSTM artifacts (matches EvaluateLstmConfusion).

    if inclU && ~inclH
        tag = 'usc_had';
        return;
    end

    if ~inclU && inclH
        if isempty(includeHuSubjects) && isempty(excludeHuSubjects) && isequal(protocolSelection, {'multi_activity_sequence'})
            tag = 'hugadb_streaming';
            return;
        end
        if isempty(includeHuSubjects) && isempty(excludeHuSubjects) && isequal(protocolSelection, {'single_activity'})
            tag = 'hugadb_single_activity';
            return;
        end
    end

    tag = sanitizeTagForArtifacts(datasetPoolLabelBinary(inclU, inclH, includeHuSubjects, excludeHuSubjects, protocolSelection));
end

function s = datasetPoolLabelBinary(inclU, inclH, includeHuSubjects, excludeHuSubjects, protocolSelection)
    if inclU && inclH
        error('Combined USC-HAD + HuGaDB LSTM evaluation has been removed.');
    elseif inclU
        s = 'USC-HAD';
    else
        s = 'HuGaDB';
    end

    if ~isempty(includeHuSubjects)
        s = sprintf('%s (subjects %s)', s, strjoin(includeHuSubjects, ', '));
    elseif ~isempty(excludeHuSubjects) && ~inclU && inclH
        s = sprintf('%s (excluding subjects %s)', s, strjoin(excludeHuSubjects, ', '));
    end
    if ~inclU && inclH && ~isempty(protocolSelection)
        s = sprintf('%s | protocols: %s', s, strjoin(protocolSelection, ', '));
    end
end

function out = sanitizeTagForArtifacts(label)
    out = regexprep(lower(char(label)), '[^a-z0-9]+', '_');
    out = regexprep(out, '^_+|_+$', '');
end
