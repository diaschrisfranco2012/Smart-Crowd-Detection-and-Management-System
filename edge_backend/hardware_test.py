from gpiozero import LED, Buzzer, Button
import time

# Defining your exact CrowdSense pins
green_led = LED(17)
red_led = LED(27)
buzzer = Buzzer(22)
kill_button = Button(23)

print("🚨 CrowdSense Hardware Test Initiated...")
print("Press the physical Kill-Switch button to test LEDs and Buzzer.")
print("Press CTRL+C in the terminal to exit.")

try:
    while True:
        if kill_button.is_pressed:
            print("🟢 Button Pressed! Triggering Hardware...")
            green_led.on()
            red_led.on()
            buzzer.on()
            time.sleep(0.5) # Hold the beep for half a second
            
            green_led.off()
            red_led.off()
            buzzer.off()
            print("⚪ Hardware Reset. Waiting for next press...")
            time.sleep(0.5) # Debounce delay
            
except KeyboardInterrupt:
    print("\n🛑 Exiting test and safely turning off all pins.")
    green_led.off()
    red_led.off()
    buzzer.off()