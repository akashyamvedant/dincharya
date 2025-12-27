import 'package:flutter/foundation.dart';

import './supabase_service.dart';

// lib/services/local_tasks_service.dart

class LocalTasksService {
  static final LocalTasksService _instance = LocalTasksService._internal();
  factory LocalTasksService() => _instance;
  LocalTasksService._internal();

  final SupabaseService _supabase = SupabaseService();

  // Get all local tasks for current user
  Future<List<Map<String, dynamic>>> getLocalTasks() async {
    try {
      final currentUser = _supabase.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final tasks = await _supabase.getLocalTasks(currentUser.id);
      return List<Map<String, dynamic>>.from(tasks);
    } catch (e) {
      debugPrint('Failed to get local tasks: $e');
      throw Exception('Failed to load tasks: ${e.toString()}');
    }
  }

  // Create a new local task
  Future<Map<String, dynamic>> createLocalTask({
    required String title,
    required String description,
    String category = 'local_work',
    DateTime? dueDate,
    int priority = 1,
  }) async {
    try {
      final currentUser = _supabase.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final taskData = {
        'user_id': currentUser.id,
        'title': title,
        'description': description,
        'category': category,
        'due_date': dueDate?.toIso8601String(),
        'priority': priority,
        'status': 'pending',
        'is_completed': false,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final result = await _supabase.createLocalTask(taskData);
      if (result.isNotEmpty) {
        return {
          'success': true,
          'task': result.first,
          'message': 'Task created successfully',
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to create task',
        };
      }
    } catch (e) {
      debugPrint('Failed to create local task: $e');
      return {
        'success': false,
        'message': 'Failed to create task: ${e.toString()}',
      };
    }
  }

  // Update a local task
  Future<Map<String, dynamic>> updateLocalTask(
    String taskId, {
    String? title,
    String? description,
    String? category,
    DateTime? dueDate,
    int? priority,
    String? status,
    bool? isCompleted,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (category != null) updates['category'] = category;
      if (dueDate != null) updates['due_date'] = dueDate.toIso8601String();
      if (priority != null) updates['priority'] = priority;
      if (status != null) updates['status'] = status;
      if (isCompleted != null) {
        updates['is_completed'] = isCompleted;
        if (isCompleted) {
          updates['completed_at'] = DateTime.now().toIso8601String();
          updates['status'] = 'completed';
        } else {
          updates['completed_at'] = null;
          updates['status'] = 'pending';
        }
      }

      final result = await _supabase.updateLocalTask(taskId, updates);
      if (result.isNotEmpty) {
        return {
          'success': true,
          'task': result.first,
          'message': 'Task updated successfully',
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to update task',
        };
      }
    } catch (e) {
      debugPrint('Failed to update local task: $e');
      return {
        'success': false,
        'message': 'Failed to update task: ${e.toString()}',
      };
    }
  }

  // Mark task as completed
  Future<Map<String, dynamic>> completeTask(String taskId) async {
    return await updateLocalTask(
      taskId,
      isCompleted: true,
    );
  }

  // Mark task as pending
  Future<Map<String, dynamic>> markTaskPending(String taskId) async {
    return await updateLocalTask(
      taskId,
      isCompleted: false,
    );
  }

  // Delete a local task
  Future<Map<String, dynamic>> deleteLocalTask(String taskId) async {
    try {
      await _supabase.deleteLocalTask(taskId);
      return {
        'success': true,
        'message': 'Task deleted successfully',
      };
    } catch (e) {
      debugPrint('Failed to delete local task: $e');
      return {
        'success': false,
        'message': 'Failed to delete task: ${e.toString()}',
      };
    }
  }

  // Get tasks by category
  Future<List<Map<String, dynamic>>> getTasksByCategory(String category) async {
    try {
      final allTasks = await getLocalTasks();
      return allTasks.where((task) => task['category'] == category).toList();
    } catch (e) {
      debugPrint('Failed to get tasks by category: $e');
      return [];
    }
  }

  // Get completed tasks
  Future<List<Map<String, dynamic>>> getCompletedTasks() async {
    try {
      final allTasks = await getLocalTasks();
      return allTasks.where((task) => task['is_completed'] == true).toList();
    } catch (e) {
      debugPrint('Failed to get completed tasks: $e');
      return [];
    }
  }

  // Get pending tasks
  Future<List<Map<String, dynamic>>> getPendingTasks() async {
    try {
      final allTasks = await getLocalTasks();
      return allTasks.where((task) => task['is_completed'] == false).toList();
    } catch (e) {
      debugPrint('Failed to get pending tasks: $e');
      return [];
    }
  }

  // Get overdue tasks
  Future<List<Map<String, dynamic>>> getOverdueTasks() async {
    try {
      final allTasks = await getLocalTasks();
      final now = DateTime.now();

      return allTasks.where((task) {
        if (task['is_completed'] == true) return false;

        final dueDateStr = task['due_date'] as String?;
        if (dueDateStr == null) return false;

        final dueDate = DateTime.parse(dueDateStr);
        return dueDate.isBefore(now);
      }).toList();
    } catch (e) {
      debugPrint('Failed to get overdue tasks: $e');
      return [];
    }
  }

  // Get task statistics
  Future<Map<String, int>> getTaskStatistics() async {
    try {
      final allTasks = await getLocalTasks();

      int totalTasks = allTasks.length;
      int completedTasks =
          allTasks.where((task) => task['is_completed'] == true).length;
      int pendingTasks =
          allTasks.where((task) => task['is_completed'] == false).length;
      int overdueTasks = 0;

      final now = DateTime.now();
      for (final task in allTasks) {
        if (task['is_completed'] == true) continue;

        final dueDateStr = task['due_date'] as String?;
        if (dueDateStr == null) continue;

        final dueDate = DateTime.parse(dueDateStr);
        if (dueDate.isBefore(now)) {
          overdueTasks++;
        }
      }

      return {
        'total': totalTasks,
        'completed': completedTasks,
        'pending': pendingTasks,
        'overdue': overdueTasks,
      };
    } catch (e) {
      debugPrint('Failed to get task statistics: $e');
      return {
        'total': 0,
        'completed': 0,
        'pending': 0,
        'overdue': 0,
      };
    }
  }

  // Search tasks
  Future<List<Map<String, dynamic>>> searchTasks(String query) async {
    try {
      final allTasks = await getLocalTasks();
      final lowercaseQuery = query.toLowerCase();

      return allTasks.where((task) {
        final title = (task['title'] as String? ?? '').toLowerCase();
        final description =
            (task['description'] as String? ?? '').toLowerCase();
        final category = (task['category'] as String? ?? '').toLowerCase();

        return title.contains(lowercaseQuery) ||
            description.contains(lowercaseQuery) ||
            category.contains(lowercaseQuery);
      }).toList();
    } catch (e) {
      debugPrint('Failed to search tasks: $e');
      return [];
    }
  }
}
