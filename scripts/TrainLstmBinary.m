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
addParameter(p, 'HuGaDBSessionProtocols', cfg.HUGADB.DEFAULT_PROTOCOLS, @(x) isempty(x) || ischar(x) || isstring(x) || iscell(x));
addParameter(p, 'ModelPath', '', @(s) ischar(s) || isstring(s));
addParameter(p, 'MaxEpochs', 12, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'EarlyStopTarget', 0.994, @(x) isnumeric(x) && isscalar(x) && x > 0 && x <= 1);
addParameter(p, 'EarlyStopMinEpochs', 3, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'EarlyStopPatience', 3, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'EarlyStopMinDelta', 5e-4, @(x) isnumeric(x) && isscalar(x) && x >= 0);
parse(p, varargin{:});

inclU = p.Results.IncludeUSCHAD;
inclH = p.Results.IncludeHuGaDB;
includeHuSubjects = NormalizeHuGaDBSubjectIds(p.Results.IncludeHuGaDBSubjects);
excludeHuSubjects = NormalizeHuGaDBSubjectIds(p.Results.ExcludeHuGaDBSubjects);
protocolSelection = NormalizeHuGaDBProtocolSelection(p.Results.HuGaDBSessionProtocols);
modelPath = resolvePath(projectRoot, p.Results.ModelPath, cfg.FILE.BINARY_LSTM);
maxEpochs = double(p.Results.MaxEpochs);
earlyStopTarget = double(p.Results.EarlyStopTarget);
earlyStopMinEpochs = double(p.Results.EarlyStopMinEpochs);
earlyStopPatience = double(p.Results.EarlyStopPatience);
earlyStopMinDelta = double(p.Results.EarlyStopMinDelta);

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
if ~isempty(protocolSelection)
    fprintf('HuGaDBSessionProtocols=%s\n', strjoin(protocolSelection, ', '));
end
fprintf('Dynamic stop: target=%.2f%% minEpochs=%d patience=%d maxEpochs=%d\n', ...
    earlyStopTarget * 100, earlyStopMinEpochs, earlyStopPatience, maxEpochs);

try
    [XCell, labelsAll, ModelMetadata] = PrepareTrainingDataSequences(cfg, ...
        'IncludeUSCHAD', inclU, ...
        'IncludeHuGaDB', inclH, ...
        'IncludeHuGaDBSubjects', includeHuSubjects, ...
        'ExcludeHuGaDBSubjects', excludeHuSubjects, ...
        'HuGaDBSessionProtocols', protocolSelection);
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
    'Label', 'binary LSTM validation');
logRecorder = MakeTrainingLogRecorder();
options.OutputFcn = @(info) LstmTrainingOutputChain(info, logRecorder, stopper);

fprintf('\nTraining (validation holdout 20%%)...\n');
net = trainNetwork(XTrain, YTrain, layers, options);
earlyStopState = stopper.GetState();

artifactTag = DefaultBinaryLstmArtifactTag(inclU, inclH, includeHuSubjects, excludeHuSubjects, protocolSelection);
trainExtra = struct( ...
    'earlyStopState', earlyStopState, ...
    'miniBatchSize', miniBatch, ...
    'maxEpochsRequested', maxEpochs, ...
    'initialLearnRate', 1e-3, ...
    'learnRateDropPeriod', 15, ...
    'learnRateDropFactor', 0.5, ...
    'solver', 'adam');
trainingArtifacts = SaveLstmTrainingArtifacts(projectRoot, 'binary', artifactTag, logRecorder.GetHistory(), trainExtra);

Yhat = classify(net, XVal);
valAcc = mean(Yhat == YVal);
fprintf('\nValidation accuracy: %.4f (%.2f%%)\n', valAcc, valAcc * 100);

cm = confusionmat(YVal, Yhat, 'Order', classNames);
fprintf('Confusion (rows=true %s/%s, cols=pred):\n', inactiveLabel, activeLabel);
disp(cm);

ModelMetadata.lstmHidden1 = 128;
ModelMetadata.lstmHidden2 = 128;
ModelMetadata.maxEpochsTrained = maxEpochs;
ModelMetadata.holdoutRNGSeed = 42;
ModelMetadata.validationAccuracy = valAcc;
ModelMetadata.validationConfusion = cm;
ModelMetadata.categoryOrder = classNames;
ModelMetadata.labelNegative = inactiveLabel;
ModelMetadata.labelPositive = activeLabel;
ModelMetadata.labelStand = inactiveLabel;
ModelMetadata.labelWalk = activeLabel;
ModelMetadata.modelPath = modelPath;
ModelMetadata.earlyStop = earlyStopState;
ModelMetadata.trainingArtifacts = trainingArtifacts;

[saveDir, ~] = fileparts(modelPath);
if ~isempty(saveDir) && ~exist(saveDir, 'dir')
    mkdir(saveDir);
end

save(modelPath, 'net', 'ModelMetadata', '-v7.3');
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
    if isfolder(raw) || startsWith(raw, filesep) || (~isempty(regexp(raw, '^[A-Za-z]:', 'once')))
        outPath = raw;
    else
        outPath = fullfile(projectRoot, raw);
    end
end
