function exportLstmConfusionMatrixPng(pngPath, YVal, Yhat, poolLabel, valAcc, precWalk, recWalk, f1Walk, specStand, ModelMetadata, seed, TN, FP, FN, TP, nTotal, lstmHidden1, footerLines)
%% exportLstmConfusionMatrixPng — shared figure export for binary LSTM confusion (report PNG).
% Used by EvaluateLstmConfusion and RedrawLstmConfusionFromMetrics.
%
% Optional footerLines: cellstr of extra lines (e.g. reconstruction disclaimer).

    if nargin < 18 || isempty(footerLines)
        footerLines = {};
    end

    fig = figure('Name', sprintf('LSTM Confusion — %s', poolLabel), 'Color', 'w', ...
        'Position', [100, 100, 720, 520]);

    tiled = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

    nexttile(tiled);
    hcm = confusionchart(YVal, Yhat, ...
        'Title', sprintf('%s | 20%% holdout | Acc = %.2f%%', poolLabel, valAcc * 100), ...
        'RowSummary', 'row-normalized', ...
        'ColumnSummary', 'column-normalized');
    hcm.XLabel = 'Predicted';
    hcm.YLabel = 'True';
    styleConfusionChartBlack(hcm);

    nexttile(tiled);
    axis off;
    if nargin >= 17 && ~isempty(lstmHidden1) && isnumeric(lstmHidden1)
        arch = sprintf('2x LSTM(%d), dropout 0.25, Adam', lstmHidden1);
    else
        arch = '2x LSTM(128), dropout 0.25, Adam (see TrainLstmBinary.m)';
    end
    nHoldout = numel(YVal);
    txt = {
        sprintf('Pool: %s', poolLabel);
        sprintf('Samples: %d windows | holdout ~%d', nTotal, nHoldout);
        sprintf('USC-HAD windows: %d  |  HuGaDB windows: %d', ModelMetadata.nWindowsUSCHAD, ModelMetadata.nWindowsHuGaDB);
        sprintf('Input: %d x %d (features x time)', ModelMetadata.sequenceInputSize, ModelMetadata.sequenceLength);
        sprintf('Model: %s', arch);
        sprintf('Fs=%d Hz, window=%d, step=%d', ModelMetadata.fs, ModelMetadata.windowSize, ModelMetadata.stepSize);
        sprintf('RNG seed (holdout): %d', seed);
        ' ';
        sprintf('Accuracy (holdout): %.4f%%', valAcc * 100);
        sprintf('Precision (Walk): %.4f', precWalk);
        sprintf('Recall (Walk): %.4f', recWalk);
        sprintf('F1 (Walk): %.4f', f1Walk);
        sprintf('Specificity (Stand): %.4f', specStand);
        ' ';
        'Confusion counts [True x Pred], order Stand, Walk:';
        sprintf('  TN=%d  FP=%d', TN, FP);
        sprintf('  FN=%d  TP=%d', FN, TP);
        };
    for k = 1:numel(footerLines)
        txt{end + 1} = footerLines{k};
    end
    text(0.05, 0.95, txt, 'Units', 'normalized', 'VerticalAlignment', 'top', ...
        'FontName', 'FixedWidth', 'FontSize', 11, 'Color', [0 0 0]);

    if ~exist(fileparts(pngPath), 'dir')
        mkdir(fileparts(pngPath));
    end
    styleReportFigureColors(fig);
    saveFigurePng(fig, pngPath);
    close(fig);
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
