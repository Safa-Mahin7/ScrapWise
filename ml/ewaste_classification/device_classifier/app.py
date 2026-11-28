import json
from pathlib import Path

import numpy as np
import streamlit as st
import tensorflow as tf
from PIL import Image
from ultralytics import YOLO
from tensorflow.keras.applications.mobilenet_v2 import preprocess_input

ROOT = Path(__file__).resolve().parent
MODEL_PATH = ROOT / "models" / "device_classifier_best.keras"
CLASS_PATH = ROOT / "models" / "class_names.json"

PROJECT_ROOT = ROOT.parents[2]
KEYBOARD_DAMAGE_MODEL = PROJECT_ROOT / "runs" / "keyboard_damage" / "scrapwise_keyboard_v1" / "weights" / "best.pt"

MOUSE_DAMAGE_MODEL = (
    PROJECT_ROOT / "runs" / "mouse_detection" /
    "scrapwise_mouse_v1" / "weights" / "best.pt"
)

LAPTOP_DAMAGE_MODEL = (
    PROJECT_ROOT / "runs" / "detect" / "runs" /
    "laptop_damage" / "scrapwise_laptop" / "weights" / "best.pt"
)

ICONS = {
    "smartphone": "Phone",
    "laptop": "Laptop",
    "tv": "Television",
    "keyboard": "Keyboard",
    "mouse": "Mouse",
    "microwave": "Microwave"
}

MATERIALS = {
    "smartphone": "Glass, aluminium, plastics, copper, battery and electronic components",
    "laptop": "Aluminium, plastics, copper, battery, glass and electronic components",
    "tv": "Glass, plastics, copper and electronic components",
    "keyboard": "Plastics, copper and electronic components",
    "mouse": "Plastics, copper and electronic components",
    "microwave": "Steel, copper, plastics, glass and electronic components"
}

st.set_page_config(
    page_title="ScrapWise | E-waste Assessment",
    page_icon="S",
    layout="wide"
)

st.markdown("""
<style>

/* Main application */
.stApp {
    background-color: #f5f8f5;
    color: #1b2d23;
}

/* Main content width and spacing */
.block-container {
    max-width: 1150px;
    padding-top: 2rem;
    padding-bottom: 3rem;
}

/* Headings */
h1, h2, h3, h4, h5, h6 {
    color: #183d2b !important;
}

/* Normal text */
p, li, label, .stMarkdown, .stCaption {
    color: #263b30;
}

/* Hero section */
.hero {
    padding: 30px;
    border-radius: 20px;
    background: linear-gradient(120deg, #e5f3e9, #f1f7f2);
    border: 1px solid #c8dfce;
    margin-bottom: 24px;
}

.hero h1 {
    font-size: 38px;
    color: #174b31 !important;
}

.hero p {
    color: #385c47 !important;
}

/* Input fields */
div[data-baseweb="input"],
div[data-baseweb="textarea"] {
    background-color: #ffffff !important;
    border-color: #b8cdbd !important;
}

div[data-baseweb="input"] input,
div[data-baseweb="textarea"] textarea,
.stTextInput input,
.stNumberInput input {
    color: #172c22 !important;
    background-color: #ffffff !important;
}

/* Dropdowns */
div[data-baseweb="select"] > div {
    background-color: #ffffff !important;
    border-color: #b8cdbd !important;
}

div[data-baseweb="select"] *,
div[data-baseweb="popover"] *,
ul[role="listbox"] *,
li[role="option"] * {
    color: #172c22 !important;
}

/* Dropdown popup */
div[data-baseweb="popover"],
div[data-baseweb="menu"] {
    background-color: #ffffff !important;
}

/* Radio buttons and checkboxes */
div[data-testid="stRadio"] label,
div[data-testid="stCheckbox"] label {
    color: #263b30 !important;
}

/* Buttons */
.stButton button {
    width: 100%;
    border-radius: 10px;
    min-height: 48px;
    background-color: #247447;
    color: #ffffff !important;
    border: 1px solid #247447;
    font-weight: 600;
}

.stButton button:hover {
    background-color: #185b35;
    color: #ffffff !important;
    border-color: #185b35;
}

/* Metrics */
div[data-testid="stMetric"] {
    background: #ffffff;
    border: 1px solid #d6e5da;
    padding: 16px;
    border-radius: 14px;
}

div[data-testid="stMetric"] label,
div[data-testid="stMetric"] p,
div[data-testid="stMetric"] div {
    color: #1b3828 !important;
}

/* Expanders */
div[data-testid="stExpander"] {
    background-color: #ffffff;
    border: 1px solid #d5e3d9;
    border-radius: 12px;
}

div[data-testid="stExpander"] summary,
div[data-testid="stExpander"] summary * {
    color: #1b3828 !important;
}

/* Forms and bordered containers */
div[data-testid="stForm"],
div[data-testid="stVerticalBlockBorderWrapper"] {
    border-color: #d5e3d9;
    border-radius: 12px;
}

/* File uploader */
div[data-testid="stFileUploader"] {
    background-color: #ffffff;
    border: 1px dashed #9dbda7;
    border-radius: 12px;
    padding: 10px;
}

div[data-testid="stFileUploader"] * {
    color: #263b30 !important;
}

/* Captions */
.stCaption, [data-testid="stCaptionContainer"] * {
    color: #52695b !important;
}

/* Alerts */
div[data-testid="stAlert"] {
    border-radius: 10px;
}

/* Horizontal divider */
hr {
    border-color: #d5e3d9;
}

/* Disabled controls */
input:disabled, textarea:disabled {
    color: #65776b !important;
    background-color: #edf1ee !important;
}

</style>
""", unsafe_allow_html=True)


