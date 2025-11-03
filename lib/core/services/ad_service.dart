import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'user_service.dart';

class AdService {
  static AdService? _instance;
  static AdService get instance {
    _instance ??= AdService._();
    return _instance!;
  }

  AdService._();

  // AdMob App ID
  static const appId = "ca-app-pub-9043208558525567~6355026522";
  
  // Test Device ID (replace with your device ID for testing)
  static const testDevice = "01234567890123456789012345678901";

  // Production Ad Unit IDs
  static const String _bannerAdUnitId = "ca-app-pub-9043208558525567/8079063932";
  static const String _interstitialAdUnitId = "ca-app-pub-9043208558525567/1513655586";
  static const String _rewardedAdUnitId = "ca-app-pub-9043208558525567/9572216801";
  static const String _rewardedInterstitialAdUnitId = "ca-app-pub-9043208558525567/2320412743";
  static const String _nativeAdUnitId = "ca-app-pub-9043208558525567/1007331074";
  static const String _appOpenAdUnitId = "ca-app-pub-9043208558525567/1677307119";

  // Use test ad units only in non-release builds (debug/profile)
  static bool get _useTestAds => !kReleaseMode;
  
  static String get bannerAdUnitId => _useTestAds 
      ? 'ca-app-pub-3940256099942544/6300978111' 
      : _bannerAdUnitId;
  
  static String get interstitialAdUnitId => _useTestAds 
      ? 'ca-app-pub-3940256099942544/1033173712' 
      : _interstitialAdUnitId;
  
  static String get rewardedAdUnitId => _useTestAds 
      ? 'ca-app-pub-3940256099942544/5224354917' 
      : _rewardedAdUnitId;
  
  static String get rewardedInterstitialAdUnitId => _useTestAds 
      ? 'ca-app-pub-3940256099942544/5354025313' 
      : _rewardedInterstitialAdUnitId;
  
  static String get nativeAdUnitId => _useTestAds 
      ? 'ca-app-pub-3940256099942544/2247696110' 
      : _nativeAdUnitId;
  
  static String get appOpenAdUnitId => _useTestAds 
      ? 'ca-app-pub-3940256099942544/3419835294' 
      : _appOpenAdUnitId;

  RewardedAd? _rewardedAd;
  RewardedInterstitialAd? _rewardedInterstitialAd;
  InterstitialAd? _interstitialAd;
  AppOpenAd? _appOpenAd;
  int _rewardAdWatchCount = 0;
  bool _isAppOpenAdReady = false;
  
  // Frequency capping - prevent ads from showing too frequently (AdMob policy)
  DateTime? _lastInterstitialAdShown;
  DateTime? _lastAppOpenAdShown;
  DateTime? _lastImageClickAdShown;
  
  static const Duration _minInterstitialInterval = Duration(seconds: 60); // 1 minute minimum
  static const Duration _minImageClickAdInterval = Duration(seconds: 30); // 30 seconds for image clicks
  static const Duration _minAppOpenAdInterval = Duration(minutes: 5); // 5 minutes for app open ads

  /// Check if user is a premium user (should not see ads)
  Future<bool> isPremiumUser() async {
    final userData = await UserService.instance.getUserData();
    return userData?.hasValidSubscription ?? false;
  }

