function TrainLstmMulticlass(varargin)
% Train a dataset-native multiclass LSTM on sequence-shaped IMU windows.
% Supports `usc_had` and `hugadb` model artifacts through the `Dataset`
% option.

scriptDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptDir);
addpath(fullfile(projectRoot, 'config'));
addpath(genpath(fullfile(projectRoot, 'src')));

cfg = ExoConfig();
hasDL = license('test', 'Deep_Learning_Toolbox') || license('test', 'Neural_Network_Toolbox');
if ~hasDL
    error(['Deep Learning Toolbox not available (license check failed). ', ...
        'Install Deep Learning Toolbox to train LSTM networks.']);
end

p = inputParser;
addParameter(p, 'Dataset', 'hugadb', @(s) ischar(s) || isstring(s));
addParameter(p, 'HuGaDBSessionProtocols', cfg.HUGADB.DEFAULT_PROTOCOLS, @(x) isempty(x) || ischar(x) || isstring(x) || iscell(x));
addParameter(p, 'ModelPath', '', @(s) ischar(s) || isstring(s));
addParameter(p, 'MaxEpochs', 12, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'EarlyStopTarget', 0.90, @(x) isnumeric(x) && isscalar(x) && x > 0 && x <= 1);
addParameter(p, 'EarlyStopMinEpochs', 3, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'EarlyStopPatience', 4, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'EarlyStopMinDelta', 1e-3, @(x) isnumeric(x) && isscalar(x) && x >= 0);
parse(p, varargin{:});

ds = lower(char(p.Results.Dataset));
protocolSelection = NormalizeHuGaDBProtocolSelection(p.Results.HuGaDBSessionProtocols);
maxEpochs = double(p.Results.MaxEpochs);
earlyStopTarget = double(p.Results.EarlyStopTarget);
earlyStopMinEpochs = double(p.Results.EarlyStopMinEpochs);
earlyStopPatience = double(p.Results.EarlyStopPatience);
earlyStopMinDelta = double(p.Results.EarlyStopMinDelta);
if ~ismember(ds, {'usc_had', 'hugadb'})
    error('Dataset must be ''usc_had'' or ''hugadb''.');
end

if strcmp(ds, 'usc_had')
    defaultModelPath = cfg.FILE.MULTICLASS_LSTM_USCHAD;
else
    defaultModelPath = cfg.FILE.MULTICLASS_LSTM_HUGADB;
end
modelPath = resolvePath(projectRoot, p.Results.ModelPath, defaultModelPath);

fprintf('===========================================================\n');
fprintf('   Multiclass LSTM (%s)\n', ds);
fprintf('===========================================================\n');

try
    [XCell, labelsAll, ModelMetadata] = PrepareTrainingDataSequencesMulticlass(cfg, ...
        'Dataset', ds, 'HuGaDBSessionProtocols', protocolSelection);
catch ME
    error('Multiclass LSTM sequence preparation failed: %s', ME.message);
end

n = numel(XCell);
K = ModelMetadata.nClasses;
classNames = ModelMetadata.classNames;
inputSize = ModelMetadata.sequenceInputSize;
fprintf('Samples: %d | input %d x %d (features x time)\n', n, inputSize, ModelMetadata.sequenceLength);
if strcmp(ds, 'hugadb') && ~isempty(protocolSelection)
    fprintf('HuGaDB session protocols used: %s\n', strjoin(protocolSelection, ', '));
end
fprintf('Dynamic stop: target=%.2f%% minEpochs=%d patience=%d maxEpochs=%d\n', ...
    earlyStopTarget * 100, earlyStopMinEpochs, earlyStopPatience, maxEpochs);
fprintf('Classes present: %s\n', mat2str(unique(labelsAll)'));
for c = 1:K
    fprintf('  Class %2d %-18s : %d windows\n', c, classNames{c}, sum(labelsAll == c));
end

Ycat = categorical(labelsAll, 1:K, classNames);
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
    fullyConnectedLayer(K, 'Name', 'fc')
    softmaxLayer('Name', 'sm')
    classificationLayer('Name', 'out')
];

miniBatch = min(128, max(16, floor(numel(XTrain) / 10)));
checkpointDir = fullfile(projectRoot, 'models', 'lstm_multiclass_checkpoints', ds);
if ~exist(checkpointDir, 'dir')
    mkdir(checkpointDir);
end

options = trainingOptions('adam', ...
    'MaxEpochs', maxEpochs, ...
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
stopper = MakeValidationEarlyStopper( ...
    'TargetAccuracy', earlyStopTarget, ...
    'MinEpochs', earlyStopMinEpochs, ...
    'PatienceChecks', earlyStopPatience, ...
    'MinDelta', earlyStopMinDelta, ...
    'Label', sprintf('multiclass LSTM (%s) validation', ds));
logRecorder = MakeTrainingLogRecorder();
options.OutputFcn = @(info) LstmTrainingOutputChain(info, logRecorder, stopper);

fprintf('\nTraining multiclass LSTM (validation holdout 20%%)...\n');
net = trainNetwork(XTrain, YTrain, layers, options);
earlyStopState = stopper.GetState();

artifactTag = DefaultMulticlassLstmArtifactTag(ds, protocolSelection);
trainExtra = struct( ...
    'earlyStopState', earlyStopState, ...
    'miniBatchSize', miniBatch, ...
    'maxEpochsRequested', maxEpochs, ...
    'initialLearnRate', 1e-3, ...
    'learnRateDropPeriod', 15, ...
    'learnRateDropFactor', 0.5, ...
    'solver', 'adam', ...
    'dataset', ds);
trainingArtifacts = SaveLstmTrainingArtifacts(projectRoot, 'multiclass', artifactTag, logRecorder.GetHistory(), trainExtra);

Yhat = classify(net, XVal);
valAcc = mean(Yhat == YVal);
fprintf('\nValidation accuracy: %.4f (%.2f%%)\n', valAcc, valAcc * 100);

cm = confusionmat(YVal, Yhat, 'Order', classNames);
fprintf('Confusion matrix computed on validation split.\n');

ModelMetadata.lstmHidden1 = 128;
ModelMetadata.lstmHidden2 = 128;
ModelMetadata.maxEpochsTrained = maxEpochs;
ModelMetadata.holdoutRNGSeed = 42;
ModelMetadata.validationAccuracy = valAcc;
ModelMetadata.validationConfusion = cm;
ModelMetadata.categoryOrder = classNames;
ModelMetadata.modelPath = modelPath;
ModelMetadata.earlyStop = earlyStopState;
ModelMetadata.trainingArtifacts = trainingArtifacts;

[saveDir, ~] = fileparts(modelPath);
if ~isempty(saveDir) && ~exist(saveDir, 'dir')
    mkdir(saveDir);
end

save(modelPath, 'net', 'ModelMetadata', 'ds', '-v7.3');
fprintf('Saved: %s\n', modelPath);
if earlyStopState.stopRequested
    fprintf('Stopped early: %s\n', earlyStopState.stopReason);
end
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
