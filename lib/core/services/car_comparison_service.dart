import 'dart:math';
import '../../models/car_data.dart';

class CarComparisonResult {
  final List<CarComparisonScore> cars;
  final String winner;
  final String summary;

  CarComparisonResult({
    required this.cars,
    required this.winner,
    required this.summary,
  });

  Map<String, dynamic> toJson() {
    return {
      'cars': cars.map((c) => c.toJson()).toList(),
      'winner': winner,
      'summary': summary,
    };
  }
}

class CarComparisonScore {
  final String name;
  final double finalScore;
  final int rank;
  final CategoryScores categoryScores;

  CarComparisonScore({
    required this.name,
    required this.finalScore,
    required this.rank,
    required this.categoryScores,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'finalScore': finalScore,
      'rank': rank,
      'categoryScores': categoryScores.toJson(),
    };
  }
}

class CategoryScores {
  final double performance;
  final double comfort;
  final double luxury;
  final double economy;
  final double reliability;
  final double value;

  CategoryScores({
    required this.performance,
    required this.comfort,
    required this.luxury,
    required this.economy,
    required this.reliability,
    required this.value,
  });

  Map<String, dynamic> toJson() {
    return {
      'performance': performance,
      'comfort': comfort,
      'luxury': luxury,
      'economy': economy,
      'reliability': reliability,
      'value': value,
    };
  }
}

class CarComparisonService {
  // Weights
  static const double weightPerformance = 0.30;
  static const double weightComfort = 0.20;
  static const double weightLuxury = 0.15;
  static const double weightEconomy = 0.20;
  static const double weightReliability = 0.10;
  static const double weightValue = 0.05;

  // Max values for normalization (based on typical car specs)
  static const double maxHorsepower = 1500.0;
  static const double maxTorque = 2000.0;
  static const double maxTopSpeed = 450.0;
  static const double minAcceleration = 1.5; // Best 0-100 time
  static const double maxAcceleration = 15.0; // Worst 0-100 time
  static const double maxFuelEfficiency = 30.0; // km/L
  static const double maxPrice = 5000000.0; // $5M

  /// Compare up to 5 cars and return structured results
  static CarComparisonResult compareCars(List<CarData> cars) {
    if (cars.isEmpty) {
      throw ArgumentError('At least one car is required');
    }
    if (cars.length > 5) {
      throw ArgumentError('Maximum 5 cars allowed');
    }

    // Extract and normalize data for each car
    final carScores = <CarComparisonScore>[];
    
    for (var car in cars) {
      final extracted = _extractCarData(car);
      final categoryScores = _calculateCategoryScores(extracted, cars);
      final finalScore = _calculateFinalScore(categoryScores);
      
      carScores.add(CarComparisonScore(
        name: car.name,
        finalScore: finalScore,
        rank: 0, // Will be set after ranking
        categoryScores: categoryScores,
      ));
    }

    // Rank cars
    carScores.sort((a, b) => b.finalScore.compareTo(a.finalScore));
    for (int i = 0; i < carScores.length; i++) {
      carScores[i] = CarComparisonScore(
        name: carScores[i].name,
        finalScore: carScores[i].finalScore,
        rank: i + 1,
        categoryScores: carScores[i].categoryScores,
      );
    }

    // Determine winner
    final winner = carScores.first.name;

    // Generate summary
    final summary = _generateSummary(carScores, cars);

    return CarComparisonResult(
      cars: carScores,
      winner: winner,
      summary: summary,
    );
  }

