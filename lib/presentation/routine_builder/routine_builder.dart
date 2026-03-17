import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_export.dart';
import '../../theme/app_theme.dart';
import '../../services/supabase_service.dart';
import './widgets/advanced_settings_widget.dart';
import './widgets/schedule_section_widget.dart';
import './widgets/task_details_form_widget.dart';
import './widgets/task_type_selector_widget.dart';

class RoutineBuilder extends StatefulWidget {
  const RoutineBuilder({super.key});

  @override
  State<RoutineBuilder> createState() => _RoutineBuilderState();
}

class _RoutineBuilderState extends State<RoutineBuilder> {
  final TextEditingController _routineNameController = TextEditingController();
  final TextEditingController _taskTitleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String _selectedTaskType = 'Meditation';
  int _selectedDuration = 15;
  TimeOfDay _selectedTime = TimeOfDay.now();
  List<String> _selectedDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
  bool _notificationsEnabled = true;
  String _selectedMeditationType = 'Mindfulness';
  String _selectedYogaSequence = 'Sun Salutation';
  String _selectedStudyMode = 'Pomodoro';
  bool _isSaving = false;

  final SupabaseService _supabaseService = SupabaseService();
  final Uuid _uuid = const Uuid();

  final List<Map<String, dynamic>> _taskTypes = [
    {'name': 'Meditation', 'icon': 'self_improvement'},
    {'name': 'Yoga', 'icon': 'fitness_center'},
    {'name': 'Study', 'icon': 'menu_book'},
    {'name': 'Work', 'icon': 'work'},
  ];

  final List<String> _meditationTypes = [
    'Mindfulness',
    'Breathing',
    'Body Scan',
    'Loving Kindness',
    'Concentration'
  ];

  final List<String> _yogaSequences = [
    'Sun Salutation',
    'Moon Salutation',
    'Warrior Sequence',
    'Hip Openers',
    'Backbends'
  ];

  final List<String> _studyModes = [
    'Pomodoro',
    'Deep Focus',
    'Active Recall',
    'Spaced Repetition',
    'Mind Mapping'
  ];

  final List<String> _weekDays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun'
  ];

  @override
  void initState() {
    super.initState();
    _routineNameController.text = 'Morning Routine';
    _taskTitleController.text = 'Daily Meditation';
  }

  @override
  void dispose() {
    _routineNameController.dispose();
    _taskTitleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveRoutine() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isSaving = true;
      });

      try {
        // Get current user ID
        final userId = _supabaseService.currentUser?.id;
        if (userId == null) {
          throw Exception('User not logged in');
        }

        // Create task object with proper field mapping
        final taskData = {
          'id': _uuid.v4(),
          'user_id': userId,
          'title': _taskTitleController.text.trim(),
          'description': _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : 'Daily ${_selectedTaskType.toLowerCase()} practice',
          'category': _selectedTaskType.toLowerCase(),
          'time': _selectedTime.format(context),
          'priority': 1,
          'status': 'pending',
          'is_completed': false,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        // Save to database
        await _supabaseService.createLocalTask(taskData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Task "${_taskTitleController.text}" saved successfully!'),
              backgroundColor: AppTheme.getSuccessColor(
                  Theme.of(context).brightness == Brightness.light),
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        debugPrint('Error saving routine: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save task: ${e.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
  }

  void _cancelRoutine() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: TextButton(
          onPressed: _cancelRoutine,
          child: Text(
            'Cancel',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
        title: Text(
          'Routine Builder',
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveRoutine,
            child: _isSaving
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                : Text(
                    'Save',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Routine Name Input
              Container(
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
                    Text(
                      'Routine Name',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    SizedBox(height: 1.h),
                    TextFormField(
                      controller: _routineNameController,
                      decoration: const InputDecoration(
                        hintText: 'Enter routine name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a routine name';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              SizedBox(height: 3.h),

              // Task Type Selection
              TaskTypeSelectorWidget(
                taskTypes: _taskTypes,
                selectedTaskType: _selectedTaskType,
                onTaskTypeChanged: (taskType) {
                  setState(() {
                    _selectedTaskType = taskType;
                  });
                },
              ),

              SizedBox(height: 3.h),

              // Task Details Form
              TaskDetailsFormWidget(
                taskTitleController: _taskTitleController,
                selectedTaskType: _selectedTaskType,
                selectedDuration: _selectedDuration,
                selectedMeditationType: _selectedMeditationType,
                selectedYogaSequence: _selectedYogaSequence,
                selectedStudyMode: _selectedStudyMode,
                meditationTypes: _meditationTypes,
                yogaSequences: _yogaSequences,
                studyModes: _studyModes,
                onDurationChanged: (duration) {
                  setState(() {
                    _selectedDuration = duration;
                  });
                },
                onMeditationTypeChanged: (type) {
                  setState(() {
                    _selectedMeditationType = type;
                  });
                },
                onYogaSequenceChanged: (sequence) {
                  setState(() {
                    _selectedYogaSequence = sequence;
                  });
                },
                onStudyModeChanged: (mode) {
                  setState(() {
                    _selectedStudyMode = mode;
                  });
                },
              ),

              SizedBox(height: 3.h),

              // Schedule Section
              ScheduleSectionWidget(
                selectedTime: _selectedTime,
                selectedDays: _selectedDays,
                weekDays: _weekDays,
                onTimeChanged: (time) {
                  setState(() {
                    _selectedTime = time;
                  });
                },
                onDaysChanged: (days) {
                  setState(() {
                    _selectedDays = days;
                  });
                },
              ),

              SizedBox(height: 3.h),

              // Advanced Settings
              AdvancedSettingsWidget(
                notesController: _notesController,
                notificationsEnabled: _notificationsEnabled,
                onNotificationToggle: (enabled) {
                  setState(() {
                    _notificationsEnabled = enabled;
                  });
                },
              ),

              SizedBox(height: 4.h),
            ],
          ),
        ),
      ),
    );
  }
}