@st.cache_resource
def load_model():
    model = tf.keras.models.load_model(MODEL_PATH)
    with open(CLASS_PATH, "r", encoding="utf-8") as f:
        classes = json.load(f)
    return model, classes


@st.cache_resource
def load_device_detector():
    return YOLO(str(PROJECT_ROOT / "yolov8n.pt"))


def identify_device(image):
    detector = load_device_detector()

    results = detector.predict(
        source=image,
        imgsz=640,
        conf=0.15,
        device="cpu",
        verbose=False
    )

    result = results[0]

    mapping = {
        "cell phone": "smartphone",
        "laptop": "laptop",
        "tv": "tv",
        "keyboard": "keyboard",
        "mouse": "mouse",
        "microwave": "microwave"
    }

    candidates = []

    if result.boxes is not None:
        for box in result.boxes:
            label = result.names[int(box.cls[0])]
            confidence = float(box.conf[0])

            if label in mapping:
                candidates.append({
                    "device": mapping[label],
                    "confidence": confidence,
                    "original_label": label
                })

    if candidates:
        candidates.sort(key=lambda x: x["confidence"], reverse=True)
        best = candidates[0]

        top_predictions = [
            {
                "device": item["device"],
                "confidence": item["confidence"]
            }
            for item in candidates[:3]
        ]

        return best["device"], best["confidence"], top_predictions

    # Fallback: use ImageNet classification if YOLO finds no supported object
    fallback = tf.keras.applications.MobileNetV2(
        weights="imagenet",
        include_top=True
    )

    resized = image.convert("RGB").resize((224, 224))
    arr = np.array(resized, dtype=np.float32)
    arr = np.expand_dims(arr, axis=0)
    arr = tf.keras.applications.mobilenet_v2.preprocess_input(arr)

    scores = fallback.predict(arr, verbose=0)[0]
    indices = np.argsort(scores)[::-1][:5]

    decoded = tf.keras.applications.mobilenet_v2.decode_predictions(
        np.expand_dims(scores, axis=0), top=5
    )[0]

    imagenet_predictions = [
        {
            "name": name.replace("_", " "),
            "confidence": float(scores[index])
        }
        for index, (_, name, _) in zip(indices, decoded)
    ]

    # Map recognizable ImageNet labels to our supported device categories.
    category_mapping = {
        "mouse": "mouse",
        "trackball": "mouse",
        "keyboard": "keyboard",
        "laptop": "laptop",
        "notebook": "laptop",
        "television": "tv",
        "tv": "tv",
        "monitor": "tv",
        "microwave": "microwave",
        "cellular telephone": "smartphone",
        "mobile phone": "smartphone",
        "smartphone": "smartphone",
        "cell phone": "smartphone"
    }

    identified_device = "smartphone"
    identified_confidence = 0.0

    for prediction in imagenet_predictions:
        label = prediction["name"].lower()

        matched_device = next(
            (
                category
                for keyword, category in category_mapping.items()
                if keyword in label
            ),
            None
        )

        if matched_device:
            identified_device = matched_device
            identified_confidence = prediction["confidence"]
            break

    top_predictions = [
        {
            "device": prediction["name"].title(),
            "confidence": prediction["confidence"]
        }
        for prediction in imagenet_predictions
    ]

    return identified_device, identified_confidence, top_predictions


@st.cache_resource
def load_laptop_damage_model():
    if not LAPTOP_DAMAGE_MODEL.exists():
        return None
    return YOLO(str(LAPTOP_DAMAGE_MODEL))


def detect_laptop_damage(image):
    model = load_laptop_damage_model()
    if model is None:
        return None, "Laptop damage model file not found."

    results = model.predict(
        source=image,
        imgsz=320,
        conf=0.15,
        device="cpu",
        verbose=False
    )

    result = results[0]
    annotated = result.plot()

    detections = []
    if result.boxes is not None:
        for box in result.boxes:
            class_id = int(box.cls[0])
            confidence = float(box.conf[0])
            label = result.names[class_id]
            detections.append({
                "label": label,
                "confidence": confidence
            })

    return Image.fromarray(annotated[:, :, ::-1]), detections



