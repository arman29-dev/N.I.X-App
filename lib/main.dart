import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_background_service/flutter_background_service.dart';

import 'screens/home_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/device_ws.dart';
import 'services/log_service.dart';
import 'utils/token_storage.dart';
import 'utils/appdata_storage.dart';
import 'utils/app_constants.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _setupDebugPrintInterceptor();
  _wireDeviceWSNotifications();
  runApp(const MyApp());
  _requestNotificationPermission().then((_) {
    _initializeBackgroundService();
  });
}

Future<void> _requestNotificationPermission() async {
  if (!Platform.isAndroid) return;
  try {
    const channel = MethodChannel('nix/notifications');
    final granted = await channel.invokeMethod<bool>('requestNotificationPermission');
    debugPrint('[Notification] POST_NOTIFICATIONS granted: $granted');
  } catch (e) {
    debugPrint('[Notification] Permission request failed: $e');
  }
}

void _wireDeviceWSNotifications() {
  debugPrint('[Notification] Wiring WS notification callbacks');
  DeviceWS().onConnectionChange = (connected) {
    debugPrint('[Notification] WS status changed to: ${connected ? "running" : "idle"}');
    try {
      FlutterBackgroundService().invoke('updateNotification', {
        'status': connected ? 'running' : 'idle',
      });
      debugPrint('[Notification] invoke() called successfully');
    } catch (e) {
      debugPrint('[Notification] Failed to send notification update: $e');
    }
  };
  // Fire immediately if WS already connected (race condition guard)
  if (DeviceWS().isConnected) {
    debugPrint('[Notification] WS already connected, firing immediately');
    DeviceWS().onConnectionChange?.call(true);
  }
}

Future<void> _initializeBackgroundService() async {
  try {
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onBgServiceStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: AppConstants.notificationChannelId,
        initialNotificationTitle: 'N.I.X ~ starting',
        initialNotificationContent: 'Background service initializing',
        foregroundServiceTypes: const [
          AndroidForegroundType.dataSync,
        ],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onBgServiceStart,
      ),
    );
    await service.startService();
  } catch (e) {
    debugPrint('Background service init failed: $e');
  }
}

@pragma('vm:entry-point')
void _onBgServiceStart(ServiceInstance service) {
  debugPrint('[Notification] Background service started');
  if (service is AndroidServiceInstance) {
    service.on('updateNotification').listen((event) {
      final status = (event?['status'] as String?) ?? 'running';
      debugPrint('[Notification] Updating notification to: $status');
      service.setForegroundNotificationInfo(
        title: 'N.I.X ~ $status',
        content: 'Tap to open',
      );
      debugPrint('[Notification] Notification updated successfully');
    });

    service.on('stop').listen((_) {
      debugPrint('[Notification] Background service stopping');
      service.stopSelf();
    });
  }
}

void _setupDebugPrintInterceptor() {
  final logService = LogService();
  final originalDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    originalDebugPrint(message, wrapWidth: wrapWidth);
    if (message != null && message.isNotEmpty) {
      logService.addDeviceLog(message);
    }
  };
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'N.I.X',
      theme: ThemeData(
        primarySwatch: Colors.teal,
      ),
      home: const SplashScreen(),
      routes: {
        '/qr-scanner': (context) => const QRScannerScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/home': (context) => const HomeScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  void _checkLoginStatus() async {
    final token = await TokenStorage.getAccessToken();
    final deviceUid = await AppDataStorage.getDeviceUID();
    if (token != null && deviceUid != null) {
      DeviceWS().connect();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else if (mounted) {
      Navigator.pushReplacementNamed(context, '/qr-scanner');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
