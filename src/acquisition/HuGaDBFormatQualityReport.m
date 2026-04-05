function lines = HuGaDBFormatQualityReport(report)
% HuGaDBFormatQualityReport  Render a HuGaDB quality report as printable lines.

    lines = {sprintf(['HuGaDB quality summary: sessions scanned=%d accepted=%d skipped=%d | ', ...
        'windows scanned=%d accepted=%d skipped=%d'], ...
        report.nSessionsScanned, report.nSessionsAccepted, report.nSessionsSkipped, ...
        report.nWindowsScanned, report.nWindowsAccepted, report.nWindowsSkipped)};

    sessionLines = formatReasonBlock('Session skip reasons', report.sessionReasons);
    windowLines = formatReasonBlock('Window skip reasons', report.windowReasons);
    lines = [lines, sessionLines, windowLines]; %#ok<AGROW>
end

function lines = formatReasonBlock(titleText, S)
    lines = {};
    fields = fieldnames(S);
    if isempty(fields)
        return;
    end
    lines{end + 1} = [titleText ':']; %#ok<AGROW>
    for i = 1:numel(fields)
        key = fields{i};
        label = strrep(key, '_', ' ');
        lines{end + 1} = sprintf('  - %s: %d', label, S.(key)); %#ok<AGROW>
    end
end
