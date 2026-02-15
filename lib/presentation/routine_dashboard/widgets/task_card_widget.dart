import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../services/task_lifecycle_service.dart';
import './animated_task_checkbox.dart';

class TaskCardWidget extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback onTaskCompleted;
  final VoidCallback onTaskEdit;
  final VoidCallback onTaskReschedule;
  final VoidCallback onTaskDelete;
  final VoidCallback? onTaskTrack;
  final String? nextTaskTime; // For completion window validation
  final String? sectionEndTime; // Section end time (12 PM, 5 PM, 10 PM)
  final void Function(String reason, String status)? onTapLocked; // Callback when locked task is tapped
  final bool isHighlighted; // Whether this task is highlighted (from notification tap)

  const TaskCardWidget({
    super.key,
    required this.task,
    required this.onTaskCompleted,
    required this.onTaskEdit,
    required this.onTaskReschedule,
    required this.onTaskDelete,
    this.onTaskTrack,
    this.nextTaskTime,
    this.sectionEndTime,
    this.onTapLocked,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    // Fix field mapping to match database schema
    final bool isCompleted = task["is_completed"] == true || 
                             task["is_completed"] == 1 ||
                             task["isCompleted"] == true;
    final double progress = (task["progress"] ?? 0.0).toDouble();
    final String title = task["title"] ?? "";
    final String duration = task["duration"] ?? "15 min";
    final String scheduledTime = task["time"] ?? task["scheduledTime"] ?? "";
    final String iconName = task["icon"] ?? _getIconForCategory(task["category"]);
    final String description = task["description"] ?? "";
    
    // Check if task is within valid completion window
    final bool isCompletable = TaskLifecycleService.isTaskCompletable(
      taskTime: scheduledTime,
      isCompleted: isCompleted,
      nextTaskTime: nextTaskTime,
    );
    final String blockReason = TaskLifecycleService.getCompletionBlockReason(
      taskTime: scheduledTime,
      isCompleted: isCompleted,
      nextTaskTime: nextTaskTime,
    );

    return Dismissible(
      key: Key('task_${task["id"]}'),
      background: _buildSwipeBackground(isLeftSwipe: false),
      secondaryBackground: _buildSwipeBackground(isLeftSwipe: true),
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          // Swipe right - Quick actions
          _showQuickActions(context);
        } else {
          // Swipe left - Delete
          onTaskDelete();
        }
      },
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          _showQuickActions(context);
          return false; // Don't dismiss, just show actions
        }
        return true; // Allow dismiss for delete
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isCompleted ? 0.7 : 1.0,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 300),
          scale: isCompleted ? 0.98 : 1.0,
          child: GestureDetector(
        onLongPress: () => _showContextMenu(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: isHighlighted
                ? [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.6),
                      blurRadius: 16,
                      spreadRadius: 4,
                    ),
                    BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.4),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Card(
            elevation: isCompleted ? 1.0 : (isHighlighted ? 8.0 : 3.0),
            color: isCompleted
                ? AppTheme.lightTheme.colorScheme.surface.withValues(alpha: 0.7)
                : AppTheme.lightTheme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: isHighlighted
                  ? const BorderSide(
                      color: Colors.amber,
                      width: 2.5,
                    )
                  : isCompleted
                      ? BorderSide(
                          color:
                              AppTheme.getSuccessColor(true).withValues(alpha: 0.3))
                      : BorderSide.none,
            ),
          child: Padding(
            padding: EdgeInsets.all(4.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    // Activity Icon
                    Container(
                      padding: EdgeInsets.all(2.w),
                      decoration: BoxDecoration(
                        color: _getTaskTypeColor().withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: CustomIconWidget(
                        iconName: iconName,
                        color: _getTaskTypeColor(),
                        size: 24,
                      ),
                    ),

                    SizedBox(width: 3.w),

                    // Task Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTheme.lightTheme.textTheme.titleMedium
                                ?.copyWith(
                              color: isCompleted
                                  ? AppTheme
                                      .lightTheme.colorScheme.onSurfaceVariant
                                  : AppTheme.lightTheme.colorScheme.onSurface,
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 0.5.h),
                          Wrap(
                            spacing: 1.w,
                            runSpacing: 0.5.h,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CustomIconWidget(
                                    iconName: 'schedule',
                                    color: AppTheme
                                        .lightTheme.colorScheme.onSurfaceVariant,
                                    size: 14,
                                  ),
                                  SizedBox(width: 1.w),
                                  Text(
                                    '$scheduledTime • $duration',
                                    style: AppTheme.lightTheme.textTheme.bodySmall
                                        ?.copyWith(
                                      color: AppTheme
                                          .lightTheme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              // Status Badge - ONLY show for incomplete tasks with overdue/missed/skipped status
                              if (!isCompleted && 
                                  task['task_status'] != null && 
                                  task['task_status'] != TaskStatus.completed &&
                                  task['task_status'] != TaskStatus.pending &&
                                  task['task_status'] != TaskStatus.active)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 1.5.w, vertical: 0.3.h),
                                  decoration: BoxDecoration(
                                    color: TaskLifecycleService.getStatusColor(task['task_status']).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        TaskLifecycleService.getStatusIcon(task['task_status']),
                                        size: 10,
                                        color: TaskLifecycleService.getStatusColor(task['task_status']),
                                      ),
                                      SizedBox(width: 0.5.w),
                                      Text(
                                        task['task_status'] == TaskStatus.overdue ? 'Overdue' : 
                                        (task['task_status'] == TaskStatus.missed ? 'Missed' : 'Skipped'),
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: TaskLifecycleService.getStatusColor(task['task_status']),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Completion Status - Animated Checkbox or Lock
                    if (isCompletable || isCompleted)
                      AnimatedTaskCheckbox(
                        isCompleted: isCompleted,
                        progress: progress,
                        onTap: isCompletable ? onTaskCompleted : () {},
                        completedColor: AppTheme.getSuccessColor(true),
                        size: 48,
                      )
                    else
                      GestureDetector(
                        onTap: () {
                          if (onTapLocked != null) {
                            onTapLocked!(
                              blockReason,
                              task['task_status'] ?? TaskStatus.pending,
                            );
                          }
                        },
                        child: Tooltip(
                          message: blockReason,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: blockReason == 'Window closed' 
                                  ? Colors.red.shade50 
                                  : Colors.grey.shade200,
                              border: Border.all(
                                color: blockReason == 'Window closed' 
                                    ? Colors.red.shade300 
                                    : Colors.grey.shade400,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  blockReason == 'Window closed' 
                                      ? Icons.cancel 
                                      : Icons.lock_clock,
                                  size: 20,
                                  color: blockReason == 'Window closed' 
                                      ? Colors.red.shade400 
                                      : Colors.grey.shade600,
                                ),
                                if (blockReason.isNotEmpty && blockReason.contains('min'))
                                  Text(
                                    blockReason.split(' ')[0],
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                // Description
                if (description.isNotEmpty) ...[
                  SizedBox(height: 1.5.h),
                  Text(
                    description,
                    style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Completion Hint
                if (!isCompleted && progress == 0) ...[
                  SizedBox(height: 1.h),
                  Row(
                    children: [
                      Icon(
                        Icons.touch_app,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      SizedBox(width: 1.w),
                      Text(
                        'Tap circle to complete',
                        style:
                            AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],

                // Progress Bar (for in-progress tasks)
                if (progress > 0 && progress < 1.0) ...[
                  SizedBox(height: 1.5.h),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppTheme.lightTheme.colorScheme.outline
                        .withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.lightTheme.colorScheme.primary,
                    ),
                    minHeight: 4,
                  ),
                ],
              ],
            ),
          ),
        ),
        ),  // Close AnimatedContainer
      ),  // Close GestureDetector
      ),  // Close AnimatedScale
      ),  // Close AnimatedOpacity
    );
  }

  Widget _buildSwipeBackground({required bool isLeftSwipe}) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 0.5.h),
      decoration: BoxDecoration(
        color: isLeftSwipe
            ? AppTheme.lightTheme.colorScheme.error.withValues(alpha: 0.1)
            : AppTheme.lightTheme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: isLeftSwipe ? Alignment.centerRight : Alignment.centerLeft,
      padding: EdgeInsets.symmetric(horizontal: 6.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomIconWidget(
            iconName: isLeftSwipe ? 'delete' : 'edit',
            color: isLeftSwipe
                ? AppTheme.lightTheme.colorScheme.error
                : AppTheme.lightTheme.colorScheme.primary,
            size: 28,
          ),
          SizedBox(height: 0.5.h),
          Text(
            isLeftSwipe ? 'Delete' : 'Edit',
            style: AppTheme.lightTheme.textTheme.labelSmall?.copyWith(
              color: isLeftSwipe
                  ? AppTheme.lightTheme.colorScheme.error
                  : AppTheme.lightTheme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showQuickActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // IMPORTANT: Allows sheet to be taller than half screen
      builder: (context) {
        final String taskTitle = task["title"] ?? "Task";
        
        return Container(
          // Limit max height to 70% of screen to prevent overflow
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: const Color(0xFFFDF8F3), // Warm cream background
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5D4037).withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SingleChildScrollView( // Makes content scrollable if needed
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 12.w,
                  height: 0.5.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5D4037).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(height: 2.h),
                
                // Title
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C1810),
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  taskTitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF5D4037).withOpacity(0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                
                SizedBox(height: 2.h),
                
                // Action buttons with reduced spacing
                _buildQuickActionButton(
                  context,
                  icon: Icons.edit_outlined,
                  iconColor: Colors.blue[700]!,
                  bgColor: Colors.blue[50]!,
                  title: 'Edit Task',
                  subtitle: 'Modify task details',
                  onTap: () {
                    Navigator.pop(context);
                    onTaskEdit();
                  },
                ),
                SizedBox(height: 1.h),
                
                _buildQuickActionButton(
                  context,
                  icon: Icons.schedule_outlined,
                  iconColor: Colors.orange[700]!,
                  bgColor: Colors.orange[50]!,
                  title: 'Reschedule',
                  subtitle: 'Change time',
                  onTap: () {
                    Navigator.pop(context);
                    onTaskReschedule();
                  },
                ),
                SizedBox(height: 1.h),
                
                _buildQuickActionButton(
                  context,
                  icon: Icons.track_changes_outlined,
                  iconColor: const Color(0xFF5D4037),
                  bgColor: const Color(0xFF5D4037).withOpacity(0.1),
                  title: 'Track Activity',
                  subtitle: 'Log completion status',
                  onTap: () {
                    Navigator.pop(context);
                    if (onTaskTrack != null) {
                      onTaskTrack!();
                    }
                  },
                ),
                SizedBox(height: 1.h),
                
                _buildQuickActionButton(
                  context,
                  icon: Icons.check_circle_outline,
                  iconColor: Colors.green[700]!,
                  bgColor: Colors.green[50]!,
                  title: 'Mark Done',
                  subtitle: 'Complete this task',
                  onTap: () {
                    Navigator.pop(context);
                    if (onTaskTrack != null) {
                      onTaskTrack!();
                    } else {
                      onTaskCompleted();
                    }
                  },
                ),
                
                SizedBox(height: 1.5.h),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildQuickActionButton(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF5D4037).withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              SizedBox(width: 4.w),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2C1810),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF5D4037).withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow
              Icon(
                Icons.chevron_right,
                color: const Color(0xFF5D4037).withOpacity(0.4),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: AppTheme.lightTheme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12.w,
              height: 0.5.h,
              decoration: BoxDecoration(
                color: AppTheme.lightTheme.colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              'Task Options',
              style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 2.h),
            _buildActionTile(
              context,
              icon: 'edit',
              title: 'Edit Task',
              onTap: () {
                Navigator.pop(context);
                onTaskEdit();
              },
            ),
            _buildActionTile(
              context,
              icon: 'schedule',
              title: 'Reschedule',
              onTap: () {
                Navigator.pop(context);
                onTaskReschedule();
              },
            ),
            if (onTaskTrack != null)
              _buildActionTile(
                context,
                icon: 'track_changes',
                title: 'Track Activity',
                onTap: () {
                  Navigator.pop(context);
                  onTaskTrack!();
                },
              ),
            _buildActionTile(
              context,
              icon: 'content_copy',
              title: 'Duplicate',
              onTap: () {
                Navigator.pop(context);
                // Handle duplicate
              },
            ),
            _buildActionTile(
              context,
              icon: 'delete',
              title: 'Delete',
              isDestructive: true,
              onTap: () {
                Navigator.pop(context);
                onTaskDelete();
              },
            ),
            SizedBox(height: 2.h),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required String icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: CustomIconWidget(
        iconName: icon,
        color: isDestructive
            ? AppTheme.lightTheme.colorScheme.error
            : AppTheme.lightTheme.colorScheme.primary,
        size: 24,
      ),
      title: Text(
        title,
        style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
          color: isDestructive
              ? AppTheme.lightTheme.colorScheme.error
              : AppTheme.lightTheme.colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Color _getTaskTypeColor() {
    final String taskType = task["type"] ?? task["category"] ?? "";
    switch (taskType.toLowerCase()) {
      case 'meditation':
        return AppTheme.lightTheme.colorScheme.tertiary;
      case 'yoga':
        return AppTheme.lightTheme.colorScheme.primary;
      case 'breathing':
      case 'pranayama':
        return AppTheme.lightTheme.colorScheme.secondary;
      case 'study':
        return AppTheme.getWarningColor(true);
      case 'journal':
        return AppTheme.lightTheme.colorScheme.primaryContainer;
      case 'exercise':
        return Colors.orange;
      case 'work':
        return Colors.blue;
      default:
        return AppTheme.lightTheme.colorScheme.primary;
    }
  }

  String _getIconForCategory(String? category) {
    switch ((category ?? '').toLowerCase()) {
      case 'meditation':
        return 'self_improvement';
      case 'yoga':
        return 'fitness_center';
      case 'breathing':
      case 'pranayama':
        return 'air';
      case 'study':
        return 'menu_book';
      case 'journal':
        return 'edit_note';
      case 'exercise':
        return 'directions_run';
      case 'work':
        return 'work';
      default:
        return 'task_alt';
    }
  }
}
