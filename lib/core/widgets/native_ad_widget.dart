import 'package:carcollection/core/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';
import '../services/user_service.dart';

/// Native ad widget that automatically hides for premium users
/// Uses default AdMob settings with no custom modifications
class NativeAdWidget extends StatefulWidget {
  const NativeAdWidget({
    super.key,
  });

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  bool _isPremiumUser = false;
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoaded) {
      _hasLoaded = true;
      _loadNativeAd();
    }
  }

  Future<void> _checkPremiumStatus() async {
    final userData = await UserService.instance.getUserData();
    final isPremium = userData?.hasValidSubscription ?? false;

    if (mounted) {
      setState(() {
        _isPremiumUser = isPremium;
      });

      // If user becomes premium, dispose ad
      if (isPremium && _nativeAd != null) {
        _nativeAd!.dispose();
        _nativeAd = null;
        _isAdLoaded = false;
      }
    }
  }

  void _loadNativeAd() {
    // Don't load if premium user
    if (_isPremiumUser) return;

    // Use default AdMob template style - required for native ads to render
    // Using default template without any custom colors or styling modifications
    _nativeAd = NativeAd(
      adUnitId: AdService.nativeAdUnitId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          print('Native ad failed to load: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _isAdLoaded = false;
              _nativeAd = null;
            });
          }
        },
        onAdOpened: (_) {
          print('Native ad opened');
        },
        onAdClosed: (_) {
          print('Native ad closed');
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        // No custom colors or styling - using AdMob defaults
      ),
    );

    _nativeAd!.load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Don't show ad if premium user
    if (_isPremiumUser) {
      return const SizedBox.shrink();
    }

    if (!_isAdLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    // Use default AdMob settings - no custom containers, labels, margins, padding, or decorations
    return SizedBox(
      width: Responsive.width(context),
      height: Responsive.scaleHeight(context, 340),
      child: AdWidget(ad: _nativeAd!),
    );
  }
}
