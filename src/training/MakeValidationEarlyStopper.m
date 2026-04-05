function stopper = MakeValidationEarlyStopper(varargin)
% MakeValidationEarlyStopper  Build an OutputFcn for dynamic LSTM early stopping.
%
% The returned struct contains:
%   stopper.OutputFcn  - pass into trainingOptions('OutputFcn', ...)
%   stopper.GetState() - returns summary of the stop decision after training

    p = inputParser;
    addParameter(p, 'TargetAccuracy', inf, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'MinEpochs', 1, @(x) isnumeric(x) && isscalar(x) && x >= 1);
    addParameter(p, 'PatienceChecks', inf, @(x) isnumeric(x) && isscalar(x) && x >= 1);
    addParameter(p, 'MinDelta', 0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
    addParameter(p, 'Label', 'validation', @(s) ischar(s) || isstring(s));
    parse(p, varargin{:});

    targetAccuracy = double(p.Results.TargetAccuracy);
    minEpochs = double(p.Results.MinEpochs);
    patienceChecks = double(p.Results.PatienceChecks);
    minDelta = double(p.Results.MinDelta);
    label = char(string(p.Results.Label));

    bestAccuracy = -inf;
    bestEpoch = 0;
    lastValidationEpoch = 0;
    staleChecks = 0;
    stopRequested = false;
    stopReason = '';

    stopper = struct();
    stopper.OutputFcn = @outputFcn;
    stopper.GetState = @getState;

    function stop = outputFcn(info)
        stop = false;
        if stopRequested
            stop = true;
            return;
        end
        if ~isfield(info, 'State') || strcmpi(info.State, 'start') || strcmpi(info.State, 'done')
            return;
        end
        if ~isfield(info, 'ValidationAccuracy') || isempty(info.ValidationAccuracy) || isnan(info.ValidationAccuracy)
            return;
        end
        if info.Epoch == lastValidationEpoch
            return;
        end
        lastValidationEpoch = info.Epoch;
        valAcc = double(info.ValidationAccuracy) / 100;

        if valAcc > bestAccuracy + minDelta
            bestAccuracy = valAcc;
            bestEpoch = info.Epoch;
            staleChecks = 0;
        else
            staleChecks = staleChecks + 1;
        end

        if info.Epoch >= minEpochs && isfinite(targetAccuracy) && valAcc >= targetAccuracy
            stopRequested = true;
            stopReason = sprintf('%s accuracy reached %.2f%% at epoch %d (target %.2f%%).', ...
                label, valAcc * 100, info.Epoch, targetAccuracy * 100);
            fprintf('Early stopping: %s\n', stopReason);
            stop = true;
            return;
        end

        if info.Epoch >= minEpochs && isfinite(patienceChecks) && staleChecks >= patienceChecks
            stopRequested = true;
            stopReason = sprintf(['%s accuracy plateaued at %.2f%% after %d validation checks ', ...
                '(best epoch %d).'], label, bestAccuracy * 100, staleChecks, bestEpoch);
            fprintf('Early stopping: %s\n', stopReason);
            stop = true;
        end
    end

    function s = getState()
        s = struct( ...
            'bestAccuracy', bestAccuracy, ...
            'bestEpoch', bestEpoch, ...
            'lastValidationEpoch', lastValidationEpoch, ...
            'staleChecks', staleChecks, ...
            'stopRequested', stopRequested, ...
            'stopReason', stopReason, ...
            'targetAccuracy', targetAccuracy, ...
            'minEpochs', minEpochs, ...
            'patienceChecks', patienceChecks, ...
            'minDelta', minDelta ...
        );
    end
end
