import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vibration/vibration.dart';
import 'services/api_service.dart';
import 'services/socket_service.dart';
import 'services/ble_broadcaster_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:ui';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDBMQxzViREV6teg68F-Pj7tNezpKeXTjo",
        authDomain: "attendance-57c1e.firebaseapp.com",
        projectId: "attendance-57c1e",
        storageBucket: "attendance-57c1e.firebasestorage.app",
        messagingSenderId: "615644070796",
        appId: "1:615644070796:web:1234567890abcdef",
      ),
    );
  } else {
    await Firebase.initializeApp();
    await initializeService();
  }
  
  runApp(const AttendanceApp());
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'attendance_service_channel',
    'Attendance Broadcaster',
    description: 'Keeps the BLE Broadcaster active in the background',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  if (!kIsWeb) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'attendance_service_channel',
      initialNotificationTitle: 'Attendance Service',
      initialNotificationContent: 'Ready to broadcast',
      foregroundServiceTypes: [AndroidForegroundType.connectedDevice],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Start the BLE Broadcaster logic
  BLEBroadcasterService.runInBackground(service);
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Secure BLE Attendance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF00FFCC),
        scaffoldBackgroundColor: const Color(0xFF0A0E17),
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FFCC),
          secondary: Color(0xFF7B61FF),
          surface: Color(0xFF151A22),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _storage = const FlutterSecureStorage();
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await _requestPermissions();
    final token = await _storage.read(key: 'jwt_token');
    if (mounted) {
      setState(() {
        _isAuthenticated = token != null;
        _isLoading = false;
      });
    }
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) return;
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location,
    ].request();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF00FFCC))));
    }
    return _isAuthenticated ? const DashboardScreen() : const LoginScreen();
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.login(_userIdController.text, _passwordController.text);
      if (res['token'] != null) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const DashboardScreen()));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login failed: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              const Icon(Icons.bluetooth_connected, size: 80, color: Color(0xFF00FFCC)),
              const SizedBox(height: 24),
              const Text('Secure Attendance', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('v2.1.0-FIX', style: TextStyle(color: Colors.white24, fontSize: 12)),
              const SizedBox(height: 48),
              TextField(controller: _userIdController, decoration: const InputDecoration(labelText: 'User ID', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: _passwordController, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()), obscureText: true),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FFCC), foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 50)),
                child: _isLoading ? const CircularProgressIndicator() : const Text('LOGIN'),
              ),
              const SizedBox(height: 16),
              TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegistrationScreen())), child: const Text('New user? Register now')),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  bool _isBroadcasting = false;
  bool _isMarked = false;
  String? _currentHash;
  Map<String, dynamic>? _debugData;
  late AnimationController _pulseController;
  StreamSubscription? _socketSubscription;
  StreamSubscription? _hashSubscription;
  String _statusMessage = "Ready";

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _initAttendanceListener();
    _initHashListener();
    _checkServiceStatus();
  }

  void _checkServiceStatus() async {
    final running = await FlutterBackgroundService().isRunning();
    setState(() {
      _isBroadcasting = running;
      if (running) _statusMessage = "Service Running";
    });
  }

  void _initHashListener() {
    _hashSubscription = FlutterBackgroundService().on('updateHash').listen((event) {
      if (mounted) {
        setState(() {
          _currentHash = event?['hash'];
          _debugData = event;
          _statusMessage = "Active: ${_currentHash}";
        });
      }
    });
  }

  void _initAttendanceListener() {
    SocketService().connect();
    _socketSubscription = SocketService().attendanceStream.listen((data) {
      if (!_isMarked) {
        setState(() {
          _isMarked = true;
          _statusMessage = "Attendance SUCCESS";
        });
        _triggerSuccessFeedback();
      }
    });
  }

  void _triggerSuccessFeedback() async {
    if (await Vibration.hasVibrator() ?? false) Vibration.vibrate(duration: 500);
    HapticFeedback.heavyImpact();
    if (_isBroadcasting) _toggleBroadcast();
  }

  void _toggleBroadcast() async {
    setState(() => _statusMessage = _isBroadcasting ? "Stopping..." : "Starting...");
    if (_isBroadcasting) {
      await BLEBroadcasterService.stopBroadcasting();
    } else {
      await BLEBroadcasterService.startBroadcasting();
    }
    
    // Immediate local update so user doesn't wait for timer
    final localHash = await BLEBroadcasterService.getCurrentHash();
    
    setState(() {
      _isBroadcasting = !_isBroadcasting;
      if (!_isBroadcasting) {
        _currentHash = null;
        _statusMessage = "Stopped";
      } else {
        _currentHash = localHash;
        _statusMessage = "Awaiting Sync...";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dashboard', style: TextStyle(fontSize: 18)),
            Text('v2.1.0-FIX', style: TextStyle(fontSize: 10, color: Colors.white24)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.history), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen()))),
          IconButton(icon: const Icon(Icons.logout), onPressed: () async {
            await const FlutterSecureStorage().deleteAll();
            await BLEBroadcasterService.stopBroadcasting();
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
          }),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              margin: const EdgeInsets.all(32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF151A22), 
                borderRadius: BorderRadius.circular(24), 
                border: Border.all(color: _isMarked ? Colors.greenAccent : Colors.white10),
                boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 15)],
              ),
              child: Column(
                children: [
                  Text('STATUS: ${_statusMessage.toUpperCase()}', style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.2)),
                  const SizedBox(height: 20),
                  if (_isBroadcasting) ...[
                    if (_currentHash == null) ...[
                      const CircularProgressIndicator(strokeWidth: 2),
                      const SizedBox(height: 12),
                      const Text('Searching for BLE...', style: TextStyle(fontSize: 12, color: Colors.white24)),
                    ] else ...[
                      const Text('BROADCASTING UUID', style: TextStyle(color: Color(0xFF00FFCC), fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(_currentHash!, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Color(0xFF00FFCC))),
                      const Divider(color: Colors.white10, height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _smallDebug('USER', _debugData?['userId'] ?? 'SYNCING'),
                          _smallDebug('SLOT', _debugData?['timeSlot']?.toString() ?? 'SYNCING'),
                        ],
                      ),
                    ],
                  ] else ...[
                    const Icon(Icons.bluetooth_disabled, size: 48, color: Colors.white10),
                    const SizedBox(height: 12),
                    const Text('Tap below to start', style: TextStyle(color: Colors.white24)),
                  ],
                  const SizedBox(height: 20),
                  Text(_isMarked ? '✓ ATTENDANCE MARKED' : '• PENDING DETECTION', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _isMarked ? Colors.greenAccent : Colors.orangeAccent)),
                ],
              ),
            ),
            Stack(
              alignment: Alignment.center,
              children: [
                if (_isBroadcasting && !_isMarked)
                  ScaleTransition(
                    scale: Tween(begin: 1.0, end: 1.4).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)),
                    child: Container(width: 180, height: 180, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF00FFCC).withOpacity(0.1))),
                  ),
                GestureDetector(
                  onTap: _isMarked ? null : _toggleBroadcast,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 140, height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, 
                      gradient: LinearGradient(
                        colors: _isMarked 
                          ? [Colors.green.shade900, Colors.green.shade700] 
                          : _isBroadcasting 
                            ? [const Color(0xFF00FFCC), const Color(0xFF00B28F)] 
                            : [const Color(0xFF2A3142), const Color(0xFF151A22)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        if (_isBroadcasting && !_isMarked) 
                          BoxShadow(color: const Color(0xFF00FFCC).withOpacity(0.3), blurRadius: 20, spreadRadius: 5)
                      ],
                    ),
                    child: Icon(_isMarked ? Icons.check : Icons.bluetooth, size: 56, color: (_isBroadcasting || _isMarked) ? Colors.black : Colors.white38),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallDebug(String title, String val) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 8, color: Colors.white38, fontWeight: FontWeight.bold)),
        Text(val, style: const TextStyle(fontSize: 10, color: Colors.white70, fontFamily: 'monospace')),
      ],
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _socketSubscription?.cancel();
    _hashSubscription?.cancel();
    super.dispose();
  }
}

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});
  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nameController = TextEditingController();
  final _instController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _api = ApiService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _instController, decoration: const InputDecoration(labelText: 'Institution Code', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _userController, decoration: const InputDecoration(labelText: 'User ID', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _passController, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()), obscureText: true),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : () async {
                setState(() => _isLoading = true);
                try {
                   await _api.register(_nameController.text, _instController.text, _userController.text, _passController.text);
                   if (!mounted) return;
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Success! Please Login.')));
                   Navigator.pop(context);
                } catch (e) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                } finally {
                   if (mounted) setState(() => _isLoading = false);
                }
              }, 
              child: _isLoading ? const CircularProgressIndicator() : const Text('REGISTER'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _api = ApiService();
  List _history = [];
  bool _loading = true;
  @override
  void initState() { super.initState(); _fetch(); }
  void _fetch() async { 
    try {
      final h = await _api.getHistory();
      if (mounted) setState(() { _history = h; _loading = false; }); 
    } catch(e) {
      if (mounted) setState(() { _loading = false; });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: _loading 
        ? const Center(child: CircularProgressIndicator())
        : _history.isEmpty 
          ? const Center(child: Text('No history found'))
          : ListView.builder(
              itemCount: _history.length,
              itemBuilder: (c, i) => ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.greenAccent),
                title: Text(_history[i]['date'] ?? 'N/A'),
                subtitle: Text(_history[i]['time'] ?? 'N/A'),
              ),
            ),
    );
  }
}
