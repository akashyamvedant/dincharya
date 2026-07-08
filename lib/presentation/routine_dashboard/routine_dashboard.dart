import 'package:flutter/material.dart';
import '../admin_messages/admin_message_popup.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import 'package:uuid/uuid.dart'; // For generating unique IDs

import '../../main.dart' show dayChangeNotifier;
import '../../core/app_export.dart';
import '../../core/constants/ad_constants.dart';
import '../../models/task_categories.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../../services/routine_tracking_service.dart';
import '../../services/task_lifecycle_service.dart';
import '../../services/ads_service.dart';
import '../../services/alarm_service.dart';
import '../../services/notification_deep_link_service.dart';
import '../../services/app_update_service.dart';
import '../../services/app_tour_service.dart';
import './widgets/add_task_bottom_sheet.dart';
import './widgets/edit_task_bottom_sheet.dart';
import './widgets/empty_routine_widget.dart';
import './widgets/missed_task_feedback_dialog.dart';
import './widgets/routine_header_widget.dart';
import './widgets/task_card_widget.dart';
import './widgets/activity_tracking_dialog.dart';
import './widgets/celebration_overlay.dart';
import './widgets/quick_tasks_section.dart';
import '../../widgets/ads/native_ad_widget.dart';
import '../../widgets/ads/banner_ad_widget.dart';
import '../../widgets/premium_paywall_widget.dart';
import '../../services/subscription_manager.dart';


class RoutineDashboard extends StatefulWidget {
  const RoutineDashboard({super.key});

  @override
  State<RoutineDashboard> createState() => _RoutineDashboardState();
}

