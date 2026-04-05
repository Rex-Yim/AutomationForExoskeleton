%% RunTrainEvalMulticlass — train ECOC models (USC-HAD 12 + HuGaDB 12) then 5-fold OOF confusion figures
TrainSvmMulticlass('Dataset', 'usc_had');
EvaluateMulticlassConfusion('Dataset', 'usc_had');
TrainSvmMulticlass('Dataset', 'hugadb');
EvaluateMulticlassConfusion('Dataset', 'hugadb');
