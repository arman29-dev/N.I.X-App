import 'dart:io';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';

Future<http.Response> registerDevice(
  String deviceUID,
  String ownerUID, {
  required String jwt,
  required String accessTokenUid,
}) async {
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  String name;
  String type;

  if (Platform.isAndroid) {
    final androidInfo = await deviceInfo.androidInfo;
    name = androidInfo.model;
    type = 'smartphone';
  } else if (Platform.isMacOS) {
    final macInfo = await deviceInfo.macOsInfo;
    name = macInfo.computerName;
    type = 'laptop';
  } else {
    final info = await deviceInfo.deviceInfo;
    name = (info.data['model'] as String? ??
        info.data['name'] as String? ??
        'Device');
    type = 'unknown';
  }

  String ipv4 = '0.0.0.0';
  try {
    final interfaces = await NetworkInterface.list();
    if (Platform.isAndroid) {
      final wifi = interfaces.where((i) => i.name == 'wlan0');
      if (wifi.isNotEmpty) {
        ipv4 = wifi.first.addresses.first.address;
      }
    }
    if (ipv4 == '0.0.0.0') {
      final iface = interfaces.firstWhere(
        (i) => i.addresses.any(
          (a) => a.type == InternetAddressType.IPv4 && !a.isLoopback,
        ),
        orElse: () => interfaces.first,
      );
      ipv4 = iface.addresses.firstWhere(
        (a) => a.type == InternetAddressType.IPv4 && !a.isLoopback,
        orElse: () => iface.addresses.first,
      ).address;
    }
  } catch (_) {
    // Fallback to 0.0.0.0
  }

  return http.post(
    Uri.parse(
      'https://quiet-pup-summary.ngrok-free.app/api/v1/device/manage/add-device',
    ),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $jwt',
    },
    body: jsonEncode(<String, String?>{
      'uid': deviceUID,
      'name': name,
      'type': type,
      'ip': ipv4,
      'owner': ownerUID,
      'token_ID': accessTokenUid,
    }),
  );
}
