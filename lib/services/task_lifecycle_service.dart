import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';
import 'routine_tracking_service.dart';

/// Task Status States
class TaskStatus {
  static const String pending = 'pending';    // Task not yet due
  static const String active = 'active';      // Task is due now
  static const String overdue = 'overdue';    // Time passed, not confirmed
  static const String completed = 'completed'; // User confirmed done
  static const String missed = 'missed';      // Day ended, not confirmed
  static const String skipped = 'skipped';    // User intentionally skipped
}

/// Smart Task Lifecycle Service
/// Handles: Status transitions, day change detection, auto-miss logic
class TaskLifecycleService {
  final SupabaseService _supabase = SupabaseService();
  final RoutineTrackingService _trackingService = RoutineTrackingService();
  
  static const String _lastActiveDateKey = 'last_active_date';
  
  /// Guard against concurrent calls (e.g., rapid app resume)
  static bool _isProcessing = false;
  
  /// Check if day changed and process accordingly
  /// Call this on app open / routine dashboard load
  /// Handles multi-day gaps (e.g., app backgrounded Sat → Mon)
  Future<bool> checkAndProcessDayChange() async {
    // Concurrency guard: prevent double-processing
    if (_isProcessing) {
      debugPrint('⚠️ [RESET] Day change check already in progress — skipping');
      return false;
    }
    _isProcessing = true;
    
    try {
      debugPrint('🔄 [RESET] Starting day change check at ${DateTime.now()}');
      
      // CRITICAL: Use getAuthenticatedUser() NOT currentUser(?).id
      // supabase_flutter v2 restores sessions ASYNCHRONOUSLY after
      // Supabase.initialize() — currentUser is NULL on cold start for
      // up to several seconds. getAuthenticatedUser() waits for the
      // INITIAL_SESSION event before returning.
      final user = await _supabase.getAuthenticatedUser();
      
      if (user == null) {
        debugPrint('⚠️ [RESET] FAILED: user not authenticated (session not restored yet)');
        return false;
      }
      
      final userId = user.id;
      debugPrint('✅ [RESET] User authenticated: ${userId.substring(0, 8)}...');
      
      final prefs = await SharedPreferences.getInstance();
      final lastActiveDate = prefs.getString(_lastActiveDateKey);
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      debugPrint('📋 [RESET] last_active_date=$lastActiveDate, today=$today');
      
      if (lastActiveDate != null && lastActiveDate != today) {
        // Calculate how many days were missed
        final lastDate = DateTime.parse(lastActiveDate);
        final todayDate = DateTime.parse(today);
        final daysMissed = todayDate.difference(lastDate).inDays;
        
        debugPrint('📅 [RESET] Day changed! $lastActiveDate → $today ($daysMissed day(s) gap)');
        
        // Process each missed day individually
        // This ensures multi-day gaps (e.g. Sat→Mon) don't skip intermediate days
        bool allSucceeded = true;
        for (int i = 0; i < daysMissed; i++) {
          final dateToProcess = lastDate.add(Duration(days: i));
          final dateStr = DateFormat('yyyy-MM-dd').format(dateToProcess);
          debugPrint('📋 [RESET] Processing missed day: $dateStr (${i + 1}/$daysMissed)');
          final success = await _processEndOfDay(dateStr);
          if (!success) {
            debugPrint('❌ [RESET] FAILED to process day: $dateStr — will retry next time');
            allSucceeded = false;
            break; // Stop processing, don't update last_active_date
          }
        }
        
        // CRITICAL FIX: Only update last_active_date AFTER confirmed reset success
        // Previously this was updated BEFORE confirming, causing permanent skip on failure
        if (allSucceeded) {
          await prefs.setString(_lastActiveDateKey, today);
          debugPrint('✅ [RESET] last_active_date updated to $today (all days processed)');
          return true; // Day changed and processed successfully
        } else {
          debugPrint('⚠️ [RESET] last_active_date NOT updated (processing failed, will retry)');
          return false;
        }
      } else if (lastActiveDate == null) {
        // First time opening app
        debugPrint('📋 [RESET] First time opening app, setting last_active_date=$today');
        await prefs.setString(_lastActiveDateKey, today);
      } else {
        debugPrint('📋 [RESET] No day change (same day: $today)');
      }
      
      return false; // No day change
    } catch (e, stackTrace) {
      debugPrint('❌ [RESET] EXCEPTION in day change check: $e');
      debugPrint('❌ [RESET] Stack: ${stackTrace.toString().split('\n').take(5).join('\n')}');
      return false;
    } finally {
      _isProcessing = false;
      debugPrint('🔄 [RESET] Day change check finished, lock released');
    }
  }
  
