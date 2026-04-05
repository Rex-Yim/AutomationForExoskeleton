function TrainSvmMulticlass(varargin)
%% TrainSvmMulticlass.m — ECOC RBF-SVM, native labels (USC-HAD 12 or HuGaDB 12)

scriptDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptDir);
addpath(fullfile(projectRoot, 'config'));
addpath(genpath(fullfile(projectRoot, 'src')));

cfg = ExoConfig();

p = inputParser;
addParameter(p, 'Dataset', 'hugadb', @(s) ischar(s) || isstring(s));
addParameter(p, 'HuGaDBSessionProtocols', cfg.HUGADB.DEFAULT_PROTOCOLS, @(x) isempty(x) || ischar(x) || isstring(x) || iscell(x));
parse(p, varargin{:});

ds = lower(char(p.Results.Dataset));
protocolSelection = NormalizeHuGaDBProtocolSelection(p.Results.HuGaDBSessionProtocols);
if ~ismember(ds, {'usc_had', 'hugadb'})
    error('Dataset must be ''usc_had'' or ''hugadb''.');
end

if strcmp(ds, 'usc_had')
    saveRel = cfg.FILE.MULTICLASS_SVM_USCHAD;
    K = ActivityClassRegistry.USCHAD_N_CLASSES;
    nameAt = @(c) ActivityClassRegistry.classNameUSCHAD(c);
else
    saveRel = cfg.FILE.MULTICLASS_SVM_HUGADB;
    K = ActivityClassRegistry.HUGADB_N_CLASSES;
    nameAt = @(c) ActivityClassRegistry.classNameHuGaDB(c);
end

fprintf('===========================================================\n');
fprintf('   Multiclass SVM (ECOC) — %s — %d activities\n', ds, K);
fprintf('===========================================================\n');

try
    [featuresAll, labelsAll, ModelMetadata] = PrepareTrainingDataMulticlass(cfg, ...
        'Dataset', ds, 'HuGaDBSessionProtocols', protocolSelection);
catch ME
    error('Multiclass data preparation failed: %s', ME.message);
end

fprintf('Windows: %d | features: %d | classes present: %s\n', ...
    size(featuresAll, 1), size(featuresAll, 2), mat2str(unique(labelsAll)'));
if strcmp(ds, 'hugadb') && ~isempty(protocolSelection)
    fprintf('HuGaDB session protocols used: %s\n', strjoin(protocolSelection, ', '));
end

for c = 1:K
    fprintf('  Class %2d %-18s : %d windows\n', c, nameAt(c), sum(labelsAll == c));
end

fprintf('\nTraining ECOC (one-vs-all, RBF learners)...\n');
t = templateSVM('KernelFunction', 'rbf', 'Standardize', true, 'BoxConstraint', 1);
ECOCModel = fitcecoc(featuresAll, labelsAll, 'Learners', t, 'Coding', 'onevsall');
fprintf('ECOC fit on full window set (no CV here — use EvaluateMulticlassConfusion).\n');

savePath = fullfile(projectRoot, saveRel);
[saveDir, ~] = fileparts(savePath);
if ~isempty(saveDir) && ~exist(saveDir, 'dir')
    mkdir(saveDir);
end

save(savePath, 'ECOCModel', 'ModelMetadata', 'ds', '-v7.3');
fprintf('Saved: %s\n', savePath);
fprintf('===========================================================\n');
end
