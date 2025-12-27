import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class RoutinePreviewWidget extends StatelessWidget {
  final String userName;
  final String ageGroup;
  final List<String> goals;
  final TimeOfDay wakeTime;
  final TimeOfDay sleepTime;

  const RoutinePreviewWidget({
    super.key,
    required this.userName,
    required this.ageGroup,
    required this.goals,
    required this.wakeTime,
    required this.sleepTime,
  });

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> generatedRoutine =
        _generateRoutine(context);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 6.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 4.h),

          // Illustration
          Center(
            child: Container(
              width: 50.w,
              height: 25.h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.lightTheme.colorScheme.primary
                        .withValues(alpha: 0.1),
                    AppTheme.lightTheme.colorScheme.secondary
                        .withValues(alpha: 0.1),
                  ],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomIconWidget(
                    iconName: 'check_circle',
                    color: AppTheme.lightTheme.colorScheme.primary,
                    size: 64,
                  ),
                  SizedBox(height: 1.h),
                  CustomIconWidget(
                    iconName: 'auto_awesome',
                    color: AppTheme.lightTheme.colorScheme.secondary,
                    size: 32,
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 4.h),

          // Headline
          Text(
            'Your Personalized Routine',
            style: AppTheme.lightTheme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.lightTheme.colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 1.h),

          // Description
          Text(
            'Based on your preferences, we\'ve created a perfect routine for you, ${userName.isNotEmpty ? userName : 'there'}!',
            style: AppTheme.lightTheme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 4.h),

          // Profile summary
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: AppTheme.lightTheme.colorScheme.primary
                  .withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.lightTheme.colorScheme.primary
                    .withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile Summary',
                  style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.lightTheme.colorScheme.primary,
                  ),
                ),
                SizedBox(height: 1.h),
                _buildSummaryRow('Age Group', ageGroup),
                _buildSummaryRow('Wake Time', wakeTime.format(context)),
                _buildSummaryRow('Sleep Time', sleepTime.format(context)),
                _buildSummaryRow('Goals', goals.join(', ')),
              ],
            ),
          ),

          SizedBox(height: 3.h),

          // Routine preview
          Text(
            'Your Daily Routine',
            style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 2.h),

          // Routine cards
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: generatedRoutine.length,
            separatorBuilder: (context, index) => SizedBox(height: 2.h),
            itemBuilder: (context, index) {
              final routine = generatedRoutine[index];
              return _buildRoutineCard(routine);
            },
          ),

          SizedBox(height: 4.h),

          // Customization note
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: AppTheme.lightTheme.colorScheme.secondary
                  .withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.lightTheme.colorScheme.secondary
                    .withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                CustomIconWidget(
                  iconName: 'info',
                  color: AppTheme.lightTheme.colorScheme.secondary,
                  size: 24,
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Text(
                    'You can customize this routine anytime from your dashboard',
                    style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.lightTheme.colorScheme.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 4.h),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 0.5.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 25.w,
            child: Text(
              '$label:',
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.lightTheme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutineCard(Map<String, dynamic> routine) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.lightTheme.colorScheme.outline.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color:
                AppTheme.lightTheme.colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Time
          Container(
            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
            decoration: BoxDecoration(
              color: AppTheme.lightTheme.colorScheme.primary
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              routine['time'] as String,
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.lightTheme.colorScheme.primary,
              ),
            ),
          ),

          SizedBox(width: 4.w),

          // Icon
          CustomIconWidget(
            iconName: routine['icon'] as String,
            color: AppTheme.lightTheme.colorScheme.primary,
            size: 24,
          ),

          SizedBox(width: 3.w),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  routine['title'] as String,
                  style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (routine['description'] != null) ...[
                  SizedBox(height: 0.5.h),
                  Text(
                    routine['description'] as String,
                    style: AppTheme.lightTheme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),

          // Duration
          if (routine['duration'] != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
              decoration: BoxDecoration(
                color: AppTheme.lightTheme.colorScheme.secondary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                routine['duration'] as String,
                style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.lightTheme.colorScheme.secondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _generateRoutine(BuildContext context) {
    final List<Map<String, dynamic>> baseRoutine = [
      {
        'time': wakeTime.format(context),
        'title': 'Morning Wake Up',
        'description': 'Start your day with gratitude',
        'icon': 'wb_sunny',
        'duration': null,
      },
      {
        'time': _addMinutes(wakeTime, 15).format(context),
        'title': 'Morning Meditation',
        'description': 'Center yourself for the day ahead',
        'icon': 'self_improvement',
        'duration': '10 min',
      },
      {
        'time': _addMinutes(wakeTime, 30).format(context),
        'title': 'Yoga Practice',
        'description': 'Gentle stretches and poses',
        'icon': 'fitness_center',
        'duration': '20 min',
      },
    ];

    // Add goal-specific activities
    if (goals.contains('Focus & Productivity')) {
      baseRoutine.add({
        'time': _addMinutes(wakeTime, 60).format(context),
        'title': 'Deep Work Session',
        'description': 'Focused work or study time',
        'icon': 'work',
        'duration': '90 min',
      });
    }

    if (goals.contains('Physical Fitness')) {
      baseRoutine.add({
        'time': '18:00',
        'title': 'Evening Exercise',
        'description': 'Physical activity and movement',
        'icon': 'directions_run',
        'duration': '30 min',
      });
    }

    // Add evening routine
    baseRoutine.addAll([
      {
        'time': _subtractMinutes(sleepTime, 60).format(context),
        'title': 'Evening Reflection',
        'description': 'Journal and reflect on your day',
        'icon': 'book',
        'duration': '15 min',
      },
      {
        'time': _subtractMinutes(sleepTime, 30).format(context),
        'title': 'Relaxation',
        'description': 'Prepare your mind for rest',
        'icon': 'spa',
        'duration': '20 min',
      },
      {
        'time': sleepTime.format(context),
        'title': 'Sleep Time',
        'description': 'Rest and rejuvenate',
        'icon': 'bedtime',
        'duration': null,
      },
    ]);

    return baseRoutine;
  }

  TimeOfDay _addMinutes(TimeOfDay time, int minutes) {
    final totalMinutes = time.hour * 60 + time.minute + minutes;
    return TimeOfDay(
      hour: (totalMinutes ~/ 60) % 24,
      minute: totalMinutes % 60,
    );
  }

  TimeOfDay _subtractMinutes(TimeOfDay time, int minutes) {
    final totalMinutes = time.hour * 60 + time.minute - minutes;
    return TimeOfDay(
      hour: (totalMinutes ~/ 60) % 24,
      minute: totalMinutes % 60,
    );
  }
}
