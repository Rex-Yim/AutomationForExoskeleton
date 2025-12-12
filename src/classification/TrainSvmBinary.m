%% TrainSvmBinary.m
% --------------------------------------------------------------------------
% FUNCTION: [] = TrainSvmBinary()
% PURPOSE: Loads IMU data, extracts time-domain features using a sliding window, and trains a Support Vector Machine (SVM) model for binary locomotion classification (Walking vs. Standing).
% --------------------------------------------------------------------------
% DATE CREATED: 2025-12-12
% LAST MODIFIED: 2025-12-12
% --------------------------------------------------------------------------
% DEPENDENCIES: 
% - ImportData.m (from src/acquisition)
% - Statistics and Machine Learning Toolbox (fitcsvm, crossval, kfoldPredict, confusionchart)
% --------------------------------------------------------------------------
% NOTES:
% - Uses 'rbf' kernel for non-linear separation.
% - Simulates ground truth labels based on time segments for initial testing.
% - Includes cross-validation and confusion matrix generation for performance assessment.
% --------------------------------------------------------------------------

% Locomotion Mode Classification: Walking vs. Standing 
% Uses Statistics and Machine Learning Toolbox

% --- Inside the main RealtimeLoop.m ---
% ... SVM loading and windowing setup ...

% Initialize FSM state
current_fsm_state = 0; % Start as STANDING (0)

for i = 1:windowSize:(length(back.acc) - windowSize)
    % 1. Extract Window and Features
    windowAcc = back.acc(i:i+windowSize-1, :);
    
    % NOTE: You should use the new extractFeatures function here!
    % features_vec = extractFeatures(windowAcc, windowGyro, Fs); 
    
    % --- For simple testing, use the two features you defined ---
    mag = sqrt(sum(windowAcc.^2, 2));
    features_vec = [mean(mag), var(mag)];
    % ----------------------------------------------------------

    % 2. Classify (Predict the next label)
    new_label = predict(SVMModel, features_vec); 

    % 3. Update FSM and get command
    [exoskeleton_command, current_fsm_state] = updateFSM(new_label, current_fsm_state);
    
    % 4. Send command to hardware (Conceptual)
    % send_to_serial(exoskeleton_command); 

end