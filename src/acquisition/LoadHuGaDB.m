% Parse HuGaDB raw trials and save `hugadb_dataset.mat` for training.
% The loader preserves all six on-body IMUs per sample and converts
% accelerometer and gyroscope channels to SI units.
%
% Single source: GitHub v1 corpus under data/HuGaDB/v1_cleanup_github/ (flat .txt; legacy nested paths below).
% Per-IMU corrupted gyros (official README matrix CSV) are zeroed when loading from raw GitHub v1;
% applying twice is a no-op. Sessions with all six IMU gyros marked corrupted are retained so
% accelerometer-only classes (for example, sitting-in-car) are still available to downstream tasks.
% Optional hugadb_manifest.json attaches provenance and sessionProtocol.

function hugadb = LoadHuGaDB(rawDir)

    here = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(fileparts(here));
    hugadbDir = fullfile(repoRoot, 'data', 'HuGaDB');

    v1CleanupFlat = fullfile(hugadbDir, 'v1_cleanup_github');
    v1CleanupAlt = fullfile(hugadbDir, 'v1_cleanup_github', 'HuGaDB_v1_github_raw');
    v1CleanupNestedLegacy = fullfile(hugadbDir, 'v1_cleanup_github', 'HuGaDB_source_github_v1');
    v1RawFlat = fullfile(hugadbDir, 'v1_raw');
    v1RawNestedGh = fullfile(hugadbDir, 'v1_raw', 'HuGaDB_source_github_v1');
    v1RawNestedAlt = fullfile(hugadbDir, 'v1_raw', 'HuGaDB_v1_github_raw');
    nestedGhLegacy = fullfile(hugadbDir, 'v1', 'HuGaDB_source_github_v1');
    nestedAltGhLegacy = fullfile(hugadbDir, 'v1', 'HuGaDB_v1_github_raw');
    flatGh = fullfile(hugadbDir, 'HuGaDB_source_github_v1');
    flatAltGh = fullfile(hugadbDir, 'HuGaDB_v1_github_raw');
    if isfolder(v1CleanupFlat)
        fallbackDir = v1CleanupFlat;
    elseif isfolder(v1CleanupAlt)
        fallbackDir = v1CleanupAlt;
    elseif isfolder(v1CleanupNestedLegacy)
        fallbackDir = v1CleanupNestedLegacy;
    elseif isfolder(v1RawFlat)
        fallbackDir = v1RawFlat;
    elseif isfolder(v1RawNestedGh)
        fallbackDir = v1RawNestedGh;
    elseif isfolder(v1RawNestedAlt)
        fallbackDir = v1RawNestedAlt;
    elseif isfolder(nestedGhLegacy)
        fallbackDir = nestedGhLegacy;
    elseif isfolder(nestedAltGhLegacy)
        fallbackDir = nestedAltGhLegacy;
    elseif isfolder(flatGh)
        fallbackDir = flatGh;
    elseif isfolder(flatAltGh)
        fallbackDir = flatAltGh;
    else
        fallbackDir = v1CleanupFlat;
    end

    if nargin < 1 || isempty(rawDir)
        rawDir = fallbackDir;
        for cand = {
                v1CleanupFlat, v1CleanupAlt, v1CleanupNestedLegacy, v1RawFlat, v1RawNestedGh, ...
                v1RawNestedAlt, nestedGhLegacy, nestedAltGhLegacy, flatGh, flatAltGh
            }
            d = cand{1};
            if ~isfolder(d)
                continue;
            end
            probe = dir(fullfile(d, '**/*.txt'));
            if isempty(probe)
                probe = dir(fullfile(d, '*.txt'));
            end
            if ~isempty(probe)
                rawDir = d;
                break;
            end
        end
    end

    if ~isfolder(rawDir)
        error('HuGaDB raw folder not found: %s', rawDir);
    end

    files = dir(fullfile(rawDir, '**/*.txt'));
    if isempty(files)
        error('No HuGaDB .txt files under %s', rawDir);
    end

    manifestPath = fullfile(rawDir, 'hugadb_manifest.json');
    if ~isfile(manifestPath)
        manifestPath = '';
    end
    [provMap, protocolMap] = loadHuGaDBManifestMaps(manifestPath);

    corruptCsv = fullfile(hugadbDir, 'hugadb_official_readme_gyro_corruption_matrix.csv');
    corruptMap = HuGaDBGyroCorruptionMatrix('load', corruptCsv);

    cfg = ExoConfig();
    hugadb = struct();
    hugadb_metadata = struct();
    hugadb_metadata.qualityReport = HuGaDBInitQualityReport();
    minSamples = cfg.HUGADB.QUALITY.MIN_VALID_SAMPLES;

    fprintf('Loading %d HuGaDB .txt files (recursive) from %s ...\n', numel(files), rawDir);

    for i = 1:numel(files)
        if files(i).isdir
            continue;
        end
        fp = fullfile(files(i).folder, files(i).name);
        hugadb_metadata.qualityReport.nSessionsScanned = hugadb_metadata.qualityReport.nSessionsScanned + 1;
        try
            M = readmatrix(fp, 'FileType', 'text', 'NumHeaderLines', 4, 'Delimiter', '\t', ...
                'TreatAsMissing', {'na', 'NA', 'NaN'});
        catch
            try
                M = dlmread(fp, '\t', 4, 0); %#ok<DLMRD>
            catch ME
                warning('Skipping %s: %s', files(i).name, ME.message);
                hugadb_metadata.qualityReport.nSessionsSkipped = hugadb_metadata.qualityReport.nSessionsSkipped + 1;
                hugadb_metadata.qualityReport = HuGaDBAppendQualityReason(hugadb_metadata.qualityReport, ...
                    'session', 'read_failure');
                continue;
            end
        end

        if size(M, 2) < 39
            warning('Skipping %s: expected >=39 columns, got %d', files(i).name, size(M, 2));
            hugadb_metadata.qualityReport.nSessionsSkipped = hugadb_metadata.qualityReport.nSessionsSkipped + 1;
            hugadb_metadata.qualityReport = HuGaDBAppendQualityReason(hugadb_metadata.qualityReport, ...
                'session', 'short_column_count');
            continue;
        end

        key = lower(files(i).name);
        if isKey(corruptMap, key)
            gmask = corruptMap(key);
            M = HuGaDBGyroCorruptionMatrix('applyRaw', M, gmask);
        else
            gmask = false(1, 6);
        end

        n = size(M, 1);
        if n < minSamples
            hugadb_metadata.qualityReport.nSessionsSkipped = hugadb_metadata.qualityReport.nSessionsSkipped + 1;
            hugadb_metadata.qualityReport = HuGaDBAppendQualityReason(hugadb_metadata.qualityReport, ...
                'session', 'too_few_samples');
            continue;
        end

        nImu = 6;
        acc = zeros(n, 3, nImu);
        gyro = zeros(n, 3, nImu);
        for s = 0:(nImu - 1)
            c0 = s * 6 + 1;
            acc(:, :, s + 1) = double(M(:, c0:c0 + 2)) / 1000;
            gyro(:, :, s + 1) = deg2rad(double(M(:, c0 + 3:c0 + 5)));
        end

        act = double(M(:, end));

        sid = files(i).name(1:end - 4); % strip .txt
        meta = ParseHuGaDBSessionName(sid);
        key = matlab.lang.makeValidName(['s_' sid], 'ReplacementStyle', 'underscore');
        hugadb.(key).acc = acc;
        hugadb.(key).gyro = gyro;
        hugadb.(key).label_full = act;
        hugadb.(key).fs = 100;
        hugadb.(key).imuOrder = {'rf', 'rs', 'rt', 'lf', 'ls', 'lt'};
        hugadb.(key).subjectId = meta.subjectId;
        hugadb.(key).sessionId = meta.sessionId;
        if ~isempty(meta.activityType)
            hugadb.(key).activityType = meta.activityType;
        end
        if isKey(provMap, sid)
            hugadb.(key).huGaDBProvenance = provMap(sid);
        end
        if isKey(protocolMap, sid)
            hugadb.(key).huGaDBSessionProtocol = protocolMap(sid);
        else
            hugadb.(key).huGaDBSessionProtocol = inferHuGaDBSessionProtocol(files(i).name);
        end
        hugadb.(key).huGaDBCorruptedImuMask = logical(gmask);
        hugadb.(key).huGaDBQuality = struct( ...
            'isQualityRejected', false, ...
            'qualityRejectReason', '', ...
            'nSamplesOriginal', n, ...
            'corruptedImuMask', logical(gmask), ...
            'allGyrosCorrupted', all(gmask), ...
            'qualityCheckedAt', char(datetime('now')), ...
            'sessionProtocol', hugadb.(key).huGaDBSessionProtocol ...
        );
        hugadb_metadata.qualityReport.nSessionsAccepted = hugadb_metadata.qualityReport.nSessionsAccepted + 1;
    end

    out = fullfile(hugadbDir, 'hugadb_dataset.mat');
    save(out, 'hugadb', 'hugadb_metadata', '-v7.3');
    fprintf('HuGaDB saved: %s (%d sessions).\n', out, numel(fieldnames(hugadb)));
    lines = HuGaDBFormatQualityReport(hugadb_metadata.qualityReport);
    for i = 1:numel(lines)
        fprintf('%s\n', lines{i});
    end
