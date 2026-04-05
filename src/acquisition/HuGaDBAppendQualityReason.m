function report = HuGaDBAppendQualityReason(report, level, reason)
% HuGaDBAppendQualityReason  Increment session/window skip reasons.

    if nargin < 3 || isempty(reason)
        reason = 'unspecified';
    end
    key = matlab.lang.makeValidName(lower(char(string(reason))));
    level = lower(strtrim(char(string(level))));

    switch level
        case 'session'
            if ~isfield(report.sessionReasons, key)
                report.sessionReasons.(key) = 0;
            end
            report.sessionReasons.(key) = report.sessionReasons.(key) + 1;
        case 'window'
            if ~isfield(report.windowReasons, key)
                report.windowReasons.(key) = 0;
            end
            report.windowReasons.(key) = report.windowReasons.(key) + 1;
        otherwise
            error('HuGaDBAppendQualityReason: unknown level "%s".', level);
    end
end
