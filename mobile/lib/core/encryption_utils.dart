import 'dart:convert';
import 'package:crypto/crypto.dart';

class EncryptionUtils {
  /// Calculates the current 30-second time slot.
  static int getCurrentTimeSlot() {
    return (DateTime.now().millisecondsSinceEpoch / 1000 / 30).floor();
  }

  /// Generates the rolling hash ID based on the userId, secret key, and time slot.
  static String generateRollingHash(String userId, String baseSecretKey, int timeSlot) {
    final data = '$userId$baseSecretKey$timeSlot';
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 10).toUpperCase();
  }
}
