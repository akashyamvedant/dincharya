import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:uuid/uuid.dart'; // For generating unique IDs

import '../../core/app_export.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../../services/routine_tracking_service.dart';
import './widgets/add_task_bottom_sheet.dart';
import './widgets/empty_routine_widget.dart';
import './widgets/routine_header_widget.dart';
import './widgets/task_card_widget.dart';
import './widgets/activity_tracking_dialog.dart';

class RoutineDashboard extends StatefulWidget {
  const RoutineDashboard({super.key});

  @override
  State<RoutineDashboard> createState() => _RoutineDashboardState();
}

class _RoutineDashboardState extends State<RoutineDashboard>
    with TickerProviderStateMixin {
  int _currentTabIndex = 0;
  bool _isLoading = false;
  int _streakCount = 0; // Dynamic streak count
  
  // Remove selectedProfile - not used properly
  // String _selectedProfile = 'Village Life';

  List<Map<String, dynamic>> _todayTasks = [];
  final SupabaseService _supabaseService = SupabaseService();
  final RoutineTrackingService _trackingService = RoutineTrackingService();
  final Uuid _uuid = Uuid();

  // Remove unused profiles - feature not implemented
  // final List<String> _routineProfiles = ['Village Life', 'City Life', 'Student Life'];
  final List<String> _tabLabels = ['Routine', 'Guided', 'Journal', 'Me'];

  @override
  void initState() {
    super.initState();
    _initializeTracking();
    _loadTasks();
    _calculateStreak();
  }

  // Calculate user's current streak
  Future<void> _calculateStreak() async {
    try {
      final history = await _trackingService.getTrackingHistory();
      // Calculate streak from history
      int streak = 0;
      final today = DateTime.now();
      
      for (int i = 0; i < 365; i++) {
        final checkDate = today.subtract(Duration(days: i));
        final dateStr = checkDate.toIso8601String().split('T')[0];
        
        final dayCompleted = history.any((entry) =>
            entry['date'] == dateStr && entry['completed'] == true);
        
        if (dayCompleted) {
          streak++;
        } else if (i > 0) {
          // Break streak if a day is missed (except today)
          break;
        }
      }
      
      if (mounted) {
        setState(() {
          _streakCount = streak;
        });
      }
    } catch (e) {
      debugPrint('Error calculating streak: $e');
    }
  }

  Future<void> _initializeTracking() async {
    await _trackingService.initialize();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final authService = AuthService();
      final isLoggedIn = await authService.isUserLoggedIn();

      if (isLoggedIn) {
        final userId = _supabaseService.currentUser?.id;
        if (userId != null) {
          final tasks = await _supabaseService.getLocalTasks(userId);
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
              content:
                  const Text('Please sign in to view and manage your routine.'),
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

      // Schedule notifications for today's tasks
      await _scheduleTaskNotifications();
    }
  }

  // Schedule notifications for today's tasks
  Future<void> _scheduleTaskNotifications() async {
    try {
      final routine = {
        'activities': _todayTasks
            .map((task) => {
                  'name': task['title'] ?? 'Task',
                  'time': task['scheduled_time'] ?? '09:00',
                })
            .toList(),
      };

      await _trackingService.scheduleRoutineNotifications(routine);
      debugPrint('📅 Scheduled notifications for ${_todayTasks.length} tasks');
    } catch (e) {
      debugPrint('❌ Error scheduling notifications: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Sticky Header
            RoutineHeaderWidget(
              selectedProfile: 'Daily Routine', // Simplified - no profile switching
              routineProfiles: const [], // Empty - feature removed
              onProfileChanged: (_) {}, // No-op
              streakCount: _streakCount, // Dynamic streak!
            ),

            // Main Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                color: AppTheme.lightTheme.primaryColor,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _todayTasks.isEmpty
                        ? const EmptyRoutineWidget()
                        : ListView(
                            padding: EdgeInsets.symmetric(vertical: 2.h),
                            children: [
                              // Today's Tasks Header
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4.w),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.today,
                                      color: AppTheme
                                          .lightTheme.colorScheme.primary,
                                      size: 24,
                                    ),
                                    SizedBox(width: 2.w),
                                    Text(
                                      'Today\'s Tasks',
                                      style: AppTheme
                                          .lightTheme.textTheme.titleLarge
                                          ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${_todayTasks.length} tasks',
                                      style: AppTheme
                                          .lightTheme.textTheme.bodyMedium
                                          ?.copyWith(
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: 2.h),

                              // Tasks List
                              ..._todayTasks
                                  .map((task) => Container(
                                        margin: EdgeInsets.symmetric(
                                            horizontal: 4.w, vertical: 1.h),
                                        child: TaskCardWidget(
                                          task: task,
                                          onTaskCompleted: () =>
                                              _onTaskCompleted(
                                                  task["id"],
                                                  task["is_completed"] as int ==
                                                      1),
                                          onTaskEdit: () =>
                                              _onTaskEdit(task["id"]),
                                          onTaskReschedule: () =>
                                              _onTaskReschedule(task["id"]),
                                          onTaskDelete: () =>
                                              _onTaskDelete(task["id"]),
                                          onTaskTrack: () =>
                                              _showTrackingDialog(task),
                                        ),
                                      ))
                                  ,

                              SizedBox(height: 8.h), // Space for FAB
                            ],
                          ),
              ),
            ),
          ],
        ),
      ),

      // Bottom Navigation
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: _onTabChanged,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        selectedItemColor: AppTheme.lightTheme.primaryColor,
        unselectedItemColor: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
        elevation: 8.0,
        items: [
          BottomNavigationBarItem(
            icon: CustomIconWidget(
              iconName: 'schedule',
              color: _currentTabIndex == 0
                  ? AppTheme.lightTheme.primaryColor
                  : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              size: 24,
            ),
            label: _tabLabels[0],
          ),
          BottomNavigationBarItem(
            icon: CustomIconWidget(
              iconName: 'self_improvement',
              color: _currentTabIndex == 1
                  ? AppTheme.lightTheme.primaryColor
                  : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              size: 24,
            ),
            label: _tabLabels[1],
          ),
          BottomNavigationBarItem(
            icon: CustomIconWidget(
              iconName: 'book',
              color: _currentTabIndex == 2
                  ? AppTheme.lightTheme.primaryColor
                  : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              size: 24,
            ),
            label: _tabLabels[2],
          ),
          BottomNavigationBarItem(
            icon: CustomIconWidget(
              iconName: 'person',
              color: _currentTabIndex == 3
                  ? AppTheme.lightTheme.primaryColor
                  : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              size: 24,
            ),
            label: _tabLabels[3],
          ),
        ],
      ),

      // Floating Action Button
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskBottomSheet,
        backgroundColor: AppTheme.lightTheme.colorScheme.tertiary,
        foregroundColor: AppTheme.lightTheme.colorScheme.onTertiary,
        elevation: 6.0,
        child: CustomIconWidget(
          iconName: 'add',
          color: AppTheme.lightTheme.colorScheme.onTertiary,
          size: 28,
        ),
      ),
    );
  }

  // Removed broken profile change method
  // void _onProfileChanged(String? newProfile) { ... }

  Future<void> _onRefresh() async {
    await _loadTasks();
    await _calculateStreak(); // Refresh streak too
  }

  Future<void> _onTaskCompleted(String taskId, bool isCompleted) async {
    final userId =
        _supabaseService.currentUser?.id; // Use SupabaseService's currentUser
    if (userId == null) return;

    final updatedStatus = isCompleted ? 0 : 1; // Toggle completion status
    final updates = {
      'is_completed': updatedStatus,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      await _supabaseService.updateLocalTask(taskId, updates);
      await _loadTasks();
      await _calculateStreak(); // Update streak after completion
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Task ${updatedStatus == 1 ? "completed" : "marked incomplete"}!'),
            duration: const Duration(seconds: 2),
            backgroundColor: AppTheme.lightTheme.primaryColor,
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

  void _onTaskEdit(String taskId) {
    // Show edit dialog instead of navigation
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Task'),
        content: const Text(
            'Task editing feature is coming soon.\nFor now, you can delete and create a new task.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _onTaskReschedule(String taskId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reschedule Task'),
        content:
            const Text('Task rescheduling feature will be available soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
    // Don't update currentTabIndex - let each screen handle its own state
    switch (index) {
      case 0:
        // Already on Routine tab - do nothing
        break;
      case 1:
        Navigator.pushNamed(context, AppRoutes.guidedSessionsHub);
        break;
      case 2:
        Navigator.pushNamed(context, AppRoutes.journalMoodTracker);
        break;
      case 3:
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Task added successfully!'),
            backgroundColor: AppTheme.lightTheme.primaryColor,
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

  Future<void> _deleteTask(String taskId) async {
    try {
      await _supabaseService.deleteLocalTask(taskId);
      await _loadTasks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Task deleted successfully'),
            backgroundColor: AppTheme.lightTheme.colorScheme.error,
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
