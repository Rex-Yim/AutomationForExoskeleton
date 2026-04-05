% Run the binary LSTM training and evaluation flow for USC-HAD and HuGaDB.
% Writes dataset-tagged models, figures, and metrics, then promotes the
% HuGaDB model to the default pipeline artifact path.

clc;

here = fileparts(mfilename('fullpath'));
projectRoot = fileparts(here);
addpath(fullfile(projectRoot, 'config'));
addpath(genpath(fullfile(projectRoot, 'src')));
addpath(here);

cfg = ExoConfig();
modelsDir = fullfile(projectRoot, 'models');
if ~exist(modelsDir, 'dir')
    mkdir(modelsDir);
end
uscModelPath = fullfile(projectRoot, cfg.FILE.BINARY_LSTM_USCHAD);
hugadbModelPath = fullfile(projectRoot, cfg.FILE.BINARY_LSTM_HUGADB);
defaultModelPath = fullfile(projectRoot, cfg.FILE.BINARY_LSTM);

fprintf('================================================================\n');
fprintf('   Binary LSTM dataset ablation: USC-HAD -> HuGaDB\n');
fprintf('================================================================\n\n');

%% 1 — USC-HAD
TrainLstmBinary('IncludeUSCHAD', true, 'IncludeHuGaDB', false, ...
    'ExcludeHuGaDBSubjects', {}, ...
    'ModelPath', uscModelPath);
EvaluateLstmConfusion('IncludeUSCHAD', true, 'IncludeHuGaDB', false, ...
    'ExcludeHuGaDBSubjects', {}, ...
    'ModelPath', uscModelPath, ...
    'OutputTag', 'usc_had');

%% 2 — HuGaDB (match SVM: exclude simulation held-out subjects)
TrainLstmBinary('IncludeUSCHAD', false, 'IncludeHuGaDB', true, ...
    'ExcludeHuGaDBSubjects', cfg.HUGADB.HELDOUT_SUBJECTS, ...
    'ModelPath', hugadbModelPath);
EvaluateLstmConfusion('IncludeUSCHAD', false, 'IncludeHuGaDB', true, ...
    'ExcludeHuGaDBSubjects', cfg.HUGADB.HELDOUT_SUBJECTS, ...
    'ModelPath', hugadbModelPath, ...
    'OutputTag', 'hugadb');

if ~strcmp(hugadbModelPath, defaultModelPath)
    copyfile(hugadbModelPath, defaultModelPath);
end
fprintf('\nDefault binary LSTM model (pipeline/report): %s\n', defaultModelPath);
fprintf('Kept HuGaDB LSTM outputs at tag-specific paths for report/poster traceability.\n');

fprintf('\n================================================================\n');
fprintf('   Binary LSTM ablation complete.\n');
fprintf('================================================================\n');
