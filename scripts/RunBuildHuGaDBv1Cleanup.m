%% RunBuildHuGaDBv1Cleanup — in-place: corrupted gyros → "na" under v1_cleanup_github
%
% Canonical corpus (flat): data/HuGaDB/v1_cleanup_github/*.txt
%
% Official per-IMU gyro flags: data/HuGaDB/hugadb_official_readme_gyro_corruption_matrix.csv
%
% Overwrites each .txt in place (atomic temp + move). Malformed data rows become an all-"na" row.

clc;
here = fileparts(mfilename('fullpath'));
projectRoot = fileparts(here);
cd(projectRoot);

addpath(genpath(fullfile(projectRoot, 'src')));

hugadbDir = fullfile(projectRoot, 'data', 'HuGaDB');
githubRaw = fullfile(hugadbDir, 'v1_cleanup_github');
if ~isfolder(githubRaw)
    alt = {
        fullfile(hugadbDir, 'v1_cleanup_github', 'HuGaDB_v1_github_raw')
        fullfile(hugadbDir, 'v1_cleanup_github', 'HuGaDB_source_github_v1')
        fullfile(hugadbDir, 'v1_raw')
        fullfile(hugadbDir, 'v1_raw', 'HuGaDB_source_github_v1')
        fullfile(hugadbDir, 'v1_raw', 'HuGaDB_v1_github_raw')
        fullfile(hugadbDir, 'v1', 'HuGaDB_source_github_v1')
        fullfile(hugadbDir, 'HuGaDB_source_github_v1')
        fullfile(hugadbDir, 'HuGaDB_v1_github_raw')
        };
    for k = 1:numel(alt)
        if isfolder(alt{k})
            githubRaw = alt{k};
            break;
        end
    end
end

matrixFile = fullfile(hugadbDir, 'hugadb_official_readme_gyro_corruption_matrix.csv');

stats = BuildHuGaDBv1Cleanup('GithubRawDir', githubRaw, 'InPlace', true, ...
    'CorruptionMatrixFile', matrixFile, 'MissingToken', 'na');

fprintf(['HuGaDB v1_cleanup (in-place) done.\n' ...
    '  files written: %d\n' ...
    '  data rows: %d\n' ...
    '  malformed rows → all na: %d\n' ...
    '  gyro cells set to na: %d\n' ...
    '  directory: %s\n'], ...
    stats.nFiles, stats.nRowsTotal, stats.nRowsMalformed, stats.nGyroCellsMarked, githubRaw);
