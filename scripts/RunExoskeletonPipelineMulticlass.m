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
activity_plot = nan(n_total_samples, 1);
activity_gt_plot = nan(n_total_samples, 1);
last_command = 0;
last_act = nan;

imuMagIdx = find(strcmpi(sim.imuOrder, cfg.SIMULATION.KALMAN_IMU_LABEL), 1);
if isempty(imuMagIdx)
    imuMagIdx = size(sim.acc, 3);
end
imuMagName = sim.imuOrder{imuMagIdx};
clear RealtimeFsm;

for i = 1:n_total_samples
    activity_gt_plot(i) = ActivityClassRegistry.mapHuGaDBNative(sim.label_full(i));
end

fprintf('Starting multiclass loop (%d samples)...\n', n_total_samples);

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

fprintf('Simulation complete.\n');

t = (1:n_total_samples) / FS;
figure('Name', 'Multiclass activity pipeline', 'Color', 'w', 'ToolBar', 'none');

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
title(ax2, sprintf('Exo command (activity→locomotion FSM) vs %s IMU magnitude', upper(imuMagName)));
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

fileTag = sprintf('subject%s_session%s', sim.subjectId, sim.sessionId);
pngName = sprintf('replay_multiclass_svm_%s.png', fileTag);
matName = sprintf('replay_multiclass_svm_%s.mat', fileTag);
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
fprintf('Plot saved: %s\n', resultsFile);
fprintf('Metrics saved: %s\n', metricsFile);
