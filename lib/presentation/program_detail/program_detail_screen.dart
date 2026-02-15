import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../services/guided_session_service.dart';

/// Program Detail Screen — shows day-by-day session list with progress tracking.
class ProgramDetailScreen extends StatefulWidget {
  final Map<String, dynamic> program;
  final Map<String, dynamic>? enrollment;

  const ProgramDetailScreen({
    super.key,
    required this.program,
    this.enrollment,
  });

  @override
  State<ProgramDetailScreen> createState() => _ProgramDetailScreenState();
}

class _ProgramDetailScreenState extends State<ProgramDetailScreen> {
  final GuidedSessionService _service = GuidedSessionService();
  List<Map<String, dynamic>> _programSessions = [];
  Map<String, dynamic>? _enrollment;
  bool _loading = true;
  bool _enrolling = false;

  String get _programId => widget.program['id']?.toString() ?? '';
  String get _title => widget.program['title'] ?? 'Program';
  String get _titleHindi => widget.program['title_hindi'] ?? '';
  String get _description => widget.program['description'] ?? '';
  String get _category => widget.program['category'] ?? 'meditation';
  int get _totalSessions => widget.program['total_sessions'] as int? ?? 0;
  int get _durationDays => widget.program['duration_days'] as int? ?? 7;
  int get _difficulty => widget.program['difficulty'] as int? ?? 2;

  int get _currentIndex => (_enrollment?['current_session_index'] as int?) ?? 0;
  bool get _isEnrolled => _enrollment != null;
  bool get _isCompleted => _enrollment?['completed'] == true;

