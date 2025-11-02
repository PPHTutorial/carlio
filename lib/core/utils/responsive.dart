import 'package:flutter/material.dart';

class Responsive {
  static const double _baseWidth = 375.0;
  static const double _baseHeight = 812.0;

  static double width(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double height(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  static double scaleWidth(BuildContext context, double value) {
    final double screenWidth = width(context);
    return (value / _baseWidth) * screenWidth;
  }

  static double scaleHeight(BuildContext context, double value) {
    final double screenHeight = height(context);
    return (value / _baseHeight) * screenHeight;
  }

  static double textScaleFactor(BuildContext context) {
    final double screenWidth = width(context);
    final double textScaleFactor = MediaQuery.of(context).textScaleFactor;
    
    // Adjust based on screen density
    final double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    
    // Base scaling
    double scale = screenWidth / _baseWidth;
    
    // Apply text scale factor from system settings
    scale *= textScaleFactor.clamp(0.8, 1.2);
    
    // Adjust for device density (higher density = slightly larger text)
    if (devicePixelRatio > 3.0) {
      scale *= 1.05;
    } else if (devicePixelRatio > 2.5) {
      scale *= 1.02;
    }
    
    return scale.clamp(0.85, 1.3);
  }

  static double fontSize(BuildContext context, double baseSize) {
    return baseSize * textScaleFactor(context);
  }

  static bool isMobile(BuildContext context) {
    return width(context) < 600;
  }

  static bool isTablet(BuildContext context) {
    final double w = width(context);
    return w >= 600 && w < 1024;
  }

  static bool isDesktop(BuildContext context) {
    return width(context) >= 1024;
  }

  static int crossAxisCount(BuildContext context) {
    if (isDesktop(context)) return 4;
    if (isTablet(context)) return 3;
    return 2;
  }

  static EdgeInsets padding(BuildContext context) {
    if (isDesktop(context)) {
      return EdgeInsets.symmetric(
        horizontal: scaleWidth(context, 48),
        vertical: scaleHeight(context, 24),
      );
    } else if (isTablet(context)) {
      return EdgeInsets.symmetric(
        horizontal: scaleWidth(context, 32),
        vertical: scaleHeight(context, 20),
      );
    }
    return EdgeInsets.symmetric(
      horizontal: scaleWidth(context, 16),
      vertical: scaleHeight(context, 16),
    );
  }

  static EdgeInsets cardPadding(BuildContext context) {
    if (isDesktop(context)) {
      return EdgeInsets.all(scaleWidth(context, 20));
    } else if (isTablet(context)) {
      return EdgeInsets.all(scaleWidth(context, 16));
    }
    return EdgeInsets.all(scaleWidth(context, 12));
  }
}

