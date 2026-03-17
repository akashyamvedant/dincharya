import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class SleepTimerWidget extends StatelessWidget {
  final Function(int) onTimerSet;
  final VoidCallback onClose;

  const SleepTimerWidget({
    super.key,
    required this.onTimerSet,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> timerOptions = [
      {"minutes": 10, "label": "10 minutes"},
      {"minutes": 20, "label": "20 minutes"},
      {"minutes": 30, "label": "30 minutes"},
      {"minutes": 45, "label": "45 minutes"},
      {"minutes": 60, "label": "1 hour"},
    ];

    return Container(
      height: 50.h,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
        border: Border(
          top: BorderSide(
            color:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: EdgeInsets.only(top: 1.h),
            width: 10.w,
            height: 0.5.h,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurfaceVariant
                  .withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2.0),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.all(4.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sleep Timer',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    padding: EdgeInsets.all(2.w),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline
                            .withValues(alpha: 0.3),
                        width: 1.0,
                      ),
                    ),
                    child: CustomIconWidget(
                      iconName: 'close',
                      color: Theme.of(context).colorScheme.onSurface,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(
            color:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            height: 1,
          ),

          // Timer Options
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(vertical: 2.h),
              itemCount: timerOptions.length + 1,
              itemBuilder: (context, index) {
                if (index == timerOptions.length) {
                  // End of session option
                  return ListTile(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                    leading: Container(
                      padding: EdgeInsets.all(2.w),
                      decoration: BoxDecoration(
                        color: AppTheme.getAccentColor(Theme.of(context).brightness == Brightness.light)
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: CustomIconWidget(
                        iconName: 'stop_circle',
                        color: AppTheme.getAccentColor(Theme.of(context).brightness == Brightness.light),
                        size: 24,
                      ),
                    ),
                    title: Text(
                      'End of session',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      'Stop when session completes',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onTap: () {
                      onTimerSet(999); // Special value for end of session
                    },
                  );
                }

                final option = timerOptions[index];
                return ListTile(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                  leading: Container(
                    padding: EdgeInsets.all(2.w),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: CustomIconWidget(
                      iconName: 'timer',
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      size: 24,
                    ),
                  ),
                  title: Text(
                    option["label"],
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  onTap: () => onTimerSet(option["minutes"]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
