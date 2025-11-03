import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/cropped_image_provider.dart';
import '../../core/services/premium_image_service.dart';
import '../../core/services/user_service.dart';
import '../../core/services/ad_service.dart';
import '../auth/login_screen.dart';
import '../premium/premium_screen.dart';

class ImagePreviewScreen extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final String carName;

  const ImagePreviewScreen({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    required this.carName,
  });

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _isDownloading = false;
  bool _isSettingWallpaper = false;
  String? _statusMessage;
  
  // Cache for preloaded image providers
  final Map<int, ImageProvider> _preloadedImages = {};
  
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    
    // Preload current and adjacent images
    _preloadImages();
    
    // Listen to page changes to preload adjacent images
    _pageController.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    if (!_pageController.position.isScrollingNotifier.value) {
      final newIndex = _pageController.page?.round() ?? _currentIndex;
      if (newIndex != _currentIndex) {
        setState(() {
          _currentIndex = newIndex;
        });
        _preloadImages();
      }
    }
  }

  /// Preload current image and adjacent images (2 before, 2 after)
  Future<void> _preloadImages() async {
    final preloadIndices = [
      _currentIndex - 2,
      _currentIndex - 1,
      _currentIndex,
      _currentIndex + 1,
      _currentIndex + 2,
    ].where((index) => 
      index >= 0 && 
      index < widget.imageUrls.length &&
      !_preloadedImages.containsKey(index)
    ).toList();

    for (final index in preloadIndices) {
      final imageUrl = widget.imageUrls[index];
      // Preload cropped image in background
      CroppedImageCache.precacheImage(imageUrl, 0.05);
      // Get and cache the provider
      final provider = await CroppedImageCache.getCroppedImageProvider(imageUrl, 0.05);
      if (provider != null) {
        _preloadedImages[index] = provider;
      }
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _downloadImage() async {
    // Check eligibility
    final eligibility = await PremiumImageService.checkDownloadEligibility();
    
    if (eligibility['requiresSignIn'] == true) {
      _showSignInPrompt();
      return;
    }

    final availableCredits = (eligibility['availableCredits'] as num?)?.toDouble() ?? 0.0;
    final minCreditsNeeded = (eligibility['minCreditsNeeded'] as num?)?.toDouble() ?? 5.0;
    final creditsNeeded = (eligibility['creditsNeeded'] as num?)?.toDouble() ?? 1.0;
    final isInSpendingMode = eligibility['isInSpendingMode'] as bool? ?? false;

    // Check if user needs more credits (minimum 5 or action cost)
    if (eligibility['requiresCredits'] == true || eligibility['requiresAds'] == true) {
      if (availableCredits < minCreditsNeeded) {
        _showCreditsRequiredDialog(
          availableCredits: availableCredits,
          minCreditsNeeded: minCreditsNeeded,
          message: eligibility['message'] as String?,
          isInSpendingMode: isInSpendingMode,
        );
        return;
      } else if (availableCredits < creditsNeeded) {
        _showCreditsRequiredDialog(
          availableCredits: availableCredits,
          minCreditsNeeded: creditsNeeded,
          message: 'You need ${creditsNeeded.toInt()} credit for this action.',
          isInSpendingMode: isInSpendingMode,
        );
        return;
      }
    }

    setState(() {
      _isDownloading = true;
      _statusMessage = 'Processing...';
    });

    try {
      final imageUrl = widget.imageUrls[_currentIndex];
      
      final success = await PremiumImageService.downloadImage(
        imageUrl: imageUrl,
        carName: widget.carName,
        onStatusUpdate: (message) {
          if (mounted) {
            setState(() {
              _statusMessage = message;
            });
          }
        },
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Image downloaded successfully' : _statusMessage ?? 'Failed to download'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _downloadAllImages() async {
    final userData = await UserService.instance.getUserData();
    
    if (userData == null) {
      _showSignInPrompt();
      return;
    }

    if (!userData.hasValidSubscription) {
      _showProRequiredDialog();
      return;
    }

    final totalCost = widget.imageUrls.length * 1.0; // 1 credit per image
    final minCredits = 5.0; // Minimum required
    
    if (userData.isInSpendingMode) {
      // In spending mode, can use remaining credits
      if (userData.credits <= 0) {
        _showCreditsRequiredDialog(
          availableCredits: userData.credits,
          minCreditsNeeded: minCredits,
          message: 'No credits remaining. Watch ads to earn credits or subscribe to Pro.',
          isInSpendingMode: true,
        );
        return;
      }
    } else {
      // Not in spending mode
      if (userData.credits < minCredits) {
        _showCreditsRequiredDialog(
          availableCredits: userData.credits,
          minCreditsNeeded: minCredits,
          message: 'You need at least ${minCredits.toInt()} credits to download images. Watch ads to earn credits or subscribe to Pro.',
          isInSpendingMode: false,
        );
        return;
      }
      
      if (userData.credits < totalCost) {
        _showCreditsRequiredDialog(
          availableCredits: userData.credits,
          minCreditsNeeded: totalCost,
          message: 'You need ${totalCost.toInt()} credits to download ${widget.imageUrls.length} images (${totalCost.toInt()} credits total).',
          isInSpendingMode: false,
        );
        return;
      }
    }

    setState(() {
      _isDownloading = true;
      _statusMessage = 'Processing...';
    });

    try {
      final success = await PremiumImageService.downloadAllImages(
        imageUrls: widget.imageUrls,
        carName: widget.carName,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _statusMessage = 'Downloading: $current / $total';
            });
          }
        },
        onStatusUpdate: (message) {
          if (mounted) {
            setState(() {
              _statusMessage = message;
            });
          }
        },
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'All images downloaded successfully' : _statusMessage ?? 'Some images failed'),
            backgroundColor: success ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _setWallpaper() async {
    final eligibility = await PremiumImageService.checkDownloadEligibility();
    
    if (eligibility['requiresSignIn'] == true) {
      _showSignInPrompt();
      return;
    }

    final availableCredits = (eligibility['availableCredits'] as num?)?.toDouble() ?? 0.0;
    final minCreditsNeeded = (eligibility['minCreditsNeeded'] as num?)?.toDouble() ?? 5.0;
    final creditsNeeded = (eligibility['creditsNeeded'] as num?)?.toDouble() ?? 1.0;
    final isInSpendingMode = eligibility['isInSpendingMode'] as bool? ?? false;

    // Check if user needs more credits (minimum 5 or action cost)
    if (eligibility['requiresCredits'] == true || eligibility['requiresAds'] == true) {
      if (availableCredits < minCreditsNeeded) {
        _showCreditsRequiredDialog(
          availableCredits: availableCredits,
          minCreditsNeeded: minCreditsNeeded,
          message: eligibility['message'] as String?,
          isInSpendingMode: isInSpendingMode,
        );
        return;
      } else if (availableCredits < creditsNeeded) {
        _showCreditsRequiredDialog(
          availableCredits: availableCredits,
          minCreditsNeeded: creditsNeeded,
          message: 'You need ${creditsNeeded.toInt()} credit for this action.',
          isInSpendingMode: isInSpendingMode,
        );
        return;
      }
    }

    setState(() {
      _isSettingWallpaper = true;
      _statusMessage = 'Processing...';
    });

    try {
      final imageUrl = widget.imageUrls[_currentIndex];
      final success = await PremiumImageService.setWallpaper(
        imageUrl: imageUrl,
        carName: widget.carName,
        onStatusUpdate: (message) {
          if (mounted) {
            setState(() {
              _statusMessage = message;
            });
          }
        },
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Wallpaper set successfully' : _statusMessage ?? 'Failed'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSettingWallpaper = false;
          _statusMessage = null;
        });
      }
    }
  }

  void _showSignInPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign In Required'),
        content: const Text('Please sign in to download images or set wallpapers.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  void _showCreditsRequiredDialog({
    required double availableCredits,
    required double minCreditsNeeded,
    String? message,
    bool? isInSpendingMode,
  }) async {
    final theme = Theme.of(context);
    final userData = await UserService.instance.getUserData();
    final spendingMode = isInSpendingMode ?? userData?.isInSpendingMode ?? false;
    
    String dialogTitle;
    String dialogMessage;
    List<Widget> dialogActions;
    
    if (spendingMode && availableCredits > 0) {
      // User is in spending mode - can use remaining credits but ads won't grant credits
      dialogTitle = 'Using Remaining Credits';
      dialogMessage = 'You\'re in spending mode. You can continue using your ${availableCredits.toStringAsFixed(1)} credits.\n\n'
          'Ads will be shown but won\'t grant credits until you reach 5 credits again.';
      dialogActions = [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            // User can proceed to use their remaining credits
          },
          child: const Text('Continue'),
        ),
      ];
    } else {
      // Normal mode - need to watch ads to earn credits
      final creditsNeeded = (minCreditsNeeded - availableCredits).ceil();
      final adsNeeded = (creditsNeeded / 1.2).ceil(); // Each ad gives 1.2 credits
      dialogTitle = 'Credits Required';
      dialogMessage = message ?? 'You need at least ${minCreditsNeeded.toInt()} credits.\n\n'
          'Watch $adsNeeded ad${adsNeeded > 1 ? 's' : ''} to earn ${creditsNeeded} credit${creditsNeeded > 1 ? 's' : ''} (1.2 credits per ad)';
      dialogActions = [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            await _watchAd();
          },
          child: Text('Watch Ad${adsNeeded > 1 ? 's' : ''}'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PremiumScreen()),
            );
          },
          child: const Text('Subscribe'),
        ),
      ];
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(dialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dialogMessage,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Current Credits: ${availableCredits.toStringAsFixed(1)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!spendingMode || availableCredits <= 0) ...[
              const SizedBox(height: 8),
              Text(
                'Minimum Required: ${minCreditsNeeded.toInt()} credits',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.error,
                ),
              ),
              if (!spendingMode) ...[
                const SizedBox(height: 8),
                Text(
                  'Or subscribe to Pro to purchase credits',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ] else ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Note: Ads shown during spending mode won\'t grant credits',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: dialogActions,
      ),
    );
  }

  void _showProRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pro Subscription Required'),
        content: const Text('Downloading all images requires a Pro subscription.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PremiumScreen()),
              );
            },
            child: const Text('View Plans'),
          ),
        ],
      ),
    );
  }

  Future<void> _watchAd() async {
    final userDataBefore = await UserService.instance.getUserData();
    final creditsBefore = userDataBefore?.credits ?? 0.0;
    final isInSpendingModeBefore = userDataBefore?.isInSpendingMode ?? false;
    
    final shown = await AdService.instance.showRandomFreemiumAd(
      onRewarded: () async {
        // Refresh user data to get updated credits
        final userDataAfter = await UserService.instance.getUserData();
        final creditsAfter = userDataAfter?.credits ?? 0.0;
        final creditsEarned = creditsAfter - creditsBefore;
        
        if (mounted) {
          if (isInSpendingModeBefore) {
            // User is in spending mode - ads were shown but no credits granted
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Ad watched. No credits granted (spending mode).\n'
                  'Continue using your ${creditsAfter.toStringAsFixed(1)} credits.',
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  creditsEarned > 0
                      ? 'Ad watched! You earned ${creditsEarned.toStringAsFixed(1)} credits.\n'
                          'Total credits: ${creditsAfter.toStringAsFixed(1)}'
                      : 'Ad watched. Total credits: ${creditsAfter.toStringAsFixed(1)}',
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ad error: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );

    if (!shown && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ad not available. Please try again later.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Photo gallery with preloaded cropped images
          PhotoViewGallery.builder(
            pageController: _pageController,
            scrollPhysics: const BouncingScrollPhysics(),
            builder: (BuildContext context, int index) {
              final imageUrl = widget.imageUrls[index];
              
              // Use cached provider if available
              if (_preloadedImages.containsKey(index)) {
                return PhotoViewGalleryPageOptions(
                  imageProvider: _preloadedImages[index]!,
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3.0,
                  initialScale: PhotoViewComputedScale.contained,
                  // Removed heroAttributes to avoid nested Hero widget error
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: Responsive.scaleWidth(context, 64),
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }
              
              // Load on demand with FutureBuilder
              return PhotoViewGalleryPageOptions.customChild(
                child: FutureBuilder<ImageProvider?>(
                  future: CroppedImageCache.getCroppedImageProvider(imageUrl, 0.05),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      // Cache the provider for future use
                      _preloadedImages[index] = snapshot.data!;
                      // Preload adjacent images in background
                      _preloadImages();
                      
                      return PhotoView(
                        imageProvider: snapshot.data!,
                        minScale: PhotoViewComputedScale.contained,
                        maxScale: PhotoViewComputedScale.covered * 3.0,
                        initialScale: PhotoViewComputedScale.contained,
                        // Removed heroAttributes to avoid nested Hero widget error
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: double.infinity,
                          height: double.infinity,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              size: Responsive.scaleWidth(context, 64),
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      );
                    }
                    // Show loading while fetching
                    return Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Colors.black,
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3.0,
                initialScale: PhotoViewComputedScale.contained,
                // Removed heroAttributes to avoid nested Hero widget error
              );
            },
            itemCount: widget.imageUrls.length,
            loadingBuilder: (context, event) => Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black,
              child: Center(
                child: CircularProgressIndicator(
                  value: event == null
                      ? null
                      : event.cumulativeBytesLoaded /
                          (event.expectedTotalBytes ?? 1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
              // Preload adjacent images when page changes
              _preloadImages();
            },
          ),

          // Watermark overlay at center
          SafeArea(
            child: IgnorePointer(
              child: Center(
                child: Opacity(
                  opacity: 0.8,
                  child: Image.asset(
                    'assets/images/watermark.png',
                    width: Responsive.scaleWidth(context, 150),
                    height: Responsive.scaleHeight(context, 150),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

          // Top bar with close button and actions
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(Responsive.scaleWidth(context, 12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon:
                          const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  if (widget.imageUrls.length > 1)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.scaleWidth(context, 16),
                        vertical: Responsive.scaleHeight(context, 8),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(
                          Responsive.scaleWidth(context, 20),
                        ),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${widget.imageUrls.length}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: _isSettingWallpaper
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.wallpaper_rounded, color: Colors.white),
                          onPressed: _isSettingWallpaper ? null : _setWallpaper,
                          tooltip: 'Set as wallpaper',
                        ),
                      ),
                      SizedBox(width: Responsive.scaleWidth(context, 8)),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: _isDownloading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.download_rounded, color: Colors.white),
                          onPressed: _isDownloading ? null : _downloadImage,
                          tooltip: 'Download image',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom bar with car name and download all button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: EdgeInsets.all(Responsive.scaleWidth(context, 16)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.carName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.imageUrls.length > 1)
                      StreamBuilder<UserData?>(
                        stream: UserService.instance.currentUserData,
                        builder: (context, snapshot) {
                          final userData = snapshot.data;
                          final canDownloadAll = userData?.hasValidSubscription ?? false;
                          
                          if (!canDownloadAll) {
                            return Padding(
                              padding: EdgeInsets.only(top: Responsive.scaleHeight(context, 12)),
                              child: OutlinedButton.icon(
                                onPressed: () => _showProRequiredDialog(),
                                icon: const Icon(Icons.star_rounded),
                                label: const Text('Pro: Download All'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.amber),
                                ),
                              ),
                            );
                          }
                          
                          return Padding(
                            padding: EdgeInsets.only(top: Responsive.scaleHeight(context, 12)),
                            child: ElevatedButton.icon(
                              onPressed: _isDownloading ? null : _downloadAllImages,
                              icon: _isDownloading
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Icon(Icons.download_rounded),
                              label: Text(_isDownloading ? (_statusMessage ?? 'Downloading...') : 'Download All Images'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.2),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
