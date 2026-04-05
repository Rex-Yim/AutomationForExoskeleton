% Run the binary SVM training and evaluation flow for USC-HAD and HuGaDB.
% Writes dataset-tagged models, figures, and metrics, then promotes the
% HuGaDB model to the default pipeline artifact path.

clc;

here = fileparts(mfilename('fullpath'));
projectRoot = fileparts(here);
addpath(fullfile(projectRoot, 'config'));
addpath(genpath(fullfile(projectRoot, 'src')));

cfg = ExoConfig();
modelsDir = fullfile(projectRoot, 'models');
if ~exist(modelsDir, 'dir')
    mkdir(modelsDir);
end
defaultModel = fullfile(projectRoot, cfg.FILE.SVM_MODEL);

fprintf('================================================================\n');
fprintf('   SVM dataset ablation: USC-HAD -> HuGaDB\n');
fprintf('================================================================\n\n');

%% 1 — USC-HAD
EvaluateSvmConfusion('IncludeUSCHAD', true, 'IncludeHuGaDB', false, ...
    'ExcludeHuGaDBSubjects', {}, ...
    'OutputTag', 'usc_had', ...
    'SaveModelPath', fullfile(modelsDir, 'Binary_SVM_Model_usc_had_only.mat'));

%% 2 — HuGaDB (exclude simulation held-out subjects, same default as LSTM)
EvaluateSvmConfusion('IncludeUSCHAD', false, 'IncludeHuGaDB', true, ...
    'ExcludeHuGaDBSubjects', cfg.HUGADB.HELDOUT_SUBJECTS, ...
    'HuGaDBSessionProtocols', cfg.HUGADB.DEFAULT_PROTOCOLS, ...
    'OutputTag', 'hugadb_streaming', ...
    'SaveModelPath', fullfile(modelsDir, 'Binary_SVM_Model_hugadb_only.mat'));

%% Default path for the active pipeline model
hugadbModelPath = fullfile(modelsDir, 'Binary_SVM_Model_hugadb_only.mat');
if ~sameCanonicalPath(hugadbModelPath, defaultModel)
    copyfile(hugadbModelPath, defaultModel);
end
fprintf('\nDefault SVM model (pipeline/report): %s\n', defaultModel);
fprintf('Kept HuGaDB confusion figure + metrics at dataset-tagged paths for report/poster traceability.\n');

fprintf('\n================================================================\n');
fprintf('   Ablation complete.\n');
fprintf('================================================================\n');

function tf = sameCanonicalPath(pathA, pathB)
    canonA = char(java.io.File(pathA).getCanonicalPath());
    canonB = char(java.io.File(pathB).getCanonicalPath());
    tf = strcmp(canonA, canonB);
end
