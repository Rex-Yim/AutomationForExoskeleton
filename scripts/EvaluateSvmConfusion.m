function EvaluateSvmConfusion(varargin)
%% EvaluateSvmConfusion — 5-fold OOF confusion matrix + metrics
%
% Optional name-value (defaults match the active HuGaDB binary SVM):
%   'IncludeUSCHAD'   (logical, default cfg.TRAINING.DEFAULT_INCLUDE_USCHAD)
%   'IncludeHuGaDB'   (logical, default cfg.TRAINING.DEFAULT_INCLUDE_HUGADB)
%   'IncludeHuGaDBSubjects' (default {})
%   'ExcludeHuGaDBSubjects' (default cfg.HUGADB.HELDOUT_SUBJECTS when cfg available)
%   'OutputTag'       (char/string, default auto) — saves
%                     svm_confusion_matrix_<tag>.png and svm_evaluation_metrics_<tag>.mat
%   'SaveModelPath'   (char/string, default '') — if nonempty, saves SVMModel + ModelMetadata there
%
% Usage:
%   >> EvaluateSvmConfusion
%   >> EvaluateSvmConfusion('IncludeHuGaDB', false, 'OutputTag', 'usc_had')

    here = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(here);
    % ExoConfig paths are relative to project root (data/...); batch runs often start in scripts/.
    cd(projectRoot);
    addpath(here);
    addpath(fullfile(projectRoot, 'config'));
    addpath(genpath(fullfile(projectRoot, 'src')));

    cfg = ExoConfig();
    classNames = ActivityClassRegistry.binaryClassNames();
    inactiveLabel = classNames{1};
    activeLabel = classNames{2};
    defaultExcludedSubjects = {};
    if isprop(cfg, 'HUGADB')
        defaultExcludedSubjects = cfg.HUGADB.HELDOUT_SUBJECTS;
    end

    p = inputParser;
    addParameter(p, 'IncludeUSCHAD', cfg.TRAINING.DEFAULT_INCLUDE_USCHAD, @islogical);
    addParameter(p, 'IncludeHuGaDB', cfg.TRAINING.DEFAULT_INCLUDE_HUGADB, @islogical);
    addParameter(p, 'IncludeHuGaDBSubjects', {}, @(x) isempty(x) || isnumeric(x) || ischar(x) || isstring(x) || iscell(x));
    addParameter(p, 'ExcludeHuGaDBSubjects', defaultExcludedSubjects, @(x) isempty(x) || isnumeric(x) || ischar(x) || isstring(x) || iscell(x));
    addParameter(p, 'HuGaDBSessionProtocols', cfg.HUGADB.DEFAULT_PROTOCOLS, @(x) isempty(x) || ischar(x) || isstring(x) || iscell(x));
    addParameter(p, 'OutputTag', '', @(s) ischar(s) || isstring(s));
    addParameter(p, 'SaveModelPath', '', @(s) ischar(s) || isstring(s));
    parse(p, varargin{:});

    inclU = p.Results.IncludeUSCHAD;
    inclH = p.Results.IncludeHuGaDB;
    includeHuSubjects = NormalizeHuGaDBSubjectIds(p.Results.IncludeHuGaDBSubjects);
    excludeHuSubjects = NormalizeHuGaDBSubjectIds(p.Results.ExcludeHuGaDBSubjects);
    protocolSelection = NormalizeHuGaDBProtocolSelection(p.Results.HuGaDBSessionProtocols);
    outTag = char(strtrim(string(p.Results.OutputTag)));
    modelPathOut = char(strtrim(string(p.Results.SaveModelPath)));

    fprintf('===========================================================\n');
    fprintf('   SVM evaluation: confusion matrix (5-fold OOF predictions)\n');
    fprintf('===========================================================\n');
    fprintf('IncludeUSCHAD=%d  IncludeHuGaDB=%d\n', inclU, inclH);
    if ~isempty(includeHuSubjects)
        fprintf('IncludeHuGaDBSubjects=%s\n', strjoin(includeHuSubjects, ', '));
    end
    if ~isempty(excludeHuSubjects)
        fprintf('ExcludeHuGaDBSubjects=%s\n', strjoin(excludeHuSubjects, ', '));
    end
    if ~isempty(protocolSelection)
        fprintf('HuGaDBSessionProtocols=%s\n', strjoin(protocolSelection, ', '));
    end

    %% 1. Features (same flags as training)
    try
        [featuresAll, labelsAll, ModelMetadata] = PrepareTrainingData(cfg, ...
            'IncludeUSCHAD', inclU, ...
            'IncludeHuGaDB', inclH, ...
            'IncludeHuGaDBSubjects', includeHuSubjects, ...
            'ExcludeHuGaDBSubjects', excludeHuSubjects, ...
            'HuGaDBSessionProtocols', protocolSelection);
    catch ME
        error('Data preparation failed: %s', ME.message);
    end

    if isempty(featuresAll)
        error('No features extracted. Run LoadUSCHAD / LoadHuGaDB as needed.');
    end

    n = size(featuresAll, 1);
    fprintf('Total windows: %d (%s=0 / %s=1)\n', n, inactiveLabel, activeLabel);
    fprintf('  Class 0: %d  |  Class 1: %d\n', sum(labelsAll == 0), sum(labelsAll == 1));

    if numel(unique(labelsAll)) < 2
        error('Need both classes in the dataset for a binary confusion matrix.');
    end

    poolLabel = datasetPoolLabel(inclU, inclH, includeHuSubjects, excludeHuSubjects, protocolSelection);

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

    fprintf('\n----------- Binary metrics (%s = positive class) -----------\n', activeLabel);
    fprintf('Precision (%s):  %.4f\n', activeLabel, precWalk);
    fprintf('Recall (%s):     %.4f\n', activeLabel, recWalk);
    fprintf('F1 (%s):         %.4f\n', activeLabel, f1Walk);
    fprintf('Specificity (%s): %.4f\n', inactiveLabel, specStand);
    fprintf('-------------------------------------------------------------\n');

    %% 4. Figure (see exportSvmConfusionMatrixPng.m; RedrawSvmConfusionFromMetrics for PNG refresh)
    if strlength(outTag) == 0
        outTag = defaultOutputTag(inclU, inclH, includeHuSubjects, excludeHuSubjects, protocolSelection, cfg);
    end
    pngPath = ResultsArtifactPath(projectRoot, 'figures', 'binary', ['svm_confusion_matrix_' outTag '.png']);
    matPath = ResultsArtifactPath(projectRoot, 'metrics', 'binary', ['svm_evaluation_metrics_' outTag '.mat']);

    exportSvmConfusionMatrixPng(pngPath, labelsAll, yHat, poolLabel, K, oofAccuracy, ...
        TN, FP, FN, TP, ModelMetadata, precWalk, recWalk, f1Walk, specStand);
    fprintf('\nFigure saved: %s\n', pngPath);

    save(matPath, 'cm', 'TP', 'TN', 'FP', 'FN', 'oofAccuracy', 'precWalk', 'recWalk', 'f1Walk', ...
        'specStand', 'yHat', 'labelsAll', 'K', 'ModelMetadata', 'poolLabel', '-v7.3');
    fprintf('Metrics saved: %s\n', matPath);

    fprintf('===========================================================\n');
