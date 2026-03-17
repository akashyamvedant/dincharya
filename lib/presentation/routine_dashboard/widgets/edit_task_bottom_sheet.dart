import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../models/task_categories.dart';
import '../../../services/alarm_service.dart';
import 'session_picker_sheet.dart';

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
  bool _alarmEnabled = false;
  String _selectedAlarmSound = 'gentle_morning';
  String? _linkedSessionId;
  String? _linkedSessionTitle;
  int? _linkedSessionDuration;

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

    // Parse alarm settings
    _alarmEnabled = widget.task['alarm_enabled'] == true;
    _selectedAlarmSound = widget.task['alarm_sound']?.toString() ?? 'gentle_morning';

    // Parse linked session
    _linkedSessionId = widget.task['linked_session_id']?.toString();
    _linkedSessionTitle = widget.task['linked_session_title']?.toString();
    final rawSessionDur = widget.task['linked_session_duration'];
    _linkedSessionDuration = rawSessionDur is int ? rawSessionDur : null;
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
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              hourMinuteColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
              hourMinuteTextColor: Theme.of(context).colorScheme.onSurface,
              dialHandColor: Theme.of(context).colorScheme.primary,
              dialBackgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              dialTextColor: Theme.of(context).colorScheme.onSurface,
              dayPeriodColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
              dayPeriodTextColor: Theme.of(context).colorScheme.onSurface,
              dayPeriodBorderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
              entryModeIconColor: Theme.of(context).colorScheme.primary,
              helpTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
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
    final customController = TextEditingController();
    bool isCustomMode = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Set Duration',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$tempDuration min',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                SizedBox(height: 2.h),

                // Slider (capped at 120)
                if (!isCustomMode) ...[
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: Theme.of(context).colorScheme.primary,
                      inactiveTrackColor:
                          Theme.of(context).colorScheme.primary.withOpacity(0.15),
                      thumbColor: Theme.of(context).colorScheme.primary,
                      overlayColor:
                          Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      trackHeight: 6,
                    ),
                    child: Slider(
                      value: tempDuration.clamp(5, 120).toDouble(),
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
                              fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      Text('120 min',
                          style: TextStyle(
                              fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                  SizedBox(height: 2.h),
                ],

                // Custom time input
                if (isCustomMode) ...[
                  TextField(
                    controller: customController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter minutes (e.g. 180)',
                      hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      suffixText: 'min',
                      suffixStyle: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary, width: 2),
                      ),
                    ),
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      if (parsed != null && parsed > 0) {
                        setDialogState(() {
                          tempDuration = parsed;
                        });
                      }
                    },
                  ),
                  SizedBox(height: 2.h),
                ],

                // Preset buttons + Custom button
                Wrap(
                  spacing: 2.w,
                  runSpacing: 1.h,
                  children: [
                    ...[5, 10, 15, 20, 30, 45, 60, 90].map((mins) {
                      final isActive = tempDuration == mins && !isCustomMode;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            tempDuration = mins;
                            isCustomMode = false;
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 3.w, vertical: 1.h),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isActive
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline,
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
                                  isActive ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      );
                    }),
                    // Custom button
                    GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          isCustomMode = !isCustomMode;
                          if (isCustomMode) {
                            customController.text = tempDuration.toString();
                          }
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 3.w, vertical: 1.h),
                        decoration: BoxDecoration(
                          color: isCustomMode
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isCustomMode
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit,
                              size: 13,
                              color: isCustomMode ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
                            ),
                            SizedBox(width: 1.w),
                            Text(
                              'Custom',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isCustomMode
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isCustomMode
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Confirm',
                    style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
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
          content: Text('Please set task duration'),
          backgroundColor: Colors.red,
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
      'alarm_enabled': _selectedCategoryId == 'wakeup' ? _alarmEnabled : false,
      'alarm_sound': _selectedCategoryId == 'wakeup' ? _selectedAlarmSound : null,
      'linked_session_id': _selectedCategory.hasGuidedSessions ? _linkedSessionId : null,
    };

    widget.onTaskUpdated(updatedTask);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
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
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 2.h),

            // Title
            Text(
              'Edit Task',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 3.h),

            // Task Title
            TextField(
              controller: _titleController,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Task Title',
                labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                prefixIcon:
                    Icon(Icons.title, color: Theme.of(context).colorScheme.primary),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                ),
              ),
            ),
            SizedBox(height: 2.h),

            // Description
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                prefixIcon:
                    Icon(Icons.notes, color: Theme.of(context).colorScheme.primary),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                ),
              ),
            ),
            SizedBox(height: 2.h),

            // Category Selection
            Text(
              'Category',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
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
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? category.color
                                : Theme.of(context).colorScheme.outline,
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
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            SizedBox(width: 1.w),
                            Text(
                              category.displayName,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Theme.of(context).colorScheme.onSurface,
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
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.outline),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer, color: Theme.of(context).colorScheme.primary),
                      SizedBox(width: 3.w),
                      Text(
                        _durationMinutes > 0
                            ? '$_durationMinutes min'
                            : 'Set duration',
                        style: TextStyle(
                          color: _durationMinutes > 0
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.edit, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 18),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 2.h),
            ],

            // Time Selection
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.outline),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.access_time,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  'Scheduled Time',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  _selectedTime.format(context),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: Icon(
                  Icons.edit,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onTap: _selectTime,
              ),
            ),
            SizedBox(height: 2.h),

            // Alarm settings — only for wakeup category
            if (_selectedCategoryId == 'wakeup') ...[
              _buildAlarmSection(),
              SizedBox(height: 2.h),
            ],

            // Guided Session linking — for meditation, yoga, pranayama
            if (_selectedCategory.hasGuidedSessions) ...[
              _buildGuidedSessionSection(),
              SizedBox(height: 2.h),
            ],

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
                      side: BorderSide(color: Theme.of(context).colorScheme.outline),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveTask,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      padding: EdgeInsets.symmetric(vertical: 1.5.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                        : Text(
                            'Save Changes',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
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

  Widget _buildGuidedSessionSection() {
    final color = _selectedCategory.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Link Guided Session (Optional)',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 1.h),
        GestureDetector(
          onTap: () async {
            final result = await showModalBottomSheet<Map<String, dynamic>>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: SessionPickerSheet(
                  category: _selectedCategoryId,
                  currentSessionId: _linkedSessionId,
                ),
              ),
            );
            if (result != null) {
              setState(() {
                if (result['unlink'] == true) {
                  _linkedSessionId = null;
                  _linkedSessionTitle = null;
                  _linkedSessionDuration = null;
                } else {
                  _linkedSessionId = result['id'] as String?;
                  _linkedSessionTitle = result['title'] as String?;
                  _linkedSessionDuration = result['duration'] as int?;
                }
              });
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: _linkedSessionId != null
                  ? color.withOpacity(0.06)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _linkedSessionId != null
                    ? color.withOpacity(0.3)
                    : Theme.of(context).colorScheme.outline,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _linkedSessionId != null
                        ? Icons.play_circle_filled
                        : Icons.add_circle_outline,
                    color: color,
                    size: 22,
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: _linkedSessionId != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _linkedSessionTitle ?? 'Session',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_linkedSessionDuration != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  '${(_linkedSessionDuration! ~/ 60)} min • Tap to change',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                          ],
                        )
                      : Text(
                          'Tap to choose a guided session',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                ),
                if (_linkedSessionId != null)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _linkedSessionId = null;
                        _linkedSessionTitle = null;
                        _linkedSessionDuration = null;
                      });
                    },
                    child: Icon(Icons.close, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  )
                else
                  Icon(Icons.chevron_right, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlarmSection() {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF57F17).withOpacity(0.08),
            const Color(0xFFFF8F00).withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF57F17).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _alarmEnabled
                      ? const Color(0xFFF57F17).withOpacity(0.15)
                      : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _alarmEnabled ? Icons.alarm_on_rounded : Icons.alarm_off_rounded,
                  color: _alarmEnabled ? Color(0xFFF57F17) : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wake Up Alarm',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      _alarmEnabled
                          ? 'Alarm will ring at scheduled time'
                          : 'Only notification will be sent',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _alarmEnabled,
                onChanged: (value) {
                  setState(() {
                    _alarmEnabled = value;
                  });
                },
                activeColor: const Color(0xFFF57F17),
                activeTrackColor: const Color(0xFFF57F17).withOpacity(0.3),
              ),
            ],
          ),
          if (_alarmEnabled) ...[
            SizedBox(height: 1.5.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.outline),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.music_note_rounded,
                    color: const Color(0xFFF57F17),
                    size: 18,
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedAlarmSound,
                        isExpanded: true,
                        dropdownColor: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        elevation: 4,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                        icon: Icon(
                          Icons.expand_more_rounded,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                        items: AlarmService.availableSounds.map((sound) {
                          return DropdownMenuItem<String>(
                            value: sound.id,
                            child: Text(sound.displayName),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedAlarmSound = value;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
