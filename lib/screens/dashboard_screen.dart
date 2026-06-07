import 'dart:async';
import 'package:flutter/material.dart';

import '../widgets/custom_button.dart';

import '../utils/token_storage.dart';
import '../utils/appdata_storage.dart';
import '../utils/app_colors.dart';
import '../utils/responsive.dart';

import '../services/device_ws.dart';
import '../api/logout_device.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String serverStatus = 'Offline';
  String deviceStatus = 'Offline';
  StreamSubscription<Map<String, dynamic>>? _wsSub;

  @override
  void initState() {
    super.initState();
    _updateDeviceStatus();
    _connectWS();
  }

  void _connectWS() {
    if (!DeviceWS().isConnected) {
      DeviceWS().connect();
    }
    _wsSub = DeviceWS().messages.listen(_handleWSMessage);
    Future.delayed(const Duration(seconds: 2), () {
      if (DeviceWS().isConnected) {
        DeviceWS().sendCommand('refresh');
        setState(() => serverStatus = 'Online');
      } else {
        setState(() => serverStatus = 'Connecting...');
      }
    });
  }

  void _handleWSMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;

    if (type == 'command') {
      if (msg['action'] == 'logout') {
        _forceLogout();
        return;
      }
    }

    if (type == 'response') {
      final action = msg['action'] as String?;
      final data = msg['data'] as Map<String, dynamic>?;

      if (action == 'toggle_status' && data != null) {
        final isOnline = data['device_status'] as bool?;
        if (isOnline != null) {
          AppDataStorage.setDeviceStatus(isOnline);
          setState(() {
            deviceStatus = isOnline ? 'Online' : 'Offline';
            serverStatus = 'Online';
          });
        }
      } else if (action == 'refresh' && data != null) {
        final device = data['device'] as Map<String, dynamic>?;
        if (device != null) {
          final isOnline = device['is_active'] as bool? ?? true;
          AppDataStorage.setDeviceStatus(isOnline);
          setState(() {
            deviceStatus = isOnline ? 'Online' : 'Offline';
            serverStatus = 'Online';
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  Future<void> _updateDeviceStatus() async {
    final status = await AppDataStorage.getDeviceStatus();
    setState(() {
      deviceStatus = (status ?? true) ? 'Online' : 'Offline';
    });

    if (status == null) {
      await AppDataStorage.setDeviceStatus(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Control Center',
          style: TextStyle(fontSize: Responsive.sp(context, 18)),
        ),
        backgroundColor: AppColors.accent,
      ),
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: Responsive.padding(context, horizontal: 40, vertical: 20),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: Responsive.isDesktop(context) ? 500 : double.infinity,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      text: 'Server Status: ',
                      style: TextStyle(fontSize: Responsive.sp(context, 24)),
                      children: [
                        TextSpan(
                          text: serverStatus,
                          style: TextStyle(
                            fontSize: Responsive.sp(context, 24),
                            color: serverStatus == 'Online'
                                ? Colors.green
                                : Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: Responsive.height(context) * 0.02),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      text: 'Device Status: ',
                      style: TextStyle(fontSize: Responsive.sp(context, 24)),
                      children: [
                        TextSpan(
                          text: deviceStatus,
                          style: TextStyle(
                            fontSize: Responsive.sp(context, 24),
                            color: deviceStatus == 'Online'
                                ? Colors.green
                                : Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: Responsive.height(context) * 0.1),
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          onPressed: () => _refreshConnection(),
                          text: 'Refresh',
                          backgroundColor: Colors.cyan,
                          icon: Icons.refresh,
                        ),
                      ),
                      SizedBox(width: Responsive.width(context) * 0.04),
                      Expanded(
                        child: CustomButton(
                          onPressed: () => _changeDeviceStatus(),
                          text: deviceStatus == 'Online'
                              ? 'Go Offline'
                              : 'Go Online',
                          backgroundColor: deviceStatus == 'Online'
                              ? Colors.red
                              : Colors.lightGreen,
                          icon: deviceStatus == 'Online'
                              ? Icons.offline_bolt
                              : Icons.online_prediction,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: Responsive.height(context) * 0.03),
                  CustomOutlinedButton(
                    onPressed: () => _showLogoutConfirmation(context),
                    text: 'Logout',
                    borderColor: Colors.redAccent,
                    icon: Icons.logout,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _refreshConnection() async {
    if (!DeviceWS().isConnected) {
      setState(() => serverStatus = 'Connecting...');
      await DeviceWS().connect();
      await Future.delayed(const Duration(seconds: 2));
    }
    if (DeviceWS().isConnected) {
      DeviceWS().sendCommand('refresh');
    }
  }

  void _changeDeviceStatus() {
    DeviceWS().sendCommand('toggle_status');
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.cardBackground,
      builder: (context) => AlertDialog(
        title: const Text('Confirm'),
        content: const Text('Are you sure you want to logout this device?'),
        actions: [
          CustomOutlinedButton(
            onPressed: () => Navigator.pop(context),
            text: 'Cancel',
            borderColor: Colors.cyan,
          ),
          SizedBox(height: 5),
          CustomButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            backgroundColor: Colors.redAccent,
            text: 'Logout',
          ),
        ],
      ),
    );
  }

  void _logout() async {
    try {
      await logout(); // best-effort server cleanup
    } catch (_) {
      // Server cleanup is best-effort; continue with local logout
    }
    await _forceLogout();
  }

  Future<void> _forceLogout() async {
    await DeviceWS().disconnect();
    await AppDataStorage.clearAppData();
    await TokenStorage.clearToken();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/qr-scanner');
    }
  }
}
