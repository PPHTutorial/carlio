import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/image_utils.dart';
import '../../core/widgets/watermarked_image.dart';
import '../../core/widgets/banner_ad_widget.dart';
import '../../core/services/favorites_service.dart';
import '../../core/services/bookmarks_service.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/car_sound_service.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/ar_service.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/share_service.dart';
import '../../core/services/car_service.dart';
import '../../models/car_data.dart';
import 'image_preview_screen.dart';
import 'specs_compare_screen.dart';

class CarDetailScreen extends StatefulWidget {
  final CarData car;
  final List<CarData>? allCars;

  const CarDetailScreen({
    super.key,
    required this.car,
    this.allCars,
  });

  @override
  State<CarDetailScreen> createState() => _CarDetailScreenState();
}

class _CarDetailScreenState extends State<CarDetailScreen> {
  int _currentImageIndex = 0;
  bool _isFavorite = false;
  bool _isBookmarked = false;
  bool _isLoadingFavorite = false;
  bool _isLoadingBookmark = false;
  bool _isPlayingSound = false;
  bool _isGeneratingAISummary = false;
  String? _aiSummary;
  final AudioService _audioService = AudioService();
  final FavoritesService _favoritesService = FavoritesService.instance;
  final BookmarksService _bookmarksService = BookmarksService.instance;
  final CarSoundService _carSoundService = CarSoundService();
  final CarService _carService = CarService();

  @override
  void initState() {
    super.initState();
    _loadFavoriteStatus();
    _loadBookmarkStatus();
    // Show app open ad on detail screen
    _showAppOpenAd();
  }

