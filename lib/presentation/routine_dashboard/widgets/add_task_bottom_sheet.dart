import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../models/task_categories.dart';

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
        color: const Color(0xFFFDF8F3),
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
              color: const Color(0xFF5D4037).withOpacity(0.3),
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
                      color: const Color(0xFF5D4037).withOpacity(0.7),
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  'Add New Task',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C1810),
                  ),
                ),
                TextButton(
                  onPressed: _addTask,
                  child: Text(
                    'Add',
                    style: TextStyle(
                      color: const Color(0xFF5D4037),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(
            color: const Color(0xFF5D4037).withOpacity(0.1),
            height: 1,
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(4.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Selection
                  Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2C1810),
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
                      color: const Color(0xFF2C1810),
                    ),
                  ),
                  SizedBox(height: 1.h),
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Enter task title',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: Padding(
                        padding: EdgeInsets.all(3.w),
                        child: CustomIconWidget(
                          iconName: 'title',
                          color: const Color(0xFF5D4037),
                          size: 20,
                        ),
                      ),
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
                        borderSide: const BorderSide(
                            color: Color(0xFF5D4037), width: 2),
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
                      color: const Color(0xFF2C1810),
                    ),
                  ),
                  SizedBox(height: 1.h),
                  TextField(
                    controller: _descriptionController,
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Add a brief description',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: Padding(
                        padding: EdgeInsets.all(3.w),
                        child: CustomIconWidget(
                          iconName: 'description',
                          color: const Color(0xFF5D4037),
                          size: 20,
                        ),
                      ),
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
                        borderSide: const BorderSide(
                            color: Color(0xFF5D4037), width: 2),
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
                                color: const Color(0xFF2C1810),
                              ),
                            ),
                            SizedBox(height: 1.h),
                            GestureDetector(
                              onTap: _selectTime,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 4.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.grey[300]!),
                                ),
                                child: Row(
                                  children: [
                                    CustomIconWidget(
                                      iconName: 'schedule',
                                      color: const Color(0xFF5D4037),
                                      size: 20,
                                    ),
                                    SizedBox(width: 2.w),
                                    Text(
                                      _selectedTime.format(context),
                                      style: TextStyle(
                                        color: const Color(0xFF2C1810),
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
                                  color: const Color(0xFF2C1810),
                                ),
                              ),
                              SizedBox(height: 1.h),
                              GestureDetector(
                                onTap: () => _showDurationPicker(),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 4.w, vertical: 2.h),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.grey[300]!),
                                  ),
                                  child: Row(
                                    children: [
                                      CustomIconWidget(
                                        iconName: 'timer',
                                        color: const Color(0xFF5D4037),
                                        size: 20,
                                      ),
                                      SizedBox(width: 2.w),
                                      Text(
                                        _durationMinutes > 0
                                            ? '$_durationMinutes min'
                                            : 'Set duration',
                                        style: TextStyle(
                                          color: _durationMinutes > 0
                                              ? const Color(0xFF2C1810)
                                              : Colors.grey[400],
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
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.8.h),
            decoration: BoxDecoration(
              color: isSelected
                  ? category.color.withOpacity(0.15)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? category.color
                    : Colors.grey[300]!,
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
                      : Colors.grey[600]!,
                  size: 18,
                ),
                SizedBox(width: 1.w),
                Expanded(
                  child: Text(
                    category.displayName,
                    style: TextStyle(
                      color: isSelected
                          ? category.color
                          : Colors.black87,
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
                // Current value display
                Text(
                  '$tempDuration min',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF5D4037),
                  ),
                ),
                SizedBox(height: 2.h),

                // Slider
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
                    divisions: 23, // 5-min steps
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

                // Preset buttons
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
                            fontWeight:
                                isActive ? FontWeight.w700 : FontWeight.w500,
                            color: isActive ? Colors.white : Colors.black87,
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
              hourMinuteShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              dialHandColor: const Color(0xFF5D4037),
              dialBackgroundColor: const Color(0xFF5D4037).withOpacity(0.08),
              entryModeIconColor: const Color(0xFF5D4037),
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: const Color(0xFF5D4037),
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
    };

    widget.onTaskAdded(newTask);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Task added successfully!'),
        backgroundColor: AppTheme.getSuccessColor(true),
      ),
    );
  }
}