end

function s = datasetPoolLabel(inclU, inclH, includeHuSubjects, excludeHuSubjects, protocolSelection)
    if inclU && inclH
        error('Combined USC-HAD + HuGaDB evaluation has been removed.');
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
    if ~inclU && inclH && ~isempty(protocolSelection)
        s = sprintf('%s | protocols: %s', s, strjoin(protocolSelection, ', '));
    end
end

function tag = defaultOutputTag(inclU, inclH, includeHuSubjects, excludeHuSubjects, protocolSelection, cfg)
    if inclU && ~inclH
        tag = 'usc_had';
        return;
    end

    if ~inclU && inclH
        if isempty(includeHuSubjects) && isempty(excludeHuSubjects) && isequal(protocolSelection, {'multi_activity_sequence'})
            tag = 'hugadb_streaming';
            return;
        end
        if isempty(includeHuSubjects) && isempty(excludeHuSubjects) && isequal(protocolSelection, {'single_activity'})
            tag = 'hugadb_single_activity';
            return;
        end
    end

    tag = sanitizeTag(datasetPoolLabel(inclU, inclH, includeHuSubjects, excludeHuSubjects, protocolSelection));
end

function out = sanitizeTag(label)
    out = regexprep(lower(char(label)), '[^a-z0-9]+', '_');
    out = regexprep(out, '^_+|_+$', '');
end
