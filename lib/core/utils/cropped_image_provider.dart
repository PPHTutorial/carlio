import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Widget that displays a network image with actual pixel-level cropping
/// Cropped images are cached to avoid re-cropping on subsequent views
class CroppedNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double cropPercent;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CroppedNetworkImage({
    super.key,
    required this.imageUrl,
    this.cropPercent = 0.05,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (cropPercent <= 0) {
      // No cropping needed, use regular CachedNetworkImage
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: fit,
        placeholder: (context, url) => placeholder ?? const SizedBox(),
        errorWidget: (context, url, error) => errorWidget ?? const SizedBox(),
      );
    }

    // Fetch, crop, and display the image
    return FutureBuilder<Uint8List?>(
      future: _loadAndCropImage(imageUrl, cropPercent),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return placeholder ?? const SizedBox();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return errorWidget ?? const SizedBox();
        }

        return Image.memory(
          snapshot.data!,
          fit: fit,
        );
      },
    );
  }

  /// Generate a cache key for the cropped image based on URL and crop percent
  String _getCacheKey(String url, double cropPercent) {
    final keyString = '${url}_cropped_${cropPercent.toStringAsFixed(2)}';
    final bytes = utf8.encode(keyString);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  /// Get the cache directory for cropped images
  Future<Directory> _getCacheDirectory() async {
    final cacheDir = await getTemporaryDirectory();
    final croppedCacheDir = Directory('${cacheDir.path}/cropped_images');
    if (!await croppedCacheDir.exists()) {
      await croppedCacheDir.create(recursive: true);
    }
    return croppedCacheDir;
  }

  Future<Uint8List?> _loadAndCropImage(String url, double cropPercent) async {
    try {
      // Generate cache key
      final cacheKey = _getCacheKey(url, cropPercent);
      final cacheDir = await _getCacheDirectory();
      final cachedFile = File('${cacheDir.path}/$cacheKey.jpg');

      // Check if cropped version exists in cache
      if (await cachedFile.exists()) {
        final cachedBytes = await cachedFile.readAsBytes();
        return cachedBytes;
      }

      // Get cached file from CachedNetworkImage's cache manager
      final cacheManager = DefaultCacheManager();
      final file = await cacheManager.getSingleFile(url);
      final bytes = await file.readAsBytes();

      // Decode the image
      final originalImage = img.decodeImage(bytes);
      if (originalImage == null) {
        throw Exception('Failed to decode image');
      }

      // Calculate crop dimensions (remove cropPercent from each edge)
      final cropX = (originalImage.width * cropPercent).round();
      final cropY = (originalImage.height * cropPercent).round();
      final cropWidth = (originalImage.width * (1 - cropPercent * 2)).round();
      final cropHeight = (originalImage.height * (1 - cropPercent * 2)).round();

      // Ensure valid dimensions
      final validX = cropX.clamp(0, originalImage.width - 1);
      final validY = cropY.clamp(0, originalImage.height - 1);
      final validWidth = cropWidth.clamp(1, originalImage.width - validX);
      final validHeight = cropHeight.clamp(1, originalImage.height - validY);

      // Crop the image
      final croppedImage = img.copyCrop(
        originalImage,
        x: validX,
        y: validY,
        width: validWidth,
        height: validHeight,
      );

      // Encode back to bytes (JPEG for smaller size)
      final croppedBytes = Uint8List.fromList(img.encodeJpg(croppedImage, quality: 95));

      // Cache the cropped image
      await cachedFile.writeAsBytes(croppedBytes);

      return croppedBytes;
    } catch (e) {
      // If cropping fails, return null to show error widget
      return null;
    }
  }
}
