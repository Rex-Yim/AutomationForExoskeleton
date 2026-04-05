%% RunTrainEvalLstmMulticlass
% Train multiclass LSTM models on USC-HAD and HuGaDB, then export holdout
% confusion figures and metrics for each dataset separately.

cfg = ExoConfig();

TrainLstmMulticlass('Dataset', 'usc_had');
EvaluateLstmMulticlassConfusion('Dataset', 'usc_had');
TrainLstmMulticlass('Dataset', 'hugadb', ...
    'HuGaDBSessionProtocols', cfg.HUGADB.DEFAULT_PROTOCOLS, ...
    'EarlyStopTarget', 0.88, ...
    'EarlyStopMinEpochs', 3, ...
    'EarlyStopPatience', 4);
EvaluateLstmMulticlassConfusion('Dataset', 'hugadb', 'HuGaDBSessionProtocols', cfg.HUGADB.DEFAULT_PROTOCOLS);
