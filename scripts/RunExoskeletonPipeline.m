% Simulate the default real-time exoskeleton control pipeline.
% This script runs the HuGaDB held-out deployment path with the binary SVM
% classifier and control-state updates.

clc; clear; close all;

% --- 1. Environment & Path Setup ---
scriptPath = fileparts(mfilename('fullpath')); 
projectRoot = fileparts(scriptPath); 

% Resolve required paths locally so the script can run directly
cd(projectRoot);
addpath(fullfile(projectRoot, 'config'));
addpath(genpath(fullfile(projectRoot, 'src')));
addpath(scriptPath);

cfg = ExoConfig();
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
fprintf('Model loaded. Simulating held-out HuGaDB replay.\n');

% --- 3. Load Data ---
try
    sim = LoadHuGaDBSimulationData(cfg);
catch ME
    error('Simulation data load failed: %s', ME.message);
end

n_total_samples = size(sim.acc, 1);
fprintf('Held-out replay subject %s session %s (%s), %d samples.\n', ...
    sim.subjectId, sim.sessionId, sim.sessionName, n_total_samples);

% --- 4. Initialization ---
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

% CRITICAL: Reset FSM persistent variables from previous runs
clear RealtimeFsm; 

fprintf('Starting simulation loop (%d samples)...\n', n_total_samples);

% --- 5. Main Real-Time Loop ---
for i = 1:n_total_samples

    % A. Optional Kalman visualization trace
    if ~isempty(kalmanFilter)
        kalmanAcc = reshape(sim.acc(i, :, kalmanImuIdx), 1, []);
        kalmanGyro = reshape(sim.gyro(i, :, kalmanImuIdx), 1, []);
        qSeg = kalmanFilter(kalmanAcc, kalmanGyro);
        kalman_trace(i) = FusionKalman.estimatePitchAngle(qSeg);
    end

    % B. AI Classification (Periodic)
    if mod(i - 1, STEP_SIZE) == 0 && (i + WINDOW_SIZE - 1) <= n_total_samples
        
        % Extract Window
        windowAcc = sim.acc(i : i+WINDOW_SIZE-1, :, :);
        windowGyro = sim.gyro(i : i+WINDOW_SIZE-1, :, :);

        % Feature extraction matches HuGaDB training (six-IMU windows)
        features_vec = ExtractLocomotionFeatures(windowAcc, windowGyro, cfg);
        
        % Predict (0=Inactive, 1=Active)
        new_label = predict(SVMModel, features_vec);
        
        % FSM Smoothing
        [exoskeleton_command, current_fsm_state] = RealtimeFsm(new_label, current_fsm_state);
        
        last_command = exoskeleton_command;
    end
    
    % Store for plotting
    fsm_plot(i) = last_command;
end

fprintf('Simulation Complete.\n');

% --- 6. Visualization ---
figure('Name', 'Exoskeleton Simulation', 'Color', 'w', 'ToolBar', 'none');
t = (1:n_total_samples) / FS;

ax1 = subplot(2,1,1);
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

ax2 = subplot(2,1,2);
% Plot acceleration magnitude to show activity intensity
acc_mag = squeeze(vecnorm(sim.acc(:, :, kalmanImuIdx), 2, 2));
plot(t, acc_mag, 'Color', [0.7 0.7 0.7]); hold on;
% Overlay Control Command
stairs(t, fsm_plot * max(acc_mag), 'r', 'LineWidth', 2);
title('Control Command (Red) vs IMU Magnitude (Gray)');
legend('IMU magnitude', 'Exo command (ON/OFF)');
ylabel('Cmd / Mag'); grid on;

linkaxes([ax1, ax2], 'x');
xlabel('Time (s)');

styleReportFigureColors(gcf);

% Save Result
resultsFile = ResultsArtifactPath(projectRoot, 'figures', 'pipeline', 'pipeline_binary_svm_output.png');
metricsFile = ResultsArtifactPath(projectRoot, 'metrics', 'pipeline', 'pipeline_binary_svm_output.mat');
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
    'modelPath', model_path);
save(metricsFile, 't', 'kalman_trace', 'fsm_plot', 'acc_mag', 'plotMeta', ...
    'FS', 'WINDOW_SIZE', 'STEP_SIZE', '-v7.3');
fprintf('Plot saved to: %s\n', resultsFile);
fprintf('Metrics saved to: %s\n', metricsFile);