import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math';
import '../../core/utils/responsive.dart';
import '../../core/utils/image_utils.dart';
import '../../models/car_data.dart';
import '../../core/services/car_comparison_service.dart';
import '../../core/services/share_service.dart';
import '../../core/services/bookmarks_service.dart';
import '../../core/services/saved_comparisons_service.dart';
import '../../core/services/ad_service.dart';
import '../../core/widgets/banner_ad_widget.dart';
import '../../core/widgets/native_ad_widget.dart';

class SpecsCompareScreen extends StatefulWidget {
  final List<CarData> allCars;
  final CarData? initialCar;
  final List<CarData>? preSelectedCars; // Pre-select these cars

  const SpecsCompareScreen({
    super.key,
    required this.allCars,
    this.initialCar,
    this.preSelectedCars,
  });

  @override
  State<SpecsCompareScreen> createState() => _SpecsCompareScreenState();
}

class _SpecsCompareScreenState extends State<SpecsCompareScreen> {
  List<CarData> _selectedCars = [];
  CarComparisonResult? _comparisonResult;
  bool _isComparing = false;
  bool _showCarSelection = true; // Control which view to show
  bool _isComparisonSaved = false;
  bool _areAllCarsBookmarked = false;
  String? _savedComparisonId;
  final BookmarksService _bookmarksService = BookmarksService.instance;
  final ShareService _shareService = ShareService();
  final AdService _adService = AdService.instance;
  final SavedComparisonsService _savedComparisonsService = SavedComparisonsService.instance;

  @override
  void initState() {
    super.initState();
    _resetSelection();
  }

