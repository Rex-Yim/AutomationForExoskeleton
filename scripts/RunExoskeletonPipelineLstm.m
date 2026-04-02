%% RunExoskeletonPipelineLstm.m
% --------------------------------------------------------------------------
% Same real-time loop as RunExoskeletonPipeline.m but classifies with the
% trained LSTM (Binary_LSTM_Network.mat) instead of the RBF SVM.
% --------------------------------------------------------------------------
% LOCATION: scripts/RunExoskeletonPipelineLstm.m
% --------------------------------------------------------------------------

clc; clear; close all;

scriptPath = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptPath);

addpath(fullfile(projectRoot, 'config'));
addpath(genpath(fullfile(projectRoot, 'src')));
addpath(scriptPath);

cfg = ExoConfig();
ACTIVITY_NAME = cfg.ACTIVITY_SIMULATION;
FS = cfg.FS;
WINDOW_SIZE = cfg.WINDOW_SIZE;
STEP_SIZE = cfg.STEP_SIZE;

model_path = fullfile(projectRoot, cfg.FILE.BINARY_LSTM);
if ~exist(model_path, 'file')
    error(['LSTM not found: %s\nRun scripts/TrainLstmBinary.m first.'], model_path);
end

L = load(model_path, 'net', 'ModelMetadata');
net = L.net;
walkLabel = 'Walk';
if isfield(L, 'ModelMetadata') && isfield(L.ModelMetadata, 'labelWalk')
    walkLabel = char(L.ModelMetadata.labelWalk);
end

fprintf('LSTM loaded. Simulating: %s\n', ACTIVITY_NAME);

try
    [back, hipL, ~, annotations] = ImportData(ACTIVITY_NAME);
catch ME
    error('Data Import Failed: %s\nEnsure "data/raw/%s" exists.', ME.message, ACTIVITY_NAME);
end

n_total_samples = size(back.acc, 1);

avg_gravity = mean(sqrt(sum(back.acc.^2, 2)));
if avg_gravity < 2.0 && avg_gravity > 0.5
    fprintf('  [INFO] Data in Gs (Mean=%.2f). Converting to m/s^2.\n', avg_gravity);
    back.acc = back.acc * 9.80665;
    hipL.acc = hipL.acc * 9.80665;
end

current_fsm_state = cfg.STATE_STANDING;
hip_flexion_angles = zeros(n_total_samples, 1);
fsm_plot = zeros(n_total_samples, 1);
last_command = 0;

[fuse_back, fuse_hipL] = FusionKalman.initializeFilters(FS);
clear RealtimeFsm;

fprintf('Starting LSTM simulation loop (%d samples)...\n', n_total_samples);

for i = 1:n_total_samples

    q_back = fuse_back(back.acc(i, :), back.gyro(i, :));
    q_hipL = fuse_hipL(hipL.acc(i, :), hipL.gyro(i, :));
    hip_flexion_angles(i) = FusionKalman.estimateAngle(q_back, q_hipL);

    if mod(i - 1, STEP_SIZE) == 0 && (i + WINDOW_SIZE - 1) <= n_total_samples
        windowAcc = back.acc(i:i + WINDOW_SIZE - 1, :);
        windowGyro = back.gyro(i:i + WINDOW_SIZE - 1, :);
        seq = ImuWindowToSequenceMatrix(windowAcc, windowGyro, cfg);
        predCat = classify(net, {seq});
        new_label = double(strcmp(char(predCat), walkLabel));
        [exoskeleton_command, current_fsm_state] = RealtimeFsm(new_label, current_fsm_state);
        last_command = exoskeleton_command;
    end

    fsm_plot(i) = last_command;
end

fprintf('Simulation complete.\n');

figure('Name', 'Exoskeleton Simulation (LSTM)', 'Color', 'w');
t = (1:n_total_samples) / FS;

ax1 = subplot(3, 1, 1);
plot(t, hip_flexion_angles, 'LineWidth', 1.5);
title('Kalman Filter: Hip Flexion Angle');
ylabel('Deg'); grid on;

ax2 = subplot(3, 1, 2);
acc_mag = sqrt(sum(back.acc.^2, 2));
plot(t, acc_mag, 'Color', [0.7 0.7 0.7]); hold on;
stairs(t, fsm_plot * max(acc_mag), 'r', 'LineWidth', 2);
title('Control Command (Red) vs Acc Mag (Gray) — LSTM + FSM');
legend('Activity energy', 'Exo command (ON/OFF)');
ylabel('Cmd / Mag'); grid on;

ax3 = subplot(3, 1, 3);
if ~isempty(annotations) && ismember('Label', annotations.Properties.VariableNames)
    plot(t, annotations.Label, 'k', 'LineWidth', 1.5);
    title('Ground Truth (Annotation.csv)');
    ylim([-0.2 1.2]);
    grid on;
else
    text(ax3, 0.5, 0.5, 'No Ground Truth Available', 'HorizontalAlignment', 'center', ...
        'Units', 'normalized', 'Color', [0 0 0]);
end

linkaxes([ax1, ax2, ax3], 'x');
xlabel('Time (s)');

styleReportFigureColors(gcf);

resultsFile = fullfile(projectRoot, 'results', 'pipeline_output_lstm.png');
if exist('exportgraphics', 'file') == 2
    exportgraphics(gcf, resultsFile, 'Resolution', 200, 'Padding', 'loose');
else
    saveas(gcf, resultsFile);
end
fprintf('Plot saved to: %s\n', resultsFile);