  /// Helper to check is_completed regardless of type (int or bool)
  static bool _isTaskCompleted(dynamic value) {
    return value == 1 || value == true;
  }

  /// Process end of day - reset ACTIVE PROFILE tasks, then track missed ones
  /// Returns true if processing was successful, false otherwise
  Future<bool> _processEndOfDay(String date) async {
    try {
      debugPrint('🔄 [EOD] Starting end-of-day processing for: $date');
      
      // CRITICAL: Use getAuthenticatedUser() to properly wait for session
      // restoration on cold start (supabase_flutter v2 async session issue)
      final client = await _supabase.client;
      if (client == null) {
        debugPrint('❌ [EOD] FAILED: Supabase client is null');
        return false;
      }
      debugPrint('✅ [EOD] Supabase client ready');
      
      final user = await _supabase.getAuthenticatedUser();
      if (user == null) {
        debugPrint('❌ [EOD] FAILED: user not authenticated');
        return false;
      }
      final userId = user.id;
      debugPrint('✅ [EOD] User: ${userId.substring(0, 8)}...');

      // Get user's active lifestyle profile
      final profileData = await client
          .from('user_profiles')
          .select('lifestyle_profile')
          .eq('id', userId)
          .maybeSingle();
      final activeProfile = profileData?['lifestyle_profile'] ?? 'custom';
      debugPrint('📋 [EOD] Active profile: $activeProfile');
      
      // STEP 1: Get ALL tasks BEFORE resetting (we need current state for tracking)
      final allTasks = await client
          .from('local_tasks')
          .select('id, title, time, task_status, is_completed, profile_source')
          .eq('user_id', userId);

      // Filter to only active profile + custom tasks
      final activeTasks = allTasks.where((task) {
        final source = task['profile_source']?.toString() ?? 'custom';
        if (activeProfile == 'custom') return source == 'custom';
        return source == activeProfile || source == 'custom';
      }).toList();
      
      debugPrint('📋 [EOD] Found ${activeTasks.length} active tasks (of ${allTasks.length} total)');
      
      // Log each task's current state for debugging
      for (final task in activeTasks) {
        debugPrint('   📌 [EOD] Task: "${task['title']}" status=${task['task_status']} completed=${task['is_completed']} time=${task['time']}');
      }

      // STEP 2: RESET only ACTIVE PROFILE TASKS
      final activeIds = activeTasks.map((t) => t['id']).toList();
      if (activeIds.isNotEmpty) {
        debugPrint('🔄 [EOD] Resetting ${activeIds.length} tasks to pending...');
        await client.from('local_tasks').update({
          'task_status': TaskStatus.pending,
          'is_completed': false,
          'status_updated_at': DateTime.now().toIso8601String(),
        }).eq('user_id', userId).inFilter('id', activeIds);
        debugPrint('✅ [EOD] Reset ${activeTasks.length} tasks to pending for new day');
      } else {
        debugPrint('⚠️ [EOD] No active tasks found to reset');
      }
      
      // STEP 3: Verify reset actually worked by reading back from DB
      if (activeIds.isNotEmpty) {
        final verifyTasks = await client
            .from('local_tasks')
            .select('id, title, task_status, is_completed')
            .eq('user_id', userId)
            .inFilter('id', activeIds);
        
        int stillCompleted = 0;
        for (final t in verifyTasks) {
          if (_isTaskCompleted(t['is_completed']) || t['task_status'] == 'completed') {
            stillCompleted++;
            debugPrint('❌ [EOD] VERIFICATION FAIL: "${t['title']}" still completed after reset!');
          }
        }
        if (stillCompleted > 0) {
          debugPrint('❌ [EOD] $stillCompleted tasks STILL completed after reset — DB update may have failed!');
          return false;
        }
        debugPrint('✅ [EOD] Verification passed: all ${verifyTasks.length} tasks are pending');
      }
      
      // STEP 4: Track uncompleted active tasks as missed
      for (final task in activeTasks) {
        try {
          final status = task['task_status'] ?? 'pending';
          final isCompleted = _isTaskCompleted(task['is_completed']);
          
          // Only track as missed if NOT completed and NOT skipped
          if (!isCompleted && status != 'completed' && status != 'skipped') {
            await _trackingService.trackActivity(
              activityName: task['title'] ?? 'Task',
              scheduledTime: task['time'] ?? '12:00 AM',
              completed: false,
              taskId: task['id'],
              skipReason: 'auto_missed_end_of_day',
              notes: 'Automatically marked as missed at end of day ($date)',
              trackingDate: date, // Use the actual date, NOT DateTime.now()
            );
            debugPrint('📝 [EOD] Tracked missed: ${task['title']}');
          } else {
            debugPrint('📝 [EOD] Skipping tracking for completed/skipped: ${task['title']} (status=$status)');
          }
        } catch (trackError) {
          debugPrint('⚠️ [EOD] Failed to track ${task['title']}: $trackError');
          // Don't fail the entire reset for a tracking error
        }
      }
      
      debugPrint('✅ [EOD] End of day processing COMPLETE for $date');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ [EOD] EXCEPTION processing end of day ($date): $e');
      debugPrint('❌ [EOD] Stack: ${stackTrace.toString().split('\n').take(5).join('\n')}');
      return false;
    }
  }
  
