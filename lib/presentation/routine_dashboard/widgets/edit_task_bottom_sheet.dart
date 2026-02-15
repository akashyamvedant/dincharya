import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

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
  late String _selectedCategory;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Meditation', 'icon': 'self_improvement'},
    {'name': 'Yoga', 'icon': 'fitness_center'},
    {'name': 'Pranayam', 'icon': 'air'},
    {'name': 'Study', 'icon': 'menu_book'},
    {'name': 'Exercise', 'icon': 'directions_run'},
    {'name': 'Work', 'icon': 'work'},
    {'name': 'Other', 'icon': 'task_alt'},
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task['title'] ?? '');
    _descriptionController = TextEditingController(text: widget.task['description'] ?? '');
    _selectedCategory = widget.task['category'] ?? 'meditation';
    
    // Parse time from task
    final timeStr = widget.task['time'] ?? '06:00 AM';
    _selectedTime = _parseTimeString(timeStr);
  }

  TimeOfDay _parseTimeString(String timeStr) {
    try {
      // Handle formats like "6:00 AM", "06:00", "14:30"
      final parts = timeStr.replaceAll(RegExp(r'[AP]M', caseSensitive: false), '').trim().split(':');
      int hour = int.parse(parts[0]);
      int minute = parts.length > 1 ? int.parse(parts[1]) : 0;
      
      // Adjust for PM
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
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _saveTask() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task title')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final updatedTask = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'category': _selectedCategory.toLowerCase(),
      'time': _selectedTime.format(context),
    };

    widget.onTaskUpdated(updatedTask);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF8F3), // Light cream background (was dark)
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
          
          // Title - explicit dark color for visibility
          Text(
            'Edit Task',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2C1810), // Dark brown text
            ),
          ),
          SizedBox(height: 3.h),

          // Task Title - light background input
          TextField(
            controller: _titleController,
            style: TextStyle(color: Colors.black87), // Input text color
            decoration: InputDecoration(
              labelText: 'Task Title',
              labelStyle: TextStyle(color: Colors.grey[600]),
              hintText: 'E.g., Morning Meditation',
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: Icon(Icons.title, color: const Color(0xFF5D4037)),
              filled: true,
              fillColor: Colors.white, // Light fill
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
                borderSide: BorderSide(color: const Color(0xFF5D4037), width: 2),
              ),
            ),
          ),
          SizedBox(height: 2.h),

          // Description - light background input
          TextField(
            controller: _descriptionController,
            maxLines: 2,
            style: TextStyle(color: Colors.black87),
            decoration: InputDecoration(
              labelText: 'Description (Optional)',
              labelStyle: TextStyle(color: Colors.grey[600]),
              hintText: 'Add notes about this task',
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: Icon(Icons.notes, color: const Color(0xFF5D4037)),
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
                borderSide: BorderSide(color: const Color(0xFF5D4037), width: 2),
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
              color: const Color(0xFF2C1810), // Dark brown for visibility
            ),
          ),
          SizedBox(height: 1.h),
          SizedBox(
            height: 6.h,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory.toLowerCase() == 
                    category['name'].toString().toLowerCase();
                return Padding(
                  padding: EdgeInsets.only(right: 2.w),
                  child: ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomIconWidget(
                          iconName: category['icon'],
                          size: 18,
                          color: isSelected ? Colors.white : Colors.black54,
                        ),
                        SizedBox(width: 1.w),
                        Text(category['name']),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category['name'];
                      });
                    },
                    selectedColor: const Color(0xFF5D4037), // Brown when selected
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 2.h),

          // Time Selection
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: ListTile(
              leading: Icon(
                Icons.access_time,
                color: const Color(0xFF5D4037),
              ),
              title: Text(
                'Scheduled Time',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                _selectedTime.format(context),
                style: TextStyle(
                  color: const Color(0xFF5D4037),
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: Icon(
                Icons.edit,
                color: const Color(0xFF5D4037),
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
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.lightTheme.colorScheme.primary,
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
                      : Text(
                          'Save Changes',
                          style: TextStyle(
                            color: AppTheme.lightTheme.colorScheme.onPrimary,
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
    );
  }
}
