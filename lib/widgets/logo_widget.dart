import 'package:flutter/material.dart';

class LogoWidget extends StatelessWidget {
  const LogoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 200,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/logo.png',
          width: 200,
          height: 200,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
