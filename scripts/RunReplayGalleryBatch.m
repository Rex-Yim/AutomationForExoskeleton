function RunReplayGalleryBatch
% RunReplayGalleryBatch — export four replay PNGs per HuGaDB (subject, session) pair:
% binary SVM, binary LSTM, multiclass ECOC SVM, multiclass LSTM.
%
% Outputs under results/figures/pipeline/<subjectXX_sessionYY>/ and the same
% layout under results/metrics/pipeline/<subjectXX_sessionYY>/:
%   replay_<model>_subjectXX_sessionYY.png  (+ optional .mat metrics)

    close all;
    scriptPath = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(scriptPath);
    cd(projectRoot);
    addpath(fullfile(projectRoot, 'config'));
    addpath(genpath(fullfile(projectRoot, 'src')));
    addpath(scriptPath);

    cfg = ExoConfig();
    FS = cfg.FS;
    WINDOW_SIZE = cfg.WINDOW_SIZE;
    STEP_SIZE = cfg.STEP_SIZE;

    pairs = {
        '06', '02'; '06', '08'; '06', '25'; ...
        '08', '14'; '08', '19'; '08', '25'; ...
        '01', '02'; '01', '13'; '02', '03' ...
    };

    svmPath = fullfile(projectRoot, cfg.FILE.SVM_MODEL);
    lstmPath = fullfile(projectRoot, cfg.FILE.BINARY_LSTM);
    mcSvmPath = fullfile(projectRoot, cfg.FILE.MULTICLASS_SVM);
    mcLstmPath = fullfile(projectRoot, cfg.FILE.MULTICLASS_LSTM);

    if ~exist(svmPath, 'file')
        error('Binary SVM not found: %s\nRun TrainSvmBinary first.', svmPath);
    end
    if ~exist(lstmPath, 'file')
        error('Binary LSTM not found: %s\nRun TrainLstmBinary first.', lstmPath);
    end
    if ~exist(mcSvmPath, 'file')
        error('Multiclass SVM not found: %s\nRun TrainSvmMulticlass(''Dataset'',''hugadb'') first.', mcSvmPath);
    end
    hasDL = license('test', 'Deep_Learning_Toolbox') || license('test', 'Neural_Network_Toolbox');
    if ~hasDL
        error('Deep Learning Toolbox required for LSTM replays.');
    end
    if ~exist(mcLstmPath, 'file')
        error('Multiclass LSTM not found: %s\nRun TrainLstmMulticlass(''Dataset'',''hugadb'') first.', mcLstmPath);
    end

    Lsvm = load(svmPath, 'SVMModel');
    SVMModel = Lsvm.SVMModel;

    Llstm = load(lstmPath, 'net', 'ModelMetadata');
    lstmNet = Llstm.net;
    lstmMeta = Llstm.ModelMetadata;

    Lmc = load(mcSvmPath, 'ECOCModel', 'ModelMetadata');
    ECOCModel = Lmc.ECOCModel;
    mcSvmMeta = Lmc.ModelMetadata;

    Lmcl = load(mcLstmPath, 'net', 'ModelMetadata');
    mcLstmNet = Lmcl.net;
    mcLstmMeta = Lmcl.ModelMetadata;

    fprintf('Replay gallery: %d sessions x 4 models.\n', size(pairs, 1));

    for r = 1:size(pairs, 1)
        subj = pairs{r, 1};
        sess = pairs{r, 2};
        fileTag = sprintf('subject%s_session%s', subj, sess);
        fprintf('\n=== %s ===\n', fileTag);

        sim = LoadHuGaDBSimulationData(cfg, ...
            'SubjectId', subj, ...
            'SessionId', sess, ...
            'HuGaDBSessionProtocols', cfg.HUGADB.DEFAULT_PROTOCOLS);

        n_total_samples = size(sim.acc, 1);
        fprintf('Replay %s (%s), %d samples, protocol %s\n', ...
            sim.sessionName, fileTag, n_total_samples, sim.sessionProtocol);

        imuMagIdx = find(strcmpi(sim.imuOrder, cfg.SIMULATION.KALMAN_IMU_LABEL), 1);
        if isempty(imuMagIdx)
            imuMagIdx = size(sim.acc, 3);
        end
        imuMagName = sim.imuOrder{imuMagIdx};

        % --- 1) Binary SVM ---
        clear RealtimeFsm;
        fsm_plot = runBinaryFsmLoopSvm(SVMModel, sim, n_total_samples, STEP_SIZE, WINDOW_SIZE, cfg);
        saveBinaryReplayPngMat(projectRoot, sim, fsm_plot, FS, imuMagIdx, imuMagName, ...
            WINDOW_SIZE, STEP_SIZE, svmPath, 'replay_binary_svm', fileTag);

        % --- 2) Binary LSTM ---
        clear RealtimeFsm;
        fsm_plot = runBinaryFsmLoopLstm(lstmNet, lstmMeta, sim, n_total_samples, STEP_SIZE, WINDOW_SIZE, cfg);
        saveBinaryReplayPngMat(projectRoot, sim, fsm_plot, FS, imuMagIdx, imuMagName, ...
            WINDOW_SIZE, STEP_SIZE, lstmPath, 'replay_binary_lstm', fileTag);

        % --- 3) Multiclass SVM ---
        clear RealtimeFsm;
        classNames = mcSvmMeta.classNames;
        if isstring(classNames)
            classNames = cellstr(classNames);
        end
        [fsm_plot, activity_plot, activity_gt_plot] = runMulticlassFsmLoopSvm( ...
            ECOCModel, sim, n_total_samples, STEP_SIZE, WINDOW_SIZE, cfg);
        saveMulticlassReplayPngMat(projectRoot, sim, fsm_plot, activity_plot, activity_gt_plot, ...
            FS, imuMagIdx, imuMagName, WINDOW_SIZE, STEP_SIZE, mcSvmPath, classNames, ...
            'replay_multiclass_svm', fileTag);

        % --- 4) Multiclass LSTM ---
        clear RealtimeFsm;
        classNames2 = mcLstmMeta.classNames;
        if isstring(classNames2)
            classNames2 = cellstr(classNames2);
        end
        [fsm_plot, activity_plot, activity_gt_plot] = runMulticlassFsmLoopLstm( ...
            mcLstmNet, classNames2, sim, n_total_samples, STEP_SIZE, WINDOW_SIZE, cfg);
        saveMulticlassReplayPngMat(projectRoot, sim, fsm_plot, activity_plot, activity_gt_plot, ...
            FS, imuMagIdx, imuMagName, WINDOW_SIZE, STEP_SIZE, mcLstmPath, classNames2, ...
            'replay_multiclass_lstm', fileTag);

        close all;
    end

    fprintf('\nReplay gallery batch complete.\n');