  Future<void> _showAppOpenAd() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      AdService.instance.showAppOpenAd();
    }
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  /// Handle back navigation with optional interstitial ad
  Future<void> _handleBackNavigation() async {
    // Show interstitial ad when navigating back (only for free users)
    final shouldShowAd = await AdService.instance.shouldShowAds();

    if (shouldShowAd) {
      await AdService.instance.showInterstitialAd(
        onAdClosed: () {
          if (mounted) {
            Navigator.pop(context);
          }
        },
        onError: (error) {
          // Navigate back even if ad fails
          if (mounted) {
            Navigator.pop(context);
          }
        },
      );
    } else {
      // Premium users navigate back immediately
      Navigator.pop(context);
    }
  }

  Future<void> _loadFavoriteStatus() async {
    final isFav = await _favoritesService.isFavorite(widget.car.id);
    if (mounted) {
      setState(() {
        _isFavorite = isFav;
      });
    }
  }

  Future<void> _loadBookmarkStatus() async {
    final isBookmarked = await _bookmarksService.isBookmarked(widget.car.id);
    if (mounted) {
      setState(() {
        _isBookmarked = isBookmarked;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    setState(() {
      _isLoadingFavorite = true;
    });

    await _favoritesService.toggleFavorite(widget.car.id);
    final isFav = await _favoritesService.isFavorite(widget.car.id);

    if (mounted) {
      setState(() {
        _isFavorite = isFav;
        _isLoadingFavorite = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(isFav ? 'Added to favorites' : 'Removed from favorites'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _toggleBookmark() async {
    setState(() {
      _isLoadingBookmark = true;
    });

    await _bookmarksService.toggleBookmark(widget.car.id);
    final isBookmarked = await _bookmarksService.isBookmarked(widget.car.id);

    if (mounted) {
      setState(() {
        _isBookmarked = isBookmarked;
        _isLoadingBookmark = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isBookmarked
              ? 'Article bookmarked'
              : 'Article removed from bookmarks'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _playEngineSound() async {
    if (_isPlayingSound) {
      await _audioService.stop();
      if (mounted) {
        setState(() {
          _isPlayingSound = false;
        });
      }
      return;
    }

    try {
      // Get or assign sound for this car using CarSoundService
      final soundAssetPath = await _carSoundService.getOrAssignSound(widget.car.id);

      if (soundAssetPath.isNotEmpty) {
        // Play sound from asset
        await _audioService.playEngineSoundFromAsset(soundAssetPath);
        
        if (mounted) {
          setState(() {
            _isPlayingSound = true;
          });
        }

        // Note: State listener is handled in AudioService
        // We'll check the playing state periodically or use a timer
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_audioService.isPlaying) {
            setState(() {
              _isPlayingSound = false;
            });
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Engine sound not available for this car'),
            ),
          );
        }
      }
    } catch (e) {
      print('Error playing engine sound: $e');
      if (mounted) {
        setState(() {
          _isPlayingSound = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing engine sound: $e'),
          ),
        );
      }
    }
  }

  Future<void> _launchARView(BuildContext context) async {
    try {
      final imageUrls = widget.car.imgs.map((imgId) {
        return ImageUtils.getCarLargeImageUrl(
          widget.car.id,
          widget.car.slug,
          imgId,
        );
      }).toList();

      await ARService.launchARView(
        carModel: widget.car.id,
        carName: widget.car.name,
        imageUrls: imageUrls,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AR not available: ${e.toString()}'),
          ),
        );
      }
    }
  }

  Future<void> _generateAISummary() async {
    if (_aiSummary != null) return;

    setState(() {
      _isGeneratingAISummary = true;
    });

    try {
      final summary = await AIService.generateCarPersonalitySummary(
        carName: widget.car.name,
        engineType: widget.car.data.engineType,
        producedIn: widget.car.producedIn > 0 ? widget.car.producedIn : null,
        countryOfOrigin: widget.car.data.countryOfOrigin,
        article: widget.car.data.article,
      );

      if (mounted) {
        setState(() {
          _aiSummary = summary;
          _isGeneratingAISummary = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGeneratingAISummary = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error generating AI summary'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildHeroSliderAppBar(context, theme),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                //_buildBasicInfo(context, theme),
                if (widget.car.specs.isNotEmpty)
                  _buildSpecificationsButton(context, theme),
                _buildActionButtons(context, theme),
                // Banner ad below action buttons and before details card
                const BannerAdWidget(),
                _buildDetails(context, theme),
                if (widget.car.data.article != null &&
                    widget.car.data.article!.isNotEmpty)
                  _buildAISummary(context, theme),
                if (widget.car.data.article != null &&
                    widget.car.data.article!.isNotEmpty)
                  //_buildArticle(context, theme),
                  SizedBox(height: Responsive.scaleHeight(context, 16)),
                // Banner ad at bottom (only for free users)
                const BannerAdWidget(),
                SizedBox(height: Responsive.scaleHeight(context, 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSliderAppBar(BuildContext context, ThemeData theme) {
    final heroHeight = Responsive.scaleHeight(context, 400) * 0.75;

    if (widget.car.imgs.isEmpty) {
      return SliverAppBar(
        expandedHeight: heroHeight,
        pinned: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: Container(
          margin: EdgeInsets.all(Responsive.scaleWidth(context, 8)),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _handleBackNavigation,
          ),
        ),
        flexibleSpace: FlexibleSpaceBar(
          background: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary.withOpacity(0.3),
                  theme.colorScheme.primaryContainer.withOpacity(0.3),
                ],
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                left: Responsive.scaleWidth(context, 16),
                right: Responsive.scaleWidth(context, 16),
                bottom: Responsive.scaleHeight(context, 16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    widget.car.name,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SliverAppBar(
      expandedHeight: heroHeight,
      pinned: true,
      elevation: 0,
      toolbarHeight: 0, // Remove toolbar to flush hero to top (like dashboard)
      backgroundColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.light,

      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            CarouselSlider.builder(
              itemCount: widget.car.imgs.length,
              itemBuilder: (context, index, realIndex) {
                final imageUrl = ImageUtils.getCarLargeImageUrl(
                  widget.car.id,
                  widget.car.slug,
                  widget.car.imgs[index],
                );
                return GestureDetector(
                  onTap: () async {
                    final imageUrls = widget.car.imgs.map((imgId) {
                      return ImageUtils.getCarLargeImageUrl(
                        widget.car.id,
                        widget.car.slug,
                        imgId,
                      );
                    }).toList();

                    // Show interstitial ad on image click (with frequency capping)
                    await AdService.instance.showInterstitialAdOnImageClick(
                      onAdClosed: () {
                        // Navigate after ad is closed or skipped
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ImagePreviewScreen(
                              imageUrls: imageUrls,
                              initialIndex: _currentImageIndex,
                              carName: widget.car.name,
                            ),
                          ),
                        );
                      },
                    );
                  },
                  child: WatermarkedImage(
                    image: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.colorScheme.primary.withOpacity(0.3),
                              theme.colorScheme.primaryContainer
                                  .withOpacity(0.3),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
              options: CarouselOptions(
                height: double.infinity,
                viewportFraction: 1.0,
                enlargeCenterPage: false,
                autoPlay: widget.car.imgs.length > 1,
                autoPlayInterval: const Duration(seconds: 5),
                enableInfiniteScroll: widget.car.imgs.length > 1,
                onPageChanged: (index, reason) {
                  setState(() {
                    _currentImageIndex = index;
                  });
                },
              ),
            ),

            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
            ),
            // Navigation buttons positioned absolutely at top (like dashboard)
            Positioned(
              top: MediaQuery.of(context).padding.top,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  Container(
                    margin: EdgeInsets.all(Responsive.scaleWidth(context, 8)),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: _handleBackNavigation,
                    ),
                  ),
                  // Action buttons (share, favorite, bookmark)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        margin:
                            EdgeInsets.all(Responsive.scaleWidth(context, 8)),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.share_rounded,
                              color: Colors.white),
                          onPressed: () async {
                            await ShareService().shareCar(
                              carName: widget.car.name,
                              imageUrl: widget.car.imgs.isNotEmpty
                                  ? ImageUtils.getCarLargeImageUrl(
                                      widget.car.id,
                                      widget.car.slug,
                                      widget.car.imgs[0],
                                    )
                                  : null,
                            );
                          },
                        ),
                      ),
                      Container(
                        margin:
                            EdgeInsets.all(Responsive.scaleWidth(context, 8)),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: _isLoadingFavorite
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Icon(
                                  _isFavorite
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color:
                                      _isFavorite ? Colors.red : Colors.white,
                                ),
                          onPressed:
                              _isLoadingFavorite ? null : _toggleFavorite,
                        ),
                      ),
                      if (widget.car.data.article != null &&
                          widget.car.data.article!.isNotEmpty)
                        Container(
                          margin:
                              EdgeInsets.all(Responsive.scaleWidth(context, 8)),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: _isLoadingBookmark
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : Icon(
                                    _isBookmarked
                                        ? Icons.bookmark_rounded
                                        : Icons.bookmark_border_rounded,
                                    color: _isBookmarked
                                        ? Colors.amber
                                        : Colors.white,
                                  ),
                            onPressed:
                                _isLoadingBookmark ? null : _toggleBookmark,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Title and badges overlay (ignoring pointer so taps pass through)
            IgnorePointer(
              child: Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top +
                      Responsive.scaleHeight(
                          context, 56), // Account for button row
                  left: Responsive.scaleWidth(context, 16),
                  right: Responsive.scaleWidth(context, 16),
                  bottom: Responsive.scaleHeight(context, 16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Image indicator at top
                    if (widget.car.imgs.length > 1)
                      Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width -
                              (Responsive.padding(context).horizontal * 8),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: widget.car.imgs.length > 15
                              ? const BouncingScrollPhysics()
                              : const NeverScrollableScrollPhysics(),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              widget.car.imgs.length,
                              (index) => Container(
                                width: Responsive.scaleWidth(context,
                                    widget.car.imgs.length > 15 ? 6 : 8),
                                height: Responsive.scaleWidth(context,
                                    widget.car.imgs.length > 15 ? 6 : 8),
                                margin: EdgeInsets.symmetric(
                                  horizontal: Responsive.scaleWidth(context,
                                      widget.car.imgs.length > 15 ? 2 : 4),
                                ),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _currentImageIndex == index
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Title and badges at bottom
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                       // SizedBox(height: Responsive.scaleHeight(context, 80)),
                        Text(
                          widget.car.name,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.7),
                                blurRadius: 12,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: Responsive.scaleHeight(context, 12)),
                        Wrap(
                          spacing: Responsive.scaleWidth(context, 8),
                          runSpacing: Responsive.scaleHeight(context, 8),
                          children: [
                            if (widget.car.data.countryOfOrigin != null)
                              _buildHeroDetailBadge(
                                context,
                                theme,
                                Icons.place_rounded,
                                widget.car.data.countryOfOrigin!,
                              ),
                            if (widget.car.producedIn > 0)
                              _buildHeroDetailBadge(
                                context,
                                theme,
                                Icons.calendar_today_rounded,
                                widget.car.producedIn.toString(),
                              ),
                            if (widget.car.data.engineType != null)
                              _buildHeroDetailBadge(
                                context,
                                theme,
                                Icons.bolt_rounded,
                                widget.car.data.engineType!,
                              ),
                            if (widget.car.numberOfShots > 0)
                              _buildHeroDetailBadge(
                                context,
                                theme,
                                Icons.photo_library_rounded,
                                '${widget.car.numberOfShots} photos',
                              ),
                          ],
                        ),
                        SizedBox(height: Responsive.scaleHeight(context, 20)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroDetailBadge(
      BuildContext context, ThemeData theme, IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.scaleWidth(context, 12),
        vertical: Responsive.scaleHeight(context, 6),
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(Responsive.scaleWidth(context, 12)),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: Responsive.fontSize(context, 14),
            color: Colors.white,
          ),
          SizedBox(width: Responsive.scaleWidth(context, 6)),
          Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfo(BuildContext context, ThemeData theme) {
    final padding = Responsive.padding(context);

    return Container(
      padding: padding,
      child: Wrap(
        spacing: Responsive.scaleWidth(context, 12),
        runSpacing: Responsive.scaleHeight(context, 12),
        children: [
          if (widget.car.data.countryOfOrigin != null)
            _buildPremiumChip(
              context,
              theme,
              Icons.place_rounded,
              widget.car.data.countryOfOrigin!,
              theme.colorScheme.primary,
            ),
          if (widget.car.producedIn > 0)
            _buildPremiumChip(
              context,
              theme,
              Icons.calendar_today_rounded,
              widget.car.producedIn.toString(),
              theme.colorScheme.secondary,
            ),
          if (widget.car.data.engineType != null)
            _buildPremiumChip(
              context,
              theme,
              Icons.bolt_rounded,
              widget.car.data.engineType!,
              theme.colorScheme.tertiary,
            ),
          if (widget.car.numberOfShots > 0)
            _buildPremiumChip(
              context,
              theme,
              Icons.photo_library_rounded,
              '${widget.car.numberOfShots} photos',
              theme.colorScheme.primaryContainer,
            ),
        ],
      ),
    );
  }

  Widget _buildPremiumChip(
    BuildContext context,
    ThemeData theme,
    IconData icon,
    String label,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.scaleWidth(context, 16),
        vertical: Responsive.scaleHeight(context, 10),
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(Responsive.scaleWidth(context, 24)),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: Responsive.fontSize(context, 18),
            color: color,
          ),
          SizedBox(width: Responsive.scaleWidth(context, 8)),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails(BuildContext context, ThemeData theme) {
    final padding = Responsive.padding(context);
    final details = widget.car.data;

    final detailItems = <_DetailItem>[];

    if (details.numbersBuilt != null) {
      detailItems.add(_DetailItem('Numbers Built', details.numbersBuilt!));
    }
    if (details.designedBy != null) {
      detailItems.add(_DetailItem('Designed By', details.designedBy!));
    }
    if (details.source != null) {
      detailItems.add(_DetailItem('Source', details.source!));
    }
    if (details.lastUpdated != null) {
      detailItems.add(_DetailItem('Last Updated', details.lastUpdated!));
    }

    if (detailItems.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(
        top: Responsive.scaleHeight(context, 8),
        bottom: Responsive.scaleHeight(context, 8),
      ),
      padding: padding,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius:
              BorderRadius.circular(Responsive.scaleWidth(context, 16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(Responsive.scaleWidth(context, 16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Details',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: Responsive.scaleHeight(context, 24)),
              ...detailItems.map((item) => _buildPremiumDetailRow(
                    context,
                    theme,
                    item.label,
                    item.value,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumDetailRow(
    BuildContext context,
    ThemeData theme,
    String label,
    String value,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.scaleHeight(context, 10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: Responsive.scaleWidth(context, 140),
            child: Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArticle(BuildContext context, ThemeData theme) {
    final padding = Responsive.padding(context);
    final article = widget.car.data.article!;

    // Split article into paragraphs
    final paragraphs = article
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return Container(
      margin:
          EdgeInsets.symmetric(vertical: Responsive.scaleHeight(context, 8)),
      padding: padding,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius:
              BorderRadius.circular(Responsive.scaleWidth(context, 16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(Responsive.scaleWidth(context, 16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'About',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: Responsive.scaleHeight(context, 24)),
              ...paragraphs.map((paragraph) => Padding(
                    padding: EdgeInsets.only(
                      bottom: Responsive.scaleHeight(context, 16),
                    ),
                    child: Text(
                      paragraph,
                      textAlign: TextAlign.justify,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.8,
                        letterSpacing: 0.3,
                        wordSpacing: 1.2,
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, ThemeData theme) {
    final padding = Responsive.padding(context);

    return Container(
      margin: EdgeInsets.symmetric(
        vertical: Responsive.scaleHeight(context, 8),
      ),
      padding: padding,
      child: Wrap(
        spacing: Responsive.scaleWidth(context, 12),
        runSpacing: Responsive.scaleHeight(context, 12),
        alignment: WrapAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: _playEngineSound,
            icon: Icon(
                _isPlayingSound ? Icons.stop_rounded : Icons.volume_up_rounded),
            label: Text(_isPlayingSound ? 'Stop Sound' : 'Engine Sound'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.scaleWidth(context, 20),
                vertical: Responsive.scaleHeight(context, 12),
              ),
            ),
          ),
          FutureBuilder<bool>(
            future: ARService.isARSupported(),
            builder: (context, snapshot) {
              if (snapshot.data == true) {
                return ElevatedButton.icon(
                  onPressed: () => _launchARView(context),
                  icon: const Icon(Icons.view_in_ar_rounded),
                  label: const Text('View in AR'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.scaleWidth(context, 20),
                      vertical: Responsive.scaleHeight(context, 12),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          if (widget.car.specs.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () => _showSpecificationsButton(context, theme),
              icon: const Icon(Icons.compare_arrows_rounded),
              label: const Text('Compare Specs'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.scaleWidth(context, 20),
                  vertical: Responsive.scaleHeight(context, 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAISummary(BuildContext context, ThemeData theme) {
    final padding = Responsive.padding(context);

    return Container(
      margin: EdgeInsets.symmetric(
        vertical: Responsive.scaleHeight(context, 8),
      ),
      padding: padding,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius:
              BorderRadius.circular(Responsive.scaleWidth(context, 16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(Responsive.scaleWidth(context, 16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: theme.colorScheme.primary,
                        size: Responsive.fontSize(context, 24),
                      ),
                      SizedBox(width: Responsive.scaleWidth(context, 8)),
                      Text(
                        'AI Personality Summary',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  if (_aiSummary == null)
                    IconButton(
                      icon: _isGeneratingAISummary
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.colorScheme.primary,
                                ),
                              ),
                            )
                          : const Icon(Icons.refresh_rounded),
                      onPressed:
                          _isGeneratingAISummary ? null : _generateAISummary,
                      tooltip: 'Generate AI Summary',
                    ),
                ],
              ),
              if (_aiSummary == null && !_isGeneratingAISummary)
                Padding(
                  padding:
                      EdgeInsets.only(top: Responsive.scaleHeight(context, 16)),
                  child: Center(
                    child: ElevatedButton.icon(
                      onPressed: _generateAISummary,
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('Generate Summary'),
                    ),
                  ),
                ),
              if (_isGeneratingAISummary)
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: Responsive.scaleHeight(context, 32),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.primary,
                          ),
                        ),
                        SizedBox(height: Responsive.scaleHeight(context, 16)),
                        Text(
                          'Generating AI summary...',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_aiSummary != null) ...[
                SizedBox(height: Responsive.scaleHeight(context, 16)),
                Text(
                  _aiSummary!,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.8,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecificationsButton(BuildContext context, ThemeData theme) {
    final padding = Responsive.padding(context);

    return Container(
      margin:
          EdgeInsets.symmetric(vertical: Responsive.scaleHeight(context, 1)),
      padding: padding,
      child: ElevatedButton.icon(
        onPressed: () => _showSpecificationsBottomSheet(context, theme),
        icon: Icon(Icons.settings_outlined),
        label: Text('View Specifications'),
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.scaleWidth(context, 24),
            vertical: Responsive.scaleHeight(context, 16),
          ),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(Responsive.scaleWidth(context, 12)),
          ),
        ),
      ),
    );
  }

  void _showSpecificationsButton(BuildContext context, ThemeData theme) async {
    List<CarData> carsToCompare = widget.allCars ?? [];
    
    // If allCars not provided, try to load from cache
    if (carsToCompare.isEmpty) {
      try {
        carsToCompare = await _carService.loadCars();
      } catch (e) {
        print('Error loading cars for comparison: $e');
      }
    }
    
    if (carsToCompare.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Car list not available for comparison. Please wait for cars to load.'),
          ),
        );
      }
      return;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SpecsCompareScreen(
            allCars: carsToCompare,
            initialCar: widget.car,
          ),
        ),
      );
    }
  }

  void _showSpecificationsBottomSheet(BuildContext context, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(Responsive.scaleWidth(context, 24)),
              topRight: Radius.circular(Responsive.scaleWidth(context, 24)),
            ),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: EdgeInsets.symmetric(
                    vertical: Responsive.scaleHeight(context, 12)),
                width: Responsive.scaleWidth(context, 40),
                height: Responsive.scaleHeight(context, 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                  borderRadius:
                      BorderRadius.circular(Responsive.scaleWidth(context, 2)),
                ),
              ),
              // Header
              Padding(
                padding: Responsive.padding(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Specifications',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Specifications content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: Responsive.padding(context),
                  children: widget.car.specs
                      .map((spec) => _buildPremiumSpecSection(
                            context,
                            theme,
                            spec,
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumSpecSection(
    BuildContext context,
    ThemeData theme,
    Specification spec,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: Responsive.scaleHeight(context, 20)),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Responsive.scaleWidth(context, 16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(Responsive.scaleWidth(context, 20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.scaleWidth(context, 12),
                vertical: Responsive.scaleHeight(context, 6),
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.15),
                borderRadius:
                    BorderRadius.circular(Responsive.scaleWidth(context, 8)),
              ),
              child: Text(
                spec.spec.toUpperCase(),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            SizedBox(height: Responsive.scaleHeight(context, 20)),
            ...spec.value.map((entry) => _buildPremiumSpecRow(
                  context,
                  theme,
                  entry['component'] as String,
                  entry['capacity'] as String,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumSpecRow(
    BuildContext context,
    ThemeData theme,
    String key,
    String value,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.scaleHeight(context, 16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              key,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailItem {
  final String label;
  final String value;

  _DetailItem(this.label, this.value);
}
