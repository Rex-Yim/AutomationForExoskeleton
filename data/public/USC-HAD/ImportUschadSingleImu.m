function [back, hipL, hipR] = import_uschad_for_pipeline(trialFieldName)
% Returns dummy hipL/hipR (zero) and puts USC-HAD data into "back" sensor
% because your current pipeline expects three IMUs but USC-HAD has only one.

load('data/public/USC-HAD/usc_had_dataset.mat', 'usc');

trial = usc.(trialFieldName);

back.acc  = trial.acc;
back.gyro = trial.gyro;

% Dummy placeholders (your Kalman/SVM only uses back for many tests anyway)
hipL.acc  = zeros(size(back.acc));
hipL.gyro = zeros(size(back.gyro));
hipR.acc  = zeros(size(back.acc));
hipR.gyro = zeros(size(back.gyro));

fprintf('Loaded USC-HAD trial %s → back sensor (label = %d: %s)\n', ...
        trialFieldName, trial.label, trial.activityName);
end