# Robotic Exoskeleton Control System

## 🚀 Project Overview
This project implements a software-centric control module for a lower-limb robotic exoskeleton, designed for heavy load transportation (>20kg). It utilizes **sensor fusion** (Kalman Filters) for kinematics estimation and **Machine Learning** (SVM) for real-time locomotion intent detection.

**Current Status:** Validation on USC-HAD dataset achieves **98.90% accuracy** with a 150ms predictive horizon.

## 🛠️ Key Features

### 1. Signal Processing Pipeline (100 Hz)
*   **Input:** 3 IMUs (Back, Left Hip, Right Hip).
*   **Fusion:** 6-DOF Indirect Kalman Filter via MATLAB `imufilter`.
*   **Output:** Real-time Hip Flexion Angle estimation.

### 2. Intention Detection (SVM)
*   **Model:** Binary Support Vector Machine (RBF Kernel).
*   **5-Dimensional Feature Space:**
    *   Translational: Mean & Variance of Acceleration.
    *   Rotational: Mean & Variance of Gyroscope (Crucial for turn detection).
    *   Frequency: Dominant Gait Frequency (FFT).

### 3. Safety Control Logic (Asymmetric FSM)
To prevent actuator "chattering" (erratic switching), the system uses asymmetric thresholds:
*   **Stand $\to$ Walk:** Triggered after **3** consecutive 'Walk' predictions (Fast response).
*   **Walk $\to$ Stand:** Triggered after **5** consecutive 'Stand' predictions (Safety buffer).

## 📂 Installation & Usage

### Prerequisites
*   MATLAB R2020b or newer.
*   Required Toolboxes:
    *   *Statistics and Machine Learning Toolbox*
    *   *Sensor Fusion and Tracking Toolbox*
    *   *Signal Processing Toolbox*

### Quick Start
1.  **Initialize Environment:**
    Sets up dynamic paths and checks for required toolboxes.
    ```matlab
    >> startup
    ```

2.  **Train the Model:**
    Loads dataset, extracts features, and trains the SVM.
    ```matlab
    >> TrainSvmBinary
    ```

3.  **Run Simulation:**
    Runs the full pipeline (Data -> Fusion -> AI -> FSM -> Control Command) and generates plots in `results/`.
    ```matlab
    >> RunExoskeletonPipeline
    ```

## 📊 Performance
The system is evaluated using 5-Fold Cross-Validation on the USC-HAD dataset.
*   **Accuracy:** 98.90%
*   **Precision:** High precision in walking detection minimizes false positives.
*   **Recall:** High recall ensures the exoskeleton does not disengage during movement.

## 🤝 Acknowledgments
*   **ExoTechHK Limited** for hardware prototype collaboration.
*   **HKSTP** for incubation support.
*   **Supervisor:** Prof. Wei-Hsin Liao, CUHK.
*   **Datasets provided by:**
    1.  Chereshnev et al. (HuGaDB)
    2.  Zhang et al. (USC-HAD)