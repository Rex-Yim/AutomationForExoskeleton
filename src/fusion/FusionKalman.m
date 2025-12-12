%% FusionKalman.m
% --------------------------------------------------------------------------
% FUNCTION: [fuse_back, fuse_hipL] = initializeFilters(Fs)
% FUNCTION: [hipFlexionAngle] = estimateAngle(orientBack, orientHipL)
% PURPOSE: Provides configuration and helper functions for the Kalman Filter 
%          used for sensor fusion (Accel/Gyro) to estimate joint angles.
% --------------------------------------------------------------------------
% DATE CREATED: 2025-12-11
% LAST MODIFIED: 2025-12-14 (Refactored to provide modular filter objects)
% --------------------------------------------------------------------------
% DEPENDENCIES: 
% - MATLAB Sensor Fusion Toolbox (imufilter, quat2eul)
% --------------------------------------------------------------------------
% NOTES:
% - The filter objects must be initialized once and updated incrementally 
%   by the main pipeline script.
% - Tuning parameters are defined here to achieve the desired RMSE.
% --------------------------------------------------------------------------

function [fuse_back, fuse_hipL] = initializeFilters(Fs)
% Initializes two independent IMU filter objects (one for the back, one for the hip).

% Tuning parameters (optimized for exoskeleton kinematics)
ACCEL_NOISE = 0.01; 
GYRO_NOISE = 0.005;

fprintf('Initializing Kalman IMU Filters (SampleRate: %d Hz)...\n', Fs);

% Initialize filter for the Back IMU
fuse_back = imufilter('SampleRate', Fs, ...
    'AccelerometerNoise', ACCEL_NOISE, ...
    'GyroscopeNoise', GYRO_NOISE, ...
    'ReferenceFrame', 'ENU'); % East-North-Up reference frame

% Initialize filter for the Left Hip IMU
fuse_hipL = imufilter('SampleRate', Fs, ...
    'AccelerometerNoise', ACCEL_NOISE, ...
    'GyroscopeNoise', GYRO_NOISE, ...
    'ReferenceFrame', 'ENU'); 

end


function hipFlexionAngle = estimateAngle(orientBack, orientHipL)
% Computes the relative joint angle (Left Hip Flexion) from the two quaternion orientations.
% This function is called once per time step in the real-time loop.

% Convert orientation quaternions to Euler angles (ZYX sequence: Yaw-Pitch-Roll)
% Pitch (Y-axis, index 2) typically represents the sagittal plane rotation (flexion/extension)
eulBack = quat2eul(orientBack, 'ZYX'); % [Yaw, Pitch, Roll]
eulHipL = quat2eul(orientHipL, 'ZYX');

% Hip Flexion Angle is the difference in Pitch angle between the two segments
% Convert from radians to degrees
hipFlexionAngle = (eulHipL(2) - eulBack(2)) * (180/pi); 

end

% --- Original Helper Function kept for general IMU data validation ---

function validateIMUData(data, label)
% Checks if the required IMU fields are present and correctly sized.
requiredFields = {'acc', 'gyro'};
for f = requiredFields
if ~isfield(data, f{1}) || size(data.(f{1}), 2) ~= 3
error('%s IMU data missing or invalid: %s field.', label, f{1});
end
end
if size(data.acc, 1) ~= size(data.gyro, 1)
error('%s IMU data size mismatch between acc and gyro.', label);
end
end