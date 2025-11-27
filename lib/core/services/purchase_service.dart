import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_service.dart';

class PurchaseService {
  final InAppPurchase _iap = InAppPurchase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  bool _isAvailable = false;

  // Product IDs - Replace with your actual product IDs from Play Store/App Store
  static const String monthlySubId = 'monthly_10';
  static const String quarterlySubId = 'quarterly_35';
  static const String halflySubId = 'halfly_75';
  static const String yearlySubId = 'yearly_200';
  static const String credits10Id = '10credit';
  static const String credits25Id = '25credit';
  static const String credits50Id = '50credit';

  static PurchaseService? _instance;
  static PurchaseService get instance {
    _instance ??= PurchaseService._();
    return _instance!;
  }

  PurchaseService._() {
    _initialize();
  }

  Future<void> _initialize() async {
    _isAvailable = await _iap.isAvailable();

    if (_isAvailable) {
      _subscription = _iap.purchaseStream.listen(
        _handlePurchaseUpdate,
        onDone: () => _subscription.cancel(),
        onError: (error) => print('Purchase error: $error'),
      );
    }
  }

  void _handlePurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (var purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _verifyAndProcessPurchase(purchase);
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _verifyAndProcessPurchase(PurchaseDetails purchase) async {
    final productId = purchase.productID;

    // Save transaction to Firestore
    await _saveTransactionToFirestore(purchase);

    // Handle subscription purchases
    if (productId == monthlySubId) {
      final expiry = DateTime.now().add(const Duration(days: 30));
      await UserService.instance.updateSubscription(
        type: SubscriptionType.monthly,
        expiry: expiry,
      );
    } else if (productId == quarterlySubId) {
      final expiry = DateTime.now().add(const Duration(days: 90));
      await UserService.instance.updateSubscription(
        type: SubscriptionType.quarterly,
        expiry: expiry,
      );
    } else if (productId == halflySubId) {
      final expiry = DateTime.now().add(const Duration(days: 180));
      await UserService.instance.updateSubscription(
        type: SubscriptionType.halfly,
        expiry: expiry,
      );
    } else if (productId == yearlySubId) {
      final expiry = DateTime.now().add(const Duration(days: 365));
      await UserService.instance.updateSubscription(
        type: SubscriptionType.yearly,
        expiry: expiry,
      );
    }
    // Handle credit purchases
    else if (productId == credits10Id) {
      await UserService.instance.addCredits(17.0);
    } else if (productId == credits25Id) {
      await UserService.instance.addCredits(32.0);
    } else if (productId == credits50Id) {
      await UserService.instance.addCredits(57.0);
    }
  }

  /// Save transaction record to Firestore for history and verification
  Future<void> _saveTransactionToFirestore(PurchaseDetails purchase) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final verificationData = <String, dynamic>{
        'localVerificationData':
            purchase.verificationData.serverVerificationData,
        'source': purchase.verificationData.source.toString(),
      };

      final transactionData = <String, dynamic>{
        'userId': userId,
        'productId': purchase.productID,
        'transactionDate': purchase.transactionDate,
        'purchaseId': purchase.purchaseID,
        'status': purchase.status.toString(),
        'verificationData': verificationData,
        'platform': purchase.verificationData.source.toString(),
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Save to transactions collection
      await _firestore
          .collection('transactions')
          .doc(purchase.purchaseID)
          .set(transactionData, SetOptions(merge: true));

      // Also save to user's transaction subcollection for easy querying
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .doc(purchase.purchaseID)
          .set(transactionData, SetOptions(merge: true));
    } catch (e) {
      print('Error saving transaction to Firestore: $e');
      // Don't throw - transaction processing should continue even if logging fails
    }
  }

  /// Get user's transaction history
  Future<List<DocumentSnapshot>> getUserTransactionHistory() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      return snapshot.docs;
    } catch (e) {
      print('Error fetching transaction history: $e');
      return [];
    }
  }

  Future<List<ProductDetails>> getProducts() async {
    if (!_isAvailable) return [];

    const productIds = {
      monthlySubId,
      quarterlySubId,
      halflySubId,
      yearlySubId,
      credits10Id,
      credits25Id,
      credits50Id,
    };

    final response = await _iap.queryProductDetails(productIds);
    return response.productDetails;
  }

  Future<bool> buySubscription(String productId) async {
    return _buyProduct(productId, isConsumable: false);
  }

  Future<bool> buyConsumableProduct(String productId) async {
    return _buyProduct(productId, isConsumable: true);
  }

  Future<bool> _buyProduct(String productId,
      {required bool isConsumable}) async {
    // Require authentication for purchases
    if (_auth.currentUser == null) {
      throw Exception('Please sign in to make a purchase');
    }

    if (!_isAvailable) return false;

    final products = await getProducts();
    final product = products.firstWhere(
      (p) => p.id == productId,
      orElse: () => throw Exception('Product not found'),
    );

    final purchaseParam = PurchaseParam(productDetails: product);

    if (isConsumable) {
      return await _iap.buyConsumable(
        purchaseParam: purchaseParam,
        autoConsume: true,
      );
    }

    return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> restorePurchases() async {
    if (!_isAvailable) return;
    await _iap.restorePurchases();
  }

  void dispose() {
    _subscription.cancel();
  }
}
