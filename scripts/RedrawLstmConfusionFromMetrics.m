function RedrawLstmConfusionFromMetrics(matPath)
%% RedrawLstmConfusionFromMetrics — rebuild lstm_confusion_matrix.png from saved metrics only.
%
% Requires results/lstm_evaluation_metrics.mat from EvaluateLstmConfusion (full run), which
% stores YVal, Yhat, TN, FP, FN, TP, etc. A file that only contains valAcc cannot redraw the chart.
%
% Usage:
%   >> RedrawLstmConfusionFromMetrics
%   >> RedrawLstmConfusionFromMetrics('/path/to/lstm_evaluation_metrics.mat')

    here = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(here);
    cd(projectRoot);
    addpath(here);
    addpath(fullfile(projectRoot, 'config'));

    if nargin < 1 || isempty(matPath)
        matPath = fullfile(projectRoot, 'results', 'lstm_evaluation_metrics.mat');
    end
    if exist(matPath, 'file') ~= 2
        error('Metrics file not found: %s\nRun EvaluateLstmConfusion after TrainLstmBinary.', matPath);
    end

    req = {'YVal', 'Yhat', 'poolLabel', 'valAcc', 'TN', 'FP', 'FN', 'TP', 'ModelMetadata', 'seed', ...
        'precWalk', 'recWalk', 'f1Walk', 'specStand', 'labelsAll'};
    S = load(matPath, req{:});
    for i = 1:numel(req)
        if ~isfield(S, req{i})
            error('lstm_evaluation_metrics.mat is missing field "%s". Run EvaluateLstmConfusion (needs trained net).', req{i});
        end
    end

    nTotal = numel(S.labelsAll);
    lstmH = [];
    if isfield(S.ModelMetadata, 'lstmHidden1')
        lstmH = S.ModelMetadata.lstmHidden1;
    end

    pngPath = fullfile(projectRoot, 'results', 'lstm_confusion_matrix.png');
    exportLstmConfusionMatrixPng(pngPath, S.YVal, S.Yhat, S.poolLabel, S.valAcc, ...
        S.precWalk, S.recWalk, S.f1Walk, S.specStand, S.ModelMetadata, S.seed, ...
        S.TN, S.FP, S.FN, S.TP, nTotal, lstmH);

    fprintf('Redrawn: %s\n(from %s)\n', pngPath, matPath);
end