end

%% --- Binary SVM loop ---
function fsm_plot = runBinaryFsmLoopSvm(SVMModel, sim, n_total_samples, STEP_SIZE, WINDOW_SIZE, cfg)
    current_fsm_state = cfg.STATE_STANDING;
    fsm_plot = zeros(n_total_samples, 1);
    last_command = 0;
    for i = 1:n_total_samples
        if mod(i - 1, STEP_SIZE) == 0 && (i + WINDOW_SIZE - 1) <= n_total_samples
            windowAcc = sim.acc(i:i + WINDOW_SIZE - 1, :, :);
            windowGyro = sim.gyro(i:i + WINDOW_SIZE - 1, :, :);
            features_vec = ExtractLocomotionFeatures(windowAcc, windowGyro, cfg);
            new_label = predict(SVMModel, features_vec);
            [exoskeleton_command, current_fsm_state] = RealtimeFsm(new_label, current_fsm_state);
            last_command = exoskeleton_command;
        end
        fsm_plot(i) = last_command;
    end
end

%% --- Binary LSTM loop ---
function fsm_plot = runBinaryFsmLoopLstm(net, Lmeta, sim, n_total_samples, STEP_SIZE, WINDOW_SIZE, cfg)
    classNames = ActivityClassRegistry.binaryClassNames();
    inactiveLabel = classNames{1};
    activeLabel = classNames{2};
    if isfield(Lmeta, 'labelPositive')
        activeLabel = char(Lmeta.labelPositive);
    elseif isfield(Lmeta, 'labelWalk')
        activeLabel = char(Lmeta.labelWalk);
    end
    if isfield(Lmeta, 'labelNegative')
        inactiveLabel = char(Lmeta.labelNegative);
    elseif isfield(Lmeta, 'labelStand')
        inactiveLabel = char(Lmeta.labelStand);
    end
    current_fsm_state = cfg.STATE_STANDING;
    fsm_plot = zeros(n_total_samples, 1);
    last_command = 0;
    for i = 1:n_total_samples
        if mod(i - 1, STEP_SIZE) == 0 && (i + WINDOW_SIZE - 1) <= n_total_samples
            windowAcc = sim.acc(i:i + WINDOW_SIZE - 1, :, :);
            windowGyro = sim.gyro(i:i + WINDOW_SIZE - 1, :, :);
            seq = ImuWindowToSequenceMatrix(windowAcc, windowGyro, cfg);
            predCat = classify(net, {seq});
            new_label = double(strcmp(char(predCat), activeLabel));
            [exoskeleton_command, current_fsm_state] = RealtimeFsm(new_label, current_fsm_state);
            last_command = exoskeleton_command;
        end
        fsm_plot(i) = last_command;
    end
