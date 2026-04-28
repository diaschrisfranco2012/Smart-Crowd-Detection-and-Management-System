import os
import atexit
import cv2
import signal
import sys
import time
import math
import psutil
import threading
import queue
from flask import Flask, Response
from ultralytics import YOLO
import firebase_admin
from firebase_admin import credentials, db
import cloudinary
import cloudinary.uploader
from twilio.rest import Client
from gpiozero import LED, Buzzer 

# ==========================================
# ALL API KEYS
# ==========================================
FIREBASE_DB_URL = ""
KEY_PATH = ""

CLOUDINARY_CLOUD_NAME = ""
CLOUDINARY_API_KEY = ""
CLOUDINARY_API_SECRET = ""

TWILIO_SID = ""
TWILIO_TOKEN = ""
FROM_NUMBER = ""
TO_NUMBER = "" 

# ==========================================
# SYSTEM LIMITS & GLOBALS
# ==========================================
CAMERA_INDEX = 0 
WARNING_LIMIT = 30
CRITICAL_LIMIT = 50 
DANGER_RADIUS_PIXELS = 180 
DENSITY_CRITICAL_LIMIT = 15 
AI_CONFIDENCE = 0.15 # Dynamic variable controlled by Flutter App

# Incident Locks
force_reset = False
call_made_for_current_incident = False

# ==========================================
# INITIALIZATION & HARDWARE SETUP
# ==========================================
print("Connecting to Firebase...")
cred = credentials.Certificate(KEY_PATH)
firebase_admin.initialize_app(cred, {'databaseURL': FIREBASE_DB_URL})
db_ref = db.reference('crowd_monitor/zone_A')

cloudinary.config(cloud_name=CLOUDINARY_CLOUD_NAME, api_key=CLOUDINARY_API_KEY, api_secret=CLOUDINARY_API_SECRET)

try:
    twilio_client = Client(TWILIO_SID, TWILIO_TOKEN)
except Exception as e:
    twilio_client = None
    print(f"Twilio Warning: {e}")

print("Loading YOLO AI...")
model = YOLO('yolo11n.pt') 

cap = cv2.VideoCapture(CAMERA_INDEX)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
cap.set(cv2.CAP_PROP_FPS, 60)

app = Flask(__name__)
annotated_frame = None      
frame_lock = threading.Lock()
stop_event = threading.Event()
ai_frame_queue = queue.Queue(maxsize=2)      
upload_queue = queue.Queue()                  

# --- HARDWARE INIT & BOOT SEQUENCE ---
try:
    green_led = LED(17)
    red_led = LED(27)
    buzzer = Buzzer(22)
    
    # 🟢 BOOT UP FEEDBACK (2 Quick Beeps & Flashes)
    print("Playing startup hardware feedback...")
    for _ in range(2):
        green_led.on()
        buzzer.on()
        time.sleep(0.1)
        green_led.off()
        buzzer.off()
        time.sleep(0.1)
        
    # Leave Green LED on permanently as the Power Light!
    green_led.on() 
    
except Exception as e:
    print(f"Hardware Init Warning: {e}")
    green_led = red_led = buzzer = None

def set_alarm_outputs(active: bool):
    if red_led and buzzer:
        if active:
            red_led.on()
            buzzer.on()
        else:
            red_led.off()
            buzzer.off()

# --- THE FIX: SMART VOICE CALL LOGIC ---
def make_emergency_call(base_message):
    if twilio_client:
        try:
            # 1. Fetch the latest location from Firebase
            loc_data = db_ref.child('location_details').get()
            spoken_location = ""
            
            if loc_data:
                zone = loc_data.get('zone', 'an unknown zone')
                floor = loc_data.get('floor', 'an unknown floor')
                spoken_location = f"This alert is reported at {zone}, on {floor}."
            
            # 2. Combine the base warning with the exact location
            full_spoken_message = f"{base_message} {spoken_location}"
            
            # 3. Tell Twilio's AI 'Alice' to speak the full custom message
            twilio_client.calls.create(
                twiml=f'<Response><Say voice="alice">{full_spoken_message}</Say></Response>',
                to=TO_NUMBER,
                from_=FROM_NUMBER
            )
            print(f"📞 Admin Call Dispatched! Alice will say: {full_spoken_message}")
        except Exception as e:
            print(f"Call Failed: {e}")

