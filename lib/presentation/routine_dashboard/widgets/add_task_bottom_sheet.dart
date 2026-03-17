import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../models/task_categories.dart';
import '../../../services/alarm_service.dart';
import 'session_picker_sheet.dart';

class AddTaskBottomSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onTaskAdded;

  const AddTaskBottomSheet({
    super.key,
    required this.onTaskAdded,
  });

  @override
  State<AddTaskBottomSheet> createState() => _AddTaskBottomSheetState();
}

class _AddTaskBottomSheetState extends State<AddTaskBottomSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String _selectedCategoryId = 'meditation';
  TimeOfDay _selectedTime = TimeOfDay.now();
  int _durationMinutes = 15;
  bool _alarmEnabled = true;
  String _selectedAlarmSound = 'gentle_morning';
  String? _linkedSessionId;
  String? _linkedSessionTitle;
  int? _linkedSessionDuration;

  TaskCategory get _selectedCategory =>
      TaskCategory.findById(_selectedCategoryId);

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 85.h,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: EdgeInsets.only(top: 1.h),
            width: 12.w,
            height: 0.5.h,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.all(4.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  'Add New Task',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                TextButton(
                  onPressed: _addTask,
                  child: Text(
                    'Add',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            height: 1,
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 4.w,
                right: 4.w,
                top: 4.w,
                bottom: MediaQuery.of(context).viewInsets.bottom + 4.w,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Selection
                  Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 1.5.h),

                  _buildCategoryGrid(),

                  SizedBox(height: 3.h),

                  // Task Title
                  Text(
                    'Task Title',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  TextField(
                    controller: _titleController,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Enter task title',
                      hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      prefixIcon: Padding(
                        padding: EdgeInsets.all(3.w),
                        child: CustomIconWidget(
                          iconName: 'title',
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                      ),
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
                        borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary, width: 2),
                      ),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),

                  SizedBox(height: 2.h),

                  // Description
                  Text(
                    'Description (Optional)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  TextField(
                    controller: _descriptionController,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Add a brief description',
                      hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      prefixIcon: Padding(
                        padding: EdgeInsets.all(3.w),
                        child: CustomIconWidget(
                          iconName: 'description',
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                      ),
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
                        borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary, width: 2),
                      ),
                    ),
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),

                  SizedBox(height: 2.h),

                  // Time and Duration Row
                  Row(
                    children: [
                      // Scheduled Time — always shown
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Scheduled Time',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            SizedBox(height: 1.h),
                            GestureDetector(
                              onTap: _selectTime,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 4.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Theme.of(context).colorScheme.outline),
                                ),
                                child: Row(
                                  children: [
                                    CustomIconWidget(
                                      iconName: 'schedule',
                                      color: Theme.of(context).colorScheme.primary,
                                      size: 20,
                                    ),
                                    SizedBox(width: 2.w),
                                    Text(
                                      _selectedTime.format(context),
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Duration — only for timed categories
                      if (_selectedCategory.hasDuration) ...[
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Duration',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              SizedBox(height: 1.h),
                              GestureDetector(
                                onTap: () => _showDurationPicker(),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 4.w, vertical: 2.h),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Theme.of(context).colorScheme.outline),
                                  ),
                                  child: Row(
                                    children: [
                                      CustomIconWidget(
                                        iconName: 'timer',
                                        color: Theme.of(context).colorScheme.primary,
                                        size: 20,
                                      ),
                                      SizedBox(width: 2.w),
                                      Text(
                                        _durationMinutes > 0
                                            ? '$_durationMinutes min'
                                            : 'Set duration',
                                        style: TextStyle(
                                          color: _durationMinutes > 0
                                              ? Theme.of(context).colorScheme.onSurface
                                              : Theme.of(context).colorScheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Hint for inevitable tasks
                  if (!_selectedCategory.hasDuration) ...[
                    SizedBox(height: 1.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 3.w, vertical: 1.h),
                      decoration: BoxDecoration(
                        color: _selectedCategory.color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: _selectedCategory.color,
                          ),
                          SizedBox(width: 2.w),
                          Expanded(
                            child: Text(
                              _getInevitableHint(),
                              style: TextStyle(
                                fontSize: 12,
                                color: _selectedCategory.color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Alarm settings — only for wakeup category
                  if (_selectedCategoryId == 'wakeup') ...[
                    SizedBox(height: 2.h),
                    _buildAlarmSection(),
                  ],

                  // Guided Session linking — for meditation, yoga, pranayama
                  if (_selectedCategory.hasGuidedSessions) ...[
                    SizedBox(height: 2.h),
                    _buildGuidedSessionSection(),
                  ],

                  SizedBox(height: 4.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2.w,
        mainAxisSpacing: 1.5.h,
        childAspectRatio: 2.2,
      ),
      itemCount: TaskCategory.all.length,
      itemBuilder: (context, index) {
        final category = TaskCategory.all[index];
        final isSelected = _selectedCategoryId == category.id;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedCategoryId = category.id;
              // Reset linked session when category changes
              // (session may not be valid for new category)
              _linkedSessionId = null;
              _linkedSessionTitle = null;
              _linkedSessionDuration = null;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.8.h),
            decoration: BoxDecoration(
              color: isSelected
                  ? category.color.withOpacity(0.15)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? category.color
                    : Theme.of(context).colorScheme.outline,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: category.color.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              children: [
                CustomIconWidget(
                  iconName: category.icon,
                  color: isSelected
                      ? category.color
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 18,
                ),
                SizedBox(width: 1.w),
                Expanded(
                  child: Text(
                    category.displayName,
                    style: TextStyle(
                      color: isSelected
                          ? category.color
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w400,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
          // Alarm toggle row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _alarmEnabled
                      ? const Color(0xFFF57F17).withOpacity(0.15)
                      : Colors.grey.withOpacity(0.1),
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

          // Sound picker — only shown when alarm is enabled
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

  String _getInevitableHint() {
    switch (_selectedCategoryId) {
      case 'wakeup':
        return 'Duration not needed — we\'ll track when you actually woke up';
      case 'hygiene':
        return 'Duration not needed — just mark when done';
      case 'nutrition':
        return 'Duration not needed — mark after eating';
      case 'sleep':
        return 'Duration not needed — we\'ll track your sleep time';
      default:
        return 'This task doesn\'t need a duration';
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
                // Current value display
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
                              fontWeight:
                                  isActive ? FontWeight.w700 : FontWeight.w500,
                              color: isActive ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
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
                                    ? Colors.white
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
              hourMinuteShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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

    if (picked != null && mounted) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _addTask() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a task title'),
          backgroundColor: Colors.red[700],
        ),
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

    final formattedTime = _selectedTime.format(context);

    final newTask = {
      "title": _titleController.text.trim(),
      "category": _selectedCategoryId,
      "type": _selectedCategoryId, // backward compat
      "duration": _selectedCategory.hasDuration
          ? '$_durationMinutes min'
          : null,
      "duration_minutes": _selectedCategory.hasDuration
          ? _durationMinutes
          : null,
      "time": formattedTime,
      "scheduledTime": formattedTime,
      "icon": _selectedCategory.icon,
      "description": _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      "is_inevitable": _selectedCategory.isInevitable,
      "alarm_enabled": _selectedCategoryId == 'wakeup' ? _alarmEnabled : false,
      "alarm_sound": _selectedCategoryId == 'wakeup' ? _selectedAlarmSound : null,
      "linked_session_id": _selectedCategory.hasGuidedSessions ? _linkedSessionId : null,
    };

    widget.onTaskAdded(newTask);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Task added successfully!'),
        backgroundColor: AppTheme.getSuccessColor(Theme.of(context).brightness == Brightness.light),
      ),
    );
  }
}
