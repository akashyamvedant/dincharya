import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../models/task_categories.dart';

/// Bottom sheet dialog for editing task details
class EditTaskBottomSheet extends StatefulWidget {
  final Map<String, dynamic> task;
  final Function(Map<String, dynamic>) onTaskUpdated;

  const EditTaskBottomSheet({
    super.key,
    required this.task,
    required this.onTaskUpdated,
  });

  @override
  State<EditTaskBottomSheet> createState() => _EditTaskBottomSheetState();
}

class _EditTaskBottomSheetState extends State<EditTaskBottomSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TimeOfDay _selectedTime;
  late String _selectedCategoryId;
  int _durationMinutes = 15;
  bool _isSaving = false;

  TaskCategory get _selectedCategory =>
      TaskCategory.findById(_selectedCategoryId);

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.task['title'] ?? '');
    _descriptionController =
        TextEditingController(text: widget.task['description'] ?? '');

    // Parse duration from task data
    final rawDuration = widget.task['duration'];
    final rawDurationMins = widget.task['duration_minutes'];
    if (rawDurationMins != null && rawDurationMins is int) {
      _durationMinutes = rawDurationMins;
    } else if (rawDuration != null && rawDuration is String) {
      // Parse "15 min" or "30" style strings
      final numStr = rawDuration.replaceAll(RegExp(r'[^0-9]'), '');
      _durationMinutes = int.tryParse(numStr) ?? 15;
    }

    // Map from either 'category' or 'type' field
    final rawCategory =
        widget.task['category'] ?? widget.task['type'] ?? 'other';
    _selectedCategoryId = TaskCategory.findById(rawCategory).id;

    // Parse time
    final timeStr = widget.task['time'] ?? '06:00 AM';
    _selectedTime = _parseTimeString(timeStr);
  }

  TimeOfDay _parseTimeString(String timeStr) {
    try {
      final parts = timeStr
          .replaceAll(RegExp(r'[AP]M', caseSensitive: false), '')
          .trim()
          .split(':');
      int hour = int.parse(parts[0]);
      int minute = parts.length > 1 ? int.parse(parts[1]) : 0;

      if (timeStr.toUpperCase().contains('PM') && hour != 12) {
        hour += 12;
      } else if (timeStr.toUpperCase().contains('AM') && hour == 12) {
        hour = 0;
      }

      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return const TimeOfDay(hour: 6, minute: 0);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: AppTheme.lightTheme.colorScheme.copyWith(
              primary: const Color(0xFF5D4037),
              onPrimary: Colors.white,
              surface: const Color(0xFFFDF8F3),
              onSurface: const Color(0xFF2C1810),
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: const Color(0xFFFDF8F3),
              dialHandColor: const Color(0xFF5D4037),
              dialBackgroundColor: const Color(0xFF5D4037).withOpacity(0.08),
              entryModeIconColor: const Color(0xFF5D4037),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _showDurationPicker() {
    int tempDuration = _durationMinutes > 0 ? _durationMinutes : 15;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFFFDF8F3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Set Duration',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C1810),
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$tempDuration min',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF5D4037),
                  ),
                ),
                SizedBox(height: 2.h),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: const Color(0xFF5D4037),
                    inactiveTrackColor:
                        const Color(0xFF5D4037).withOpacity(0.15),
                    thumbColor: const Color(0xFF5D4037),
                    overlayColor:
                        const Color(0xFF5D4037).withOpacity(0.1),
                    trackHeight: 6,
                  ),
                  child: Slider(
                    value: tempDuration.toDouble(),
                    min: 5,
                    max: 120,
                    divisions: 23,
                    label: '$tempDuration min',
                    onChanged: (value) {
                      setDialogState(() {
                        tempDuration = value.round();
                      });
                    },
                  ),
                ),
                SizedBox(height: 0.5.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('5 min',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[500])),
                    Text('120 min',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
                SizedBox(height: 2.h),
                Wrap(
                  spacing: 2.w,
                  runSpacing: 1.h,
                  children: [5, 10, 15, 20, 30, 45, 60, 90].map((mins) {
                    final isActive = tempDuration == mins;
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          tempDuration = mins;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 3.w, vertical: 1.h),
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFF5D4037)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isActive
                                ? const Color(0xFF5D4037)
                                : Colors.grey[300]!,
                          ),
                        ),
                        child: Text(
                          '${mins}m',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color:
                                isActive ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _durationMinutes = tempDuration;
                  });
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5D4037),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Confirm',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _saveTask() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task title')),
      );
      return;
    }

    // Only require duration for timed categories
    if (_selectedCategory.hasDuration && _durationMinutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please set task duration'),
          backgroundColor: Colors.red[700],
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final updatedTask = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'category': _selectedCategoryId,
      'type': _selectedCategoryId, // backward compat
      'time': _selectedTime.format(context),
      'icon': _selectedCategory.icon,
      'duration': _selectedCategory.hasDuration
          ? '$_durationMinutes min'
          : null,
      'duration_minutes': _selectedCategory.hasDuration
          ? _durationMinutes
          : null,
      'is_inevitable': _selectedCategory.isInevitable,
    };

    widget.onTaskUpdated(updatedTask);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: const BoxDecoration(
        color: Color(0xFFFDF8F3),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 12.w,
                height: 0.5.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF5D4037).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 2.h),

            // Title
            const Text(
              'Edit Task',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C1810),
              ),
            ),
            SizedBox(height: 3.h),

            // Task Title
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                labelText: 'Task Title',
                labelStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon:
                    const Icon(Icons.title, color: Color(0xFF5D4037)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF5D4037), width: 2),
                ),
              ),
            ),
            SizedBox(height: 2.h),

            // Description
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                labelStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon:
                    const Icon(Icons.notes, color: Color(0xFF5D4037)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF5D4037), width: 2),
                ),
              ),
            ),
            SizedBox(height: 2.h),

            // Category Selection
            const Text(
              'Category',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C1810),
              ),
            ),
            SizedBox(height: 1.h),
            SizedBox(
              height: 5.h,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: TaskCategory.all.length,
                itemBuilder: (context, index) {
                  final category = TaskCategory.all[index];
                  final isSelected = _selectedCategoryId == category.id;
                  return Padding(
                    padding: EdgeInsets.only(right: 2.w),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategoryId = category.id;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(
                            horizontal: 3.w, vertical: 0.8.h),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? category.color
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? category.color
                                : Colors.grey[300]!,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CustomIconWidget(
                              iconName: category.icon,
                              size: 16,
                              color: isSelected
                                  ? Colors.white
                                  : Colors.black54,
                            ),
                            SizedBox(width: 1.w),
                            Text(
                              category.displayName,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 2.h),

            // Duration — only for timed categories
            if (_selectedCategory.hasDuration) ...[
              GestureDetector(
                onTap: () => _showDurationPicker(),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer, color: Color(0xFF5D4037)),
                      SizedBox(width: 3.w),
                      Text(
                        _durationMinutes > 0
                            ? '$_durationMinutes min'
                            : 'Set duration',
                        style: TextStyle(
                          color: _durationMinutes > 0
                              ? const Color(0xFF2C1810)
                              : Colors.grey[400],
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.edit, color: Colors.grey[400], size: 18),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 2.h),
            ],

            // Time Selection
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.access_time,
                  color: Color(0xFF5D4037),
                ),
                title: const Text(
                  'Scheduled Time',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  _selectedTime.format(context),
                  style: const TextStyle(
                    color: Color(0xFF5D4037),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: const Icon(
                  Icons.edit,
                  color: Color(0xFF5D4037),
                ),
                onTap: _selectTime,
              ),
            ),
            SizedBox(height: 3.h),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 1.5.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey[400]!),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveTask,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5D4037),
                      padding: EdgeInsets.symmetric(vertical: 1.5.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 2.h),
          ],
        ),
      ),
    );
  }
}
