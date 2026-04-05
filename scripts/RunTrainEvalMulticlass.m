%% RunTrainEvalMulticlass — train ECOC models (USC-HAD 12 + HuGaDB 12) then 5-fold OOF confusion figures
cfg = ExoConfig();
TrainSvmMulticlass('Dataset', 'usc_had');
EvaluateMulticlassConfusion('Dataset', 'usc_had');
TrainSvmMulticlass('Dataset', 'hugadb', 'HuGaDBSessionProtocols', cfg.HUGADB.DEFAULT_PROTOCOLS);
EvaluateMulticlassConfusion('Dataset', 'hugadb', 'HuGaDBSessionProtocols', cfg.HUGADB.DEFAULT_PROTOCOLS);
