# 🤖 AutomationForExoskeleton

This project implements a complete, simulated real-time control system for a powered lower-limb exoskeleton using Inertial Measurement Unit (IMU) data. The pipeline integrates Sensor Fusion, Locomotion Classification, and a Finite State Machine (FSM) to generate stable, continuous control commands (e.g., Stand/Walk).

## 🚀 Key Features

  * **Integrated Pipeline:** Simulates the entire real-time data flow from sensor acquisition to command generation.
  * **Sensor Fusion (Kalman Filter):** Provides robust estimation of joint kinematics (e.g., hip flexion angle) from raw accelerometer and gyroscope data.
  * **Locomotion Classification (SVM):** Uses a pre-trained Support Vector Machine on a sliding window to detect instantaneous activity (e.g., preparing to walk).
  * **Finite State Machine (FSM):** Stabilizes the classifier output to produce smooth, non-flickering control commands suitable for an exoskeleton motor controller.
  * **Performance Testing:** Dedicated script for evaluating end-to-end system metrics (Accuracy, Precision, Recall) against ground truth data.

## 🧱 Project Architecture & Data Flow

The control system is built as a sequential pipeline, running on a fixed sampling rate ($FS$) and processing data in windows ($W$) that step by a defined amount ($S$).

IMU Data → (Sensor Fusion/Kalman) → Estimated Angle → (Feature Extraction) → Feature Vector → (SVM Model) → Locomotion Label → (FSM) → Exoskeleton Command

### Core Component Files

| Path | Component | Purpose |
| :--- | :--- | :--- |
| `src/fusion/FusionKalman.m` | Kalman Filter | Estimates sensor orientation and joint angles (e.g., hip flexion) for state estimation. |
| `src/features/Features.m` | Feature Extraction | Calculates time-domain and frequency-domain features from the sliding window IMU data. |
| `models/Binary_SVM_Model.mat` | Trained Model | The pre-trained SVM used for binary classification (Locomotion vs. Non-Locomotion). |
| `src/classification/RealtimeFsm.m` | Finite State Machine | Takes the raw SVM output and current state to issue a robust motor command (0: Stand, 1: Walk). |

-----

## 🛠️ Setup and Prerequisites

### 1\. Environment

This project requires **MATLAB R2019b or later**. The following toolboxes are likely necessary (ensure they are installed):

  * Signal Processing Toolbox
  * Statistics and Machine Learning Toolbox

### 2\. Configuration

All critical parameters (Sampling Frequency, Window Size, Step Size, File Paths) are managed in:

  * `config/ExoConfig.m`

### 3\. Data & Model Preparation (Crucial)

Before running the simulation scripts, the project requires **two** main dependencies:

#### A. Raw Data

Raw IMU data must be placed in the `data/raw/` directory, organized by activity type (e.g., `walking_straight`). The simulation scripts rely on `ImportData.m` to access `.csv` files within these subdirectories.

#### B. Trained SVM Model

The pipeline relies on a pre-trained SVM model: `models/Binary_SVM_Model.mat`.

**If this file is missing, you must first run the training script:**

```matlab
>> TrainSvmBinary
```

*(Note: If `TrainSvmBinary.m` is not present, you will need to write it, utilizing `PrepareTrainingData.m` and `Classifier.m` to generate the model.)*

-----

## ▶️ Execution

### 1\. Run the Pipeline Simulation

To visualize the system's output (estimated angle, FSM command) against ground truth:

```matlab
>> RunExoskeletonPipeline
```

**Output:** A plot is saved to `results/realtime_pipeline_output.png` showing Kinematics, Control Command, and Ground Truth over time.

### 2\. Test Performance

To run the simulation and calculate quantitative classification metrics:

```matlab
>> TestPipelinePerformance
```

**Output:** Prints a detailed table to the Command Window, including **Accuracy**, **Precision**, **Recall**, and **Specificity** for the simulated activity.

### 3\. Utility Scripts

For documentation and sharing, use the helper scripts located in `scripts/utils/`:

| Utility Function | Command | Purpose |
| :--- | :--- | :--- |
| `GenerateProjectTree.m` | `>> GenerateProjectTree` | Scans the project structure and saves a text tree file (`project_tree.txt`). |
| `ConcatenateCode.m` | `>> ConcatenateCode` | Merges all `.m` source files into a single, structured file (`concatenated_code.txt`) for easy sharing. |

-----

## 📂 File Structure Summary

The project adheres to a standard data science/MLOps structure:

```
AutomationForExoskeleton/
├── config/             # System configuration file (ExoConfig.m)
├── data/               # Input data (raw, interim, processed)
├── models/             # Trained machine learning models (.mat files)
├── results/            # Pipeline output images and metrics
├── scripts/            # Executable top-level scripts
│   ├── utils/          # Utility scripts (code concatenation, tree generation)
│   ├── RunExoskeletonPipeline.m
│   └── TestPipelinePerformance.m
└── src/                # Core logic functions
    ├── acquisition/    # Data import and loading functions
    ├── classification/ # SVM and FSM logic
    ├── features/       # Feature extraction logic
    └── fusion/         # Sensor fusion logic (Kalman)
```
---

📚 References
The data structures and experimental context for this project were informed by the following public datasets:

[1] Chereshnev, R., Kertész-Farkas, A. (2018). HuGaDB: Human Gait Database for Activity Recognition from Wearable Inertial Sensor Networks. In: van der Aalst, W., et al. Analysis of Images, Social Networks and Texts. AIST 2017. Lecture Notes in Computer Science(), vol 10716. Springer, Cham. https://doi.org/10.1007/978-3-319-73013-4_12

[2] Zhang, M., & Sawchuk, A. A. (2012). USC-HAD: A daily activity dataset for ubiquitous activity recognition using wearable sensors. In Proceedings of the 2012 ACM Conference on Ubiquitous Computing (UbiComp '12) (pp. 1036–1043). ACM. https://doi.org/10.1145/2370216.2370438

---

🤝 Acknowledgements
This README documentation was drafted and refined with the assistance of an AI language model (specifically, the Gemini model built by Google). The final content, structure, and technical accuracy were verified and approved by the project author.

