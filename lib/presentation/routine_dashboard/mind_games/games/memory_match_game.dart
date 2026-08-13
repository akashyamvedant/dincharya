// lib/presentation/routine_dashboard/mind_games/games/memory_match_game.dart
// PREMIUM v3 — Memory Card Match. Flip two, find matching pairs.
// Animated card flips, sound effects, level progression, premium results.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../game_sfx_service.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class MemoryMatchGame extends StatefulWidget {
  const MemoryMatchGame({super.key});
  @override
  State<MemoryMatchGame> createState() => _MemoryMatchGameState();
}

enum _Phase { start, countdown, playing, results }

class _MemoryMatchGameState extends State<MemoryMatchGame>
    with SingleTickerProviderStateMixin {
  final _rng = Random(), _svc = MindGamesService();
  final _sfx = GameSfxService();
  static const _icons = [
    '🧘',
    '🕉️',
    '🌿',
    '🌸',
    '☀️',
    '🌙',
    '🔥',
    '💧',
    '🪷',
    '🕊️',
    '🍃',
    '✨'
  ];

  int _level = 6, _moves = 0, _found = 0, _totalMs = 0;
  List<String> _cards = [];
  List<bool> _flipped = [], _matched = [];
  int? _first, _second;
  bool _lock = false;
  _Phase _phase = _Phase.start;
  final _sw = Stopwatch();
  bool _isNewBest = false;
  int _xpEarned = 0;

  void _start() {
    final pool = _icons.take(_level).toList();
    _cards = [...pool, ...pool]..shuffle(_rng);
    _flipped = List.filled(_cards.length, false);
    _matched = List.filled(_cards.length, false);
    setState(() {
      _moves = 0;
      _found = 0;
      _first = null;
      _second = null;
      _lock = false;
      _isNewBest = false;
      _xpEarned = 0;
      _phase = _Phase.countdown;
      _sw
        ..reset()
        ..start();
    });
  }

  void _tap(int i) {
    if (_phase != _Phase.playing || _lock || _flipped[i] || _matched[i]) return;
    GameHaptics.tap();
    setState(() => _flipped[i] = true);
    if (_first == null) {
      _first = i;
      return;
    }
    _second = i;
    _moves++;
    _lock = true;
    if (_cards[_first!] == _cards[_second!]) {
      // Match found!
      GameHaptics.correct();
      _sfx.playCorrect();
      setState(() {
        _matched[_first!] = true;
        _matched[_second!] = true;
        _found++;
      });
      _resetSelection();
    } else {
      // No match
      GameHaptics.wrong();
      _sfx.playWrong();
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) {
          setState(() {
            _flipped[_first!] = false;
            _flipped[_second!] = false;
            _resetSelection();
          });
        }
      });
    }
  }

  void _resetSelection() {
    _first = null;
    _second = null;
    _lock = false;
    if (_found >= _level) _finish();
    setState(() {});
  }

  Future<void> _finish() async {
    _sw.stop();
    _totalMs = _sw.elapsedMilliseconds;
    setState(() => _phase = _Phase.results);
    GameHaptics.win();
    _sfx.playWin();

    final efficiency = _level / _moves; // 1.0 = perfect (no misses)
    final score = (_level * 10.0) - ((_moves - _level) * 0.5);
    _xpEarned = 10 +
        (efficiency > 0.8
            ? 15
            : efficiency > 0.6
                ? 10
                : 5) +
        (_level >= 10 ? 10 : 0);

    await _svc.saveScore(
      gameType: 'memory_match',
      score: score.clamp(0.0, 100.0),
      accuracy: efficiency,
      reactionTimeMs: _totalMs,
      roundsCompleted: _found,
    );
    _isNewBest =
        await _svc.submitLocalBest('memory_match', score.clamp(0.0, 100.0));
    await _svc.addXp(_xpEarned);
    if (_isNewBest) _sfx.playNewBest();
    if (mounted) setState(() {});
  }

  int _cols() => _cards.length <= 12
      ? 4
      : _cards.length <= 16
          ? 4
          : 5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameTheme.bg(context),
      appBar: AppBar(
        backgroundColor: GameTheme.bg(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: GameTheme.textPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🃏', style: TextStyle(fontSize: 16.sp)),
            SizedBox(width: 2.w),
            Text('Memory Match',
                style: TextStyle(
                    color: GameTheme.textPrimary(context),
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        centerTitle: true,
      ),
      body: Stack(children: [
        if (_phase == _Phase.start) _startScreen(context),
        if (_phase == _Phase.countdown)
          GameCountdown(onDone: () => setState(() => _phase = _Phase.playing)),
        if (_phase == _Phase.playing) _gameScreen(context),
        if (_phase == _Phase.results) _resultScreen(context),
      ]),
    );
  }

  Widget _startScreen(BuildContext ctx) => GameStartScreen(
        icon: '🃏',
        title: 'Memory Card Match',
        description:
            'Flip cards to find matching pairs.\nFewer moves = better memory!\n\n$_level pairs · ${_level * 2} cards · 3 levels',
        buttonLabel: 'Start Matching',
        preview: Container(
          padding: EdgeInsets.all(4.w),
          decoration: GameTheme.card(ctx),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _previewCard(ctx, '🧘', true),
              SizedBox(width: 2.w),
              _previewCard(ctx, '?', false),
              SizedBox(width: 2.w),
              _previewCard(ctx, '🧘', true),
              SizedBox(width: 2.w),
              _previewCard(ctx, '?', false),
            ],
          ),
        ),
        onStart: _start,
      );

  Widget _previewCard(BuildContext ctx, String content, bool revealed) {
    return Container(
      width: 12.w,
      height: 14.w,
      decoration: BoxDecoration(
        color: revealed
            ? GameTheme.primary(ctx).withValues(alpha: 0.1)
            : GameTheme.primary(ctx).withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: revealed
              ? GameColors.successGreen.withValues(alpha: 0.4)
              : GameTheme.primary(ctx).withValues(alpha: 0.2),
        ),
      ),
      child: Center(
          child: Text(content,
              style: TextStyle(
                  fontSize: 18.sp,
                  color: revealed ? null : GameTheme.textMuted(ctx)))),
    );
  }

  Widget _gameScreen(BuildContext ctx) => Padding(
        padding: EdgeInsets.all(3.w),
        child: Column(children: [
          // Stats row
          Padding(
            padding: EdgeInsets.symmetric(vertical: 1.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _statChip(ctx, Icons.swap_horiz_rounded, '$_moves', 'Moves'),
                SizedBox(width: 3.w),
                _statChip(ctx, Icons.check_circle_rounded, '$_found/$_level',
                    'Pairs'),
                SizedBox(width: 3.w),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.6.h),
                  decoration: BoxDecoration(
                    color: GameColors.gold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: GameColors.gold.withValues(alpha: 0.2),
                        width: 0.5),
                  ),
                  child: Text('Lv ${(_level - 4) ~/ 2}',
                      style: TextStyle(
                          color: GameColors.gold,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          // Progress
          GameProgressBar(current: _found, total: _level, showLabel: false),
          SizedBox(height: 2.h),
          // Card grid
          Expanded(
            child: GridView.count(
              crossAxisCount: _cols(),
              childAspectRatio: 0.85,
              mainAxisSpacing: 2.w,
              crossAxisSpacing: 2.w,
              children: List.generate(_cards.length, (i) {
                final show = _flipped[i] || _matched[i];
                final isMatched = _matched[i];
                return GestureDetector(
                  onTap: () => _tap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    decoration: BoxDecoration(
                      color: isMatched
                          ? GameColors.successGreen.withValues(alpha: 0.1)
                          : show
                              ? GameTheme.primary(ctx).withValues(alpha: 0.08)
                              : (GameTheme.isDark(ctx)
                                  ? const Color(0xFF2E2218)
                                  : Colors.white),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isMatched
                            ? GameColors.successGreen.withValues(alpha: 0.5)
                            : show
                                ? GameTheme.primary(ctx).withValues(alpha: 0.3)
                                : GameTheme.primary(ctx)
                                    .withValues(alpha: 0.12),
                        width: isMatched ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: show ? 0.02 : 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: show
                            ? Text(_cards[i],
                                key: ValueKey('show_$i'),
                                style: TextStyle(fontSize: 26.sp))
                            : Icon(Icons.help_outline_rounded,
                                key: ValueKey('hide_$i'),
                                size: 20.sp,
                                color: GameTheme.textMuted(ctx)),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ]),
      );

  Widget _statChip(
      BuildContext ctx, IconData icon, String value, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.6.h),
      decoration: BoxDecoration(
        color: GameTheme.primary(ctx).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: GameTheme.primary(ctx).withValues(alpha: 0.12), width: 0.5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13.sp, color: GameTheme.textSecondary(ctx)),
        SizedBox(width: 1.5.w),
        Text(value,
            style: TextStyle(
                color: GameTheme.textPrimary(ctx),
                fontSize: 13.sp,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _resultScreen(BuildContext ctx) {
    final efficiency = _moves > 0 ? (_level / _moves * 100).round() : 0;
    final performance = (_level / _moves).clamp(0.0, 1.0);
    final timeStr = '${_totalMs ~/ 1000}s';

    return GameResultsScreen(
      gameIcon: _level >= 10 ? '🏆' : '🃏',
      title: _level >= 10 ? 'All Levels Complete!' : 'Level Complete!',
      performance: performance,
      score:
          ((_level * 10.0) - ((_moves - _level) * 0.5)).clamp(0, 100).round(),
      scoreLabel: 'Score',
      xpEarned: _xpEarned,
      isNewBest: _isNewBest,
      stats: [
        GameResultStat('Moves', '$_moves'),
        GameResultStat('Efficiency', '$efficiency%'),
        GameResultStat('Time', timeStr),
      ],
      onRetry: _start,
      onDone: () => Navigator.pop(context),
    );
  }
}
