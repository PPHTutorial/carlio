import 'package:flutter/material.dart';
import '../../core/utils/responsive.dart';
import '../../core/services/bookmarks_service.dart';
import '../../core/services/car_service.dart';
import '../../core/widgets/banner_ad_widget.dart';
import '../../core/widgets/native_ad_widget.dart';
import '../../models/car_data.dart';
import '../car/car_detail_screen.dart';
import '../car/car_list_screen.dart';

class BookmarkedCarsScreen extends StatefulWidget {
  const BookmarkedCarsScreen({super.key});

  @override
  State<BookmarkedCarsScreen> createState() => _BookmarkedCarsScreenState();
}

class _BookmarkedCarsScreenState extends State<BookmarkedCarsScreen> {
  final BookmarksService _bookmarksService = BookmarksService.instance;
  final CarService _carService = CarService();
  List<CarData> _bookmarkedCars = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookmarkedCars();
  }

  Future<void> _loadBookmarkedCars() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final bookmarkedIds = await _bookmarksService.getBookmarkedArticleIds();
      final allCars = await _carService.loadCars();

      // Filter cars to only include bookmarked ones
      final bookmarkedCars = allCars.where((car) => bookmarkedIds.contains(car.id)).toList();

      if (mounted) {
        setState(() {
          _bookmarkedCars = bookmarkedCars;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading bookmarked cars: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarked Cars'),
        actions: [
          if (_bookmarkedCars.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all_rounded),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear All Bookmarks'),
                    content: const Text('Remove all bookmarked cars?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Clear All'),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                );

                if (confirmed == true && mounted) {
                  for (var car in _bookmarkedCars) {
                    await _bookmarksService.removeBookmark(car.id);
                  }
                  _loadBookmarkedCars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All bookmarks cleared')),
                  );
                }
              },
              tooltip: 'Clear all',
            ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            Expanded(
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
              ),
            )
          else if (_bookmarkedCars.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: Responsive.padding(context),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bookmark_border_rounded,
                        size: Responsive.scaleWidth(context, 80),
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(height: Responsive.scaleHeight(context, 24)),
                      Text(
                        'No bookmarked cars',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: Responsive.scaleHeight(context, 8)),
                      Text(
                        'Bookmark cars from the detail screen to view them here',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadBookmarkedCars,
                child: Column(
                  children: [
                    Padding(
                      padding: Responsive.padding(context),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_bookmarkedCars.length} ${_bookmarkedCars.length == 1 ? 'car' : 'cars'} bookmarked',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const NativeAdWidget(),
                    Expanded(
                      child: CarListScreen(
                        cars: _bookmarkedCars,
                        onCarTap: (car) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CarDetailScreen(car: car),
                            ),
                          ).then((_) => _loadBookmarkedCars()); // Refresh after returning
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const BannerAdWidget(),
        ],
      ),
    );
  }
}

