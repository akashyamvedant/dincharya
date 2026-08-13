// lib/presentation/routine_dashboard/mind_games/games/stroop_test_game.dart
// Stroop Color-Word Test (Stroop, 1935). Premium UI v3.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../game_sfx_service.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class StroopTestGame extends StatefulWidget {
  const StroopTestGame({super.key});
  @override
  State<StroopTestGame> createState() => _StroopTestGameState();
}

enum _Phase { start, countdown, playing, results }

class _StroopTestGameState extends State<StroopTestGame> {
  final _rng = Random(), _service = MindGamesService();
  final _sfx = GameSfxService();
  static const _total = 20, _choices = 4;

  int _idx = 0, _correct = 0, _wrong = 0;
  final List<int> _rts = [];
  String _word = '';
  Color _inkColor = Colors.black;
  List<Color> _choiceColors = [];
  DateTime? _start;
  _Phase _phase = _Phase.start;
  bool _isNewBest = false;
  int _xpEarned = 0;
  int _lastTapCorrect = -1; // For flash feedback
  int _combo = 0; // Consecutive correct answers

  @override
  void initState() {
    super.initState();
    _genRound();
  }

  void _genRound() {
    final wi = _rng.nextInt(GameColors.stroop.length);
    int ii;
    do {
      ii = _rng.nextInt(GameColors.stroop.length);
    } while (ii == wi && GameColors.stroop.length > 1);
    _word = GameColors.stroopNames[wi];
    _inkColor = GameColors.stroop[ii];
    _choiceColors = [_inkColor];
    while (_choiceColors.length < _choices) {
      final c = GameColors.stroop[_rng.nextInt(GameColors.stroop.length)];
      if (!_choiceColors.contains(c)) _choiceColors.add(c);
    }
    _choiceColors.shuffle(_rng);
    _start = DateTime.now();
  }

  void _tap(Color c) {
    if (_phase != _Phase.playing) return;
    final rt = DateTime.now().difference(_start!).inMilliseconds;
    _rts.add(rt);
    final isCorrect = c == _inkColor;
    if (isCorrect) {
      _correct++;
      _combo++;
      GameHaptics.correct();
      _sfx.playCorrect();
    } else {
      _wrong++;
      _combo = 0;
      GameHaptics.wrong();
      _sfx.playWrong();
    }
    _lastTapCorrect = isCorrect ? 1 : 0;
    _idx++;
    if (_idx >= _total) {
      _finish();
      return;
    }
    _genRound();
    setState(() {});
    // Reset flash after brief delay
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _lastTapCorrect = -1);
    });
  }

  Future<void> _finish() async {
    setState(() => _phase = _Phase.results);
    GameHaptics.win();
    _sfx.playWin();

    final acc = _correct / _total;
    final avgRT =
        _rts.isNotEmpty ? _rts.reduce((a, b) => a + b) / _rts.length : 0.0;
    final score = ((_correct - _wrong * 0.5) / _total * 100).clamp(0.0, 100.0);
    _xpEarned = 10 + (acc * 20).round() + (avgRT < 800 ? 5 : 0);

    await _service.saveScore(
      gameType: 'stroop',
      score: score,
      accuracy: acc,
      reactionTimeMs: avgRT.round(),
      roundsCompleted: _total,
    );
    _isNewBest = await _service.submitLocalBest('stroop', score);
    await _service.addXp(_xpEarned);
    if (_isNewBest) _sfx.playNewBest();
    if (mounted) setState(() {});
  }

  void _startGame() {
    setState(() {
      _phase = _Phase.countdown;
      _idx = 0;
      _correct = 0;
      _wrong = 0;
      _rts.clear();
      _isNewBest = false;
      _xpEarned = 0;
      _combo = 0;
      _genRound();
    });
  }

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
            Text('🎨', style: TextStyle(fontSize: 16.sp)),
            SizedBox(width: 2.w),
            Text('Stroop Color Test',
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
        icon: '🎨',
        title: 'Stroop Color Test',
        description:
            'A color word appears in a different ink color.\nTap the INK color, not the word!\n\n20 rounds · Tests cognitive inhibition',
        buttonLabel: 'Start Test',
        preview: Container(
          padding: EdgeInsets.all(4.w),
          decoration: GameTheme.card(ctx),
          child: Column(children: [
            Text('BLUE',
                style: TextStyle(
                    color: Colors.red,
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w900)),
            SizedBox(height: 1.h),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.arrow_downward_rounded,
                  size: 16.sp, color: GameColors.chakraRed),
              SizedBox(width: 2.w),
              Text('Tap RED (the ink color)',
                  style: TextStyle(
                      color: GameColors.chakraRed,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
        onStart: _startGame,
      );

  Widget _gameScreen(BuildContext ctx) {
    return Column(children: [
      // Progress bar
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
        child: GameProgressBar(current: _idx + 1, total: _total),
      ),
      // Score indicators + combo
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _scoreChip(ctx, Icons.check_circle_rounded, '$_correct',
                GameColors.successGreen),
            SizedBox(width: 3.w),
            GameComboIndicator(combo: _combo),
            SizedBox(width: 3.w),
            _scoreChip(
                ctx, Icons.cancel_rounded, '$_wrong', GameColors.errorRed),
          ],
        ),
      ),
      // Word display
      Expanded(
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Container(
              key: ValueKey('$_idx'),
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: _inkColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: _inkColor.withValues(alpha: 0.2), width: 1.5),
              ),
              child: Text(
                _word,
                style: TextStyle(
                  color: _inkColor,
                  fontSize: 44.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ),
      ),
      // Choice buttons
      Padding(
        padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 4.h),
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 2.5.w,
          crossAxisSpacing: 2.5.w,
          childAspectRatio: 2.8,
          children: _choiceColors.map((c) {
            final name = GameColors.stroopNames[GameColors.stroop.indexOf(c)];
            return GestureDetector(
              onTap: () => _tap(c),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      c.withValues(alpha: 0.35),
                      c.withValues(alpha: 0.2)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.withValues(alpha: 0.6), width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: c.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: Center(
                  child: Text(
                    name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4)
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ]);
  }

  Widget _scoreChip(
      BuildContext ctx, IconData icon, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: color),
          SizedBox(width: 1.5.w),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 13.sp, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _resultScreen(BuildContext ctx) {
    final acc = (_correct / _total * 100).round();
    final avgRT =
        _rts.isNotEmpty ? _rts.reduce((a, b) => a + b) ~/ _rts.length : 0;
    final performance = (_correct / _total).clamp(0.0, 1.0);

    return GameResultsScreen(
      gameIcon: '🎨',
      title: 'Stroop Test Complete!',
      performance: performance,
      score: ((_correct - _wrong * 0.5) / _total * 100).clamp(0, 100).round(),
      scoreLabel: 'Score',
      xpEarned: _xpEarned,
      isNewBest: _isNewBest,
      stats: [
        GameResultStat('Accuracy', '$acc%'),
        GameResultStat('Avg Speed', '${avgRT}ms'),
        GameResultStat('Correct', '$_correct/$_total'),
      ],
      onRetry: _startGame,
      onDone: () => Navigator.pop(context),
    );
  }
}
