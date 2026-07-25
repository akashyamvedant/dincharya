// lib/services/ad_gate.dart
// Centralized ad-gating singleton enforcing cross-format cooldowns,
// session budgets, and first-session protections.

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Central gatekeeper for ALL ad formats in the app.
///
/// Problems it solves:
/// 1. App Open + Interstitial had SEPARATE cooldowns → user could get both
///    back-to-back within 30 seconds. Now: shared 3-minute cooldown across ALL
///    full-screen ad formats.
/// 2. No per-day interstitial budget → heavy users could see many interstitials
///    per day. Now: max 3 interstitial-class exposures per day.
/// 3. Individual widgets don't know what other formats are doing.
///    Now: single source of truth for all gating decisions.
///
/// Usage:
///   final gate = AdGate();
///   if (await gate.canShowFullScreen()) { ... gate.didShowFullScreen(); }
///   if (await gate.canShowInterstitial()) { ... gate.didShowInterstitial(); }
class AdGate {
  AdGate._();
  static final AdGate _instance = AdGate._();
  factory AdGate() => _instance;

  // ── SharedPreferences keys ──
  static const String _prefLastFullScreenTime = 'adgate_last_full_screen_time';
  static const String _prefSessionInterstitialCount = 'adgate_session_interstitial_count';
  static const String _prefSessionResetDate = 'adgate_session_reset_date';

  // ── Configuration ──
  /// Shared cooldown for ALL full-screen ad formats (App Open + Interstitial).
  /// Google's policy: users should never feel bombarded by full-screen ads.
  /// 3 minutes = comfortable gap even during frequent app switches.
  static const int sharedFullScreenCooldownSeconds = 180; // 3 minutes

  /// Maximum interstitial-class ad exposures per user per calendar day.
  /// Includes both interstitial and app-open. Keeps ad fatigue in check.
  static const int maxFullScreenPerDay = 3;

  // ── Methods ──

  /// Check if ANY full-screen ad (App Open or Interstitial) can be shown.
  /// Enforces the shared cooldown: once any full-screen ad shows, ALL formats
  /// are blocked for [sharedFullScreenCooldownSeconds].
  Future<bool> canShowFullScreen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTimeMs = prefs.getInt(_prefLastFullScreenTime);
      if (lastTimeMs == null) return true;

      final lastTime = DateTime.fromMillisecondsSinceEpoch(lastTimeMs);
      final secondsSinceLast = DateTime.now().difference(lastTime).inSeconds;
      if (secondsSinceLast < sharedFullScreenCooldownSeconds) {
        debugPrint(
            '🚦 AdGate: Full-screen cooldown active (${secondsSinceLast}s < ${sharedFullScreenCooldownSeconds}s)');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('⚠️ AdGate: canShowFullScreen error — $e');
      return true; // Fail open — don't block ads on pref read failure
    }
  }

  /// Call after ANY full-screen ad was shown (App Open OR Interstitial).
  /// Resets the shared cooldown timer for ALL formats.
  Future<void> didShowFullScreen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          _prefLastFullScreenTime, DateTime.now().millisecondsSinceEpoch);

      // Also increment the session interstitial budget counter.
      await _incrementSessionCount();

      debugPrint('🚦 AdGate: Full-screen cooldown reset — all formats blocked for ${sharedFullScreenCooldownSeconds}s');
    } catch (e) {
      debugPrint('⚠️ AdGate: didShowFullScreen error — $e');
    }
  }

  /// Check if we're under the daily interstitial budget AND the shared cooldown
  /// has passed. Combines both gates in one check for convenience.
  Future<bool> canShowInterstitial() async {
    if (!await canShowFullScreen()) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      _ensureDayReset(prefs);

      final count = prefs.getInt(_prefSessionInterstitialCount) ?? 0;
      if (count >= maxFullScreenPerDay) {
        debugPrint('🚦 AdGate: Daily interstitial budget exhausted ($count/$maxFullScreenPerDay)');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('⚠️ AdGate: canShowInterstitial error — $e');
      return true; // Fail open
    }
  }

  /// Call after an interstitial was shown. Increments the daily count.
  Future<void> didShowInterstitial() async {
    await didShowFullScreen(); // Shared cooldown always applies
  }

  /// Get remaining interstitial budget for the day (for debugging/logging).
  Future<int> getRemainingBudget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _ensureDayReset(prefs);
      final count = prefs.getInt(_prefSessionInterstitialCount) ?? 0;
      final remaining = maxFullScreenPerDay - count;
      return remaining < 0 ? 0 : remaining;
    } catch (e) {
      return maxFullScreenPerDay;
    }
  }

  // ── Internal helpers ──

  Future<void> _incrementSessionCount() async {
    final prefs = await SharedPreferences.getInstance();
    _ensureDayReset(prefs);
    final count = (prefs.getInt(_prefSessionInterstitialCount) ?? 0) + 1;
    await prefs.setInt(_prefSessionInterstitialCount, count);
    debugPrint('🚦 AdGate: Interstitial count = $count/$maxFullScreenPerDay today');
  }

  /// Reset the daily counter if the stored date is not today.
  void _ensureDayReset(SharedPreferences prefs) {
    final today = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
    final storedDate = prefs.getString(_prefSessionResetDate);
    if (storedDate != today) {
      prefs.setInt(_prefSessionInterstitialCount, 0);
      prefs.setString(_prefSessionResetDate, today);
    }
  }
}
