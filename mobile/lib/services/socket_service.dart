import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vibration/vibration.dart';
import 'dart:async';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? socket;
  final _storage = const FlutterSecureStorage();
  final _attendanceStreamController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get attendanceStream => _attendanceStreamController.stream;

  void connect() async {
    final userId = await _storage.read(key: 'user_id');
    if (userId == null) return;

    // Use the same base URL as API
    String baseUrl = 'https://ble-attendance-backend-ktik.onrender.com';

    socket = IO.io(baseUrl, IO.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .build());

    socket?.connect();

    socket?.onConnect((_) {
      print('Socket connected: Successfully');
      // Join the private room for this user
      socket?.emit('join_user', userId);
    });

    socket?.on('attendance_marked', (data) {
      print('Real-time attendance received: $data');
      _attendanceStreamController.add(data);
      
      // Provide haptic feedback
      Vibration.vibrate(duration: 500);
    });

    socket?.onDisconnect((_) => print('Socket disconnected'));
  }

  void disconnect() {
    socket?.disconnect();
    _attendanceStreamController.close();
  }
}
