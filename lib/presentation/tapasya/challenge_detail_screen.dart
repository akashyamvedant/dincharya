// lib/presentation/tapasya/challenge_detail_screen.dart
//
// Detailed view of a Tapasya challenge.
// Shows leaderboard, progress chart, and share button.

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/tapasya_service.dart';

class ChallengeDetailScreen extends StatefulWidget {
  const ChallengeDetailScreen({super.key});

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  final TapasyaService _tapasyaService = TapasyaService();
  Map<String, dynamic>? _challenge;
  bool _isLoading = true;
  bool _isJoining = false;

  static const _primaryColor = Color(0xFFE65100);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic> && _challenge == null) {
      _challenge = args;
      _loadDetail();
    }
  }

  Future<void> _loadDetail() async {
    if (_challenge == null) return;
    setState(() => _isLoading = true);

    final detail = await _tapasyaService.getChallengeDetail(_challenge!['id']);
    if (detail != null && mounted) {
      setState(() {
        _challenge = detail;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _joinChallenge() async {
    if (_isJoining || _challenge == null) return;
    setState(() => _isJoining = true);

    final success = await _tapasyaService.joinChallenge(challengeId: _challenge!['id']);
    
    if (mounted) {
      setState(() => _isJoining = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔥 Challenge joined! Practice to climb the leaderboard.'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
        _loadDetail(); // Refresh
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to join challenge.'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  void _shareChallenge() {
    if (_challenge == null) return;
    final shareText = TapasyaService.generateChallengeShareText(_challenge!);
    Share.share(shareText);
  }

  Future<void> _cancelChallenge() async {
    if (_challenge == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Challenge?'),
        content: const Text(
          'This will permanently cancel this challenge for all participants. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Challenge'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await _tapasyaService.cancelChallenge(_challenge!['id']);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Challenge cancelled.'), backgroundColor: Colors.red),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to cancel challenge.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_challenge == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Challenge')),
        body: const Center(child: Text('Challenge not found')),
      );
    }

    final title = _challenge!['title'] ?? 'Challenge';
    final category = _challenge!['category'] ?? 'any';
    final goalType = _challenge!['goal_type'] ?? 'total_minutes';
    final goalValue = _challenge!['goal_value'] ?? 0;
    final durationDays = _challenge!['duration_days'] ?? 7;
    final status = _challenge!['status'] ?? 'active';
    final leaderboard = _challenge!['leaderboard'] as List<Map<String, dynamic>>? ?? [];
    final participantCount = _challenge!['participant_count'] ?? leaderboard.length;
    final endsAt = DateTime.tryParse(_challenge!['ends_at'] ?? '');
    final daysLeft = endsAt != null ? endsAt.difference(DateTime.now()).inDays : 0;
    final isCompleted = status == 'completed';
    final specificSessions = _challenge!['specific_sessions_list'] as List<dynamic>?;

    String goalLabel;
    switch (goalType) {
      case 'total_minutes':
        goalLabel = '$goalValue minutes';
        break;
      case 'session_count':
        goalLabel = '$goalValue sessions';
        break;
      case 'streak_days':
        goalLabel = '$goalValue day streak';
        break;
      default:
        goalLabel = '$goalValue';
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──
          SliverAppBar(
            expandedHeight: 20.h,
            pinned: true,
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryColor, _primaryColor.withOpacity(0.7)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(4.w, 6.h, 4.w, 2.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          _getCategoryEmoji(category),
                          style: const TextStyle(fontSize: 32),
                        ),
                        SizedBox(height: 0.5.h),
                        Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22.sp,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: _shareChallenge,
              ),
              if (_challenge!['creator_id'] == Supabase.instance.client.auth.currentUser?.id)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (val) {
                    if (val == 'cancel') _cancelChallenge();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'cancel',
                      child: Text('Cancel Challenge', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
            ],
          ),

          // ── Stats Banner ──
          SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.all(4.w),
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _primaryColor.withOpacity(0.08),
                    _primaryColor.withOpacity(0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _primaryColor.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn('🎯', 'Goal', goalLabel),
                  Container(width: 1, height: 40, color: _primaryColor.withOpacity(0.2)),
                  _buildStatColumn('📅', isCompleted ? 'Status' : 'Left', isCompleted ? 'Completed' : '${daysLeft}d'),
                  Container(width: 1, height: 40, color: _primaryColor.withOpacity(0.2)),
                  _buildStatColumn('👥', 'Players', '$participantCount'),
                ],
              ),
            ),
          ),

          if (specificSessions != null && specificSessions.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                padding: EdgeInsets.all(3.5.w),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _primaryColor.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('🎯', style: TextStyle(fontSize: 14.sp)),
                        SizedBox(width: 2.w),
                        Text(
                          'Target Specific Sessions',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: _primaryColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 1.h),
                    Wrap(
                      spacing: 2.w,
                      runSpacing: 0.8.h,
                      children: specificSessions.map((session) {
                        return Container(
                          padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            session['title'] ?? 'Session',
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

          // ── My Progress Card ──
          if (!_isLoading && leaderboard.isNotEmpty) ...[
            () {
              final myEntry = leaderboard.where((p) => p['is_me'] == true).toList();
              if (myEntry.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
              final me = myEntry.first;
              final myProgress = me['current_progress'] ?? 0;
              final myProgressPercent = goalValue > 0 ? (myProgress / goalValue).clamp(0.0, 1.0) : 0.0;
              return SliverToBoxAdapter(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                  padding: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primaryColor.withOpacity(0.12), _primaryColor.withOpacity(0.04)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _primaryColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('🙋', style: TextStyle(fontSize: 18.sp)),
                          SizedBox(width: 2.w),
                          Text(
                            'Your Progress',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              color: _primaryColor,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$myProgress / $goalValue $goalLabel',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 1.5.h),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: myProgressPercent.toDouble(),
                          backgroundColor: theme.colorScheme.outline.withOpacity(0.1),
                          valueColor: const AlwaysStoppedAnimation(_primaryColor),
                          minHeight: 8,
                        ),
                      ),
                      SizedBox(height: 0.8.h),
                      Text(
                        '${(myProgressPercent * 100).toInt()}% complete • Rank #${me['rank'] ?? '-'}',
                        style: TextStyle(fontSize: 11.sp, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              );
            }(),
          ],

          // ── Leaderboard Header ──
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 0),
              child: Row(
                children: [
                  Text(
                    '🏆 Leaderboard',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  if (!isCompleted)
                    Text(
                      '$daysLeft days remaining',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(child: SizedBox(height: 1.h)),

          // ── Leaderboard List ──
          if (_isLoading)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(8.h),
                  child: const CircularProgressIndicator(color: _primaryColor),
                ),
              ),
            )
          else if (leaderboard.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(8.h),
                child: Column(
                  children: [
                    const Text('🏟️', style: TextStyle(fontSize: 48)),
                    SizedBox(height: 1.h),
                    Text(
                      'No participants yet',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 0.5.h),
                    Text(
                      'Be the first to join!',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final participant = leaderboard[index];
                  return _buildLeaderboardRow(participant, index, goalValue, goalType);
                },
                childCount: leaderboard.length,
              ),
            ),

          // ── Bottom padding ──
          SliverToBoxAdapter(child: SizedBox(height: 10.h)),
        ],
      ),

      // ── Bottom Action ──
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _shareChallenge,
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Invite Friends'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    foregroundColor: theme.colorScheme.onSurface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: EdgeInsets.symmetric(vertical: 1.5.h),
                  ),
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isJoining ? null : _joinChallenge,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: EdgeInsets.symmetric(vertical: 1.5.h),
                  ),
                  child: _isJoining
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Join Challenge 🔥', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String emoji, String label, String value) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        SizedBox(height: 0.3.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardRow(Map<String, dynamic> participant, int index, int goalValue, String goalType) {
    final theme = Theme.of(context);
    final rank = participant['rank'] ?? index + 1;
    final name = participant['display_name'] ?? 'User';
    final progress = participant['current_progress'] ?? 0;
    final isMe = participant['is_me'] == true;
    final progressPercent = goalValue > 0 ? (progress / goalValue).clamp(0.0, 1.0) : 0.0;

    String suffix;
    switch (goalType) {
      case 'total_minutes':
        suffix = 'min';
        break;
      case 'session_count':
        suffix = 'sessions';
        break;
      case 'streak_days':
        suffix = 'days';
        break;
      default:
        suffix = '';
    }

    final rankEmoji = rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '#$rank';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: isMe
            ? _primaryColor.withOpacity(0.08)
            : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(14),
        border: isMe ? Border.all(color: _primaryColor.withOpacity(0.3), width: 2) : null,
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 36,
            child: Center(
              child: rank <= 3
                  ? Text(rankEmoji, style: const TextStyle(fontSize: 22))
                  : Text(
                      rankEmoji,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
          SizedBox(width: 3.w),

          // Avatar
          () {
            final avatarUrl = participant['avatar_url'] as String?;
            return CircleAvatar(
              radius: 18,
              backgroundColor: isMe ? _primaryColor.withOpacity(0.2) : theme.colorScheme.surfaceContainerHighest,
              backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
              child: (avatarUrl == null || avatarUrl.isEmpty)
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isMe ? _primaryColor : theme.colorScheme.onSurface,
                      ),
                    )
                  : null,
            );
          }(),
          SizedBox(width: 3.w),

          // Name + Progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isMe ? '$name (You)' : name,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: isMe ? FontWeight.bold : FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$progress $suffix',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                        color: isMe ? _primaryColor : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 0.5.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressPercent.toDouble(),
                    backgroundColor: theme.colorScheme.outline.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation(
                      isMe ? _primaryColor : _primaryColor.withOpacity(0.5),
                    ),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getCategoryEmoji(String category) {
    switch (category) {
      case 'yoga':
        return '🧘';
      case 'pranayama':
        return '🌬️';
      case 'meditation':
        return '🧘‍♂️';
      default:
        return '🏆';
    }
  }
}
