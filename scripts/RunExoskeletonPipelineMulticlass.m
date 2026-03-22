%% RunExoskeletonPipelineMulticlass.m
% Same simulation as RunExoskeletonPipeline, but ECOC multiclass activity +
% FSM driven by locomotion vs non-locomotion mapping.
clc; clear; close all;

scriptPath = fileparts(mfilename('fullpath'));
projectRoot = fileparts(scriptPath);

addpath(fullfile(projectRoot, 'config'));
addpath(genpath(fullfile(projectRoot, 'src')));

cfg = ExoConfig();
ACTIVITY_NAME = cfg.ACTIVITY_SIMULATION;
FS = cfg.FS;
WINDOW_SIZE = cfg.WINDOW_SIZE;
STEP_SIZE = cfg.STEP_SIZE;

model_path = fullfile(projectRoot, cfg.FILE.MULTICLASS_SVM);
if ~exist(model_path, 'file')
    error('Multiclass model not found: %s\nRun TrainSvmMulticlass first.', model_path);
end

L = load(model_path, 'ECOCModel');
ECOCModel = L.ECOCModel;
fprintf('Multiclass ECOC loaded. Simulating: %s\n', ACTIVITY_NAME);

try
    [back, hipL, ~, annotations] = ImportData(ACTIVITY_NAME);
catch ME
    error('Data Import Failed: %s', ME.message);
end

n_total_samples = size(back.acc, 1);

avg_gravity = mean(sqrt(sum(back.acc.^2, 2)));
if avg_gravity < 2.0 && avg_gravity > 0.5
    fprintf('  [INFO] Converting acc from g to m/s^2.\n');
    back.acc = back.acc * 9.80665;
    hipL.acc = hipL.acc * 9.80665;
end

current_fsm_state = cfg.STATE_STANDING;
hip_flexion_angles = zeros(n_total_samples, 1);
fsm_plot = zeros(n_total_samples, 1);
activity_plot = nan(n_total_samples, 1);
last_command = 0;
last_act = nan;

[fuse_back, fuse_hipL] = FusionKalman.initializeFilters(FS);
clear RealtimeFsm;

fprintf('Starting multiclass loop (%d samples)...\n', n_total_samples);

for i = 1:n_total_samples
    q_back = fuse_back(back.acc(i, :), back.gyro(i, :));
    q_hipL = fuse_hipL(hipL.acc(i, :), hipL.gyro(i, :));
    hip_flexion_angles(i) = FusionKalman.estimateAngle(q_back, q_hipL);

    if mod(i - 1, STEP_SIZE) == 0 && (i + WINDOW_SIZE - 1) <= n_total_samples
        windowAcc = back.acc(i:i + WINDOW_SIZE - 1, :);
        windowGyro = back.gyro(i:i + WINDOW_SIZE - 1, :);
        features_vec = LocomotionFeatureVector(windowAcc, windowGyro, FS, cfg);
        last_act = predict(ECOCModel, features_vec);
        last_act = double(last_act(1));
        [exoskeleton_command, current_fsm_state] = RealtimeFsmFromActivityClass(last_act, current_fsm_state);
        last_command = exoskeleton_command;
    end

    fsm_plot(i) = last_command;
    activity_plot(i) = last_act;
end

fprintf('Simulation complete.\n');

t = (1:n_total_samples) / FS;
figure('Name', 'Multiclass activity pipeline', 'Color', 'w');

ax1 = subplot(3, 1, 1);
plot(t, hip_flexion_angles, 'LineWidth', 1.5);
title('Hip flexion (Kalman)');
ylabel('Deg'); grid on;

ax2 = subplot(3, 1, 2);
acc_mag = sqrt(sum(back.acc.^2, 2));
plot(t, acc_mag, 'Color', [0.75 0.75 0.75]); hold on;
stairs(t, fsm_plot * max(acc_mag), 'r', 'LineWidth', 2);
title('Exo command (from activity→locomotion FSM)');
legend('Acc mag', 'Cmd'); grid on;

ax3 = subplot(3, 1, 3);
plot(t, activity_plot, 'LineWidth', 1.2);
ylim([0.5, ActivityClassRegistry.N_CLASSES + 0.5]);
yticks(1:ActivityClassRegistry.N_CLASSES);
yticklabels(ActivityClassRegistry.CLASS_NAMES);
title('Predicted activity class (updates each window step)');
xlabel('Time (s)'); grid on;
linkaxes([ax1, ax2, ax3], 'x');

resultsFile = fullfile(projectRoot, 'results', 'pipeline_multiclass_output.png');
saveas(gcf, resultsFile);
fprintf('Plot saved: %s\n', resultsFile);