  /// Extract numeric data from CarData specs (works with scraped/cached data)
  static Map<String, double> _extractCarData(CarData car) {
    final data = <String, double>{
      'horsepower': 0.0,
      'torque_nm': 0.0,
      'acceleration_0_100': 0.0,
      'top_speed': 0.0,
      'fuel_efficiency_kmpl': 0.0,
      'price': 0.0,
      'comfort_score': 5.0, // Default
      'luxury_score': 5.0, // Default
      'reliability_score': 5.0, // Default
      'weight_kg': 0.0,
    };

    // Iterate through all specs (works with scraped data structure)
    for (var spec in car.specs) {
      final specName = spec.spec.toLowerCase();
      
      // Extract from Performance figures or Engine specs
      if (specName.contains('performance') || specName.contains('engine')) {
        for (var entry in spec.value) {
          final component = (entry['component'] as String? ?? '').toLowerCase();
          final capacity = entry['capacity'] as String? ?? '';
          
          // Extract horsepower (multiple formats)
          if ((component.contains('power') || component.contains('combined power') || 
               component == 'power') && data['horsepower'] == 0.0) {
            final hp = _extractNumber(capacity, ['bhp', 'hp', 'ps', 'kw', 'w']);
            if (hp > 0) {
              // Convert kW to HP if needed
              if (capacity.toLowerCase().contains('kw')) {
                data['horsepower'] = hp * 1.341; // kW to HP
              } else if (capacity.toLowerCase().contains('w')) {
                data['horsepower'] = hp / 745.7; // Watts to HP
              } else {
                data['horsepower'] = hp;
              }
            }
          }
          
          // Extract torque (multiple formats)
          if ((component.contains('torque') || component.contains('combined torque') || 
               component == 'torque') && data['torque_nm'] == 0.0) {
            final torque = _extractNumber(capacity, ['nm', 'ft lbs', 'lb-ft', 'ft-lbs', 'lb ft']);
            if (torque > 0) {
              // Convert ft-lbs to Nm if needed
              final capacityLower = capacity.toLowerCase();
              if (capacityLower.contains('ft') && (capacityLower.contains('lbs') || capacityLower.contains('lb'))) {
                data['torque_nm'] = torque * 1.356; // ft-lbs to Nm
              } else {
                data['torque_nm'] = torque;
              }
            }
          }
          
          // Extract top speed
          if ((component.contains('top speed') || component.contains('max speed') || 
               component == 'top speed') && data['top_speed'] == 0.0) {
            final speed = _extractNumber(capacity, ['km/h', 'mph', 'kmh', 'kph']);
            if (speed > 0) {
              // Convert mph to km/h if needed
              if (capacity.toLowerCase().contains('mph')) {
                data['top_speed'] = speed * 1.609;
              } else {
                data['top_speed'] = speed;
              }
            }
          }
          
          // Extract acceleration (0-100 km/h or 0-60 mph)
          if ((component.contains('0-100') || component.contains('0-60') || 
               component.contains('acceleration') || component.contains('0 to 100') ||
               component.contains('0 to 60')) && data['acceleration_0_100'] == 0.0) {
            final accel = _extractNumber(capacity, ['s', 'sec', 'seconds']);
            if (accel > 0) {
              // If it's 0-60 mph, convert to approximate 0-100 km/h
              if (component.contains('0-60') || component.contains('0 to 60')) {
                data['acceleration_0_100'] = accel * 1.55; // Approximate conversion
              } else {
                data['acceleration_0_100'] = accel;
              }
            }
          }
        }
      }
      
      // Extract fuel efficiency from any spec containing fuel/economy
      if (specName.contains('fuel') || specName.contains('economy') || 
          specName.contains('consumption') || specName.contains('dimensions')) {
        for (var entry in spec.value) {
          final component = (entry['component'] as String? ?? '').toLowerCase();
          final capacity = entry['capacity'] as String? ?? '';
          
          if ((component.contains('fuel') || component.contains('consumption') || 
               component.contains('efficiency') || component.contains('economy')) && 
              data['fuel_efficiency_kmpl'] == 0.0) {
            final efficiency = _extractNumber(capacity, ['km/l', 'kmpl', 'l/100km', 'mpg', 'km/liter']);
            if (efficiency > 0) {
              final capacityLower = capacity.toLowerCase();
              // Convert L/100km to km/L
              if (capacityLower.contains('l/100km') || capacityLower.contains('l/100 km')) {
                data['fuel_efficiency_kmpl'] = 100.0 / efficiency;
              } 
              // Convert mpg (US) to km/L (approximate: 1 mpg ≈ 0.425 km/L)
              else if (capacityLower.contains('mpg')) {
                data['fuel_efficiency_kmpl'] = efficiency * 0.425;
              } 
              else {
                data['fuel_efficiency_kmpl'] = efficiency;
              }
            }
          }
        }
      }
      
      // Extract weight from Dimensions spec
      if (specName.contains('dimension') || specName.contains('weight')) {
        for (var entry in spec.value) {
          final component = (entry['component'] as String? ?? '').toLowerCase();
          final capacity = entry['capacity'] as String? ?? '';
          
          if (component.contains('weight') && data['weight_kg'] == 0.0) {
            final weight = _extractNumber(capacity, ['kg', 'kilo', 'lbs', 'pounds', 'lb']);
            if (weight > 0) {
              final capacityLower = capacity.toLowerCase();
              // Convert lbs to kg
              if (capacityLower.contains('lbs') || capacityLower.contains('pounds') || capacityLower.contains('lb')) {
                data['weight_kg'] = weight * 0.453592; // lbs to kg
              } else {
                data['weight_kg'] = weight;
              }
            }
          }
        }
      }
    }

    // Estimate comfort/luxury based on engine type, country, and specs
    if (car.data.engineType != null) {
      final engineType = car.data.engineType!.toLowerCase();
      if (engineType.contains('hybrid') || engineType.contains('electric')) {
        data['comfort_score'] = 7.5;
        data['luxury_score'] = 7.0;
      }
    }
    
    // Estimate based on country of origin
    if (car.data.countryOfOrigin != null) {
      final country = car.data.countryOfOrigin!.toLowerCase();
      if (country.contains('germany') || country.contains('italy')) {
        data['luxury_score'] = max(data['luxury_score']!, 7.5);
        data['reliability_score'] = max(data['reliability_score']!, 7.0);
      } else if (country.contains('japan')) {
        data['reliability_score'] = max(data['reliability_score']!, 8.0);
      }
    }

    // Estimate price based on performance (rough approximation)
    if (data['price'] == 0.0) {
      final hp = data['horsepower']!;
      final basePrice = hp * 100; // Rough estimate
      data['price'] = basePrice.clamp(20000.0, maxPrice);
    }

    return data;
  }

