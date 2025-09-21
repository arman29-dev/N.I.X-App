import 'package:http/http.dart' as http;

Future<bool> getServerStatus () async {
  final response = await http.get(
    Uri.parse('https://quiet-pup-summary.ngrok-free.app/server-status'),
  );

  return response.statusCode == 200;
}
