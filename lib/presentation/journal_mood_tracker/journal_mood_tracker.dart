import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:uuid/uuid.dart'; // For generating unique IDs

import '../../core/app_export.dart';
import '../../services/supabase_service.dart';
import './widgets/bottom_action_widget.dart';
import './widgets/calendar_widget.dart';
import './widgets/journal_entry_widget.dart';
import './widgets/mood_selector_widget.dart';

class JournalMoodTracker extends StatefulWidget {
  const JournalMoodTracker({super.key});

  @override
  State<JournalMoodTracker> createState() => _JournalMoodTrackerState();
}

class _JournalMoodTrackerState extends State<JournalMoodTracker>
    with TickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  String _selectedMood = '😊';
  final TextEditingController _journalController = TextEditingController();
  bool _isAutoSaving = false;
  int _wordCount = 0;
  DateTime? _writingStartTime;

  Map<String, Map<String, dynamic>> _journalEntries =
      {}; // Changed to mutable map
  final SupabaseService _supabaseService = SupabaseService();
  final Uuid _uuid = Uuid(); // Initialize Uuid

  final List<String> _moodOptions = ['😔', '😐', '😊', '😄', '😍'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: 2);
    _loadJournalEntries(); // Load entries on init
    _loadEntryForDate(_selectedDate); // Load today's entry
    _journalController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _journalController.dispose();
    super.dispose();
  }

  Future<void> _loadJournalEntries() async {
    final userId = _supabaseService.currentUser?.id;
    if (userId == null) return;

    try {
      final entries = await _supabaseService.getJournalEntries(userId);
      setState(() {
        _journalEntries = {
          for (var entry in entries)
            _formatDateKey(DateTime.parse(entry['date'])):
                Map<String, dynamic>.from(entry)
        };
      });
    } catch (e) {
      debugPrint('Error loading journal entries: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load journal entries: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  // Removed unused method _loadTodayEntry

  void _onTextChanged() {
    if (_writingStartTime == null && _journalController.text.isNotEmpty) {
      _writingStartTime = DateTime.now();
    }

    setState(() {
      _wordCount = _journalController.text
          .split(' ')
          .where((word) => word.isNotEmpty)
          .length;
    });

    _autoSave();
  }

  void _autoSave() {
    if (_isAutoSaving) return;

    setState(() {
      _isAutoSaving = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isAutoSaving = false;
        });
      }
    });
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    _loadEntryForDate(date);
  }

  void _loadEntryForDate(DateTime date) {
    final dateKey = _formatDateKey(date);
    final entry = _journalEntries[dateKey];

    if (entry != null) {
      setState(() {
        _selectedMood = entry['mood'] as String;
        _journalController.text = entry['entry'] as String;
        _wordCount = entry['wordCount'] as int;
      });
    } else {
      setState(() {
        _selectedMood = '😊';
        _journalController.clear();
        _wordCount = 0;
      });
    }
    _writingStartTime = null;
  }

  void _onMoodSelected(String mood) {
    setState(() {
      _selectedMood = mood;
    });
  }

  Future<void> _saveEntry() async {
    final userId = _supabaseService.currentUser?.id;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please log in to save journal entries.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    final dateKey = _formatDateKey(_selectedDate);
    final writingTime = _writingStartTime != null
        ? DateTime.now().difference(_writingStartTime!).inMinutes
        : 0;

    final entryData = {
      "id": _journalEntries[dateKey]?['id'] ??
          _uuid.v4(), // Use existing ID or generate new
      "user_id": userId,
      'date': dateKey,
      'mood': _selectedMood,
      'entry': _journalController.text,
      'word_count': _wordCount, // Changed to match Supabase schema
      'writing_time': writingTime, // Changed to match Supabase schema
      'has_photo': false,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      await _supabaseService
          .createJournalEntry(entryData); // create handles update if ID exists
      await _loadJournalEntries(); // Reload all entries
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Entry saved successfully!'),
            backgroundColor: AppTheme.lightTheme.primaryColor,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving journal entry: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save entry: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showInsights() {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
            height: 70.h,
            decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(children: [
              Container(
                  width: 12.w,
                  height: 0.5.h,
                  margin: EdgeInsets.symmetric(vertical: 2.h),
                  decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: Text('Mood Insights',
                      style: Theme.of(context).textTheme.headlineSmall)),
              SizedBox(height: 3.h),
              Expanded(
                  child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.w),
                      child: Column(children: [
                        Container(
                            padding: EdgeInsets.all(4.w),
                            decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(12)),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('This Week',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  SizedBox(height: 2.h),
                                  Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildMoodStat('😍', '2'),
                                        _buildMoodStat('😄', '3'),
                                        _buildMoodStat('😊', '1'),
                                        _buildMoodStat('😐', '1'),
                                        _buildMoodStat('😔', '0'),
                                      ]),
                                ])),
                        SizedBox(height: 2.h),
                        Container(
                            padding: EdgeInsets.all(4.w),
                            decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(12)),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Journal Stats',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  SizedBox(height: 2.h),
                                  Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildStatItem('Total Entries', '15'),
                                        _buildStatItem('Avg Words', '12'),
                                        _buildStatItem('Streak', '7 days'),
                                      ]),
                                ])),
                      ]))),
            ])));
  }

  Widget _buildMoodStat(String emoji, String count) {
    return Column(children: [
      Text(emoji, style: TextStyle(fontSize: 20.sp)),
      SizedBox(height: 0.5.h),
      Text(count, style: Theme.of(context).textTheme.bodySmall),
    ]);
  }

  Widget _buildStatItem(String label, String value) {
    return Column(children: [
      Text(value,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: AppTheme.lightTheme.primaryColor)),
      SizedBox(height: 0.5.h),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text('Journal & Mood'), actions: [
          IconButton(
              onPressed: _showInsights,
              icon: CustomIconWidget(
                  iconName: 'insights',
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 24)),
        ]),
        body: Column(children: [
          // Calendar Header
          CalendarWidget(
              selectedDate: _selectedDate,
              journalEntries: _journalEntries,
              onDateSelected: _onDateSelected),

          // Main Content
          Expanded(
              child: SingleChildScrollView(
                  padding: EdgeInsets.all(4.w),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Today's Entry Header
                        Text(
                            _selectedDate.day == DateTime.now().day &&
                                    _selectedDate.month ==
                                        DateTime.now().month &&
                                    _selectedDate.year == DateTime.now().year
                                ? "Today's Entry"
                                : "Entry for ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                            style: Theme.of(context).textTheme.headlineSmall),
                        SizedBox(height: 2.h),

                        // Mood Selector
                        MoodSelectorWidget(
                            selectedMood: _selectedMood,
                            moodOptions: _moodOptions,
                            onMoodSelected: _onMoodSelected),
                        SizedBox(height: 3.h),

                        // Journal Entry
                        JournalEntryWidget(
                            controller: _journalController,
                            wordCount: _wordCount,
                            isAutoSaving: _isAutoSaving,
                            writingStartTime: _writingStartTime),
                        SizedBox(height: 3.h),

                        // Bottom Actions
                        BottomActionWidget(
                            onSave: _saveEntry,
                            onVoiceInput: () {
                              // Voice input functionality would be implemented here
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Voice input feature coming soon!')));
                            },
                            onPhotoAttach: () {
                              // Photo attachment functionality would be implemented here
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Photo attachment feature coming soon!')));
                            }),
                      ]))),
        ]),
        bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: 2, // Journal tab active
            onTap: (index) {
              switch (index) {
                case 0:
                  Navigator.pushNamed(context, AppRoutes.routineDashboard);
                  break;
                case 1:
                  Navigator.pushNamed(context, AppRoutes.guidedSessionsHub);
                  break;
                case 2:
                  // Current screen - Journal
                  break;
                case 3:
                  Navigator.pushNamed(context, AppRoutes.profileSettings);
                  break;
              }
            },
            items: [
              BottomNavigationBarItem(
                  icon: CustomIconWidget(
                      iconName: 'schedule',
                      color: Theme.of(context)
                          .bottomNavigationBarTheme
                          .unselectedItemColor!,
                      size: 24),
                  activeIcon: CustomIconWidget(
                      iconName: 'schedule',
                      color: Theme.of(context)
                          .bottomNavigationBarTheme
                          .selectedItemColor!,
                      size: 24),
                  label: 'Routine'),
              BottomNavigationBarItem(
                  icon: CustomIconWidget(
                      iconName: 'self_improvement',
                      color: Theme.of(context)
                          .bottomNavigationBarTheme
                          .unselectedItemColor!,
                      size: 24),
                  activeIcon: CustomIconWidget(
                      iconName: 'self_improvement',
                      color: Theme.of(context)
                          .bottomNavigationBarTheme
                          .selectedItemColor!,
                      size: 24),
                  label: 'Guided'),
              BottomNavigationBarItem(
                  icon: CustomIconWidget(
                      iconName: 'book',
                      color: Theme.of(context)
                          .bottomNavigationBarTheme
                          .selectedItemColor!,
                      size: 24),
                  activeIcon: CustomIconWidget(
                      iconName: 'book',
                      color: Theme.of(context)
                          .bottomNavigationBarTheme
                          .selectedItemColor!,
                      size: 24),
                  label: 'Journal'),
              BottomNavigationBarItem(
                  icon: CustomIconWidget(
                      iconName: 'person',
                      color: Theme.of(context)
                          .bottomNavigationBarTheme
                          .unselectedItemColor!,
                      size: 24),
                  activeIcon: CustomIconWidget(
                      iconName: 'person',
                      color: Theme.of(context)
                          .bottomNavigationBarTheme
                          .selectedItemColor!,
                      size: 24),
                  label: 'Me'),
            ]));
  }
}
