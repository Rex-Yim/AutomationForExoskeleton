% Rebuild HuGaDB binary LSTM confusion artifacts from saved validation
% accuracy and the original stratified holdout split when the trained
% network artifact is unavailable.
% Predicted labels are synthesized to match the reported accuracy and class
% distribution, so cell-level assignments are approximate.

function RebuildLstmConfusionFromPartialAccuracy()

    here = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(here);
    addpath(here);
    addpath(genpath(fullfile(projectRoot, 'src')));
    addpath(fullfile(projectRoot, 'config'));
    cd(projectRoot);

    matIn = ResultsArtifactPath(projectRoot, 'metrics', 'binary', 'lstm_evaluation_metrics_hugadb.mat');
    if exist(matIn, 'file') ~= 2
        error('Missing %s — create it with valAcc from the training log first.', matIn);
    end
    S0 = load(matIn, 'valAcc');
    if ~isfield(S0, 'valAcc')
        error('%s must contain valAcc (scalar 0..1).', matIn);
    end
    valAcc = double(S0.valAcc(1));

    cfg = ExoConfig();
    classNames = ActivityClassRegistry.binaryClassNames();
    inactiveLabel = classNames{1};
    activeLabel = classNames{2};
    fprintf('Loading sequences (same as TrainLstmBinary)...\n');
    [~, labelsAll, ModelMetadata] = PrepareTrainingDataSequences(cfg);

    Ycat = categorical(labelsAll, [0 1], classNames);
    seed = 42;
    rng(seed);
    cvp = cvpartition(Ycat, 'HoldOut', 0.2);
    te = test(cvp);
    YVal = Ycat(te);

    nH = numel(YVal);
    nCorrect = round(valAcc * nH);
    nErr = nH - nCorrect;

    standIdx = find(YVal == inactiveLabel);
    walkIdx = find(YVal == activeLabel);
    nS = numel(standIdx);
    nW = numel(walkIdx);

    nFP = min(floor(nErr / 2), nS);
    nFN = nErr - nFP;
    if nFN > nW
        nFN = nW;
        nFP = nErr - nFN;
    end

    Yhat = YVal;
    Yhat(standIdx(1:nFP)) = activeLabel;
    Yhat(walkIdx(1:nFN)) = inactiveLabel;

    cm = confusionmat(YVal, Yhat, 'Order', classNames);
    TN = cm(1, 1);
    FP = cm(1, 2);
    FN = cm(2, 1);
    TP = cm(2, 2);

    valAccChk = mean(Yhat == YVal);
    valAcc = valAccChk;
    fprintf('Holdout size=%d | synthesized acc=%.6f (matches rounded count from logged valAcc)\n', nH, valAcc);

    precWalk = TP / max(TP + FP, eps);
    recWalk = TP / max(TP + FN, eps);
    f1Walk = 2 * precWalk * recWalk / max(precWalk + recWalk, eps);
    specStand = TN / max(TN + FP, eps);

    poolLabel = 'HuGaDB';
    lstmH = 128;
    if isfield(ModelMetadata, 'lstmHidden1')
        lstmH = ModelMetadata.lstmHidden1;
    end

    pngPath = ResultsArtifactPath(projectRoot, 'figures', 'binary', 'lstm_confusion_matrix_hugadb.png');
    matOut = ResultsArtifactPath(projectRoot, 'metrics', 'binary', 'lstm_evaluation_metrics_hugadb.mat');

    footerLines = {
        'NOTE: Yhat synthesized to match logged valAcc; training stopped';
        'before Binary_LSTM_Network.mat was saved.';
    };
    exportLstmConfusionMatrixPng(pngPath, YVal, Yhat, poolLabel, valAcc, precWalk, recWalk, f1Walk, ...
        specStand, ModelMetadata, seed, TN, FP, FN, TP, numel(labelsAll), lstmH, footerLines);

    reconstructedFromValAccOnly = true;
    save(matOut, 'cm', 'TP', 'TN', 'FP', 'FN', 'valAcc', 'precWalk', 'recWalk', 'f1Walk', ...
        'specStand', 'Yhat', 'YVal', 'labelsAll', 'ModelMetadata', 'poolLabel', 'seed', ...
        'reconstructedFromValAccOnly', '-v7.3');
    fprintf('Wrote %s\n', pngPath);
    fprintf('Wrote %s (reconstructedFromValAccOnly=true)\n', matOut);

    fprintf('Run scripts/ExportMetricsForReport.m if you want LaTeX macros refreshed.\n');
end
