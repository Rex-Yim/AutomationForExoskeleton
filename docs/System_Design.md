# Exoskeleton Control System
## System Design Document
**Version:** 1.2  
**Date:** March 22, 2026

---

## 1. Executive Summary
This document describes the architecture of the software-centric control module for the ExoTechHK lower-limb exoskeleton. The system integrates inertial measurement units (IMUs), Support Vector Machine (SVM) classification, and Kalman Filter sensor fusion to provide real-time, adaptive assistance.

Version 1.2 documents **merged USC-HAD + HuGaDB** training with a **30-dimensional** window feature vector (six IMU slots × five statistics per slot), **binary** and **multiclass** ECOC SVM paths, and the asymmetric finite state machine for assist gating.

---

## 2. System Architecture

### 2.1 Configuration (`ExoConfig.m`)
The system is driven by a configuration class that centralizes tuning parameters.
*   **Sampling Rate:** 100 Hz  
*   **Window Size:** 1.0 s (100 samples)  
*   **Step Size:** 0.5 s (50 samples)  
*   **Paths:** `usc_had_dataset.mat`, `hugadb_dataset.mat`, `Binary_SVM_Model.mat`, `Multiclass_SVM_ECOC.mat`  
*   **LOCOMOTION:** `N_IMU_SLOTS = 6`, `FEATURES_PER_IMU = 5` (must match `Features.m`)

### 2.2 Data Flow Pipeline
1.  **Input:** Raw CSV (Acc + Gyro) via `ImportData.m` (simulation), or public `.mat` caches via loaders.
2.  **Pre-processing:** G-force heuristic → conversion to m/s² if needed.
3.  **Feature extraction:** Five features per IMU (`Features.m`). HuGaDB uses **six IMUs** per window (`FeaturesFromImuStack`). USC-HAD and on-line simulation use **one IMU + zero padding** (`LocomotionFeatureVector`) → **1×30** vector.
4.  **Inference — binary:** RBF SVM (`fitcsvm`) → class 0/1 (non-locomotion vs locomotion-like per dataset label maps).
5.  **Inference — multiclass (optional):** ECOC SVM (`fitcecoc`) → 12 unified activity names (`ActivityClassRegistry.m`). Exo assist can map locomotion-like classes through `RealtimeFsmFromActivityClass.m`.
6.  **State machine:** `RealtimeFsm.m` applies asymmetric hysteresis on **binary** predictions.
7.  **Fusion:** Kalman (`imufilter`) computes hip flexion angle in parallel.
8.  **Output:** Control command (0/1) + kinematics; multiclass scripts add activity labels for logging/plots.

---

## 3. Core Components

### 3.1 Feature Extraction (`Features.m`, `FeaturesFromImuStack.m`, `LocomotionFeatureVector.m`)
Per IMU window, the feature vector is **1×5**:
1. Mean acc magnitude  
2. Variance of acc magnitude  
3. Mean gyro magnitude  
4. Variance of gyro magnitude  
5. Dominant FFT frequency of vertical acceleration  

**Training on public data:** HuGaDB trials store **N×3×6** acc/gyro (`LoadHuGaDB.m`); stacked features are **1×30**. USC-HAD trials use one IMU → **1×5** inside `LocomotionFeatureVector` plus **25 zeros**.

### 3.2 Activity labels (`ActivityClassRegistry.m`)
Maps raw USC-HAD (12 trial activities) and HuGaDB (8 sample-level IDs) into **12 unified classes** for multiclass training. Binary training uses `ExoConfig.DS.*.WALKING_LABELS` / `NON_WALKING_LABELS`.

### 3.3 Sensor Fusion (`FusionKalman.m`)
Static class wrapping MATLAB `imufilter`. Output: orientation → hip flexion proxy vs back.

### 3.4 Finite State Machine (`RealtimeFsm.m`)
Asymmetric hysteresis: **3** consecutive walk-like binary predictions to enter walking assist; **5** consecutive non-locomotion to exit.

---

## 4. Execution & File Organization

### 4.1 Path Management
`startup.m` adds `config/`, `scripts/`, `src/` (recursive), and public dataset folders.

**USC-HAD:** `LoadUSCHAD.m` → `data/public/USC-HAD/usc_had_dataset.mat` (recursive raw `.mat` under `USC-HAD_raw/`).

**HuGaDB:** `LoadHuGaDB.m` → `data/public/HuGaDB/hugadb_dataset.mat` (recursive `**/*.txt` under `HuGaDB_v2_raw/`, six IMUs per row).

**Binary training / evaluation:** `TrainSvmBinary.m`, `EvaluateSvmConfusion.m`, `RunSvmDatasetAblation.m` (USC-only, HuGaDB-only, merged).

**Multiclass:** `PrepareTrainingDataMulticlass.m`, `TrainSvmMulticlass.m`, `EvaluateMulticlassConfusion.m`, `RunTrainEvalMulticlass.m`, `RunExoskeletonPipelineMulticlass.m`.

### 4.2 Directory Structure (abridged)
```text
AutomationForExoskeleton/
├── config/                 # ExoConfig.m, ActivityClassRegistry.m
├── data/public/USC-HAD/    # LoadUSCHAD.m, usc_had_dataset.mat
├── data/public/HuGaDB/     # LoadHuGaDB.m, hugadb_dataset.mat
├── models/                 # Binary_SVM_Model*.mat, Multiclass_SVM_ECOC.mat
├── results/                # Figures + .mat metrics
├── scripts/                # Train/eval/pipeline scripts
└── src/
    ├── acquisition/        # PrepareTrainingData*.m
    ├── classification/   # RealtimeFsm.m, RealtimeFsmFromActivityClass.m
    ├── features/         # Features.m, FeaturesFromImuStack.m, LocomotionFeatureVector.m
    └── fusion/
```