end

%% --- Multiclass SVM loop ---
function [fsm_plot, activity_plot, activity_gt_plot] = runMulticlassFsmLoopSvm( ...
        ECOCModel, sim, n_total_samples, STEP_SIZE, WINDOW_SIZE, cfg)
    current_fsm_state = cfg.STATE_STANDING;
    fsm_plot = zeros(n_total_samples, 1);
    activity_plot = nan(n_total_samples, 1);
    activity_gt_plot = nan(n_total_samples, 1);
    last_command = 0;
    last_act = nan;
    for i = 1:n_total_samples
        activity_gt_plot(i) = ActivityClassRegistry.mapHuGaDBNative(sim.label_full(i));
    end
    for i = 1:n_total_samples
        if mod(i - 1, STEP_SIZE) == 0 && (i + WINDOW_SIZE - 1) <= n_total_samples
            windowAcc = sim.acc(i:i + WINDOW_SIZE - 1, :, :);
            windowGyro = sim.gyro(i:i + WINDOW_SIZE - 1, :, :);
            features_vec = ExtractLocomotionFeatures(windowAcc, windowGyro, cfg);
            last_act = predict(ECOCModel, features_vec);
            last_act = double(last_act(1));
            [exoskeleton_command, current_fsm_state] = RealtimeFsmFromActivityClass(last_act, current_fsm_state, 'hugadb');
            last_command = exoskeleton_command;
        end
        fsm_plot(i) = last_command;
        activity_plot(i) = last_act;
    end
end

%% --- Multiclass LSTM loop ---
function [fsm_plot, activity_plot, activity_gt_plot] = runMulticlassFsmLoopLstm( ...
        net, classNames, sim, n_total_samples, STEP_SIZE, WINDOW_SIZE, cfg)
    current_fsm_state = cfg.STATE_STANDING;
    fsm_plot = zeros(n_total_samples, 1);
    activity_plot = nan(n_total_samples, 1);
    activity_gt_plot = nan(n_total_samples, 1);
    last_command = 0;
    last_act = nan;
    for i = 1:n_total_samples
        activity_gt_plot(i) = ActivityClassRegistry.mapHuGaDBNative(sim.label_full(i));
    end
    for i = 1:n_total_samples
        if mod(i - 1, STEP_SIZE) == 0 && (i + WINDOW_SIZE - 1) <= n_total_samples
            windowAcc = sim.acc(i:i + WINDOW_SIZE - 1, :, :);
            windowGyro = sim.gyro(i:i + WINDOW_SIZE - 1, :, :);
            seq = ImuWindowToSequenceMatrix(windowAcc, windowGyro, cfg);
            predCat = classify(net, {seq});
            last_act = find(strcmp(classNames, char(predCat)), 1);
            if isempty(last_act)
                error('Unexpected LSTM class label: %s', char(predCat));
            end
            [exoskeleton_command, current_fsm_state] = RealtimeFsmFromActivityClass(last_act, current_fsm_state, 'hugadb');
            last_command = exoskeleton_command;
        end
        fsm_plot(i) = last_command;
        activity_plot(i) = last_act;
    end
