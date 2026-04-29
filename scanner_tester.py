import bluetooth, binascii, time

print("--- RAW TESTER WITH RESET ---")
ble = bluetooth.BLE()
ble.active(False)
time.sleep(1)
ble.active(True)

def irq(event, data):
    if event == 5:
        # data[1] = addr, data[4] = adv_data
        print("ADDR:", binascii.hexlify(data[1]).decode(), "DATA:", binascii.hexlify(data[4]).decode())

ble.irq(irq)
ble.gap_scan(0, 100000, 100000, True)

while True:
    time.sleep(1)
