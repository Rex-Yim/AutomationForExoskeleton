%% TrainSvmBinary.m
% --------------------------------------------------------------------------
% FUNCTION: [SVMModel, metrics] = TrainSvmBinary()
% PURPOSE: Trains a binary Support Vector Machine (SVM) classifier for
% Locomotion (1) vs. Static (0) using data from the USC-HAD dataset,
% and saves the model for the real-time pipeline.
% --------------------------------------------------------------------------
% DATE CREATED: 2025-12-13
% LAST MODIFIED: 2025-12-13 (Fixed subject-wise splitting logic)
% --------------------------------------------------------------------------
% DEPENDENCIES:
% - ExoConfig.m
% - LoadUSCHAD.m (or any data loading function that returns IMU data)
% - PrepareTrainingData.m
% - Features.m
% --------------------------------------------------------------------------
% NOTES:
% - Uses a 70/30 Subject-wise split for training/testing.
% - Classification is Locomotion (1) vs. Non-Locomotion (0).
% --------------------------------------------------------------------------
function [SVMModel, metrics] = TrainSvmBinary()
clc; clear; close all;
% --- 1. Configuration and Setup ---
cfg = ExoConfig();
% Training parameters
FS = cfg.FS;
WINDOW_SIZE = cfg.WINDOW_SIZE;
STEP_SIZE = cfg.STEP_SIZE;
C_SVM = 1;               % SVM Box Constraint
KERNEL_FUNCTION = 'linear'; % Or 'rbf' for a non-linear boundary
% File paths for data and model saving
model_save_path = cfg.FILE.SVM_MODEL;

fprintf('--- Starting Binary SVM Training Pipeline ---\n');
fprintf('Activity Window: %d samples (%.2f s), Step: %d samples\n', WINDOW_SIZE, WINDOW_SIZE/FS, STEP_SIZE);
fprintf('Kernel Function: %s, Box Constraint (C): %.1f\n', KERNEL_FUNCTION, C_SVM);

% --- 2. Data Acquisition and Splitting (LOGIC FIX APPLIED HERE) ---
try
    % FIX: Load the pre-processed .mat file, which should contain the 'usc' structure
    data_file = cfg.FILE.USCHAD_DATA;
    fprintf('Loading USC-HAD data from: %s...\n', data_file);

    if ~exist(data_file, 'file')
        error('Pre-processed data file not found. Please run LoadUSCHAD.m first to generate it.');
    end
    
    loaded = load(data_file, 'usc');
    all_trials_struct = loaded.usc;

catch ME
    error('Data loading failed. Error: %s', ME.message);
end

% Extract unique subject IDs for subject-wise splitting
all_field_names = fieldnames(all_trials_struct);
% Extract subject ID (e.g., 3 from 'subject3_activity...')
subject_ids_per_trial = cellfun(@(x) sscanf(x, 'subject%d_activity%*d_trial%*d', 1), all_field_names);
unique_subjects = unique(subject_ids_per_trial);

n_subjects = length(unique_subjects);
rng(1); % For reproducibility

% Perform subject-wise split
cv_split = cvpartition(n_subjects, 'Holdout', 0.3);
train_subject_indices = find(cv_split.training);
test_subject_indices = find(cv_split.test);

train_subjects = unique_subjects(train_subject_indices);
test_subjects = unique_subjects(test_subject_indices);

fprintf('Total subjects found: %d. Training subjects: %d, Testing subjects: %d.\n', ...
    n_subjects, length(train_subjects), length(test_subjects));

% Select the field names belonging to the training/testing subjects
train_trial_names = all_field_names(ismember(subject_ids_per_trial, train_subjects));
test_trial_names = all_field_names(ismember(subject_ids_per_trial, test_subjects));

% Reorganize the data into a cell array of trial structs for PrepareTrainingData
all_train_trials = cellfun(@(name) all_trials_struct.(name), train_trial_names, 'UniformOutput', false);
all_test_trials = cellfun(@(name) all_trials_struct.(name), test_trial_names, 'UniformOutput', false);