@st.cache_resource
def load_keyboard_damage_model():
    if not KEYBOARD_DAMAGE_MODEL.exists():
        return None
    return YOLO(str(KEYBOARD_DAMAGE_MODEL))


def detect_keyboard_damage(image):
    model = load_keyboard_damage_model()

    if model is None:
        return None, "Keyboard damage model file not found."

    results = model.predict(
        source=image,
        imgsz=640,
        conf=0.25,
        device="cpu",
        verbose=False
    )

    result = results[0]
    annotated = result.plot()

    detections = []

    if result.boxes is not None:
        for box in result.boxes:
            class_id = int(box.cls[0])
            confidence = float(box.conf[0])
            label = result.names[class_id]

            detections.append({
                "label": label,
                "confidence": confidence
            })

    return Image.fromarray(annotated[:, :, ::-1]), detections


@st.cache_resource
def load_mouse_damage_model():
    if not MOUSE_DAMAGE_MODEL.exists():
        return None
    return YOLO(str(MOUSE_DAMAGE_MODEL))


def detect_mouse_condition(image):
    model = load_mouse_damage_model()

    if model is None:
        return None, "Unknown", 0.0

    results = model.predict(
        source=image,
        imgsz=640,
        conf=0.25,
        device="cpu",
        verbose=False
    )

    result = results[0]
    annotated = result.plot()

    prediction = "Unknown"
    confidence = 0.0

    if result.boxes is not None and len(result.boxes) > 0:
        best_box = max(result.boxes, key=lambda box: float(box.conf[0]))
        class_id = int(best_box.cls[0])
        confidence = float(best_box.conf[0])
        prediction = result.names[class_id]

    return Image.fromarray(annotated[:, :, ::-1]), prediction, confidence


