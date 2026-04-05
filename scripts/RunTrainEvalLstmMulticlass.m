%% RunTrainEvalLstmMulticlass
% Train multiclass LSTM models on USC-HAD and HuGaDB, then export holdout
% confusion figures and metrics for each dataset separately.

TrainLstmMulticlass('Dataset', 'usc_had');
EvaluateLstmMulticlassConfusion('Dataset', 'usc_had');
TrainLstmMulticlass('Dataset', 'hugadb');
EvaluateLstmMulticlassConfusion('Dataset', 'hugadb');
