import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class EmptyRoutineWidget extends StatelessWidget {
  final VoidCallback? onRoutineCreated;
  
  const EmptyRoutineWidget({super.key, this.onRoutineCreated});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Illustration
            Container(
              width: 60.w,
              height: 30.h,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomIconWidget(
                    iconName: 'self_improvement',
                    color: Theme.of(context).colorScheme.primary
                        .withValues(alpha: 0.6),
                    size: 80,
                  ),
                  SizedBox(height: 2.h),
                  CustomIconWidget(
                    iconName: 'add_circle_outline',
                    color: Theme.of(context).colorScheme.tertiary
                        .withValues(alpha: 0.8),
                    size: 40,
                  ),
                ],
              ),
            ), // Added comma here

            SizedBox(height: 4.h),

            // Title
            Text(
              'Begin Your Journey',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: 1.5.h),

            // Description
            Text(
              'Create your first routine to start building discipline, peace, and productivity in your daily life.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: 4.h),

            // Call-to-Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.pushNamed(context, '/routine-builder');
                  // Reload tasks after returning
                  onRoutineCreated?.call();
                },
                icon: CustomIconWidget(
                  iconName: 'add',
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 20,
                ),
                label: Text(
                  'Build Your First Routine',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: EdgeInsets.symmetric(vertical: 2.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                ),
              ),
            ),

            SizedBox(height: 2.h),

            // Secondary Action
            TextButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/guided-sessions-hub');
              },
              icon: CustomIconWidget(
                iconName: 'explore',
                color: Theme.of(context).colorScheme.primary,
                size: 18,
              ),
              label: Text(
                'Explore Guided Sessions',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            SizedBox(height: 6.h),

            // Inspirational Quote
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline
                      .withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  CustomIconWidget(
                    iconName: 'format_quote',
                    color: Theme.of(context).colorScheme.tertiary,
                    size: 24,
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    'योगः कर्मसु कौशलम्',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    'Yoga is skill in action',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
