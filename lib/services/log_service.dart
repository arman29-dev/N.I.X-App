import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../utils/token_storage.dart';
import '../utils/app_constants.dart';

class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  final StreamController<Map<String, dynamic>> _logController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get logStream => _logController.stream;

  void addLog(Map<String, dynamic> entry) {
    _logController.add(entry);
  }

  void addDeviceLog(String message,
      {String level = 'INFO', String? source}) {
    _logController.add({
      'timestamp': DateTime.now().toIso8601String(),
      'level': level,
      'message': message,
      'source': source ?? 'device',
    });
  }

  Future<List<Map<String, dynamic>>> fetchServerLogs(
    String logType, {
    int lines = 100,
  }) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) return [];

    final uri = Uri.parse(
        '${AppConstants.serverUrl}/api/v1/logs/$logType?lines=$lines');

    try {
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return (body['data'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
      }
    } catch (e) {
      addDeviceLog('Failed to fetch logs: $e', level: 'ERROR');
    }

    return [];
  }

  void dispose() {
    _logController.close();
  }
}
