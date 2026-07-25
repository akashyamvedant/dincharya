// lib/presentation/tapasya/tapasya_hub.dart
//
// Main screen for Tapasya (तपस्या) — 5th bottom nav tab
// Shows active challenges, circles, community challenges, activity feed, and badges.
// Uses app's Serene Earth Palette for cohesive design.

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../core/constants/ad_constants.dart';
import '../../services/tapasya_service.dart';
import '../../widgets/ads/banner_ad_widget.dart';
import './widgets/challenge_card_widget.dart';
import './widgets/activity_feed_widget.dart';
import './widgets/tapasya_skeleton.dart';

class TapasyaHub extends StatefulWidget {
  const TapasyaHub({super.key});

  @override
  State<TapasyaHub> createState() => _TapasyaHubState();
}

class _TapasyaHubState extends State<TapasyaHub> with SingleTickerProviderStateMixin {
  final TapasyaService _tapasyaService = TapasyaService();
  int _currentBottomIndex = 2; // Tapasya tab active

  bool _isLoading = true;
  List<Map<String, dynamic>> _activeChallenges = [];
  List<Map<String, dynamic>> _communityChallenges = [];
  List<Map<String, dynamic>> _activityFeed = [];
  List<Map<String, dynamic>> _myBadges = [];
  List<Map<String, dynamic>> _myCircles = [];
  int _badgeCount = 0;
  DateTime? _lastExpiredCheck;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _loadChallenges(),
        _loadCommunityChallenge(),
        _loadActivityFeed(),
        _loadBadges(),
        _loadCircles(),
      ]);

      // Throttle: Check expired challenges at most once per 5 minutes
      final now = DateTime.now();
      if (_lastExpiredCheck == null || now.difference(_lastExpiredCheck!).inMinutes >= 5) {
        _lastExpiredCheck = now;
        _tapasyaService.checkExpiredChallenges();
      }
    } catch (e) {
      debugPrint('❌ Error loading Tapasya data: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadChallenges() async {
    final challenges = await _tapasyaService.getMyChallenges(status: 'active');
    if (mounted) setState(() => _activeChallenges = challenges);
  }

  Future<void> _loadCommunityChallenge() async {
    final challenges = await _tapasyaService.getCommunityChallenge();
    if (mounted) setState(() => _communityChallenges = challenges);
  }

  Future<void> _loadActivityFeed() async {
    final feed = await _tapasyaService.getActivityFeed(limit: 10);
    if (mounted) setState(() => _activityFeed = feed);
  }

  Future<void> _loadBadges() async {
    final badges = await _tapasyaService.getMyBadges();
    if (mounted) {
      setState(() {
        _myBadges = badges;
        _badgeCount = badges.length;
      });
    }
  }

  Future<void> _loadCircles() async {
    final circles = await _tapasyaService.getMyCircles();
    if (mounted) setState(() => _myCircles = circles);
  }

  bool _processedInviteCode = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_processedInviteCode) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic> && args.containsKey('joinCircleInviteCode')) {
        _processedInviteCode = true;
        final inviteCode = args['joinCircleInviteCode'] as String;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleJoinCircleInvite(inviteCode);
        });
      }
    }
  }

  Future<void> _handleJoinCircleInvite(String code) async {
    setState(() => _isLoading = true);
    final success = await _tapasyaService.joinCircle(inviteCode: code);
    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔥 Successfully joined circle! Let\'s practice together.'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to join circle. Invalid invite code or circle is full.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            _buildHeader(theme, isDark),

            // ── Content ──
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                color: theme.colorScheme.primary,
                child: _isLoading
                    ? const TapasyaSkeleton()
                    : ListView(
                        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                        children: [
                          // ── Hero Banner ──
                          _buildHeroBanner(theme, isDark),
                          SizedBox(height: 2.5.h),

                          // ── Stats Row ──
                          _buildStatsRow(theme, isDark),
                          SizedBox(height: 3.h),

                          // ── Active Challenges ──
                          _buildSectionHeader(
                            theme,
                            'Active Challenges',
                            actionLabel: '+ New',
                            onAction: () => Navigator.pushNamed(context, '/tapasya/create-challenge').then((_) => _loadData()),
                          ),
                          SizedBox(height: 1.5.h),

                          if (_activeChallenges.isEmpty)
                            _buildEmptyCard(
                              theme: theme,
                              isDark: isDark,
                              icon: Icons.emoji_events_outlined,
                              title: 'No active challenges',
                              subtitle: 'Create your first challenge and invite friends!',
                              buttonText: 'Create Challenge',
                              onTap: () => Navigator.pushNamed(context, '/tapasya/create-challenge').then((_) => _loadData()),
                            )
                          else
                            SizedBox(
                              height: 20.h,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _activeChallenges.length,
                                separatorBuilder: (_, __) => SizedBox(width: 3.w),
                                itemBuilder: (context, index) {
                                  return ChallengeCardWidget(
                                    challenge: _activeChallenges[index],
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/tapasya/challenge',
                                        arguments: _activeChallenges[index],
                                      ).then((_) => _loadData());
                                    },
                                  );
                                },
                              ),
                            ),

                          SizedBox(height: 3.h),

                          // ── My Circles ──
                          _buildSectionHeader(
                            theme,
                            'My Circles',
                            icon: Icons.groups_rounded,
                            actionLabel: '+ New',
                            onAction: () => Navigator.pushNamed(context, '/tapasya/create-circle').then((_) => _loadData()),
                          ),
                          SizedBox(height: 1.h),

                          if (_myCircles.isEmpty)
                            _buildEmptyCard(
                              theme: theme,
                              isDark: isDark,
                              icon: Icons.groups_3_outlined,
                              title: 'No circles joined',
                              subtitle: 'Create a circle or join an existing one to practice together!',
                              buttonText: 'Create Circle',
                              onTap: () => Navigator.pushNamed(context, '/tapasya/create-circle').then((_) => _loadData()),
                            )
                          else
                            SizedBox(
                              height: 14.h,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _myCircles.length,
                                separatorBuilder: (_, __) => SizedBox(width: 3.w),
                                itemBuilder: (context, index) {
                                  final circle = _myCircles[index];
                                  return _buildCircleCard(circle, theme, isDark);
                                },
                              ),
                            ),

                          SizedBox(height: 3.h),

                          // ── My Badges (horizontal scroll) ──
                          if (_myBadges.isNotEmpty) ...[
                            _buildSectionHeader(
                              theme,
                              'My Badges',
                              icon: Icons.military_tech_rounded,
                              actionLabel: 'View All',
                              onAction: () => Navigator.pushNamed(context, '/tapasya/badges'),
                            ),
                            SizedBox(height: 1.h),
                            SizedBox(
                              height: 9.h,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _myBadges.length,
                                separatorBuilder: (_, __) => SizedBox(width: 2.w),
                                itemBuilder: (context, index) {
                                  final badge = _myBadges[index]['badge'] ?? _myBadges[index];
                                  return _buildBadgeChip(badge, theme, isDark);
                                },
                              ),
                            ),
                            SizedBox(height: 3.h),
                          ],

                          // ── Community Challenges ──
                          _buildSectionHeader(
                            theme,
                            'Community Challenges',
                            icon: Icons.public_rounded,
                            actionLabel: 'Browse',
                            onAction: () => Navigator.pushNamed(context, '/tapasya/community'),
                          ),
                          SizedBox(height: 1.h),

                          if (_communityChallenges.isEmpty)
                            _buildEmptyCard(
                              theme: theme,
                              isDark: isDark,
                              icon: Icons.groups_outlined,
                              title: 'No community challenges',
                              subtitle: 'Community challenges will appear here soon!',
                            )
                          else
                            ...(_communityChallenges.take(3).map((challenge) {
                              return Padding(
                                padding: EdgeInsets.only(bottom: 1.5.h),
                                child: _buildCommunityChallenge(challenge, theme, isDark),
                              );
                            })),

                          SizedBox(height: 3.h),

                          // ── Recent Activity ──
                          _buildSectionHeader(theme, 'Recent Activity', icon: Icons.bolt_rounded),
                          SizedBox(height: 1.h),

                          if (_activityFeed.isEmpty)
                            _buildEmptyCard(
                              theme: theme,
                              isDark: isDark,
                              icon: Icons.timeline_outlined,
                              title: 'No activity yet',
                              subtitle: 'Complete a session or join a challenge to see activity here',
                            )
                          else
                            ...(_activityFeed.take(5).map((activity) {
                              return ActivityFeedWidget(
                                activity: activity,
                                onReact: (emoji) async {
                                  await _tapasyaService.addReaction(activity['id'], emoji);
                                  _loadActivityFeed();
                                },
                              );
                            })),

                          SizedBox(height: 4.h),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),

      // ── FAB: Create Challenge ──
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/tapasya/create-challenge').then((_) => _loadData()),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        icon: const Icon(Icons.add),
        label: Text('Challenge', style: TextStyle(fontWeight: FontWeight.w600)),
      ),

      // ── Bottom Navigation ──
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Banner ad — own placement, non-collapsible (analytics integrity fix)
          const AdaptiveBannerAdWidget(placement: BannerPlacement.tapasyaHub),
          BottomNavigationBar(
            currentIndex: _currentBottomIndex,
            type: BottomNavigationBarType.fixed,
            backgroundColor: theme.colorScheme.surface,
            selectedItemColor: theme.colorScheme.primary,
            unselectedItemColor: theme.colorScheme.onSurfaceVariant,
            selectedFontSize: 12,
            unselectedFontSize: 11,
            items: [
              BottomNavigationBarItem(
                icon: CustomIconWidget(
                  iconName: 'schedule',
                  color: _currentBottomIndex == 0
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  size: 24,
                ),
                label: 'Routine',
              ),
              BottomNavigationBarItem(
                icon: CustomIconWidget(
                  iconName: 'self_improvement',
                  color: _currentBottomIndex == 1
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  size: 24,
                ),
                label: 'Guided',
              ),
              BottomNavigationBarItem(
                icon: Icon(
                  Icons.local_fire_department,
                  color: _currentBottomIndex == 2
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  size: 24,
                ),
                label: 'Tapasya',
              ),
              BottomNavigationBarItem(
                icon: CustomIconWidget(
                  iconName: 'book',
                  color: _currentBottomIndex == 3
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  size: 24,
                ),
                label: 'Journal',
              ),
              BottomNavigationBarItem(
                icon: CustomIconWidget(
                  iconName: 'person',
                  color: _currentBottomIndex == 4
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  size: 24,
                ),
                label: 'Me',
              ),
            ],
            onTap: (index) {
              if (index == _currentBottomIndex) return;
              setState(() => _currentBottomIndex = index);
              switch (index) {
                case 0:
                  Navigator.pushReplacementNamed(context, '/routine-dashboard');
                  break;
                case 1:
                  Navigator.pushReplacementNamed(context, '/guided-sessions-hub');
                  break;
                case 2:
                  break; // Already here
                case 3:
                  Navigator.pushReplacementNamed(context, '/journal-mood-tracker');
                  break;
                case 4:
                  Navigator.pushReplacementNamed(context, '/profile-settings');
                  break;
              }
            },
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ── HEADER ──
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildHeader(ThemeData theme, bool isDark) {
    return Padding(
      padding: EdgeInsets.fromLTRB(5.w, 2.h, 5.w, 1.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'तपस्या',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.0,
                ),
              ),
              SizedBox(height: 0.3.h),
              Text(
                'Tapasya Hub',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          // Badges chip
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/tapasya/badges'),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.military_tech_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  SizedBox(width: 1.5.w),
                  Text(
                    '$_badgeCount',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ── HERO BANNER ──
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildHeroBanner(ThemeData theme, bool isDark) {
    return Container(
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isDark
              ? [
                  theme.colorScheme.primary.withValues(alpha: 0.2),
                  theme.colorScheme.secondary.withValues(alpha: 0.1),
                  theme.colorScheme.surface,
                ]
              : [
                  theme.colorScheme.primary.withValues(alpha: 0.12),
                  theme.colorScheme.secondary.withValues(alpha: 0.06),
                  theme.colorScheme.surface,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top label
          Container(
            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '🔥 SANGHA SADHANA',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          SizedBox(height: 1.5.h),
          Text(
            'Practice together\nin real-time.',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          SizedBox(height: 0.8.h),
          Text(
            'Sync timers, build discipline with your circle.',
            style: theme.textTheme.bodySmall,
          ),
          SizedBox(height: 2.h),
          // CTA button
          GestureDetector(
            onTap: () {
              if (_myCircles.isNotEmpty) {
                Navigator.pushNamed(
                  context,
                  '/tapasya/circle',
                  arguments: _myCircles.first,
                );
              } else {
                Navigator.pushNamed(context, '/tapasya/create-circle').then((_) => _loadData());
              }
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.2.h),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.radio_button_checked, color: theme.colorScheme.onPrimary, size: 16),
                  SizedBox(width: 2.w),
                  Text(
                    'Join Live Sadhana',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ── STATS ROW ──
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildStatsRow(ThemeData theme, bool isDark) {
    return Row(
      children: [
        _buildStatCard(
          theme: theme,
          isDark: isDark,
          value: '${_activeChallenges.length}',
          label: 'ACTIVE',
          isHighlighted: false,
        ),
        SizedBox(width: 3.w),
        _buildStatCard(
          theme: theme,
          isDark: isDark,
          value: '${_myCircles.length}',
          label: 'CIRCLES',
          isHighlighted: true,
        ),
        SizedBox(width: 3.w),
        _buildStatCard(
          theme: theme,
          isDark: isDark,
          value: '$_badgeCount',
          label: 'BADGES',
          isHighlighted: false,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required ThemeData theme,
    required bool isDark,
    required String value,
    required String label,
    required bool isHighlighted,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 1.8.h),
        decoration: BoxDecoration(
          color: isHighlighted
              ? theme.colorScheme.primary
              : theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: isHighlighted
              ? null
              : Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
          boxShadow: isHighlighted
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: isHighlighted
                  ? theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w800,
                    )
                  : theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
            ),
            SizedBox(height: 0.3.h),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isHighlighted
                    ? theme.colorScheme.onPrimary.withValues(alpha: 0.85)
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ── SECTION HEADER ──
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildSectionHeader(ThemeData theme, String title, {IconData? icon, String? actionLabel, VoidCallback? onAction}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(width: 2.5.w),
            if (icon != null) ...[
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              SizedBox(width: 1.5.w),
            ],
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.6.h),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                actionLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ── EMPTY CARD ──
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildEmptyCard({
    required ThemeData theme,
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    String? buttonText,
    VoidCallback? onTap,
  }) {
    return Container(
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
          SizedBox(height: 1.h),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 0.5.h),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          if (buttonText != null) ...[
            SizedBox(height: 2.h),
            ElevatedButton(
              onPressed: onTap,
              child: Text(buttonText),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ── COMMUNITY CHALLENGE CARD ──
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildCommunityChallenge(Map<String, dynamic> challenge, ThemeData theme, bool isDark) {
    final isJoined = challenge['is_joined'] == true;
    final participantCount = challenge['participant_count'] ?? 0;
    final daysLeft = DateTime.tryParse(challenge['ends_at'] ?? '')
            ?.difference(DateTime.now())
            .inDays ??
        0;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/tapasya/challenge', arguments: challenge).then((_) => _loadData()),
      child: Container(
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('🏆', style: TextStyle(fontSize: 20)),
              ),
            ),
            SizedBox(width: 3.w),
            // Title & meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    challenge['title'] ?? 'Challenge',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 0.3.h),
                  Text(
                    '$participantCount participants • ${daysLeft}d left',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            SizedBox(width: 2.w),
            // Join / Joined indicator
            if (!isJoined)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 0.8.h),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Join',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              Icon(
                Icons.check_circle_rounded,
                color: isDark ? const Color(0xFF81C784) : const Color(0xFF4A7C59),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ── BADGE CHIP ──
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildBadgeChip(Map<String, dynamic> badge, ThemeData theme, bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withValues(alpha: isDark ? 0.1 : 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.secondary.withValues(alpha: isDark ? 0.2 : 0.12),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(badge['icon'] ?? '🏅', style: TextStyle(fontSize: 18.sp)),
          SizedBox(height: 0.3.h),
          Text(
            badge['title'] ?? '',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ── CIRCLE CARD ──
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildCircleCard(Map<String, dynamic> circle, ThemeData theme, bool isDark) {
    final name = circle['name'] ?? 'Circle';
    final memberCount = circle['member_count'] ?? 1;
    final description = circle['description'] ?? '';

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/tapasya/circle',
        arguments: circle,
      ).then((_) => _loadData()),
      child: Container(
        width: 48.w,
        padding: EdgeInsets.all(3.5.w),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.groups_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 1.h),
            Text(
              '$memberCount members',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            if (description.isNotEmpty) ...[
              SizedBox(height: 0.3.h),
              Text(
                description,
                style: theme.textTheme.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
