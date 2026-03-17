import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../services/local_tasks_service.dart';
import '../../widgets/custom_icon_widget.dart';
import './widgets/task_statistics_widget.dart';
import 'widgets/add_task_bottom_sheet.dart';
import 'widgets/task_card_widget.dart';

// lib/presentation/local_tasks/local_tasks_screen.dart

class LocalTasksScreen extends StatefulWidget {
  const LocalTasksScreen({super.key});

  @override
  State<LocalTasksScreen> createState() => _LocalTasksScreenState();
}

class _LocalTasksScreenState extends State<LocalTasksScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final LocalTasksService _tasksService = LocalTasksService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allTasks = [];
  List<Map<String, dynamic>> _filteredTasks = [];
  Map<String, int> _statistics = {};
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadTasks();
    _loadStatistics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final tasks = await _tasksService.getLocalTasks();
      setState(() {
        _allTasks = tasks;
        _filterTasks();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to load tasks: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStatistics() async {
    try {
      final stats = await _tasksService.getTaskStatistics();
      setState(() {
        _statistics = stats;
      });
    } catch (e) {
      debugPrint('Failed to load statistics: $e');
    }
  }

  void _filterTasks() {
    List<Map<String, dynamic>> filtered = _allTasks;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((task) {
        final title = (task['title'] as String? ?? '').toLowerCase();
        final description =
            (task['description'] as String? ?? '').toLowerCase();
        final category = (task['category'] as String? ?? '').toLowerCase();
        final query = _searchQuery.toLowerCase();

        return title.contains(query) ||
            description.contains(query) ||
            category.contains(query);
      }).toList();
    }

    // Apply tab filter
    switch (_tabController.index) {
      case 0: // All tasks
        break;
      case 1: // Pending
        filtered =
            filtered.where((task) => task['is_completed'] == false).toList();
        break;
      case 2: // Completed
        filtered =
            filtered.where((task) => task['is_completed'] == true).toList();
        break;
      case 3: // Overdue
        final now = DateTime.now();
        filtered = filtered.where((task) {
          if (task['is_completed'] == true) return false;

          final dueDateStr = task['due_date'] as String?;
          if (dueDateStr == null) return false;

          final dueDate = DateTime.parse(dueDateStr);
          return dueDate.isBefore(now);
        }).toList();
        break;
    }

    setState(() {
      _filteredTasks = filtered;
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _filterTasks();
  }

  void _addTask(Map<String, dynamic> taskData) {
    _loadTasks();
    _loadStatistics();
  }

  void _completeTask(String taskId) async {
    try {
      final result = await _tasksService.completeTask(taskId);
      if (result['success']) {
        _loadTasks();
        _loadStatistics();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(result['message']),
              backgroundColor: Theme.of(context).colorScheme.tertiary));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to complete task: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error));
      }
    }
  }

  void _deleteTask(String taskId) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Delete Task'),
                content:
                    const Text('Are you sure you want to delete this task?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel')),
                  ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Delete')),
                ]));

    if (confirmed == true) {
      try {
        final result = await _tasksService.deleteLocalTask(taskId);

        if (result['success']) {
          _loadTasks();
          _loadStatistics();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(result['message']),
                backgroundColor: Theme.of(context).colorScheme.tertiary));
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(result['message']),
                backgroundColor: Theme.of(context).colorScheme.error));
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Failed to delete task: ${e.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.error));
        }
      }
    }
  }

  void _editTask(Map<String, dynamic> taskData) {
    _loadTasks();
    _loadStatistics();
  }

  void _showAddTaskBottomSheet() {
    // Fixed onTaskAdded callback to match expected signature
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddTaskBottomSheet(
        onTaskAdded: (Map<String, dynamic> taskData) {
          _addTask(taskData);
        },
      ),
    );
  }

  // Removed unused method _toggleTaskCompletion

  // Removed unused method _deleteTaskByObject

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: Text('Local Work & Tasks',
                style: Theme.of(context).textTheme.titleLarge),
            actions: [
              IconButton(
                  onPressed: _loadTasks,
                  icon: CustomIconWidget(
                      iconName: 'refresh',
                      color: Theme.of(context).colorScheme.primary,
                      size: 24)),
            ],
            bottom: TabBar(
                controller: _tabController,
                onTap: (index) => _filterTasks(),
                tabs: [
                  Tab(text: 'All (${_statistics['total'] ?? 0})'),
                  Tab(text: 'Pending (${_statistics['pending'] ?? 0})'),
                  Tab(text: 'Done (${_statistics['completed'] ?? 0})'),
                  Tab(text: 'Overdue (${_statistics['overdue'] ?? 0})'),
                ])),
        body: Column(children: [
          // Statistics
          TaskStatisticsWidget(statistics: _statistics),

          // Search Bar
          Container(
              padding: EdgeInsets.all(4.w),
              child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                      hintText: 'Search tasks...',
                      prefixIcon: Padding(
                          padding: EdgeInsets.all(3.w),
                          child: CustomIconWidget(
                              iconName: 'search',
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              size: 20)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                              icon: CustomIconWidget(
                                  iconName: 'clear',
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  size: 20))
                          : null),
                  onChanged: _onSearchChanged)),

          // Tasks List
          Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredTasks.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: () async {
                            await _loadTasks();
                            await _loadStatistics();
                          },
                          child: ListView.builder(
                              padding: EdgeInsets.symmetric(horizontal: 4.w),
                              itemCount: _filteredTasks.length,
                              itemBuilder: (context, index) {
                                final task = _filteredTasks[index];
                                // Fixed TaskCardWidget constructor call
                                return TaskCardWidget(
                                  task: task,
                                  onTaskCompleted: (taskId) =>
                                      _completeTask(taskId),
                                  onTaskDeleted: (taskId) =>
                                      _deleteTask(taskId),
                                  onTaskEdited: (taskData) =>
                                      _editTask(taskData),
                                );
                              }))),
        ]),
        floatingActionButton: FloatingActionButton(
            onPressed: _showAddTaskBottomSheet,
            child: CustomIconWidget(
                iconName: 'add',
                color: Theme.of(context).colorScheme.onPrimary,
                size: 24)));
  }

  Widget _buildEmptyState() {
    String message;
    String suggestion;

    switch (_tabController.index) {
      case 1:
        message = 'No pending tasks';
        suggestion = 'Great! All tasks are completed';
        break;
      case 2:
        message = 'No completed tasks';
        suggestion = 'Complete some tasks to see them here';
        break;
      case 3:
        message = 'No overdue tasks';
        suggestion = 'Excellent! You are on track';
        break;
      default:
        message = 'No local tasks yet';
        suggestion = 'Add your first task to get started';
    }

    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      CustomIconWidget(
          iconName: 'task_alt',
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 64),
      SizedBox(height: 2.h),
      Text(message,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
      SizedBox(height: 1.h),
      Text(suggestion,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center),
    ]));
  }
}
