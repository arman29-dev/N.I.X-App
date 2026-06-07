import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nix/api/register_device.dart';
import 'package:nix/services/device_ws.dart';
import 'package:nix/utils/appdata_storage.dart';
import 'package:nix/utils/token_storage.dart';

import '../utils/app_colors.dart';
import '../utils/responsive.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool isProcessing = false;

  Future<void> _processQRData(String qrData) async {
    if (isProcessing) return;

    setState(() {
      isProcessing = true;
    });

    try {
      final qrJson = jsonDecode(qrData);
      final deviceUid = qrJson['device_uid'] as String?;
      final userAccessToken = qrJson['user_access_token'] as String?;
      final accessTokenUid = qrJson['access_token_uid'] as String?;
      final ownerUid = qrJson['owner_uid'] as String?;

      if (deviceUid == null || userAccessToken == null || accessTokenUid == null || ownerUid == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid QR Code: Missing required data')),
        );
        return;
      }

      final response = await registerDevice(
        deviceUid,
        ownerUid,
        jwt: userAccessToken,
        accessTokenUid: accessTokenUid,
      );

      if (response.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error: ${response.statusCode}')),
        );
        return;
      }

      final responseData = jsonDecode(response.body);
      final stats = responseData['stats'];
      final msg = responseData['message'] ?? responseData['msg'];
      final deviceStatus = responseData['device_status'];

      if (stats != 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      } else {
        await TokenStorage.setToken(userAccessToken, 'Bearer', accessTokenUid);
        await AppDataStorage.setAccessTokenUID(accessTokenUid);
        await AppDataStorage.setDeviceStatus(deviceStatus ?? true);
        await AppDataStorage.setDeviceUID(deviceUid);

        DeviceWS().connect();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
        Navigator.pushReplacementNamed(context, '/home');
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

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final scanAreaSize = Responsive.isMobile(context) 
        ? screenSize.width * 0.7 
        : screenSize.width * 0.4;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Device Registration',
          style: TextStyle(fontSize: Responsive.sp(context, 18)),
        ),
        backgroundColor: AppColors.cardBackground,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
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
          CustomPaint(
            painter: ScannerOverlayPainter(scanAreaSize),
            child: Container(),
          ),
          Center(
            child: SizedBox(
              width: scanAreaSize,
              height: scanAreaSize,
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      width: Responsive.width(context) * 0.1,
                      height: Responsive.width(context) * 0.1,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.white, width: 4),
                          left: BorderSide(color: Colors.white, width: 4),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: Responsive.width(context) * 0.1,
                      height: Responsive.width(context) * 0.1,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.white, width: 4),
                          right: BorderSide(color: Colors.white, width: 4),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Container(
                      width: Responsive.width(context) * 0.1,
                      height: Responsive.width(context) * 0.1,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.white, width: 4),
                          left: BorderSide(color: Colors.white, width: 4),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: Responsive.width(context) * 0.1,
                      height: Responsive.width(context) * 0.1,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.white, width: 4),
                          right: BorderSide(color: Colors.white, width: 4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: Responsive.height(context) * 0.12,
            left: 0,
            right: 0,
            child: Container(
              padding: Responsive.padding(context, horizontal: 20, vertical: 0),
              child: Column(
                children: [
                  if (isProcessing)
                    const CircularProgressIndicator(color: AppColors.accent)
                  else
                    Text(
                      'Scan QR code',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: Responsive.sp(context, 18),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  SizedBox(height: Responsive.height(context) * 0.015),
                  Text(
                    'Position the QR code within the frame to scan',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: Responsive.sp(context, 14),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
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

class ScannerOverlayPainter extends CustomPainter {
  final double scanAreaSize;

  ScannerOverlayPainter(this.scanAreaSize);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final scanRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: scanAreaSize,
      height: scanAreaSize,
    );

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(scanRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}