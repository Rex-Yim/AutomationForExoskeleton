function sim = LoadHuGaDBSimulationData(cfg, varargin)
%% LoadHuGaDBSimulationData — choose one held-out HuGaDB session for pseudo-real-time replay

    if nargin < 1
        cfg = ExoConfig();
    end

    p = inputParser;
    addParameter(p, 'SubjectId', cfg.HUGADB.DEFAULT_SIM_SUBJECT, @(s) ischar(s) || isstring(s) || isnumeric(s));
    addParameter(p, 'SessionId', cfg.HUGADB.DEFAULT_SIM_SESSION, @(s) ischar(s) || isstring(s) || isnumeric(s));
    addParameter(p, 'HuGaDBSessionProtocols', cfg.HUGADB.DEFAULT_PROTOCOLS, @(x) isempty(x) || ischar(x) || isstring(x) || iscell(x));
    parse(p, varargin{:});

    subjectIds = NormalizeHuGaDBSubjectIds(p.Results.SubjectId);
    subjectId = subjectIds{1};
    protocolSelection = NormalizeHuGaDBProtocolSelection(p.Results.HuGaDBSessionProtocols);
    sessionId = char(strtrim(string(p.Results.SessionId)));
    if ~isempty(sessionId)
        sessionId = NormalizeHuGaDBSubjectIds(sessionId);
        sessionId = sessionId{1};
    end

    if ~exist(cfg.FILE.HUGADB_DATA, 'file')
        error('HuGaDB cache not found at %s. Run LoadHuGaDB first.', cfg.FILE.HUGADB_DATA);
    end

    S = load(cfg.FILE.HUGADB_DATA, 'hugadb');
    if ~isfield(S, 'hugadb') || ~isstruct(S.hugadb)
        error('HuGaDB cache at %s does not contain a valid hugadb struct.', cfg.FILE.HUGADB_DATA);
    end

    hug = S.hugadb;
    names = fieldnames(hug);
    matchNames = {};
    matchLengths = [];
    matchProtocols = {};

    for i = 1:numel(names)
        trialName = names{i};
        trial = hug.(trialName);
        meta = ResolveHuGaDBTrialMetadata(trialName, trial);
        [isValidTrial, trialInfo] = HuGaDBEvaluateTrialQuality(trial, cfg, ...
            'TrialName', trialName, 'SessionMeta', meta, 'AllowedProtocols', protocolSelection);
        if ~isValidTrial
            continue;
        end
        if ~strcmp(meta.subjectId, subjectId)
            continue;
        end
        if ~isempty(sessionId) && ~strcmp(meta.sessionId, sessionId)
            continue;
        end
        matchNames{end + 1} = trialName; %#ok<AGROW>
        matchLengths(end + 1) = size(trial.acc, 1); %#ok<AGROW>
        matchProtocols{end + 1} = trialInfo.protocol; %#ok<AGROW>
    end

    if isempty(matchNames)
        if isempty(sessionId)
            error('No valid HuGaDB sessions found for held-out subject %s after protocol/quality filtering.', subjectId);
        end
        error('No valid HuGaDB session found for subject %s session %s after protocol/quality filtering.', subjectId, sessionId);
    end

    [~, bestIdx] = max(matchLengths);
    selectedName = matchNames{bestIdx};
    trial = hug.(selectedName);
    meta = ResolveHuGaDBTrialMetadata(selectedName, trial);

    activeSet = cfg.DS.HUGADB.ACTIVE_LABELS;
    binaryLabels = double(ismember(trial.label_full(:), activeSet));

    sim = struct();
    sim.sessionName = selectedName;
    sim.subjectId = meta.subjectId;
    sim.sessionId = meta.sessionId;
    sim.sessionProtocol = matchProtocols{bestIdx};
    sim.acc = trial.acc;
    sim.gyro = trial.gyro;
    sim.label_full = trial.label_full(:);
    sim.binaryLabel = binaryLabels;
    sim.fs = trial.fs;
    sim.imuOrder = trial.imuOrder;
    sim.annotations = table((1:numel(binaryLabels)).', sim.label_full, sim.binaryLabel, ...
        'VariableNames', {'Sample', 'Label', 'BinaryLabel'});
end
