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

% --- Configuration (Use ExoConfig for centralized management) ---
cfg = ExoConfig();
ACTIVITY_NAME = cfg.ACTIVITY_SIMULATION; 
FS = cfg.FS; 
WINDOW_SIZE = cfg.WINDOW_SIZE; 
STEP_SIZE = cfg.STEP_SIZE; 

% --- 1. Load Trained Model ---
model_path = cfg.FILE.SVM_MODEL;
if ~exist(model_path, 'file')
error('Trained SVM Model not found. Please run TrainSvmBinary first to generate: %s', model_path);
end
load(model_path, 'SVMModel');
fprintf('Trained SVM Model loaded successfully.\n');

% --- 2. Initialize Exoskeleton State ---
current_fsm_state = cfg.STATE_STANDING; % 0: STANDING, 1: WALKING
hip_flexion_angles = []; % Store estimated joint angles

% --- 3. Initialize Sensor Fusion Filter (Kalman) ---
% Using the new modular function from FusionKalman.m
[fuse_back, fuse_hipL] = initializeFilters(FS); 
fprintf('Kalman Filter initialized for real-time operation.\n');

% --- 4. Load Data for Simulation (Data Acquisition Protocol) ---
try
[back, hipL, ~, annotations] = ImportData(ACTIVITY_NAME); 
catch ME
warning('Data import failed via ImportData.m: %s. Falling back to dummy data.', ME.message);
% Dummy data fallback if ImportData fails to read CSVs
data_len = 5000;
back.acc = [zeros(data_len, 2), ones(data_len, 1)*9.8];
back.gyro = zeros(data_len, 3);
hipL = struct('acc', zeros(data_len, 3), 'gyro', zeros(data_len, 3));
annotations = table(zeros(data_len, 1), 'VariableNames', {'Label'}); 
end

n_total_samples = size(back.acc, 1);
fprintf('Starting real-time simulation on %d samples...\n', n_total_samples);

% --- 5. Main Real-Time Simulation Loop ---
fsm_plot = zeros(n_total_samples, 1);
last_command = 0;

for i = 1:n_total_samples

% --- Sensor Fusion (Incremental Update) ---
% 1. Update IMU filters with current sample (i). The filter object's state is updated internally.
update(fuse_back, back.acc(i,:), back.gyro(i,:));
update(fuse_hipL, hipL.acc(i,:), hipL.gyro(i,:));

% 2. Calculate current hip flexion angle
% Fix: Pass the filter objects (which hold the state) directly.
current_angle = estimateAngle(fuse_back, fuse_hipL); 
hip_flexion_angles(i) = current_angle; %#ok<AGROW>

% --- Locomotion Classification (Sliding Window Check) ---
if mod(i - 1, STEP_SIZE) == 0 && (i + WINDOW_SIZE - 1) <= n_total_samples

windowAcc = back.acc(i : i+WINDOW_SIZE-1, :);
windowGyro = back.gyro(i : i+WINDOW_SIZE-1, :); % Fix: Extract Gyro window

% 1. Extract Features
% Fix: Pass both Accel and Gyro to Features.m
features_vec = Features(windowAcc, windowGyro, FS); 

% 2. Classify (Predict the next label)
new_label = predict(SVMModel, features_vec); 

% 3. Update FSM and get command
[exoskeleton_command, current_fsm_state] = RealtimeFsm(new_label, current_fsm_state);

last_command = exoskeleton_command; 

fprintf('Time step %d: Classification Label=%d, FSM State=%d, Command=%d\n', ...
i, new_label, current_fsm_state, exoskeleton_command);
end

% Store the current command for this sample index
fsm_plot(i) = last_command;
end

% --- 6. Visualization and Finalization ---
fprintf('\nPipeline simulation complete.\n');

figure('Name', 'Pipeline Output');
t = (1:n_total_samples) / FS;

subplot(3,1,1);
plot(t, hip_flexion_angles, 'LineWidth', 1.5);
title('Estimated Left Hip Flexion Angle (Kalman)');
ylabel('Angle (deg)');
grid on;

subplot(3,1,2);
stairs(t, fsm_plot, 'LineWidth', 1.5);
ylim([-0.1 1.1]);
yticks([0 1]);
yticklabels({'STANDING', 'WALKING'});
title('Exoskeleton Control Command (FSM Output)');
ylabel('Command');
grid on;

subplot(3,1,3);
if ismember('Label', annotations.Properties.VariableNames) && size(annotations, 1) == n_total_samples
plot(t, annotations.Label, 'LineWidth', 1.5, 'Color', 'k');
title('Ground Truth Label (from Annotation.csv)');
xlabel('Time (s)');
ylabel('Label');
grid on;
else
text(0.5, 0.5, 'Ground Truth plotting skipped (size mismatch or missing data).', 'HorizontalAlignment', 'center');
title('Ground Truth Label');
xlabel('Time (s)');
end

saveas(gcf, 'results/realtime_pipeline_output.png');
fprintf('Output plot saved to results/realtime_pipeline_output.png\n');