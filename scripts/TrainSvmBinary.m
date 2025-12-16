%% TrainSvmBinary.m
% --------------------------------------------------------------------------
% SCRIPT: TrainSvmBinary
% PURPOSE: Trains the binary SVM (Walking vs. Standing) and saves the model.
% --------------------------------------------------------------------------
% LOCATION: scripts/TrainSvmBinary.m
% --------------------------------------------------------------------------
% DATE CREATED: 2025-12-13
% LAST MODIFIED: 2025-12-17
% --------------------------------------------------------------------------

clc; clear; close all;

% Initialize Configuration
cfg = ExoConfig();

fprintf('===========================================================\n');
fprintf('   Training SVM Binary Classifier (Walk vs. Stand)\n');
fprintf('===========================================================\n');

% --- 1. Prepare Data ---
try
    % This function now handles all loading, windowing, and feature extraction
    [featuresAll, labelsAll, ModelMetadata] = PrepareTrainingData(cfg);
catch ME
    error('Data preparation failed: %s', ME.message);
end

if isempty(featuresAll)
    error('No features extracted. Ensure "LoadUSCHAD" has been run and data is valid.');
end

% --- 2. Train SVM Model ---
fprintf('\nTraining SVM (RBF Kernel, Standardized)...\n');

% Fit binary SVM
% - Kernel: RBF (Gaussian) is typically best for non-linear IMU boundaries
% - Standardize: Critical because features (Acc vs Gyro) have different scales
SVMModel = fitcsvm(featuresAll, labelsAll, ...
    'KernelFunction', 'rbf', ...
    'Standardize', true, ...
    'BoxConstraint', 1.0, ...
    'ClassNames', [0, 1]);

% --- 3. Evaluate Performance (Cross-Validation) ---
fprintf('Performing 5-Fold Cross-Validation...\n');
cvModel = crossval(SVMModel, 'KFold', 5);
cvError = kfoldLoss(cvModel);
cvAccuracy = (1 - cvError) * 100;

fprintf('-----------------------------------------------------------\n');
fprintf('   Model Accuracy (5-Fold CV): %.2f%%\n', cvAccuracy);
fprintf('-----------------------------------------------------------\n');

% --- 4. Save Model ---
savePath = cfg.FILE.SVM_MODEL;

% Ensure results directory exists
[saveDir, ~] = fileparts(savePath);
if ~exist(saveDir, 'dir')
    mkdir(saveDir);
end

% Save both the Model object and the Metadata
save(savePath, 'SVMModel', 'ModelMetadata');
fprintf('Model saved successfully to:\n  -> %s\n', savePath);
fprintf('===========================================================\n');