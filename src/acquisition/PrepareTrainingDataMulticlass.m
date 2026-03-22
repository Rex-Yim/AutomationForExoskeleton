%% PrepareTrainingDataMulticlass.m
% Sliding-window features + unified activity class 1..K (ActivityClassRegistry).
% Same feature layout as PrepareTrainingData (LOCOMOTION vector size).
% NAME-VALUE: 'IncludeUSCHAD', 'IncludeHuGaDB' (defaults true).

function [features, labels_class, ModelMetadata] = PrepareTrainingDataMulticlass(cfg, varargin)

    if nargin < 1
        cfg = ExoConfig();
    end

    p = inputParser;
    addParameter(p, 'IncludeUSCHAD', true, @islogical);
    addParameter(p, 'IncludeHuGaDB', true, @islogical);
    parse(p, varargin{:});

    if ~p.Results.IncludeUSCHAD && ~p.Results.IncludeHuGaDB
        error('AutomationForExoskeleton:PrepareTrainingDataMulticlass:NoSource', ...
            'At least one of IncludeUSCHAD and IncludeHuGaDB must be true.');
    end

    features = [];
    labels_class = [];
    n_usc = 0;
    n_hu = 0;

    if p.Results.IncludeUSCHAD && exist(cfg.FILE.USCHAD_DATA, 'file')
        loadedData = load(cfg.FILE.USCHAD_DATA, 'usc');
        usc = loadedData.usc;
        all_trial_names = fieldnames(usc);

        fprintf('Preparing USC-HAD (multiclass): %d trials...\n', length(all_trial_names));

        for i = 1:length(all_trial_names)
            trial = usc.(all_trial_names{i});
            acc = trial.acc;
            gyro = trial.gyro;
            raw_label = trial.label(:);
            n_samples = size(acc, 1);

            if n_samples < cfg.WINDOW_SIZE
                continue;
            end

            c = ActivityClassRegistry.mapUSCHAD(raw_label(1));
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
    elseif p.Results.IncludeUSCHAD
        warning('AutomationForExoskeleton:MissingUSCHAD', ...
            'USC-HAD not found at %s.', cfg.FILE.USCHAD_DATA);
    end

    if p.Results.IncludeHuGaDB && exist(cfg.FILE.HUGADB_DATA, 'file')
        S = load(cfg.FILE.HUGADB_DATA, 'hugadb');
        hug = S.hugadb;
        hnames = fieldnames(hug);

        fprintf('Preparing HuGaDB (multiclass): %d sessions...\n', numel(hnames));

        for i = 1:numel(hnames)
            trial = hug.(hnames{i});
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
                c = ActivityClassRegistry.hugadbWindowClass(chunk);
                if c < 1
                    continue;
                end

                if ndims(acc) == 3 && size(acc, 2) == 3 && size(acc, 3) > 1
                    feature_vector = FeaturesFromImuStack(acc(ws:we, :, :), gyro(ws:we, :, :), cfg.FS);
                elseif size(acc, 2) == 3
                    accW = squeeze(acc(ws:we, :, :));
                    gyroW = squeeze(gyro(ws:we, :, :));
                    feature_vector = LocomotionFeatureVector(accW, gyroW, cfg.FS, cfg);
                else
                    error('AutomationForExoskeleton:PrepareTrainingDataMulticlass:HuGaDBShape', ...
                        'Unexpected HuGaDB acc size: %s.', mat2str(size(acc)));
                end

                features = [features; feature_vector]; %#ok<AGROW>
                labels_class = [labels_class; c]; %#ok<AGROW>
                n_hu = n_hu + 1;
            end
        end
    elseif p.Results.IncludeHuGaDB
        warning('AutomationForExoskeleton:MissingHuGaDB', ...
            'HuGaDB not found at %s.', cfg.FILE.HUGADB_DATA);
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
    ModelMetadata.includeUSCHAD = p.Results.IncludeUSCHAD;
    ModelMetadata.includeHuGaDB = p.Results.IncludeHuGaDB;
    ModelMetadata.task = 'multiclass';
    ModelMetadata.classNames = ActivityClassRegistry.CLASS_NAMES;
    ModelMetadata.nClasses = ActivityClassRegistry.N_CLASSES;

    fprintf(['Multiclass feature extraction complete. Total %d windows (%d features). ', ...
        'USC-HAD windows: %d | HuGaDB windows: %d\n'], ...
        size(features, 1), size(features, 2), n_usc, n_hu);
end
