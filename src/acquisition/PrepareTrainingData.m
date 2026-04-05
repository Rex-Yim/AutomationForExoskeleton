% Prepare sliding-window features for binary active-vs-inactive classification.
% Returns feature vectors and labels from USC-HAD and/or HuGaDB using the
% dataset inclusion and HuGaDB subject-filter options in `varargin`.
% Feature layout matches the configured locomotion feature vector, with
% zero-padding used when a dataset provides fewer IMU streams.

function [features, labels_binary, ModelMetadata] = PrepareTrainingData(cfg, varargin)

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
    addParameter(p, 'HuGaDBSessionProtocols', cfg.HUGADB.DEFAULT_PROTOCOLS, @isValidProtocolFilter);
    parse(p, varargin{:});

    if ~p.Results.IncludeUSCHAD && ~p.Results.IncludeHuGaDB
        error('AutomationForExoskeleton:PrepareTrainingData:NoSource', ...
            'Exactly one of IncludeUSCHAD and IncludeHuGaDB must be true.');
    end

    if p.Results.IncludeUSCHAD && p.Results.IncludeHuGaDB
        error('AutomationForExoskeleton:PrepareTrainingData:CombinedDatasetRemoved', ...
            ['Combined USC-HAD + HuGaDB training has been removed. ', ...
             'Choose either USC-HAD or HuGaDB.']);
    end

    features = [];
    labels_binary = [];
    n_usc = 0;
    n_hu = 0;
    usedHuSubjects = {};
    usedHuProtocols = {};
    includeHuSubjects = NormalizeHuGaDBSubjectIds(p.Results.IncludeHuGaDBSubjects);
    excludeHuSubjects = NormalizeHuGaDBSubjectIds(p.Results.ExcludeHuGaDBSubjects);
    protocolSelection = NormalizeHuGaDBProtocolSelection(p.Results.HuGaDBSessionProtocols);
    huQualityReport = HuGaDBInitQualityReport();

    %% --- USC-HAD ---
    if p.Results.IncludeUSCHAD && exist(cfg.FILE.USCHAD_DATA, 'file')
        loadedData = load(cfg.FILE.USCHAD_DATA, 'usc');
        usc = loadedData.usc;
        all_trial_names = fieldnames(usc);

        fprintf('Preparing USC-HAD: %d trials...\n', length(all_trial_names));

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

                feature_vector = LocomotionFeatureVector(windowAcc, windowGyro, cfg.FS, cfg);

                features = [features; feature_vector]; %#ok<AGROW>
                labels_binary = [labels_binary; trial_label_binary]; %#ok<AGROW>
                n_usc = n_usc + 1;
            end
        end
    elseif p.Results.IncludeUSCHAD
        warning('AutomationForExoskeleton:MissingUSCHAD', ...
            'USC-HAD not found at %s. Run LoadUSCHAD or set IncludeUSCHAD false for HuGaDB.', cfg.FILE.USCHAD_DATA);
    end

    %% --- HuGaDB (per-sample labels; majority vote inside each window) ---
    if p.Results.IncludeHuGaDB && exist(cfg.FILE.HUGADB_DATA, 'file')
        S = load(cfg.FILE.HUGADB_DATA, 'hugadb');
        hug = S.hugadb;
        hnames = fieldnames(hug);

        fprintf('Preparing HuGaDB: %d sessions...\n', numel(hnames));

        activeSet = cfg.DS.HUGADB.ACTIVE_LABELS;

        for i = 1:numel(hnames)
            trial = hug.(hnames{i});
            meta = ResolveHuGaDBTrialMetadata(hnames{i}, trial);
            huQualityReport.nSessionsScanned = huQualityReport.nSessionsScanned + 1;
            if ~shouldIncludeHuGaDBTrial(meta.subjectId, includeHuSubjects, excludeHuSubjects)
                huQualityReport.nSessionsSkipped = huQualityReport.nSessionsSkipped + 1;
                huQualityReport = HuGaDBAppendQualityReason(huQualityReport, 'session', 'subject_filtered_out');
                continue;
            end
            [isValidTrial, trialInfo] = HuGaDBEvaluateTrialQuality(trial, cfg, ...
                'TrialName', hnames{i}, 'SessionMeta', meta, 'AllowedProtocols', protocolSelection);
            if ~isValidTrial
                huQualityReport.nSessionsSkipped = huQualityReport.nSessionsSkipped + 1;
                huQualityReport = HuGaDBAppendQualityReason(huQualityReport, 'session', trialInfo.reason);
                continue;
            end
            huQualityReport.nSessionsAccepted = huQualityReport.nSessionsAccepted + 1;

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
                trial_label_binary = double(mean(isActive) >= 0.5); % majority
                huQualityReport.nWindowsScanned = huQualityReport.nWindowsScanned + 1;

                if ndims(acc) == 3 && size(acc, 2) == 3 && size(acc, 3) > 1
                    windowAcc = acc(ws:we, :, :);
                    windowGyro = gyro(ws:we, :, :);
                elseif size(acc, 2) == 3
                    % Nx3 legacy, or Nx3x1 after squeeze
                    windowAcc = squeeze(acc(ws:we, :, :));
                    windowGyro = squeeze(gyro(ws:we, :, :));
                else
                    error('AutomationForExoskeleton:PrepareTrainingData:HuGaDBShape', ...
                        'Unexpected HuGaDB acc size: %s.', mat2str(size(acc)));
                end
                [isValidWindow, windowReason] = HuGaDBEvaluateWindowQuality(windowAcc, windowGyro, chunk);
                if ~isValidWindow
                    huQualityReport.nWindowsSkipped = huQualityReport.nWindowsSkipped + 1;
                    huQualityReport = HuGaDBAppendQualityReason(huQualityReport, 'window', windowReason);
                    continue;
                end
                if ndims(acc) == 3 && size(acc, 2) == 3 && size(acc, 3) > 1
                    feature_vector = FeaturesFromImuStack(windowAcc, windowGyro, cfg.FS);
                else
                    feature_vector = LocomotionFeatureVector(windowAcc, windowGyro, cfg.FS, cfg);
                end

                features = [features; feature_vector]; %#ok<AGROW>
                labels_binary = [labels_binary; trial_label_binary]; %#ok<AGROW>
                n_hu = n_hu + 1;
                huQualityReport.nWindowsAccepted = huQualityReport.nWindowsAccepted + 1;
            end

            usedHuSubjects{end + 1} = meta.subjectId; %#ok<AGROW>
            usedHuProtocols{end + 1} = trialInfo.protocol; %#ok<AGROW>
        end
    elseif p.Results.IncludeHuGaDB
        warning('AutomationForExoskeleton:MissingHuGaDB', ...
            'HuGaDB not found at %s. Run LoadHuGaDB, or training uses USC-HAD.', cfg.FILE.HUGADB_DATA);
    end

    if isempty(features)
        error('No features extracted. Build usc_had_dataset.mat (LoadUSCHAD) and/or hugadb_dataset.mat (LoadHuGaDB).');
    end

    ModelMetadata.fs = cfg.FS;
    ModelMetadata.windowSize = cfg.WINDOW_SIZE;
    ModelMetadata.stepSize = cfg.STEP_SIZE;
    ModelMetadata.featureCount = size(features, 2);
    ModelMetadata.locomotionNImuSlots = cfg.LOCOMOTION.N_IMU_SLOTS;
    ModelMetadata.locomotionFeaturesPerImu = cfg.LOCOMOTION.FEATURES_PER_IMU;
    ModelMetadata.dateTrained = char(datetime('now'));
    ModelMetadata.nWindowsUSCHAD = n_usc;
    ModelMetadata.nWindowsHuGaDB = n_hu;
    ModelMetadata.includeUSCHAD = p.Results.IncludeUSCHAD;
    ModelMetadata.includeHuGaDB = p.Results.IncludeHuGaDB;
    ModelMetadata.includeHuGaDBSubjects = includeHuSubjects;
    ModelMetadata.excludeHuGaDBSubjects = excludeHuSubjects;
    ModelMetadata.usedHuGaDBSubjects = unique(usedHuSubjects, 'stable');
    ModelMetadata.huGaDBProtocolSelection = protocolSelection;
    ModelMetadata.usedHuGaDBProtocols = unique(usedHuProtocols, 'stable');
    ModelMetadata.huGaDBQualityReport = huQualityReport;
    ModelMetadata.categoryOrder = ActivityClassRegistry.binaryClassNames();
    ModelMetadata.labelNegative = ModelMetadata.categoryOrder{1};
    ModelMetadata.labelPositive = ModelMetadata.categoryOrder{2};

    fprintf(['Feature extraction complete. Total %d windows (%d features). ', ...
        'USC-HAD windows: %d | HuGaDB windows: %d\n'], ...
        size(features, 1), size(features, 2), n_usc, n_hu);
    if p.Results.IncludeHuGaDB
        lines = HuGaDBFormatQualityReport(huQualityReport);
        for i = 1:numel(lines)
            fprintf('%s\n', lines{i});
        end
    end
end

function tf = isValidSubjectFilter(value)
    tf = isempty(value) || isnumeric(value) || ischar(value) || isstring(value) || iscell(value);
end

function tf = isValidProtocolFilter(value)
    tf = isempty(value) || ischar(value) || isstring(value) || iscell(value);
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
