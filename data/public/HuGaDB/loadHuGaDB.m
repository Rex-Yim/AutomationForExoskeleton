% Batch load and save HuGaDB as .mat
clear; clc;
dataDir = 'HuGaDB_v2_various';  % Path to .txt files

files = dir(fullfile(dataDir, '*.txt'));
hugadb_data = struct();  % Store all sessions

for i = 1:length(files)
    filePath = fullfile(dataDir, files(i).name);
    rawMatrix = dlmread(filePath, '\t', 4, 0);  % Skips 4 header lines
    
    % Parse into struct (column indices based on standard HuGaDB format)
    data.acc_rf = rawMatrix(:, 1:3);    % Right foot accel (x,y,z)
    data.gyro_rf = rawMatrix(:, 4:6);   % Right foot gyro (x,y,z)
    data.acc_rs = rawMatrix(:, 7:9);    % Right shin accel
    data.gyro_rs = rawMatrix(:, 10:12); % Right shin gyro
    data.acc_rt = rawMatrix(:, 13:15);  % Right thigh accel
    data.gyro_rt = rawMatrix(:, 16:18); % Right thigh gyro
    data.acc_lf = rawMatrix(:, 19:21);  % Left foot accel
    data.gyro_lf = rawMatrix(:, 22:24); % Left foot gyro
    data.acc_ls = rawMatrix(:, 25:27);  % Left shin accel
    data.gyro_ls = rawMatrix(:, 28:30); % Left shin gyro
    data.acc_lt = rawMatrix(:, 31:33);  % Left thigh accel
    data.gyro_lt = rawMatrix(:, 34:36); % Left thigh gyro
    data.emg_r = rawMatrix(:, 37);      % Right EMG
    data.emg_l = rawMatrix(:, 38);      % Left EMG
    data.labels = rawMatrix(:, 39);     % Activity label
    
    sessionID = files(i).name(1:end-4);  % e.g., 'HuGaDB_v2_various_01_00'
    hugadb_data.(sessionID) = data;
end

save('hugadb_dataset.mat', 'hugadb_data');
disp('HuGaDB saved as hugadb_dataset.mat');
