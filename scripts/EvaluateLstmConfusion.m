function EvaluateLstmConfusion(varargin)
%% EvaluateLstmConfusion — holdout confusion + metrics for trained binary LSTM
%
% Loads models/Binary_LSTM_Network.mat (see TrainLstmBinary) and reproduces the
% same stratified 20% holdout split as training (rng(42) + cvpartition).
%
% Optional name-value (defaults match merged training):
%   'IncludeUSCHAD'   (logical, default true)
%   'IncludeHuGaDB'   (logical, default true)
%   'OutputTag'       (char/string, default '') — if nonempty, saves
%                     lstm_confusion_matrix_<tag>.png and lstm_evaluation_metrics_<tag>.mat
%
% Usage:
%   >> EvaluateLstmConfusion
%   >> EvaluateLstmConfusion('IncludeHuGaDB', false, 'OutputTag', 'usc_had_only')
%
% Requires Deep Learning Toolbox and a trained file at cfg.FILE.BINARY_LSTM.

    here = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(here);
    addpath(fullfile(projectRoot, 'config'));
    addpath(genpath(fullfile(projectRoot, 'src')));

    p = inputParser;
    addParameter(p, 'IncludeUSCHAD', true, @islogical);
    addParameter(p, 'IncludeHuGaDB', true, @islogical);
    addParameter(p, 'OutputTag', '', @(s) ischar(s) || isstring(s));
    parse(p, varargin{:});

    inclU = p.Results.IncludeUSCHAD;
    inclH = p.Results.IncludeHuGaDB;
    outTag = char(strtrim(string(p.Results.OutputTag)));

    hasDL = license('test', 'Deep_Learning_Toolbox') || license('test', 'Neural_Network_Toolbox');
    if ~hasDL
        error('Deep Learning Toolbox required to classify with the LSTM network.');
    end

    cfg = ExoConfig();
    modelPath = fullfile(projectRoot, cfg.FILE.BINARY_LSTM);
    if ~exist(modelPath, 'file')
        error('Trained LSTM not found: %s\nRun TrainLstmBinary.m first.', modelPath);
    end

    fprintf('===========================================================\n');
    fprintf('   LSTM evaluation: holdout confusion (matches TrainLstmBinary split)\n');
    fprintf('===========================================================\n');
    fprintf('IncludeUSCHAD=%d  IncludeHuGaDB=%d\n', inclU, inclH);

    L = load(modelPath, 'net', 'ModelMetadata');
    net = L.net;

    try
        [XCell, labelsAll, ModelMetadata] = PrepareTrainingDataSequences(cfg, ...
            'IncludeUSCHAD', inclU, 'IncludeHuGaDB', inclH);
    catch ME
        error('Sequence preparation failed: %s', ME.message);
    end

    n = numel(XCell);
    fprintf('Total windows: %d\n', n);
    fprintf('  Stand: %d  |  Walk: %d\n', sum(labelsAll == 0), sum(labelsAll == 1));

    if numel(unique(labelsAll)) < 2
        error('Need both classes in the dataset for a binary confusion matrix.');
    end

    Ycat = categorical(labelsAll, [0 1], {'Stand', 'Walk'});
    seed = 42;
    if isfield(L.ModelMetadata, 'holdoutRNGSeed')
        seed = L.ModelMetadata.holdoutRNGSeed;
    end
    rng(seed);
    cvp = cvpartition(Ycat, 'HoldOut', 0.2);
    te = test(cvp);

    XVal = XCell(te);
    YVal = Ycat(te);

    Yhat = classify(net, XVal);
    valAcc = mean(Yhat == YVal);
    fprintf('\nHoldout accuracy (same split as training): %.4f (%.2f%%)\n', valAcc, valAcc * 100);

    cm = confusionmat(YVal, Yhat, 'Order', {'Stand', 'Walk'});
    TN = cm(1, 1);
    FP = cm(1, 2);
    FN = cm(2, 1);
    TP = cm(2, 2);

    precWalk = TP / max(TP + FP, eps);
    recWalk = TP / max(TP + FN, eps);
    f1Walk = 2 * precWalk * recWalk / max(precWalk + recWalk, eps);
    specStand = TN / max(TN + FP, eps);

    fprintf('\n----------- Binary metrics (Walk = positive class) -----------\n');
    fprintf('Precision (Walk):  %.4f\n', precWalk);
    fprintf('Recall (Walk):     %.4f\n', recWalk);
    fprintf('F1 (Walk):         %.4f\n', f1Walk);
    fprintf('Specificity (Stand): %.4f\n', specStand);
    fprintf('-------------------------------------------------------------\n');

    poolLabel = datasetPoolLabel(inclU, inclH);

    resultsDir = fullfile(projectRoot, 'results');
    if ~exist(resultsDir, 'dir')
        mkdir(resultsDir);
    end

    if strlength(outTag) > 0
        pngPath = fullfile(resultsDir, ['lstm_confusion_matrix_' outTag '.png']);
        matPath = fullfile(resultsDir, ['lstm_evaluation_metrics_' outTag '.mat']);
    else
        pngPath = fullfile(resultsDir, 'lstm_confusion_matrix.png');
        matPath = fullfile(resultsDir, 'lstm_evaluation_metrics.mat');
    end

    lstmH = [];
    if isfield(L.ModelMetadata, 'lstmHidden1')
        lstmH = L.ModelMetadata.lstmHidden1;
    end
    exportLstmConfusionMatrixPng(pngPath, YVal, Yhat, poolLabel, valAcc, precWalk, recWalk, f1Walk, ...
        specStand, ModelMetadata, seed, TN, FP, FN, TP, n, lstmH, {});
    fprintf('\nFigure saved: %s\n', pngPath);

    save(matPath, 'cm', 'TP', 'TN', 'FP', 'FN', 'valAcc', 'precWalk', 'recWalk', 'f1Walk', ...
        'specStand', 'Yhat', 'YVal', 'labelsAll', 'ModelMetadata', 'poolLabel', 'seed', '-v7.3');
    fprintf('Metrics saved: %s\n', matPath);

    fprintf('===========================================================\n');
end

function s = datasetPoolLabel(inclU, inclH)
    if inclU && inclH
        s = 'USC-HAD + HuGaDB';
    elseif inclU
        s = 'USC-HAD only';
    else
        s = 'HuGaDB only';
    end
end
