import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'supabase_service.dart';

class RoutineService {
  static final RoutineService _instance = RoutineService._internal();
  factory RoutineService() => _instance;
  RoutineService._internal();

  final SupabaseService _supabaseService = SupabaseService();
  final Uuid _uuid = Uuid();

  /// Creates a personalized default routine based on user preferences
  Future<void> createDefaultRoutine({
    required String userId,
    required String userName,
    required String ageGroup,
    required List<String> goals,
    required TimeOfDay wakeTime,
    required TimeOfDay sleepTime,
  }) async {
    try {
      debugPrint('Creating default routine for user: $userName');

      // Generate routine tasks based on user preferences
      final routineTasks = _generatePersonalizedTasks(
        userName: userName,
        ageGroup: ageGroup,
        goals: goals,
        wakeTime: wakeTime,
        sleepTime: sleepTime,
      );

      // Create tasks in database
      for (final task in routineTasks) {
        await _createTask(userId, task);
      }

      debugPrint(
          'Successfully created ${routineTasks.length} default routine tasks');
    } catch (e) {
      debugPrint('Error creating default routine: $e');
      rethrow;
    }
  }

  /// Generates personalized tasks based on user preferences
  List<Map<String, dynamic>> _generatePersonalizedTasks({
    required String userName,
    required String ageGroup,
    required List<String> goals,
    required TimeOfDay wakeTime,
    required TimeOfDay sleepTime,
  }) {
    final List<Map<String, dynamic>> tasks = [];

    // Morning routine (based on wake time)
    tasks.addAll(_generateMorningRoutine(wakeTime, goals));

    // Day routine (based on age group and goals)
    tasks.addAll(_generateDayRoutine(ageGroup, goals, wakeTime));

    // Evening routine (based on sleep time)
    tasks.addAll(_generateEveningRoutine(sleepTime, goals));

    return tasks;
  }

  /// Generates morning routine tasks
  List<Map<String, dynamic>> _generateMorningRoutine(
      TimeOfDay wakeTime, List<String> goals) {
    final List<Map<String, dynamic>> morningTasks = [];

    // Wake up task
    morningTasks.add({
      'title': 'Good Morning! 🌅',
      'description': 'Start your day with gratitude and positive energy',
      'time': _formatTime(wakeTime),
      'category': 'morning',
      'priority': 1,
    });

    // Meditation (if mindfulness goal is selected)
    if (goals.contains('Mindfulness') || goals.contains('Stress Relief')) {
      morningTasks.add({
        'title': 'Morning Meditation 🧘‍♀️',
        'description': 'Center yourself for the day ahead',
        'time': _formatTime(_addMinutes(wakeTime, 10)),
        'category': 'meditation',
        'priority': 2,
      });
    }

    // Exercise (if fitness goal is selected)
    if (goals.contains('Physical Fitness') || goals.contains('Energy Boost')) {
      morningTasks.add({
        'title': 'Morning Exercise 💪',
        'description': 'Get your blood flowing and energy up',
        'time': _formatTime(_addMinutes(wakeTime, 25)),
        'category': 'exercise',
        'priority': 2,
      });
    }

    // Breakfast
    morningTasks.add({
      'title': 'Healthy Breakfast 🥗',
      'description': 'Fuel your body with nutritious food',
      'time': _formatTime(_addMinutes(wakeTime, 45)),
      'category': 'nutrition',
      'priority': 3,
    });

    return morningTasks;
  }

