%% TestPipelinePerformance.m
% --------------------------------------------------------------------------
% FUNCTION: [metrics] = TestPipelinePerformance()
% PURPOSE: Runs the full real-time simulation pipeline and evaluates the 
% locomotion classification performance against ground truth labels.
% --------------------------------------------------------------------------
% DATE CREATED: 2025-12-13
% LAST MODIFIED: 2025-12-13 (Fixed ground truth binarization and missing gyro data)
% --------------------------------------------------------------------------
% DEPENDENCIES: 
% - ExoConfig.m
% - ImportData.m
% - Features.m
% - RealtimeFsm.m
% - FusionKalman.m
% - Binary_SVM_Model.mat (Trained model)
% --------------------------------------------------------------------------
% NOTES:
% - Loads ground truth from Annotation.csv for the simulated activity.
% - Calculates Accuracy, Precision (Positive Predictive Value), and Recall (Sensitivity).
% --------------------------------------------------------------------------

function [metrics] = TestPipelinePerformance()

clc; close all;
cfg = ExoConfig();

% --- 0. Pre-Flight Check ---
model_path = cfg.FILE.SVM_MODEL;
if ~exist(model_path, 'file')
error('Trained SVM Model not found. Please run TrainSvmBinary first.');
end

% --- 1. Load Trained Model and Configuration ---
% Need to load ModelMetadata to ensure compatibility, even if not fully used here
loaded = load(model_path, 'SVMModel', 'ModelMetadata');
SVMModel = loaded.SVMModel;
ModelMetadata = loaded.ModelMetadata;

FS = ModelMetadata.fs;
WINDOW_SIZE = ModelMetadata.windowSize;
STEP_SIZE = ModelMetadata.stepSize;
ACTIVITY_NAME = cfg.ACTIVITY_SIMULATION;

fprintf('--- Starting Full Pipeline Performance Test ---\n');
fprintf('Simulating Activity: %s (FS: %d Hz)\n', ACTIVITY_NAME, FS);

% --- 2. Load Data and Ground Truth ---
try
[back, hipL, ~, annotations] = ImportData(ACTIVITY_NAME); 
n_total_samples = size(back.acc, 1);

if ~ismember('Label', annotations.Properties.VariableNames) || size(annotations, 1) ~= n_total_samples
error('Annotation file is invalid or size mismatch. Cannot perform evaluation.');
end

ground_truth = annotations.Label; % Multi-class label (e.g., 1, 4, 8)

% Fix: Binarize the ground truth label to match the FSM output (0 or 1)
walking_labels = cfg.DS.USCHAD.WALKING_LABELS; 
non_walking_labels = cfg.DS.USCHAD.NON_WALKING_LABELS; 

ground_truth_binary = zeros(size(ground_truth));
% Map locomotion labels to 1 (WALKING)
ground_truth_binary(ismember(ground_truth, walking_labels)) = cfg.STATE_WALKING; 
% Map non-locomotion labels to 0 (STANDING)
ground_truth_binary(ismember(ground_truth, non_walking_labels)) = cfg.STATE_STANDING; 

catch ME
error('Data loading or ground truth check failed: %s', ME.message);
end

% --- 3. Run Simulation (Simplified Pipeline Loop) ---

% Initialize states and filters
current_fsm_state = cfg.STATE_STANDING; 
fsm_plot = zeros(n_total_samples, 1);
last_command = 0;
% Filters are initialized in RunExoskeletonPipeline, but we initialize here too
[fuse_back, fuse_hipL] = initializeFilters(FS); 

for i = 1:n_total_samples

% Kinematics (Run but results discarded here, focus is on classification)
update(fuse_back, back.acc(i,:), back.gyro(i,:));
update(fuse_hipL, hipL.acc(i,:), hipL.gyro(i,:)); 

% Classification Check
if mod(i - 1, STEP_SIZE) == 0 && (i + WINDOW_SIZE - 1) <= n_total_samples

windowAcc = back.acc(i : i+WINDOW_SIZE-1, :);
windowGyro = back.gyro(i : i+WINDOW_SIZE-1, :); % Fix: Extract Gyro window

% Fix: Pass both Accel and Gyro to Features.m
features_vec = Features(windowAcc, windowGyro, FS); 
new_label = predict(SVMModel, features_vec); 

[exoskeleton_command, current_fsm_state] = RealtimeFsm(new_label, current_fsm_state);
last_command = exoskeleton_command; 
end

fsm_plot(i) = last_command;
end

% --- 4. Performance Evaluation ---

% We compare the FSM output (fsm_plot) against the binarized ground truth.
% True Positives (TP): Walk predicted as Walk
% Fix: Use ground_truth_binary instead of raw ground_truth
TP = sum(ground_truth_binary == 1 & fsm_plot == 1);
% True Negatives (TN): Stand predicted as Stand
TN = sum(ground_truth_binary == 0 & fsm_plot == 0);
% False Positives (FP): Stand predicted as Walk (Type I Error)
FP = sum(ground_truth_binary == 0 & fsm_plot == 1);
% False Negatives (FN): Walk predicted as Stand (Type II Error)
FN = sum(ground_truth_binary == 1 & fsm_plot == 0);

% Calculate Metrics
Accuracy = (TP + TN) / (TP + TN + FP + FN);
Precision = TP / (TP + FP); % How many predicted 'Walks' were correct
Recall = TP / (TP + FN); % How many actual 'Walks' were caught
Specificity = TN / (TN + FP); % How many actual 'Stands' were caught

metrics.TP = TP;
metrics.TN = TN;
metrics.FP = FP;
metrics.FN = FN;
metrics.Accuracy = Accuracy;
metrics.Precision = Precision;
metrics.Recall = Recall;
metrics.Specificity = Specificity;


% --- 5. Report Results ---
fprintf('\n--- Classification Performance Summary ---\n');
fprintf('Target Activity: %s\n', ACTIVITY_NAME);
fprintf('Total Samples: %d\n', n_total_samples);
fprintf('------------------------------------------\n');
fprintf('True Positives (TP): %d\n', TP);
fprintf('True Negatives (TN): %d\n', TN);
fprintf('False Positives (FP): %d\n', FP);
fprintf('False Negatives (FN): %d\n', FN);
fprintf('------------------------------------------\n');
fprintf('SYSTEM ACCURACY: %.2f%%\n', Accuracy * 100);
fprintf('PRECISION (Walk): %.2f%%\n', Precision * 100);
fprintf('RECALL (Walk): %.2f%%\n', Recall * 100);
fprintf('SPECIFICITY (Stand): %.2f%%\n', Specificity * 100);
fprintf('------------------------------------------\n');

end