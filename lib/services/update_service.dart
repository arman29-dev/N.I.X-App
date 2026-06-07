import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';

import '../utils/app_constants.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  bool _isDownloading = false;
  double _downloadProgress = 0;
  String? _downloadedPath;

  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  String? get downloadedPath => _downloadedPath;

  final StreamController<double> _progressController =
      StreamController<double>.broadcast();
  Stream<double> get progressStream => _progressController.stream;

  Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      final uri = Uri.parse(
        'https://api.github.com/repos/${AppConstants.githubRepo}/releases/latest',
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'tag_name': data['tag_name'] as String?,
          'body': data['body'] as String?,
          'html_url': data['html_url'] as String?,
          'assets': data['assets'] as List<dynamic>?,
        };
      } else if (response.statusCode == 403 || response.statusCode == 429) {
        debugPrint('UpdateService: rate limited or forbidden');
      }
    } catch (e) {
      debugPrint('UpdateService: check failed: $e');
    }
    return null;
  }

  Future<void> downloadAndInstall(Map<String, dynamic> releaseData) async {
    if (_isDownloading) return;
    _isDownloading = true;
    _downloadProgress = 0;

    try {
      final assets = releaseData['assets'] as List<dynamic>? ?? [];
      String? apkUrl;
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String?;
          break;
        }
      }

      if (apkUrl == null) {
        debugPrint('UpdateService: no APK asset found');
        _isDownloading = false;
        return;
      }

      final apkResponse = await http.Client().send(
        http.Request('GET', Uri.parse(apkUrl)),
      );

      if (apkResponse.statusCode != 200) {
        debugPrint('UpdateService: download failed with status ${apkResponse.statusCode}');
        _isDownloading = false;
        return;
      }

      final dir = Directory.systemTemp;
      final file = File('${dir.path}/nix_update.apk');
      final sink = file.openWrite();
      final total = apkResponse.contentLength ?? 0;
      int received = 0;

      await for (final chunk in apkResponse.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          _downloadProgress = received / total;
          _progressController.add(_downloadProgress);
        }
      }

      await sink.flush();
      await sink.close();
      _downloadedPath = file.path;
      _downloadProgress = 1.0;
      _progressController.add(1.0);

      debugPrint('UpdateService: APK downloaded to $file');

      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        debugPrint('UpdateService: open file returned ${result.type} — ${result.message}');
      }
    } catch (e) {
      debugPrint('UpdateService: download failed: $e');
    } finally {
      _isDownloading = false;
    }
  }

  void dispose() {
    _progressController.close();
  }
}
