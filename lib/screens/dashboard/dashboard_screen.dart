import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/image_utils.dart';
import '../../core/utils/constants.dart';
import '../../core/widgets/watermarked_image.dart';
import '../../models/car_data.dart';
import '../car/car_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  final List<CarData> cars;
  final VoidCallback? onLoadMore;
  final bool isLoadingMore;

  const DashboardScreen({
    super.key,
    required this.cars,
    this.onLoadMore,
    this.isLoadingMore = false,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<CarData> _recentCars = [];
  List<int> _recentCarIndexes = [];
  int _randomSeed = 0;
  int _heroCarIndex = 0;
  Timer? _heroCarTimer;
  List<CarData> _featuredCars = [];

  @override
  void initState() {
    super.initState();
    _randomizeRecentCars();
    _initializeHeroCar();
  }

  @override
  void didUpdateWidget(DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-randomize when cars list changes or when navigating back to dashboard
    if (widget.cars != oldWidget.cars || widget.cars.length != oldWidget.cars.length) {
      _randomizeRecentCars();
      _initializeHeroCar();
    }
  }

  @override
  void dispose() {
    _heroCarTimer?.cancel();
    super.dispose();
  }

  void _initializeHeroCar() {
    // Cancel existing timer if any
    _heroCarTimer?.cancel();

    // Get latest loaded cars (last items in the list are most recent)
    final latestCars = widget.cars.length > 6 
        ? widget.cars.reversed.take(6).toList().reversed.toList()
        : List<CarData>.from(widget.cars.reversed);
    
    if (latestCars.isEmpty) {
      setState(() {
        _featuredCars = [];
        _heroCarIndex = 0;
      });
      return;
    }

    setState(() {
      _featuredCars = latestCars;
      // Randomly select initial hero car
      _heroCarIndex = Random().nextInt(latestCars.length);
    });

    // Set up timer to change hero car every 5 minutes (300 seconds)
    _heroCarTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted && _featuredCars.isNotEmpty) {
        setState(() {
          // Randomly select a new hero car
          _heroCarIndex = Random().nextInt(_featuredCars.length);
        });
      }
    });
  }

  void _randomizeRecentCars() {
    if (widget.cars.isEmpty) {
      setState(() {
        _recentCars = [];
        _recentCarIndexes = [];
      });
      return;
    }

    // Generate seed based on current time to change selection on each navigation/interaction
    // Using 10-second intervals gives variety while keeping it trackable
    final now = DateTime.now();
    final seed = now.millisecondsSinceEpoch ~/ (1000 * 10); // Changes every 10 seconds
    
    // Always randomize if seed changed or if no cars are selected
    // This ensures fresh selection on each visit
    if (seed != _randomSeed || _recentCars.isEmpty) {
      final random = Random(seed);
      final availableCars = List<CarData>.from(widget.cars);
      
      // Shuffle and take 8 random cars
      availableCars.shuffle(random);
      final selectedCars = availableCars.take(8).toList();
      
      // Track the original indexes/positions in the main cars list
      final selectedIndexes = selectedCars.map((car) {
        return widget.cars.indexWhere((c) => c.id == car.id);
      }).where((index) => index != -1).toList();

      setState(() {
        _recentCars = selectedCars;
        _recentCarIndexes = selectedIndexes;
        _randomSeed = seed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = Responsive.padding(context);

    // Calculate statistics
    final totalCars = widget.cars.length;
    final uniqueBrands = widget.cars.map((c) {
      final parts = c.name.split(' ');
      return parts.isNotEmpty ? parts.first : '';
    }).where((b) => b.isNotEmpty).toSet().length;
    final totalPhotos = widget.cars.fold<int>(
      0,
      (sum, car) => sum + car.numberOfShots,
    );
    // Get latest loaded cars (last items in the list are most recent)
    final featuredCars = widget.cars.length > 6 
        ? widget.cars.reversed.take(6).toList().reversed.toList()
        : List<CarData>.from(widget.cars.reversed);

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildHeroSection(context, theme, _featuredCars),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              padding.left,
              padding.top,
              padding.right,
              0,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildStatsSection(context, theme, totalCars, uniqueBrands, totalPhotos),
                if (widget.onLoadMore != null)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: padding.vertical),
                    child: Center(
                      child: ElevatedButton.icon(
                        onPressed: widget.isLoadingMore ? null : widget.onLoadMore,
                        icon: widget.isLoadingMore
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    theme.colorScheme.onPrimary,
                                  ),
                                ),
                              )
                            : const Icon(Icons.cloud_download_rounded),
                        label: Text(widget.isLoadingMore ? 'Loading...' : 'Load More Cars'),
                      ),
                    ),
                  ),
                SizedBox(height: Responsive.scaleHeight(context, 4)),
                if (featuredCars.isNotEmpty)
                  _buildFeaturedSection(context, theme, featuredCars),
                SizedBox(height: Responsive.scaleHeight(context, 40)),
                _buildRecentSection(context, theme, _recentCars),
                SizedBox(height: Responsive.scaleHeight(context, 32)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, ThemeData theme, List<CarData> featuredCars) {
    if (featuredCars.isEmpty) {
      return SliverAppBar(
        expandedHeight: Responsive.scaleHeight(context, 200),
        pinned: true,
        elevation: 0,
        title: Text(
          AppConstants.appName,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () {
              // TODO: Implement share functionality
            },
            tooltip: 'Share',
          ),
        ],
        flexibleSpace: FlexibleSpaceBar(
          background: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primaryContainer,
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: Responsive.padding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      AppConstants.appName,
                      style: theme.textTheme.headlineLarge?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: Responsive.scaleHeight(context, 8)),
                    Text(
                      'Your premium car collection',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onPrimary.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Use current hero car index, wrap around if needed
    final currentIndex = _heroCarIndex % featuredCars.length;
    final heroCar = featuredCars[currentIndex];

    return SliverAppBar(
      expandedHeight: Responsive.scaleHeight(context, 380),
      pinned: true,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      backgroundColor: theme.colorScheme.surface,
      foregroundColor: theme.colorScheme.onSurface,
      title: Text(
        AppConstants.appName,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share_rounded),
          onPressed: () {
            // TODO: Implement share functionality
          },
          tooltip: 'Share',
        ),
      ],
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final expanded = constraints.biggest.height >= Responsive.scaleHeight(context, 380);
          final isLight = !expanded; // Assume dark image, so use light status bar
          WidgetsBinding.instance.addPostFrameCallback((_) {
            SystemChrome.setSystemUIOverlayStyle(
              isLight ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
            );
          });
          
          return FlexibleSpaceBar(
            background: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CarDetailScreen(car: heroCar),
                  ),
                );
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Hero image with cropping
                  if (heroCar.imgs.isNotEmpty)
                    Positioned.fill(
                      child: WatermarkedImage(
                        image: 
                          CachedNetworkImage(
                          imageUrl: ImageUtils.getCarLargeImageUrl(
                            heroCar.id,
                            heroCar.slug,
                            heroCar.imgs.first,
                          ),
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
                                  theme.colorScheme.primary,
                                  theme.colorScheme.primaryContainer,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.0),
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  // Content
                  SafeArea(
                    child: Padding(
                      padding: Responsive.padding(context),
                      
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Featured car details at bottom
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: Responsive.scaleWidth(context, 12),
                                  vertical: Responsive.scaleHeight(context, 6),
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(
                                    Responsive.scaleWidth(context, 20),
                                  ),
                                ),
                                child: Text(
                                  'Featured',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.onPrimary,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              SizedBox(height: Responsive.scaleHeight(context, 12)),
                              Text(
                                heroCar.name,
                                style: theme.textTheme.headlineLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.5),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: Responsive.scaleHeight(context, 8)),
                              Row(
                                children: [
                                  if (heroCar.data.countryOfOrigin != null)
                                    _buildHeroBadge(
                                      context,
                                      theme,
                                      Icons.place,
                                      heroCar.data.countryOfOrigin!,
                                    ),
                                  SizedBox(width: Responsive.scaleWidth(context, 12)),
                                  if (heroCar.producedIn > 0)
                                    _buildHeroBadge(
                                      context,
                                      theme,
                                      Icons.calendar_today,
                                      heroCar.producedIn.toString(),
                                    ),
                                  SizedBox(width: Responsive.scaleWidth(context, 12)),
                                  _buildHeroBadge(
                                    context,
                                    theme,
                                    Icons.photo_library,
                                    '${heroCar.numberOfShots}',
                                  ),
                                ],
                              ),
                              
                            ],
                          ),
                          SizedBox(height: Responsive.scaleHeight(context, 50)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroBadge(BuildContext context, ThemeData theme, IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.scaleWidth(context, 10),
        vertical: Responsive.scaleHeight(context, 4),
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
          Icon(icon, size: Responsive.fontSize(context, 14), color: Colors.white),
          SizedBox(width: Responsive.scaleWidth(context, 6)),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(
    BuildContext context,
    ThemeData theme,
    int totalCars,
    int uniqueBrands,
    int totalPhotos,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: Responsive.scaleHeight(context, 20)),
        Row(
          children: [
            Expanded(
              child: _PremiumStatCard(
                icon: Icons.directions_car_rounded,
                label: 'Total Cars',
                value: totalCars.toString(),
                iconColor: theme.colorScheme.primary,
                iconBackgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              ),
            ),
            SizedBox(width: Responsive.scaleWidth(context, 12)),
            Expanded(
              child: _PremiumStatCard(
                icon: Icons.category_rounded,
                label: 'Brands',
                value: uniqueBrands.toString(),
                iconColor: theme.colorScheme.secondary,
                iconBackgroundColor: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
              ),
            ),
            SizedBox(width: Responsive.scaleWidth(context, 12)),
            Expanded(
              child: _PremiumStatCard(
                icon: Icons.photo_library_rounded,
                label: 'Photos',
                value: totalPhotos.toString(),
                iconColor: theme.colorScheme.tertiary,
                iconBackgroundColor: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeaturedSection(BuildContext context, ThemeData theme, List<CarData> featuredCars) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Featured Collection',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                'View All',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: Responsive.scaleHeight(context, 20)),
        SizedBox(
          height: Responsive.scaleHeight(context, 240),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: featuredCars.length,
            itemBuilder: (context, index) {
              final car = featuredCars[index];
              return Container(
                width: Responsive.scaleWidth(context, 320),
                margin: EdgeInsets.only(
                  right: Responsive.scaleWidth(context, 20),
                ),
                child: _PremiumCarCard(
                  car: car,
                  showFeaturedBadge: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CarDetailScreen(car: car),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentSection(BuildContext context, ThemeData theme, List<CarData> recentCars) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Additions',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: Responsive.scaleHeight(context, 20)),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: Responsive.crossAxisCount(context),
            crossAxisSpacing: Responsive.scaleWidth(context, 20),
            mainAxisSpacing: Responsive.scaleWidth(context, 20),
            childAspectRatio: 0.68,
          ),
          itemCount: recentCars.length,
          itemBuilder: (context, index) {
            final car = recentCars[index];
            return _PremiumCarCard(
              car: car,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CarDetailScreen(car: car),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _PremiumStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final Color iconBackgroundColor;

  const _PremiumStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    required this.iconBackgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Responsive.scaleWidth(context, 16)),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(Responsive.scaleWidth(context, 16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon container with solid color
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBackgroundColor,
                borderRadius: BorderRadius.circular(Responsive.scaleWidth(context, 12)),
                boxShadow: [
                  BoxShadow(
                    color: iconColor.withValues(alpha: 0.2),
                    blurRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            SizedBox(height: Responsive.scaleHeight(context, 16)),
            // Value
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.5,
                height: 1.1,
              ),
            ),
            SizedBox(height: Responsive.scaleHeight(context, 4)),
            // Label
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumCarCard extends StatelessWidget {
  final CarData car;
  final VoidCallback onTap;
  final bool showFeaturedBadge;

  const _PremiumCarCard({
    required this.car,
    required this.onTap,
    this.showFeaturedBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Responsive.scaleWidth(context, 12)),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(Responsive.scaleWidth(context, 12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Responsive.scaleWidth(context, 12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      car.imgs.isNotEmpty
                          ? SizedBox.expand(
                              child: ImageUtils.cropImageEdges(
                                  CachedNetworkImage(
                                  imageUrl: ImageUtils.getCarLargeImageUrl(
                                    car.id,
                                    car.slug,
                                    car.imgs.first,
                                  ),
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    width: double.infinity,
                                    height: double.infinity,
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
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
                                          theme.colorScheme.primaryContainer.withOpacity(0.3),
                                        ],
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.directions_car_rounded,
                                      size: Responsive.scaleWidth(context, 64),
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
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
                                    theme.colorScheme.primaryContainer.withOpacity(0.2),
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.directions_car_rounded,
                                size: Responsive.scaleWidth(context, 64),
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                      // Gradient overlay bottom
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: Responsive.scaleHeight(context, 80),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.6),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Year badge at top left
                      if (car.producedIn > 0)
                        Positioned(
                          top: Responsive.scaleHeight(context, 12),
                          left: Responsive.scaleWidth(context, 12),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: Responsive.scaleWidth(context, 10),
                              vertical: Responsive.scaleHeight(context, 5),
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(
                                Responsive.scaleWidth(context, 16),
                              ),
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
                      // Featured badge at top center
                      if (showFeaturedBadge)
                        Positioned(
                          top: Responsive.scaleHeight(context, 12),
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: Responsive.scaleWidth(context, 12),
                                vertical: Responsive.scaleHeight(context, 6),
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    theme.colorScheme.primary,
                                    theme.colorScheme.primaryContainer,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(
                                  Responsive.scaleWidth(context, 20),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    size: Responsive.fontSize(context, 14),
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: Responsive.scaleWidth(context, 4)),
                                  Text(
                                    'Featured',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      // Photo count badge at top right
                      Positioned(
                        top: Responsive.scaleHeight(context, 12),
                        right: Responsive.scaleWidth(context, 12),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.scaleWidth(context, 12),
                            vertical: Responsive.scaleHeight(context, 6),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(
                              Responsive.scaleWidth(context, 16),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.photo_library_rounded,
                                size: Responsive.fontSize(context, 14),
                                color: Colors.white,
                              ),
                              SizedBox(width: Responsive.scaleWidth(context, 4)),
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
                          bottom: Responsive.scaleHeight(context, 12),
                          left: Responsive.scaleWidth(context, 12),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: Responsive.scaleWidth(context, 10),
                              vertical: Responsive.scaleHeight(context, 5),
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(
                                Responsive.scaleWidth(context, 16),
                              ),
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
                  padding: EdgeInsets.all(Responsive.scaleWidth(context, 12)),
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
                      SizedBox(width: Responsive.scaleWidth(context, 8)),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: Responsive.fontSize(context, 12),
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
