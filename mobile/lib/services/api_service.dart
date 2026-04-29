import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static String get baseUrl {
    return 'https://ble-attendance-backend-ktik.onrender.com/api';
  }
  final _storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> register(String name, String institutionCode, String userId, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'institution_code': institutionCode,
        'user_id': userId,
        'password': password,
      }),
    ).timeout(const Duration(seconds: 10));
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> login(String userId, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'password': password,
      }),
    ).timeout(const Duration(seconds: 10));

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      await _storage.write(key: 'jwt_token', value: data['token']);
      await _storage.write(key: 'base_secret_key', value: data['base_secret_key']);
      await _storage.write(key: 'user_id', value: data['user']['user_id']);
    }

    return data;
  }

  Future<List<dynamic>> getHistory() async {
    final token = await _storage.read(key: 'jwt_token');
    final response = await http.get(
      Uri.parse('$baseUrl/attendance/history'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['history'] ?? [];
    } else {
      throw Exception('Failed to load history: ${response.body}');
    }
  }

  static Future<String?> fetchCurrentUUID(String userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/attendance/uuid?userId=$userId')).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['uuid'];
      }
    } catch (_) { }
    return null;
  }
}
