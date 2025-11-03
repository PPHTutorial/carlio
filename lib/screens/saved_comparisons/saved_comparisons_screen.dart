import 'package:flutter/material.dart';
import '../../core/utils/responsive.dart';
import '../../core/services/saved_comparisons_service.dart';
import '../../core/services/car_service.dart';
import '../../core/widgets/banner_ad_widget.dart';
import '../../models/car_data.dart';
import '../car/specs_compare_screen.dart';

class SavedComparisonsScreen extends StatefulWidget {
  const SavedComparisonsScreen({super.key});

  @override
  State<SavedComparisonsScreen> createState() => _SavedComparisonsScreenState();
}

class _SavedComparisonsScreenState extends State<SavedComparisonsScreen> {
  final SavedComparisonsService _savedComparisonsService = SavedComparisonsService.instance;
  final CarService _carService = CarService();
  List<SavedComparison> _savedComparisons = [];
  List<CarData> _allCars = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final comparisons = await _savedComparisonsService.getSavedComparisons();
      final cars = await _carService.loadCars();

      if (mounted) {
        setState(() {
          _savedComparisons = comparisons;
          _allCars = cars;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading saved comparisons: $e')),
        );
      }
    }
  }

  Future<void> _deleteComparison(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comparison'),
        content: const Text('Are you sure you want to delete this saved comparison?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final deleted = await _savedComparisonsService.deleteComparison(id);
      if (deleted && mounted) {
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comparison deleted')),
        );
      }
    }
  }

  List<CarData> _getCarsForComparison(SavedComparison comparison) {
    return comparison.carIds
        .map((id) => _allCars.firstWhere(
              (car) => car.id == id,
              orElse: () => _createDummyCar(id, comparison.carNames, comparison.carIds),
            ))
        .toList();
  }

  CarData _createDummyCar(String id, List<String> names, List<String> carIds) {
    // Create a minimal car data for cars that might not be in cache
    final nameIndex = carIds.indexOf(id);
    final name = nameIndex < names.length && nameIndex >= 0 ? names[nameIndex] : 'Unknown Car';
    
    return CarData(
      id: id,
      name: name,
      slug: id,
      imgs: [],
      specs: [],
      producedIn: 0,
      numberOfShots: 0,
      lastUpdated: DateTime.now().toIso8601String(),
      data: CarDetails(
        countryOfOrigin: null,
        engineType: null,
        producedIn: null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Comparisons'),
        actions: [
          if (_savedComparisons.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear All'),
                    content: const Text('Delete all saved comparisons?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete All'),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                );

                if (confirmed == true && mounted) {
                  for (var comparison in _savedComparisons) {
                    await _savedComparisonsService.deleteComparison(comparison.id);
                  }
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All comparisons deleted')),
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
          else if (_savedComparisons.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: Responsive.padding(context),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.compare_arrows_rounded,
                        size: Responsive.scaleWidth(context, 80),
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(height: Responsive.scaleHeight(context, 24)),
                      Text(
                        'No saved comparisons',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: Responsive.scaleHeight(context, 8)),
                      Text(
                        'Save comparisons from the comparison screen to view them here',
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
                onRefresh: _loadData,
                child: ListView.builder(
                  padding: Responsive.padding(context),
                  itemCount: _savedComparisons.length,
                  itemBuilder: (context, index) {
                    final comparison = _savedComparisons[index];
                    final cars = _getCarsForComparison(comparison);
                    
                    return _buildComparisonCard(context, theme, comparison, cars);
                  },
                ),
              ),
            ),
          const BannerAdWidget(),
        ],
      ),
    );
  }

  Widget _buildComparisonCard(
    BuildContext context,
    ThemeData theme,
    SavedComparison comparison,
    List<CarData> cars,
  ) {
    final dateFormat = '${comparison.createdAt.day}/${comparison.createdAt.month}/${comparison.createdAt.year}';
    
    return Container(
      margin: EdgeInsets.only(bottom: Responsive.scaleHeight(context, 16)),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Responsive.scaleWidth(context, 16)),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: InkWell(
        onTap: () async {
          if (cars.length >= 2) {
            // Show comparison with all cars pre-selected
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SpecsCompareScreen(
                  allCars: _allCars,
                  initialCar: cars.first,
                  preSelectedCars: cars, // Pass all cars to be pre-selected
                ),
              ),
            );
            // Refresh after returning
            if (mounted) {
              _loadData();
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cannot open: Not enough cars available'),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(Responsive.scaleWidth(context, 16)),
        child: Padding(
          padding: EdgeInsets.all(Responsive.scaleWidth(context, 16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.compare_arrows_rounded,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            SizedBox(width: Responsive.scaleWidth(context, 8)),
                            Text(
                              '${cars.length} Cars',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: Responsive.scaleHeight(context, 4)),
                        Text(
                          comparison.carNames.join(' vs '),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: theme.colorScheme.error,
                    ),
                    onPressed: () => _deleteComparison(comparison.id),
                    tooltip: 'Delete',
                  ),
                ],
              ),
              SizedBox(height: Responsive.scaleHeight(context, 12)),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.scaleWidth(context, 12),
                      vertical: Responsive.scaleHeight(context, 6),
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(Responsive.scaleWidth(context, 12)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.emoji_events_rounded,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        SizedBox(width: Responsive.scaleWidth(context, 4)),
                        Text(
                          comparison.result.winner,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: Responsive.scaleWidth(context, 8)),
                  Text(
                    dateFormat,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

