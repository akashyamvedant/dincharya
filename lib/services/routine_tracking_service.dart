import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'supabase_service.dart';
import 'notification_deep_link_service.dart';

/// Routine Tracking Service - 100% SUPABASE (NO LOCAL STORAGE!)
class RoutineTrackingService {
  static final RoutineTrackingService _instance = RoutineTrackingService._internal();
  factory RoutineTrackingService() => _instance;
  RoutineTrackingService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final SupabaseService _supabase = SupabaseService();
  bool _isInitialized = false;
  
  // Notification comes 5 minutes BEFORE task time
  static const int reminderMinutesBefore = 5;

  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('⚠️ RoutineTrackingService already initialized');
      return;
    }
    
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata')); // India timezone
      debugPrint('✅ Timezone set to Asia/Kolkata');
      
      // DO NOT re-initialize FlutterLocalNotificationsPlugin here!
      // NotificationService already initialized it with a unified tap handler
      // that routes both alarm and task notifications correctly.
      // We only use _notifications for SCHEDULING, not for tap handling.
      
      // Request Android notification permission (Android 13+)
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final notificationPermission = await androidPlugin.requestNotificationsPermission();
        debugPrint('🔔 Notification permission granted: $notificationPermission');
        
        final exactAlarmPermission = await androidPlugin.requestExactAlarmsPermission();
        debugPrint('⏰ Exact alarm permission granted: $exactAlarmPermission');
      }
      
      _isInitialized = true;
      debugPrint('✅ RoutineTrackingService initialized (scheduling only — tap handling via NotificationService)');
      
      // NOTE: Cold-start notification handling is done by NotificationService.checkForAlarmLaunch()
      // in main.dart — it handles BOTH alarm AND task payloads.
    } catch (e) {
      debugPrint('❌ Failed to initialize RoutineTrackingService: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    // This handler is kept as a no-op in case any old code references it.
    // All notification tap handling is now centralized in NotificationService.
    debugPrint('🔔 RoutineTrackingService._onNotificationTapped called (delegated to NotificationService)');
  }
  
  /// Send immediate test notification to verify system works
  Future<void> sendTestNotification() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      
      debugPrint('🧪 Sending TEST notification...');
      
      const androidDetails = AndroidNotificationDetails(
        'test_channel',
        'Test Notifications',
        channelDescription: 'For testing notifications',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );
      const iosDetails = DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true);
      const notificationDetails = NotificationDetails(android: androidDetails, iOS: iosDetails);

      await _notifications.show(
        0,
        '🧪 Test Notification',
        'If you see this, notifications are working!',
        notificationDetails,
      );
      debugPrint('✅ Test notification sent!');
    } catch (e) {
      debugPrint('❌ Test notification failed: $e');
    }
  }

  /// Schedule a test notification 10 seconds from now
  Future<void> testScheduledNotification() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      
      debugPrint('🧪 Scheduling TEST notification for 10 seconds from now...');
      
      final scheduledTime = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10));
      
      final androidDetails = AndroidNotificationDetails(
        'dincharya_test_99999', // Unique channel for test
        'Test Reminders',
        channelDescription: 'DinCharya test notifications',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        showWhen: true,
        when: scheduledTime.millisecondsSinceEpoch,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        subText: 'DinCharya',
        ticker: 'Test Notification',
        styleInformation: const DefaultStyleInformation(true, true),
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true, 
        presentBadge: true, 
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );
      final notificationDetails = NotificationDetails(android: androidDetails, iOS: iosDetails);

      debugPrint('📍 Scheduled for: $scheduledTime');
      
      await _notifications.zonedSchedule(
        99999, // unique test ID
        '⏰ Test Task - Morning Yoga',
        'Coming up at 06:30! Get ready in 5 minutes.',
        scheduledTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      
      debugPrint('✅ Test scheduled notification set for $scheduledTime');
      
      // Check pending notifications
      await checkPendingNotifications();
    } catch (e) {
      debugPrint('❌ Test scheduled notification failed: $e');
    }
  }
  
  /// Check all pending notifications
  Future<void> checkPendingNotifications() async {
    try {
      final pending = await _notifications.pendingNotificationRequests();
      debugPrint('📋 Pending notifications: ${pending.length}');
      for (var n in pending) {
        debugPrint('  📌 ID: ${n.id}, Title: ${n.title}, Body: ${n.body}');
      }
    } catch (e) {
      debugPrint('❌ Error checking pending: $e');
    }
  }

  Future<void> scheduleRoutineNotifications(Map<String, dynamic> routine) async {
    if (!_isInitialized) {
      debugPrint('⚠️ Service not initialized, initializing now...');
      await initialize();
    }
    
    final activities = routine['activities'] as List<dynamic>? ?? [];
    debugPrint('📅 Scheduling notifications for ${activities.length} activities...');
    
    // Collect all scheduled task names for group summary
    List<String> scheduledTaskNames = [];
    
    int scheduledCount = 0;
    for (var activity in activities) {
      final time = activity['time'] as String?;
      final name = activity['name'] as String?;
      final taskId = activity['id'] as String?;  // Get task ID for deep linking
      if (time != null && name != null) {
        final success = await _scheduleNotification(name, time, taskId: taskId);
        if (success) {
          scheduledCount++;
          scheduledTaskNames.add('⏰ $name');
        }
      }
    }
    
    // If we have multiple tasks, also schedule a group summary notification
    // This ensures OEM devices show task names when grouped
    if (scheduledTaskNames.length > 1) {
      await _scheduleGroupSummary(scheduledTaskNames);
    }
    
    debugPrint('✅ Successfully scheduled $scheduledCount/${activities.length} notifications');
  }
  
  /// Schedule a group summary notification that shows all task names
  /// NOTE: This only sets up group styling for scheduled notifications
  /// It does NOT show an instant notification (that was causing bugs!)
  Future<void> _scheduleGroupSummary(List<String> taskNames) async {
    try {
      // Group summary is handled automatically by Android when multiple
      // notifications with same groupKey are shown. No need to show instant notification.
      debugPrint('📋 Group summary configured for ${taskNames.length} tasks (will show when individual reminders fire)');
    } catch (e) {
      debugPrint('❌ Error configuring group summary: $e');
    }
  }

  /// Schedule a notification for a specific task
  /// [taskId] is included in payload for deep linking (highlight on tap)
  Future<bool> _scheduleNotification(String activityName, String timeString, {String? taskId}) async {
    try {
      final time = _parseTime(timeString);
      if (time == null) {
        return false;
      }
      
      final scheduledTime = _getScheduledTime(time);
      final taskTimeFormatted = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      final notificationId = _generateNotificationId(activityName);
      
      // Build payload for deep linking
      final payload = taskId != null ? 'task_id:$taskId' : null;
      
      // Use shared channel with group key for proper grouping
      final androidDetails = AndroidNotificationDetails(
        'dincharya_reminders',
        'DinCharya Reminders',
        channelDescription: 'DinCharya routine task reminders',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        showWhen: true,
        when: scheduledTime.millisecondsSinceEpoch,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        autoCancel: true,
        ongoing: false,
        groupKey: 'dincharya_tasks',
        setAsGroupSummary: false,
        subText: 'DinCharya',
        ticker: 'DinCharya: $activityName',
        styleInformation: BigTextStyleInformation(
          'Scheduled for $taskTimeFormatted\nGet ready in $reminderMinutesBefore minutes!',
          contentTitle: '⏰ $activityName',
          summaryText: 'DinCharya',
        ),
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true, 
        presentBadge: true, 
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );
      final notificationDetails = NotificationDetails(android: androidDetails, iOS: iosDetails);
      
      await _notifications.zonedSchedule(
        notificationId,
        '⏰ $activityName',
        'Coming up at $taskTimeFormatted! Get ready in $reminderMinutesBefore minutes.',
        scheduledTime,
        notificationDetails,
        payload: payload,  // Include task ID for deep linking
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      
      return true;
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
      return false;
    }
  }

  TimeOfDay? _parseTime(String timeString) {
    try {
      // Handle "HH:MM" format
      final parts = timeString.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1].replaceAll(RegExp(r'[^0-9]'), ''));
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (e) {
      debugPrint('❌ Error parsing time "$timeString": $e');
    }
    return null;
  }

  int _generateNotificationId(String activityName) {
    return activityName.hashCode.abs() % 100000;
  }

  tz.TZDateTime _getScheduledTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    
    // Calculate notification time (5 minutes before task)
    var taskTime = tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
    var notifyTime = taskTime.subtract(Duration(minutes: reminderMinutesBefore));
    
    // If time has passed today, schedule for tomorrow
    if (notifyTime.isBefore(now)) {
      notifyTime = notifyTime.add(const Duration(days: 1));
      debugPrint('📆 Time passed, scheduled for tomorrow');
    }
    
    return notifyTime;
  }

  /// Track activity - ENHANCED VERSION with duration, completion %, ratings
  /// [trackingDate] allows overriding the tracking date (for end-of-day processing
  /// where missed tasks should be recorded under their actual date, not today)
  Future<void> trackActivity({
    required String activityName,
    required bool completed,
    required String scheduledTime,
    DateTime? actualTime,
    String? taskId,
    int? durationMinutes,
    int completionPercent = 100,
    int? difficultyRating,
    int? qualityRating,
    String? skipReason,
    String? notes,
    String? trackingDate, // Override date for end-of-day processing
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

      // Use provided tracking date or default to today
      final effectiveDate = trackingDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Calculate XP based on completion and difficulty
      int xpEarned = 0;
      if (completed) {
        xpEarned = 10; // Base XP
        if (difficultyRating != null) {
          xpEarned += difficultyRating * 2; // Bonus for harder tasks
        }
        if (completionPercent == 100) {
          xpEarned += 5; // Full completion bonus
        }
      }

      // Insert tracking record
      await client.from('routine_tracking').insert({
        'user_id': currentUser.id,
        'task_id': taskId,
        'activity_name': activityName,
        'scheduled_time': scheduledTime,
        'completed': completed,
        'completed_at': actualTime?.toIso8601String(),
        'actual_duration_minutes': durationMinutes,
        'completion_percent': completionPercent,
        'difficulty_rating': difficultyRating,
        'quality_rating': qualityRating,
        'skip_reason': skipReason,
        'notes': notes,
        'xp_earned': xpEarned,
        'tracking_date': effectiveDate,
      });

      // Update user stats ONLY if completed (not for missed/skipped)
      if (completed) {
        await _updateUserStats(
          userId: currentUser.id,
          durationMinutes: durationMinutes ?? 0,
          xpEarned: xpEarned,
        );
      }

      debugPrint('✅ Tracked: $activityName ($effectiveDate) - ${completed ? "Completed ($completionPercent%)" : "Missed"} +$xpEarned XP');
    } catch (e) {
      debugPrint('❌ Error tracking: $e');
    }
  }

  /// Update user stats (streak, total tasks, XP)
  Future<void> _updateUserStats({
    required String userId,
    required int durationMinutes,
    required int xpEarned,
  }) async {
    try {
      final client = await _supabase.client;
      if (client == null) return;

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      // Get current user stats
      final userStats = await client
          .from('user_profiles')
          .select('current_streak, best_streak, last_active_date, total_tasks_completed, total_minutes_tracked')
          .eq('id', userId)
          .single();

      int currentStreak = userStats['current_streak'] ?? 0;
      int bestStreak = userStats['best_streak'] ?? 0;
      String? lastActiveDate = userStats['last_active_date'];
      int totalCompleted = userStats['total_tasks_completed'] ?? 0;
      int totalMinutes = userStats['total_minutes_tracked'] ?? 0;

      // Calculate streak
      if (lastActiveDate != null) {
        final lastDate = DateTime.parse(lastActiveDate);
        final todayDate = DateTime.parse(today);
        final difference = todayDate.difference(lastDate).inDays;

        if (difference == 1) {
          // Consecutive day - increment streak
          currentStreak += 1;
        } else if (difference > 1) {
          // Streak broken - reset
          currentStreak = 1;
        }
        // If difference is 0, same day - don't change streak
      } else {
        // First ever activity
        currentStreak = 1;
      }

      // Update best streak if needed
      if (currentStreak > bestStreak) {
        bestStreak = currentStreak;
      }

      // Build update payload
      final updatePayload = <String, dynamic>{
        'current_streak': currentStreak,
        'best_streak': bestStreak,
        'last_active_date': today,
        'total_tasks_completed': totalCompleted + 1,
        'total_minutes_tracked': totalMinutes + durationMinutes,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Update user profile
      await client.from('user_profiles').update(updatePayload).eq('id', userId);

      debugPrint('🔥 Streak: $currentStreak days (Best: $bestStreak) | +${xpEarned}XP');
    } catch (e) {
      debugPrint('❌ Error updating user stats: $e');
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
