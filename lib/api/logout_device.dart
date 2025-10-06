import 'dart:convert';
import 'package:http/http.dart' as http;

import '../utils/appdata_storage.dart';
import '../utils/token_storage.dart';

Future<bool> logout() async {
  final accessTokenUID = await AppDataStorage.getAccesTokenUID();
  final deviceUID = await AppDataStorage.getDeviceUID();

  final token = await TokenStorage.getAccessToken();

  final response = await http.post(
    Uri.parse(
      'https://quiet-pup-summary.ngrok-free.app/api/v1/device/manage/logout',
    ),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode(<String, String?>{
      'device_uid': deviceUID,
      'access_token_uid': accessTokenUID,
    }),
  );

  if (response.statusCode == 200) {
    return true;
  } else {
    return false;
  }
}
