function [tf, reason] = HuGaDBEvaluateWindowQuality(windowAcc, windowGyro, labelChunk)
% HuGaDBEvaluateWindowQuality  Validate one HuGaDB feature/sequence window.

    reason = '';
    if isempty(windowAcc) || isempty(windowGyro)
        reason = 'empty_window';
        tf = false;
        return;
    end
    if ~isequal(size(windowAcc), size(windowGyro))
        reason = 'window_shape_mismatch';
        tf = false;
        return;
    end
    if any(~isfinite(windowAcc(:))) || any(~isfinite(windowGyro(:)))
        reason = 'non_finite_signal';
        tf = false;
        return;
    end
    if nargin >= 3 && ~isempty(labelChunk) && any(~isfinite(labelChunk(:)))
        reason = 'non_finite_labels';
        tf = false;
        return;
    end
    if all(windowAcc(:) == 0) && all(windowGyro(:) == 0)
        reason = 'all_zero_window';
        tf = false;
        return;
    end
    tf = true;
end
