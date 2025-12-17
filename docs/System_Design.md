# Exoskeleton Control System
## System Design Document
**Version:** 1.1
**Date:** December 17, 2025

---

## Table of Contents
1. Executive Summary
2. System Architecture
3. Core Components
4. Execution Pipeline
5. Data Model
6. Design Patterns and Principles
7. Performance Considerations
8. Safety and Robustness
9. Extension and Customization
10. Testing and Validation
11. Deployment Considerations
12. Future Enhancements
13. File Organization
14. Conclusion

---

## 1. Executive Summary
This document describes the architecture and design of an intelligent exoskeleton control system that enables real-time locomotion state estimation and adaptive assistance. The system integrates inertial measurement units (IMUs), machine learning classification, sensor fusion, and finite state machine control to provide seamless support for human mobility.

### 1.1 Purpose
The system aims to detect and respond to different locomotion modes (walking vs. standing) in real-time to provide appropriate exoskeleton assistance while ensuring user safety and natural movement patterns.

### 1.2 Key Features
*   **Real-time locomotion classification** using Support Vector Machine (SVM) with an expanded 5-dimensional feature space.
*   **Multi-IMU sensor fusion** with Kalman filtering for accurate hip flexion angle estimation.
*   **Asymmetric Finite State Machine (FSM)** for robust state transitions with distinct entry/exit thresholds.
*   **Modular architecture** supporting multiple public datasets (USC-HAD, HuGaDB).
*   **Dynamic Pathing:** Self-locating scripts that function independently of the working directory.

---

## 2. System Architecture

### 2.1 Architecture Overview
The system follows a layered architecture with clear separation of concerns:

| Layer | Components |
| :--- | :--- |
| **Configuration** | `ExoConfig.m` - Centralized system parameters |
| **Data Acquisition** | `ImportData.m`, `PrepareTrainingData.m`, Dataset loaders (`LoadUSCHAD`, `LoadHuGaDB`) |
| **Feature Extraction** | `Features.m` - Time and frequency domain features (Acc + Gyro) |
| **Sensor Fusion** | `FusionKalman.m` - Kalman filter for orientation estimation |
| **Classification** | `Classifier.m`, `StateEstimator.m`, `RealtimeFsm.m` |
| **Training & Testing** | `TrainSvmBinary.m`, `TestPipelinePerformance.m` |
| **Execution** | `RunExoskeletonPipeline.m` - Main execution script |

### 2.2 Data Flow
The system processes data through the following pipeline:

1.  **Raw IMU Data Acquisition:** Accelerometer and gyroscope data from Back, Left Hip, and Right Hip sensors (100 Hz sampling rate).
2.  **Unit Normalization:** Automatic detection and conversion of G-force to $m/s^2$.
3.  **Windowing:** Data segmented into 1-second windows with 50% overlap (50 samples step size).
4.  **Feature Extraction:** Mean magnitude, variance, and dominant frequency computed for each window (5 features total).
5.  **Classification:** SVM classifier predicts locomotion state (walking vs. standing).
6.  **State Estimation:** FSM validates predictions using asymmetric hysteresis thresholds.
7.  **Sensor Fusion:** Kalman filter fuses accelerometer and gyroscope data for joint angle estimation.
8.  **Control Command Generation:** Commands sent to exoskeleton actuators based on confirmed state.

---

## 3. Core Components

### 3.1 Configuration Management (`ExoConfig.m`)
Centralizes all system parameters to enable easy tuning without modifying core algorithms.

**Key Parameters:**
*   `FS`: 100 Hz (IMU sampling rate)
*   `WINDOW_SIZE`: 100 samples (1.0 seconds)
*   `STEP_SIZE`: 50 samples (0.5 seconds overlap)
*   `ACCEL_NOISE`: 0.01 (Kalman filter param)
*   `GYRO_NOISE`: 0.005 (Kalman filter param)

### 3.2 Data Acquisition Layer

#### 3.2.1 `ImportData.m`
Responsible for loading raw IMU data from project-specific raw CSV files.
*   **Dynamic Pathing:** Uses `mfilename` to locate the project root relative to the script, ensuring robustness across different machines.
*   **Validation:** Checks for file existence and table integrity.

#### 3.2.2 `PrepareTrainingData.m`
Processes multiple trials from public datasets (USC-HAD) to create training/testing sets.
*   Handles sliding window segmentation.
*   Extracts the full 5-feature vector for every window.
*   Binarizes labels (Walk vs. Non-Walk) based on `ExoConfig` definitions.

### 3.3 Feature Extraction (`Features.m`)
Converts raw IMU data windows into discriminative features. The system now utilizes **5 features** (previously 3) to improve classification accuracy by incorporating rotational dynamics.

**Extracted Features:**
1.  **Mean Acceleration Magnitude:** Overall movement intensity.
2.  **Variance of Acceleration Magnitude:** Movement regularity/energy.
3.  **Mean Gyroscope Magnitude:** (New) Detects body rotation intensity.
4.  **Variance of Gyroscope Magnitude:** (New) Detects rotational volatility.
5.  **Dominant Frequency:** Extracted via FFT on Z-axis acceleration (1-2 Hz gait pattern).

### 3.4 Sensor Fusion (`FusionKalman.m`)
Implements a static class wrapper around the MATLAB `imufilter`.

**Functionality:**
*   **Initialization:** Creates independent filter objects for Back and Hip sensors with ENU reference frame.
*   **Angle Estimation:** Converts Quaternions to Euler angles (ZYX sequence) and computes the pitch difference between the Back and Hip to determine the **Hip Flexion Angle**.

