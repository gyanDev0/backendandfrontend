import network, socket, time, machine, os, bluetooth, urequests, gc, binascii, json
from sh1106 import SH1106_I2C

# --- HARDWARE SETUP ---
# Pins might need adjustment based on user hardware
i2c = machine.I2C(0, scl=machine.Pin(22), sda=machine.Pin(21))
oled = SH1106_I2C(128, 64, i2c)
dac = machine.DAC(machine.Pin(25)) # Internal DAC for audio

# --- BUTTONS ---
btn_up   = machine.Pin(27, machine.Pin.IN, machine.Pin.PULL_UP)
btn_down = machine.Pin(14, machine.Pin.IN, machine.Pin.PULL_UP)
btn_back = machine.Pin(12, machine.Pin.IN, machine.Pin.PULL_UP)
btn_ok   = machine.Pin(13, machine.Pin.IN, machine.Pin.PULL_UP)

# --- CONFIG ---
# Replace with your actual server URL or IP
SERVER_URL = "https://ble-attendance-backend-ktik.onrender.com"
DEVICE_ID = "esp32_01"
CONFIG_FILE = "wifi.dat"

ble = bluetooth.BLE()
# Cache for seen UUIDs to prevent rapid re-scans (cleared every 1 minute)
seen_uuids = {} 

def display(l1="", l2="", l3="", l4="", sel=-1):
    oled.fill(0)
    lines = [l1, l2, l3, l4]
    for i, line in enumerate(lines):
        prefix = "> " if sel == i else "  "
        oled.text(prefix + str(line)[:18], 0, i*16)
    oled.show()

# --- ADV DATA PARSER ---
def parse_adv_data(adv_data):
    res = {"uuid": None, "name": "Unknown"}
    i = 0
    while i < len(adv_data):
        try:
            length = adv_data[i]
            if length == 0: break
            type_code = adv_data[i+1]
            # 0xFF is Manufacturer Data
            if type_code == 0xFF:
                # Assuming company ID (2 bytes) + hash
                res["uuid"] = binascii.hexlify(adv_data[i+4:i+1+length]).decode()
            elif type_code == 0x09: # Complete Local Name
                res["name"] = adv_data[i+2:i+1+length].decode('utf-8')
            i += length + 1
        except: break
    return res

# --- ATTENDANCE SYSTEM ---
def play_audio_data(data):
    # Simple WAV playback (skipping header)
    try:
        # Start after header (approx 44 bytes for standard WAV)
        for i in range(44, len(data)):
            dac.write(data[i])
            # Delay to match sample rate (approx 8000Hz or 16000Hz)
            # 1/16000 = 62.5us, 1/8000 = 125us
            time.sleep_us(100) 
        dac.write(0) # Reset DAC
    except Exception as e:
        print("Audio play error:", e)

def check_server_and_play(uid):
    # Check local cache first
    now = time.time()
    if uid in seen_uuids and (now - seen_uuids[uid]) < 30:
        return

    ble.gap_scan(None) # Stop scan during processing
    display("VERIFYING...", "UUID: " + uid[:10], "", "")
    
    try:
        url = SERVER_URL + "/api/attendance/scan"
        payload = json.dumps({"uuid": uid, "device_id": DEVICE_ID})
        headers = {'Content-Type': 'application/json'}
        
        print("Sending to server:", url)
        res = urequests.post(url, data=payload, headers=headers, timeout=10)
        
        if res.status_code == 200:
            data = res.json()
            res.close()
            
            name = data.get("name", "Unknown")
            audio_url = data.get("audio_url")
            
            display("SUCCESS!", "Welcome", name, "")
            
            if audio_url:
                print("Downloading audio:", audio_url)
                aud_res = urequests.get(audio_url, timeout=15)
                if aud_res.status_code == 200:
                    content = aud_res.content
                    display("PLAYING AUDIO", name, "", "")
                    play_audio_data(content)
                aud_res.close()
            
            seen_uuids[uid] = now # Add to cache
            time.sleep(2)
        else:
            print("Server Error:", res.status_code, res.text)
            display("INVALID ID", "Not Authorized", "Try Again", "")
            res.close()
            time.sleep(2)
            
    except Exception as e:
        print("Request Failed:", e)
        display("SERVER ERROR", "Check Connection", str(e)[:18], "")
        time.sleep(2)
    
    gc.collect()
    display("ATTENDANCE ON", "Ready to Scan", "", "BACK to exit")
    ble.gap_scan(0, 30000, 30000, False)

def attendance_system():
    if not network.WLAN(network.STA_IF).isconnected():
        display("WIFI ERROR", "Not Connected", "Setup WiFi first", "BACK to exit")
        while btn_back.value() == 1: pass
        return
        
    display("ATTENDANCE ON", "Ready to Scan", "", "BACK to exit")
    seen_uuids.clear()
    ble.active(True)
    
    def ble_irq(event, data):
        if event == 5: # _IRQ_SCAN_RESULT
            addr_type, addr, adv_type, rssi, adv_data = data
            info = parse_adv_data(adv_data)
            if info["uuid"]:
                check_server_and_play(info["uuid"])

    ble.irq(ble_irq)
    ble.gap_scan(0, 30000, 30000, False)
    
    while btn_back.value() == 1:
        # Clear cache older than 1 minute to allow re-marking if the user comes back
        now = time.time()
        for uid in list(seen_uuids.keys()):
            if now - seen_uuids[uid] > 60:
                del seen_uuids[uid]
        time.sleep(1)
        
    ble.gap_scan(None)
    ble.active(False)

# --- WIFI & MAIN --- (Simplified for brevity)
def wifi_connect():
    if CONFIG_FILE in os.listdir():
        with open(CONFIG_FILE) as f:
            lines = f.read().splitlines()
            if len(lines) >= 2:
                display("CONNECTING...", lines[0], "", "")
                sta = network.WLAN(network.STA_IF)
                sta.active(True)
                sta.connect(lines[0], lines[1])
                for _ in range(20):
                    if sta.isconnected(): 
                        display("CONNECTED", "IP:", sta.ifconfig()[0], "")
                        time.sleep(1)
                        return True
                    time.sleep(0.5)
    return False

def main():
    wifi_connect()
    menu = ["Attendance", "Reset ESP"]
    sel = 0
    while True:
        display("== SMART ATTEND ==", menu[0], menu[1], "", sel=sel+1)
        if btn_up.value() == 0: sel = (sel-1)%len(menu); time.sleep(0.2)
        if btn_down.value() == 0: sel = (sel+1)%len(menu); time.sleep(0.2)
        if btn_ok.value() == 0:
            time.sleep(0.2)
            if sel == 0: attendance_system()
            elif sel == 1: machine.reset()

if __name__ == "__main__":
    main()
