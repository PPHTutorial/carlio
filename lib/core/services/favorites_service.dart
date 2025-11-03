import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/car_data.dart';

class FavoritesService {
  static const String _favoritesKey = 'favorite_cars';
  static FavoritesService? _instance;
  
  static FavoritesService get instance {
    _instance ??= FavoritesService._();
    return _instance!;
  }

  FavoritesService._();

  Future<List<String>> getFavoriteCarIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = prefs.getString(_favoritesKey);
      if (favoritesJson == null) return [];
      
      final List<dynamic> decoded = json.decode(favoritesJson);
      return List<String>.from(decoded);
    } catch (e) {
      print('Error getting favorites: $e');
      return [];
    }
  }

  Future<bool> isFavorite(String carId) async {
    final favorites = await getFavoriteCarIds();
    return favorites.contains(carId);
  }

  Future<void> addFavorite(String carId) async {
    try {
      final favorites = await getFavoriteCarIds();
      if (!favorites.contains(carId)) {
        favorites.add(carId);
        await _saveFavorites(favorites);
      }
    } catch (e) {
      print('Error adding favorite: $e');
    }
  }

  Future<void> removeFavorite(String carId) async {
    try {
      final favorites = await getFavoriteCarIds();
      favorites.remove(carId);
      await _saveFavorites(favorites);
    } catch (e) {
      print('Error removing favorite: $e');
    }
  }

  Future<void> toggleFavorite(String carId) async {
    final isFav = await isFavorite(carId);
    if (isFav) {
      await removeFavorite(carId);
    } else {
      await addFavorite(carId);
    }
  }

  Future<List<CarData>> getFavoriteCars(List<CarData> allCars) async {
    final favoriteIds = await getFavoriteCarIds();
    return allCars.where((car) => favoriteIds.contains(car.id)).toList();
  }

  Future<void> _saveFavorites(List<String> favorites) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_favoritesKey, json.encode(favorites));
    } catch (e) {
      print('Error saving favorites: $e');
    }
  }
}

