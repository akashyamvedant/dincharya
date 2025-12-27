import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class ProfileStepWidget extends StatelessWidget {
  final String userName;
  final String selectedAgeGroup;
  final List<String> ageGroups;
  final Function(String) onNameChanged;
  final Function(String) onAgeGroupChanged;

  const ProfileStepWidget({
    super.key,
    required this.userName,
    required this.selectedAgeGroup,
    required this.ageGroups,
    required this.onNameChanged,
    required this.onAgeGroupChanged,
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
                    iconName: 'person',
                    color: AppTheme.lightTheme.colorScheme.primary,
                    size: 64,
                  ),
                  SizedBox(height: 1.h),
                  CustomIconWidget(
                    iconName: 'edit',
                    color: AppTheme.lightTheme.colorScheme.secondary,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 4.h),

          // Headline
          Text(
            'Tell us about yourself',
            style: AppTheme.lightTheme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.lightTheme.colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 1.h),

          // Description
          Text(
            'Help us personalize your DinCharya experience',
            style: AppTheme.lightTheme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 4.h),

          // Enhanced Name input with validation feedback
          Text(
            'Your Name',
            style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),
          TextFormField(
            initialValue: userName,
            onChanged: onNameChanged,
            decoration: InputDecoration(
              hintText: 'Enter your name',
              prefixIcon: Icon(
                Icons.person_outline,
                color: userName.isNotEmpty
                    ? AppTheme.lightTheme.colorScheme.primary
                    : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              ),
              suffixIcon: userName.isNotEmpty
                  ? Icon(
                      Icons.check_circle,
                      color: AppTheme.lightTheme.colorScheme.primary,
                      size: 20,
                    )
                  : null,
              filled: true,
              fillColor: userName.isNotEmpty
                  ? AppTheme.lightTheme.colorScheme.primary
                      .withValues(alpha: 0.05)
                  : AppTheme.lightTheme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: userName.isNotEmpty
                      ? AppTheme.lightTheme.colorScheme.primary
                      : AppTheme.lightTheme.colorScheme.outline,
                ),
              ),
            ),
            textInputAction: TextInputAction.next,
          ),

          SizedBox(height: 3.h),

          // Age group selection
          Text(
            'Age Group',
            style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'This helps us suggest appropriate routines',
            style: AppTheme.lightTheme.textTheme.bodySmall,
          ),
          SizedBox(height: 2.h),

          // Segmented control for age groups
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.lightTheme.colorScheme.outline,
              ),
            ),
            child: Column(
              children: ageGroups.map((group) {
                final isSelected = selectedAgeGroup == group;
                return InkWell(
                  onTap: () => onAgeGroupChanged(group),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 4.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.lightTheme.colorScheme.primary
                              .withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CustomIconWidget(
                          iconName: _getAgeGroupIcon(group),
                          color: isSelected
                              ? AppTheme.lightTheme.colorScheme.primary
                              : AppTheme.lightTheme.colorScheme.onSurface,
                          size: 24,
                        ),
                        SizedBox(width: 3.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group,
                                style: AppTheme.lightTheme.textTheme.bodyLarge
                                    ?.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? AppTheme.lightTheme.colorScheme.primary
                                      : AppTheme
                                          .lightTheme.colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                _getAgeGroupDescription(group),
                                style: AppTheme.lightTheme.textTheme.bodySmall
                                    ?.copyWith(
                                  color: isSelected
                                      ? AppTheme.lightTheme.colorScheme.primary
                                          .withValues(alpha: 0.7)
                                      : AppTheme.lightTheme.colorScheme
                                          .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          CustomIconWidget(
                            iconName: 'check_circle',
                            color: AppTheme.lightTheme.colorScheme.primary,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          SizedBox(height: 4.h),
        ],
      ),
    );
  }

  String _getAgeGroupIcon(String group) {
    switch (group) {
      case 'Student':
        return 'school';
      case 'Professional':
        return 'work';
      case 'Elder':
        return 'elderly';
      default:
        return 'person';
    }
  }

  String _getAgeGroupDescription(String group) {
    switch (group) {
      case 'Student':
        return 'Focus on study routines and stress management';
      case 'Professional':
        return 'Balance productivity with wellness practices';
      case 'Elder':
        return 'Maintain health and spiritual well-being';
      default:
        return '';
    }
  }
}