  /// Check if ads should be shown (not premium user)
  Future<bool> shouldShowAds() async {
    return !(await isPremiumUser());
  }

  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    // Preload ads after initialization
    loadRewardedAd();
    loadInterstitialAd();
    loadRewardedInterstitialAd();
  }

  Future<void> loadRewardedAd() async {
    // Don't load if premium user
    if (await isPremiumUser()) return;
    
    await RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (error) {
          print('Rewarded ad failed to load: $error');
          _rewardedAd = null;
        },
      ),
    );
  }

  Future<void> loadRewardedInterstitialAd() async {
    // Don't load if premium user
    if (await isPremiumUser()) return;
    
    await RewardedInterstitialAd.load(
      adUnitId: rewardedInterstitialAdUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedInterstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          print('Rewarded interstitial ad failed to load: $error');
          _rewardedInterstitialAd = null;
        },
      ),
    );
  }

  Future<void> loadInterstitialAd() async {
    // Don't load if premium user
    if (await isPremiumUser()) return;
    
    await InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          print('Interstitial ad failed to load: $error');
          _interstitialAd = null;
        },
      ),
    );
  }

  Future<void> loadAppOpenAd() async {
    // Don't load if premium user
    if (await isPremiumUser()) {
      _isAppOpenAdReady = false;
      return;
    }
    
    await AppOpenAd.load(
      adUnitId: appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _isAppOpenAdReady = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _appOpenAd = null;
              _isAppOpenAdReady = false;
              loadAppOpenAd(); // Preload next app open ad
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _appOpenAd = null;
              _isAppOpenAdReady = false;
              loadAppOpenAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          print('App open ad failed to load: $error');
          _appOpenAd = null;
          _isAppOpenAdReady = false;
        },
      ),
    );
  }

  Future<bool> showRewardedAd({
    required Function() onRewarded,
    Function(String)? onError,
  }) async {
    // Skip if premium user
    if (await isPremiumUser()) {
      onRewarded();
      return true;
    }

    if (_rewardedAd == null) {
      await loadRewardedAd();
    }

    if (_rewardedAd == null) {
      onError?.call('Ad not loaded');
      return false;
    }

    bool rewarded = false;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        onError?.call(error.message);
        loadRewardedAd();
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) async {
        rewarded = true;
        _rewardAdWatchCount++;
        // Grant 1.2 credits for watching rewarded ad
        // Skip if user is in spending mode (they're using credits, ads won't grant credits)
        await UserService.instance.addCredits(1.2, skipIfInSpendingMode: true);
        onRewarded();
      },
    );

    return rewarded;
  }

  Future<bool> showRewardedInterstitialAd({
    required Function() onRewarded,
    Function(String)? onError,
  }) async {
    // Skip if premium user
    if (await isPremiumUser()) {
      onRewarded();
      return true;
    }

    if (_rewardedInterstitialAd == null) {
      await loadRewardedInterstitialAd();
    }

    if (_rewardedInterstitialAd == null) {
      // Fallback to regular rewarded ad
      return await showRewardedAd(onRewarded: onRewarded, onError: onError);
    }

    bool rewarded = false;

    _rewardedInterstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedInterstitialAd = null;
        loadRewardedInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedInterstitialAd = null;
        onError?.call(error.message);
        loadRewardedInterstitialAd();
      },
    );

    _rewardedInterstitialAd!.show(
      onUserEarnedReward: (ad, reward) async {
        rewarded = true;
        _rewardAdWatchCount++;
        // Grant 1.2 credits for watching rewarded interstitial ad
        // Skip if user is in spending mode (they're using credits, ads won't grant credits)
        await UserService.instance.addCredits(1.2, skipIfInSpendingMode: true);
        onRewarded();
      },
    );

    return rewarded;
  }

  Future<bool> showInterstitialAd({
    Function()? onAdClosed,
    Function(String)? onError,
    bool respectFrequencyCap = true,
  }) async {
    // Skip if premium user
    if (await isPremiumUser()) {
      onAdClosed?.call();
      return true;
    }

    // Frequency capping check
    if (respectFrequencyCap && _lastInterstitialAdShown != null) {
      final timeSinceLastAd = DateTime.now().difference(_lastInterstitialAdShown!);
      if (timeSinceLastAd < _minInterstitialInterval) {
        onAdClosed?.call(); // Continue without showing ad
        return false;
      }
    }

    if (_interstitialAd == null) {
      await loadInterstitialAd();
    }

    if (_interstitialAd == null) {
      onError?.call('Ad not loaded');
      onAdClosed?.call(); // Continue even if ad fails
      return false;
    }

    bool shown = false;
    _lastInterstitialAdShown = DateTime.now();

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        shown = true;
        onAdClosed?.call();
        loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        onError?.call(error.message);
        onAdClosed?.call(); // Continue even if ad fails
        loadInterstitialAd();
      },
    );

    _interstitialAd!.show();
    return shown;
  }

  /// Show interstitial ad on image click with frequency capping (30 seconds minimum)
  Future<bool> showInterstitialAdOnImageClick({
    Function()? onAdClosed,
    Function(String)? onError,
  }) async {
    // Skip if premium user
    if (await isPremiumUser()) {
      onAdClosed?.call();
      return true;
    }

    // Stricter frequency cap for image clicks (30 seconds)
    if (_lastImageClickAdShown != null) {
      final timeSinceLastAd = DateTime.now().difference(_lastImageClickAdShown!);
      if (timeSinceLastAd < _minImageClickAdInterval) {
        onAdClosed?.call(); // Continue without showing ad
        return false;
      }
    }

    if (_interstitialAd == null) {
      await loadInterstitialAd();
    }

    if (_interstitialAd == null) {
      onAdClosed?.call(); // Continue even if ad fails
      return false;
    }

    bool shown = false;
    _lastImageClickAdShown = DateTime.now();

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        shown = true;
        onAdClosed?.call();
        loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        onError?.call(error.message);
        onAdClosed?.call();
        loadInterstitialAd();
      },
    );

    _interstitialAd!.show();
    return shown;
  }

  Future<bool> showAppOpenAd() async {
    // Skip if premium user
    if (await isPremiumUser()) return false;

    // Frequency capping for app open ads (5 minutes minimum)
    if (_lastAppOpenAdShown != null) {
      final timeSinceLastAd = DateTime.now().difference(_lastAppOpenAdShown!);
      if (timeSinceLastAd < _minAppOpenAdInterval) {
        return false;
      }
    }

    if (!_isAppOpenAdReady || _appOpenAd == null) {
      await loadAppOpenAd();
      return false;
    }

    _lastAppOpenAdShown = DateTime.now();
    _appOpenAd!.show();
    return true;
  }

  /// Show a random ad (rewarded or rewarded interstitial) for freemium features
  Future<bool> showRandomAd({
    required Function() onRewarded,
    Function(String)? onError,
  }) async {
    // Skip if premium user
    if (await isPremiumUser()) {
      onRewarded();
      return true;
    }

    final random = Random();
    if (random.nextBool()) {
      return await showRewardedInterstitialAd(
        onRewarded: onRewarded, 
        onError: onError
      );
    } else {
      return await showRewardedAd(
        onRewarded: onRewarded, 
        onError: onError
      );
    }
  }

  /// Show random ad (rewarded, rewarded interstitial, or interstitial)
  /// This is used for the freemium "watch 2 ads" requirement
  Future<bool> showRandomFreemiumAd({
    required Function() onRewarded,
    Function(String)? onError,
  }) async {
    // Skip if premium user
    if (await isPremiumUser()) {
      onRewarded();
      return true;
    }

    final random = Random();
    final adType = random.nextInt(3);
    
    switch (adType) {
      case 0:
        return await showRewardedAd(
          onRewarded: onRewarded, 
          onError: onError
        );
      case 1:
        return await showRewardedInterstitialAd(
          onRewarded: onRewarded, 
          onError: onError
        );
      case 2:
        bool shown = await showInterstitialAd(
          onAdClosed: onRewarded,
          onError: onError,
        );
        if (shown) {
          onRewarded();
        }
        return shown;
      default:
        return await showRewardedAd(
          onRewarded: onRewarded, 
          onError: onError
        );
    }
  }

  int get rewardAdWatchCount => _rewardAdWatchCount;

  void resetRewardCount() {
    _rewardAdWatchCount = 0;
  }

  bool get isAppOpenAdReady => _isAppOpenAdReady;
}
