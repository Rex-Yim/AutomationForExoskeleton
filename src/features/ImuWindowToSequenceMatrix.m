function M = ImuWindowToSequenceMatrix(windowAcc, windowGyro, cfg)
%% ImuWindowToSequenceMatrix — IMU window → matrix for sequenceInputLayer
% Each column is one timestep; rows are interleaved acc(3)+gyro(3) per IMU slot.
% Single IMU (Nx3): fills slot 1 only; remaining slots zero-padded to 6*3*2 = 36 rows.
% Stacked IMU (Nx3xS): fills slots 1..S; remaining slots zero-padded.
%
% Output size: (6 * N_IMU_SLOTS) x WINDOW_SIZE — MATLAB RNN convention: features x time.

    if nargin < 3
        cfg = ExoConfig();
    end

    if ~isequal(size(windowAcc), size(windowGyro))
        error('ImuWindowToSequenceMatrix: acc and gyro sizes must match.');
    end

    T = size(windowAcc, 1);
    Smax = cfg.LOCOMOTION.N_IMU_SLOTS;
    nCh = 6 * Smax;
    M = zeros(nCh, T);

    if ndims(windowAcc) == 3 && size(windowAcc, 3) >= 1
        S = size(windowAcc, 3);
        if S > Smax
            error('ImuWindowToSequenceMatrix: more than N_IMU_SLOTS (%d) in stack.', Smax);
        end
        for t = 1:T
            for s = 1:S
                a = squeeze(windowAcc(t, :, s));
                g = squeeze(windowGyro(t, :, s));
                a = a(:);
                g = g(:);
                if numel(a) ~= 3 || numel(g) ~= 3
                    error('ImuWindowToSequenceMatrix: expected 3-D acc/gyro per IMU.');
                end
                r0 = (s - 1) * 6;
                M(r0 + (1:3), t) = a;
                M(r0 + (4:6), t) = g;
            end
        end
    elseif size(windowAcc, 2) == 3
        for t = 1:T
            M(1:3, t) = windowAcc(t, :).';
            M(4:6, t) = windowGyro(t, :).';
        end
    else
        error('ImuWindowToSequenceMatrix: expected Nx3 or Nx3xS acc/gyro.');
    end
end
