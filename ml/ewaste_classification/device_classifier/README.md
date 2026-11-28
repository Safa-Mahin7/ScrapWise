# ScrapWise E-Waste AI Module

## Setup

Run these commands from the ScrapWise repository root.

Create and activate a virtual environment:

\\\powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
\\\

Install dependencies:

\\\powershell
pip install -r ml/ewaste_classification/device_classifier/requirements.txt
\\\

## Run the application

\\\powershell
streamlit run ml/ewaste_classification/device_classifier/app.py
\\\

## Models required

The application uses the following trained models:

- Device classification: ml/ewaste_classification/device_classifier/models/device_classifier_best.keras
- Class names: ml/ewaste_classification/device_classifier/models/class_names.json
- Smartphone damage assessment: ml/ewaste_classification/models/smartphone_damage_deeplab.keras
- Laptop damage detection: uns/detect/runs/laptop_damage/scrapwise_laptop/weights/best.pt
- Keyboard damage detection: uns/keyboard_damage/scrapwise_keyboard_v1/weights/best.pt
- Mouse detection: uns/mouse_detection/scrapwise_mouse_v1/weights/best.pt
- YOLO base model: yolov8n.pt

## Supported devices

- Smartphone: image-based damage assessment and condition questionnaire
- Laptop: image-based damage detection and condition assessment
- Keyboard: image-based damage detection
- Mouse: image-based damage detection
- TV: questionnaire-based condition assessment
- Microwave: questionnaire-based condition and safety assessment

## Notes

- The application performs local inference.
- Model predictions are estimates and should not replace professional repair or safety inspection.
- TV and microwave assessment currently relies on user-reported condition information rather than dedicated damage-detection models.
- All required model files must be present at their specified paths.
