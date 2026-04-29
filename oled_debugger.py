import bluetooth, binascii, time, machine, ssd1306

# --- OLED DEBUGGER ---
# This bypasses the Serial Monitor to show discovery on screen.

i2c = machine.I2C(0, scl=machine.Pin(22), sda=machine.Pin(21))
oled = ssd1306.SSD1306_I2C(128, 64, i2c)

def display(l1, l2, l3=""):
    oled.fill(0)
    oled.text(l1, 0, 0)
    oled.text(l2, 0, 16)
    oled.text(l3, 0, 32)
    oled.show()

display("OLED DEBUGGER", "Starting BLE...")

ble = bluetooth.BLE()
ble.active(False)
time.sleep(1)
ble.active(True)

dev_count = 0
last_mac = "None"

def irq(event, data):
    global dev_count, last_mac
    if event == 5:
        dev_count += 1
        last_mac = binascii.hexlify(data[1]).decode()[:12]

ble.irq(irq)
ble.gap_scan(0, 100000, 100000, True)

print("Display Debugger Active.")

while True:
    display("SCANNING...", "Count: " + str(dev_count), "Last: " + last_mac)
    time.sleep(1)
