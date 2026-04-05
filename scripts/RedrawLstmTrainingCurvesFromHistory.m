function RedrawLstmTrainingCurvesFromHistory(matPath)
% RedrawLstmTrainingCurvesFromHistory — rebuild TXT+PNG from a saved *_history.mat (no retrain).
    if nargin < 1 || isempty(matPath)
        error('Usage: RedrawLstmTrainingCurvesFromHistory(''/path/to/lstm_*_training_*_history.mat'')');
    end
    if ~exist(matPath, 'file')
        error('Not found: %s', matPath);
    end
    S = load(matPath, 'trainingHistory', 'tag', 'modelKind', 'extra');
    if ~isfield(S, 'trainingHistory')
        error('File missing trainingHistory: %s', matPath);
    end
    tag = 'unknown';
    if isfield(S, 'tag')
        tag = S.tag;
    end
    modelKind = 'binary';
    if isfield(S, 'modelKind')
        modelKind = S.modelKind;
    end
    extra = struct();
    if isfield(S, 'extra')
        extra = S.extra;
    end
    here = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(here);
    addpath(genpath(fullfile(projectRoot, 'src')));
    addpath(here);
    SaveLstmTrainingArtifacts(projectRoot, modelKind, tag, S.trainingHistory, extra);
end
