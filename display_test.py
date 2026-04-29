import machine, time
import ssd1306

# --- HARDWARE SETUP ---
# Default I2C pins for ESP32
SCL_PIN = 22
SDA_PIN = 21

print("Initiating Display Test...")

try:
    i2c = machine.I2C(0, scl=machine.Pin(SCL_PIN), sda=machine.Pin(SDA_PIN))
    
    # scan for devices
    devices = i2c.scan()
    if not devices:
        print("ERROR: No I2C devices found. Check your wiring (VCC, GND, SCL, SDA).")
    else:
        addr = devices[0]
        print(f"I2C devices found at address: {hex(addr)}")
        oled = ssd1306.SSD1306_I2C(128, 64, i2c, addr=addr)
    
    # Simple animation test
    state = True
    while True:
        oled.fill(0)
        oled.text("DISPLAY TEST OK", 0, 0)
        oled.text("Pins: SCL 22, SDA 21", 0, 16)
        
        if state:
            oled.rect(32, 32, 64, 30, 1)
            oled.text("BLINK ON", 40, 42)
        else:
            oled.text("BLINK OFF", 40, 42)
            
        oled.show()
        state = not state
        time.sleep(1)
        
except Exception as e:
    print(f"FAILED to initialize display: {e}")
    print("\nTroubleshooting tips:")
    print("1. Ensure sh1106.py file is uploaded to your ESP32.")
    print("2. Verify SCL is on Pin 22 and SDA is on Pin 21.")
    print("3. Check if your display requires a different I2C address.")
