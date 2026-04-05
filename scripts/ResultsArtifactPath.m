function outPath = ResultsArtifactPath(projectRoot, artifactKind, artifactGroup, fileName)
%% ResultsArtifactPath - Canonical location for saved result artifacts.
%
% artifactKind:  'figures' | 'metrics'
% artifactGroup: 'binary' | 'multiclass' | 'pipeline'

    artifactKind = char(string(artifactKind));
    artifactGroup = char(string(artifactGroup));
    fileName = char(string(fileName));

    validKinds = {'figures', 'metrics'};
    validGroups = {'binary', 'multiclass', 'pipeline'};

    if ~ismember(artifactKind, validKinds)
        error('Unsupported artifact kind: %s', artifactKind);
    end
    if ~ismember(artifactGroup, validGroups)
        error('Unsupported artifact group: %s', artifactGroup);
    end

    outDir = fullfile(projectRoot, 'results', artifactKind, artifactGroup);
    if exist(outDir, 'dir') ~= 7
        mkdir(outDir);
    end

    outPath = fullfile(outDir, fileName);
end
