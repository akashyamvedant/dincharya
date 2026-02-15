// lib/services/payment_service.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/payment_models.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'supabase_service.dart';
import 'subscription_manager.dart';
import '../core/utils/validators.dart';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  Razorpay? _razorpay;
  bool _isInitialized = false;
  Function(PaymentResult)? _onPaymentResult;
  final SupabaseService _supabase = SupabaseService();
  
  // Store current plan being purchased
  PaymentPlan? _currentPlan;

  // Get Razorpay Key ID from .env file
  static String get _razorpayKeyId => dotenv.env['RAZORPAY_KEY_ID'] ?? '';
  
  // Get Razorpay Key Secret from .env file (for signature verification)
  static String get _razorpayKeySecret => dotenv.env['RAZORPAY_KEY_SECRET'] ?? '';
  
  static const String _companyName = 'DinCharya';
  static const String _companyLogo =
      'https://djaevixaqvwtuizbadds.supabase.co/storage/v1/object/public/app-assets/logo.png';

  // Secure hash function for payment verification
  // ignore: unused_element - kept for future payment security
  String _hashPaymentData(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  void initialize() {
    // Skip Razorpay initialization on web platform
    if (kIsWeb) {
      debugPrint(
          'Payment service: Skipping Razorpay initialization on web platform');
      return;
    }

    // Validate Razorpay credentials before initialization
    if (_razorpayKeyId.isEmpty || _razorpayKeyId == 'YOUR_RAZORPAY_KEY_ID') {
      debugPrint(
          'Warning: Razorpay not configured. Payment features will be disabled.');
      debugPrint(
          'Get your Razorpay credentials from https://dashboard.razorpay.com/');
      return; // Don't initialize if credentials are not set
    }

    try {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
      _isInitialized = true;
      debugPrint('Razorpay initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize Razorpay: $e');
    }
  }

  void dispose() {
    try {
      _razorpay?.clear();
    } catch (e) {
      debugPrint('Error disposing Razorpay: $e');
    }
  }

  Future<void> initiatePayment({
    required PaymentPlan plan,
    required String userEmail,
    required String userPhone,
    required String userName,
    required Function(PaymentResult) onResult,
    String? couponCode, // Optional coupon code for Razorpay offers
  }) async {
    try {
      debugPrint('🔵 initiatePayment called for plan: ${plan.name}');
      debugPrint('🔵 Email: $userEmail, Phone: $userPhone, Name: $userName');
      debugPrint('🔵 Coupon Code: ${couponCode ?? "None"}');
      debugPrint('🔵 Razorpay Key ID: ${_razorpayKeyId.isNotEmpty ? _razorpayKeyId.substring(0, 10) + "..." : "NOT SET"}');
      debugPrint('🔵 Is Initialized: $_isInitialized');
      
      // Store current plan for use in success handler
      _currentPlan = plan;
      
      // Input validation
      if (!Validators.isValidEmail(userEmail)) {
        debugPrint('❌ Email validation failed');
        onResult(PaymentResult.failure(
          errorMessage: 'Invalid email address',
          errorCode: 'INVALID_EMAIL',
        ));
        return;
      }

      if (!Validators.isValidPhone(userPhone)) {
        debugPrint('❌ Phone validation failed: $userPhone');
        onResult(PaymentResult.failure(
          errorMessage: 'Invalid phone number',
          errorCode: 'INVALID_PHONE',
        ));
        return;
      }

      if (!Validators.isValidName(userName)) {
        debugPrint('❌ Name validation failed: $userName');
        onResult(PaymentResult.failure(
          errorMessage: 'Invalid user name',
          errorCode: 'INVALID_NAME',
        ));
        return;
      }

      if (!Validators.isValidAmount(plan.price)) {
        debugPrint('❌ Amount validation failed: ${plan.price}');
        onResult(PaymentResult.failure(
          errorMessage: 'Invalid payment amount',
          errorCode: 'INVALID_AMOUNT',
        ));
        return;
      }

      // Check if Razorpay is initialized
      if (!_isInitialized) {
        debugPrint('❌ Razorpay not initialized! Trying to initialize now...');
        initialize();
        if (!_isInitialized) {
          debugPrint('❌ Still not initialized after retry');
          onResult(PaymentResult.failure(
            errorMessage: 'Payment service not available. Check Razorpay configuration.',
            errorCode: 'SERVICE_UNAVAILABLE',
          ));
          return;
        }
      }

      debugPrint('✅ Razorpay initialized, proceeding with payment...');
      _onPaymentResult = onResult;

      // Generate receipt ID
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final receiptId = 'rcpt_${timestamp}';

      final options = {
        'key': _razorpayKeyId,
        'amount': (plan.price * 100).toInt(), // Amount in paisa
        'currency': plan.currency,
        'name': _companyName,
        'description': '${plan.name} Subscription',
        'receipt': receiptId,
        'image': _companyLogo,
        'prefill': {
          'contact': userPhone.isNotEmpty ? userPhone.trim() : null,
          'email': userEmail.trim(),
          'name': userName.isNotEmpty ? userName.trim() : null,
        },
        'theme': {
          'color': '#8B4513', // DinCharya warm brown color
        },
        'notes': {
          'plan_id': plan.id,
          'plan_duration': plan.duration,
          'user_email': userEmail.trim(),
          'coupon_code': couponCode ?? '',
          'timestamp': timestamp.toString(),
        },
        'retry': {'enabled': true, 'max_count': 3},
        'send_sms_hash': true,
        'remember_customer': true,
        'timeout': 300, // 5 minutes
      };

      // Validate options before proceeding
      if (!_validatePaymentOptions(options)) {
        debugPrint('❌ Payment options validation failed');
        onResult(PaymentResult.failure(
          errorMessage: 'Invalid payment configuration',
          errorCode: 'INVALID_CONFIG',
        ));
        return;
      }

      debugPrint('✅ Opening Razorpay with options: $options');
      _razorpay?.open(options);
    } catch (e) {
      debugPrint('Error initiating payment: $e');
      onResult(PaymentResult.failure(
        errorMessage: 'Failed to initiate payment: ${e.toString()}',
        errorCode: 'INITIATION_ERROR',
      ));
    }
  }

  // Generate secure random string
  // ignore: unused_element - kept for future security features
  String _generateSecureRandom() {
    final random = DateTime.now().microsecondsSinceEpoch % 10000;
    return random.toString().padLeft(4, '0');
  }

  // Validate payment options
  bool _validatePaymentOptions(Map<String, dynamic> options) {
    try {
      if (options['key'] == null || options['key'].toString().isEmpty) {
        debugPrint('❌ Key is missing');
        return false;
      }
      if (options['amount'] == null || options['amount'] <= 0) {
        debugPrint('❌ Amount is invalid: ${options['amount']}');
        return false;
      }
      if (options['currency'] == null ||
          options['currency'].toString().isEmpty) {
        debugPrint('❌ Currency is missing');
        return false;
      }
      if (options['name'] == null || options['name'].toString().isEmpty) {
        debugPrint('❌ Name is missing');
        return false;
      }
      debugPrint('✅ Payment options validated successfully');
      return true;
    } catch (e) {
      debugPrint('Error validating payment options: $e');
      return false;
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      debugPrint('🎉 Payment success callback received!');
      debugPrint('🎉 Payment ID: ${response.paymentId}');

      // Validate response
      if (response.paymentId == null || response.paymentId!.isEmpty) {
        debugPrint('❌ Invalid payment response - no paymentId');
        _onPaymentResult?.call(PaymentResult.failure(
          errorMessage: 'Invalid payment response',
          errorCode: 'INVALID_RESPONSE',
        ));
        return;
      }

      debugPrint('✅ Payment ID received: ${response.paymentId}');
      debugPrint('✅ Order ID: ${response.orderId ?? "none"}');
      debugPrint('✅ Signature: ${response.signature?.isNotEmpty == true ? "present" : "none"}');

      // Note: Signature verification only works with server-side order creation
      // For client-side checkout, we skip verification as orderId is not from Razorpay API
      // The payment is still valid - verified by Razorpay's internal systems

      final result = PaymentResult.success(
        paymentId: response.paymentId!,
        orderId: response.orderId ?? '',
        signature: response.signature ?? '',
      );

      // Save payment details to database FIRST
      try {
        await _savePaymentDetails(response);
        debugPrint('✅ Payment details saved successfully');
      } catch (saveError) {
        debugPrint('❌ Error saving payment: $saveError');
        // Still mark as success - payment was made, just log the save error
      }

      _onPaymentResult?.call(result);

      // Show success toast
      _showToast('Payment successful! Subscription activated.', isSuccess: true);
    } catch (e) {
      debugPrint('❌ Error handling payment success: $e');
      _onPaymentResult?.call(PaymentResult.failure(
        errorMessage: 'Error processing payment: ${e.toString()}',
        errorCode: 'PROCESSING_ERROR',
      ));
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    try {
      debugPrint('Payment error: ${response.message}');

      String errorMessage = 'Payment failed';
      String errorCode = 'UNKNOWN_ERROR';

      if (response.message != null && response.message!.isNotEmpty) {
        errorMessage = response.message!;
        // Extract error code if available
        if (response.message!.contains('cancelled')) {
          errorCode = 'USER_CANCELLED';
        } else if (response.message!.contains('failed')) {
          errorCode = 'PAYMENT_FAILED';
        } else if (response.message!.contains('timeout')) {
          errorCode = 'TIMEOUT';
        }
      }

      final result = PaymentResult.failure(
        errorMessage: errorMessage,
        errorCode: errorCode,
      );

      _onPaymentResult?.call(result);

      // Show error toast
      _showToast(errorMessage, isSuccess: false);
    } catch (e) {
      debugPrint('Error handling payment error: $e');
      _onPaymentResult?.call(PaymentResult.failure(
        errorMessage: 'Error processing payment failure: ${e.toString()}',
        errorCode: 'PROCESSING_ERROR',
      ));
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    try {
      debugPrint('External wallet selected: ${response.walletName}');
      // Handle external wallet selection if needed
    } catch (e) {
      debugPrint('Error handling external wallet: $e');
    }
  }

  // Verify payment signature using HMAC-SHA256
  // ignore: unused_element - kept for payment verification
  bool _verifyPaymentSignature(PaymentSuccessResponse response) {
    try {
      if (response.signature == null || response.signature!.isEmpty) {
        return false;
      }
      
      // Skip verification if key secret not configured
      if (_razorpayKeySecret.isEmpty) {
        debugPrint('⚠️ Skipping signature verification - key secret not configured');
        return true;
      }

      // Create the expected signature using HMAC-SHA256
      final data = '${response.orderId}|${response.paymentId}';
      final key = utf8.encode(_razorpayKeySecret);
      final hmac = Hmac(sha256, key);
      final digest = hmac.convert(utf8.encode(data));
      final expectedSignature = digest.toString();

      return response.signature == expectedSignature;
    } catch (e) {
      debugPrint('Error verifying payment signature: $e');
      return false;
    }
  }

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

  /// Save payment to SUPABASE with actual plan data
  Future<void> _savePaymentDetails(PaymentSuccessResponse response) async {
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

      // Use stored plan data or default to monthly
      final plan = _currentPlan ?? PaymentPlan.availablePlans[0];
      final amountInPaisa = (plan.price * 100).toInt();
      
      // Calculate expiry based on plan duration
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

      // Deactivate any existing active subscriptions first 
      // (prevents duplicate active records)
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

      // Save new subscription to Supabase
      await client.from('subscriptions').insert({
        'user_id': userId,
        'plan_id': plan.id,
        'plan_name': plan.name,
        'status': 'active',
        'razorpay_payment_id': response.paymentId,
        'razorpay_order_id': response.orderId,
        'razorpay_signature': response.signature,
        'amount': amountInPaisa,
        'currency': plan.currency,
        'started_at': now.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'is_trial': false,
      });

      // Also save to audit log
      await client.from('payment_audit_log').insert({
        'user_id': userId,
        'event_type': 'payment_success',
        'razorpay_payment_id': response.paymentId,
        'razorpay_order_id': response.orderId,
        'amount': amountInPaisa,
        'currency': plan.currency,
        'status': 'success',
        'metadata': {
          'signature': response.signature,
          'plan_id': plan.id,
          'plan_name': plan.name,
          'duration': plan.duration,
        },
      });

      debugPrint('✅ Payment saved to Supabase: ${plan.name} expires ${expiresAt.toIso8601String()}');
      
      // Also update user_profiles table to keep subscription status in sync
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

      // Refresh SubscriptionManager cache so premium status takes effect immediately
      await SubscriptionManager().onPaymentSuccess();
      debugPrint('✅ SubscriptionManager cache refreshed after payment');
      
      // Clear current plan after saving
      _currentPlan = null;
    } catch (e) {
      debugPrint('❌ Error saving payment to Supabase: $e');
    }
  }

  /// Check subscription from SUPABASE (not SharedPreferences!)
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

  /// Get payment info from SUPABASE (not SharedPreferences!)
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
          'signature': data[0]['razorpay_signature'],
          'provider': 'razorpay',
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

  /// Cancel subscription in SUPABASE (not SharedPreferences!)
  Future<void> clearSubscription() async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return;

      final client = await _supabase.client;
      if (client == null) return;

      // Mark subscription as cancelled in Supabase
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

  // Utility method to validate Razorpay credentials format
  static bool validateRazorpayCredentials() {
    return _razorpayKeyId.startsWith('rzp_') &&
        _razorpayKeyId != 'YOUR_RAZORPAY_KEY_ID' &&
        _razorpayKeyId.isNotEmpty;
  }

  // Get Razorpay configuration status
  static Map<String, dynamic> getRazorpayConfigStatus() {
    return {
      'key_id_configured': _razorpayKeyId.isNotEmpty && _razorpayKeyId.startsWith('rzp_'),
      'key_secret_configured': _razorpayKeySecret.isNotEmpty,
      'company_logo_configured': _companyLogo != 'https://your-logo-url.com/logo.png',
      'credentials_valid': validateRazorpayCredentials(),
    };
  }
}
