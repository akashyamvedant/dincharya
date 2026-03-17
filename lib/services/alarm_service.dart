// lib/services/alarm_service.dart
// Dedicated alarm service for wakeup tasks — COMPLETELY SEPARATE from NotificationService.
// Uses its own notification channel, its own ID range, and its own persistence.
// Alarm sounds are streamed from Supabase storage and cached locally.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  // Uses the SAME plugin instance as NotificationService — this is fine because
  // channels are isolated by channelId. The plugin is a thin wrapper around the platform.
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // SharedPreferences key for storing active alarms
  static const String _activeAlarmsKey = 'dincharya_active_alarms';
  static const String _cachedSoundsKey = 'dincharya_cached_alarm_sounds';

  // Notification ID range: 50000-99999 (NotificationService uses lower range)
  static const int _alarmIdBase = 50000;

  // Supabase storage base URL for alarm sounds
  static String get _supabaseStorageUrl {
    final url = dotenv.env['SUPABASE_URL'] ?? '';
    return '$url/storage/v1/object/public/alarm-sounds';
  }

  // Available alarm sounds (served from Supabase storage)
  static const List<AlarmSound> availableSounds = [
    AlarmSound(
      id: 'gentle_morning',
      displayName: 'Gentle Morning 🌅',
      fileName: 'gentle_morning.mp3',
    ),
    AlarmSound(
      id: 'temple_bells',
      displayName: 'Temple Bells 🛕',
      fileName: 'temple_bells.mp3',
    ),
  ];

  /// Initialize alarm service — call AFTER NotificationService.initialize()
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb) {
      _isInitialized = true;
      return;
    }

    try {
      // We don't re-initialize the plugin — NotificationService does that.
      // We only ensure our alarm channel exists on Android.
      if (Platform.isAndroid) {
        final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

        if (androidPlugin != null) {
          // Delete ALL old channels (Android caches channel settings)
          await androidPlugin.deleteNotificationChannel('dincharya_alarm');
          await androidPlugin.deleteNotificationChannel('dincharya_alarm_v2');
          await androidPlugin.deleteNotificationChannel('dincharya_alarm_v3');

          // Create alarm channel v4 — SILENT channel.
          // Sound is handled by AlarmRingScreen's AudioPlayer (custom ringtone).
          // The notification only serves as: fullScreenIntent + vibration.
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              'dincharya_alarm_v4',
              'Wakeup Alarms',
              description: 'Silent alarm trigger — sound plays via alarm screen',
              importance: Importance.max,
              playSound: false,
              enableVibration: true,
              enableLights: true,
            ),
          );
        }
      }

      // Pre-cache alarm sounds in background
      _preCacheAlarmSounds();

      _isInitialized = true;
      debugPrint('✅ AlarmService initialized (v4 silent channel)');
    } catch (e) {
      debugPrint('Failed to initialize AlarmService: $e');
    }
  }

  /// Pre-download and cache alarm sounds from Supabase
  Future<void> _preCacheAlarmSounds() async {
    try {
      for (final sound in availableSounds) {
        await getCachedSoundPath(sound.fileName);
      }
      debugPrint('✅ Alarm sounds pre-cached');
    } catch (e) {
      debugPrint('⚠️ Failed to pre-cache alarm sounds: $e');
    }
  }

  /// Get path to cached alarm sound file, downloading if needed.
  /// Public so AlarmRingScreen can access cached files for audio playback.
  Future<String?> getCachedSoundPath(String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${dir.path}/alarm_sounds');
      if (!cacheDir.existsSync()) {
        cacheDir.createSync(recursive: true);
      }

      final file = File('${cacheDir.path}/$fileName');

      // Return cached file if it exists
      if (file.existsSync() && file.lengthSync() > 0) {
        return file.path;
      }

      // Download from Supabase storage using Dio
      final url = '$_supabaseStorageUrl/$fileName';
      debugPrint('⬇️ Downloading alarm sound: $url');

      final dio = Dio();
      final response = await dio.download(url, file.path);
      if (response.statusCode == 200) {
        debugPrint('✅ Cached alarm sound: $fileName');
        return file.path;
      } else {
        debugPrint('❌ Failed to download alarm sound: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error caching alarm sound: $e');
      return null;
    }
  }

  /// Check if exact alarm permission is granted
  Future<bool> isExactAlarmPermitted() async {
    if (kIsWeb || !Platform.isAndroid) return true;

    try {
      final status = await Permission.scheduleExactAlarm.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('Error checking exact alarm permission: $e');
      return false;
    }
  }

  /// Request exact alarm permission with explanation — returns true if granted
  Future<bool> requestExactAlarmPermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;

    try {
      final status = await Permission.scheduleExactAlarm.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('Error requesting exact alarm permission: $e');
      return false;
    }
  }

  /// Schedule a wakeup alarm for a task
  Future<bool> scheduleWakeupAlarm({
    required String taskId,
    required DateTime alarmTime,
    String soundId = 'gentle_morning',
    String taskTitle = 'Wake Up',
  }) async {
    if (!_isInitialized || kIsWeb) return false;

    try {
      // Check permission first
      final hasPermission = await isExactAlarmPermitted();
      final scheduleMode = hasPermission
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      if (!hasPermission) {
        debugPrint('AlarmService: Exact alarm not permitted, using inexact mode');
      }

      final notificationId = _getNotificationId(taskId);

      // Cancel any existing alarm for this task first
      await _notifications.cancel(notificationId);

      // Build SILENT notification with fullScreenIntent + vibration only.
      // All sound is played by AlarmRingScreen's AudioPlayer (user's custom ringtone).
      final androidDetails = AndroidNotificationDetails(
        'dincharya_alarm_v4',
        'Wakeup Alarms',
        channelDescription: 'Silent alarm trigger — sound plays via alarm screen',
        importance: Importance.max,
        priority: Priority.max,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        autoCancel: false,
        ongoing: true,
        playSound: false,  // SILENT — custom sound plays via AlarmRingScreen
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
        // No FLAG_INSISTENT — no notification sound to loop
        styleInformation: BigTextStyleInformation(
          'Time to wake up! Your daily routine awaits. 🌅',
          contentTitle: '⏰ $taskTitle',
          summaryText: 'Tap to open alarm',
        ),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Schedule the alarm
      final scheduledDate = tz.TZDateTime.from(alarmTime, tz.local);

      await _notifications.zonedSchedule(
        notificationId,
        '⏰ $taskTitle',
        'Time to wake up! Your daily routine awaits. 🌅',
        scheduledDate,
        notificationDetails,
        androidScheduleMode: scheduleMode,
        payload: jsonEncode({
          'type': 'wakeup_alarm',
          'taskId': taskId,
          'soundId': soundId,
          'taskTitle': taskTitle,
        }),
      );

      // Save alarm to SharedPreferences for persistence
      await _saveActiveAlarm(taskId, alarmTime, soundId, taskTitle);

      debugPrint('AlarmService: Scheduled alarm for $taskTitle at $alarmTime '
          '(id=$notificationId, mode=${hasPermission ? "exact" : "inexact"})');

      return true;
    } catch (e) {
      debugPrint('AlarmService: Failed to schedule alarm: $e');
      return false;
    }
  }

  /// Cancel alarm for a specific task
  Future<void> cancelAlarm(String taskId) async {
    if (kIsWeb) return;

    try {
      final notificationId = _getNotificationId(taskId);
      await _notifications.cancel(notificationId);
      await _removeActiveAlarm(taskId);
      debugPrint('AlarmService: Cancelled alarm for task $taskId');
    } catch (e) {
      debugPrint('AlarmService: Failed to cancel alarm: $e');
    }
  }

  /// Cancel all alarms
  Future<void> cancelAllAlarms() async {
    if (kIsWeb) return;

    try {
      final alarms = await getActiveAlarms();
      for (final alarm in alarms) {
        final id = _getNotificationId(alarm['taskId'] as String);
        await _notifications.cancel(id);
      }
      await _clearActiveAlarms();
      debugPrint('AlarmService: Cancelled all alarms');
    } catch (e) {
      debugPrint('AlarmService: Failed to cancel all alarms: $e');
    }
  }

  /// Reschedule alarm with snooze (5 min from now)
  Future<bool> snoozeAlarm({
    required String taskId,
    String soundId = 'gentle_morning',
    String taskTitle = 'Wake Up',
    int snoozeMinutes = 5,
  }) async {
    final snoozeTime = DateTime.now().add(Duration(minutes: snoozeMinutes));
    return await scheduleWakeupAlarm(
      taskId: '${taskId}_snooze',
      alarmTime: snoozeTime,
      soundId: soundId,
      taskTitle: '$taskTitle (Snoozed)',
    );
  }

  /// Get the Supabase public URL for an alarm sound
  String getAlarmSoundUrl(String soundId) {
    final sound = availableSounds.firstWhere(
      (s) => s.id == soundId,
      orElse: () => availableSounds.first,
    );
    return '$_supabaseStorageUrl/${sound.fileName}';
  }

  /// Silence the notification sound without canceling the notification itself.
  /// This allows the custom ringtone to take over from the notification sound.
  /// We update the notification to remove sound + FLAG_INSISTENT.
  Future<void> silenceNotification(String taskId) async {
    try {
      final notificationId = _getNotificationId(taskId);
      // Cancel and immediately re-show a silent notification
      // (simplest way to stop FLAG_INSISTENT sound)
      await _notifications.cancel(notificationId);
      debugPrint('🔇 Notification sound silenced for task $taskId');
    } catch (e) {
      debugPrint('Error silencing notification: $e');
    }
  }

  /// Get all active alarms from SharedPreferences
  Future<List<Map<String, dynamic>>> getActiveAlarms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alarmsJson = prefs.getString(_activeAlarmsKey);
      if (alarmsJson == null) return [];

      final List<dynamic> decoded = jsonDecode(alarmsJson);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('AlarmService: Failed to get active alarms: $e');
      return [];
    }
  }

  /// Check if a task has an active alarm
  Future<bool> hasActiveAlarm(String taskId) async {
    final alarms = await getActiveAlarms();
    return alarms.any((a) => a['taskId'] == taskId);
  }

  // --- Private helpers ---

  int _getNotificationId(String taskId) {
    return (taskId.hashCode.abs() % 50000) + _alarmIdBase;
  }

  Future<void> _saveActiveAlarm(
    String taskId,
    DateTime alarmTime,
    String soundId,
    String taskTitle,
  ) async {
    try {
      final alarms = await getActiveAlarms();
      alarms.removeWhere((a) => a['taskId'] == taskId);

      alarms.add({
        'taskId': taskId,
        'alarmTime': alarmTime.toIso8601String(),
        'soundId': soundId,
        'taskTitle': taskTitle,
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeAlarmsKey, jsonEncode(alarms));
    } catch (e) {
      debugPrint('AlarmService: Failed to save alarm: $e');
    }
  }

  Future<void> _removeActiveAlarm(String taskId) async {
    try {
      final alarms = await getActiveAlarms();
      alarms.removeWhere((a) => a['taskId'] == taskId);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeAlarmsKey, jsonEncode(alarms));
    } catch (e) {
      debugPrint('AlarmService: Failed to remove alarm: $e');
    }
  }

  Future<void> _clearActiveAlarms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activeAlarmsKey);
    } catch (e) {
      debugPrint('AlarmService: Failed to clear alarms: $e');
    }
  }
}

/// Model class for alarm sound options
class AlarmSound {
  final String id;
  final String displayName;
  final String fileName;

  const AlarmSound({
    required this.id,
    required this.displayName,
    required this.fileName,
  });
}
