%% RealtimeFsmFromActivityClass — map native multiclass activity to binary FSM (exo assist on/off)
function [command, new_state] = RealtimeFsmFromActivityClass(activityClassId, current_state, dataset)
    if nargin < 3 || isempty(dataset)
        dataset = 'hugadb';
    end
    ds = lower(char(dataset));
    if strcmp(ds, 'usc_had')
        loc = double(ActivityClassRegistry.isLocomotionNativeUSCHAD(activityClassId));
    else
        loc = double(ActivityClassRegistry.isLocomotionNativeHuGaDB(activityClassId));
    end
    [command, new_state] = RealtimeFsm(loc, current_state);
end
