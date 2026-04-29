import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../core/encryption_utils.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'api_service.dart';

class BLEBroadcasterService {
  static const _storage = FlutterSecureStorage();
  static bool _isAdvertising = false;
  static final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();

  static Future<void> startBroadcasting() async {
    final service = FlutterBackgroundService();
    if (!(await service.isRunning())) {
      await service.startService();
    }
    _isAdvertising = true;
  }

  static Future<void> stopBroadcasting() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
    _isAdvertising = false;
  }

  @pragma('vm:entry-point')
  static void runInBackground(ServiceInstance service) async {
    final storage = const FlutterSecureStorage();
    final peripheral = FlutterBlePeripheral();
    int lastTimeSlot = -1;

    Future<void> updateAdvertising() async {
      final currentTimeSlot = EncryptionUtils.getCurrentTimeSlot();
      if (currentTimeSlot == lastTimeSlot) return;
      lastTimeSlot = currentTimeSlot;

      String? userId = await storage.read(key: 'user_id');
      String? secretKey = await storage.read(key: 'base_secret_key');
      if (userId == null || secretKey == null) return;

      try {
        // Try fetch server source of truth UUID first
        String? hexHash = await ApiService.fetchCurrentUUID(userId);

        if (hexHash == null) {
          // Fallback if offline
          final data = '$userId$secretKey$currentTimeSlot';
          final digest = sha256.convert(utf8.encode(data));
          hexHash = digest.toString().toLowerCase().substring(0, 20);
        }

        if (await peripheral.isAdvertising) await peripheral.stop();

        // Standardized Service UUID for discovery
        final String serviceUuid = "0000ff01-0000-1000-8000-00805f9b34fb";
        
        final AdvertiseData advertiseData = AdvertiseData(
          serviceUuid: serviceUuid,
          localName: "ATT", // Short name for fallback
          // Including the hash in Service Data (more reliable than Name)
          serviceData: Uint8List.fromList(utf8.encode(hexHash)),
          includeDeviceName: false,
        );

        await peripheral.start(advertiseData: advertiseData);

        service.invoke('updateHash', {
          'hash': hexHash,
          'userId': userId,
          'timeSlot': currentTimeSlot,
        });
        print('[BLE] Broadcast Active: $hexHash');
      } catch (e) {
        print('[BLE] Error: $e');
      }
    }

    Timer.periodic(const Duration(seconds: 1), (timer) async => await updateAdvertising());
    service.on('stopService').listen((event) async {
      await peripheral.stop();
      service.stopSelf();
    });
    await updateAdvertising();
  }

  static Future<String?> getCurrentHash() async {
    final userId = await _storage.read(key: 'user_id');
    final secretKey = await _storage.read(key: 'base_secret_key');
    if (userId == null || secretKey == null) return null;
    
    String? hash = await ApiService.fetchCurrentUUID(userId);
    if (hash != null) return hash;
    
    return EncryptionUtils.generateRollingHash(userId, secretKey, EncryptionUtils.getCurrentTimeSlot());
  }
}
