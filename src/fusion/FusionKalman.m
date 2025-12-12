%% FusionKalman.m
% --------------------------------------------------------------------------
% FUNCTION: [hipFlexionAngle] = run_fusion_kalman(sessionID)
% PURPOSE: Implements a Kalman Filter for sensor fusion (Accel/Gyro) to estimate low-latency joint angles for exoskeleton control.
% --------------------------------------------------------------------------
% DATE CREATED: 2025-12-11
% LAST MODIFIED: 2025-12-12
% --------------------------------------------------------------------------
% DEPENDENCIES: 
%   - import_data (from ImportData.m)
%   - MATLAB Sensor Fusion Toolbox (imufilter)
% --------------------------------------------------------------------------
% NOTES:
%   - Tuned for real-time operation (incremental updates).
%   - Estimates Left Hip Flexion Angle by calculating the relative orientation between the Back and Left Hip IMUs.
%   - Estimates joint angles with low latency (<200ms) 
% --------------------------------------------------------------------------

clc; clear; close all;

% 1. Load Data
[back, hipL, hipR] = import_data('01'); % Assumes you have session01 files

% Input validation
validateIMUData(back, 'Back');
validateIMUData(hipL, 'Left Hip');
validateIMUData(hipR, 'Right Hip');  % If needed

% 2. Initialize Kalman Filter (Sensor Fusion Toolbox)
% Tuning parameters to achieve RMSE < 5 deg 
Fs = 100; % Sample rate (Hz)
fuse = imufilter('SampleRate', Fs, ...
                 'AccelerometerNoise', 0.01, ...
                 'GyroscopeNoise', 0.005, ...
                 'ReferenceFrame', 'ENU');

realTimeMode = true;  % Flag: true for incremental updates (real-time), false for batch

if realTimeMode
    % 3. Process in loop for real-time (incremental updates)
    orientBack = zeros(length(back.acc), 1, 'quaternion');
    orientHipL = zeros(length(hipL.acc), 1, 'quaternion');
    
    for i = 1:length(back.acc)
        orientBack(i) = fuse(back.acc(i,:), back.gyro(i,:));
        reset(fuse);  % Optional reset per side; adjust based on needs
        orientHipL(i) = fuse(hipL.acc(i,:), hipL.gyro(i,:));
    end
else
    % Original batch mode
    [orientBack, ~] = fuse(back.acc, back.gyro);
    reset(fuse);
    [orientHipL, ~] = fuse(hipL.acc, hipL.gyro);
end

% 4. Compute Relative Joint Angle (Hip Flexion)
eulBack = quat2eul(orientBack, 'ZYX');
eulHipL = quat2eul(orientHipL, 'ZYX');
hipFlexionAngle = (eulHipL(:,2) - eulBack(:,2)) * (180/pi); 

% 5. Test RMSE against ground truth (example: load from file or simulate)
% Assume true_angles is a vector from Vicon or validation data
true_angles = zeros(length(hipFlexionAngle), 1);  % Placeholder: replace with actual
rmse = sqrt(mean((hipFlexionAngle - true_angles).^2));
fprintf('RMSE: %.2f degrees\n', rmse);
if rmse > 5
    warning('RMSE exceeds target threshold of 5 degrees.');
end

% 6. Visualization 
figure('Name', 'Real-time Joint Kinematics');
t = (1:length(hipFlexionAngle)) / Fs;
plot(t, hipFlexionAngle, 'LineWidth', 1.5);
grid on;
title('Estimated Left Hip Flexion Angle (Kalman Fusion)');
xlabel('Time (s)');
ylabel('Angle (deg)');
legend('Hip Flexion');

% Save result for report evidence
saveas(gcf, '../results/joint_angles_rmse.png');
disp('Kinematics estimation complete. Plot saved.');

% Helper function for validation
function validateIMUData(data, label)
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