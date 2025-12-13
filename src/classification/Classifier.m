%% Classifier.m
% --------------------------------------------------------------------------
% FUNCTION: [performance] = EvaluateClassifier(test_trial_name)
% PURPOSE: Loads a trained SVM and tests its performance on a specific, 
% held-out single trial from the USC-HAD dataset.
% --------------------------------------------------------------------------
% DATE CREATED: 2025-12-13
% LAST MODIFIED: 2025-12-13 (Fixed label handling/binarization)
% --------------------------------------------------------------------------
% DEPENDENCIES: 
% - ExoConfig.m
% - ImportUschadSingleImu.m
% - Features.m
% --------------------------------------------------------------------------
% NOTES:
% - Calculates window-by-window classification accuracy.
% --------------------------------------------------------------------------

function [performance] = Classifier(test_trial_name)

clc;
cfg = ExoConfig();

% --- 0. Pre-Flight Check ---
model_path = cfg.FILE.SVM_MODEL;
if ~exist(model_path, 'file')
error('Trained SVM Model not found. Please run TrainSvmBinary first.');
end

% --- 1. Load Trained Model and Metadata ---
loaded = load(model_path, 'SVMModel', 'ModelMetadata');
SVMModel = loaded.SVMModel;
ModelMetadata = loaded.ModelMetadata;

FS = ModelMetadata.fs;
WINDOW_SIZE = ModelMetadata.windowSize;
STEP_SIZE = ModelMetadata.stepSize;

fprintf('--- Starting Classifier Evaluation ---\n');
fprintf('Testing on trial: %s (FS: %d Hz)\n', test_trial_name, FS);

% --- 2. Load Test Data and Determine Ground Truth ---
try
% Fix: Corrected function signature call (returns 3 IMU structs)
[back, ~, ~] = ImportUschadSingleImu(test_trial_name); 

% Load the USC structure to get the activity ID for the test trial
loaded_usc = load(cfg.FILE.USCHAD_DATA, 'usc');
raw_activity_id = loaded_usc.usc.(test_trial_name).label;

n_total_samples = size(back.acc, 1);

% Fix: Binarize the ground truth label based on the ModelMetadata
if ismember(raw_activity_id, ModelMetadata.WALKING_LABELS_RAW)
    ground_truth_binary = cfg.STATE_WALKING; % 1
else
    ground_truth_binary = cfg.STATE_STANDING; % 0
end

% Create a ground truth label for every *window*
n_windows = floor((n_total_samples - ModelMetadata.windowSize) / ModelMetadata.stepSize) + 1;
ground_truth_windows = repmat(ground_truth_binary, n_windows, 1);

catch ME
error('Data loading or ground truth determination failed: %s', ME.message);
end

% --- 3. Extract Features for Test Data ---
test_features = [];
window_labels = []; % Store the predicted label for each window

for k = 1:STEP_SIZE:(n_total_samples - WINDOW_SIZE + 1)
    window_start = k;
    window_end = k + WINDOW_SIZE - 1;

    windowAcc = back.acc(window_start:window_end, :);
    windowGyro = back.gyro(window_start:window_end, :); % Include Gyro

    feature_vector = Features(windowAcc, windowGyro, FS);
    test_features = [test_features; feature_vector]; %#ok<AGROW>
end

% --- 4. Classify All Windows ---
predicted_labels = predict(SVMModel, test_features);


% --- 5. Performance Evaluation (Window-by-Window) ---
TP = sum(ground_truth_windows == 1 & predicted_labels == 1);
TN = sum(ground_truth_windows == 0 & predicted_labels == 0);
FP = sum(ground_truth_windows == 0 & predicted_labels == 1);
FN = sum(ground_truth_windows == 1 & predicted_labels == 0);

Accuracy = (TP + TN) / (TP + TN + FP + FN);
Precision = TP / (TP + FP); 
Recall = TP / (TP + FN); 
Specificity = TN / (TN + FP);

performance.TP = TP;
performance.TN = TN;
performance.FP = FP;
performance.FN = FN;
performance.Accuracy = Accuracy;
performance.Precision = Precision;
performance.Recall = Recall;
performance.Specificity = Specificity;

% --- 6. Report Results ---
fprintf('\n--- Classification Performance Summary (Window-by-Window) ---\n');
fprintf('Target Label: %d (WALK=%d, STAND=%d)\n', ground_truth_binary, cfg.STATE_WALKING, cfg.STATE_STANDING);
fprintf('Total Windows: %d\n', n_windows);
fprintf('------------------------------------------\n');
fprintf('Accuracy: %.2f%%\n', Accuracy * 100);
fprintf('Precision: %.2f%%\n', Precision * 100);
fprintf('Recall: %.2f%%\n', Recall * 100);
fprintf('------------------------------------------\n');

end