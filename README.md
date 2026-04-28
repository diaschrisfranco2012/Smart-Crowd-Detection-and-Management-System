# 🚨 CrowdSense: Proactive Crowd Safety & Stampede Detection System

![CrowdSense Concept](https://img.shields.io/badge/Status-Live-success) ![Platform](https://img.shields.io/badge/Platform-Raspberry%20Pi%205%20%7C%20Flutter-blue) ![AI](https://img.shields.io/badge/AI-YOLOv11-orange)

![IOT]_module](assets/IOT.jpeg)

**CrowdSense** is an edge-computing IoT safety system engineered to detect real-time stampedes, critical overcrowding, and fatal bottlenecks. Built as a Final Year BCA Project by Chris Dias, Mevin Quadros, Saieshwar Malkarnekar, Yash Bhandari, and Saheel Shaikh at Rosary College of Commerce & Arts, Goa.

Instead of relying on passive CCTV monitoring, CrowdSense uses **Euclidean centroid math** and **Edge AI** to actively measure human density. When a life-threatening cluster forms, it automatically triggers hardware alarms, snaps evidence photos, and dispatches AI voice calls and SMS alerts to security personnel.

---

## ✨ Key System Features

* **🧠 Edge AI Processing:** Runs entirely on a Raspberry Pi 5 using Ultralytics YOLOv11. No cloud video streaming required, ensuring zero-latency detection and low bandwidth usage.
* **📐 Stampede Density Logic:** Calculates the exact pixel distance between human centroids. If too many individuals cross the critical proximity threshold, it flags a "Stampede Risk" (overriding standard room capacity limits).
* **⏱️ 3.5-Second Threat Lock:** Prevents false alarms by requiring a dense cluster to be sustained for 3.5 continuous seconds before triggering a Level 1 Emergency.
* **📞 Automated Twilio Dispatch:** Instantly fires an AI Text-to-Speech Voice Call and an SMS containing a Google Maps link of the exact zone and floor.
* **🛡️ Anti-Spam Protocol:** Limits Twilio to exactly *one* phone call per emergency event. The system locks the call function until a human admin manually clears the incident on the app.
* **📱 Flutter Admin Dashboard:** A cross-platform mobile app connected via Firebase Realtime Database to view live logs, device health (CPU/Storage), and clear active alarms.

---

## 🏗️ Architecture & Tech Stack

* **Hardware:** Raspberry Pi 5 (Active Cooler), 5MP Camera Module, Push Button, Active Buzzer, LEDs.
* **AI / Computer Vision:** Python, Ultralytics YOLOv11 (`yolo11n.pt`), OpenCV.
* **Backend / Edge Server:** Flask (for local MJPEG video streaming), Threading, Queue.
* **Cloud Infrastructure:** Firebase Realtime Database (App Sync), Cloudinary (Evidence Image Hosting).
* **Communication:** Twilio REST API.
* **Frontend:** Flutter & Dart.

---

## 🔌 Hardware Wiring & GPIO Setup

To replicate the edge device, wire the components to the Raspberry Pi 5 as follows:

* **Green LED (System Live):** GPIO Pin 17
* **Red LED (Emergency Active):** GPIO Pin 27
* **Active Buzzer (Alarm):** GPIO Pin 22
* **Physical Push Button (Kill-Switch/Launcher):** GPIO Pin 23

---

## ⚙️ Installation & Setup

### 1. Prerequisites
Ensure your Raspberry Pi 5 is running a 64-bit OS with Python 3.9+ installed.
```bash
sudo apt update && sudo apt upgrade
sudo apt install python3-pip
```

### 2. Clone the Repository
```bash
git clone https://github.com/diaschrisfranco2012/Smart-Crowd-Detection-and-Management-System.git
cd Smart-Crowd-Detection-and-Management-System
```

### 3. Install Python Dependencies
```bash
pip install opencv-python ultralytics firebase-admin cloudinary twilio flask psutil gpiozero
```

### 4. Cloud & API Configurations
You must configure the following services before booting the system:
* **Firebase:** Download your `firebase_key.json` service account file and place it in the root directory.
* **Cloudinary:** Update `CLOUDINARY_CLOUD_NAME`, `API_KEY`, and `API_SECRET` in `pi_serverWc5.py` (e.g., `de3zhyybl`).
* **Twilio:** Update your Account SID, Auth Token, and routing phone numbers in `pi_serverWc5.py`.

---

## 🚀 Usage Guide

### Method 1: Manual Execution
You can run the core engine directly from the terminal to see live console logs:
```bash
python3 pi_serverWc5.py
```

### Method 2: Hardware Button Launch (Production Mode)
To use the physical Kill-Switch button:
1. Run the launcher script in the background: `python3 launcher.py`
2. Press the physical button on your breadboard. The system will emit two startup beeps, initialize the YOLO model, and turn on the Green LED.

