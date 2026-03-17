import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'package:intl/intl.dart';
import '../../../core/app_export.dart';
import '../../../services/routine_tracking_service.dart';
import '../../../services/supabase_service.dart';

class ActivityTrackingDialog extends StatefulWidget {
  final String activityName;
  final String scheduledTime;
  final String? taskId;
  final VoidCallback? onComplete;

  const ActivityTrackingDialog({
    super.key,
    required this.activityName,
    required this.scheduledTime,
    this.taskId,
    this.onComplete,
  });

  @override
  State<ActivityTrackingDialog> createState() => _ActivityTrackingDialogState();
}

class _ActivityTrackingDialogState extends State<ActivityTrackingDialog> {
  final RoutineTrackingService _trackingService = RoutineTrackingService();

  bool _isCompleted = false;
  DateTime? _actualTime;
  String? _selectedReason;
  String _notes = '';
  List<Map<String, dynamic>> _suggestions = [];

  final List<String> _commonReasons = [
    'Overslept',
    'Forgot',
    'Busy with work',
    'Not feeling well',
    'Weather issues',
    'Emergency',
    'Travel',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    if (mounted) {
      // Generate helpful suggestions based on activity type
      final activityLower = widget.activityName.toLowerCase();
      final suggestions = <Map<String, dynamic>>[];
      
      if (activityLower.contains('meditation') || activityLower.contains('dhyan')) {
        suggestions.addAll([
          {'title': '🧘 Start Small', 'description': 'Even 5 minutes of meditation daily builds the habit.'},
          {'title': '⏰ Same Time', 'description': 'Try meditating at the same time each day for consistency.'},
        ]);
      } else if (activityLower.contains('yoga') || activityLower.contains('asana')) {
        suggestions.addAll([
          {'title': '🧎 Warm Up First', 'description': 'Light stretching before yoga prevents injuries.'},
          {'title': '💧 Stay Hydrated', 'description': 'Drink water 30 mins before practice.'},
        ]);
      } else if (activityLower.contains('pranayama') || activityLower.contains('breathing')) {
        suggestions.addAll([
          {'title': '💨 Empty Stomach', 'description': 'Practice pranayama on an empty stomach.'},
          {'title': '🌅 Morning Best', 'description': 'Early morning is ideal for breath work.'},
        ]);
      } else if (activityLower.contains('exercise') || activityLower.contains('workout')) {
        suggestions.addAll([
          {'title': '💪 Progressive Overload', 'description': 'Gradually increase intensity for results.'},
          {'title': '😴 Rest Days', 'description': 'Rest days help muscles recover and grow.'},
        ]);
      } else if (activityLower.contains('study') || activityLower.contains('read')) {
        suggestions.addAll([
          {'title': '📚 Pomodoro', 'description': 'Study 25 mins, break 5 mins for better focus.'},
          {'title': '🎯 Active Recall', 'description': 'Test yourself while studying for better retention.'},
        ]);
      } else if (activityLower.contains('journal') || activityLower.contains('write')) {
        suggestions.addAll([
          {'title': '📝 Gratitude First', 'description': 'Start by writing 3 things you\'re grateful for.'},
          {'title': '🌙 Evening Reflection', 'description': 'Journal before bed helps process the day.'},
        ]);
      } else {
        suggestions.addAll([
          {'title': '✨ One Step at a Time', 'description': 'Small daily progress leads to big results.'},
          {'title': '🎯 Set Clear Goals', 'description': 'Know why you\'re doing this activity.'},
        ]);
      }
      
      setState(() {
        _suggestions = suggestions;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Light cream background
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: BoxConstraints(maxHeight: 80.h),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(4.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(2.w),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _isCompleted ? Icons.check_circle : Icons.access_time,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.activityName,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'Scheduled: ${widget.scheduledTime}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 3.h),

              // Completion Status
              Text(
                'Did you complete this activity?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),

              SizedBox(height: 2.h),

              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isCompleted = true),
                      child: Container(
                        padding: EdgeInsets.all(3.w),
                        decoration: BoxDecoration(
                          color: _isCompleted
                              ? Colors.green.withValues(alpha: 0.1)
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                _isCompleted ? Colors.green : Theme.of(context).colorScheme.outline,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: _isCompleted
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                            SizedBox(width: 2.w),
                            Text(
                              'Yes',
                              style: TextStyle(
                                color: _isCompleted
                                    ? Colors.green
                                    : Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isCompleted = false),
                      child: Container(
                        padding: EdgeInsets.all(3.w),
                        decoration: BoxDecoration(
                          color: !_isCompleted
                              ? Colors.red.withValues(alpha: 0.1)
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                !_isCompleted ? Colors.red : Theme.of(context).colorScheme.outline,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cancel,
                              color:
                                  !_isCompleted ? Colors.red : Theme.of(context).colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                            SizedBox(width: 2.w),
                            Text(
                              'No',
                              style: TextStyle(
                                color:
                                    !_isCompleted ? Colors.red : Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 3.h),

              // Actual Time (if completed)
              if (_isCompleted) ...[
                Text(
                  'What time did you actually complete it?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 2.h),
                GestureDetector(
                  onTap: _selectActualTime,
                  child: Container(
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.outline),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        SizedBox(width: 2.w),
                        Text(
                          _actualTime != null
                              ? DateFormat('HH:mm').format(_actualTime!)
                              : 'Select time',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: _actualTime != null
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 3.h),
              ],

              // Reason (if not completed)
              if (!_isCompleted) ...[
                Text(
                  'What was the reason?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 2.h),
                Wrap(
                  spacing: 2.w,
                  runSpacing: 1.h,
                  children: _commonReasons
                      .map((reason) => GestureDetector(
                            onTap: () =>
                                setState(() => _selectedReason = reason),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 3.w, vertical: 1.h),
                              decoration: BoxDecoration(
                                color: _selectedReason == reason
                                    ? Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.1)
                                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _selectedReason == reason
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.outline,
                                ),
                              ),
                              child: Text(
                                reason,
                                style: TextStyle(
                                  color: _selectedReason == reason
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
                SizedBox(height: 3.h),
              ],

              // Notes
              Text(
                'Additional notes (optional)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 2.h),
              TextField(
                maxLines: 3,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Add any notes about this activity...',
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (value) => _notes = value,
              ),

              SizedBox(height: 3.h),

              // Suggestions
              if (_suggestions.isNotEmpty) ...[
                Text(
                  '💡 Suggestions for improvement:',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 2.h),
                ..._suggestions.map((suggestion) => Container(
                      margin: EdgeInsets.only(bottom: 1.h),
                      padding: EdgeInsets.all(3.w),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            suggestion['title'] ?? '',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                          ),
                          SizedBox(height: 0.5.h),
                          Text(
                            suggestion['description'] ?? '',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )),
                SizedBox(height: 3.h),
              ],

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveTracking,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: EdgeInsets.symmetric(vertical: 2.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Save',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
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

  Future<void> _selectActualTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
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

    if (time != null) {
      setState(() {
        final now = DateTime.now();
        _actualTime =
            DateTime(now.year, now.month, now.day, time.hour, time.minute);
      });
    }
  }

  Future<void> _saveTracking() async {
    try {
      // Save to tracking service using the enhanced trackActivity method
      await _trackingService.trackActivity(
        activityName: widget.activityName,
        scheduledTime: widget.scheduledTime,
        completed: _isCompleted,
        actualTime: _actualTime,
        taskId: widget.taskId,
        skipReason: _selectedReason,
        notes: _notes.isNotEmpty ? _notes : null,
      );

      // Also update the main task completion status if taskId is provided
      if (widget.taskId != null) {
        try {
          final supabaseService = SupabaseService();
          final userId = supabaseService.currentUser?.id;

          if (userId != null) {
            final updates = {
              'is_completed': _isCompleted ? 1 : 0,
              'updated_at': DateTime.now().toIso8601String(),
            };
            await supabaseService.updateLocalTask(widget.taskId!, updates);
            debugPrint(
                '✅ Updated Supabase task: ${widget.taskId} - ${_isCompleted ? "completed" : "incomplete"}');
          } else {
            debugPrint('❌ Unable to update task completion without login');
          }
        } catch (e) {
          debugPrint('❌ Error updating task completion: $e');
        }
      } else {
        debugPrint('❌ No task ID provided for update');
      }

      // Haptic feedback
      HapticFeedback.lightImpact();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isCompleted
                ? 'Great job! Activity tracked successfully.'
                : 'Activity marked as missed. Keep trying!'),
            backgroundColor: _isCompleted ? Colors.green : Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );

        Navigator.of(context).pop();
        // Call the completion callback to refresh the dashboard
        widget.onComplete?.call();
      }
    } catch (e) {
      debugPrint('Error saving tracking data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving data. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
