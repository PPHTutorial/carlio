import 'dart:io';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class ImageService {
  static final Dio _dio = Dio();

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

  static Future<bool> downloadImage(String imageUrl, String fileName) async {
    try {
      final hasPermission = await requestStoragePermission();
      if (!hasPermission) {
        return false;
      }

      final tempDir = await getTemporaryDirectory();
      final tempFile =
          File('${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');

      final response = await _dio.download(
        imageUrl,
        tempFile.path,
        options: Options(
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      if (response.statusCode == 200) {
        try {
          await Gal.putImage(tempFile.path);
          await tempFile.delete();
          return true;
        } catch (galError) {
          print('Error saving image to gallery: $galError');
          // Clean up temp file even if save fails
          try {
            await tempFile.delete();
          } catch (_) {}
          return false;
        }
      }
      return false;
    } catch (e) {
      print('Error downloading image: $e');
      return false;
    }
  }

  static Future<bool> downloadAllImages(
    List<String> imageUrls,
    String carName,
    Function(int current, int total)? onProgress,
  ) async {
    try {
      final hasPermission = await requestStoragePermission();
      if (!hasPermission) {
        return false;
      }

      final tempDir = await getTemporaryDirectory();
      int downloaded = 0;
      for (int i = 0; i < imageUrls.length; i++) {
        final url = imageUrls[i];
        final tempFile = File(
            '${tempDir.path}/${carName}_${i + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg');

        final response = await _dio.download(
          url,
          tempFile.path,
          options: Options(
            receiveTimeout: const Duration(seconds: 30),
          ),
        );

        if (response.statusCode == 200) {
          try {
            await Gal.putImage(tempFile.path);
            await tempFile.delete();
            downloaded++;
            onProgress?.call(downloaded, imageUrls.length);
          } catch (galError) {
            print('Error saving image $i to gallery: $galError');
            // Clean up temp file even if save fails
            try {
              await tempFile.delete();
            } catch (_) {}
            // Continue with next image instead of failing completely
          }
        }
      }

      return downloaded == imageUrls.length;
    } catch (e) {
      print('Error downloading images: $e');
      return false;
    }
  }

  static Future<bool> setWallpaper(String imageUrl) async {
    try {
      if (Platform.isAndroid) {
        final permissionStatus =
            await Permission.manageExternalStorage.request();
        if (!permissionStatus.isGranted) {
          return false;
        }
      }

      // Download image first to a temporary location
      final tempDir = await getApplicationDocumentsDirectory();
      final tempFile = File('${tempDir.path}/wallpaper_temp.jpg');
      await _dio.download(imageUrl, tempFile.path);

      // Use platform channel to set wallpaper
      // Note: This requires native implementation
      const platform = MethodChannel('com.carcollection/wallpaper');
      try {
        await platform
            .invokeMethod('setWallpaper', {'imagePath': tempFile.path});

        // Clean up
        try {
          await tempFile.delete();
        } catch (_) {}

        return true;
      } catch (e) {
        print('Error setting wallpaper via platform channel: $e');
        // Clean up on error
        try {
          await tempFile.delete();
        } catch (_) {}
        return false;
      }
    } catch (e) {
      print('Error setting wallpaper: $e');
      return false;
    }
  }
}
