%% PrepareTrainingData.m
% --------------------------------------------------------------------------
% FUNCTION: [features, labels_binary, ModelMetadata] = PrepareTrainingData(cfg, varargin)
% PURPOSE:  Sliding-window features for binary Walk(1) vs Stand(0) from
%           USC-HAD and/or HuGaDB. Vector length = N_IMU_SLOTS * FEATURES_PER_IMU
%           (ExoConfig.LOCOMOTION): HuGaDB uses all 6 IMUs; USC-HAD / legacy HuGaDB
%           use one IMU stream + zero padding for unused slots (inference matches).
% --------------------------------------------------------------------------
% NAME-VALUE:
%   'IncludeUSCHAD' (logical, default true) — windows from usc_had_dataset.mat
%   'IncludeHuGaDB' (logical, default true) — append hugadb_dataset.mat if present;
%      otherwise warn and continue (when true).
%   At least one of IncludeUSCHAD / IncludeHuGaDB must be true.
% --------------------------------------------------------------------------

function [features, labels_binary, ModelMetadata] = PrepareTrainingData(cfg, varargin)

    if nargin < 1
        cfg = ExoConfig();
    end

    p = inputParser;
    addParameter(p, 'IncludeUSCHAD', true, @islogical);
    addParameter(p, 'IncludeHuGaDB', true, @islogical);
    parse(p, varargin{:});

    if ~p.Results.IncludeUSCHAD && ~p.Results.IncludeHuGaDB
        error('AutomationForExoskeleton:PrepareTrainingData:NoSource', ...
            'At least one of IncludeUSCHAD and IncludeHuGaDB must be true.');
    end

    features = [];
    labels_binary = [];
    n_usc = 0;
    n_hu = 0;

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

            is_walking = ismember(raw_label, cfg.DS.USCHAD.WALKING_LABELS);
            trial_label_binary = double(is_walking);

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
            'USC-HAD not found at %s. Run LoadUSCHAD or set IncludeUSCHAD false for HuGaDB only.', cfg.FILE.USCHAD_DATA);
    end

    %% --- HuGaDB (per-sample labels; majority vote inside each window) ---
    if p.Results.IncludeHuGaDB && exist(cfg.FILE.HUGADB_DATA, 'file')
        S = load(cfg.FILE.HUGADB_DATA, 'hugadb');
        hug = S.hugadb;
        hnames = fieldnames(hug);

        fprintf('Preparing HuGaDB: %d sessions...\n', numel(hnames));

        walkSet = cfg.DS.HUGADB.WALKING_LABELS;

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
                isW = ismember(chunk, walkSet);
                trial_label_binary = double(mean(isW) >= 0.5); % majority

                if ndims(acc) == 3 && size(acc, 2) == 3 && size(acc, 3) > 1
                    feature_vector = FeaturesFromImuStack(acc(ws:we, :, :), gyro(ws:we, :, :), cfg.FS);
                elseif size(acc, 2) == 3
                    % Nx3 legacy, or Nx3x1 after squeeze
                    accW = squeeze(acc(ws:we, :, :));
                    gyroW = squeeze(gyro(ws:we, :, :));
                    feature_vector = LocomotionFeatureVector(accW, gyroW, cfg.FS, cfg);
                else
                    error('AutomationForExoskeleton:PrepareTrainingData:HuGaDBShape', ...
                        'Unexpected HuGaDB acc size: %s.', mat2str(size(acc)));
                end

                features = [features; feature_vector]; %#ok<AGROW>
                labels_binary = [labels_binary; trial_label_binary]; %#ok<AGROW>
                n_hu = n_hu + 1;
            end
        end
    elseif p.Results.IncludeHuGaDB
        warning('AutomationForExoskeleton:MissingHuGaDB', ...
            'HuGaDB not found at %s. Run LoadHuGaDB, or training uses USC-HAD only.', cfg.FILE.HUGADB_DATA);
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

    fprintf(['Feature extraction complete. Total %d windows (%d features). ', ...
        'USC-HAD windows: %d | HuGaDB windows: %d\n'], ...
        size(features, 1), size(features, 2), n_usc, n_hu);
end
