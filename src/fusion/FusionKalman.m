%% FusionKalman.m
% --------------------------------------------------------------------------
% CLASS: FusionKalman
% PURPOSE: Static helper class for Kinematics and Sensor Fusion.
%          Contains methods to initialize filters and calculate joint angles.
% --------------------------------------------------------------------------
% LOCATION: src/fusion/FusionKalman.m
% --------------------------------------------------------------------------
% DATE CREATED: 2025-12-11
% LAST MODIFIED: 2025-12-17
% --------------------------------------------------------------------------

classdef FusionKalman
    methods (Static)
        function [fuse_back, fuse_hipL] = initializeFilters(Fs)
            % initializeFilters: Sets up IMU filters for Back and Hip.
            % Tuning parameters (Optimized for human motion)
            ACCEL_NOISE = 0.01; 
            GYRO_NOISE = 0.005;

            fprintf('Initializing Kalman IMU Filters (SampleRate: %d Hz)...\n', Fs);
            
            % Filter for Back IMU
            fuse_back = imufilter('SampleRate', Fs, ...
                'AccelerometerNoise', ACCEL_NOISE, ...
                'GyroscopeNoise', GYRO_NOISE, ...
                'ReferenceFrame', 'ENU');

            % Filter for Left Hip IMU
            fuse_hipL = imufilter('SampleRate', Fs, ...
                'AccelerometerNoise', ACCEL_NOISE, ...
                'GyroscopeNoise', GYRO_NOISE, ...
                'ReferenceFrame', 'ENU');
        end
        
        function hipFlexionAngle = estimateAngle(orientBack, orientHipL)
            % estimateAngle: Computes relative joint angle (flexion/pitch) 
            % between the Back and the Hip.
            
            % Input check
            if any(isnan(orientBack)) || any(isnan(orientHipL))
                hipFlexionAngle = 0;
                return;
            end
        
            % Convert Quaternions to Euler Angles (ZYX order)
            % Index 2 corresponds to Pitch (Y-axis rotation), usually Flexion/Extension
            eulBack = quat2eul(orientBack, 'ZYX');
            eulHipL = quat2eul(orientHipL, 'ZYX');
        
            % Calculate Relative Angle
            angle_rad = eulHipL(2) - eulBack(2);
            
            % Convert to Degrees
            hipFlexionAngle = angle_rad * (180/pi);
        end
    end
end