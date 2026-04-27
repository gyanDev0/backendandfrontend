 import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
 import 'package:flutter_secure_storage/flutter_secure_storage.dart';
 import 'package:firebase_core/firebase_core.dart';
 import 'package:cloud_firestore/cloud_firestore.dart';
 import 'package:vibration/vibration.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vibration/vibration.dart';
import 'services/api_service.dart';
import 'services/socket_service.dart';
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
        appId: "1:615644070796:web:1234567890abcdef", // Placeholder, will work for Firestore
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

  // Start the BLE Broadcaster logic within the background isolate
  BLEBroadcasterService.runInBackground(service);
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Secure BLE Attendance',
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
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Colors.white),
          bodyLarge: TextStyle(fontFamily: 'Inter', color: Colors.white70),
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
    // Request permissions first
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

    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location,
    ].request();

    if (kDebugMode) {
      statuses.forEach((permission, status) {
        print('${permission.toString()}: ${status.toString()}');
      });
    }
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
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.bluetooth_connected, size: 80, color: Color(0xFF00FFCC)),
              const SizedBox(height: 24),
              const Text('Secure Attendance', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
              const SizedBox(height: 48),
              TextField(
                controller: _userIdController,
                decoration: const InputDecoration(labelText: 'User ID', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
                obscureText: true,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FFCC),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.black) 
                    : const Text('LOGIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegistrationScreen()));
                },
                child: const Text('New user? Register now', style: TextStyle(color: Color(0xFF00FFCC))),
              ),
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
  // Removed instance because methods are static
  bool _isBroadcasting = false;
  bool _isMarked = false;
  String? _userId;
  late AnimationController _pulseController;
  StreamSubscription? _socketSubscription;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _initAttendanceListener();
  }

  Future<void> _initAttendanceListener() async {
    SocketService().connect();
    _socketSubscription = SocketService().attendanceStream.listen((data) {
      if (!_isMarked) {
        setState(() => _isMarked = true);
        _triggerSuccessFeedback();
        
        // Show a success dialog or snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attendance marked for ${data['name']}!'),
            backgroundColor: Colors.green,
          )
        );
      }
    });
  }

  void _triggerSuccessFeedback() async {
    // Vibrate
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 500, amplitude: 128);
    }
    // Haptic feedback
    HapticFeedback.heavyImpact();
    
    // Stop broadcasting automatically once marked
    if (_isBroadcasting) {
      _toggleBroadcast();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _socketSubscription?.cancel();
    BLEBroadcasterService.stopBroadcasting();
    super.dispose();
  }

  void _toggleBroadcast() async {
    if (_isBroadcasting) {
      await BLEBroadcasterService.stopBroadcasting();
    } else {
      await BLEBroadcasterService.startBroadcasting();
    }
    setState(() {
      _isBroadcasting = !_isBroadcasting;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Color(0xFF00FFCC)),
            tooltip: 'Attendance History',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            onPressed: () async {
              await const FlutterSecureStorage().deleteAll();
              await BLEBroadcasterService.stopBroadcasting();
              if(!mounted) return;
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- NEW: Today's Status Card ---
            Container(
              margin: const EdgeInsets.fromLTRB(32, 0, 32, 48),
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF151A22),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _isMarked ? Colors.greenAccent.withOpacity(0.3) : Colors.white10,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'TODAY\'S STATUS',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      letterSpacing: 1.5,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isMarked ? Icons.verified_user : Icons.pending_actions,
                        color: _isMarked ? Colors.greenAccent : Colors.orangeAccent,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isMarked ? 'Attendance Marked' : 'Pending Detection',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _isMarked ? Colors.greenAccent : Colors.orangeAccent,
                        ),
                      ),
                    ],
                  ),
                  if (_isMarked) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Last updated: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                    ),
                  ]
                ],
              ),
            ),

            Stack(
              alignment: Alignment.center,
              children: [
                if (_isBroadcasting && !_isMarked)
                  ScaleTransition(
                    scale: Tween(begin: 1.0, end: 1.5).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)),
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF00FFCC).withOpacity(0.2),
                      ),
                    ),
                  ),
                GestureDetector(
                  onTap: _isMarked ? null : _toggleBroadcast,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: _isMarked
                          ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
                          : _isBroadcasting 
                            ? [const Color(0xFF00FFCC), const Color(0xFF00B28F)]
                            : [const Color(0xFF3A4255), const Color(0xFF2A3142)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        if (_isBroadcasting && !_isMarked)
                          BoxShadow(
                            color: const Color(0xFF00FFCC).withOpacity(0.6),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                      ],
                    ),
                    child: Icon(
                      _isMarked ? Icons.check : Icons.bluetooth,
                      size: 64,
                      color: (_isBroadcasting || _isMarked) ? Colors.black : Colors.white54,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            if (_isMarked)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.greenAccent.withOpacity(0.5), width: 2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.greenAccent, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Attendance Marked!',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          Text(
                            'Successfully recorded at ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              Text(
                _isBroadcasting ? 'Broadcasting Secure ID...' : 'Tap to Broadcast',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _isBroadcasting ? const Color(0xFF00FFCC) : Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40.0),
                child: Text(
                  'Your dynamic ID refreshes every 30 seconds. Keep your device near the ESP32 scanner.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, height: 1.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nameController = TextEditingController();
  final _institutionController = TextEditingController();
  final _userIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;

  Future<void> _register() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.register(
        _nameController.text,
        _institutionController.text,
        _userIdController.text,
        _passwordController.text,
      );
      if (res['message'] != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration successful! Please login.')));
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration failed: ${res['error']}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline)),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _institutionController,
                decoration: const InputDecoration(labelText: 'Institution Code', border: OutlineInputBorder(), prefixIcon: Icon(Icons.school)),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _userIdController,
                decoration: const InputDecoration(labelText: 'User ID', border: OutlineInputBorder(), prefixIcon: Icon(Icons.fingerprint)),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline)),
                obscureText: true,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FFCC),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.black) 
                    : const Text('REGISTER', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
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
  final _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _history = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final history = await _apiService.getHistory();
      if (mounted) {
        setState(() {
          _history = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FFCC)))
          : _error != null
              ? Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.redAccent)))
              : _history.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 64, color: Colors.white.withOpacity(0.2)),
                          const SizedBox(height: 16),
                          const Text('No records found yet', style: TextStyle(color: Colors.white54)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchHistory,
                      color: const Color(0xFF00FFCC),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          final item = _history[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF151A22),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00FFCC).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.calendar_today, color: Color(0xFF00FFCC), size: 20),
                              ),
                              title: Text(
                                item['date'] ?? 'Unknown Date',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              subtitle: Text(
                                'Time: ${item['time'] ?? '--:--:--'}',
                                style: TextStyle(color: Colors.white.withOpacity(0.5)),
                              ),
                              trailing: const Icon(Icons.check_circle, color: Colors.greenAccent),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
