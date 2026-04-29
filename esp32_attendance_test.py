import bluetooth, binascii, time, machine

# --- ATOMIC RECOVERY SCANNER ---
print("--- HARD-RESETTING BLE RADIO ---")
ble = bluetooth.BLE()
ble.active(False)
time.sleep(1)
ble.active(True)
time.sleep(1)

def irq(event, data):
    if event == 5: # _IRQ_SCAN_RESULT
        addr = binascii.hexlify(data[1]).decode()
        rssi = data[3]
        adv_data = binascii.hexlify(data[4]).decode()
        
        # Check for our ATT identifier in the payload
        # Service UUID 0xFF01 appears as '030301ff' or '020106...1601ff'
        is_attendance = "01ff" in adv_data
        
        print("-" * 50)
        print("DEVICE  :", addr)
        print("RSSI    :", rssi)
        if is_attendance:
            print(">>> FOUND ATTENDANCE SIGNAL! <<<")
            print("DATA    :", adv_data)

print("Scanner V4 (RECOVERY) Started.")
ble.irq(irq)

# 100ms interval, 100ms window (100% duty cycle for testing)
ble.gap_scan(0, 100000, 100000, True)

# Heartbeat loop
count = 0
while True:
    count += 1
    print("System Heartbeat... {} seconds active".format(count * 5))
    
    # Check if radio is still active
    if not ble.active():
        print("CRITICAL: BLE went inactive! Restarting...")
        ble.active(True)
        ble.gap_scan(0, 100000, 100000, True)
        
    time.sleep(5)
