%% ExportMetricsForReport.m
% Writes docs/latex/generated_metrics.tex from results/svm_evaluation_metrics*.mat
% and results/multiclass_evaluation_metrics.mat so the PDF matches committed numbers.
% Run from project root after EvaluateSvmConfusion / RunSvmDatasetAblation as needed.
%
% LOCATION: scripts/ExportMetricsForReport.m

function ExportMetricsForReport()

    here = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(here);
    resultsDir = fullfile(projectRoot, 'results');
    outPath = fullfile(projectRoot, 'docs', 'latex', 'generated_metrics.tex');

    tags = {'usc_had_only', 'hugadb_only', 'merged'};
    macro = {'BinaryOofAccUsc', 'BinaryOofAccHuGa', 'BinaryOofAccMerged'};
    vals = zeros(1, 3);

    for i = 1:3
        p = fullfile(resultsDir, ['svm_evaluation_metrics_' tags{i} '.mat']);
        if ~exist(p, 'file')
            error('Missing %s — run RunSvmDatasetAblation or EvaluateSvmConfusion with tags.', p);
        end
        S = load(p, 'oofAccuracy');
        vals(i) = S.oofAccuracy;
    end

    mcPath = fullfile(resultsDir, 'multiclass_evaluation_metrics.mat');
    if ~exist(mcPath, 'file')
        error('Missing %s — run EvaluateMulticlassConfusion.', mcPath);
    end
    M = load(mcPath, 'oofAcc');
    mcAcc = M.oofAcc;

    lstmPath = fullfile(resultsDir, 'lstm_evaluation_metrics.mat');
    hasLstm = exist(lstmPath, 'file');
    if hasLstm
        L = load(lstmPath, 'valAcc');
        lstmAcc = L.valAcc * 100;
    end

    fid = fopen(outPath, 'w');
    if fid < 0
        error('Cannot open %s for write.', outPath);
    end

    fprintf(fid, '%% AUTO-GENERATED — do not edit by hand.\n');
    fprintf(fid, '%% Regenerate: scripts/ExportMetricsForReport.m\n');
    fprintf(fid, '%% Source: results/svm_evaluation_metrics_*.mat, multiclass_evaluation_metrics.mat\n');
    for i = 1:3
        fprintf(fid, '\\newcommand{\\%s}{%s}\n', macro{i}, formatPct(vals(i)));
    end
    fprintf(fid, '\\newcommand{\\MulticlassOofAcc}{%s}\n', formatPct(mcAcc));
    if hasLstm
        fprintf(fid, '\\newcommand{\\LstmHoldoutAcc}{%s}\n', formatPct(lstmAcc));
        fprintf(fid, '\\newcommand{\\HasLstmMetrics}{1}\n');
    else
        fprintf(fid, '%% Optional: run TrainLstmBinary + EvaluateLstmConfusion, then re-export.\n');
        fprintf(fid, '\\newcommand{\\HasLstmMetrics}{0}\n');
    end

    fclose(fid);
    fprintf('Wrote %s\n', outPath);
end

function s = formatPct(x)
    s = sprintf('%.2f', x);
end
