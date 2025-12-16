%% ExoConfig.m
% --------------------------------------------------------------------------
% CLASS: ExoConfig
% PURPOSE: Central configuration for parameters, constants, and paths.
% --------------------------------------------------------------------------
% LOCATION: config/ExoConfig.m
% --------------------------------------------------------------------------
% DATE CREATED: 2025-12-13
% LAST MODIFIED: 2025-12-17
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
            'SVM_MODEL', fullfile('results', 'Binary_SVM_Model.mat'), ...
            'USCHAD_DATA', fullfile('data', 'public', 'USC-HAD', 'usc_had_dataset.mat') ...
        );
        
        % ---------------- Dataset Definitions --------------
        DS = struct(...
            'USCHAD', struct(...
                'WALKING_LABELS', [1, 2, 3, 4, 5, 6], ...
                'NON_WALKING_LABELS', [7, 8, 9, 10, 11, 12] ...
            )...
        );
        
        % ---------------- State Machine --------------------
        STATE_STANDING = 0;
        STATE_WALKING = 1;
        
        % ---------------- Simulation -----------------------
        ACTIVITY_SIMULATION = 'walking_straight';
    end
end