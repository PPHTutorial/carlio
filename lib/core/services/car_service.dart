import 'dart:convert';
import '../../models/car_data.dart';
import '../../core/utils/constants.dart';
import '../../scraper/car_scraper.dart';
import 'cache_service.dart';
import 'package:flutter/services.dart';

class CarService {
  static List<CarData>? _cachedCars;
  static bool _isScraping = false;
  final CacheService _cacheService = CacheService();
  final CarScraper _scraper = CarScraper();

  /// Load cars from cache first, then scrape if needed
  Future<List<CarData>> loadCars({bool forceRefresh = false}) async {
    // Return in-memory cache if available and not forcing refresh
    if (_cachedCars != null && !forceRefresh) {
      return _cachedCars!;
    }

    // Try to load from disk cache
    if (!forceRefresh) {
      final cachedCars = await _cacheService.loadCars();
      if (cachedCars.isNotEmpty) {
        _cachedCars = cachedCars;
        return cachedCars;
      }
    }

    // Fallback to bundled JSON if available (for initial release)
    try {
      try {
        final jsonString = await rootBundle.loadString(AppConstants.carsDataFile);
        final List<dynamic> jsonData = json.decode(jsonString);
        _cachedCars = jsonData.map((json) => _carDataFromJson(json)).toList();
        // Save to cache for future use
        await _cacheService.saveCars(_cachedCars!);
        return _cachedCars!;
      } catch (e) {
        // Assets not available, continue to scraping
      }
    } catch (e) {
      print('Error loading from assets: $e');
    }

    // If no cache and no assets, start scraping (will return empty initially)
    return [];
  }

  /// Scrape cars on-demand with pagination - sequential per-item scraping
  /// Scrapes each item fully before moving to the next
  Future<List<CarData>> scrapeCars({
    int startPage = 0,
    int endPage = 1,
    bool appendToCache = true,
    Function(CarData)? onCarScraped, // Callback when each car is fully scraped
  }) async {
    if (_isScraping) {
      // Return existing cache if already scraping
      return _cachedCars ?? [];
    }

    try {
      _isScraping = true;

      // Load existing cache
      final existingCars = await _cacheService.loadCars();
      final existingIds = existingCars.map((c) => c.id).toSet();
      _cachedCars = existingCars;

      // Scrape page by page, item by item
      for (int page = startPage; page <= endPage; page++) {
        // Get basic info for this page only
        final basicInfos = await _scrapePageBasicInfo(page);

        if (basicInfos.isEmpty) continue;

        // Filter out already scraped cars for this page
        final newBasicInfos = basicInfos
            .where((info) => !existingIds.contains(info.id))
            .toList();

        if (newBasicInfos.isEmpty) continue;

        // Scrape each item fully before moving to next
        for (int i = 0; i < newBasicInfos.length; i++) {
          final info = newBasicInfos[i];
          
          try {
            // Fully scrape this item (details, specs, images - everything)
            final carData = await _scraper.scrapeCarDetails(info);
            
            // Immediately cache this fully scraped item
            if (appendToCache) {
              await _cacheService.appendCars([carData]);
            }

            // Add to in-memory cache
            existingCars.add(carData);
            existingIds.add(carData.id);
            _cachedCars = existingCars;

            // Notify UI that a new car is ready
            if (onCarScraped != null) {
              onCarScraped(carData);
            }

            // Add delay between requests to be respectful
            await Future.delayed(const Duration(milliseconds: 800));
          } catch (e) {
            print('Error scraping ${info.name}: $e');
            // Continue to next item even if one fails
          }
        }

        // Small delay between pages
        if (page < endPage) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      return _cachedCars ?? [];
    } catch (e) {
      print('Error scraping cars: $e');
      return _cachedCars ?? [];
    } finally {
      _isScraping = false;
    }
  }

  /// Scrape basic info for a single page
  Future<List<CarBasicInfo>> _scrapePageBasicInfo(int page) async {
    final startIndex = page * CarScraper.carsPerPage;
    String url;
    
    if (page == 0) {
      url = '${CarScraper.baseUrl}/search/&modified=2000';
    } else {
      url = '${CarScraper.baseUrl}/search/&keys=&method=&carspagestart=$startIndex&modified=2000';
    }

    try {
      final html = await _scraper.fetchPage(url);
      final cars = _scraper.parseSearchPage(html);
      
      // Add delay to be respectful to the server
      await Future.delayed(const Duration(milliseconds: 500));
      
      return cars;
    } catch (e) {
      print('Error scraping page ${page + 1}: $e');
      return [];
    }
  }

  /// Load more cars (pagination) with progressive updates
  Future<List<CarData>> loadMoreCars({
    required int currentPage,
    int pagesToLoad = 1,
    Function(CarData)? onCarScraped,
  }) async {
    final endPage = currentPage + pagesToLoad - 1;
    return await scrapeCars(
      startPage: currentPage,
      endPage: endPage,
      appendToCache: true,
      onCarScraped: onCarScraped,
    );
  }

  /// Check if more data can be loaded
  Future<bool> hasMoreData() async {
    final metadata = await _cacheService.getMetadata();
    if (metadata == null) return true;

    final pagesCached = metadata['pagesCached'] as int? ?? 0;
    // Assuming max pages (adjust based on actual data)
    return pagesCached < 67;
  }

  /// Get cache metadata
  Future<Map<String, dynamic>?> getCacheMetadata() async {
    return await _cacheService.getMetadata();
  }

  /// Clear all cache
  Future<void> clearCache() async {
    await _cacheService.clearCache();
    _cachedCars = null;
  }

  bool get isScraping => _isScraping;

  CarData _carDataFromJson(Map<String, dynamic> json) {
    return CarData(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      numberOfShots: json['number of shots'] as int? ?? 0,
      producedIn: json['produced in'] as int? ?? 0,
      lastUpdated: json['last updated'] as String? ?? '',
      data: _carDetailsFromJson(json['data'] as Map<String, dynamic>? ?? {}),
      imgs: List<String>.from(json['imgs'] as List? ?? []),
      specs: (json['specs'] as List? ?? [])
          .map((s) => _specificationFromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  CarDetails _carDetailsFromJson(Map<String, dynamic> json) {
    final details = CarDetails();
    details.countryOfOrigin = json['country of origin'] as String?;
    details.producedIn = json['produced in'] as int?;
    details.numbersBuilt = json['numbers built'] as String?;
    details.engineType = json['engine type'] as String?;
    details.designedBy = json['designed by'] as String?;
    details.source = json['source'] as String?;
    details.lastUpdated = json['last updated'] as String?;
    details.article = json['article'] as String?;
    return details;
  }

  Specification _specificationFromJson(Map<String, dynamic> json) {
    return Specification(
      spec: json['spec'] as String? ?? '',
      value: List<Map<String, dynamic>>.from(json['value'] as List? ?? []),
    );
  }

  void dispose() {
    _scraper.dispose();
  }
}
