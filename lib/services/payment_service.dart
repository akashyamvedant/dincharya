// lib/services/payment_service.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../models/payment_models.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'supabase_service.dart';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  Razorpay? _razorpay;
  bool _isInitialized = false;
  Function(PaymentResult)? _onPaymentResult;
  final SupabaseService _supabase = SupabaseService();

  // Razorpay credentials from environment variables
  // You can get these from your Razorpay Dashboard: https://dashboard.razorpay.com/
  static const String _razorpayKeyId = String.fromEnvironment('RAZORPAY_KEY_ID',
      defaultValue: 'rzp_live_2kYJDdAef2pyQP');
  static const String _razorpayKeySecret = String.fromEnvironment(
      'RAZORPAY_KEY_SECRET',
      defaultValue: '0KIYQ2tCGiWRwyRgXT1SxJla');
  static const String _companyName = 'DinCharya';
  static const String _companyLogo =
      'https://your-logo-url.com/logo.png'; // Replace with your logo URL

  // Razorpay Webhook Secret for payment verification
  static const String _webhookSecret = String.fromEnvironment(
      'RAZORPAY_WEBHOOK_SECRET',
      defaultValue: 'YOUR_WEBHOOK_SECRET');

  // Input validation helpers
  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }

  bool _isValidPhone(String phone) {
    return RegExp(r'^\+?[1-9]\d{1,14}$').hasMatch(phone);
  }

  bool _isValidName(String name) {
    return name.isNotEmpty &&
        name.length <= 100 &&
        RegExp(r'^[a-zA-Z\s]+$').hasMatch(name);
  }

  bool _isValidAmount(double amount) {
    return amount > 0 && amount <= 100000; // Max 1 lakh INR
  }

  // Secure hash function for payment verification
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
    if (_razorpayKeyId == 'YOUR_RAZORPAY_KEY_ID' ||
        _razorpayKeyId.isEmpty ||
        _razorpayKeySecret == 'YOUR_RAZORPAY_KEY_SECRET' ||
        _razorpayKeySecret.isEmpty) {
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
  }) async {
    try {
      // Input validation
      if (!_isValidEmail(userEmail)) {
        onResult(PaymentResult.failure(
          errorMessage: 'Invalid email address',
          errorCode: 'INVALID_EMAIL',
        ));
        return;
      }

      if (!_isValidPhone(userPhone)) {
        onResult(PaymentResult.failure(
          errorMessage: 'Invalid phone number',
          errorCode: 'INVALID_PHONE',
        ));
        return;
      }

      if (!_isValidName(userName)) {
        onResult(PaymentResult.failure(
          errorMessage: 'Invalid user name',
          errorCode: 'INVALID_NAME',
        ));
        return;
      }

      if (!_isValidAmount(plan.price)) {
        onResult(PaymentResult.failure(
          errorMessage: 'Invalid payment amount',
          errorCode: 'INVALID_AMOUNT',
        ));
        return;
      }

      // Check if Razorpay is initialized
      if (!_isInitialized) {
        onResult(PaymentResult.failure(
          errorMessage: 'Payment service not available',
          errorCode: 'SERVICE_UNAVAILABLE',
        ));
        return;
      }

      _onPaymentResult = onResult;

      // Generate secure order ID with timestamp and random component
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = _generateSecureRandom();
      final orderId = 'order_${timestamp}_$random';

      final options = {
        'key': _razorpayKeyId,
        'amount': (plan.price * 100).toInt(), // Amount in paisa
        'currency': plan.currency,
        'name': _companyName,
        'description': '${plan.name} Subscription',
        'order_id': orderId,
        'image': _companyLogo,
        'prefill': {
          'contact': userPhone.trim(),
          'email': userEmail.trim(),
          'name': userName.trim(),
        },
        'theme': {
          'color': '#6366F1', // Your app's primary color
        },
        'notes': {
          'plan_id': plan.id,
          'plan_duration': plan.duration,
          'user_email': userEmail.trim(),
          'timestamp': timestamp.toString(),
        },
        'retry': {'enabled': true, 'max_count': 3},
        'send_sms_hash': true,
        'remember_customer': true,
        'timeout': 300, // 5 minutes
        'modal': {
          'ondismiss': () {
            onResult(PaymentResult.failure(
              errorMessage: 'Payment cancelled by user',
              errorCode: 'USER_CANCELLED',
            ));
          },
        },
      };

      // Validate options before proceeding
      if (!_validatePaymentOptions(options)) {
        onResult(PaymentResult.failure(
          errorMessage: 'Invalid payment configuration',
          errorCode: 'INVALID_CONFIG',
        ));
        return;
      }

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
  String _generateSecureRandom() {
    final random = DateTime.now().microsecondsSinceEpoch % 10000;
    return random.toString().padLeft(4, '0');
  }

  // Validate payment options
  bool _validatePaymentOptions(Map<String, dynamic> options) {
    try {
      if (options['key'] == null || options['key'].toString().isEmpty) {
        return false;
      }
      if (options['amount'] == null || options['amount'] <= 0) {
        return false;
      }
      if (options['currency'] == null ||
          options['currency'].toString().isEmpty) {
        return false;
      }
      if (options['name'] == null || options['name'].toString().isEmpty) {
        return false;
      }
      if (options['order_id'] == null ||
          options['order_id'].toString().isEmpty) {
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Error validating payment options: $e');
      return false;
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    try {
      debugPrint('Payment success: ${response.paymentId}');

      // Validate response
      if (response.paymentId == null || response.paymentId!.isEmpty) {
        _onPaymentResult?.call(PaymentResult.failure(
          errorMessage: 'Invalid payment response',
          errorCode: 'INVALID_RESPONSE',
        ));
        return;
      }

      // Verify payment signature if webhook secret is configured
      if (_webhookSecret != 'YOUR_WEBHOOK_SECRET' &&
          _webhookSecret.isNotEmpty) {
        if (!_verifyPaymentSignature(response)) {
          _onPaymentResult?.call(PaymentResult.failure(
            errorMessage: 'Payment verification failed',
            errorCode: 'VERIFICATION_FAILED',
          ));
          return;
        }
      }

      final result = PaymentResult.success(
        paymentId: response.paymentId!,
        orderId: response.orderId ?? '',
        signature: response.signature ?? '',
      );

      _onPaymentResult?.call(result);
      _savePaymentDetails(response);

      // Show success toast
      _showToast('Payment successful!', isSuccess: true);
    } catch (e) {
      debugPrint('Error handling payment success: $e');
      _onPaymentResult?.call(PaymentResult.failure(
        errorMessage: 'Error processing payment success: ${e.toString()}',
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

  // Verify payment signature
  bool _verifyPaymentSignature(PaymentSuccessResponse response) {
    try {
      if (response.signature == null || response.signature!.isEmpty) {
        return false;
      }

      // Create the expected signature
      final data = '${response.orderId}|${response.paymentId}';
      final expectedSignature = _hashPaymentData(data + _webhookSecret);

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

  /// Save payment to SUPABASE (not SharedPreferences!)
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

      // Save to Supabase subscriptions table
      await client.from('subscriptions').insert({
        'user_id': userId,
        'plan_id': 'monthly', // You can pass this dynamically
        'plan_name': 'Premium',
        'status': 'active',
        'razorpay_payment_id': response.paymentId,
        'razorpay_order_id': response.orderId,
        'razorpay_signature': response.signature,
        'amount': 9900, // Store in paisa
        'currency': 'INR',
        'started_at': DateTime.now().toIso8601String(),
        'expires_at': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      });

      // Also save to audit log
      await client.from('payment_audit_log').insert({
        'user_id': userId,
        'event_type': 'payment_success',
        'razorpay_payment_id': response.paymentId,
        'razorpay_order_id': response.orderId,
        'amount': 9900,
        'status': 'success',
        'metadata': {'signature': response.signature},
      });

      debugPrint('✅ Payment saved to Supabase');
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
        _razorpayKeyId.isNotEmpty &&
        _razorpayKeySecret != 'YOUR_RAZORPAY_KEY_SECRET' &&
        _razorpayKeySecret.isNotEmpty;
  }

  // Get Razorpay configuration status
  static Map<String, dynamic> getRazorpayConfigStatus() {
    return {
      'key_id_configured':
          _razorpayKeyId != 'YOUR_RAZORPAY_KEY_ID' && _razorpayKeyId.isNotEmpty,
      'key_secret_configured':
          _razorpayKeySecret != 'YOUR_RAZORPAY_KEY_SECRET' &&
              _razorpayKeySecret.isNotEmpty,
      'webhook_configured':
          _webhookSecret != 'YOUR_WEBHOOK_SECRET' && _webhookSecret.isNotEmpty,
      'company_logo_configured':
          _companyLogo != 'https://your-logo-url.com/logo.png',
      'credentials_valid': validateRazorpayCredentials(),
    };
  }
}
