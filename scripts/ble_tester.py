import asyncio
import hashlib
import time
from bleak import BleakScanner

# ==============================================================================
# --- Configuration ---
# Fill in USER_ID and SECRET_KEY to verify your own hash.
# Leave empty to passively log all detected manufacturer-data hashes.
# ==============================================================================
USER_ID = ""     # e.g., "user_123"
SECRET_KEY = ""  # e.g., "your_secret_key"

# Company ID used by the Flutter app (must match manufacturerId: 0x1001)
TARGET_COMPANY_ID = 0x1001


def calculate_expected_hash(user_id, secret_key):
    """Replicates the rolling hash logic from EncryptionUtils.dart"""
    if not user_id or not secret_key:
        return None
    time_slot = int(time.time() // 30)
    data = f"{user_id}{secret_key}{time_slot}"
    return hashlib.sha256(data.encode("utf-8")).hexdigest()[:10].upper()


def extract_hash_from_manufacturer_data(mfr_data: dict) -> str | None:
    """
    Reads the Manufacturer Data field from the advertisement.
    mfr_data is a dict of {company_id (int): bytes}.
    We look for our custom Company ID (0x1001) and decode the bytes as UTF-8.
    """
    if not mfr_data:
        return None
    payload_bytes = mfr_data.get(TARGET_COMPANY_ID)
    if payload_bytes is None:
        return None
    try:
        return payload_bytes.decode("utf-8")
    except Exception:
        return None


async def run_scanner():
    print("=" * 60)
    print("   BLE Attendance Tester — Manufacturer Data Mode")
    print("=" * 60)
    print(f"  Listening for Company ID : 0x{TARGET_COMPANY_ID:04X}")

    expected_hash = calculate_expected_hash(USER_ID, SECRET_KEY)
    if expected_hash:
        print(f"  Verifying against hash   : {expected_hash}  (user={USER_ID})")
    else:
        print("  Mode                     : Passive (no user configured)")
    print("=" * 60)
    print(
        f"{'Source':<16} | {'Hash / Data':<12} | {'Address':<18} | {'RSSI':<5} | Status"
    )
    print("-" * 75)

    seen_devices: dict[str, int] = {}  # address -> last rssi

    def detection_callback(device, advertisement_data):
        # ── PRIMARY: Manufacturer Data ────────────────────────────────────────
        mfr_hash = extract_hash_from_manufacturer_data(
            advertisement_data.manufacturer_data
        )

        # ── FALLBACK: Local Name ───────────────────────────────────────────────
        name = advertisement_data.local_name
        local_name_hash = (
            name if name and len(name) == 10 and name.isupper() else None
        )

        # Decide what to display
        if mfr_hash:
            source = "MFR DATA 0x1001"
            detected_hash = mfr_hash
        elif local_name_hash:
            source = "LOCAL NAME"
            detected_hash = local_name_hash
        else:
            return  # Not our device

        # Determine match status
        if expected_hash:
            if detected_hash == expected_hash:
                status = "✅  MATCH!"
            else:
                status = "⚠️   OTHER HASH"
        else:
            status = "ℹ️   DETECTED"

        # Only print if new device or RSSI changed noticeably
        rssi = device.rssi or 0
        if device.address not in seen_devices or abs(seen_devices[device.address] - rssi) > 3:
            seen_devices[device.address] = rssi
            print(
                f"{source:<16} | {detected_hash:<12} | {device.address:<18} | {rssi:<5} | {status}"
            )

            # Detailed breakdown when MFR data is present
            if mfr_hash and advertisement_data.manufacturer_data:
                raw = advertisement_data.manufacturer_data.get(TARGET_COMPANY_ID, b"")
                hex_str = " ".join(f"0x{b:02X}" for b in raw)
                print(f"  └─ Raw bytes: [{hex_str}]")

    async with BleakScanner(detection_callback):
        print("Scanning... Press Ctrl+C to stop.\n")
        while True:
            await asyncio.sleep(1.0)


if __name__ == "__main__":
    try:
        asyncio.run(run_scanner())
    except KeyboardInterrupt:
        print("\n\nScanner stopped.")
