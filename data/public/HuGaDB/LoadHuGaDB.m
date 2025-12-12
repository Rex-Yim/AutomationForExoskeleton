%% LoadHuGaDB.m
% --------------------------------------------------------------------------
% FUNCTION: [] = LoadHuGaDB()
% PURPOSE: Loads all raw HuGaDB text files, parses the data, and saves it 
%          to a single .mat file, structured for use with the project's 
%          three-IMU (Back, HipL, HipR) pipeline convention.
% --------------------------------------------------------------------------
% DATE CREATED: 2025-12-12
% LAST MODIFIED: 2025-12-14 (Restructured output for pipeline compatibility)
% --------------------------------------------------------------------------
% DEPENDENCIES: 
% - dlmread (MATLAB built-in)
% --------------------------------------------------------------------------
% NOTES:
% - HuGaDB Sensor Mapping:
%   - Project's HipL -> HuGaDB Left Thigh (lt)
%   - Project's HipR -> HuGaDB Right Thigh (rt)
%   - Project's Back -> Dummy zeros (HuGaDB lacks a dedicated back sensor)
% --------------------------------------------------------------------------

clear; clc;

dataDir = 'HuGaDB_v2_raw'; % Path to .txt files
outputFile = 'hugadb_dataset.mat';

files = dir(fullfile(dataDir, '*.txt'));
hugadb_data = struct(); % Store all sessions

if isempty(files)
    error('No raw HuGaDB .txt files found in %s.', dataDir);
end

fprintf('Loading and restructuring %d HuGaDB trials...\n', length(files));

% Activity ID to Name mapping (simplified example for HuGaDB)
% Labels in HuGaDB are: 1=Sit, 2=Stand, 3=SitToStand, 4=StandToSit, 5=Walk, 6=StairsUp, 7=StairsDown, 8=Run
activityNames = {'Sit', 'Stand', 'SitToStand', 'StandToSit', 'Walk', 'StairsUp', 'StairsDown', 'Run'};

for i = 1:length(files)
    filePath = fullfile(dataDir, files(i).name);
    % Skips 4 header lines using dlmread
    rawMatrix = dlmread(filePath, '\t', 4, 0); 

    % --- 1. Parse Raw Data (Column indices based on standard HuGaDB format) ---
    
    % Data for Hip L (using Left Thigh IMU)
    data.hipL.acc = rawMatrix(:, 31:33); % Left thigh accel
    data.hipL.gyro = rawMatrix(:, 34:36); % Left thigh gyro

    % Data for Hip R (using Right Thigh IMU)
    data.hipR.acc = rawMatrix(:, 13:15); % Right thigh accel
    data.hipR.gyro = rawMatrix(:, 16:18); % Right thigh gyro

    % Data for Back (Dummy zero data to satisfy pipeline input)
    data.back.acc = zeros(size(data.hipL.acc));
    data.back.gyro = zeros(size(data.hipL.gyro));

    % Activity label and Metadata
    label = rawMatrix(:, 39); % Activity label
    data.label = label(1); % Use the first label as the trial label (assuming single activity per file)
    data.activityName = activityNames{data.label};
    data.fs = 100; % Assuming 100 Hz for HuGaDB (common rate)
    
    % Store the full label vector separately if needed for time-series analysis
    data.labels_full = label; 
    
    % --- 2. Store in Main Structure ---
    sessionID = files(i).name(1:end-4); % e.g., 'HuGaDB_v2_various_01_00'
    hugadb_data.(sessionID) = data;
end

save(outputFile, 'hugadb_data', '-v7.3');
fprintf('HuGaDB saved as %s (%d trials) with pipeline-compatible structure.\n', outputFile, length(files));