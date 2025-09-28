import 'package:url_launcher/url_launcher.dart';

// The URL to be opened.
final Uri registrationUri = Uri.parse('https://quiet-pup-summary.ngrok-free.app/web/home');

// Asynchronous function to launch the URL.
// It checks if the URL can be launched before attempting to do so.
Future<void> launchUrlInBrowser() async {
  if (!await launchUrl(registrationUri)) {
    throw Exception('Could not launch $registrationUri');
  }
}
