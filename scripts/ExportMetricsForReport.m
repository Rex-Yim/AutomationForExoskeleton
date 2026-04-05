% Export dataset-specific SVM and LSTM metrics to
% `docs/latex/generated_metrics.tex` so the report matches committed
% evaluation artifacts.

function ExportMetricsForReport()

    here = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(here);
    outPath = fullfile(projectRoot, 'docs', 'latex', 'generated_metrics.tex');

    svmTags = {'usc_had', 'hugadb'};
    svmMacros = {'BinaryOofAccUsc', 'BinaryOofAccHuGa'};
    svmVals = zeros(1, numel(svmTags));

    for i = 1:numel(svmTags)
        p = ResultsArtifactPath(projectRoot, 'metrics', 'binary', ['svm_evaluation_metrics_' svmTags{i} '.mat']);
        if ~exist(p, 'file')
            error('Missing %s — run RunSvmDatasetAblation or EvaluateSvmConfusion with tags.', p);
        end
        S = load(p, 'oofAccuracy');
        svmVals(i) = S.oofAccuracy;
    end

    mcUscPath = ResultsArtifactPath(projectRoot, 'metrics', 'multiclass', 'multiclass_evaluation_metrics_usc_had.mat');
    mcHuPath = ResultsArtifactPath(projectRoot, 'metrics', 'multiclass', 'multiclass_evaluation_metrics_hugadb.mat');
    if ~exist(mcUscPath, 'file') || ~exist(mcHuPath, 'file')
        error(['Missing multiclass metrics — run EvaluateMulticlassConfusion for both datasets ', ...
            '(see RunTrainEvalMulticlass). Expected:\n  %s\n  %s'], mcUscPath, mcHuPath);
    end
    Mu = load(mcUscPath, 'oofAcc');
    Mh = load(mcHuPath, 'oofAcc');
    mcAccUsc = Mu.oofAcc;
    mcAccHu = Mh.oofAcc;

    [hasBinaryLstm, lstmBinaryAccUsc, lstmBinaryAccHu] = loadBinaryLstmMetrics(projectRoot);
    [hasMulticlassLstm, lstmMulticlassAccUsc, lstmMulticlassAccHu] = loadMulticlassLstmMetrics(projectRoot);

    fid = fopen(outPath, 'w');
    if fid < 0
        error('Cannot open %s for write.', outPath);
    end

    fprintf(fid, '%% AUTO-GENERATED — do not edit by hand.\n');
    fprintf(fid, '%% Regenerate: scripts/ExportMetricsForReport.m\n');
    fprintf(fid, '%% Source: results/metrics/*/*_evaluation_metrics_*.mat\n');
    for i = 1:numel(svmMacros)
        fprintf(fid, '\\newcommand{\\%s}{%s}\n', svmMacros{i}, formatPct(svmVals(i)));
    end
    fprintf(fid, '\\newcommand{\\MulticlassOofAccUsc}{%s}\n', formatPct(mcAccUsc));
    fprintf(fid, '\\newcommand{\\MulticlassOofAccHuGa}{%s}\n', formatPct(mcAccHu));
    fprintf(fid, '%% Legacy alias: HuGaDB native multiclass ECOC OOF (same as \\MulticlassOofAccHuGa)\n');
    fprintf(fid, '\\newcommand{\\MulticlassOofAcc}{%s}\n', formatPct(mcAccHu));
    fprintf(fid, '\\newcommand{\\LstmBinaryHoldoutAccUsc}{%s}\n', formatPct(lstmBinaryAccUsc));
    fprintf(fid, '\\newcommand{\\LstmBinaryHoldoutAccHuGa}{%s}\n', formatPct(lstmBinaryAccHu));
    fprintf(fid, '\\newcommand{\\LstmMulticlassHoldoutAccUsc}{%s}\n', formatPct(lstmMulticlassAccUsc));
    fprintf(fid, '\\newcommand{\\LstmMulticlassHoldoutAccHuGa}{%s}\n', formatPct(lstmMulticlassAccHu));
    fprintf(fid, '\\newcommand{\\HasBinaryLstmMetrics}{%d}\n', hasBinaryLstm);
    fprintf(fid, '\\newcommand{\\HasMulticlassLstmMetrics}{%d}\n', hasMulticlassLstm);
    fprintf(fid, '%% Legacy aliases kept for older text blocks.\n');
    fprintf(fid, '\\newcommand{\\LstmHoldoutAcc}{%s}\n', formatPct(lstmBinaryAccHu));
    fprintf(fid, '\\newcommand{\\HasLstmMetrics}{%d}\n', hasBinaryLstm);

    fclose(fid);
    fprintf('Wrote %s\n', outPath);
end

function s = formatPct(x)
    s = sprintf('%.2f', x);
end

function [hasMetrics, accUsc, accHu] = loadBinaryLstmMetrics(projectRoot)
    accUsc = 0;
    accHu = 0;
    uscPath = ResultsArtifactPath(projectRoot, 'metrics', 'binary', 'lstm_evaluation_metrics_usc_had.mat');
    huPath = ResultsArtifactPath(projectRoot, 'metrics', 'binary', 'lstm_evaluation_metrics_hugadb.mat');
    hasMetrics = exist(uscPath, 'file') && exist(huPath, 'file');
    if hasMetrics
        Lu = load(uscPath, 'valAcc');
        Lh = load(huPath, 'valAcc');
        accUsc = Lu.valAcc * 100;
        accHu = Lh.valAcc * 100;
    end
end

function [hasMetrics, accUsc, accHu] = loadMulticlassLstmMetrics(projectRoot)
    accUsc = 0;
    accHu = 0;
    uscPath = ResultsArtifactPath(projectRoot, 'metrics', 'multiclass', 'lstm_multiclass_evaluation_metrics_usc_had.mat');
    huPath = ResultsArtifactPath(projectRoot, 'metrics', 'multiclass', 'lstm_multiclass_evaluation_metrics_hugadb.mat');
    hasMetrics = exist(uscPath, 'file') && exist(huPath, 'file');
    if hasMetrics
        Lu = load(uscPath, 'valAcc');
        Lh = load(huPath, 'valAcc');
        accUsc = Lu.valAcc * 100;
        accHu = Lh.valAcc * 100;
    end
end
