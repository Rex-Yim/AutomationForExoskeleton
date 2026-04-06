% Export dataset-specific SVM and LSTM metrics to
% `docs/latex/generated_metrics.tex` so the report matches committed
% evaluation artifacts.

function ExportMetricsForReport()

    here = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(here);
    outPath = fullfile(projectRoot, 'docs', 'latex', 'generated_metrics.tex');

    svmTags = {'usc_had', 'hugadb_streaming'};
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
    mcHuPath = ResultsArtifactPath(projectRoot, 'metrics', 'multiclass', 'multiclass_evaluation_metrics_hugadb_streaming.mat');
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

    [replaySubj, replaySess] = loadReplayPipelineMeta(projectRoot);
    fprintf(fid, '%% HuGaDB replay identifiers (from replay_binary_svm metrics plotMeta under results/metrics/pipeline/<subject_session>/).\n');
    fprintf(fid, '\\newcommand{\\ReplayHuGaDBSubject}{%s}\n', latexMacroText(replaySubj));
    fprintf(fid, '\\newcommand{\\ReplayHuGaDBSession}{%s}\n', latexMacroText(replaySess));

    if ~isequal(replaySubj, '?') && ~isequal(replaySess, '?')
        tag = sprintf('subject%s_session%s', replaySubj, replaySess);
        fprintf(fid, '%% Canonical replay PNG paths (same files as RunReplayGalleryBatch for this session).\n');
        fprintf(fid, '\\newcommand{\\ReplayPipelineFigBinarySvm}{%s/replay_binary_svm_%s.png}\n', tag, tag);
        fprintf(fid, '\\newcommand{\\ReplayPipelineFigBinaryLstm}{%s/replay_binary_lstm_%s.png}\n', tag, tag);
        fprintf(fid, '\\newcommand{\\ReplayPipelineFigMulticlassSvm}{%s/replay_multiclass_svm_%s.png}\n', tag, tag);
        fprintf(fid, '\\newcommand{\\ReplayPipelineFigMulticlassLstm}{%s/replay_multiclass_lstm_%s.png}\n', tag, tag);
    else
        fprintf(fid, '%% Replay pipeline figure paths unknown — run RunExoskeletonPipeline then ExportMetricsForReport.\n');
        fprintf(fid, '\\newcommand{\\ReplayPipelineFigBinarySvm}{?}\n');
        fprintf(fid, '\\newcommand{\\ReplayPipelineFigBinaryLstm}{?}\n');
        fprintf(fid, '\\newcommand{\\ReplayPipelineFigMulticlassSvm}{?}\n');
        fprintf(fid, '\\newcommand{\\ReplayPipelineFigMulticlassLstm}{?}\n');
    end

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
    huPath = ResultsArtifactPath(projectRoot, 'metrics', 'binary', 'lstm_evaluation_metrics_hugadb_streaming.mat');
    hasMetrics = exist(uscPath, 'file') && exist(huPath, 'file');
    if hasMetrics
        Lu = load(uscPath, 'valAcc');
        Lh = load(huPath, 'valAcc');
        accUsc = Lu.valAcc * 100;
        accHu = Lh.valAcc * 100;
    end
end

function [subj, sess] = loadReplayPipelineMeta(projectRoot)
    subj = '?';
    sess = '?';
    addpath(fullfile(projectRoot, 'config'));
    addpath(fullfile(projectRoot, 'scripts'));
    cfg = ExoConfig();
    tag = sprintf('subject%s_session%s', cfg.HUGADB.DEFAULT_SIM_SUBJECT, cfg.HUGADB.DEFAULT_SIM_SESSION);
    pNew = ResultsArtifactPath(projectRoot, 'metrics', 'pipeline', sprintf('replay_binary_svm_%s.mat', tag), tag);
    pOld = ResultsArtifactPath(projectRoot, 'metrics', 'pipeline', 'pipeline_binary_svm_output.mat');
    if exist(pNew, 'file')
        p = pNew;
    elseif exist(pOld, 'file')
        p = pOld;
    else
        return;
    end
    S = load(p, 'plotMeta');
    if ~isfield(S, 'plotMeta')
        return;
    end
    pm = S.plotMeta;
    if isfield(pm, 'subjectId') && ~isempty(pm.subjectId)
        subj = char(string(pm.subjectId));
    end
    if isfield(pm, 'sessionId') && ~isempty(pm.sessionId)
        sess = char(string(pm.sessionId));
    end
end

function s = latexMacroText(raw)
    if nargin < 1 || isempty(strtrim(char(string(raw))))
        s = '?';
        return;
    end
    s = char(string(raw));
    s = strrep(s, '\', '\textbackslash{}');
    s = strrep(s, '{', '\{');
    s = strrep(s, '}', '\}');
    s = strrep(s, '_', '\_');
    s = strrep(s, '%', '\%');
    s = strrep(s, '#', '\#');
    s = strrep(s, '&', '\&');
end

function [hasMetrics, accUsc, accHu] = loadMulticlassLstmMetrics(projectRoot)
    accUsc = 0;
    accHu = 0;
    uscPath = ResultsArtifactPath(projectRoot, 'metrics', 'multiclass', 'lstm_multiclass_evaluation_metrics_usc_had.mat');
    huPath = ResultsArtifactPath(projectRoot, 'metrics', 'multiclass', 'lstm_multiclass_evaluation_metrics_hugadb_streaming.mat');
    hasMetrics = exist(uscPath, 'file') && exist(huPath, 'file');
    if hasMetrics
        Lu = load(uscPath, 'valAcc');
        Lh = load(huPath, 'valAcc');
        accUsc = Lu.valAcc * 100;
        accHu = Lh.valAcc * 100;
    end
end
