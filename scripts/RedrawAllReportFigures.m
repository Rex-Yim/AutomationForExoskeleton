function RedrawAllReportFigures()
%% RedrawAllReportFigures — regenerate PNGs from saved metrics and training histories (no model training).
%
% Updates confusion matrices and LSTM training curve PNGs using results/metrics/*.mat.
% Pipeline time-series figures (results/figures/pipeline/<subject_session>/replay_*.png) require running the
% RunExoskeletonPipeline*.m scripts separately; they load pretrained models and replay data.

    here = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(here);
    cd(projectRoot);
    addpath(here);
    addpath(fullfile(projectRoot, 'config'));
    addpath(genpath(fullfile(projectRoot, 'src')));

    nOk = 0;

    d = dir(fullfile(projectRoot, 'results', 'metrics', 'binary', 'svm_evaluation_metrics_*.mat'));
    for k = 1:numel(d)
        try
            RedrawSvmConfusionFromMetrics(fullfile(d(k).folder, d(k).name));
            nOk = nOk + 1;
        catch ME
            warning('RedrawAllReportFigures:Svm', 'Skip %s: %s', d(k).name, ME.message);
        end
    end

    d = dir(fullfile(projectRoot, 'results', 'metrics', 'binary', 'lstm_evaluation_metrics_*.mat'));
    for k = 1:numel(d)
        try
            RedrawLstmConfusionFromMetrics(fullfile(d(k).folder, d(k).name));
            nOk = nOk + 1;
        catch ME
            warning('RedrawAllReportFigures:LstmBinary', 'Skip %s: %s', d(k).name, ME.message);
        end
    end

    d = dir(fullfile(projectRoot, 'results', 'metrics', 'multiclass', 'multiclass_evaluation_metrics_*.mat'));
    for k = 1:numel(d)
        try
            RedrawMulticlassConfusionFromMetrics(fullfile(d(k).folder, d(k).name));
            nOk = nOk + 1;
        catch ME
            warning('RedrawAllReportFigures:McSvm', 'Skip %s: %s', d(k).name, ME.message);
        end
    end

    d = dir(fullfile(projectRoot, 'results', 'metrics', 'multiclass', 'lstm_multiclass_evaluation_metrics_*.mat'));
    for k = 1:numel(d)
        try
            RedrawLstmMulticlassConfusionFromMetrics(fullfile(d(k).folder, d(k).name));
            nOk = nOk + 1;
        catch ME
            warning('RedrawAllReportFigures:McLstm', 'Skip %s: %s', d(k).name, ME.message);
        end
    end

    d = [ ...
        dir(fullfile(projectRoot, 'results', 'metrics', 'binary', '*_history.mat')); ...
        dir(fullfile(projectRoot, 'results', 'metrics', 'multiclass', '*_history.mat')) ...
        ];
    for k = 1:numel(d)
        try
            RedrawLstmTrainingCurvesFromHistory(fullfile(d(k).folder, d(k).name));
            nOk = nOk + 1;
        catch ME
            warning('RedrawAllReportFigures:History', 'Skip %s: %s', d(k).name, ME.message);
        end
    end

    fprintf('RedrawAllReportFigures: completed %d redraw steps (see warnings for any skips).\n', nOk);
    fprintf(['For pipeline PNGs (no training; loads saved nets): RedrawPipelineFigures ', ...
        'or RunExoskeletonPipeline / RunExoskeletonPipelineLstm / ', ...
        'RunExoskeletonPipelineMulticlass / RunExoskeletonPipelineMulticlassLstm.\n']);
end
