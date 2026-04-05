function paths = SaveLstmTrainingArtifacts(projectRoot, modelKind, tag, trainingHistory, extra)
% SaveLstmTrainingArtifacts — write MAT history, text log, and loss/accuracy curve PNG.
%
% modelKind: 'binary' | 'multiclass'
% tag: e.g. 'usc_had', 'hugadb_streaming'
% trainingHistory: struct from MakeTrainingLogRecorder.GetHistory()
% extra: struct with optional fields earlyStopState, miniBatchSize, maxEpochsRequested,
%        learnRate, learnRateDropPeriod, learnRateDropFactor, solver (char)

    if nargin < 5 || isempty(extra)
        extra = struct();
    end

    modelKind = char(string(modelKind));
    if ~ismember(modelKind, {'binary', 'multiclass'})
        error('modelKind must be ''binary'' or ''multiclass''.');
    end
    grp = modelKind;
    prefix = sprintf('lstm_%s', modelKind);

    stem = sprintf('%s_training_%s', prefix, tag);
    matPath = ResultsArtifactPath(projectRoot, 'metrics', grp, [stem '_history.mat']);
    pngPath = ResultsArtifactPath(projectRoot, 'figures', grp, [stem '_curves.png']);
    txtPath = ResultsArtifactPath(projectRoot, 'logs', grp, [stem '.txt']);

    save(matPath, 'trainingHistory', 'tag', 'modelKind', 'extra', '-v7.3');
    fprintf('Training history MAT: %s\n', matPath);

    writeTrainingTextLog(txtPath, tag, modelKind, trainingHistory, extra);
    fprintf('Training text log: %s\n', txtPath);

    addpath(fullfile(projectRoot, 'scripts'));
    fig = plotTrainingCurves(trainingHistory, tag, modelKind, extra);
    if ~isempty(fig) && isgraphics(fig)
        styleReportFigureColors(fig);
        if exist('exportgraphics', 'file') == 2
            exportgraphics(fig, pngPath, 'Resolution', 200, 'Padding', 'loose');
        else
            set(fig, 'PaperPositionMode', 'auto');
            print(fig, pngPath, '-dpng', '-r200');
        end
        close(fig);
        fprintf('Training curves PNG: %s\n', pngPath);
    end

    paths = struct('historyMat', matPath, 'logTxt', txtPath, 'curvesPng', pngPath);
end

function writeTrainingTextLog(txtPath, tag, modelKind, H, extra)
    [fid, msg] = fopen(txtPath, 'w');
    if fid < 0
        error('Cannot write log: %s (%s)', txtPath, msg);
    end
    cleanup = onCleanup(@() fclose(fid));

    fprintf(fid, '%% LSTM training log (%s, tag=%s)\n', modelKind, tag);
    fprintf(fid, '%% Generated: %s\n', datestr(now, 31));
    if isstruct(extra)
        if isfield(extra, 'earlyStopState') && isstruct(extra.earlyStopState)
            es = extra.earlyStopState;
            if isfield(es, 'stopReason') && strlength(string(es.stopReason)) > 0
                fprintf(fid, '%% Early stop: %s\n', es.stopReason);
            end
        end
        if isfield(extra, 'miniBatchSize')
            fprintf(fid, '%% MiniBatchSize: %g\n', extra.miniBatchSize);
        end
        if isfield(extra, 'maxEpochsRequested')
            fprintf(fid, '%% MaxEpochs (requested): %g\n', extra.maxEpochsRequested);
        end
    end
    fprintf(fid, '%% Columns: iteration, epoch, trainingLoss, validationLoss, trainingAccuracy, validationAccuracy, learningRate\n');

    n = numel(H.iteration);
    for i = 1:n
        fprintf(fid, '%g\t%g\t%g\t%g\t%g\t%g\t%g\n', ...
            H.iteration(i), H.epoch(i), ...
            H.trainingLoss(i), H.validationLoss(i), ...
            H.trainingAccuracy(i), H.validationAccuracy(i), ...
            H.learningRate(i));
    end
end

function fig = plotTrainingCurves(H, tag, modelKind, extra)
    it = H.iteration;
    if isempty(it)
        warning('SaveLstmTrainingArtifacts:EmptyHistory', 'No training history rows; skipping curve PNG.');
        fig = [];
        return;
    end

    fig = figure('Name', sprintf('LSTM training (%s)', tag), 'Color', 'w', ...
        'Position', [120, 120, 900, 520], 'ToolBar', 'none', 'Visible', 'off');

    tl = H.trainingLoss;
    vl = H.validationLoss;
    ta = H.trainingAccuracy;
    va = H.validationAccuracy;

    subplot(2, 1, 1);
    hold on;
    plot(it, tl, 'Color', [0.15 0.35 0.65], 'LineWidth', 1.1, 'DisplayName', 'Training loss');
    plot(it, vl, 'Color', [0.85 0.35 0.12], 'LineWidth', 1.1, 'DisplayName', 'Validation loss');
    hold off;
    grid on;
    xlabel('Iteration');
    ylabel('Loss');
    title(sprintf('%s LSTM (%s) — loss', modelKind, tag), 'Interpreter', 'none');
    legend('Location', 'best');

    subplot(2, 1, 2);
    hold on;
    plot(it, ta, 'Color', [0.15 0.35 0.65], 'LineWidth', 1.1, 'DisplayName', 'Training acc');
    plot(it, va, 'Color', [0.12 0.55 0.35], 'LineWidth', 1.1, 'DisplayName', 'Validation acc');
    hold off;
    grid on;
    xlabel('Iteration');
    ylabel('Accuracy (%)');
    title(sprintf('%s LSTM (%s) — accuracy (MATLAB trainNetwork)', modelKind, tag), 'Interpreter', 'none');
    legend('Location', 'best');

    vm = isfinite(va) & ~isnan(va);
    if any(vm)
        [bestVal, iBest] = max(va(vm));
        idx = find(vm);
        bestIter = it(idx(iBest));
        bestEp = H.epoch(idx(iBest));
        annotationStr = sprintf('Best val acc: %.2f%% (iter %g, epoch %g)', bestVal, bestIter, bestEp);
        if isstruct(extra) && isfield(extra, 'earlyStopState') && isstruct(extra.earlyStopState)
            es = extra.earlyStopState;
            if isfield(es, 'stopRequested') && es.stopRequested && isfield(es, 'stopReason')
                annotationStr = sprintf('%s | %s', annotationStr, es.stopReason);
            end
        end
        if exist('sgtitle', 'file') == 2
            sgtitle(fig, annotationStr, 'Interpreter', 'none', 'FontSize', 11, 'FontWeight', 'normal');
        end
    end
end
