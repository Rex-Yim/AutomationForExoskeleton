function exportSvmConfusionMatrixPng(pngPath, labelsAll, yHat, poolLabel, K, oofAccuracy, TN, FP, FN, TP, ModelMetadata, precWalk, recWalk, f1Walk, specStand)
%% exportSvmConfusionMatrixPng — shared figure export for binary SVM confusion (report PNG).
% Used by EvaluateSvmConfusion (full CV) and RedrawSvmConfusionFromMetrics (metrics .mat only).

    n = numel(labelsAll);
    fig = figure('Name', sprintf('SVM Confusion — %s', poolLabel), 'Color', 'w', ...
        'Position', [100, 100, 760, 620]);

    classNames = ActivityClassRegistry.binaryClassNames();
    if nargin >= 11 && isstruct(ModelMetadata) && isfield(ModelMetadata, 'categoryOrder') ...
            && numel(ModelMetadata.categoryOrder) == 2
        classNames = ModelMetadata.categoryOrder;
    end
    labelsCat = categorical(labelsAll, [0, 1], ...
        {sprintf('%s (0)', classNames{1}), sprintf('%s (1)', classNames{2})});
    yHatCat = categorical(yHat, [0, 1], ...
        {sprintf('%s (0)', classNames{1}), sprintf('%s (1)', classNames{2})});
    hcm = confusionchart(labelsCat, yHatCat, ...
        'Title', sprintf(['%s | %d-fold OOF | Acc = %.2f%%\n' ...
        'TN=%d  FP=%d  |  FN=%d  TP=%d  (rows=true, cols=pred)'], ...
        poolLabel, K, oofAccuracy, TN, FP, FN, TP));
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
