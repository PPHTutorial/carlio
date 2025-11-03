import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';
import '../services/user_service.dart';

/// Banner ad widget that automatically hides for premium users
class BannerAdWidget extends StatefulWidget {
  final AdSize? adSize;
  
  const BannerAdWidget({
    super.key,
    this.adSize,
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _isPremiumUser = false;

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
    _loadBannerAd();
  }

  Future<void> _checkPremiumStatus() async {
    final userData = await UserService.instance.getUserData();
    final isPremium = userData?.hasValidSubscription ?? false;
    
    if (mounted) {
      setState(() {
        _isPremiumUser = isPremium;
      });
      
      // If user becomes premium, dispose ad
      if (isPremium && _bannerAd != null) {
        _bannerAd!.dispose();
        _bannerAd = null;
        _isAdLoaded = false;
      }
    }
  }

  void _loadBannerAd() async {
    // Don't load if premium user
    if (_isPremiumUser) return;
    
    final adSize = widget.adSize ?? AdSize.banner;
    
    _bannerAd = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          print('Banner ad failed to load: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _isAdLoaded = false;
              _bannerAd = null;
            });
          }
        },
        onAdOpened: (_) {
          print('Banner ad opened');
        },
        onAdClosed: (_) {
          print('Banner ad closed');
        },
      ),
    );

    _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Don't show ad if premium user
    if (_isPremiumUser) {
      return const SizedBox.shrink();
    }

    if (!_isAdLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    final adSize = widget.adSize ?? AdSize.banner;
    
    return Container(
      alignment: Alignment.center,
      width: adSize.width.toDouble(),
      height: adSize.height.toDouble(),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