  /// Update task statuses based on current time
  /// Call this periodically or on dashboard refresh
  Future<void> updateTaskStatuses(List<Map<String, dynamic>> tasks) async {
    try {
      final client = await _supabase.client;
      if (client == null) return;
      
      final now = DateTime.now();
      final currentMinutes = now.hour * 60 + now.minute;
      
      // Sort tasks by time to calculate deadlines
      tasks.sort((a, b) {
        final timeA = _parseTimeToMinutes(a['time'] ?? '12:00 AM');
        final timeB = _parseTimeToMinutes(b['time'] ?? '12:00 AM');
        return timeA.compareTo(timeB);
      });
      
      for (int i = 0; i < tasks.length; i++) {
        final task = tasks[i];
        final currentStatus = task['task_status'] ?? TaskStatus.pending;
        
        // Skip already completed/missed/skipped tasks
        if (currentStatus == TaskStatus.completed ||
            currentStatus == TaskStatus.missed ||
            currentStatus == TaskStatus.skipped) {
          continue;
        }
        
        final taskMinutes = _parseTimeToMinutes(task['time'] ?? '12:00 AM');
        
        // NEVER change status of already completed tasks (check both int and bool)
        if (_isTaskCompleted(task['is_completed']) || currentStatus == TaskStatus.completed) {
          if (currentStatus != TaskStatus.completed) {
            // Sync task_status with is_completed if out of sync
            await client.from('local_tasks').update({
              'task_status': TaskStatus.completed,
              'status_updated_at': DateTime.now().toIso8601String(),
            }).eq('id', task['id']);
            debugPrint('🔄 Synced ${task['title']} to completed status');
          }
          continue; // Skip to next task
        }
        
        // Calculate deadline (next task's time, or grace period for last task)
        int deadlineMinutes;
        if (i < tasks.length - 1) {
          deadlineMinutes = _parseTimeToMinutes(tasks[i + 1]['time'] ?? '23:59');
        } else {
          // Last task of day: give 60 minutes grace period instead of 11:59 PM
          deadlineMinutes = taskMinutes + 60;
          if (deadlineMinutes > 23 * 60 + 59) {
            deadlineMinutes = 23 * 60 + 59;
          }
        }
        
        String newStatus;
        
        if (currentMinutes < taskMinutes - 10) {
          // More than 10 min before task time - pending
          newStatus = TaskStatus.pending;
        } else if (currentMinutes >= taskMinutes - 10 && currentMinutes < deadlineMinutes) {
          // Within completion window (10 min before to deadline) - active/completable
          if (currentMinutes < taskMinutes) {
            newStatus = TaskStatus.active; // Early unlock window
          } else {
            newStatus = TaskStatus.overdue; // Past scheduled time but still completable
          }
        } else {
          // Past deadline (with grace period) - missed
          newStatus = TaskStatus.missed;
        }
        
        // Update if status changed
        if (newStatus != currentStatus) {
          await client.from('local_tasks').update({
            'task_status': newStatus,
            'status_updated_at': DateTime.now().toIso8601String(),
            'deadline_time': _minutesToTimeString(deadlineMinutes),
          }).eq('id', task['id']);
          
          debugPrint('📝 ${task['title']}: $currentStatus → $newStatus');
        }
      }
    } catch (e) {
      debugPrint('❌ Error updating task statuses: $e');
    }
  }
  
