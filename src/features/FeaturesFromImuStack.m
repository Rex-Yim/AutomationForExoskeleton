function v = FeaturesFromImuStack(acc, gyro, Fs)
%% FeaturesFromImuStack — concatenate Features() over S IMUs (acc/gyro Nx3xS)
    if ~isequal(size(acc), size(gyro))
        error('FeaturesFromImuStack: acc and gyro must be the same size.');
    end
    if size(acc, 2) ~= 3
        error('FeaturesFromImuStack: expected acc Nx3xS.');
    end
    S = size(acc, 3);
    v = zeros(1, 5 * S);
    for s = 1:S
        v((s - 1) * 5 + (1:5)) = Features(acc(:, :, s), gyro(:, :, s), Fs);
    end
end
