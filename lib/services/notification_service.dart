// lib/services/notification_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:timezone/timezone.dart' as tz;
import '../main.dart' show navigatorKey;
import '../routes/app_routes.dart';
import 'notification_deep_link_service.dart';

/// Top-level background handler for notifications received when app is killed.
/// MUST be a top-level function (not a method) and annotated with @pragma.
@pragma('vm:entry-point')
void _onBackgroundNotificationResponse(NotificationResponse response) {
  // This runs in a headless isolate — can't navigate directly.
  // Store the payload so it can be read when app starts.
  debugPrint('🔔 Background notification response: ${response.payload}');
  // The app will handle this via getNotificationAppLaunchDetails() on startup.
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // Store pending alarm payload (set from launch details check)
  String? _pendingAlarmPayload;
  String? get pendingAlarmPayload => _pendingAlarmPayload;
  void clearPendingAlarmPayload() => _pendingAlarmPayload = null;

  // Initialize notification service
  Future<void> initialize() async {
    try {
      // Skip notification initialization on web platform
      if (kIsWeb) {
        debugPrint(
            'Notification service: Skipping initialization on web platform');
        _isInitialized = true;
        return;
      }

      // Request notification permission
      await _requestPermission();

      // Initialize local notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
        // CRITICAL: Register background handler so alarm notifications
        // are processed even when app was killed
        onDidReceiveBackgroundNotificationResponse:
            _onBackgroundNotificationResponse,
      );

      _isInitialized = true;
      debugPrint('Notification service initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize notification service: $e');
    }
  }

  /// Check if the app was launched by tapping a notification.
  /// Call this AFTER initialize() and AFTER the navigator is ready.
  /// Returns true if a payload was found and should be navigated to.
  Future<bool> checkForAlarmLaunch() async {
    try {
      final launchDetails = await _flutterLocalNotificationsPlugin
          .getNotificationAppLaunchDetails();

      if (launchDetails == null || !launchDetails.didNotificationLaunchApp) {
        return false;
      }

      final response = launchDetails.notificationResponse;
      if (response == null || response.payload == null) return false;

      final payload = response.payload!;
      debugPrint('🚀 App launched from notification: $payload');

      // Check for alarm payload
      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        if (data['type'] == 'wakeup_alarm') {
          debugPrint('⏰ Cold-start alarm detected — storing payload for navigation');
          _pendingAlarmPayload = payload;
          return true;
        }
      } catch (_) {
        // Not JSON — check for task_id format
      }
      
      // Check for task notification payload (task_id:UUID)
      final deepLinkService = NotificationDeepLinkService();
      final taskId = deepLinkService.parseTaskIdFromPayload(payload);
      if (taskId != null) {
        debugPrint('📋 Cold-start task notification — setting pending highlight: $taskId');
        deepLinkService.setHighlightedTask(taskId);
        return false; // Don't treat as alarm — dashboard will handle the highlight
      }
    } catch (e) {
      debugPrint('Error checking launch notification: $e');
    }
    return false;
  }

  /// Navigate to alarm screen using pending payload.
  /// Call this after the navigator key is available (e.g., after first frame).
  void navigateToPendingAlarm() {
    if (_pendingAlarmPayload == null) return;
    
    final payload = _pendingAlarmPayload!;
    _pendingAlarmPayload = null;
    
    debugPrint('⏰ Navigating to AlarmRingScreen from pending payload');
    navigatorKey.currentState?.pushNamed(
      AppRoutes.alarmRing,
      arguments: payload,
    );
  }

  // Request notification permission
  Future<void> _requestPermission() async {
    if (Platform.isAndroid) {
      await Permission.notification.request();
    } else if (Platform.isIOS) {
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }

  /// UNIFIED notification tap handler — routes to correct handler based on payload.
  /// Handles BOTH alarm notifications AND task reminder notifications.
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    // Check for alarm (JSON format with type: "wakeup_alarm")
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      if (data['type'] == 'wakeup_alarm') {
        debugPrint('🔔 Alarm notification tapped — opening AlarmRingScreen');
        navigatorKey.currentState?.pushNamed(
          AppRoutes.alarmRing,
          arguments: payload,
        );
        return;
      }
    } catch (_) {
      // Not JSON — check for task payload below
    }

    // Check for task (format: "task_id:UUID")
    final deepLinkService = NotificationDeepLinkService();
    final taskId = deepLinkService.parseTaskIdFromPayload(payload);
    if (taskId != null) {
      debugPrint('📋 Task notification tapped — highlighting + navigating to task: $taskId');
      deepLinkService.setHighlightedTask(taskId);
      return;
    }
    
    debugPrint('⚠️ Unknown notification payload: $payload');
  }

  // Show instant notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) return;

    // Skip on web platform
    if (kIsWeb) {
      debugPrint(
          'Notification: $title - $body (Web platform - showing in console)');
      return;
    }

    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'dincharya_channel',
        'DinCharya Notifications',
        channelDescription: 'Notifications for DinCharya app',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: false,
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails();

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Failed to show notification: $e');
    }
  }

  // Schedule notification - Fixed androidScheduleMode parameter
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (!_isInitialized) return;

    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'dincharya_scheduled',
        'DinCharya Scheduled',
        channelDescription: 'Scheduled notifications for DinCharya app',
        importance: Importance.max,
        priority: Priority.high,
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails();

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Failed to schedule notification: $e');
    }
  }

  // Schedule daily routine reminder
  Future<void> scheduleRoutineReminder({
    required String routineName,
    required DateTime time,
  }) async {
    await scheduleNotification(
      title: 'Routine Reminder',
      body: 'Time for your $routineName routine!',
      scheduledDate: time,
      payload: 'routine_reminder',
    );
  }

  // Schedule meditation reminder
  Future<void> scheduleMeditationReminder({
    required DateTime time,
  }) async {
    await scheduleNotification(
      title: 'Meditation Time',
      body: 'Take a moment to meditate and find your inner peace.',
      scheduledDate: time,
      payload: 'meditation_reminder',
    );
  }

  // Schedule journal reminder
  Future<void> scheduleJournalReminder({
    required DateTime time,
  }) async {
    await scheduleNotification(
      title: 'Journal Time',
      body: 'Reflect on your day and write in your journal.',
      scheduledDate: time,
      payload: 'journal_reminder',
    );
  }

  // Show streak notification
  Future<void> showStreakNotification(int streakDays) async {
    await showNotification(
      title: 'Streak Achievement! 🔥',
      body: 'Amazing! You have completed $streakDays days in a row!',
      payload: 'streak_achievement',
    );
  }

  // Show weekly summary notification
  Future<void> showWeeklySummaryNotification() async {
    await showNotification(
      title: 'Weekly Summary',
      body: 'Check out your progress from this week!',
      payload: 'weekly_summary',
    );
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('Failed to cancel notifications: $e');
    }
  }

  // Cancel notification by id
  Future<void> cancelNotification(int id) async {
    try {
      await _flutterLocalNotificationsPlugin.cancel(id);
    } catch (e) {
      debugPrint('Failed to cancel notification: $e');
    }
  }

  // Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _flutterLocalNotificationsPlugin
          .pendingNotificationRequests();
    } catch (e) {
      debugPrint('Failed to get pending notifications: $e');
      return [];
    }
  }

  // Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    try {
      if (Platform.isAndroid) {
        return await Permission.notification.isGranted;
      } else if (Platform.isIOS) {
        final result = await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.checkPermissions();
        return result?.isEnabled ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('Failed to check notification permission: $e');
      return false;
    }
  }
}
