# Robotic Exoskeleton Control System

## 🚀 Project Overview
This project implements a software-centric control module for a lower-limb robotic exoskeleton. It utilizes **sensor fusion** (Kalman Filters) for kinematics and **Machine Learning** (SVM) for real-time locomotion intent detection.

## 🛠️ System Architecture

### 1. Signal Processing Pipeline (100 Hz)
*   **Input:** 3 IMUs (Back, Left Hip, Right Hip).
*   **Fusion:** 6-DOF Kalman Filter (Indirect) via MATLAB `imufilter`.
*   **Output:** Hip Flexion Angle ($\theta_{flexion} = \theta_{thigh} - \theta_{back}$).

### 2. Machine Learning (Intention Detection)
*   **Model:** Binary SVM (RBF Kernel).
*   **Features (5-D Vector):**
    1.  `Mean_Acc`: Overall energy.
    2.  `Var_Acc`: Movement smoothness.
    3.  `Mean_Gyro`: Rotational intensity.
    4.  `Var_Gyro`: Rotational volatility.
    5.  `Dom_Freq`: Gait cadence (FFT).
*   **Performance:** ~98.8% Accuracy (USC-HAD 5-Fold CV).

### 3. Safety Control Logic (FSM)
To prevent erratic switching, the system uses **Asymmetric Hysteresis**:
*   **Stand $\to$ Walk:** Triggered after **3** consecutive 'Walk' predictions.
*   **Walk $\to$ Stand:** Triggered after **5** consecutive 'Stand' predictions.
*   *Benefit:* This "easy to start, hard to stop" logic prevents the exoskeleton from locking up during brief hesitations.

## 📂 Installation & Usage

### Prerequisites
*   MATLAB R2020b+
*   Toolboxes: *Statistics and Machine Learning*, *Sensor Fusion*, *Signal Processing*.

### Quick Start
1.  **Initialize Environment:**
    ```matlab
    >> startup
    ```
2.  **Train Model:** (Required first run)
    ```matlab
    >> TrainSvmBinary
    ```
3.  **Run Simulation:**
    ```matlab
    >> RunExoskeletonPipeline
    ```

## 📊 Directory Structure
*   `config/`: Global tuning parameters (Window size: 1.0s, Step: 0.5s).
*   `src/fusion/`: Kalman filter implementation.
*   `src/features/`: Feature extraction algorithms.
*   `src/classification/`: SVM prediction and FSM state logic.

## 🤝 Acknowledgments

*   **ExoTechHK Limited** for collaboration and prototype access.
*   **HKSTP** for incubation support.
*   **Datasets provided by:**
    1.  Chereshnev et al. (HuGaDB)
    2.  Zhang et al. (USC-HAD)

