import 'package:http/http.dart' as http;
import 'package:nix/utils/token_storage.dart';
import 'package:nix/utils/appdata_storage.dart';

Future<bool> getServerStatus() async {
  final response = await http.get(
    Uri.parse('https://quiet-pup-summary.ngrok-free.app/ping'),
  );

  return response.statusCode == 200;
}

Future<http.Response> toggleDeviceStatus() async {
  final token = await TokenStorage.getAccessToken();
  final deviceId = await AppDataStorage.getDeviceUID();

  return http.get(
    Uri.parse('https://quiet-pup-summary.ngrok-free.app/api/v1/device/manage/toggle-status?uid=$deviceId'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    },
  );
}
