import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class ShareService {
  static final ShareService _instance = ShareService._internal();
  factory ShareService() => _instance;
  ShareService._internal();

  /// Share the app with a message and app store links
  Future<void> shareApp() async {
    try {
      const appName = 'CarCollection';
      const message = 'Check out this amazing car collection app! 🚗\n\n'
          'Discover stunning car images, specifications, and more!\n\n'
          'Download now:';
      
      // You can replace these with your actual app store URLs when published
      const androidUrl = 'https://play.google.com/store/apps/details?id=com.codeink.stsl.carcollection';
      // iOS URL will be added when app is published to App Store
      
      await Share.share(
        '$message\n$androidUrl',
        subject: 'Check out $appName',
      );
    } catch (e) {
      print('Error sharing app: $e');
    }
  }

  /// Share a specific car with its details
  Future<void> shareCar({
    required String carName,
    String? imageUrl,
  }) async {
    try {
      final message = 'Check out this amazing car: $carName 🚗\n\n'
          'Discover more in CarCollection app!';
      
      if (imageUrl != null) {
        // Share with image (if supported by platform)
        try {
          await Share.shareXFiles(
            [],
            text: message,
            subject: carName,
          );
        } catch (e) {
          // Fallback to text only
          await Share.share(message, subject: carName);
        }
      } else {
        await Share.share(message, subject: carName);
      }
    } catch (e) {
      print('Error sharing car: $e');
    }
  }

  /// Share text with copy to clipboard option
  Future<void> shareText(String text, {String? subject}) async {
    try {
      await Share.share(text, subject: subject);
    } catch (e) {
      print('Error sharing text: $e');
    }
  }

  /// Copy text to clipboard
  Future<void> copyToClipboard(String text, {String? label}) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (e) {
      print('Error copying to clipboard: $e');
    }
  }

  /// Open app store page for rating
  Future<void> openAppStoreForRating() async {
    try {
      // Android Play Store
      // Note: For iOS, replace with your actual App Store ID when published
      const androidUrl = 'https://play.google.com/store/apps/details?id=com.codeink.stsl.carcollection';
      
      final uri = Uri.parse(androidUrl); // You can detect platform and use appropriate URL
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Error opening app store: $e');
    }
  }
}