end

function saveBinaryReplayPngMat(projectRoot, sim, fsm_plot, FS, imuMagIdx, imuMagName, ...
        WINDOW_SIZE, STEP_SIZE, model_path, stem, fileTag)
    n_total_samples = size(sim.acc, 1);
    classNames = ActivityClassRegistry.binaryClassNames();
    inactiveLabel = classNames{1};
    activeLabel = classNames{2};
    t = (1:n_total_samples) / FS;
    acc_mag = squeeze(vecnorm(sim.acc(:, :, imuMagIdx), 2, 2));
    hasGt = isfield(sim, 'binaryLabel') && ~isempty(sim.binaryLabel);
    nRows = 1 + double(hasGt);
    isLstm = contains(stem, 'lstm');
    ttl = 'SVM + FSM';
    if isLstm
        ttl = 'LSTM + FSM';
    end
    figure('Name', 'Replay', 'Color', 'w', 'ToolBar', 'none', ...
        'Position', [100 100 1000 380 + 160 * double(hasGt)]);
    axCmd = subplot(nRows, 1, 1);
    yyaxis(axCmd, 'left');
    hMag = plot(t, acc_mag, 'Color', [0.7 0.7 0.7]);
    ylabel('IMU magnitude');
    yyaxis(axCmd, 'right');
    hCmd = stairs(t, fsm_plot, 'Color', [0.2 0.75 0.35], 'LineWidth', 2);
    ylim([-0.1 1.1]);
    yticks([0 1]);
    yticklabels({'OFF', 'ON'});
    title(axCmd, sprintf('Control command (%s) vs %s IMU magnitude', ttl, upper(imuMagName)));
    legend([hMag, hCmd], {'IMU magnitude', 'Exo command'}, 'Location', 'northeast');
    grid on;
    if hasGt
        axGt = subplot(nRows, 1, 2);
        stairs(t, sim.binaryLabel, 'Color', [0.85 0.2 0.2], 'LineWidth', 1.8);
        title(sprintf('Ground truth (subject %s, session %s)', sim.subjectId, sim.sessionId));
        ylabel('State');
        ylim([-0.1 1.1]);
        yticks([0 1]);
        yticklabels({inactiveLabel, activeLabel});
        grid on;
        linkaxes([axCmd, axGt], 'x');
        xlabel(axGt, 'Time (s)');
    else
        xlabel(axCmd, 'Time (s)');
    end
    styleReportFigureColors(gcf);
    pngName = [stem '_' fileTag '.png'];
    matName = [stem '_' fileTag '.mat'];
    resultsFile = ResultsArtifactPath(projectRoot, 'figures', 'pipeline', pngName, fileTag);
    metricsFile = ResultsArtifactPath(projectRoot, 'metrics', 'pipeline', matName, fileTag);
    if exist('exportgraphics', 'file') == 2
        exportgraphics(gcf, resultsFile, 'Resolution', 200, 'Padding', 'loose');
    else
        saveas(gcf, resultsFile);
    end
    groundTruth = [];
    if isfield(sim, 'binaryLabel') && ~isempty(sim.binaryLabel)
        groundTruth = sim.binaryLabel;
    end
    plotMeta = struct( ...
        'subjectId', sim.subjectId, ...
        'sessionId', sim.sessionId, ...
        'sessionName', sim.sessionName, ...
        'sessionProtocol', sim.sessionProtocol, ...
        'imuMagnitudeLabel', imuMagName, ...
        'modelPath', model_path, ...
        'labelNegative', inactiveLabel, ...
        'labelPositive', activeLabel);
    save(metricsFile, 't', 'fsm_plot', 'acc_mag', 'groundTruth', 'plotMeta', ...
        'FS', 'WINDOW_SIZE', 'STEP_SIZE', '-v7.3');
    fprintf('  Saved %s\n', pngName);
