import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/responsive.dart';
import '../../models/car_data.dart';
import '../car/car_detail_screen.dart';
import '../car/car_list_screen.dart';

class GarageScreen extends StatefulWidget {
  final List<CarData> cars;
  final VoidCallback? onLoadMore;
  final bool isLoadingMore;

  const GarageScreen({
    super.key,
    required this.cars,
    this.onLoadMore,
    this.isLoadingMore = false,
  });

  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends State<GarageScreen> {
  String _searchQuery = '';
  String _displaySearchQuery = ''; // For immediate UI update
  String? _selectedBrand;
  int? _selectedYear;
  Timer? _searchDebounceTimer;
  
  // Cached values to avoid recalculation on every build
  List<CarData>? _cachedFilteredCars;
  String? _lastSearchQuery;
  String? _lastSelectedBrand;
  int? _lastSelectedYear;
  int _lastCarsLength = 0;
  
  List<String>? _cachedUniqueBrands;
  List<int>? _cachedUniqueYears;
  late final TextEditingController _searchController;
  
  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }
  
  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<CarData> get _filteredCars {
    // Only recalculate if filters or car list changed
    if (_cachedFilteredCars == null ||
        _searchQuery != _lastSearchQuery ||
        _selectedBrand != _lastSelectedBrand ||
        _selectedYear != _lastSelectedYear ||
        widget.cars.length != _lastCarsLength) {
      
      var filtered = widget.cars;

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        filtered = filtered.where((car) {
          return car.name.toLowerCase().contains(query) ||
              (car.data.countryOfOrigin?.toLowerCase().contains(query) ?? false);
        }).toList();
      }

      final selectedBrand = _selectedBrand;
      if (selectedBrand != null) {
        final brandLower = selectedBrand.toLowerCase();
        filtered = filtered.where((car) {
          return car.name.toLowerCase().startsWith(brandLower);
        }).toList();
      }

      if (_selectedYear != null) {
        final year = _selectedYear!;
        filtered = filtered.where((car) {
          return car.producedIn == year || car.data.producedIn == year;
        }).toList();
      }

      _cachedFilteredCars = filtered;
      _lastSearchQuery = _searchQuery;
      _lastSelectedBrand = _selectedBrand;
      _lastSelectedYear = _selectedYear;
      _lastCarsLength = widget.cars.length;
    }

    return _cachedFilteredCars!;
  }

  List<String> get _uniqueBrands {
    if (_cachedUniqueBrands == null || widget.cars.length != _lastCarsLength) {
      final brands = <String>{};
      for (final car in widget.cars) {
        final parts = car.name.split(' ');
        if (parts.isNotEmpty) {
          brands.add(parts.first);
        }
      }
      _cachedUniqueBrands = brands.toList()..sort();
    }
    return _cachedUniqueBrands!;
  }

  List<int> get _uniqueYears {
    if (_cachedUniqueYears == null || widget.cars.length != _lastCarsLength) {
      final years = <int>{};
      for (final car in widget.cars) {
        if (car.producedIn > 0) years.add(car.producedIn);
        if (car.data.producedIn != null && car.data.producedIn! > 0) {
          years.add(car.data.producedIn!);
        }
      }
      _cachedUniqueYears = years.toList()..sort((a, b) => b.compareTo(a));
    }
    return _cachedUniqueYears!;
  }
  
  @override
  void didUpdateWidget(GarageScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Invalidate cache if cars list changed
    if (oldWidget.cars.length != widget.cars.length) {
      _cachedFilteredCars = null;
      _cachedUniqueBrands = null;
      _cachedUniqueYears = null;
      _lastCarsLength = widget.cars.length;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: SafeArea(
        child: Column(
          children: [
            _buildPremiumHeader(context, theme),
            _buildPremiumFilters(context, theme),
            Expanded(
              child: _filteredCars.isEmpty
                  ? _buildEmptyState(context, theme)
                  : CarListScreen(
                      cars: _filteredCars,
                      onCarTap: (car) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CarDetailScreen(car: car),
                          ),
                        );
                      },
                      onLoadMore: widget.onLoadMore,
                      isLoadingMore: widget.isLoadingMore,
                    ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildPremiumHeader(BuildContext context, ThemeData theme) {
    final padding = Responsive.padding(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        padding.left,
        padding.top,
        padding.right,
        padding.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Garage',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: Responsive.scaleHeight(context, 4)),
                    Text(
                      '${_filteredCars.length} ${_filteredCars.length == 1 ? 'car' : 'cars'} in collection',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.scaleHeight(context, 16)),
          _buildPremiumSearchField(context, theme),
        ],
      ),
    );
  }

  Widget _buildPremiumSearchField(BuildContext context, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Responsive.scaleWidth(context, 16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          // Update display immediately for UI responsiveness
          _displaySearchQuery = value;
          
          // Debounce actual filtering to avoid performance issues
          _searchDebounceTimer?.cancel();
          _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() {
                _searchQuery = value;
              });
            }
          });
          // Update UI for clear button
          setState(() {});
        },
        decoration: InputDecoration(
          hintText: 'Search by name or country...',
          prefixIcon: Icon(
            Icons.search_rounded,
            size: Responsive.fontSize(context, 24),
            color: theme.colorScheme.onSurfaceVariant,
          ),
          suffixIcon: _displaySearchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    _searchDebounceTimer?.cancel();
                    setState(() {
                      _displaySearchQuery = '';
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: Responsive.scaleWidth(context, 20),
            vertical: Responsive.scaleHeight(context, 16),
          ),
        ),
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPremiumFilters(BuildContext context, ThemeData theme) {
    return Container(
      
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.scaleWidth(context, 8),
        vertical: Responsive.scaleHeight(context, 8),
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildPremiumFilterChip(
              context,
              theme,
              label: 'All Brands',
              isSelected: _selectedBrand == null,
              onTap: () => setState(() => _selectedBrand = null),
            ),
            SizedBox(width: Responsive.scaleWidth(context, 12)),
            ..._uniqueBrands.take(12).map((brand) => Padding(
                  padding: EdgeInsets.only(right: Responsive.scaleWidth(context, 12)),
                  child: _buildPremiumFilterChip(
                    context,
                    theme,
                    label: brand,
                    isSelected: _selectedBrand == brand,
                    onTap: () => setState(() => _selectedBrand = brand),
                  ),
                )),
            SizedBox(width: Responsive.scaleWidth(context, 8)),
            Container(
              width: 1,
              height: Responsive.scaleHeight(context, 24),
              color: theme.colorScheme.outlineVariant,
            ),
            SizedBox(width: Responsive.scaleWidth(context, 16)),
            _buildPremiumFilterChip(
              context,
              theme,
              label: 'All Years',
              isSelected: _selectedYear == null,
              onTap: () => setState(() => _selectedYear = null),
            ),
            SizedBox(width: Responsive.scaleWidth(context, 12)),
            ..._uniqueYears.take(10).map((year) => Padding(
                  padding: EdgeInsets.only(right: Responsive.scaleWidth(context, 12)),
                  child: _buildPremiumFilterChip(
                    context,
                    theme,
                    label: year.toString(),
                    isSelected: _selectedYear == year,
                    onTap: () => setState(() => _selectedYear = year),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumFilterChip(
    BuildContext context,
    ThemeData theme, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Responsive.scaleWidth(context, 20)),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.scaleWidth(context, 16),
            vertical: Responsive.scaleHeight(context, 10),
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(Responsive.scaleWidth(context, 20)),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: Responsive.padding(context),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(Responsive.scaleWidth(context, 24)),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
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
              'Try adjusting your search or filters',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
