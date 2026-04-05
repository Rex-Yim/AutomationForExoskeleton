function [tf, info] = HuGaDBEvaluateTrialQuality(trial, cfg, varargin)
% HuGaDBEvaluateTrialQuality  Validate one cached/raw HuGaDB session.

    if nargin < 2
        cfg = ExoConfig();
    end

    p = inputParser;
    addParameter(p, 'TrialName', '', @(s) ischar(s) || isstring(s));
    addParameter(p, 'SessionMeta', struct(), @isstruct);
    addParameter(p, 'AllowedProtocols', cfg.HUGADB.DEFAULT_PROTOCOLS, @(x) true);
    parse(p, varargin{:});

    trialName = char(string(p.Results.TrialName));
    meta = p.Results.SessionMeta;
    allowedProtocols = NormalizeHuGaDBProtocolSelection(p.Results.AllowedProtocols);

    info = struct( ...
        'reason', '', ...
        'nSamples', 0, ...
        'protocol', '', ...
        'corruptedImuMask', false(1, 6), ...
        'qualityFlags', struct(), ...
        'trialName', trialName ...
    );

    if ~isstruct(trial) || isempty(fieldnames(trial))
        info.reason = 'invalid_trial_struct';
        tf = false;
        return;
    end

    protocol = '';
    if isfield(trial, 'huGaDBSessionProtocol')
        protocol = lower(strtrim(char(string(trial.huGaDBSessionProtocol))));
    elseif isfield(meta, 'sessionProtocol')
        protocol = lower(strtrim(char(string(meta.sessionProtocol))));
    end
    protocolList = NormalizeHuGaDBProtocolSelection(protocol);
    if isempty(protocolList)
        protocol = 'unknown_protocol';
    else
        protocol = protocolList{1};
    end
    info.protocol = protocol;

    if ~isempty(allowedProtocols) && ~any(strcmp(protocol, allowedProtocols))
        info.reason = 'protocol_filtered_out';
        tf = false;
        return;
    end

    requiredFields = {'acc', 'gyro', 'label_full'};
    for i = 1:numel(requiredFields)
        if ~isfield(trial, requiredFields{i})
            info.reason = ['missing_' requiredFields{i}];
            tf = false;
            return;
        end
    end

    acc = trial.acc;
    gyro = trial.gyro;
    lf = trial.label_full(:);

    if ~isequal(size(acc), size(gyro))
        info.reason = 'acc_gyro_shape_mismatch';
        tf = false;
        return;
    end
    if isempty(acc) || size(acc, 1) < cfg.HUGADB.QUALITY.MIN_VALID_SAMPLES
        info.reason = 'too_few_samples';
        tf = false;
        return;
    end
    if size(acc, 2) ~= 3
        info.reason = 'invalid_imu_shape';
        tf = false;
        return;
    end
    if numel(lf) ~= size(acc, 1)
        info.reason = 'label_length_mismatch';
        tf = false;
        return;
    end
    if ~isnumeric(acc) || ~isnumeric(gyro) || ~isnumeric(lf)
        info.reason = 'non_numeric_payload';
        tf = false;
        return;
    end

    info.nSamples = size(acc, 1);

    if isfield(trial, 'huGaDBCorruptedImuMask')
        mask = logical(trial.huGaDBCorruptedImuMask(:)).';
        if numel(mask) == 6
            info.corruptedImuMask = mask;
        end
    end

    info.qualityFlags = struct( ...
        'hasNonFiniteAcc', any(~isfinite(acc(:))), ...
        'hasNonFiniteGyro', any(~isfinite(gyro(:))), ...
        'hasNonFiniteLabels', any(~isfinite(lf(:))), ...
        'allSignalZero', all(acc(:) == 0) && all(gyro(:) == 0), ...
        'corruptedImuMask', info.corruptedImuMask, ...
        'protocol', protocol ...
    );

    if isfield(trial, 'huGaDBQuality') && isstruct(trial.huGaDBQuality)
        q = trial.huGaDBQuality;
        if isfield(q, 'isQualityRejected') && logical(q.isQualityRejected)
            info.reason = 'quality_rejected_at_ingest';
            tf = false;
            return;
        end
    end

    if info.qualityFlags.allSignalZero
        info.reason = 'all_signal_zero';
        tf = false;
        return;
    end

    tf = true;
end
