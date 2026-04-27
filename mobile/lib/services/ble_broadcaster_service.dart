import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../core/encryption_utils.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class BLEBroadcasterService {
  static const _storage = FlutterSecureStorage();
  static bool _isAdvertising = false;
  static final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();

  static bool get isAdvertising => _isAdvertising;

  /// Start the background service which handles BLE advertising
  static Future<void> startBroadcasting() async {
    final service = FlutterBackgroundService();
    var isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
    }
    _isAdvertising = true;
  }

  /// Stop the background service
  static Future<void> stopBroadcasting() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
    _isAdvertising = false;
  }

  /// Entry point for the background isolate
  @pragma('vm:entry-point')
  static void runInBackground(ServiceInstance service) async {
    final storage = const FlutterSecureStorage();
    final peripheral = FlutterBlePeripheral();
    Timer? timer;

    final userId = await storage.read(key: 'user_id');
    final secretKey = await storage.read(key: 'base_secret_key');

    if (userId == null || secretKey == null) {
      service.stopSelf();
      return;
    }

    Future<void> advertise() async {
      try {
        final hash = EncryptionUtils.generateRollingHash(
            userId, secretKey, EncryptionUtils.getCurrentTimeSlot());

        if (await peripheral.isAdvertising) {
          await peripheral.stop();
        }

        // Encode the 10-char rolling hash as raw bytes for Manufacturer Data
        final Uint8List hashBytes = Uint8List.fromList(utf8.encode(hash));

        final AdvertiseData advertiseData = AdvertiseData(
          // PRIMARY: Manufacturer Data (Android) — Company ID 0x1001 + hash bytes
          manufacturerId: 0x1001,
          manufacturerData: hashBytes,
          // SECONDARY: Local Name — iOS fallback (hash is exactly 10 chars)
          localName: hash,
          includeDeviceName: false,
          includePowerLevel: false,
        );

        await peripheral.start(advertiseData: advertiseData);
        
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "Attendance Broadcaster Active",
            content: "Broadcasting Hash: $hash",
          );
        }
      } catch (e) {
        print('[Background BLE] Error: $e');
      }
    }

    // Initial broadcast
    await advertise();

    // Rolling refresh every 30 seconds
    timer = Timer.periodic(const Duration(seconds: 30), (t) async {
      await advertise();
    });

    service.on('stopService').listen((event) async {
      timer?.cancel();
      if (await peripheral.isAdvertising) {
        await peripheral.stop();
      }
      service.stopSelf();
    });
  }

  /// Get the current rolling hash (for display in UI)
  static Future<String?> getCurrentHash() async {
    final userId = await _storage.read(key: 'user_id');
    final secretKey = await _storage.read(key: 'base_secret_key');
    if (userId == null || secretKey == null) return null;
    return EncryptionUtils.generateRollingHash(
        userId, secretKey, EncryptionUtils.getCurrentTimeSlot());
  }
}
