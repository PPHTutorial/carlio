import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class BookmarksService {
  static const String _bookmarksKey = 'bookmarked_articles';
  static BookmarksService? _instance;
  
  static BookmarksService get instance {
    _instance ??= BookmarksService._();
    return _instance!;
  }

  BookmarksService._();

  Future<List<String>> getBookmarkedArticleIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarksJson = prefs.getString(_bookmarksKey);
      if (bookmarksJson == null) return [];
      
      final List<dynamic> decoded = json.decode(bookmarksJson);
      return List<String>.from(decoded);
    } catch (e) {
      print('Error getting bookmarks: $e');
      return [];
    }
  }

  Future<bool> isBookmarked(String carId) async {
    final bookmarks = await getBookmarkedArticleIds();
    return bookmarks.contains(carId);
  }

  Future<void> addBookmark(String carId) async {
    try {
      final bookmarks = await getBookmarkedArticleIds();
      if (!bookmarks.contains(carId)) {
        bookmarks.add(carId);
        await _saveBookmarks(bookmarks);
      }
    } catch (e) {
      print('Error adding bookmark: $e');
    }
  }

  Future<void> removeBookmark(String carId) async {
    try {
      final bookmarks = await getBookmarkedArticleIds();
      bookmarks.remove(carId);
      await _saveBookmarks(bookmarks);
    } catch (e) {
      print('Error removing bookmark: $e');
    }
  }

  Future<void> toggleBookmark(String carId) async {
    final currentlyBookmarked = await isBookmarked(carId);
    if (currentlyBookmarked) {
      await removeBookmark(carId);
    } else {
      await addBookmark(carId);
    }
  }

  Future<void> _saveBookmarks(List<String> bookmarks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_bookmarksKey, json.encode(bookmarks));
    } catch (e) {
      print('Error saving bookmarks: $e');
    }
  }
}

