import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase Analytics service for DAU/MAU tracking and user engagement.
/// Works alongside Supabase — Firebase Analytics is client-side only,
/// it doesn't interact with your Supabase backend at all.
///
/// Auto-collected (NO code needed): DAU, MAU, session_start, screen_view,
/// first_open, app_update, app_remove, ad_click, ad_impression, etc.
///
/// This service adds Dincharya-specific custom events on top.
class FirebaseAnalyticsService {
  // Singleton
  static final FirebaseAnalyticsService _instance =
      FirebaseAnalyticsService._internal();
  factory FirebaseAnalyticsService() => _instance;
  FirebaseAnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Get the observer for MaterialApp's navigatorObservers.
  /// This auto-tracks screen_view events for every route change.
  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  // ─────────────────────────────────────────────
  //  USER IDENTITY (link Firebase analytics to your Supabase user)
  // ─────────────────────────────────────────────

  /// Set Supabase user ID so Firebase can track per-user behavior.
  /// Call this after successful login.
  Future<void> setUserId(String userId) async {
    try {
      await _analytics.setUserId(id: userId);
      debugPrint('📊 Firebase Analytics: User ID set');
    } catch (e) {
      debugPrint('❌ Firebase Analytics setUserId failed: $e');
    }
  }

  /// Set user properties for segmentation in Firebase Console
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
    } catch (e) {
      debugPrint('❌ Firebase Analytics setUserProperty failed: $e');
    }
  }

  /// Clear user identity on logout
  Future<void> clearUser() async {
    try {
      await _analytics.setUserId(id: null);
      debugPrint('📊 Firebase Analytics: User cleared');
    } catch (e) {
      debugPrint('❌ Firebase Analytics clearUser failed: $e');
    }
  }

  // ─────────────────────────────────────────────
  //  CUSTOM EVENTS — Dincharya Specific
  // ─────────────────────────────────────────────

  /// Track when user completes a daily task
  Future<void> logTaskCompleted({
    required String taskName,
    required String timeOfDay,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'task_completed',
        parameters: {
          'task_name': taskName,
          'time_of_day': timeOfDay,
        },
      );
    } catch (e) {
      debugPrint('❌ Firebase Analytics logTaskCompleted failed: $e');
    }
  }

  /// Track when user starts a yoga session
  Future<void> logYogaSessionStart({
    required String sessionId,
    required String sessionName,
    int? durationMinutes,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'yoga_session_start',
        parameters: {
          'session_id': sessionId,
          'session_name': sessionName,
          if (durationMinutes != null) 'duration_minutes': durationMinutes,
        },
      );
    } catch (e) {
      debugPrint('❌ Firebase Analytics logYogaSessionStart failed: $e');
    }
  }

  /// Track when user completes a yoga session
  Future<void> logYogaSessionComplete({
    required String sessionId,
    required int durationSeconds,
    required int posesCompleted,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'yoga_session_complete',
        parameters: {
          'session_id': sessionId,
          'duration_seconds': durationSeconds,
          'poses_completed': posesCompleted,
        },
      );
    } catch (e) {
      debugPrint('❌ Firebase Analytics logYogaSessionComplete failed: $e');
    }
  }

  /// Track daily routine completion percentage
  Future<void> logDailyProgress({
    required int completedTasks,
    required int totalTasks,
    required int completionPercent,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'daily_progress',
        parameters: {
          'completed_tasks': completedTasks,
          'total_tasks': totalTasks,
          'completion_percent': completionPercent,
        },
      );
    } catch (e) {
      debugPrint('❌ Firebase Analytics logDailyProgress failed: $e');
    }
  }

  /// Track subscription events
  Future<void> logSubscriptionEvent({
    required String action, // 'started', 'renewed', 'cancelled'
    String? plan,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'subscription_event',
        parameters: {
          'action': action,
          if (plan != null) 'plan': plan,
        },
      );
    } catch (e) {
      debugPrint('❌ Firebase Analytics logSubscriptionEvent failed: $e');
    }
  }

  /// Generic event logger for any custom event
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
    } catch (e) {
      debugPrint('❌ Firebase Analytics logEvent($name) failed: $e');
    }
  }
}