  /// Extract number from string with units (handles various formats from scraped data)
  static double _extractNumber(String text, List<String> units) {
    if (text.isEmpty) return 0.0;
    
    // Remove commas, spaces, and common separators
    final cleaned = text.replaceAll(',', '')
                        .replaceAll(' ', '')
                        .replaceAll('(', '')
                        .replaceAll(')', '');
    
    // Try to extract number - handle cases like "818 bhp / 610 kW" or "2.9 s"
    // Look for patterns: number, number/number, or number with unit
    final patterns = [
      // Pattern: "number" or "number.0"
      RegExp(r'^([\d.]+)'),
      // Pattern: "number / number" (take first number)
      RegExp(r'^([\d.]+)/'),
      // Pattern: "number number" (take first)
      RegExp(r'^([\d.]+)[a-zA-Z]'),
    ];
    
    for (var pattern in patterns) {
      final match = pattern.firstMatch(cleaned);
      if (match != null) {
        final numberStr = match.group(1) ?? '0';
        final parsed = double.tryParse(numberStr);
        if (parsed != null && parsed > 0) {
          return parsed;
        }
      }
    }
    
    // Fallback: extract any number from the string
    final regex = RegExp(r'([\d]+\.?[\d]*)');
    final match = regex.firstMatch(cleaned);
    if (match != null) {
      return double.tryParse(match.group(1) ?? '0') ?? 0.0;
    }
    
    return 0.0;
  }

  /// Calculate category scores (0-10)
  static CategoryScores _calculateCategoryScores(
    Map<String, double> data,
    List<CarData> allCars,
  ) {
    // Performance: horsepower, torque, acceleration, top speed
    final hpScore = _normalize(data['horsepower']!, 0, maxHorsepower, true);
    final torqueScore = _normalize(data['torque_nm']!, 0, maxTorque, true);
    final speedScore = _normalize(data['top_speed']!, 0, maxTopSpeed, true);
    final accelScore = data['acceleration_0_100']! > 0
        ? _normalize(data['acceleration_0_100']!, minAcceleration, maxAcceleration, false)
        : 5.0;
    
    final performance = ((hpScore * 0.3 + torqueScore * 0.3 + speedScore * 0.2 + accelScore * 0.2) * 10).clamp(0.0, 10.0);

    // Fuel Economy
    final economy = (_normalize(data['fuel_efficiency_kmpl']!, 0, maxFuelEfficiency, true) * 10).clamp(0.0, 10.0);

    // Comfort, Luxury, Reliability (use extracted or default values)
    final comfort = data['comfort_score']!.clamp(0.0, 10.0);
    final luxury = data['luxury_score']!.clamp(0.0, 10.0);
    final reliability = data['reliability_score']!.clamp(0.0, 10.0);

    // Value: inverse of price relative to performance
    final priceScore = data['price']! > 0
        ? _normalize(data['price']!, 0, maxPrice, false) * 10
        : 5.0;
    final value = (10.0 - priceScore).clamp(0.0, 10.0);

    return CategoryScores(
      performance: performance,
      comfort: comfort,
      luxury: luxury,
      economy: economy,
      reliability: reliability,
      value: value,
    );
  }

