function outPath = ResultsArtifactPath(projectRoot, artifactKind, artifactGroup, fileName, subfolder)
%% ResultsArtifactPath - Canonical location for saved result artifacts.
%
% artifactKind:  'figures' | 'metrics' | 'logs'
% artifactGroup: 'binary' | 'multiclass' | 'pipeline'
%
% Optional fifth argument subfolder: when non-empty, results are placed under
%   results/<kind>/<group>/<subfolder>/
% (used for per-session replay galleries under pipeline/).

    artifactKind = char(string(artifactKind));
    artifactGroup = char(string(artifactGroup));
    fileName = char(string(fileName));
    if nargin < 5 || isempty(subfolder)
        subfolder = '';
    else
        subfolder = char(string(subfolder));
    end

    validKinds = {'figures', 'metrics', 'logs'};
    validGroups = {'binary', 'multiclass', 'pipeline'};

    if ~ismember(artifactKind, validKinds)
        error('Unsupported artifact kind: %s', artifactKind);
    end
    if ~ismember(artifactGroup, validGroups)
        error('Unsupported artifact group: %s', artifactGroup);
    end

    if isempty(subfolder)
        outDir = fullfile(projectRoot, 'results', artifactKind, artifactGroup);
    else
        outDir = fullfile(projectRoot, 'results', artifactKind, artifactGroup, subfolder);
    end
    if exist(outDir, 'dir') ~= 7
        mkdir(outDir);
    end

    outPath = fullfile(outDir, fileName);
end
