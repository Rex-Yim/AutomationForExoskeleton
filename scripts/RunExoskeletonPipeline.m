%% RunExoskeletonPipeline.m
% --------------------------------------------------------------------------
% FUNCTION: [] = RunExoskeletonPipeline()
% PURPOSE: Main script to simulate the real-time exoskeleton control system. 
% It integrates Data Acquisition, Sensor Fusion (Kalman), 
% and Locomotion Classification (SVM/FSM) to generate control commands.
% --------------------------------------------------------------------------
% DATE CREATED: 2025-12-13
% LAST MODIFIED: 2025-12-13 (Fixed missing gyro data and Kalman interface)
% --------------------------------------------------------------------------
% DEPENDENCIES: 
% - ImportData.m
% - Features.m
% - RealtimeFsm.m
% - FusionKalman.m 
% - Binary_SVM_Model.mat 
% --------------------------------------------------------------------------
% NOTES:
% - Simulates real-time data flow by iterating over the imported batch data.
% --------------------------------------------------------------------------

clc; clear; close all;

% --- Configuration ---
cfg = ExoConfig();
ACTIVITY_NAME = cfg.ACTIVITY_SIMULATION;
FS = cfg.FS; 
WINDOW_SIZE = cfg.WINDOW_SIZE; 
STEP_SIZE = cfg.STEP_SIZE; 

% --- 1. Load Trained Model ---
model_path = cfg.FILE.SVM_MODEL;
if ~exist(model_path, 'file')
    error('Trained SVM Model not found. Run TrainSvmBinary first.');
end
load(model_path, 'SVMModel');
fprintf('Trained SVM Model loaded successfully.\n');

% --- 2. Initialize Exoskeleton State ---
current_fsm_state = cfg.STATE_STANDING;
hip_flexion_angles = zeros(1, 1); % Initialize array

% --- 3. Initialize Sensor Fusion Filter (Kalman) ---
[fuse_back, fuse_hipL] = initializeFilters(FS);

% --- 4. Load Data ---
try
    [back, hipL, ~, annotations] = ImportData(ACTIVITY_NAME);
catch ME
    warning('Data import failed: %s. Using dummy data.', ME.message);
    data_len = 5000;
    back.acc = [zeros(data_len, 2), ones(data_len, 1)*9.8];
    back.gyro = zeros(data_len, 3);
    hipL = struct('acc', zeros(data_len, 3), 'gyro', zeros(data_len, 3));
    annotations = table(zeros(data_len, 1), 'VariableNames', {'Label'});
end

n_total_samples = size(back.acc, 1);
hip_flexion_angles = zeros(n_total_samples, 1); % Pre-allocate
fsm_plot = zeros(n_total_samples, 1);
last_command = 0;

fprintf('Starting real-time simulation on %d samples...\n', n_total_samples);

% --- 5. Main Real-Time Simulation Loop ---
for i = 1:n_total_samples

    % --- Sensor Fusion (Corrected Logic) ---
    % Standard imufilter usage: q = fuse(acc, gyro)
    q_back = fuse_back(back.acc(i,:), back.gyro(i,:));
    q_hipL = fuse_hipL(hipL.acc(i,:), hipL.gyro(i,:));
    
    % Calculate Angle using the current quaternions
    hip_flexion_angles(i) = estimateAngle(q_back, q_hipL);

    % --- Locomotion Classification ---
    if mod(i - 1, STEP_SIZE) == 0 && (i + WINDOW_SIZE - 1) <= n_total_samples
        windowAcc = back.acc(i : i+WINDOW_SIZE-1, :);
        windowGyro = back.gyro(i : i+WINDOW_SIZE-1, :);

        features_vec = Features(windowAcc, windowGyro, FS);
        new_label = predict(SVMModel, features_vec);
        [exoskeleton_command, current_fsm_state] = RealtimeFsm(new_label, current_fsm_state);
        
        last_command = exoskeleton_command;
    end
    fsm_plot(i) = last_command;
end

fprintf('\nPipeline simulation complete.\n');

% --- 6. Visualization (Plotting code remains the same) ---
figure('Name', 'Pipeline Output');
t = (1:n_total_samples) / FS;

subplot(3,1,1);
plot(t, hip_flexion_angles, 'LineWidth', 1.5);
title('Estimated Left Hip Flexion Angle (Kalman)');
ylabel('Angle (deg)'); grid on;

subplot(3,1,2);
stairs(t, fsm_plot, 'LineWidth', 1.5);
ylim([-0.1 1.1]);
title('Exoskeleton Control Command');
ylabel('Command (0=Stand, 1=Walk)'); grid on;

subplot(3,1,3);
if ismember('Label', annotations.Properties.VariableNames)
    plot(t, annotations.Label, 'k', 'LineWidth', 1.5);
    title('Ground Truth');
end
saveas(gcf, 'results/realtime_pipeline_output.png');