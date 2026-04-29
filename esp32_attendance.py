import network, socket, time, machine, os, bluetooth, urequests, gc, json, binascii

# --- CONFIG ---
SERVER_URL = "https://ble-attendance-backend-ktik.onrender.com"
DEVICE_ID = "esp32_01"
CONFIG_FILE = "wifi.dat"

# --- HARDWARE ---
i2c = machine.I2C(0, scl=machine.Pin(22), sda=machine.Pin(21))
import ssd1306
oled = ssd1306.SSD1306_I2C(128, 64, i2c)
btn_ok = machine.Pin(13, machine.Pin.IN, machine.Pin.PULL_UP)

def display(l1="", l2="", l3="", l4=""):
    oled.fill(0)
    oled.text(str(l1)[:18], 0, 0); oled.text(str(l2)[:18], 0, 16)
    oled.text(str(l3)[:18], 0, 32); oled.text(str(l4)[:18], 0, 48)
    oled.show()

# Setup DAC on generic Pin 25
dac = machine.DAC(machine.Pin(25))

# --- OPTIMIZED PARSER: HUNT FOR SERVICE DATA (0x16) FOR UUID 0xFF01 ---
def parse_attendance_data(adv_data):
    i = 0
    while i < len(adv_data):
        try:
            length = adv_data[i]
            if length == 0: break
            type_code = adv_data[i+1]
            
            # 0x16 = Service Data (16-bit UUID)
            if type_code == 0x16:
                # Payload: [UUID 2 bytes][Rolling Hash...]
                payload = adv_data[i+2:i+1+length]
                # Check for our ID: 0xFF01 (Stored as \x01\xff in Little Endian)
                if payload[0:2] == b'\x01\xff':
                    return payload[2:].decode('utf-8')
            i += length + 1
        except: break
    return None

def mark_attendance(uid):
    display("VERIFYING...", uid[:15], "Please wait")
    try:
        print(">>> DISCOVERED PHONE! UUID:", uid)
        url = SERVER_URL + "/api/attendance"
        res = urequests.post(url, json={"uuid": uid, "device_id": DEVICE_ID}, stream=True, timeout=10)
        
        if res.status_code == 200:
            name = res.headers.get("X-User-Name", "User")
            display("SUCCESS!", "Welcome", name)
            print("Access granted to:", name)
            
            # Skip WAV header (approx 44 bytes) safely
            try:
                res.raw.read(44)
                while True:
                    chunk = res.raw.read(256)
                    if not chunk: break
                    for b in chunk:
                        dac.write(b)
                        time.sleep_us(85) # slightly faster than 90us to account for loop overhead
            except Exception as e:
                print("Audio play error:", e)
        else:
            display("INVALID", "Error: " + str(res.status_code))
            print("Access denied. Code:", res.status_code)
        res.close()
    except Exception as e:
        display("SERVER ERROR", "Check WiFi")
        print("Request failed:", e)
    time.sleep(2)

def start_scanning():
    ble = bluetooth.BLE(); ble.active(True)
    seen = {}
    print("--- ATTENDANCE SCANNER V3 (SERVICE UUID) ---")
    display("SYSTEM READY", "Scanning for app")
    
    def irq(event, data):
        if event == 5:
            addr_type, addr, adv_type, rssi, adv_data = data
            uid = parse_attendance_data(adv_data)
            if uid:
                now = time.time()
                if uid not in seen or (now - seen[uid]) > 30:
                    mark_attendance(uid)
                    seen[uid] = now
                    display("SYSTEM READY", "Scanning for app")

    ble.irq(irq)
    # Active scan, 100ms interval, 50ms window
    ble.gap_scan(0, 100000, 50000, True)
    while True: time.sleep(1)

def wifi_connect():
    sta = network.WLAN(network.STA_IF); sta.active(True)
    if CONFIG_FILE in os.listdir():
        with open(CONFIG_FILE) as f:
            lines = f.read().splitlines()
            display("WIFI...", lines[0])
            sta.connect(lines[0], lines[1])
            for _ in range(20):
                if sta.isconnected(): return True
                time.sleep(0.5)
    return False

# --- MAIN ---
print("System V3 Started.")
display("ATTENDANCE SYSTEM", "Press OK to Start")
while btn_ok.value() == 1: time.sleep(0.1)

if wifi_connect():
    start_scanning()
else:
    display("WIFI ERROR", "Reboot to try")
