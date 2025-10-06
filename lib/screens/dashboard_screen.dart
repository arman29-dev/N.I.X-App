import 'dart:async';
import 'package:flutter/material.dart';

import '../widgets/custom_button.dart';

import '../utils/token_storage.dart';
import '../utils/appdata_storage.dart';
import '../utils/app_colors.dart';
import '../utils/responsive.dart';

import '../api/check_server_status.dart';
import '../api/logout_device.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String serverStatus = 'Offline';
  String deviceStatus = 'Offline';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _updateStatuses();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateStatuses();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _updateServerStatus() async {
    try {
      final result = await getServerStatus();
      setState(() {
        serverStatus = (result == true) ? 'Online' : 'Offline';
      });
    } catch (_) {
      setState(() {
        serverStatus = 'Error';
      });
    }
  }

  Future<void> _updateStatuses() async {
    final status = await AppDataStorage.getDeviceStatus();
    setState(() {
      deviceStatus = (status ?? true) ? 'Online' : 'Offline';
    });

    // Save the status if it was null (first time)
    if (status == null) {
      await AppDataStorage.setDeviceStatus(true);
    }

    await _updateServerStatus();
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
                            color: serverStatus == 'Online'? Colors.green : Colors.redAccent,
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
                            color: deviceStatus == 'Online'? Colors.green : Colors.redAccent,
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
                          onPressed: () => _changeStatus(deviceStatus),
                          text: deviceStatus == 'Online'? 'Go Offline' : 'Go Online',
                          backgroundColor: deviceStatus == 'Online'? Colors.red : Colors.lightGreen,
                          icon: deviceStatus == 'Online'? Icons.offline_bolt : Icons.online_prediction,
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

  void _refreshConnection() {
    _updateStatuses();
  }

  void _changeStatus(String currentState) {
    _updateStatuses();
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
    bool stats = await logout();
    if (!mounted) return;

    if (stats) {
      await AppDataStorage.clearAppData();
      await TokenStorage.clearToken();
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: AppColors.cardBackground,
        builder: (context) => AlertDialog(
          title: const Text('Logout Error'),
          content: const Text('You were unable to logout. Most probably a server issue.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Stay Logged-In', style: TextStyle(color: Colors.green)),
            ),
          ],
        ),
      );
    }
  }
}
