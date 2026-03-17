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
                    Theme.of(context).colorScheme.primary
                        .withValues(alpha: 0.1),
                    Theme.of(context).colorScheme.secondary
                        .withValues(alpha: 0.1),
                  ],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomIconWidget(
                    iconName: 'check_circle',
                    color: Theme.of(context).colorScheme.primary,
                    size: 64,
                  ),
                  SizedBox(height: 1.h),
                  CustomIconWidget(
                    iconName: 'auto_awesome',
                    color: Theme.of(context).colorScheme.secondary,
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
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 1.h),

          // Description
          Text(
            'Based on your preferences, we\'ve created a perfect routine for you, ${userName.isNotEmpty ? userName : 'there'}!',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 4.h),

          // Profile summary
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary
                  .withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary
                    .withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile Summary',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                SizedBox(height: 1.h),
                _buildSummaryRow(context, 'Age Group', ageGroup),
                _buildSummaryRow(context, 'Wake Time', wakeTime.format(context)),
                _buildSummaryRow(context, 'Sleep Time', sleepTime.format(context)),
                _buildSummaryRow(context, 'Goals', goals.join(', ')),
              ],
            ),
          ),

          SizedBox(height: 3.h),

          // Routine preview
          Text(
            'Your Daily Routine',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
              return _buildRoutineCard(context, routine);
            },
          ),

          SizedBox(height: 4.h),

          // Customization note
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary
                  .withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.secondary
                    .withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                CustomIconWidget(
                  iconName: 'info',
                  color: Theme.of(context).colorScheme.secondary,
                  size: 24,
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Text(
                    'You can customize this routine anytime from your dashboard',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
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

  Widget _buildSummaryRow(BuildContext context, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 0.5.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 25.w,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutineCard(BuildContext context, Map<String, dynamic> routine) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
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
              color: Theme.of(context).colorScheme.primary
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              routine['time'] as String,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),

          SizedBox(width: 4.w),

          // Icon
          CustomIconWidget(
            iconName: routine['icon'] as String,
            color: Theme.of(context).colorScheme.primary,
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
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (routine['description'] != null) ...[
                  SizedBox(height: 0.5.h),
                  Text(
                    routine['description'] as String,
                    style: Theme.of(context).textTheme.bodySmall,
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
                color: Theme.of(context).colorScheme.secondary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                routine['duration'] as String,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Generates the SAME routine that RoutineService.createDefaultRoutine creates
  /// This ensures "what you see = what you get"
  List<Map<String, dynamic>> _generateRoutine(BuildContext context) {
    final List<Map<String, dynamic>> routine = [];

    // === MORNING ROUTINE (mirrors RoutineService._generateMorningRoutine) ===
    routine.add({
      'time': wakeTime.format(context),
      'title': 'Good Morning! 🌅',
      'description': 'Start your day with gratitude and positive energy',
      'icon': 'wb_sunny',
      'duration': null,
    });

    if (goals.contains('Mindfulness') || goals.contains('Stress Relief')) {
      routine.add({
        'time': _addMinutes(wakeTime, 10).format(context),
        'title': 'Morning Meditation 🧘‍♀️',
        'description': 'Center yourself for the day ahead',
        'icon': 'self_improvement',
        'duration': '10 min',
      });
    }

    if (goals.contains('Physical Fitness') || goals.contains('Energy Boost')) {
      routine.add({
        'time': _addMinutes(wakeTime, 25).format(context),
        'title': 'Morning Exercise 💪',
        'description': 'Get your blood flowing and energy up',
        'icon': 'fitness_center',
        'duration': '25 min',
      });
    }

    routine.add({
      'time': _addMinutes(wakeTime, 45).format(context),
      'title': 'Healthy Breakfast 🥗',
      'description': 'Fuel your body with nutritious food',
      'icon': 'restaurant',
      'duration': '20 min',
    });

    // === DAY ROUTINE (mirrors RoutineService._generateDayRoutine) ===
    if (goals.contains('Focus & Productivity')) {
      routine.add({
        'time': _addMinutes(wakeTime, 90).format(context),
        'title': 'Deep Work Session 🎯',
        'description': 'Focused work or study time',
        'icon': 'work',
        'duration': '90 min',
      });
    }

    routine.add({
      'time': _addMinutes(wakeTime, 240).format(context),
      'title': 'Midday Break ☀️',
      'description': 'Take a moment to rest and recharge',
      'icon': 'free_breakfast',
      'duration': null,
    });

    // Age-group specific afternoon task
    if (ageGroup == 'Student') {
      routine.add({
        'time': _addMinutes(wakeTime, 300).format(context),
        'title': 'Study Session 📚',
        'description': 'Review and prepare for tomorrow',
        'icon': 'school',
        'duration': '60 min',
      });
    } else if (ageGroup == 'Professional') {
      routine.add({
        'time': _addMinutes(wakeTime, 300).format(context),
        'title': 'Work Tasks 💼',
        'description': 'Complete important work assignments',
        'icon': 'work',
        'duration': '60 min',
      });
    } else if (ageGroup == 'Elder') {
      routine.add({
        'time': _addMinutes(wakeTime, 300).format(context),
        'title': 'Gentle Activity 🚶‍♀️',
        'description': 'Light walk or gentle movement',
        'icon': 'directions_walk',
        'duration': '30 min',
      });
    }

    // === EVENING ROUTINE (mirrors RoutineService._generateEveningRoutine) ===
    routine.add({
      'time': _subtractMinutes(sleepTime, 120).format(context),
      'title': 'Evening Meal 🍽️',
      'description': 'Enjoy a light, healthy dinner',
      'icon': 'dinner_dining',
      'duration': '30 min',
    });

    if (goals.contains('Stress Relief') || goals.contains('Better Sleep')) {
      routine.add({
        'time': _subtractMinutes(sleepTime, 60).format(context),
        'title': 'Evening Relaxation 🌙',
        'description': 'Wind down and prepare for rest',
        'icon': 'spa',
        'duration': '30 min',
      });
    }

    if (goals.contains('Mindfulness') || goals.contains('Emotional Balance')) {
      routine.add({
        'time': _subtractMinutes(sleepTime, 30).format(context),
        'title': 'Evening Reflection 📝',
        'description': 'Reflect on your day and write in your journal',
        'icon': 'book',
        'duration': '15 min',
      });
    }

    routine.add({
      'time': _subtractMinutes(sleepTime, 15).format(context),
      'title': 'Prepare for Sleep 😴',
      'description': 'Get ready for a restful night',
      'icon': 'bedtime',
      'duration': null,
    });

    return routine;
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
