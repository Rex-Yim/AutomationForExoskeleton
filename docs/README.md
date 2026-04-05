# Robotic Exoskeleton Control System

## Project overview
Software-centric control module for a lower-limb exoskeleton (heavy load transport). The final repository path uses **HuGaDB** for training and held-out-session replay, while keeping **USC-HAD vs HuGaDB** comparisons in the paper/poster as benchmark context. **Kalman fusion** (`imufilter`) is retained for simulation-side kinematic visualization, and **SVM** classification drives locomotion intent gating.

## Current implementation (summary)

### Pipeline (100 Hz)
- **Input:** HuGaDB `.mat` cache for training and held-out HuGaDB replay via `LoadHuGaDBSimulationData.m`; USC-HAD is retained for benchmark comparisons.
- **Fusion:** Optional Kalman-filtered segment-pitch visualization from one held-out HuGaDB IMU.
- **Binary assist model:** RBF SVM, **30-D** window features (5 per IMU slot × 6 slots: HuGaDB fills all; USC-HAD uses one stream + zero padding when benchmarking). Positive class = **active movement** per dataset label maps, not only walk vs stand.
- **Binary LSTM (optional):** sequence input `(6 × N_IMU_SLOTS) × WINDOW_SIZE` via `ImuWindowToSequenceMatrix` / `PrepareTrainingDataSequences`; train with `TrainLstmBinary` → `models/Binary_LSTM_Network.mat`; simulate with `RunExoskeletonPipelineLstm` (requires Deep Learning Toolbox).
- **Multiclass:** ECOC + SVM (`fitcecoc`) on **native** labels — USC-HAD **12** trial activities or HuGaDB **12** per-sample IDs (`ActivityClassRegistry.m`); train/eval per dataset (`'Dataset'`, `'usc_had'` / `'hugadb'`). No cross-dataset multiclass label space.
- **FSM:** `RealtimeFsm.m` — 3 consecutive active predictions to turn assist on, 5 inactive predictions to turn off.

### Binary benchmarks and deployment baseline
Values below match the committed `results/metrics/binary/svm_evaluation_metrics_*.mat` files (regenerate with `RunSvmDatasetAblation` or `EvaluateSvmConfusion`).

| Training set | OOF accuracy |
|--------------|----------------|
| USC-HAD | 99.44% |
| HuGaDB  | 97.85% |

These comparison rows are kept for the report/poster table; **re-run** `RunSvmDatasetAblation` after refreshing `hugadb_dataset.mat` so the HuGaDB column matches the refreshed metrics files. The default binary HuGaDB model excludes subjects in `ExoConfig.HUGADB.HELDOUT_SUBJECTS` (same policy as binary LSTM) so held-out replay subjects stay out of training.

Multiclass: run `EvaluateMulticlassConfusion('Dataset','usc_had')` and `...('Dataset','hugadb')` — default uses a **stratified subsample** for CV speed; metrics in `results/metrics/multiclass/multiclass_evaluation_metrics_usc_had.mat` and `results/metrics/multiclass/multiclass_evaluation_metrics_hugadb.mat`.

**Report / PDF:** run `scripts/ExportMetricsForReport.m` to refresh `docs/latex/generated_metrics.tex` so LaTeX tables and the abstract stay aligned with those `.mat` files after you re-evaluate.

## Prerequisites
- MATLAB R2020b+ (tested on R2025b).
- Toolboxes: Statistics and Machine Learning, Sensor Fusion and Tracking, Signal Processing. For LSTM training/inference: Deep Learning Toolbox.

## Quick start (project root as current folder)
No global setup step is required for the main train/eval/simulation scripts; they add the paths they need at runtime.

1. **Build datasets (when raw data present)**  
   - If calling the dataset loaders from the project root, first add their folders to the MATLAB path:
   ```matlab
   addpath(fullfile(pwd, 'data', 'USC-HAD'));
   addpath(fullfile(pwd, 'data', 'HuGaDB'));
   ```
   - USC-HAD: raw `.mat` under `data/USC-HAD/USC-HAD_raw/` → `LoadUSCHAD`  
   - HuGaDB: GitHub v1 under `v1_cleanup_github/` (flat `HuGaDB_v1_*.txt`); run `LoadHuGaDB` (applies the official gyro corruption matrix from `hugadb_official_readme_gyro_corruption_matrix.csv` when reading raw `.txt` files; optional `scripts/RunBuildHuGaDBv1Cleanup.m` writes corrupted gyros as `na` in place).  
   - Those raw folders and the generated `usc_had_dataset.mat` / `hugadb_dataset.mat` caches are **not** in the GitHub repo; place downloads locally (official dataset releases), then run the builder and loaders.

2. **Binary model**  
   - `TrainSvmBinary` — default HuGaDB training  
   - `TrainLstmBinary` — optional sequence classifier (Deep Learning Toolbox)  
   - `EvaluateLstmConfusion` — holdout confusion matrix + metrics for the trained LSTM (`results/figures/binary/lstm_confusion_matrix_<tag>.png`)  
   - `RunSvmDatasetAblation` — USC-HAD and HuGaDB benchmarks + default model copy  
   - `EvaluateSvmConfusion` — confusion + metrics for reports  

3. **Multiclass model**  
   - `TrainSvmMulticlass('Dataset','usc_had')` → `models/Multiclass_SVM_ECOC_usc_had.mat`  
   - `TrainSvmMulticlass('Dataset','hugadb')` → `models/Multiclass_SVM_ECOC_hugadb.mat`  
   - `EvaluateMulticlassConfusion` with the same `'Dataset'` name-value  
   - `RunTrainEvalMulticlass` — trains both and runs both evaluations  
   - `RunExoskeletonPipelineMulticlass` — sim with HuGaDB 12-class model + FSM  

4. **Simulation**  
   - `RunExoskeletonPipeline` — binary SVM → `results/figures/pipeline/pipeline_binary_svm_output.png`  
   - `RunExoskeletonPipelineLstm` — binary LSTM (after `TrainLstmBinary`) → `results/figures/pipeline/pipeline_output_lstm.png`  

## Report / LaTeX
Sources under `docs/latex/`; compiled PDFs: **`docs/final_report.pdf`** (`docs/latex/compile.sh`) and **`docs/poster.pdf`** (`docs/latex/compile_poster.sh`). Figures now live under `results/figures/` (e.g. `binary/svm_confusion_matrix_hugadb.png`, `multiclass/multiclass_confusion_matrix_hugadb.png`, `pipeline/pipeline_binary_svm_output.png`). For the optional LSTM figure, generate `results/figures/binary/lstm_confusion_matrix_hugadb.png` via `RunLstmDatasetAblation` or `EvaluateLstmConfusion('OutputTag','hugadb', ...)`. See `docs/latex/README.md`.

## Acknowledgments
- **ExoTechHK Limited**, **HKSTP**, **Prof. Wei-Hsin Liao** (CUHK).  
- Datasets: HuGaDB (Chereshnev et al.); USC-HAD (Zhang et al.).