# ==========================================
# THE FIREBASE LISTENERS (APP SYNC)
# ==========================================
def on_firebase_status_change(event):
    global force_reset, call_made_for_current_incident
    if event.data == "Normal":
        print("📱 APP OVERRIDE: Admin marked area safe. Resetting alarms and call lock!")
        force_reset = True
        call_made_for_current_incident = False 

def on_settings_change(event):
    global WARNING_LIMIT, CRITICAL_LIMIT, DENSITY_CRITICAL_LIMIT, AI_CONFIDENCE
    data = event.data
    if data:
        if 'warning_limit' in data: WARNING_LIMIT = data['warning_limit']
        if 'critical_limit' in data: CRITICAL_LIMIT = data['critical_limit']
        if 'density_limit' in data: DENSITY_CRITICAL_LIMIT = data['density_limit']
        if 'ai_confidence' in data: AI_CONFIDENCE = float(data['ai_confidence'])
        print(f"⚙️ App updated settings! Warn: {WARNING_LIMIT}, Crit: {CRITICAL_LIMIT}, Dense: {DENSITY_CRITICAL_LIMIT}, Conf: {AI_CONFIDENCE}")

db.reference('crowd_monitor/zone_A/status').listen(on_firebase_status_change)
db.reference('crowd_monitor/zone_A/settings').listen(on_settings_change)

# --- 🛠️ COMPLETE HARDWARE UNLOCKER ---
def cleanup_gpio():
    try:
        if red_led: 
            red_led.off()
            red_led.close()
        if buzzer: 
            buzzer.off()
            buzzer.close()
        if green_led: 
            green_led.off()
            green_led.close()
    except Exception as e:
        pass

# --- 🛠️ OS-LEVEL NUKE HANDLER ---
def shutdown_handler(signum=None, frame=None):
    stop_event.set()
    try: 
        print("\n🛑 Shutting down! Sending OFFLINE status to Firebase...")
        db_ref.update({
            "pi_is_online": False,
            "status": "Offline",
            "live_count": 0  
        })
        time.sleep(1) # Grace period for Firebase to sync
    except Exception as e: 
        print(f"Failed to update Firebase: {e}")

    # 🔴 SHUTDOWN BEEP HAPPENS HERE NOW!
    print("Playing shutdown hardware feedback...")
    try:
        if green_led and buzzer:
            green_led.on()
            buzzer.on()
            time.sleep(1)
            green_led.off()
            buzzer.off()
    except Exception:
        pass
        
    print("Unlocking Camera and GPIO Pins...")
    try:
        if cap.isOpened():
            cap.release()
    except Exception:
        pass
        
    cleanup_gpio()
    time.sleep(0.5) # Give the physical hardware half a second to fully release pins
    
    if signum is not None: 
        print("Bypassing Flask. Forcing instant OS exit...")
        os._exit(0) # INSTANT KILL FOR FROZEN THREADS

atexit.register(cleanup_gpio)
signal.signal(signal.SIGINT, shutdown_handler)
signal.signal(signal.SIGTERM, shutdown_handler)

# ==========================================
# UPLOAD WORKER THREAD
# ==========================================
def upload_worker():
    while not stop_event.is_set():
        try: task = upload_queue.get(timeout=1)
        except queue.Empty: continue

        task_type = task.get('type')
        
        if task_type == 'firebase_update':
            try: db_ref.update(task['data'])
            except Exception as e: print(f"Firebase update failed: {e}")
            
        elif task_type == 'firebase_push':
            try: db_ref.child(task['child']).push(task['data'])
            except Exception as e: print(f"Firebase push failed: {e}")
            
        elif task_type == 'cloudinary_upload':
            try:
                result = cloudinary.uploader.upload(task['file'], folder="crowdsense_alerts")
                upload_queue.put({
                    'type': 'firebase_push',
                    'child': 'history',
                    'data': task['log_data'] | {'image_url': result['secure_url']}
                })
            except Exception as e: print(f"Cloudinary upload failed: {e}")
            
        elif task_type == 'twilio_call':
            make_emergency_call(task['message'])
            
        elif task_type == 'twilio_sms_alert':
            try:
                loc_data = db_ref.child('location_details').get()
                loc_text = "Location: Unknown"
                if loc_data:
                    zone = loc_data.get('zone', 'Unknown Zone')
                    floor = loc_data.get('floor', 'Unknown Floor')
                    lat = loc_data.get('latitude', '')
                    lng = loc_data.get('longitude', '')
                    if lat and lng:
                        loc_text = f"Loc: {zone}, {floor}. Maps: https://www.google.com/maps/search/?api=1&query={lat},{lng}"
                    else:
                        loc_text = f"Loc: {zone}, {floor}"
                
                full_message = f"🚨 CROWDSENSE ALERT: {task['reason']}!\n{loc_text}"
                if twilio_client:
                    twilio_client.messages.create(body=full_message, to=TO_NUMBER, from_=FROM_NUMBER)
                    print("📱 SMS Alert Sent Successfully!")
            except Exception as e: 
                print(f"SMS Alert Failed: {e}")

