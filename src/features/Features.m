%% Features.m
% --------------------------------------------------------------------------
% FUNCTION: [features_out] = Features(windowAcc, windowGyro, Fs)
% PURPOSE: Calculates time-domain and frequency-domain features from IMU data windows for use in the locomotion classifier.
% --------------------------------------------------------------------------
% DATE CREATED: 2025-12-11
% LAST MODIFIED: 2025-12-14 (Header fix)
% --------------------------------------------------------------------------
% DEPENDENCIES: 
% - MATLAB built-in functions (fft, abs, mean, var, max)
% --------------------------------------------------------------------------
% NOTES:
% - Calculates mean/variance of acceleration magnitude and the dominant frequency.
% - Dominant frequency is crucial for distinguishing steady-state walking (1-2 Hz).
% - Currently ignores windowGyro input (~).
% --------------------------------------------------------------------------

function [features_out] = Features(windowAcc, ~, Fs)

% 1. Time-Domain Features (Used in TrainSvmBinary.m)
% Calculate magnitude of acceleration vector (net force)
mag_acc = sqrt(sum(windowAcc.^2, 2));

% Feature 1: Mean of Acceleration Magnitude
feat_mean_mag = mean(mag_acc);

% Feature 2: Variance of Acceleration Magnitude
feat_var_mag = var(mag_acc);


% 2. Frequency-Domain Features
N = length(windowAcc);
if N < 2
% Handle edge case of very small window
features_out = [feat_mean_mag, feat_var_mag, 0];
return; 
end

% Perform Fast Fourier Transform (FFT) on the raw Z-axis of acceleration
% Z-axis (vertical/gravity) often has the clearest gait signature
acc_z = windowAcc(:, 3); % Assuming Z is the 3rd column

Y = fft(acc_z);
P2 = abs(Y/N);
P1 = P2(1:floor(N/2)+1); % Single-sided spectrum
P1(2:end-1) = 2*P1(2:end-1);

% Frequency vector
f = Fs*(0:floor(N/2))/N;

% Feature 3: Dominant Frequency (excluding DC component at f(1)=0)
[~, idx] = max(P1(2:end)); % Find peak amplitude index, starting from index 2
feat_dom_freq = f(idx + 1); % Adjust index back to frequency vector f

% 3. Output
% Combine all features into a single row vector
features_out = [feat_mean_mag, feat_var_mag, feat_dom_freq];

end