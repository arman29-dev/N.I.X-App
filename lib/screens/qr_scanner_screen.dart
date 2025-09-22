import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:nix/api/register_device.dart';
import 'package:nix/utils/appdata_storage.dart';
import '../utils/app_colors.dart';
import '../utils/token_storage.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool isProcessing = false;

  Map<String, dynamic>? _decodeJWT(String token, String secret) {
    try {
      final jwt = JWT.verify(token, SecretKey(secret));
      return jwt.payload;
    } catch (e) {
      print('JWT decode error: $e');
      return null;
    }
  }

  Future<void> _processQRData(String qrData) async {
    if (isProcessing) return;

    setState(() {
      isProcessing = true;
    });

    try {
      final qrJson = jsonDecode(qrData);
      final deviceUid = qrJson['device_uid'];
      final secret = qrJson['secret'];
      final userAccessToken = qrJson['user_access_token'];

      final storedToken = TokenStorage.getAccessToken();

      if (storedToken == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No stored token found')));
        return;
      }

      // Decode both JWT tokens using the secret
      final storedTokenData = _decodeJWT(storedToken, secret);
      final qrTokenData = _decodeJWT(userAccessToken, secret);

      if (storedTokenData == null || qrTokenData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to decode JWT tokens')),
        );
        return;
      }

      // Debug logging
      print('Stored token data: $storedTokenData');
      print('QR token data: $qrTokenData');

      // Compare decoded token data
      if (_compareTokenData(storedTokenData, qrTokenData)) {
        final response = await registerDevice(deviceUid, qrTokenData['uid']);
        final responseData = jsonDecode(response.body);

        final stats = responseData['stats'];
        final msg = responseData['message'];
        final deviceStatus = responseData['device_status'];

        if (stats != 200) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        } else {
          AppDataStorage.setDeviceStatus(deviceStatus);
          AppDataStorage.setDeviceUID(deviceUid);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Token does not match')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invalid QR Code format: $e')));
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  bool _compareTokenData(Map<String, dynamic> stored, Map<String, dynamic> qr) {
    // Compare relevant fields from decoded JWT data
    return stored['sub'] == qr['sub'] && // subject (email)
        stored['uid'] == qr['uid'] && // user ID
        stored['exp'] == qr['exp']; // expiration
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Device Registration'),
        backgroundColor: AppColors.cardBackground,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: MobileScanner(
              controller: cameraController,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                    _processQRData(barcode.rawValue!);
                    break;
                  }
                }
              },
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              color: AppColors.cardBackground,
              child: Center(
                child: isProcessing
                    ? const CircularProgressIndicator(color: AppColors.accent)
                    : const Text(
                        'Point camera at QR code',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}
