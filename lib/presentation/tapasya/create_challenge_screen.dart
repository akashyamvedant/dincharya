// lib/presentation/tapasya/create_challenge_screen.dart
//
// Screen to create a new Tapasya challenge.
// User selects: category, goal type, goal value, duration, visibility.

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/tapasya_service.dart';

class CreateChallengeScreen extends StatefulWidget {
  const CreateChallengeScreen({super.key});

  @override
  State<CreateChallengeScreen> createState() => _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends State<CreateChallengeScreen> {
  final TapasyaService _tapasyaService = TapasyaService();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _challengeType = 'group'; // '1v1', 'group', 'community'
  String _category = 'any'; // 'yoga', 'pranayama', 'meditation', 'any'
  String _goalType = 'total_minutes';
  int _goalValue = 60;
  int _durationDays = 7;
  bool _isPublic = false;
  int _maxParticipants = 20;
  bool _isCreating = false;
  String? _circleId;

  List<Map<String, dynamic>> _availableSessions = [];
  List<String> _selectedSessionIds = [];
  bool _loadingSessions = false;
  bool _showSessionsSelector = false;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _loadingSessions = true;
      _selectedSessionIds = [];
      _showSessionsSelector = false;
    });
    final list = await _tapasyaService.getSessionsByCategory(_category);
    if (mounted) {
      setState(() {
        _availableSessions = list;
        _loadingSessions = false;
      });
    }
  }

  String _getSessionThumbnail(String? thumbnailUrl, String? youtubeUrl) {
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      return thumbnailUrl;
    }
    if (youtubeUrl != null && youtubeUrl.isNotEmpty) {
      final regExp = RegExp(
        r'^.*(youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|\&v=)([^#\&\?]*).*',
        caseSensitive: false,
      );
      final match = regExp.firstMatch(youtubeUrl);
      if (match != null && match.groupCount >= 2) {
        final videoId = match.group(2);
        if (videoId != null && videoId.isNotEmpty) {
          return 'https://img.youtube.com/vi/$videoId/mqdefault.jpg';
        }
      }
    }
    // Fallback category matching placeholder images
    if (_category == 'yoga') {
      return 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?q=80&w=200&auto=format&fit=crop';
    } else if (_category == 'pranayama') {
      return 'https://images.unsplash.com/photo-1506126613408-eca07ce68773?q=80&w=200&auto=format&fit=crop';
    } else {
      return 'https://images.unsplash.com/photo-1518241353330-0f7941c2d9b5?q=80&w=200&auto=format&fit=crop';
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic> && args.containsKey('circle_id')) {
      _circleId = args['circle_id'] as String;
      _challengeType = 'group'; // Circle challenges are always group type
    }
  }

  static const _primaryColor = Color(0xFFE65100);

  final List<Map<String, dynamic>> _challengeTypes = [
    {'key': '1v1', 'label': '1v1', 'icon': '🤺', 'desc': 'Challenge a friend'},
    {'key': 'group', 'label': 'Group', 'icon': '👥', 'desc': '2-50 participants'},
    {'key': 'community', 'label': 'Community', 'icon': '🌍', 'desc': 'Open to everyone'},
  ];

  final List<Map<String, dynamic>> _categories = [
    {'key': 'any', 'label': 'Any Practice', 'emoji': '✨'},
    {'key': 'yoga', 'label': 'Yoga', 'emoji': '🧘'},
    {'key': 'pranayama', 'label': 'Pranayama', 'emoji': '🌬️'},
    {'key': 'meditation', 'label': 'Meditation', 'emoji': '🧘‍♂️'},
  ];

  final List<Map<String, dynamic>> _goalTypes = [
    {'key': 'total_minutes', 'label': 'Total Minutes', 'icon': '⏱️', 'suffix': 'min'},
    {'key': 'session_count', 'label': 'Session Count', 'icon': '🔢', 'suffix': 'sessions'},
    {'key': 'streak_days', 'label': 'Streak Days', 'icon': '🔥', 'suffix': 'days'},
  ];

  final List<int> _durationOptions = [1, 3, 7, 14, 30];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String get _autoTitle {
    final catLabel = _categories.firstWhere((c) => c['key'] == _category)['label'];
    final durLabel = '${_durationDays}d';
    return '$catLabel Challenge ($durLabel)';
  }

  Future<void> _createChallenge() async {
    if (_isCreating) return;
    setState(() => _isCreating = true);

    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : _autoTitle;

    final challenge = await _tapasyaService.createChallenge(
      title: title,
      description: _descriptionController.text.trim(),
      challengeType: _challengeType,
      category: _category,
      specificSessionIds: _selectedSessionIds,
      goalType: _goalType,
      goalValue: _goalValue,
      durationDays: _durationDays,
      isPublic: _circleId == null && (_isPublic || _challengeType == 'community'),
      maxParticipants: _challengeType == '1v1' ? 2 : _maxParticipants,
      circleId: _circleId,
    );

    setState(() => _isCreating = false);

    if (challenge != null && mounted) {
      // Show success with share option
      _showSuccessDialog(challenge);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to create challenge. Please try again.'),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  void _showSuccessDialog(Map<String, dynamic> challenge) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('🔥', style: TextStyle(fontSize: 28)),
            SizedBox(width: 8),
            Text('Challenge Created!'),
          ],
        ),
        content: const Text(
          'Your challenge is live! Share it with friends to start competing.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Later'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final shareText = TapasyaService.generateChallengeShareText(challenge);
              Share.share(shareText);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Share Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Create Challenge 🔥'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_circleId == null) ...[
              // ── Challenge Type ──
              _buildLabel('Challenge Type'),
              SizedBox(height: 1.h),
              Row(
                children: _challengeTypes.map((type) {
                  final isSelected = type['key'] == _challengeType;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _challengeType = type['key']),
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 1.w),
                        padding: EdgeInsets.symmetric(vertical: 1.5.h),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _primaryColor.withOpacity(0.12)
                              : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? _primaryColor : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(type['icon'], style: const TextStyle(fontSize: 24)),
                            SizedBox(height: 0.5.h),
                            Text(
                              type['label'],
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? _primaryColor : theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 3.h),
            ],

            // ── Title (optional) ──
            _buildLabel('Challenge Title (optional)'),
            SizedBox(height: 1.h),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: _autoTitle,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _primaryColor, width: 2),
                ),
              ),
            ),

            SizedBox(height: 3.h),

            // ── Category ──
            _buildLabel('Practice Category'),
            SizedBox(height: 1.h),
            Wrap(
              spacing: 2.w,
              runSpacing: 1.h,
              children: _categories.map((cat) {
                final isSelected = cat['key'] == _category;
                return GestureDetector(
                  onTap: () {
                    if (_category != cat['key']) {
                      setState(() => _category = cat['key']);
                      _loadSessions();
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _primaryColor.withOpacity(0.12)
                          : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? _primaryColor : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(cat['emoji'], style: const TextStyle(fontSize: 18)),
                        SizedBox(width: 1.5.w),
                        Text(
                          cat['label'],
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? _primaryColor : theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            if (_availableSessions.isNotEmpty) ...[
              SizedBox(height: 3.h),
              GestureDetector(
                onTap: () => setState(() => _showSessionsSelector = !_showSessionsSelector),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _selectedSessionIds.isNotEmpty
                          ? _primaryColor.withOpacity(0.5)
                          : theme.colorScheme.outlineVariant.withOpacity(0.3),
                      width: _selectedSessionIds.isNotEmpty ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selectedSessionIds.isNotEmpty ? Icons.playlist_add_check : Icons.playlist_add,
                        color: _selectedSessionIds.isNotEmpty ? _primaryColor : theme.colorScheme.onSurfaceVariant,
                        size: 24,
                      ),
                      SizedBox(width: 3.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Target Specific Sessions',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            SizedBox(height: 0.5.h),
                            Text(
                              _selectedSessionIds.isEmpty
                                  ? 'Challenge all sessions in this category'
                                  : '${_selectedSessionIds.length} specific sessions selected',
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: _selectedSessionIds.isNotEmpty ? _primaryColor : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _showSessionsSelector ? Icons.expand_less : Icons.expand_more,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              if (_showSessionsSelector) ...[
                SizedBox(height: 1.5.h),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: 30.h),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.symmetric(vertical: 1.h),
                      itemCount: _availableSessions.length,
                      itemBuilder: (context, index) {
                        final session = _availableSessions[index];
                        final idStr = session['id']?.toString() ?? '';
                        final isSelected = _selectedSessionIds.contains(idStr);
                        final thumbnail = _getSessionThumbnail(session['thumbnail_url'], session['media_url']);

                        return Container(
                          margin: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _primaryColor.withOpacity(0.06)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: CheckboxListTile(
                            contentPadding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
                            secondary: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                thumbnail,
                                width: 15.w,
                                height: 11.w,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Container(
                                  width: 15.w,
                                  height: 11.w,
                                  color: _primaryColor.withOpacity(0.15),
                                  child: const Icon(Icons.spa, color: _primaryColor, size: 18),
                                ),
                              ),
                            ),
                            title: Text(
                              session['title'] ?? 'Session',
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            subtitle: session['title_hindi'] != null
                                ? Text(
                                    session['title_hindi']!,
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                                    ),
                                  )
                                : null,
                            value: isSelected,
                            activeColor: _primaryColor,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedSessionIds.add(idStr);
                                } else {
                                  _selectedSessionIds.remove(idStr);
                                }
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ] else if (_loadingSessions) ...[
              SizedBox(height: 3.h),
              const Center(child: CircularProgressIndicator(color: _primaryColor)),
            ],

            SizedBox(height: 3.h),

            // ── Goal Type ──
            _buildLabel('Goal Type'),
            SizedBox(height: 1.h),
            ...(_goalTypes.map((goal) {
              final isSelected = goal['key'] == _goalType;
              return GestureDetector(
                onTap: () => setState(() {
                  _goalType = goal['key'];
                  // Reset goal value to sensible default
                  if (goal['key'] == 'total_minutes') _goalValue = 60;
                  if (goal['key'] == 'session_count') _goalValue = 10;
                  if (goal['key'] == 'streak_days') _goalValue = 7;
                }),
                child: Container(
                  margin: EdgeInsets.only(bottom: 1.h),
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _primaryColor.withOpacity(0.12)
                        : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? _primaryColor : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(goal['icon'], style: const TextStyle(fontSize: 22)),
                      SizedBox(width: 3.w),
                      Text(
                        goal['label'],
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? _primaryColor : theme.colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      if (isSelected)
                        Icon(Icons.check_circle, color: _primaryColor, size: 22),
                    ],
                  ),
                ),
              );
            })),

            SizedBox(height: 3.h),

            // ── Goal Value Slider ──
            _buildLabel('Target: $_goalValue ${_goalTypes.firstWhere((g) => g['key'] == _goalType)['suffix']}'),
            SizedBox(height: 1.h),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: _primaryColor,
                thumbColor: _primaryColor,
                overlayColor: _primaryColor.withOpacity(0.2),
                inactiveTrackColor: _primaryColor.withOpacity(0.15),
              ),
              child: Slider(
                value: _goalValue.toDouble(),
                min: _goalType == 'streak_days' ? 1 : 5,
                max: _goalType == 'total_minutes'
                    ? 500
                    : _goalType == 'session_count'
                        ? 100
                        : 30,
                divisions: _goalType == 'total_minutes' ? 99 : null,
                onChanged: (val) => setState(() => _goalValue = val.round()),
              ),
            ),

            SizedBox(height: 3.h),

            // ── Duration ──
            _buildLabel('Duration'),
            SizedBox(height: 1.h),
            Row(
              children: _durationOptions.map((days) {
                final isSelected = days == _durationDays;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _durationDays = days),
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 0.5.w),
                      padding: EdgeInsets.symmetric(vertical: 1.5.h),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _primaryColor
                            : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '${days}d',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            SizedBox(height: 3.h),

            // ── Visibility toggle ──
            if (_challengeType != 'community')
              Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Text('🌐', style: TextStyle(fontSize: 22)),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Public Challenge',
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'Anyone can discover and join',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _isPublic,
                      onChanged: (val) => setState(() => _isPublic = val),
                      activeColor: _primaryColor,
                    ),
                  ],
                ),
              ),

            SizedBox(height: 4.h),

            // ── Create Button ──
            SizedBox(
              width: double.infinity,
              height: 7.h,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createChallenge,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  shadowColor: _primaryColor.withOpacity(0.4),
                ),
                child: _isCreating
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        '🔥 Create Challenge',
                        style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold),
                      ),
              ),
            ),

            SizedBox(height: 4.h),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}
