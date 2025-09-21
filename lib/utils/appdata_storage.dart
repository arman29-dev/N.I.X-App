import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class AppDataStorage {
  static String? _email;
  static bool? _status;

  static Future<String> get _filePath async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/login_data.json';
  }

  static Future<void> setEmail(String email) async {
    _email = email;
    await _updateFile({'email': email});
  }

  static Future<void> setDeviceStatus(bool status) async {
    _status = status;
    await _updateFile({'status': status});
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

  static Future<bool?> getDeviceStatus() async {
    if (_status != null) return _status;

    try {
      final file = File(await _filePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content);
        _status = data['status'];
        return _status;
      }
    } catch (e) {
      // File doesn't exist or error reading
    }
    return null;
  }

  static Future<bool> isLoggedIn() async {
    final email = await getEmail();
    return email != null;
  }

  static Future<void> clearLoginData() async {
    _email = null;
    _status = null;
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
