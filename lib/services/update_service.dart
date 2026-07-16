import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

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

  final StreamController<Map<String, dynamic>> _updateFoundController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onUpdateAvailable =>
      _updateFoundController.stream;

  Timer? _autoCheckTimer;

  void startAutoCheck(String currentVersion) {
    _runCheck(currentVersion);
    _autoCheckTimer = Timer.periodic(
      const Duration(hours: 24),
      (_) => _runCheck(currentVersion),
    );
  }

  void stopAutoCheck() {
    _autoCheckTimer?.cancel();
    _autoCheckTimer = null;
  }

  Future<void> _runCheck(String currentVersion) async {
    final release = await checkForUpdate();
    if (release != null) {
      final latestTag = release['tag_name'] as String? ?? '';
      if (_isNewerVersion(latestTag, currentVersion)) {
        _updateFoundController.add(release);
      }
    }
  }

  bool _isNewerVersion(String latest, String current) {
    final a = latest.replaceFirst(RegExp(r'^v'), '');
    final b = current.replaceFirst(RegExp(r'^v'), '');
    if (a.isEmpty || b.isEmpty) return false;
    final partsA = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final partsB = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (int i = 0; i < partsA.length && i < partsB.length; i++) {
      if (partsA[i] > partsB[i]) return true;
      if (partsA[i] < partsB[i]) return false;
    }
    return partsA.length > partsB.length;
  }

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

  Future<bool> downloadAndInstall(Map<String, dynamic> releaseData) async {
    if (_isDownloading) return false;
    if (!Platform.isAndroid) {
      debugPrint('UpdateService: APK download not supported on this platform');
      return false;
    }
    _isDownloading = true;
    _downloadProgress = 0;

    try {
      final tagName = releaseData['tag_name'] as String? ?? 'latest';
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
        return false;
      }

      final request = http.Request('GET', Uri.parse(apkUrl));
      request.headers['Accept'] = 'application/octet-stream';
      final apkResponse = await http.Client().send(request);

      if (apkResponse.statusCode != 200) {
        debugPrint('UpdateService: download failed with status ${apkResponse.statusCode}');
        _isDownloading = false;
        return false;
      }

      final extDir = await getExternalStorageDirectory();
      if (extDir == null) {
        debugPrint('UpdateService: external storage not available');
        _isDownloading = false;
        return false;
      }

      final downloadDir = Directory('${extDir.path}/Download');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final file = File('${downloadDir.path}/nix-$tagName.apk');
      if (await file.exists()) {
        await file.delete();
      }

      final sink = file.openWrite();
      int total = apkResponse.contentLength ?? 0;
      int received = 0;

      if (total > 0) {
        await for (final chunk in apkResponse.stream) {
          sink.add(chunk);
          received += chunk.length;
          _downloadProgress = received / total;
          _progressController.add(_downloadProgress);
        }
      } else {
        final bytes = await apkResponse.stream.toBytes();
        total = bytes.length;
        received = 0;
        const chunkSize = 8192;
        for (int offset = 0; offset < total; offset += chunkSize) {
          final end = (offset + chunkSize > total) ? total : offset + chunkSize;
          sink.add(bytes.sublist(offset, end));
          received = end;
          _downloadProgress = received / total;
          _progressController.add(_downloadProgress);
        }
      }

      await sink.flush();
      await sink.close();

      final raf = await file.open(mode: FileMode.read);
      final header = await raf.read(4);
      await raf.close();
      if (header.length < 4 || header[0] != 0x50 || header[1] != 0x4b) {
        debugPrint('UpdateService: invalid APK (missing PK header)');
        await file.delete();
        _isDownloading = false;
        return false;
      }

      _downloadedPath = file.path;
      _downloadProgress = 1.0;
      _progressController.add(1.0);

      debugPrint('UpdateService: APK downloaded to $file');

      _isDownloading = false;
      return true;
    } catch (e) {
      debugPrint('UpdateService: download failed: $e');
      _downloadProgress = 0;
      _progressController.add(0);
      _isDownloading = false;
      return false;
    }
  }

  void dispose() {
    _autoCheckTimer?.cancel();
    _progressController.close();
    _updateFoundController.close();
  }
}
