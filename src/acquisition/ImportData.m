%% ImportData.m
% --------------------------------------------------------------------------
% FUNCTION: [back, hipL, hipR, annotations] = ImportData(activityName)
% PURPOSE: Implements the Data Acquisition Protocol, reading raw CSV data from 
% a specified activity folder. Handles Timestamp column stripping.
% --------------------------------------------------------------------------
% DATE CREATED: 2025-12-11
% LAST MODIFIED: 2025-12-17 (Added column cleaning in process_imu_table)
% --------------------------------------------------------------------------

function [back, hipL, hipR, annotations] = ImportData(activityName)
    % Define path to the specific activity folder relative to 'scripts'
    baseDir = '../data/raw/';
    activityPath = fullfile(baseDir, activityName);
    
    % Filenames
    fileAcc = fullfile(activityPath, 'Accelerometer.csv');
    fileGyro = fullfile(activityPath, 'Gyroscope.csv');
    fileAnnot = fullfile(activityPath, 'Annotation.csv');
    
    % Check files exist
    if ~isfolder(activityPath)
        error('Activity folder not found: %s', activityPath);
    end
    if ~isfile(fileAcc) || ~isfile(fileGyro)
        error('IMU data files not found in: %s', activityPath);
    end
    
    % --- 1. Import Raw Tables ---
    opts = detectImportOptions(fileAcc);
    accTable = readtable(fileAcc, opts);
    
    opts = detectImportOptions(fileGyro);
    gyroTable = readtable(fileGyro, opts);
    
    if isfile(fileAnnot)
        opts = detectImportOptions(fileAnnot);
        annotations = readtable(fileAnnot, opts);
    else
        warning('Annotation file not found. Returning empty table.');
        annotations = table();
    end
    
    % --- 2. Process and Assign Data ---
    back = process_imu_table(accTable, gyroTable);
    
    % Setup dummy data for hips (since we only have one physical sensor in this dataset)
    N_samples = size(back.acc, 1);
    
    hipL.acc = zeros(N_samples, 3);
    hipL.gyro = zeros(N_samples, 3);
    hipR.acc = zeros(N_samples, 3);
    hipR.gyro = zeros(N_samples, 3);
    
    fprintf('Imported %d samples of IMU data for activity "%s".\n', N_samples, activityName);
end

%% --- NESTED FUNCTION (Utility for Table Processing) ---
function imu = process_imu_table(accTable, gyroTable)
    % Converts tables to standard IMU data structure (Nx3 arrays).
    % Automatically keeps only the last 3 columns if Timestamp is present.

    rawAcc = table2array(accTable);
    rawGyro = table2array(gyroTable);

    % --- Fix: Handle Timestamp Column (e.g., if data is Nx4) ---
    if size(rawAcc, 2) > 3
        % Assume format is [Timestamp, X, Y, Z], take last 3
        imu.acc = rawAcc(:, end-2:end);
    else
        imu.acc = rawAcc;
    end

    if size(rawGyro, 2) > 3
        % Assume format is [Timestamp, X, Y, Z], take last 3
        imu.gyro = rawGyro(:, end-2:end);
    else
        imu.gyro = rawGyro;
    end
end