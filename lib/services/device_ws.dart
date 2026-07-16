import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import '../utils/token_storage.dart';
import '../utils/appdata_storage.dart';

class DeviceWS {
  static final DeviceWS _instance = DeviceWS._internal();
  factory DeviceWS() => _instance;
  DeviceWS._internal();

  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _connecting = false;
  Timer? _reconnectTimer;
  String? _userId;
  String? _deviceId;
  String? _baseUrl;

  void Function(bool connected)? onConnectionChange;
  void Function()? onLogoutRequest;

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  bool get isConnected => _isConnected;

  static const String _defaultBaseUrl = 'https://quiet-pup-summary.ngrok-free.app';

  Future<void> connect({String? baseUrl}) async {
    if (_connecting) return;
    _connecting = true;
    if (_isConnected) {
      _connecting = false;
      return;
    }
    _baseUrl = baseUrl ?? _defaultBaseUrl;
    final token = await TokenStorage.getAccessToken();
    _deviceId = await AppDataStorage.getDeviceUID();

    if (token == null || _deviceId == null) {
      debugPrint('DeviceWS: Missing token or device UID');
      _connecting = false;
      return;
    }

    try {
      final jwt = JWT.decode(token);
      _userId = jwt.payload['uid'] as String?;
    } catch (e) {
      debugPrint('DeviceWS: Failed to decode JWT: $e');
      _connecting = false;
      return;
    }

    if (_userId == null) {
      debugPrint('DeviceWS: Missing user ID in token');
      _connecting = false;
      return;
    }

    await _doConnect(token);
    _connecting = false;
  }

  Future<void> _doConnect(String token) async {
    if (_deviceId == null || _userId == null) return;

    final wsUrl = _baseUrl!
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');

    final uri = Uri.parse('$wsUrl/comms/ws/device/$_userId/$_deviceId?token=$token');

    try {
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;
      _isConnected = true;
      _reconnectTimer?.cancel();
      debugPrint('DeviceWS: Connected');
      onConnectionChange?.call(true);

      _channel!.stream.listen(
        (data) {
          try {
            final message = jsonDecode(data as String) as Map<String, dynamic>;
            // Intercept logout command from server (e.g., device deleted from dashboard)
            if (message['type'] == 'command' && message['action'] == 'logout') {
              onLogoutRequest?.call();
              return;
            }
            _messageController.add(message);
          } catch (e) {
            debugPrint('DeviceWS: Parse error: $e');
          }
        },
        onDone: () {
          debugPrint('DeviceWS: Disconnected');
          _isConnected = false;
          onConnectionChange?.call(false);
          _scheduleReconnect();
        },
        onError: (error) {
          debugPrint('DeviceWS: Error: $error');
          _isConnected = false;
          onConnectionChange?.call(false);
          _scheduleReconnect();
        },
      );
    } catch (e) {
      debugPrint('DeviceWS: Connection failed: $e');
      _isConnected = false;
      _connecting = false;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () async {
      final token = await TokenStorage.getAccessToken();
      if (token != null) {
        await _doConnect(token);
      }
    });
  }

  void sendCommand(String action, {Map<String, dynamic>? data}) {
    if (_channel == null || !_isConnected) {
      debugPrint('DeviceWS: Not connected, cannot send command');
      return;
    }

    final message = {
      'action': action,
      if (data != null) 'data': data,
    };

    try {
      _channel!.sink.add(jsonEncode(message));
    } catch (e) {
      debugPrint('DeviceWS: Send error: $e');
    }
  }

  Future<Map<String, dynamic>?> sendCommandAndWait(
    String action, {
    Map<String, dynamic>? data,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!_isConnected) {
      debugPrint('DeviceWS: Not connected');
      return null;
    }

    final completer = Completer<Map<String, dynamic>?>();
    StreamSubscription<Map<String, dynamic>>? sub;

    sub = _messageController.stream.listen((msg) {
      if (msg['type'] == 'response' && msg['action'] == action) {
        completer.complete(msg['data'] as Map<String, dynamic>?);
        sub?.cancel();
      }
    });

    sendCommand(action, data: data);

    final result = await completer.future.timeout(timeout, onTimeout: () {
      sub?.cancel();
      return null;
    });

    return result;
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _isConnected = false;
    onConnectionChange?.call(false);
    await _channel?.sink.close();
    _channel = null;
    debugPrint('DeviceWS: Disconnected');
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
