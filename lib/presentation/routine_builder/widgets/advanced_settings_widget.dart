import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class AdvancedSettingsWidget extends StatelessWidget {
  final TextEditingController notesController;
  final bool notificationsEnabled;
  final Function(bool) onNotificationToggle;

  const AdvancedSettingsWidget({
    super.key,
    required this.notesController,
    required this.notificationsEnabled,
    required this.onNotificationToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CustomIconWidget(
                iconName: 'settings',
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              SizedBox(width: 2.w),
              Text(
                'Advanced Settings',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          SizedBox(height: 2.h),

          // Notifications Toggle
          Container(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'notifications',
                      color: Theme.of(context).colorScheme.onSurface,
                      size: 20,
                    ),
                    SizedBox(width: 3.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notifications',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                        Text(
                          'Get reminders for this task',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
                Switch(
                  value: notificationsEnabled,
                  onChanged: onNotificationToggle,
                ),
              ],
            ),
          ),

          SizedBox(height: 2.h),

          // Notes Section
          Text(
            'Notes (Optional)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
          SizedBox(height: 1.h),
          TextFormField(
            controller: notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Add any additional notes or instructions...',
              border: OutlineInputBorder(),
            ),
          ),

          SizedBox(height: 2.h),

          // Tips Section
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: AppTheme.getAccentColor(
                      Theme.of(context).brightness == Brightness.light)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'tips_and_updates',
                      color: AppTheme.getAccentColor(
                          Theme.of(context).brightness == Brightness.light),
                      size: 16,
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      'Tips',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.getAccentColor(
                                Theme.of(context).brightness ==
                                    Brightness.light),
                          ),
                    ),
                  ],
                ),
                SizedBox(height: 1.h),
                Text(
                  '• Start with shorter durations and gradually increase\n• Choose consistent times for better habit formation\n• Enable notifications to stay on track',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.getAccentColor(
                            Theme.of(context).brightness == Brightness.light),
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
