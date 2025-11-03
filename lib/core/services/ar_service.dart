import 'package:flutter/services.dart';

class ARService {
  static const MethodChannel _channel = MethodChannel('ar_service');
    /// Check if AR is supported on the device
  static Future<bool> isARSupported() async {
    try {
      final bool supported = await _channel.invokeMethod('isARSupported');
      return supported;
    } catch (e) {
      print('Error checking AR support: $e');
      return false;
    }
  }

  /// Launch AR view for a car
  static Future<void> launchARView({
    required String carModel,
    required String carName,
    List<String>? imageUrls,
  }) async {
    try {
      await _channel.invokeMethod('launchAR', {
        'carModel': carModel,
        'carName': carName,
        'imageUrls': imageUrls ?? [],
      });
    } catch (e) {
      print('Error launching AR: $e');
      rethrow;
    }
  }

  /// Get available AR models for a car
  static Future<List<String>> getAvailableARModels(String carId) async {
    try {
      final List<dynamic> models = await _channel.invokeMethod('getARModels', {
        'carId': carId,
      });
      return models.cast<String>();
    } catch (e) {
      print('Error getting AR models: $e');
      return [];
    }
  }
}

