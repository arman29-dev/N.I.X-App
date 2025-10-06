import 'dart:io';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:nix/utils/appdata_storage.dart';

import '../utils/token_storage.dart';

Future<http.Response> registerDevice(String deviceUID, String ownerUID) async {
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
  final interfaces = await NetworkInterface.list();
  final ipv4 = interfaces.firstWhere((i) => i.name == 'wlan0').addresses.first.address;
  final token = await TokenStorage.getAccessToken();
  final tokenID = await AppDataStorage.getAccesTokenUID();

  if (tokenID == null) {
    return http.Response('{"msg": "Please login first to get access token"}', 400);
  }

  return http.post(
    Uri.parse(
      'https://quiet-pup-summary.ngrok-free.app/api/v1/device/manage/add-device',
    ),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode(<String, String?>{
      'uid': deviceUID,
      'name': androidInfo.model,
      'type': 'smartphone',
      'ip': ipv4,
      'owner': ownerUID,
      'token_ID': tokenID,
    }),
  );
}
