function EvaluateLstmConfusion(varargin)
%% EvaluateLstmConfusion — holdout confusion + metrics for trained binary LSTM
%
% Loads models/Binary_LSTM_Network.mat (see TrainLstmBinary) and reproduces the
% same stratified 20% holdout split as training (rng(42) + cvpartition).
%
% Optional name-value (defaults match the active HuGaDB deployment policy):
%   'IncludeUSCHAD'   (logical, default cfg.TRAINING.DEFAULT_INCLUDE_USCHAD)
%   'IncludeHuGaDB'   (logical, default cfg.TRAINING.DEFAULT_INCLUDE_HUGADB)
%   'IncludeHuGaDBSubjects' (default {})
%   'ExcludeHuGaDBSubjects' (default cfg.HUGADB.HELDOUT_SUBJECTS)
%   'ModelPath'       (char/string, default cfg.FILE.BINARY_LSTM)
%   'OutputTag'       (char/string, default auto) — saves
%                     lstm_confusion_matrix_<tag>.png and lstm_evaluation_metrics_<tag>.mat
%
% Usage:
%   >> EvaluateLstmConfusion
%   >> EvaluateLstmConfusion('IncludeHuGaDB', false, 'OutputTag', 'usc_had')
%
% Requires Deep Learning Toolbox and a trained file at cfg.FILE.BINARY_LSTM.

    here = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(here);
    addpath(fullfile(projectRoot, 'config'));
    addpath(genpath(fullfile(projectRoot, 'src')));

    cfg = ExoConfig();
    classNames = ActivityClassRegistry.binaryClassNames();
    inactiveLabel = classNames{1};
    activeLabel = classNames{2};
    p = inputParser;
    addParameter(p, 'IncludeUSCHAD', cfg.TRAINING.DEFAULT_INCLUDE_USCHAD, @islogical);
    addParameter(p, 'IncludeHuGaDB', cfg.TRAINING.DEFAULT_INCLUDE_HUGADB, @islogical);
    addParameter(p, 'IncludeHuGaDBSubjects', {}, @(x) isempty(x) || isnumeric(x) || ischar(x) || isstring(x) || iscell(x));
    addParameter(p, 'ExcludeHuGaDBSubjects', cfg.HUGADB.HELDOUT_SUBJECTS, @(x) isempty(x) || isnumeric(x) || ischar(x) || isstring(x) || iscell(x));
    addParameter(p, 'ModelPath', cfg.FILE.BINARY_LSTM, @(s) ischar(s) || isstring(s));
    addParameter(p, 'OutputTag', '', @(s) ischar(s) || isstring(s));
    parse(p, varargin{:});

    inclU = p.Results.IncludeUSCHAD;
    inclH = p.Results.IncludeHuGaDB;
    includeHuSubjects = NormalizeHuGaDBSubjectIds(p.Results.IncludeHuGaDBSubjects);
    excludeHuSubjects = NormalizeHuGaDBSubjectIds(p.Results.ExcludeHuGaDBSubjects);
    modelPath = resolvePath(projectRoot, p.Results.ModelPath, cfg.FILE.BINARY_LSTM);
    outTag = char(strtrim(string(p.Results.OutputTag)));

    hasDL = license('test', 'Deep_Learning_Toolbox') || license('test', 'Neural_Network_Toolbox');
    if ~hasDL
        error('Deep Learning Toolbox required to classify with the LSTM network.');
    end

    if ~exist(modelPath, 'file')
        error('Trained LSTM not found: %s\nRun TrainLstmBinary.m first.', modelPath);
    end

    fprintf('===========================================================\n');
    fprintf('   LSTM evaluation: holdout confusion (matches TrainLstmBinary split)\n');
    fprintf('===========================================================\n');
    fprintf('IncludeUSCHAD=%d  IncludeHuGaDB=%d\n', inclU, inclH);
    if ~isempty(includeHuSubjects)
        fprintf('IncludeHuGaDBSubjects=%s\n', strjoin(includeHuSubjects, ', '));
    end
    if ~isempty(excludeHuSubjects)
        fprintf('ExcludeHuGaDBSubjects=%s\n', strjoin(excludeHuSubjects, ', '));
    end

    L = load(modelPath, 'net', 'ModelMetadata');
    net = L.net;

    try
        [XCell, labelsAll, ModelMetadata] = PrepareTrainingDataSequences(cfg, ...
            'IncludeUSCHAD', inclU, ...
            'IncludeHuGaDB', inclH, ...
            'IncludeHuGaDBSubjects', includeHuSubjects, ...
            'ExcludeHuGaDBSubjects', excludeHuSubjects);
    catch ME
        error('Sequence preparation failed: %s', ME.message);
    end

    n = numel(XCell);
    fprintf('Total windows: %d\n', n);
    fprintf('  %s: %d  |  %s: %d\n', inactiveLabel, sum(labelsAll == 0), activeLabel, sum(labelsAll == 1));

    if numel(unique(labelsAll)) < 2
        error('Need both classes in the dataset for a binary confusion matrix.');
    end

    Ycat = categorical(labelsAll, [0 1], classNames);
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

    cm = confusionmat(YVal, Yhat, 'Order', classNames);
    TN = cm(1, 1);
    FP = cm(1, 2);
    FN = cm(2, 1);
    TP = cm(2, 2);

    precWalk = TP / max(TP + FP, eps);
    recWalk = TP / max(TP + FN, eps);
    f1Walk = 2 * precWalk * recWalk / max(precWalk + recWalk, eps);
    specStand = TN / max(TN + FP, eps);

    fprintf('\n----------- Binary metrics (%s = positive class) -----------\n', activeLabel);
    fprintf('Precision (%s):  %.4f\n', activeLabel, precWalk);
    fprintf('Recall (%s):     %.4f\n', activeLabel, recWalk);
    fprintf('F1 (%s):         %.4f\n', activeLabel, f1Walk);
    fprintf('Specificity (%s): %.4f\n', inactiveLabel, specStand);
    fprintf('-------------------------------------------------------------\n');

    poolLabel = datasetPoolLabel(inclU, inclH, includeHuSubjects, excludeHuSubjects);

    if strlength(outTag) == 0
        outTag = defaultOutputTag(inclU, inclH, includeHuSubjects, excludeHuSubjects, cfg);
    end
    pngPath = ResultsArtifactPath(projectRoot, 'figures', 'binary', ['lstm_confusion_matrix_' outTag '.png']);
    matPath = ResultsArtifactPath(projectRoot, 'metrics', 'binary', ['lstm_evaluation_metrics_' outTag '.mat']);

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

