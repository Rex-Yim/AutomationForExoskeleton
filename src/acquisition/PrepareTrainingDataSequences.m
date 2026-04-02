%% PrepareTrainingDataSequences.m
% --------------------------------------------------------------------------
% [XCell, labels_binary, ModelMetadata] = PrepareTrainingDataSequences(cfg, varargin)
% Sliding-window sequences for LSTM: each sample is (6*N_IMU_SLOTS) x WINDOW_SIZE,
% same labeling and sources as PrepareTrainingData.m (USC-HAD + optional HuGaDB).
% NAME-VALUE: 'IncludeUSCHAD', 'IncludeHuGaDB' (same defaults as PrepareTrainingData).
% --------------------------------------------------------------------------

function [XCell, labels_binary, ModelMetadata] = PrepareTrainingDataSequences(cfg, varargin)

    if nargin < 1
        cfg = ExoConfig();
    end

    p = inputParser;
    addParameter(p, 'IncludeUSCHAD', true, @islogical);
    addParameter(p, 'IncludeHuGaDB', true, @islogical);
    parse(p, varargin{:});

    if ~p.Results.IncludeUSCHAD && ~p.Results.IncludeHuGaDB
        error('AutomationForExoskeleton:PrepareTrainingDataSequences:NoSource', ...
            'At least one of IncludeUSCHAD and IncludeHuGaDB must be true.');
    end

    XCell = {};
    labels_binary = [];
    n_usc = 0;
    n_hu = 0;

    nCh = cfg.LOCOMOTION.N_IMU_SLOTS * 6;

    %% --- USC-HAD ---
    if p.Results.IncludeUSCHAD && exist(cfg.FILE.USCHAD_DATA, 'file')
        loadedData = load(cfg.FILE.USCHAD_DATA, 'usc');
        usc = loadedData.usc;
        all_trial_names = fieldnames(usc);

        fprintf('Preparing USC-HAD sequences: %d trials...\n', length(all_trial_names));

        for i = 1:length(all_trial_names)
            trial_name = all_trial_names{i};
            trial = usc.(trial_name);

            acc = trial.acc;
            gyro = trial.gyro;
            raw_label = trial.label;
            n_samples = size(acc, 1);

            if n_samples < cfg.WINDOW_SIZE
                continue;
            end

            is_walking = ismember(raw_label, cfg.DS.USCHAD.WALKING_LABELS);
            trial_label_binary = double(is_walking);

            for k = 1:cfg.STEP_SIZE:(n_samples - cfg.WINDOW_SIZE + 1)
                window_start = k;
                window_end = k + cfg.WINDOW_SIZE - 1;

                windowAcc = acc(window_start:window_end, :);
                windowGyro = gyro(window_start:window_end, :);

                seq = ImuWindowToSequenceMatrix(windowAcc, windowGyro, cfg);
                XCell{end + 1, 1} = seq; %#ok<AGROW>
                labels_binary = [labels_binary; trial_label_binary]; %#ok<AGROW>
                n_usc = n_usc + 1;
            end
        end
    elseif p.Results.IncludeUSCHAD
        warning('AutomationForExoskeleton:MissingUSCHAD', ...
            'USC-HAD not found at %s.', cfg.FILE.USCHAD_DATA);
    end

    %% --- HuGaDB ---
    if p.Results.IncludeHuGaDB && exist(cfg.FILE.HUGADB_DATA, 'file')
        S = load(cfg.FILE.HUGADB_DATA, 'hugadb');
        hug = S.hugadb;
        hnames = fieldnames(hug);

        fprintf('Preparing HuGaDB sequences: %d sessions...\n', numel(hnames));

        walkSet = cfg.DS.HUGADB.WALKING_LABELS;

        for i = 1:numel(hnames)
            trial = hug.(hnames{i});
            acc = trial.acc;
            gyro = trial.gyro;
            lf = trial.label_full(:);
            n_samples = size(acc, 1);

            if n_samples < cfg.WINDOW_SIZE
                continue;
            end

            for k = 1:cfg.STEP_SIZE:(n_samples - cfg.WINDOW_SIZE + 1)
                ws = k;
                we = k + cfg.WINDOW_SIZE - 1;
                chunk = lf(ws:we);
                isW = ismember(chunk, walkSet);
                trial_label_binary = double(mean(isW) >= 0.5);

                if ndims(acc) == 3 && size(acc, 2) == 3 && size(acc, 3) > 1
                    windowAcc = acc(ws:we, :, :);
                    windowGyro = gyro(ws:we, :, :);
                elseif size(acc, 2) == 3
                    accW = squeeze(acc(ws:we, :, :));
                    gyroW = squeeze(gyro(ws:we, :, :));
                    windowAcc = accW;
                    windowGyro = gyroW;
                else
                    error('AutomationForExoskeleton:PrepareTrainingDataSequences:HuGaDBShape', ...
                        'Unexpected HuGaDB acc size: %s.', mat2str(size(acc)));
                end

                seq = ImuWindowToSequenceMatrix(windowAcc, windowGyro, cfg);
                XCell{end + 1, 1} = seq; %#ok<AGROW>
                labels_binary = [labels_binary; trial_label_binary]; %#ok<AGROW>
                n_hu = n_hu + 1;
            end
        end
    elseif p.Results.IncludeHuGaDB
        warning('AutomationForExoskeleton:MissingHuGaDB', ...
            'HuGaDB not found at %s.', cfg.FILE.HUGADB_DATA);
    end

    if isempty(XCell)
        error('No sequences extracted. Build usc_had_dataset.mat and/or hugadb_dataset.mat.');
    end

    ModelMetadata.fs = cfg.FS;
    ModelMetadata.windowSize = cfg.WINDOW_SIZE;
    ModelMetadata.stepSize = cfg.STEP_SIZE;
    ModelMetadata.sequenceInputSize = nCh;
    ModelMetadata.sequenceLength = cfg.WINDOW_SIZE;
    ModelMetadata.nWindowsUSCHAD = n_usc;
    ModelMetadata.nWindowsHuGaDB = n_hu;
    ModelMetadata.includeUSCHAD = p.Results.IncludeUSCHAD;
    ModelMetadata.includeHuGaDB = p.Results.IncludeHuGaDB;
    ModelMetadata.dateTrained = char(datetime('now'));

    fprintf(['Sequence extraction complete. Total %d windows (%d x %d each). ', ...
        'USC-HAD: %d | HuGaDB: %d\n'], numel(XCell), nCh, cfg.WINDOW_SIZE, n_usc, n_hu);
end