  /// Normalize value to 0-1 range
  static double _normalize(double value, double min, double max, bool higherIsBetter) {
    if (max == min) return 0.5; // Prevent divide by zero
    final normalized = (value - min) / (max - min);
    return (higherIsBetter ? normalized.clamp(0.0, 1.0) : (1.0 - normalized).clamp(0.0, 1.0)).toDouble();
  }

  /// Calculate weighted final score
  static double _calculateFinalScore(CategoryScores scores) {
    return (scores.performance * weightPerformance +
            scores.comfort * weightComfort +
            scores.luxury * weightLuxury +
            scores.economy * weightEconomy +
            scores.reliability * weightReliability +
            scores.value * weightValue)
        .clamp(0.0, 10.0)
        .toDouble();
  }

  /// Generate human-readable summary
  static String _generateSummary(List<CarComparisonScore> scores, List<CarData> cars) {
    if (scores.isEmpty) return 'No comparison available.';

    final buffer = StringBuffer();
    
    // Winner
    buffer.writeln('🏆 ${scores.first.name} takes the top spot with a score of ${scores.first.finalScore.toStringAsFixed(1)}/10, excelling in ${_getStrongestCategory(scores.first)}.');
    
    // Ranked results
    buffer.writeln('\nRankings:');
    for (var i = 0; i < scores.length && i < 5; i++) {
      final car = scores[i];
      final rankEmoji = ['🥇', '🥈', '🥉', '4️⃣', '5️⃣'][i];
      buffer.writeln('$rankEmoji ${car.rank}. ${car.name} (${car.finalScore.toStringAsFixed(1)}/10)');
    }
    
    // Strengths/weaknesses
    buffer.writeln('\nHighlights:');
    for (var i = 0; i < scores.length && i < 3; i++) {
      final car = scores[i];
      final strengths = _getStrengths(car);
      final weaknesses = _getWeaknesses(car);
      
      buffer.write('${car.name}: ');
      if (strengths.isNotEmpty) {
        buffer.write('Strong in ${strengths.join(', ')}. ');
      }
      if (weaknesses.isNotEmpty && i == 0) {
        buffer.write('Could improve in ${weaknesses.join(', ')}.');
      }
      buffer.writeln();
    }
    
    // Best fit
    buffer.writeln('\nBest fit:');
    if (scores.isNotEmpty) {
      buffer.writeln('• ${scores.first.name} - Best overall performance');
    }
    final bestEconomy = scores.reduce((a, b) => a.categoryScores.economy > b.categoryScores.economy ? a : b);
    if (bestEconomy.name != scores.first.name) {
      buffer.writeln('• ${bestEconomy.name} - Best fuel economy');
    }
    final bestValue = scores.reduce((a, b) => a.categoryScores.value > b.categoryScores.value ? a : b);
    if (bestValue.name != scores.first.name && bestValue.name != bestEconomy.name) {
      buffer.writeln('• ${bestValue.name} - Best value for money');
    }

    return buffer.toString();
  }

  static String _getStrongestCategory(CarComparisonScore score) {
    final scores = [
      ('Performance', score.categoryScores.performance),
      ('Comfort', score.categoryScores.comfort),
      ('Luxury', score.categoryScores.luxury),
      ('Economy', score.categoryScores.economy),
      ('Reliability', score.categoryScores.reliability),
      ('Value', score.categoryScores.value),
    ];
    scores.sort((a, b) => b.$2.compareTo(a.$2));
    return scores.first.$1;
  }

  static List<String> _getStrengths(CarComparisonScore score) {
    final strengths = <String>[];
    if (score.categoryScores.performance >= 8.0) strengths.add('performance');
    if (score.categoryScores.comfort >= 8.0) strengths.add('comfort');
    if (score.categoryScores.luxury >= 8.0) strengths.add('luxury');
    if (score.categoryScores.economy >= 8.0) strengths.add('fuel economy');
    if (score.categoryScores.reliability >= 8.0) strengths.add('reliability');
    if (score.categoryScores.value >= 8.0) strengths.add('value');
    return strengths;
  }

  static List<String> _getWeaknesses(CarComparisonScore score) {
    final weaknesses = <String>[];
    if (score.categoryScores.performance < 5.0) weaknesses.add('performance');
    if (score.categoryScores.comfort < 5.0) weaknesses.add('comfort');
    if (score.categoryScores.luxury < 5.0) weaknesses.add('luxury');
    if (score.categoryScores.economy < 5.0) weaknesses.add('fuel economy');
    if (score.categoryScores.reliability < 5.0) weaknesses.add('reliability');
    if (score.categoryScores.value < 5.0) weaknesses.add('value');
    return weaknesses;
  }
}