function outPath = resolvePath(projectRoot, pathArg, defaultPath)
    raw = strtrim(char(string(pathArg)));
    if isempty(raw)
        raw = defaultPath;
    end
    if startsWith(raw, filesep) || (~isempty(regexp(raw, '^[A-Za-z]:', 'once')))
        outPath = raw;
    else
        outPath = fullfile(projectRoot, raw);
    end
end

function s = datasetPoolLabel(inclU, inclH, includeHuSubjects, excludeHuSubjects)
    if inclU && inclH
        error('Combined USC-HAD + HuGaDB LSTM evaluation has been removed.');
    elseif inclU
        s = 'USC-HAD';
    else
        s = 'HuGaDB';
    end

    if ~isempty(includeHuSubjects)
        s = sprintf('%s (subjects %s)', s, strjoin(includeHuSubjects, ', '));
    elseif ~isempty(excludeHuSubjects) && ~inclU && inclH
        s = sprintf('%s (excluding subjects %s)', s, strjoin(excludeHuSubjects, ', '));
    end
end

function tag = defaultOutputTag(inclU, inclH, includeHuSubjects, excludeHuSubjects, cfg)
    if inclU && ~inclH
        tag = 'usc_had';
        return;
    end

    if ~inclU && inclH
        if isempty(includeHuSubjects) && isempty(excludeHuSubjects)
            tag = 'hugadb';
            return;
        end
    end

    tag = sanitizeTag(datasetPoolLabel(inclU, inclH, includeHuSubjects, excludeHuSubjects));
end

function out = sanitizeTag(label)
    out = regexprep(lower(char(label)), '[^a-z0-9]+', '_');
    out = regexprep(out, '^_+|_+$', '');
end
