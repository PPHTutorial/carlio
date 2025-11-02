import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../models/car_data.dart';

class CacheService {
  static const String _cacheFileName = 'cars_cache.json';
  static const String _cacheMetadataFile = 'cache_metadata.json';

  Future<String> _getCacheDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${directory.path}/cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir.path;
  }

  Future<File> _getCacheFile() async {
    final cacheDir = await _getCacheDirectory();
    return File('$cacheDir/$_cacheFileName');
  }

  Future<File> _getMetadataFile() async {
    final cacheDir = await _getCacheDirectory();
    return File('$cacheDir/$_cacheMetadataFile');
  }

  Future<void> saveCars(List<CarData> cars) async {
    try {
      final file = await _getCacheFile();
      final jsonList = cars.map((car) => _carDataToJson(car)).toList();
      await file.writeAsString(json.encode(jsonList));
      
      // Save metadata
      final metadataFile = await _getMetadataFile();
      final metadata = {
        'lastUpdated': DateTime.now().toIso8601String(),
        'count': cars.length,
        'pagesCached': _calculatePagesCached(cars.length),
      };
      await metadataFile.writeAsString(json.encode(metadata));
    } catch (e) {
      print('Error saving cache: $e');
    }
  }

  Future<List<CarData>> loadCars() async {
    try {
      final file = await _getCacheFile();
      if (!await file.exists()) {
        return [];
      }

      final jsonString = await file.readAsString();
      final List<dynamic> jsonData = json.decode(jsonString);
      return jsonData.map((json) => _carDataFromJson(json)).toList();
    } catch (e) {
      print('Error loading cache: $e');
      return [];
    }
  }

  Future<void> appendCars(List<CarData> newCars) async {
    final existingCars = await loadCars();
    final existingIds = existingCars.map((c) => c.id).toSet();
    
    // Filter out duplicates
    final uniqueNewCars = newCars.where((car) => !existingIds.contains(car.id)).toList();
    
    if (uniqueNewCars.isNotEmpty) {
      existingCars.addAll(uniqueNewCars);
      await saveCars(existingCars);
    }
  }

  Future<Map<String, dynamic>?> getMetadata() async {
    try {
      final file = await _getMetadataFile();
      if (!await file.exists()) {
        return null;
      }

      final jsonString = await file.readAsString();
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      print('Error loading metadata: $e');
      return null;
    }
  }

  Future<void> clearCache() async {
    try {
      final file = await _getCacheFile();
      final metadataFile = await _getMetadataFile();
      
      if (await file.exists()) {
        await file.delete();
      }
      if (await metadataFile.exists()) {
        await metadataFile.delete();
      }
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  int _calculatePagesCached(int carCount) {
    // Assuming 30 cars per page
    return (carCount / 30).ceil();
  }

  Map<String, dynamic> _carDataToJson(CarData car) {
    return {
      'id': car.id,
      'name': car.name,
      'slug': car.slug,
      'number of shots': car.numberOfShots,
      'produced in': car.producedIn,
      'last updated': car.lastUpdated,
      'data': {
        'country of origin': car.data.countryOfOrigin,
        'produced in': car.data.producedIn,
        'numbers built': car.data.numbersBuilt,
        'engine type': car.data.engineType,
        'designed by': car.data.designedBy,
        'source': car.data.source,
        'last updated': car.data.lastUpdated,
        'article': car.data.article,
      },
      'imgs': car.imgs,
      'specs': car.specs.map((spec) => {
        'spec': spec.spec,
        'value': spec.value,
      }).toList(),
    };
  }

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
}

