import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';
import '../services/user_service.dart';
import '../utils/responsive.dart';

/// Native ad widget that automatically hides for premium users
class NativeAdWidget extends StatefulWidget {
  final AdSize adSize;
  final double? height;
  
  const NativeAdWidget({
    super.key,
    this.adSize = const AdSize(width: 320, height: 250),
    this.height,
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

    final theme = Theme.of(context);

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
        mainBackgroundColor: theme.colorScheme.surfaceContainerHighest,
        cornerRadius: 12.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: theme.colorScheme.onPrimary,
          style: NativeTemplateFontStyle.bold,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: theme.colorScheme.onSurface,
          style: NativeTemplateFontStyle.bold,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: theme.colorScheme.onSurfaceVariant,
          style: NativeTemplateFontStyle.normal,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: theme.colorScheme.onSurfaceVariant,
          style: NativeTemplateFontStyle.normal,
        ),
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

    final height = widget.height ?? widget.adSize.height.toDouble();
    
    return Container(
      alignment: Alignment.center,
      width: double.infinity,
      height: height,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.scaleWidth(context, 16),
        vertical: Responsive.scaleHeight(context, 8),
      ),
      child: AdWidget(ad: _nativeAd!),
    );
  }
}