### 3.5 Classification Layer

#### 3.5.1 Classifier (`Classifier.m`)
Wrapper for evaluating the SVM model on specific trials. Calculates Accuracy, Precision, Recall, and Specificity.

#### 3.5.3 Realtime FSM (`RealtimeFsm.m`)
Implements a two-state FSM with **asymmetric hysteresis** to prevent rapid oscillation (debouncing).

**States:**
*   `STATE_STANDING` (0)
*   `STATE_WALKING` (1)

**Transition Logic:**
1.  **Standing $\to$ Walking:** Requires **3** consecutive "Walking" predictions (`WALK_ENTRY_THRESHOLD`).
2.  **Walking $\to$ Standing:** Requires **5** consecutive "Standing" predictions (`STAND_EXIT_THRESHOLD`).
    *   *Rationale:* It is safer to delay stopping (keep walking) than to stop prematurely, hence the higher exit threshold.

---

## 4. Execution Pipeline

### 4.1 Training Phase (`TrainSvmBinary.m`)
1.  Loads configuration.
2.  Calls `PrepareTrainingData` to generate feature matrix (N x 5) and labels.
3.  Trains Binary SVM (RBF Kernel, Standardized).
4.  Performs 5-Fold Cross-Validation.
5.  Saves model and metadata (FS, Window Size) to `models/Binary_SVM_Model.mat`.

### 4.2 Real-time Execution (`RunExoskeletonPipeline.m`)
Simulates the embedded control loop:
1.  **Init:** Loads Model and Config; initializes Kalman Filters.
2.  **Load:** Imports raw CSV data for a specific activity (e.g., `walking_straight`).
3.  **Sanity Check:** Detects if Acceleration is in Gs (mean ~1.0) and converts to $m/s^2$ if necessary.
4.  **Loop:**
    *   Updates Kalman Filter (every sample).
    *   Extracts Features & Predicts Class (every 50 samples).
    *   Updates FSM state.
5.  **Visualize:** Generates `results/pipeline_output.png` showing joint angles and state transitions.

---

## 5. Data Model

### 5.1 IMU Data Structure
```matlab
imu_data = struct(
    'acc', [Nx3 double],  % Acceleration [m/s^2]
    'gyro', [Nx3 double]  % Angular velocity [rad/s]
);
```

### 5.3 Feature Vector Format
Five-dimensional feature space:
```matlab
features = [mean_acc, var_acc, mean_gyro, var_gyro, dom_freq]
% Size: [1 x 5] double
```

---

## 6. Design Patterns and Principles
*   **Static Factory Method:** Used in `FusionKalman` for filter initialization.
*   **Singleton/Global Config:** `ExoConfig` acts as the single source of truth.
*   **Pipeline Pattern:** `RunExoskeletonPipeline` demonstrates a linear processing flow (Input $\to$ Feature $\to$ SVM $\to$ FSM $\to$ Output).
*   **Strategy Pattern:** Different dataset loaders (`LoadUSCHAD`, `LoadHuGaDB`) normalize data into a common structure for the pipeline.

---

## 7. Performance Considerations
*   **Computational Efficiency:**
    *   FFT is only computed on the Z-axis acceleration, not all 6 axes.
    *   Features are simple statistical aggregations.
*   **Memory Management:**
    *   `RealtimeFsm` uses `persistent` variables to maintain state without global variables.
    *   `imufilter` objects are optimized for stream processing.

---

## 8. Safety and Robustness
### 8.1 FSM Safeguards
*   **Asymmetric Thresholds:** The system is biased towards "Walking." It takes longer to exit the walking state (5 frames) than to enter it (3 frames). This prevents the exoskeleton from locking up if the user momentarily stumbles or changes pace.
*   **Default Safe State:** The FSM defaults to `STATE_STANDING` on initialization or error.

### 8.2 Input Validation
*   `ImportData` and `RunExoskeletonPipeline` include checks for unit scale (Gs vs $m/s^2$).
*   `Features.m` handles edge cases where window size is too small for FFT.

---

## 13. File Organization

The project structure has been refined to include model storage and utility scripts.

```text
AutomationForExoskeleton/
├── config/
│   └── ExoConfig.m            # System parameters
├── data/
│   ├── public/                # External datasets (USC-HAD, HuGaDB)
│   └── raw/                   # Project-specific CSV inputs
├── docs/                      # Documentation
├── models/
│   └── Binary_SVM_Model.mat   # Trained SVM model
├── results/                   # Simulation plots and logs
├── scripts/
│   ├── utils/                 # Helper utilities
│   │   ├── ConcatenateCode.m
│   │   └── GenerateProjectTree.m
│   ├── RunExoskeletonPipeline.m   # Main simulation
│   ├── TestPipelinePerformance.m  # End-to-end testing
│   └── TrainSvmBinary.m           # Model training
├── src/
│   ├── acquisition/           # Data loading logic
│   ├── classification/        # SVM and FSM logic
│   ├── features/              # Feature extraction
│   └── fusion/                # Kalman filtering
├── tests/                     # Unit tests
└── startup.m                  # Path initialization
```

---

## 14. Conclusion
The Exoskeleton Control System (v1.1) represents a robust, modular platform for human locomotion assistance. By integrating gyroscope features into the classification layer and implementing asymmetric state transition logic, the system offers improved accuracy and safety over the initial design. The codebase is organized for scalability, allowing easy integration of new sensors or algorithms in future iterations.
