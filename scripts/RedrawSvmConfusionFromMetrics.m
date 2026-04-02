function RedrawSvmConfusionFromMetrics(matPath)
%% RedrawSvmConfusionFromMetrics — rebuild svm_confusion_matrix.png from saved metrics only.
%
% Use this when you only need a fixed layout/clipping for the report PNG and do not want to
% re-run cross-validation or need the raw datasets. Requires results/svm_evaluation_metrics.mat
% from a previous EvaluateSvmConfusion (or merged copy from RunSvmDatasetAblation).
%
% Usage:
%   >> RedrawSvmConfusionFromMetrics
%   >> RedrawSvmConfusionFromMetrics('/path/to/svm_evaluation_metrics.mat')

    here = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(here);
    cd(projectRoot);
    addpath(here);
    addpath(fullfile(projectRoot, 'config'));

    if nargin < 1 || isempty(matPath)
        matPath = fullfile(projectRoot, 'results', 'svm_evaluation_metrics.mat');
    end
    if exist(matPath, 'file') ~= 2
        error('Metrics file not found: %s\nRun EvaluateSvmConfusion once (with data), or pass path to svm_evaluation_metrics*.mat', matPath);
    end

    S = load(matPath, 'labelsAll', 'yHat', 'poolLabel', 'K', 'oofAccuracy', 'TN', 'FP', 'FN', 'TP', ...
        'ModelMetadata', 'precWalk', 'recWalk', 'f1Walk', 'specStand');

    pngPath = fullfile(projectRoot, 'results', 'svm_confusion_matrix.png');
    exportSvmConfusionMatrixPng(pngPath, S.labelsAll, S.yHat, S.poolLabel, S.K, S.oofAccuracy, ...
        S.TN, S.FP, S.FN, S.TP, S.ModelMetadata, S.precWalk, S.recWalk, S.f1Walk, S.specStand);

    fprintf('Redrawn: %s\n(from %s)\n', pngPath, matPath);
end
