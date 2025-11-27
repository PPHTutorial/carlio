import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_rating_service.dart';
import 'share_service.dart';

/// Service to manage smart app rating and sharing prompts
/// Shows prompts at appropriate times without being annoying
class AppFeedbackService {
  static final AppFeedbackService _instance = AppFeedbackService._internal();
  factory AppFeedbackService() => _instance;
  AppFeedbackService._internal();

  static const String _lastPromptKey = 'last_feedback_prompt';
  static const String _promptCountKey = 'feedback_prompt_count';
  static const String _hasRatedKey = 'has_rated_app';
  static const String _hasSharedKey = 'has_shared_app';
  static const String _hasDeclinedKey = 'has_declined_feedback';
  static const String _sessionCountKey = 'app_session_count';
  static const String _actionCountKey = 'app_action_count';
  static const String _lastSessionKey = 'last_app_session';

  final AppRatingService _ratingService = AppRatingService();
  final ShareService _shareService = ShareService();

  // Minimum requirements before showing prompt
  static const int _minSessions = 3; // User must have used app at least 3 times
  static const int _minActions =
      10; // User must have performed at least 10 actions
  static const int _minDaysSinceInstall = 2; // At least 2 days since first use
  static const int _minDaysBetweenPrompts =
      14; // Don't show more than once every 2 weeks
  static const int _maxPrompts = 3; // Maximum 3 prompts total

  /// Track app session (call when app starts)
  Future<void> trackSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionCount = (prefs.getInt(_sessionCountKey) ?? 0) + 1;
      await prefs.setInt(_sessionCountKey, sessionCount);
      await prefs.setInt(
          _lastSessionKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('Error tracking session: $e');
    }
  }

  /// Track user action (call when user performs meaningful actions)
  Future<void> trackAction() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final actionCount = (prefs.getInt(_actionCountKey) ?? 0) + 1;
      await prefs.setInt(_actionCountKey, actionCount);
    } catch (e) {
      print('Error tracking action: $e');
    }
  }

  /// Check if conditions are met to show feedback prompt
  Future<bool> _shouldShowPrompt() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Don't show if user already rated and shared
      final hasRated = prefs.getBool(_hasRatedKey) ?? false;
      final hasShared = prefs.getBool(_hasSharedKey) ?? false;
      if (hasRated && hasShared) {
        return false;
      }

      // Don't show if declined too many times
      final declinedCount = prefs.getInt(_hasDeclinedKey) ?? 0;
      if (declinedCount >= 2) {
        return false;
      }

      // Check session count
      final sessionCount = prefs.getInt(_sessionCountKey) ?? 0;
      if (sessionCount < _minSessions) {
        return false;
      }

      // Check action count
      final actionCount = prefs.getInt(_actionCountKey) ?? 0;
      if (actionCount < _minActions) {
        return false;
      }

      // Check days since first use (approximate from first session)
      final firstSession = prefs.getInt(_lastSessionKey);
      if (firstSession != null) {
        final firstSessionDate =
            DateTime.fromMillisecondsSinceEpoch(firstSession);
        final daysSinceFirstUse =
            DateTime.now().difference(firstSessionDate).inDays;
        if (daysSinceFirstUse < _minDaysSinceInstall) {
          return false;
        }
      }

      // Check frequency capping
      final lastPrompt = prefs.getInt(_lastPromptKey);
      if (lastPrompt != null) {
        final lastPromptDate = DateTime.fromMillisecondsSinceEpoch(lastPrompt);
        final daysSinceLastPrompt =
            DateTime.now().difference(lastPromptDate).inDays;
        if (daysSinceLastPrompt < _minDaysBetweenPrompts) {
          return false;
        }
      }

      // Check max prompts
      final promptCount = prefs.getInt(_promptCountKey) ?? 0;
      if (promptCount >= _maxPrompts) {
        return false;
      }

      return true;
    } catch (e) {
      print('Error checking if should show prompt: $e');
      return false;
    }
  }

  /// Show feedback dialog (rating and sharing options)
  Future<void> showFeedbackDialog(BuildContext context) async {
    if (!await _shouldShowPrompt()) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final hasRated = prefs.getBool(_hasRatedKey) ?? false;
      final hasShared = prefs.getBool(_hasSharedKey) ?? false;

      // Update prompt tracking
      await prefs.setInt(_lastPromptKey, DateTime.now().millisecondsSinceEpoch);
      await prefs.setInt(
          _promptCountKey, (prefs.getInt(_promptCountKey) ?? 0) + 1);

      if (!context.mounted) return;

      final theme = Theme.of(context);
      final result = await showDialog<String>(
        context: context,
        barrierDismissible: true,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.favorite_rounded,
                color: theme.colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Enjoying CarCollection?',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Your support helps us improve! Would you like to rate us or share the app with friends?',
            style: theme.textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, 'decline');
              },
              child: Text(
                'Maybe Later',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            if (!hasRated)
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context, 'rate');
                },
                icon: const Icon(Icons.star_rounded),
                label: const Text('Rate App'),
              ),
            if (!hasShared)
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context, 'share');
                },
                icon: const Icon(Icons.share_rounded),
                label: const Text('Share App'),
              ),
          ],
        ),
      );

      // Handle user response
      if (result == 'rate') {
        await _handleRateAction(context);
      } else if (result == 'share') {
        await _handleShareAction();
      } else if (result == 'decline') {
        await _handleDecline();
      }
    } catch (e) {
      print('Error showing feedback dialog: $e');
    }
  }

  /// Handle rate action
  Future<void> _handleRateAction(BuildContext context) async {
    try {
      final shown = await _ratingService.requestRating();
      if (shown) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_hasRatedKey, true);
      } else if (context.mounted) {
        // Fallback: open app store
        await _shareService.openAppStoreForRating();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_hasRatedKey, true);
      }
    } catch (e) {
      print('Error handling rate action: $e');
    }
  }

  /// Handle share action
  Future<void> _handleShareAction() async {
    try {
      await _shareService.shareApp();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hasSharedKey, true);
    } catch (e) {
      print('Error handling share action: $e');
    }
  }

  /// Handle decline
  Future<void> _handleDecline() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final declinedCount = (prefs.getInt(_hasDeclinedKey) ?? 0) + 1;
      await prefs.setInt(_hasDeclinedKey, declinedCount);
    } catch (e) {
      print('Error handling decline: $e');
    }
  }

  /// Check if should show prompt before app closes
  Future<bool> shouldShowOnExit() async {
    // Show on exit if conditions are met and user hasn't rated/shared
    return await _shouldShowPrompt();
  }

  /// Reset feedback state (for testing)
  Future<void> resetFeedbackState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastPromptKey);
      await prefs.remove(_promptCountKey);
      await prefs.remove(_hasRatedKey);
      await prefs.remove(_hasSharedKey);
      await prefs.remove(_hasDeclinedKey);
    } catch (e) {
      print('Error resetting feedback state: $e');
    }
  }
}