end

function [provMap, protocolMap] = loadHuGaDBManifestMaps(manifestPath)
    provMap = containers.Map('KeyType', 'char', 'ValueType', 'char');
    protocolMap = containers.Map('KeyType', 'char', 'ValueType', 'char');
    if ~isfile(manifestPath)
        return;
    end
    try
        txt = fileread(manifestPath);
        L = jsondecode(txt);
    catch
        return;
    end
    if isempty(L)
        return;
    end
    for k = 1:numel(L)
        item = L(k);
        if ~isfield(item, 'outputFile') || numel(char(string(item.outputFile))) < 5
            continue;
        end
        of = char(string(item.outputFile));
        if ~endsWith(of, '.txt')
            continue;
        end
        stem = of(1:end - 4);
        if isfield(item, 'provenance')
            provMap(stem) = char(string(item.provenance));
        end
        if isfield(item, 'sessionProtocol')
            protocolMap(stem) = char(string(item.sessionProtocol));
        elseif isfield(item, 'sourceGithubFile')
            src = lower(char(string(item.sourceGithubFile)));
            if contains(src, 'various')
                protocolMap(stem) = 'multi_activity_sequence';
            else
                protocolMap(stem) = 'single_activity';
            end
        end
    end
end

function s = inferHuGaDBSessionProtocol(basename)
    if contains(lower(basename), 'various')
        s = 'multi_activity_sequence';
    else
        s = 'single_activity';
    end
end
