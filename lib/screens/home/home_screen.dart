import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/utils/responsive.dart';
import '../../core/services/car_service.dart';
import '../../core/services/ad_service.dart';
import '../../core/services/user_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/app_feedback_service.dart';
import '../../models/car_data.dart';
import '../dashboard/dashboard_screen.dart';
import '../garage/garage_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final CarService _carService = CarService();
  final AppFeedbackService _feedbackService = AppFeedbackService();
  List<CarData> _cars = [];
  bool _isLoading = true;
  bool _isScraping = false;
  int _currentPage = 0;
  DateTime? _appStartTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appStartTime = DateTime.now();
    _loadCars();
    // Track session
    _feedbackService.trackSession();
    // Show app open ad on home screen load
    _showAppOpenAd();
    // Fetch user data when screen loads (if user is signed in)
    _fetchUserDataOnLoad();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _carService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App is going to background - check if we should show feedback prompt
      _checkAndShowFeedbackOnExit();
    }
  }

  Future<void> _checkAndShowFeedbackOnExit() async {
    if (!mounted) return;

    final shouldShow = await _feedbackService.shouldShowOnExit();
    if (shouldShow && _appStartTime != null) {
      // Only show if user has been using app for at least 30 seconds
      final sessionDuration = DateTime.now().difference(_appStartTime!);
      if (sessionDuration.inSeconds >= 30) {
        // Small delay to ensure app state is stable
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          try {
            await _feedbackService.showFeedbackDialog(context);
          } catch (e) {
            // Silently handle any errors showing the dialog
            print('Error showing feedback dialog: $e');
          }
        }
      }
    }
  }

  /// Automatically fetch user data when home screen loads
  /// This ensures user data is available after successful sign-in
  Future<void> _fetchUserDataOnLoad() async {
    final authService = AuthService();
    if (authService.currentUser != null) {
      // User is signed in, fetch user data
      try {
        await UserService.instance.getUserData();
        print('HomeScreen: User data fetched automatically after sign-in');
      } catch (e) {
        print('HomeScreen: Error fetching user data: $e');
      }
    }
  }

  Future<void> _showAppOpenAd() async {
    // Small delay to ensure screen is visible
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      AdService.instance.showAppOpenAd();
    }
  }

  Future<void> _loadCars({bool startScraping = true}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load from cache first
      final cars = await _carService.loadCars();

      setState(() {
        _cars = cars;
        _isLoading = false;
      });

      // If no cars and scraping is enabled, start scraping
      if (cars.isEmpty && startScraping && !_carService.isScraping) {
        _startInitialScraping();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      // Start scraping if loading fails
      if (startScraping && !_carService.isScraping) {
        _startInitialScraping();
      }
    }
  }

  Future<void> _startInitialScraping() async {
    if (_carService.isScraping) return;

    setState(() {
      _isScraping = true;
    });

    try {
      // Scrape first page with progressive updates
      await _carService.scrapeCars(
        startPage: 0,
        endPage: 0,
        appendToCache: true,
        onCarScraped: (car) {
          // Update UI as each car is scraped
          if (mounted) {
            setState(() {
              // Add new car to the list if not already present
              if (!_cars.any((c) => c.id == car.id)) {
                _cars = [..._cars, car];
              }
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isScraping = false;
          _currentPage = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScraping = false;
        });
      }
    }
  }

  Future<void> _loadMoreCars() async {
    if (_carService.isScraping) return;

    setState(() {
      _isScraping = true;
    });

    try {
      final nextPage = _currentPage + 1;

      // Load more cars with progressive updates
      final updatedCars = await _carService.loadMoreCars(
        currentPage: nextPage,
        pagesToLoad: 1,
        onCarScraped: (car) {
          // Update UI as each car is scraped
          if (mounted) {
            setState(() {
              // Add new car to the list if not already present
              if (!_cars.any((c) => c.id == car.id)) {
                _cars = [..._cars, car];
              }
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          // Update with final result to ensure all cars are included
          _cars = updatedCars;
          _isScraping = false;
          // Update page count based on how many pages were actually loaded
          _currentPage = nextPage;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScraping = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
              SizedBox(height: Responsive.scaleHeight(context, 24)),
              Text(
                'Loading your collection...',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_cars.isEmpty) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Center(
          child: Padding(
            padding: Responsive.padding(context),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isScraping) ...[
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                  SizedBox(height: Responsive.scaleHeight(context, 24)),
                  Text(
                    'Collecting cars from the web...',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: Responsive.scaleHeight(context, 8)),
                  Text(
                    'This may take a moment',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  Container(
                    padding: EdgeInsets.all(Responsive.scaleWidth(context, 24)),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.directions_car_rounded,
                      size: Responsive.scaleWidth(context, 64),
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: Responsive.scaleHeight(context, 24)),
                  Text(
                    'No cars found',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: Responsive.scaleHeight(context, 8)),
                  Text(
                    'Start collecting cars from the web',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: Responsive.scaleHeight(context, 32)),
                  ElevatedButton.icon(
                    onPressed: _startInitialScraping,
                    icon: const Icon(Icons.cloud_download_rounded),
                    label: const Text('Start Collecting'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.scaleWidth(context, 24),
                        vertical: Responsive.scaleHeight(context, 16),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return StreamBuilder<UserData?>(
      // Listen to auth state changes and automatically fetch user data
      stream: UserService.instance.currentUserData,
      builder: (context, userDataSnapshot) {
        // When user signs in, this stream will automatically update
        // and trigger a rebuild with the new user data

        return Scaffold(
          /* appBar: AppBar(
            automaticallyImplyLeading: false,
          ), */
          body: IndexedStack(
            index: _currentIndex,
            children: [
              DashboardScreen(
                key: ValueKey(
                    'dashboard_${_currentIndex == 0 ? DateTime.now().millisecondsSinceEpoch ~/ (1000 * 10) : 0}'),
                cars: _cars,
                onLoadMore: _loadMoreCars,
                isLoadingMore: _isScraping,
              ),
              GarageScreen(
                cars: _cars,
                onLoadMore: _loadMoreCars,
                isLoadingMore: _isScraping,
              ),
            ],
          ),
          bottomNavigationBar: Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress indicator when loading more
                  if (_isScraping)
                    Container(
                      height: 3,
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  // Custom bottom navigation
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color:
                              theme.colorScheme.shadow.withValues(alpha: 0.1),
                          blurRadius: 12,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.scaleWidth(context, 16),
                          vertical: Responsive.scaleHeight(context, 8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            // Dashboard button
                            Expanded(
                              child: _buildNavButton(
                                context,
                                theme,
                                icon: Icons.dashboard_outlined,
                                selectedIcon: Icons.dashboard_rounded,
                                label: 'Dashboard',
                                isSelected: _currentIndex == 0,
                                onTap: () {
                                  setState(() {
                                    _currentIndex = 0;
                                  });
                                },
                              ),
                            ),
                            // Garage button
                            Expanded(
                              child: _buildNavButton(
                                context,
                                theme,
                                icon: Icons.garage_outlined,
                                selectedIcon: Icons.garage_rounded,
                                label: 'Garage',
                                isSelected: _currentIndex == 1,
                                onTap: () {
                                  setState(() {
                                    _currentIndex = 1;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          floatingActionButton: Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              final theme = Theme.of(context);
              return FloatingActionButton(
                onPressed: () {
                  themeProvider.setThemeMode(
                    themeProvider.isDark ? ThemeMode.light : ThemeMode.dark,
                  );
                },
                elevation: 0,
                highlightElevation: 0,
                backgroundColor: Colors.transparent,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: themeProvider.isDark
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.secondaryContainer,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return RotationTransition(
                        turns: Tween<double>(begin: 0.0, end: 0.5).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeInOut,
                          ),
                        ),
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeInOut,
                            ),
                          ),
                          child: child,
                        ),
                      );
                    },
                    child: Icon(
                      themeProvider.isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      key: ValueKey(themeProvider.isDark),
                      color: theme.colorScheme.onPrimaryContainer,
                      size: 28,
                    ),
                  ),
                ),
              );
            },
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        );
      },
    );
  }

  Widget _buildNavButton(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(
            minHeight: 56,
            maxHeight: 56,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.scaleWidth(context, 8),
            vertical: Responsive.scaleHeight(context, 6),
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: animation,
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  );
                },
                child: Icon(
                  isSelected ? selectedIcon : icon,
                  key: ValueKey(isSelected),
                  color: isSelected
                      ? (theme.brightness == Brightness.dark
                          ? Colors.white
                          : theme.colorScheme.primary)
                      : (theme.brightness == Brightness.dark
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
                          : theme.colorScheme.onSurfaceVariant),
                  size: 22,
                ),
              ),
              SizedBox(height: Responsive.scaleHeight(context, 2)),
              Flexible(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: theme.textTheme.labelSmall!.copyWith(
                    color: isSelected
                        ? (theme.brightness == Brightness.dark
                            ? Colors.white
                            : theme.colorScheme.primary)
                        : (theme.brightness == Brightness.dark
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
                            : theme.colorScheme.onSurfaceVariant),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: Responsive.fontSize(context, 10),
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