  @override
  void initState() {
    super.initState();
    _enrollment = widget.enrollment;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final sessions = await _service.getProgramSessions(_programId);
      if (mounted) {
        setState(() {
          _programSessions = sessions;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _enroll() async {
    setState(() => _enrolling = true);
    final success = await _service.enrollInProgram(_programId);
    if (success && mounted) {
      // Reload enrollments to get enrollment data
      final enrollments = await _service.getEnrolledPrograms();
      final mine = enrollments.where((e) => e['program_id'] == _programId).toList();
      setState(() {
        _enrollment = mine.isNotEmpty ? mine.first : {'current_session_index': 0, 'completed': false};
        _enrolling = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enrolled in $_title! 🎉'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      if (mounted) setState(() => _enrolling = false);
    }
  }

  Future<void> _startSession(Map<String, dynamic> programSession, int dayIndex) async {
    final sessionData = programSession['sessions'] as Map<String, dynamic>?;
    if (sessionData == null) return;

    HapticFeedback.mediumImpact();

    // Navigate to media player
    await Navigator.pushNamed(context, '/media-player', arguments: sessionData);
    if (!mounted) return;

    // Advance progress if this is the current day
    if (_isEnrolled && dayIndex == _currentIndex) {
      await _service.advanceProgramProgress(_programId);
      // Refresh enrollment
      final enrollments = await _service.getEnrolledPrograms();
      final mine = enrollments.where((e) => e['program_id'] == _programId).toList();
      if (mounted) {
        setState(() {
          _enrollment = mine.isNotEmpty ? mine.first : _enrollment;
        });

        // Check if program completed
        if (_enrollment?['completed'] == true) {
          _showCompletionDialog();
        }
      }
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🎉 Program Complete!', style: TextStyle(fontSize: 22)),
        content: Text(
          'Congratulations! You\'ve finished "$_title". Keep up the great practice!',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: _getCategoryColor(),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Awesome!'),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor() {
    switch (_category) {
      case 'meditation':
        return const Color(0xFF8B4513);
      case 'pranayama':
        return const Color(0xFF4A7C59);
      case 'yoga':
        return const Color(0xFFFF6B35);
      default:
        return const Color(0xFFCD853F);
    }
  }

  String _difficultyLabel() {
    switch (_difficulty) {
      case 1:
        return 'Beginner';
      case 2:
        return 'Easy';
      case 3:
        return 'Intermediate';
      case 4:
        return 'Advanced';
      case 5:
        return 'Expert';
      default:
        return 'All Levels';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getCategoryColor();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 22.h,
            pinned: true,
            backgroundColor: color,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: EdgeInsets.fromLTRB(5.w, 12.h, 5.w, 2.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      _title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_titleHindi.isNotEmpty)
                      Text(
                        _titleHindi,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    SizedBox(height: 1.h),
                    Row(
                      children: [
                        _metaChip(Icons.play_circle_outline, '$_totalSessions sessions'),
                        SizedBox(width: 2.w),
                        _metaChip(Icons.calendar_today_outlined, '$_durationDays days'),
                        SizedBox(width: 2.w),
                        _metaChip(Icons.trending_up, _difficultyLabel()),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(4.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  if (_description.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        _description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                      ),
                    ),

                  SizedBox(height: 2.h),

                  // Progress Section (only if enrolled)
                  if (_isEnrolled) _buildProgressSection(color),

                  SizedBox(height: 2.h),

                  // Sessions Header
                  Row(
                    children: [
                      Text(
                        _isEnrolled ? 'Your Journey' : 'Sessions',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C1810),
                        ),
                      ),
                      const Spacer(),
                      if (_isEnrolled && !_isCompleted)
                        Text(
                          'Day ${_currentIndex + 1} of $_totalSessions',
                          style: TextStyle(
                            fontSize: 13,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 1.h),
                ],
              ),
            ),
          ),

          // Sessions List
          if (_loading)
            const SliverToBoxAdapter(
              child: Center(child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              )),
            )
          else if (_programSessions.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(8.w),
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
                      SizedBox(height: 1.h),
                      Text(
                        'Sessions are being prepared',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildDayTile(index, color),
                childCount: _programSessions.length,
              ),
            ),

          // Bottom spacer
          SliverToBoxAdapter(child: SizedBox(height: 10.h)),
        ],
      ),

      // Enroll / Continue Button
      bottomNavigationBar: _buildBottomAction(color),
    );
  }

  Widget _buildProgressSection(Color color) {
    final progress = _isCompleted ? 1.0 : (_totalSessions > 0 ? _currentIndex / _totalSessions : 0.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isCompleted ? Icons.emoji_events : Icons.trending_up,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _isCompleted ? 'Completed! 🎉' : '${(progress * 100).toInt()}% Complete',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Text(
                '$_currentIndex / $_totalSessions',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayTile(int index, Color color) {
    final programSession = _programSessions[index];
    final sessionData = programSession['sessions'] as Map<String, dynamic>?;
    final dayNumber = programSession['day_number'] as int? ?? (index + 1);
    final sessionTitle = sessionData?['title'] ?? 'Session ${index + 1}';
    final duration = sessionData?['duration'] as int? ?? 600;
    final durationMin = (duration / 60).round();

    // Determine state
    final bool isCompleted = _isEnrolled && index < _currentIndex;
    final bool isCurrent = _isEnrolled && index == _currentIndex && !_isCompleted;
    final bool isLocked = _isEnrolled && index > _currentIndex && !_isCompleted;
    final bool isAvailable = !_isEnrolled || isCurrent || isCompleted;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
      child: InkWell(
        onTap: isAvailable ? () => _startSession(programSession, index) : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isCurrent
                ? color.withOpacity(0.08)
                : isLocked
                    ? Colors.grey[100]
                    : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isCurrent
                ? Border.all(color: color, width: 2)
                : Border.all(color: Colors.grey.withOpacity(0.1)),
            boxShadow: isCurrent
                ? [BoxShadow(color: color.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))]
                : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              // Day circle
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? const Color(0xFF4A7C59)
                      : isCurrent
                          ? color
                          : Colors.grey[300],
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, color: Colors.white, size: 22)
                      : isLocked
                          ? Icon(Icons.lock_outline, color: Colors.grey[500], size: 18)
                          : Text(
                              '$dayNumber',
                              style: TextStyle(
                                color: isCurrent ? Colors.white : Colors.grey[600],
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                ),
              ),

              SizedBox(width: 3.w),

              // Session info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Day $dayNumber',
                      style: TextStyle(
                        fontSize: 11,
                        color: isCurrent ? color : Colors.grey[500],
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sessionTitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isLocked ? Colors.grey[400] : const Color(0xFF2C1810),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$durationMin min',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),

              // Action
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Start',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                )
              else if (isCompleted)
                Icon(Icons.replay, color: Colors.grey[400], size: 20)
              else if (!_isEnrolled)
                Icon(Icons.play_circle_outline, color: color.withOpacity(0.5), size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAction(Color color) {
    if (_isCompleted) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.emoji_events),
            label: const Text('Program Completed!'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A7C59),
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, 6.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    }

    if (!_isEnrolled) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
          child: ElevatedButton.icon(
            onPressed: _enrolling ? null : _enroll,
            icon: _enrolling
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.play_arrow_rounded),
            label: Text(_enrolling ? 'Enrolling...' : 'Start Program'),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, 6.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    }

    // Enrolled — show continue
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
        child: ElevatedButton.icon(
          onPressed: () {
            if (_currentIndex < _programSessions.length) {
              _startSession(_programSessions[_currentIndex], _currentIndex);
            }
          },
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text('Continue — Day ${_currentIndex + 1}'),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            minimumSize: Size(double.infinity, 6.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
