// lib/presentation/local_tasks/widgets/task_card_widget.dart
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

class TaskCardWidget extends StatelessWidget {
  final Map<String, dynamic> task;
  final Function(String) onTaskCompleted;
  final Function(String) onTaskDeleted;
  final Function(Map<String, dynamic>) onTaskEdited;

  const TaskCardWidget({
    super.key,
    required this.task,
    required this.onTaskCompleted,
    required this.onTaskDeleted,
    required this.onTaskEdited,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = task['is_completed'] ?? false;
    final String title = task['title'] ?? 'Untitled Task';
    final String description = task['description'] ?? '';
    final String category = task['category'] ?? 'General';
    final String priority = task['priority'] ?? 'Medium';
    final String? dueDateStr = task['due_date'];
    final String taskId = task['id'] ?? '';

    DateTime? dueDate;
    if (dueDateStr != null && dueDateStr.isNotEmpty) {
      try {
        dueDate = DateTime.parse(dueDateStr);
      } catch (e) {
        // Invalid date format
      }
    }

    final bool isOverdue =
        dueDate != null && dueDate.isBefore(DateTime.now()) && !isCompleted;

    return Card(
        margin: EdgeInsets.symmetric(vertical: 1.h, horizontal: 0),
        elevation: isCompleted ? 1.0 : 2.0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isOverdue
                ? BorderSide(color: Colors.red.withAlpha(128), width: 1)
                : BorderSide.none),
        child: Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isCompleted
                    ? Theme.of(context).colorScheme.surface.withAlpha(179)
                    : Theme.of(context).colorScheme.surface),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header Row
              Row(children: [
                // Priority Indicator
                Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                        color: _getPriorityColor(priority),
                        borderRadius: BorderRadius.circular(2))),

                SizedBox(width: 3.w),

                // Task Content
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      // Title
                      Text(title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isCompleted
                                      ? Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                      : Theme.of(context).colorScheme.onSurface,
                                  decoration: isCompleted
                                      ? TextDecoration.lineThrough
                                      : null),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),

                      if (description.isNotEmpty) ...[
                        SizedBox(height: 0.5.h),
                        Text(description,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    decoration: isCompleted
                                        ? TextDecoration.lineThrough
                                        : null),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ])),

                SizedBox(width: 2.w),

                // Completion Checkbox
                GestureDetector(
                    onTap: () => onTaskCompleted(taskId),
                    child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: isCompleted
                                    ? Colors.green
                                    : Theme.of(context).colorScheme.outline,
                                width: 2),
                            color: isCompleted
                                ? Colors.green
                                : Colors.transparent),
                        child: isCompleted
                            ? Icon(Icons.check, color: Colors.white, size: 16)
                            : null)),

                SizedBox(width: 2.w),

                // Menu Button
                PopupMenuButton<String>(
                    icon: CustomIconWidget(
                        iconName: 'more_vert',
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 20),
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onTaskEdited(task);
                          break;
                        case 'delete':
                          onTaskDeleted(taskId);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                          PopupMenuItem(
                              value: 'edit',
                              child: Row(children: [
                                CustomIconWidget(
                                    iconName: 'edit',
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 18),
                                SizedBox(width: 2.w),
                                const Text('Edit'),
                              ])),
                          PopupMenuItem(
                              value: 'delete',
                              child: Row(children: [
                                CustomIconWidget(
                                    iconName: 'delete',
                                    color: Colors.red,
                                    size: 18),
                                SizedBox(width: 2.w),
                                const Text('Delete'),
                              ])),
                        ]),
              ]),

              // Footer Row
              SizedBox(height: 1.h),
              Row(children: [
                // Category
                Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                    decoration: BoxDecoration(
                        color: _getCategoryColor(category).withAlpha(26),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _getCategoryColor(category).withAlpha(77))),
                    child: Text(category,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: _getCategoryColor(category),
                            fontWeight: FontWeight.w500))),

                SizedBox(width: 2.w),

                // Priority
                Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                    decoration: BoxDecoration(
                        color: _getPriorityColor(priority).withAlpha(26),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _getPriorityColor(priority).withAlpha(77))),
                    child: Text(priority,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: _getPriorityColor(priority),
                            fontWeight: FontWeight.w500))),

                const Spacer(),

                // Due Date
                if (dueDate != null)
                  Row(children: [
                    CustomIconWidget(
                        iconName: isOverdue ? 'warning' : 'schedule',
                        color: isOverdue
                            ? Colors.red
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 14),
                    SizedBox(width: 1.w),
                    Text(_formatDueDate(dueDate),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: isOverdue
                                ? Colors.red
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                            fontWeight: isOverdue
                                ? FontWeight.w600
                                : FontWeight.normal)),
                  ]),
              ]),

              // Overdue Warning
              if (isOverdue) ...[
                SizedBox(height: 1.h),
                Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                    decoration: BoxDecoration(
                        color: Colors.red.withAlpha(26),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.withAlpha(77))),
                    child: Row(children: [
                      CustomIconWidget(
                          iconName: 'warning', color: Colors.red, size: 14),
                      SizedBox(width: 1.w),
                      Text('Task is overdue',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w500)),
                    ])),
              ],
            ])));
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.blue;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'work':
        return Colors.blue;
      case 'personal':
        return Colors.purple;
      case 'health':
        return Colors.green;
      case 'education':
        return Colors.orange;
      case 'shopping':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String _formatDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (taskDate == today) {
      return 'Today ${dueDate.hour.toString().padLeft(2, '0')}:${dueDate.minute.toString().padLeft(2, '0')}';
    } else if (taskDate == today.add(const Duration(days: 1))) {
      return 'Tomorrow';
    } else if (taskDate.isBefore(today)) {
      final difference = today.difference(taskDate).inDays;
      return '$difference day${difference > 1 ? 's' : ''} ago';
    } else {
      return '${dueDate.day}/${dueDate.month}';
    }
  }
}
