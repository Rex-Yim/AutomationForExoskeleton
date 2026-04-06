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
    sim = LoadHuGaDBSimulationData(cfg, 'HuGaDBSessionProtocols', cfg.HUGADB.DEFAULT_PROTOCOLS);
catch ME
    error('Simulation data load failed: %s', ME.message);
end

n_total_samples = size(sim.acc, 1);
fprintf('Held-out replay subject %s session %s (%s), %d samples.\n', ...
    sim.subjectId, sim.sessionId, sim.sessionName, n_total_samples);
fprintf('Replay protocol: %s\n', sim.sessionProtocol);

current_fsm_state = cfg.STATE_STANDING;
fsm_plot = zeros(n_total_samples, 1);
last_command = 0;

imuMagIdx = find(strcmpi(sim.imuOrder, cfg.SIMULATION.KALMAN_IMU_LABEL), 1);
if isempty(imuMagIdx)
    imuMagIdx = size(sim.acc, 3);
end
imuMagName = sim.imuOrder{imuMagIdx};
clear RealtimeFsm;

fprintf('Starting LSTM simulation loop (%d samples)...\n', n_total_samples);

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

fprintf('Simulation complete.\n');

% Match `RunExoskeletonPipeline.m`: one IMU acc magnitude with overlaid assist command.
t = (1:n_total_samples) / FS;
acc_mag = squeeze(vecnorm(sim.acc(:, :, imuMagIdx), 2, 2));
hasGt = isfield(sim, 'binaryLabel') && ~isempty(sim.binaryLabel);
nRows = 1 + double(hasGt);

figure('Name', 'Exoskeleton Simulation (LSTM)', 'Color', 'w', 'ToolBar', 'none', ...
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
title(axCmd, sprintf('Control command (LSTM + FSM) vs %s IMU magnitude', upper(imuMagName)));
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

fileTag = sprintf('subject%s_session%s', sim.subjectId, sim.sessionId);
pngName = sprintf('replay_binary_lstm_%s.png', fileTag);
matName = sprintf('replay_binary_lstm_%s.mat', fileTag);
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
fprintf('Plot saved to: %s\n', resultsFile);
fprintf('Metrics saved to: %s\n', metricsFile);