# ==========================================
# 🧠 AI PROCESSING THREAD
# ==========================================
def ai_processing():
    global force_reset, annotated_frame, call_made_for_current_incident, AI_CONFIDENCE

    start_critical_time = None
    last_alert_time = 0
    last_firebase_ping = 0
    frame_count = 0

    last_boxes = []
    last_density_flags = []
    last_total_persons = 0
    last_dense_count = 0
    last_fall_detected = False

    while not stop_event.is_set():
        try: frame = ai_frame_queue.get(timeout=1)
        except queue.Empty: continue

        frame_count += 1
        annotated = frame.copy()

        # --- Performance Saver: Process 1 frame out of every 10 ---
        if frame_count % 10 != 0:
            for i, (x1, y1, x2, y2) in enumerate(last_boxes):
                box_color = (0, 255, 0)
                if last_density_flags[i]: box_color = (0, 0, 255)
                elif last_total_persons > WARNING_LIMIT: box_color = (0, 165, 255)
                cv2.rectangle(annotated, (x1, y1), (x2, y2), box_color, 4)
            
            with frame_lock: annotated_frame = annotated
            continue

        # --- High Accuracy YOLO Run ---
        results = model.predict(frame, conf=AI_CONFIDENCE, iou=0.90, imgsz=640, classes=[0], verbose=False)
        current_total = 0
        centroids = []
        current_boxes = []
        fall_detected_in_frame = False 

        if results[0].boxes:
            for box in results[0].boxes:
                current_total += 1
                x1, y1, x2, y2 = map(int, box.xyxy[0])
                
                # --- THE MAIN PI FALL DETECTION MATH ---
                if (x2 - x1) > ((y2 - y1) * 1.2): 
                    fall_detected_in_frame = True 
                
                cx, cy = (x1 + x2) // 2, (y1 + y2) // 2
                centroids.append((cx, cy))
                current_boxes.append((x1, y1, x2, y2))

        # Density Matrix
        current_dense_count = 0
        current_density_flags = [False] * len(centroids)

        for i in range(len(centroids)):
            close_neighbors = 0
            for j in range(len(centroids)):
                if i != j:
                    dist = math.hypot(centroids[i][0] - centroids[j][0], centroids[i][1] - centroids[j][1])
                    if dist < DANGER_RADIUS_PIXELS: close_neighbors += 1
            if close_neighbors >= 2:
                current_density_flags[i] = True
                current_dense_count += 1

        last_boxes = current_boxes
        last_density_flags = current_density_flags
        last_total_persons = current_total
        last_dense_count = current_dense_count
        last_fall_detected = fall_detected_in_frame

        # --- Draw Actual Boxes ---
        for i, (x1, y1, x2, y2) in enumerate(current_boxes):
            box_color = (0, 255, 0)
            if current_density_flags[i]: box_color = (0, 0, 255)
            elif current_total > WARNING_LIMIT: box_color = (0, 165, 255)
            cv2.rectangle(annotated, (x1, y1), (x2, y2), box_color, 4)
        
        with frame_lock: annotated_frame = annotated

        # App Kill Switch Override
        if force_reset:
            start_critical_time = None
            last_alert_time = 0 
            set_alarm_outputs(False) 
            force_reset = False 

        now = time.time()
        
        # --- 1. FALL DETECTION CLOUDINARY UPLOAD LOGIC ---
        if fall_detected_in_frame and (now - last_alert_time) > 60:
            print("🚨 FALL DETECTED! Snapping Evidence...")
            current_timestamp_ms = int(now * 1000)
            temp_file = "temp_fall.jpg"
            cv2.imwrite(temp_file, frame)

            upload_queue.put({
                'type': 'cloudinary_upload',
                'file': temp_file,
                'log_data': {
                    "timestamp": current_timestamp_ms,
                    "description": "Medical: Fall Detected",
                    "type": "Pending",
                    "people_count": current_total,
                    "dense_count": current_dense_count
                }
            })
            
            upload_queue.put({
                'type': 'firebase_update',
                'data': {"status": "POTENTIAL FALL", "last_alert_timestamp": current_timestamp_ms, "latest_evidence_url": ""} # Reset URL so app waits for new one
            })
            
            last_alert_time = now

        # --- 2. STAMPEDE THREAT STOPWATCH LOGIC ---
        is_threat = (current_total > CRITICAL_LIMIT) or (current_dense_count > DENSITY_CRITICAL_LIMIT)

        if is_threat:
            if start_critical_time is None:
                start_critical_time = now
            elapsed = now - start_critical_time
        else:
            start_critical_time = None
            elapsed = 0

        # Trigger if threat is sustained for 3.5 seconds
        if elapsed > 3.5 and (now - last_alert_time) > 60:
            print("🚨 ALERT TRIGGERED! Snapping Evidence...")
            set_alarm_outputs(True) 
            current_timestamp_ms = int(now * 1000)
            temp_file = "temp_evidence.jpg"
            cv2.imwrite(temp_file, frame)

            reason = "Stampede Density Detected" if current_dense_count > DENSITY_CRITICAL_LIMIT else "Critical Headcount Reached"

            # Upload Evidence
            upload_queue.put({
                'type': 'cloudinary_upload',
                'file': temp_file,
                'log_data': {
                    "timestamp": current_timestamp_ms,
                    "description": reason,
                    "type": "Pending",
                    "people_count": current_total,
                    "dense_count": current_dense_count
                }
            })
            
            # Update Status
            upload_queue.put({
                'type': 'firebase_update',
                'data': {"status": "CRITICAL RISK", "last_alert_timestamp": current_timestamp_ms}
            })
            
            # Smart Voice Call (Once per incident)
            if not call_made_for_current_incident:
                upload_queue.put({
                    'type': 'twilio_call',
                    'message': "Overcrowd detected. Please go and check this location immediately."
                })
                call_made_for_current_incident = True
            
            # Trigger Smart SMS
            upload_queue.put({
                'type': 'twilio_sms_alert',
                'reason': reason
            })

            last_alert_time = now
            start_critical_time = None # Reset clock for next burst

        # Fast Sync Firebase Ping (0.5 seconds)
        if now - last_firebase_ping > 0.5:
            disk = psutil.disk_usage('/')
            status_text = "Normal"
            if current_total > WARNING_LIMIT: status_text = "High Density"
            
            current_status = db_ref.child('status').get()
            # Prevent heartbeat from overwriting emergencies
            if current_status == "CRITICAL RISK": status_text = "CRITICAL RISK"
            elif current_status == "POTENTIAL FALL": status_text = "POTENTIAL FALL"

            upload_queue.put({
                'type': 'firebase_update',
                'data': {
                    "live_count": current_total,
                    "dense_count": current_dense_count,
                    "pi_is_online": True,
                    "pi_storage_used": round(disk.used / (1024 ** 3), 2),
                    "pi_storage_total": round(disk.total / (1024 ** 3), 2),
                    "status": status_text
                }
            })
            last_firebase_ping = now

