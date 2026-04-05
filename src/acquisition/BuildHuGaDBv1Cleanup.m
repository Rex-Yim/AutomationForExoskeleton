function stats = BuildHuGaDBv1Cleanup(varargin)
% BuildHuGaDBv1Cleanup  Copy GitHub HuGaDB v1 .txt corpus with corrupted gyros set to a missing token.
%
%   For each session listed in the official README gyro corruption CSV, gyro columns for
%   corrupted IMUs are replaced with the token (default 'na') on every data row. Rows that
%   do not parse as 39 numeric tab-separated fields are replaced entirely by 39 missing tokens.
%
%   Name-Value:
%     'GithubRawDir'          — folder containing HuGaDB_v1_*.txt (recursive scan optional)
%     'OutputDir'             — mirror tree of cleaned .txt files (omit if InPlace true)
%     'InPlace'               — if true, overwrite files under GithubRawDir (OutputDir ignored)
%     'CorruptionMatrixFile'  — hugadb_official_readme_gyro_corruption_matrix.csv
%     'MissingToken'          — default 'na'
%
%   Returns struct with fields nFiles, nRowsTotal, nRowsMalformed, nGyroCellsMarked.

    p = inputParser;
    addParameter(p, 'GithubRawDir', '', @(s) ischar(s) || isstring(s));
    addParameter(p, 'OutputDir', '', @(s) ischar(s) || isstring(s));
    addParameter(p, 'InPlace', false, @islogical);
    addParameter(p, 'CorruptionMatrixFile', '', @(s) ischar(s) || isstring(s));
    addParameter(p, 'MissingToken', 'na', @(s) ischar(s) || isstring(s));
    parse(p, varargin{:});

    githubRaw = char(p.Results.GithubRawDir);
    outRoot = char(p.Results.OutputDir);
    inPlace = logical(p.Results.InPlace);
    matrixFile = char(p.Results.CorruptionMatrixFile);
    miss = char(p.Results.MissingToken);

    if ~isfolder(githubRaw)
        error('BuildHuGaDBv1Cleanup: GithubRawDir not found: %s', githubRaw);
    end
    if inPlace
        outRoot = githubRaw;
    elseif isempty(outRoot)
        error('BuildHuGaDBv1Cleanup: OutputDir is required unless InPlace is true.');
    end
    if isempty(matrixFile) || ~isfile(matrixFile)
        error('BuildHuGaDBv1Cleanup: CorruptionMatrixFile must exist: %s', matrixFile);
    end

    corruptMap = HuGaDBGyroCorruptionMatrix('load', matrixFile);

    files = dir(fullfile(githubRaw, '**/*.txt'));
    if isempty(files)
        files = dir(fullfile(githubRaw, '*.txt'));
    end

    stats = struct('nFiles', 0, 'nRowsTotal', 0, 'nRowsMalformed', 0, 'nGyroCellsMarked', 0);
    nHeader = 4;
    nCol = 39;
    tab = char(9);

    for i = 1:numel(files)
        if files(i).isdir
            continue;
        end
        fp = fullfile(files(i).folder, files(i).name);
        rel = erase(fp, [githubRaw filesep]);
        rel = strrep(rel, '\', filesep);
        outPath = fullfile(outRoot, rel);
        outFolder = fileparts(outPath);
        if ~isfolder(outFolder)
            mkdir(outFolder);
        end

        txt = fileread(fp);
        lines = splitlines(txt);
        if isempty(lines)
            warning('BuildHuGaDBv1Cleanup: empty file skipped: %s', fp);
            continue;
        end

        key = lower(files(i).name);
        if isKey(corruptMap, key)
            gmask = logical(corruptMap(key));
        else
            gmask = false(1, 6);
        end

        outLines = cell(size(lines));
        for k = 1:min(nHeader, numel(lines))
            outLines{k} = lines{k};
        end

        for k = (nHeader + 1):numel(lines)
            line = lines{k};
            if strlength(strtrim(line)) == 0
                outLines{k} = line;
                continue;
            end
            stats.nRowsTotal = stats.nRowsTotal + 1;
            parts = string(split(line, tab));
            if numel(parts) ~= nCol
                outLines{k} = rowMissing(miss, nCol);
                stats.nRowsMalformed = stats.nRowsMalformed + 1;
                continue;
            end
            nums = str2double(parts);
            if any(isnan(nums))
                outLines{k} = rowMissing(miss, nCol);
                stats.nRowsMalformed = stats.nRowsMalformed + 1;
                continue;
            end
            tok = string(miss);
            for s = 0:5
                if s + 1 <= numel(gmask) && gmask(s + 1)
                    idx = s * 6 + (4:6);
                    parts(idx) = tok;
                    stats.nGyroCellsMarked = stats.nGyroCellsMarked + 3;
                end
            end
            outLines{k} = char(strjoin(parts, tab));
        end

        if ~writeAtomicTxt(outPath, outLines)
            warning('BuildHuGaDBv1Cleanup: could not write: %s', outPath);
            continue;
        end

        stats.nFiles = stats.nFiles + 1;
    end
end

function s = rowMissing(miss, nCol)
    tab = char(9);
    parts = repmat({miss}, 1, nCol);
    s = strjoin(parts, tab);
end

function ok = writeAtomicTxt(outPath, outLines)
    ok = false;
    outFolder = fileparts(outPath);
    if ~isempty(outFolder) && ~isfolder(outFolder)
        mkdir(outFolder);
    end
    [~, base, ext] = fileparts(outPath);
    tmpPath = fullfile(outFolder, ['.tmp_write_' sprintf('%d_', randi(1e9)) base ext]);
    fid = fopen(tmpPath, 'w');
    if fid < 0
        return;
    end
    cleanupFid = onCleanup(@() fclose(fid));
    for k = 1:numel(outLines)
        fprintf(fid, '%s\n', outLines{k});
    end
    clear cleanupFid;
    try
        movefile(tmpPath, outPath, 'f');
        ok = true;
    catch
        if isfile(tmpPath)
            delete(tmpPath);
        end
    end
end
