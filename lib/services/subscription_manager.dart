// lib/services/subscription_manager.dart
//
// Centralized subscription state manager — singleton.
// Caches premium status to avoid repeated DB queries and provides
// feature-gating helpers used across the entire app.
// Also handles 7-day free trial activation and status.

import 'package:flutter/foundation.dart';
import 'supabase_service.dart';
import 'payment_service.dart';
import 'ads_service.dart';

/// Feature flags gated behind premium subscription
enum PremiumFeature {
  adFree,
  unlimitedAiGuide,
  premiumSessions,
  advancedAnalytics,
  offlineContent,
  prioritySupport,
}

class SubscriptionManager extends ChangeNotifier {
  // ── Singleton ──
  static final SubscriptionManager _instance = SubscriptionManager._internal();
  factory SubscriptionManager() => _instance;
  SubscriptionManager._internal();

  final PaymentService _paymentService = PaymentService();
  final SupabaseService _supabase = SupabaseService();

  // ── State ──
  bool _isPremium = false;
  bool _isLoaded = false;
  bool _isTrial = false;
  DateTime? _expiresAt;
  DateTime? _trialExpiresAt;
  String? _planId;
  String _planStatus = 'free';
  
  // Free-tier daily AI message limit
  static const int freeAiDailyLimit = 5;
  int _aiMessagesToday = 0;
  DateTime? _aiCountDate;

  // Trial constants
  static const int trialDurationDays = 7;

  // ── Getters ──
  bool get isPremium => _isPremium;
  bool get isLoaded => _isLoaded;
  bool get isTrial => _isTrial;
  DateTime? get expiresAt => _expiresAt;
  DateTime? get trialExpiresAt => _trialExpiresAt;
  String get planStatus => _planStatus;
  String? get planId => _planId;
  int get aiMessagesRemaining =>
      _isPremium ? 999 : (freeAiDailyLimit - _aiMessagesToday).clamp(0, freeAiDailyLimit);
  bool get hasAiMessagesLeft => _isPremium || _aiMessagesToday < freeAiDailyLimit;

  /// Check if a specific premium feature is available to the user
  bool canAccess(PremiumFeature feature) {
    if (_isPremium) return true;
    // Free users can access nothing from premium features
    switch (feature) {
      case PremiumFeature.adFree:
        return false;
      case PremiumFeature.unlimitedAiGuide:
        return hasAiMessagesLeft; // limited access
      case PremiumFeature.premiumSessions:
        return false;
      case PremiumFeature.advancedAnalytics:
        return false; // basic analytics only
      case PremiumFeature.offlineContent:
        return false;
      case PremiumFeature.prioritySupport:
        return false;
    }
  }

  /// Initialize — call once at app startup
  Future<void> initialize() async {
    if (_isLoaded) return;
    await refresh();
  }

  /// Refresh subscription status from Supabase
  Future<void> refresh() async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) {
        _setFree();
        return;
      }

      final client = await _supabase.client;
      if (client == null) {
        _setFree();
        return;
      }

      // Query for active subscription (includes paid + trial)
      final data = await client
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active')
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('expires_at', ascending: false)
          .limit(1);

      if (data.isNotEmpty) {
        final sub = data[0];
        _isPremium = true;
        _planId = sub['plan_id'] as String?;
        _isTrial = sub['is_trial'] == true;
        _planStatus = _isTrial ? 'trial' : 'premium';

        final expiresStr = sub['expires_at'] as String?;
        _expiresAt = expiresStr != null ? DateTime.tryParse(expiresStr) : null;

        if (_isTrial) {
          final trialExpStr = sub['trial_expires_at'] as String?;
          _trialExpiresAt = trialExpStr != null ? DateTime.tryParse(trialExpStr) : null;
        }
      } else {
        _setFree();
      }

      _isLoaded = true;
      notifyListeners();
      debugPrint('✅ SubscriptionManager: ${_isPremium ? (_isTrial ? "TRIAL" : "PREMIUM") : "FREE"} (plan: $_planId)');
    } catch (e) {
      debugPrint('⚠️ SubscriptionManager refresh error: $e');
      _setFree();
    }
  }

  /// Start a 7-day free trial for a new user
  /// Call this after successful signup/onboarding
  Future<bool> startFreeTrial() async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return false;

      final client = await _supabase.client;
      if (client == null) return false;

      // Check if user already had a trial
      final existing = await client
          .from('subscriptions')
          .select('id')
          .eq('user_id', userId)
          .eq('is_trial', true)
          .limit(1);

      if (existing.isNotEmpty) {
        debugPrint('⚠️ User already had a trial');
        return false;
      }

      final now = DateTime.now();
      final trialEnd = now.add(Duration(days: trialDurationDays));

      await client.from('subscriptions').insert({
        'user_id': userId,
        'plan_id': 'free_trial',
        'plan_name': '7-Day Free Trial',
        'status': 'active',
        'amount': 0,
        'currency': 'INR',
        'started_at': now.toIso8601String(),
        'expires_at': trialEnd.toIso8601String(),
        'is_trial': true,
        'trial_started_at': now.toIso8601String(),
        'trial_expires_at': trialEnd.toIso8601String(),
      });

      debugPrint('✅ Free trial started! Expires: $trialEnd');
      await refresh();
      return true;
    } catch (e) {
      debugPrint('❌ Failed to start free trial: $e');
      return false;
    }
  }

  /// Track AI message usage for free users
  void trackAiMessage() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Reset counter for new day
    if (_aiCountDate == null || _aiCountDate != todayDate) {
      _aiMessagesToday = 0;
      _aiCountDate = todayDate;
    }

    _aiMessagesToday++;
    notifyListeners();
  }

  /// Days remaining until subscription/trial expires
  int get daysRemaining {
    if (!_isPremium || _expiresAt == null) return 0;
    return _expiresAt!.difference(DateTime.now()).inDays;
  }

  /// Trial days remaining
  int get trialDaysRemaining {
    if (!_isTrial || _trialExpiresAt == null) return 0;
    return _trialExpiresAt!.difference(DateTime.now()).inDays;
  }

  /// Whether subscription is about to expire (within 7 days)
  bool get isExpiringSoon {
    return _isPremium && daysRemaining <= 7 && daysRemaining > 0;
  }

  /// Whether this is a lifetime plan
  bool get isLifetime {
    return _planId == 'lifetime_premium';
  }

  void _setFree() {
    _isPremium = false;
    _isTrial = false;
    _expiresAt = null;
    _trialExpiresAt = null;
    _planId = null;
    _planStatus = 'free';
    _isLoaded = true;
  }

  /// Call after a successful payment to update cache immediately
  Future<void> onPaymentSuccess() async {
    _isLoaded = false; // Force re-fetch
    await refresh();
    
    // Also refresh AdsService so ads stop showing immediately
    try {
      await AdsService().refreshPremiumStatus();
      debugPrint('✅ AdsService refreshed after payment — ads disabled');
    } catch (e) {
      debugPrint('⚠️ AdsService refresh failed (non-blocking): $e');
    }
  }

  /// Call after subscription cancellation
  Future<void> onCancellation() async {
    await _paymentService.clearSubscription();
    _isLoaded = false;
    await refresh();
  }
}
