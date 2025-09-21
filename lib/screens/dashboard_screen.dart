import 'package:flutter/material.dart';
import 'dart:async';

import '../widgets/custom_button.dart';
import '../utils/token_storage.dart';
import '../utils/appdata_storage.dart';
import '../utils/app_colors.dart';
import '../api/check_server_status.dart';

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
      _updateServerStatus();
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
        serverStatus = 'Error Getting Server Status';
      });
    }
  }

  Future<void> _updateStatuses() async {
    final status = await AppDataStorage.getDeviceStatus();
    setState(() {
      deviceStatus = (status == true) ? 'Online' : 'Offline';
    });

    await _updateServerStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Control Center'),
        backgroundColor: AppColors.accent,
      ),
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RichText(
                text: TextSpan(
                  text: 'Server Status: ',
                  style: const TextStyle(fontSize: 30),
                  children: [
                    TextSpan(
                      text: serverStatus,
                      style: TextStyle(
                        fontSize: 30,
                        color: serverStatus == 'Online'? Colors.green : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              RichText(
                text: TextSpan(
                  text: 'Device Status: ',
                  style: const TextStyle(fontSize: 30),
                  children: [
                    TextSpan(
                      text: deviceStatus,
                      style: TextStyle(
                        fontSize: 30,
                        color: deviceStatus == 'Online'? Colors.green : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 100),
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomButton(
                      onPressed: () => _takeOffline(),
                      text: deviceStatus == 'Online'? 'Take Offline' : 'Take Online',
                      backgroundColor: deviceStatus == 'Online'? Colors.red : Colors.lightGreen,
                      icon: deviceStatus == 'Online'? Icons.offline_bolt : Icons.online_prediction,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              CustomOutlinedButton(
                onPressed: () => _showRevokeConfirmation(context),
                text: 'Logout',
                borderColor: Colors.redAccent,
                icon: Icons.logout,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _refreshConnection() {
    // API call for refresh connection
    print('Refresh connection API call');
    _updateStatuses();
  }

  void _takeOffline() {
    // API call for take offline
    print('Take offline API call');
  }

  void _showRevokeConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm'),
        content: const Text('Are you sure you want to logout this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _logout(context);
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _logout(BuildContext context) async {
    // API call for logout
    print('Logout API call');
    await AppDataStorage.clearLoginData();
    TokenStorage.clearToken();
    Navigator.pushReplacementNamed(context, '/home');
  }
}
