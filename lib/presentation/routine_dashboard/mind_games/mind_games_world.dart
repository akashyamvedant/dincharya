// mind_games_world.dart — Mind Games Hub v3
// Serene Earth aesthetic — matches Routine Dashboard design language.
// Clean · warm · minimal · wellness-focused (NOT arcade gaming).
// v3: Animated stats, brain age gauge, search, best scores on tiles,
//     daily challenge countdown, played-today indicators.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'game_theme.dart';
import 'mind_games_service.dart';
import '../../../services/ads_service.dart';
import '../../../core/constants/ad_constants.dart';
import 'widgets/achievements_screen.dart';
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
    case GameCategory.speed:
      return const Color(0xFFCD853F); // warm amber
    case GameCategory.memory:
      return const Color(0xFFC17767); // terracotta
    case GameCategory.focus:
      return const Color(0xFF7D9471); // sage green
    case GameCategory.logic:
      return const Color(0xFF9C7A5B); // clay brown
    case GameCategory.all:
      return const Color(0xFFCD853F);
  }
}

String _categoryLabel(GameCategory c) {
  switch (c) {
    case GameCategory.speed:
      return 'Speed';
    case GameCategory.memory:
      return 'Memory';
    case GameCategory.focus:
      return 'Focus';
    case GameCategory.logic:
      return 'Logic';
    case GameCategory.all:
      return 'All';
  }
}

class _GameEntry {
  final String name, subtitle;
  final IconData icon;
  final GameCategory category;
  final Widget Function() builder;
  const _GameEntry(
      this.name, this.icon, this.subtitle, this.category, this.builder);
}

// ═══ Main Hub ═══
class MindGamesWorld extends StatefulWidget {
  const MindGamesWorld({super.key});
  @override
  State<MindGamesWorld> createState() => _MindGamesWorldState();
}

