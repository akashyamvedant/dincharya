// lib/services/quick_task_service.dart
// Local-only quick tasks stored in SharedPreferences.
// No Supabase — device-only storage for ad-hoc daily work items.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class QuickTask {
  final String id;
  final String title;
  final bool isCompleted;
  final DateTime createdAt;

  QuickTask({
    required this.id,
    required this.title,
    this.isCompleted = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  QuickTask copyWith({String? title, bool? isCompleted}) {
    return QuickTask(
      id: id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isCompleted': isCompleted,
        'createdAt': createdAt.toIso8601String(),
      };

  factory QuickTask.fromJson(Map<String, dynamic> json) => QuickTask(
        id: json['id'] as String,
        title: json['title'] as String,
        isCompleted: json['isCompleted'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

class QuickTaskService {
  static const String _storageKey = 'quick_tasks_v1';
  static final QuickTaskService _instance = QuickTaskService._internal();
  final Uuid _uuid = const Uuid();

  factory QuickTaskService() => _instance;
  QuickTaskService._internal();

  // ─── CRUD Operations ─────────────────────────────────

  /// Load all quick tasks, auto-clearing stale tasks from previous days.
  Future<List<QuickTask>> getTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return [];

      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final tasks = decoded
          .map((e) => QuickTask.fromJson(e as Map<String, dynamic>))
          .toList();

      // Auto-clear completed tasks from previous days
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final filtered = tasks.where((t) {
        // Keep all of today's tasks (completed or not)
        if (!t.createdAt.isBefore(todayStart)) return true;
        // Keep incomplete tasks from previous days (carry-over)
        return !t.isCompleted;
      }).toList();

      // Save back if anything was removed
      if (filtered.length != tasks.length) {
        await _saveTasks(filtered, prefs);
      }

      return filtered;
    } catch (e) {
      debugPrint('QuickTaskService.getTasks error: $e');
      return [];
    }
  }

  /// Add a new quick task. Returns the created task.
  Future<QuickTask> addTask(String title) async {
    final task = QuickTask(
      id: _uuid.v4(),
      title: title.trim(),
    );

    final tasks = await getTasks();
    tasks.add(task);
    await _saveTasks(tasks);
    return task;
  }

  /// Toggle completion status of a task.
  Future<void> toggleComplete(String taskId) async {
    final tasks = await getTasks();
    final index = tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    tasks[index] = tasks[index].copyWith(
      isCompleted: !tasks[index].isCompleted,
    );
    await _saveTasks(tasks);
  }

  /// Delete a single task.
  Future<void> deleteTask(String taskId) async {
    final tasks = await getTasks();
    tasks.removeWhere((t) => t.id == taskId);
    await _saveTasks(tasks);
  }

  /// Clear all completed tasks.
  Future<void> clearCompleted() async {
    final tasks = await getTasks();
    tasks.removeWhere((t) => t.isCompleted);
    await _saveTasks(tasks);
  }

  /// Clear all tasks.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  // ─── Internal ────────────────────────────────────────

  Future<void> _saveTasks(List<QuickTask> tasks,
      [SharedPreferences? prefs]) async {
    prefs ??= await SharedPreferences.getInstance();
    final encoded = jsonEncode(tasks.map((t) => t.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}
