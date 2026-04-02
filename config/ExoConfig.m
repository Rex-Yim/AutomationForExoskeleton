%% ExoConfig.m
% --------------------------------------------------------------------------
% CLASS: ExoConfig
% PURPOSE: Central configuration for parameters, constants, and paths.
% --------------------------------------------------------------------------
% LOCATION: config/ExoConfig.m
% --------------------------------------------------------------------------
% DATE CREATED: 2025-12-13
% LAST MODIFIED: 2026-03-22 (BINARY_LSTM path for sequence classifier)
% --------------------------------------------------------------------------

classdef ExoConfig < handle
    properties (Constant)
        % ---------------- System Parameters ----------------
        FS = 100;               % Sampling Frequency (Hz)
        WINDOW_SIZE = 100;      % Sliding window size (1.0 second)
        STEP_SIZE = 50;         % Sliding window step (0.5 second)
        
        % ---------------- File Paths -----------------------
        % Uses relative paths from the project root
        FILE = struct(...
            'SVM_MODEL', fullfile('models', 'Binary_SVM_Model.mat'), ...
            'BINARY_LSTM', fullfile('models', 'Binary_LSTM_Network.mat'), ...
            'MULTICLASS_SVM', fullfile('models', 'Multiclass_SVM_ECOC.mat'), ...
            'USCHAD_DATA', fullfile('data', 'public', 'USC-HAD', 'usc_had_dataset.mat'), ...
            'HUGADB_DATA', fullfile('data', 'public', 'HuGaDB', 'hugadb_dataset.mat') ...
        );
        
        % ---------------- Dataset Definitions --------------
        DS = struct(...
            'USCHAD', struct(...
                'WALKING_LABELS', [1, 2, 3, 4, 5, 6], ...
                'NON_WALKING_LABELS', [7, 8, 9, 10, 11, 12] ...
            ), ...
            'HUGADB', struct(...
                'WALKING_LABELS', [5, 6, 7, 8], ...   % Walk, StairsUp, StairsDown, Run
                'NON_WALKING_LABELS', [1, 2, 3, 4] ... % Sit, Stand, SitToStand, StandToSit
            ) ...
        );
        
        % ---------------- State Machine --------------------
        STATE_STANDING = 0;
        STATE_WALKING = 1;
        
        % ---------------- Simulation -----------------------
        ACTIVITY_SIMULATION = 'walking_straight';

        % ---------------- Locomotion features (train + inference) ------------
        % HuGaDB v2 provides 6 IMUs per row; Features.m outputs 5 scalars per IMU.
        % USC-HAD and on-device inference use one IMU → pad to N_IMU_SLOTS * FEATURES_PER_IMU.
        LOCOMOTION = struct( ...
            'N_IMU_SLOTS', 6, ...
            'FEATURES_PER_IMU', 5 ...
        );
    end
end
