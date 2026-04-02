%% TrainLstmBinary.m
% --------------------------------------------------------------------------
% Trains a binary Walk vs Stand LSTM on the same windows as TrainSvmBinary
% (PrepareTrainingDataSequences → 36 x WINDOW_SIZE per sample by default).
% Requires Deep Learning Toolbox. Saves net + ModelMetadata to cfg.FILE.BINARY_LSTM.
% --------------------------------------------------------------------------
% LOCATION: scripts/TrainLstmBinary.m
% --------------------------------------------------------------------------

clc; clear; close all;

scriptPath = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptPath);
addpath(fullfile(projectRoot, 'config'));
addpath(genpath(fullfile(projectRoot, 'src')));

cfg = ExoConfig();

hasDL = license('test', 'Deep_Learning_Toolbox') || license('test', 'Neural_Network_Toolbox');
if ~hasDL
    error(['Deep Learning Toolbox not available (license check failed). ', ...
        'Install Deep Learning Toolbox to train LSTM networks.']);
end

fprintf('===========================================================\n');
fprintf('   Training binary LSTM (locomotion vs non-locomotion)\n');
fprintf('===========================================================\n');

try
    [XCell, labelsAll, ModelMetadata] = PrepareTrainingDataSequences(cfg);
catch ME
    error('Sequence preparation failed: %s', ME.message);
end

n = numel(XCell);
inputSize = ModelMetadata.sequenceInputSize;
fprintf('Samples: %d | input %d x %d (features x time)\n', n, inputSize, ModelMetadata.sequenceLength);

Ycat = categorical(labelsAll, [0 1], {'Stand', 'Walk'});
fprintf('  Stand: %d  |  Walk: %d\n', sum(labelsAll == 0), sum(labelsAll == 1));

%% Stratified holdout validation
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

options = trainingOptions('adam', ...
    'MaxEpochs', 45, ...
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
    'Verbose', true);

fprintf('\nTraining (validation holdout 20%%)...\n');
net = trainNetwork(XTrain, YTrain, layers, options);

Yhat = classify(net, XVal);
valAcc = mean(Yhat == YVal);
fprintf('\nValidation accuracy: %.4f (%.2f%%)\n', valAcc, valAcc * 100);

cm = confusionmat(YVal, Yhat, 'Order', {'Stand', 'Walk'});
fprintf('Confusion (rows=true Stand/Walk, cols=pred):\n');
disp(cm);

ModelMetadata.lstmHidden1 = 128;
ModelMetadata.lstmHidden2 = 128;
ModelMetadata.validationAccuracy = valAcc;
ModelMetadata.validationConfusion = cm;
ModelMetadata.categoryOrder = {'Stand', 'Walk'};
ModelMetadata.labelStand = 'Stand';
ModelMetadata.labelWalk = 'Walk';

savePath = cfg.FILE.BINARY_LSTM;
[saveDir, ~] = fileparts(savePath);
if ~isempty(saveDir) && ~exist(saveDir, 'dir')
    mkdir(saveDir);
end

save(savePath, 'net', 'ModelMetadata', '-v7.3');
fprintf('Saved: %s\n', savePath);
fprintf('===========================================================\n');
