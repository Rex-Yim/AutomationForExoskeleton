function EvaluateMulticlassConfusion(varargin)
%% Multiclass  K-fold OOF confusion. Default: stratified subsample for speed (full ECOC CV is very slow).
    here = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(here);
    addpath(here);
    addpath(fullfile(projectRoot, 'config'));
    addpath(genpath(fullfile(projectRoot, 'src')));

    p = inputParser;
    addParameter(p, 'IncludeUSCHAD', true, @islogical);
    addParameter(p, 'IncludeHuGaDB', true, @islogical);
    addParameter(p, 'MaxWindowsForCV', 20000, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'KFolds', 5, @(x) isnumeric(x) && isscalar(x) && x >= 2);
    parse(p, varargin{:});

    cfg = ExoConfig();
    K = ActivityClassRegistry.N_CLASSES;
    names = ActivityClassRegistry.CLASS_NAMES;

    fprintf('===========================================================\n');
    fprintf('   Multiclass evaluation (%d-fold OOF)\n', p.Results.KFolds);
    fprintf('===========================================================\n');

    [featuresAll, labelsAll, ModelMetadata] = PrepareTrainingDataMulticlass(cfg, ...
        'IncludeUSCHAD', p.Results.IncludeUSCHAD, 'IncludeHuGaDB', p.Results.IncludeHuGaDB);

    n0 = size(featuresAll, 1);
    usedSubsamp = false;
    if n0 > p.Results.MaxWindowsForCV && isfinite(p.Results.MaxWindowsForCV)
        [featuresAll, labelsAll] = stratifiedSubsample(featuresAll, labelsAll, p.Results.MaxWindowsForCV);
        usedSubsamp = true;
        fprintf('Stratified subsample for CV: %d / %d windows (MaxWindowsForCV=%d).\n', ...
            size(featuresAll, 1), n0, p.Results.MaxWindowsForCV);
    else
        fprintf('CV on full set: %d windows (expect long runtime).\n', n0);
    end

    t = templateSVM('KernelFunction', 'rbf', 'Standardize', true, 'BoxConstraint', 1);
    Mdl = fitcecoc(featuresAll, labelsAll, 'Learners', t, 'Coding', 'onevsall');

    cvModel = crossval(Mdl, 'KFold', p.Results.KFolds);
    yHat = kfoldPredict(cvModel);
    yHatNum = double(yHat(:));
    labelsAll = labelsAll(:);

    oofAcc = mean(yHatNum == labelsAll) * 100;
    fprintf('OOF accuracy: %.2f%% (%d windows)\n', oofAcc, numel(labelsAll));

    cm = confusionmat(labelsAll, yHatNum, 'Order', 1:K);

    resultsDir = fullfile(projectRoot, 'results');
    if ~exist(resultsDir, 'dir')
        mkdir(resultsDir);
    end

    fig = figure('Name', 'Multiclass confusion', 'Color', 'w', 'Position', [80, 80, 900, 720]);
    catTrue = categorical(labelsAll, 1:K, names, 'Ordinal', true);
    catPred = categorical(yHatNum, 1:K, names, 'Ordinal', true);
    h = confusionchart(catTrue, catPred);
    sub = '';
    if usedSubsamp
        sub = ' (stratified subsample CV)';
    end
    h.Title = sprintf('%d-fold OOF%s | Acc = %.2f%%', p.Results.KFolds, sub, oofAcc);
    h.XLabel = 'Predicted';
    h.YLabel = 'True';
    styleConfusionChartBlack(h);
    styleReportFigureColors(fig);

    pngPath = fullfile(resultsDir, 'multiclass_confusion_matrix.png');
    if exist('exportgraphics', 'file') == 2
        exportgraphics(fig, pngPath, 'Resolution', 200, 'Padding', 'loose');
    else
        saveas(fig, pngPath);
    end
    close(fig);
    fprintf('Figure: %s\n', pngPath);

    nOriginalWindows = n0;
    matPath = fullfile(resultsDir, 'multiclass_evaluation_metrics.mat');
    save(matPath, 'cm', 'oofAcc', 'labelsAll', 'yHatNum', 'ModelMetadata', 'K', ...
        'usedSubsamp', 'nOriginalWindows', '-v7.3');
    fprintf('Metrics: %s\n', matPath);
    fprintf('===========================================================\n');
end

function [Xs, ys] = stratifiedSubsample(X, y, maxN)
    y = y(:);
    rng(1);
    uy = unique(y);
    per = max(floor(double(maxN) / numel(uy)), 50);
    Xs = [];
    ys = [];
    for c = uy'
        ix = find(y == c);
        take = min(per, numel(ix));
        if take < 1
            continue;
        end
        rp = ix(randperm(numel(ix), take));
        Xs = [Xs; X(rp, :)]; %#ok<AGROW>
        ys = [ys; y(rp)]; %#ok<AGROW>
    end
end