  /// Mark task as completed
  Future<void> completeTask(String taskId, String taskName, String scheduledTime) async {
    try {
      final client = await _supabase.client;
      if (client == null) return;
      
      await client.from('local_tasks').update({
        'task_status': TaskStatus.completed,
        'is_completed': true,
        'status_updated_at': DateTime.now().toIso8601String(),
      }).eq('id', taskId);
      
      // Track in history
      await _trackingService.trackActivity(
        activityName: taskName,
        scheduledTime: scheduledTime,
        completed: true,
        taskId: taskId,
        actualTime: DateTime.now(),
      );
      
      debugPrint('✅ Task completed: $taskName');
    } catch (e) {
      debugPrint('❌ Error completing task: $e');
    }
  }
  
  /// Mark task as skipped
  Future<void> skipTask(String taskId, String taskName, String scheduledTime, String reason) async {
    try {
      final client = await _supabase.client;
      if (client == null) return;
      
      await client.from('local_tasks').update({
        'task_status': TaskStatus.skipped,
        'is_completed': false,
        'status_updated_at': DateTime.now().toIso8601String(),
      }).eq('id', taskId);
      
      // Track in history
      await _trackingService.trackActivity(
        activityName: taskName,
        scheduledTime: scheduledTime,
        completed: false,
        taskId: taskId,
        skipReason: reason,
      );
      
      debugPrint('⏭️ Task skipped: $taskName ($reason)');
    } catch (e) {
      debugPrint('❌ Error skipping task: $e');
    }
  }
  
  /// Check if task is within valid completion window
  /// Rules:
  /// - Task unlocks 10 minutes BEFORE scheduled time
  /// - Task locks when next task's time arrives (or 11:59 PM for last task)
  /// - Already completed tasks return false
  static bool isTaskCompletable({
    required String taskTime,
    required bool isCompleted,
    String? nextTaskTime,
    int unlockMinutesBefore = 10,
  }) {
    if (isCompleted) return false;
    
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    
    // Parse task scheduled time
    final taskMinutes = _parseTimeToMinutesStatic(taskTime);
    
    // Calculate unlock time (10 min before scheduled time)
    final unlockMinutes = taskMinutes - unlockMinutesBefore;
    
    // Calculate deadline (next task's time, or grace period for last task)
    int deadlineMinutes;
    if (nextTaskTime != null && nextTaskTime.isNotEmpty) {
      deadlineMinutes = _parseTimeToMinutesStatic(nextTaskTime);
    } else {
      // Last task: 60 min grace period
      deadlineMinutes = taskMinutes + 60;
      if (deadlineMinutes > 23 * 60 + 59) {
        deadlineMinutes = 23 * 60 + 59;
      }
    }
    
    // Check if current time is within completion window
    final isAfterUnlock = currentMinutes >= unlockMinutes;
    final isBeforeDeadline = currentMinutes < deadlineMinutes;
    
    debugPrint('🔐 Task $taskTime: unlock=${_minutesToTimeStatic(unlockMinutes)}, '
        'deadline=${_minutesToTimeStatic(deadlineMinutes)}, '
        'now=${_minutesToTimeStatic(currentMinutes)}, '
        'canComplete=${isAfterUnlock && isBeforeDeadline}');
    
    return isAfterUnlock && isBeforeDeadline;
  }
  
