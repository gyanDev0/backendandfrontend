import bluetooth
import binascii
import time

# Very simple BLE Scanner
# This script ONLY scans and prints everything it sees.
# No WiFi, No Server, No Display - just raw BLE.

ble = bluetooth.BLE()
ble.active(True)

def demo_irq(event, data):
    if event == 5: # _IRQ_SCAN_RESULT
        addr_type, addr, adv_type, rssi, adv_data = data
        address = binascii.hexlify(addr).decode()
        payload = binascii.hexlify(adv_data).decode()
        
        print("-" * 40)
        print("DEVICE FOUND!")
        print("MAC ADDRESS:", address)
        print("RSSI       :", rssi)
        print("RAW PAYLOAD:", payload)
        
        # Try to decode name if possible
        i = 0
        while i < len(adv_data):
            try:
                length = adv_data[i]
                if length == 0: break
                type_code = adv_data[i+1]
                if type_code in (0x08, 0x09):
                    name = adv_data[i+2:i+1+length].decode('utf-8')
                    print("NAME FOUND :", name)
                i += length + 1
            except: break

print("Starting Scanner Tester...")
ble.irq(demo_irq)

# Scan forever (0ms)
# Interval 100ms, Window 100ms
ble.gap_scan(0, 100000, 100000, True)

print("Scanner is active. Watch the terminal for incoming data.")

while True:
    time.sleep(1)
