import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/appdata_storage.dart';

Future<http.Response> loginUser(String email, String password, String otp) async {
  final response = await http.post(
    Uri.parse('https://quiet-pup-summary.ngrok-free.app/api/v1/user/auth/login'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, String>{
      'email': email,
      'password': password,
      'twoFA': otp
    }),
  );

  if (response.statusCode == 200) {
    await AppDataStorage.setEmail(email);
  }

  return response;
}
