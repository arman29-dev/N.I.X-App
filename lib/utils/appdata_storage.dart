import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppDataStorage {
  static String? _email;
  static String? _accessTokenUID;
  static String? _deviceUID;

  static const String _deviceStatusKey = 'device_status';
  static const String _batteryOptAskedKey = 'battery_opt_asked';
  static const String _devUnlockedKey = 'dev_unlocked';
  static const String _notificationEmailKey = 'notification_email';
  static const String _backgroundRunKey = 'background_run';
  static const String _lastInstalledReleaseKey = 'last_installed_release';

  static Future<String> get _filePath async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/login_data.json';
  }

  static Future<void> setEmail(String email) async {
    _email = email;
    await _updateFile({'email': email});
  }

  static Future<void> setDeviceStatus(bool status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_deviceStatusKey, status);
  }

  static Future<void> setAccessTokenUID(String accessTokenUID) async {
    _accessTokenUID = accessTokenUID;
    await _updateFile({'accessTokenUID': accessTokenUID});
  }

  static Future<void> setDeviceUID(String deviceUID) async {
    _deviceUID = deviceUID;
    await _updateFile({'deviceUID': deviceUID});
  }

  static Future<void> _updateFile(Map<String, dynamic> newData) async {
    final file = File(await _filePath);
    Map<String, dynamic> existingData = {};

    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        existingData = jsonDecode(content);
      } catch (e) {
        // File corrupted or empty, start fresh
      }
    }

    existingData.addAll(newData);
    await file.writeAsString(jsonEncode(existingData));
  }

  static Future<String?> getEmail() async {
    if (_email != null) return _email;

    try {
      final file = File(await _filePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content);
        _email = data['email'];
        return _email;
      }
    } catch (e) {
      // File doesn't exist or error reading
    }
    return null;
  }

  static Future<String?> getDeviceUID() async {
    if (_deviceUID != null) return _deviceUID;

    try {
      final file = File(await _filePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content);
        _deviceUID = data['deviceUID'];
        return _deviceUID;
      }
    } catch (e) {
      // File doesn't exist or error reading
    }
    return null;
  }

  static Future<String?> getAccesTokenUID() async {
    if (_accessTokenUID != null) return _accessTokenUID;

    try {
      final file = File(await _filePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content);
        _accessTokenUID = data['accessTokenUID'];
        return _accessTokenUID;
      }
    } catch (e) {
      // File doesn't exist or error reading
    }
    return null;
  }

  static Future<bool?> getDeviceStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_deviceStatusKey);
  }

  static Future<bool> getBatteryOptAsked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_batteryOptAskedKey) ?? false;
  }

  static Future<void> setBatteryOptAsked(bool asked) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_batteryOptAskedKey, asked);
  }

  static Future<void> setDevUnlocked(bool unlocked) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_devUnlockedKey, unlocked);
  }

  static Future<bool> getDevUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_devUnlockedKey) ?? false;
  }

  static Future<void> setNotificationEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_notificationEmailKey, email);
  }

  static Future<String?> getNotificationEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_notificationEmailKey);
  }

  static Future<void> setBackgroundRun(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_backgroundRunKey, value);
  }

  static Future<bool> getBackgroundRun() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_backgroundRunKey) ?? true;
  }

  static Future<bool> isLoggedIn() async {
    final email = await getEmail();
    final tokenId = await getAccesTokenUID();
    return email != null && tokenId != null;
  }

  static Future<void> setLastInstalledRelease(String tag) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastInstalledReleaseKey, tag);
  }

  static Future<String?> getLastInstalledRelease() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastInstalledReleaseKey);
  }

  static Future<void> clearAppData() async {
    _email = null;
    _accessTokenUID = null;
    _deviceUID = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deviceStatusKey);

    try {
      final file = File(await _filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // File doesn't exist
    }
  }
}
