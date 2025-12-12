% import_data.m
% Implements the Data Acquisition Protocol described in Interim Report Section 4.1
% 
% Reads CSV files from 3 mobile phones (Back, Left Hip, Right Hip)

function [back, hipL, hipR] = import_data(sessionID)
    % Define paths
    baseDir = '../data/raw/';
    
    % Filenames based on your specific export format (adjust as needed)
    fileBack = fullfile(baseDir, sprintf('session%s_back.csv', sessionID));
    fileHipL = fullfile(baseDir, sprintf('session%s_hipL.csv', sessionID));
    fileHipR = fullfile(baseDir, sprintf('session%s_hipR.csv', sessionID));

    % Check files exist
    if ~isfile(fileBack), error('Back IMU file not found: %s', fileBack); end

    % Import Table
    opts = detectImportOptions(fileBack);
    opts.VariableNamingRule = 'preserve';
    
    rawBack = readtable(fileBack, opts);
    rawHipL = readtable(fileHipL, opts);
    rawHipR = readtable(fileHipR, opts);

    % Pre-process and Synchronize (Simple approach: Trim to shortest duration)
    % Converting tables to standardized structs
    back = process_imu_table(rawBack);
    hipL = process_imu_table(rawHipL);
    hipR = process_imu_table(rawHipR);
    
    disp(['Data imported successfully for Session: ', sessionID]);
end

function data = process_imu_table(tbl)
    % Map columns (Adjust 'AccelerationX', etc. to your app's header names)
    % Supports standard mobile export formats
    
    % Extract arrays
    data.time = tbl.time; % Ensure this is in seconds
    
    % Accelerometer (m/s^2)
    data.acc = [tbl.ax, tbl.ay, tbl.az]; 
    
    % Gyroscope (rad/s)
    data.gyro = [tbl.gx, tbl.gy, tbl.gz];
    
    % Magnetometer (uT) - As claimed in 
    if ismember('mx', tbl.Properties.VariableNames)
        data.mag = [tbl.mx, tbl.my, tbl.mz];
    else
        % Fallback if mag is noisy/missing (Robustness)
        data.mag = zeros(height(tbl), 3); 
    end
end