function RedrawMulticlassConfusionFromMetrics(matPath)
%% RedrawMulticlassConfusionFromMetrics — rebuild multiclass ECOC confusion PNG from saved OOF metrics (no retrain).
%
% Requires multiclass_evaluation_metrics_<tag>.mat from a prior EvaluateMulticlassConfusion run.
%
% Usage:
%   >> RedrawMulticlassConfusionFromMetrics
%   >> RedrawMulticlassConfusionFromMetrics('/path/to/multiclass_evaluation_metrics_hugadb_streaming.mat')

    here = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(here);
    cd(projectRoot);
    addpath(here);
    addpath(fullfile(projectRoot, 'config'));
    addpath(genpath(fullfile(projectRoot, 'src')));

    if nargin < 1 || isempty(matPath)
        matPath = ResultsArtifactPath(projectRoot, 'metrics', 'multiclass', 'multiclass_evaluation_metrics_hugadb_streaming.mat');
    end
    if exist(matPath, 'file') ~= 2
        error('Metrics file not found: %s', matPath);
    end

    [~, baseName, ~] = fileparts(matPath);
    prefix = 'multiclass_evaluation_metrics_';
    if ~startsWith(baseName, prefix)
        error('Expected filename multiclass_evaluation_metrics_<tag>.mat, got: %s', baseName);
    end
    tag = char(extractAfter(baseName, prefix));

    S = load(matPath);
    req = {'labelsAll', 'yHatNum', 'K', 'oofAcc', 'ds'};
    for i = 1:numel(req)
        if ~isfield(S, req{i})
            error('MAT file missing field "%s": %s', req{i}, matPath);
        end
    end

    ds = lower(char(string(S.ds)));
    if strcmp(ds, 'usc_had')
        names = ActivityClassRegistry.USCHAD_CLASS_NAMES;
    else
        names = ActivityClassRegistry.HUGADB_CLASS_NAMES;
    end
    K = S.K;
    labelsAll = S.labelsAll(:);
    yHatNum = double(S.yHatNum(:));
    oofAcc = double(S.oofAcc);

    usedSubsamp = false;
    if isfield(S, 'usedSubsamp')
        usedSubsamp = logical(S.usedSubsamp);
    end
    kFolds = 5;
    if isfield(S, 'ModelMetadata') && isstruct(S.ModelMetadata) && isfield(S.ModelMetadata, 'kFolds')
        kFolds = double(S.ModelMetadata.kFolds);
    end

    sub = '';
    if usedSubsamp
        sub = ' (stratified subsample CV)';
    end

    fig = figure('Name', sprintf('Multiclass confusion (%s)', ds), 'Color', 'w', ...
        'ToolBar', 'none', 'Position', [80, 80, 900, 720]);
    catTrue = categorical(labelsAll, 1:K, names, 'Ordinal', true);
    catPred = categorical(yHatNum, 1:K, names, 'Ordinal', true);
    h = confusionchart(catTrue, catPred);
    h.Title = sprintf('%s | %d-fold OOF%s | Acc = %.2f%%', ds, kFolds, sub, oofAcc);
    h.XLabel = 'Predicted';
    h.YLabel = 'True';
    styleConfusionChartBlack(h);
    styleReportFigureColors(fig);

    pngPath = ResultsArtifactPath(projectRoot, 'figures', 'multiclass', ['multiclass_confusion_matrix_' tag '.png']);
    if exist('exportgraphics', 'file') == 2
        exportgraphics(fig, pngPath, 'Resolution', 200, 'Padding', 'loose');
    else
        saveas(fig, pngPath);
    end
    close(fig);
    fprintf('Redrawn: %s\n(from %s)\n', pngPath, matPath);
end