% --- 3. Feature Extraction and Label Preparation ---
fprintf('Extracting features from training data...\n');
% PrepareTrainingData now correctly receives a cell array of trial structs
[X_train, Y_train] = PrepareTrainingData(all_train_trials, cfg, FS, WINDOW_SIZE, STEP_SIZE);

fprintf('Training Data Matrix (X_train) size: %s\n', mat2str(size(X_train)));
fprintf('Training Label Vector (Y_train) size: %s\n', mat2str(size(Y_train)));

% Check for data balance (important for binary classification)
n_locomotion = sum(Y_train == cfg.STATE_WALKING);
n_static = sum(Y_train == cfg.STATE_STANDING);
fprintf('Training Samples: Locomotion (1): %d, Static (0): %d\n', n_locomotion, n_static);

% --- 4. Model Training (Support Vector Machine) ---
fprintf('Starting SVM training...\n');
% Train a binary classifier
t_start = tic;
SVMModel = fitcsvm(X_train, Y_train, ...
    'KernelFunction', KERNEL_FUNCTION, ...
    'BoxConstraint', C_SVM, ...
    'Standardize', true, ...
    'ClassNames', [cfg.STATE_STANDING, cfg.STATE_WALKING]); % Ensure classes are recognized as 0 and 1
t_elapsed = toc(t_start);
fprintf('SVM training completed in %.2f seconds.\n', t_elapsed);

% --- 5. Model Testing (Evaluation on Holdout Set) ---
fprintf('Extracting features from testing data...\n');
% PrepareTrainingData now correctly receives a cell array of trial structs
[X_test, Y_test] = PrepareTrainingData(all_test_trials, cfg, FS, WINDOW_SIZE, STEP_SIZE);

% Predict labels on the test set
Y_pred = predict(SVMModel, X_test);

% Calculate Performance Metrics
TP = sum(Y_test == cfg.STATE_WALKING & Y_pred == cfg.STATE_WALKING);
TN = sum(Y_test == cfg.STATE_STANDING & Y_pred == cfg.STATE_STANDING);
FP = sum(Y_test == cfg.STATE_STANDING & Y_pred == cfg.STATE_WALKING);
FN = sum(Y_test == cfg.STATE_WALKING & Y_pred == cfg.STATE_STANDING);

Accuracy = (TP + TN) / (TP + TN + FP + FN);
Precision = TP / (TP + FP);
Recall = TP / (TP + FN); % Sensitivity
Specificity = TN / (TN + FP);

metrics.TP = TP;
metrics.TN = TN;
metrics.FP = FP;
metrics.FN = FN;
metrics.Accuracy = Accuracy;
metrics.Precision = Precision;
metrics.Recall = Recall;
metrics.Specificity = Specificity;

fprintf('\n--- Test Set Performance Summary (Holdout Subjects) ---\n');
fprintf('Total Test Samples: %d\n', length(Y_test));
fprintf('------------------------------------------\n');
fprintf('True Positives (TP): %d\n', TP);
fprintf('True Negatives (TN): %d\n', TN);
fprintf('False Positives (FP): %d\n', FP);
fprintf('False Negatives (FN): %d\n', FN);
fprintf('------------------------------------------\n');
fprintf('Accuracy: %.2f%%\n', Accuracy * 100);
fprintf('Precision (Walk): %.2f%%\n', Precision * 100);
fprintf('Recall (Walk): %.2f%%\n', Recall * 100);
fprintf('Specificity (Stand): %.2f%%\n', Specificity * 100);
fprintf('------------------------------------------\n');

% --- 6. Save the Model and Metadata ---
% Metadata needed by the real-time pipeline scripts
ModelMetadata.fs = FS;
ModelMetadata.windowSize = WINDOW_SIZE;
ModelMetadata.stepSize = STEP_SIZE;
ModelMetadata.trainSubjects = train_subjects;
ModelMetadata.testSubjects = test_subjects;
save(model_save_path, 'SVMModel', 'ModelMetadata');

fprintf('\nTrained SVM Model and Metadata saved successfully to: %s\n', model_save_path);
end