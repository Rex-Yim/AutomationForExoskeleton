%% ImportData.m
% --------------------------------------------------------------------------
% FUNCTION: [back, hipL, hipR, annotations] = ImportData(activityName)
% PURPOSE: Implements the Data Acquisition Protocol, reading raw CSV data from 
% a specified activity folder (assuming a single IMU on the back).
% --------------------------------------------------------------------------
% DATE CREATED: 2025-12-11
% LAST MODIFIED: 2025-12-13 (Fixed dummy data sizing for hipL/hipR)
% --------------------------------------------------------------------------
% DEPENDENCIES: 
% - process_imu_table (Nested function)
% --------------------------------------------------------------------------
% NOTES:
% - Assumes raw CSV files are named Accelerometer.csv, Gyroscope.csv, etc. 
% within the '../data/raw/<activityName>/' folder.
% - This function is currently adapted to load the *single* IMU data found in 
% the raw directory and assigns it to the 'back' sensor. 
% - 'hipL' and 'hipR' are returned as zero arrays for pipeline compatibility.
% --------------------------------------------------------------------------

function [back, hipL, hipR, annotations] = ImportData(activityName)
% Define path to the specific activity folder
baseDir = '../data/raw/';
activityPath = fullfile(baseDir, activityName);

% Filenames
fileAcc = fullfile(activityPath, 'Accelerometer.csv');
fileGyro = fullfile(activityPath, 'Gyroscope.csv');
fileAnnot = fullfile(activityPath, 'Annotation.csv'); % Includes ground truth labels

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
N_samples = size(back.acc, 1);

% Fix: Create dummy zero data with correct N_samples size
hipL.acc = zeros(N_samples, 3);
hipL.gyro = zeros(N_samples, 3);
hipR.acc = zeros(N_samples, 3);
hipR.gyro = zeros(N_samples, 3);

fprintf('Imported %d samples of IMU data for activity "%s".\n', N_samples, activityName);
end

%% --- NESTED FUNCTION (Utility for Table Processing) ---
function imu = process_imu_table(accTable, gyroTable)
% Converts imported tables to standard IMU data structure (Nx3 arrays).

% Error checking for missing data (as dummy creation is now handled by the caller)
if isempty(accTable) || isempty(gyroTable)
    error('process_imu_table: Called without data. Data loading failed.');
end

imu.acc = table2array(accTable);
imu.gyro = table2array(gyroTable);
end