%% LoadUSCHAD.m
% --------------------------------------------------------------------------
% FUNCTION: [usc] = loadUSCHAD(rawDir)
% PURPOSE: Loads all raw USC-HAD `.mat` files, normalizes the structure, and saves all trials into a single `usc_had_dataset.mat` file.
% --------------------------------------------------------------------------
% DATE CREATED: 2025-12-12
% LAST MODIFIED: 2025-12-13
% --------------------------------------------------------------------------
% DEPENDENCIES: 
%   - MATLAB built-in functions (dir, load, regexp)
% --------------------------------------------------------------------------
% NOTES:
%   - Converts USC-HAD's gyro format (3xN) to standard (Nx3).
%   - Saves the activity name and label (1-12) for each trial.
% --------------------------------------------------------------------------

function usc = LoadUSCHAD(rawDir)

if nargin < 1
    rawDir = fullfile('data/public/USC-HAD/RawData');
end

if ~isfolder(rawDir)
    error('USC-HAD RawData folder not found: %s', rawDir);
end

files = dir(fullfile(rawDir, '*.mat'));
usc = struct();

activityNames = {'WalkForward','WalkLeft','WalkRight','GoUpstairs',...
                 'GoDownstairs','RunForward','Jump','Sit','Stand',...
                 'Sleep','ElevatorUp','ElevatorDown'};

fprintf('Loading %d USC-HAD trials...\n', length(files));

for i = 1:length(files)
    filepath = fullfile(rawDir, files(i).name);
    tmp = load(filepath);               % contains 'sensor_data'
    
    % Extract fields
    acc  = tmp.sensor_data.acc;         % Nx3  (already in m/s²)
    gyro = tmp.sensor_data.gyro';       % 3xN → Nx3 (rad/s)
    
    % Parse filename: e.g., a1_t2_s3.mat → activity 1, trial 2, subject 3
    tokens = regexp(files(i).name, 'a(?<act>\d+)_t(?<trial>\d+)_s(?<subj>\d+)', 'names');
    actID  = str2double(tokens.act);
    subjID = str2double(tokens.subj(2:end));  % filename has 'sX' but field is just number
    
    fieldName = sprintf('subject%d_activity%d_trial%d', subjID, actID, str2double(tokens.trial));
    
    usc.(fieldName).acc   = acc;
    usc.(fieldName).gyro  = gyro;
    usc.(fieldName).label = actID;              % 1-12
    usc.(fieldName).subject = subjID;
    usc.(fieldName).activityName = activityNames{actID};
    usc.(fieldName).fs = 100;
end

save('data/public/USC-HAD/usc_had_dataset.mat', 'usc', '-v7.3');
fprintf('USC-HAD saved as usc_had_dataset.mat (%d trials)\n', length(files));
end