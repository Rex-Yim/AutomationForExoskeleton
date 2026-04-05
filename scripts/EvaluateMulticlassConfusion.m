function EvaluateMulticlassConfusion(varargin)
%% Multiclass  K-fold OOF confusion. Default: stratified subsample for speed (full ECOC CV is very slow).
    here = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(here);
    addpath(here);
    addpath(fullfile(projectRoot, 'config'));
    addpath(genpath(fullfile(projectRoot, 'src')));

    p = inputParser;
    addParameter(p, 'Dataset', 'hugadb', @(s) ischar(s) || isstring(s));
    addParameter(p, 'MaxWindowsForCV', 20000, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'KFolds', 5, @(x) isnumeric(x) && isscalar(x) && x >= 2);
    addParameter(p, 'HuGaDBSessionProtocols', ExoConfig().HUGADB.DEFAULT_PROTOCOLS, @(x) isempty(x) || ischar(x) || isstring(x) || iscell(x));
    parse(p, varargin{:});

    ds = lower(char(p.Results.Dataset));
    protocolSelection = NormalizeHuGaDBProtocolSelection(p.Results.HuGaDBSessionProtocols);
    if ~ismember(ds, {'usc_had', 'hugadb'})
        error('Dataset must be ''usc_had'' or ''hugadb''.');
    end

    cfg = ExoConfig();
    if strcmp(ds, 'usc_had')
        K = ActivityClassRegistry.USCHAD_N_CLASSES;
        names = ActivityClassRegistry.USCHAD_CLASS_NAMES;
        tag = 'usc_had';
    else
        K = ActivityClassRegistry.HUGADB_N_CLASSES;
        names = ActivityClassRegistry.HUGADB_CLASS_NAMES;
        if isequal(protocolSelection, {'multi_activity_sequence'})
            tag = 'hugadb_streaming';
        elseif isequal(protocolSelection, {'single_activity'})
            tag = 'hugadb_single_activity';
        else
            tag = 'hugadb';
        end
    end

    fprintf('===========================================================\n');
    fprintf('   Multiclass evaluation (%s, %d-fold OOF)\n', ds, p.Results.KFolds);
    fprintf('===========================================================\n');

    [featuresAll, labelsAll, ModelMetadata] = PrepareTrainingDataMulticlass(cfg, ...
        'Dataset', ds, 'HuGaDBSessionProtocols', protocolSelection);
    if strcmp(ds, 'hugadb') && ~isempty(protocolSelection)
        fprintf('HuGaDB session protocols used: %s\n', strjoin(protocolSelection, ', '));
    end

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

    fig = figure('Name', sprintf('Multiclass confusion (%s)', ds), 'Color', 'w', ...
        'ToolBar', 'none', 'Position', [80, 80, 900, 720]);
    catTrue = categorical(labelsAll, 1:K, names, 'Ordinal', true);
    catPred = categorical(yHatNum, 1:K, names, 'Ordinal', true);
    h = confusionchart(catTrue, catPred);
    sub = '';
    if usedSubsamp
        sub = ' (stratified subsample CV)';
    end
    h.Title = sprintf('%s | %d-fold OOF%s | Acc = %.2f%%', ds, p.Results.KFolds, sub, oofAcc);
    h.XLabel = 'Predicted';
    h.YLabel = 'True';
    styleConfusionChartBlack(h);
    styleReportFigureColors(fig);

    pngPath = ResultsArtifactPath(projectRoot, 'figures', 'multiclass', sprintf('multiclass_confusion_matrix_%s.png', tag));
    if exist('exportgraphics', 'file') == 2
        exportgraphics(fig, pngPath, 'Resolution', 200, 'Padding', 'loose');
    else
        saveas(fig, pngPath);
    end
    close(fig);
    fprintf('Figure: %s\n', pngPath);

    nOriginalWindows = n0;
    matPath = ResultsArtifactPath(projectRoot, 'metrics', 'multiclass', sprintf('multiclass_evaluation_metrics_%s.mat', tag));
    save(matPath, 'cm', 'oofAcc', 'labelsAll', 'yHatNum', 'ModelMetadata', 'K', ...
        'usedSubsamp', 'nOriginalWindows', 'ds', '-v7.3');
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
