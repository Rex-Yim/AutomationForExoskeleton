%% Features.m
% --------------------------------------------------------------------------
% FUNCTION: [features_out] = Features(windowAcc, windowGyro, Fs)
% PURPOSE: Extracts a feature vector from a window of IMU data.
% --------------------------------------------------------------------------
% INPUTS:
%   - windowAcc:  Nx3 matrix of Accelerometer data (m/s^2)
%   - windowGyro: Nx3 matrix of Gyroscope data (rad/s)
%   - Fs:         Sampling Frequency (Hz)
% OUTPUTS:
%   - features_out: 1x5 vector [AccMean, AccVar, GyroMean, GyroVar, DomFreq]
% --------------------------------------------------------------------------
% LOCATION: src/features/Features.m
% --------------------------------------------------------------------------
% DATE CREATED: 2025-12-11
% LAST MODIFIED: 2025-12-17
% --------------------------------------------------------------------------

function [features_out] = Features(windowAcc, windowGyro, Fs)

    % --- 1. Accelerometer Features ---
    % Calculate magnitude of acceleration vector (net force)
    mag_acc = sqrt(sum(windowAcc.^2, 2));
    
    feat_mean_acc = mean(mag_acc); % Mean intensity
    feat_var_acc  = var(mag_acc);  % Variability/Energy

    % --- 2. Gyroscope Features (NEW) ---
    % Calculate magnitude of rotational velocity
    mag_gyro = sqrt(sum(windowGyro.^2, 2));
    
    feat_mean_gyro = mean(mag_gyro); % Is the body rotating?
    feat_var_gyro  = var(mag_gyro);  % How erratic is the rotation?

    % --- 3. Frequency-Domain Features ---
    N = length(windowAcc);
    
    % Edge case protection for tiny windows
    if N < 2
        features_out = [feat_mean_acc, feat_var_acc, feat_mean_gyro, feat_var_gyro, 0];
        return; 
    end

    % Perform FFT on Z-axis acceleration (Gravity axis usually has strongest gait signal)
    acc_z = windowAcc(:, 3); 
    
    Y = fft(acc_z);
    P2 = abs(Y/N);
    P1 = P2(1:floor(N/2)+1); % Single-sided spectrum
    P1(2:end-1) = 2*P1(2:end-1);

    % Frequency vector
    f = Fs*(0:floor(N/2))/N;

    % Find Dominant Frequency (exclude DC component at index 1)
    [~, idx] = max(P1(2:end)); 
    feat_dom_freq = f(idx + 1); 

    % --- 4. Assemble Output ---
    features_out = [feat_mean_acc, feat_var_acc, feat_mean_gyro, feat_var_gyro, feat_dom_freq];

end