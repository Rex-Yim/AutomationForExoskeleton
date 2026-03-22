%% TrainSvmMulticlass.m — ECOC RBF-SVM, unified 12-class activity recognition
clc; clear; close all;

cfg = ExoConfig();

fprintf('===========================================================\n');
fprintf('   Multiclass SVM (ECOC) — %d activities\n', ActivityClassRegistry.N_CLASSES);
fprintf('===========================================================\n');

try
    [featuresAll, labelsAll, ModelMetadata] = PrepareTrainingDataMulticlass(cfg);
catch ME
    error('Multiclass data preparation failed: %s', ME.message);
end

K = ActivityClassRegistry.N_CLASSES;
fprintf('Windows: %d | features: %d | classes present: %s\n', ...
    size(featuresAll, 1), size(featuresAll, 2), mat2str(unique(labelsAll)'));

for c = 1:K
    fprintf('  Class %2d %-14s : %d windows\n', c, ActivityClassRegistry.CLASS_NAMES{c}, sum(labelsAll == c));
end

fprintf('\nTraining ECOC (one-vs-all, RBF learners)...\n');
t = templateSVM('KernelFunction', 'rbf', 'Standardize', true, 'BoxConstraint', 1);
ECOCModel = fitcecoc(featuresAll, labelsAll, 'Learners', t, 'Coding', 'onevsall');
fprintf('ECOC fit on full window set (no CV here — use EvaluateMulticlassConfusion).\n');

scriptDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptDir);
savePath = fullfile(projectRoot, cfg.FILE.MULTICLASS_SVM);

[saveDir, ~] = fileparts(savePath);
if ~exist(saveDir, 'dir')
    mkdir(saveDir);
end

save(savePath, 'ECOCModel', 'ModelMetadata', '-v7.3');
fprintf('Saved: %s\n', savePath);
fprintf('===========================================================\n');
