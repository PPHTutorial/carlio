import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppRatingService {
  static final AppRatingService _instance = AppRatingService._internal();
  factory AppRatingService() => _instance;
  AppRatingService._internal();

  static const String _lastRatingRequestKey = 'last_rating_request';
  static const String _ratingRequestCountKey = 'rating_request_count';
  static const String _hasRatedKey = 'has_rated';
  static const String _hasDeclinedKey = 'has_declined';

  /// Request app rating (with smart frequency capping)
  /// - Won't show if already rated
  /// - Won't show if declined more than 2 times
  /// - Won't show if requested less than 7 days ago
  /// - Won't show if requested more than 3 times total
  Future<bool> requestRating({
    bool force = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if user already rated
      if (!force && prefs.getBool(_hasRatedKey) == true) {
        return false;
      }

      // Check if user declined too many times
      if (!force) {
        final declinedCount = prefs.getInt(_hasDeclinedKey) ?? 0;
        if (declinedCount >= 2) {
          return false;
        }
      }

      // Check frequency capping (don't show more than once per week)
      if (!force) {
        final lastRequest = prefs.getInt(_lastRatingRequestKey);
        if (lastRequest != null) {
          final lastRequestDate = DateTime.fromMillisecondsSinceEpoch(lastRequest);
          final daysSinceLastRequest = DateTime.now().difference(lastRequestDate).inDays;
          
          if (daysSinceLastRequest < 7) {
            return false;
          }
        }

        // Don't request more than 3 times total
        final requestCount = prefs.getInt(_ratingRequestCountKey) ?? 0;
        if (requestCount >= 3) {
          return false;
        }
      }

      // Check if In-App Review is available
      final InAppReview inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        // Update request tracking
        await prefs.setInt(_lastRatingRequestKey, DateTime.now().millisecondsSinceEpoch);
        await prefs.setInt(_ratingRequestCountKey, (prefs.getInt(_ratingRequestCountKey) ?? 0) + 1);

        // Request review
        await inAppReview.requestReview();
        
        // Assume user reviewed (they might have, we don't know for sure)
        // Don't set hasRatedKey here - let them review again if they want
        return true;
      } else {
        // In-App Review not available, open store page
        // This will be handled by the caller
        return false;
      }
    } catch (e) {
      print('Error requesting rating: $e');
      return false;
    }
  }

  /// Mark that user has rated (called after successful rating)
  Future<void> markAsRated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hasRatedKey, true);
    } catch (e) {
      print('Error marking as rated: $e');
    }
  }

  /// Mark that user declined rating
  Future<void> markAsDeclined() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentCount = prefs.getInt(_hasDeclinedKey) ?? 0;
      await prefs.setInt(_hasDeclinedKey, currentCount + 1);
    } catch (e) {
      print('Error marking as declined: $e');
    }
  }

  /// Reset rating state (for testing or user request)
  Future<void> resetRatingState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastRatingRequestKey);
      await prefs.remove(_ratingRequestCountKey);
      await prefs.remove(_hasRatedKey);
      await prefs.remove(_hasDeclinedKey);
    } catch (e) {
      print('Error resetting rating state: $e');
    }
  }

  /// Check if user has already rated
  Future<bool> hasRated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_hasRatedKey) ?? false;
    } catch (e) {
      return false;
    }
  }
}

