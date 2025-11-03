import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'car_comparison_service.dart';
import '../../models/car_data.dart';

class SavedComparison {
  final String id;
  final List<String> carIds;
  final List<String> carNames;
  final CarComparisonResult result;
  final DateTime createdAt;
  final String? notes;

  SavedComparison({
    required this.id,
    required this.carIds,
    required this.carNames,
    required this.result,
    required this.createdAt,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'carIds': carIds,
      'carNames': carNames,
      'result': {
        'winner': result.winner,
        'cars': result.cars.map((car) => {
          'name': car.name,
          'finalScore': car.finalScore,
          'rank': car.rank,
          'categoryScores': {
            'performance': car.categoryScores.performance,
            'comfort': car.categoryScores.comfort,
            'luxury': car.categoryScores.luxury,
            'economy': car.categoryScores.economy,
            'reliability': car.categoryScores.reliability,
            'value': car.categoryScores.value,
          },
        }).toList(),
        'summary': result.summary,
      },
      'createdAt': createdAt.toIso8601String(),
      'notes': notes,
    };
  }

  factory SavedComparison.fromJson(Map<String, dynamic> json) {
    return SavedComparison(
      id: json['id'] as String,
      carIds: List<String>.from(json['carIds'] as List),
      carNames: List<String>.from(json['carNames'] as List),
      result: CarComparisonResult(
        cars: (json['result']['cars'] as List).map((carJson) {
          return CarComparisonScore(
            name: carJson['name'] as String,
            finalScore: (carJson['finalScore'] as num).toDouble(),
            rank: carJson['rank'] as int,
            categoryScores: CategoryScores(
              performance: (carJson['categoryScores']['performance'] as num).toDouble(),
              comfort: (carJson['categoryScores']['comfort'] as num).toDouble(),
              luxury: (carJson['categoryScores']['luxury'] as num).toDouble(),
              economy: (carJson['categoryScores']['economy'] as num).toDouble(),
              reliability: (carJson['categoryScores']['reliability'] as num).toDouble(),
              value: (carJson['categoryScores']['value'] as num).toDouble(),
            ),
          );
        }).toList(),
        winner: json['result']['winner'] as String,
        summary: json['result']['summary'] as String,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      notes: json['notes'] as String?,
    );
  }
}

class SavedComparisonsService {
  static const String _comparisonsKey = 'saved_comparisons';
  static SavedComparisonsService? _instance;

  static SavedComparisonsService get instance {
    _instance ??= SavedComparisonsService._();
    return _instance!;
  }

  SavedComparisonsService._();

  /// Save a comparison result
  Future<String> saveComparison({
    required List<CarData> selectedCars,
    required CarComparisonResult result,
    String? notes,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final comparisons = await getSavedComparisons();

      final savedComparison = SavedComparison(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        carIds: selectedCars.map((car) => car.id).toList(),
        carNames: selectedCars.map((car) => car.name).toList(),
        result: result,
        createdAt: DateTime.now(),
        notes: notes,
      );

      comparisons.insert(0, savedComparison); // Add to beginning (most recent first)

      // Limit to last 50 comparisons to prevent storage bloat
      if (comparisons.length > 50) {
        comparisons.removeRange(50, comparisons.length);
      }

      await _saveComparisons(prefs, comparisons);
      return savedComparison.id;
    } catch (e) {
      print('Error saving comparison: $e');
      rethrow;
    }
  }

  /// Get all saved comparisons (most recent first)
  Future<List<SavedComparison>> getSavedComparisons() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final comparisonsJson = prefs.getString(_comparisonsKey);
      if (comparisonsJson == null) return [];

      final List<dynamic> decoded = json.decode(comparisonsJson);
      return decoded
          .map((json) => SavedComparison.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting saved comparisons: $e');
      return [];
    }
  }

  /// Get a specific comparison by ID
  Future<SavedComparison?> getComparisonById(String id) async {
    try {
      final comparisons = await getSavedComparisons();
      return comparisons.firstWhere(
        (comparison) => comparison.id == id,
        orElse: () => throw Exception('Comparison not found'),
      );
    } catch (e) {
      print('Error getting comparison by ID: $e');
      return null;
    }
  }

  /// Delete a saved comparison
  Future<bool> deleteComparison(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final comparisons = await getSavedComparisons();
      final initialLength = comparisons.length;
      comparisons.removeWhere((comparison) => comparison.id == id);

      if (comparisons.length < initialLength) {
        await _saveComparisons(prefs, comparisons);
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting comparison: $e');
      return false;
    }
  }

  /// Update notes for a saved comparison
  Future<bool> updateComparisonNotes(String id, String? notes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final comparisons = await getSavedComparisons();
      final index = comparisons.indexWhere((comparison) => comparison.id == id);

      if (index != -1) {
        final updatedComparison = SavedComparison(
          id: comparisons[index].id,
          carIds: comparisons[index].carIds,
          carNames: comparisons[index].carNames,
          result: comparisons[index].result,
          createdAt: comparisons[index].createdAt,
          notes: notes,
        );
        comparisons[index] = updatedComparison;
        await _saveComparisons(prefs, comparisons);
        return true;
      }
      return false;
    } catch (e) {
      print('Error updating comparison notes: $e');
      return false;
    }
  }

  /// Clear all saved comparisons
  Future<void> clearAllComparisons() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_comparisonsKey);
    } catch (e) {
      print('Error clearing comparisons: $e');
    }
  }

  /// Get the count of saved comparisons
  Future<int> getComparisonCount() async {
    final comparisons = await getSavedComparisons();
    return comparisons.length;
  }

  /// Save comparisons to SharedPreferences
  Future<void> _saveComparisons(
    SharedPreferences prefs,
    List<SavedComparison> comparisons,
  ) async {
    try {
      final jsonList = comparisons.map((c) => c.toJson()).toList();
      await prefs.setString(_comparisonsKey, json.encode(jsonList));
    } catch (e) {
      print('Error saving comparisons: $e');
      rethrow;
    }
  }
}

