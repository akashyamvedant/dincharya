import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class TaskCardWidget extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback onTaskCompleted;
  final VoidCallback onTaskEdit;
  final VoidCallback onTaskReschedule;
  final VoidCallback onTaskDelete;
  final VoidCallback? onTaskTrack;

  const TaskCardWidget({
    super.key,
    required this.task,
    required this.onTaskCompleted,
    required this.onTaskEdit,
    required this.onTaskReschedule,
    required this.onTaskDelete,
    this.onTaskTrack,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = task["isCompleted"] ?? false;
    final double progress = (task["progress"] ?? 0.0).toDouble();
    final String title = task["title"] ?? "";
    final String duration = task["duration"] ?? "";
    final String scheduledTime = task["scheduledTime"] ?? "";
    final String iconName = task["icon"] ?? "task_alt";
    final String description = task["description"] ?? "";

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
      child: GestureDetector(
        onLongPress: () => _showContextMenu(context),
        child: Card(
          elevation: isCompleted ? 1.0 : 3.0,
          color: isCompleted
              ? AppTheme.lightTheme.colorScheme.surface.withValues(alpha: 0.7)
              : AppTheme.lightTheme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isCompleted
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
                          Row(
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
                        ],
                      ),
                    ),

                    // Completion Status - Enhanced Checkbox
                    GestureDetector(
                      onTap: onTaskCompleted,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                isCompleted ? Colors.green : Colors.grey[400]!,
                            width: 2.5,
                          ),
                          color:
                              isCompleted ? Colors.green : Colors.transparent,
                          boxShadow: [
                            BoxShadow(
                              color: isCompleted
                                  ? Colors.green.withValues(alpha: 0.3)
                                  : Colors.grey.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: isCompleted
                            ? Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 24,
                              )
                            : progress > 0
                                ? Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        value: progress,
                                        strokeWidth: 3,
                                        backgroundColor: AppTheme
                                            .lightTheme.colorScheme.outline
                                            .withValues(alpha: 0.3),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          AppTheme
                                              .lightTheme.colorScheme.primary,
                                        ),
                                      ),
                                      Text(
                                        '${(progress * 100).toInt()}%',
                                        style: AppTheme
                                            .lightTheme.textTheme.labelSmall
                                            ?.copyWith(
                                          fontSize: 8.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  )
                                : null,
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
      ),
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
              'Quick Actions',
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
              icon: 'check_circle',
              title: 'Mark Done',
              onTap: () {
                Navigator.pop(context);
                onTaskCompleted();
              },
            ),
            SizedBox(height: 2.h),
          ],
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
    final String taskType = task["type"] ?? "";
    switch (taskType) {
      case 'meditation':
        return AppTheme.lightTheme.colorScheme.tertiary;
      case 'yoga':
        return AppTheme.lightTheme.colorScheme.primary;
      case 'breathing':
        return AppTheme.lightTheme.colorScheme.secondary;
      case 'study':
        return AppTheme.getWarningColor(true);
      case 'journal':
        return AppTheme.lightTheme.colorScheme.primaryContainer;
      default:
        return AppTheme.lightTheme.colorScheme.outline;
    }
  }
}
