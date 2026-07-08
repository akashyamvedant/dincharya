// lib/presentation/tapasya/tapasya_hub.dart
//
// Main screen for Tapasya (तपस्या) — 5th bottom nav tab
// Shows active challenges, circles, community challenges, activity feed, and badges.

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

      // Check expired challenges on each load
      _tapasyaService.checkExpiredChallenges();
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
    final primaryColor = const Color(0xFFE65100); // Deep orange — fire/tapasya color

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Container(
              height: 20.h,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                child: Stack(
                  children: [
                    // Dynamic abstract fire/flow background image
                    Positioned.fill(
                      child: Image.network(
                        'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?q=80&w=600',
                        fit: BoxFit.cover,
                      ),
                    ),
                    // Gradient overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primaryColor.withOpacity(0.95),
                              primaryColor.withOpacity(0.65),
                              Colors.black.withOpacity(0.3),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),
                    // Content
                    Padding(
                      padding: EdgeInsets.fromLTRB(5.w, 3.h, 5.w, 2.h),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '🔥',
                                      style: TextStyle(fontSize: 26.sp),
                                    ),
                                    SizedBox(width: 2.w),
                                    Text(
                                      'तपस्या',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 22.sp,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                        shadows: const [
                                          Shadow(
                                            blurRadius: 8.0,
                                            color: Colors.black45,
                                            offset: Offset(1.0, 1.0),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 0.8.h),
                                Text(
                                  'Challenge yourself. Grow together.',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Badges count button
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(context, '/tapasya/badges'),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('🏅', style: TextStyle(fontSize: 15.sp)),
                                  SizedBox(width: 1.5.w),
                                  Text(
                                    '$_badgeCount',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Content ──
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                color: primaryColor,
                child: _isLoading
                    ? const TapasyaSkeleton()
                    : ListView(
                        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                        children: [
                          // ── Active Challenges ──
                          _buildSectionHeader(
                            '🏆 Active Challenges',
                            actionLabel: '+ New',
                            onAction: () => Navigator.pushNamed(context, '/tapasya/create-challenge').then((_) => _loadData()),
                          ),
                          SizedBox(height: 1.h),

                          if (_activeChallenges.isEmpty)
                            _buildEmptyCard(
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
                            '👥 My Circles',
                            actionLabel: '+ New',
                            onAction: () => Navigator.pushNamed(context, '/tapasya/create-circle').then((_) => _loadData()),
                          ),
                          SizedBox(height: 1.h),

                          if (_myCircles.isEmpty)
                            _buildEmptyCard(
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
                                  return _buildCircleCard(circle);
                                },
                              ),
                            ),

                          SizedBox(height: 3.h),

                          // ── My Badges (horizontal scroll) ──
                          if (_myBadges.isNotEmpty) ...[
                            _buildSectionHeader(
                              '🏅 My Badges',
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
                                  return _buildBadgeChip(badge);
                                },
                              ),
                            ),
                            SizedBox(height: 3.h),
                          ],

                          // ── Community Challenges ──
                          _buildSectionHeader(
                            '🌍 Community Challenges',
                            actionLabel: 'Browse',
                            onAction: () => Navigator.pushNamed(context, '/tapasya/community'),
                          ),
                          SizedBox(height: 1.h),

                          if (_communityChallenges.isEmpty)
                            _buildEmptyCard(
                              icon: Icons.groups_outlined,
                              title: 'No community challenges',
                              subtitle: 'Community challenges will appear here soon!',
                            )
                          else
                            ...(_communityChallenges.take(3).map((challenge) {
                              return Padding(
                                padding: EdgeInsets.only(bottom: 1.5.h),
                                child: _buildCommunityChallenge(challenge),
                              );
                            })),

                          SizedBox(height: 3.h),

                          // ── Recent Activity ──
                          _buildSectionHeader('⚡ Recent Activity'),
                          SizedBox(height: 1.h),

                          if (_activityFeed.isEmpty)
                            _buildEmptyCard(
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
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Challenge', style: TextStyle(fontWeight: FontWeight.bold)),
      ),

      // ── Bottom Navigation ──
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AdaptiveBannerAdWidget(placement: BannerPlacement.guidedHub),
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

  // ── Helper Widgets ──

  Widget _buildSectionHeader(String title, {String? actionLabel, VoidCallback? onAction}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
              decoration: BoxDecoration(
                color: const Color(0xFFE65100).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                actionLabel,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFE65100),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyCard({
    required IconData icon,
    required String title,
    required String subtitle,
    String? buttonText,
    VoidCallback? onTap,
  }) {
    return Container(
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant),
          SizedBox(height: 1.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 0.5.h),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.sp,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (buttonText != null) ...[
            SizedBox(height: 2.h),
            ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.5.h),
              ),
              child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommunityChallenge(Map<String, dynamic> challenge) {
    final theme = Theme.of(context);
    final isJoined = challenge['is_joined'] == true;
    final participantCount = challenge['participant_count'] ?? 0;
    final daysLeft = DateTime.tryParse(challenge['ends_at'] ?? '')
            ?.difference(DateTime.now())
            .inDays ??
        0;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/tapasya/challenge', arguments: challenge).then((_) => _loadData()),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE65100).withOpacity(0.3), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              // Underlay Background Image
              Positioned.fill(
                child: Image.network(
                  'https://images.unsplash.com/photo-1511632765486-a01980e01a18?q=80&w=400',
                  fit: BoxFit.cover,
                ),
              ),
              // Gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.85),
                        Colors.black.withOpacity(0.55),
                        const Color(0xFFE65100).withOpacity(0.1),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: EdgeInsets.all(4.w),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE65100).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text('🏆', style: TextStyle(fontSize: 20)),
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            challenge['title'] ?? 'Challenge',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: const [
                                Shadow(blurRadius: 4, color: Colors.black),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 0.5.h),
                          Text(
                            '$participantCount participants • ${daysLeft}d left',
                            style: TextStyle(
                              fontSize: 11.5.sp,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 2.w),
                    if (!isJoined)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE65100),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE65100).withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          'Join',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: EdgeInsets.all(1.w),
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle, color: Colors.green, size: 24),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeChip(Map<String, dynamic> badge) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withOpacity(0.15),
            Colors.orange.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(badge['icon'] ?? '🏅', style: TextStyle(fontSize: 20.sp)),
          SizedBox(height: 0.3.h),
          Text(
            badge['title'] ?? '',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleCard(Map<String, dynamic> circle) {
    final theme = Theme.of(context);
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
        width: 52.w,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE65100).withOpacity(0.25),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              // Underlay Background Image
              Positioned.fill(
                child: Image.network(
                  'https://images.unsplash.com/photo-1522071820081-009f0129c71c?q=80&w=400',
                  fit: BoxFit.cover,
                ),
              ),
              // Gradient Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.85),
                        Colors.black.withOpacity(0.55),
                        const Color(0xFFE65100).withOpacity(0.08),
                      ],
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                    ),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: EdgeInsets.all(4.w),
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
                            color: const Color(0xFFE65100).withOpacity(0.25),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text('👥', style: TextStyle(fontSize: 14)),
                          ),
                        ),
                        SizedBox(width: 2.w),
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 13.5.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: const [
                                Shadow(blurRadius: 4, color: Colors.black87),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 1.5.h),
                    Text(
                      '$memberCount members',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      SizedBox(height: 0.5.h),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: Colors.white54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
