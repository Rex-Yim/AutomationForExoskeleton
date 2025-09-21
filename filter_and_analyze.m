function filter_and_analyze(data, label, sensor_type)

    % Calculate  magnitude for both datasets
    magnitude = sqrt(data.x.^2 + data.y.^2 + data.z.^2);

    % Filter parameters
    fs = 100; % Sampling frequency
    fc = 5;   % Cutoff frequency
    window_size = 15; % For moving average
    
    % Determine titles and units based on sensor type
    if strcmp(sensor_type, 'accel')
        unit = 'm/s²';
        sensor_name = 'Accelerometer';
        magnitude_label = 'Acceleration Magnitude';
    else
        unit = 'rad/s';
        sensor_name = 'Gyroscope';
        magnitude_label = 'Angular Velocity Magnitude';
    end
    
    % Low-pass Butterworth filter on each component separately
    [b, a] = butter(4, fc/(fs/2), 'low');
    x_lp = filtfilt(b, a, data.x);
    y_lp = filtfilt(b, a, data.y);
    z_lp = filtfilt(b, a, data.z);
    
    % Recalculate magnitude from filtered components
    mag_lp_from_components = sqrt(x_lp.^2 + y_lp.^2 + z_lp.^2);
    
    % Moving average filter on each component
    x_ma = movmean(data.x, window_size);
    y_ma = movmean(data.y, window_size);
    z_ma = movmean(data.z, window_size);
    mag_ma_from_components = sqrt(x_ma.^2 + y_ma.^2 + z_ma.^2);
    
    % Plot filtered X, Y, Z components separately
    figure;
    
    % Filtered X component
    subplot(3,1,1);
    plot(data.seconds_elapsed, data.x, data.seconds_elapsed, x_lp, 'r', 'LineWidth', 0.5);
    title([label ' - X ' sensor_name ' - Original vs Low-Pass Filtered']);
    xlabel('Time (s)');
    ylabel([sensor_name ' (' unit ')']);
    legend('Original', 'Filtered');
    grid on;
    
    % Filtered Y component
    subplot(3,1,2);
    plot(data.seconds_elapsed, data.y, data.seconds_elapsed, y_lp, 'r', 'LineWidth', 0.5);
    title([label ' - Y ' sensor_name ' - Original vs Low-Pass Filtered']);
    xlabel('Time (s)');
    ylabel([sensor_name ' (' unit ')']);
    legend('Original', 'Filtered');
    grid on;
    
    % Filtered Z component
    subplot(3,1,3);
    plot(data.seconds_elapsed, data.z, data.seconds_elapsed, z_lp, 'r', 'LineWidth', 0.5);
    title([label ' - Z ' sensor_name ' - Original vs Low-Pass Filtered']);
    xlabel('Time (s)');
    ylabel([sensor_name ' (' unit ')']);
    legend('Original', 'Filtered');
    grid on;
    
    sgtitle([label ' - ' sensor_name ' Individual Component Filtering Results']);
    
    % Compare original vs filtered data for magnitude
    figure;
    
    % Original magnitude
    subplot(3,1,1);
    plot(data.seconds_elapsed, magnitude);
    title([label ' - Original ' magnitude_label]);
    xlabel('Time (s)');
    ylabel([sensor_name ' (' unit ')']);
    grid on;
    
    % Low-pass filtered magnitude
    subplot(3,1,2);
    plot(data.seconds_elapsed, mag_lp_from_components);
    title([label ' - Low-Pass Filtered ' magnitude_label ' (from filtered X,Y,Z)']);
    xlabel('Time (s)');
    ylabel([sensor_name ' (' unit ')']);
    grid on;
    
    % Moving average filtered magnitude
    subplot(3,1,3);
    plot(data.seconds_elapsed, mag_ma_from_components);
    title([label ' - Moving Average Filtered ' magnitude_label ' (window = ' num2str(window_size) ')']);
    xlabel('Time (s)');
    ylabel([sensor_name ' (' unit ')']);
    grid on;
    
    sgtitle([label ' - ' sensor_name ' Noise Filtering Comparison']);
    
    % Create spectrogram for magnitude
    fs = 100; % Sampling frequency
    window = 256; % Window size
    noverlap = 200; % Overlap between windows
    nfft = 512; % Number of FFT points
    
    figure;
    subplot(2,1,1);
    spectrogram(magnitude, window, noverlap, nfft, fs, 'yaxis');
    title([label ' - Original - Spectrogram of ' magnitude_label]);
    colorbar;
    
    subplot(2,1,2);
    spectrogram(mag_lp_from_components, window, noverlap, nfft, fs, 'yaxis');
    title([label ' - Low-Pass Filtered - Spectrogram (from filtered X,Y,Z)']);
    colorbar;
end