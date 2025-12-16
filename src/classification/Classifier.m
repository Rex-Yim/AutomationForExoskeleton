%% Classifier.m
% --------------------------------------------------------------------------
% FUNCTION: [performance] = Classifier(test_trial_name)
% PURPOSE: Loads a specific trial from the saved USC-HAD dataset and 
%          evaluates the SVM model against it.
% --------------------------------------------------------------------------
% LOCATION: src/classification/Classifier.m
% --------------------------------------------------------------------------
% DATE CREATED: 2025-12-13
% LAST MODIFIED: 2025-12-17
% --------------------------------------------------------------------------

function [performance] = Classifier(test_trial_name)

    clc;
    cfg = ExoConfig();
    
    % --- 1. Load Trained Model ---
    % Resolve absolute path to model
    rootPath = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    model_path = fullfile(rootPath, cfg.FILE.SVM_MODEL);
    
    if ~exist(model_path, 'file')
        error('Trained SVM Model not found at: %s', model_path);
    end
    
    loaded = load(model_path, 'SVMModel', 'ModelMetadata');
    SVMModel = loaded.SVMModel;
    ModelMetadata = loaded.ModelMetadata;
    
    FS = ModelMetadata.fs;
    WINDOW_SIZE = ModelMetadata.windowSize;
    STEP_SIZE = ModelMetadata.stepSize;
    
    fprintf('--- Classifier Evaluation ---\n');
    fprintf('Trial: %s | Model FS: %d Hz\n', test_trial_name, FS);
    
    % --- 2. Load Data (Fix: Load directly from .mat) ---
    dataFile = fullfile(rootPath, cfg.FILE.USCHAD_DATA);
    
    if ~exist(dataFile, 'file')
        error('Dataset not found: %s', dataFile);
    end
    
    dataStruct = load(dataFile, 'usc');
    if ~isfield(dataStruct.usc, test_trial_name)
        error('Trial "%s" does not exist in the loaded dataset.', test_trial_name);
    end
    
    trialData = dataStruct.usc.(test_trial_name);
    
    % Prepare Sensor Data
    back.acc = trialData.acc;
    back.gyro = trialData.gyro;
    raw_activity_id = trialData.label;
    
    % --- 3. Determine Ground Truth ---
    % Map the USC Label (1-12) to Binary (0=Stand, 1=Walk)
    if ismember(raw_activity_id, cfg.DS.USCHAD.WALKING_LABELS)
        gt_binary = cfg.STATE_WALKING;
    else
        gt_binary = cfg.STATE_STANDING;
    end
    
    n_total_samples = size(back.acc, 1);
    
    % --- 4. Sliding Window Classification ---
    features_list = [];
    predictions = [];
    
    % Iterate
    for k = 1:STEP_SIZE:(n_total_samples - WINDOW_SIZE + 1)
        w_start = k;
        w_end = k + WINDOW_SIZE - 1;
        
        wAcc = back.acc(w_start:w_end, :);
        wGyro = back.gyro(w_start:w_end, :);
        
        f_vec = Features(wAcc, wGyro, FS);
        features_list = [features_list; f_vec]; %#ok<AGROW>
    end
    
    if isempty(features_list)
        error('Data too short for window size %d', WINDOW_SIZE);
    end
    
    % Batch Predict
    predictions = predict(SVMModel, features_list);
    
    % --- 5. Metrics Calculation ---
    % Create Ground Truth vector matching the number of windows
    num_windows = length(predictions);
    gt_vector = repmat(gt_binary, num_windows, 1);
    
    TP = sum(gt_vector == 1 & predictions == 1);
    TN = sum(gt_vector == 0 & predictions == 0);
    FP = sum(gt_vector == 0 & predictions == 1);
    FN = sum(gt_vector == 1 & predictions == 0);
    
    Accuracy = (TP + TN) / num_windows;
    Precision = TP / (TP + FP);
    Recall = TP / (TP + FN);
    Specificity = TN / (TN + FP);
    
    % Handle potential NaNs (divide by zero)
    if isnan(Precision), Precision = 0; end
    if isnan(Recall), Recall = 0; end
    if isnan(Specificity), Specificity = 0; end
    
    performance.Accuracy = Accuracy;
    performance.Precision = Precision;
    performance.Recall = Recall;
    performance.TP = TP;
    performance.TN = TN;
    
    fprintf('Result: Acc=%.2f%% | Prec=%.2f%% | Rec=%.2f%%\n', ...
        Accuracy*100, Precision*100, Recall*100);

end