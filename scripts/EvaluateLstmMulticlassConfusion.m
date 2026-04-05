function EvaluateLstmMulticlassConfusion(varargin)
%% EvaluateLstmMulticlassConfusion
% Holdout confusion + metrics for trained multiclass LSTM models.

    here = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(here);
    addpath(here);
    addpath(fullfile(projectRoot, 'config'));
    addpath(genpath(fullfile(projectRoot, 'src')));

    cfg = ExoConfig();
    p = inputParser;
    addParameter(p, 'Dataset', 'hugadb', @(s) ischar(s) || isstring(s));
    addParameter(p, 'HuGaDBSessionProtocols', cfg.HUGADB.DEFAULT_PROTOCOLS, @(x) isempty(x) || ischar(x) || isstring(x) || iscell(x));
    addParameter(p, 'ModelPath', '', @(s) ischar(s) || isstring(s));
    addParameter(p, 'OutputTag', '', @(s) ischar(s) || isstring(s));
    parse(p, varargin{:});

    ds = lower(char(p.Results.Dataset));
    protocolSelection = NormalizeHuGaDBProtocolSelection(p.Results.HuGaDBSessionProtocols);
    if ~ismember(ds, {'usc_had', 'hugadb'})
        error('Dataset must be ''usc_had'' or ''hugadb''.');
    end

    if strcmp(ds, 'usc_had')
        defaultModelPath = cfg.FILE.MULTICLASS_LSTM_USCHAD;
        defaultTag = 'usc_had';
    else
        defaultModelPath = cfg.FILE.MULTICLASS_LSTM_HUGADB;
        if isequal(protocolSelection, {'multi_activity_sequence'})
            defaultTag = 'hugadb_streaming';
        elseif isequal(protocolSelection, {'single_activity'})
            defaultTag = 'hugadb_single_activity';
        else
            defaultTag = 'hugadb';
        end
    end
    modelPath = resolvePath(projectRoot, p.Results.ModelPath, defaultModelPath);
    outTag = char(strtrim(string(p.Results.OutputTag)));
    if isempty(outTag)
        outTag = defaultTag;
    end

    hasDL = license('test', 'Deep_Learning_Toolbox') || license('test', 'Neural_Network_Toolbox');
    if ~hasDL
        error('Deep Learning Toolbox required to classify with the multiclass LSTM network.');
    end

    if ~exist(modelPath, 'file')
        error('Trained multiclass LSTM not found: %s\nRun TrainLstmMulticlass first.', modelPath);
    end

    fprintf('===========================================================\n');
    fprintf('   Multiclass LSTM evaluation (%s)\n', ds);
    fprintf('===========================================================\n');

    L = load(modelPath, 'net', 'ModelMetadata');
    net = L.net;

    [XCell, labelsAll, ModelMetadata] = PrepareTrainingDataSequencesMulticlass(cfg, ...
        'Dataset', ds, 'HuGaDBSessionProtocols', protocolSelection);
    if strcmp(ds, 'hugadb') && ~isempty(protocolSelection)
        fprintf('HuGaDB session protocols used: %s\n', strjoin(protocolSelection, ', '));
    end
    classNames = ModelMetadata.classNames;
    K = ModelMetadata.nClasses;

    Ycat = categorical(labelsAll, 1:K, classNames);
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
    fprintf('Holdout accuracy: %.4f (%.2f%%)\n', valAcc, valAcc * 100);

    labelsVal = categoricalToNativeIds(YVal, classNames);
    yHatNum = categoricalToNativeIds(Yhat, classNames);
    cm = confusionmat(labelsVal, yHatNum, 'Order', 1:K);

    fig = figure('Name', sprintf('Multiclass LSTM confusion (%s)', ds), 'Color', 'w', ...
        'ToolBar', 'none', 'Position', [80, 80, 900, 720]);
    h = confusionchart(YVal, Yhat);
    h.Title = sprintf('Multiclass LSTM (%s) | 20%% holdout | Acc = %.2f%%', ds, valAcc * 100);
    h.XLabel = 'Predicted';
    h.YLabel = 'True';
    styleConfusionChartBlack(h);
    styleReportFigureColors(fig);

    pngPath = ResultsArtifactPath(projectRoot, 'figures', 'multiclass', sprintf('lstm_multiclass_confusion_matrix_%s.png', outTag));
    if exist('exportgraphics', 'file') == 2
        exportgraphics(fig, pngPath, 'Resolution', 200, 'Padding', 'loose');
    else
        saveas(fig, pngPath);
    end
    close(fig);
    fprintf('Figure: %s\n', pngPath);

    matPath = ResultsArtifactPath(projectRoot, 'metrics', 'multiclass', sprintf('lstm_multiclass_evaluation_metrics_%s.mat', outTag));
    save(matPath, 'cm', 'valAcc', 'labelsAll', 'labelsVal', 'yHatNum', 'YVal', 'Yhat', ...
        'ModelMetadata', 'K', 'seed', 'ds', '-v7.3');
    fprintf('Metrics: %s\n', matPath);
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

function ids = categoricalToNativeIds(Ycat, classNames)
    ids = zeros(numel(Ycat), 1);
    for i = 1:numel(classNames)
        ids(Ycat == classNames{i}) = i;
    end
end
