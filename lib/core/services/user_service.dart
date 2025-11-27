import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';

enum SubscriptionType { free, monthly, quarterly, halfly, yearly }

class UserData {
  final String userId;
  final String email;
  final String name;
  final double credits;
  final SubscriptionType subscriptionType;
  final DateTime? subscriptionExpiry;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool hasReachedMinimum; // Track if user has reached 5 credits threshold

  UserData({
    required this.userId,
    required this.email,
    required this.name,
    required this.credits,
    required this.subscriptionType,
    this.subscriptionExpiry,
    required this.createdAt,
    required this.updatedAt,
    this.hasReachedMinimum = false,
  });

  bool get isPro => subscriptionType != SubscriptionType.free;

  bool get hasValidSubscription {
    if (!isPro) return false;
    if (subscriptionExpiry == null) return false;
    return subscriptionExpiry!.isAfter(DateTime.now());
  }

  factory UserData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    // Handle both int and double credits from Firestore
    final creditsValue = data['credits'];
    final credits = creditsValue is int
        ? creditsValue.toDouble()
        : (creditsValue as num?)?.toDouble() ?? 0.0;

    // Determine if user is in spending mode (has reached 5 credits and hasn't depleted to 0)
    final hasReachedMinimum = data['hasReachedMinimum'] as bool? ?? false;

    return UserData(
      userId: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      credits: credits,
      subscriptionType:
          _parseSubscriptionType(data['subscriptionType'] ?? 'free'),
      subscriptionExpiry: data['subscriptionExpiry']?.toDate(),
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: data['updatedAt']?.toDate() ?? DateTime.now(),
      hasReachedMinimum: hasReachedMinimum,
    );
  }

  /// Check if user is in spending mode (can use credits until 0)
  bool get isInSpendingMode {
    return hasReachedMinimum && credits > 0;
  }

  static SubscriptionType _parseSubscriptionType(String type) {
    switch (type) {
      case 'monthly':
        return SubscriptionType.monthly;
      case 'yearly':
        return SubscriptionType.yearly;
      case 'quarterly':
        return SubscriptionType.quarterly;
      case 'halfly':
        return SubscriptionType.halfly;
      default:
        return SubscriptionType.free;
    }
  }
}

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static UserService? _instance;
  static UserService get instance {
    _instance ??= UserService._();
    return _instance!;
  }

  UserService._();

  Stream<UserData?> get currentUserData {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value(null);

    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserData.fromFirestore(doc);
    });
  }

  Future<UserData?> getUserData() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('UserService: No user ID - user not authenticated');
      return null;
    }

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) {
        print('UserService: User document does not exist for user: $userId');
        return null;
      }
      return UserData.fromFirestore(doc);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        print(
            'UserService: Permission denied - Firestore rules may not be configured correctly');
        print('User ID: $userId');
        print('Error: ${e.message}');
        print(
            'Please ensure Firestore rules allow authenticated users to read their own documents');
        print(
            'Rules should be: allow read: if request.auth != null && request.auth.uid == userId;');
      } else {
        print('UserService: Firestore error: ${e.code} - ${e.message}');
      }
      rethrow;
    } catch (e) {
      print('UserService: Unexpected error getting user data: $e');
      return null;
    }
  }

  Future<void> addCredits(double amount,
      {bool skipIfInSpendingMode = false}) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('UserService: Cannot add credits - user not authenticated');
      return;
    }

    try {
      // Read current credits and add new amount (FieldValue.increment doesn't support double)
      final userData = await getUserData();
      final currentCredits = userData?.credits ?? 0.0;

      // If user is in spending mode and skip flag is set, don't add credits
      if (skipIfInSpendingMode && userData?.isInSpendingMode == true) {
        print(
            'UserService: Skipping credit addition - user is in spending mode');
        return;
      }

      final newCredits = currentCredits + amount;
      final newHasReachedMinimum =
          newCredits >= 5.0 || (userData?.hasReachedMinimum ?? false);

      await _firestore.collection('users').doc(userId).update({
        'credits': newCredits,
        'hasReachedMinimum': newHasReachedMinimum,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        print('UserService: Permission denied adding credits');
        print(
            'Please ensure Firestore rules allow updates: allow update: if request.auth != null && request.auth.uid == userId;');
        rethrow;
      } else {
        print(
            'UserService: Firestore error adding credits: ${e.code} - ${e.message}');
        rethrow;
      }
    } catch (e) {
      print('UserService: Unexpected error adding credits: $e');
      rethrow;
    }
  }

  Future<bool> useCredits(double amount) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('UserService: Cannot use credits - user not authenticated');
      return false;
    }

    try {
      final userData = await getUserData();
      if (userData == null) return false;

      // Check if user can use credits:
      // 1. If user is in spending mode (hasReachedMinimum && credits > 0), allow usage until 0
      // 2. Otherwise, need at least the amount required
      if (userData.isInSpendingMode) {
        // In spending mode, can use credits as long as credits > 0
        // Use actual available credits if less than requested amount
        if (userData.credits <= 0) {
          return false;
        }
      } else {
        // Not in spending mode - need at least the amount required
        if (userData.credits < amount) {
          return false;
        }
      }

      // Use actual available credits if in spending mode and credits are less than amount
      final actualAmount =
          userData.isInSpendingMode && userData.credits < amount
              ? userData.credits
              : amount;

      final newCredits =
          (userData.credits - actualAmount).clamp(0.0, double.infinity);
      // Reset hasReachedMinimum when credits reach 0
      final newHasReachedMinimum =
          newCredits > 0 ? userData.hasReachedMinimum : false;

      await _firestore.collection('users').doc(userId).update({
        'credits': newCredits,
        'hasReachedMinimum': newHasReachedMinimum,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        print('UserService: Permission denied using credits');
        print(
            'Please ensure Firestore rules allow updates: allow update: if request.auth != null && request.auth.uid == userId;');
      } else {
        print(
            'UserService: Firestore error using credits: ${e.code} - ${e.message}');
      }
      return false;
    } catch (e) {
      print('UserService: Unexpected error using credits: $e');
      return false;
    }
  }

  Future<void> updateSubscription({
    required SubscriptionType type,
    DateTime? expiry,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    late final String subscriptionString;
    switch (type) {
      case SubscriptionType.monthly:
        subscriptionString = 'monthly';
        break;
      case SubscriptionType.quarterly:
        subscriptionString = 'quarterly';
        break;
      case SubscriptionType.halfly:
        subscriptionString = 'halfly';
        break;
      case SubscriptionType.yearly:
        subscriptionString = 'yearly';
        break;
      case SubscriptionType.free:
        subscriptionString = 'free';
        break;
    }

    await _firestore.collection('users').doc(userId).update({
      'subscriptionType': subscriptionString,
      'subscriptionExpiry': expiry,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> canPerformAction(
      {bool requiresPro = false, double creditCost = 1.0}) async {
    final userData = await getUserData();
    if (userData == null) return false;

    if (requiresPro && !userData.hasValidSubscription) {
      return false;
    }

    if (userData.hasValidSubscription && creditCost > 0) {
      return userData.credits >= creditCost;
    }

    return true;
  }
}
