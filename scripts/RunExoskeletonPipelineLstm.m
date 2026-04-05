% Simulate the real-time exoskeleton pipeline with the binary LSTM model.
% Uses the same control loop as `RunExoskeletonPipeline` but replaces the
% SVM classifier with the trained sequence model.

clc; clear; close all;

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

model_path = fullfile(projectRoot, cfg.FILE.BINARY_LSTM);
if ~exist(model_path, 'file')
    error(['LSTM not found: %s\nRun scripts/TrainLstmBinary.m first.'], model_path);
end

L = load(model_path, 'net', 'ModelMetadata');
net = L.net;
classNames = ActivityClassRegistry.binaryClassNames();
inactiveLabel = classNames{1};
activeLabel = classNames{2};
if isfield(L, 'ModelMetadata') && isfield(L.ModelMetadata, 'labelPositive')
    activeLabel = char(L.ModelMetadata.labelPositive);
elseif isfield(L, 'ModelMetadata') && isfield(L.ModelMetadata, 'labelWalk')
    activeLabel = char(L.ModelMetadata.labelWalk);
end
if isfield(L, 'ModelMetadata') && isfield(L.ModelMetadata, 'labelNegative')
    inactiveLabel = char(L.ModelMetadata.labelNegative);
elseif isfield(L, 'ModelMetadata') && isfield(L.ModelMetadata, 'labelStand')
    inactiveLabel = char(L.ModelMetadata.labelStand);
end

fprintf('LSTM loaded. Simulating held-out HuGaDB replay.\n');

try
    sim = LoadHuGaDBSimulationData(cfg);
catch ME
    error('Simulation data load failed: %s', ME.message);
end

n_total_samples = size(sim.acc, 1);
fprintf('Held-out replay subject %s session %s (%s), %d samples.\n', ...
    sim.subjectId, sim.sessionId, sim.sessionName, n_total_samples);

current_fsm_state = cfg.STATE_STANDING;
kalman_trace = zeros(n_total_samples, 1);
fsm_plot = zeros(n_total_samples, 1);
last_command = 0;

kalmanImuIdx = find(strcmpi(sim.imuOrder, cfg.SIMULATION.KALMAN_IMU_LABEL), 1);
if isempty(kalmanImuIdx)
    kalmanImuIdx = size(sim.acc, 3);
end
kalmanImuName = sim.imuOrder{kalmanImuIdx};
if cfg.SIMULATION.KALMAN_ENABLED
    kalmanFilter = FusionKalman.initializeSingleFilter(FS);
else
    kalmanFilter = [];
end
clear RealtimeFsm;

fprintf('Starting LSTM simulation loop (%d samples)...\n', n_total_samples);

for i = 1:n_total_samples

    if ~isempty(kalmanFilter)
        kalmanAcc = reshape(sim.acc(i, :, kalmanImuIdx), 1, []);
        kalmanGyro = reshape(sim.gyro(i, :, kalmanImuIdx), 1, []);
        qSeg = kalmanFilter(kalmanAcc, kalmanGyro);
        kalman_trace(i) = FusionKalman.estimatePitchAngle(qSeg);
    end

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

fprintf('Simulation complete.\n');

figure('Name', 'Exoskeleton Simulation (LSTM)', 'Color', 'w', 'ToolBar', 'none', ...
    'Position', [100 100 1100 1400]);
t = (1:n_total_samples) / FS;
acc_mag_all = squeeze(vecnorm(sim.acc, 2, 2));
gyro_mag_all = squeeze(vecnorm(sim.gyro, 2, 2));
if isvector(acc_mag_all)
    acc_mag_all = acc_mag_all(:);
end
if isvector(gyro_mag_all)
    gyro_mag_all = gyro_mag_all(:);
end
imuLabels = sim.imuOrder(:).';
if numel(imuLabels) ~= size(acc_mag_all, 2)
    imuLabels = arrayfun(@(k) sprintf('IMU %d', k), 1:size(acc_mag_all, 2), 'UniformOutput', false);
end
nImu = size(acc_mag_all, 2);
axs = gobjects(nImu + 3, 1);
tlo = tiledlayout(nImu + 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

axs(1) = nexttile(tlo);
if ~isempty(kalmanFilter)
    plot(t, kalman_trace, 'LineWidth', 1.5);
    title(sprintf('Kalman Filter: %s segment pitch', upper(kalmanImuName)));
    ylabel('Deg');
else
    plot(t, zeros(size(t)), 'LineWidth', 1.5);
    title('Kalman visualization disabled');
    ylabel('Deg');
end
grid on;

for imuIdx = 1:nImu
    axs(imuIdx + 1) = nexttile(tlo);
    yyaxis left;
    accHandle = plot(t, acc_mag_all(:, imuIdx), 'Color', [0.2 0.6 1.0], 'LineWidth', 1.0);
    ylabel('Acc Mag');
    yyaxis right;
    gyroHandle = plot(t, gyro_mag_all(:, imuIdx), 'Color', [0.95 0.6 0.1], 'LineWidth', 1.0);
    ylabel('Gyro Mag');
    title(sprintf('IMU %s Acc and Gyro Magnitude', char(upper(string(imuLabels{imuIdx})))));
    if imuIdx == 1
        legend([accHandle, gyroHandle], {'Acc mag', 'Gyro mag'}, ...
            'Location', 'eastoutside');
    end
    grid on;
end

axs(nImu + 2) = nexttile(tlo);
stairs(t, fsm_plot, 'r', 'LineWidth', 1.8);
title('Exo Command (LSTM + FSM)');
ylabel('Cmd');
ylim([-0.1 1.1]);
yticks([0 1]);
yticklabels({'OFF', 'ON'});
grid on;

axs(end) = nexttile(tlo);
if isfield(sim, 'binaryLabel') && ~isempty(sim.binaryLabel)
    stairs(t, sim.binaryLabel, 'Color', [0.2 0.8 0.2], 'LineWidth', 1.8);
    title(sprintf('Ground Truth (HuGaDB subject %s session %s)', sim.subjectId, sim.sessionId));
    ylabel('State');
    ylim([-0.1 1.1]);
    yticks([0 1]);
    yticklabels({inactiveLabel, activeLabel});
    grid on;
else
    text(axs(end), 0.5, 0.5, 'No Ground Truth Available', 'HorizontalAlignment', 'center', ...
        'Units', 'normalized', 'Color', [0 0 0]);
end

linkaxes(axs, 'x');
xlabel(tlo, 'Time (s)');

styleReportFigureColors(gcf);

resultsFile = ResultsArtifactPath(projectRoot, 'figures', 'pipeline', 'pipeline_output_lstm.png');
metricsFile = ResultsArtifactPath(projectRoot, 'metrics', 'pipeline', 'pipeline_output_lstm.mat');
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
    'kalmanImuLabel', kalmanImuName, ...
    'modelPath', model_path, ...
    'labelNegative', inactiveLabel, ...
    'labelPositive', activeLabel);
acc_mag = acc_mag_all(:, min(kalmanImuIdx, size(acc_mag_all, 2)));
gyro_mag = gyro_mag_all(:, min(kalmanImuIdx, size(gyro_mag_all, 2)));
save(metricsFile, 't', 'kalman_trace', 'fsm_plot', 'acc_mag', 'acc_mag_all', 'gyro_mag', ...
    'gyro_mag_all', 'groundTruth', 'plotMeta', 'FS', 'WINDOW_SIZE', 'STEP_SIZE', '-v7.3');
fprintf('Plot saved to: %s\n', resultsFile);
fprintf('Metrics saved to: %s\n', metricsFile);