class _RoutineDashboardState extends State<RoutineDashboard>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _currentTabIndex = 0;
  bool _isLoading = false;
  int _streakCount = 0; // Dynamic streak count
  int _bestStreak = 0; // Personal best streak
  int _totalXP = 0; // Total XP earned
  double _weeklyCompletion = 0.0; // Weekly completion rate
  List<bool> _weeklyDays = [false, false, false, false, false, false, false];
  bool _showCelebration = false;
  int _celebrationXP = 25;
  String _celebrationTaskName = '';
  String _selectedCategory = 'all'; // For category filter
  
  // Category definitions for filter chips
  final List<Map<String, String>> _categories = [
    {'key': 'all', 'label': 'All', 'icon': '📋'},
    {'key': 'meditation', 'label': 'Meditation', 'icon': '🧘'},
    {'key': 'yoga', 'label': 'Yoga', 'icon': '🧎'},
    {'key': 'pranayama', 'label': 'Pranayama', 'icon': '💨'},
    {'key': 'study', 'label': 'Study', 'icon': '📚'},
    {'key': 'journal', 'label': 'Journal', 'icon': '📝'},
    {'key': 'exercise', 'label': 'Exercise', 'icon': '💪'},
  ];

  List<Map<String, dynamic>> _todayTasks = [];
  final SupabaseService _supabaseService = SupabaseService();
  final RoutineTrackingService _trackingService = RoutineTrackingService();
  final TaskLifecycleService _lifecycleService = TaskLifecycleService();
  final NotificationDeepLinkService _deepLinkService = NotificationDeepLinkService();
  final Uuid _uuid = Uuid();
  
  // Currently highlighted task ID (from notification tap)
  String? _highlightedTaskId;
  
  // ScrollController for main content to enable scroll-to-task
  final ScrollController _scrollController = ScrollController();
  
  // Map of task IDs to GlobalKeys for scrolling
  final Map<String, GlobalKey> _taskKeys = {};
  
  // GlobalKeys for app tour
  final GlobalKey _progressSummaryKey = GlobalKey();
  final GlobalKey _addTaskFabKey = GlobalKey();
  final GlobalKey _bottomNavKey = GlobalKey();
  final AppTourService _appTourService = AppTourService();

  // In-App Update
  final AppUpdateService _appUpdateService = AppUpdateService();
  bool _updateAvailable = false;
  bool _flexibleUpdateDownloaded = false;

  final List<String> _tabLabels = ['Routine', 'Guided', 'Tapasya', 'Journal', 'Me'];


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeTracking();
    _initializeLifecycle();
    _initializeDeepLinkListener();
    _checkForAppUpdate();
    
    // Layer 4: Listen for app-level day change notifications
    dayChangeNotifier.addListener(_onGlobalDayChange);
    
    // Listen for tab navigation requests from notification taps
    _deepLinkService.navigateToRoutineTab.addListener(_onNavigateToRoutineTab);
    
    // Check for admin in-app messages and premium offer after UI is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAdminMessages();
      _checkPremiumOffer();
    });
  }

  /// Check for unread admin popup messages and show if any exist.
  Future<void> _checkAdminMessages() async {
    try {
      await Future.delayed(const Duration(seconds: 2)); // Let dashboard settle
      if (!mounted) return;
      await AdminMessagePopup.showPendingMessages(context, triggerPage: 'dashboard');
    } catch (e) {
      debugPrint('⚠️ Admin message check failed: $e');
    }
  }

  /// Show one-time premium upsell for new users (replaces old free trial).
  /// Flag is set after signup in auth_service.dart.
  Future<void> _checkPremiumOffer() async {
    try {
      // Wait for dashboard to fully settle + admin messages to finish
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted) return;

      // Skip if already premium
      final subManager = SubscriptionManager();
      if (subManager.isPremium) return;

      final prefs = await SharedPreferences.getInstance();
      final shouldShow = prefs.getBool('show_premium_offer') ?? false;
      if (!shouldShow) return;

      // Clear flag immediately so it only shows once
      await prefs.setBool('show_premium_offer', false);

      if (!mounted) return;
      await showPremiumPaywall(
        context,
        featureName: 'Welcome to DinCharya! 🎉',
        description:
            'Premium में Ad-free experience, unlimited AI Guide, advanced analytics और बहुत कुछ मिलेगा।\n\nसिर्फ ₹199/month से शुरू!',
        icon: Icons.card_giftcard,
      );
      debugPrint('🎯 Welcome premium offer shown to new user');
    } catch (e) {
      debugPrint('⚠️ Premium offer check failed: $e');
    }
  }

  /// Initialize lifecycle service and check for day change
  Future<void> _initializeLifecycle() async {
    // Check if day changed (processes missed tasks from yesterday)
    final dayChanged = await _lifecycleService.checkAndProcessDayChange();
    if (dayChanged) {
      debugPrint('📅 New day detected - tasks reset');
    }
    
    // Now load tasks and calculate streak
    await _loadTasks();
    await _calculateStreak();
    await _loadWeeklyStats();
    await _loadUserXP();
    
    // Update task statuses based on current time
    if (_todayTasks.isNotEmpty) {
      await _lifecycleService.updateTaskStatuses(_todayTasks);
      // Reload to get updated statuses
      await _loadTasks();
    }
  }

  /// Initialize listener for notification deep link highlighting
  void _initializeDeepLinkListener() {
    _deepLinkService.highlightedTaskId.addListener(_onHighlightedTaskChanged);
  }

  /// Check Play Store for app updates
  Future<void> _checkForAppUpdate() async {
    final info = await _appUpdateService.checkForUpdate();
    if (info == null || !_appUpdateService.isUpdateAvailable) return;
    if (!mounted) return;

    // Critical update (stale > 3 days) → mandatory immediate update
    if (_appUpdateService.isCriticalUpdate && _appUpdateService.canDoImmediateUpdate) {
      await _appUpdateService.startImmediateUpdate();
      return;
    }

    // Normal update → start flexible download in background
    if (_appUpdateService.canDoFlexibleUpdate) {
      final started = await _appUpdateService.startFlexibleUpdate();
      if (started && mounted) {
        setState(() {
          _updateAvailable = true;
          _flexibleUpdateDownloaded = true;
        });
      }
    } else {
      // Flexible not allowed, just show banner
      if (mounted) {
        setState(() {
          _updateAvailable = true;
        });
      }
    }
  }

  /// Called when notification requests navigation to Routine tab
  void _onNavigateToRoutineTab() {
    if (_deepLinkService.navigateToRoutineTab.value && _currentTabIndex != 0) {
      debugPrint('📋 Switching to Routine tab (notification deep link)');
      setState(() {
        _currentTabIndex = 0;
      });
    }
  }

  /// Called when highlighted task ID changes (from notification tap)
  void _onHighlightedTaskChanged() {
    final newHighlightedId = _deepLinkService.highlightedTaskId.value;
    
    setState(() {
      _highlightedTaskId = newHighlightedId;
    });
    
    if (_highlightedTaskId != null) {
      debugPrint('🔦 Dashboard: Highlighting task $_highlightedTaskId');
      // Try to scroll — with retry for when tasks haven't loaded yet
      _scrollToHighlightedTaskWithRetry();
    }
  }
  
  /// Scroll to the highlighted task with retry logic.
  /// Tasks load from Supabase asynchronously — GlobalKeys may not exist yet.
  /// Retries up to 10 times (every 500ms = 5 seconds total).
  void _scrollToHighlightedTaskWithRetry({int attempt = 0}) {
    if (_highlightedTaskId == null || attempt >= 10) {
      if (attempt >= 10) debugPrint('⚠️ Gave up scrolling to task after 10 attempts');
      return;
    }
    
    final key = _taskKeys[_highlightedTaskId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.3, // Position task 30% from top
      );
      debugPrint('🔦 Scrolled to task $_highlightedTaskId (attempt ${attempt + 1})');
      _deepLinkService.consumePendingTask();
    } else {
      // Tasks not rendered yet — retry after delay
      debugPrint('⏳ Task key not ready for $_highlightedTaskId — retrying (attempt ${attempt + 1}/10)...');
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _scrollToHighlightedTaskWithRetry(attempt: attempt + 1);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deepLinkService.highlightedTaskId.removeListener(_onHighlightedTaskChanged);
    _deepLinkService.navigateToRoutineTab.removeListener(_onNavigateToRoutineTab);
    dayChangeNotifier.removeListener(_onGlobalDayChange);
    _scrollController.dispose();
    super.dispose();
  }

  /// Layer 4: Called when app-level day change is detected (from main.dart).
  /// Refreshes all dashboard data without re-running day change processing
  /// (that's already been handled by main.dart's Layer 1).
  void _onGlobalDayChange() {
    debugPrint('📅 RoutineDashboard: Received global day change notification — refreshing UI');
    _loadTasks();
    _calculateStreak();
    _loadWeeklyStats();
    _loadUserXP();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check day change when app returns from background
      _initializeLifecycle();
    }
  }

  // Load streak from user_profiles (authoritative source, updated by _updateUserStats)
  Future<void> _calculateStreak() async {
    try {
      final userId = _supabaseService.currentUser?.id;
      if (userId == null) return;
      
      final client = await _supabaseService.client;
      if (client == null) return;
      
      final profile = await client
          .from('user_profiles')
          .select('current_streak, best_streak')
          .eq('id', userId)
          .maybeSingle();
      
      if (mounted) {
        setState(() {
          _streakCount = profile?['current_streak'] ?? 0;
          _bestStreak = profile?['best_streak'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Error loading streak: $e');
    }
  }

  Future<void> _initializeTracking() async {
    await _trackingService.initialize();
    debugPrint('✅ Tracking service initialized');
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final authService = AuthService();
      final isLoggedIn = await authService.isUserLoggedIn();

      if (isLoggedIn) {
          // CRITICAL: Use getAuthenticatedUser() not currentUser?.id
          // currentUser is null on cold start before supabase_flutter v2
          // restores the session from local storage asynchronously.
          final user = await _supabaseService.getAuthenticatedUser();
          final userId = user?.id;
          if (userId != null) {
          var tasks = await _supabaseService.getLocalTasks(userId);
          
          // FAILSAFE: Check if any tasks are still completed from a previous day
          // This catches edge cases where the lifecycle service reset failed
          final today = DateTime.now();
          final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
          bool needsForceReset = false;
          
          for (final task in tasks) {
            final isCompleted = task['is_completed'] == true || task['is_completed'] == 1;
            final statusUpdatedAt = task['status_updated_at']?.toString() ?? '';
            
            if (isCompleted && statusUpdatedAt.isNotEmpty) {
              // Extract just the date part from status_updated_at
              final updateDate = statusUpdatedAt.length >= 10 ? statusUpdatedAt.substring(0, 10) : '';
              if (updateDate.isNotEmpty && updateDate != todayStr && updateDate.compareTo(todayStr) < 0) {
                debugPrint('⚠️ [FAILSAFE] Task "${task['title']}" still completed from $updateDate (today=$todayStr) — forcing reset!');
                needsForceReset = true;
              }
            }
          }
          
          if (needsForceReset) {
            debugPrint('🔄 [FAILSAFE] Forcing task reset via lifecycle service...');
            // Force-clear the last_active_date to trigger a fresh day change
            final prefs = await SharedPreferences.getInstance();
            final yesterday = DateTime.now().subtract(const Duration(days: 1));
            final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
            await prefs.setString('last_active_date', yesterdayStr);
            
            // Re-run day change processing
            final resetDone = await _lifecycleService.checkAndProcessDayChange();
            debugPrint('🔄 [FAILSAFE] Force reset result: $resetDone');
            
            // Reload tasks after force reset
            tasks = await _supabaseService.getLocalTasks(userId);
          }
          
          // Sort tasks by time (AM to PM)
          tasks.sort((a, b) {
            final timeA = _parseTimeToMinutes(a['time'] ?? '12:00 AM');
            final timeB = _parseTimeToMinutes(b['time'] ?? '12:00 AM');
            return timeA.compareTo(timeB);
          });
          setState(() {
            _todayTasks = tasks;
          });
        }
      } else {
        setState(() {
          _todayTasks = [];
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please sign in to view and manage your routine.'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading tasks: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load tasks: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
      
      // After tasks load, check if there's a pending deep link task to scroll to
      final pendingId = _deepLinkService.pendingTaskId;
      if (pendingId != null) {
        debugPrint('📋 Tasks loaded — processing pending deep link task: $pendingId');
        // Ensure highlight is set
        if (_highlightedTaskId == null) {
          setState(() { _highlightedTaskId = pendingId; });
        }
        // Give widgets time to render, then scroll
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToHighlightedTaskWithRetry();
        });
      }

      // Schedule notifications for today's tasks (only once per session)
      await _scheduleTaskNotifications();
      
      // Reschedule wakeup alarms (ensures alarms survive app restart)
      _rescheduleWakeupAlarms();

      // Check and show app tour for first-time users (with delay for UI to settle)
      _checkAndShowAppTour();
    }
  }
  
  /// Check if app tour should be shown and display it
  Future<void> _checkAndShowAppTour() async {
    // Small delay to ensure UI is fully rendered
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (!mounted) return;
    
    final shouldShow = await _appTourService.shouldShowTour();
    if (shouldShow && _todayTasks.isNotEmpty) {
      debugPrint('📚 Showing app tour for first-time user');
      
      // Get first task key for highlighting
      GlobalKey? firstTaskKey;
      if (_todayTasks.isNotEmpty) {
        final firstTaskId = _todayTasks.first['id'] as String?;
        if (firstTaskId != null) {
          firstTaskKey = _taskKeys[firstTaskId];
        }
      }
      
      final targets = _appTourService.createTourTargets(
        progressSummaryKey: _progressSummaryKey,
        addTaskFabKey: _addTaskFabKey,
        firstTaskCardKey: firstTaskKey,
        bottomNavKey: _bottomNavKey,
      );
      
      _appTourService.showTour(
        context: context,
        targets: targets,
      );
    }
  }

  // Schedule notifications for today's tasks
  Future<void> _scheduleTaskNotifications() async {
    try {
      // Cancel existing notifications first to avoid duplicates
      await _trackingService.cancelAllNotifications();
      
      final activities = _todayTasks.map((task) {
        // Extract time - could be 'time', 'scheduled_time', or 'due_date'
        String timeStr;
        
        if (task['time'] != null) {
          timeStr = task['time'];
        } else if (task['scheduled_time'] != null) {
          timeStr = task['scheduled_time'];
        } else if (task['due_date'] != null) {
          // due_date is in ISO format like "2026-01-25T10:30:00"
          timeStr = _extractTimeFromIso(task['due_date']);
        } else {
          timeStr = '09:00';
        }
        
        // Convert 12-hour format to 24-hour if needed (e.g., "6:00 AM" -> "06:00")
        if (timeStr.contains('AM') || timeStr.contains('PM')) {
          timeStr = _convertTo24Hour(timeStr);
        }
        
        return {
          'id': task['id'],  // Include task ID for deep link highlighting
          'name': task['title'] ?? task['name'] ?? 'Task',
          'time': timeStr,
        };
      }).toList();

      final routine = {'activities': activities};
      await _trackingService.scheduleRoutineNotifications(routine);
      debugPrint('✅ Notifications scheduled for ${activities.length} tasks');
    } catch (e) {
      debugPrint('Error scheduling notifications: $e');
    }
  }
  
  // Extract time from ISO date string like "2026-01-25T10:30:00" -> "10:30"
  String _extractTimeFromIso(String isoDate) {
    try {
      final dateTime = DateTime.parse(isoDate);
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      debugPrint('❌ Failed to parse ISO date: $isoDate');
      return '09:00';
    }
  }
  
  // Convert 12-hour time to 24-hour format
  String _convertTo24Hour(String time12h) {
    try {
      final parts = time12h.split(' ');
      if (parts.length != 2) return '09:00';
      
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final minute = timeParts.length > 1 ? timeParts[1] : '00';
      final period = parts[1].toUpperCase();
      
      if (period == 'AM' && hour == 12) {
        hour = 0;
      } else if (period == 'PM' && hour != 12) {
        hour += 12;
      }
      
      return '${hour.toString().padLeft(2, '0')}:$minute';
    } catch (e) {
      return '09:00';
    }
  }

  // Show tracking dialog for a task
  void _showTrackingDialog(Map<String, dynamic> task) {
    showDialog(
      context: context,
      builder: (context) => ActivityTrackingDialog(
        activityName: task['title'] ?? 'Task',
        scheduledTime: task['scheduled_time'] ?? '09:00',
        taskId: task['id'],
        onComplete: () {
          // Refresh the dashboard to show updated task status
          _loadTasks();
        },
      ),
    );
  }

  // Show dialog explaining why task is locked
  void _showLockedTaskDialog(
    BuildContext context,
    String taskName,
    String reason,
    String status,
    String scheduledTime,
  ) {
    String title;
    String message;
    IconData icon;
    Color iconColor;
    
    if (reason.contains('unlock')) {
      // Task not yet available
      title = '⏳ अभी समय नहीं हुआ';
      message = '"$taskName" का समय अभी नहीं आया है।\n\n'
          '📅 Task Time: $scheduledTime\n'
          '🔓 $reason';
      icon = Icons.lock_clock;
      iconColor = Colors.blue;
    } else if (reason == 'Window closed' || status == 'missed') {
      // Task window closed / missed
      title = '❌ Task छूट गया';
      message = '"$taskName" का completion window बंद हो गया।\n\n'
          '📅 Scheduled: $scheduledTime\n'
          '⚠️ आपने इस task को समय पर confirm नहीं किया।\n\n'
          'अगली बार समय पर complete करें!';
      icon = Icons.cancel;
      iconColor = Colors.red;
    } else if (status == 'overdue') {
      // Task is overdue but still completable
      title = '⚠️ Time निकल गया';
      message = '"$taskName" का scheduled time निकल गया है।\n\n'
          '📅 Scheduled: $scheduledTime\n'
          '⏰ आप अभी भी इसे complete कर सकते हैं!';
      icon = Icons.warning_amber;
      iconColor = Colors.orange;
    } else {
      title = '🔒 Task Locked';
      message = reason.isNotEmpty ? reason : 'This task is not available right now.';
      icon = Icons.lock;
      iconColor = Colors.grey;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            SizedBox(width: 2.w),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            fontSize: 14.sp,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('समझ गया'),
          ),
        ],
      ),
    );
  }

  /// Load weekly completion stats for the header
  Future<void> _loadWeeklyStats() async {
    try {
      final userId = _supabaseService.currentUser?.id;
      if (userId == null) return;
      
      final client = await _supabaseService.client;
      if (client == null) return;
      
      final now = DateTime.now();
      // Monday of this week
      final mondayOffset = now.weekday - 1;
      final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: mondayOffset));
      
      final weeklyTracking = await client
          .from('routine_tracking')
          .select('tracking_date, task_id, activity_name, completed')
          .eq('user_id', userId)
          .gte('tracking_date', monday.toIso8601String().split('T')[0])
          .lte('tracking_date', now.toIso8601String().split('T')[0]);
      
      // Calculate per-day completion — DEDUPLICATED by task_id
      // A task may have both a "completed" record (user tap) and a "missed"
      // record (end-of-day auto-processing). We keep only the best result per task.
      List<bool> days = [false, false, false, false, false, false, false];
      
      // Group by day, then deduplicate by task_id (completed wins over missed)
      // Key: dayIndex, Value: Map<taskId, bestResult>
      Map<int, Map<String, bool>> dayTaskResults = {};
      
      for (final task in weeklyTracking) {
        final dateStr = task['tracking_date'];
        if (dateStr == null) continue;
        try {
          final date = DateTime.parse(dateStr);
          final dayIndex = date.weekday - 1; // 0 = Monday
          final taskId = task['task_id']?.toString() ?? task['activity_name']?.toString() ?? '';
          final isCompleted = task['completed'] == true;
          
          dayTaskResults[dayIndex] ??= {};
          // Keep true if already true (completed wins over missed)
          final existing = dayTaskResults[dayIndex]![taskId];
          if (existing == null || (!existing && isCompleted)) {
            dayTaskResults[dayIndex]![taskId] = isCompleted;
          }
        } catch (_) {}
      }
      
      int totalCompleted = 0;
      int totalTasks = 0;
      for (final entry in dayTaskResults.entries) {
        final taskMap = entry.value;
        final completed = taskMap.values.where((v) => v).length;
        final total = taskMap.length;
        totalCompleted += completed;
        totalTasks += total;
        // Consider day completed if >50% tasks done
        days[entry.key] = completed > total / 2;
      }
      
      if (mounted) {
        setState(() {
          _weeklyDays = days;
          _weeklyCompletion = totalTasks > 0 ? totalCompleted / totalTasks : 0.0;
        });
      }
    } catch (e) {
      debugPrint('Error loading weekly stats: $e');
    }
  }
  
  /// Load user's total XP from profile
  Future<void> _loadUserXP() async {
    try {
      final userId = _supabaseService.currentUser?.id;
      if (userId == null) return;
      
      final client = await _supabaseService.client;
      if (client == null) return;
      
      final profile = await client
          .from('user_profiles')
          .select('total_tasks_completed')
          .eq('id', userId)
          .maybeSingle();
      
      // Estimate XP from total tasks (25 XP per task)
      final totalTasks = profile?['total_tasks_completed'] ?? 0;
      if (mounted) {
        setState(() {
          _totalXP = totalTasks * 25;
        });
      }
    } catch (e) {
      debugPrint('Error loading user XP: $e');
    }
  }

  /// Premium update banner shown at top of dashboard
  Widget _buildUpdateBanner() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDAA520), Color(0xFFB8860B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDAA520).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.system_update_rounded, color: Colors.white, size: 24),
          ),
          SizedBox(width: 3.w),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Update Available! 🎉',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _flexibleUpdateDownloaded
                      ? 'Download complete — tap to install'
                      : 'A newer version is ready for you',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          // Dismiss
          GestureDetector(
            onTap: () => setState(() => _updateAvailable = false),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close, color: Colors.white.withOpacity(0.6), size: 18),
            ),
          ),
          SizedBox(width: 1.w),
          // Action button
          ElevatedButton(
            onPressed: () async {
              if (_flexibleUpdateDownloaded) {
                await _appUpdateService.completeFlexibleUpdate();
              } else if (_appUpdateService.canDoImmediateUpdate) {
                await _appUpdateService.startImmediateUpdate();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFB8860B),
              padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text(
              _flexibleUpdateDownloaded ? 'Install' : 'Update',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Sticky Header
            RoutineHeaderWidget(
              selectedProfile: 'custom', // Will load from database later
              routineProfiles: const [],
              onProfileChanged: (_) {},
              streakCount: _streakCount,
              totalXP: _totalXP,
              weeklyCompletion: _weeklyCompletion,
              weeklyDays: _weeklyDays,
              onProfileTap: null,
            ),

            // Main Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                color: Theme.of(context).primaryColor,
                child: _todayTasks.isEmpty
                    ? (_isLoading 
                        ? ListView(
                            padding: EdgeInsets.symmetric(vertical: 2.h),
                            children: [
                              // Show shimmer/placeholder while loading
                              _buildProgressSummary(),
                              SizedBox(height: 2.h),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4.w),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.today,
                                      color: Theme.of(context).colorScheme.primary,
                                      size: 24,
                                    ),
                                    SizedBox(width: 2.w),
                                    Text(
                                      'Today\'s Tasks',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                    const Spacer(),
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 2.h),
                              // Loading placeholders
                              ...List.generate(3, (i) => Container(
                                margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                                height: 10.h,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'Loading...',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                                    ),
                                  ),
                                ),
                              )),
                            ],
                          )
                        : EmptyRoutineWidget(onRoutineCreated: _loadTasks))
                    : ListView(
                        padding: EdgeInsets.symmetric(vertical: 2.h),
                        children: [
                          // ── Update Banner ──
                          if (_updateAvailable) _buildUpdateBanner(),

                          // Daily Progress Summary
                          Container(
                            key: _progressSummaryKey,
                            child: _buildProgressSummary(),
                          ),
                              
                              SizedBox(height: 2.h),
                              
                              // Today's Tasks Header
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4.w),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.today,
                                      color: Theme.of(context).colorScheme.primary,
                                      size: 24,
                                    ),
                                    SizedBox(width: 2.w),
                                    Text(
                                      'Today\'s Tasks',
                                      style: Theme.of(context).textTheme.titleLarge
                                          ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                    const Spacer(),
                                    _buildCompletedBadge(),
                                  ],
                                ),
                              ),

                              SizedBox(height: 1.h),

                              // Time-Grouped Task Sections with Native Ads
                              _buildTimeSection('morning', _groupedTasks['morning']!),
                              // Native Ad after Morning section
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4.w),
                                child: const NativeAdWidget(placement: NativePlacement.routineMorning),
                              ),
                              
                              _buildTimeSection('afternoon', _groupedTasks['afternoon']!),
                              // Native Ad after Afternoon section
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4.w),
                                child: const NativeAdWidget(placement: NativePlacement.routineAfternoon),
                              ),
                              
                              _buildTimeSection('evening', _groupedTasks['evening']!),

                              // Quick Tasks (local-only, device storage)
                              const QuickTasksSection(),

                              // Native Ad at bottom of task list
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4.w),
                                child: const NativeAdWidget(placement: NativePlacement.routineDashboard),
                              ),

                              SizedBox(height: 8.h), // Space for FAB
                            ],
                          ),

              ),
            ),
          ],
        ),
      ),

      // Bottom Navigation + Anchored Adaptive Banner
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Anchored Adaptive Banner — always visible on highest-traffic screen
          const AdaptiveBannerAdWidget(placement: BannerPlacement.routineDashboard),
          BottomNavigationBar(
        key: _bottomNavKey,
        currentIndex: _currentTabIndex,
        onTap: _onTabChanged,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
        elevation: 8.0,
        items: [
          BottomNavigationBarItem(
            icon: CustomIconWidget(
              iconName: 'schedule',
              color: _currentTabIndex == 0
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 24,
            ),
            label: _tabLabels[0],
          ),
          BottomNavigationBarItem(
            icon: CustomIconWidget(
              iconName: 'self_improvement',
              color: _currentTabIndex == 1
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 24,
            ),
            label: _tabLabels[1],
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.local_fire_department,
              color: _currentTabIndex == 2
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 24,
            ),
            label: _tabLabels[2],
          ),
          BottomNavigationBarItem(
            icon: CustomIconWidget(
              iconName: 'book',
              color: _currentTabIndex == 3
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 24,
            ),
            label: _tabLabels[3],
          ),
          BottomNavigationBarItem(
            icon: CustomIconWidget(
              iconName: 'person',
              color: _currentTabIndex == 4
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 24,
            ),
            label: _tabLabels[4],
          ),
        ],
      ),
        ],
      ),

      // Floating Action Button
      floatingActionButton: FloatingActionButton(
        key: _addTaskFabKey,
        onPressed: _showAddTaskBottomSheet,
        backgroundColor: Theme.of(context).colorScheme.tertiary,
        foregroundColor: Theme.of(context).colorScheme.onTertiary,
        elevation: 6.0,
        child: CustomIconWidget(
          iconName: 'add',
          color: Theme.of(context).colorScheme.onTertiary,
          size: 28,
        ),
      ),
    ), // Close Scaffold
        // Celebration Overlay
        if (_showCelebration)
          CelebrationOverlay(
            xpEarned: _celebrationXP,
            taskName: _celebrationTaskName,
            dailyProgress: _todayTasks.isEmpty ? 0.0 :
              _todayTasks.where((t) => t['is_completed'] == true || t['is_completed'] == 1).length / _todayTasks.length,
            onDismiss: () {
              if (mounted) setState(() => _showCelebration = false);
            },
          ),
      ], // Close Stack children
    ); // Close Stack
  }

  // Removed broken profile change method
  // void _onProfileChanged(String? newProfile) { ... }

  // Helper to parse time string to minutes for sorting
  int _parseTimeToMinutes(String timeStr) {
    try {
      // Handle formats like "3:00 AM", "12:30 PM"
      final cleanTime = timeStr.trim();
      final isPM = cleanTime.toUpperCase().contains('PM');
      final isAM = cleanTime.toUpperCase().contains('AM');
      
      final timePart = cleanTime.replaceAll(RegExp(r'[APMapm\s]'), '');
      final parts = timePart.split(':');
      
      int hours = int.tryParse(parts[0]) ?? 0;
      int minutes = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      
      // Convert to 24-hour format for proper sorting
      if (isPM && hours != 12) {
        hours += 12;
      } else if (isAM && hours == 12) {
        hours = 0;
      }
      
      return hours * 60 + minutes;
    } catch (e) {
      return 720; // Default to noon if parsing fails
    }
  }

  // Helper to get time period (morning/afternoon/evening)
  String _getTimePeriod(int minutes) {
    if (minutes < 720) return 'morning';      // Before 12 PM
    if (minutes < 1020) return 'afternoon';   // Before 5 PM  
    return 'evening';
  }

  // Get filtered tasks based on selected category
  List<Map<String, dynamic>> get _filteredTasks {
    if (_selectedCategory == 'all') return _todayTasks;
    return _todayTasks.where((task) => 
      task['type']?.toString().toLowerCase() == _selectedCategory
    ).toList();
  }

  // Get tasks grouped by time period
  Map<String, List<Map<String, dynamic>>> get _groupedTasks {
    final groups = <String, List<Map<String, dynamic>>>{
      'morning': [],
      'afternoon': [],
      'evening': [],
    };
    
    for (var task in _filteredTasks) {
      final minutes = _parseTimeToMinutes(task['time'] ?? '12:00 PM');
      final period = _getTimePeriod(minutes);
      groups[period]!.add(task);
    }
    
    return groups;
  }

  // Build category filter chips
  Widget _buildCategoryFilters() {
    return Container(
      height: 5.h,
      margin: EdgeInsets.symmetric(horizontal: 2.w),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category['key'];
          final taskCount = category['key'] == 'all' 
              ? _todayTasks.length 
              : _todayTasks.where((t) => 
                  t['type']?.toString().toLowerCase() == category['key']
                ).length;
          
          return Padding(
            padding: EdgeInsets.only(right: 2.w),
            child: FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(category['icon']!, style: TextStyle(fontSize: 12.sp)),
                  SizedBox(width: 1.w),
                  Text(
                    category['label']!,
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: isSelected 
                          ? Colors.white 
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if (taskCount > 0) ...[
                    SizedBox(width: 1.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 1.5.w, vertical: 0.2.h),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? Colors.white.withOpacity(0.3) 
                            : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$taskCount',
                        style: TextStyle(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.bold,
                          color: isSelected 
                              ? Colors.white 
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = category['key']!;
                });
              },
              backgroundColor: Theme.of(context).colorScheme.surface,
              selectedColor: Theme.of(context).colorScheme.primary,
              checkmarkColor: Colors.transparent,
              side: BorderSide(
                color: isSelected 
                    ? Color(0xFF8B4513) 
                    : Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
              padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
            ),
          );
        },
      ),
    );
  }

  // Build section header for time periods
  Widget _buildTimeSection(String period, List<Map<String, dynamic>> tasks) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    
    final sectionData = {
      'morning': {'title': 'Morning', 'icon': '🌅', 'subtitle': '5 AM - 12 PM'},
      'afternoon': {'title': 'Afternoon', 'icon': '☀️', 'subtitle': '12 PM - 5 PM'},
      'evening': {'title': 'Evening', 'icon': '🌙', 'subtitle': '5 PM - 10 PM'},
    };
    
    final data = sectionData[period]!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
          child: Row(
            children: [
              Text(data['icon']!, style: TextStyle(fontSize: 16.sp)),
              SizedBox(width: 2.w),
              Text(
                data['title']!,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(width: 2.w),
              Text(
                data['subtitle']!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${tasks.where((t) => t['is_completed'] == true || t['is_completed'] == 1).length}/${tasks.length}',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...List.generate(tasks.length, (index) {
          final task = tasks[index];
          
          // Section end times
          final sectionEndTimes = {
            'morning': '12:00 PM',
            'afternoon': '05:00 PM',
            'evening': '10:00 PM',
          };
          
          // Calculate next task's time for completion window
          // For last task in section, use section end time
          String? nextTaskTime;
          if (index < tasks.length - 1) {
            nextTaskTime = tasks[index + 1]['time'] ?? tasks[index + 1]['scheduledTime'];
          } else {
            // Last task in section - use section end time as deadline
            nextTaskTime = sectionEndTimes[period];
          }
          
          // Create or get existing GlobalKey for this task (for scroll-to-task)
          final taskId = task['id'] as String?;
          if (taskId != null && !_taskKeys.containsKey(taskId)) {
            _taskKeys[taskId] = GlobalKey();
          }
          
          return Container(
            key: taskId != null ? _taskKeys[taskId] : null,
            margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.8.h),
            child: TaskCardWidget(
              task: task,
              nextTaskTime: nextTaskTime,
              sectionEndTime: sectionEndTimes[period],
              isHighlighted: _highlightedTaskId == task['id'],
              onTaskCompleted: () => _onTaskCompleted(
                  task["id"],
                  task["is_completed"] == true || task["is_completed"] == 1),
              onTaskEdit: () => _onTaskEdit(task["id"]),
              onTaskReschedule: () => _onTaskReschedule(task["id"]),
              onTaskDelete: () => _onTaskDelete(task["id"]),
              onTaskTrack: () => _showTrackingDialog(task),
              onSessionPlay: task['linked_session_id'] != null
                  ? () => _playLinkedSession(task['linked_session_id'].toString())
                  : null,
              onTapLocked: (String reason, String status) => _showLockedTaskDialog(
                context, 
                task['title'] ?? 'Task', 
                reason, 
                status,
                task['time'] ?? '',
              ),
            ),
          );
        }),
      ],
    );
  }

  // Build COMPACT daily progress summary widget
  Widget _buildProgressSummary() {
    final completedCount = _todayTasks.where((task) => 
      task['is_completed'] == true || task['is_completed'] == 1
    ).length;
    final totalCount = _todayTasks.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
            Theme.of(context).colorScheme.tertiary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          // Circular progress (smaller)
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    completedCount == totalCount && totalCount > 0
                        ? AppTheme.getSuccessColor(Theme.of(context).brightness == Brightness.light)
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 10.sp,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 3.w),
          // Text info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Daily Progress',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text(
                  '$completedCount of $totalCount tasks',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Celebration if complete
          if (completedCount == totalCount && totalCount > 0)
            Text('🎉', style: TextStyle(fontSize: 20.sp)),
        ],
      ),
    );
  }

  Widget _buildCompletedBadge() {
    final completedCount = _todayTasks.where((task) => 
      task['is_completed'] == true || task['is_completed'] == 1
    ).length;
    final totalCount = _todayTasks.length;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
      decoration: BoxDecoration(
        color: completedCount == totalCount && totalCount > 0
            ? AppTheme.getSuccessColor(Theme.of(context).brightness == Brightness.light).withOpacity(0.1)
            : Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            completedCount == totalCount && totalCount > 0
                ? Icons.check_circle
                : Icons.pending_actions,
            size: 16,
            color: completedCount == totalCount && totalCount > 0
                ? AppTheme.getSuccessColor(Theme.of(context).brightness == Brightness.light)
                : Theme.of(context).colorScheme.primary,
          ),
          SizedBox(width: 1.w),
          Text(
            '$completedCount/$totalCount',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: completedCount == totalCount && totalCount > 0
                  ? AppTheme.getSuccessColor(Theme.of(context).brightness == Brightness.light)
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onRefresh() async {
    await _loadTasks();
    await _calculateStreak(); // Refresh streak too
  }

  Future<void> _onTaskCompleted(String taskId, bool isCompleted) async {
    final userId =
        _supabaseService.currentUser?.id; // Use SupabaseService's currentUser
    if (userId == null) return;

    final updatedStatus = !isCompleted; // Toggle: if completed, mark incomplete and vice versa
    
    // ── CHECK FOR MISSED INEVITABLE TASKS BEFORE COMPLETING ──
    if (updatedStatus && mounted) {
      // Only check when COMPLETING (not uncompleting)
      final missedTasks = _getMissedInevitableTasks(taskId);
      for (final missedTask in missedTasks) {
        if (!mounted) break;
        final proceed = await MissedTaskFeedbackDialog.show(context, missedTask);
        if (!proceed) return; // User dismissed, don't complete
        
        // Mark the missed task as completed so it won't trigger the dialog again
        final missedTaskId = missedTask['id'];
        if (missedTaskId != null) {
          try {
            await _supabaseService.updateLocalTask(missedTaskId, {
              'is_completed': true,
              'task_status': 'completed', // ALSO set task_status!
              'updated_at': DateTime.now().toIso8601String(),
            });
          } catch (e) {
            debugPrint('Error marking missed task as completed: $e');
          }
        }
      }
    }
    
    final updates = {
      'is_completed': updatedStatus, // Send boolean, not int
      'task_status': updatedStatus ? 'completed' : 'pending', // CRITICAL: keep task_status in sync
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      // Find task for celebration and tracking
      final task = _todayTasks.firstWhere(
        (t) => t['id'] == taskId,
        orElse: () => {},
      );
      final taskName = task['title'] ?? 'Task';
      final scheduledTime = task['scheduled_time'] ?? task['time'] ?? '';
      
      await _supabaseService.updateLocalTask(taskId, updates);
      
      // ── CRITICAL: Track task completion in routine_tracking + user_profiles ──
      if (updatedStatus) {
        // Task is being marked as COMPLETED — record it
        await _trackingService.trackActivity(
          taskId: taskId,
          activityName: taskName,
          scheduledTime: scheduledTime is String ? scheduledTime : '',
          completed: true,
          actualTime: DateTime.now(),
          durationMinutes: task['duration_minutes'] as int? ?? 15,
          completionPercent: 100,
          notes: 'Completed via quick toggle',
        );
      }
      
      await _loadTasks();
      await _calculateStreak(); // Update streak after completion
      await _loadWeeklyStats(); // Refresh weekly stats
      
      // Show celebration overlay when completing (not uncompleting)
      if (updatedStatus && mounted) {
        setState(() {
          _celebrationTaskName = taskName;
          _celebrationXP = 25;
          _totalXP += 25; // Increment local XP
          _showCelebration = true;
        });

        // Premium nudge after 3rd task completion (engagement-based upsell)
        _checkTaskCompletionNudge();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Task marked incomplete'),
            duration: const Duration(seconds: 2),
            backgroundColor: Theme.of(context).primaryColor,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating task completion: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update task: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Engagement-based premium upsell — shown once after 3rd task completion.
  /// Only for free users. Non-blocking, shows after celebration dismisses.
  Future<void> _checkTaskCompletionNudge() async {
    try {
      // Skip if already premium
      final subManager = SubscriptionManager();
      if (subManager.isPremium) return;

      final prefs = await SharedPreferences.getInstance();

      // Check if nudge was already shown
      final nudgeShown = prefs.getBool('task_completion_nudge_shown') ?? false;
      if (nudgeShown) return;

      // Increment completion counter
      final completionCount = (prefs.getInt('task_completion_count') ?? 0) + 1;
      await prefs.setInt('task_completion_count', completionCount);

      // Show nudge on 3rd completion
      if (completionCount >= 3) {
        await prefs.setBool('task_completion_nudge_shown', true);

        // Wait for celebration overlay to dismiss
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;

        await showPremiumPaywall(
          context,
          featureName: 'आप बहुत अच्छा कर रहे हैं! 🔥',
          description:
              'Premium में upgrade करें और पाएं:\n• Ad-free अनुभव\n• Unlimited AI Guide\n• Advanced Analytics\n\nसिर्फ ₹199/month!',
          icon: Icons.trending_up,
        );
        debugPrint('🎯 Task completion premium nudge shown (3rd task)');
      }
    } catch (e) {
      debugPrint('⚠️ Task completion nudge failed: $e');
    }
  }

  /// Find missed inevitable tasks that are scheduled BEFORE the task being completed.
  /// These are tasks like Wake Up, Eating, Sleep that the user does regardless.
  List<Map<String, dynamic>> _getMissedInevitableTasks(String currentTaskId) {
    // Find the current task to get its time
    final currentTask = _todayTasks.firstWhere(
      (t) => t['id'] == currentTaskId,
      orElse: () => {},
    );
    if (currentTask.isEmpty) return [];

    final currentTimeStr = currentTask['time'] ?? '';
    final currentMinutes = _timeToMinutes(currentTimeStr);
    if (currentMinutes < 0) return [];

    final missed = <Map<String, dynamic>>[];

    for (final task in _todayTasks) {
      if (task['id'] == currentTaskId) continue;

      // Check if task is incomplete
      final isCompleted = task['is_completed'] == true || task['is_completed'] == 1;
      if (isCompleted) continue;

      // Check if task is inevitable (wakeup, eating, sleep, hygiene)
      final categoryId = task['category'] ?? task['type'] ?? '';
      if (!TaskCategory.isInevitableCategory(categoryId)) continue;

      // Check if task is scheduled BEFORE the current task
      final taskTimeStr = task['time'] ?? '';
      final taskMinutes = _timeToMinutes(taskTimeStr);
      if (taskMinutes < 0 || taskMinutes >= currentMinutes) continue;

      // Check if task status is missed or overdue
      final status = task['task_status'] ?? '';
      final isMissedOrOverdue = status == TaskStatus.missed ||
          status == TaskStatus.overdue ||
          status == TaskStatus.skipped ||
          status == ''; // No status = not yet handled

      if (isMissedOrOverdue) {
        missed.add(task);
      }
    }

    // Sort by scheduled time (earliest first)
    missed.sort((a, b) {
      final aMin = _timeToMinutes(a['time'] ?? '');
      final bMin = _timeToMinutes(b['time'] ?? '');
      return aMin.compareTo(bMin);
    });

    return missed;
  }

  /// Convert time string like "6:00 AM" or "14:30" to minutes since midnight
  int _timeToMinutes(String timeStr) {
    try {
      if (timeStr.isEmpty) return -1;
      
      final upper = timeStr.toUpperCase().trim();
      final isPM = upper.contains('PM');
      final isAM = upper.contains('AM');
      
      final cleaned = upper.replaceAll(RegExp(r'[APM\s]'), '');
      final parts = cleaned.split(':');
      int hour = int.parse(parts[0]);
      int minute = parts.length > 1 ? int.parse(parts[1]) : 0;

      if (isPM && hour != 12) hour += 12;
      if (isAM && hour == 12) hour = 0;

      return hour * 60 + minute;
    } catch (e) {
      return -1;
    }
  }

  void _onTaskEdit(String taskId) {
    // Find the task to edit
    final task = _todayTasks.firstWhere(
      (t) => t['id'] == taskId,
      orElse: () => {},
    );
    
    if (task.isEmpty) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: EditTaskBottomSheet(
          task: task,
          onTaskUpdated: (updatedTask) async {
            // Capture messenger before async gap (bottom sheet pops before this runs)
            final messenger = ScaffoldMessenger.of(context);
            try {
              await _supabaseService.updateLocalTask(taskId, {
                'title': updatedTask['title'],
                'description': updatedTask['description'],
                'category': updatedTask['category'],
                'type': updatedTask['type'],
                'time': updatedTask['time'],
                'icon': updatedTask['icon'],
                'duration': updatedTask['duration'],
                'duration_minutes': updatedTask['duration_minutes'],
                'is_inevitable': updatedTask['is_inevitable'],
                'alarm_enabled': updatedTask['alarm_enabled'],
                'alarm_sound': updatedTask['alarm_sound'],
                'linked_session_id': updatedTask['linked_session_id'],
                'updated_at': DateTime.now().toIso8601String(),
              });
              await _loadTasks();

              // Reschedule or cancel alarm for wakeup tasks
              if (updatedTask['category'] == 'wakeup') {
                if (updatedTask['alarm_enabled'] == true) {
                  final taskWithId = {...updatedTask, 'id': taskId};
                  _scheduleWakeupAlarm(taskWithId);
                } else {
                  await AlarmService().cancelAlarm(taskId);
                }
              }

              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: const Text('Task updated successfully!'),
                    backgroundColor: AppTheme.getSuccessColor(Theme.of(context).brightness == Brightness.light),
                  ),
                );
              }
            } catch (e) {
              debugPrint('Error updating task: $e');
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Failed to update task: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        ),
      ),
    );
  }

  void _onTaskReschedule(String taskId) async {
    // Find the task
    final task = _todayTasks.firstWhere(
      (t) => t['id'] == taskId,
      orElse: () => {},
    );
    
    if (task.isEmpty) return;
    
    // Parse current time
    TimeOfDay currentTime = const TimeOfDay(hour: 6, minute: 0);
    try {
      final timeStr = task['time'] ?? '06:00 AM';
      final parts = timeStr.replaceAll(RegExp(r'[AP]M', caseSensitive: false), '').trim().split(':');
      int hour = int.parse(parts[0]);
      int minute = parts.length > 1 ? int.parse(parts[1]) : 0;
      if (timeStr.toUpperCase().contains('PM') && hour != 12) hour += 12;
      if (timeStr.toUpperCase().contains('AM') && hour == 12) hour = 0;
      currentTime = TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      debugPrint('Error parsing time: $e');
    }
    
    // Show time picker
    final TimeOfDay? newTime = await showTimePicker(
      context: context,
      initialTime: currentTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              hourMinuteColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
              hourMinuteTextColor: Theme.of(context).colorScheme.onSurface,
              dialHandColor: Theme.of(context).colorScheme.primary,
              dialBackgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              dialTextColor: Theme.of(context).colorScheme.onSurface,
              dayPeriodColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
              dayPeriodTextColor: Theme.of(context).colorScheme.onSurface,
              dayPeriodBorderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
              entryModeIconColor: Theme.of(context).colorScheme.primary,
              helpTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (newTime != null && mounted) {
      try {
        await _supabaseService.updateLocalTask(taskId, {
          'time': newTime.format(context),
          'updated_at': DateTime.now().toIso8601String(),
        });
        await _loadTasks();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Task rescheduled to ${newTime.format(context)}'),
              backgroundColor: AppTheme.getSuccessColor(Theme.of(context).brightness == Brightness.light),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error rescheduling task: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to reschedule: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _onTaskDelete(String taskId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _deleteTask(taskId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Fixed bottom navigation - no setState, just navigate
  void _onTabChanged(int index) {
    switch (index) {
      case 0:
        // Already on Routine tab
        break;
      case 1:
        Navigator.pushNamed(context, AppRoutes.guidedSessionsHub);
        break;
      case 2:
        Navigator.pushNamed(context, '/tapasya');
        break;
      case 3:
        Navigator.pushNamed(context, AppRoutes.journalMoodTracker);
        break;
      case 4:
        Navigator.pushNamed(context, AppRoutes.profileSettings);
        break;
    }
  }

  void _showAddTaskBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTaskBottomSheet(
        onTaskAdded: (Map<String, dynamic> newTask) async {
          await _addTaskAsync(newTask);
        },
      ),
    );
  }

  /// Play a linked guided session by fetching its data and navigating to media player
  Future<void> _playLinkedSession(String sessionId) async {
    try {
      final client = await _supabaseService.client;
      if (client == null) return;

      final response = await client
          .from('sessions')
          .select('id, title, title_hindi, description, category, difficulty, duration, '
              'media_type, media_url, youtube_url, video_url, audio_url, '
              'thumbnail_url, instructor_name, is_premium, tags, view_count')
          .eq('id', sessionId)
          .eq('is_active', true)
          .limit(1);

      if (response.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session not found or no longer available')),
          );
        }
        return;
      }

      final session = Map<String, dynamic>.from(response.first);
      if (mounted) {
        Navigator.pushNamed(context, '/media-player', arguments: session);
      }
    } catch (e) {
      debugPrint('Error playing linked session: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load session: $e')),
        );
      }
    }
  }

  Future<void> _addTaskAsync(Map<String, dynamic> newTask) async {
    final userId =
        _supabaseService.currentUser?.id; // Use SupabaseService's currentUser
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please log in to add tasks.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    final taskWithId = {
      ...newTask,
      "id": _uuid.v4(), // Generate a unique ID for the task
      "user_id": userId,
      "is_completed": 0, // Default to not completed
      "updated_at": DateTime.now().toIso8601String(),
    };

    try {
      await _supabaseService.createLocalTask(taskWithId);
      await _loadTasks();
      
      // Schedule alarm for wakeup tasks
      if (newTask['category'] == 'wakeup' && newTask['alarm_enabled'] == true) {
        _scheduleWakeupAlarm(taskWithId);
      }
      
      // Show interstitial ad with frequency capping (every 3 task adds)
      AdsService().showInterstitialAdWithCapping(InterstitialPlacement.taskAdded);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Task added successfully!'),
            backgroundColor: Theme.of(context).primaryColor,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding task: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add task: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
  /// Reschedule all wakeup alarms on app load (survives restart)
  void _rescheduleWakeupAlarms() {
    for (final task in _todayTasks) {
      if (task['category'] == 'wakeup' && task['alarm_enabled'] == true) {
        _scheduleWakeupAlarm(task);
      }
    }
  }

  /// Schedule wakeup alarm for a task
  void _scheduleWakeupAlarm(Map<String, dynamic> task) async {
    try {
      final timeStr = task['scheduledTime'] as String? ?? task['time'] as String?;
      if (timeStr == null) return;

      // Parse time string (format: "5:00 AM" or "17:00")
      final now = DateTime.now();
      TimeOfDay? timeOfDay;
      
      // Handle 12-hour format (e.g. "5:00 AM")
      final amPmMatch = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)', caseSensitive: false).firstMatch(timeStr);
      if (amPmMatch != null) {
        int hour = int.parse(amPmMatch.group(1)!);
        final minute = int.parse(amPmMatch.group(2)!);
        final period = amPmMatch.group(3)!.toUpperCase();
        
        if (period == 'PM' && hour != 12) hour += 12;
        if (period == 'AM' && hour == 12) hour = 0;
        
        timeOfDay = TimeOfDay(hour: hour, minute: minute);
      } else {
        // Handle 24-hour format (e.g. "17:00")
        final parts = timeStr.split(':');
        if (parts.length == 2) {
          timeOfDay = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 5,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
      
      if (timeOfDay == null) return;

      // Calculate alarm time — if the time already passed today, schedule for tomorrow
      var alarmTime = DateTime(now.year, now.month, now.day, timeOfDay.hour, timeOfDay.minute);
      if (alarmTime.isBefore(now)) {
        alarmTime = alarmTime.add(const Duration(days: 1));
      }

      final taskId = task['id'] as String;
      final soundId = task['alarm_sound'] as String? ?? 'gentle_morning';
      final taskTitle = task['title'] as String? ?? 'Wake Up';

      final success = await AlarmService().scheduleWakeupAlarm(
        taskId: taskId,
        alarmTime: alarmTime,
        soundId: soundId,
        taskTitle: taskTitle,
      );

      if (success && mounted) {
        debugPrint('Wakeup alarm scheduled for $taskTitle at $alarmTime');
      }
    } catch (e) {
      debugPrint('Failed to schedule wakeup alarm: $e');
    }
  }

  Future<void> _deleteTask(String taskId) async {
    try {
      // Cancel any alarm for this task before deleting
      await AlarmService().cancelAlarm(taskId);

      await _supabaseService.deleteLocalTask(taskId);
      await _loadTasks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Task deleted successfully'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting task: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete task: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
