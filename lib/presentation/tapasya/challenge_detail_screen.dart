// lib/presentation/tapasya/challenge_detail_screen.dart
//
// Detailed view of a Tapasya challenge.
// For 1v1: Shows head-to-head VS view.
// For group/community: Shows leaderboard.

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:async';

import '../../services/tapasya_service.dart';

class ChallengeDetailScreen extends StatefulWidget {
  const ChallengeDetailScreen({super.key});

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen>
    with SingleTickerProviderStateMixin {
  final TapasyaService _tapasyaService = TapasyaService();
  Map<String, dynamic>? _challenge;
  bool _isLoading = true;
  bool _isJoining = false;
  bool _dataChanged = false; // Track if data changed for Hub refresh

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    // Auto-refresh every 10 seconds to catch opponent joins, progress updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && _challenge != null) {
        _loadDetail();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic> && _challenge == null) {
      if (args.containsKey('id') && args.length == 1) {
        // Deep link — only has ID, need to fetch full data
        _loadChallengeById(args['id']);
      } else {
        _challenge = args;
        _loadDetail();
      }
    }
  }

  Future<void> _loadChallengeById(String challengeId) async {
    setState(() => _isLoading = true);
    final detail = await _tapasyaService.getChallengeDetail(challengeId);
    if (detail != null && mounted) {
      setState(() {
        _challenge = detail;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDetail() async {
    if (_challenge == null) return;
    // Don't set _isLoading = true here — avoids full-screen flash on refresh.
    // Initial load already has _isLoading = true from init state.

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
      if (success) {
        _dataChanged = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_is1v1
                ? '🤺 Duel accepted! Practice to win.'
                : '🔥 Challenge joined! Practice to climb the leaderboard.'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
        // Reload data and update UI immediately
        await _loadDetail();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to join challenge.'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
      if (mounted) setState(() => _isJoining = false);
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

  // ── Helper getters ──
  String get _currentUserId => Supabase.instance.client.auth.currentUser?.id ?? '';
  bool get _is1v1 => _challenge?['challenge_type'] == '1v1';
  bool get _isCreator => _challenge?['creator_id'] == _currentUserId;
  bool get _isParticipant {
    final leaderboard = _challenge?['leaderboard'] as List<Map<String, dynamic>>? ?? [];
    return leaderboard.any((p) => p['is_me'] == true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Loading state
    if (_isLoading || _challenge == null) {
      return PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop && _dataChanged) {
            // Will be handled by Navigator result
          }
        },
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text('Challenge'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(_dataChanged),
            ),
          ),
          body: _isLoading
              ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
              : const Center(child: Text('Challenge not found')),
        ),
      );
    }

    final title = _challenge!['title'] ?? 'Challenge';
    final category = _challenge!['category'] ?? 'any';
    final goalType = _challenge!['goal_type'] ?? 'total_minutes';
    final goalValue = _challenge!['goal_value'] ?? 0;
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

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && _dataChanged) {
          // Result will be passed via Navigator.pop
        }
      },
      child: Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──
          SliverAppBar(
            expandedHeight: 20.h,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(_dataChanged),
            ),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.7)],
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
                        Row(
                          children: [
                            Text(
                              _is1v1 ? '🤺' : _getCategoryEmoji(category),
                              style: const TextStyle(fontSize: 32),
                            ),
                            if (_is1v1) ...[
                              SizedBox(width: 2.w),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '1v1 DUEL',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ],
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
              if (_isCreator)
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
                    theme.colorScheme.primary.withValues(alpha: 0.08),
                    theme.colorScheme.primary.withValues(alpha: 0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn('🎯', 'Goal', goalLabel),
                  Container(width: 1, height: 40, color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                  _buildStatColumn('📅', isCompleted ? 'Status' : 'Left', isCompleted ? 'Completed' : '${daysLeft}d'),
                  Container(width: 1, height: 40, color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                  _buildStatColumn(_is1v1 ? '🤺' : '👥', 'Players', '$participantCount'),
                ],
              ),
            ),
          ),

          // ── Specific Sessions ──
          if (specificSessions != null && specificSessions.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                padding: EdgeInsets.all(3.5.w),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
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
                            color: theme.colorScheme.primary,
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

          // ── MAIN CONTENT: 1v1 Head-to-Head OR Group Leaderboard ──
          if (_is1v1)
            _build1v1HeadToHead(theme, leaderboard, goalValue, goalType, goalLabel, isCompleted, daysLeft)
          else ...[
            // ── My Progress Card (Group/Community) ──
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
                        colors: [theme.colorScheme.primary.withValues(alpha: 0.12), theme.colorScheme.primary.withValues(alpha: 0.04)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
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
                                color: theme.colorScheme.primary,
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
                            backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.1),
                            valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
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
                    child: CircularProgressIndicator(color: theme.colorScheme.primary),
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
          ],

          // ── Bottom padding ──
          SliverToBoxAdapter(child: SizedBox(height: 10.h)),
        ],
      ),

      // ── Bottom Action Bar (Context-Aware) ──
      bottomNavigationBar: _buildBottomBar(theme, isCompleted),
    ),
    );  // Close PopScope
  }

  // ══════════════════════════════════════════
  // 1v1 HEAD-TO-HEAD VIEW
  // ══════════════════════════════════════════

  Widget _build1v1HeadToHead(
    ThemeData theme,
    List<Map<String, dynamic>> leaderboard,
    int goalValue,
    String goalType,
    String goalLabel,
    bool isCompleted,
    int daysLeft,
  ) {
    // Get player A (me or first) and player B (opponent)
    Map<String, dynamic>? playerA;
    Map<String, dynamic>? playerB;

    for (final p in leaderboard) {
      if (p['is_me'] == true) {
        playerA = p;
      } else {
        playerB = p;
      }
    }

    // If user is not a participant, use first two entries
    if (playerA == null && leaderboard.isNotEmpty) {
      playerA = leaderboard[0];
      playerB = leaderboard.length > 1 ? leaderboard[1] : null;
    }

    // Fallback: if leaderboard hasn't loaded yet but user is creator,
    // show their info from Supabase auth
    if (playerA == null && _isCreator) {
      final user = Supabase.instance.client.auth.currentUser;
      playerA = {
        'is_me': true,
        'display_name': user?.userMetadata?['full_name'] ?? 'You',
        'avatar_url': user?.userMetadata?['avatar_url'],
        'current_progress': 0,
        'rank': 1,
      };
    }

    final waitingForOpponent = leaderboard.length < 2;

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

    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.all(4.w),
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.1),
              theme.colorScheme.tertiary.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            // ── Header ──
            Text(
              isCompleted ? '🏆 FINAL RESULT' : '⚔️ HEAD TO HEAD',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            SizedBox(height: 0.5.h),
            if (!isCompleted && !waitingForOpponent)
              Text(
                '$daysLeft days remaining',
                style: TextStyle(fontSize: 11.sp, color: theme.colorScheme.onSurfaceVariant),
              ),

            SizedBox(height: 2.h),

            // ── VS Avatars ──
            Row(
              children: [
                // Player A
                Expanded(child: _buildPlayerCard(theme, playerA, goalValue, suffix, true)),

                // VS Badge
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2.w),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'VS',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),

                // Player B (or waiting)
                Expanded(
                  child: waitingForOpponent
                      ? _buildWaitingCard(theme)
                      : _buildPlayerCard(theme, playerB, goalValue, suffix, false),
                ),
              ],
            ),

            SizedBox(height: 2.5.h),

            // ── Progress Comparison Bars ──
            if (!waitingForOpponent) ...[
              _buildDualProgressBar(theme, playerA, playerB, goalValue, suffix),

              // ── Status Badge ──
              SizedBox(height: 2.h),
              _buildStatusBadge(theme, playerA, playerB, isCompleted),
            ],

            // ── Waiting for Opponent CTA ──
            if (waitingForOpponent) ...[
              SizedBox(height: 1.h),
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _pulseAnimation.value,
                    child: child,
                  );
                },
                child: Text(
                  '⏳ Waiting for opponent...',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              SizedBox(height: 1.5.h),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _shareChallenge,
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Share & Find Opponent'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                    side: BorderSide(color: theme.colorScheme.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: EdgeInsets.symmetric(vertical: 1.5.h),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerCard(ThemeData theme, Map<String, dynamic>? player, int goalValue, String suffix, bool isLeft) {
    if (player == null) return const SizedBox.shrink();

    final name = player['display_name'] ?? 'User';
    final progress = player['current_progress'] ?? 0;
    final isMe = player['is_me'] == true;
    final avatarUrl = player['avatar_url'] as String?;
    final rank = player['rank'] ?? 0;

    return Column(
      children: [
        // Avatar
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isMe ? theme.colorScheme.primary : theme.colorScheme.outline.withValues(alpha: 0.3),
              width: isMe ? 3 : 2,
            ),
            boxShadow: isMe
                ? [BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.2), blurRadius: 8)]
                : null,
          ),
          child: CircleAvatar(
            radius: 30,
            backgroundColor: isMe
                ? theme.colorScheme.primary.withValues(alpha: 0.15)
                : theme.colorScheme.surfaceContainerHighest,
            backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
            child: (avatarUrl == null || avatarUrl.isEmpty)
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isMe ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                    ),
                  )
                : null,
          ),
        ),
        SizedBox(height: 0.8.h),

        // Name
        Text(
          isMe ? 'You' : name,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

        // Progress
        Text(
          '$progress $suffix',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w900,
            color: isMe ? theme.colorScheme.primary : theme.colorScheme.tertiary,
          ),
        ),
        Text(
          'of $goalValue',
          style: TextStyle(fontSize: 10.sp, color: theme.colorScheme.onSurfaceVariant),
        ),

        // Rank badge
        if (rank == 1)
          Padding(
            padding: EdgeInsets.only(top: 0.5.h),
            child: const Text('👑', style: TextStyle(fontSize: 18)),
          ),
      ],
    );
  }

  Widget _buildWaitingCard(ThemeData theme) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
              width: 2,
              strokeAlign: BorderSide.strokeAlignOutside,
            ),
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          ),
          child: Center(
            child: Icon(
              Icons.person_add_alt_1_rounded,
              size: 28,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
        ),
        SizedBox(height: 0.8.h),
        Text(
          'Opponent',
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
        Text(
          '? ${""}',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
        ),
        Text(
          'waiting...',
          style: TextStyle(fontSize: 10.sp, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
        ),
      ],
    );
  }

  Widget _buildDualProgressBar(
    ThemeData theme,
    Map<String, dynamic>? playerA,
    Map<String, dynamic>? playerB,
    int goalValue,
    String suffix,
  ) {
    final progressA = (playerA?['current_progress'] ?? 0) as int;
    final progressB = (playerB?['current_progress'] ?? 0) as int;
    final percentA = goalValue > 0 ? (progressA / goalValue).clamp(0.0, 1.0) : 0.0;
    final percentB = goalValue > 0 ? (progressB / goalValue).clamp(0.0, 1.0) : 0.0;
    final nameA = playerA?['is_me'] == true ? 'You' : (playerA?['display_name'] ?? 'Player 1');
    final nameB = playerB?['is_me'] == true ? 'You' : (playerB?['display_name'] ?? 'Player 2');

    return Column(
      children: [
        // Player A bar
        _buildSingleBar(theme, nameA, progressA, percentA, suffix, theme.colorScheme.primary),
        SizedBox(height: 1.h),
        // Player B bar
        _buildSingleBar(theme, nameB, progressB, percentB, suffix, theme.colorScheme.tertiary),
      ],
    );
  }

  Widget _buildSingleBar(ThemeData theme, String name, int progress, double percent, String suffix, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
            Text('$progress $suffix (${(percent * 100).toInt()}%)', style: TextStyle(fontSize: 10.sp, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
        SizedBox(height: 0.3.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percent,
            backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(ThemeData theme, Map<String, dynamic>? playerA, Map<String, dynamic>? playerB, bool isCompleted) {
    final progressA = (playerA?['current_progress'] ?? 0) as int;
    final progressB = (playerB?['current_progress'] ?? 0) as int;
    final isMe = playerA?['is_me'] == true;

    String text;
    String emoji;
    Color bgColor;
    Color textColor;

    if (isCompleted) {
      if (progressA > progressB && isMe) {
        emoji = '🏆'; text = 'You Won!'; bgColor = Colors.amber.withValues(alpha: 0.15); textColor = Colors.amber[800]!;
      } else if (progressA < progressB && isMe) {
        emoji = '💪'; text = 'Better luck next time!'; bgColor = theme.colorScheme.surfaceContainerHighest; textColor = theme.colorScheme.onSurfaceVariant;
      } else if (progressA == progressB) {
        emoji = '🤝'; text = 'It\'s a tie!'; bgColor = theme.colorScheme.primary.withValues(alpha: 0.1); textColor = theme.colorScheme.primary;
      } else {
        emoji = '🏆'; text = 'Challenge Completed'; bgColor = Colors.amber.withValues(alpha: 0.15); textColor = Colors.amber[800]!;
      }
    } else {
      if (progressA > progressB && isMe) {
        emoji = '🔥'; text = 'You\'re leading by ${progressA - progressB}!'; bgColor = const Color(0xFF4A7C59).withValues(alpha: 0.12); textColor = const Color(0xFF4A7C59);
      } else if (progressA < progressB && isMe) {
        emoji = '⚡'; text = 'Behind by ${progressB - progressA} — keep going!'; bgColor = theme.colorScheme.tertiary.withValues(alpha: 0.1); textColor = theme.colorScheme.tertiary;
      } else if (progressA == progressB) {
        emoji = '⚖️'; text = 'It\'s tied — break the deadlock!'; bgColor = theme.colorScheme.primary.withValues(alpha: 0.1); textColor = theme.colorScheme.primary;
      } else {
        emoji = '📊'; text = 'Challenge in progress'; bgColor = theme.colorScheme.surfaceContainerHighest; textColor = theme.colorScheme.onSurfaceVariant;
      }
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          SizedBox(width: 2.w),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  // CONTEXT-AWARE BOTTOM BAR
  // ══════════════════════════════════════════

  Widget _buildBottomBar(ThemeData theme, bool isCompleted) {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: _buildBottomBarContent(theme, isCompleted),
      ),
    );
  }

  Widget _buildBottomBarContent(ThemeData theme, bool isCompleted) {
    // Completed — show winner celebration + rematch
    if (isCompleted) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _shareChallenge,
              icon: const Icon(Icons.share, size: 18),
              label: const Text('Share Result'),
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
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/tapasya/create-challenge');
              },
              icon: const Icon(Icons.replay, size: 18),
              label: const Text('Rematch 🔄'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: EdgeInsets.symmetric(vertical: 1.5.h),
              ),
            ),
          ),
        ],
      );
    }

    // Check if challenge is full (for 1v1: 2 players, for group: max_participants)
    final leaderboard = _challenge?['leaderboard'] as List<Map<String, dynamic>>? ?? [];
    final maxParticipants = _challenge?['max_participants'] ?? 20;
    final isFull = leaderboard.length >= maxParticipants;

    // Already joined or created — show appropriate share/invite button
    if (_isCreator || _isParticipant) {
      // For 1v1 creator waiting for opponent
      final waitingForOpponent = _is1v1 && leaderboard.length < 2;
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _shareChallenge,
          icon: Icon(waitingForOpponent ? Icons.person_add_alt_1 : Icons.share, size: 18),
          label: Text(waitingForOpponent
              ? 'Share & Find Opponent 🤺'
              : 'Invite Friends'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: EdgeInsets.symmetric(vertical: 1.5.h),
          ),
        ),
      );
    }

    // Not joined but challenge is full — show share only
    if (isFull) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _shareChallenge,
          icon: const Icon(Icons.share, size: 18),
          label: Text(_is1v1 ? 'Challenge Full — 2/2 Players' : 'Challenge Full'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            foregroundColor: theme.colorScheme.onSurfaceVariant,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: EdgeInsets.symmetric(vertical: 1.5.h),
          ),
        ),
      );
    }

    // Not joined, not full — show join + share
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _shareChallenge,
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Share'),
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
              backgroundColor: theme.colorScheme.primary,
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
                : Text(
                    _is1v1 ? 'Accept Duel 🤺' : 'Join Challenge 🔥',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════
  // SHARED WIDGETS
  // ══════════════════════════════════════════

  Widget _buildStatColumn(String emoji, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        SizedBox(height: 0.3.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            color: theme.colorScheme.onSurfaceVariant,
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
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: isMe ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3), width: 2) : null,
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
              backgroundColor: isMe ? theme.colorScheme.primary.withValues(alpha: 0.2) : theme.colorScheme.surfaceContainerHighest,
              backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
              child: (avatarUrl == null || avatarUrl.isEmpty)
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isMe ? theme.colorScheme.primary : theme.colorScheme.onSurface,
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
                        color: isMe ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 0.5.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressPercent.toDouble(),
                    backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(
                      isMe ? theme.colorScheme.primary : theme.colorScheme.primary.withValues(alpha: 0.5),
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
