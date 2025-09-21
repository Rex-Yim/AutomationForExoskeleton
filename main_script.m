% MAIN SCRIPT FOR ACCELEROMETER AND GYROSCOPE DATA ANALYSIS
clear; clc; close all;

% DEFINE SITTING PATH
sitting_accel_path = 'data/Sitting_still-2025-09-21_07-42-00/Accelerometer.csv'; 
sitting_gyro_path = 'data/Sitting_still-2025-09-21_07-42-00/Gyroscope.csv';

% LOAD SITTING DATA
opts = detectImportOptions(sitting_accel_path);
sitting_accel = readtable(sitting_accel_path, opts);
sitting_gyro = readtable(sitting_gyro_path, opts);

% FILTER AND ANALYZE SITTING DATA
filter_and_analyze(sitting_accel, 'Sitting', 'accel');
filter_and_analyze(sitting_gyro, 'Sitting', 'gyro');

% DEFINE WALKING PATH
walking_accel_path = 'data/Walk_straight_-2025-09-21_09-34-01/Accelerometer.csv';
walking_gyro_path = 'data/Walk_straight_-2025-09-21_09-34-01/Gyroscope.csv';

% LOAD WALKING DATA
walking_accel = readtable(walking_accel_path, opts);
walking_gyro = readtable(walking_gyro_path, opts);

% FILTER AND ANALYZE WALKING DATA
filter_and_analyze(walking_accel, 'Walking', 'accel');
filter_and_analyze(walking_gyro, 'Walking', 'gyro');