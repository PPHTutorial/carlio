import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class CarSoundService {
  static final CarSoundService _instance = CarSoundService._internal();
  factory CarSoundService() => _instance;
  CarSoundService._internal();

  static const String _soundAssignmentsKey = 'car_sound_assignments';

  // List of available sound files (both .mp3 and .aac formats)
  // Total: 22 .mp3 files + 3 .aac files = 25 sound files
  static final List<String> _availableSounds = [
    // MP3 files (001-022)
    'assets/engine/carlio_001.mp3',
    'assets/engine/carlio_002.mp3',
    'assets/engine/carlio_003.mp3',
    'assets/engine/carlio_004.mp3',
    'assets/engine/carlio_005.mp3',
    'assets/engine/carlio_006.mp3',
    'assets/engine/carlio_007.mp3',
    'assets/engine/carlio_008.mp3',
    'assets/engine/carlio_009.mp3',
    'assets/engine/carlio_010.mp3',
    'assets/engine/carlio_011.mp3',
    'assets/engine/carlio_012.mp3',
    'assets/engine/carlio_013.mp3',
    'assets/engine/carlio_014.mp3',
    'assets/engine/carlio_015.mp3',
    'assets/engine/carlio_016.mp3',
    'assets/engine/carlio_017.mp3',
    'assets/engine/carlio_018.mp3',
    'assets/engine/carlio_019.mp3',
    'assets/engine/carlio_020.mp3',
    'assets/engine/carlio_021.mp3',
    'assets/engine/carlio_022.mp3',
    // AAC files (0023-0025) - note: these have 4-digit numbers
    'assets/engine/carlio_0023.aac',
    'assets/engine/carlio_0024.aac',
    'assets/engine/carlio_0025.aac',
  ];

  /// Get or assign a sound file for a specific car
  /// Returns the asset path to the sound file
  Future<String> getOrAssignSound(String carId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get existing assignments
      final assignmentsJson = prefs.getString(_soundAssignmentsKey);
      Map<String, String> assignments = {};
      
      if (assignmentsJson != null) {
        // Parse JSON string to Map
        assignments = _parseAssignments(assignmentsJson);
      }

      // Check if car already has an assigned sound
      if (assignments.containsKey(carId)) {
        final assignedSound = assignments[carId]!;
        // Verify the sound file still exists in available sounds
        if (_availableSounds.contains(assignedSound)) {
          print('CarSoundService: Using existing assignment for $carId: $assignedSound');
          return assignedSound;
        } else {
          // Sound file no longer exists, reassign
          print('CarSoundService: Sound file no longer exists, reassigning for $carId');
          assignments.remove(carId);
        }
      }

      // Assign a random sound to this car
      final random = Random();
      final availableSounds = List<String>.from(_availableSounds);
      
      // Remove already assigned sounds to ensure variety
      final assignedSounds = assignments.values.toSet();
      availableSounds.removeWhere((sound) => assignedSounds.contains(sound));
      
      // If all sounds are assigned, reset and use any sound
      if (availableSounds.isEmpty) {
        availableSounds.addAll(_availableSounds);
      }
      
      final selectedSound = availableSounds[random.nextInt(availableSounds.length)];
      
      // Save the assignment
      assignments[carId] = selectedSound;
      await _saveAssignments(prefs, assignments);
      
      print('CarSoundService: Assigned sound to $carId: $selectedSound');
      return selectedSound;
    } catch (e) {
      print('Error getting/assigning sound: $e');
      // Return default sound if error
      return _availableSounds.isNotEmpty ? _availableSounds[0] : '';
    }
  }

  /// Get the assigned sound for a car (without assigning if not exists)
  Future<String?> getAssignedSound(String carId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final assignmentsJson = prefs.getString(_soundAssignmentsKey);
      
      if (assignmentsJson != null) {
        final assignments = _parseAssignments(assignmentsJson);
        final sound = assignments[carId];
        if (sound != null && _availableSounds.contains(sound)) {
          return sound;
        }
      }
      return null;
    } catch (e) {
      print('Error getting assigned sound: $e');
      return null;
    }
  }

  /// Reassign a sound for a specific car
  Future<String> reassignSound(String carId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final assignmentsJson = prefs.getString(_soundAssignmentsKey);
      Map<String, String> assignments = {};
      
      if (assignmentsJson != null) {
        assignments = _parseAssignments(assignmentsJson);
      }

      // Remove existing assignment
      assignments.remove(carId);

      // Assign a new random sound
      final random = Random();
      final availableSounds = List<String>.from(_availableSounds);
      
      // Prefer sounds that aren't heavily used
      final assignedSounds = assignments.values.toSet();
      availableSounds.removeWhere((sound) => assignedSounds.contains(sound));
      
      if (availableSounds.isEmpty) {
        availableSounds.addAll(_availableSounds);
      }
      
      final selectedSound = availableSounds[random.nextInt(availableSounds.length)];
      assignments[carId] = selectedSound;
      
      await _saveAssignments(prefs, assignments);
      
      return selectedSound;
    } catch (e) {
      print('Error reassigning sound: $e');
      return _availableSounds.isNotEmpty ? _availableSounds[0] : '';
    }
  }

  /// Parse assignments from JSON string
  Map<String, String> _parseAssignments(String jsonString) {
    try {
      // Simple JSON parsing: {"carId1":"sound1","carId2":"sound2"}
      final Map<String, String> result = {};
      final cleaned = jsonString.replaceAll('{', '').replaceAll('}', '').replaceAll('"', '');
      final pairs = cleaned.split(',');
      
      for (final pair in pairs) {
        if (pair.trim().isEmpty) continue;
        final parts = pair.split(':');
        if (parts.length == 2) {
          result[parts[0].trim()] = parts[1].trim();
        }
      }
      
      return result;
    } catch (e) {
      print('Error parsing assignments: $e');
      return {};
    }
  }

  /// Save assignments to SharedPreferences
  Future<void> _saveAssignments(SharedPreferences prefs, Map<String, String> assignments) async {
    try {
      // Convert map to simple JSON string format
      final entries = assignments.entries.map((e) => '"${e.key}":"${e.value}"').join(',');
      final jsonString = '{$entries}';
      await prefs.setString(_soundAssignmentsKey, jsonString);
    } catch (e) {
      print('Error saving assignments: $e');
    }
  }

  /// Get all available sound files
  List<String> getAvailableSounds() {
    return List.unmodifiable(_availableSounds);
  }

  /// Clear all sound assignments (for testing/debugging)
  Future<void> clearAssignments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_soundAssignmentsKey);
    } catch (e) {
      print('Error clearing assignments: $e');
    }
  }
}


