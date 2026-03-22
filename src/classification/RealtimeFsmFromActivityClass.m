%% RealtimeFsmFromActivityClass — map multiclass activity to binary FSM (exo assist on/off)
function [command, new_state] = RealtimeFsmFromActivityClass(activityClassId, current_state)
    loc = double(ActivityClassRegistry.isLocomotionClass(activityClassId));
    [command, new_state] = RealtimeFsm(loc, current_state);
end
