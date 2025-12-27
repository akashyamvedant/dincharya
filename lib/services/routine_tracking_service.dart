import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'supabase_service.dart';

/// Routine Tracking Service - 100% SUPABASE (NO LOCAL STORAGE!)
class RoutineTrackingService {
  static final RoutineTrackingService _instance = RoutineTrackingService._internal();
  factory RoutineTrackingService() => _instance;
  RoutineTrackingService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final SupabaseService _supabase = SupabaseService();

  Future<void> initialize() async {
    tz.initializeTimeZones();
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _notifications.initialize(initSettings, onDidReceiveNotificationResponse: _onNotificationTapped);
    debugPrint('✅ RoutineTrackingService initialized (100% Supabase)');
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  Future<void> scheduleRoutineNotifications(Map<String, dynamic> routine) async {
    final activities = routine['activities'] as List<dynamic>? ?? [];
    for (var activity in activities) {
      final time = activity['time'] as String?;
      final name = activity['name'] as String?;
      if (time != null && name != null) {
        await _scheduleNotification(name, time);
      }
    }
  }

  Future<void> _scheduleNotification(String activityName, String timeString) async {
    try {
      final time = _parseTime(timeString);
      if (time == null) return;

      final androidDetails = AndroidNotificationDetails(
        'routine_reminders',
        'Daily Routine Reminders',
        channelDescription: 'Notifications for daily routine activities',
        importance: Importance.high,
        priority: Priority.high,
      );

      const iosDetails = DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true);
      final notificationDetails = NotificationDetails(android: androidDetails, iOS: iosDetails);

      await _notifications.zonedSchedule(
        _generateNotificationId(activityName),
        'DinCharya Reminder',
        'Time for: $activityName',
        _nextInstanceOfTime(time),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
    }
  }

  TimeOfDay? _parseTime(String timeString) {
    try {
      final parts = timeString.split(':');
      if (parts.length == 2) {
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (e) {
      debugPrint('Error parsing time: $e');
    }
    return null;
  }

  int _generateNotificationId(String activityName) {
    return activityName.hashCode.abs() % 100000;
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Track activity - SAVES TO SUPABASE!
  Future<void> trackActivity({
    required String activityName,
    required bool completed,
    required String scheduledTime,
    DateTime? actualTime,
    String? reason,
    String? notes,
  }) async {
    try {
      final currentUser = _supabase.currentUser;
      if (currentUser == null) {
        debugPrint('⚠️ Cannot track: User not authenticated');
        return;
      }

      final client = await _supabase.client;
      if (client == null) {
        debugPrint('⚠️ Supabase not initialized');
        return;
      }

      await client.from('routine_tracking').insert({
        'user_id': currentUser.id,
        'activity_name': activityName,
        'scheduled_time': scheduledTime,
        'completed': completed,
        'completed_at': actualTime?.toIso8601String(),
        'reason': reason,
        'notes': notes,
        'tracking_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      });

      debugPrint('✅ Tracked: $activityName - ${completed ? "Completed" : "Missed"}');
    } catch (e) {
      debugPrint('❌ Error tracking: $e');
    }
  }

  /// Get today's progress - FROM SUPABASE!
  Future<Map<String, dynamic>> getTodayProgress() async {
    try {
      final currentUser = _supabase.currentUser;
      if (currentUser == null) return {'activities': []};

      final client = await _supabase.client;
      if (client == null) return {'activities': []};

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final data = await client
          .from('routine_tracking')
          .select()
          .eq('user_id', currentUser.id)
          .eq('tracking_date', today);

      return {'activities': data};
    } catch (e) {
      debugPrint('Error getting today progress: $e');
      return {'activities': []};
    }
  }

  /// Get tracking history - FROM SUPABASE!
  Future<List<Map<String, dynamic>>> getTrackingHistory({int days = 30}) async {
    try {
      final currentUser = _supabase.currentUser;
      if (currentUser == null) return [];

      final client = await _supabase.client;
      if (client == null) return [];

      final cutoffDate = DateTime.now().subtract(Duration(days: days));
      final cutoffDateStr = DateFormat('yyyy-MM-dd').format(cutoffDate);

      final data = await client
          .from('routine_tracking')
          .select()
          .eq('user_id', currentUser.id)
          .gte('tracking_date', cutoffDateStr)
          .order('tracking_date', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error getting history: $e');
      return [];
    }
  }

  /// Get completion stats - FROM SUPABASE!
  Future<Map<String, dynamic>> getCompletionStats() async {
    try {
      final currentUser = _supabase.currentUser;
      if (currentUser == null) return {'total': 0, 'completed': 0, 'completionRate': 0.0, 'missed': 0};

      final client = await _supabase.client;
      if (client == null) return {'total': 0, 'completed': 0, 'completionRate': 0.0, 'missed': 0};

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final todayData = await client
          .from('routine_tracking')
          .select()
          .eq('user_id', currentUser.id)
          .eq('tracking_date', today);

      final total = todayData.length;
      final completed = todayData.where((e) => e['completed'] == true).length;

      return {
        'total': total,
        'completed': completed,
        'completionRate': total > 0 ? (completed / total) : 0.0,
        'missed': total - completed,
      };
    } catch (e) {
      debugPrint('Error getting stats: $e');
      return {'total': 0, 'completed': 0, 'completionRate': 0.0, 'missed': 0};
    }
  }

  /// Clear old data - FROM SUPABASE!
  Future<void> clearOldData() async {
    try {
      final currentUser = _supabase.currentUser;
      if (currentUser == null) return;

      final client = await _supabase.client;
      if (client == null) return;

      final cutoffDate = DateTime.now().subtract(const Duration(days: 90));
      final cutoffDateStr = DateFormat('yyyy-MM-dd').format(cutoffDate);

      await client
          .from('routine_tracking')
          .delete()
          .eq('user_id', currentUser.id)
          .lt('tracking_date', cutoffDateStr);

      debugPrint('🗑️ Cleared data older than 90 days');
    } catch (e) {
      debugPrint('Error clearing old data: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
