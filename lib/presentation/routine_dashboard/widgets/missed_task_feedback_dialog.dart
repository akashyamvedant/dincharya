import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/task_categories.dart';

/// Dialog shown when user tries to complete a task while a previous
/// inevitable task (wakeup, eating, sleep, hygiene) was missed.
/// Collects feedback: actual time done and reason for missing.
class MissedTaskFeedbackDialog extends StatefulWidget {
  final Map<String, dynamic> missedTask;

  const MissedTaskFeedbackDialog({
    super.key,
    required this.missedTask,
  });

  /// Shows dialog and returns true if user provided feedback or skipped.
  /// Returns false if dialog was dismissed.
  static Future<bool> show(
      BuildContext context, Map<String, dynamic> missedTask) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => MissedTaskFeedbackDialog(missedTask: missedTask),
    );
    return result ?? false;
  }

  @override
  State<MissedTaskFeedbackDialog> createState() =>
      _MissedTaskFeedbackDialogState();
}

class _MissedTaskFeedbackDialogState extends State<MissedTaskFeedbackDialog> {
  TimeOfDay _actualTime = TimeOfDay.now();
  String? _selectedReason;
  final TextEditingController _notesController = TextEditingController();
  bool _isSaving = false;

  final List<Map<String, dynamic>> _reasons = [
    {'id': 'overslept', 'label': 'Overslept', 'icon': Icons.hotel},
    {'id': 'tired', 'label': 'Tired', 'icon': Icons.battery_alert},
    {'id': 'forgot', 'label': 'Forgot', 'icon': Icons.psychology_alt},
    {'id': 'busy', 'label': 'Busy', 'icon': Icons.work_outline},
    {'id': 'skipped', 'label': 'Skipped', 'icon': Icons.skip_next},
    {'id': 'not_needed', 'label': 'Not Needed', 'icon': Icons.block},
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskTitle = widget.missedTask['title'] ?? 'Task';
    final scheduledTime = widget.missedTask['time'] ?? '';
    final categoryId =
        widget.missedTask['category'] ?? widget.missedTask['type'] ?? 'other';
    final category = TaskCategory.findById(categoryId);

    return Dialog(
      backgroundColor: const Color(0xFFFDF8F3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 5.h),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(5.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.feedback_outlined,
                      color: Colors.orange.shade700,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Missed Task',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C1810),
                          ),
                        ),
                        Text(
                          'Quick feedback helps track habits',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 2.5.h),

              // Missed task info card
              Container(
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.red.shade100,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: category.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getIconData(category.icon),
                        color: category.color,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            taskTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Color(0xFF2C1810),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Scheduled at $scheduledTime',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Missed',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 2.5.h),

              // Actual time picker
              const Text(
                'When did you actually do it?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C1810),
                ),
              ),
              SizedBox(height: 1.h),
              GestureDetector(
                onTap: _pickActualTime,
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF5D4037)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.schedule,
                        color: Color(0xFF5D4037),
                        size: 20,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        _actualTime.format(context),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF5D4037),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 2.5.h),

              // Reason chips
              const Text(
                'Reason (optional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C1810),
                ),
              ),
              SizedBox(height: 1.h),
              Wrap(
                spacing: 2.w,
                runSpacing: 1.h,
                children: _reasons.map((reason) {
                  final isSelected = _selectedReason == reason['id'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedReason =
                            isSelected ? null : reason['id'] as String;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(
                          horizontal: 3.w, vertical: 1.h),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF5D4037)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF5D4037)
                              : Colors.grey[300]!,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            reason['icon'] as IconData,
                            size: 14,
                            color: isSelected
                                ? Colors.white
                                : Colors.grey[600],
                          ),
                          SizedBox(width: 1.w),
                          Text(
                            reason['label'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              SizedBox(height: 2.h),

              // Notes (optional)
              TextField(
                controller: _notesController,
                maxLines: 2,
                style: const TextStyle(color: Colors.black87, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Any notes? (optional)',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
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
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 3.w, vertical: 1.5.h),
                ),
              ),

              SizedBox(height: 3.h),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveFeedback,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5D4037),
                        padding: EdgeInsets.symmetric(vertical: 1.5.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save & Continue',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickActualTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _actualTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(0xFF5D4037),
                  surface: const Color(0xFFFDF8F3),
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _actualTime = picked);
    }
  }

  Future<void> _saveFeedback() async {
    setState(() => _isSaving = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        Navigator.pop(context, true);
        return;
      }

      final taskId = widget.missedTask['id'];
      final taskTitle = widget.missedTask['title'] ?? 'Task';
      final scheduledTime = widget.missedTask['time'] ?? '';
      final now = DateTime.now();
      final actualTimeStr = _actualTime.format(context);

      // Save feedback to routine_tracking table
      try {
        await supabase.from('routine_tracking').upsert({
          'user_id': userId,
          'task_id': taskId,
          'activity_name': taskTitle,
          'tracking_date': now.toIso8601String().substring(0, 10),
          'actual_time': actualTimeStr,
          'scheduled_time': scheduledTime,
          'skip_reason': _selectedReason,
          'notes': _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
          'completed': true,
          'status': 'missed_with_feedback',
          'updated_at': now.toIso8601String(),
        }, onConflict: 'user_id,task_id,tracking_date');
      } catch (e) {
        // If routine_tracking doesn't have these columns yet, 
        // save to a simpler format
        debugPrint('Feedback save note: $e');
        try {
          await supabase.from('routine_tracking').upsert({
            'user_id': userId,
            'task_id': taskId,
            'activity_name': taskTitle,
            'tracking_date': now.toIso8601String().substring(0, 10),
            'status': 'missed_with_feedback',
            'completed': true,
            'notes': 'Actual: $actualTimeStr | Reason: ${_selectedReason ?? "none"} | ${_notesController.text.trim()}',
            'updated_at': now.toIso8601String(),
          }, onConflict: 'user_id,task_id,tracking_date');
        } catch (e2) {
          debugPrint('Feedback fallback save error: $e2');
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error saving missed task feedback: $e');
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'wb_sunny':
        return Icons.wb_sunny;
      case 'shower':
        return Icons.shower;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'air':
        return Icons.air;
      case 'directions_run':
        return Icons.directions_run;
      case 'restaurant':
        return Icons.restaurant;
      case 'menu_book':
        return Icons.menu_book;
      case 'work':
        return Icons.work;
      case 'edit_note':
        return Icons.edit_note;
      case 'bedtime':
        return Icons.bedtime;
      case 'task_alt':
        return Icons.task_alt;
      default:
        return Icons.circle;
    }
  }
}
