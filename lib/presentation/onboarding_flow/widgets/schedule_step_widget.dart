import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class ScheduleStepWidget extends StatelessWidget {
  final List<String> selectedGoals;
  final List<String> availableGoals;
  final Function(List<String>) onGoalsChanged;
  final TimeOfDay wakeTime;
  final TimeOfDay sleepTime;
  final Function(TimeOfDay) onWakeTimeChanged;
  final Function(TimeOfDay) onSleepTimeChanged;

  const ScheduleStepWidget({
    super.key,
    required this.selectedGoals,
    required this.availableGoals,
    required this.onGoalsChanged,
    required this.wakeTime,
    required this.sleepTime,
    required this.onWakeTimeChanged,
    required this.onSleepTimeChanged,
  });

  @override
  Widget build(BuildContext context) {
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
                    iconName: 'schedule',
                    color: AppTheme.lightTheme.colorScheme.primary,
                    size: 64,
                  ),
                  SizedBox(height: 1.h),
                  CustomIconWidget(
                    iconName: 'access_time',
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
            'Your Goals & Schedule',
            style: AppTheme.lightTheme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.lightTheme.colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 1.h),

          // Description
          Text(
            'Select your wellness goals and set your daily schedule',
            style: AppTheme.lightTheme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 4.h),

          // Goals selection
          Text(
            'Primary Goals',
            style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Choose what you want to focus on (select multiple)',
            style: AppTheme.lightTheme.textTheme.bodySmall,
          ),
          SizedBox(height: 2.h),

          // Goals chips
          Wrap(
            spacing: 2.w,
            runSpacing: 1.h,
            children: availableGoals.map((goal) {
              final isSelected = selectedGoals.contains(goal);
              return FilterChip(
                label: Text(goal),
                selected: isSelected,
                onSelected: (selected) {
                  List<String> updatedGoals = List.from(selectedGoals);
                  if (selected) {
                    updatedGoals.add(goal);
                  } else {
                    updatedGoals.remove(goal);
                  }
                  onGoalsChanged(updatedGoals);
                },
                backgroundColor: AppTheme.lightTheme.colorScheme.surface,
                selectedColor: AppTheme.lightTheme.colorScheme.primary
                    .withValues(alpha: 0.2),
                checkmarkColor: AppTheme.lightTheme.colorScheme.primary,
                labelStyle: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                  color: isSelected
                      ? AppTheme.lightTheme.colorScheme.primary
                      : AppTheme.lightTheme.colorScheme.onSurface,
                ),
                side: BorderSide(
                  color: isSelected
                      ? AppTheme.lightTheme.colorScheme.primary
                      : AppTheme.lightTheme.colorScheme.outline,
                ),
              );
            }).toList(),
          ),

          SizedBox(height: 4.h),

          // Schedule section
          Text(
            'Daily Schedule',
            style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Set your preferred wake and sleep times',
            style: AppTheme.lightTheme.textTheme.bodySmall,
          ),
          SizedBox(height: 2.h),

          // Time pickers
          Row(
            children: [
              Expanded(
                child: _buildTimePicker(
                  context,
                  'Wake Time',
                  'wb_sunny',
                  wakeTime,
                  onWakeTimeChanged,
                ),
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: _buildTimePicker(
                  context,
                  'Sleep Time',
                  'bedtime',
                  sleepTime,
                  onSleepTimeChanged,
                ),
              ),
            ],
          ),

          SizedBox(height: 4.h),
        ],
      ),
    );
  }

  Widget _buildTimePicker(
    BuildContext context,
    String label,
    String iconName,
    TimeOfDay time,
    Function(TimeOfDay) onTimeChanged,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: AppTheme.lightTheme.colorScheme.outline,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () async {
          final TimeOfDay? picked = await showTimePicker(
            context: context,
            initialTime: time,
            builder: (context, child) {
              return Theme(
                data: AppTheme.lightTheme,
                child: child!,
              );
            },
          );
          if (picked != null) {
            onTimeChanged(picked);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(4.w),
          child: Column(
            children: [
              CustomIconWidget(
                iconName: iconName,
                color: AppTheme.lightTheme.colorScheme.primary,
                size: 32,
              ),
              SizedBox(height: 1.h),
              Text(
                label,
                style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 0.5.h),
              Text(
                time.format(context),
                style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                  color: AppTheme.lightTheme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
