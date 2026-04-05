function TrainLstmBinary(varargin)
% Train a binary active-vs-inactive LSTM using sequence windows from
% `PrepareTrainingDataSequences`.
% Requires Deep Learning Toolbox and saves the trained network together with
% model metadata.

scriptPath = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptPath);
addpath(fullfile(projectRoot, 'config'));
addpath(genpath(fullfile(projectRoot, 'src')));

cfg = ExoConfig();
classNames = ActivityClassRegistry.binaryClassNames();
inactiveLabel = classNames{1};
activeLabel = classNames{2};
hasDL = license('test', 'Deep_Learning_Toolbox') || license('test', 'Neural_Network_Toolbox');
if ~hasDL
    error(['Deep Learning Toolbox not available (license check failed). ', ...
        'Install Deep Learning Toolbox to train LSTM networks.']);
end

p = inputParser;
addParameter(p, 'IncludeUSCHAD', cfg.TRAINING.DEFAULT_INCLUDE_USCHAD, @islogical);
addParameter(p, 'IncludeHuGaDB', cfg.TRAINING.DEFAULT_INCLUDE_HUGADB, @islogical);
addParameter(p, 'IncludeHuGaDBSubjects', {}, @(x) isempty(x) || isnumeric(x) || ischar(x) || isstring(x) || iscell(x));
addParameter(p, 'ExcludeHuGaDBSubjects', cfg.HUGADB.HELDOUT_SUBJECTS, @(x) isempty(x) || isnumeric(x) || ischar(x) || isstring(x) || iscell(x));
addParameter(p, 'ModelPath', '', @(s) ischar(s) || isstring(s));
parse(p, varargin{:});

inclU = p.Results.IncludeUSCHAD;
inclH = p.Results.IncludeHuGaDB;
includeHuSubjects = NormalizeHuGaDBSubjectIds(p.Results.IncludeHuGaDBSubjects);
excludeHuSubjects = NormalizeHuGaDBSubjectIds(p.Results.ExcludeHuGaDBSubjects);
modelPath = resolvePath(projectRoot, p.Results.ModelPath, cfg.FILE.BINARY_LSTM);

fprintf('===========================================================\n');
fprintf('   Training binary LSTM (active vs. inactive)\n');
fprintf('===========================================================\n');
fprintf('IncludeUSCHAD=%d  IncludeHuGaDB=%d\n', inclU, inclH);
if ~isempty(includeHuSubjects)
    fprintf('IncludeHuGaDBSubjects=%s\n', strjoin(includeHuSubjects, ', '));
end
if ~isempty(excludeHuSubjects)
    fprintf('ExcludeHuGaDBSubjects=%s\n', strjoin(excludeHuSubjects, ', '));
end

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
inputSize = ModelMetadata.sequenceInputSize;
fprintf('Samples: %d | input %d x %d (features x time)\n', n, inputSize, ModelMetadata.sequenceLength);

Ycat = categorical(labelsAll, [0 1], classNames);
fprintf('  %s: %d  |  %s: %d\n', inactiveLabel, sum(labelsAll == 0), activeLabel, sum(labelsAll == 1));
if isfield(ModelMetadata, 'excludeHuGaDBSubjects') && ~isempty(ModelMetadata.excludeHuGaDBSubjects)
    fprintf('Held-out HuGaDB subjects excluded from LSTM training: %s\n', ...
        strjoin(ModelMetadata.excludeHuGaDBSubjects, ', '));
end

% Fixed RNG so EvaluateLstmConfusion can reproduce the same split.
rng(42);
cvp = cvpartition(Ycat, 'HoldOut', 0.2);
tr = training(cvp);
te = test(cvp);

XTrain = XCell(tr);
YTrain = Ycat(tr);
XVal = XCell(te);
YVal = Ycat(te);

layers = [
    sequenceInputLayer(inputSize, 'Name', 'in')
    lstmLayer(128, 'OutputMode', 'sequence', 'Name', 'lstm1')
    dropoutLayer(0.25, 'Name', 'drop1')
    lstmLayer(128, 'OutputMode', 'last', 'Name', 'lstm2')
    dropoutLayer(0.25, 'Name', 'drop2')
    fullyConnectedLayer(2, 'Name', 'fc')
    softmaxLayer('Name', 'sm')
    classificationLayer('Name', 'out')
];

miniBatch = min(128, max(16, floor(numel(XTrain) / 10)));
checkpointDir = fullfile(projectRoot, 'models', 'lstm_checkpoints');
if ~exist(checkpointDir, 'dir')
    mkdir(checkpointDir);
end

options = trainingOptions('adam', ...
    'MaxEpochs', 23, ...
    'MiniBatchSize', miniBatch, ...
    'InitialLearnRate', 1e-3, ...
    'LearnRateSchedule', 'piecewise', ...
    'LearnRateDropFactor', 0.5, ...
    'LearnRateDropPeriod', 15, ...
    'ValidationData', {XVal, YVal}, ...
    'ValidationFrequency', max(1, floor(numel(XTrain) / miniBatch)), ...
    'Shuffle', 'every-epoch', ...
    'ExecutionEnvironment', 'auto', ...
    'Plots', 'none', ...
    'Verbose', true, ...
    'CheckpointPath', checkpointDir);

fprintf('\nTraining (validation holdout 20%%)...\n');
net = trainNetwork(XTrain, YTrain, layers, options);

Yhat = classify(net, XVal);
valAcc = mean(Yhat == YVal);
fprintf('\nValidation accuracy: %.4f (%.2f%%)\n', valAcc, valAcc * 100);

cm = confusionmat(YVal, Yhat, 'Order', classNames);
fprintf('Confusion (rows=true %s/%s, cols=pred):\n', inactiveLabel, activeLabel);
disp(cm);

ModelMetadata.lstmHidden1 = 128;
ModelMetadata.lstmHidden2 = 128;
ModelMetadata.maxEpochsTrained = 23;
ModelMetadata.holdoutRNGSeed = 42;
ModelMetadata.validationAccuracy = valAcc;
ModelMetadata.validationConfusion = cm;
ModelMetadata.categoryOrder = classNames;
ModelMetadata.labelNegative = inactiveLabel;
ModelMetadata.labelPositive = activeLabel;
ModelMetadata.labelStand = inactiveLabel;
ModelMetadata.labelWalk = activeLabel;
ModelMetadata.modelPath = modelPath;

[saveDir, ~] = fileparts(modelPath);
if ~isempty(saveDir) && ~exist(saveDir, 'dir')
    mkdir(saveDir);
end

save(modelPath, 'net', 'ModelMetadata', '-v7.3');
fprintf('Saved: %s\n', modelPath);
fprintf('===========================================================\n');
end

function outPath = resolvePath(projectRoot, pathArg, defaultPath)
    raw = strtrim(char(string(pathArg)));
    if isempty(raw)
        raw = defaultPath;
    end
    if isfolder(raw) || startsWith(raw, filesep) || (~isempty(regexp(raw, '^[A-Za-z]:', 'once')))
        outPath = raw;
    else
        outPath = fullfile(projectRoot, raw);
    end
end
