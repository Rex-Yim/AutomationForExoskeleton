%% RealtimeFsm.m
% --------------------------------------------------------------------------
% FUNCTION: [command, state] = updateFSM(new_label, current_state)
% PURPOSE: Implements the Finite State Machine (FSM) to manage transitions between locomotion modes and generate exoskeleton control commands.
% --------------------------------------------------------------------------
% DATE CREATED: 2025-09-21
% LAST MODIFIED: 2025-12-12
% --------------------------------------------------------------------------
% DEPENDENCIES: 
% - None (Self-contained logic)
% --------------------------------------------------------------------------
% NOTES:
% - State smoothing: requires 3 consecutive labels to confirm a state change.
% - The output `command` is a simple low-level signal (e.g., 0=stand, 1=walk gait).
% --------------------------------------------------------------------------

function [command, next_state] = RealtimeFsm(new_label, current_state)

% --- Configuration Parameters ---
persistent state_counter % Persist across calls to track consecutive labels
if isempty(state_counter)
    state_counter = 0; % 0: Consecutive label counter
end

% Required consecutive labels to confirm a state transition
CONFIRMATION_THRESHOLD = 3; 

% --- State Definitions ---
% Use descriptive integer codes
STATE_STANDING = 0;
STATE_WALKING = 1;

% Assuming new_label comes from SVM (0=Stand, 1=Walk)

% Initialize next state and command to current values
next_state = current_state;
command = current_state; % Command is typically the same as the final state

% ----------------------------------------------------------------
% 1. CHECK FOR CONSISTENCY (Smoothing)
% ----------------------------------------------------------------

if new_label == next_state
    % Label matches current state, reset counter
    state_counter = 0;
    return; % No state change needed
end

% ----------------------------------------------------------------
% 2. CHECK FOR TRANSITION
% ----------------------------------------------------------------

if new_label ~= next_state
    % Label suggests a change; increment counter
    state_counter = state_counter + 1;

    if state_counter >= CONFIRMATION_THRESHOLD
        % Threshold reached: Execute the transition
        
        if current_state == STATE_STANDING && new_label == STATE_WALKING
            % Transition: STANDING -> WALKING
            next_state = STATE_WALKING;
            command = 1; % Low-level command to initiate walking gait
            fprintf('FSM Transition: STANDING -> WALKING\n');

        elseif current_state == STATE_WALKING && new_label == STATE_STANDING
            % Transition: WALKING -> STANDING
            next_state = STATE_STANDING;
            command = 0; % Low-level command to lock/stop exoskeleton
            fprintf('FSM Transition: WALKING -> STANDING\n');
        end

        % Reset counter after successful transition
        state_counter = 0;
    end
end

% If the threshold was not reached, next_state remains current_state
end