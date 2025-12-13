%% RealtimeFsm.m
% --------------------------------------------------------------------------
% FUNCTION: [command, new_state] = RealtimeFsm(classified_label, current_state)
% PURPOSE: Implements a simple Finite State Machine (FSM) to transition
% the exoskeleton control state based on the SVM classification output.
% It prevents rapid, noisy switching between STANDING (0) and WALKING (1).
% --------------------------------------------------------------------------
% DATE CREATED: 2025-12-13
% LAST MODIFIED: 2025-12-13 (Initial implementation)
% --------------------------------------------------------------------------
% DEPENDENCIES: 
% - ExoConfig.m (Requires constants for state definitions)
% --------------------------------------------------------------------------
% NOTES:
% - State 0: STANDING/NON-LOCOMOTION
% - State 1: WALKING/LOCOMOTION
% - COMMAND is the output signal for the exoskeleton actuators (0 or 1).
% --------------------------------------------------------------------------

function [command, new_state] = RealtimeFsm(classified_label, current_state)

% Load Configuration for State Constants
cfg = ExoConfig();
STATE_STANDING = cfg.STATE_STANDING; % Should be 0
STATE_WALKING = cfg.STATE_WALKING;   % Should be 1

% --- FSM Parameters (Adjust these for sensitivity/latency trade-off) ---
% The number of consecutive WALKING predictions required to transition from STANDING to WALKING.
WALK_ENTRY_THRESHOLD = 3; 
% The number of consecutive STANDING predictions required to transition from WALKING to STANDING.
STAND_EXIT_THRESHOLD = 5; 

persistent walk_counter stand_counter;

% Initialize counters on first call
if isempty(walk_counter) || isempty(stand_counter)
    walk_counter = 0;
    stand_counter = 0;
end

% --- 1. Update Transition Counters ---

if classified_label == STATE_WALKING
    walk_counter = walk_counter + 1;
    stand_counter = 0; % Reset opposing counter
else % classified_label == STATE_STANDING
    stand_counter = stand_counter + 1;
    walk_counter = 0; % Reset opposing counter
end


% --- 2. State Transition Logic ---

new_state = current_state; % Assume state remains the same

switch current_state
    case STATE_STANDING
        % Current State: STANDING (0)
        
        % Check for transition to WALKING
        if walk_counter >= WALK_ENTRY_THRESHOLD
            new_state = STATE_WALKING;
            % Reset counter for the new state's exit condition
            stand_counter = 0; 
            fprintf('FSM Transition: STANDING -> WALKING\n');
        end
        
    case STATE_WALKING
        % Current State: WALKING (1)
        
        % Check for transition back to STANDING
        if stand_counter >= STAND_EXIT_THRESHOLD
            new_state = STATE_STANDING;
            % Reset counter for the new state's exit condition
            walk_counter = 0;
            fprintf('FSM Transition: WALKING -> STANDING\n');
        end
        
    otherwise
        % Handle unexpected state (should not happen)
        warning('FSM received an unexpected current state: %d. Defaulting to STANDING.', current_state);
        new_state = STATE_STANDING;
        
end


% --- 3. Generate Control Command ---

% The control command is typically the new state itself, representing 
% whether the exoskeleton should be providing locomotion assistance (1) or 
% locked/idle (0).
command = new_state;

end