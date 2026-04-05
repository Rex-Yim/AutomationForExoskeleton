% Prepare sliding-window sequence data for binary LSTM training.
% Returns `XCell`, binary labels, and metadata using the same dataset controls
% as `PrepareTrainingData`. Each sequence has size
% `(6 * N_IMU_SLOTS) x WINDOW_SIZE`.

function [XCell, labels_binary, ModelMetadata] = PrepareTrainingDataSequences(cfg, varargin)

    if nargin < 1
        cfg = ExoConfig();
    end

    defaultIncludeUSC = true;
    defaultIncludeHu = true;
    defaultExcludedSubjects = {};
    if isprop(cfg, 'TRAINING')
        defaultIncludeUSC = cfg.TRAINING.DEFAULT_INCLUDE_USCHAD;
        defaultIncludeHu = cfg.TRAINING.DEFAULT_INCLUDE_HUGADB;
    end
    if isprop(cfg, 'HUGADB')
        defaultExcludedSubjects = cfg.HUGADB.HELDOUT_SUBJECTS;
    end

    p = inputParser;
    addParameter(p, 'IncludeUSCHAD', defaultIncludeUSC, @islogical);
    addParameter(p, 'IncludeHuGaDB', defaultIncludeHu, @islogical);
    addParameter(p, 'IncludeHuGaDBSubjects', {}, @isValidSubjectFilter);
    addParameter(p, 'ExcludeHuGaDBSubjects', defaultExcludedSubjects, @isValidSubjectFilter);
    parse(p, varargin{:});

    if ~p.Results.IncludeUSCHAD && ~p.Results.IncludeHuGaDB
        error('AutomationForExoskeleton:PrepareTrainingDataSequences:NoSource', ...
            'Exactly one of IncludeUSCHAD and IncludeHuGaDB must be true.');
    end

    if p.Results.IncludeUSCHAD && p.Results.IncludeHuGaDB
        error('AutomationForExoskeleton:PrepareTrainingDataSequences:CombinedDatasetRemoved', ...
            ['Combined USC-HAD + HuGaDB sequence training has been removed. ', ...
             'Choose either USC-HAD or HuGaDB.']);
    end

    XCell = {};
    labels_binary = [];
    n_usc = 0;
    n_hu = 0;
    usedHuSubjects = {};
    includeHuSubjects = NormalizeHuGaDBSubjectIds(p.Results.IncludeHuGaDBSubjects);
    excludeHuSubjects = NormalizeHuGaDBSubjectIds(p.Results.ExcludeHuGaDBSubjects);

    nCh = cfg.LOCOMOTION.N_IMU_SLOTS * 6;

    %% --- USC-HAD ---
    if p.Results.IncludeUSCHAD && exist(cfg.FILE.USCHAD_DATA, 'file')
        loadedData = load(cfg.FILE.USCHAD_DATA, 'usc');
        usc = loadedData.usc;
        all_trial_names = fieldnames(usc);

        fprintf('Preparing USC-HAD sequences: %d trials...\n', length(all_trial_names));

        for i = 1:length(all_trial_names)
            trial_name = all_trial_names{i};
            trial = usc.(trial_name);

            acc = trial.acc;
            gyro = trial.gyro;
            raw_label = trial.label;
            n_samples = size(acc, 1);

            if n_samples < cfg.WINDOW_SIZE
                continue;
            end

            is_active = ismember(raw_label, cfg.DS.USCHAD.ACTIVE_LABELS);
            trial_label_binary = double(is_active);

            for k = 1:cfg.STEP_SIZE:(n_samples - cfg.WINDOW_SIZE + 1)
                window_start = k;
                window_end = k + cfg.WINDOW_SIZE - 1;

                windowAcc = acc(window_start:window_end, :);
                windowGyro = gyro(window_start:window_end, :);

                seq = ImuWindowToSequenceMatrix(windowAcc, windowGyro, cfg);
                XCell{end + 1, 1} = seq; %#ok<AGROW>
                labels_binary = [labels_binary; trial_label_binary]; %#ok<AGROW>
                n_usc = n_usc + 1;
            end
        end
    elseif p.Results.IncludeUSCHAD
        warning('AutomationForExoskeleton:MissingUSCHAD', ...
            'USC-HAD not found at %s.', cfg.FILE.USCHAD_DATA);
    end

    %% --- HuGaDB ---
    if p.Results.IncludeHuGaDB && exist(cfg.FILE.HUGADB_DATA, 'file')
        S = load(cfg.FILE.HUGADB_DATA, 'hugadb');
        hug = S.hugadb;
        hnames = fieldnames(hug);

        fprintf('Preparing HuGaDB sequences: %d sessions...\n', numel(hnames));

        activeSet = cfg.DS.HUGADB.ACTIVE_LABELS;

        for i = 1:numel(hnames)
            trial = hug.(hnames{i});
            meta = ResolveHuGaDBTrialMetadata(hnames{i}, trial);
            if ~shouldIncludeHuGaDBTrial(meta.subjectId, includeHuSubjects, excludeHuSubjects)
                continue;
            end

            acc = trial.acc;
            gyro = trial.gyro;
            lf = trial.label_full(:);
            n_samples = size(acc, 1);

            if n_samples < cfg.WINDOW_SIZE
                continue;
            end

            for k = 1:cfg.STEP_SIZE:(n_samples - cfg.WINDOW_SIZE + 1)
                ws = k;
                we = k + cfg.WINDOW_SIZE - 1;
                chunk = lf(ws:we);
                isActive = ismember(chunk, activeSet);
                trial_label_binary = double(mean(isActive) >= 0.5);

                if ndims(acc) == 3 && size(acc, 2) == 3 && size(acc, 3) > 1
                    windowAcc = acc(ws:we, :, :);
                    windowGyro = gyro(ws:we, :, :);
                elseif size(acc, 2) == 3
                    accW = squeeze(acc(ws:we, :, :));
                    gyroW = squeeze(gyro(ws:we, :, :));
                    windowAcc = accW;
                    windowGyro = gyroW;
                else
                    error('AutomationForExoskeleton:PrepareTrainingDataSequences:HuGaDBShape', ...
                        'Unexpected HuGaDB acc size: %s.', mat2str(size(acc)));
                end

                seq = ImuWindowToSequenceMatrix(windowAcc, windowGyro, cfg);
                XCell{end + 1, 1} = seq; %#ok<AGROW>
                labels_binary = [labels_binary; trial_label_binary]; %#ok<AGROW>
                n_hu = n_hu + 1;
            end

            usedHuSubjects{end + 1} = meta.subjectId; %#ok<AGROW>
        end
    elseif p.Results.IncludeHuGaDB
        warning('AutomationForExoskeleton:MissingHuGaDB', ...
            'HuGaDB not found at %s.', cfg.FILE.HUGADB_DATA);
    end

    if isempty(XCell)
        error('No sequences extracted. Build usc_had_dataset.mat and/or hugadb_dataset.mat.');
    end

    ModelMetadata.fs = cfg.FS;
    ModelMetadata.windowSize = cfg.WINDOW_SIZE;
    ModelMetadata.stepSize = cfg.STEP_SIZE;
    ModelMetadata.sequenceInputSize = nCh;
    ModelMetadata.sequenceLength = cfg.WINDOW_SIZE;
    ModelMetadata.nWindowsUSCHAD = n_usc;
    ModelMetadata.nWindowsHuGaDB = n_hu;
    ModelMetadata.includeUSCHAD = p.Results.IncludeUSCHAD;
    ModelMetadata.includeHuGaDB = p.Results.IncludeHuGaDB;
    ModelMetadata.includeHuGaDBSubjects = includeHuSubjects;
    ModelMetadata.excludeHuGaDBSubjects = excludeHuSubjects;
    ModelMetadata.usedHuGaDBSubjects = unique(usedHuSubjects, 'stable');
    ModelMetadata.dateTrained = char(datetime('now'));
    ModelMetadata.categoryOrder = ActivityClassRegistry.binaryClassNames();
    ModelMetadata.labelNegative = ModelMetadata.categoryOrder{1};
    ModelMetadata.labelPositive = ModelMetadata.categoryOrder{2};

    fprintf(['Sequence extraction complete. Total %d windows (%d x %d each). ', ...
        'USC-HAD: %d | HuGaDB: %d\n'], numel(XCell), nCh, cfg.WINDOW_SIZE, n_usc, n_hu);
end

function tf = isValidSubjectFilter(value)
    tf = isempty(value) || isnumeric(value) || ischar(value) || isstring(value) || iscell(value);
end

function tf = shouldIncludeHuGaDBTrial(subjectId, includeSubjects, excludeSubjects)
    tf = true;
    if ~isempty(includeSubjects)
        tf = any(strcmp(subjectId, includeSubjects));
    end
    if tf && ~isempty(excludeSubjects)
        tf = ~any(strcmp(subjectId, excludeSubjects));
    end
end
