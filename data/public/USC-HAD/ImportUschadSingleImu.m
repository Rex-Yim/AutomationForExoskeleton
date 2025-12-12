%% ImportUschadSingleImu.m
% --------------------------------------------------------------------------
% FUNCTION: [back, hipL, hipR] = import_uschad_for_pipeline(trialFieldName)
% PURPOSE: Adapts the single-IMU USC-HAD data format to match the project's three-IMU pipeline, assigning the real data to the 'back' sensor.
% --------------------------------------------------------------------------
% DATE CREATED: 2025-12-12
% LAST MODIFIED: 2025-12-12
% --------------------------------------------------------------------------
% DEPENDENCIES: 
%   - usc_had_dataset.mat
% --------------------------------------------------------------------------
% NOTES:
%   - `hipL` and `hipR` are returned as dummy zero arrays to satisfy pipeline function signatures.
%   - Used for pipeline validation when only one IMU is required.
% --------------------------------------------------------------------------

function [back, hipL, hipR] = ImportUschadSingleImu(trialFieldName)

load('data/public/USC-HAD/usc_had_dataset.mat', 'usc');

trial = usc.(trialFieldName);

back.acc  = trial.acc;
back.gyro = trial.gyro;

% Dummy placeholders (your Kalman/SVM only uses back for many tests anyway)
hipL.acc  = zeros(size(back.acc));
hipL.gyro = zeros(size(back.gyro));
hipR.acc  = zeros(size(back.acc));
hipR.gyro = zeros(size(back.gyro));

fprintf('Loaded USC-HAD trial %s → back sensor (label = %d: %s)\n', ...
        trialFieldName, trial.label, trial.activityName);
end