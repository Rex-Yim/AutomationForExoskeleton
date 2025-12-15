%% FusionKalman.m
% --------------------------------------------------------------------------
% FUNCTION: [fuse_back, fuse_hipL] = initializeFilters(Fs)
% FUNCTION: [hipFlexionAngle] = estimateAngle(orientBack, orientHipL)
% PURPOSE: Provides configuration and helper functions for the Kalman Filter 
%          used for sensor fusion (Accel/Gyro) to estimate joint angles.
% --------------------------------------------------------------------------
% DATE CREATED: 2025-12-11
% LAST MODIFIED: 2025-12-15 (Refactored to provide modular filter objects)
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
    % Tuning parameters (optimized for exoskeleton kinematics)
    ACCEL_NOISE = 0.01; 
    GYRO_NOISE = 0.005;

    fprintf('Initializing Kalman IMU Filters (SampleRate: %d Hz)...\n', Fs);
    
    % Initialize filter for the Back IMU (Standard MATLAB imufilter)
    fuse_back = imufilter('SampleRate', Fs, ...
        'AccelerometerNoise', ACCEL_NOISE, ...
        'GyroscopeNoise', GYRO_NOISE, ...
        'ReferenceFrame', 'ENU');

    % Initialize filter for the Left Hip IMU
    fuse_hipL = imufilter('SampleRate', Fs, ...
        'AccelerometerNoise', ACCEL_NOISE, ...
        'GyroscopeNoise', GYRO_NOISE, ...
        'ReferenceFrame', 'ENU');
end

function hipFlexionAngle = estimateAngle(orientBack, orientHipL)
    % PURPOSE: Computes relative joint angle from two orientation quaternions.
    % INPUTS: orientBack, orientHipL (1x4 quaternions or quaternion objects)
    
    % 1. Data Safety: Ensure inputs are valid
    if any(isnan(orientBack)) || any(isnan(orientHipL))
        hipFlexionAngle = 0;
        return;
    end

    % 2. Convert to Euler Angles (ZYX: Yaw, Pitch, Roll)
    % Note: Pitch (index 2) usually corresponds to flexion/extension
    eulBack = quat2eul(orientBack, 'ZYX');
    eulHipL = quat2eul(orientHipL, 'ZYX');

    % 3. Calculate Relative Angle (Difference in Pitch)
    angle_rad = eulHipL(2) - eulBack(2);
    
    % 4. Convert to degrees
    hipFlexionAngle = angle_rad * (180/pi);
end