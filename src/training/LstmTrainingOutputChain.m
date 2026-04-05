function stop = LstmTrainingOutputChain(info, logRecorder, stopper)
% LstmTrainingOutputChain — run training log recorder then early-stop callback.
    logRecorder.OutputFcn(info);
    stop = stopper.OutputFcn(info);
end
