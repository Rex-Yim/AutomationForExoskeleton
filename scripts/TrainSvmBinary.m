% Train the binary active-vs-inactive SVM and save the default deployment model.
% Training uses the configured dataset mix while excluding held-out HuGaDB
% simulation subjects from the deployment artifact.

clc; clear; close all;

% Initialize Configuration
cfg = ExoConfig();

fprintf('===========================================================\n');
fprintf('   Training SVM Binary Classifier (Active vs. Inactive)\n');
fprintf('===========================================================\n');

% --- 1. Prepare Data ---
try
    [featuresAll, labelsAll, ModelMetadata] = PrepareTrainingData(cfg, ...
        'IncludeUSCHAD', cfg.TRAINING.DEFAULT_INCLUDE_USCHAD, ...
        'IncludeHuGaDB', cfg.TRAINING.DEFAULT_INCLUDE_HUGADB, ...
        'HuGaDBSessionProtocols', cfg.HUGADB.DEFAULT_PROTOCOLS);
catch ME
    error('Data preparation failed: %s', ME.message);
end

if isempty(featuresAll)
    error('No features extracted. Run LoadUSCHAD (and optionally LoadHuGaDB), then retry.');
end

if isfield(ModelMetadata, 'nWindowsUSCHAD')
    fprintf('Window counts — USC-HAD: %d | HuGaDB: %d\n', ...
        ModelMetadata.nWindowsUSCHAD, ModelMetadata.nWindowsHuGaDB);
end
if isfield(ModelMetadata, 'excludeHuGaDBSubjects')
    fprintf('Held-out HuGaDB subjects excluded from training: %s\n', ...
        strjoin(ModelMetadata.excludeHuGaDBSubjects, ', '));
end
if isfield(ModelMetadata, 'huGaDBProtocolSelection') && ~isempty(ModelMetadata.huGaDBProtocolSelection)
    fprintf('HuGaDB session protocols used: %s\n', strjoin(ModelMetadata.huGaDBProtocolSelection, ', '));
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
fprintf('   Model Accuracy (5-Fold CV on active training pool): %.2f%%\n', cvAccuracy);
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
