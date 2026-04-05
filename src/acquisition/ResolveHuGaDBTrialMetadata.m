function meta = ResolveHuGaDBTrialMetadata(trialName, trial)
%% ResolveHuGaDBTrialMetadata — normalize HuGaDB session metadata from cache fields

    parsed = ParseHuGaDBSessionName(trialName);

    meta = struct();
    meta.trialName = char(string(trialName));
    meta.fileStem = parsed.fileStem;
    meta.subjectId = parsed.subjectId;
    meta.sessionId = parsed.sessionId;

    if nargin < 2 || ~isstruct(trial)
        return;
    end

    if isfield(trial, 'subjectId') && ~isempty(trial.subjectId)
        meta.subjectId = NormalizeHuGaDBSubjectIds(trial.subjectId);
        meta.subjectId = meta.subjectId{1};
    end

    if isfield(trial, 'sessionId') && ~isempty(trial.sessionId)
        meta.sessionId = NormalizeHuGaDBSubjectIds(trial.sessionId);
        meta.sessionId = meta.sessionId{1};
    end
end
