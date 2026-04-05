function recorder = MakeTrainingLogRecorder()
% MakeTrainingLogRecorder — capture trainNetwork OutputFcn rows for LSTM training logs.
%
% recorder.OutputFcn — chain before early-stopping OutputFcn (always returns stop=false).
% recorder.GetHistory() — struct of column vectors (NaN where unavailable).

    epoch = [];
    iteration = [];
    trainingLoss = [];
    validationLoss = [];
    trainingAccuracy = [];
    validationAccuracy = [];
    learningRate = [];

    recorder.OutputFcn = @outputFcn;
    recorder.GetHistory = @getHistory;

    function stop = outputFcn(info)
        stop = false;
        if ~isfield(info, 'State') || strcmpi(info.State, 'start') || strcmpi(info.State, 'done')
            return;
        end
        epoch(end + 1, 1) = grabScalar(info, 'Epoch'); %#ok<AGROW>
        iteration(end + 1, 1) = grabScalar(info, 'Iteration'); %#ok<AGROW>
        trainingLoss(end + 1, 1) = grabScalarNan(info, 'TrainingLoss'); %#ok<AGROW>
        validationLoss(end + 1, 1) = grabScalarNan(info, 'ValidationLoss'); %#ok<AGROW>
        trainingAccuracy(end + 1, 1) = grabScalarNan(info, 'TrainingAccuracy'); %#ok<AGROW>
        validationAccuracy(end + 1, 1) = grabScalarNan(info, 'ValidationAccuracy'); %#ok<AGROW>
        learningRate(end + 1, 1) = grabScalarNan(info, 'BaseLearnRate'); %#ok<AGROW>
    end

    function H = getHistory()
        H = struct( ...
            'epoch', epoch(:), ...
            'iteration', iteration(:), ...
            'trainingLoss', trainingLoss(:), ...
            'validationLoss', validationLoss(:), ...
            'trainingAccuracy', trainingAccuracy(:), ...
            'validationAccuracy', validationAccuracy(:), ...
            'learningRate', learningRate(:));
    end
end

function v = grabScalar(info, name)
    if ~isfield(info, name) || isempty(info.(name))
        v = NaN;
        return;
    end
    x = info.(name);
    if ~isnumeric(x) && ~islogical(x)
        v = NaN;
        return;
    end
    v = double(x(1));
end

function v = grabScalarNan(info, name)
    v = grabScalar(info, name);
end
