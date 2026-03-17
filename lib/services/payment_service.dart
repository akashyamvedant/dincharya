// lib/services/payment_service.dart
//
// Payment service using Google Play Billing via in_app_purchase package.
// Razorpay code is preserved below (disabled) for future Alternative Billing.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../models/payment_models.dart';
import 'supabase_service.dart';
import 'subscription_manager.dart';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  // ── Google Play Billing ──
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _isAvailable = false;
  bool _isInitialized = false;

  // Cached products from Google Play
  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;
  bool get isAvailable => _isAvailable;

  // Callback for purchase results
  Function(PaymentResult)? _onPaymentResult;
  final SupabaseService _supabase = SupabaseService();

  // Store current plan being purchased (for Supabase save)
  PaymentPlan? _currentPlan;

  // ── Google Play Product IDs ──
  // These must match EXACTLY what you create in Play Console
  static const Set<String> _subscriptionIds = {
    'monthly_premium',
    'yearly_premium',
  };
  static const Set<String> _oneTimeProductIds = {
    'lifetime_premium',
  };
  static Set<String> get allProductIds => {
    ..._subscriptionIds,
    ..._oneTimeProductIds,
  };

  static const String _companyName = 'DinCharya';

  // ══════════════════════════════════════════════════════════════
  // ██  INITIALIZATION
  // ══════════════════════════════════════════════════════════════

  /// Initialize Google Play Billing and start listening for purchases.
  /// Call this once at app startup or when payment screen opens.
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('💰 PaymentService already initialized');
      return;
    }

    // Skip on web platform
    if (kIsWeb) {
      debugPrint('💰 PaymentService: Skipping on web platform');
      return;
    }

    try {
      _isAvailable = await _iap.isAvailable();
      if (!_isAvailable) {
        debugPrint('⚠️ Google Play Billing not available on this device');
        return;
      }

      // Listen to purchase updates (this stream is critical!)
      _purchaseSubscription = _iap.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: () {
          debugPrint('💰 Purchase stream closed');
          _purchaseSubscription?.cancel();
        },
        onError: (error) {
          debugPrint('❌ Purchase stream error: $error');
        },
      );

      // Load available products from Google Play
      await loadProducts();

      _isInitialized = true;
      debugPrint('✅ Google Play Billing initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize Google Play Billing: $e');
    }
  }

  /// Clean up resources
  void dispose() {
    _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
    _isInitialized = false;
    debugPrint('💰 PaymentService disposed');
  }

  // ══════════════════════════════════════════════════════════════
  // ██  PRODUCTS
  // ══════════════════════════════════════════════════════════════

  /// Load products from Google Play Store.
  /// Returns true if at least one product was found.
  Future<bool> loadProducts() async {
    try {
      debugPrint('🔵 Loading products from Google Play...');
      debugPrint('🔵 Product IDs: $allProductIds');

      final ProductDetailsResponse response =
          await _iap.queryProductDetails(allProductIds);

      if (response.error != null) {
        debugPrint('❌ Error loading products: ${response.error}');
        return false;
      }

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('⚠️ Products not found in Play Console: ${response.notFoundIDs}');
        debugPrint('   → Make sure these products are created and ACTIVATED in Play Console');
      }

      _products = response.productDetails;
      debugPrint('✅ Loaded ${_products.length} products from Google Play:');
      for (final p in _products) {
        debugPrint('   - ${p.id}: ${p.title} → ${p.price}');
      }

      return _products.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error querying products: $e');
      return false;
    }
  }

  /// Get a specific product by ID
  ProductDetails? getProduct(String productId) {
    try {
      return _products.firstWhere((p) => p.id == productId);
    } catch (_) {
      return null;
    }
  }

  /// Check if a product is a subscription (vs one-time purchase)
  static bool isSubscription(String productId) {
    return _subscriptionIds.contains(productId);
  }

  // ══════════════════════════════════════════════════════════════
  // ██  PURCHASE FLOW
  // ══════════════════════════════════════════════════════════════

  /// Initiate a purchase for a given plan.
  /// This is the main entry point called from the UI.
  /// Keeps the same API signature as the Razorpay version for compatibility.
  Future<void> initiatePayment({
    required PaymentPlan plan,
    required String userEmail,
    required String userPhone,
    required String userName,
    required Function(PaymentResult) onResult,
    String? couponCode, // Ignored for Google Play (Google manages pricing)
  }) async {
    try {
      debugPrint('🔵 initiatePayment called for plan: ${plan.name}');

      // Store plan and callback
      _currentPlan = plan;
      _onPaymentResult = onResult;

      if (!_isAvailable) {
        debugPrint('❌ Google Play Billing not available');
        onResult(PaymentResult.failure(
          errorMessage: 'Google Play Billing is not available on this device',
          errorCode: 'SERVICE_UNAVAILABLE',
        ));
        return;
      }

      // Find the matching Google Play product
      final product = getProduct(plan.id);
      if (product == null) {
        debugPrint('❌ Product not found: ${plan.id}');
        debugPrint('   Available products: ${_products.map((p) => p.id).toList()}');
        onResult(PaymentResult.failure(
          errorMessage: 'Product not available. Please try again later.',
          errorCode: 'PRODUCT_NOT_FOUND',
        ));
        return;
      }

      // Determine purchase type
      await _buyProduct(product, plan);
    } catch (e) {
      debugPrint('❌ Error initiating purchase: $e');
      onResult(PaymentResult.failure(
        errorMessage: 'Failed to initiate purchase: ${e.toString()}',
        errorCode: 'INITIATION_ERROR',
      ));
    }
  }

  /// Internal method to trigger Google Play purchase flow
  Future<void> _buyProduct(ProductDetails product, PaymentPlan plan) async {
    try {
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: product,
      );

      debugPrint('🔵 Starting Google Play purchase for: ${product.id}');

      bool success;
      if (isSubscription(product.id)) {
        // Subscriptions are non-consumable by nature
        success = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
        // Lifetime is a non-consumable one-time purchase
        success = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      }

      debugPrint('🔵 Purchase initiated: $success');
      // Actual result comes through _onPurchaseUpdate stream
    } catch (e) {
      debugPrint('❌ Purchase error: $e');
      _onPaymentResult?.call(PaymentResult.failure(
        errorMessage: 'Purchase failed: ${e.toString()}',
        errorCode: 'PURCHASE_ERROR',
      ));
    }
  }

  // ══════════════════════════════════════════════════════════════
  // ██  PURCHASE STREAM HANDLER
  // ══════════════════════════════════════════════════════════════

  /// Handle purchase updates from Google Play.
  /// This is called for ALL purchase events — success, error, restore, pending.
  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchase in purchaseDetailsList) {
      debugPrint('💰 Purchase update: ${purchase.productID} → ${purchase.status}');

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _handleSuccessfulPurchase(purchase);
          break;
        case PurchaseStatus.error:
          _handlePurchaseError(purchase);
          break;
        case PurchaseStatus.canceled:
          _handlePurchaseCanceled(purchase);
          break;
        case PurchaseStatus.pending:
          debugPrint('⏳ Purchase pending: ${purchase.productID}');
          _showToast('Payment is being processed...', isSuccess: true);
          break;
      }
    }
  }

  /// Handle successful purchase (or restore)
  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchase) async {
    try {
      debugPrint('🎉 Purchase successful: ${purchase.productID}');
      debugPrint('   Purchase ID: ${purchase.purchaseID}');
      debugPrint('   Status: ${purchase.status}');

      // ── IMPORTANT: Complete the purchase with Google Play ──
      // This acknowledges the purchase and prevents auto-refund after 3 days
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
        debugPrint('✅ Purchase completed/acknowledged with Google Play');
      }

      // Save to Supabase
      try {
        await _savePaymentToSupabase(purchase);
        debugPrint('✅ Payment saved to Supabase');
      } catch (saveError) {
        debugPrint('❌ Error saving payment to Supabase: $saveError');
        // Still mark as success — payment was made
      }

      // Create result
      final result = PaymentResult.success(
        paymentId: purchase.purchaseID ?? '',
        orderId: purchase.productID,
        signature: '', // Google Play handles verification server-side
      );

      _onPaymentResult?.call(result);

      // Show success toast
      if (purchase.status == PurchaseStatus.purchased) {
        _showToast('Payment successful! Subscription activated.', isSuccess: true);
      } else if (purchase.status == PurchaseStatus.restored) {
        _showToast('Purchase restored successfully!', isSuccess: true);
      }
    } catch (e) {
      debugPrint('❌ Error handling purchase success: $e');
      _onPaymentResult?.call(PaymentResult.failure(
        errorMessage: 'Error processing payment: ${e.toString()}',
        errorCode: 'PROCESSING_ERROR',
      ));
    }
  }

  /// Handle purchase error
  void _handlePurchaseError(PurchaseDetails purchase) {
    try {
      debugPrint('❌ Purchase error: ${purchase.error}');

      // Complete the purchase to clear it from the queue
      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }

      final errorMessage = purchase.error?.message ?? 'Payment failed';
      final result = PaymentResult.failure(
        errorMessage: errorMessage,
        errorCode: purchase.error?.code ?? 'UNKNOWN_ERROR',
      );

      _onPaymentResult?.call(result);
      _showToast(errorMessage, isSuccess: false);
    } catch (e) {
      debugPrint('❌ Error handling purchase error: $e');
      _onPaymentResult?.call(PaymentResult.failure(
        errorMessage: 'Error processing payment failure',
        errorCode: 'PROCESSING_ERROR',
      ));
    }
  }

  /// Handle purchase cancellation
  void _handlePurchaseCanceled(PurchaseDetails purchase) {
    debugPrint('🚫 Purchase canceled: ${purchase.productID}');

    // Complete to clear from queue
    if (purchase.pendingCompletePurchase) {
      _iap.completePurchase(purchase);
    }

    _onPaymentResult?.call(PaymentResult.failure(
      errorMessage: 'Purchase was canceled',
      errorCode: 'USER_CANCELLED',
    ));
  }

  // ══════════════════════════════════════════════════════════════
  // ██  SUPABASE INTEGRATION
  // ══════════════════════════════════════════════════════════════

  /// Save purchase to Supabase subscriptions table.
  /// Reuses existing column structure for backward compatibility.
  Future<void> _savePaymentToSupabase(PurchaseDetails purchase) async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) {
        debugPrint('⚠️ Cannot save payment: User not authenticated');
        return;
      }

      final client = await _supabase.client;
      if (client == null) {
        debugPrint('⚠️ Supabase not initialized');
        return;
      }

      // Determine plan details
      final plan = _currentPlan ?? _planFromProductId(purchase.productID);

      // Use Google Play's ACTUAL price (what was charged), not fallback pricing
      // This ensures the amount in Supabase matches the real charge
      final googleProduct = getProduct(purchase.productID);
      final double actualPrice = googleProduct?.rawPrice ?? plan.price;
      final String actualCurrency = googleProduct?.currencyCode ?? plan.currency;
      final amountInSmallestUnit = (actualPrice * 100).toInt();

      // Calculate expiry
      final now = DateTime.now();
      final Duration expiryDuration;
      switch (plan.duration) {
        case 'lifetime':
          expiryDuration = const Duration(days: 36500); // ~100 years
          break;
        case 'year':
          expiryDuration = const Duration(days: 365);
          break;
        default: // month
          expiryDuration = const Duration(days: 30);
      }
      final expiresAt = now.add(expiryDuration);

      // Deactivate existing active subscriptions (prevent duplicates)
      try {
        await client.from('subscriptions')
            .update({
              'status': 'superseded',
              'cancelled_at': now.toIso8601String(),
              'updated_at': now.toIso8601String(),
            })
            .eq('user_id', userId)
            .eq('status', 'active');
        debugPrint('✅ Old subscriptions deactivated');
      } catch (e) {
        debugPrint('⚠️ Could not deactivate old subs (non-blocking): $e');
      }

      // Generate unique order ID for deduplication
      final uniqueOrderId = 'gp_${purchase.purchaseID ?? DateTime.now().millisecondsSinceEpoch}_${DateTime.now().millisecondsSinceEpoch}';

      // Save new subscription
      // Using existing razorpay_* columns for backward compatibility
      // razorpay_payment_id → stores Google Play purchase ID
      // razorpay_order_id → stores unique order ID (for dedup)
      // razorpay_signature → stores purchase token for verification
      await client.from('subscriptions').insert({
        'user_id': userId,
        'plan_id': plan.id,
        'plan_name': plan.name,
        'status': 'active',
        'razorpay_payment_id': purchase.purchaseID ?? '',
        'razorpay_order_id': uniqueOrderId,
        'razorpay_signature': _extractPurchaseToken(purchase),
        'amount': amountInSmallestUnit,
        'currency': actualCurrency,
        'started_at': now.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'is_trial': false,
      });

      // Save to audit log
      try {
        await client.from('payment_audit_log').insert({
          'user_id': userId,
          'event_type': 'payment_success',
          'razorpay_payment_id': purchase.purchaseID ?? '',
          'razorpay_order_id': uniqueOrderId,
          'amount': amountInSmallestUnit,
          'currency': actualCurrency,
          'status': 'success',
          'metadata': {
            'provider': 'google_play',
            'purchase_token': _extractPurchaseToken(purchase),
            'plan_id': plan.id,
            'plan_name': plan.name,
            'duration': plan.duration,
            'google_play_price': googleProduct?.price ?? 'unknown',
            'google_play_raw_price': actualPrice,
          },
        });
      } catch (e) {
        debugPrint('⚠️ Audit log save failed (non-blocking): $e');
      }

      debugPrint('✅ Payment saved to Supabase: ${plan.name} expires ${expiresAt.toIso8601String()}');

      // Update user_profiles
      try {
        final tierName = plan.duration == 'lifetime' ? 'lifetime'
            : plan.duration == 'year' ? 'yearly'
            : 'monthly';
        await client.from('user_profiles')
            .update({
              'subscription_status': 'premium',
              'subscription_tier': tierName,
              'subscription_expires_at': expiresAt.toIso8601String(),
              'updated_at': now.toIso8601String(),
            })
            .eq('id', userId);
        debugPrint('✅ user_profiles subscription status updated to premium/$tierName');
      } catch (e) {
        debugPrint('⚠️ user_profiles update failed (non-blocking): $e');
      }

      // Refresh SubscriptionManager cache
      await SubscriptionManager().onPaymentSuccess();
      debugPrint('✅ SubscriptionManager cache refreshed after payment');

      // Clear current plan
      _currentPlan = null;
    } catch (e) {
      debugPrint('❌ Error saving payment to Supabase: $e');
    }
  }

  /// Extract purchase token from PurchaseDetails (platform-specific)
  String _extractPurchaseToken(PurchaseDetails purchase) {
    // The verificationData contains the purchase token for server verification
    return purchase.verificationData.serverVerificationData;
  }

  /// Create a PaymentPlan from a product ID (fallback when _currentPlan is null)
  PaymentPlan _planFromProductId(String productId) {
    final plans = PaymentPlan.getLocalizedPlans();
    try {
      return plans.firstWhere((p) => p.id == productId);
    } catch (_) {
      // Fallback to monthly
      return plans.first;
    }
  }

  // ══════════════════════════════════════════════════════════════
  // ██  RESTORE PURCHASES
  // ══════════════════════════════════════════════════════════════

  /// Restore previous purchases from Google Play.
  /// Call this from "Restore Purchases" button.
  Future<void> restorePurchases() async {
    try {
      debugPrint('🔄 Restoring purchases from Google Play...');
      await _iap.restorePurchases();
      // Results come through _onPurchaseUpdate stream
    } catch (e) {
      debugPrint('❌ Error restoring purchases: $e');
      _showToast('Failed to restore purchases', isSuccess: false);
    }
  }

  // ══════════════════════════════════════════════════════════════
  // ██  SUBSCRIPTION QUERIES (unchanged — Supabase-based)
  // ══════════════════════════════════════════════════════════════

  /// Check if subscription is active (from Supabase)
  Future<bool> isSubscriptionActive() async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return false;

      final client = await _supabase.client;
      if (client == null) return false;

      final data = await client
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active')
          .gt('expires_at', DateTime.now().toIso8601String())
          .limit(1);

      return data.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking subscription from Supabase: $e');
      return false;
    }
  }

  /// Get last payment info (from Supabase)
  Future<Map<String, dynamic>?> getLastPaymentInfo() async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return null;

      final client = await _supabase.client;
      if (client == null) return null;

      final data = await client
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1);

      if (data.isNotEmpty) {
        return {
          'payment_id': data[0]['razorpay_payment_id'],
          'order_id': data[0]['razorpay_order_id'],
          'provider': 'google_play',
          'status': data[0]['status'],
          'expires_at': data[0]['expires_at'],
        };
      }
      return null;
    } catch (e) {
      debugPrint('Error getting payment info from Supabase: $e');
      return null;
    }
  }

  /// Cancel/clear subscription in Supabase
  Future<void> clearSubscription() async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return;

      final client = await _supabase.client;
      if (client == null) return;

      await client
          .from('subscriptions')
          .update({
            'status': 'cancelled',
            'cancelled_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('status', 'active');

      debugPrint('✅ Subscription cancelled in Supabase');
    } catch (e) {
      debugPrint('❌ Error clearing subscription: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════
  // ██  UTILITIES
  // ══════════════════════════════════════════════════════════════

  void _showToast(String message, {required bool isSuccess}) {
    try {
      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        textColor: Colors.white,
      );
    } catch (e) {
      debugPrint('Error showing toast: $e');
    }
  }

  /// Get billing status for debugging
  static Map<String, dynamic> getBillingStatus() {
    final instance = PaymentService();
    return {
      'provider': 'google_play',
      'is_available': instance._isAvailable,
      'is_initialized': instance._isInitialized,
      'products_loaded': instance._products.length,
      'product_ids': instance._products.map((p) => p.id).toList(),
    };
  }
}

// ══════════════════════════════════════════════════════════════════
// ██  RAZORPAY CODE — DISABLED (kept for future Alternative Billing)
// ══════════════════════════════════════════════════════════════════
//
// When Alternative Billing enrollment is resolved, un-comment this
// and create a dual-provider system:
//
// import 'package:razorpay_flutter/razorpay_flutter.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:crypto/crypto.dart';
// import 'dart:convert';
// import '../core/utils/validators.dart';
//
// === Razorpay configuration ===
// static String get _razorpayKeyId => dotenv.env['RAZORPAY_KEY_ID'] ?? '';
// static String get _razorpayKeySecret => dotenv.env['RAZORPAY_KEY_SECRET'] ?? '';
//
// === Razorpay initialization ===
// Razorpay? _razorpay;
// void _initRazorpay() {
//   _razorpay = Razorpay();
//   _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
//   _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
//   _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
// }
//
// === Razorpay payment options ===
// final options = {
//   'key': _razorpayKeyId,
//   'amount': (plan.price * 100).toInt(),
//   'currency': plan.currency,
//   'name': _companyName,
//   'description': '${plan.name} Subscription',
//   'prefill': {'contact': userPhone, 'email': userEmail, 'name': userName},
//   'theme': {'color': '#8B4513'},
// };
// _razorpay?.open(options);
//
// === Razorpay credential validation ===
// static bool validateRazorpayCredentials() {
//   return _razorpayKeyId.startsWith('rzp_') &&
//       _razorpayKeyId != 'YOUR_RAZORPAY_KEY_ID' &&
//       _razorpayKeyId.isNotEmpty;
// }
// ══════════════════════════════════════════════════════════════════
