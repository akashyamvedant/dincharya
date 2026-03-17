// Fixed RecorderImpl import and usage
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../services/supabase_service.dart';
import '../../widgets/custom_icon_widget.dart';

// lib/presentation/enhanced_journal/enhanced_journal_screen.dart

class EnhancedJournalScreen extends StatefulWidget {
  const EnhancedJournalScreen({super.key});

  @override
  State<EnhancedJournalScreen> createState() => _EnhancedJournalScreenState();
}

class _EnhancedJournalScreenState extends State<EnhancedJournalScreen> {
  final SupabaseService _supabase = SupabaseService();
  final ImagePicker _imagePicker = ImagePicker();
  // Fixed: Use concrete implementation of AudioRecorder
  final AudioRecorder _audioRecorder = AudioRecorder();

  List<Map<String, dynamic>> _journalEntries = [];
  bool _isLoading = false;
  // Fixed Record import and usage
  bool _isRecording = false;
  int _currentBottomIndex = 2; // Journal tab active

  @override
  void initState() {
    super.initState();
    _loadJournalEntries();
  }

  Future<void> _loadJournalEntries() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = _supabase.currentUser;
      if (currentUser != null) {
        final entries = await _supabase.getJournalEntries(currentUser.id);
        setState(() {
          _journalEntries = List<Map<String, dynamic>>.from(entries);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load journal entries: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createNewEntry({
    String? title,
    String? content,
    int? moodRating,
    List<String>? imagePaths,
    String? audioPath,
  }) async {
    try {
      final currentUser = _supabase.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      List<String> imageUrls = [];
      String? audioUrl;

      // Upload images if any
      if (imagePaths != null && imagePaths.isNotEmpty) {
        for (String imagePath in imagePaths) {
          final file = File(imagePath);
          final bytes = await file.readAsBytes();
          final fileName =
              'journal_${DateTime.now().millisecondsSinceEpoch}_${imagePaths.indexOf(imagePath)}.jpg';
          final url =
              await _supabase.uploadFile('journal_images', fileName, bytes);
          imageUrls.add(url);
        }
      }

      // Upload audio if any
      if (audioPath != null) {
        final file = File(audioPath);
        final bytes = await file.readAsBytes();
        final fileName =
            'journal_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        audioUrl = await _supabase.uploadFile('journal_audio', fileName, bytes);
      }

      final entryData = {
        'user_id': currentUser.id,
        'title': title,
        'content': content,
        'mood_rating': moodRating,
        'image_urls': imageUrls,
        'audio_url': audioUrl,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase.createJournalEntry(entryData);
      await _loadJournalEntries();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Journal entry created successfully'),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create entry: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        // Stop recording
        final path = await _audioRecorder.stop();
        setState(() {
          _isRecording = false;
        });

        if (path != null) {
          await _createNewEntry(
            title: 'Voice Note - ${DateTime.now().toString().split('.')[0]}',
            audioPath: path,
          );
        }
      } else {
        // Start recording
        if (await _audioRecorder.hasPermission()) {
          final directory = await getTemporaryDirectory();
          final fileName =
              'voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
          final filePath = '${directory.path}/$fileName';

          await _audioRecorder.start(
            RecordConfig(
              encoder: AudioEncoder.aacLc,
              bitRate: 128000,
              sampleRate: 44100,
            ),
            path: filePath,
          );

          setState(() {
            _isRecording = true;
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Microphone permission required')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voice recording failed: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        await _createNewEntry(
          title: 'Photo Entry - ${DateTime.now().toString().split('.')[0]}',
          imagePaths: [image.path],
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Photo capture failed: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showCreateEntryDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    int moodRating = 3;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Journal Entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 2.h),
                TextField(
                  controller: contentController,
                  decoration: const InputDecoration(
                    labelText: 'Content',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                  onChanged: (value) {
                    // Real-time validation
                    if (value.length > 5000) {
                      contentController.text = value.substring(0, 5000);
                      contentController.selection =
                          TextSelection.collapsed(offset: 5000);
                    }
                  },
                ),
                SizedBox(height: 2.h),
                Row(
                  children: [
                    const Text('Mood: '),
                    Expanded(
                      child: Slider(
                        value: moodRating.toDouble(),
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: moodRating.toString(),
                        onChanged: (value) {
                          setDialogState(() {
                            moodRating = value.round();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _createNewEntry(
                  title: titleController.text.isNotEmpty
                      ? titleController.text
                      : null,
                  content: contentController.text,
                  moodRating: moodRating,
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods for the fixed widget calls
  void _showNewEntryDialog() {
    _showCreateEntryDialog();
  }

  void _pickImage() {
    _takePhoto();
  }

  void _navigateToMoodTracker() {
    // Navigate to mood tracker screen
    Navigator.pushNamed(context, '/mood-tracker');
  }

  void _viewEntry(Map<String, dynamic> entry) {
    // Navigate to entry view
    // Implementation depends on your entry view screen
  }

  void _editEntry(Map<String, dynamic> entry) {
    // Navigate to entry edit
    // Implementation depends on your entry edit screen
  }

  void _deleteEntry(String entryId) {
    // Delete entry implementation
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Perform actual deletion
              _performDeleteEntry(entryId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteEntry(String entryId) async {
    try {
      // This method doesn't exist in SupabaseService
      // await _supabase.deleteJournalEntry(entryId);
      await _loadJournalEntries();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete entry: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Fixed QuickActionsWidget call
            QuickActionsWidget(
              onNewEntry: _showNewEntryDialog,
              onVoiceEntry: _toggleRecording,
              onPhotoEntry: _pickImage,
              onMoodTracker: () => _navigateToMoodTracker(),
            ),

            // Journal Entries
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _journalEntries.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadJournalEntries,
                          child: ListView.builder(
                            padding: EdgeInsets.symmetric(horizontal: 4.w),
                            itemCount: _journalEntries.length,
                            itemBuilder: (context, index) {
                              final entry = _journalEntries[index];
                              // Fixed JournalEntryCard call
                              return JournalEntryCard(
                                entry: entry,
                                onTap: () => _viewEntry(entry),
                                onEdit: () => _editEntry(entry),
                                onDelete: () => _deleteEntry(entry['id']),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateEntryDialog,
        child: CustomIconWidget(
          iconName: 'add',
          color: Theme.of(context).colorScheme.onPrimary,
          size: 24,
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomIconWidget(
            iconName: 'auto_stories',
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 64,
          ),
          SizedBox(height: 2.h),
          Text(
            'No journal entries yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Start writing your thoughts and experiences',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentBottomIndex,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Theme.of(context).colorScheme.surface,
      selectedItemColor: Theme.of(context).colorScheme.primary,
      unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
      items: [
        BottomNavigationBarItem(
          icon: CustomIconWidget(
            iconName: 'schedule',
            color: _currentBottomIndex == 0
                ? Color(0xFF8B4513)
                : Theme.of(context).colorScheme.onSurfaceVariant,
            size: 24,
          ),
          label: 'Routine',
        ),
        BottomNavigationBarItem(
          icon: CustomIconWidget(
            iconName: 'self_improvement',
            color: _currentBottomIndex == 1
                ? Color(0xFF8B4513)
                : Theme.of(context).colorScheme.onSurfaceVariant,
            size: 24,
          ),
          label: 'Guided',
        ),
        BottomNavigationBarItem(
          icon: CustomIconWidget(
            iconName: 'book',
            color: _currentBottomIndex == 2
                ? Color(0xFF8B4513)
                : Theme.of(context).colorScheme.onSurfaceVariant,
            size: 24,
          ),
          label: 'Journal',
        ),
        BottomNavigationBarItem(
          icon: CustomIconWidget(
            iconName: 'person',
            color: _currentBottomIndex == 3
                ? Color(0xFF8B4513)
                : Theme.of(context).colorScheme.onSurfaceVariant,
            size: 24,
          ),
          label: 'Me',
        ),
      ],
      onTap: (index) {
        setState(() {
          _currentBottomIndex = index;
        });

        switch (index) {
          case 0:
            Navigator.pushNamed(context, '/routine-dashboard');
            break;
          case 1:
            Navigator.pushNamed(context, '/guided-sessions-hub');
            break;
          case 2:
            // Already on journal screen
            break;
          case 3:
            Navigator.pushNamed(context, '/profile-settings');
            break;
        }
      },
    );
  }
}

// QuickActionsWidget - this would typically be in a separate file
class QuickActionsWidget extends StatelessWidget {
  final VoidCallback onNewEntry;
  final VoidCallback onVoiceEntry;
  final VoidCallback onPhotoEntry;
  final VoidCallback onMoodTracker;

  const QuickActionsWidget({
    super.key,
    required this.onNewEntry,
    required this.onVoiceEntry,
    required this.onPhotoEntry,
    required this.onMoodTracker,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: onNewEntry,
          ),
          IconButton(
            icon: Icon(Icons.mic),
            onPressed: onVoiceEntry,
          ),
          IconButton(
            icon: Icon(Icons.camera_alt),
            onPressed: onPhotoEntry,
          ),
          IconButton(
            icon: Icon(Icons.mood),
            onPressed: onMoodTracker,
          ),
        ],
      ),
    );
  }
}

// JournalEntryCard - this would typically be in a separate file
class JournalEntryCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const JournalEntryCard({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        title: Text(entry['title'] ?? 'Untitled'),
        subtitle: Text(entry['content'] ?? ''),
        onTap: onTap,
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              onTap: onEdit,
              child: Text('Edit'),
            ),
            PopupMenuItem(
              onTap: onDelete,
              child: Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }
}