end

function saveMulticlassReplayPngMat(projectRoot, sim, fsm_plot, activity_plot, activity_gt_plot, ...
        FS, imuMagIdx, imuMagName, WINDOW_SIZE, STEP_SIZE, model_path, classNames, stem, fileTag)
    n_total_samples = size(sim.acc, 1);
    K = numel(classNames);
    t = (1:n_total_samples) / FS;
    figure('Name', 'Multiclass replay', 'Color', 'w', 'ToolBar', 'none');
    ax2 = subplot(2, 1, 1);
    acc_mag = squeeze(vecnorm(sim.acc(:, :, imuMagIdx), 2, 2));
    yyaxis(ax2, 'left');
    hMag = plot(t, acc_mag, 'Color', [0.75 0.75 0.75]);
    ylabel('IMU magnitude');
    yyaxis(ax2, 'right');
    hCmd = stairs(t, fsm_plot, 'Color', [0.2 0.75 0.35], 'LineWidth', 2);
    ylim([-0.1 1.1]);
    yticks([0 1]);
    yticklabels({'OFF', 'ON'});
    isLstm = contains(stem, 'lstm');
    if isLstm
        title(ax2, sprintf('Exo command (LSTM activity→locomotion FSM) vs %s IMU magnitude', upper(imuMagName)));
    else
        title(ax2, sprintf('Exo command (activity→locomotion FSM) vs %s IMU magnitude', upper(imuMagName)));
    end
    legend([hMag, hCmd], {'IMU magnitude', 'Exo command'}, 'Location', 'northeast');
    grid on;
    ax3 = subplot(2, 1, 2);
    stairs(t, activity_gt_plot, 'Color', [0.85 0.2 0.2], 'LineWidth', 1.0); hold on;
    plot(t, activity_plot, 'LineWidth', 1.2, 'Color', [0 0.4470 0.7410]);
    ylim([0.5, K + 0.5]);
    yticks(1:K);
    yticklabels(classNames);
    title('Activity class: prediction vs ground truth');
    xlabel('Time (s)'); grid on;
    legend(ax3, 'Ground truth', 'Predicted', 'Location', 'southoutside', 'Orientation', 'horizontal');
    linkaxes([ax2, ax3], 'x');
    styleReportFigureColors(gcf);
    pngName = [stem '_' fileTag '.png'];
    matName = [stem '_' fileTag '.mat'];
    resultsFile = ResultsArtifactPath(projectRoot, 'figures', 'pipeline', pngName, fileTag);
    metricsFile = ResultsArtifactPath(projectRoot, 'metrics', 'pipeline', matName, fileTag);
    if exist('exportgraphics', 'file') == 2
        exportgraphics(gcf, resultsFile, 'Resolution', 200, 'Padding', 'loose');
    else
        saveas(gcf, resultsFile);
    end
    plotMeta = struct( ...
        'subjectId', sim.subjectId, ...
        'sessionId', sim.sessionId, ...
        'sessionName', sim.sessionName, ...
        'sessionProtocol', sim.sessionProtocol, ...
        'imuMagnitudeLabel', imuMagName, ...
        'modelPath', model_path, ...
        'classNames', {classNames});
    save(metricsFile, 't', 'fsm_plot', 'activity_plot', 'acc_mag', ...
        'activity_gt_plot', 'plotMeta', 'FS', 'WINDOW_SIZE', 'STEP_SIZE', '-v7.3');
    fprintf('  Saved %s\n', pngName);
end
