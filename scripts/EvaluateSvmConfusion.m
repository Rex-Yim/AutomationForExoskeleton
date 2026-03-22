function EvaluateSvmConfusion(varargin)
%% EvaluateSvmConfusion — 5-fold OOF confusion matrix + metrics
%
% Optional name-value (defaults match merged training):
%   'IncludeUSCHAD'   (logical, default true)
%   'IncludeHuGaDB'   (logical, default true)
%   'OutputTag'       (char/string, default '') — if nonempty, saves
%                     svm_confusion_matrix_<tag>.png and svm_evaluation_metrics_<tag>.mat
%   'SaveModelPath'   (char/string, default '') — if nonempty, saves SVMModel + ModelMetadata there
%
% Usage:
%   >> EvaluateSvmConfusion
%   >> EvaluateSvmConfusion('IncludeHuGaDB', false, 'OutputTag', 'usc_had_only')

    here = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(here);
    addpath(fullfile(projectRoot, 'config'));
    addpath(genpath(fullfile(projectRoot, 'src')));

    p = inputParser;
    addParameter(p, 'IncludeUSCHAD', true, @islogical);
    addParameter(p, 'IncludeHuGaDB', true, @islogical);
    addParameter(p, 'OutputTag', '', @(s) ischar(s) || isstring(s));
    addParameter(p, 'SaveModelPath', '', @(s) ischar(s) || isstring(s));
    parse(p, varargin{:});

    inclU = p.Results.IncludeUSCHAD;
    inclH = p.Results.IncludeHuGaDB;
    outTag = char(strtrim(string(p.Results.OutputTag)));
    modelPathOut = char(strtrim(string(p.Results.SaveModelPath)));

    cfg = ExoConfig();

    fprintf('===========================================================\n');
    fprintf('   SVM evaluation: confusion matrix (5-fold OOF predictions)\n');
    fprintf('===========================================================\n');
    fprintf('IncludeUSCHAD=%d  IncludeHuGaDB=%d\n', inclU, inclH);

    %% 1. Features (same flags as training)
    try
        [featuresAll, labelsAll, ModelMetadata] = PrepareTrainingData(cfg, ...
            'IncludeUSCHAD', inclU, 'IncludeHuGaDB', inclH);
    catch ME
        error('Data preparation failed: %s', ME.message);
    end

    if isempty(featuresAll)
        error('No features extracted. Run LoadUSCHAD / LoadHuGaDB as needed.');
    end

    n = size(featuresAll, 1);
    fprintf('Total windows: %d (Stand=0 / Walk=1)\n', n);
    fprintf('  Class 0: %d  |  Class 1: %d\n', sum(labelsAll == 0), sum(labelsAll == 1));

    if numel(unique(labelsAll)) < 2
        error('Need both classes in the dataset for a binary confusion matrix.');
    end

    poolLabel = datasetPoolLabel(inclU, inclH);

    %% 2. Same SVM as TrainSvmBinary
    SVMModel = fitcsvm(featuresAll, labelsAll, ...
        'KernelFunction', 'rbf', ...
        'Standardize', true, ...
        'BoxConstraint', 1.0, ...
        'ClassNames', [0, 1]);

    if strlength(modelPathOut) > 0
        [saveDir, ~] = fileparts(modelPathOut);
        if ~isempty(saveDir) && ~exist(saveDir, 'dir')
            mkdir(saveDir);
        end
        save(modelPathOut, 'SVMModel', 'ModelMetadata', '-v7.3');
        fprintf('Model saved: %s\n', modelPathOut);
    end

    K = 5;
    fprintf('\nRunning %d-fold cross-validation (out-of-fold predictions)...\n', K);
    cvModel = crossval(SVMModel, 'KFold', K);
    yHat = kfoldPredict(cvModel);

    oofAccuracy = mean(yHat == labelsAll) * 100;
    cvLoss = kfoldLoss(cvModel);
    fprintf('OOF accuracy (from predictions): %.4f%%\n', oofAccuracy);
    fprintf('kfoldLoss (misclassification rate): %.6f  -> acc %.4f%%\n', cvLoss, (1 - cvLoss) * 100);

    %% 3. Confusion matrix (rows = true, cols = predicted)
    cm = confusionmat(labelsAll, yHat, 'Order', [0, 1]);

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

    %% 4. Figure
    fig = figure('Name', sprintf('SVM Confusion — %s', poolLabel), 'Color', 'w', ...
        'Position', [100, 100, 720, 520]);

    tiled = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

    nexttile(tiled);
    labelsCat = categorical(labelsAll, [0, 1], {'Stand (0)', 'Walk (1)'});
    yHatCat = categorical(yHat, [0, 1], {'Stand (0)', 'Walk (1)'});
    hcm = confusionchart(labelsCat, yHatCat, ...
        'Title', sprintf('%s | %d-fold OOF | Acc = %.2f%%', poolLabel, K, oofAccuracy), ...
        'RowSummary', 'row-normalized', ...
        'ColumnSummary', 'column-normalized');
    hcm.XLabel = 'Predicted';
    hcm.YLabel = 'True';

    nexttile(tiled);
    axis off;
    txt = {
        sprintf('Pool: %s', poolLabel);
        sprintf('Samples: %d windows', n);
        sprintf('USC-HAD windows: %d  |  HuGaDB windows: %d', ModelMetadata.nWindowsUSCHAD, ModelMetadata.nWindowsHuGaDB);
        sprintf('Model: RBF SVM, standardized, BoxConstraint=1.0');
        sprintf('Features: %d (see Features.m)', ModelMetadata.featureCount);
        sprintf('Fs=%d Hz, window=%d, step=%d', ModelMetadata.fs, ModelMetadata.windowSize, ModelMetadata.stepSize);
        ' ';
        sprintf('Accuracy (OOF): %.4f%%', oofAccuracy);
        sprintf('Precision (Walk): %.4f', precWalk);
        sprintf('Recall (Walk): %.4f', recWalk);
        sprintf('F1 (Walk): %.4f', f1Walk);
        sprintf('Specificity (Stand): %.4f', specStand);
        ' ';
        'Confusion counts [True x Pred], order Stand, Walk:';
        sprintf('  TN=%d  FP=%d', TN, FP);
        sprintf('  FN=%d  TP=%d', FN, TP);
        };
    text(0.05, 0.95, txt, 'Units', 'normalized', 'VerticalAlignment', 'top', ...
        'FontName', 'FixedWidth', 'FontSize', 11);

    resultsDir = fullfile(projectRoot, 'results');
    if ~exist(resultsDir, 'dir')
        mkdir(resultsDir);
    end

    if strlength(outTag) > 0
        pngPath = fullfile(resultsDir, ['svm_confusion_matrix_' outTag '.png']);
        matPath = fullfile(resultsDir, ['svm_evaluation_metrics_' outTag '.mat']);
    else
        pngPath = fullfile(resultsDir, 'svm_confusion_matrix.png');
        matPath = fullfile(resultsDir, 'svm_evaluation_metrics.mat');
    end

    saveas(fig, pngPath);
    close(fig);
    fprintf('\nFigure saved: %s\n', pngPath);

    save(matPath, 'cm', 'TP', 'TN', 'FP', 'FN', 'oofAccuracy', 'precWalk', 'recWalk', 'f1Walk', ...
        'specStand', 'yHat', 'labelsAll', 'K', 'ModelMetadata', 'poolLabel', '-v7.3');
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
