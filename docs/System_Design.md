# Exoskeleton Control System
## System Design Document
**Version:** 1.3  
**Date:** April 5, 2026

---

## 1. Executive Summary
This document describes the architecture of the software-centric control module for the ExoTechHK lower-limb exoskeleton. The system integrates inertial measurement units (IMUs), Support Vector Machine (SVM) classification, and optional Kalman Filter visualization to provide real-time, adaptive assistance.

Version 1.3 uses **HuGaDB** from **GitHub v1** only: `LoadHuGaDB.m` reads raw `.txt` files and applies the official gyro corruption matrix (CSV next to the loader). Binary and multiclass HuGaDB training/evaluation default to excluding `ExoConfig.HUGADB.HELDOUT_SUBJECTS` so the policy matches binary LSTM and held-out simulation. The common feature vector remains **30-dimensional** (six IMU slots × five statistics per slot), with **binary** and **multiclass** ECOC SVM paths and the asymmetric finite state machine for assist gating.

---

## 2. System Architecture

### 2.1 Configuration (`ExoConfig.m`)
The system is driven by a configuration class that centralizes tuning parameters.
*   **Sampling Rate:** 100 Hz  
*   **Window Size:** 1.0 s (100 samples)  
*   **Step Size:** 0.5 s (50 samples)  
*   **Paths:** `usc_had_dataset.mat`, `hugadb_dataset.mat`, `Binary_SVM_Model_hugadb_only.mat`, `Multiclass_SVM_ECOC_usc_had.mat`, `Multiclass_SVM_ECOC_hugadb.mat`  
*   **LOCOMOTION:** `N_IMU_SLOTS = 6`, `FEATURES_PER_IMU = 5` (must match `Features.m`)

### 2.2 Data Flow Pipeline
1.  **Input:** Public `.mat` caches via loaders; held-out HuGaDB sessions replay through `LoadHuGaDBSimulationData.m`.
2.  **Pre-processing:** HuGaDB cache is already normalized to m/s² and rad/s during loading.
3.  **Feature extraction:** Five features per IMU (`Features.m`). HuGaDB uses **six IMUs** per window (`FeaturesFromImuStack`). USC-HAD uses **one IMU + zero padding** (`LocomotionFeatureVector`) for benchmark comparisons.
4.  **Inference — binary:** RBF SVM (`fitcsvm`) → class 0/1 (inactive vs active movement per dataset label maps).
5.  **Inference — multiclass (optional):** ECOC SVM (`fitcecoc`) on **native** labels: USC-HAD **12** trial activities or HuGaDB **12** per-sample IDs (`ActivityClassRegistry.m`). Exo assist maps active-movement classes through `RealtimeFsmFromActivityClass.m` (dataset argument: `'usc_had'` / `'hugadb'`).
6.  **State machine:** `RealtimeFsm.m` applies asymmetric hysteresis on **binary** predictions.
7.  **Fusion:** Optional Kalman (`imufilter`) computes a segment-pitch visualization trace in parallel.
8.  **Output:** Control command (0/1) + visualization trace; multiclass scripts add activity labels for logging/plots.

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
Multiclass ECOC uses **dataset-native** IDs (no cross-dataset unification): USC-HAD **1…12** per trial, HuGaDB **1…12** per sample (window label = mode over samples). Binary training uses dataset-specific active / non-active ID groups from `ExoConfig.DS`.

### 3.3 Sensor Fusion (`FusionKalman.m`)
Static class wrapping MATLAB `imufilter`. Under the HuGaDB replay path it produces an orientation-derived segment-pitch trace for visualization.

### 3.4 Finite State Machine (`RealtimeFsm.m`)
Asymmetric hysteresis: **3** consecutive active binary predictions to enter assist; **5** consecutive inactive predictions to exit.

---

## 4. Execution & File Organization

### 4.1 Path Management
Main scripts resolve `projectRoot` locally and add `config/`, the active `scripts/` folder, and `src/` (recursive) as needed. Dataset loader functions remain under `data/USC-HAD/`, `data/HuGaDB/`, etc., and can be added to the MATLAB path when rebuilding local caches.

**USC-HAD:** `LoadUSCHAD.m` → `data/USC-HAD/usc_had_dataset.mat` (recursive raw `.mat` under `USC-HAD_raw/`).

**HuGaDB:** `LoadHuGaDB.m` → `data/HuGaDB/hugadb_dataset.mat` (GitHub v1 under `v1_cleanup_github/` flat layout or legacy nested `v1_raw`/flat paths; official gyro corruption matrix zeroes bad IMU gyros; `readmatrix` treats `na` as missing when present; all-six-corrupt trials skipped; six IMUs per row; optional manifest adds `huGaDBProvenance` / **`huGaDBSessionProtocol`**).

**Binary training / evaluation:** `TrainSvmBinary.m`, `EvaluateSvmConfusion.m`, `RunSvmDatasetAblation.m` (USC-HAD and HuGaDB).

**Multiclass:** `PrepareTrainingDataMulticlass.m`, `TrainSvmMulticlass.m`, `EvaluateMulticlassConfusion.m`, `RunTrainEvalMulticlass.m`, `RunExoskeletonPipelineMulticlass.m`.

**CUHK-REXYIM (local captures):** `ImportData.m` → `data/CUHK-REXYIM/<activity>/` with `Accelerometer.csv`, `Gyroscope.csv`, optional `Annotation.csv`.

### 4.2 Directory Structure (abridged)
```text
AutomationForExoskeleton/
├── config/                 # ExoConfig.m, ActivityClassRegistry.m
├── data/USC-HAD/           # LoadUSCHAD.m, usc_had_dataset.mat
├── data/HuGaDB/            # LoadHuGaDB.m, hugadb_dataset.mat
├── data/CUHK-REXYIM/       # project phone CSVs per activity (`ImportData.m`)
├── models/                 # Binary_SVM_Model*.mat, Multiclass_SVM_ECOC_usc_had.mat, Multiclass_SVM_ECOC_hugadb.mat
├── results/                # figures/ and metrics/ outputs
├── scripts/                # Train/eval/pipeline scripts
└── src/
    ├── acquisition/        # PrepareTrainingData*.m
    ├── classification/   # RealtimeFsm.m, RealtimeFsmFromActivityClass.m
    ├── features/         # Features.m, FeaturesFromImuStack.m, LocomotionFeatureVector.m
    └── fusion/
```