  @override
  void didUpdateWidget(SpecsCompareScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_comparisonResult != null) {
      _checkComparisonStatus();
    }
  }

  Future<void> _checkComparisonStatus() async {
    if (_comparisonResult == null || _selectedCars.isEmpty) {
      if (mounted) {
        setState(() {
          _isComparisonSaved = false;
          _areAllCarsBookmarked = false;
          _savedComparisonId = null;
        });
      }
      return;
    }

    // Check if comparison is saved
    final savedComparisons = await _savedComparisonsService.getSavedComparisons();
    final carIds = _selectedCars.map((car) => car.id).toList()..sort();
    
    bool isSaved = false;
    String? savedId;
    
    try {
      final savedComparison = savedComparisons.firstWhere(
        (comp) {
          final compCarIds = List<String>.from(comp.carIds)..sort();
          return compCarIds.length == carIds.length &&
              compCarIds.every((id) => carIds.contains(id)) &&
              carIds.every((id) => compCarIds.contains(id));
        },
      );
      savedId = savedComparison.id;
      isSaved = true;
    } catch (e) {
      // Comparison not found - not saved
      isSaved = false;
      savedId = null;
    }

    // Check if all cars are bookmarked
    bool allBookmarked = true;
    for (var car in _selectedCars) {
      final isBookmarked = await _bookmarksService.isBookmarked(car.id);
      if (!isBookmarked) {
        allBookmarked = false;
        break;
      }
    }

    if (mounted) {
      setState(() {
        _isComparisonSaved = isSaved;
        _areAllCarsBookmarked = allBookmarked;
        _savedComparisonId = savedId;
      });
    }
  }

  void _resetSelection() {
    setState(() {
      _selectedCars.clear();
      _comparisonResult = null;
      _isComparing = false;
      _showCarSelection = true;
      // If pre-selected cars provided, use them; otherwise use initial car
      if (widget.preSelectedCars != null && widget.preSelectedCars!.isNotEmpty) {
        _selectedCars = List.from(widget.preSelectedCars!);
        // If we have 2+ cars, auto-run comparison
        if (_selectedCars.length >= 2) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _performComparison();
          });
        }
      } else if (widget.initialCar != null) {
        _selectedCars = [widget.initialCar!];
      }
    });
  }

  bool get _shouldShowCarSelection {
    // Show car selection if:
    // - Less than 2 cars selected, OR
    // - No comparison result and less than 5 cars and user wants to add more
    return _selectedCars.length < 2 ||
        (_comparisonResult == null &&
            _selectedCars.length < 5 &&
            _showCarSelection);
  }

  void _runComparison() async {
    if (_selectedCars.length < 2) return;

    // Show interstitial ad before comparison
    await _adService.showInterstitialAd(
      onAdClosed: () {
        _performComparison();
      },
      onError: (error) {
        // Continue even if ad fails
        _performComparison();
      },
    );
  }

  void _performComparison() {
    if (_selectedCars.length < 2) return;

    setState(() {
      _isComparing = true;
      _showCarSelection = false; // Switch to comparison view
    });

    try {
      final result = CarComparisonService.compareCars(_selectedCars);
      setState(() {
        _comparisonResult = result;
        _isComparing = false;
      });
      // Check status after comparison
      _checkComparisonStatus();
    } catch (e) {
      setState(() {
        _isComparing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error comparing cars: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare Specifications'),
        actions: [
          if (_selectedCars.length >= 2)
            IconButton(
              icon: const Icon(Icons.clear_all_rounded),
              onPressed: () {
                setState(() {
                  _selectedCars.clear();
                  if (widget.initialCar != null) {
                    _selectedCars.add(widget.initialCar!);
                  }
                });
              },
              tooltip: 'Clear selection',
            ),
        ],
      ),
      body: Column(
        children: [
          // Top banner ad
          BannerAdWidget(),
          // Selected cars chips (2-column grid)
          if (_selectedCars.isNotEmpty)
            Container(
              padding: Responsive.padding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: Responsive.scaleWidth(context, 4),
                      mainAxisSpacing: Responsive.scaleHeight(context, 4),
                      childAspectRatio: 3.5,
                    ),
                    itemCount:  _selectedCars.length,
                    itemBuilder: (context, index) {
                      final car = _selectedCars[index];
                  return Chip(
                        label: Text(
                          car.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 12),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    onDeleted: () {
                      setState(() {
                        _selectedCars.remove(car);
                            // Reset comparison when removing cars
                            _comparisonResult = null;
                            _showCarSelection =
                                true; // Show selection view when removing
                      });
                    },
                        deleteIcon: const Icon(Icons.close, size: 16),
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.scaleWidth(context, 4),
                          vertical: Responsive.scaleHeight(context, 2),
                        ),
                      );
                    },
                  ),
                  // Add More Cars button (under the grid, when less than 5)
                  if (_selectedCars.length < 5 && _selectedCars.length >= 2)
                    Padding(
                      padding: EdgeInsets.only(
                        top: Responsive.scaleHeight(context, 12),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            // Show interstitial ad
                            await _adService.showInterstitialAd(
                              onAdClosed: () {
                                setState(() {
                                  _showCarSelection = true;
                                });
                              },
                              onError: (error) {
                                setState(() {
                                  _showCarSelection = true;
                                });
                              },
                            );
                          },
                          icon: Icon(Icons.add_circle_outline_rounded),
                          label:
                              Text('Add More Cars (${_selectedCars.length}/5)'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: Responsive.scaleWidth(context, 24),
                              vertical: Responsive.scaleHeight(context, 16),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          // Car selection list or comparison view
          Expanded(
            child: _shouldShowCarSelection
                ? _buildCarSelectionView(context, theme)
                : _buildComparisonView(context, theme),
          ),
          // Bottom banner ad
          BannerAdWidget(),
        ],
      ),
    );
  }

  Widget _buildCarSelectionView(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: Responsive.padding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
            _selectedCars.isEmpty
                    ? 'Select 2-5 cars to compare'
                    : _selectedCars.length == 1
                        ? 'Select 1-4 more cars to compare (${_selectedCars.length}/5)'
                        : 'Add more cars or start comparison (${_selectedCars.length}/5)',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
              ),
              if (_selectedCars.length >= 2) ...[
                SizedBox(height: Responsive.scaleHeight(context, 12)),
                // Compare button in selection view
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _runComparison(),
                    icon: Icon(Icons.compare_arrows_rounded),
                    label: Text('Compare ${_selectedCars.length} Cars'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.scaleWidth(context, 24),
                        vertical: Responsive.scaleHeight(context, 16),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: Responsive.padding(context),
            itemCount: widget.allCars.length,
            itemBuilder: (context, index) {
              final car = widget.allCars[index];
              final isSelected = _selectedCars.any((c) => c.id == car.id);
              final canSelect = _selectedCars.length < 5 && !isSelected;
              final maxReached = _selectedCars.length >= 5;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    isSelected ? Icons.check_rounded : Icons.add_rounded,
                    color: isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                title: Text(car.name),
                subtitle: maxReached && !isSelected
                    ? Text(
                        'Maximum 5 cars allowed',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      )
                    : Text(
                  car.data.countryOfOrigin ?? 'Unknown origin',
                  style: theme.textTheme.bodySmall,
                ),
                trailing: car.specs.isNotEmpty
                    ? Icon(
                        Icons.verified_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      )
                    : null,
                onTap: canSelect
                    ? () async {
                        // Show interstitial ad on car selection
                        await _adService.showInterstitialAd(
                          onAdClosed: () {
                        setState(() {
                          _selectedCars.add(car);
                              // Reset comparison when adding new car
                              _comparisonResult = null;
                              // If we reach 5 cars, auto-compare and switch to comparison view
                              if (_selectedCars.length >= 5) {
                                _showCarSelection = false;
                                // Auto-run comparison when 5 cars are selected
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  _performComparison();
                                });
                              }
                            });
                          },
                          onError: (error) {
                            // Continue even if ad fails
                            setState(() {
                              _selectedCars.add(car);
                              _comparisonResult = null;
                              if (_selectedCars.length >= 5) {
                                _showCarSelection = false;
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  _performComparison();
                                });
                              }
                            });
                          },
                        );
                      }
                    : isSelected
                        ? () {
                            setState(() {
                              _selectedCars.remove(car);
                              // Reset comparison when removing car
                              _comparisonResult = null;
                            });
                          }
                        : null,
                enabled: canSelect || isSelected,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonView(BuildContext context, ThemeData theme) {
    // Don't auto-run - user must click Compare button

    if (_isComparing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: Responsive.scaleHeight(context, 16)),
            Text('Comparing cars...', style: theme.textTheme.bodyLarge),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: Responsive.padding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show action buttons if not yet compared
          if (_comparisonResult == null)
            Padding(
              padding: Responsive.padding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Compare button (always visible when 2+ cars selected)
                  if (_selectedCars.length >= 2)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _runComparison(),
                        icon: Icon(Icons.compare_arrows_rounded),
                        label: Text('Compare ${_selectedCars.length} Cars'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: Responsive.scaleWidth(context, 24),
                            vertical: Responsive.scaleHeight(context, 16),
                          ),
                        ),
                      ),
                    ),
                  // Info text
                  if (_selectedCars.length >= 2 && _selectedCars.length < 5)
                    Padding(
                      padding: EdgeInsets.only(
                          top: Responsive.scaleHeight(context, 8)),
                      child: Text(
                        'You can add ${5 - _selectedCars.length} more car${5 - _selectedCars.length > 1 ? 's' : ''} before comparing',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ),
                ],
              ),
            ),
          // Comparison results header
          if (_comparisonResult != null) _buildResultsHeader(context, theme),
          if (_comparisonResult != null)
            SizedBox(height: Responsive.scaleHeight(context, 24)),
          // Native ad after winner card
          if (_comparisonResult != null) NativeAdWidget(),
          if (_comparisonResult != null)
            SizedBox(height: Responsive.scaleHeight(context, 24)),
          // Action buttons (share, save, bookmark, fullscreen)
          if (_comparisonResult != null) _buildActionButtons(context, theme),
          if (_comparisonResult != null)
            SizedBox(height: Responsive.scaleHeight(context, 24)),
          // Category scores comparison
          if (_comparisonResult != null)
            _buildCategoryScoresComparison(context, theme),
          if (_comparisonResult != null)
            SizedBox(height: Responsive.scaleHeight(context, 24)),
          // Second native ad after category scores
          if (_comparisonResult != null) NativeAdWidget(),
          if (_comparisonResult != null)
            SizedBox(height: Responsive.scaleHeight(context, 24)),
          // Header with car names
          _buildComparisonHeader(context, theme),
          SizedBox(height: Responsive.scaleHeight(context, 24)),
          // Basic info comparison (horizontally scrollable)
          _buildBasicInfoComparison(context, theme),
          SizedBox(height: Responsive.scaleHeight(context, 24)),
          // Specifications comparison (horizontally scrollable)
          _buildSpecsComparison(context, theme),
          if (_comparisonResult != null)
            SizedBox(height: Responsive.scaleHeight(context, 24)),
          // AI Summary
          if (_comparisonResult != null) _buildSummary(context, theme),
        ],
      ),
    );
  }

  Widget _buildComparisonHeader(BuildContext context, ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.scaleWidth(context, 16),
          vertical: Responsive.scaleHeight(context, 12),
        ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
          borderRadius:
              BorderRadius.circular(Responsive.scaleWidth(context, 12)),
      ),
      child: Row(
          children: _selectedCars.asMap().entries.map((entry) {
            final index = entry.key;
            final car = entry.value;
            return Container(
              margin: EdgeInsets.only(
                right: index < _selectedCars.length - 1
                    ? Responsive.scaleWidth(context, 16)
                    : 0,
              ),
              constraints: BoxConstraints(
                minWidth: Responsive.scaleWidth(context, 120),
                maxWidth: Responsive.scaleWidth(context, 200),
              ),
            child: Text(
              car.name,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: Responsive.fontSize(context, 14),
              ),
                textAlign: TextAlign.left,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        ),
      ),
    );
  }

  Widget _buildBasicInfoComparison(BuildContext context, ThemeData theme) {
    final comparisonData = <String, List<String?>>{};

    // Collect all unique keys
    final allKeys = <String>{};
    for (var car in _selectedCars) {
      if (car.data.countryOfOrigin != null) {
        allKeys.add('Country');
      }
      if (car.producedIn > 0) {
        allKeys.add('Year');
      }
      if (car.data.engineType != null) {
        allKeys.add('Engine');
      }
      if (car.numberOfShots > 0) {
        allKeys.add('Photos');
      }
    }

    for (var key in allKeys) {
      comparisonData[key] = _selectedCars.map((car) {
        switch (key) {
          case 'Country':
            return car.data.countryOfOrigin;
          case 'Year':
            return car.producedIn > 0 ? car.producedIn.toString() : null;
          case 'Engine':
            return car.data.engineType;
          case 'Photos':
            return car.numberOfShots.toString();
          default:
            return null;
        }
      }).toList();
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Responsive.scaleWidth(context, 12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(Responsive.scaleWidth(context, 16)),
            child: Text(
              'Basic Information',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: Responsive.fontSize(context, 16),
              ),
            ),
          ),
          ...comparisonData.entries.map((entry) {
            return _buildComparisonRow(
              context,
              theme,
              entry.key,
              entry.value,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(
    BuildContext context,
    ThemeData theme,
    String label,
    List<String?> values,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Container(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.scaleWidth(context, 16),
        vertical: Responsive.scaleHeight(context, 12),
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
              width: Responsive.scaleWidth(context, 120),
              child: Align(
                alignment: Alignment.centerLeft,
            child: Text(
              label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: Responsive.fontSize(context, 12),
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
            ),
            SizedBox(width: Responsive.scaleWidth(context, 8)),
            ...values.asMap().entries.map((entry) {
              final index = entry.key;
              final value = entry.value;
              return Container(
                margin: EdgeInsets.only(
                  right: index < values.length - 1
                      ? Responsive.scaleWidth(context, 12)
                      : 0,
                ),
                constraints: BoxConstraints(
                  minWidth: Responsive.scaleWidth(context, 100),
                  maxWidth: Responsive.scaleWidth(context, 180),
                ),
                  child: Text(
                    value ?? 'N/A',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: Responsive.fontSize(context, 12),
                    ),
                  textAlign: TextAlign.left,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  ),
                );
            }),
        ],
        ),
      ),
    );
  }

  Widget _buildSpecsComparison(BuildContext context, ThemeData theme) {
    // Get all unique spec categories
    final allSpecCategories = <String>{};
    for (var car in _selectedCars) {
      for (var spec in car.specs) {
        allSpecCategories.add(spec.spec);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Specifications',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: Responsive.scaleHeight(context, 16)),
        ...allSpecCategories.map((category) {
          return Container(
            margin:
                EdgeInsets.only(bottom: Responsive.scaleHeight(context, 16)),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius:
                  BorderRadius.circular(Responsive.scaleWidth(context, 12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.all(Responsive.scaleWidth(context, 16)),
                  child: Text(
                    category.toUpperCase(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                ..._buildSpecCategoryComparison(context, theme, category),
              ],
            ),
          );
        }),
      ],
    );
  }

  List<Widget> _buildSpecCategoryComparison(
    BuildContext context,
    ThemeData theme,
    String category,
  ) {
    // Get all unique component names for this category
    final allComponents = <String>{};
    for (var car in _selectedCars) {
      final categorySpec = car.specs.firstWhere(
        (spec) => spec.spec == category,
        orElse: () => Specification(spec: category, value: []),
      );
      for (var entry in categorySpec.value) {
        final component = entry['component'] as String? ?? '';
        if (component.isNotEmpty) {
          allComponents.add(component);
        }
      }
    }

    final widgets = <Widget>[];

    for (var component in allComponents) {
      final values = _selectedCars.map((car) {
        final categorySpec = car.specs.firstWhere(
          (spec) => spec.spec == category,
          orElse: () => Specification(spec: category, value: []),
        );
        final entry = categorySpec.value.firstWhere(
          (e) => (e['component'] as String?) == component,
          orElse: () => <String, dynamic>{},
        );
        return entry['capacity'] as String? ?? 'N/A';
      }).toList();

      widgets.add(_buildComparisonRow(context, theme, component, values));
    }

    return widgets;
  }

  Widget _buildResultsHeader(BuildContext context, ThemeData theme) {
    if (_comparisonResult == null) return const SizedBox.shrink();

    // Find the winning car from selected cars
    final winnerName = _comparisonResult!.winner;
    final winningCar = _selectedCars.firstWhere(
      (car) => car.name == winnerName,
      orElse: () => _selectedCars.first,
    );

    // Get a random image from the winning car
    String? winnerImageUrl;
    if (winningCar.imgs.isNotEmpty) {
      final randomIndex = Random().nextInt(winningCar.imgs.length);
      winnerImageUrl = ImageUtils.getCarLargeImageUrl(
        winningCar.id,
        winningCar.slug,
        winningCar.imgs[randomIndex],
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Responsive.scaleWidth(context, 20)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(Responsive.scaleWidth(context, 16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text content column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🏆 Winner',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: Responsive.scaleHeight(context, 8)),
                Text(
                  _comparisonResult!.winner,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.left,
                ),
                SizedBox(height: Responsive.scaleHeight(context, 12)),
                Text(
                  'Score: ${_comparisonResult!.cars.first.finalScore.toStringAsFixed(1)}/10',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimary.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.left,
                ),
              ],
            ),
          ),
          // Image column
          if (winnerImageUrl != null) ...[
            SizedBox(width: Responsive.scaleWidth(context, 16)),
            ClipRRect(
              borderRadius:
                  BorderRadius.circular(Responsive.scaleWidth(context, 12)),
              child: Container(
                width: Responsive.scaleWidth(context, 120),
                height: Responsive.scaleHeight(context, 120),
                child: CachedNetworkImage(
                  imageUrl: winnerImageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.image_not_supported,
                      color: theme.colorScheme.onPrimary.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: Responsive.scaleWidth(context, 8),
      children: [
        ElevatedButton.icon(
          onPressed: () => _shareComparison(),
          icon: Icon(Icons.share_rounded, size: 18),
          label: Text('Share',
              style: TextStyle(fontSize: Responsive.fontSize(context, 12))),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.scaleWidth(context, 16),
              vertical: Responsive.scaleHeight(context, 10),
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _saveComparison(),
          icon: Icon(
            _isComparisonSaved ? Icons.save_rounded : Icons.save_outlined,
            size: 18,
            color: _isComparisonSaved
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
          ),
          label: Text(
            _isComparisonSaved ? 'Saved' : 'Save',
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 12),
              color: _isComparisonSaved
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
            ),
          ),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.scaleWidth(context, 16),
              vertical: Responsive.scaleHeight(context, 10),
            ),
            
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _bookmarkComparison(),
          icon: Icon(
            _areAllCarsBookmarked
                ? Icons.bookmark_rounded
                : Icons.bookmark_outline_rounded,
            size: 18,
            color: _areAllCarsBookmarked
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
          ),
          label: Text(
            _areAllCarsBookmarked ? 'Bookmarked' : 'Bookmark',
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 12),
              color: _areAllCarsBookmarked
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
            ),
          ),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.scaleWidth(context, 16),
              vertical: Responsive.scaleHeight(context, 10),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _shareComparison() async {
    if (_comparisonResult == null) return;

    // Show rewarded video ad before sharing
    await _adService.showRewardedInterstitialAd(
      onRewarded: () async {
        final buffer = StringBuffer();
        buffer.writeln('🚗 Car Comparison Results\n');
        buffer.writeln('🏆 Winner: ${_comparisonResult!.winner}\n');
        buffer.writeln('Rankings:');
        for (var car in _comparisonResult!.cars) {
          buffer.writeln(
              '${car.rank}. ${car.name} - ${car.finalScore.toStringAsFixed(1)}/10');
        }
        buffer.writeln('\n${_comparisonResult!.summary}');
        buffer.writeln('\nGenerated by CarCollection App');

        await _shareService.shareText(buffer.toString(),
            subject: 'Car Comparison Results');
      },
      onError: (error) async {
        // Continue even if ad fails
        final buffer = StringBuffer();
        buffer.writeln('🚗 Car Comparison Results\n');
        buffer.writeln('🏆 Winner: ${_comparisonResult!.winner}\n');
        buffer.writeln('Rankings:');
        for (var car in _comparisonResult!.cars) {
          buffer.writeln(
              '${car.rank}. ${car.name} - ${car.finalScore.toStringAsFixed(1)}/10');
        }
        buffer.writeln('\n${_comparisonResult!.summary}');
        buffer.writeln('\nGenerated by CarCollection App');

        await _shareService.shareText(buffer.toString(),
            subject: 'Car Comparison Results');
      },
    );
  }

  Future<void> _saveComparison() async {
    if (_comparisonResult == null) return;

    // If already saved, unsave it
    if (_isComparisonSaved && _savedComparisonId != null) {
      final deleted = await _savedComparisonsService.deleteComparison(_savedComparisonId!);
      if (mounted && deleted) {
        setState(() {
          _isComparisonSaved = false;
          _savedComparisonId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Comparison removed from saved')),
        );
      }
      return;
    }

    // Show interstitial ad before saving
    await _adService.showInterstitialAd(
      onAdClosed: () async {
        try {
          final savedId = await _savedComparisonsService.saveComparison(
            selectedCars: _selectedCars,
            result: _comparisonResult!,
          );

          if (mounted) {
            setState(() {
              _isComparisonSaved = true;
              _savedComparisonId = savedId;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Comparison saved for future reference')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error saving comparison: $e')),
            );
          }
        }
      },
      onError: (error) async {
        // Continue even if ad fails
        try {
          final savedId = await _savedComparisonsService.saveComparison(
            selectedCars: _selectedCars,
            result: _comparisonResult!,
          );

          if (mounted) {
            setState(() {
              _isComparisonSaved = true;
              _savedComparisonId = savedId;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Comparison saved for future reference')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error saving comparison: $e')),
            );
          }
        }
      },
    );
  }

  Future<void> _bookmarkComparison() async {
    if (_comparisonResult == null) return;

    // If all bookmarked, unbookmark all
    if (_areAllCarsBookmarked) {
      for (var car in _selectedCars) {
        await _bookmarksService.removeBookmark(car.id);
      }
      if (mounted) {
        setState(() {
          _areAllCarsBookmarked = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Comparison unbookmarked')),
        );
      }
      return;
    }

    // Show interstitial ad before bookmarking
    await _adService.showInterstitialAd(
      onAdClosed: () async {
        // Bookmark each car
        for (var car in _selectedCars) {
          await _bookmarksService.addBookmark(car.id);
        }

        if (mounted) {
          setState(() {
            _areAllCarsBookmarked = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Comparison bookmarked')),
          );
        }
      },
      onError: (error) async {
        // Continue even if ad fails
        for (var car in _selectedCars) {
          await _bookmarksService.addBookmark(car.id);
        }

        if (mounted) {
          setState(() {
            _areAllCarsBookmarked = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Comparison bookmarked')),
          );
        }
      },
    );
  }

  Widget _buildCategoryScoresComparison(BuildContext context, ThemeData theme) {
    if (_comparisonResult == null) return const SizedBox.shrink();

    final categories = [
      ('Performance', 'performance'),
      ('Comfort', 'comfort'),
      ('Luxury', 'luxury'),
      ('Fuel Economy', 'economy'),
      ('Reliability', 'reliability'),
      ('Value', 'value'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Responsive.scaleWidth(context, 16)),
      ),
      padding: EdgeInsets.all(Responsive.scaleWidth(context, 16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Category Scores',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_selectedCars.length > 2)
                ElevatedButton.icon(
                  onPressed: () async {
                    // Show rewarded video ad before fullscreen
                    await _adService.showRewardedAd(
                      onRewarded: () {
                        _showFullscreenComparison(context);
                      },
                      onError: (error) {
                        // Continue even if ad fails
                        _showFullscreenComparison(context);
                      },
                    );
                  },
                  icon: Icon(Icons.fullscreen_rounded, size: 18),
                  label: Text('Fullscreen',
                      style: TextStyle(
                          fontSize: Responsive.fontSize(context, 12))),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.scaleWidth(context, 16),
                      vertical: Responsive.scaleHeight(context, 10),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: Responsive.scaleHeight(context, 16)),
          ...categories.map((category) {
            return Padding(
              padding:
                  EdgeInsets.only(bottom: Responsive.scaleHeight(context, 16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.$1,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: Responsive.fontSize(context, 12),
                    ),
                  ),
                  SizedBox(height: Responsive.scaleHeight(context, 8)),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children:
                          _comparisonResult!.cars.asMap().entries.map((entry) {
                        final index = entry.key;
                        final car = entry.value;
                        final score = _getCategoryScore(car, category.$2);
                        return Container(
                          margin: EdgeInsets.only(
                            right: index < _comparisonResult!.cars.length - 1
                                ? Responsive.scaleWidth(context, 12)
                                : 0,
                          ),
                          width: Responsive.scaleWidth(context, 120),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Car name header (left aligned)
                              Container(
                                height: Responsive.scaleHeight(context, 40),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  car.name,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    fontSize: Responsive.fontSize(context, 11),
                                  ),
                                  textAlign: TextAlign.left,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(
                                  height: Responsive.scaleHeight(context, 2)),
                              // Progress bar with background
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                    Responsive.scaleWidth(context, 20)),
                                child: Container(
                                  height: Responsive.scaleHeight(context, 12),
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme.surfaceContainerHighest
                                        .withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(
                                        Responsive.scaleWidth(context, 20)),
                                  ),
                                  child: Stack(
                                    children: [
                                      // Background
                                      Container(
                                        width: double.infinity,
                                        height: double.infinity,
                                        decoration: BoxDecoration(
                                          color: theme
                                              .colorScheme.outlineVariant
                                              .withOpacity(0.8),
                                          borderRadius: BorderRadius.circular(
                                              Responsive.scaleWidth(
                                                  context, 20)),
                                        ),
                                      ),
                                      // Progress
                                      FractionallySizedBox(
                                        widthFactor: score / 10,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                theme.colorScheme.primary,
                                                theme.colorScheme
                                                    .primaryContainer,
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                                Responsive.scaleWidth(
                                                    context, 20)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(
                                  height: Responsive.scaleHeight(context, 6)),
                              Text(
                                score.toStringAsFixed(1),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: Responsive.fontSize(context, 12),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showFullscreenComparison(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullscreenComparisonScreen(
          comparisonResult: _comparisonResult!,
          selectedCars: _selectedCars,
        ),
        fullscreenDialog: false,
      ),
    );
  }

  double _getCategoryScore(CarComparisonScore car, String category) {
    switch (category) {
      case 'performance':
        return car.categoryScores.performance;
      case 'comfort':
        return car.categoryScores.comfort;
      case 'luxury':
        return car.categoryScores.luxury;
      case 'economy':
        return car.categoryScores.economy;
      case 'reliability':
        return car.categoryScores.reliability;
      case 'value':
        return car.categoryScores.value;
      default:
        return 0.0;
    }
  }

  Widget _buildSummary(BuildContext context, ThemeData theme) {
    if (_comparisonResult == null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(Responsive.scaleWidth(context, 20)),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Responsive.scaleWidth(context, 16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  color: theme.colorScheme.primary),
              SizedBox(width: Responsive.scaleWidth(context, 8)),
              Text(
                'AI Summary',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.scaleHeight(context, 16)),
          Text(
            _comparisonResult!.summary,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// Fullscreen landscape comparison screen
class _FullscreenComparisonScreen extends StatelessWidget {
  final CarComparisonResult comparisonResult;
  final List<CarData> selectedCars;

  const _FullscreenComparisonScreen({
    required this.comparisonResult,
    required this.selectedCars,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Comparison - ${selectedCars.length} Cars'),
        actions: [
          IconButton(
            icon: Icon(Icons.rotate_right_rounded),
            onPressed: () {
              // Rotate screen (device will handle orientation)
            },
            tooltip: 'Rotate to landscape',
          ),
        ],
      ),
      body: OrientationBuilder(
        builder: (context, orientation) {
          return SingleChildScrollView(
            scrollDirection: orientation == Orientation.landscape
                ? Axis.horizontal
                : Axis.vertical,
            child: orientation == Orientation.landscape
                ? _buildLandscapeView(context, theme)
                : _buildPortraitView(context, theme),
          );
        },
      ),
    );
  }

  Widget _buildLandscapeView(BuildContext context, ThemeData theme) {
    return Container(
      padding: EdgeInsets.all(Responsive.scaleWidth(context, 24)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category scores column
          Container(
            width: Responsive.scaleWidth(context, 250),
            padding: EdgeInsets.all(Responsive.scaleWidth(context, 16)),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius:
                  BorderRadius.circular(Responsive.scaleWidth(context, 12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Category Scores',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: Responsive.scaleHeight(context, 16)),
                ...[
                  'Performance',
                  'Comfort',
                  'Luxury',
                  'Economy',
                  'Reliability',
                  'Value'
                ].map((catName) {
                  final category = catName.toLowerCase().replaceAll(' ', '');
                  return Padding(
                    padding: EdgeInsets.only(
                        bottom: Responsive.scaleHeight(context, 12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          catName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            fontSize: Responsive.fontSize(context, 11),
                          ),
                        ),
                        SizedBox(height: Responsive.scaleHeight(context, 4)),
                        ...comparisonResult.cars.map((car) {
                          final score = _getCategoryScore(car, category);
                          return Padding(
                            padding: EdgeInsets.only(
                                bottom: Responsive.scaleHeight(context, 4)),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                        Responsive.scaleWidth(context, 10)),
                                    child: Container(
                                      height:
                                          Responsive.scaleHeight(context, 8),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.outlineVariant
                                            .withOpacity(0.2),
                                      ),
                                      child: FractionallySizedBox(
                                        widthFactor: score / 10,
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                theme.colorScheme.primary,
                                                theme.colorScheme
                                                    .primaryContainer,
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                    width: Responsive.scaleWidth(context, 8)),
                                SizedBox(
                                  width: Responsive.scaleWidth(context, 35),
                                  child: Text(
                                    score.toStringAsFixed(1),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize:
                                          Responsive.fontSize(context, 11),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          SizedBox(width: Responsive.scaleWidth(context, 16)),
          // Car names and scores column
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: comparisonResult.cars.asMap().entries.map((entry) {
                  final index = entry.key;
                  final car = entry.value;
                  return Container(
                    margin: EdgeInsets.only(
                      right: index < comparisonResult.cars.length - 1
                          ? Responsive.scaleWidth(context, 16)
                          : 0,
                    ),
                    width: Responsive.scaleWidth(context, 200),
                    padding: EdgeInsets.all(Responsive.scaleWidth(context, 16)),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(
                          Responsive.scaleWidth(context, 12)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          car.name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: Responsive.fontSize(context, 14),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: Responsive.scaleHeight(context, 8)),
                        Text(
                          'Rank: ${car.rank}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            fontSize: Responsive.fontSize(context, 12),
                          ),
                        ),
                        Text(
                          'Score: ${car.finalScore.toStringAsFixed(1)}/10',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: Responsive.fontSize(context, 12),
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortraitView(BuildContext context, ThemeData theme) {
    return Padding(
      padding: Responsive.padding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rotate device to landscape for better view',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: Responsive.scaleHeight(context, 24)),
          // Category scores in portrait
          Container(
            padding: EdgeInsets.all(Responsive.scaleWidth(context, 16)),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius:
                  BorderRadius.circular(Responsive.scaleWidth(context, 12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Category Scores',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: Responsive.scaleHeight(context, 16)),
                ...[
                  'Performance',
                  'Comfort',
                  'Luxury',
                  'Economy',
                  'Reliability',
                  'Value'
                ].map((catName) {
                  final category = catName.toLowerCase().replaceAll(' ', '');
                  return Padding(
                    padding: EdgeInsets.only(
                        bottom: Responsive.scaleHeight(context, 12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          catName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            fontSize: Responsive.fontSize(context, 12),
                          ),
                        ),
                        SizedBox(height: Responsive.scaleHeight(context, 8)),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: comparisonResult.cars
                                .asMap()
                                .entries
                                .map((entry) {
                              final index = entry.key;
                              final car = entry.value;
                              final score = _getCategoryScore(car, category);
                              return Container(
                                margin: EdgeInsets.only(
                                  right:
                                      index < comparisonResult.cars.length - 1
                                          ? Responsive.scaleWidth(context, 12)
                                          : 0,
                                ),
                                width: Responsive.scaleWidth(context, 120),
                                child: Column(
                                  children: [
                                    Text(
                                      car.name,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w500,
                                        fontSize:
                                            Responsive.fontSize(context, 11),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                    SizedBox(
                                        height:
                                            Responsive.scaleHeight(context, 8)),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                          Responsive.scaleWidth(context, 20)),
                                      child: Container(
                                        height:
                                            Responsive.scaleHeight(context, 12),
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: theme
                                              .colorScheme.outlineVariant
                                              .withOpacity(0.2),
                                        ),
                                        child: FractionallySizedBox(
                                          widthFactor: score / 10,
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  theme.colorScheme.primary,
                                                  theme.colorScheme
                                                      .primaryContainer,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                        height:
                                            Responsive.scaleHeight(context, 6)),
                                    Text(
                                      score.toStringAsFixed(1),
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize:
                                            Responsive.fontSize(context, 12),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _getCategoryScore(CarComparisonScore car, String category) {
    switch (category) {
      case 'performance':
        return car.categoryScores.performance;
      case 'comfort':
        return car.categoryScores.comfort;
      case 'luxury':
        return car.categoryScores.luxury;
      case 'economy':
        return car.categoryScores.economy;
      case 'reliability':
        return car.categoryScores.reliability;
      case 'value':
        return car.categoryScores.value;
      default:
        return 0.0;
    }
  }
}
