import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import 'custom_button.dart';

class DashboardControls extends StatelessWidget {
  final String serverStatus;
  final String deviceStatus;
  final VoidCallback onRefresh;
  final VoidCallback onToggle;
  final VoidCallback onLogout;

  const DashboardControls({
    super.key,
    required this.serverStatus,
    required this.deviceStatus,
    required this.onRefresh,
    required this.onToggle,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            text: 'Server: ',
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
            text: 'Device: ',
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
        SizedBox(height: Responsive.height(context) * 0.06),
        Row(
          children: [
            Expanded(
              child: CustomButton(
                onPressed: onRefresh,
                text: 'Refresh',
                backgroundColor: Colors.cyan,
                icon: Icons.refresh,
              ),
            ),
            SizedBox(width: Responsive.width(context) * 0.04),
            Expanded(
              child: CustomButton(
                onPressed: onToggle,
                text: deviceStatus == 'Online' ? 'Go Offline' : 'Go Online',
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
          onPressed: onLogout,
          text: 'Logout',
          borderColor: Colors.redAccent,
          icon: Icons.logout,
        ),
      ],
    );
  }
}
