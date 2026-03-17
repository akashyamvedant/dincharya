import 'package:flutter/material.dart';

/// Unified task category system used across the entire app.
/// Categories are divided into "inevitable" (things user WILL do regardless)
/// and "timed" (activities that have a specific duration).
class TaskCategory {
  final String id;
  final String displayName;
  final String icon;
  final Color color;
  final bool hasDuration;    // Whether duration field should show
  final bool isInevitable;   // Whether this task happens regardless (wakeup, eat, sleep)
  final bool hasGuidedSessions; // Whether guided sessions can be linked (meditation, yoga, pranayama)

  const TaskCategory({
    required this.id,
    required this.displayName,
    required this.icon,
    required this.color,
    this.hasDuration = true,
    this.isInevitable = false,
    this.hasGuidedSessions = false,
  });

  /// All available task categories
  static const List<TaskCategory> all = [
    TaskCategory(
      id: 'wakeup',
      displayName: 'Wake Up',
      icon: 'wb_sunny',
      color: Color(0xFFF57F17),  // Amber
      hasDuration: false,
      isInevitable: true,
    ),
    TaskCategory(
      id: 'hygiene',
      displayName: 'Hygiene & Fresh',
      icon: 'shower',
      color: Color(0xFF00ACC1),  // Cyan
      hasDuration: false,
      isInevitable: true,
    ),
    TaskCategory(
      id: 'meditation',
      displayName: 'Meditation',
      icon: 'self_improvement',
      color: Color(0xFF7E57C2),  // Deep Purple
      hasDuration: true,
      isInevitable: false,
      hasGuidedSessions: true,
    ),
    TaskCategory(
      id: 'yoga',
      displayName: 'Yoga / Asana',
      icon: 'fitness_center',
      color: Color(0xFF5D4037),  // Brown (app primary)
      hasDuration: true,
      isInevitable: false,
      hasGuidedSessions: true,
    ),
    TaskCategory(
      id: 'pranayama',
      displayName: 'Pranayama',
      icon: 'air',
      color: Color(0xFF26A69A),  // Teal
      hasDuration: true,
      isInevitable: false,
      hasGuidedSessions: true,
    ),
    TaskCategory(
      id: 'exercise',
      displayName: 'Exercise',
      icon: 'directions_run',
      color: Color(0xFFE65100),  // Deep Orange
      hasDuration: true,
      isInevitable: false,
    ),
    TaskCategory(
      id: 'nutrition',
      displayName: 'Eating / Meal',
      icon: 'restaurant',
      color: Color(0xFF43A047),  // Green
      hasDuration: false,
      isInevitable: true,
    ),
    TaskCategory(
      id: 'study',
      displayName: 'Study',
      icon: 'menu_book',
      color: Color(0xFFFFA726),  // Orange
      hasDuration: true,
      isInevitable: false,
    ),
    TaskCategory(
      id: 'work',
      displayName: 'Work',
      icon: 'work',
      color: Color(0xFF1E88E5),  // Blue
      hasDuration: true,
      isInevitable: false,
    ),
    TaskCategory(
      id: 'journal',
      displayName: 'Journal',
      icon: 'edit_note',
      color: Color(0xFF8D6E63),  // Brown light
      hasDuration: true,
      isInevitable: false,
    ),
    TaskCategory(
      id: 'sleep',
      displayName: 'Sleep',
      icon: 'bedtime',
      color: Color(0xFF3949AB),  // Indigo
      hasDuration: false,
      isInevitable: true,
    ),
    TaskCategory(
      id: 'other',
      displayName: 'Other',
      icon: 'task_alt',
      color: Color(0xFF78909C),  // Blue Grey
      hasDuration: true,
      isInevitable: false,
    ),
  ];

  /// Find a category by its ID. Falls back to 'other' if not found.
  static TaskCategory findById(String? id) {
    if (id == null || id.isEmpty) return all.last; // 'other'
    return all.firstWhere(
      (c) => c.id == id.toLowerCase(),
      orElse: () => _matchLegacy(id),
    );
  }

  /// Map legacy category names to new system
  static TaskCategory _matchLegacy(String id) {
    switch (id.toLowerCase()) {
      case 'morning':
      case 'dainik':
        return findById('wakeup');
      case 'breathing':
        return findById('pranayama');
      case 'adhyatmik':
        return findById('meditation');
      case 'sharirik':
        return findById('exercise');
      case 'manasik':
        return findById('study');
      case 'relaxation':
      case 'break':
        return findById('other');
      default:
        return all.last; // 'other'
    }
  }

  /// Get color for a category ID
  static Color getColor(String? categoryId) => findById(categoryId).color;

  /// Get icon name for a category ID
  static String getIcon(String? categoryId) => findById(categoryId).icon;

  /// Check if a category is inevitable (user does it regardless)
  static bool isInevitableCategory(String? categoryId) =>
      findById(categoryId).isInevitable;

  /// Check if duration should be shown
  static bool showDuration(String? categoryId) =>
      findById(categoryId).hasDuration;
}
