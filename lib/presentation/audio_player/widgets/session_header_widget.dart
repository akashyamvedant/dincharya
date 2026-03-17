import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class SessionHeaderWidget extends StatelessWidget {
  final String title;
  final String instructor;
  final VoidCallback onClose;

  const SessionHeaderWidget({
    super.key,
    required this.title,
    required this.instructor,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 0.5.h),
                Text(
                  instructor,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          SizedBox(width: 4.w),

          // Close Button
          GestureDetector(
            onTap: onClose,
            child: Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: CustomIconWidget(
                iconName: 'close',
                color: Theme.of(context).colorScheme.onSurface,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
