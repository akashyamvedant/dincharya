// mind_games_world.dart — Mind Games Hub
// Serene Earth aesthetic — matches Routine Dashboard design language.
// Clean · warm · minimal · wellness-focused (NOT arcade gaming).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'game_theme.dart';
import 'mind_games_service.dart';
// ── All game imports ──
import 'games/stroop_test_game.dart';
import 'games/number_search_game.dart';
import 'games/breath_counting_game.dart';
import 'games/recall_your_day_game.dart';
import 'games/speed_match_game.dart';
import 'games/reaction_time_game.dart';
import 'games/memory_match_game.dart';
import 'games/simon_says_game.dart';
import 'games/odd_one_out_game.dart';
import 'games/quick_math_game.dart';
import 'games/hand_gesture_switch.dart';
import 'games/blind_fold_challenge.dart';
import 'games/game_2048.dart';
import 'games/sudoku_game.dart';
import 'games/wordle_game.dart';
import 'games/block_puzzle_game.dart';
import 'games/flow_free_game.dart';
import 'games/dual_nback_game.dart';
import 'games/memory_matrix_game.dart';
import 'games/visual_search_game.dart';
import 'games/number_sequence_game.dart';
import 'games/word_scramble_game.dart';
import 'games/digit_span_game.dart';
import 'games/tile_match_game.dart';
import 'games/daily_trivia_game.dart';
import 'games/mantra_recall_game.dart';
import 'games/asana_sequence_game.dart';
import 'games/mudra_speed_game.dart';
import 'games/thought_watch_game.dart';
import 'games/mantra_japa_game.dart';
import 'games/trataka_game.dart';
import 'games/guna_balance_game.dart';
import 'games/mandala_mirror_game.dart';
import 'games/shloka_game.dart';
import 'games/aum_vibration_game.dart';
import 'games/non_dominant_hand_game.dart';
import 'games/five_senses_game.dart';
import 'games/fist_clench_game.dart';
import 'games/circletriangle_game.dart';
import 'games/new_thing_daily_game.dart';
import 'games/stop_tech_game.dart';
import 'games/self_control_game.dart';

enum GameCategory { speed, memory, focus, logic, all }

// ── Category earth-tone palette (muted, wellness-appropriate) ──
Color _categoryColor(GameCategory c) {
  switch (c) {
    case GameCategory.speed:  return const Color(0xFFCD853F); // warm amber
    case GameCategory.memory: return const Color(0xFFC17767); // terracotta
    case GameCategory.focus:  return const Color(0xFF7D9471); // sage green
    case GameCategory.logic:  return const Color(0xFF9C7A5B); // clay brown
    case GameCategory.all:    return const Color(0xFFCD853F);
  }
}

String _categoryLabel(GameCategory c) {
  switch (c) {
    case GameCategory.speed:  return 'Speed';
    case GameCategory.memory: return 'Memory';
    case GameCategory.focus:  return 'Focus';
    case GameCategory.logic:  return 'Logic';
    case GameCategory.all:    return 'All';
  }
}

class _GameEntry {
  final String name, subtitle;
  final IconData icon;
  final GameCategory category;
  final Widget Function() builder;
  const _GameEntry(this.name, this.icon, this.subtitle, this.category, this.builder);
}

// ═══ Main Hub ═══
class MindGamesWorld extends StatefulWidget {
  const MindGamesWorld({super.key});
  @override
  State<MindGamesWorld> createState() => _MindGamesWorldState();
}

