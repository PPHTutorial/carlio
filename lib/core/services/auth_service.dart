import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final userId = userCredential.user?.uid;
      if (userId == null) {
        throw Exception('User creation failed - no user ID returned');
      }

      // Update display name first (doesn't require Firestore permissions)
      try {
        await userCredential.user?.updateDisplayName(name);
      } catch (e) {
        // Display name update is not critical, continue
        print('Warning: Could not update display name: $e');
      }

      // Create user document in Firestore with error handling
      try {
        await _firestore.collection('users').doc(userId).set({
          'email': email,
          'name': name,
          'credits': 0.0,
          'hasReachedMinimum': false,
          'subscriptionType': 'free',
          'subscriptionExpiry': null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: false));
      } on FirebaseException catch (firestoreError) {
        // Check if it's a permission error
        if (firestoreError.code == 'permission-denied') {
          // If Firestore write fails due to permissions, try to delete the auth user
          try {
            await userCredential.user?.delete();
          } catch (deleteError) {
            print('Warning: Could not delete auth user after Firestore failure: $deleteError');
          }
          
          // Throw a user-friendly error with instructions
          throw Exception(
            'Firestore permission denied. Please configure Firestore security rules in Firebase Console:\n'
            '1. Go to Firestore Database → Rules\n'
            '2. Copy rules from FIRESTORE_RULES.txt or SETUP_GUIDE.md\n'
            '3. Click Publish\n'
            'Then try signing up again.'
          );
        } else {
          // Other Firestore errors
          try {
            await userCredential.user?.delete();
          } catch (deleteError) {
            print('Warning: Could not delete auth user after Firestore failure: $deleteError');
          }
          
          throw Exception(
            'Failed to save user data: ${firestoreError.message ?? firestoreError.code}. '
            'Please try again or contact support.'
          );
        }
      } catch (firestoreError) {
        // Generic catch for non-FirebaseException errors
        try {
          await userCredential.user?.delete();
        } catch (deleteError) {
          print('Warning: Could not delete auth user after Firestore failure: $deleteError');
        }
        
        throw Exception(
          'Failed to save user data: ${firestoreError.toString()}. '
          'Please check Firestore permissions and try again.'
        );
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      // Re-throw with user-friendly message
      throw Exception(_getAuthErrorMessage(e));
    } catch (e) {
      // Re-throw other errors as-is (already has user-friendly message for Firestore)
      rethrow;
    }
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      // Throw with user-friendly message
      throw Exception(_getAuthErrorMessage(e));
    }
  }

  /// Get user-friendly error messages from Firebase Auth exceptions
  String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email. Please sign up first.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Invalid email address. Please check your email and try again.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'Sign in with email/password is not enabled. Please contact support.';
      case 'email-already-in-use':
        return 'An account already exists with this email. Please sign in instead.';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password.';
      case 'network-request-failed':
        return 'Network error. Please check your connection and try again.';
      case 'requires-recent-login':
        return 'This operation requires recent login. Please sign out and sign in again.';
      default:
        return 'Authentication failed: ${e.message ?? e.code}. Please try again.';
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> updateUserProfile({String? name}) async {
    if (name != null && _auth.currentUser != null) {
      await _auth.currentUser!.updateDisplayName(name);
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'name': name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}

