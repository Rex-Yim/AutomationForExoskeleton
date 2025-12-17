# Exoskeleton Control System
## System Design Document
**Version:** 1.2
**Date:** December 17, 2025

---

## Table of Contents
1. Executive Summary
2. System Architecture
3. Core Components
4. Execution Pipeline
5. Data Model
6. Design Patterns and Principles
7. Safety and Robustness
8. File Organization

---

## 1. Executive Summary
This document describes the architecture of an intelligent exoskeleton control system. The system integrates inertial measurement units (IMUs), machine learning classification, and sensor fusion to provide adaptive assistance. Version 1.2 introduces dynamic pathing, an expanded 5-dimensional feature space, and asymmetric state transition logic for improved safety.

### 1.1 Key Features
*   **5-D Feature Space:** Now includes Gyroscope mean and variance to better detect rotational gait dynamics.
*   **Asymmetric FSM:** Implementation of distinct entry (3 frames) and exit (5 frames) thresholds to prevent premature assistance termination.
*   **Dynamic Pathing:** Scripts automatically resolve project roots, allowing execution from any directory or machine.
*   **Auto-Calibration:** Input pipeline automatically detects and converts G-force units to $m/s^2$.

---

## 2. System Architecture

### 2.1 Configuration (`ExoConfig.m`)
The system is driven by a singleton configuration class that centralizes all tuning parameters.
*   **Sampling Rate:** 100 Hz
*   **Window Size:** 1.0s (100 samples)
*   **Step Size:** 0.5s (50 samples)
*   **Model Paths:** Relative paths to `models/` and `data/`.

### 2.2 Data Flow Diagram
1.  **Input:** Raw CSV (Acc + Gyro) $\to$ `ImportData.m`.
2.  **Pre-processing:** Unit conversion ($g \to m/s^2$) + Windowing.
3.  **Feature Extraction:** 5 statistical/frequency features computed per window.
4.  **Inference:** SVM (RBF Kernel) predicts Class 0 or 1.
5.  **State Machine:** FSM applies hysteresis to filter noise.
6.  **Fusion:** Kalman Filter computes Hip Flexion Angle parallel to AI.
7.  **Output:** Control Command (0/1) + Joint Angle visual.

---

## 3. Core Components

### 3.1 Feature Extraction (`Features.m`)
The feature vector has been expanded to capture rotational energy, which is critical for distinguishing "shifting weight while standing" from "turning/walking".

**Feature Vector ($1 \times 5$):**
1.  **Mean Acc Magnitude:** $\mu(|a|)$
2.  **Var Acc Magnitude:** $\sigma^2(|a|)$
3.  **Mean Gyro Magnitude:** $\mu(|\omega|)$ *(New)*
4.  **Var Gyro Magnitude:** $\sigma^2(|\omega|)$ *(New)*
5.  **Dominant Frequency:** Peak FFT frequency of Z-axis acceleration ($1-2$ Hz range).

### 3.2 Sensor Fusion (`FusionKalman.m`)
Implemented as a `Static` class wrapping MATLAB's `imufilter`.
*   **Input:** 3-axis Acc, 3-axis Gyro.
*   **Algorithm:** Indirect Kalman Filter.
*   **Output:** Orientation (Quaternion) $\to$ Euler Angles.
*   **Flexion Calculation:** $\theta_{flexion} = \text{Pitch}_{thigh} - \text{Pitch}_{back}$.

### 3.3 Finite State Machine (`RealtimeFsm.m`)
Uses **Asymmetric Hysteresis** to manage state transitions. This design prioritizes user safety by making it "easier to start, harder to stop."

*   **States:** `STANDING (0)`, `WALKING (1)`
*   **Transition Stand $\to$ Walk:**
    *   Trigger: SVM predicts 'Walk'.
    *   Threshold: **3** consecutive predictions.
    *   *Reasoning:* Quick response to initiation.
*   **Transition Walk $\to$ Stand:**
    *   Trigger: SVM predicts 'Stand'.
    *   Threshold: **5** consecutive predictions.
    *   *Reasoning:* Prevents locking the leg during a stumble, brief pause, or missed classification frame.

---

## 4. Execution Pipeline

### 4.1 Training (`TrainSvmBinary.m`)
1.  Loads `ExoConfig`.
2.  Iterates through USC-HAD dataset using `LoadUSCHAD`.
3.  Extracts 5 features per window.
4.  Trains **RBF SVM** with **Standardization** (`true`).
    *   *Note: Standardization is vital because Gyro (rad/s) and Acc (m/s²) have vastly different value ranges.*
5.  Saves model + `ModelMetadata` (FS, Window Size) to `.mat`.

### 4.2 Real-time Simulation (`RunExoskeletonPipeline.m`)
1.  **Boot:** Loads Model and initializes `persistent` FSM variables.
2.  **Loop (1...N):**
    *   Update Kalman Filter (Every sample).
    *   Check Unit Scale (Auto-fix Gs to m/s²).
    *   **Every 50 samples:** Extract Features $\to$ SVM Predict $\to$ Update FSM.
3.  **Visualization:** Plots Joint Angle overlaid with Control Commands.

---

## 6. Design Patterns

*   **Singleton Configuration:** `ExoConfig` class ensures consistent parameters across training, testing, and simulation.
*   **Static Factory:** `FusionKalman.initializeFilters()` creates configured filter objects.
*   **Persistence:** `RealtimeFsm` uses MATLAB `persistent` variables to maintain state counters without requiring global variables or external class properties.
*   **Location Independence:** All scripts use `mfilename('fullpath')` to resolve file paths relative to the project root, eliminating "File Not Found" errors on different machines.

---

## 8. File Organization

```text
AutomationForExoskeleton/
├── config/
│   └── ExoConfig.m            # Global Configuration
├── data/
│   ├── public/                # USC-HAD / HuGaDB loaders
│   └── raw/                   # Input CSVs (Activity Data)
├── models/
│   └── Binary_SVM_Model.mat   # Trained Model + Metadata
├── scripts/
│   ├── RunExoskeletonPipeline.m   # Main Simulation
│   ├── TrainSvmBinary.m           # Training Logic
│   ├── TestPipelinePerformance.m  # Accuracy/Metrics
│   └── utils/                     # Helpers (Concatenate, Tree)
└── src/
    ├── acquisition/           # ImportData, PrepareTrainingData
    ├── classification/        # RealtimeFsm, Classifier
    ├── features/              # Features.m (5-dim extraction)
    └── fusion/                # FusionKalman.m (Static class)