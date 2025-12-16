%% PrepareTrainingData.m
% --------------------------------------------------------------------------
% FUNCTION: [features, labels_binary, ModelMetadata] = PrepareTrainingData(cfg)
% PURPOSE: Iterates through the USC-HAD dataset, extracts features using
%          the standardized pipeline logic, and binarizes labels.
% --------------------------------------------------------------------------
% LOCATION: src/acquisition/PrepareTrainingData.m
% --------------------------------------------------------------------------
% DATE CREATED: 2025-12-13
% LAST MODIFIED: 2025-12-17
% --------------------------------------------------------------------------

function [features, labels_binary, ModelMetadata] = PrepareTrainingData(cfg)

    if nargin < 1
        cfg = ExoConfig();
    end

    % --- 1. Load USC-HAD Data Structure ---
    % Checks if the dataset exists. If not, prompts user to run LoadUSCHAD.
    if ~exist(cfg.FILE.USCHAD_DATA, 'file')
        error('USC-HAD dataset not found at: %s. \nPlease run "LoadUSCHAD" first.', cfg.FILE.USCHAD_DATA);
    end
    
    loadedData = load(cfg.FILE.USCHAD_DATA, 'usc');
    usc = loadedData.usc;

    features = [];
    labels_binary = [];
    all_trial_names = fieldnames(usc);

    fprintf('Preparing Training Data: Extracting features from %d trials...\n', length(all_trial_names));

    % --- 2. Iterate through all trials ---
    for i = 1:length(all_trial_names)
        trial_name = all_trial_names{i};
        trial = usc.(trial_name);
        
        % Data Access
        acc = trial.acc;
        gyro = trial.gyro;
        raw_label = trial.label;
        n_samples = size(acc, 1);
        
        % Skip trials shorter than one window
        if n_samples < cfg.WINDOW_SIZE
            continue; 
        end
        
        % --- Label Binarization ---
        % Convert specific USC-HAD Activity ID to Binary (1=Walk, 0=Stand)
        is_walking = ismember(raw_label, cfg.DS.USCHAD.WALKING_LABELS);
        trial_label_binary = double(is_walking);

        % --- Sliding Window Feature Extraction ---
        for k = 1:cfg.STEP_SIZE:(n_samples - cfg.WINDOW_SIZE + 1)
            window_start = k;
            window_end = k + cfg.WINDOW_SIZE - 1;
            
            windowAcc = acc(window_start:window_end, :);
            windowGyro = gyro(window_start:window_end, :);

            % Extract Features (Using updated 5-feature logic)
            feature_vector = Features(windowAcc, windowGyro, cfg.FS);
            
            features = [features; feature_vector]; %#ok<AGROW>
            labels_binary = [labels_binary; trial_label_binary]; %#ok<AGROW>
        end
    end

    % --- 3. Prepare Metadata ---
    % This ensures the Real-time pipeline knows how to match the model
    ModelMetadata.fs = cfg.FS;
    ModelMetadata.windowSize = cfg.WINDOW_SIZE;
    ModelMetadata.stepSize = cfg.STEP_SIZE;
    ModelMetadata.featureCount = size(features, 2);
    ModelMetadata.dateTrained = char(datetime('now'));

    fprintf('Feature extraction complete. Generated %d windows with %d features each.\n', ...
        size(features, 1), size(features, 2));
end