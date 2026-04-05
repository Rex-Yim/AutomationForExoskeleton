% Debounce binary locomotion predictions into stable control states.
% The FSM applies entry and exit thresholds to reduce rapid switching
% between standing and walking commands.

function [command, new_state] = RealtimeFsm(classified_label, current_state)

cfg = ExoConfig();
STATE_STANDING = cfg.STATE_STANDING;
STATE_WALKING = cfg.STATE_WALKING;

% Tune these thresholds to trade responsiveness against prediction noise.
WALK_ENTRY_THRESHOLD = 3; 
STAND_EXIT_THRESHOLD = 5; 

persistent walk_counter stand_counter;

if isempty(walk_counter) || isempty(stand_counter)
    walk_counter = 0;
    stand_counter = 0;
end

if classified_label == STATE_WALKING
    walk_counter = walk_counter + 1;
    stand_counter = 0;
else % classified_label == STATE_STANDING
    stand_counter = stand_counter + 1;
    walk_counter = 0;
end

new_state = current_state;

switch current_state
    case STATE_STANDING
        if walk_counter >= WALK_ENTRY_THRESHOLD
            new_state = STATE_WALKING;
            stand_counter = 0; 
            fprintf('FSM Transition: STANDING -> WALKING\n');
        end
        
    case STATE_WALKING
        if stand_counter >= STAND_EXIT_THRESHOLD
            new_state = STATE_STANDING;
            walk_counter = 0;
            fprintf('FSM Transition: WALKING -> STANDING\n');
        end
        
    otherwise
        warning('FSM received an unexpected current state: %d. Defaulting to STANDING.', current_state);
        new_state = STATE_STANDING;
        
end

command = new_state;

end