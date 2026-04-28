#!/usr/bin/env python
# coding: utf-8

# In[ ]:


import streamlit as st
import cv2
import numpy as np
from ultralytics import YOLO
import tempfile
import time
from twilio.rest import Client  # <--- NEW IMPORT

# ==========================================
#  TWILIO CONFIGURATION (FILL THESE IN)
# ==========================================
TWILIO_SID = ""
TWILIO_TOKEN = ""
FROM_NUMBER = ""  # Your Twilio Number
TO_NUMBER = ""    # The Guard's Personal Number

# Initialize Twilio Client (Safe fail if keys are empty)
try:
    client = Client(TWILIO_SID, TWILIO_TOKEN)
except:
    client = None

# ==========================================
# 1. APP CONFIGURATION
# ==========================================
st.set_page_config(
    page_title="Stampede Risk Analysis",
    page_icon="🛡️",
    layout="wide",
    initial_sidebar_state="collapsed"
)

# ==========================================
# 2. SESSION STATE
# ==========================================
if 'page' not in st.session_state:
    st.session_state['page'] = 'home'
if 'video_source' not in st.session_state:
    st.session_state['video_source'] = None
if 'theme' not in st.session_state:
    st.session_state['theme'] = 'light'

# Buffer & Alert Logic State
if 'start_critical_time' not in st.session_state:
    st.session_state['start_critical_time'] = None
if 'last_alert_time' not in st.session_state:
    st.session_state['last_alert_time'] = 0
if 'last_call_time' not in st.session_state: # <--- NEW: Call Cooldown
    st.session_state['last_call_time'] = 0

# ==========================================
# 3. DYNAMIC CSS
# ==========================================
if st.session_state['theme'] == 'dark':
    bg_color = "#0f172a"
    text_color = "#f8fafc"
    card_bg = "#1e293b"
    border_color = "#334155"
    shadow_color = "rgba(0,0,0,0.3)"
    sidebar_icon_color = "#ffffff"
else:
    bg_color = "#f1f5f9"
    text_color = "#0f172a"
    card_bg = "#ffffff"
    border_color = "#e2e8f0"
    shadow_color = "rgba(0,0,0,0.05)"
    sidebar_icon_color = "#334155"

st.markdown(f"""
    <style>
        .stApp {{
            background-color: {bg_color};
            font-family: 'Poppins', sans-serif;
            color: {text_color};
        }}
        header {{visibility: hidden;}}
        .block-container {{
            padding-top: 1rem;
            padding-bottom: 0rem;
        }}
        
        [data-testid="stSidebarCollapsedControl"] {{
            color: {sidebar_icon_color} !important;
            background-color: {card_bg};
            border-radius: 50%;
            padding: 5px;
            box-shadow: 0 2px 5px {shadow_color};
        }}
        
        .status-container {{
            display: flex;
            justify-content: center;
            gap: 20px;
            margin-bottom: 10px;
        }}
        .status-box {{
            padding: 12px 20px;
            border-radius: 10px;
            font-weight: 600;
            font-size: 1.1rem;
            min-width: 250px;
            text-align: center;
            background: {card_bg};
            box-shadow: 0 4px 6px {shadow_color};
            border: 1px solid {border_color};
            color: {text_color};
        }}
        
        .status-normal {{ background-color: #dcfce7; color: #15803d; border-color: #bbf7d0; }}
        .status-warning {{ background-color: #fef9c3; color: #a16207; border-color: #fde047; }}
        .status-critical {{ 
            background-color: #fee2e2; 
            color: #b91c1c; 
            border-color: #fecaca;
            animation: pulse 1.5s infinite;
        }}
        
        @keyframes pulse {{
            0% {{ box-shadow: 0 0 0 0 rgba(220, 38, 38, 0.4); }}
            70% {{ box-shadow: 0 0 0 10px rgba(220, 38, 38, 0); }}
            100% {{ box-shadow: 0 0 0 0 rgba(220, 38, 38, 0); }}
        }}

        [data-testid="stImage"] img {{
            border-radius: 12px;
            max-height: 400px;
            width: auto;
            object-fit: contain;
            box-shadow: 0 10px 30px {shadow_color};
        }}
        
        h1, h2, h3, p {{ color: {text_color} !important; }}
    </style>
""", unsafe_allow_html=True)

# ==========================================
# 4. HELPER FUNCTIONS
# ==========================================
@st.cache_resource
def load_model():
    return YOLO('yolo11n.pt')

model = load_model()

def trigger_emergency_call(count):
    """Triggers a Twilio call if not in cooldown."""
    CALL_COOLDOWN = 60 # Seconds between calls
    
    if time.time() - st.session_state['last_call_time'] > CALL_COOLDOWN:
        if client:
            try:
                message = f"Critical Alert. Stampede risk detected. Crowd count is {count}. Immediate action required."
                call = client.calls.create(
                    twiml=f'<Response><Say voice="alice">{message}</Say></Response>',
                    to=TO_NUMBER,
                    from_=FROM_NUMBER
                )
                st.toast(f"📲 CALLING SECURITY! (SID: {call.sid})", icon="📞")
                st.session_state['last_call_time'] = time.time()
            except Exception as e:
                st.error(f"Twilio Failed: {e}")
        else:
            st.toast("⚠️ Twilio Keys Missing - Call Simuluated", icon="🔕")

