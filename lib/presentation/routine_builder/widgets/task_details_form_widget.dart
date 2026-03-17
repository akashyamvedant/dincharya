import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

class TaskDetailsFormWidget extends StatelessWidget {
  final TextEditingController taskTitleController;
  final String selectedTaskType;
  final int selectedDuration;
  final String selectedMeditationType;
  final String selectedYogaSequence;
  final String selectedStudyMode;
  final List<String> meditationTypes;
  final List<String> yogaSequences;
  final List<String> studyModes;
  final Function(int) onDurationChanged;
  final Function(String) onMeditationTypeChanged;
  final Function(String) onYogaSequenceChanged;
  final Function(String) onStudyModeChanged;

  const TaskDetailsFormWidget({
    super.key,
    required this.taskTitleController,
    required this.selectedTaskType,
    required this.selectedDuration,
    required this.selectedMeditationType,
    required this.selectedYogaSequence,
    required this.selectedStudyMode,
    required this.meditationTypes,
    required this.yogaSequences,
    required this.studyModes,
    required this.onDurationChanged,
    required this.onMeditationTypeChanged,
    required this.onYogaSequenceChanged,
    required this.onStudyModeChanged,
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
                iconName: 'edit_note',
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              SizedBox(width: 2.w),
              Text(
                'Task Details',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          SizedBox(height: 2.h),

          // Task Title
          Text(
            'Task Title',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
          SizedBox(height: 1.h),
          TextFormField(
            controller: taskTitleController,
            decoration: const InputDecoration(
              hintText: 'Enter task title',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a task title';
              }
              return null;
            },
          ),

          SizedBox(height: 2.h),

          // Duration Picker
          Text(
            'Duration (minutes)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
          SizedBox(height: 1.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: selectedDuration > 5
                      ? () => onDurationChanged(selectedDuration - 5)
                      : null,
                  icon: CustomIconWidget(
                    iconName: 'remove',
                    color: selectedDuration > 5
                        ? Color(0xFF8B4513)
                        : Theme.of(context).disabledColor,
                    size: 20,
                  ),
                ),
                Text(
                  '$selectedDuration min',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  onPressed: selectedDuration < 120
                      ? () => onDurationChanged(selectedDuration + 5)
                      : null,
                  icon: CustomIconWidget(
                    iconName: 'add',
                    color: selectedDuration < 120
                        ? Color(0xFF8B4513)
                        : Theme.of(context).disabledColor,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 2.h),

          // Task Type Specific Options
          if (selectedTaskType == 'Meditation') ...[
            Text(
              'Meditation Type',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            SizedBox(height: 1.h),
            DropdownButtonFormField<String>(
              value: selectedMeditationType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: meditationTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  onMeditationTypeChanged(value);
                }
              },
            ),
          ] else if (selectedTaskType == 'Yoga') ...[
            Text(
              'Yoga Sequence',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            SizedBox(height: 1.h),
            DropdownButtonFormField<String>(
              value: selectedYogaSequence,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: yogaSequences.map((sequence) {
                return DropdownMenuItem(
                  value: sequence,
                  child: Text(sequence),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  onYogaSequenceChanged(value);
                }
              },
            ),
          ] else if (selectedTaskType == 'Study') ...[
            Text(
              'Study Mode',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            SizedBox(height: 1.h),
            DropdownButtonFormField<String>(
              value: selectedStudyMode,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: studyModes.map((mode) {
                return DropdownMenuItem(
                  value: mode,
                  child: Text(mode),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  onStudyModeChanged(value);
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}
