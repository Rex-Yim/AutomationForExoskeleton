%% ExoConfig.m
% --------------------------------------------------------------------------
% PURPOSE: Defines all global configuration parameters, constants, and 
% hyperparameters for the exoskeleton control pipeline.
% --------------------------------------------------------------------------
% DATE CREATED: 2025-12-13
% LAST MODIFIED: 2025-12-13 (Updated USC-HAD labels)
% --------------------------------------------------------------------------
% NOTES:
% - Edit this file to tune the system (e.g., Fs, window size, Kalman noise).
% - All other scripts should load these variables using a function call.
% --------------------------------------------------------------------------

function cfg = ExoConfig()

% --- General System Parameters ---
cfg.FS = 100; % Sample Rate (Hz) - Matches USC-HAD
cfg.ACTIVITY_SIMULATION = 'walking_straight'; % Default raw folder for pipeline simulation

% --- Classification Parameters (Locomotion Mode) ---
cfg.WINDOW_SIZE_S = 1.0; % Window duration in seconds
cfg.STEP_SIZE_S = 0.5; % Step duration in seconds (50% overlap)
cfg.WINDOW_SIZE = round(cfg.WINDOW_SIZE_S * cfg.FS);
cfg.STEP_SIZE = round(cfg.STEP_SIZE_S * cfg.FS);

% SVM Model Parameters
cfg.SVM_KERNEL = 'rbf';
cfg.SVM_STANDARDIZE = true;

% FSM Parameters
cfg.FSM_CONFIRMATION_THRESHOLD = 3; % Consecutive labels required for state change
cfg.STATE_STANDING = 0;
cfg.STATE_WALKING = 1;

% Dataset Specific Labels (USC-HAD)
% Fix: Expanded labels to cover all activities (1-6 locomotion, 7-12 non-locomotion)
cfg.DS.USCHAD.WALKING_LABELS = [1, 2, 3, 4, 5, 6]; % WalkForward, WalkLeft, WalkRight, Upstairs, Downstairs, RunForward
cfg.DS.USCHAD.NON_WALKING_LABELS = [7, 8, 9, 10, 11, 12]; % Jump, Sit, Stand, Sleep, ElevatorUp, ElevatorDown

% --- Sensor Fusion Parameters (Kalman Filter) ---
% Tuning parameters to achieve RMSE < 5 deg
cfg.KALMAN.ACCEL_NOISE = 0.01; 
cfg.KALMAN.GYRO_NOISE = 0.005;

% --- File Paths & Names ---
cfg.FILE.SVM_MODEL = 'results/Binary_SVM_Model.mat';
cfg.FILE.USCHAD_DATA = 'data/public/USC-HAD/usc_had_dataset.mat';
cfg.FILE.HUGADB_DATA = 'data/public/HuGaDB/hugadb_dataset.mat';

end