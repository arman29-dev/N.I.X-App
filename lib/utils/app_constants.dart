class AppConstants {
  static const String serverUrl = 'https://quiet-pup-summary.ngrok-free.app';

  static String get wsUrl => serverUrl
      .replaceFirst('https://', 'wss://')
      .replaceFirst('http://', 'ws://');

  static const String githubRepo = 'arman29-dev/N.I.X-App';

  static const String devPassword = 'nix#26';

  static const int deviceLogMaxLines = 1000;

  static const String notificationChannelId = 'nix_background_channel';
  static const String notificationChannelName = 'N.I.X Background Service';
}
