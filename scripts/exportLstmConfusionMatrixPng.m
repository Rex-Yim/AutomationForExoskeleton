function exportLstmConfusionMatrixPng(pngPath, YVal, Yhat, poolLabel, valAcc, precWalk, recWalk, f1Walk, specStand, ModelMetadata, seed, TN, FP, FN, TP, nTotal, lstmHidden1, footerLines)
%% exportLstmConfusionMatrixPng — shared figure export for binary LSTM confusion (report PNG).
% Used by EvaluateLstmConfusion and RedrawLstmConfusionFromMetrics.
%
% Optional footerLines: cellstr of extra lines (e.g. reconstruction disclaimer).

    if nargin < 18 || isempty(footerLines)
        footerLines = {};
    end

    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(projectRoot, 'config'));

    classNames = ActivityClassRegistry.binaryClassNames();
    if nargin >= 11 && isstruct(ModelMetadata) && isfield(ModelMetadata, 'categoryOrder') ...
            && numel(ModelMetadata.categoryOrder) == 2
        classNames = ModelMetadata.categoryOrder;
    end
    labelsForChart = {sprintf('%s (0)', classNames{1}), sprintf('%s (1)', classNames{2})};
    Yc = renamecats(YVal, classNames, labelsForChart);
    Yh = renamecats(Yhat, classNames, labelsForChart);

    % Match binary SVM confusion style: multi-line title (avoids left/right clipping) + same chart sizing.
    titleStr = buildLstmBinaryConfusionTitle(poolLabel, valAcc, TN, FP, FN, TP);

    fig = figure('Name', sprintf('LSTM Confusion — %s', poolLabel), 'Color', 'w', ...
        'Position', [100, 100, 760, 620]);

    hcm = confusionchart(Yc, Yh, 'Title', titleStr);
    hcm.XLabel = 'Predicted';
    hcm.YLabel = 'True';
    styleConfusionChartBlack(hcm);

    if ~exist(fileparts(pngPath), 'dir')
        mkdir(fileparts(pngPath));
    end
    styleReportFigureColors(fig);
    saveFigurePng(fig, pngPath);
    close(fig);
end

function t = buildLstmBinaryConfusionTitle(poolLabel, valAcc, TN, FP, FN, TP)
%% Multi-line title aligned with exportSvmConfusionMatrixPng (counts row + wrapped pool text).
    accLine = sprintf('20%% holdout | Acc = %.2f%%', valAcc * 100);
    cntLine = sprintf('TN=%d  FP=%d  |  FN=%d  TP=%d  (rows=true, cols=pred)', TN, FP, FN, TP);
    parts = strsplit(poolLabel, ' | ');
    parts = cellfun(@strtrim, parts, 'UniformOutput', false);
    poolBlock = strjoin(parts, sprintf('\n'));
    % confusionchart titles use TeX rules; underscores read as subscripts without Interpreter='none'.
    poolBlock = strrep(poolBlock, '_', ' ');
    t = sprintf('%s\n%s\n%s', poolBlock, accLine, cntLine);
end

function saveFigurePng(fig, pngPath)
    drawnow;
    if exist('exportgraphics', 'file') == 2
        exportgraphics(fig, pngPath, 'Resolution', 200, 'Padding', 'loose');
    else
        set(fig, 'PaperPositionMode', 'auto');
        print(fig, pngPath, '-dpng', '-r200');
    end
end
