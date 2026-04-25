import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'dart:io';

import '../../services/supabase_service.dart';

/// Admin screen for managing Guided Sessions
class SessionsAdminScreen extends StatefulWidget {
  const SessionsAdminScreen({super.key});

  @override
  State<SessionsAdminScreen> createState() => _SessionsAdminScreenState();
}

class _SessionsAdminScreenState extends State<SessionsAdminScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;
  String _filterCategory = 'all';

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      final client = await _supabaseService.client;
      if (client == null) throw Exception('Supabase not initialized');

      final response = await client
          .from('sessions')
          .select()
          .order('display_order', ascending: true);

      if (mounted) {
        setState(() {
          _sessions = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading sessions: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading sessions: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredSessions {
    if (_filterCategory == 'all') return _sessions;
    return _sessions.where((s) => s['category'] == _filterCategory).toList();
  }

  bool _isReordering = false;

  /// Handle reorder of sessions (drag-and-drop)
  /// Only works within a specific category, not in "All" view
  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (_isReordering) return;
    if (_filterCategory == 'all') return; // Should never happen, but safety check
    
    // Adjust index for removal
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    
    // Get the filtered sessions for the current category
    final categorySessionsIds = _filteredSessions.map((s) => s['id']).toList();
    
    // Create a working list from filtered sessions
    final workingList = List<Map<String, dynamic>>.from(_filteredSessions);
    
    setState(() {
      _isReordering = true;
      // Reorder locally in the working list
      final item = workingList.removeAt(oldIndex);
      workingList.insert(newIndex, item);
    });

    try {
      final client = await _supabaseService.client;
      if (client == null) throw Exception('Supabase not initialized');

      // Update display_order ONLY for sessions in this category
      for (int i = 0; i < workingList.length; i++) {
        await client
            .from('sessions')
            .update({'display_order': i})
            .eq('id', workingList[i]['id']);
      }

      debugPrint('✅ ${_filterCategory.toUpperCase()} sessions reordered successfully');
      
      // Reload all sessions to reflect changes
      await _loadSessions();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_filterCategory.toUpperCase()} sessions reordered!'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error reordering sessions: $e');
      // Reload to restore original order on error
      await _loadSessions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reordering: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isReordering = false);
      }
    }
  }

  Future<void> _deleteSession(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Session'),
        content: Text('Are you sure you want to delete this session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final client = await _supabaseService.client;
        if (client == null) throw Exception('Supabase not initialized');

        await client.from('sessions').delete().eq('id', id);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Session deleted successfully!')),
        );
        _loadSessions();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting session: $e')),
        );
      }
    }
  }

  void _showAddEditDialog([Map<String, dynamic>? session]) {
    showDialog(
      context: context,
      builder: (context) => _AddEditSessionDialog(
        session: session,
        onSaved: () {
          Navigator.pop(context);
          _loadSessions();
        },
      ),
    );
  }

  // Warm brown theme colors for consistency
  static const Color _primaryBrown = Color(0xFF8B4513);
  static const Color _creamBackground = Color(0xFFFDF8F3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Sessions Admin',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: _primaryBrown,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadSessions,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: EdgeInsets.all(3.w),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'All'),
                  SizedBox(width: 2.w),
                  _buildFilterChip('meditation', 'Meditation'),
                  SizedBox(width: 2.w),
                  _buildFilterChip('pranayama', 'Pranayama'),
                  SizedBox(width: 2.w),
                  _buildFilterChip('yoga', 'Yoga'),
                ],
              ),
            ),
          ),

          // Sessions count
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredSessions.length} sessions',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Total: ${_sessions.length}',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          ),

          SizedBox(height: 1.h),

          // Sessions list
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _filteredSessions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.video_library_outlined,
                                size: 48, color: Colors.grey),
                            SizedBox(height: 2.h),
                            Text('No sessions found'),
                            SizedBox(height: 2.h),
                            ElevatedButton.icon(
                              onPressed: () => _showAddEditDialog(),
                              icon: Icon(Icons.add),
                              label: Text('Add First Session'),
                            ),
                          ],
                        ),
                      )
                    : _filterCategory == 'all'
                        // Read-only list for "All" filter - no reordering
                        ? Column(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                                    SizedBox(width: 2.w),
                                    Text(
                                      'Select a category to reorder sessions',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14.sp,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ListView.builder(
                                  padding: EdgeInsets.all(4.w),
                                  itemCount: _filteredSessions.length,
                                  itemBuilder: (context, index) {
                                    final session = _filteredSessions[index];
                                    return _buildSessionCard(session, index, isReorderEnabled: false);
                                  },
                                ),
                              ),
                            ],
                          )
                        // Reorderable list for category-specific filters
                        : Column(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                                child: Row(
                                  children: [
                                    Icon(Icons.drag_indicator, size: 16, color: _primaryBrown),
                                    SizedBox(width: 2.w),
                                    Text(
                                      'Drag to reorder ${_filterCategory.toUpperCase()} sessions',
                                      style: TextStyle(
                                        color: _primaryBrown,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ReorderableListView.builder(
                                  padding: EdgeInsets.all(4.w),
                                  onReorder: _onReorder,
                                  buildDefaultDragHandles: false,
                                  itemCount: _filteredSessions.length,
                                  itemBuilder: (context, index) {
                                    final session = _filteredSessions[index];
                                    return _buildSessionCard(session, index, isReorderEnabled: true);
                                  },
                                ),
                              ),
                            ],
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: _primaryBrown,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Session', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filterCategory == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filterCategory = value);
      },
      selectedColor: _primaryBrown.withOpacity(0.15),
      checkmarkColor: _primaryBrown,
      labelStyle: TextStyle(
        color: isSelected ? _primaryBrown : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session, int index, {bool isReorderEnabled = true}) {
    final title = session['title'] as String? ?? 'Untitled';
    final category = session['category'] as String? ?? 'meditation';
    final duration = session['duration'] as int? ?? 600;
    final difficulty = session['difficulty'] as int? ?? 3;
    final isActive = session['is_active'] as bool? ?? true;
    final isPremium = session['is_premium'] as bool? ?? false;
    final mediaType = session['media_type'] as String? ?? 'youtube';
    final displayOrder = session['display_order'] as int? ?? 0;

    return Card(
      key: ValueKey(session['id']),
      margin: EdgeInsets.only(bottom: 2.h),
      color: Theme.of(context).scaffoldBackgroundColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _primaryBrown.withOpacity(0.2)),
      ),
      child: Padding(
        padding: EdgeInsets.all(3.w),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Drag handle for reordering (only in category filter mode)
            if (isReorderEnabled)
              ReorderableDragStartListener(
                index: index,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 1.w, vertical: 2.h),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.drag_indicator,
                        color: _primaryBrown.withOpacity(0.6),
                        size: 24,
                      ),
                      SizedBox(height: 0.5.h),
                      Text(
                        '#${index + 1}',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: _primaryBrown.withOpacity(0.5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              // Simple order display for "All" view
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
                child: Text(
                  '#${displayOrder + 1}',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            SizedBox(width: 2.w),
            // Thumbnail or leading icon
            Container(
              width: 55,
              height: 45,
              decoration: BoxDecoration(
                color: _getCategoryColor(category).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: (session['thumbnail_url'] != null && (session['thumbnail_url'] as String).isNotEmpty)
                  ? Image.network(
                      session['thumbnail_url'] as String,
                      fit: BoxFit.cover,
                      width: 55,
                      height: 45,
                      errorBuilder: (_, __, ___) => Icon(
                        _getMediaIcon(mediaType),
                        color: _getCategoryColor(category),
                        size: 22,
                      ),
                    )
                  : Icon(
                      _getMediaIcon(mediaType),
                      color: _getCategoryColor(category),
                      size: 22,
                    ),
            ),
            SizedBox(width: 3.w),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16.sp,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Badges in a Wrap to prevent overflow
                      if (isPremium || !isActive)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isPremium)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'PRO',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            if (!isActive) ...[
                              SizedBox(width: 4),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'OFF',
                                  style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                  SizedBox(height: 0.5.h),
                  // Subtitle with info - use Wrap to prevent overflow
                  Wrap(
                    spacing: 2.w,
                    runSpacing: 0.3.h,
                    children: [
                      _buildInfoChip(Icons.category, category.toUpperCase()),
                      _buildInfoChip(Icons.timer, '${duration ~/ 60} min'),
                      _buildInfoChip(Icons.star, '$difficulty/5', color: Colors.amber),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getMediaTypeColor(mediaType).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          mediaType.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9.sp,
                            color: _getMediaTypeColor(mediaType),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Trailing menu
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _showAddEditDialog(session);
                } else if (value == 'steps') {
                  _showStepsSheet(session);
                } else if (value == 'delete') {
                  _deleteSession(session['id']);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                  value: 'steps',
                  child: Row(
                    children: [
                      Icon(Icons.list_alt, size: 18, color: _primaryBrown),
                      SizedBox(width: 8),
                      Text('Manage Steps'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
              icon: Icon(Icons.more_vert, color: _primaryBrown),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showStepsSheet(Map<String, dynamic> session) async {
    final client = await _supabaseService.client;
    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Supabase not initialized')),
      );
      return;
    }

    // Find linked yoga_pose for this session
    final poseRes = await client
        .from('yoga_poses')
        .select('id, name, name_hindi, total_steps')
        .eq('linked_session_id', session['id'])
        .maybeSingle();

    if (poseRes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No yoga pose linked to this session. Link a pose first from the web admin.')),
      );
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StepsManagementSheet(
        poseId: poseRes['id'] as String,
        poseName: poseRes['name'] as String? ?? 'Steps',
        sessionTitle: session['title'] as String? ?? 'Session',
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'meditation':
        return _primaryBrown;
      case 'pranayama':
        return const Color(0xFF6B7B3C); // Olive green
      case 'yoga':
        return const Color(0xFFB8860B); // Golden brown
      default:
        return _primaryBrown;
    }
  }

  IconData _getMediaIcon(String mediaType) {
    switch (mediaType) {
      case 'youtube':
        return Icons.play_circle;
      case 'video':
        return Icons.video_file;
      case 'audio':
        return Icons.audiotrack;
      default:
        return Icons.play_circle;
    }
  }

  Color _getMediaTypeColor(String mediaType) {
    switch (mediaType) {
      case 'youtube':
        return Colors.red;
      case 'video':
        return Colors.blue;
      case 'audio':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

/// Dialog for adding/editing sessions with file upload
class _AddEditSessionDialog extends StatefulWidget {
  final Map<String, dynamic>? session;
  final VoidCallback onSaved;

  const _AddEditSessionDialog({
    this.session,
    required this.onSaved,
  });

  @override
  State<_AddEditSessionDialog> createState() => _AddEditSessionDialogState();
}

class _AddEditSessionDialogState extends State<_AddEditSessionDialog> {
  final _formKey = GlobalKey<FormState>();
  final SupabaseService _supabaseService = SupabaseService();
  
  late TextEditingController _titleController;
  late TextEditingController _titleHindiController;
  late TextEditingController _descriptionController;
  late TextEditingController _youtubeUrlController;
  late TextEditingController _videoUrlController;
  late TextEditingController _audioUrlController;
  late TextEditingController _durationController;
  
  String _category = 'meditation';
  String _mediaType = 'youtube'; // youtube, video, audio
  int _difficulty = 3;
  bool _isPremium = false;
  bool _isActive = true;
  bool _isSaving = false;
  bool _isUploading = false;
  
  // Thumbnail
  String _thumbnailUrl = '';
  String? _selectedThumbnailFileName;
  Uint8List? _selectedThumbnailFileBytes;
  
  // File upload for video
  String? _selectedVideoFileName;
  Uint8List? _selectedVideoFileBytes;
  
  // File upload for audio
  String? _selectedAudioFileName;
  Uint8List? _selectedAudioFileBytes;
  
  double _uploadProgress = 0;
  int _uploadedBytes = 0;
  int _totalBytes = 0;
  double _uploadSpeed = 0;
  // ignore: unused_field - used for upload time tracking
  DateTime? _uploadStartTime;

  bool get isEditing => widget.session != null;

  @override
  void initState() {
    super.initState();
    final s = widget.session;
    _titleController = TextEditingController(text: s?['title'] ?? '');
    _titleHindiController = TextEditingController(text: s?['title_hindi'] ?? '');
    _descriptionController = TextEditingController(text: s?['description'] ?? '');
    _youtubeUrlController = TextEditingController(text: s?['youtube_url'] ?? '');
    _videoUrlController = TextEditingController(text: s?['video_url'] ?? '');
    _audioUrlController = TextEditingController(text: s?['audio_url'] ?? '');
    _durationController = TextEditingController(
      text: s != null ? ((s['duration'] as int?) ?? 600).toString() : '600',
    );
    _category = s?['category'] ?? 'meditation';
    _mediaType = s?['media_type'] ?? 'youtube';
    _difficulty = s?['difficulty'] ?? 3;
    _isPremium = s?['is_premium'] ?? false;
    _isActive = s?['is_active'] ?? true;
    _thumbnailUrl = s?['thumbnail_url'] ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleHindiController.dispose();
    _descriptionController.dispose();
    _youtubeUrlController.dispose();
    _videoUrlController.dispose();
    _audioUrlController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _pickThumbnailFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedThumbnailFileName = file.name;
          _selectedThumbnailFileBytes = file.bytes;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Thumbnail selected: ${file.name}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _deleteThumbnail() async {
    if (_thumbnailUrl.isEmpty) return;
    try {
      final client = await _supabaseService.client;
      if (client != null && _thumbnailUrl.contains('sessions-media')) {
        final uri = Uri.parse(_thumbnailUrl);
        final pathParts = uri.path.split('/storage/v1/object/public/sessions-media/');
        if (pathParts.length > 1) {
          await client.storage.from('sessions-media').remove([pathParts[1]]);
        }
      }
    } catch (e) {
      debugPrint('Error deleting thumbnail from storage: $e');
    }
    setState(() {
      _thumbnailUrl = '';
      _selectedThumbnailFileName = null;
      _selectedThumbnailFileBytes = null;
    });
  }

  Future<void> _pickVideoFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mov', 'avi', 'mkv', 'webm'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedVideoFileName = file.name;
          _selectedVideoFileBytes = file.bytes;
          _mediaType = 'video'; // Auto-set media type
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video selected: ${file.name} | Media type set to VIDEO')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking video: $e')),
      );
    }
  }

  Future<void> _pickAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'aac', 'm4a', 'ogg'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedAudioFileName = file.name;
          _selectedAudioFileBytes = file.bytes;
          _mediaType = 'audio'; // Auto-set media type
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Audio selected: ${file.name} | Media type set to AUDIO')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking audio: $e')),
      );
    }
  }

  Future<String?> _uploadFile(String type, Uint8List fileBytes, String fileName) async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _uploadedBytes = 0;
      _totalBytes = fileBytes.length;
      _uploadStartTime = DateTime.now();
      _uploadSpeed = 0;
    });

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = fileName.split('.').last.toLowerCase();
      final uploadFileName = '${type}_${timestamp}.$extension';

      debugPrint('📤 Starting upload: $uploadFileName (${_totalBytes} bytes)');

      setState(() => _uploadProgress = 0.1);

      final publicUrl = await _supabaseService.uploadFile(
        'sessions-media',
        uploadFileName,
        fileBytes,
      );

      debugPrint('✅ Upload successful: $publicUrl');

      setState(() {
        _isUploading = false;
        _uploadProgress = 1;
        _uploadedBytes = _totalBytes;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 2.w),
                Text('${type.toUpperCase()} uploaded!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      return publicUrl;
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 2.w),
              Expanded(
                child: Text(
                  'Upload failed. Please check storage permissions.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return null;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Get current URLs from text controllers
      String youtubeUrl = _youtubeUrlController.text.trim();
      String videoUrl = _videoUrlController.text.trim();
      String audioUrl = _audioUrlController.text.trim();

      // Upload thumbnail if selected
      if (_selectedThumbnailFileBytes != null && _selectedThumbnailFileName != null) {
        final uploadedUrl = await _uploadFile('thumbnail', _selectedThumbnailFileBytes!, _selectedThumbnailFileName!);
        if (uploadedUrl != null) {
          _thumbnailUrl = uploadedUrl;
        } else {
          throw Exception('Thumbnail upload failed');
        }
      }

      // Upload video file if selected
      if (_selectedVideoFileBytes != null && _selectedVideoFileName != null) {
        final uploadedUrl = await _uploadFile('video', _selectedVideoFileBytes!, _selectedVideoFileName!);
        if (uploadedUrl != null) {
          videoUrl = uploadedUrl;
          _videoUrlController.text = uploadedUrl;
        } else {
          throw Exception('Video upload failed');
        }
      }

      // Upload audio file if selected
      if (_selectedAudioFileBytes != null && _selectedAudioFileName != null) {
        final uploadedUrl = await _uploadFile('audio', _selectedAudioFileBytes!, _selectedAudioFileName!);
        if (uploadedUrl != null) {
          audioUrl = uploadedUrl;
          _audioUrlController.text = uploadedUrl;
        } else {
          throw Exception('Audio upload failed');
        }
      }

      final client = await _supabaseService.client;
      if (client == null) throw Exception('Supabase not initialized');

      // Determine active media_url based on media_type
      String activeMediaUrl = '';
      if (_mediaType == 'youtube') activeMediaUrl = youtubeUrl;
      else if (_mediaType == 'video') activeMediaUrl = videoUrl;
      else if (_mediaType == 'audio') activeMediaUrl = audioUrl;

      final data = {
        'title': _titleController.text.trim(),
        'title_hindi': _titleHindiController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _category,
        'media_type': _mediaType,
        'media_url': activeMediaUrl,
        'youtube_url': youtubeUrl.isNotEmpty ? youtubeUrl : null,
        'video_url': videoUrl.isNotEmpty ? videoUrl : null,
        'audio_url': audioUrl.isNotEmpty ? audioUrl : null,
        'thumbnail_url': _thumbnailUrl.isNotEmpty ? _thumbnailUrl : null,
        'duration': int.tryParse(_durationController.text) ?? 600,
        'difficulty': _difficulty,
        'is_premium': _isPremium,
        'is_active': _isActive,
      };

      // Debug: Print what we're saving
      debugPrint('📝 Saving session with data:');
      debugPrint('  media_type: $_mediaType');
      debugPrint('  youtube_url: $youtubeUrl');
      debugPrint('  video_url: $videoUrl');
      debugPrint('  audio_url: $audioUrl');
      debugPrint('  media_url: $activeMediaUrl');

      if (isEditing) {
        final sessionId = widget.session!['id'];
        debugPrint('🔄 Updating session ID: $sessionId');
        
        final response = await client
            .from('sessions')
            .update(data)
            .eq('id', sessionId)
            .select();
        
        debugPrint('✅ Update response: $response');
      } else {
        final response = await client.from('sessions').insert(data).select();
        debugPrint('✅ Insert response: $response');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'Session updated! (media_type: $_mediaType)' : 'Session added!'),
          backgroundColor: Colors.green,
        ),
      );
      widget.onSaved();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 90.w,
        constraints: BoxConstraints(maxHeight: 85.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(isEditing ? Icons.edit : Icons.add, color: Colors.white),
                  SizedBox(width: 2.w),
                  Text(
                    isEditing ? 'Edit Session' : 'Add New Session',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(4.w),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Title *',
                          hintText: 'Morning Meditation',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v?.isEmpty == true ? 'Required' : null,
                      ),
                      SizedBox(height: 2.h),

                      // Title Hindi
                      TextFormField(
                        controller: _titleHindiController,
                        decoration: InputDecoration(
                          labelText: 'Title (Hindi)',
                          hintText: 'प्रातःकालीन ध्यान',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 2.h),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: 'Description *',
                          hintText: 'Start your day with peaceful awareness...',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (v) => v?.isEmpty == true ? 'Required' : null,
                      ),
                      SizedBox(height: 2.h),

                      // ── THUMBNAIL SECTION ──
                      Text('🖼️ Session Thumbnail', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
                      SizedBox(height: 1.h),
                      Container(
                        padding: EdgeInsets.all(3.w),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _thumbnailUrl.isNotEmpty || _selectedThumbnailFileName != null
                                ? const Color(0xFF8B4513).withOpacity(0.5)
                                : Colors.grey.shade300,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: _thumbnailUrl.isNotEmpty
                              ? const Color(0xFF8B4513).withOpacity(0.03)
                              : Colors.transparent,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Preview existing thumbnail
                            if (_thumbnailUrl.isNotEmpty)
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      _thumbnailUrl,
                                      width: double.infinity,
                                      height: 18.h,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        height: 12.h,
                                        color: Colors.grey.shade200,
                                        child: Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                                      ),
                                    ),
                                  ),
                                  // Delete overlay button
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: GestureDetector(
                                      onTap: _deleteThumbnail,
                                      child: Container(
                                        padding: EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.85),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.delete, color: Colors.white, size: 18),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            // Show selected file name
                            if (_selectedThumbnailFileName != null) ...[
                              SizedBox(height: 1.h),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.image, color: Colors.green, size: 16),
                                    SizedBox(width: 1.w),
                                    Expanded(
                                      child: Text(
                                        'New: $_selectedThumbnailFileName',
                                        style: TextStyle(color: Colors.green, fontSize: 11.sp),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            SizedBox(height: 1.h),
                            // Upload button
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isUploading ? null : _pickThumbnailFile,
                                    icon: Icon(Icons.upload, size: 18),
                                    label: Text(
                                      _thumbnailUrl.isNotEmpty ? 'Change Thumbnail' : 'Upload Thumbnail',
                                      style: TextStyle(fontSize: 12.sp),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF8B4513),
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(vertical: 1.2.h),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                                if (_thumbnailUrl.isNotEmpty) ...[
                                  SizedBox(width: 2.w),
                                  IconButton(
                                    onPressed: _deleteThumbnail,
                                    icon: Icon(Icons.delete_outline, color: Colors.red),
                                    tooltip: 'Remove thumbnail',
                                  ),
                                ],
                              ],
                            ),
                            Text('PNG, JPG, WEBP', style: TextStyle(fontSize: 9.sp, color: Colors.grey)),
                          ],
                        ),
                      ),
                      SizedBox(height: 2.5.h),

                      // Category
                      Text('Category *', style: TextStyle(fontWeight: FontWeight.w500)),
                      SizedBox(height: 1.h),
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(value: 'meditation', label: Text('Meditation')),
                          ButtonSegment(value: 'pranayama', label: Text('Pranayama')),
                          ButtonSegment(value: 'yoga', label: Text('Yoga')),
                        ],
                        selected: {_category},
                        onSelectionChanged: (v) => setState(() => _category = v.first),
                      ),
                      SizedBox(height: 2.h),

                      // Media Type Selection
                      Text('Media Type *', style: TextStyle(fontWeight: FontWeight.w500)),
                      SizedBox(height: 1.h),
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                            value: 'youtube',
                            label: Text('YouTube'),
                            icon: Icon(Icons.play_circle, size: 16),
                          ),
                          ButtonSegment(
                            value: 'video',
                            label: Text('Video'),
                            icon: Icon(Icons.video_file, size: 16),
                          ),
                          ButtonSegment(
                            value: 'audio',
                            label: Text('Audio'),
                            icon: Icon(Icons.audiotrack, size: 16),
                          ),
                        ],
                        selected: {_mediaType},
                        onSelectionChanged: (v) => setState(() => _mediaType = v.first),
                      ),
                      SizedBox(height: 2.h),

                      // --- YOUTUBE SECTION ---
                      _buildMediaSection(
                        title: 'YouTube Video',
                        icon: Icons.play_circle,
                        iconColor: Colors.red,
                        isSelected: _mediaType == 'youtube',
                        onSelect: () => setState(() => _mediaType = 'youtube'),
                        child: TextFormField(
                          controller: _youtubeUrlController,
                          decoration: InputDecoration(
                            labelText: 'YouTube URL',
                            hintText: 'https://www.youtube.com/watch?v=...',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.link, color: Colors.red),
                          ),
                        ),
                        hasContent: _youtubeUrlController.text.isNotEmpty,
                      ),

                      SizedBox(height: 1.5.h),

                      // --- VIDEO SECTION ---
                      _buildMediaSection(
                        title: 'Uploaded Video',
                        icon: Icons.video_file,
                        iconColor: Colors.blue,
                        isSelected: _mediaType == 'video',
                        onSelect: () => setState(() => _mediaType = 'video'),
                        child: Column(
                          children: [
                            if (_videoUrlController.text.isNotEmpty)
                              Container(
                                padding: EdgeInsets.all(2.w),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.blue, size: 20),
                                    SizedBox(width: 2.w),
                                    Expanded(
                                      child: Text(
                                        'Video uploaded',
                                        style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            SizedBox(height: 1.h),
                            Text(
                              _selectedVideoFileName ?? 'No new file selected',
                              style: TextStyle(
                                color: _selectedVideoFileName != null ? Colors.green : Colors.grey,
                                fontSize: 11.sp,
                              ),
                            ),
                            SizedBox(height: 1.h),
                            ElevatedButton.icon(
                              onPressed: _isUploading ? null : _pickVideoFile,
                              icon: Icon(Icons.upload_file),
                              label: Text(_selectedVideoFileName != null ? 'Change Video' : 'Select Video'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            SizedBox(height: 0.5.h),
                            Text('MP4, MOV, AVI, MKV, WEBM', style: TextStyle(fontSize: 9.sp, color: Colors.grey)),
                          ],
                        ),
                        hasContent: _videoUrlController.text.isNotEmpty || _selectedVideoFileName != null,
                      ),

                      SizedBox(height: 1.5.h),

                      // --- AUDIO SECTION ---
                      _buildMediaSection(
                        title: 'Uploaded Audio',
                        icon: Icons.audiotrack,
                        iconColor: Colors.green,
                        isSelected: _mediaType == 'audio',
                        onSelect: () => setState(() => _mediaType = 'audio'),
                        child: Column(
                          children: [
                            if (_audioUrlController.text.isNotEmpty)
                              Container(
                                padding: EdgeInsets.all(2.w),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                                    SizedBox(width: 2.w),
                                    Expanded(
                                      child: Text(
                                        'Audio uploaded',
                                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            SizedBox(height: 1.h),
                            Text(
                              _selectedAudioFileName ?? 'No new file selected',
                              style: TextStyle(
                                color: _selectedAudioFileName != null ? Colors.green : Colors.grey,
                                fontSize: 11.sp,
                              ),
                            ),
                            SizedBox(height: 1.h),
                            ElevatedButton.icon(
                              onPressed: _isUploading ? null : _pickAudioFile,
                              icon: Icon(Icons.upload_file),
                              label: Text(_selectedAudioFileName != null ? 'Change Audio' : 'Select Audio'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            SizedBox(height: 0.5.h),
                            Text('MP3, WAV, AAC, M4A, OGG', style: TextStyle(fontSize: 9.sp, color: Colors.grey)),
                          ],
                        ),
                        hasContent: _audioUrlController.text.isNotEmpty || _selectedAudioFileName != null,
                      ),

                      // Upload progress indicator
                      if (_isUploading) ...[
                        SizedBox(height: 2.h),
                        Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 1.h),
                              Text('Uploading...', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                      SizedBox(height: 2.h),

                      // Duration
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _durationController,
                              decoration: InputDecoration(
                                labelText: 'Duration (seconds) *',
                                hintText: '600',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.timer),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) => v?.isEmpty == true ? 'Required' : null,
                            ),
                          ),
                          SizedBox(width: 2.w),
                          Text(
                            '= ${(int.tryParse(_durationController.text) ?? 0) ~/ 60} min',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      SizedBox(height: 2.h),

                      // Difficulty
                      Text('Difficulty: $_difficulty/5', style: TextStyle(fontWeight: FontWeight.w500)),
                      Slider(
                        value: _difficulty.toDouble(),
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: _getDifficultyLabel(_difficulty),
                        onChanged: (v) => setState(() => _difficulty = v.toInt()),
                      ),
                      SizedBox(height: 1.h),

                      // Toggles
                      SwitchListTile(
                        title: Text('Premium Content'),
                        subtitle: Text('Only for premium users'),
                        value: _isPremium,
                        onChanged: (v) => setState(() => _isPremium = v),
                      ),
                      SwitchListTile(
                        title: Text('Active'),
                        subtitle: Text('Visible to users'),
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Actions
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: (_isSaving || _isUploading) ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                      child: (_isSaving || _isUploading)
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(isEditing ? 'Update Session' : 'Add Session'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDifficultyLabel(int difficulty) {
    switch (difficulty) {
      case 1:
      case 2:
        return 'Beginner';
      case 3:
        return 'Intermediate';
      case 4:
      case 5:
        return 'Advanced';
      default:
        return 'Intermediate';
    }
  }

  /// Format bytes to human-readable format (KB, MB, GB)
  // ignore: unused_element - kept for future use
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Format upload speed to human-readable format
  // ignore: unused_element - kept for future use
  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    if (bytesPerSecond < 1024 * 1024) return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  /// Calculate estimated time remaining
  // ignore: unused_element - kept for future use
  String _calculateETA() {
    if (_uploadSpeed <= 0 || _uploadProgress >= 1) return 'Calculating...';
    
    final remainingBytes = _totalBytes - _uploadedBytes;
    final secondsRemaining = (remainingBytes / _uploadSpeed).ceil();
    
    if (secondsRemaining < 60) return '$secondsRemaining sec';
    if (secondsRemaining < 3600) return '${(secondsRemaining / 60).ceil()} min';
    return '${(secondsRemaining / 3600).ceil()} hr';
  }

  /// Build a styled media section card
  Widget _buildMediaSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onSelect,
    required Widget child,
    required bool hasContent,
  }) {
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? iconColor : (hasContent ? iconColor.withOpacity(0.5) : Colors.grey.shade300),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? iconColor.withOpacity(0.05) : Colors.transparent,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 24),
                SizedBox(width: 2.w),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.sp,
                    color: isSelected ? iconColor : Colors.grey[700],
                  ),
                ),
                Spacer(),
                if (isSelected)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.3.h),
                    decoration: BoxDecoration(
                      color: iconColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'ACTIVE',
                      style: TextStyle(color: Colors.white, fontSize: 9.sp, fontWeight: FontWeight.bold),
                    ),
                  ),
                if (hasContent && !isSelected)
                  Icon(Icons.check_circle, color: iconColor, size: 20),
              ],
            ),
            SizedBox(height: 1.5.h),
            child,
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// Steps Management Bottom Sheet
// ═══════════════════════════════════════════════════════

class _StepsManagementSheet extends StatefulWidget {
  final String poseId;
  final String poseName;
  final String sessionTitle;

  const _StepsManagementSheet({
    required this.poseId,
    required this.poseName,
    required this.sessionTitle,
  });

  @override
  State<_StepsManagementSheet> createState() => _StepsManagementSheetState();
}

class _StepsManagementSheetState extends State<_StepsManagementSheet> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _steps = [];
  bool _isLoading = true;

  static const Color _primaryBrown = Color(0xFF8B4513);

  @override
  void initState() {
    super.initState();
    _loadSteps();
  }

  Future<void> _loadSteps() async {
    setState(() => _isLoading = true);
    try {
      final client = await _supabaseService.client;
      if (client == null) return;

      final response = await client
          .from('pose_steps')
          .select()
          .eq('pose_id', widget.poseId)
          .order('step_number', ascending: true);

      if (mounted) {
        setState(() {
          _steps = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading steps: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteStep(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Step'),
        content: Text('Delete "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final client = await _supabaseService.client;
        if (client == null) return;
        await client.from('pose_steps').delete().eq('id', id);
        // Update total_steps count
        final remaining = await client.from('pose_steps').select('id').eq('pose_id', widget.poseId);
        await client.from('yoga_poses').update({'total_steps': (remaining as List).length}).eq('id', widget.poseId);
        _loadSteps();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _openEditDialog([Map<String, dynamic>? step]) {
    showDialog(
      context: context,
      builder: (context) => _StepEditDialog(
        poseId: widget.poseId,
        step: step,
        nextStepNumber: _steps.length + 1,
        onSaved: () {
          Navigator.pop(context);
          _loadSteps();
        },
      ),
    );
  }

  IconData _stepTypeIcon(String? type) {
    switch (type) {
      case 'guided_audio': return Icons.headphones;
      case 'meditation_open': return Icons.notifications_active;
      default: return Icons.self_improvement;
    }
  }

  Color _stepTypeColor(String? type) {
    switch (type) {
      case 'guided_audio': return const Color(0xFF6D28D9);
      case 'meditation_open': return const Color(0xFF92400E);
      default: return const Color(0xFF166534);
    }
  }

  String _stepTypeLabel(String? type) {
    switch (type) {
      case 'guided_audio': return 'Guided Audio';
      case 'meditation_open': return 'Open Meditation';
      default: return 'Pose';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 85.h,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: EdgeInsets.all(4.w),
            child: Row(
              children: [
                Icon(Icons.list_alt, color: _primaryBrown),
                SizedBox(width: 2.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Steps: ${widget.poseName}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.sp,
                        ),
                      ),
                      Text(
                        '${widget.sessionTitle} • ${_steps.length} steps',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _loadSteps,
                  icon: Icon(Icons.refresh, color: _primaryBrown),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close),
                ),
              ],
            ),
          ),
          Divider(height: 1),

          // Steps list
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _steps.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.list_alt, size: 48, color: Colors.grey[400]),
                            SizedBox(height: 1.h),
                            Text('No steps yet', style: TextStyle(color: Colors.grey[600])),
                            SizedBox(height: 2.h),
                            ElevatedButton.icon(
                              onPressed: () => _openEditDialog(),
                              icon: Icon(Icons.add),
                              label: Text('Add First Step'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryBrown,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                        itemCount: _steps.length,
                        itemBuilder: (context, index) {
                          final step = _steps[index];
                          final stepType = step['step_type'] as String? ?? 'pose';
                          final name = step['name'] as String? ?? 'Step ${index + 1}';
                          final duration = step['duration_seconds'] as int? ?? 10;

                          return Card(
                            margin: EdgeInsets.only(bottom: 1.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: _stepTypeColor(stepType).withOpacity(0.3),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _stepTypeColor(stepType).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    '${step['step_number'] ?? index + 1}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _stepTypeColor(stepType),
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  // Step type badge
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _stepTypeColor(stepType).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(_stepTypeIcon(stepType), size: 12, color: _stepTypeColor(stepType)),
                                        SizedBox(width: 4),
                                        Text(
                                          _stepTypeLabel(stepType),
                                          style: TextStyle(fontSize: 10, color: _stepTypeColor(stepType), fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Duration
                                  Text('⏱️ ${duration}s', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                  // Audio indicator
                                  if (step['audio_url'] != null && (step['audio_url'] as String).isNotEmpty)
                                    Text('🎵 Audio', style: TextStyle(fontSize: 11, color: Color(0xFF6D28D9))),
                                  // Bell indicator
                                  if (stepType == 'meditation_open' && step['bell_interval_minutes'] != null)
                                    Text('🔔 ${step['bell_interval_minutes']}min', style: TextStyle(fontSize: 11, color: Color(0xFF92400E))),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'edit') _openEditDialog(step);
                                  if (v == 'delete') _deleteStep(step['id'], name);
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Add button
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(3.w),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openEditDialog(),
                  icon: Icon(Icons.add),
                  label: Text('Add Step'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBrown,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 1.5.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// Step Edit Dialog
// ═══════════════════════════════════════════════════════

class _StepEditDialog extends StatefulWidget {
  final String poseId;
  final Map<String, dynamic>? step;
  final int nextStepNumber;
  final VoidCallback onSaved;

  const _StepEditDialog({
    required this.poseId,
    this.step,
    required this.nextStepNumber,
    required this.onSaved,
  });

  @override
  State<_StepEditDialog> createState() => _StepEditDialogState();
}

class _StepEditDialogState extends State<_StepEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final SupabaseService _supabaseService = SupabaseService();

  late TextEditingController _nameController;
  late TextEditingController _nameHindiController;
  late TextEditingController _instructionController;
  late TextEditingController _durationController;
  late TextEditingController _audioUrlController;
  late TextEditingController _bellIntervalController;

  String _stepType = 'pose';
  String _breathing = 'normal';
  bool _isSaving = false;
  bool _isUploading = false;

  bool get isEditing => widget.step != null;
  static const Color _primaryBrown = Color(0xFF8B4513);

  @override
  void initState() {
    super.initState();
    final s = widget.step;
    _nameController = TextEditingController(text: s?['name'] ?? '');
    _nameHindiController = TextEditingController(text: s?['name_hindi'] ?? '');
    _instructionController = TextEditingController(text: s?['instruction'] ?? '');
    _durationController = TextEditingController(text: '${s?['duration_seconds'] ?? 10}');
    _audioUrlController = TextEditingController(text: s?['audio_url'] ?? '');
    _bellIntervalController = TextEditingController(text: '${s?['bell_interval_minutes'] ?? 5}');
    _stepType = s?['step_type'] ?? 'pose';
    _breathing = s?['breathing'] ?? 'normal';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameHindiController.dispose();
    _instructionController.dispose();
    _durationController.dispose();
    _audioUrlController.dispose();
    _bellIntervalController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAudio() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'aac', 'm4a', 'ogg'],
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null && file.path == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not read file')),
        );
        return;
      }

      setState(() => _isUploading = true);

      // Read file bytes
      List<int> fileBytes;
      if (file.bytes != null) {
        fileBytes = file.bytes!;
      } else {
        final f = File(file.path!);
        fileBytes = await f.readAsBytes();
      }

      // Generate unique path
      final ext = file.extension ?? 'mp3';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'audio/steps/${widget.poseId}_${timestamp}.$ext';

      // Upload via SupabaseService
      final publicUrl = await _supabaseService.uploadFile(
        'sessions-media',
        storagePath,
        fileBytes,
      );

      setState(() {
        _audioUrlController.text = publicUrl;
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Audio uploaded successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Upload failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final client = await _supabaseService.client;
      if (client == null) throw Exception('Supabase not initialized');

      final stepNum = widget.step?['step_number'] ?? widget.nextStepNumber;

      final data = {
        'pose_id': widget.poseId,
        'step_number': stepNum,
        'name': _nameController.text.trim(),
        'name_hindi': _nameHindiController.text.trim().isNotEmpty ? _nameHindiController.text.trim() : null,
        'instruction': _instructionController.text.trim().isNotEmpty ? _instructionController.text.trim() : null,
        'breathing': _breathing,
        'duration_seconds': int.tryParse(_durationController.text) ?? 10,
        'display_order': stepNum,
        'step_type': _stepType,
        'audio_url': _audioUrlController.text.trim().isNotEmpty ? _audioUrlController.text.trim() : null,
        'bell_interval_minutes': _stepType == 'meditation_open'
            ? (int.tryParse(_bellIntervalController.text) ?? 5)
            : null,
      };

      if (isEditing) {
        await client.from('pose_steps').update(data).eq('id', widget.step!['id']);
      } else {
        await client.from('pose_steps').insert(data);
      }

      // Update total_steps
      final allSteps = await client.from('pose_steps').select('id').eq('pose_id', widget.poseId);
      await client.from('yoga_poses').update({'total_steps': (allSteps as List).length}).eq('id', widget.poseId);

      widget.onSaved();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 90.w,
        constraints: BoxConstraints(maxHeight: 80.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: _primaryBrown,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(isEditing ? Icons.edit : Icons.add, color: Colors.white),
                  SizedBox(width: 2.w),
                  Text(
                    isEditing ? 'Edit Step' : 'Add Step',
                    style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold),
                  ),
                  Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(4.w),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Step Type selector
                      Text('Step Type *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp)),
                      SizedBox(height: 1.h),
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(value: 'pose', label: Text('🧘 Pose', style: TextStyle(fontSize: 12.sp))),
                          ButtonSegment(value: 'guided_audio', label: Text('🎧 Guided', style: TextStyle(fontSize: 12.sp))),
                          ButtonSegment(value: 'meditation_open', label: Text('🔔 Open', style: TextStyle(fontSize: 12.sp))),
                        ],
                        selected: {_stepType},
                        onSelectionChanged: (v) => setState(() => _stepType = v.first),
                      ),
                      SizedBox(height: 0.5.h),
                      Text(
                        _stepType == 'pose'
                            ? 'Standard pose with breathing & image'
                            : _stepType == 'guided_audio'
                                ? 'Audio-guided meditation (auto-ends with audio)'
                                : 'Self-paced meditation with interval bell',
                        style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 2.h),

                      // Name
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Name *',
                          hintText: 'e.g. Deep Meditation',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v?.isEmpty == true ? 'Required' : null,
                      ),
                      SizedBox(height: 1.5.h),

                      // Name Hindi
                      TextFormField(
                        controller: _nameHindiController,
                        decoration: InputDecoration(
                          labelText: 'Name (Hindi)',
                          hintText: 'e.g. गहरा ध्यान',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 1.5.h),

                      // Instruction
                      TextFormField(
                        controller: _instructionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Instruction',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 1.5.h),

                      // Duration
                      TextFormField(
                        controller: _durationController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Duration (seconds)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.timer),
                          suffixText: '= ${(int.tryParse(_durationController.text) ?? 0) ~/ 60} min',
                        ),
                      ),
                      SizedBox(height: 2.h),

                      // ── Audio URL (for guided_audio & meditation_open) ──
                      if (_stepType == 'guided_audio' || _stepType == 'meditation_open') ...[
                        Text(
                          _stepType == 'guided_audio' ? '🎵 Guided Audio' : '🎵 Loop Audio',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp),
                        ),
                        SizedBox(height: 1.h),
                        // Upload Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isUploading ? null : _pickAndUploadAudio,
                            icon: _isUploading
                                ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Icon(Icons.upload_file),
                            label: Text(_isUploading ? 'Uploading...' : 'Upload Audio File'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF6D28D9),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 1.5.h),
                            ),
                          ),
                        ),
                        SizedBox(height: 1.h),
                        // Or paste URL
                        TextFormField(
                          controller: _audioUrlController,
                          decoration: InputDecoration(
                            labelText: 'Or paste Audio URL',
                            hintText: 'https://...mp3',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.link, color: Color(0xFF6D28D9)),
                            suffixIcon: _audioUrlController.text.isNotEmpty
                                ? Icon(Icons.check_circle, color: Colors.green)
                                : null,
                          ),
                        ),
                        if (_audioUrlController.text.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: 0.5.h),
                            child: Text(
                              '✅ Audio set',
                              style: TextStyle(fontSize: 11.sp, color: Colors.green[700]),
                            ),
                          ),
                        SizedBox(height: 2.h),
                      ],

                      // ── Bell Interval (only meditation_open) ──
                      if (_stepType == 'meditation_open') ...[
                        Text('🔔 Bell Interval (minutes)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp)),
                        SizedBox(height: 0.5.h),
                        TextFormField(
                          controller: _bellIntervalController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Minutes',
                            hintText: '5',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.notifications_active, color: Color(0xFF92400E)),
                          ),
                        ),
                        Text(
                          'A bell will ring at this interval',
                          style: TextStyle(fontSize: 10.sp, color: Colors.grey[600]),
                        ),
                        SizedBox(height: 2.h),
                      ],

                      // ── Breathing (only for pose type) ──
                      if (_stepType == 'pose') ...[
                        Text('Breathing', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp)),
                        SizedBox(height: 1.h),
                        SegmentedButton<String>(
                          segments: [
                            ButtonSegment(value: 'inhale', label: Text('Inhale', style: TextStyle(fontSize: 11.sp))),
                            ButtonSegment(value: 'exhale', label: Text('Exhale', style: TextStyle(fontSize: 11.sp))),
                            ButtonSegment(value: 'hold', label: Text('Hold', style: TextStyle(fontSize: 11.sp))),
                            ButtonSegment(value: 'normal', label: Text('Normal', style: TextStyle(fontSize: 11.sp))),
                          ],
                          selected: {_breathing},
                          onSelectionChanged: (v) => setState(() => _breathing = v.first),
                        ),
                        SizedBox(height: 2.h),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Actions
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryBrown,
                        foregroundColor: Colors.white,
                      ),
                      child: _isSaving
                          ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(isEditing ? 'Update Step' : 'Add Step'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
