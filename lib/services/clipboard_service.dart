import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../services/device_ws.dart';
import '../utils/appdata_storage.dart';

class ClipboardService {
  static final ClipboardService _instance = ClipboardService._internal();
  factory ClipboardService() => _instance;
  ClipboardService._internal();

  static const int maxClipboardLength = 1024 * 1024; // 1MB limit

  String? _lastSent;
  String? _deviceUid;
  bool _running = false;
  Timer? _fallbackTimer;
  EventChannel? _channel;
  StreamSubscription<dynamic>? _clipboardSub;
  StreamSubscription<Map<String, dynamic>>? _wsSub;
  void Function(bool)? _prevOnConnectionChange;

  Future<void> start() async {
    if (_running) return;
    _running = true;

    _deviceUid = await AppDataStorage.getDeviceUID();

    // Subscribe to WS messages for receiving clipboard sync from remote devices
    _wsSub = DeviceWS().messages.listen(_handleWSMessage);

    // Chain into onConnectionChange for reconnect clipboard re-check
    _prevOnConnectionChange = DeviceWS().onConnectionChange;
    DeviceWS().onConnectionChange = (connected) {
      _prevOnConnectionChange?.call(connected);
      if (connected) {
        _onWSReconnected();
      }
    };

    if (Platform.isAndroid) {
      try {
        _channel = const EventChannel('nix/clipboard');
        _clipboardSub = _channel!.receiveBroadcastStream().listen((text) {
          if (text is String && text.isNotEmpty && text != _lastSent) {
            _sendClipboard(text);
          }
        }, onError: (error) {
          _fallbackToPolling();
        });
      } catch (e) {
        _fallbackToPolling();
      }
    } else {
      _fallbackToPolling();
    }
  }

  void _handleWSMessage(Map<String, dynamic> msg) {
    if (msg['type'] != 'event') return;
    if (msg['event'] != 'clipboard_sync') return;

    final data = msg['data'] as Map<String, dynamic>?;
    if (data == null) return;

    final sourceDevice = data['source_device'] as String?;
    // Secondary echo guard — server already excludes source via send_to_user_device_except
    if (_deviceUid != null && sourceDevice == _deviceUid) return;

    final text = data['text'] as String?;
    if (text == null || text.isEmpty) return;

    _lastSent = text;
    Clipboard.setData(ClipboardData(text: text));
  }

  void _fallbackToPolling() {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollClipboard());
  }

  void stop() {
    _running = false;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _clipboardSub?.cancel();
    _clipboardSub = null;
    _channel = null;
    _wsSub?.cancel();
    _wsSub = null;
    if (_prevOnConnectionChange != null) {
      DeviceWS().onConnectionChange = _prevOnConnectionChange;
      _prevOnConnectionChange = null;
    }
  }

  Future<void> _onWSReconnected() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null && data.text!.isNotEmpty && data.text != _lastSent) {
        if (data.text!.length <= maxClipboardLength) {
          _sendClipboard(data.text!);
        }
      }
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _pollClipboard() async {
    if (!_running) return;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null && data.text!.isNotEmpty && data.text != _lastSent) {
        if (data.text!.length <= maxClipboardLength) {
          _sendClipboard(data.text!);
        }
      }
    } catch (e) {
      // Silently fail on clipboard access denied (e.g., iOS)
    }
  }

  void _sendClipboard(String text) {
    if (!_running || text == _lastSent) return;
    if (text.length > maxClipboardLength) return;
    _lastSent = text;
    DeviceWS().sendCommand('clipboard_sync', data: {'text': text});
  }

  /// Called when clipboard is updated from a remote device via WebSocket
  /// so the local listener/polling won't re-send the same text back.
  void notifyRemoteUpdate(String text) {
    _lastSent = text;
  }
}
