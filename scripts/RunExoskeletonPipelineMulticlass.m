% Simulate the real-time pipeline with the multiclass ECOC activity model.
% Uses native HuGaDB activity labels together with locomotion-state mapping
% to drive the FSM.
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

model_path = fullfile(projectRoot, cfg.FILE.MULTICLASS_SVM);
if ~exist(model_path, 'file')
    error('Multiclass model not found: %s\nRun TrainSvmMulticlass(''Dataset'', ''hugadb'') first.', model_path);
end

L = load(model_path, 'ECOCModel', 'ModelMetadata');
ECOCModel = L.ECOCModel;
meta = L.ModelMetadata;
K = meta.nClasses;
classNames = meta.classNames;
fprintf('Multiclass ECOC loaded (%s, K=%d). Simulating held-out HuGaDB replay.\n', meta.dataset, K);

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
activity_plot = nan(n_total_samples, 1);
last_command = 0;
last_act = nan;

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

fprintf('Starting multiclass loop (%d samples)...\n', n_total_samples);

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
        features_vec = ExtractLocomotionFeatures(windowAcc, windowGyro, cfg);
        last_act = predict(ECOCModel, features_vec);
        last_act = double(last_act(1));
        [exoskeleton_command, current_fsm_state] = RealtimeFsmFromActivityClass(last_act, current_fsm_state, 'hugadb');
        last_command = exoskeleton_command;
    end

    fsm_plot(i) = last_command;
    activity_plot(i) = last_act;
end

fprintf('Simulation complete.\n');

t = (1:n_total_samples) / FS;
figure('Name', 'Multiclass activity pipeline', 'Color', 'w', 'ToolBar', 'none');

ax1 = subplot(3, 1, 1);
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

ax2 = subplot(3, 1, 2);
acc_mag = squeeze(vecnorm(sim.acc(:, :, kalmanImuIdx), 2, 2));
plot(t, acc_mag, 'Color', [0.75 0.75 0.75]); hold on;
stairs(t, fsm_plot * max(acc_mag), 'r', 'LineWidth', 2);
title('Exo command (from activity→locomotion FSM)');
legend('Acc mag', 'Cmd'); grid on;

ax3 = subplot(3, 1, 3);
plot(t, activity_plot, 'LineWidth', 1.2);
ylim([0.5, K + 0.5]);
yticks(1:K);
yticklabels(classNames);
title('Predicted activity class (native, updates each window step)');
xlabel('Time (s)'); grid on;
linkaxes([ax1, ax2, ax3], 'x');

styleReportFigureColors(gcf);

resultsFile = ResultsArtifactPath(projectRoot, 'figures', 'pipeline', 'pipeline_multiclass_output.png');
metricsFile = ResultsArtifactPath(projectRoot, 'metrics', 'pipeline', 'pipeline_multiclass_output.mat');
if exist('exportgraphics', 'file') == 2
    exportgraphics(gcf, resultsFile, 'Resolution', 200, 'Padding', 'loose');
else
    saveas(gcf, resultsFile);
end
plotMeta = struct( ...
    'subjectId', sim.subjectId, ...
    'sessionId', sim.sessionId, ...
    'sessionName', sim.sessionName, ...
    'kalmanImuLabel', kalmanImuName, ...
    'modelPath', model_path, ...
    'classNames', {classNames});
save(metricsFile, 't', 'kalman_trace', 'fsm_plot', 'activity_plot', 'acc_mag', ...
    'plotMeta', 'FS', 'WINDOW_SIZE', 'STEP_SIZE', '-v7.3');
fprintf('Plot saved: %s\n', resultsFile);
fprintf('Metrics saved: %s\n', metricsFile);
