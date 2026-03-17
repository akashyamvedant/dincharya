import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../models/task_categories.dart';
import '../../../services/task_lifecycle_service.dart';
import './animated_task_checkbox.dart';

class TaskCardWidget extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback onTaskCompleted;
  final VoidCallback onTaskEdit;
  final VoidCallback onTaskReschedule;
  final VoidCallback onTaskDelete;
  final VoidCallback? onTaskTrack;
  final VoidCallback? onSessionPlay; // Callback to play linked guided session
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
    this.onSessionPlay,
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
      background: _buildSwipeBackground(context, isLeftSwipe: false),
      secondaryBackground: _buildSwipeBackground(context, isLeftSwipe: true),
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
                ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
                : Theme.of(context).colorScheme.surface,
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
                              AppTheme.getSuccessColor(Theme.of(context).brightness == Brightness.light).withValues(alpha: 0.3))
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
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                              color: isCompleted
                                  ? Theme.of(context)
                                      .colorScheme.onSurfaceVariant
                                  : Theme.of(context).colorScheme.onSurface,
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
                                    color: Theme.of(context)
                                        .colorScheme.onSurfaceVariant,
                                    size: 14,
                                  ),
                                  SizedBox(width: 1.w),
                                  Text(
                                    TaskCategory.showDuration(task["category"] ?? task["type"]) && duration.isNotEmpty
                                        ? '$scheduledTime • $duration'
                                        : scheduledTime,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme.onSurfaceVariant,
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
                        completedColor: AppTheme.getSuccessColor(Theme.of(context).brightness == Brightness.light),
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
                                  ? Colors.red.withOpacity(0.1) 
                                  : Theme.of(context).colorScheme.surfaceContainerHighest,
                              border: Border.all(
                                color: blockReason == 'Window closed' 
                                    ? Colors.red.shade300 
                                    : Theme.of(context).colorScheme.outline,
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
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                if (blockReason.isNotEmpty && blockReason.contains('min'))
                                  Text(
                                    blockReason.split(' ')[0],
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Linked Session — Play button
                if (!isCompleted && task['linked_session_id'] != null && onSessionPlay != null) ...[
                  SizedBox(height: 1.h),
                  GestureDetector(
                    onTap: onSessionPlay,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
                      decoration: BoxDecoration(
                        color: _getTaskTypeColor().withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getTaskTypeColor().withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_circle_filled,
                            size: 18,
                            color: _getTaskTypeColor(),
                          ),
                          SizedBox(width: 1.5.w),
                          Text(
                            'Start Session',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _getTaskTypeColor(),
                            ),
                          ),
                          SizedBox(width: 1.w),
                          Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: _getTaskTypeColor().withOpacity(0.6),
                          ),
                        ],
                      ),
                    ),
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
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(width: 1.w),
                      Text(
                        'Tap circle to complete',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    backgroundColor: Theme.of(context).colorScheme.outline
                        .withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
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

  Widget _buildSwipeBackground(BuildContext context, {required bool isLeftSwipe}) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 0.5.h),
      decoration: BoxDecoration(
        color: isLeftSwipe
            ? Theme.of(context).colorScheme.error.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
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
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
            size: 28,
          ),
          SizedBox(height: 0.5.h),
          Text(
            isLeftSwipe ? 'Delete' : 'Edit',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isLeftSwipe
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
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
            color: Theme.of(context).scaffoldBackgroundColor, // Warm cream background
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
                    color: Theme.of(context).colorScheme.outline,
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
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  taskTitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                  bgColor: Colors.blue.withOpacity(0.1),
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
                  bgColor: Colors.orange.withOpacity(0.1),
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
                  bgColor: Colors.green.withOpacity(0.1),
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
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withOpacity(0.03),
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
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12.w,
              height: 0.5.h,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              'Task Options',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
        size: 24,
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: isDestructive
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.onSurface,
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
    final String taskType = task["category"] ?? task["type"] ?? "";
    return TaskCategory.getColor(taskType);
  }

  String _getIconForCategory(String? category) {
    return TaskCategory.getIcon(category);
  }
}
