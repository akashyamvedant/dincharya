// lib/presentation/local_tasks/widgets/task_statistics_widget.dart
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

class TaskStatisticsWidget extends StatelessWidget {
  final Map<String, int> statistics;

  const TaskStatisticsWidget({
    super.key,
    required this.statistics,
  });

  @override
  Widget build(BuildContext context) {
    final total = statistics['total'] ?? 0;
    final completed = statistics['completed'] ?? 0;
    final pending = statistics['pending'] ?? 0;
    final overdue = statistics['overdue'] ?? 0;

    final completionRate = total > 0 ? (completed / total * 100) : 0.0;

    return Container(
        margin: EdgeInsets.all(4.w),
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Theme.of(context).colorScheme.outline.withAlpha(51))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            CustomIconWidget(
                iconName: 'analytics',
                color: Theme.of(context).colorScheme.primary,
                size: 24),
            SizedBox(width: 2.w),
            Text('Task Overview',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface)),
            const Spacer(),
            Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                decoration: BoxDecoration(
                    color:
                        _getCompletionRateColor(completionRate).withAlpha(26),
                    borderRadius: BorderRadius.circular(8)),
                child: Text('${completionRate.toInt()}% Complete',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _getCompletionRateColor(completionRate),
                        fontWeight: FontWeight.w600))),
          ]),

          SizedBox(height: 2.h),

          // Statistics Grid
          Row(children: [
            Expanded(
                child: _buildStatCard(context,
                    icon: 'task',
                    label: 'Total',
                    value: total.toString(),
                    color: Theme.of(context).colorScheme.primary)),
            SizedBox(width: 2.w),
            Expanded(
                child: _buildStatCard(context,
                    icon: 'check_circle',
                    label: 'Done',
                    value: completed.toString(),
                    color: Colors.green)),
            SizedBox(width: 2.w),
            Expanded(
                child: _buildStatCard(context,
                    icon: 'schedule',
                    label: 'Pending',
                    value: pending.toString(),
                    color: Colors.orange)),
            SizedBox(width: 2.w),
            Expanded(
                child: _buildStatCard(context,
                    icon: 'warning',
                    label: 'Overdue',
                    value: overdue.toString(),
                    color: Colors.red)),
          ]),

          if (total > 0) ...[
            SizedBox(height: 2.h),

            // Progress Bar
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Progress',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500)),
              SizedBox(height: 1.h),
              LinearProgressIndicator(
                  value: completionRate / 100,
                  backgroundColor:
                      Theme.of(context).colorScheme.outline.withAlpha(51),
                  valueColor: AlwaysStoppedAnimation<Color>(
                      _getCompletionRateColor(completionRate)),
                  minHeight: 6),
            ]),
          ],
        ]));
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
        padding: EdgeInsets.symmetric(vertical: 1.h, horizontal: 2.w),
        decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withAlpha(77))),
        child: Column(children: [
          CustomIconWidget(iconName: icon, color: color, size: 20),
          SizedBox(height: 0.5.h),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w700)),
          SizedBox(height: 0.2.h),
          Text(label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 10.sp),
              textAlign: TextAlign.center),
        ]));
  }

  Color _getCompletionRateColor(double rate) {
    if (rate >= 80) {
      return Colors.green;
    } else if (rate >= 60) {
      return Colors.orange;
    } else if (rate >= 40) {
      return Colors.yellow.shade700;
    } else {
      return Colors.red;
    }
  }
}
