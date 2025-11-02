import 'dart:io';

/// Script to take screenshots of the Flutter app
/// 
/// Usage:
///   dart scripts/take_screenshots.dart
///   flutter test integration_test/screenshot_test.dart
/// 
/// Screenshots will be saved to the 'screenshots' directory

void main() {
  print('📸 Flutter App Screenshot Capture');
  print('==================================\n');
  print('To capture screenshots, run:');
  print('  flutter test integration_test/screenshot_test.dart\n');
  print('For Android device:');
  print('  flutter test integration_test/screenshot_test.dart --device-id <device-id>\n');
  print('Available devices:');
  print('  flutter devices\n');
  print('Screenshots will be saved to: screenshots/\n');
}

