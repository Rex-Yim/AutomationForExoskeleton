% Prepare sliding-window features and native activity labels for one dataset.
% Supports `Dataset` values `usc_had` and `hugadb` and returns the same
% feature layout as `PrepareTrainingData`.

function [features, labels_class, ModelMetadata] = PrepareTrainingDataMulticlass(cfg, varargin)

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
    addParameter(p, 'HuGaDBSessionProtocols', cfg.HUGADB.DEFAULT_PROTOCOLS, @(x) isempty(x) || ischar(x) || isstring(x) || iscell(x));
    parse(p, varargin{:});

    ds = lower(char(p.Results.Dataset));
    includeHuSubjects = NormalizeHuGaDBSubjectIds(p.Results.IncludeHuGaDBSubjects);
    excludeHuSubjects = NormalizeHuGaDBSubjectIds(p.Results.ExcludeHuGaDBSubjects);
    protocolSelection = NormalizeHuGaDBProtocolSelection(p.Results.HuGaDBSessionProtocols);
    if ~ismember(ds, {'usc_had', 'hugadb'})
        error('AutomationForExoskeleton:PrepareTrainingDataMulticlass:Dataset', ...
            'Dataset must be ''usc_had'' or ''hugadb''.');
    end

    features = [];
    labels_class = [];
    n_usc = 0;
    n_hu = 0;
    usedHuProtocols = {};
    huQualityReport = HuGaDBInitQualityReport();

    if strcmp(ds, 'usc_had')

        if ~exist(cfg.FILE.USCHAD_DATA, 'file')
            error('AutomationForExoskeleton:PrepareTrainingDataMulticlass:MissingUSCHAD', ...
                'USC-HAD not found at %s.', cfg.FILE.USCHAD_DATA);
        end

        loadedData = load(cfg.FILE.USCHAD_DATA, 'usc');
        usc = loadedData.usc;
        all_trial_names = fieldnames(usc);

        fprintf('Preparing USC-HAD (multiclass, native 1..%d): %d trials...\n', ...
            ActivityClassRegistry.USCHAD_N_CLASSES, length(all_trial_names));

        for i = 1:length(all_trial_names)
            trial = usc.(all_trial_names{i});
            acc = trial.acc;
            gyro = trial.gyro;
            raw_label = trial.label(:);
            n_samples = size(acc, 1);

            if n_samples < cfg.WINDOW_SIZE
                continue;
            end

            c = ActivityClassRegistry.validateUSCHADNative(raw_label(1));
            if c < 1
                continue;
            end

            for k = 1:cfg.STEP_SIZE:(n_samples - cfg.WINDOW_SIZE + 1)
                ws = k;
                we = k + cfg.WINDOW_SIZE - 1;
                windowAcc = acc(ws:we, :);
                windowGyro = gyro(ws:we, :);
                feature_vector = LocomotionFeatureVector(windowAcc, windowGyro, cfg.FS, cfg);

                features = [features; feature_vector]; %#ok<AGROW>
                labels_class = [labels_class; c]; %#ok<AGROW>
                n_usc = n_usc + 1;
            end
        end

    else

        if ~exist(cfg.FILE.HUGADB_DATA, 'file')
            error('AutomationForExoskeleton:PrepareTrainingDataMulticlass:MissingHuGaDB', ...
                'HuGaDB not found at %s.', cfg.FILE.HUGADB_DATA);
        end

        S = load(cfg.FILE.HUGADB_DATA, 'hugadb');
        hug = S.hugadb;
        hnames = fieldnames(hug);

        fprintf('Preparing HuGaDB (multiclass, native 1..%d): %d sessions...\n', ...
            ActivityClassRegistry.HUGADB_N_CLASSES, numel(hnames));

        for i = 1:numel(hnames)
            trial = hug.(hnames{i});
            meta = ResolveHuGaDBTrialMetadata(hnames{i}, trial);
            huQualityReport.nSessionsScanned = huQualityReport.nSessionsScanned + 1;
            if ~shouldIncludeHuGaDBTrialMc(meta.subjectId, includeHuSubjects, excludeHuSubjects)
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
                c = ActivityClassRegistry.hugadbNativeWindowClass(chunk);
                huQualityReport.nWindowsScanned = huQualityReport.nWindowsScanned + 1;
                if c < 1
                    huQualityReport.nWindowsSkipped = huQualityReport.nWindowsSkipped + 1;
                    huQualityReport = HuGaDBAppendQualityReason(huQualityReport, 'window', 'invalid_native_class');
                    continue;
                end

                if ndims(acc) == 3 && size(acc, 2) == 3 && size(acc, 3) > 1
                    windowAcc = acc(ws:we, :, :);
                    windowGyro = gyro(ws:we, :, :);
                elseif size(acc, 2) == 3
                    windowAcc = squeeze(acc(ws:we, :, :));
                    windowGyro = squeeze(gyro(ws:we, :, :));
                else
                    error('AutomationForExoskeleton:PrepareTrainingDataMulticlass:HuGaDBShape', ...
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
                labels_class = [labels_class; c]; %#ok<AGROW>
                n_hu = n_hu + 1;
                huQualityReport.nWindowsAccepted = huQualityReport.nWindowsAccepted + 1;
            end
            usedHuProtocols{end + 1} = trialInfo.protocol; %#ok<AGROW>
        end
    end

    if isempty(features)
        error('No features extracted for multiclass. Run LoadUSCHAD / LoadHuGaDB.');
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
    ModelMetadata.dataset = ds;
    ModelMetadata.task = 'multiclass_native';
    ModelMetadata.includeHuGaDBSubjects = includeHuSubjects;
    ModelMetadata.excludeHuGaDBSubjects = excludeHuSubjects;
    ModelMetadata.huGaDBProtocolSelection = protocolSelection;
    ModelMetadata.usedHuGaDBProtocols = unique(usedHuProtocols, 'stable');
    ModelMetadata.huGaDBQualityReport = huQualityReport;

    if strcmp(ds, 'usc_had')
        ModelMetadata.classNames = ActivityClassRegistry.USCHAD_CLASS_NAMES;
        ModelMetadata.nClasses = ActivityClassRegistry.USCHAD_N_CLASSES;
    else
        ModelMetadata.classNames = ActivityClassRegistry.HUGADB_CLASS_NAMES;
        ModelMetadata.nClasses = ActivityClassRegistry.HUGADB_N_CLASSES;
    end

    fprintf(['Multiclass feature extraction complete. Total %d windows (%d features). ', ...
        'USC-HAD windows: %d | HuGaDB windows: %d\n'], ...
        size(features, 1), size(features, 2), n_usc, n_hu);
    if strcmp(ds, 'hugadb')
        lines = HuGaDBFormatQualityReport(huQualityReport);
        for i = 1:numel(lines)
            fprintf('%s\n', lines{i});
        end
    end
end

function tf = shouldIncludeHuGaDBTrialMc(subjectId, includeSubjects, excludeSubjects)
    tf = true;
    if ~isempty(includeSubjects)
        tf = any(strcmp(subjectId, includeSubjects));
    end
    if tf && ~isempty(excludeSubjects)
        tf = ~any(strcmp(subjectId, excludeSubjects));
    end
end
