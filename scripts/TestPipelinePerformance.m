%% TestPipelinePerformance.m
% --------------------------------------------------------------------------
% FUNCTION: [metrics] = TestPipelinePerformance()
% PURPOSE: Runs the full real-time simulation pipeline and evaluates the 
%          locomotion classification performance against ground truth labels.
% --------------------------------------------------------------------------
% DATE CREATED: 2025-12-13
% LAST MODIFIED: 2025-12-17 (Added heuristic ground truth generation)
% --------------------------------------------------------------------------

function [metrics] = TestPipelinePerformance()

    clc; 
    
    % --- 1. Path Robustness Setup ---
    % Ensure ImportData works by temporarily switching to the script directory
    scriptPath = fileparts(mfilename('fullpath'));
    originalPath = pwd;
    cleanupObj = onCleanup(@() cd(originalPath)); % Auto-restore path
    cd(scriptPath);
    
    projectRoot = fileparts(scriptPath); 

    % --- 2. Configuration & Model Loading ---
    try
        cfg = ExoConfig();
        
        % Construct absolute model path
        model_path = fullfile(projectRoot, cfg.FILE.SVM_MODEL);
        
        if ~exist(model_path, 'file')
            error('Trained SVM Model not found at: %s\nPlease run TrainSvmBinary first.', model_path);
        end
        
        loaded = load(model_path, 'SVMModel', 'ModelMetadata');
        SVMModel = loaded.SVMModel;
        ModelMetadata = loaded.ModelMetadata;
        
        FS = ModelMetadata.fs;
        WINDOW_SIZE = ModelMetadata.windowSize;
        STEP_SIZE = ModelMetadata.stepSize;
        ACTIVITY_NAME = cfg.ACTIVITY_SIMULATION;
        
        fprintf('--- Starting Full Pipeline Performance Test ---\n');
        fprintf('Simulating Activity: %s (FS: %d Hz)\n', ACTIVITY_NAME, FS);
        
    catch ME
        error('Initialization failed: %s', ME.message);
    end

    % --- 3. Load Data and Ground Truth ---
    try
        [back, hipL, ~, annotations] = ImportData(ACTIVITY_NAME); 
        n_total_samples = size(back.acc, 1);

        % Flag to determine if we need to generate ground truth manually
        use_heuristic_gt = false;

        if isempty(annotations)
            warning('Annotation file is empty.');
            use_heuristic_gt = true;
        elseif ~ismember('Label', annotations.Properties.VariableNames)
            warning('Annotation file missing "Label" column.');
            use_heuristic_gt = true;
        elseif size(annotations, 1) ~= n_total_samples
            warning('Annotation mismatch: %d labels vs %d samples.', size(annotations,1), n_total_samples);
            use_heuristic_gt = true;
        end

        % --- GROUND TRUTH GENERATION ---
        if use_heuristic_gt
            fprintf('>> generating GROUND TRUTH based on Activity Name ("%s")...\n', ACTIVITY_NAME);
            
            % If activity name contains movement keywords, assume WALKING
            if contains(lower(ACTIVITY_NAME), {'walk', 'up', 'down', 'run', 'jog', 'stairs'})
                ground_truth_binary = ones(n_total_samples, 1) * cfg.STATE_WALKING;
                fprintf('   -> Assumed Truth: WALKING (1) for all samples.\n');
            else
                ground_truth_binary = ones(n_total_samples, 1) * cfg.STATE_STANDING;
                fprintf('   -> Assumed Truth: STANDING (0) for all samples.\n');
            end
        else
            % Normal processing of Annotation.csv
            ground_truth = annotations.Label; 
            walking_labels = cfg.DS.USCHAD.WALKING_LABELS; 
            non_walking_labels = cfg.DS.USCHAD.NON_WALKING_LABELS; 
            
            ground_truth_binary = zeros(size(ground_truth));
            ground_truth_binary(ismember(ground_truth, walking_labels)) = cfg.STATE_WALKING; 
            ground_truth_binary(ismember(ground_truth, non_walking_labels)) = cfg.STATE_STANDING; 
        end

    catch ME
        error('Data loading failed: %s', ME.message);
    end

    % --- 4. Run Simulation (Simplified Pipeline Loop) ---
    fprintf('Processing %d samples...\n', n_total_samples);
    
    current_fsm_state = cfg.STATE_STANDING; 
    fsm_plot = zeros(n_total_samples, 1);
    last_command = 0;
    
    % Initialize Filters
    [fuse_back, fuse_hipL] = FusionKalman.initializeFilters(FS); 

    for i = 1:n_total_samples
        % Update Kinematics (Simulate timing)
        fuse_back(back.acc(i,:), back.gyro(i,:));
        fuse_hipL(hipL.acc(i,:), hipL.gyro(i,:)); 

        % Classification Check
        if mod(i - 1, STEP_SIZE) == 0 && (i + WINDOW_SIZE - 1) <= n_total_samples
            
            windowAcc = back.acc(i : i+WINDOW_SIZE-1, :);
            windowGyro = back.gyro(i : i+WINDOW_SIZE-1, :); 

            % Extract Features (5-feature vector)
            features_vec = Features(windowAcc, windowGyro, FS); 
            
            % Predict
            new_label = predict(SVMModel, features_vec); 

            % Update FSM
            [exoskeleton_command, current_fsm_state] = RealtimeFsm(new_label, current_fsm_state);
            last_command = exoskeleton_command; 
        end
        fsm_plot(i) = last_command;
    end

    % --- 5. Performance Evaluation ---
    
    TP = sum(ground_truth_binary == 1 & fsm_plot == 1);
    TN = sum(ground_truth_binary == 0 & fsm_plot == 0);
    FP = sum(ground_truth_binary == 0 & fsm_plot == 1);
    FN = sum(ground_truth_binary == 1 & fsm_plot == 0);

    Accuracy = (TP + TN) / (TP + TN + FP + FN);
    Precision = TP / (TP + FP); 
    Recall = TP / (TP + FN); 
    Specificity = TN / (TN + FP);
    
    % Handle NaN
    if isnan(Precision), Precision = 0; end
    if isnan(Recall), Recall = 0; end
    if isnan(Specificity), Specificity = 0; end

    metrics.TP = TP; metrics.TN = TN;
    metrics.FP = FP; metrics.FN = FN;
    metrics.Accuracy = Accuracy;

    % --- 6. Report Results ---
    fprintf('\n==========================================\n');
    fprintf('   CLASSIFICATION PERFORMANCE SUMMARY\n');
    fprintf('==========================================\n');
    fprintf('Target Activity: %s\n', ACTIVITY_NAME);
    fprintf('Total Samples:   %d\n', n_total_samples);
    fprintf('------------------------------------------\n');
    fprintf('True Positives  (TP): %d\n', TP);
    fprintf('True Negatives  (TN): %d\n', TN);
    fprintf('False Positives (FP): %d\n', FP);
    fprintf('False Negatives (FN): %d\n', FN);
    fprintf('------------------------------------------\n');
    fprintf('SYSTEM ACCURACY:      %.2f%%\n', Accuracy * 100);
    fprintf('PRECISION (Walk):     %.2f%%\n', Precision * 100);
    fprintf('RECALL (Walk):        %.2f%%\n', Recall * 100);
    fprintf('SPECIFICITY (Stand):  %.2f%%\n', Specificity * 100);
    fprintf('==========================================\n');

end