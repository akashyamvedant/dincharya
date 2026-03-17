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
                    iconName: 'person',
                    color: Theme.of(context).colorScheme.primary,
                    size: 64,
                  ),
                  SizedBox(height: 1.h),
                  CustomIconWidget(
                    iconName: 'edit',
                    color: Theme.of(context).colorScheme.secondary,
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
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 1.h),

          // Description
          Text(
            'Help us personalize your DinCharya experience',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 4.h),

          // Enhanced Name input with validation feedback
          Text(
            'Your Name',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),
          TextFormField(
            initialValue: userName,
            onChanged: onNameChanged,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: 'Enter your name',
              hintStyle: TextStyle(
                color: Colors.grey[500],
              ),
              prefixIcon: Icon(
                Icons.person_outline,
                color: userName.isNotEmpty
                    ? Color(0xFF8B4513)
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              suffixIcon: userName.isNotEmpty
                  ? Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    )
                  : null,
              filled: true,
              fillColor: userName.isNotEmpty
                  ? Theme.of(context).colorScheme.primary
                      .withValues(alpha: 0.05)
                  : Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: userName.isNotEmpty
                      ? Color(0xFF8B4513)
                      : Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
            textInputAction: TextInputAction.next,
          ),

          SizedBox(height: 3.h),

          // Age group selection
          Text(
            'Age Group',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'This helps us suggest appropriate routines',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          SizedBox(height: 2.h),

          // Segmented control for age groups
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline,
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
                          ? Theme.of(context).colorScheme.primary
                              .withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CustomIconWidget(
                          iconName: _getAgeGroupIcon(group),
                          color: isSelected
                              ? Color(0xFF8B4513)
                              : Theme.of(context).colorScheme.onSurface,
                          size: 24,
                        ),
                        SizedBox(width: 3.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? Color(0xFF8B4513)
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                _getAgeGroupDescription(group),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                          .withValues(alpha: 0.7)
                                      : Theme.of(context).colorScheme
                                          .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          CustomIconWidget(
                            iconName: 'check_circle',
                            color: Theme.of(context).colorScheme.primary,
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
