import os
import psutil
import cv2
import firebase_admin
from firebase_admin import credentials, db
import time

# --- CONFIG ---
KEY_PATH = "/home/kali/Desktop/TY/firebase_key.json"
DB_URL = ""

def check_status():
    print("\n🔍 --- CROWDSENSE SYSTEM DIAGNOSTICS ---")
    
    # 1. Check if AI Service is actually running
    ai_status = os.popen("systemctl is-active crowdsense.service").read().strip()
    status_icon = "Online" if ai_status == "active" else "Offline"
    print(f"{status_icon} AI Service Status: {ai_status.upper()}")

    # 2. Check Camera Hardware
    cap = cv2.VideoCapture(0)
    if cap.isOpened():
        ret, _ = cap.read()
        if ret:
            print("Camera Hardware: FOUND & STREAMING")
        else:
            print("⚠️ Camera Hardware: FOUND but NO IMAGE (Check Power)")
        cap.release()
    else:
        print("Camera Hardware: NOT FOUND (Check Index 0/1)")

    # 3. Check Internet & Firebase
    try:
        if not firebase_admin._apps:
            cred = credentials.Certificate(KEY_PATH)
            firebase_admin.initialize_app(cred, {'databaseURL': DB_URL})
        
        # Try to read one value to confirm connection
        test_val = db.reference('crowd_monitor/zone_A/pi_is_online').get()
        print(f"Firebase Cloud: CONNECTED (Pi Online: {test_val})")
    except Exception as e:
        print(f"Firebase Cloud: FAILED ({str(e)[:50]}...)")

    # 4. System Resources
    cpu = psutil.cpu_percent()
    temp = os.popen("vcgencmd measure_temp").read().replace("temp=","").strip()
    print(f"System: CPU {cpu}% | Temp: {temp}")
    print("------------------------------------------\n")

if __name__ == "__main__":
    while True:
        os.system('clear')
        check_status()
        print("Press Ctrl+C to stop monitoring...")
        time.sleep(3)