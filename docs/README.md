# AutomationForExoskeleton
Final Year Project: Robotic Exoskeleton for Load Transportation (Department of Mechanical and Automation Engineering, The Chinese University of Hong Kong)
Sep 2025 – May 2026 at CUHK, Shatin, Hong Kong

## Project Description
Project partnered with ExoTechHK Limited (HKSTP)
- Developing intention detection algorithm using MATLAB to predict user locomotion modes (walking, stair ascent/descent) and state transitions (sit-to-stand).
- Engineering multi-sensor data processing pipeline: Fused IMU data (accelerometer, gyroscope) via Kalman filtering (imufilter) to estimate accurate hips and lower back kinematics.
- Training and deploying machine learning models (SVM, LSTM) using MATLAB's Statistics & ML and Deep Learning Toolboxes, achieving high classification accuracy.
- Potential Results: Enabled proactive and seamless power assistance by translating predicted user intent into control signals for the exoskeleton's actuators, enhancing stability and reducing metabolic cost for the user.

## Data Collection Protocol
The data acquisition prototype uses three mobile phones as IMUs (leveraging built-in accelerometers, gyroscopes, and magnetometers) to simulate sensor placement on the lower limbs and back. This setup enables real-time data collection with the following standardized protocol:
- Attach phones to the left hip, right hip, and lower back.
- Perform controlled tasks: Walk 10 m on flat ground, climb 10 steps, navigate uneven surfaces, or perform sit-to-stand transitions at self-selected speeds.
- Export data as CSV files containing: 1) Accelerometer (m/s²), 2) Gyroscope (rad/s), and 3) Magnetometer (µT) readings.
- Testing includes preliminary simulations to verify data integrity and reproducibility, allowing other researchers to leverage the datasets for biomechanics studies.

This protocol ensures accessibility and fosters collaboration in wearable technology research.

## MATLAB Toolboxes/Dependencies
- MATLAB (core environment for scripting and simulation)
- Signal Processing Toolbox (for filtering and signal processing of IMU data)
- Statistics and Machine Learning Toolbox (for feature extraction, SVM training)
- Sensor Fusion and Tracking Toolbox (for IMU data fusion and Kalman filters)
- Deep Learning Toolbox (for LSTM models in sequential prediction)
- ROS Toolbox (for hardware integration and simulation with exoskeleton frames)

## Installation and Usage
1. Clone the repository: `git clone <repo-url>`
2. Ensure required toolboxes are installed in MATLAB.
3. Run `loadDataFromFile.m` to process HuGaDB data.
4. Execute `fusion_kalman.m` for sensor fusion and visualization.
5. Train models with `train_svm_binary.m`.

For contributions or issues, see LICENSE (CC0) and contact the author.