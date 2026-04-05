function RedrawPipelineFigures()
%% RedrawPipelineFigures — regenerate pipeline timeline PNGs (loads pretrained models; no training).
%
% Each script clears the workspace; they are run sequentially from one function call.

    here = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(here);
    cd(projectRoot);
    addpath(here);
    addpath(fullfile(projectRoot, 'config'));
    addpath(genpath(fullfile(projectRoot, 'src')));

    % Each run() invokes scripts that call clear — re-resolve path before every run (no locals survive).
    here = fileparts(mfilename('fullpath'));
    run(fullfile(here, 'RunExoskeletonPipeline.m'));
    here = fileparts(mfilename('fullpath'));
    run(fullfile(here, 'RunExoskeletonPipelineLstm.m'));
    here = fileparts(mfilename('fullpath'));
    run(fullfile(here, 'RunExoskeletonPipelineMulticlass.m'));
    here = fileparts(mfilename('fullpath'));
    run(fullfile(here, 'RunExoskeletonPipelineMulticlassLstm.m'));
end
