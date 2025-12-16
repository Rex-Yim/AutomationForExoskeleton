%% RunExoskeletonPipeline.m
% --------------------------------------------------------------------------
% PURPOSE: Main script to simulate the real-time exoskeleton control system. 
% --------------------------------------------------------------------------
% LOCATION: scripts/RunExoskeletonPipeline.m
% --------------------------------------------------------------------------
% DATE CREATED: 2025-12-13
% LAST MODIFIED: 2025-12-17 (Fixed Pathing and Static Method Calls)
% --------------------------------------------------------------------------

clc; clear; close all;

% --- 1. Environment & Path Setup ---
scriptPath = fileparts(mfilename('fullpath')); 
projectRoot = fileparts(scriptPath); 

% Add necessary paths just in case startup.m wasn't run
addpath(fullfile(projectRoot, 'config'));
addpath(genpath(fullfile(projectRoot, 'src')));

cfg = ExoConfig();
ACTIVITY_NAME = cfg.ACTIVITY_SIMULATION; % e.g., 'walking_straight'
FS = cfg.FS; 
WINDOW_SIZE = cfg.WINDOW_SIZE; 
STEP_SIZE = cfg.STEP_SIZE; 

% --- 2. Load Trained Model ---
model_path = fullfile(projectRoot, cfg.FILE.SVM_MODEL);

if ~exist(model_path, 'file')
    error('Trained SVM Model not found at: %s\nPlease run TrainSvmBinary first.', model_path);
end

loaded = load(model_path, 'SVMModel');
SVMModel = loaded.SVMModel;
fprintf('Model loaded. Simulating activity: %s\n', ACTIVITY_NAME);

% --- 3. Load Data ---
try
    [back, hipL, ~, annotations] = ImportData(ACTIVITY_NAME);
catch ME
    error('Data Import Failed: %s\nEnsure "data/raw/%s" exists.', ME.message, ACTIVITY_NAME);
end

n_total_samples = size(back.acc, 1);

% --- 4. Unit Sanity Check (Auto-Correction) ---
% SVM expects m/s^2. If data is in Gs (mean ~1.0), convert it.
avg_gravity = mean(sqrt(sum(back.acc.^2, 2)));
if avg_gravity < 2.0 && avg_gravity > 0.5
    fprintf('  [INFO] Data detected in Gs (Mean=%.2f). Converting to m/s^2.\n', avg_gravity);
    back.acc = back.acc * 9.80665;
    hipL.acc = hipL.acc * 9.80665;
    % Gyro is usually rad/s or deg/s. Assuming rad/s for now based on Loader.
end

% --- 5. Initialization ---
current_fsm_state = cfg.STATE_STANDING;
hip_flexion_angles = zeros(n_total_samples, 1); 
fsm_plot = zeros(n_total_samples, 1);
last_command = 0;

[fuse_back, fuse_hipL] = FusionKalman.initializeFilters(FS);

% CRITICAL: Reset FSM persistent variables from previous runs
clear RealtimeFsm; 

fprintf('Starting simulation loop (%d samples)...\n', n_total_samples);

% --- 6. Main Real-Time Loop ---
for i = 1:n_total_samples

    % A. Kinematics (Sensor Fusion)
    q_back = fuse_back(back.acc(i,:), back.gyro(i,:));
    q_hipL = fuse_hipL(hipL.acc(i,:), hipL.gyro(i,:));
    
    hip_flexion_angles(i) = FusionKalman.estimateAngle(q_back, q_hipL);

    % B. AI Classification (Periodic)
    if mod(i - 1, STEP_SIZE) == 0 && (i + WINDOW_SIZE - 1) <= n_total_samples
        
        % Extract Window
        windowAcc = back.acc(i : i+WINDOW_SIZE-1, :);
        windowGyro = back.gyro(i : i+WINDOW_SIZE-1, :);

        % Feature Extraction
        features_vec = Features(windowAcc, windowGyro, FS);
        
        % Predict (0=Stand, 1=Walk)
        new_label = predict(SVMModel, features_vec);
        
        % FSM Smoothing
        [exoskeleton_command, current_fsm_state] = RealtimeFsm(new_label, current_fsm_state);
        
        last_command = exoskeleton_command;
    end
    
    % Store for plotting
    fsm_plot(i) = last_command;
end

fprintf('Simulation Complete.\n');

% --- 7. Visualization ---
figure('Name', 'Exoskeleton Simulation', 'Color', 'w');
t = (1:n_total_samples) / FS;

ax1 = subplot(3,1,1);
plot(t, hip_flexion_angles, 'LineWidth', 1.5);
title('Kalman Filter: Hip Flexion Angle');
ylabel('Deg'); grid on;

ax2 = subplot(3,1,2);
% Plot acceleration magnitude to show activity intensity
acc_mag = sqrt(sum(back.acc.^2, 2));
plot(t, acc_mag, 'Color', [0.7 0.7 0.7]); hold on;
% Overlay Control Command
stairs(t, fsm_plot * max(acc_mag), 'r', 'LineWidth', 2);
title('Control Command (Red) vs Acc Mag (Gray)');
legend('Activity Energy', 'Exo Command (ON/OFF)');
ylabel('Cmd / Mag'); grid on;

ax3 = subplot(3,1,3);
if ~isempty(annotations) && ismember('Label', annotations.Properties.VariableNames)
    plot(t, annotations.Label, 'k', 'LineWidth', 1.5);
    title('Ground Truth (Annotation.csv)');
    ylim([-0.2 1.2]);
else
    text(0.5, 0.5, 'No Ground Truth Available', 'HorizontalAlignment', 'center');
end
linkaxes([ax1, ax2, ax3], 'x');
xlabel('Time (s)');

% Save Result
resultsFile = fullfile(projectRoot, 'results', 'pipeline_output.png');
saveas(gcf, resultsFile);
fprintf('Plot saved to: %s\n', resultsFile);