class _MindGamesWorldState extends State<MindGamesWorld>
    with SingleTickerProviderStateMixin {
  final _service = MindGamesService();

  int _xp = 0, _streak = 0, _brainAge = 30, _longestStreak = 0;
  bool _loading = true;
  GameCategory _filter = GameCategory.all;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadStats();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final futures = await Future.wait([
      _service.getXp(),
      _service.getStreak(),
      _service.getLongestStreak(),
      _service.calculateBrainAge(),
    ]);
    if (mounted) {
      setState(() {
        _xp = futures[0] as int;
        _streak = futures[1] as int;
        _longestStreak = futures[2] as int;
        _brainAge = futures[3] as int;
        _loading = false;
      });
      _fadeCtrl.forward();
    }
  }

  void _openGame(Widget game) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => game,
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ).then((_) => _loadStats());
  }

  // ── GAME REGISTRY (Material icons, earth tones) ──
  List<_GameEntry> get _allGames => [
    // Speed
    _GameEntry('Reaction', Icons.bolt_rounded, 'Reflex', GameCategory.speed, () => const ReactionTimeGame()),
    _GameEntry('Speed Match', Icons.compare_arrows_rounded, 'Comparison', GameCategory.speed, () => const SpeedMatchGame()),
    _GameEntry('Number Search', Icons.search_rounded, 'Scanning', GameCategory.speed, () => const NumberSearchGame()),
    _GameEntry('Gesture Switch', Icons.back_hand_rounded, 'Coordination', GameCategory.speed, () => const HandGestureSwitchGame()),
    _GameEntry('Mudra Speed', Icons.front_hand_rounded, 'Yoga Reflex', GameCategory.speed, () => const MudraSpeedGame()),
    _GameEntry('Circle-Triangle', Icons.change_history_rounded, 'Bimanual', GameCategory.speed, () => const CircleTriangleGame()),
    _GameEntry('Non-Dom Hand', Icons.pan_tool_rounded, 'Neurobic', GameCategory.speed, () => const NonDominantHandGame()),
    // Memory
    _GameEntry('Memory Match', Icons.style_rounded, 'Visual', GameCategory.memory, () => const MemoryMatchGame()),
    _GameEntry('Simon Says', Icons.grid_view_rounded, 'Sequence', GameCategory.memory, () => const SimonSaysGame()),
    _GameEntry('Recall Day', Icons.event_note_rounded, 'Recall', GameCategory.memory, () => const RecallYourDayGame()),
    _GameEntry('Dual N-Back', Icons.hearing_rounded, 'Working Mem', GameCategory.memory, () => const DualNBackGame()),
    _GameEntry('Memory Matrix', Icons.grid_on_rounded, 'Visual Work', GameCategory.memory, () => const MemoryMatrixGame()),
    _GameEntry('Digit Span', Icons.pin_rounded, 'Verbal Work', GameCategory.memory, () => const DigitSpanGame()),
    _GameEntry('Mantra Recall', Icons.self_improvement_rounded, 'Auditory', GameCategory.memory, () => const MantraRecallGame()),
    _GameEntry('Asana Sequence', Icons.accessibility_new_rounded, 'Sequence', GameCategory.memory, () => const AsanaSequenceGame()),
    _GameEntry('Shloka', Icons.menu_book_rounded, 'Verbal', GameCategory.memory, () => const ShlokaGame()),
    // Focus
    _GameEntry('Stroop Test', Icons.palette_rounded, 'Attention', GameCategory.focus, () => const StroopTestGame()),
    _GameEntry('Breath Focus', Icons.air_rounded, 'Interoception', GameCategory.focus, () => const BreathCountingGame()),
    _GameEntry('Blind Fold', Icons.visibility_off_rounded, 'Spatial', GameCategory.focus, () => const BlindFoldChallengeGame()),
    _GameEntry('Odd One Out', Icons.filter_center_focus_rounded, 'Perception', GameCategory.focus, () => const OddOneOutGame()),
    _GameEntry('Visual Search', Icons.visibility_rounded, 'Attention', GameCategory.focus, () => const VisualSearchGame()),
    _GameEntry('Thought Watch', Icons.psychology_rounded, 'Vipassana', GameCategory.focus, () => const ThoughtWatchGame()),
    _GameEntry('Japa Counter', Icons.repeat_rounded, 'Mantra', GameCategory.focus, () => const MantraJapaGame()),
    _GameEntry('Trataka', Icons.remove_red_eye_rounded, 'Gaze', GameCategory.focus, () => const TratakaGame()),
    _GameEntry('Aum Vibration', Icons.graphic_eq_rounded, 'Chant', GameCategory.focus, () => const AumVibrationGame()),
    _GameEntry('5 Senses', Icons.spa_rounded, 'Imagination', GameCategory.focus, () => const FiveSensesGame()),
    _GameEntry('Fist Clench', Icons.sports_mma_rounded, 'Neurobic', GameCategory.focus, () => const FistClenchGame()),
    _GameEntry('New Thing', Icons.eco_rounded, 'Growth', GameCategory.focus, () => const NewThingDailyGame()),
    _GameEntry('Stop Tech', Icons.phonelink_erase_rounded, 'Detox', GameCategory.focus, () => const StopTechGame()),
    _GameEntry('Self Control', Icons.spa_outlined, 'Willpower', GameCategory.focus, () => const SelfControlGame()),
    // Logic
    _GameEntry('Quick Math', Icons.calculate_rounded, 'Calculation', GameCategory.logic, () => const QuickMathGame()),
    _GameEntry('2048', Icons.grid_4x4_rounded, 'Merge Puzzle', GameCategory.logic, () => const Game2048()),
    _GameEntry('Sudoku', Icons.apps_rounded, 'Classic', GameCategory.logic, () => const SudokuGame()),
    _GameEntry('Wordle', Icons.abc_rounded, 'Word Puzzle', GameCategory.logic, () => const WordleGame()),
    _GameEntry('Block Puzzle', Icons.dashboard_rounded, 'Spatial', GameCategory.logic, () => const BlockPuzzleGame()),
    _GameEntry('Flow Free', Icons.timeline_rounded, 'Path', GameCategory.logic, () => const FlowFreeGame()),
    _GameEntry('Num Sequence', Icons.trending_up_rounded, 'Pattern', GameCategory.logic, () => const NumberSequenceGame()),
    _GameEntry('Word Scramble', Icons.shuffle_rounded, 'Verbal', GameCategory.logic, () => const WordScrambleGame()),
    _GameEntry('Tile Match', Icons.extension_rounded, 'Visual', GameCategory.logic, () => const TileMatchGame()),
    _GameEntry('Daily Trivia', Icons.quiz_rounded, 'Knowledge', GameCategory.logic, () => const DailyTriviaGame()),
    _GameEntry('Guna Balance', Icons.balance_rounded, 'Philosophy', GameCategory.logic, () => const GunaBalanceGame()),
    _GameEntry('Mandala Mirror', Icons.flip_rounded, 'Symmetry', GameCategory.logic, () => const MandalaMirrorGame()),
  ];

  List<_GameEntry> get _filteredGames => _filter == GameCategory.all
      ? _allGames
      : _allGames.where((g) => g.category == _filter).toList();

  _GameEntry get _dailyChallenge {
    final idx = MindGamesService.dailyChallengeIndex(_allGames.length);
    return _allGames[idx];
  }

  // ── BUILD ──
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: _buildAppBar(context),
      body: _loading
          ? _buildLoading(context)
          : FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 4.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsRow(context),
                    SizedBox(height: 2.5.h),
                    _buildDailyChallenge(context),
                    SizedBox(height: 2.5.h),
                    _buildSectionTitle(context, 'Categories'),
                    SizedBox(height: 1.2.h),
                    _buildCategoryChips(context),
                    SizedBox(height: 2.5.h),
                    _buildSectionTitle(context,
                        '${_categoryLabel(_filter)} Games · ${_filteredGames.length}'),
                    SizedBox(height: 1.2.h),
                    _buildGameGrid(context),
                    SizedBox(height: 2.h),
                    _buildFooter(context),
                  ],
                ),
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_rounded, color: GameTheme.textPrimary(context)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.psychology_rounded, color: GameTheme.primary(context), size: 22),
          SizedBox(width: 2.w),
          Text('Mind Games',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: GameTheme.textPrimary(context),
                    fontWeight: FontWeight.w700,
                  )),
        ],
      ),
      centerTitle: true,
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: GameTheme.primary(context),
            strokeWidth: 2.5,
          ),
          SizedBox(height: 2.h),
          Text('Loading your progress...',
              style: TextStyle(
                  color: GameTheme.textSecondary(context), fontSize: 13.sp)),
        ],
      ),
    );
  }

  // ═══ SECTION TITLE ═══
  Widget _buildSectionTitle(BuildContext ctx, String title) {
    return Text(title,
        style: TextStyle(
              fontSize: 18.sp,
              color: GameTheme.textPrimary(ctx),
              fontWeight: FontWeight.w700,
            ));
  }

  // ═══ STATS ROW — matches routine header badges ═══
  Widget _buildStatsRow(BuildContext ctx) {
    final level = MindGamesService.levelForXp(_xp);
    final progress = MindGamesService.levelProgress(_xp);
    return Column(
      children: [
        Row(
          children: [
            _statBadge(ctx,
                icon: Icons.local_fire_department_rounded,
                color: const Color(0xFFFF8F00),
                value: '$_streak',
                label: _streak == 1 ? 'day' : 'days'),
            SizedBox(width: 3.w),
            _statBadge(ctx,
                icon: Icons.psychology_alt_rounded,
                color: GameColors.brainPurple,
                value: '$_brainAge',
                label: 'brain age'),
            SizedBox(width: 3.w),
            _statBadge(ctx,
                icon: Icons.emoji_events_rounded,
                color: GameTheme.primary(ctx),
                value: 'Lv $level',
                label: '$_xp XP'),
          ],
        ),
        SizedBox(height: 1.2.h),
        // Subtle integrated XP progress
        Container(
          padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.2.h),
          decoration: GameTheme.card(ctx),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Level $level',
                      style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: GameTheme.textPrimary(ctx))),
                  Text('${MindGamesService.xpToNextLevel(_xp)} XP to next',
                      style: TextStyle(
                          fontSize: 12.sp, color: GameTheme.textMuted(ctx))),
                ],
              ),
              SizedBox(height: 0.8.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: progress),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOut,
                  builder: (_, v, __) => LinearProgressIndicator(
                    value: v,
                    minHeight: 6,
                    backgroundColor:
                        GameTheme.primary(ctx).withValues(alpha: 0.1),
                    valueColor:
                        AlwaysStoppedAnimation(GameTheme.primary(ctx)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statBadge(BuildContext ctx,
      {required IconData icon,
      required Color color,
      required String value,
      required String label}) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 1.4.h, horizontal: 2.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            color.withValues(alpha: 0.1),
            color.withValues(alpha: 0.05),
          ]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            SizedBox(height: 0.5.h),
            Text(value,
                style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                    color: GameTheme.textPrimary(ctx))),
            Text(label,
                style: TextStyle(
                    fontSize: 11.sp, color: GameTheme.textSecondary(ctx)),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // ═══ DAILY CHALLENGE HERO ═══
  Widget _buildDailyChallenge(BuildContext ctx) {
    final game = _dailyChallenge;
    final catColor = _categoryColor(game.category);
    return Container(
      width: double.infinity,
      decoration: GameTheme.heroCard(ctx),
      padding: EdgeInsets.all(4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.wb_sunny_rounded,
                  size: 17.sp, color: GameTheme.primary(ctx)),
              SizedBox(width: 2.w),
              Text('DAILY CHALLENGE',
                  style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: GameTheme.primary(ctx))),
              const Spacer(),
              Text(_categoryLabel(game.category),
                  style: TextStyle(
                      fontSize: 12.sp, color: GameTheme.textMuted(ctx))),
            ],
          ),
          SizedBox(height: 2.h),
          Row(
            children: [
              Container(
                width: 14.w,
                height: 14.w,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: catColor.withValues(alpha: 0.3)),
                ),
                child: Icon(game.icon, color: catColor, size: 26.sp),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(game.name,
                        style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w800,
                            color: GameTheme.textPrimary(ctx))),
                    SizedBox(height: 0.5.h),
                    Text(game.subtitle,
                        style: TextStyle(
                            fontSize: 14.sp,
                            color: GameTheme.textSecondary(ctx))),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () => _openGame(game.builder()),
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: Text('Play Now',
                  style: TextStyle(
                      fontSize: 16.sp, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: GameTheme.primary(ctx),
                foregroundColor: Theme.of(ctx).colorScheme.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══ CATEGORY CHIPS ═══
  Widget _buildCategoryChips(BuildContext ctx) {
    final cats = [
      (GameCategory.all, Icons.apps_rounded, 'All'),
      (GameCategory.speed, Icons.bolt_rounded, 'Speed'),
      (GameCategory.memory, Icons.style_rounded, 'Memory'),
      (GameCategory.focus, Icons.center_focus_strong_rounded, 'Focus'),
      (GameCategory.logic, Icons.extension_rounded, 'Logic'),
    ];
    return SizedBox(
      height: 5.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: cats.length,
        separatorBuilder: (_, __) => SizedBox(width: 2.w),
        itemBuilder: (_, i) {
          final (cat, icon, label) = cats[i];
          final sel = _filter == cat;
          final color = cat == GameCategory.all
              ? GameTheme.primary(ctx)
              : _categoryColor(cat);
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _filter = cat);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: EdgeInsets.symmetric(horizontal: 3.5.w),
              decoration: BoxDecoration(
                color: sel
                    ? color.withValues(alpha: 0.15)
                    : GameTheme.primary(ctx).withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: sel
                      ? color.withValues(alpha: 0.4)
                      : GameTheme.primary(ctx).withValues(alpha: 0.12),
                  width: sel ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(icon,
                      size: 17.sp,
                      color: sel ? color : GameTheme.textSecondary(ctx)),
                  SizedBox(width: 1.5.w),
                  Text(label,
                      style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          color:
                              sel ? color : GameTheme.textSecondary(ctx))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══ GAME GRID ═══
  Widget _buildGameGrid(BuildContext ctx) {
    final games = _filteredGames;
    if (games.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 6.h),
          child: Text('No games in this category.',
              style: TextStyle(
                  color: GameTheme.textMuted(ctx), fontSize: 13.sp)),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 3.w,
        crossAxisSpacing: 3.w,
        childAspectRatio: 0.9,
      ),
      itemCount: games.length,
      itemBuilder: (_, index) => _GameTile(
        game: games[index],
        color: _categoryColor(games[index].category),
        index: index,
        onTap: () => _openGame(games[index].builder()),
      ),
    );
  }

  // ═══ FOOTER ═══
  Widget _buildFooter(BuildContext ctx) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(3.5.w),
        decoration: BoxDecoration(
          color: GameTheme.primary(ctx).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: GameTheme.primary(ctx).withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Icon(Icons.spa_rounded,
                color: GameTheme.primary(ctx), size: 24.sp),
            SizedBox(height: 1.h),
            Text('Train daily · 42 games · 4 categories',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: GameTheme.textPrimary(ctx))),
            SizedBox(height: 0.4.h),
            Text('Track your Brain Age & grow mindfully',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12.sp, color: GameTheme.textSecondary(ctx))),
          ],
        ),
      ),
    );
  }
}

// ═══ GAME TILE — clean warm card with earth-toned Material icon ═══
class _GameTile extends StatefulWidget {
  final _GameEntry game;
  final Color color;
  final int index;
  final VoidCallback onTap;
  const _GameTile(
      {required this.game,
      required this.color,
      required this.index,
      required this.onTap});
  @override
  State<_GameTile> createState() => _GameTileState();
}

class _GameTileState extends State<_GameTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 400), vsync: this);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    Future.delayed(Duration(milliseconds: 40 * widget.index), () {
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
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Opacity(
        opacity: _anim.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - _anim.value) * 12),
          child: child,
        ),
      ),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            decoration: GameTheme.card(context),
            padding: EdgeInsets.all(2.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 14.w,
                  height: 14.w,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(widget.game.icon,
                      color: widget.color, size: 28.sp),
                ),
                SizedBox(height: 1.h),
                Text(widget.game.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w700,
                        color: GameTheme.textPrimary(context))),
                Text(widget.game.subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10.sp,
                        color: GameTheme.textSecondary(context))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
