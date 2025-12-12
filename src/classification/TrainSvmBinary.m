%% TrainSvmBinary.m
% --------------------------------------------------------------------------
% FUNCTION: [SVMModel] = TrainSvmBinary()
% PURPOSE: Loads IMU data, extracts time-domain features using a sliding window,
%          and trains a Support Vector Machine (SVM) model for binary locomotion
%          classification (Walking vs. Non-Walking/Standing).
% --------------------------------------------------------------------------
% DATE CREATED: 2025-12-11
% LAST MODIFIED: 2025-12-14 (Implementation of training logic)
% --------------------------------------------------------------------------
% DEPENDENCIES: 
% - Features.m (from src/classification)
% - LoadUSCHAD.m (to ensure data is processed)
% - Statistics and Machine Learning Toolbox (fitcsvm, crossval, kfoldPredict)
% --------------------------------------------------------------------------
% NOTES:
% - Uses 'rbf' kernel for non-linear separation.
% - Uses USC-HAD dataset trials for training.
% - 'Walking' is labeled 1, 'Non-Walking' (Sit/Stand) is labeled 0.
% --------------------------------------------------------------------------

function [SVMModel] = TrainSvmBinary()

% --- Configuration ---
FS = 100; % Sampling Frequency of USC-HAD (Hz)
WINDOW_SIZE = FS * 1; % 1 second window (100 samples)
STEP_SIZE = FS * 0.5; % 0.5 second step (50% overlap)

% --- Data Loading ---
data_file = 'data/public/USC-HAD/usc_had_dataset.mat';
if ~exist(data_file, 'file')
    error('Processed USC-HAD data not found at %s. Please run LoadUSCHAD first.', data_file);
end
load(data_file, 'usc');

% --- Feature Extraction and Labeling ---
X = []; % Feature Matrix (N x 3 features: MeanMag, VarMag, DomFreq)
Y = []; % Label Vector (N x 1 labels: 1=Walk, 0=Non-Walk)
fieldNames = fieldnames(usc);

fprintf('Extracting features using a sliding window (Window: %d, Step: %d)...\n', WINDOW_SIZE, STEP_SIZE);

% Target activities for binary classification (USC-HAD Labels):
WALKING_LABEL = 1; % WalkForward
NON_WALKING_LABELS = [8, 9]; % Sit, Stand
VALID_LABELS = [WALKING_LABEL, NON_WALKING_LABELS];

for i = 1:length(fieldNames)
    trial = usc.(fieldNames{i});

    if ismember(trial.label, VALID_LABELS)
        % Using only the 'back' IMU data for feature extraction
        acc_data = trial.acc;
        n_samples = size(acc_data, 1);

        % Slide the window
        for k = 1:STEP_SIZE:(n_samples - WINDOW_SIZE)
            windowAcc = acc_data(k:k+WINDOW_SIZE-1, :);

            % Extract features using the defined function
            features_vec = Features(windowAcc, [], FS); % Pass [] for gyro (ignored by Features.m)

            % Map original label to binary label
            if trial.label == WALKING_LABEL
                binary_label = 1; % Walk
            else
                binary_label = 0; % Non-Walk (Sit/Stand)
            end

            X = [X; features_vec]; %#ok<AGROW>
            Y = [Y; binary_label]; %#ok<AGROW>
        end
    end
end

fprintf('Feature extraction complete. Total windows: %d\n', size(X, 1));
fprintf('Walking windows (Label 1): %d\n', sum(Y==1));
fprintf('Non-Walking windows (Label 0): %d\n', sum(Y==0));

% --- Model Training and Validation ---
rng(1); % For reproducibility

fprintf('Starting SVM Training (RBF Kernel)...\n');

% Train the SVM model
SVMModel = fitcsvm(X, Y, ...
    'KernelFunction', 'rbf', ...
    'Standardize', true, ... 
    'ClassNames', [0, 1]); 

% --- Cross-Validation for Performance Assessment ---
CVMdl = crossval(SVMModel, 'KFold', 5);
classLoss = kfoldLoss(CVMdl);
kfoldPredictions = kfoldPredict(CVMdl);

% Calculate accuracy and Confusion Matrix (results will be printed on chart)
accuracy = sum(kfoldPredictions == Y) / length(Y);
confMat = confusionchart(Y, kfoldPredictions); 

fprintf('--- Training Results ---\n');
fprintf('5-Fold Cross-Validation Loss: %.4f\n', classLoss);
fprintf('5-Fold Cross-Validation Accuracy: %.2f%%\n', accuracy * 100);

% --- Save the Trained Model ---
model_save_path = 'results/Binary_SVM_Model.mat';
save(model_save_path, 'SVMModel');
fprintf('Trained SVM Model saved to: %s\n', model_save_path);

% Optional: Plotting the features (for visualization)
figure('Name', 'Feature Space Visualization');
gscatter(X(:,1), X(:,2), Y, 'br', 'o*');
xlabel('Feature 1: Mean Accel Magnitude');
ylabel('Feature 2: Variance Accel Magnitude');
title('2D Feature Space (Walking vs. Non-Walking)');
saveas(gcf, 'results/feature_space.png');

end