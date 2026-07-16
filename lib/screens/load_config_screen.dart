import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/config_decryptor.dart';
import '../utils/app_constants.dart';
import '../utils/app_colors.dart';
import '../utils/appdata_storage.dart';
import '../utils/token_storage.dart';
import '../services/device_ws.dart';
import '../api/register_device.dart';

class LoadConfigScreen extends StatefulWidget {
  const LoadConfigScreen({super.key});

  @override
  State<LoadConfigScreen> createState() => _LoadConfigScreenState();
}

class _LoadConfigScreenState extends State<LoadConfigScreen> {
  bool _loading = false;
  String? _status;
  double _progress = 0;

  Future<void> _pickAndDecrypt() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['nixconfig'],
    );

    if (result == null || result.files.isEmpty || result.files.single.path == null) return;

    setState(() {
      _loading = true;
      _progress = 0.1;
      _status = 'Decrypting config file...';
    });

    try {
      final file = File(result.files.single.path!);
      final contents = await file.readAsString();

      setState(() => _progress = 0.3);

      final config = decryptConfigFile(
        contents,
        AppConstants.secretKey,
      );

      if (config == null) {
        setState(() {
          _status = 'Failed to decrypt config file. Invalid or corrupted.';
          _loading = false;
          _progress = 0;
        });
        return;
      }

      setState(() {
        _progress = 0.5;
        _status = 'Registering device...';
      });

      final registerResponse = await registerDevice(
        config['device_uid']!,
        config['owner_uid']!,
        jwt: config['user_access_token']!,
        accessTokenUid: config['access_token_uid']!,
      );

      setState(() => _progress = 0.8);

      if (registerResponse.statusCode == 200 || registerResponse.statusCode == 201) {
        TokenStorage.setToken(
          config['user_access_token']!,
          'bearer',
          config['access_token_uid']!,
        );
        AppDataStorage.setEmail('');
        AppDataStorage.setAccessTokenUID(config['access_token_uid']!);
        AppDataStorage.setDeviceUID(config['device_uid']!);
        AppDataStorage.setDeviceStatus(true);

        setState(() {
          _status = 'Connecting...';
          _progress = 0.95;
        });

        DeviceWS().connect();

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        final body = jsonDecode(registerResponse.body) as Map<String, dynamic>;
        setState(() {
          _status = 'Registration failed: ${body['message'] ?? body['error'] ?? registerResponse.statusCode}';
          _loading = false;
          _progress = 0;
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _loading = false;
        _progress = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Load Config',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF0D1016),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.download_for_offline,
                  size: 44,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Desktop Registration',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Select the .nixconfig file downloaded\nfrom your N.I.X web dashboard.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 36),
              if (_loading) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _status ?? '',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (_status != null && !_loading)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(
                    _status!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _status!.startsWith('Error') || _status!.startsWith('Failed')
                          ? Colors.redAccent
                          : Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _pickAndDecrypt,
                  icon: Icon(
                    Icons.folder_open,
                    size: 20,
                    color: _loading ? Colors.white38 : Colors.white,
                  ),
                  label: Text(
                    _loading ? 'Processing...' : 'Load Config File',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _loading ? Colors.white38 : Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent.withValues(alpha: _loading ? 0.3 : 0.9),
                    disabledBackgroundColor: const Color(0xFF2A2D3A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
