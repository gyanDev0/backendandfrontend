import bluetooth, binascii, time

ble = bluetooth.BLE()
ble.active(True)

def analyze_packet(adv_data):
    i = 0
    results = []
    while i < len(adv_data):
        try:
            length = adv_data[i]
            if length == 0: break
            type_code = adv_data[i+1]
            data = adv_data[i+2:i+1+length]
            
            # --- Decode Specific Types ---
            if type_code == 0xFF:
                results.append("  [Manufacturer Data]: " + binascii.hexlify(data).decode())
            elif type_code in (0x02, 0x03):
                # Service UUIDs are often sent in Little Endian
                results.append("  [Service UUIDs   ]: " + binascii.hexlify(data).decode())
            elif type_code == 0x16:
                results.append("  [Service Data    ]: " + binascii.hexlify(data).decode())
            elif type_code in (0x08, 0x09):
                results.append("  [Device Name     ]: " + data.decode('utf-8'))
            else:
                results.append("  [Type 0x{:02x}       ]: ".format(type_code) + binascii.hexlify(data).decode())
            
            i += length + 1
        except: break
    return results

def irq(event, data):
    if event == 5: # _IRQ_SCAN_RESULT
        addr = binascii.hexlify(data[1]).decode()
        rssi = data[3]
        adv_data = data[4]
        
        analysis = analyze_packet(adv_data)
        
        if analysis:
            print("=" * 60)
            print("DEVICE: {} | RSSI: {}".format(addr, rssi))
            for line in analysis:
                print(line)
            # Short sleep to make it readable
            time.sleep(0.5)

print("Starting Deep BLE Analyzer... (Scanning for all records)")
ble.irq(irq)
ble.gap_scan(0, 100000, 100000, True)

while True:
    time.sleep(1)
