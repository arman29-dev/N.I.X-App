import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dart_ipify/dart_ipify.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../utils/token_storage.dart';

Future<http.Response> registerDevice(String deviceUID, String ownerUID) async {
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
  final ipv4 = await Ipify.ipv4();
  final token =  TokenStorage.getAccessToken();

  return http.post(
    Uri.parse(
      'https://quiet-pup-summary.ngrok-free.app/api/v1/device/manage/add-device',
    ),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    },
    body: jsonEncode(<String, String>{
      'uid': deviceUID,
      'name': androidInfo.model,
      'type': 'smartphone',
      'ip': ipv4,
      'owner': ownerUID,
    }),
  );
}
