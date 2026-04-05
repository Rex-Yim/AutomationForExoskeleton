function RedrawSvmConfusionFromMetrics(matPath)
%% RedrawSvmConfusionFromMetrics — rebuild the HuGaDB SVM confusion PNG from saved metrics only.
%
% Use this when you only need a fixed layout/clipping for the report PNG and do not want to
% re-run cross-validation or need the raw datasets. Requires
% results/metrics/binary/svm_evaluation_metrics_hugadb_streaming.mat
% from a previous EvaluateSvmConfusion run or a tagged ablation output.
%
% Usage:
%   >> RedrawSvmConfusionFromMetrics
%   >> RedrawSvmConfusionFromMetrics('/path/to/svm_evaluation_metrics_hugadb_streaming.mat')

    here = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(here);
    cd(projectRoot);
    addpath(here);
    addpath(fullfile(projectRoot, 'config'));

    if nargin < 1 || isempty(matPath)
        matPath = ResultsArtifactPath(projectRoot, 'metrics', 'binary', 'svm_evaluation_metrics_hugadb_streaming.mat');
    end
    if exist(matPath, 'file') ~= 2
        error('Metrics file not found: %s\nRun EvaluateSvmConfusion once (with data), or pass path to svm_evaluation_metrics_*.mat', matPath);
    end

    [~, baseName, ~] = fileparts(matPath);
    prefix = 'svm_evaluation_metrics_';
    if ~startsWith(baseName, prefix)
        error('Expected filename svm_evaluation_metrics_<tag>.mat, got: %s', baseName);
    end
    tag = extractAfter(baseName, prefix);

    S = load(matPath, 'labelsAll', 'yHat', 'poolLabel', 'K', 'oofAccuracy', 'TN', 'FP', 'FN', 'TP', ...
        'ModelMetadata', 'precWalk', 'recWalk', 'f1Walk', 'specStand');

    pngPath = ResultsArtifactPath(projectRoot, 'figures', 'binary', ['svm_confusion_matrix_' tag '.png']);
    exportSvmConfusionMatrixPng(pngPath, S.labelsAll, S.yHat, S.poolLabel, S.K, S.oofAccuracy, ...
        S.TN, S.FP, S.FN, S.TP, S.ModelMetadata, S.precWalk, S.recWalk, S.f1Walk, S.specStand);

    fprintf('Redrawn: %s\n(from %s)\n', pngPath, matPath);
end
