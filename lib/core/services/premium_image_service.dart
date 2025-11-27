import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'user_service.dart';

class PremiumImageService {
  static final Dio _dio = Dio();
  static const double ACTION_CREDIT_COST = 1.0; // 1 credit per action
  static const double MIN_CREDITS_REQUIRED = 5.0; // Minimum 5 credits needed

  static Future<bool> requestStoragePermission() async {
    // For saving images, we don't need read permissions on Android 10+
    // The gal package handles saving without requiring READ_MEDIA_IMAGES permission
    // On iOS, we still need photos permission for saving
    if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted;
    }
    // Android: No permission needed for saving images (gal package handles it via MediaStore)
    return true;
  }

  /// Download image with cropping and watermark logic
  static Future<bool> downloadImage({
    required String imageUrl,
    required String carName,
    Function(String)? onStatusUpdate,
  }) async {
    try {
      final userData = await UserService.instance.getUserData();
      if (userData == null) {
        onStatusUpdate?.call('Please sign in to download images');
        return false;
      }

      // Check if user is in spending mode (has reached 5 credits and can continue using until 0)
      if (userData.isInSpendingMode) {
        // User can use credits until they reach 0
        if (userData.credits <= 0) {
          onStatusUpdate?.call(
              'No credits remaining. Watch ads to earn credits or subscribe to Pro.');
          return false;
        }
      } else {
        // Not in spending mode - need at least 5 credits to start
        if (userData.credits < MIN_CREDITS_REQUIRED) {
          onStatusUpdate?.call(
              'You need at least ${MIN_CREDITS_REQUIRED.toInt()} credits. Watch ads to earn credits or subscribe to Pro.');
          return false;
        }

        // Check if user has enough credits for the action
        if (userData.credits < ACTION_CREDIT_COST) {
          onStatusUpdate?.call(
              'Insufficient credits. You need ${ACTION_CREDIT_COST.toInt()} credit for this action.');
          return false;
        }
      }

      // Deduct 1 credit for the action
      final used = await UserService.instance.useCredits(ACTION_CREDIT_COST);
      if (!used) {
        onStatusUpdate?.call('Failed to deduct credits');
        return false;
      }

      final hasPermission = await requestStoragePermission();
      if (!hasPermission) {
        onStatusUpdate?.call('Storage permission denied');
        return false;
      }

      onStatusUpdate?.call('Downloading image...');

      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
          '${tempDir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.jpg');

      await _dio.download(imageUrl, tempFile.path);

      onStatusUpdate?.call('Processing image...');

      // Process image: crop and add watermark if needed
      final processedBytes = await _processImage(
        tempFile.path,
        addWatermark: !userData.hasValidSubscription,
      );

      final processedFile = File(
          '${tempDir.path}/processed_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await processedFile.writeAsBytes(processedBytes);

      try {
        await Gal.putImage(processedFile.path);
        onStatusUpdate?.call('Image downloaded successfully');
      } catch (galError) {
        print('Error saving image to gallery: $galError');
        onStatusUpdate?.call('Failed to save image to gallery');
        // Clean up files
        try {
          await tempFile.delete();
          await processedFile.delete();
        } catch (_) {}
        return false;
      }

      await tempFile.delete();
      await processedFile.delete();
      return true;
    } catch (e) {
      print('Error downloading image: $e');
      return false;
    }
  }

  /// Set wallpaper with cropping and watermark logic
  static Future<bool> setWallpaper({
    required String imageUrl,
    required String carName,
    Function(String)? onStatusUpdate,
  }) async {
    try {
      final userData = await UserService.instance.getUserData();
      if (userData == null) {
        onStatusUpdate?.call('Please sign in to set wallpaper');
        return false;
      }

      // Check if user is in spending mode (has reached 5 credits and can continue using until 0)
      if (userData.isInSpendingMode) {
        // User can use credits until they reach 0
        if (userData.credits <= 0) {
          onStatusUpdate?.call(
              'No credits remaining. Watch ads to earn credits or subscribe to Pro.');
          return false;
        }
      } else {
        // Not in spending mode - need at least 5 credits to start
        if (userData.credits < MIN_CREDITS_REQUIRED) {
          onStatusUpdate?.call(
              'You need at least ${MIN_CREDITS_REQUIRED.toInt()} credits. Watch ads to earn credits or subscribe to Pro.');
          return false;
        }

        // Check if user has enough credits for the action
        if (userData.credits < ACTION_CREDIT_COST) {
          onStatusUpdate?.call(
              'Insufficient credits. You need ${ACTION_CREDIT_COST.toInt()} credit for this action.');
          return false;
        }
      }

      // Deduct 1 credit for the action
      final used = await UserService.instance.useCredits(ACTION_CREDIT_COST);
      if (!used) {
        onStatusUpdate?.call('Failed to deduct credits');
        return false;
      }

      // Request wallpaper permission (doesn't require storage permission on Android 10+)
      // Just check if we can set wallpaper via platform channel
      // Note: SET_WALLPAPER permission is granted automatically on Android

      onStatusUpdate?.call('Downloading image...');

      final tempDir = await getApplicationDocumentsDirectory();
      final tempFile = File('${tempDir.path}/wallpaper_temp.jpg');
      await _dio.download(imageUrl, tempFile.path);

      onStatusUpdate?.call('Processing image...');

      final processedBytes = await _processImage(
        tempFile.path,
        addWatermark: !userData.hasValidSubscription,
      );

      final processedFile = File('${tempDir.path}/wallpaper_processed.jpg');
      await processedFile.writeAsBytes(processedBytes);

      // Set wallpaper via platform channel
      // SET_WALLPAPER permission is automatically granted on Android
      const platform = MethodChannel('com.carcollection/wallpaper');
      try {
        await platform
            .invokeMethod('setWallpaper', {'imagePath': processedFile.path});
        await tempFile.delete();
        await processedFile.delete();
        onStatusUpdate?.call('Wallpaper set successfully');
        return true;
      } catch (e) {
        // Clean up on error
        try {
          await tempFile.delete();
          await processedFile.delete();
        } catch (_) {}
        onStatusUpdate?.call('Failed to set wallpaper: ${e.toString()}');
        return false;
      }
    } catch (e) {
      print('Error setting wallpaper: $e');
      return false;
    }
  }

  /// Download all images - only for pro users with credits
  static Future<bool> downloadAllImages({
    required List<String> imageUrls,
    required String carName,
    Function(int current, int total)? onProgress,
    Function(String)? onStatusUpdate,
  }) async {
    try {
      final userData = await UserService.instance.getUserData();
      if (userData == null) {
        onStatusUpdate?.call('Please sign in');
        return false;
      }

      if (!userData.hasValidSubscription) {
        onStatusUpdate
            ?.call('Pro subscription required to download all images');
        return false;
      }

      final totalCost = imageUrls.length * ACTION_CREDIT_COST;

      // Check if user is in spending mode
      if (userData.isInSpendingMode) {
        // User can use credits until they reach 0
        if (userData.credits <= 0) {
          onStatusUpdate?.call(
              'No credits remaining. Watch ads to earn credits or subscribe to Pro.');
          return false;
        }
        // In spending mode, user can use all available credits (even if less than totalCost)
        // We'll deduct what they have available
      } else {
        // Not in spending mode - need at least 5 credits to start
        if (userData.credits < MIN_CREDITS_REQUIRED) {
          onStatusUpdate?.call(
              'You need at least ${MIN_CREDITS_REQUIRED.toInt()} credits. Watch ads to earn credits or subscribe to Pro.');
          return false;
        }

        if (userData.credits < totalCost) {
          onStatusUpdate?.call(
              'Insufficient credits. Need ${totalCost.toInt()} credits (${imageUrls.length} images × ${ACTION_CREDIT_COST.toInt()} credit each)');
          return false;
        }
      }

      // Calculate actual cost (in spending mode, use available credits if less than totalCost)
      final actualCost = userData.isInSpendingMode
          ? (userData.credits < totalCost ? userData.credits : totalCost)
          : totalCost;

      // Deduct credits BEFORE starting download (prevents download without payment)
      final creditsUsed = await UserService.instance.useCredits(actualCost);
      if (!creditsUsed) {
        onStatusUpdate?.call('Failed to deduct credits. Please try again.');
        return false;
      }

      final hasPermission = await requestStoragePermission();
      if (!hasPermission) {
        // Refund credits if permission denied (since we already deducted)
        await UserService.instance.addCredits(actualCost);
        onStatusUpdate?.call('Storage permission denied. Credits refunded.');
        return false;
      }

      int downloaded = 0;
      final tempDir = await getTemporaryDirectory();

      // Calculate how many images user can actually download
      final imagesToDownload =
          userData.isInSpendingMode && userData.credits < totalCost
              ? (actualCost / ACTION_CREDIT_COST).floor()
              : imageUrls.length;

      for (int i = 0; i < imagesToDownload; i++) {
        onStatusUpdate?.call('Processing ${i + 1}/$imagesToDownload...');

        final tempFile = File(
            '${tempDir.path}/temp_${i}_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await _dio.download(imageUrls[i], tempFile.path);

        final processedBytes = await _processImage(
          tempFile.path,
          addWatermark: false, // Pro users get no watermark
        );

        final processedFile = File(
            '${tempDir.path}/processed_${i}_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await processedFile.writeAsBytes(processedBytes);

        try {
          await Gal.putImage(processedFile.path);
          downloaded++;
          onProgress?.call(downloaded, imagesToDownload);
        } catch (galError) {
          print('Error saving image $i to gallery: $galError');
          // Continue with next image instead of failing completely
        } finally {
          // Clean up files regardless of success/failure
          try {
            await tempFile.delete();
            await processedFile.delete();
          } catch (_) {}
        }
      }

      if (userData.isInSpendingMode && imagesToDownload < imageUrls.length) {
        onStatusUpdate?.call(
            'Downloaded $imagesToDownload of ${imageUrls.length} images (used all available credits)');
      } else {
        onStatusUpdate?.call('All images downloaded successfully');
      }
      return true;
    } catch (e) {
      print('Error downloading all images: $e');
      // Credits were already deducted before starting, so don't refund on error
      // This prevents abuse (user gets images even if download partially fails)
      return false;
    }
  }

  /// Process image: crop 5% from edges and optionally add watermark
  static Future<Uint8List> _processImage(
    String imagePath, {
    required bool addWatermark,
    double cropPercent = 0.05,
  }) async {
    final imageBytes = await File(imagePath).readAsBytes();
    img.Image? image = img.decodeImage(imageBytes);

    if (image == null) {
      throw Exception('Failed to decode image');
    }

    // Crop 5% from all edges
    final cropX = (image.width * cropPercent).round();
    final cropY = (image.height * cropPercent).round();
    final cropWidth = image.width - (cropX * 2);
    final cropHeight = image.height - (cropY * 2);

    img.Image cropped = img.copyCrop(
      image,
      x: cropX,
      y: cropY,
      width: cropWidth,
      height: cropHeight,
    );

    // Add watermark if needed
    if (addWatermark) {
      cropped = await _addWatermark(cropped);
    }

    return Uint8List.fromList(img.encodeJpg(cropped, quality: 95));
  }

  /// Add watermark to image using watermark.png from assets
  static Future<img.Image> _addWatermark(img.Image image) async {
    try {
      // Load watermark image from assets
      final ByteData watermarkData =
          await rootBundle.load('assets/images/watermark.png');
      final Uint8List watermarkBytes = watermarkData.buffer.asUint8List();

      // Decode the watermark image
      img.Image? watermark = img.decodeImage(watermarkBytes);

      if (watermark == null) {
        print('Warning: Failed to decode watermark.png, skipping watermark');
        return image;
      }

      // Calculate watermark size (60% of image width, maintaining aspect ratio)
      final double targetWidth = image.width * 0.2;
      final double scaleFactor = targetWidth / watermark.width;
      final int watermarkWidth = targetWidth.round();
      final int watermarkHeight = (watermark.height * scaleFactor).round();

      // Resize watermark to calculated size
      watermark = img.copyResize(
        watermark,
        width: watermarkWidth,
        height: watermarkHeight,
        interpolation: img.Interpolation.linear,
      );

      // Position watermark at center of the image
      final int watermarkX = (image.width - watermarkWidth) ~/ 2;
      final int watermarkY = (image.height - watermarkHeight) ~/ 2;

      // Composite watermark onto the image with alpha blending
      return img.compositeImage(
        image,
        watermark,
        dstX: watermarkX.clamp(0, image.width - 1),
        dstY: watermarkY.clamp(0, image.height - 1),
        blend: img.BlendMode.alpha,
      );
    } catch (e) {
      print('Error loading watermark: $e');
      print(
          'Make sure assets/images/watermark.png exists and is declared in pubspec.yaml');
      // Return original image if watermark loading fails
      return image;
    }
  }

  /// Check if user can download/set wallpaper
  static Future<Map<String, dynamic>> checkDownloadEligibility() async {
    final userData = await UserService.instance.getUserData();
    if (userData == null) {
      return {
        'canDownload': false,
        'requiresSignIn': true,
        'requiresAds': false,
        'requiresCredits': false,
        'requiresPro': false,
        'creditsNeeded': 0,
        'minCreditsNeeded': MIN_CREDITS_REQUIRED,
        'availableCredits': 0.0,
      };
    }

    final availableCredits = userData.credits;

    // Check if user is in spending mode (can use credits until 0)
    if (userData.isInSpendingMode) {
      // User can use credits as long as they have any credits remaining
      if (availableCredits > 0) {
        return {
          'canDownload': true,
          'requiresSignIn': false,
          'requiresAds': true, // Show ads but don't grant credits
          'requiresCredits': false,
          'requiresPro': false,
          'creditsNeeded': ACTION_CREDIT_COST,
          'minCreditsNeeded': MIN_CREDITS_REQUIRED,
          'availableCredits': availableCredits,
          'isInSpendingMode': true,
        };
      } else {
        return {
          'canDownload': false,
          'requiresSignIn': false,
          'requiresAds': true,
          'requiresCredits': true,
          'requiresPro': false,
          'creditsNeeded': ACTION_CREDIT_COST,
          'minCreditsNeeded': MIN_CREDITS_REQUIRED,
          'availableCredits': availableCredits,
          'message': 'No credits remaining. Watch ads to earn credits.',
        };
      }
    }

    // Not in spending mode - need minimum 5 credits
    if (availableCredits < MIN_CREDITS_REQUIRED) {
      return {
        'canDownload': false,
        'requiresSignIn': false,
        'requiresAds': true, // Need to watch ads to earn credits
        'requiresCredits': true,
        'requiresPro': false,
        'creditsNeeded': ACTION_CREDIT_COST,
        'minCreditsNeeded': MIN_CREDITS_REQUIRED,
        'availableCredits': availableCredits,
        'message':
            'You need at least ${MIN_CREDITS_REQUIRED.toInt()} credits. Watch ads to earn 1.2 credits per ad.',
      };
    }

    // Check if user has enough for the action (1 credit)
    if (availableCredits < ACTION_CREDIT_COST) {
      return {
        'canDownload': false,
        'requiresSignIn': false,
        'requiresAds': true,
        'requiresCredits': true,
        'requiresPro': false,
        'creditsNeeded': ACTION_CREDIT_COST,
        'minCreditsNeeded': MIN_CREDITS_REQUIRED,
        'availableCredits': availableCredits,
        'message':
            'You need ${ACTION_CREDIT_COST.toInt()} credit for this action. Watch ads to earn credits.',
      };
    }

    // User can perform action
    return {
      'canDownload': true,
      'requiresSignIn': false,
      'requiresAds': false,
      'requiresCredits': false,
      'requiresPro': false,
      'creditsNeeded': ACTION_CREDIT_COST,
      'minCreditsNeeded': MIN_CREDITS_REQUIRED,
      'availableCredits': availableCredits,
    };
  }
}