def assess_device(data):
    age = data["age"]
    working = data["working"]
    damage = data["damage"]
    water = data["water"]
    repair_cost = data["repair_cost"]
    replacement_cost = data["replacement_cost"]

    if water:
        return {
            "pathway": "Professional inspection",
            "severity": "High risk",
            "reason": "Possible liquid damage. Do not power on or charge the device. Seek professional inspection.",
            "action": "Keep the device switched off and arrange safe inspection."
        }

    if damage == "Severe":
        severity = "Severe"
    elif damage == "Moderate":
        severity = "Moderate"
    elif damage == "Minor":
        severity = "Minor"
    else:
        severity = "No reported damage"

    if data.get("microwave_heating") is not None:
        heating = data["microwave_heating"]
        turntable = data["microwave_turntable"]
        door = data["microwave_door"]
        controls = data["microwave_controls"]
        safety_signs = data.get("microwave_safety_signs", [])

        microwave_issues = []

        if heating in ["Weak heating", "Not heating"]:
            microwave_issues.append("Heating: " + heating)

        if turntable in ["Intermittent", "Not working"]:
            microwave_issues.append("Turntable: " + turntable)

        if controls in ["Intermittent", "Not working"]:
            microwave_issues.append("Control panel: " + controls)

        if door in ["Loose / does not close securely", "Damaged door or seal"]:
            microwave_issues.append("Door condition: " + door)

        safety_concerns = [
            item for item in safety_signs
            if item != "None reported"
        ]

        unsafe_door = door in [
            "Loose / does not close securely",
            "Damaged door or seal"
        ]

        if safety_concerns or unsafe_door:
            concern_text = safety_concerns.copy()

            if unsafe_door:
                concern_text.append(door)

            return {
                "pathway": "Professional safety inspection",
                "severity": "High risk",
                "reason": (
                    "Potential microwave safety concerns were reported: "
                    + ", ".join(concern_text)
                    + ". The microwave should not be used until professionally inspected."
                ),
                "action": (
                    "Stop using the microwave. Disconnect it from power if safe to do so. "
                    "Do not open or dismantle its casing. Arrange professional inspection. "
                    "If repair is not viable, send it to an authorized e-waste recycler."
                ),
                "microwave_issues": microwave_issues,
                "safety_concerns": concern_text
            }

        all_normal = (
            heating == "Heats normally"
            and turntable in ["Working", "Not applicable"]
            and door == "Closes securely"
            and controls == "Working"
            and not microwave_issues
        )

        if all_normal and data["working_status"] == "Yes" and damage in ["None", "Minor"]:
            return {
                "pathway": "Reuse / Resale",
                "severity": "Good condition",
                "reason": (
                    "The microwave is reported to heat normally, its door closes securely, "
                    "and its main functions are working without reported safety concerns."
                ),
                "action": (
                    "Consider continued use, donation or resale after a basic functionality "
                    "check and cleaning."
                )
            }

        if (
            len(microwave_issues) >= 2
            or data["working_status"] == "No"
            or heating == "Not heating"
        ):
            microwave_pathway = "Repair / Recycling assessment"
            microwave_reason = (
                "The microwave has multiple reported functional problems or is not "
                "operating normally: " + "; ".join(microwave_issues) + "."
            )
            microwave_action = (
                "Arrange professional diagnosis and obtain a repair estimate. "
                "If repair is not viable, use an authorized e-waste recycler."
            )

        elif microwave_issues:
            microwave_pathway = "Repair assessment"
            microwave_reason = (
                "A microwave function requires attention: "
                + "; ".join(microwave_issues) + "."
            )
            microwave_action = (
                "Have the affected component professionally inspected and obtain a repair "
                "estimate before deciding on reuse or resale."
            )

        else:
            microwave_pathway = "Inspection before reuse / resale"
            microwave_reason = (
                "The microwave's reported condition is incomplete or uncertain. "
                "Its functionality should be confirmed before reuse or resale."
            )
            microwave_action = (
                "Arrange a safe functionality check by a qualified person before "
                "deciding on reuse, repair or recycling."
            )

        # Compare repair cost with replacement cost when both are provided.
        if (
            repair_cost is not None
            and replacement_cost is not None
            and replacement_cost > 0
        ):
            ratio = repair_cost / replacement_cost

            if ratio >= 0.60:
                microwave_pathway = "Recycling assessment"
                microwave_reason += (
                    " The estimated repair cost is high relative to replacement cost."
                )
                microwave_action = (
                    "Compare replacement options. If repair is not economically viable, "
                    "send the microwave to an authorized e-waste recycler."
                )

            elif ratio <= 0.40 and repair_cost > 0:
                microwave_pathway = "Repair assessment"
                microwave_reason += (
                    " The estimated repair cost is relatively low compared with "
                    "replacement cost."
                )
                microwave_action = (
                    "Obtain a professional repair quote and confirm the appliance "
                    "can be safely restored before proceeding."
                )

        return {
            "pathway": microwave_pathway,
            "severity": severity,
            "reason": microwave_reason,
            "action": microwave_action,
            "microwave_issues": microwave_issues
        }

    if data.get("tv_display") is not None:
        tv_display = data["tv_display"]
        tv_sound = data["tv_sound"]
        tv_power = data["tv_power"]
        working_status = data.get("working_status", "Unknown")

        display_issue = tv_display not in ["Normal", "Unknown"]
        sound_issue = tv_sound not in ["Normal", "Unknown"]
        power_issue = tv_power not in ["Turns on normally", "Unknown"]

        tv_issues = []
        if display_issue:
            tv_issues.append(tv_display)
        if sound_issue:
            tv_issues.append(tv_sound)
        if power_issue:
            tv_issues.append(tv_power)

        if not tv_issues and data["working_status"] == "Yes" and damage in ["None", "Minor"]:
            return {
                "pathway": "Reuse / Resale",
                "severity": "Good condition",
                "reason": "The TV is reported to function normally, with no reported display, sound or power issues.",
                "action": "Consider continued use, donation or resale after basic testing."
            }

        if tv_display in ["Cracked screen", "No display"]:
            tv_severity = "Severe"
        elif display_issue or power_issue:
            tv_severity = "Moderate"
        elif sound_issue:
            tv_severity = "Minor"
        else:
            tv_severity = severity

        if data["working_status"] == "No" or tv_power == "Does not turn on":
            tv_pathway = "Repair / Recycling assessment"
            tv_reason = "The TV is reported as non-functional or unable to power on."
            tv_action = "Get a professional diagnosis and repair estimate. If repair is not viable, use an authorized e-waste recycler."

        elif tv_display in ["Cracked screen", "No display"]:
            tv_pathway = "Screen repair / Recycling assessment"
            tv_reason = "The reported display condition may require major repair or replacement of display components."
            tv_action = "Obtain a screen repair estimate and compare it with the TV's replacement value before deciding."

        elif tv_issues:
            tv_pathway = "Repair assessment"
            tv_reason = "The TV has reported condition issues: " + ", ".join(tv_issues) + "."
            tv_action = "Have the affected components inspected and obtain a repair estimate before deciding on reuse or resale."

        else:
            tv_pathway = "Inspection before reuse / resale"
            tv_reason = "The TV's reported condition requires further verification."
            tv_action = "Test the TV thoroughly and obtain a repair estimate if any issue is confirmed."

        if repair_cost is not None and replacement_cost is not None and replacement_cost > 0:
            ratio = repair_cost / replacement_cost

            if ratio >= 0.60:
                tv_pathway = "Recycling assessment"
                tv_reason += " The estimated repair cost is high relative to replacement cost."
                tv_action = "Consider replacement. If repair is not economically viable, send the TV to an authorized e-waste recycler."
            elif ratio <= 0.40 and repair_cost > 0:
                tv_pathway = "Repair"
                tv_reason += " The estimated repair cost is relatively low compared with replacement cost."
                tv_action = "Obtain a confirmed repair quote and check parts availability before proceeding."

        return {
            "pathway": tv_pathway,
            "severity": tv_severity,
            "reason": tv_reason,
            "action": tv_action,
            "tv_issues": tv_issues
        }
    if data.get("mouse_clicks") is not None:
        clicks = data["mouse_clicks"]
        scroll = data["mouse_scroll"]
        movement = data["mouse_movement"]
        connection = data["mouse_connection"]
        mouse_prediction = data.get("mouse_prediction", "Unknown")
        mouse_confidence = data.get("mouse_confidence", 0.0)

        # Treat low-confidence AI predictions as inconclusive.
        if mouse_confidence < 0.60:
            mouse_prediction = "Unknown"

        mouse_issues = []

        if clicks in ["One faulty", "Both faulty"]:
            mouse_issues.append("Click buttons: " + clicks)

        if scroll in ["Intermittent", "Not working"]:
            mouse_issues.append("Scroll wheel: " + scroll)

        if movement in ["Intermittent", "Not working"]:
            mouse_issues.append("Cursor movement: " + movement)

        if connection in ["Intermittent", "Disconnected"]:
            mouse_issues.append("Connection: " + connection)

        all_functional = (
            clicks == "Both working"
            and scroll == "Working"
            and movement == "Smooth"
            and connection == "Stable"
        )

        if all_functional and mouse_prediction == "NormalMouse" and damage in ["None", "Minor"]:
            return {
                "pathway": "Reuse / Resale",
                "severity": "Good condition",
                "reason": "The mouse is reported to function normally, has little or no visible damage, and the experimental AI classified it as normal.",
                "action": "Consider continued use, donation or resale after basic testing."
            }

        if all_functional and mouse_prediction == "DefectiveMouse":
            return {
                "pathway": "Inspection before reuse / resale",
                "severity": "AI finding requires confirmation",
                "reason": "The functional questionnaire indicates normal operation, but the experimental AI classified the mouse as defective. The image prediction may be inaccurate.",
                "action": "Physically test all buttons, scroll wheel, cursor movement and connection. Confirm any visible defect before deciding."
            }

        if not mouse_issues and all_functional:
            return {
                "pathway": "Inspection before reuse / resale",
                "severity": "Condition requires confirmation",
                "reason": "The mouse is reported to function normally, but the AI prediction or physical condition is inconclusive.",
                "action": "Perform a complete physical test and confirm the condition before reuse or resale."
            }

        if len(mouse_issues) >= 2 or data["working_status"] == "No":
            return {
                "pathway": "Repair / Recycling assessment",
                "severity": severity,
                "reason": "Multiple mouse functions are reported to have problems: " + "; ".join(mouse_issues) + ".",
                "action": "Obtain a repair assessment. If repair is not viable, send the mouse to an authorized e-waste recycler.",
                "mouse_issues": mouse_issues
            }

        if mouse_issues:
            return {
                "pathway": "Repair assessment",
                "severity": severity,
                "reason": "A mouse function is reported to have a problem: " + "; ".join(mouse_issues) + ".",
                "action": "Check the affected component, obtain a repair estimate and test the mouse again before reuse.",
                "mouse_issues": mouse_issues
            }

        return {
            "pathway": "Inspection before reuse / resale",
            "severity": severity,
            "reason": "The mouse condition could not be confidently determined from the available information.",
            "action": "Perform a complete functionality test and inspect the mouse before deciding."
        }

    visual_detections = data.get("visual_detections", [])

    if working and visual_detections and damage in ["None", "Minor", "Unknown"]:
        detected_labels = list(dict.fromkeys(
            item["label"].replace("_", " ").replace("Dameged-Keys", "Damaged Keys").title()
            for item in visual_detections
        ))

        return {
            "pathway": "Inspection before reuse / resale",
            "severity": "Visual finding requires confirmation",
            "reason": (
                "The user-reported condition indicates little or no damage, "
                "but the AI visual detector flagged: "
                + ", ".join(detected_labels)
                + ". The visual finding is preliminary and needs human confirmation."
            ),
            "action": (
                "Confirm the detected damage. If genuine, obtain a repair estimate "
                "and compare it with the device's value before deciding on repair, "
                "reuse, resale or responsible recycling."
            ),
            "visual_findings": detected_labels
        }

    if working and damage in ["None", "Minor"]:
        pathway = "Reuse / Resale"
        reason = "The device is reported to be functional with little or no visible damage."
        action = "Consider continued use, donation, or resale after data removal and basic checks."

    elif repair_cost is not None and replacement_cost is not None:
        ratio = repair_cost / max(replacement_cost, 1)

        if ratio <= 0.40:
            pathway = "Repair"
            reason = "The estimated repair cost is relatively low compared with replacement cost."
            action = "Obtain a repair quote and check spare-part availability."

        elif ratio >= 0.60:
            pathway = "Recycling assessment"
            reason = "The estimated repair cost is high relative to replacement cost."
            action = "Compare repair options. If repair is not viable, send it to an authorized e-waste channel."

        else:
            pathway = "Repair or resale assessment"
            reason = "The repair-versus-replacement decision is not clear from the estimates."
            action = "Compare repair quotes, device age, functionality and market value."

    elif working:
        pathway = "Repair / Resale assessment"
        reason = "The device works, but reported damage requires further evaluation."
        action = "Get a repair estimate and check resale value before deciding."

    else:
        pathway = "Repair / Recycling assessment"
        reason = "The device is reported as non-functional. Repair feasibility is unknown."
        action = "Obtain a professional assessment. If repair is not viable, use an authorized e-waste recycler."

    if age >= 7 and not working and pathway == "Repair":
        pathway = "Repair / Recycling assessment"
        reason = "The device is older and non-functional. Repair feasibility should be carefully evaluated."
        action = "Compare repair cost and parts availability; recycle responsibly if repair is not viable."

    return {
        "pathway": pathway,
        "severity": severity,
        "reason": reason,
        "action": action
    }


