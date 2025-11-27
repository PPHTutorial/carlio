import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/image_utils.dart';
import '../../core/widgets/banner_ad_widget.dart';
import '../../core/widgets/native_ad_widget.dart';
import '../../models/car_data.dart';

class CarListScreen extends StatefulWidget {
  final List<CarData> cars;
  final Function(CarData) onCarTap;
  final VoidCallback? onLoadMore;
  final bool isLoadingMore;

  const CarListScreen({
    super.key,
    required this.cars,
    required this.onCarTap,
    this.onLoadMore,
    this.isLoadingMore = false,
  });

  @override
  State<CarListScreen> createState() => _CarListScreenState();
}

class _CarListScreenState extends State<CarListScreen> {
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollDebounceTimer;
  bool _isLoadingMoreTriggered = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollDebounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    // Debounce scroll events to reduce load more trigger frequency
    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;

      final position = _scrollController.position;
      if (!position.hasContentDimensions) return;

      final threshold = position.maxScrollExtent * 0.8;
      if (position.pixels >= threshold &&
          widget.onLoadMore != null &&
          !widget.isLoadingMore &&
          !_isLoadingMoreTriggered) {
        _isLoadingMoreTriggered = true;
        widget.onLoadMore!();
        // Reset flag after a delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _isLoadingMoreTriggered = false;
          }
        });
      }
    });
  }

  // Calculate number of sections (each section has 6 cars + 1 ad)
  int get _sectionCount {
    return ((widget.cars.length - 1) / 6).floor() + 1;
  }

  // Get cars for a specific section
  List<CarData> _getCarsForSection(int sectionIndex) {
    final startIndex = sectionIndex * 6;
    final endIndex = (startIndex + 6).clamp(0, widget.cars.length);
    return widget.cars.sublist(startIndex, endIndex);
  }

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = Responsive.crossAxisCount(context);
    final spacing = Responsive.scaleWidth(context, 20);

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      cacheExtent: 500,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.all(spacing),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, sectionIndex) {
                final carsInSection = _getCarsForSection(sectionIndex);

                return Column(
                  children: [
                    // Car grid (2 rows of 3 = 6 cars)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final itemWidth = (constraints.maxWidth -
                                (spacing * (crossAxisCount - 1))) /
                            crossAxisCount;
                        final itemHeight = itemWidth / 0.68;

                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: carsInSection.asMap().entries.map((entry) {
                            final index = entry.key;
                            final car = entry.value;
                            final globalIndex = sectionIndex * 6 + index;

                            // Preload images for next few items
                            _preloadNextImages(globalIndex);

                            return SizedBox(
                              width: itemWidth,
                              height: itemHeight,
                              child: RepaintBoundary(
                                child: _PremiumCarCard(
                                  key: ValueKey(car.id),
                                  car: car,
                                  onTap: () => widget.onCarTap(car),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    // Ad after every 6 cars (full width banner or native)
                    if (sectionIndex < _sectionCount - 1 ||
                        carsInSection.length == 6)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: spacing),
                        child: sectionIndex % 2 == 0
                            ? const BannerAdWidget() // Banner ad spans full width
                            : const NativeAdWidget(), // Native ad
                      ),
                  ],
                );
              },
              childCount: _sectionCount,
            ),
          ),
        ),
      ],
    );
  }

  void _preloadNextImages(int currentIndex) {
    // Preload next 3 images for smooth scrolling
    for (int i = 1; i <= 3; i++) {
      final nextIndex = currentIndex + i;
      if (nextIndex < widget.cars.length) {
        final car = widget.cars[nextIndex];
        if (car.imgs.isNotEmpty) {
          final imageUrl =
              ImageUtils.getCarMediumImageUrl(car.id, car.imgs.first);
          // Precache without blocking the UI
          try {
            CachedNetworkImageProvider(imageUrl)
                .resolve(const ImageConfiguration())
                .addListener(ImageStreamListener((_, __) {}));
          } catch (_) {
            // Ignore errors in preloading
          }
        }
      }
    }
  }
}

class _PremiumCarCard extends StatelessWidget {
  final CarData car;
  final VoidCallback onTap;

  const _PremiumCarCard({
    super.key,
    required this.car,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Use thumbnails for list view - much faster and smaller
    final imageUrl = car.imgs.isNotEmpty
        ? ImageUtils.getCarLargeImageUrl(car.id, car.slug, car.imgs.first)
        : null;

    // Cache responsive values to avoid recalculation
    final borderRadius = 12.0;
    final padding = 12.0;
    final badgePaddingH = 10.0;
    final badgePaddingV = 5.0;
    final iconSize = 64.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              // Use fade-in for smoother appearance
                              fadeInDuration: const Duration(milliseconds: 200),
                              fadeOutDuration:
                                  const Duration(milliseconds: 100),
                              placeholder: (context, url) => Container(
                                width: double.infinity,
                                height: double.infinity,
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                child: Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        theme.colorScheme.primary,
                                      ),
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
                                      theme.colorScheme.primary
                                          .withOpacity(0.2),
                                      theme.colorScheme.primaryContainer
                                          .withOpacity(0.2),
                                    ],
                                  ),
                                ),
                                child: Icon(
                                  Icons.directions_car_rounded,
                                  size: iconSize,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    theme.colorScheme.primary.withOpacity(0.2),
                                    theme.colorScheme.primaryContainer
                                        .withOpacity(0.2),
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.directions_car_rounded,
                                size: iconSize,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                      // Gradient overlay bottom - cached opacity
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 80,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Color(0x99000000), // ~0.6 opacity black
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Year badge at top left
                      if (car.producedIn > 0)
                        Positioned(
                          top: padding,
                          left: padding,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: badgePaddingH,
                              vertical: badgePaddingV,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              car.producedIn.toString(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      // Photo count badge at top right
                      Positioned(
                        top: padding,
                        right: padding,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: badgePaddingH + 2,
                            vertical: badgePaddingV + 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.photo_library_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${car.numberOfShots}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Country badge at bottom left
                      if (car.data.countryOfOrigin != null)
                        Positioned(
                          bottom: padding,
                          left: padding,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: badgePaddingH,
                              vertical: badgePaddingV,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              car.data.countryOfOrigin!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(padding),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          car.name,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
