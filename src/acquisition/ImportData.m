%% ImportData.m
% --------------------------------------------------------------------------
% FUNCTION: [back, hipL, hipR, annotations] = ImportData(activityName)
% PURPOSE: Implements the Data Acquisition Protocol. It locates the 
%          AutomationForExoskeleton project root dynamically and reads raw 
%          CSV data.
% --------------------------------------------------------------------------
% LOCATION: src/acquisition/ImportData.m
% --------------------------------------------------------------------------
% DATE CREATED: 2025-12-11
% LAST MODIFIED: 2025-12-17
% --------------------------------------------------------------------------

function [back, hipL, hipR, annotations] = ImportData(activityName)
    
    % --- 1. Path Management (Location Independent) ---
    % Get the directory of THIS file (.../src/acquisition/)
    funcDir = fileparts(mfilename('fullpath'));
    % Go up two levels to find Project Root (.../AutomationForExoskeleton/)
    projectRoot = fileparts(fileparts(funcDir));
    
    % Construct absolute path to data
    baseDir = fullfile(projectRoot, 'data', 'raw');
    activityPath = fullfile(baseDir, activityName);
    
    % --- 2. Validation ---
    if ~isfolder(activityPath)
        error('Activity folder not found at: %s', activityPath);
    end
    
    fileAcc = fullfile(activityPath, 'Accelerometer.csv');
    fileGyro = fullfile(activityPath, 'Gyroscope.csv');
    fileAnnot = fullfile(activityPath, 'Annotation.csv');
    
    if ~isfile(fileAcc) || ~isfile(fileGyro)
        error('Missing IMU CSV files in: %s', activityPath);
    end
    
    % --- 3. Import Raw Tables ---
    % Suppress warnings for modified variable names during import
    opts = detectImportOptions(fileAcc);
    opts.VariableNamingRule = 'preserve'; 
    accTable = readtable(fileAcc, opts);
    
    opts = detectImportOptions(fileGyro);
    opts.VariableNamingRule = 'preserve';
    gyroTable = readtable(fileGyro, opts);
    
    if isfile(fileAnnot)
        opts = detectImportOptions(fileAnnot);
        annotations = readtable(fileAnnot, opts);
    else
        warning('Annotation file not found. Returning empty table.');
        annotations = table();
    end
    
    % --- 4. Process and Assign Data ---
    back = process_imu_table(accTable, gyroTable);
    
    % Setup placeholder data for hips (Dataset usually only has 1 sensor)
    N_samples = size(back.acc, 1);
    
    hipL.acc = zeros(N_samples, 3);
    hipL.gyro = zeros(N_samples, 3);
    hipR.acc = zeros(N_samples, 3);
    hipR.gyro = zeros(N_samples, 3);
    
    fprintf('Imported %d samples for activity: "%s"\n', N_samples, activityName);
end

%% --- NESTED UTILITY ---
function imu = process_imu_table(accTable, gyroTable)
    % Converts tables to standard Nx3 arrays.
    % Handles cases where specific columns (Timestamp) might exist.
    
    rawAcc = table2array(accTable);
    rawGyro = table2array(gyroTable);

    % Logic: If 4 columns, assume [Time, X, Y, Z]. If 3, assume [X, Y, Z].
    if size(rawAcc, 2) >= 4
        imu.acc = rawAcc(:, end-2:end);
    else
        imu.acc = rawAcc(:, 1:3);
    end

    if size(rawGyro, 2) >= 4
        imu.gyro = rawGyro(:, end-2:end);
    else
        imu.gyro = rawGyro(:, 1:3);
    end
end