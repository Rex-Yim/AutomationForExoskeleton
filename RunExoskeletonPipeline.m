%% RunExoskeletonPipeline.m
% --------------------------------------------------------------------------
% FUNCTION: [] = RunExoskeletonPipeline()
% PURPOSE: Main script to simulate the real-time exoskeleton control system. 
%          It integrates Data Acquisition, Sensor Fusion (Kalman), 
%          and Locomotion Classification (SVM/FSM) to generate control commands.
% --------------------------------------------------------------------------
% DATE CREATED: 2025-12-13
% LAST MODIFIED: 2025-12-13
% --------------------------------------------------------------------------
% DEPENDENCIES: 
% - ImportData.m
% - Features.m
% - RealtimeFsm.m
% - FusionKalman.m (Initializes filter)
% - Binary_SVM_Model.mat (Trained model from TrainSvmBinary.m)
% - MATLAB Sensor Fusion Toolbox
% --------------------------------------------------------------------------
% NOTES:
% - Simulates real-time data flow by iterating over the imported batch data.
% - Uses a 1-second sliding window for classification.
% --------------------------------------------------------------------------

clc; clear; close all;

% --- Configuration ---
SESSION_ID = 'walking_straight'; % Use one of the raw data folders for simulation
FS = 100; % Sample Rate (Hz)
WINDOW_SIZE = FS * 1; % 1 second window for classification
STEP_SIZE = FS * 0.5; % 0.5 second step (50% overlap)

% --- 1. Load Trained Model ---
model_path = 'results/Binary_SVM_Model.mat';
if ~exist(model_path, 'file')
    error('Trained SVM Model not found. Please run TrainSvmBinary first to generate: %s', model_path);
end
load(model_path, 'SVMModel');
fprintf('Trained SVM Model loaded successfully.\n');

% --- 2. Initialize Exoskeleton State ---
current_fsm_state = 0; % 0: STANDING, 1: WALKING
hip_flexion_angles = []; % Store estimated joint angles

% --- 3. Initialize Sensor Fusion Filter (Kalman) ---
% The core filter from FusionKalman.m
fuse_back = imufilter('SampleRate', FS, ...
    'AccelerometerNoise', 0.01, ...
    'GyroscopeNoise', 0.005);
fuse_hipL = imufilter('SampleRate', FS, ...
    'AccelerometerNoise', 0.01, ...
    'GyroscopeNoise', 0.005);
fprintf('Kalman Filter initialized for real-time operation.\n');

% --- 4. Load Data for Simulation (Conceptual Data Acquisition) ---
% NOTE: ImportData is designed for sessionX_IMU.csv. 
% For this simulation, we will load USC-HAD data which is already processed 
% or adapt the ImportData.m to read the raw/ folder structure.
% For simplicity, we assume we have a processed structure (like the output of ImportData)
try
    % Using the raw folder structure for simulation
    data_path = fullfile('data', 'raw', SESSION_ID);
    back.acc = csvread(fullfile(data_path, 'Accelerometer.csv'), 1, 0); % Skip header
    back.gyro = csvread(fullfile(data_path, 'Gyroscope.csv'), 1, 0);
    % Simulate the same length for hipL, hipR with zeros if not available
    hipL = struct('acc', zeros(size(back.acc)), 'gyro', zeros(size(back.gyro)));
catch ME
    warning('Could not load specific raw data. Falling back to dummy data. Error: %s', ME.message);
    % Dummy data for pipeline testing if raw files are missing
    data_len = 5000;
    back.acc = [zeros(data_len, 2), ones(data_len, 1)*9.8];
    back.gyro = zeros(data_len, 3);
    hipL = struct('acc', zeros(data_len, 3), 'gyro', zeros(data_len, 3));
end

n_total_samples = size(back.acc, 1);
fprintf('Starting real-time simulation on %d samples...\n', n_total_samples);

% --- 5. Main Real-Time Simulation Loop ---
for i = 1:n_total_samples
    
    % --- Sensor Fusion (Incremental Update) ---
    % 1. Update IMU filters with current sample (i)
    orientBack = update(fuse_back, back.acc(i,:), back.gyro(i,:));
    orientHipL = update(fuse_hipL, hipL.acc(i,:), hipL.gyro(i,:));

    % 2. Calculate current hip flexion angle
    eulBack = quat2eul(orientBack, 'ZYX');
    eulHipL = quat2eul(orientHipL, 'ZYX');
    current_angle = (eulHipL(2) - eulBack(2)) * (180/pi); 
    hip_flexion_angles(i) = current_angle; %#ok<AGROW>

    % --- Locomotion Classification (Sliding Window Check) ---
    % Check if a new classification window is available
    if mod(i - 1, STEP_SIZE) == 0 && (i + WINDOW_SIZE - 1) <= n_total_samples
        
        windowAcc = back.acc(i : i+WINDOW_SIZE-1, :);
        
        % 1. Extract Features
        features_vec = Features(windowAcc, [], FS);
        
        % 2. Classify (Predict the next label)
        % Predict returns [0] for Non-Walk, [1] for Walk
        new_label = predict(SVMModel, features_vec); 
        
        % 3. Update FSM and get command
        [exoskeleton_command, current_fsm_state] = RealtimeFsm(new_label, current_fsm_state);
        
        % 4. Send command to hardware (Conceptual)
        % send_to_serial(exoskeleton_command); 
        
        fprintf('Time step %d: Classification Label=%d, FSM State=%d, Command=%d\n', ...
             i, new_label, current_fsm_state, exoskeleton_command);
    end
end

% --- 6. Visualization and Finalization ---
fprintf('\nPipeline simulation complete.\n');

figure('Name', 'Pipeline Output');
t = (1:n_total_samples) / FS;

subplot(2,1,1);
plot(t, hip_flexion_angles, 'LineWidth', 1.5);
title('Estimated Left Hip Flexion Angle (Kalman)');
ylabel('Angle (deg)');
grid on;

subplot(2,1,2);
% Plot FSM state over time (needs interpolation to match sample rate)
fsm_plot = zeros(n_total_samples, 1);
state_idx = 1:STEP_SIZE:n_total_samples;
for k = 1:length(state_idx)
    % Find the latest state command/state known at this time window
    % Simple interpolation for visualization
    fsm_plot(state_idx(k):min(n_total_samples, state_idx(k)+STEP_SIZE-1)) = current_fsm_state;
end
stairs(t, fsm_plot, 'LineWidth', 1.5);
ylim([-0.1 1.1]);
yticks([0 1]);
yticklabels({'STANDING', 'WALKING'});
title('Locomotion Mode (FSM Output)');
xlabel('Time (s)');
ylabel('State Command');
grid on;

% Save result
saveas(gcf, 'results/realtime_pipeline_output.png');
fprintf('Output plot saved to results/realtime_pipeline_output.png\n');

end