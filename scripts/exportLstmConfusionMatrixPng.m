function exportLstmConfusionMatrixPng(pngPath, YVal, Yhat, poolLabel, valAcc, precWalk, recWalk, f1Walk, specStand, ModelMetadata, seed, TN, FP, FN, TP, nTotal, lstmHidden1, footerLines)
%% exportLstmConfusionMatrixPng — shared figure export for binary LSTM confusion (report PNG).
% Used by EvaluateLstmConfusion and RedrawLstmConfusionFromMetrics.
%
% Optional footerLines: cellstr of extra lines (e.g. reconstruction disclaimer).

    if nargin < 18 || isempty(footerLines)
        footerLines = {};
    end

    fig = figure('Name', sprintf('LSTM Confusion — %s', poolLabel), 'Color', 'w', ...
        'Position', [100, 100, 720, 620]);

    hcm = confusionchart(YVal, Yhat, ...
        'Title', sprintf('%s | 20%% holdout | Acc = %.2f%%', poolLabel, valAcc * 100));
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

function saveFigurePng(fig, pngPath)
    drawnow;
    if exist('exportgraphics', 'file') == 2
        exportgraphics(fig, pngPath, 'Resolution', 200, 'Padding', 'loose');
    else
        set(fig, 'PaperPositionMode', 'auto');
        print(fig, pngPath, '-dpng', '-r200');
    end
end