class _MindGamesWorldState extends State<MindGamesWorld>
    with TickerProviderStateMixin {
  final _service = MindGamesService();

  int _xp = 0, _streak = 0, _brainAge = 30, _longestStreak = 0;
  int _gamesPlayedCount = 0; // Counter for interstitial ad capping
  final bool _loading = false; // Start with false — show UI immediately
  GameCategory _filter = GameCategory.all;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  Map<String, double?> _bestScores = {};
  Set<String> _playedToday = {};
  Timer? _countdownTimer;
  String _dailyCountdown = '';
  List<GameBadge> _earnedBadges = [];

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late AnimationController _gaugeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _gaugeCtrl = AnimationController(
        duration: const Duration(milliseconds: 1200), vsync: this);
    // Show UI immediately, load data in background
    _fadeCtrl.forward();
    _gaugeCtrl.forward();
    _loadStatsProgressive();
    _startCountdownTimer();
    // Preload ads so they're ready when user finishes a game
    AdsService().loadRewardedAdForPlacement(RewardedPlacement.mindGameDoubleXp);
    AdsService().loadRewardedAdForPlacement(RewardedPlacement.mindGameRetry);
    AdsService().loadInterstitialAd(InterstitialPlacement.gameCompleted);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _gaugeCtrl.dispose();
    _countdownTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _startCountdownTimer() {
    _updateCountdown();
    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _updateCountdown());
  }

  void _updateCountdown() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final remaining = tomorrow.difference(now);
    final h = remaining.inHours;
    final m = remaining.inMinutes % 60;
    final s = remaining.inSeconds % 60;
    if (mounted) {
      setState(() => _dailyCountdown = '${h}h ${m}m ${s}s');
    }
  }

  /// Progressive loading — fast local data first, then Supabase in background
  Future<void> _loadStatsProgressive() async {
    // Phase 1: Load fast local data (SharedPreferences — instant)
    try {
      final localFutures = await Future.wait([
        _service.getXp(),
        _service.getStreak(),
        _service.getLongestStreak(),
      ]);
      if (mounted) {
        setState(() {
          _xp = localFutures[0];
          _streak = localFutures[1];
          _longestStreak = localFutures[2];
        });
      }
    } catch (_) {}

    // Phase 2: Load slower Supabase data in background (non-blocking)
    _loadSupabaseData();
  }

  Future<void> _loadSupabaseData() async {
    try {
      final results = await Future.wait([
        _service.calculateBrainAge(),
        _service.getBestScores(),
        _service.getPlayedToday(),
        _service.getEarnedBadges(),
      ]);
      if (mounted) {
        final bests = results[1] as Map<String, Map<String, dynamic>>;
        final bestScores = <String, double?>{};
        for (final entry in bests.entries) {
          bestScores[entry.key] = (entry.value['score'] as num?)?.toDouble();
        }
        setState(() {
          _brainAge = results[0] as int;
          _bestScores = bestScores;
          _playedToday = results[2] as Set<String>;
          _earnedBadges = results[3] as List<GameBadge>;
        });
        // Re-animate gauge with real brain age
        _gaugeCtrl.forward(from: 0.0);
      }
    } catch (_) {}
  }

  /// Called after returning from a game — reload stats
  Future<void> _loadStats() async {
    await _loadStatsProgressive();
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
    ).then((_) {
      _loadStats();
      // Show interstitial after every 3rd game
      _gamesPlayedCount++;
      if (_gamesPlayedCount % 3 == 0) {
        AdsService()
            .showInterstitialAdWithCapping(InterstitialPlacement.gameCompleted);
      }
    });
  }

  // ── GAME REGISTRY (Material icons, earth tones) ──
  List<_GameEntry> get _allGames => [
        // Speed
        _GameEntry('Reaction', Icons.bolt_rounded, 'Reflex', GameCategory.speed,
            () => const ReactionTimeGame()),
        _GameEntry('Speed Match', Icons.compare_arrows_rounded, 'Comparison',
            GameCategory.speed, () => const SpeedMatchGame()),
        _GameEntry('Number Search', Icons.search_rounded, 'Scanning',
            GameCategory.speed, () => const NumberSearchGame()),
        _GameEntry('Gesture Switch', Icons.back_hand_rounded, 'Coordination',
            GameCategory.speed, () => const HandGestureSwitchGame()),
        _GameEntry('Mudra Speed', Icons.front_hand_rounded, 'Yoga Reflex',
            GameCategory.speed, () => const MudraSpeedGame()),
        _GameEntry('Circle-Triangle', Icons.change_history_rounded, 'Bimanual',
            GameCategory.speed, () => const CircleTriangleGame()),
        _GameEntry('Non-Dom Hand', Icons.pan_tool_rounded, 'Neurobic',
            GameCategory.speed, () => const NonDominantHandGame()),
        // Memory
        _GameEntry('Memory Match', Icons.style_rounded, 'Visual',
            GameCategory.memory, () => const MemoryMatchGame()),
        _GameEntry('Simon Says', Icons.grid_view_rounded, 'Sequence',
            GameCategory.memory, () => const SimonSaysGame()),
        _GameEntry('Recall Day', Icons.event_note_rounded, 'Recall',
            GameCategory.memory, () => const RecallYourDayGame()),
        _GameEntry('Dual N-Back', Icons.hearing_rounded, 'Working Mem',
            GameCategory.memory, () => const DualNBackGame()),
        _GameEntry('Memory Matrix', Icons.grid_on_rounded, 'Visual Work',
            GameCategory.memory, () => const MemoryMatrixGame()),
        _GameEntry('Digit Span', Icons.pin_rounded, 'Verbal Work',
            GameCategory.memory, () => const DigitSpanGame()),
        _GameEntry('Mantra Recall', Icons.self_improvement_rounded, 'Auditory',
            GameCategory.memory, () => const MantraRecallGame()),
        _GameEntry('Asana Sequence', Icons.accessibility_new_rounded,
            'Sequence', GameCategory.memory, () => const AsanaSequenceGame()),
        _GameEntry('Shloka', Icons.menu_book_rounded, 'Verbal',
            GameCategory.memory, () => const ShlokaGame()),
        // Focus
        _GameEntry('Stroop Test', Icons.palette_rounded, 'Attention',
            GameCategory.focus, () => const StroopTestGame()),
        _GameEntry('Breath Focus', Icons.air_rounded, 'Interoception',
            GameCategory.focus, () => const BreathCountingGame()),
        _GameEntry('Blind Fold', Icons.visibility_off_rounded, 'Spatial',
            GameCategory.focus, () => const BlindFoldChallengeGame()),
        _GameEntry('Odd One Out', Icons.filter_center_focus_rounded,
            'Perception', GameCategory.focus, () => const OddOneOutGame()),
        _GameEntry('Visual Search', Icons.visibility_rounded, 'Attention',
            GameCategory.focus, () => const VisualSearchGame()),
        _GameEntry('Thought Watch', Icons.psychology_rounded, 'Vipassana',
            GameCategory.focus, () => const ThoughtWatchGame()),
        _GameEntry('Japa Counter', Icons.repeat_rounded, 'Mantra',
            GameCategory.focus, () => const MantraJapaGame()),
        _GameEntry('Trataka', Icons.remove_red_eye_rounded, 'Gaze',
            GameCategory.focus, () => const TratakaGame()),
        _GameEntry('Aum Vibration', Icons.graphic_eq_rounded, 'Chant',
            GameCategory.focus, () => const AumVibrationGame()),
        _GameEntry('5 Senses', Icons.spa_rounded, 'Imagination',
            GameCategory.focus, () => const FiveSensesGame()),
        _GameEntry('Fist Clench', Icons.sports_mma_rounded, 'Neurobic',
            GameCategory.focus, () => const FistClenchGame()),
        _GameEntry('New Thing', Icons.eco_rounded, 'Growth', GameCategory.focus,
            () => const NewThingDailyGame()),
        _GameEntry('Stop Tech', Icons.phonelink_erase_rounded, 'Detox',
            GameCategory.focus, () => const StopTechGame()),
        _GameEntry('Self Control', Icons.spa_outlined, 'Willpower',
            GameCategory.focus, () => const SelfControlGame()),
        // Logic
        _GameEntry('Quick Math', Icons.calculate_rounded, 'Calculation',
            GameCategory.logic, () => const QuickMathGame()),
        _GameEntry('2048', Icons.grid_4x4_rounded, 'Merge Puzzle',
            GameCategory.logic, () => const Game2048()),
        _GameEntry('Sudoku', Icons.apps_rounded, 'Classic', GameCategory.logic,
            () => const SudokuGame()),
        _GameEntry('Wordle', Icons.abc_rounded, 'Word Puzzle',
            GameCategory.logic, () => const WordleGame()),
        _GameEntry('Block Puzzle', Icons.dashboard_rounded, 'Spatial',
            GameCategory.logic, () => const BlockPuzzleGame()),
        _GameEntry('Flow Free', Icons.timeline_rounded, 'Path',
            GameCategory.logic, () => const FlowFreeGame()),
        _GameEntry('Num Sequence', Icons.trending_up_rounded, 'Pattern',
            GameCategory.logic, () => const NumberSequenceGame()),
        _GameEntry('Word Scramble', Icons.shuffle_rounded, 'Verbal',
            GameCategory.logic, () => const WordScrambleGame()),
        _GameEntry('Tile Match', Icons.extension_rounded, 'Visual',
            GameCategory.logic, () => const TileMatchGame()),
        _GameEntry('Daily Trivia', Icons.quiz_rounded, 'Knowledge',
            GameCategory.logic, () => const DailyTriviaGame()),
        _GameEntry('Guna Balance', Icons.balance_rounded, 'Philosophy',
            GameCategory.logic, () => const GunaBalanceGame()),
        _GameEntry('Mandala Mirror', Icons.flip_rounded, 'Symmetry',
            GameCategory.logic, () => const MandalaMirrorGame()),
      ];

  List<_GameEntry> get _filteredGames {
    var games = _filter == GameCategory.all
        ? _allGames
        : _allGames.where((g) => g.category == _filter).toList();
    if (_searchQuery.isNotEmpty) {
      games = games
          .where((g) =>
              g.name.toLowerCase().contains(_searchQuery) ||
              g.subtitle.toLowerCase().contains(_searchQuery) ||
              _categoryLabel(g.category).toLowerCase().contains(_searchQuery))
          .toList();
    }
    return games;
  }

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
                    _buildSearchBar(context),
                    SizedBox(height: 2.h),
                    _buildBadgesRow(context),
                    SizedBox(height: 2.5.h),
                    _buildWeeklySummary(context),
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
        icon: Icon(Icons.arrow_back_rounded,
            color: GameTheme.textPrimary(context)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.psychology_rounded,
              color: GameTheme.primary(context), size: 22),
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

  // ═══ STATS ROW — Brain Age Gauge + Animated Badges ═══
  Widget _buildStatsRow(BuildContext ctx) {
    final level = MindGamesService.levelForXp(_xp);
    final progress = MindGamesService.levelProgress(_xp);
    return Column(
      children: [
        Row(
          children: [
            // Brain Age Circular Gauge
            _buildBrainAgeGauge(ctx),
            SizedBox(width: 4.w),
            // Streak + Level badges stacked
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _statBadge(ctx,
                            icon: Icons.local_fire_department_rounded,
                            color: const Color(0xFFFF8F00),
                            value: '$_streak',
                            label: _streak == 1 ? 'day streak' : 'day streak'),
                      ),
                      SizedBox(width: 2.5.w),
                      Expanded(
                        child: _statBadge(ctx,
                            icon: Icons.emoji_events_rounded,
                            color: GameTheme.primary(ctx),
                            value: 'Lv $level',
                            label: '$_xp XP'),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.2.h),
                  // XP Progress bar
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
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
                            Text(
                                '${MindGamesService.xpToNextLevel(_xp)} XP to Lv ${level + 1}',
                                style: TextStyle(
                                    fontSize: 12.sp,
                                    color: GameTheme.textMuted(ctx))),
                          ],
                        ),
                        SizedBox(height: 0.6.h),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: progress),
                            duration: const Duration(milliseconds: 1000),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, __) => ShaderMask(
                              shaderCallback: (bounds) =>
                                  GameTheme.xpGradient().createShader(bounds),
                              child: LinearProgressIndicator(
                                value: v,
                                minHeight: 7,
                                backgroundColor: GameTheme.primary(ctx)
                                    .withValues(alpha: 0.08),
                                valueColor:
                                    const AlwaysStoppedAnimation(Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ═══ BRAIN AGE CIRCULAR GAUGE ═══
  Widget _buildBrainAgeGauge(BuildContext ctx) {
    // Brain age 25 (best) to 50 (worst) → map to 0.0-1.0 progress
    final gaugeProgress = (1.0 - ((_brainAge - 20) / 35.0)).clamp(0.0, 1.0);
    final gaugeColor = _brainAge <= 28
        ? GameColors.successGreen
        : _brainAge <= 35
            ? GameColors.mediumAmber
            : GameColors.errorRed;

    return SizedBox(
      width: 26.w,
      height: 26.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring
          SizedBox(
            width: 26.w,
            height: 26.w,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 5,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation(
                GameTheme.primary(ctx).withValues(alpha: 0.08),
              ),
            ),
          ),
          // Animated progress ring
          SizedBox(
            width: 26.w,
            height: 26.w,
            child: AnimatedBuilder(
              animation: _gaugeCtrl,
              builder: (_, __) => CircularProgressIndicator(
                value: gaugeProgress * _gaugeCtrl.value,
                strokeWidth: 5,
                strokeCap: StrokeCap.round,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation(gaugeColor),
              ),
            ),
          ),
          // Center content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.psychology_alt_rounded,
                  color: gaugeColor, size: 18.sp),
              SizedBox(height: 0.3.h),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 30, end: _brainAge),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => Text(
                  '$v',
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w900,
                    color: GameTheme.textPrimary(ctx),
                  ),
                ),
              ),
              Text(
                'brain age',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: GameTheme.textSecondary(ctx),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
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
                    fontSize: 12.sp, color: GameTheme.textSecondary(ctx)),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // ═══ DAILY CHALLENGE HERO with countdown ═══
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
              Container(
                padding: EdgeInsets.all(1.5.w),
                decoration: BoxDecoration(
                  color: GameTheme.primary(ctx).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.wb_sunny_rounded,
                    size: 15.sp, color: GameTheme.primary(ctx)),
              ),
              SizedBox(width: 2.w),
              Text('DAILY CHALLENGE',
                  style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: GameTheme.primary(ctx))),
              const Spacer(),
              // Countdown timer
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: GameColors.errorRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: GameColors.errorRed.withValues(alpha: 0.2),
                      width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_outlined,
                        size: 12.sp, color: GameColors.errorRed),
                    SizedBox(width: 1.w),
                    Text(_dailyCountdown,
                        style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: GameColors.errorRed,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ])),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Row(
            children: [
              Container(
                width: 15.w,
                height: 15.w,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      catColor.withValues(alpha: 0.2),
                      catColor.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: catColor.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: catColor.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(game.icon, color: catColor, size: 28.sp),
              ),
              SizedBox(width: 3.5.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(game.name,
                        style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w800,
                            color: GameTheme.textPrimary(ctx))),
                    SizedBox(height: 0.4.h),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 2.w, vertical: 0.3.h),
                          decoration: GameTheme.categoryBadge(ctx, catColor),
                          child: Text(game.subtitle,
                              style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: catColor)),
                        ),
                        SizedBox(width: 2.w),
                        Text('+30 XP',
                            style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                color: GameColors.gold)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _openGame(game.builder()),
                child: Ink(
                  decoration: GameTheme.gradientButton(ctx),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded,
                            size: 20,
                            color: Theme.of(ctx).colorScheme.onPrimary),
                        SizedBox(width: 2.w),
                        Text('Play Now',
                            style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(ctx).colorScheme.onPrimary,
                                letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══ SEARCH BAR ═══
  Widget _buildSearchBar(BuildContext ctx) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: GameTheme.isDark(ctx) ? const Color(0xFF2A2015) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: GameTheme.primary(ctx)
              .withValues(alpha: _searchQuery.isNotEmpty ? 0.4 : 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
        style: TextStyle(fontSize: 14.sp, color: GameTheme.textPrimary(ctx)),
        decoration: InputDecoration(
          hintText: 'Search 41 mind games...',
          hintStyle:
              TextStyle(color: GameTheme.textMuted(ctx), fontSize: 13.sp),
          prefixIcon: Icon(Icons.search_rounded,
              color: GameTheme.textSecondary(ctx), size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: 18, color: GameTheme.textMuted(ctx)),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  // ═══ BADGES ROW — Horizontal scrollable earned badges ═══
  Widget _buildBadgesRow(BuildContext ctx) {
    final totalBadges = MindGamesService.allBadges.length;
    final earnedCount = _earnedBadges.length;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          ctx,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const AchievementsScreen(),
            transitionsBuilder: (_, anim, __, child) => FadeTransition(
              opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
              child: child,
            ),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 1.5.h),
        decoration: GameTheme.card(ctx),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.workspace_premium_rounded,
                    size: 16.sp, color: GameColors.gold),
                SizedBox(width: 2.w),
                Text('Achievements',
                    style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: GameTheme.textPrimary(ctx))),
                const Spacer(),
                Text('$earnedCount/$totalBadges',
                    style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: GameColors.gold)),
                SizedBox(width: 1.w),
                Icon(Icons.chevron_right_rounded,
                    size: 16.sp, color: GameTheme.textMuted(ctx)),
              ],
            ),
            SizedBox(height: 1.2.h),
            if (_earnedBadges.isEmpty)
              Text('Play games to earn badges!',
                  style: TextStyle(
                      fontSize: 12.sp, color: GameTheme.textMuted(ctx)))
            else
              SizedBox(
                height: 5.h,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _earnedBadges.length,
                  separatorBuilder: (_, __) => SizedBox(width: 2.w),
                  itemBuilder: (_, i) {
                    final badge = _earnedBadges[i];
                    return Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 3.w, vertical: 0.8.h),
                      decoration: BoxDecoration(
                        color: GameColors.gold.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: GameColors.gold.withValues(alpha: 0.25),
                            width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(badge.emoji, style: TextStyle(fontSize: 14.sp)),
                          SizedBox(width: 1.5.w),
                          Text(badge.name,
                              style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: GameTheme.textPrimary(ctx))),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══ WEEKLY SUMMARY — 7-day activity dots ═══
  Widget _buildWeeklySummary(BuildContext ctx) {
    final today = DateTime.now();
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final activeDays = _streak > 0
        ? (_streak > 7 ? 7 : _streak)
        : (_playedToday.isNotEmpty ? 1 : 0);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.8.h),
      decoration: GameTheme.card(ctx),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_view_week_rounded,
                  size: 15.sp, color: GameTheme.primary(ctx)),
              SizedBox(width: 2.w),
              Text('This Week',
                  style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: GameTheme.textPrimary(ctx))),
              const Spacer(),
              Text('$activeDays/7 days',
                  style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: activeDays >= 5
                          ? GameColors.successGreen
                          : GameTheme.textSecondary(ctx))),
            ],
          ),
          SizedBox(height: 1.5.h),
          // 7-day activity dots
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final isActive = i < activeDays;
              final isToday = i == (today.weekday - 1);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: isToday ? 9.w : 8.w,
                    height: isToday ? 9.w : 8.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? GameTheme.primary(ctx).withValues(alpha: 0.2)
                          : GameTheme.primary(ctx).withValues(alpha: 0.04),
                      border: Border.all(
                        color: isToday
                            ? GameTheme.accent(ctx).withValues(alpha: 0.6)
                            : isActive
                                ? GameTheme.primary(ctx).withValues(alpha: 0.3)
                                : GameTheme.primary(ctx)
                                    .withValues(alpha: 0.08),
                        width: isToday ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: isActive
                          ? Icon(Icons.check_rounded,
                              size: 12.sp, color: GameTheme.primary(ctx))
                          : null,
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(days[i],
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                        color: isToday
                            ? GameTheme.accent(ctx)
                            : GameTheme.textMuted(ctx),
                      )),
                ],
              );
            }),
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
                          color: sel ? color : GameTheme.textSecondary(ctx))),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded,
                  size: 40.sp, color: GameTheme.textMuted(ctx)),
              SizedBox(height: 1.5.h),
              Text('No games found',
                  style: TextStyle(
                      color: GameTheme.textMuted(ctx),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600)),
              SizedBox(height: 0.5.h),
              Text('Try a different search or category',
                  style: TextStyle(
                      color: GameTheme.textMuted(ctx), fontSize: 12.sp)),
            ],
          ),
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
        childAspectRatio: 0.82,
      ),
      itemCount: games.length,
      itemBuilder: (_, index) => _GameTile(
        game: games[index],
        color: _categoryColor(games[index].category),
        index: index,
        bestScore:
            _bestScores[games[index].name.toLowerCase().replaceAll(' ', '_')],
        playedToday: _playedToday
            .contains(games[index].name.toLowerCase().replaceAll(' ', '_')),
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
          gradient: GameTheme.animatedGradient(ctx, opacity: 0.06),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: GameTheme.primary(ctx).withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Icon(Icons.spa_rounded, color: GameTheme.primary(ctx), size: 24.sp),
            SizedBox(height: 1.h),
            Text('Train daily · 41 games · 4 categories',
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
            SizedBox(height: 1.h),
            // Longest streak badge
            if (_longestStreak > 0)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.6.h),
                decoration: BoxDecoration(
                  color: GameColors.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: GameColors.gold.withValues(alpha: 0.25),
                      width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.workspace_premium_rounded,
                        size: 14.sp, color: GameColors.gold),
                    SizedBox(width: 1.5.w),
                    Text('Best streak: $_longestStreak days',
                        style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: GameTheme.textSecondary(ctx))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══ GAME TILE — Premium card with best score, played indicator, difficulty ═══
class _GameTile extends StatefulWidget {
  final _GameEntry game;
  final Color color;
  final int index;
  final double? bestScore;
  final bool playedToday;
  final VoidCallback onTap;
  const _GameTile({
    required this.game,
    required this.color,
    required this.index,
    this.bestScore,
    this.playedToday = false,
    required this.onTap,
  });
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
    // Cap stagger animation to first 12 visible items
    final delay = widget.index < 12 ? 40 * widget.index : 0;
    Future.delayed(Duration(milliseconds: delay), () {
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
          scale: _pressed ? 0.93 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            decoration:
                GameTheme.elevatedCard(context, accentColor: widget.color),
            padding: EdgeInsets.all(2.w),
            child: Stack(
              children: [
                // Played today checkmark (top-right)
                if (widget.playedToday)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 5.w,
                      height: 5.w,
                      decoration: BoxDecoration(
                        color: GameColors.successGreen,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                GameColors.successGreen.withValues(alpha: 0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(Icons.check_rounded,
                          size: 10.sp, color: Colors.white),
                    ),
                  ),
                // Main content
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon with category color background
                    Container(
                      width: 14.w,
                      height: 14.w,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            widget.color.withValues(alpha: 0.18),
                            widget.color.withValues(alpha: 0.06),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: widget.color.withValues(alpha: 0.2),
                            width: 0.5),
                      ),
                      child: Icon(widget.game.icon,
                          color: widget.color, size: 28.sp),
                    ),
                    SizedBox(height: 0.8.h),
                    Text(widget.game.name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: GameTheme.textPrimary(context))),
                    SizedBox(height: 0.2.h),
                    // Best score or subtitle
                    if (widget.bestScore != null && widget.bestScore! > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.emoji_events_rounded,
                              size: 10.sp, color: GameColors.gold),
                          SizedBox(width: 1.w),
                          Text('${widget.bestScore!.round()}',
                              style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                  color: GameColors.gold)),
                        ],
                      )
                    else
                      Text(widget.game.subtitle,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11.sp,
                              color: GameTheme.textSecondary(context))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