st.markdown("""
<div class="hero">
<h1>ScrapWise</h1>
<p>AI-driven electronic waste assessment and decision support</p>
<p>Identify a device, assess its condition and discover its most suitable next pathway.</p>
</div>
""", unsafe_allow_html=True)

st.markdown("## 1. Device identification")

uploaded = st.file_uploader(
    "Upload an electronic device image",
    type=["jpg", "jpeg", "png", "webp"]
)

if uploaded:
    image = Image.open(uploaded).convert("RGB")
    st.image(image, caption="Uploaded device", width=500)

    if st.button("Identify Device", type="primary"):
        with st.spinner("AI is identifying the device..."):
            name, confidence, top_predictions = identify_device(image)
            st.session_state.device_result = {
                "name": name,
                "confidence": confidence,
                "top_predictions": top_predictions
            }

if "device_result" in st.session_state:
    result = st.session_state.device_result
    detected_device = result["name"]
    confidence = result["confidence"]

    device_options = ["smartphone", "laptop", "tv", "keyboard", "mouse", "microwave"]
    selected_index = device_options.index(detected_device) if detected_device in device_options else 0

    device = st.selectbox(
        "Confirm or correct the device category",
        device_options,
        index=selected_index,
        format_func=lambda x: x.title()
    )

    if device != detected_device:
        st.warning(f"You corrected the AI identification from {detected_device.title()} to {device.title()}.")

    st.success(f"Confirmed device category: {device.title()}")
    st.metric("Classification confidence", f"{confidence * 100:.1f}%")

    with st.expander("View AI prediction scores"):
        for prediction in result.get("top_predictions", []):
            st.write(
                f"**{prediction['device'].title()}** ? "
                f"{prediction['confidence'] * 100:.1f}%"
            )
            st.progress(min(prediction["confidence"], 1.0))

    if confidence < 0.60:
        st.warning("The identification is uncertain. Please verify the device category.")
    elif confidence < 0.85:
        st.info("Possible match. Please verify the device category.")
    else:
        st.success("High-confidence device identification.")

    if device == "keyboard" and uploaded:
        st.markdown("### AI visual damage detection")

        if st.button("Detect Keyboard Damage"):
            with st.spinner("AI is checking for damaged or missing keys..."):
                annotated_image, detections = detect_keyboard_damage(image)
                st.session_state.keyboard_detection = detections
                st.session_state.keyboard_annotated = annotated_image

        if "keyboard_detection" in st.session_state:
            detected = st.session_state.keyboard_detection
            annotated = st.session_state.keyboard_annotated

            if annotated is not None:
                st.image(annotated, caption="AI keyboard damage detection")

            if detected is None:
                st.error("Keyboard damage model could not be loaded.")
            elif len(detected) == 0:
                st.info("No damaged keys detected. This does not guarantee the keyboard is undamaged.")
            else:
                st.write("Detected damaged or missing keys:")
                st.metric("Detected damaged-key regions", len(detected))

                for item in detected:
                    st.write(
                        f"- {item['label'].replace('_', ' ').title()} "
                        f"({item['confidence'] * 100:.1f}% detection confidence)"
                    )

            st.caption(
                "Experimental keyboard damage detector. It identifies visible "
                "damaged or missing keys. Results require human confirmation."
            )
    if device == "laptop" and uploaded:
        st.markdown("### AI visual damage detection")

        if st.button("Detect Laptop Damage"):
            with st.spinner("AI is checking visible damage..."):
                annotated_image, detections = detect_laptop_damage(image)
                st.session_state.laptop_detection = detections
                st.session_state.laptop_annotated = annotated_image

        if "laptop_detection" in st.session_state:
            detected = st.session_state.laptop_detection
            annotated = st.session_state.laptop_annotated

            if annotated is not None:
                st.image(annotated, caption="Experimental AI damage detection")

            if detected is None:
                st.error("Laptop damage model could not be loaded.")
            elif len(detected) == 0:
                st.info("No damage was detected. This does not guarantee the device is undamaged.")
            else:
                st.write("Detected visible damage:")
                for item in detected:
                    st.write(
                        f"- {item['label'].replace('_', ' ').title()} "
                        f"({item['confidence'] * 100:.1f}% detection confidence)"
                    )

            st.caption(
                "Experimental laptop damage detector. Results may be inaccurate "
                "and should be confirmed by a human."
            )

    if device == "mouse" and uploaded:
        st.markdown("### AI mouse condition classification")

        if st.button("Detect Mouse Condition"):
            with st.spinner("AI is checking the mouse image..."):
                annotated_image, prediction, prediction_confidence = detect_mouse_condition(image)
                st.session_state.mouse_prediction = prediction
                st.session_state.mouse_confidence = prediction_confidence
                st.session_state.mouse_annotated = annotated_image
                st.session_state.mouse_detection_image = uploaded.getvalue()

        if (
            "mouse_prediction" in st.session_state
            and st.session_state.get("mouse_detection_image") == uploaded.getvalue()
        ):
            prediction = st.session_state.mouse_prediction
            prediction_confidence = st.session_state.mouse_confidence
            annotated = st.session_state.mouse_annotated

            if annotated is not None:
                st.image(annotated, caption="Experimental mouse condition classification")

            if prediction == "Unknown":
                st.warning("The model could not classify the mouse. Please rely on physical testing.")
            elif prediction == "DefectiveMouse":
                st.warning("AI prediction: Defective mouse ({:.1f}% confidence)".format(prediction_confidence * 100))
            elif prediction == "NormalMouse":
                st.success("AI prediction: Normal mouse ({:.1f}% confidence)".format(prediction_confidence * 100))

            st.caption(
                "Experimental AI classifier. It classifies the overall mouse image, "
                "not individual components. Results require physical testing and confirmation."
            )

    st.markdown("---")
    st.markdown("## 2. Device condition assessment")
    st.caption("Please answer based on the device's current condition.")

    with st.form("assessment_form"):
        age = st.number_input(
            "Approximate device age (years)",
            min_value=0,
            max_value=50,
            value=2
        )

        working = st.radio(
            "Does the device currently function?",
            ["Yes", "Partially", "No", "Unknown"],
            horizontal=True
        )

        if device == "mouse":
            mouse_clicks = st.selectbox(
                "Mouse click buttons",
                ["Both working", "One faulty", "Both faulty", "Unknown"]
            )

            mouse_scroll = st.selectbox(
                "Scroll wheel condition",
                ["Working", "Intermittent", "Not working", "Unknown"]
            )

            mouse_movement = st.selectbox(
                "Cursor movement",
                ["Smooth", "Intermittent", "Not working", "Unknown"]
            )

            mouse_connection = st.selectbox(
                "Mouse connection",
                ["Stable", "Intermittent", "Disconnected", "Unknown"]
            )

        if device == "microwave":
            microwave_heating = st.selectbox(
                "Microwave heating performance",
                ["Heats normally", "Weak heating", "Not heating", "Unknown"]
            )

            microwave_turntable = st.selectbox(
                "Turntable condition",
                ["Working", "Intermittent", "Not working", "Not applicable", "Unknown"]
            )

            microwave_door = st.selectbox(
                "Door and latch condition",
                [
                    "Closes securely",
                    "Loose / does not close securely",
                    "Damaged door or seal",
                    "Unknown"
                ]
            )

            microwave_controls = st.selectbox(
                "Control panel condition",
                ["Working", "Intermittent", "Not working", "Unknown"]
            )

            microwave_safety_signs = st.multiselect(
                "Any unusual signs during operation? (Select all that apply)",
                [
                    "None reported",
                    "Sparks inside",
                    "Burning smell",
                    "Smoke",
                    "Unusual loud noise"
                ]
            )

        if device == "tv":
            tv_display = st.selectbox(
                "TV display condition",
                [
                    "Normal",
                    "Lines on screen",
                    "Spots or dark patches",
                    "Cracked screen",
                    "No display",
                    "Flickering",
                    "Unknown"
                ]
            )

            tv_sound = st.selectbox(
                "TV sound condition",
                [
                    "Normal",
                    "Distorted sound",
                    "No sound",
                    "Unknown"
                ]
            )

            tv_power = st.selectbox(
                "TV power condition",
                [
                    "Turns on normally",
                    "Intermittent power",
                    "Does not turn on",
                    "Unknown"
                ]
            )

        damage = st.selectbox(
            "Visible physical damage",
            ["None", "Minor", "Moderate", "Severe", "Unknown"]
        )

        water = st.radio(
            "Has the device experienced liquid or water damage?",
            ["No", "Yes", "Unknown"],
            horizontal=True
        )

        repair_cost = st.number_input(
            "Estimated repair cost (INR, optional)",
            min_value=0,
            value=0,
            step=500
        )

        replacement_cost = st.number_input(
            "Estimated replacement cost (INR, optional)",
            min_value=0,
            value=0,
            step=1000
        )

        submitted = st.form_submit_button(
            "Generate E-waste Assessment",
            type="primary"
        )

    if submitted:
        data = {
            "age": age,
            "working": working == "Yes",
            "working_status": working,
            "damage": damage,
            "water": water == "Yes",
            "repair_cost": repair_cost if repair_cost > 0 else None,
            "replacement_cost": replacement_cost if replacement_cost > 0 else None,
            "visual_detections": (
                st.session_state.get("laptop_detection", [])
                if device == "laptop"
                else st.session_state.get("keyboard_detection", [])
                if device == "keyboard"
                else []
            ),
            "microwave_heating": (
                microwave_heating if device == "microwave" else None
            ),
            "microwave_turntable": (
                microwave_turntable if device == "microwave" else None
            ),
            "microwave_door": (
                microwave_door if device == "microwave" else None
            ),
            "microwave_controls": (
                microwave_controls if device == "microwave" else None
            ),
            "microwave_safety_signs": (
                microwave_safety_signs if device == "microwave" else []
            ),
            "tv_display": tv_display if device == "tv" else None,
            "tv_sound": tv_sound if device == "tv" else None,
            "tv_power": tv_power if device == "tv" else None,
            "mouse_clicks": mouse_clicks if device == "mouse" else None,
            "mouse_scroll": mouse_scroll if device == "mouse" else None,
            "mouse_movement": mouse_movement if device == "mouse" else None,
            "mouse_connection": mouse_connection if device == "mouse" else None,
            "mouse_prediction": (
                st.session_state.get("mouse_prediction", "Unknown")
                if device == "mouse" and st.session_state.get("mouse_detection_image") == uploaded.getvalue()
                else "Unknown"
            ),
            "mouse_confidence": (
                st.session_state.get("mouse_confidence", 0.0)
                if device == "mouse" and st.session_state.get("mouse_detection_image") == uploaded.getvalue()
                else 0.0
            )
        }

        assessment = assess_device(data)
        st.session_state.assessment = assessment
        st.session_state.assessment_device = device
        st.session_state.assessment_device = device
        st.session_state.assessment_data = data

    if "assessment" in st.session_state and st.session_state.get("assessment_device") == device:
        assessment = st.session_state.assessment

        st.markdown("---")
        st.markdown("## 3. Assessment result")

        st.subheader("Overall assessment summary")

        if assessment.get("visual_findings"):
            st.warning(
                "The questionnaire and AI visual findings do not fully agree. "
                "Visual damage requires confirmation before deciding on reuse or resale."
            )
            st.write(
                "**AI visual finding:** "
                + ", ".join(assessment["visual_findings"])
            )
        else:
            st.info(
                "The recommendation is based on the device identification and "
                "user-reported condition."
            )

        st.subheader("Recommended pathway")
        st.markdown(f"### {assessment['pathway']}")

        col1, col2 = st.columns(2)

        with col1:
            st.metric("Reported damage severity", assessment["severity"])

        with col2:
            st.metric("Device category", device.title())

        st.markdown("### Why this recommendation?")
        st.write(assessment["reason"])

        st.markdown("### Suggested next step")
        st.info(assessment["action"])

        st.markdown("### Potential recoverable materials")
        st.write(MATERIALS.get(device, "Materials require further assessment."))

        st.markdown("### Responsible e-waste handling")
        st.write(
            "If reuse or resale is not feasible, hand over the device to an "
            "authorized e-waste collection or recycling channel. Do not dismantle "
            "batteries or hazardous components yourself."
        )

        st.caption(
            "This is a preliminary decision-support assessment. "
            "Visual damage detection for laptops and keyboards is experimental; other devices use "
            "user-reported condition. Material information is indicative."
        )

    if st.button("Start a new assessment"):
        for key in ["device_result", "assessment", "assessment_data", "laptop_detection", "laptop_annotated", "keyboard_detection", "keyboard_annotated"]:
            st.session_state.pop(key, None)
        st.rerun()

st.markdown("---")
st.caption("ScrapWise | Prototype | AI-assisted e-waste assessment")