### Method 3: Systemd Service
If configured as a background service:
* **Start:** `sudo systemctl start crowdsense.service`
* **Stop:** `sudo systemctl stop crowdsense.service`
* **Restart:** `sudo systemctl restart crowdsense.service`

---

## 📂 Core File Structure

* **`pi_serverWc5.py`**: The main edge-computing engine. Handles video capture, AI inference, centroid math, and API dispatches using multi-threading.
* **`launcher.py`**: A lightweight hardware listener that safely boots or terminates the main server using the physical push-button to prevent OS lockups.
* **`flutter_app/`**: Contains the full Dart codebase for the cross-platform mobile dashboard.
* **`yolo11n.pt`**: The pre-trained Nano YOLO model optimized for high-FPS edge processing.
* **`yolov8n-pose.pt`**: The pre-trained Nano YOLO Pose model used for real-time fall detection, a tertiary safety feature of the project.

---

## 🛠️ The Ultimate Troubleshooting & Debugging Guide
When working with hardware, AI, and cloud services simultaneously, you might run into a few specific quirks. Here is exactly how to diagnose and fix the most common issues you might face while running CrowdSense:

#### 1. The Camera is "Busy" or "Locked"

What happens: You try to run the script, but the terminal throws an error saying Device or resource busy or cv2.VideoCapture(0) failed.

Why it happens: A previous run of the script crashed or was closed improperly, and the Pi never officially "let go" of the camera hardware.

How to fix it: You need to force-kill any hidden Python tasks using the camera. Run sudo pkill -f pi_server in the terminal, or simply reboot the Pi.

#### 2. The Buzzer and LEDs are Stuck ON

What happens: You stop the code (like pressing CTRL+C), but the red LED stays lit and the buzzer keeps screaming.

Why it happens: The script was killed exactly while the alarm was ringing, meaning it never reached the cleanup_gpio() function at the end of the code.

How to fix it: Never just pull the power plug! Run your launcher.py script and press the physical button to properly boot and shut down the system. The launcher forces a pin reset.

#### 3. System Crashes Immediately on Boot (jwt_grant error)

What happens: The code starts, loads YOLO, but instantly crashes with a massive wall of text mentioning google/auth and Firebase.

Why it happens: The Raspberry Pi doesn't have a built-in battery clock. If it boots up without Wi-Fi, it might think the year is 2023. Google's security servers strictly check timestamps, so if the Pi's clock is wrong, Firebase rejects your login.

How to fix it: Open the terminal and type date. If the date and time are completely wrong, connect the Pi to a strong Wi-Fi network and reboot it so it auto-syncs the correct global time.

#### 4. The Twilio Phone Call Only Worked Once

What happens: A stampede happens, the app updates, the SMS sends, but the Twilio Voice Call doesn't ring your phone.

Why it happens: The system is doing exactly what it's supposed to do! The Anti-Spam lock (call_made_for_current_incident) is currently locked from a previous test or emergency.

How to fix it: The hardware is waiting for human confirmation. Open the Flutter app and manually click the button to reset the room status to "Normal". This unlocks the system and arms the phone call for the next emergency.

#### 5. The Flutter App Shows Broken Image Links

What happens: You get an alert on the app, but instead of seeing the crowd snapshot, you just see a broken image icon.

Why it happens: The Raspberry Pi is trying to upload the photo to a Cloudinary account that doesn't exist, so it returns a dead link to Firebase.

How to fix it: Open pi_serverWc5.py and check line 25. Make sure the CLOUDINARY_CLOUD_NAME is set exactly to your auto-generated ID (like de3zhyybl) and not a placeholder word.

#### 6. The Video Feed is Lagging or the Pi is Overheating

What happens: The bounding boxes are moving in slow motion, or the Raspberry Pi feels dangerously hot to the touch.

Why it happens: YOLO is processing too many frames per second (FPS), maxing out the CPU, or the Active Cooler isn't plugged into the correct fan header.

How to fix it: First, make sure the Active Cooler fan is actually spinning. Second, check the "Ghost Box Optimization" in the Python code—ensure the time.sleep() in the camera thread is active so the Pi skips unnecessary frames and gets time to "breathe".

---

## 🔮 Future Roadmap

* **Thermal Imaging Integration:** Utilize FLIR thermal cameras for density detection in pitch-black and smoke-filled environments.
* **Multi-Camera Sync:** Connect multiple edge devices to track crowd flow across massive campus layouts.
* **Predictive Analytics:** Upgrade the logic to forecast stampedes *before* they happen based on directional velocity.

---
*Architected for safety. Engineered for the edge.*