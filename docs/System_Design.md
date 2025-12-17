# Exoskeleton Control System
## System Design Document
**Version:** 1.1
**Date:** December 17, 2025

---

## 1. Executive Summary
This document describes the architecture of the software-centric control module for the ExoTechHK lower-limb exoskeleton. The system integrates inertial measurement units (IMUs), Support Vector Machine (SVM) classification, and Kalman Filter sensor fusion to provide real-time, adaptive assistance. 

Version 1.1 introduces a refined 5-dimensional feature space to capture rotational dynamics and an Asymmetric Finite State Machine (FSM) to enhance user safety during gait transitions.

---

## 2. System Architecture

### 2.1 Configuration (`ExoConfig.m`)
The system is driven by a singleton configuration class that centralizes all tuning parameters to ensure consistency between training and simulation environments.
*   **Sampling Rate:** 100 Hz
*   **Window Size:** 1.0s (100 samples)
*   **Step Size:** 0.5s (50 samples)
*   **Data Structure:** Handles standardized formatting for USC-HAD and HuGaDB datasets.

### 2.2 Data Flow Pipeline
1.  **Input:** Raw CSV (Acc + Gyro) imported via `ImportData.m`.
2.  **Pre-processing:** Automatic detection of G-force units; conversion to $m/s^2$ if mean acceleration < 2.0g.
3.  **Feature Extraction:** 5 statistical/frequency features computed per window.
4.  **Inference:** Binary SVM (RBF Kernel) predicts Class 0 (Stand) or 1 (Walk).
5.  **State Machine:** FSM applies asymmetric hysteresis to filter noise.
6.  **Fusion:** Kalman Filter (`imufilter`) computes Hip Flexion Angle in parallel to ML.
7.  **Output:** Control Command (0/1) + Joint Kinematics.

---

## 3. Core Components

### 3.1 Feature Extraction (`Features.m`)
The feature vector has been expanded from 3 to 5 dimensions. The inclusion of Gyroscope variance is critical for distinguishing "shifting weight while standing" from actual "turning/walking".

**Feature Vector ($1 \times 5$):**
1.  **Mean Acc Magnitude:** $\mu(|a|)$ - Represents overall translational intensity.
2.  **Var Acc Magnitude:** $\sigma^2(|a|)$ - Represents movement smoothness.
3.  **Mean Gyro Magnitude:** $\mu(|\omega|)$ - **(New)** Captures rotational intensity.
4.  **Var Gyro Magnitude:** $\sigma^2(|\omega|)$ - **(New)** Captures rotational volatility/turns.
5.  **Dominant Frequency:** Peak FFT frequency of Z-axis acceleration (typically 1-2 Hz for gait).

### 3.2 Sensor Fusion (`FusionKalman.m`)
Implemented as a `Static` class wrapping MATLAB's `imufilter`.
*   **Input:** 3-axis Accelerometer, 3-axis Gyroscope.
*   **Algorithm:** Indirect Kalman Filter.
*   **Output:** Orientation (Quaternion) $\to$ Euler Angles.
*   **Kinematics:** $\theta_{flexion} = \theta_{thigh} - \theta_{back}$ (Calculated in real-time loop).

### 3.3 Finite State Machine (`RealtimeFsm.m`)
Uses **Asymmetric Hysteresis** to manage state transitions. This design prioritizes user safety by implementing an "easy to start, hard to stop" logic.

*   **States:** `STANDING (0)`, `WALKING (1)`
*   **Transition Stand $\to$ Walk:**
    *   Trigger: SVM predicts 'Walk'.
    *   Threshold: **3** consecutive frames.
    *   *Reasoning:* Ensures quick response to locomotion initiation.
*   **Transition Walk $\to$ Stand:**
    *   Trigger: SVM predicts 'Stand'.
    *   Threshold: **5** consecutive frames.
    *   *Reasoning:* Prevents the exoskeleton from locking the leg during a stumble, brief pause, or single missed classification frame.

---

## 4. Execution & File Organization

### 4.1 Path Management
The project uses dynamic path resolution (`mfilename('fullpath')`) in `startup.m` and `ConcatenateCode.m`. This allows the repository to run immediately upon cloning without manual path configuration.

### 4.2 Directory Structure
```text
AutomationForExoskeleton/
├── config/                # Global tuning (ExoConfig.m)
├── data/                  # Loaders for USC-HAD / HuGaDB
├── models/                # Trained Binary_SVM_Model.mat
├── results/               # Pipeline visualization outputs
├── scripts/               # Main executables (RunExoskeletonPipeline.m)
│   └── utils/             # Helpers (Tree generation, Code export)
└── src/                   # Core logic
    ├── classification/    # FSM and State Estimation
    ├── features/          # Feature extraction algorithms
    └── fusion/            # Kalman filter implementation
```