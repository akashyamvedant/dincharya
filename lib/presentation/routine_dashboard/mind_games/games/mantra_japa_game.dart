import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class MantraJapaGame extends StatefulWidget {
  const MantraJapaGame({super.key});
  @override
  State<MantraJapaGame> createState() => _MantraJapaGameState();
}

class _MantraJapaGameState extends State<MantraJapaGame> {
  final _service = MindGamesService();

  static const _target = 108;

  int _count = 0;
  bool _started = false;
  bool _showingCountdown = false;
  bool _isDone = false;
  bool _isNewBest = false;
  Stopwatch? _sw;
  Timer? _resetTimer;

  // Tap rhythm tracking
  final List<int> _intervals = [];
  DateTime? _lastTapTime;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  void _startGame() {
    _count = 0;
    _intervals.clear();
    _lastTapTime = null;
    _isDone = false;
    _isNewBest = false;
    _sw = Stopwatch();
    setState(() {
      _showingCountdown = true;
    });
  }

  void _onCountdownDone() {
    _sw?.start();
    setState(() {
      _showingCountdown = false;
      _started = true;
    });
    _startResetTimer();
  }

  void _startResetTimer() {
    // If no tap for 3 seconds, auto-finish
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _started && !_isDone) {
        _finishGame();
      }
    });
  }

  void _tapCounter() {
    if (!_started || _isDone) {
      return;
    }

    final now = DateTime.now();
    if (_lastTapTime != null) {
      _intervals.add(
          now.difference(_lastTapTime!).inMilliseconds);
    }
    _lastTapTime = now;

    setState(() {
      _count++;
    });
    GameHaptics.tap();
    _startResetTimer();

    if (_count >= _target) {
      _finishGame();
    }
  }

  void _resetCounter() {
    if (!_started || _isDone) {
      return;
    }
    setState(() {
      _count = 0;
      _intervals.clear();
      _lastTapTime = null;
    });
  }

  double _rhythmScore() {
    if (_intervals.length < 3) {
      return 0.0;
    }
    final avg = _intervals.reduce((a, b) => a + b) /
        _intervals.length;
    double variance = 0.0;
    for (final iv in _intervals) {
      variance += (iv - avg) * (iv - avg);
    }
    variance /= _intervals.length;
    final stdDev = sqrt(variance);
    // Lower std dev relative to avg = better rhythm
    return (1.0 - (stdDev / avg).clamp(0.0, 1.0));
  }

  Future<void> _finishGame() async {
    _resetTimer?.cancel();
    _sw?.stop();
    _isDone = true;
    _started = false;

    final timeMs = _sw?.elapsedMilliseconds ?? 0;
    final completion = (_count / _target).clamp(0.0, 1.0);
    final rhythm = _rhythmScore();
    final finalScore =
        ((completion * 500) + (rhythm * 500))
            .clamp(0.0, 1000.0);

    await _service.saveScore(
      gameType: 'mantra_japa',
      score: finalScore,
      accuracy: completion,
      reactionTimeMs: timeMs,
      roundsCompleted: _count,
      metadata: {
        'target': _target,
        'count': _count,
        'rhythm': rhythm,
      },
    );
    _isNewBest =
        await _service.submitLocalBest('mantra_japa', finalScore);
    await _service.addXp(
        5 + (completion * 20.0).round());
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameTheme.bg(context),
      appBar: _started
          ? null
          : AppBar(
              backgroundColor: GameTheme.bg(context),
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_rounded,
                    color: GameTheme.textPrimary(context)),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Japa Counter',
                style: TextStyle(
                  color: GameTheme.textPrimary(context),
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
            ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (!_started && !_isDone && !_showingCountdown) {
      return _startScreen(context);
    }
    if (_showingCountdown) {
      return GameCountdown(onDone: _onCountdownDone);
    }
    if (_isDone) {
      return _resultScreen(context);
    }
    return _counterScreen(context);
  }

  Widget _startScreen(BuildContext ctx) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(6.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📿', style: TextStyle(fontSize: 54.sp)),
            SizedBox(height: 3.h),
            Text('Mantra Japa',
                style: GameTheme.heading(ctx, size: 26)),
            SizedBox(height: 2.h),
            Text(
              'Tap for each mantra repetition.\nAim for $_target (one mala).\nSteady rhythm = higher score.\nChant your favorite mantra!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: GameTheme.textSecondary(ctx),
                fontSize: 14.sp,
                height: 1.5,
              ),
            ),
            SizedBox(height: 4.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GameTheme.primary(ctx),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 1.6.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Start Japa',
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _counterScreen(BuildContext ctx) {
    final progress = (_count / _target).clamp(0.0, 1.0);
    final malaRound = _count ~/ _target;
    final remaining =
        _target - (_count % _target);

    return GestureDetector(
      onTap: _tapCounter,
      behavior: HitTestBehavior.translucent,
      child: Container(
        color: GameTheme.bg(ctx),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '🕉️',
                style: TextStyle(fontSize: 32.sp),
              ),
              SizedBox(height: 2.h),
              // Progress ring
              SizedBox(
                width: 55.w,
                height: 55.w,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 6,
                      backgroundColor: GameTheme
                          .primary(ctx)
                          .withValues(alpha: 0.1),
                      color: GameTheme.accent(ctx),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$_count',
                          style: TextStyle(
                            fontSize: 40.sp,
                            fontWeight: FontWeight.bold,
                            color: GameTheme
                                .textPrimary(ctx),
                          ),
                        ),
                        Text(
                          '/ $_target',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: GameTheme
                                .textMuted(ctx),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 3.h),
              Text(
                'Tap to count each chant',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: GameTheme.textSecondary(ctx),
                ),
              ),
              SizedBox(height: 1.5.h),
              if (_count > 0)
                Text(
                  '$remaining to next mala round',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: GameTheme.textMuted(ctx),
                  ),
                ),
              if (malaRound > 0)
                Padding(
                  padding: EdgeInsets.only(top: 1.h),
                  child: Text(
                    'Round $malaRound complete',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: GameColors.gold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              SizedBox(height: 4.h),
              TextButton(
                onPressed: _resetCounter,
                child: Text(
                  'Reset Counter',
                  style: TextStyle(
                    color: GameTheme.textMuted(ctx),
                    fontSize: 13.sp,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultScreen(BuildContext ctx) {
    final timeMs = _sw?.elapsedMilliseconds ?? 0;
    final completion =
        (_count / _target).clamp(0.0, 1.0);
    final rhythm = _rhythmScore();
    String insight;
    if (completion >= 0.95 && rhythm >= 0.8) {
      insight = 'Perfect Japa!';
    } else if (completion >= 0.7) {
      insight = 'Good practice!';
    } else {
      insight = 'Keep chanting...';
    }

    return GameResultsScreen(
      gameIcon: '📿',
      title: insight,
      performance: completion,
      score: ((completion * 500) + (rhythm * 500))
          .clamp(0.0, 1000.0)
          .round(),
      scoreLabel: 'Japa Score',
      isNewBest: _isNewBest,
      stats: [
        GameResultStat('Count', '$_count/$_target'),
        GameResultStat(
            'Time', '${(timeMs / 1000).round()}s'),
        GameResultStat(
            'Rhythm', '${(rhythm * 100).round()}%'),
      ],
      onRetry: _startGame,
      onDone: () => Navigator.pop(context),
    );
  }
}