  /// Get reason why task cannot be completed
  static String getCompletionBlockReason({
    required String taskTime,
    required bool isCompleted,
    String? nextTaskTime,
  }) {
    if (isCompleted) return 'Already completed';
    
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final taskMinutes = _parseTimeToMinutesStatic(taskTime);
    final unlockMinutes = taskMinutes - 10;
    
    if (currentMinutes < unlockMinutes) {
      final waitMinutes = unlockMinutes - currentMinutes;
      if (waitMinutes < 60) {
        return '$waitMinutes min में unlock होगा';
      } else {
        final hours = waitMinutes ~/ 60;
        final mins = waitMinutes % 60;
        return '${hours}h ${mins}m में unlock';
      }
    }
    
    // Calculate deadline (next task's time, or grace period for last task)
    int deadlineMinutes;
    if (nextTaskTime != null && nextTaskTime.isNotEmpty) {
      deadlineMinutes = _parseTimeToMinutesStatic(nextTaskTime);
    } else {
      // Last task: 60 min grace period
      deadlineMinutes = taskMinutes + 60;
      if (deadlineMinutes > 23 * 60 + 59) {
        deadlineMinutes = 23 * 60 + 59;
      }
    }
    
    if (currentMinutes >= deadlineMinutes) {
      return 'Window closed';
    }
    
    return '';
  }
  
  // Static helper for parsing time (for use in static methods)
  static int _parseTimeToMinutesStatic(String time) {
    try {
      final parts = time.split(' ');
      final timeParts = parts[0].split(':');
      int hours = int.parse(timeParts[0]);
      final int minutes = int.parse(timeParts[1]);
      
      if (parts.length > 1) {
        final period = parts[1].toUpperCase();
        if (period == 'PM' && hours != 12) hours += 12;
        if (period == 'AM' && hours == 12) hours = 0;
      }
      
      return hours * 60 + minutes;
    } catch (e) {
      return 0;
    }
  }
  
  // Static helper for formatting minutes to time
  static String _minutesToTimeStatic(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    final period = hours >= 12 ? 'PM' : 'AM';
    final displayHours = hours > 12 ? hours - 12 : (hours == 0 ? 12 : hours);
    return '${displayHours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')} $period';
  }
  
  /// Get status color for UI
  static Color getStatusColor(String status) {
    switch (status) {
      case TaskStatus.pending:
        return Colors.grey;
      case TaskStatus.active:
        return Colors.blue;
      case TaskStatus.overdue:
        return Colors.orange;
      case TaskStatus.completed:
        return Colors.green;
      case TaskStatus.missed:
        return Colors.red;
      case TaskStatus.skipped:
        return Colors.grey.shade600;
      default:
        return Colors.grey;
    }
  }
  
  /// Get status icon for UI
  static IconData getStatusIcon(String status) {
    switch (status) {
      case TaskStatus.pending:
        return Icons.schedule;
      case TaskStatus.active:
        return Icons.play_circle_outline;
      case TaskStatus.overdue:
        return Icons.warning_amber;
      case TaskStatus.completed:
        return Icons.check_circle;
      case TaskStatus.missed:
        return Icons.cancel;
      case TaskStatus.skipped:
        return Icons.skip_next;
      default:
        return Icons.help_outline;
    }
  }
  
  /// Get status label in Hindi
  static String getStatusLabel(String status) {
    switch (status) {
      case TaskStatus.pending:
        return 'अभी करना है';
      case TaskStatus.active:
        return 'अभी का time';
      case TaskStatus.overdue:
        return 'Time निकल गया';
      case TaskStatus.completed:
        return 'पूरा हुआ';
      case TaskStatus.missed:
        return 'छूट गया';
      case TaskStatus.skipped:
        return 'Skip किया';
      default:
        return status;
    }
  }
  
  // Helper: Parse time string to minutes
  int _parseTimeToMinutes(String time) {
    try {
      final parts = time.split(' ');
      final timeParts = parts[0].split(':');
      int hours = int.parse(timeParts[0]);
      final int minutes = int.parse(timeParts[1]);
      
      if (parts.length > 1) {
        final period = parts[1].toUpperCase();
        if (period == 'PM' && hours != 12) hours += 12;
        if (period == 'AM' && hours == 12) hours = 0;
      }
      
      return hours * 60 + minutes;
    } catch (e) {
      return 0;
    }
  }
  
  // Helper: Convert minutes to time string
  String _minutesToTimeString(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    final period = hours >= 12 ? 'PM' : 'AM';
    final displayHours = hours > 12 ? hours - 12 : (hours == 0 ? 12 : hours);
    return '${displayHours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')} $period';
  }
}
