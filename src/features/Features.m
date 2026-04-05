% Extract a compact IMU feature vector from one window of accelerometer and
% gyroscope data.

function [features_out] = Features(windowAcc, windowGyro, Fs)

    % Use vector magnitudes to summarize motion intensity per window.
    mag_acc = sqrt(sum(windowAcc.^2, 2));
    
    feat_mean_acc = mean(mag_acc); % Mean intensity
    feat_var_acc  = var(mag_acc);  % Variability/Energy

    mag_gyro = sqrt(sum(windowGyro.^2, 2));
    
    feat_mean_gyro = mean(mag_gyro); % Is the body rotating?
    feat_var_gyro  = var(mag_gyro);  % How erratic is the rotation?

    N = length(windowAcc);
    
    % Edge case protection for tiny windows
    if N < 2
        features_out = [feat_mean_acc, feat_var_acc, feat_mean_gyro, feat_var_gyro, 0];
        return; 
    end

    % Use the Z-axis acceleration spectrum as a simple gait-frequency proxy.
    acc_z = windowAcc(:, 3); 
    
    Y = fft(acc_z);
    P2 = abs(Y/N);
    P1 = P2(1:floor(N/2)+1); % Single-sided spectrum
    P1(2:end-1) = 2*P1(2:end-1);

    f = Fs*(0:floor(N/2))/N;

    [~, idx] = max(P1(2:end)); 
    feat_dom_freq = f(idx + 1); 

    % --- 4. Assemble Output ---
    features_out = [feat_mean_acc, feat_var_acc, feat_mean_gyro, feat_var_gyro, feat_dom_freq];

end