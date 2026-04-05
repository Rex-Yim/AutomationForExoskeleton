function featureVector = ExtractLocomotionFeatures(windowAcc, windowGyro, cfg)
%% ExtractLocomotionFeatures — shared binary feature extraction for single or stacked IMUs

    if nargin < 3
        cfg = ExoConfig();
    end

    if ~isequal(size(windowAcc), size(windowGyro))
        error('ExtractLocomotionFeatures: acc and gyro sizes must match.');
    end

    if ndims(windowAcc) == 3 && size(windowAcc, 2) == 3 && size(windowAcc, 3) > 1
        featureVector = FeaturesFromImuStack(windowAcc, windowGyro, cfg.FS);
    elseif size(windowAcc, 2) == 3
        featureVector = LocomotionFeatureVector(windowAcc, windowGyro, cfg.FS, cfg);
    else
        error('ExtractLocomotionFeatures: expected Nx3 or Nx3xS IMU data.');
    end
end
