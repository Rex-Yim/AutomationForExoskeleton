%% LoadHuGaDB.m
% --------------------------------------------------------------------------
% FUNCTION: hugadb = LoadHuGaDB(rawDir)
% PURPOSE:  Parse HuGaDB v2 .txt trials and save hugadb_dataset.mat for
%           training (all six on-body IMUs per row, per-sample activity IDs).
% --------------------------------------------------------------------------
% SENSOR:   Six IMUs in file order: rf, rs, rt, lf, ls, lt (acc xyz, gyro xyz each).
% UNITS:    acc columns scaled by /1000 -> m/s^2 (HuGaDB int format). Gyro deg/s -> rad/s.
% --------------------------------------------------------------------------

function hugadb = LoadHuGaDB(rawDir)

    loaderDir = fileparts(mfilename('fullpath'));
    if nargin < 1 || isempty(rawDir)
        rawDir = fullfile(loaderDir, 'HuGaDB_v2_raw');
    end

    if ~isfolder(rawDir)
        error('HuGaDB raw folder not found: %s', rawDir);
    end

    files = dir(fullfile(rawDir, '**/*.txt'));
    if isempty(files)
        error('No HuGaDB .txt files under %s', rawDir);
    end

    hugadb = struct();
    minSamples = 100; % align with ExoConfig.WINDOW_SIZE — shorter trials yield no windows

    fprintf('Loading %d HuGaDB .txt files (recursive)...\n', numel(files));

    for i = 1:numel(files)
        if files(i).isdir
            continue;
        end
        fp = fullfile(files(i).folder, files(i).name);
        try
            M = readmatrix(fp, 'FileType', 'text', 'NumHeaderLines', 4, 'Delimiter', '\t');
        catch
            try
                M = dlmread(fp, '\t', 4, 0); %#ok<DLMRD>
            catch ME
                warning('Skipping %s: %s', files(i).name, ME.message);
                continue;
            end
        end

        if size(M, 2) < 39
            warning('Skipping %s: expected >=39 columns, got %d', files(i).name, size(M, 2));
            continue;
        end

        n = size(M, 1);
        if n < minSamples
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
        key = matlab.lang.makeValidName(['s_' sid], 'ReplacementStyle', 'underscore');
        hugadb.(key).acc = acc;
        hugadb.(key).gyro = gyro;
        hugadb.(key).label_full = act;
        hugadb.(key).fs = 100;
        hugadb.(key).imuOrder = {'rf', 'rs', 'rt', 'lf', 'ls', 'lt'};
    end

    out = fullfile(loaderDir, 'hugadb_dataset.mat');
    save(out, 'hugadb', '-v7.3');
    fprintf('HuGaDB saved: %s (%d sessions).\n', out, numel(fieldnames(hugadb)));
end
