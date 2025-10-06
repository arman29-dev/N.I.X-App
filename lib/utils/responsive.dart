import 'package:flutter/material.dart';

class Responsive {
  static double width(BuildContext context) => MediaQuery.of(context).size.width;
  static double height(BuildContext context) => MediaQuery.of(context).size.height;
  
  static bool isMobile(BuildContext context) => width(context) < 600;
  static bool isTablet(BuildContext context) => width(context) >= 600 && width(context) < 1024;
  static bool isDesktop(BuildContext context) => width(context) >= 1024;
  
  static double sp(BuildContext context, double size) {
    double scaleFactor = width(context) / 375; // Base width 375 (iPhone)
    return size * scaleFactor.clamp(0.9, 1.1); // Reduced scaling range
  }
  
  static EdgeInsets padding(BuildContext context, {
    double horizontal = 16,
    double vertical = 16,
  }) {
    return EdgeInsets.symmetric(
      horizontal: horizontal,
      vertical: vertical,
    );
  }
}
