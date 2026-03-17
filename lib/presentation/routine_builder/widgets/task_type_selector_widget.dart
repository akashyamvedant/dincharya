import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

class TaskTypeSelectorWidget extends StatelessWidget {
  final List<Map<String, dynamic>> taskTypes;
  final String selectedTaskType;
  final Function(String) onTaskTypeChanged;

  const TaskTypeSelectorWidget({
    super.key,
    required this.taskTypes,
    required this.selectedTaskType,
    required this.onTaskTypeChanged,
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
                iconName: 'category',
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              SizedBox(width: 2.w),
              Text(
                'Task Type',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          SizedBox(height: 2.h),
          SizedBox(
            height: 6.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: taskTypes.length,
              separatorBuilder: (context, index) => SizedBox(width: 3.w),
              itemBuilder: (context, index) {
                final taskType = taskTypes[index];
                final isSelected = taskType['name'] == selectedTaskType;

                return GestureDetector(
                  onTap: () => onTaskTypeChanged(taskType['name']),
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Color(0xFF8B4513)
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? Color(0xFF8B4513)
                            : Theme.of(context).dividerColor,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomIconWidget(
                          iconName: taskType['icon'],
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurface,
                          size: 18,
                        ),
                        SizedBox(width: 2.w),
                        Text(
                          taskType['name'],
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context).colorScheme.onSurface,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
