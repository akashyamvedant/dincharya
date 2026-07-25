import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/app_export.dart';
import '../../core/constants/ad_constants.dart';
import '../../services/ads_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/ads/banner_ad_widget.dart';
import './widgets/bottom_action_widget.dart';
import './widgets/calendar_widget.dart';
import './widgets/journal_entry_widget.dart';
import './widgets/mood_selector_widget.dart';
import '../admin_messages/admin_message_popup.dart';

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

  Map<String, Map<String, dynamic>> _journalEntries = {};
  final SupabaseService _supabaseService = SupabaseService();
  final Uuid _uuid = Uuid();
  final ImagePicker _imagePicker = ImagePicker();

  // Attachment state - for new attachments being added
  List<Uint8List> _selectedImages = [];
  List<String> _selectedImageNames = [];
  Uint8List? _selectedAudio;
  String? _selectedAudioName;
  bool _isUploading = false;
  
  // Saved attachment URLs - from loaded entries
  List<String> _savedImageUrls = [];
  String? _savedAudioUrl;

  final List<String> _moodOptions = ['😔', '😐', '😊', '😄', '😍'];

  // Convert emoji to mood rating (1-5)
  int _moodToRating(String mood) {
    switch (mood) {
      case '😔': return 1;
      case '😐': return 2;
      case '😊': return 3;
      case '😄': return 4;
      case '😍': return 5;
      default: return 3;
    }
  }

  // Convert mood rating to emoji
  String _ratingToMood(int rating) {
    switch (rating) {
      case 1: return '😔';
      case 2: return '😐';
      case 3: return '😊';
      case 4: return '😄';
      case 5: return '😍';
      default: return '😊';
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: 2);
    _loadJournalEntries(); // Load entries on init
    _loadEntryForDate(_selectedDate); // Load today's entry
    _journalController.addListener(_onTextChanged);
    // Check for admin in-app messages targeting this page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAdminMessages();
    });
  }

  /// Check for unread admin popup messages targeting this page.
  Future<void> _checkAdminMessages() async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      await AdminMessagePopup.showPendingMessages(context, triggerPage: 'journal');
    } catch (e) {
      debugPrint('⚠️ Admin message check failed: $e');
    }
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
        _journalEntries = {};
        for (var entry in entries) {
          // Handle date field - could be 'date' or parse from 'created_at'
          DateTime? entryDate;
          if (entry['date'] != null) {
            // Try parsing date field (could be 'YYYY-MM-DD' or full ISO string)
            final dateStr = entry['date'].toString();
            entryDate = DateTime.tryParse(dateStr);
          }
          if (entryDate == null && entry['created_at'] != null) {
            entryDate = DateTime.tryParse(entry['created_at'].toString());
          }
          
          if (entryDate != null) {
            final dateKey = _formatDateKey(entryDate);
            _journalEntries[dateKey] = Map<String, dynamic>.from(entry);
          }
        }
      });
      debugPrint('📚 Loaded ${_journalEntries.length} journal entries');
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
        // Convert mood_rating (int) to emoji
        final moodRating = entry['mood_rating'] as int? ?? 3;
        _selectedMood = _ratingToMood(moodRating);
        _journalController.text = (entry['content'] ?? entry['entry'] ?? '') as String;
        _wordCount = (entry['word_count'] ?? 0) as int;
        
        // Load saved attachment URLs
        final imageUrls = entry['image_urls'];
        if (imageUrls != null && imageUrls is List) {
          _savedImageUrls = imageUrls.map((e) => e.toString()).toList();
        } else {
          _savedImageUrls = [];
        }
        _savedAudioUrl = entry['audio_url']?.toString();
        if (_savedAudioUrl?.isEmpty == true) _savedAudioUrl = null;
        
        // Clear new attachments when loading saved entry
        _selectedImages.clear();
        _selectedImageNames.clear();
        _selectedAudio = null;
        _selectedAudioName = null;
      });
    } else {
      setState(() {
        _selectedMood = '😊';
        _journalController.clear();
        _wordCount = 0;
        _savedImageUrls = [];
        _savedAudioUrl = null;
        _selectedImages.clear();
        _selectedImageNames.clear();
        _selectedAudio = null;
        _selectedAudioName = null;
      });
    }
    _writingStartTime = null;
  }

  void _onMoodSelected(String mood) {
    setState(() {
      _selectedMood = mood;
    });
  }

  // Pick photo from gallery or camera
  Future<void> _pickPhoto() async {
    try {
      // Show dialog to choose source
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Select Photo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library, color: Colors.blue),
                title: Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: Icon(Icons.camera_alt, color: Colors.green),
                title: Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImages.add(bytes);
          _selectedImageNames.add(image.name);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Photo added: ${image.name}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Pick audio file
  Future<void> _pickAudio() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          setState(() {
            _selectedAudio = file.bytes;
            _selectedAudioName = file.name;
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Audio added: ${file.name}'),
                backgroundColor: Colors.blue,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick audio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Clear all attachments
  void _clearAttachments() {
    setState(() {
      _selectedImages.clear();
      _selectedImageNames.clear();
      _selectedAudio = null;
      _selectedAudioName = null;
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

    setState(() => _isUploading = true);

    try {
      final dateKey = _formatDateKey(_selectedDate);
      final writingTime = _writingStartTime != null
          ? DateTime.now().difference(_writingStartTime!).inMinutes
          : 0;

      // Upload images if any
      List<String> imageUrls = [];
      for (int i = 0; i < _selectedImages.length; i++) {
        final fileName = 'journal_${userId}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        try {
          final url = await _supabaseService.uploadFile(
            'journal_images',
            fileName,
            _selectedImages[i].toList(),
          );
          imageUrls.add(url);
          debugPrint('📸 Image uploaded: $url');
        } catch (e) {
          debugPrint('❌ Image upload failed: $e');
        }
      }

      // Upload audio if any
      String? audioUrl;
      if (_selectedAudio != null && _selectedAudioName != null) {
        final ext = _selectedAudioName!.split('.').last;
        final fileName = 'journal_${userId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        try {
          audioUrl = await _supabaseService.uploadFile(
            'journal_audio',
            fileName,
            _selectedAudio!.toList(),
          );
          debugPrint('🎵 Audio uploaded: $audioUrl');
        } catch (e) {
          debugPrint('❌ Audio upload failed: $e');
        }
      }

      final entryData = {
        "id": _journalEntries[dateKey]?['id'] ?? _uuid.v4(),
        "user_id": userId,
        'title': 'Journal - ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
        'content': _journalController.text,
        'date': dateKey,
        'mood_rating': _moodToRating(_selectedMood),
        'word_count': _wordCount,
        'writing_time': writingTime,
        'image_urls': imageUrls.isNotEmpty ? imageUrls : null,
        'audio_url': audioUrl,
        'has_photo': imageUrls.isNotEmpty,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabaseService.createJournalEntry(entryData);
      await _loadJournalEntries();
      
      // Clear form after successful save for fresh entry
      setState(() {
        _journalController.clear();
        _selectedMood = '😊';
        _wordCount = 0;
        _writingStartTime = null;
      });
      
      // Clear attachments after successful save
      _clearAttachments();
      
      // Interstitial ad after journal save — REMOVED for premium feel
      // AdsService().showInterstitialAdWithCapping(InterstitialPlacement.journalSaved);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Entry saved! ${imageUrls.length} photos, ${audioUrl != null ? "1 audio" : "0 audio"}'),
            backgroundColor: Theme.of(context).primaryColor,
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
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showInsights() {
    // Calculate real stats from entries
    final now = DateTime.now();
    final weekAgo = now.subtract(Duration(days: 7));
    
    // Count moods for this week
    Map<int, int> moodCounts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    int totalWords = 0;
    int entriesThisWeek = 0;
    
    _journalEntries.forEach((dateKey, entry) {
      final entryDate = DateTime.tryParse(dateKey);
      if (entryDate != null && entryDate.isAfter(weekAgo)) {
        entriesThisWeek++;
        final moodRating = entry['mood_rating'] as int? ?? 3;
        moodCounts[moodRating] = (moodCounts[moodRating] ?? 0) + 1;
        totalWords += (entry['word_count'] as int? ?? 0);
      }
    });
    
    final avgWords = entriesThisWeek > 0 ? (totalWords / entriesThisWeek).round() : 0;
    final totalEntries = _journalEntries.length;
    
    // Calculate streak
    int streak = 0;
    DateTime checkDate = DateTime(now.year, now.month, now.day);
    while (_journalEntries.containsKey(_formatDateKey(checkDate))) {
      streak++;
      checkDate = checkDate.subtract(Duration(days: 1));
    }

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
                                        _buildMoodStat('😍', '${moodCounts[5]}'),
                                        _buildMoodStat('😄', '${moodCounts[4]}'),
                                        _buildMoodStat('😊', '${moodCounts[3]}'),
                                        _buildMoodStat('😐', '${moodCounts[2]}'),
                                        _buildMoodStat('😔', '${moodCounts[1]}'),
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
                                        _buildStatItem('Total Entries', '$totalEntries'),
                                        _buildStatItem('Avg Words', '$avgWords'),
                                        _buildStatItem('Streak', '$streak days'),
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
              ?.copyWith(color: Theme.of(context).primaryColor)),
      SizedBox(height: 0.5.h),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ]);
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  void _showMoodInsights() {
    // Calculate insights from journal entries
    final entries = _journalEntries.values.toList();
    final entryCount = entries.length;
    
    // Calculate average mood
    double avgMood = 3.0;
    if (entries.isNotEmpty) {
      final moodSum = entries.fold<int>(0, (sum, e) => sum + ((e['mood_rating'] as int?) ?? 3));
      avgMood = moodSum / entries.length;
    }
    
    // Calculate total words
    final totalWords = entries.fold<int>(0, (sum, e) => sum + ((e['word_count'] as int?) ?? 0));
    
    // Get mood emoji for average
    final avgMoodEmoji = avgMood <= 1.5 ? '😔' : avgMood <= 2.5 ? '😐' : avgMood <= 3.5 ? '😊' : avgMood <= 4.5 ? '😄' : '😍';
    
    // Get most common mood
    final moodCounts = <int, int>{};
    for (final e in entries) {
      final mood = (e['mood_rating'] as int?) ?? 3;
      moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
    }
    int mostCommonMood = 3;
    int maxCount = 0;
    moodCounts.forEach((mood, count) {
      if (count > maxCount) {
        maxCount = count;
        mostCommonMood = mood;
      }
    });
    final mostCommonEmoji = {1: '😔', 2: '😐', 3: '😊', 4: '😄', 5: '😍'}[mostCommonMood] ?? '😊';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 12.w,
              height: 0.5.h,
              margin: EdgeInsets.symmetric(vertical: 2.h),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(4.w),
              child: Column(
                children: [
                  Text(
                    '📊 Your Mood Insights',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildInsightCard('Total Entries', '$entryCount', Icons.book),
                      _buildInsightCard('Total Words', '$totalWords', Icons.text_fields),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildInsightCard('Avg Mood', '${avgMood.toStringAsFixed(1)} $avgMoodEmoji', Icons.mood),
                      _buildInsightCard('Top Mood', mostCommonEmoji, Icons.star),
                    ],
                  ),
                  SizedBox(height: 3.h),
                  // Encouragement message
                  Container(
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text('💪', style: TextStyle(fontSize: 24)),
                        SizedBox(width: 2.w),
                        Expanded(
                          child: Text(
                            entryCount > 7 
                                ? 'Great job! You\'re building a strong journaling habit!'
                                : entryCount > 0 
                                    ? 'Keep writing! Consistency builds a powerful habit.'
                                    : 'Start journaling today to track your mood journey!',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 2.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard(String title, String value, IconData icon) {
    return Container(
      width: 40.w,
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
          SizedBox(height: 1.h),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final warmBrown = Theme.of(context).colorScheme.primary;
    final warmAmber = Theme.of(context).colorScheme.secondary;
    final warmCream = Theme.of(context).scaffoldBackgroundColor;
    
    return Scaffold(
        backgroundColor: warmCream,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [warmBrown.withOpacity(0.12), warmAmber.withOpacity(0.08)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: warmBrown.withOpacity(0.1)),
                ),
                child: CustomIconWidget(
                  iconName: 'book',
                  color: warmBrown,
                  size: 20,
                ),
              ),
              SizedBox(width: 2.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Journal',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: warmBrown,
                      fontWeight: FontWeight.w800,
                      fontSize: 20.sp,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    'Your daily reflection',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: warmBrown.withOpacity(0.5),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            Padding(
              padding: EdgeInsets.only(right: 2.w),
              child: GestureDetector(
                onTap: _showInsights,
                child: Container(
                  padding: EdgeInsets.all(2.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [warmBrown.withOpacity(0.12), warmAmber.withOpacity(0.08)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: warmBrown.withOpacity(0.1)),
                  ),
                  child: CustomIconWidget(
                    iconName: 'insights',
                    color: warmBrown,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
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
                        // Personalized Greeting Header — editorial style
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                          margin: EdgeInsets.only(bottom: 2.h),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                warmBrown.withOpacity(0.07),
                                warmAmber.withOpacity(0.04),
                                Colors.white.withOpacity(0.3),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: warmBrown.withOpacity(0.12),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: warmBrown.withOpacity(0.06),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_getGreeting()} ✨',
                                      style: TextStyle(
                                        fontSize: 17.sp,
                                        fontWeight: FontWeight.w800,
                                        color: warmBrown,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    SizedBox(height: 0.5.h),
                                    Text(
                                      _selectedDate.day == DateTime.now().day &&
                                              _selectedDate.month == DateTime.now().month &&
                                              _selectedDate.year == DateTime.now().year
                                          ? "What's on your mind today?"
                                          : "Viewing ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        color: warmBrown.withOpacity(0.55),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_journalEntries.containsKey(_formatDateKey(_selectedDate)))
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.green.withOpacity(0.12), Colors.green.withOpacity(0.06)],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.green.withOpacity(0.25)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle_rounded, size: 15, color: Colors.green[600]),
                                      SizedBox(width: 1.w),
                                      Text('Saved', style: TextStyle(fontSize: 10.sp, color: Colors.green[700], fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                )
                              else
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [warmAmber.withOpacity(0.12), warmAmber.withOpacity(0.06)],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: warmAmber.withOpacity(0.25)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit_note_rounded, size: 15, color: warmBrown),
                                      SizedBox(width: 1.w),
                                      Text('New', style: TextStyle(fontSize: 10.sp, color: warmBrown, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Mood Selector
                        MoodSelectorWidget(
                            selectedMood: _selectedMood,
                            moodOptions: _moodOptions,
                            onMoodSelected: _onMoodSelected),
                        SizedBox(height: 2.5.h),

                        // Journal Entry
                        JournalEntryWidget(
                            controller: _journalController,
                            wordCount: _wordCount,
                            isAutoSaving: _isAutoSaving,
                            writingStartTime: _writingStartTime),
                        SizedBox(height: 3.h),

                        // Saved Attachments Display (from loaded entry)
                        if (_savedImageUrls.isNotEmpty || _savedAudioUrl != null)
                          Container(
                            padding: EdgeInsets.all(3.w),
                            margin: EdgeInsets.only(bottom: 2.h),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.green.withOpacity(0.06), Colors.green.withOpacity(0.03)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.green.withOpacity(0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.check_circle, size: 16, color: Colors.green),
                                    SizedBox(width: 1.w),
                                    Text('Saved Attachments', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700])),
                                  ],
                                ),
                                SizedBox(height: 1.h),
                                // Saved Images
                                if (_savedImageUrls.isNotEmpty)
                                  SizedBox(
                                    height: 12.h,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _savedImageUrls.length,
                                      itemBuilder: (ctx, i) => Container(
                                        margin: EdgeInsets.only(right: 2.w),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            _savedImageUrls[i],
                                            height: 12.h,
                                            width: 20.w,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              height: 12.h,
                                              width: 20.w,
                                              color: Colors.grey[200],
                                              child: Icon(Icons.broken_image, color: Colors.grey),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                // Saved Audio
                                if (_savedAudioUrl != null) ...[
                                  SizedBox(height: 1.h),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.audiotrack, size: 16, color: Colors.blue),
                                        SizedBox(width: 1.w),
                                        Text('Audio attached', style: TextStyle(color: Colors.blue, fontSize: 10.sp)),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                        // New Attachment Indicators (being added now)
                        if (_selectedImages.isNotEmpty || _selectedAudio != null)
                          Container(
                            padding: EdgeInsets.all(3.w),
                            margin: EdgeInsets.only(bottom: 2.h),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [warmBrown.withOpacity(0.08), warmAmber.withOpacity(0.04)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: warmBrown.withOpacity(0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('New Attachments', style: TextStyle(fontWeight: FontWeight.bold, color: warmBrown)),
                                SizedBox(height: 1.h),
                                Wrap(
                                  spacing: 2.w,
                                  runSpacing: 1.h,
                                  children: [
                                    ..._selectedImageNames.map((name) => Chip(
                                      avatar: Icon(Icons.image, size: 18, color: Colors.green),
                                      label: Text(name.length > 15 ? '${name.substring(0, 12)}...' : name, style: TextStyle(fontSize: 10.sp)),
                                      deleteIcon: Icon(Icons.close, size: 16),
                                      onDeleted: () {
                                        final idx = _selectedImageNames.indexOf(name);
                                        setState(() {
                                          _selectedImages.removeAt(idx);
                                          _selectedImageNames.removeAt(idx);
                                        });
                                      },
                                    )),
                                    if (_selectedAudioName != null)
                                      Chip(
                                        avatar: Icon(Icons.audiotrack, size: 18, color: Colors.blue),
                                        label: Text(_selectedAudioName!.length > 15 ? '${_selectedAudioName!.substring(0, 12)}...' : _selectedAudioName!, style: TextStyle(fontSize: 10.sp)),
                                        deleteIcon: Icon(Icons.close, size: 16),
                                        onDeleted: () => setState(() { _selectedAudio = null; _selectedAudioName = null; }),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                        // Bottom Actions
                        BottomActionWidget(
                            onSave: _isUploading ? () {} : _saveEntry,
                            onVoiceInput: _pickAudio,
                            onPhotoAttach: _pickPhoto,
                            currentEntryText: _journalController.text,
                            onShowInsights: _showMoodInsights),

                        // Upload Progress Indicator
                        if (_isUploading)
                          Padding(
                            padding: EdgeInsets.only(top: 2.h),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                                SizedBox(width: 2.w),
                                Text('Uploading...', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                      
                        // Banner Ad — REMOVED for premium feel
                        // const BannerAdWidget(placement: BannerPlacement.journal),
                        
                        SizedBox(height: 1.h),
                      ]))),
        ]),
        bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: 3, // Journal tab is now index 3
            backgroundColor: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
            selectedItemColor: Theme.of(context).bottomNavigationBarTheme.selectedItemColor ?? warmBrown,
            unselectedItemColor: Theme.of(context).bottomNavigationBarTheme.unselectedItemColor ?? Colors.grey[600],
            onTap: (index) {
              switch (index) {
                case 0:
                  Navigator.pushReplacementNamed(context, AppRoutes.routineDashboard);
                  break;
                case 1:
                  Navigator.pushReplacementNamed(context, AppRoutes.guidedSessionsHub);
                  break;
                case 2:
                  Navigator.pushReplacementNamed(context, '/tapasya');
                  break;
                case 3:
                  // Current screen - Journal
                  break;
                case 4:
                  Navigator.pushReplacementNamed(context, AppRoutes.profileSettings);
                  break;
              }
            },
            items: [
              BottomNavigationBarItem(
                  icon: Icon(Icons.schedule, color: Theme.of(context).bottomNavigationBarTheme.unselectedItemColor, size: 24),
                  activeIcon: Icon(Icons.schedule, color: Theme.of(context).bottomNavigationBarTheme.selectedItemColor, size: 24),
                  label: 'Routine'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.self_improvement, color: Theme.of(context).bottomNavigationBarTheme.unselectedItemColor, size: 24),
                  activeIcon: Icon(Icons.self_improvement, color: Theme.of(context).bottomNavigationBarTheme.selectedItemColor, size: 24),
                  label: 'Guided'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.local_fire_department, color: Theme.of(context).bottomNavigationBarTheme.unselectedItemColor, size: 24),
                  activeIcon: Icon(Icons.local_fire_department, color: Theme.of(context).bottomNavigationBarTheme.selectedItemColor, size: 24),
                  label: 'Tapasya'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.book, color: Theme.of(context).bottomNavigationBarTheme.selectedItemColor, size: 24),
                  activeIcon: Icon(Icons.book, color: Theme.of(context).bottomNavigationBarTheme.selectedItemColor, size: 24),
                  label: 'Journal'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person, color: Theme.of(context).bottomNavigationBarTheme.unselectedItemColor, size: 24),
                  activeIcon: Icon(Icons.person, color: Theme.of(context).bottomNavigationBarTheme.selectedItemColor, size: 24),
                  label: 'Me'),
            ]));
  }
}
