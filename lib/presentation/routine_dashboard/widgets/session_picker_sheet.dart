// lib/presentation/routine_dashboard/widgets/session_picker_sheet.dart
// Bottom sheet to pick a guided session to link with a task.
// Filtered by category (meditation, yoga, pranayama).

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../../services/supabase_service.dart';

class SessionPickerSheet extends StatefulWidget {
  final String category; // 'meditation', 'yoga', or 'pranayama'
  final String? currentSessionId; // Currently linked session (if any)

  const SessionPickerSheet({
    super.key,
    required this.category,
    this.currentSessionId,
  });

  @override
  State<SessionPickerSheet> createState() => _SessionPickerSheetState();
}

class _SessionPickerSheetState extends State<SessionPickerSheet> {
  final SupabaseService _supabase = SupabaseService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    try {
      final client = await _supabase.client;
      if (client == null) return;

      final response = await client
          .from('sessions')
          .select()
          .eq('category', widget.category)
          .eq('is_active', true)
          .order('view_count', ascending: false);

      if (mounted) {
        setState(() {
          _sessions = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading sessions for picker: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredSessions {
    if (_searchQuery.isEmpty) return _sessions;
    final q = _searchQuery.toLowerCase();
    return _sessions.where((s) {
      final title = (s['title'] as String? ?? '').toLowerCase();
      final desc = (s['description'] as String? ?? '').toLowerCase();
      return title.contains(q) || desc.contains(q);
    }).toList();
  }

  String _formatDuration(int? seconds) {
    if (seconds == null) return '--';
    final min = seconds ~/ 60;
    return '$min min';
  }

  String _getDifficultyLabel(int? diff) {
    switch (diff) {
      case 1: return 'Beginner';
      case 2: return 'Easy';
      case 3: return 'Moderate';
      case 4: return 'Advanced';
      case 5: return 'Expert';
      default: return 'Moderate';
    }
  }

  Color _getCategoryColor() {
    switch (widget.category) {
      case 'meditation': return const Color(0xFF7E57C2);
      case 'yoga': return Theme.of(context).colorScheme.primary;
      case 'pranayama': return const Color(0xFF26A69A);
      default: return Theme.of(context).colorScheme.primary;
    }
  }

  String _getCategoryLabel() {
    switch (widget.category) {
      case 'meditation': return 'Meditation Sessions';
      case 'yoga': return 'Yoga Sessions';
      case 'pranayama': return 'Pranayama Sessions';
      default: return 'Sessions';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getCategoryColor();

    return Container(
      height: 75.h,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: EdgeInsets.only(top: 1.h),
            width: 12.w,
            height: 0.5.h,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          SizedBox(height: 1.5.h),

          // Title
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 5.w),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.play_circle_outline, color: color, size: 22),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getCategoryLabel(),
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'Choose a guided session to link',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Unlink button (if currently linked)
                if (widget.currentSessionId != null)
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context, {'unlink': true}),
                    icon: Icon(Icons.link_off, size: 16, color: Colors.red.shade400),
                    label: Text(
                      'Unlink',
                      style: TextStyle(color: Colors.red.shade400, fontSize: 12.sp),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 1.5.h),

          // Search bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 5.w),
            child: TextField(
              controller: _searchController,
              onChanged: (q) => setState(() => _searchQuery = q),
              decoration: InputDecoration(
                hintText: 'Search sessions...',
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13.sp),
                prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurfaceVariant),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          SizedBox(height: 1.h),

          // Sessions list
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: color,
                      strokeWidth: 2,
                    ),
                  )
                : _filteredSessions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.music_off, size: 48, color: Theme.of(context).colorScheme.outline),
                            SizedBox(height: 1.h),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No sessions available'
                                  : 'No sessions match your search',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
                        itemCount: _filteredSessions.length,
                        itemBuilder: (context, index) {
                          final session = _filteredSessions[index];
                          final isCurrentlyLinked =
                              session['id']?.toString() == widget.currentSessionId;
                          return _buildSessionCard(session, color, isCurrentlyLinked);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(
    Map<String, dynamic> session,
    Color color,
    bool isCurrentlyLinked,
  ) {
    final title = session['title'] as String? ?? 'Untitled';
    final description = session['description'] as String? ?? '';
    final duration = session['duration'] as int?;
    final difficulty = session['difficulty'] as int?;
    final isPremium = session['is_premium'] as bool? ?? false;

    return GestureDetector(
      onTap: () {
        Navigator.pop(context, {
          'id': session['id']?.toString(),
          'title': title,
          'duration': duration,
          'thumbnail_url': session['thumbnail_url'],
        });
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 1.h),
        padding: EdgeInsets.all(3.5.w),
        decoration: BoxDecoration(
          color: isCurrentlyLinked ? color.withOpacity(0.08) : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCurrentlyLinked ? color.withOpacity(0.4) : Theme.of(context).colorScheme.outline,
            width: isCurrentlyLinked ? 1.5 : 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Play icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isCurrentlyLinked ? Icons.check_circle : Icons.play_circle_filled,
                color: color,
                size: 26,
              ),
            ),
            SizedBox(width: 3.w),
            // Title + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isPremium)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '👑 PRO',
                            style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                  if (description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        description,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  SizedBox(height: 0.5.h),
                  // Meta row: duration + difficulty
                  Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      SizedBox(width: 4),
                      Text(
                        _formatDuration(duration),
                        style: TextStyle(fontSize: 10.sp, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      SizedBox(width: 3.w),
                      Icon(Icons.signal_cellular_alt, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      SizedBox(width: 4),
                      Text(
                        _getDifficultyLabel(difficulty),
                        style: TextStyle(fontSize: 10.sp, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      if (isCurrentlyLinked) ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Linked',
                            style: TextStyle(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ],
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
