import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/logo_widget.dart';
import '../widgets/custom_button.dart';
import '../utils/app_colors.dart';

import 'login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _launchRegistration() async {
    final Uri url = Uri.parse(
      'https://quiet-pup-summary.ngrok-free.app/web/home',
    );
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const LogoWidget(),
              const SizedBox(height: 30),
              const Text(
                'N.I.X - Your Private Agent',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 100),
              CustomButton(
                text: 'Login',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                },
                backgroundColor: AppColors.accent,
              ),
              const SizedBox(height: 20),
              CustomButton(
                text: 'Register',
                onPressed: _launchRegistration,
                backgroundColor: AppColors.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
