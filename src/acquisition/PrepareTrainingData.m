%% PrepareTrainingData.m
% --------------------------------------------------------------------------
% FUNCTION: [features, labels_binary, ModelMetadata] = PrepareTrainingData(cfg)
% PURPOSE: Loads data, extracts features in sliding windows, and binarizes 
% the labels for binary SVM training (WALKING=1, STANDING=0).
% --------------------------------------------------------------------------
% DATE CREATED: 2025-12-13
% LAST MODIFIED: 2025-12-13 (Added ModelMetadata output)
% --------------------------------------------------------------------------
% DEPENDENCIES: 
% - ExoConfig.m
% - LoadUSCHAD.m (to ensure data is processed)
% - ImportUschadSingleImu.m
% - Features.m
% --------------------------------------------------------------------------

function [features, labels_binary, ModelMetadata] = PrepareTrainingData(cfg)

if nargin < 1
    cfg = ExoConfig();
end

% --- 1. Load USC-HAD Data Structure ---
% NOTE: Assuming LoadUSCHAD has been run and usc_had_dataset.mat exists
load(cfg.FILE.USCHAD_DATA, 'usc');

% Prepare lists for feature vectors and corresponding binary labels
features = [];
labels_binary = [];
all_trial_names = fieldnames(usc);

fprintf('Starting feature extraction on %d USC-HAD trials...\n', length(all_trial_names));

% --- 2. Iterate through all trials ---
for i = 1:length(all_trial_names)
    trial_name = all_trial_names{i};
    trial = usc.(trial_name);
    
    % Use only the 'back' IMU data (single IMU pipeline simulation)
    acc = trial.acc;
    gyro = trial.gyro;
    raw_label = trial.label;
    
    n_samples = size(acc, 1);
    
    % Binarize the single trial label
    is_walking = ismember(raw_label, cfg.DS.USCHAD.WALKING_LABELS);
    trial_label_binary = double(is_walking);

    % --- Sliding Window Feature Extraction ---
    for k = 1:cfg.STEP_SIZE:(n_samples - cfg.WINDOW_SIZE + 1)
        window_start = k;
        window_end = k + cfg.WINDOW_SIZE - 1;
        
        windowAcc = acc(window_start:window_end, :);
        windowGyro = gyro(window_start:window_end, :);

        % Extract Features (pass both Accel and Gyro)
        feature_vector = Features(windowAcc, windowGyro, cfg.FS);
        
        features = [features; feature_vector]; %#ok<AGROW>
        labels_binary = [labels_binary; trial_label_binary]; %#ok<AGROW>
    end
end

% --- 3. Prepare Metadata ---
ModelMetadata.fs = cfg.FS;
ModelMetadata.windowSize = cfg.WINDOW_SIZE;
ModelMetadata.stepSize = cfg.STEP_SIZE;
% Fix: Save the raw multi-class labels used for binarization (CRITICAL for evaluation scripts)
ModelMetadata.WALKING_LABELS_RAW = cfg.DS.USCHAD.WALKING_LABELS; 
ModelMetadata.NON_WALKING_LABELS_RAW = cfg.DS.USCHAD.NON_WALKING_LABELS;

fprintf('Feature extraction complete. Total %d windows generated.\n', size(features, 1));
end