import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../utils/app_constants.dart';
import '../utils/token_storage.dart';

Future<String?> uploadFile(String filePath, String fileName, {String? targetDevice}) async {
  final token = await TokenStorage.getAccessToken();
  if (token == null) return null;

  final uri = Uri.parse('${AppConstants.serverUrl}/api/v1/comms/upload');
  final request = http.MultipartRequest('POST', uri)
    ..headers['Authorization'] = 'Bearer $token'
    ..files.add(await http.MultipartFile.fromPath('file', filePath, filename: fileName));
  if (targetDevice != null) {
    request.fields['target_device'] = targetDevice;
  }

  try {
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      return body?['file_id'] as String?;
    }
    return null;
  } catch (e) {
    return null;
  }
}

Future<bool> downloadFile(String fileId, String savePath) async {
  final token = await TokenStorage.getAccessToken();
  if (token == null) return false;

  final uri = Uri.parse('${AppConstants.serverUrl}/api/v1/comms/download/$fileId');
  try {
    final response = await http.get(uri, headers: {
      'Authorization': 'Bearer $token',
    });
    if (response.statusCode == 200) {
      final file = File(savePath);
      await file.writeAsBytes(response.bodyBytes);
      return true;
    }
    return false;
  } catch (e) {
    return false;
  }
}

Stream<double> downloadFileWithProgress(String fileId, String savePath) async* {
  final token = await TokenStorage.getAccessToken();
  if (token == null) {
    yield -1;
    return;
  }

  final uri = Uri.parse('${AppConstants.serverUrl}/api/v1/comms/download/$fileId');
  try {
    final request = http.Request('GET', uri);
    request.headers['Authorization'] = 'Bearer $token';
    final streamed = await http.Client().send(request);

    if (streamed.statusCode != 200) {
      yield -1;
      return;
    }

    final file = File(savePath);
    final sink = file.openWrite();
    final total = streamed.contentLength ?? 0;
    var received = 0;

    if (total > 0) {
      await for (final chunk in streamed.stream) {
        sink.add(chunk);
        received += chunk.length;
        yield received / total;
      }
    } else {
      final bytes = await streamed.stream.toBytes();
      sink.add(bytes);
      received = bytes.length;
      yield 1.0;
    }

    await sink.flush();
    await sink.close();
    yield 1.0;
  } catch (e) {
    yield -1;
  }
}
