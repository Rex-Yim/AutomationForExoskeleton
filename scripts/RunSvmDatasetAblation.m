%% RunSvmDatasetAblation.m
% --------------------------------------------------------------------------
% Runs three training/evaluation setups in order:
%   1) USC-HAD only     2) HuGaDB only     3) merged (both)
%
% Writes tagged models under models/ and tagged figures/metrics under results/.
% After completion, copies the merged model and merged confusion outputs to the
% default paths used by RunExoskeletonPipeline / LaTeX (Binary_SVM_Model.mat,
% svm_confusion_matrix.png, svm_evaluation_metrics.mat).
% --------------------------------------------------------------------------
% PREREQ: startup or paths to config + src; usc_had_dataset.mat and/or
%         hugadb_dataset.mat from LoadUSCHAD / LoadHuGaDB.
% USAGE:  >> RunSvmDatasetAblation
% --------------------------------------------------------------------------

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
resultsDir = fullfile(projectRoot, 'results');
if ~exist(resultsDir, 'dir')
    mkdir(resultsDir);
end

defaultModel = fullfile(projectRoot, cfg.FILE.SVM_MODEL);

fprintf('================================================================\n');
fprintf('   SVM dataset ablation: USC-HAD only -> HuGaDB only -> merged\n');
fprintf('================================================================\n\n');

%% 1 — USC-HAD only
EvaluateSvmConfusion('IncludeUSCHAD', true, 'IncludeHuGaDB', false, ...
    'OutputTag', 'usc_had_only', ...
    'SaveModelPath', fullfile(modelsDir, 'Binary_SVM_Model_usc_had_only.mat'));

%% 2 — HuGaDB only
EvaluateSvmConfusion('IncludeUSCHAD', false, 'IncludeHuGaDB', true, ...
    'OutputTag', 'hugadb_only', ...
    'SaveModelPath', fullfile(modelsDir, 'Binary_SVM_Model_hugadb_only.mat'));

%% 3 — Merged
mergedModelPath = fullfile(modelsDir, 'Binary_SVM_Model_merged.mat');
EvaluateSvmConfusion('IncludeUSCHAD', true, 'IncludeHuGaDB', true, ...
    'OutputTag', 'merged', ...
    'SaveModelPath', mergedModelPath);

%% Default paths for pipeline + legacy figure names
copyfile(mergedModelPath, defaultModel);
fprintf('\nDefault SVM model (pipeline): %s\n', defaultModel);

mergedPng = fullfile(resultsDir, 'svm_confusion_matrix_merged.png');
mergedMat = fullfile(resultsDir, 'svm_evaluation_metrics_merged.mat');
copyfile(mergedPng, fullfile(resultsDir, 'svm_confusion_matrix.png'));
copyfile(mergedMat, fullfile(resultsDir, 'svm_evaluation_metrics.mat'));
fprintf('Copied merged confusion figure + metrics to svm_confusion_matrix.png / svm_evaluation_metrics.mat\n');

fprintf('\n================================================================\n');
fprintf('   Ablation complete.\n');
fprintf('================================================================\n');
