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
    sim = LoadHuGaDBSimulationData(cfg, 'HuGaDBSessionProtocols', cfg.HUGADB.DEFAULT_PROTOCOLS);
catch ME
    error('Simulation data load failed: %s', ME.message);
end

n_total_samples = size(sim.acc, 1);
fprintf('Held-out replay subject %s session %s (%s), %d samples.\n', ...
    sim.subjectId, sim.sessionId, sim.sessionName, n_total_samples);
fprintf('Replay protocol: %s\n', sim.sessionProtocol);

% --- 4. Initialization ---
current_fsm_state = cfg.STATE_STANDING;
fsm_plot = zeros(n_total_samples, 1);
last_command = 0;

imuMagIdx = find(strcmpi(sim.imuOrder, cfg.SIMULATION.KALMAN_IMU_LABEL), 1);
if isempty(imuMagIdx)
    imuMagIdx = size(sim.acc, 3);
end
imuMagName = sim.imuOrder{imuMagIdx};

% CRITICAL: Reset FSM persistent variables from previous runs
clear RealtimeFsm; 

fprintf('Starting simulation loop (%d samples)...\n', n_total_samples);

% --- 5. Main Real-Time Loop ---
for i = 1:n_total_samples

    % AI Classification (Periodic)
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

% --- 6. Visualization (match RunExoskeletonPipelineLstm: row 1 = SVM+FSM vs IMU, row 2 = GT) ---
classNames = ActivityClassRegistry.binaryClassNames();
inactiveLabel = classNames{1};
activeLabel = classNames{2};

t = (1:n_total_samples) / FS;
acc_mag = squeeze(vecnorm(sim.acc(:, :, imuMagIdx), 2, 2));
hasGt = isfield(sim, 'binaryLabel') && ~isempty(sim.binaryLabel);
nRows = 1 + double(hasGt);

figure('Name', 'Exoskeleton Simulation', 'Color', 'w', 'ToolBar', 'none', ...
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
title(axCmd, sprintf('Control command (SVM + FSM) vs %s IMU magnitude', upper(imuMagName)));
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

% Save Result (same path convention as RunReplayGalleryBatch — no duplicate root pipeline_*.png)
fileTag = sprintf('subject%s_session%s', sim.subjectId, sim.sessionId);
pngName = sprintf('replay_binary_svm_%s.png', fileTag);
matName = sprintf('replay_binary_svm_%s.mat', fileTag);
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
