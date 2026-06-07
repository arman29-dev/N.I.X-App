import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/update_service.dart';

void startAutoUpdateCheck() {
  try {
    PackageInfo.fromPlatform().then((info) {
      UpdateService().startAutoCheck(info.version);

      final currentVersion = info.version;
      UpdateService().onUpdateAvailable.listen((release) {
        final latestTag = release['tag_name'] as String? ?? '';
        _showUpdateNotification(
          'New Update available',
          '$currentVersion -> $latestTag',
        );
      });
    });
  } catch (e) {
    debugPrint('Auto-check init failed: $e');
  }
}

void _showUpdateNotification(String title, String body) {
  try {
    const channel = MethodChannel('nix/notifications');
    channel.invokeMethod('showUpdateNotification', {
      'title': title,
      'body': body,
    });
  } catch (e) {
    debugPrint('Show notification failed: $e');
  }
}
