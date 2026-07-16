import 'dart:io' show Platform;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_background_service/flutter_background_service.dart';

import 'screens/home_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/load_config_screen.dart';
import 'services/device_ws.dart';
import 'services/log_service.dart';
import 'services/clipboard_service.dart';
import 'api/logout_device.dart';
import 'utils/app_navigation.dart';
import 'utils/auto_update.dart';
import 'utils/token_storage.dart';
import 'utils/appdata_storage.dart';
import 'utils/app_constants.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _setupDebugPrintInterceptor();
  _wireDeviceWSNotifications();
  _setupNotificationMethodChannel();
  _setupMenuBarChannel();
  runApp(const MyApp());
  _requestNotificationPermission().then((_) async {
    await _initializeBackgroundService();
    _checkLaunchIntent();
  });
}

void _setupMenuBarChannel() {
  const channel = MethodChannel('nix/menu');
  channel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'openDevPanel':
        AppNavigation.onOpenDevPanel?.call();
      case 'refreshConnection':
        await DeviceWS().disconnect();
        DeviceWS().connect();
    }
  });
}

void _setupNotificationMethodChannel() {
  const channel = MethodChannel('nix/notifications');
  channel.setMethodCallHandler((call) async {
    if (call.method == 'openUpdates') {
      AppNavigation.onOpenUpdates?.call();
      AppNavigation.pendingOpenUpdates = AppNavigation.onOpenUpdates == null;
    } else if (call.method == 'openChat') {
      AppNavigation.onOpenChat?.call();
      AppNavigation.pendingOpenChat = AppNavigation.onOpenChat == null;
    }
    return null;
  });
}

Future<void> _checkLaunchIntent() async {
  try {
    const channel = MethodChannel('nix/notifications');
    final extras = await channel.invokeMethod<List<dynamic>>('getLaunchIntent');
    if (extras != null) {
      if (extras.contains('nix_open_updates')) {
        AppNavigation.pendingOpenUpdates = true;
      }
      if (extras.contains('nix_open_chat')) {
        AppNavigation.pendingOpenChat = true;
      }
    }
  } catch (e) {
    debugPrint('Launch intent check failed: $e');
  }
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
  if (!Platform.isAndroid) return;
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
  if (!Platform.isAndroid) return;
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
    await Future.delayed(const Duration(milliseconds: 500));
    service.invoke('updateNotification', {
      'status': DeviceWS().isConnected ? 'running' : 'idle',
    });
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
      navigatorKey: AppNavigation.navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.teal,
      ),
      home: const SplashScreen(),
      routes: {
        '/qr-scanner': (context) => const QRScannerScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/home': (context) => const HomeScreen(),
        '/load-config': (context) => const LoadConfigScreen(),
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
      await DeviceWS().connect();
      startAutoUpdateCheck();
      // Start clipboard sync if enabled
      final clipboardSync = await AppDataStorage.getClipboardSync();
      if (clipboardSync) {
        ClipboardService().start();
      }
      // Handle forced logout from server (device deleted from dashboard)
      DeviceWS().onLogoutRequest = () async {
        try {
          await logout();
        } catch (_) {}
        await DeviceWS().disconnect();
        await AppDataStorage.clearAppData();
        await TokenStorage.clearToken();
        if (Platform.isAndroid) {
          FlutterBackgroundService().invoke('stop');
        }
        AppNavigation.navigatorKey.currentState
            ?.pushReplacementNamed('/qr-scanner');
      };
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else if (Platform.isMacOS) {
      // Desktop: load config file instead of QR scan
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/load-config');
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
