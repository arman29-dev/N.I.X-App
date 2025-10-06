import 'dart:convert';
import 'package:flutter/material.dart';

import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import '../utils/app_colors.dart';
import '../utils/token_storage.dart';
import '../utils/appdata_storage.dart';
import '../utils/responsive.dart';
import '../api/login.dart';
import 'registration_screen.dart';
import 'qr_scanner_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _otpController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await loginUser(
        _emailController.text,
        _passwordController.text,
        _otpController.text,
      );

      final responseData = jsonDecode(response.body);

      if (responseData.containsKey('access_token') &&
          responseData.containsKey('success')) {
        await TokenStorage.setToken(
          responseData['access_token'],
          responseData['token_type'] ?? 'Bearer',
          responseData['access_token_uid']
        );

        await AppDataStorage.setAccessTokenUID(responseData['access_token_uid']);
        await AppDataStorage.setEmail(_emailController.text); // Save email for login persistence

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Login successful!')));

        // Navigate to QR Scanner
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const QRScannerScreen()),
        );
      } else if (responseData.containsKey('Error')) {
        // Error - display error message
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(responseData['Error'])));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unexpected response format')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: Responsive.padding(context, horizontal: 30, vertical: 20),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: Responsive.isDesktop(context) ? 400 : double.infinity,
              ),
              padding: EdgeInsets.all(Responsive.width(context) * 0.08),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Welcome Back',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: Responsive.sp(context, 28),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: Responsive.height(context) * 0.05),
                  CustomTextField(
                    hintText: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    controller: _emailController,
                  ),
                  SizedBox(height: Responsive.height(context) * 0.025),
                  CustomTextField(
                    hintText: 'Password',
                    isPassword: true,
                    controller: _passwordController,
                  ),
                  SizedBox(height: Responsive.height(context) * 0.025),
                  CustomTextField(
                    hintText: '2FA-OTP',
                    keyboardType: TextInputType.number,
                    controller: _otpController,
                  ),
                  SizedBox(height: Responsive.height(context) * 0.05),
                  CustomButton(
                    text: _isLoading ? 'Logging in...' : 'Login',
                    onPressed: _isLoading ? () {} : _handleLogin,
                    backgroundColor: AppColors.accent,
                  ),
                  SizedBox(height: Responsive.height(context) * 0.025),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.accent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Login with Passkey',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: Responsive.sp(context, 16),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: Responsive.height(context) * 0.04),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {},
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        '  |  ',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegistrationScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'Create a New Account',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }
}
