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
  static const String updateNotificationChannelId = 'nix_update_channel';
  static const String updateNotificationChannelName = 'N.I.X Updates';
  static const String fileNotificationChannelId = 'nix_file_channel';
  static const String fileNotificationChannelName = 'N.I.X File Transfers';

  // AES-256-GCM decryption key (must match server SECRET_KEY)
  // Used to decrypt .nixconfig desktop registration files.
  // Change this if you change SECRET_KEY in the server's .env!
  static const String secretKey = 'OAvsMXBzWGhBAY_3ByzT8ocXYe8a0Y2OHqt4dwmlgqg';
}