  /// Generates day routine tasks based on age group
  List<Map<String, dynamic>> _generateDayRoutine(
      String ageGroup, List<String> goals, TimeOfDay wakeTime) {
    final List<Map<String, dynamic>> dayTasks = [];

    // Work/Study session (if focus goal is selected)
    if (goals.contains('Focus & Productivity')) {
      dayTasks.add({
        'title': 'Deep Work Session 🎯',
        'description': 'Focused work or study time',
        'time': _formatTime(_addMinutes(wakeTime, 90)),
        'category': 'work',
        'priority': 2,
      });
    }

    // Midday break
    dayTasks.add({
      'title': 'Midday Break ☀️',
      'description': 'Take a moment to rest and recharge',
      'time': _formatTime(_addMinutes(wakeTime, 240)), // 4 hours after wake up
      'category': 'break',
      'priority': 3,
    });

    // Afternoon activity based on age group
    if (ageGroup == 'Student') {
      dayTasks.add({
        'title': 'Study Session 📚',
        'description': 'Review and prepare for tomorrow',
        'time': _formatTime(_addMinutes(wakeTime, 300)),
        'category': 'study',
        'priority': 2,
      });
    } else if (ageGroup == 'Professional') {
      dayTasks.add({
        'title': 'Work Tasks 💼',
        'description': 'Complete important work assignments',
        'time': _formatTime(_addMinutes(wakeTime, 300)),
        'category': 'work',
        'priority': 2,
      });
    } else if (ageGroup == 'Elder') {
      dayTasks.add({
        'title': 'Gentle Activity 🚶‍♀️',
        'description': 'Light walk or gentle movement',
        'time': _formatTime(_addMinutes(wakeTime, 300)),
        'category': 'exercise',
        'priority': 3,
      });
    }

    return dayTasks;
  }

  /// Generates evening routine tasks
  List<Map<String, dynamic>> _generateEveningRoutine(
      TimeOfDay sleepTime, List<String> goals) {
    final List<Map<String, dynamic>> eveningTasks = [];

    // Dinner
    eveningTasks.add({
      'title': 'Evening Meal 🍽️',
      'description': 'Enjoy a light, healthy dinner',
      'time':
          _formatTime(_subtractMinutes(sleepTime, 120)), // 2 hours before sleep
      'category': 'nutrition',
      'priority': 3,
    });

    // Evening relaxation
    if (goals.contains('Stress Relief') || goals.contains('Better Sleep')) {
      eveningTasks.add({
        'title': 'Evening Relaxation 🌙',
        'description': 'Wind down and prepare for rest',
        'time': _formatTime(_subtractMinutes(sleepTime, 60)),
        'category': 'relaxation',
        'priority': 2,
      });
    }

    // Journaling (if mindfulness goal is selected)
    if (goals.contains('Mindfulness') || goals.contains('Emotional Balance')) {
      eveningTasks.add({
        'title': 'Evening Reflection 📝',
        'description': 'Reflect on your day and write in your journal',
        'time': _formatTime(_subtractMinutes(sleepTime, 30)),
        'category': 'journal',
        'priority': 3,
      });
    }

    // Sleep preparation
    eveningTasks.add({
      'title': 'Prepare for Sleep 😴',
      'description': 'Get ready for a restful night',
      'time': _formatTime(_subtractMinutes(sleepTime, 15)),
      'category': 'sleep',
      'priority': 1,
    });

    return eveningTasks;
  }

  /// Creates a task in the database
  Future<void> _createTask(String userId, Map<String, dynamic> taskData) async {
    final task = {
      'id': _uuid.v4(),
      'user_id': userId,
      'title': taskData['title'],
      'description': taskData['description'],
      'category': taskData['category'],
      'time': taskData['time'],
      'priority': taskData['priority'],
      'is_completed': false,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      await _supabaseService.createLocalTask(task);
    } catch (e) {
      debugPrint('Error creating task: $e');
      rethrow;
    }
  }

  /// Helper method to format time
  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Helper method to add minutes to time
  TimeOfDay _addMinutes(TimeOfDay time, int minutes) {
    final totalMinutes = time.hour * 60 + time.minute + minutes;
    final newHour = (totalMinutes ~/ 60) % 24;
    final newMinute = totalMinutes % 60;
    return TimeOfDay(hour: newHour, minute: newMinute);
  }

  /// Helper method to subtract minutes from time
  TimeOfDay _subtractMinutes(TimeOfDay time, int minutes) {
    final totalMinutes = time.hour * 60 + time.minute - minutes;
    if (totalMinutes < 0) {
      final adjustedMinutes = totalMinutes + (24 * 60);
      final newHour = (adjustedMinutes ~/ 60) % 24;
      final newMinute = adjustedMinutes % 60;
      return TimeOfDay(hour: newHour, minute: newMinute);
    }
    final newHour = (totalMinutes ~/ 60) % 24;
    final newMinute = totalMinutes % 60;
    return TimeOfDay(hour: newHour, minute: newMinute);
  }
}
