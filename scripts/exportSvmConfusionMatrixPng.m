function exportSvmConfusionMatrixPng(pngPath, labelsAll, yHat, poolLabel, K, oofAccuracy, TN, FP, FN, TP, ModelMetadata, precWalk, recWalk, f1Walk, specStand)
%% exportSvmConfusionMatrixPng — shared figure export for binary SVM confusion (report PNG).
% Used by EvaluateSvmConfusion (full CV) and RedrawSvmConfusionFromMetrics (metrics .mat only).

    n = numel(labelsAll);
    fig = figure('Name', sprintf('SVM Confusion — %s', poolLabel), 'Color', 'w', ...
        'Position', [100, 100, 760, 940]);

    tiled = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'normal');
    if isprop(tiled, 'RowHeights')
        tiled.RowHeights = {'1.1x', '2.35x'};
    end

    nexttile(tiled);
    labelsCat = categorical(labelsAll, [0, 1], {'Stand (0)', 'Walk (1)'});
    yHatCat = categorical(yHat, [0, 1], {'Stand (0)', 'Walk (1)'});
    hcm = confusionchart(labelsCat, yHatCat, ...
        'Title', sprintf(['%s | %d-fold OOF | Acc = %.2f%%\n' ...
        'TN=%d  FP=%d  |  FN=%d  TP=%d  (rows=true, cols=pred)'], ...
        poolLabel, K, oofAccuracy, TN, FP, FN, TP), ...
        'RowSummary', 'row-normalized', ...
        'ColumnSummary', 'column-normalized');
    hcm.XLabel = 'Predicted';
    hcm.YLabel = 'True';
    styleConfusionChartBlack(hcm);

    axTxt = nexttile(tiled);
    axis(axTxt, 'off');
    axTxt.Clipping = 'off';
    txt = {
        sprintf('Pool: %s', poolLabel);
        sprintf('Samples: %d windows', n);
        sprintf('USC-HAD windows: %d  |  HuGaDB windows: %d', ModelMetadata.nWindowsUSCHAD, ModelMetadata.nWindowsHuGaDB);
        sprintf('Model: RBF SVM, standardized, BoxConstraint=1.0');
        sprintf('Features: %d (see Features.m)', ModelMetadata.featureCount);
        sprintf('Fs=%d Hz, window=%d, step=%d', ModelMetadata.fs, ModelMetadata.windowSize, ModelMetadata.stepSize);
        ' ';
        sprintf('Accuracy (OOF): %.4f%%', oofAccuracy);
        sprintf('Precision (Walk): %.4f', precWalk);
        sprintf('Recall (Walk): %.4f', recWalk);
        sprintf('F1 (Walk): %.4f', f1Walk);
        sprintf('Specificity (Stand): %.4f', specStand);
        };
    text(axTxt, 0.02, 0.99, txt, 'Units', 'normalized', 'VerticalAlignment', 'top', ...
        'FontName', 'FixedWidth', 'FontSize', 9, 'Color', [0 0 0]);
    xlim(axTxt, [0 1]);
    ylim(axTxt, [-0.22 1.02]);

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
