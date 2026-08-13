// lib/presentation/routine_dashboard/mind_games/widgets/achievements_screen.dart
// PREMIUM ACHIEVEMENTS SCREEN — Full badges page with earned/locked states,
// progress tracking, category breakdown, and celebration animations.

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});
  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with TickerProviderStateMixin {
  final _service = MindGamesService();
  List<GameBadge> _earnedBadges = [];
  bool _loading = true;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadBadges();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBadges() async {
    final earned = await _service.getEarnedBadges();
    if (mounted) {
      setState(() {
        _earnedBadges = earned;
        _loading = false;
      });
      _fadeCtrl.forward();
    }
  }

  Set<String> get _earnedIds => _earnedBadges.map((b) => b.id).toSet();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: GameTheme.textPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspace_premium_rounded,
                color: GameColors.gold, size: 22),
            SizedBox(width: 2.w),
            Text('Achievements',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: GameTheme.textPrimary(context),
                      fontWeight: FontWeight.w700,
                    )),
          ],
        ),
        centerTitle: true,
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                  color: GameTheme.primary(context), strokeWidth: 2.5))
          : FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 4.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProgressHeader(context),
                    SizedBox(height: 3.h),
                    _buildSectionLabel(context, 'Earned',
                        count: _earnedBadges.length),
                    SizedBox(height: 1.5.h),
                    if (_earnedBadges.isEmpty)
                      _buildEmptyEarned(context)
                    else
                      _buildBadgeGrid(context, _earnedBadges, earned: true),
                    SizedBox(height: 3.h),
                    _buildSectionLabel(context, 'Locked',
                        count: MindGamesService.allBadges.length -
                            _earnedBadges.length),
                    SizedBox(height: 1.5.h),
                    _buildBadgeGrid(
                      context,
                      MindGamesService.allBadges
                          .where((b) => !_earnedIds.contains(b.id))
                          .toList(),
                      earned: false,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ═══ PROGRESS HEADER ═══
  Widget _buildProgressHeader(BuildContext ctx) {
    final total = MindGamesService.allBadges.length;
    final earned = _earnedBadges.length;
    final progress = total > 0 ? earned / total : 0.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(5.w),
      decoration: GameTheme.heroCard(ctx),
      child: Column(
        children: [
          // Trophy icon with glow
          Container(
            width: 20.w,
            height: 20.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  GameColors.gold.withValues(alpha: 0.2),
                  GameColors.gold.withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(
                  color: GameColors.gold.withValues(alpha: 0.3), width: 2),
              boxShadow: [
                BoxShadow(
                  color: GameColors.gold.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(Icons.emoji_events_rounded,
                size: 36.sp, color: GameColors.gold),
          ),
          SizedBox(height: 2.h),
          Text('$earned / $total',
              style: TextStyle(
                fontSize: 28.sp,
                fontWeight: FontWeight.w900,
                color: GameTheme.textPrimary(ctx),
              )),
          SizedBox(height: 0.5.h),
          Text('Badges Earned',
              style: TextStyle(
                fontSize: 13.sp,
                color: GameTheme.textSecondary(ctx),
                fontWeight: FontWeight.w500,
              )),
          SizedBox(height: 2.h),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: progress),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                        colors: [GameColors.gold, Color(0xFFFFA500)])
                    .createShader(bounds),
                child: LinearProgressIndicator(
                  value: v,
                  minHeight: 8,
                  backgroundColor:
                      GameTheme.primary(ctx).withValues(alpha: 0.08),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ),
          ),
          SizedBox(height: 1.h),
          Text('${(progress * 100).round()}% complete',
              style: TextStyle(
                fontSize: 11.sp,
                color: GameTheme.textMuted(ctx),
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }

  // ═══ SECTION LABEL ═══
  Widget _buildSectionLabel(BuildContext ctx, String title, {int count = 0}) {
    return Row(
      children: [
        Text(title,
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: GameTheme.textPrimary(ctx),
            )),
        SizedBox(width: 2.w),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.3.h),
          decoration: BoxDecoration(
            color: GameTheme.primary(ctx).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$count',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: GameTheme.primary(ctx),
              )),
        ),
      ],
    );
  }

  // ═══ EMPTY EARNED STATE ═══
  Widget _buildEmptyEarned(BuildContext ctx) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(5.w),
      decoration: GameTheme.card(ctx),
      child: Column(
        children: [
          Icon(Icons.lock_outline_rounded,
              size: 32.sp, color: GameTheme.textMuted(ctx)),
          SizedBox(height: 1.h),
          Text('No badges yet',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: GameTheme.textSecondary(ctx),
              )),
          SizedBox(height: 0.5.h),
          Text('Play mind games to earn your first badge!',
              style: TextStyle(
                fontSize: 12.sp,
                color: GameTheme.textMuted(ctx),
              )),
        ],
      ),
    );
  }

  // ═══ BADGE GRID ═══
  Widget _buildBadgeGrid(BuildContext ctx, List<GameBadge> badges,
      {required bool earned}) {
    if (badges.isEmpty) {
      return SizedBox(
        width: double.infinity,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 2.h),
          child: Center(
            child: Text(
              earned ? '' : 'All badges earned! 🎉',
              style: TextStyle(
                fontSize: 13.sp,
                color: GameTheme.textMuted(ctx),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 3.w,
        crossAxisSpacing: 3.w,
        childAspectRatio: 2.8,
      ),
      itemCount: badges.length,
      itemBuilder: (_, i) =>
          _BadgeCard(badge: badges[i], earned: earned, index: i),
    );
  }
}

// ═══ INDIVIDUAL BADGE CARD ═══
class _BadgeCard extends StatefulWidget {
  final GameBadge badge;
  final bool earned;
  final int index;
  const _BadgeCard(
      {required this.badge, required this.earned, required this.index});
  @override
  State<_BadgeCard> createState() => _BadgeCardState();
}

class _BadgeCardState extends State<_BadgeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    Future.delayed(Duration(milliseconds: 80 * widget.index), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Opacity(
        opacity: _anim.value.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 0.8 + (_anim.value * 0.2),
          child: child,
        ),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.2.h),
        decoration: BoxDecoration(
          color: widget.earned
              ? (GameTheme.isDark(ctx) ? const Color(0xFF2E2218) : Colors.white)
              : (GameTheme.isDark(ctx)
                  ? const Color(0xFF1E1810)
                  : const Color(0xFFF5F0EA)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.earned
                ? GameColors.gold.withValues(alpha: 0.35)
                : GameTheme.primary(ctx).withValues(alpha: 0.08),
            width: widget.earned ? 1.5 : 1,
          ),
          boxShadow: widget.earned
              ? [
                  BoxShadow(
                    color: GameColors.gold.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Emoji circle
            Container(
              width: 11.w,
              height: 11.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: widget.earned
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          GameColors.gold.withValues(alpha: 0.2),
                          GameColors.gold.withValues(alpha: 0.05),
                        ],
                      )
                    : null,
                color: widget.earned
                    ? null
                    : GameTheme.primary(ctx).withValues(alpha: 0.05),
                border: Border.all(
                  color: widget.earned
                      ? GameColors.gold.withValues(alpha: 0.3)
                      : GameTheme.primary(ctx).withValues(alpha: 0.1),
                ),
              ),
              child: Center(
                child: widget.earned
                    ? Text(widget.badge.emoji,
                        style: TextStyle(fontSize: 18.sp))
                    : Icon(Icons.lock_rounded,
                        size: 16.sp, color: GameTheme.textMuted(ctx)),
              ),
            ),
            SizedBox(width: 2.5.w),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.badge.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w700,
                      color: widget.earned
                          ? GameTheme.textPrimary(ctx)
                          : GameTheme.textMuted(ctx),
                    ),
                  ),
                  SizedBox(height: 0.2.h),
                  Text(
                    widget.badge.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: widget.earned
                          ? GameTheme.textSecondary(ctx)
                          : GameTheme.textMuted(ctx).withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            // Earned checkmark
            if (widget.earned)
              Icon(Icons.verified_rounded,
                  size: 16.sp, color: GameColors.successGreen),
          ],
        ),
      ),
    );
  }
}
