# Robotic Exoskeleton Control System

## Project overview
Software-centric control module for a lower-limb exoskeleton (heavy load transport). Uses **Kalman fusion** (`imufilter`) for kinematics and **SVM** classification for locomotion intent. Public training data: **USC-HAD** and **HuGaDB** (optional merge).

## Current implementation (summary)

### Pipeline (100 Hz)
- **Input:** Three phone IMUs (back, hips) in simulation via `ImportData.m`; public datasets via `.mat` caches.
- **Fusion:** 6-DOF indirect Kalman filter → hip flexion angle estimate.
- **Binary assist model:** RBF SVM, **30-D** window features (5 per IMU slot × 6 slots: HuGaDB fills all; USC-HAD / simulation use one stream + zero padding). Positive class = **locomotion-like** (walk, stairs, run per label maps), not generic “any motion.”
- **Binary LSTM (optional):** sequence input `(6 × N_IMU_SLOTS) × WINDOW_SIZE` via `ImuWindowToSequenceMatrix` / `PrepareTrainingDataSequences`; train with `TrainLstmBinary` → `models/Binary_LSTM_Network.mat`; simulate with `RunExoskeletonPipelineLstm` (requires Deep Learning Toolbox).
- **Multiclass (12 activities):** ECOC + SVM (`fitcecoc`), unified labels in `ActivityClassRegistry.m`; baseline OOF accuracy is moderate on merged public data—use for analysis / future phone-specific fine-tuning.
- **FSM:** `RealtimeFsm.m` — 3 consecutive walk-like predictions to turn assist on, 5 non-locomotion to turn off.

### Typical binary CV (5-fold OOF, current feature pipeline)
Values below match the committed `results/svm_evaluation_metrics_*.mat` files (regenerate with `RunSvmDatasetAblation` or `EvaluateSvmConfusion`).

| Training set | OOF accuracy |
|--------------|----------------|
| USC-HAD only | 98.91% |
| HuGaDB only  | 88.60% |
| Merged       | 94.50% |

Run `RunSvmDatasetAblation` to regenerate all three; default `models/Binary_SVM_Model.mat` is the **merged** model.

Multiclass: run `EvaluateMulticlassConfusion` — default uses a **stratified subsample** for CV speed; latest OOF in `results/multiclass_evaluation_metrics.mat` is **56.76%**.

**Report / PDF:** run `scripts/ExportMetricsForReport.m` to refresh `docs/latex/generated_metrics.tex` so LaTeX tables and the abstract stay aligned with those `.mat` files after you re-evaluate.

## Prerequisites
- MATLAB R2020b+ (tested on R2025b).
- Toolboxes: Statistics and Machine Learning, Sensor Fusion and Tracking, Signal Processing. For LSTM training/inference: Deep Learning Toolbox.

## Quick start (project root as current folder)
```matlab
startup
```

1. **Build datasets (when raw data present)**  
   - USC-HAD: raw `.mat` under `data/public/USC-HAD/USC-HAD_raw/` → `LoadUSCHAD`  
   - HuGaDB: `.txt` under `data/public/HuGaDB/HuGaDB_v2_raw/` → `LoadHuGaDB`  
   - Those raw folders and the merged `usc_had_dataset.mat` / `hugadb_dataset.mat` caches are **not** in the GitHub repo; place downloads locally (official dataset releases), then run the loaders.

2. **Binary model**  
   - `TrainSvmBinary` — merged training if both `.mat` exist  
   - `TrainLstmBinary` — optional sequence classifier (Deep Learning Toolbox)  
   - `EvaluateLstmConfusion` — holdout confusion matrix + metrics for the trained LSTM (`results/lstm_confusion_matrix.png`)  
   - `RunSvmDatasetAblation` — USC-only, HuGaDB-only, merged + default model copy  
   - `EvaluateSvmConfusion` — confusion + metrics for reports  

3. **Multiclass model**  
   - `TrainSvmMulticlass` → `models/Multiclass_SVM_ECOC.mat`  
   - `EvaluateMulticlassConfusion`  
   - `RunExoskeletonPipelineMulticlass` — sim with activity trace + FSM from multiclass  

4. **Simulation**  
   - `RunExoskeletonPipeline` — binary SVM → `results/pipeline_output.png`  
   - `RunExoskeletonPipelineLstm` — binary LSTM (after `TrainLstmBinary`) → `results/pipeline_output_lstm.png`  

## Report / LaTeX
Sources under `docs/latex/`; figures read from `results/` (e.g. `svm_confusion_matrix.png`, `multiclass_confusion_matrix.png`, `pipeline_output.png`). After LSTM training, run `EvaluateLstmConfusion` to add `lstm_confusion_matrix.png` (the PDF includes it when present). See `docs/latex/README.md` and CI workflow `.github/workflows/build-latex-pdf.yml`.

## Acknowledgments
- **ExoTechHK Limited**, **HKSTP**, **Prof. Wei-Hsin Liao** (CUHK).  
- Datasets: HuGaDB (Chereshnev et al.); USC-HAD (Zhang et al.).
