function [XCell, labelsClass, ModelMetadata] = PrepareTrainingDataSequencesMulticlass(cfg, varargin)
% Prepare sliding-window sequences and native activity labels for one dataset.
% Supports `Dataset` values `usc_had` and `hugadb` and returns sequence
% samples shaped for multiclass LSTM training.

    if nargin < 1
        cfg = ExoConfig();
    end

    defaultExcludedSubjects = {};
    if isprop(cfg, 'HUGADB')
        defaultExcludedSubjects = cfg.HUGADB.HELDOUT_SUBJECTS;
    end

    p = inputParser;
    addParameter(p, 'Dataset', 'hugadb', @(s) ischar(s) || isstring(s));
    addParameter(p, 'IncludeHuGaDBSubjects', {}, @(x) isempty(x) || isnumeric(x) || ischar(x) || isstring(x) || iscell(x));
    addParameter(p, 'ExcludeHuGaDBSubjects', defaultExcludedSubjects, @(x) isempty(x) || isnumeric(x) || ischar(x) || isstring(x) || iscell(x));
    parse(p, varargin{:});

    ds = lower(char(p.Results.Dataset));
    includeHuSubjects = NormalizeHuGaDBSubjectIds(p.Results.IncludeHuGaDBSubjects);
    excludeHuSubjects = NormalizeHuGaDBSubjectIds(p.Results.ExcludeHuGaDBSubjects);
    if ~ismember(ds, {'usc_had', 'hugadb'})
        error('AutomationForExoskeleton:PrepareTrainingDataSequencesMulticlass:Dataset', ...
            'Dataset must be ''usc_had'' or ''hugadb''.');
    end

    XCell = {};
    labelsClass = [];
    nUsc = 0;
    nHu = 0;
    nCh = cfg.LOCOMOTION.N_IMU_SLOTS * 6;

    if strcmp(ds, 'usc_had')
        if ~exist(cfg.FILE.USCHAD_DATA, 'file')
            error('AutomationForExoskeleton:PrepareTrainingDataSequencesMulticlass:MissingUSCHAD', ...
                'USC-HAD not found at %s.', cfg.FILE.USCHAD_DATA);
        end

        loadedData = load(cfg.FILE.USCHAD_DATA, 'usc');
        usc = loadedData.usc;
        allTrialNames = fieldnames(usc);

        fprintf('Preparing USC-HAD multiclass sequences: %d trials...\n', numel(allTrialNames));
        for i = 1:numel(allTrialNames)
            trial = usc.(allTrialNames{i});
            acc = trial.acc;
            gyro = trial.gyro;
            rawLabel = trial.label(:);
            nSamples = size(acc, 1);

            if nSamples < cfg.WINDOW_SIZE
                continue;
            end

            classId = ActivityClassRegistry.validateUSCHADNative(rawLabel(1));
            if classId < 1
                continue;
            end

            for k = 1:cfg.STEP_SIZE:(nSamples - cfg.WINDOW_SIZE + 1)
                ws = k;
                we = k + cfg.WINDOW_SIZE - 1;
                seq = ImuWindowToSequenceMatrix(acc(ws:we, :), gyro(ws:we, :), cfg);
                XCell{end + 1, 1} = seq; %#ok<AGROW>
                labelsClass = [labelsClass; classId]; %#ok<AGROW>
                nUsc = nUsc + 1;
            end
        end

        classNames = ActivityClassRegistry.USCHAD_CLASS_NAMES;
        nClasses = ActivityClassRegistry.USCHAD_N_CLASSES;
    else
        if ~exist(cfg.FILE.HUGADB_DATA, 'file')
            error('AutomationForExoskeleton:PrepareTrainingDataSequencesMulticlass:MissingHuGaDB', ...
                'HuGaDB not found at %s.', cfg.FILE.HUGADB_DATA);
        end

        S = load(cfg.FILE.HUGADB_DATA, 'hugadb');
        hug = S.hugadb;
        hnames = fieldnames(hug);

        fprintf('Preparing HuGaDB multiclass sequences: %d sessions...\n', numel(hnames));
        for i = 1:numel(hnames)
            trial = hug.(hnames{i});
            meta = ResolveHuGaDBTrialMetadata(hnames{i}, trial);
            if ~shouldIncludeHuGaDBTrialSeqMc(meta.subjectId, includeHuSubjects, excludeHuSubjects)
                continue;
            end

            acc = trial.acc;
            gyro = trial.gyro;
            lf = trial.label_full(:);
            nSamples = size(acc, 1);

            if nSamples < cfg.WINDOW_SIZE
                continue;
            end

            for k = 1:cfg.STEP_SIZE:(nSamples - cfg.WINDOW_SIZE + 1)
                ws = k;
                we = k + cfg.WINDOW_SIZE - 1;
                classId = ActivityClassRegistry.hugadbNativeWindowClass(lf(ws:we));
                if classId < 1
                    continue;
                end

                if ndims(acc) == 3 && size(acc, 2) == 3 && size(acc, 3) > 1
                    windowAcc = acc(ws:we, :, :);
                    windowGyro = gyro(ws:we, :, :);
                elseif size(acc, 2) == 3
                    windowAcc = squeeze(acc(ws:we, :, :));
                    windowGyro = squeeze(gyro(ws:we, :, :));
                else
                    error('AutomationForExoskeleton:PrepareTrainingDataSequencesMulticlass:HuGaDBShape', ...
                        'Unexpected HuGaDB acc size: %s.', mat2str(size(acc)));
                end

                seq = ImuWindowToSequenceMatrix(windowAcc, windowGyro, cfg);
                XCell{end + 1, 1} = seq; %#ok<AGROW>
                labelsClass = [labelsClass; classId]; %#ok<AGROW>
                nHu = nHu + 1;
            end
        end

        classNames = ActivityClassRegistry.HUGADB_CLASS_NAMES;
        nClasses = ActivityClassRegistry.HUGADB_N_CLASSES;
    end

    if isempty(XCell)
        error('No sequences extracted for multiclass LSTM. Build dataset MAT files first.');
    end

    ModelMetadata.fs = cfg.FS;
    ModelMetadata.windowSize = cfg.WINDOW_SIZE;
    ModelMetadata.stepSize = cfg.STEP_SIZE;
    ModelMetadata.sequenceInputSize = nCh;
    ModelMetadata.sequenceLength = cfg.WINDOW_SIZE;
    ModelMetadata.nWindowsUSCHAD = nUsc;
    ModelMetadata.nWindowsHuGaDB = nHu;
    ModelMetadata.dataset = ds;
    ModelMetadata.task = 'multiclass_native_sequence';
    ModelMetadata.classNames = classNames;
    ModelMetadata.nClasses = nClasses;
    ModelMetadata.dateTrained = char(datetime('now'));
    ModelMetadata.includeHuGaDBSubjects = includeHuSubjects;
    ModelMetadata.excludeHuGaDBSubjects = excludeHuSubjects;

    fprintf(['Multiclass sequence extraction complete. Total %d windows (%d x %d each). ', ...
        'USC-HAD: %d | HuGaDB: %d\n'], numel(XCell), nCh, cfg.WINDOW_SIZE, nUsc, nHu);
end

function tf = shouldIncludeHuGaDBTrialSeqMc(subjectId, includeSubjects, excludeSubjects)
    tf = true;
    if ~isempty(includeSubjects)
        tf = any(strcmp(subjectId, includeSubjects));
    end
    if tf && ~isempty(excludeSubjects)
        tf = ~any(strcmp(subjectId, excludeSubjects));
    end
end
