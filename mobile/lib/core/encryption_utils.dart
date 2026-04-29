import 'dart:convert';
import 'package:crypto/crypto.dart';

class EncryptionUtils {
  /// Calculates the current 30-second time slot.
  static int getCurrentTimeSlot() {
    return (DateTime.now().millisecondsSinceEpoch / 1000 / 30).floor();
  }

  /// Generates the rolling hash ID based on the userId, secret key, and time slot.
  /// Standardized to Lowercase Hex for cross-platform compatibility.
  static String generateRollingHash(String userId, String baseSecretKey, int timeSlot) {
    final data = '$userId$baseSecretKey$timeSlot';
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    
    // Using first 20 characters of the hex string to ensure it fits in BLE packets
    // while remaining highly secure.
    return digest.toString().toLowerCase().substring(0, 20);
  }
}
