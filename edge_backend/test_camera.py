import cv2
import time

print("📷 Initializing CrowdSense Camera Test...")

# Open the default camera (0 is usually the standard Pi camera or USB webcam)
cap = cv2.VideoCapture(0)

# Check if the camera actually opened
if not cap.isOpened():
    print("❌ ERROR: Could not open the camera. Check your physical ribbon cable!")
    exit()

print("✅ Camera connected successfully!")
print("A video window should pop up. Press 'q' on your keyboard to close it.")

# Variables to calculate Frame Rate (FPS)
prev_time = 0

try:
    while True:
        # Read a frame from the camera
        success, frame = cap.read()
        
        if not success:
            print("❌ ERROR: Failed to grab a frame.")
            break
            
        # Calculate a simple FPS counter
        current_time = time.time()
        fps = 1 / (current_time - prev_time)
        prev_time = current_time
        
        # Put the FPS text on the screen
        cv2.putText(frame, f"FPS: {int(fps)}", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
        
        # Show the video feed
        cv2.imshow("CrowdSense Camera Diagnostic", frame)
        
        # Wait for 1 millisecond, and check if 'q' was pressed to quit
        if cv2.waitKey(1) & 0xFF == ord('q'):
            print("🛑 'q' pressed. Shutting down camera.")
            break
            
except KeyboardInterrupt:
    print("\n🛑 Force quit detected.")

finally:
    # Always safely release the camera hardware when done
    cap.release()
    cv2.destroyAllWindows()
    print("⚪ Camera safely unlocked.")