# ==========================================
# 📷 CAPTURE THREAD
# ==========================================
def capture_frames():
    while not stop_event.is_set():
        ret, frame = cap.read()
        if not ret: continue
        try: ai_frame_queue.put_nowait(frame)
        except queue.Full: pass 

# ==========================================
# 📡 FLASK STREAMING SERVER
# ==========================================
def generate_feed():
    global annotated_frame
    while not stop_event.is_set():
        with frame_lock: frame = annotated_frame
        if frame is None:
            time.sleep(0.03)
            continue
        (flag, encodedImage) = cv2.imencode(".jpg", frame)
        if not flag: continue
        yield (b'--frame\r\n' b'Content-Type: image/jpeg\r\n\r\n' + bytearray(encodedImage) + b'\r\n')

@app.route('/video_feed')
def video_feed(): return Response(generate_feed(), mimetype="multipart/x-mixed-replace; boundary=frame")
@app.route('/')
def index(): return "CrowdSense Camera is Live!"

if __name__ == '__main__':
    threading.Thread(target=upload_worker, daemon=True).start()
    threading.Thread(target=ai_processing, daemon=True).start()
    threading.Thread(target=capture_frames, daemon=True).start()
    print(f"📡 Starting Live Stream Server on Port 5000...")
    app.run(host="0.0.0.0", port=5000, debug=False, threaded=True)