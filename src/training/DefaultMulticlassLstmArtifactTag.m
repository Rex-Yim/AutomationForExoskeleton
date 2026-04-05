function tag = DefaultMulticlassLstmArtifactTag(ds, protocolSelection)
% DefaultMulticlassLstmArtifactTag — dataset tag for multiclass LSTM artifacts (matches EvaluateLstmMulticlassConfusion).

    ds = lower(char(string(ds)));
    if strcmp(ds, 'usc_had')
        tag = 'usc_had';
        return;
    end

    if isequal(protocolSelection, {'multi_activity_sequence'})
        tag = 'hugadb_streaming';
    elseif isequal(protocolSelection, {'single_activity'})
        tag = 'hugadb_single_activity';
    else
        tag = 'hugadb';
    end
end
