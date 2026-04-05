function RedrawLstmMulticlassConfusionFromMetrics(matPath)
%% RedrawLstmMulticlassConfusionFromMetrics — rebuild multiclass LSTM confusion PNG from saved metrics (no retrain).
%
% Requires lstm_multiclass_evaluation_metrics_<tag>.mat from EvaluateLstmMulticlassConfusion.
%
% Usage:
%   >> RedrawLstmMulticlassConfusionFromMetrics
%   >> RedrawLstmMulticlassConfusionFromMetrics('/path/to/lstm_multiclass_evaluation_metrics_hugadb_streaming.mat')

    here = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(here);
    cd(projectRoot);
    addpath(here);
    addpath(fullfile(projectRoot, 'config'));
    addpath(genpath(fullfile(projectRoot, 'src')));

    if nargin < 1 || isempty(matPath)
        matPath = ResultsArtifactPath(projectRoot, 'metrics', 'multiclass', 'lstm_multiclass_evaluation_metrics_hugadb_streaming.mat');
    end
    if exist(matPath, 'file') ~= 2
        error('Metrics file not found: %s', matPath);
    end

    [~, baseName, ~] = fileparts(matPath);
    prefix = 'lstm_multiclass_evaluation_metrics_';
    if ~startsWith(baseName, prefix)
        error('Expected filename lstm_multiclass_evaluation_metrics_<tag>.mat, got: %s', baseName);
    end
    tag = char(extractAfter(baseName, prefix));

    req = {'YVal', 'Yhat', 'valAcc', 'ds'};
    S = load(matPath, req{:});
    for i = 1:numel(req)
        if ~isfield(S, req{i})
            error('MAT file missing field "%s": %s', req{i}, matPath);
        end
    end

    ds = char(string(S.ds));
    valAcc = double(S.valAcc);

    fig = figure('Name', sprintf('Multiclass LSTM confusion (%s)', ds), 'Color', 'w', ...
        'ToolBar', 'none', 'Position', [80, 80, 900, 720]);
    h = confusionchart(S.YVal, S.Yhat);
    h.Title = sprintf('Multiclass LSTM (%s) | 20%% holdout | Acc = %.2f%%', ds, valAcc * 100);
    h.XLabel = 'Predicted';
    h.YLabel = 'True';
    styleConfusionChartBlack(h);
    styleReportFigureColors(fig);

    pngPath = ResultsArtifactPath(projectRoot, 'figures', 'multiclass', ['lstm_multiclass_confusion_matrix_' tag '.png']);
    if exist('exportgraphics', 'file') == 2
        exportgraphics(fig, pngPath, 'Resolution', 200, 'Padding', 'loose');
    else
        saveas(fig, pngPath);
    end
    close(fig);
    fprintf('Redrawn: %s\n(from %s)\n', pngPath, matPath);
end