def create_density_bar(count):
    max_capacity = 100 
    percentage = min(count / max_capacity, 1.0)
    bar_length = 10
    filled = int(bar_length * percentage)
    bar = "█" * filled + "░" * (bar_length - filled)
    return f"{count} People detected &nbsp; {bar}"

def process_frame(frame):
    results = model.predict(frame, conf=0.10, iou=0.90, imgsz=640, classes=[0], verbose=False)
    total_persons = len(results[0].boxes) if results[0].boxes else 0
    overlay = frame.copy()
    
    status_text = "Normal"
    css_class = "status-normal"
    
    if total_persons > 20:
        if st.session_state['start_critical_time'] is None:
            st.session_state['start_critical_time'] = time.time()
        
        elapsed = time.time() - st.session_state['start_critical_time']
        
        if elapsed > 3.0:
            status_text = "CRITICAL RISK"
            css_class = "status-critical"
            
            # --- ALERT LOGIC ---
            # 1. UI Toast Notification
            if time.time() - st.session_state['last_alert_time'] > 5:
                st.toast("🚨 STAMPEDE DETECTED: PLEASE CLEAR THE AREA!", icon="⚠️")
                st.session_state['last_alert_time'] = time.time()
            
            # 2. Twilio Phone Call (NEW ADDITION)
            trigger_emergency_call(total_persons)

        else:
            status_text = f"High Density (Confirming... {int(elapsed)}s)"
            css_class = "status-warning"
    else:
        st.session_state['start_critical_time'] = None # Reset buffer
        if total_persons > 20:
            status_text = "High Density"
            css_class = "status-warning"

    # Drawing Boxes
    if results[0].boxes:
        for box in results[0].boxes:
            x1, y1, x2, y2 = map(int, box.xyxy[0])
            box_color = (0, 255, 0) # Default Green
            if total_persons > 20: box_color = (0, 165, 255) # Orange
            if status_text == "CRITICAL RISK": box_color = (0, 0, 255) # Red
            cv2.rectangle(overlay, (x1, y1), (x2, y2), box_color, -1)

    cv2.addWeighted(overlay, 0.4, frame, 0.6, 0, frame)
    return frame, total_persons, status_text, css_class

# ==========================================
# 5. SIDEBAR
# ==========================================
with st.sidebar:
    st.title("⚙️ Settings")
    mode = st.radio("Display Mode", ["Light", "Dark"], index=0 if st.session_state['theme'] == 'light' else 1)
    if mode == "Dark" and st.session_state['theme'] != 'dark':
        st.session_state['theme'] = 'dark'
        st.rerun()
    elif mode == "Light" and st.session_state['theme'] != 'light':
        st.session_state['theme'] = 'light'
        st.rerun()

# ==========================================
# 6. PAGES
# ==========================================
def show_home():
    st.markdown("<br>", unsafe_allow_html=True)
    col1, col2, col3 = st.columns([1, 2, 1])
    with col2:
        with st.container(border=True):
            st.markdown("<h1 style='text-align: center;'>🛡️ Stampede Risk Analysis</h1>", unsafe_allow_html=True)
            if st.button(" Start Live Webcam Feed", use_container_width=True, type="primary"):
                st.session_state['page'] = 'live'
                st.rerun()
            st.markdown("---")
            uploaded_file = st.file_uploader(" ", type=["mp4", "avi"])
            if uploaded_file:
                if st.button("Analyze Uploaded Media", use_container_width=True):
                    st.session_state['video_source'] = uploaded_file
                    st.session_state['page'] = 'analysis'
                    st.rerun()

def run_video_loop(cap):
    status_placeholder = st.empty()
    video_placeholder = st.empty()
    frame_count = 0
    
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret: break
            
        processed_frame, count, status, css = process_frame(frame)
        
        # UI Updates
        status_placeholder.markdown(f"""
            <div class="status-container">
                <div class="status-box {css}">Chances: {status}</div>
                <div class="status-box">{create_density_bar(count)}</div>
            </div>
        """, unsafe_allow_html=True)
        
        frame_rgb = cv2.cvtColor(processed_frame, cv2.COLOR_BGR2RGB)
        video_placeholder.image(frame_rgb, channels="RGB", use_container_width=True)

def show_live():
    if st.button("⬅ Home"):
        st.session_state['page'] = 'home'
        st.rerun()
    cap = cv2.VideoCapture(0)
    run_video_loop(cap)
    cap.release()

def show_analysis():
    if st.button("⬅ Home"):
        st.session_state['page'] = 'home'
        st.session_state['video_source'] = None
        st.rerun()
    tfile = tempfile.NamedTemporaryFile(delete=False)
    tfile.write(st.session_state['video_source'].read())
    cap = cv2.VideoCapture(tfile.name)
    run_video_loop(cap)
    cap.release()

# ==========================================
# 7. ROUTER
# ==========================================
if st.session_state['page'] == 'home': show_home()
elif st.session_state['page'] == 'live': show_live()
elif st.session_state['page'] == 'analysis': show_analysis()

