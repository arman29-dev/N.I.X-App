import 'dart:convert';
import 'package:http/http.dart' as http;

import '../utils/app_constants.dart';
import '../utils/token_storage.dart';

Future<bool> updateNotificationEmail(String email) async {
  final token = await TokenStorage.getAccessToken();
  if (token == null) return false;

  try {
    final response = await http.put(
      Uri.parse('${AppConstants.serverUrl}/api/v1/user/preferences/notification-email'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(<String, String>{
        'notification_email': email,
      }),
    );
    return response.statusCode == 200;
  } catch (_) {
    return false;
  }
}
