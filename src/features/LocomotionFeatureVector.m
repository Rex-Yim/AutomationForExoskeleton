function v = LocomotionFeatureVector(windowAcc, windowGyro, Fs, cfg)
%% LocomotionFeatureVector — single-IMU window padded to merged training dimension
% Matches USC-HAD rows in PrepareTrainingData (one sensor + zeros for unused slots).
    dim = cfg.LOCOMOTION.N_IMU_SLOTS * cfg.LOCOMOTION.FEATURES_PER_IMU;
    base = Features(windowAcc, windowGyro, Fs);
    if numel(base) ~= cfg.LOCOMOTION.FEATURES_PER_IMU
        error('LocomotionFeatureVector: Features() length does not match FEATURES_PER_IMU.');
    end
    v = [base, zeros(1, dim - numel(base))];
end
