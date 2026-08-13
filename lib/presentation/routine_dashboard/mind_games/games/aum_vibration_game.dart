import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

enum _Phase { inhale, chant, exhale, rest }

class AumVibrationGame extends StatefulWidget {
  const AumVibrationGame({super.key});
  @override
  State<AumVibrationGame> createState() => _AumVibrationGameState();
}

class _AumVibrationGameState extends State<AumVibrationGame>
    with SingleTickerProviderStateMixin {
  final _service = MindGamesService();

  static const _sessionSecs = 60;
  static const _totalRounds = 5;

  int _roundNum = 0;
  int _secondsLeft = 0;
  int _phaseSecs = 0;

  // Phases: inhale(2s) → chant(hold, variable) → exhale(3s) → rest
  _Phase _phase = _Phase.inhale;

  bool _isHolding = false;
  DateTime? _holdStart;
  int _currentHoldMs = 0;
  final List<int> _holdDurations = [];

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  bool _started = false;
  bool _showingCountdown = false;
  bool _isDone = false;
  bool _isNewBest = false;
  Timer? _phaseTimer;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        duration: const Duration(milliseconds: 1500),
        vsync: this);
    _pulseAnim =
        Tween<double>(begin: 1.0, end: 1.5).animate(
            CurvedAnimation(
                parent: _pulseCtrl,
                curve: Curves.easeInOut));
    _pulseCtrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _holdTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _startGame() {
    _roundNum = 0;
    _isDone = false;
    _isNewBest = false;
    _holdDurations.clear();
    setState(() {
      _showingCountdown = true;
    });
  }

  void _onCountdownDone() {
    setState(() {
      _showingCountdown = false;
      _started = true;
    });
    _startRound();
  }

  void _startRound() {
    _secondsLeft = _sessionSecs ~/ _totalRounds;
    _phase = _Phase.inhale;
    _phaseSecs = 2;
    _isHolding = false;
    _currentHoldMs = 0;
    _startPhaseTimer();
  }

  void _startPhaseTimer() {
    _phaseTimer?.cancel();
    _phaseTimer =
        Timer(Duration(seconds: _phaseSecs), () {
      if (!mounted || !_started || _isDone) {
        return;
      }
      _nextPhase();
    });
  }

  void _nextPhase() {
    setState(() {
      switch (_phase) {
        case _Phase.inhale:
          _phase = _Phase.chant;
          _phaseSecs = 8;
          break;
        case _Phase.chant:
          _phase = _Phase.exhale;
          _phaseSecs = 3;
          _isHolding = false;
          _holdTimer?.cancel();
          break;
        case _Phase.exhale:
          _phase = _Phase.rest;
          _phaseSecs = 1;
          break;
        case _Phase.rest:
          _roundNum++;
          if (_roundNum >= _totalRounds) {
            _finishGame();
            return;
          }
          _phase = _Phase.inhale;
          _phaseSecs = 2;
          break;
      }
    });
    _startPhaseTimer();
  }

  void _startHold() {
    if (_phase != _Phase.chant || _isDone) {
      return;
    }
    _holdStart = DateTime.now();
    setState(() {
      _isHolding = true;
    });
    GameHaptics.tap();

    _holdTimer =
        Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted || !_isHolding) {
        t.cancel();
        return;
      }
      setState(() {
        _currentHoldMs =
            DateTime.now()
                .difference(_holdStart!)
                .inMilliseconds;
      });
    });
  }

  void _endHold() {
    if (!_isHolding || _isDone) {
      return;
    }
    _holdTimer?.cancel();
    if (_holdStart != null) {
      _holdDurations.add(_currentHoldMs);
    }
    setState(() {
      _isHolding = false;
      _currentHoldMs = 0;
    });
    GameHaptics.tap();
  }

  double _avgHoldMs() {
    if (_holdDurations.isEmpty) {
      return 0.0;
    }
    return _holdDurations.reduce((a, b) => a + b) /
        _holdDurations.length;
  }

  Future<void> _finishGame() async {
    _phaseTimer?.cancel();
    _holdTimer?.cancel();
    _isDone = true;
    _started = false;

    final avgMs = _avgHoldMs();
    // Score based on consistency and duration (ideal ~5000ms per chant)
    double consistency = 0.0;
    if (_holdDurations.length >= 2) {
      double variance = 0.0;
      for (final d in _holdDurations) {
        variance += (d - avgMs) * (d - avgMs);
      }
      variance /= _holdDurations.length;
      final stdDev = sqrt(variance);
      consistency =
          (1.0 - (stdDev / avgMs).clamp(0.0, 1.0));
    }

    final completion =
        (_holdDurations.length / _totalRounds).clamp(0.0, 1.0);
    final finalScore =
        ((completion * 400) + (consistency * 300) +
                (min(avgMs / 5000.0, 1.0) * 300))
            .clamp(0.0, 1000.0);

    await _service.saveScore(
      gameType: 'aum_vibration',
      score: finalScore,
      accuracy: completion,
      reactionTimeMs: avgMs.round(),
      roundsCompleted: _holdDurations.length,
      metadata: {
        'rounds': _totalRounds,
        'completed': _holdDurations.length,
        'avg_ms': avgMs.round(),
        'consistency': consistency,
      },
    );
    _isNewBest =
        await _service.submitLocalBest('aum_vibration', finalScore);
    await _service.addXp(
        5 + (completion * 20.0).round());
    if (mounted) {
      setState(() {});
    }
  }

  String _phaseText() {
    switch (_phase) {
      case _Phase.inhale:
        return 'Breathe In...';
      case _Phase.chant:
        return 'Chant "AUM"';
      case _Phase.exhale:
        return 'Breathe Out...';
      case _Phase.rest:
        return 'Rest...';
    }
  }

  String _phaseEmoji() {
    switch (_phase) {
      case _Phase.inhale:
        return '🌬️';
      case _Phase.chant:
        return '🕉️';
      case _Phase.exhale:
        return '💨';
      case _Phase.rest:
        return '😌';
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
                'Aum Vibration',
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
    return _chantScreen(context);
  }

  Widget _startScreen(BuildContext ctx) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(6.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🕉️', style: TextStyle(fontSize: 40.sp)),
            SizedBox(height: 3.h),
            Text('Aum Vibration',
                style: GameTheme.heading(ctx, size: 26)),
            SizedBox(height: 2.h),
            Text(
              'Follow the breath cycle:\nInhale → Press & Hold to chant\n"AUUUUUM" → Exhale\n$_totalRounds rounds.\nLonger & steadier = higher score!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: GameTheme.textSecondary(ctx),
                fontSize: 13.sp,
                height: 1.6,
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
                  'Begin',
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

  Widget _chantScreen(BuildContext ctx) {
    return GestureDetector(
      onPanStart: _phase == _Phase.chant
          ? (_) => _startHold()
          : null,
      onPanEnd: _phase == _Phase.chant
          ? (_) => _endHold()
          : null,
      onTapUp: _phase == _Phase.chant
          ? (_) => _endHold()
          : null,
      onLongPressStart: _phase == _Phase.chant
          ? (_) => _startHold()
          : null,
      onLongPressEnd: _phase == _Phase.chant
          ? (_) => _endHold()
          : null,
      behavior: HitTestBehavior.translucent,
      child: Container(
        color: GameTheme.bg(ctx),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Round ${_roundNum + 1}/$_totalRounds',
                style: TextStyle(
                  color: GameTheme.textSecondary(ctx),
                  fontSize: 14.sp,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                _phaseEmoji(),
                style: TextStyle(fontSize: 36.sp),
              ),
              SizedBox(height: 2.h),
              // Pulse ring during chant
              if (_phase == _Phase.chant)
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) =>
                      Transform.scale(
                    scale: _isHolding
                        ? 1.0 +
                            (_currentHoldMs / 10000.0)
                                .clamp(0.0, 0.5)
                        : 1.0,
                    child: Container(
                      width: 40.w,
                      height: 40.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isHolding
                              ? GameColors.gold
                                  .withValues(alpha: 0.6)
                              : GameTheme.primary(ctx)
                                  .withValues(alpha: 0.2),
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                ),
              if (_phase != _Phase.chant)
                SizedBox(height: 20.w),
              SizedBox(height: 3.h),
              Text(
                _phaseText(),
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                  color: _phase == _Phase.chant
                      ? GameColors.gold
                      : GameTheme.textPrimary(ctx),
                ),
              ),
              if (_phase == _Phase.chant)
                Padding(
                  padding: EdgeInsets.only(top: 2.h),
                  child: Column(
                    children: [
                      Text(
                        _isHolding
                            ? 'Chanting... ${(_currentHoldMs / 1000).toStringAsFixed(1)}s'
                            : 'Press & Hold to chant AUM',
                        style: TextStyle(
                          color: _isHolding
                              ? GameColors.gold
                              : GameTheme
                                  .textSecondary(ctx),
                          fontSize: 16.sp,
                        ),
                      ),
                      if (_isHolding)
                        Padding(
                          padding:
                              EdgeInsets.only(top: 1.h),
                          child: Text(
                            'Release to finish chant',
                            style: TextStyle(
                              color: GameTheme
                                  .textMuted(ctx),
                              fontSize: 12.sp,
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
    );
  }

  Widget _resultScreen(BuildContext ctx) {
    final avgMs = _avgHoldMs();
    double consistency = 0.0;
    if (_holdDurations.length >= 2) {
      double variance = 0.0;
      for (final d in _holdDurations) {
        variance += (d - avgMs) * (d - avgMs);
      }
      variance /= _holdDurations.length;
      final stdDev = sqrt(variance);
      consistency =
          (1.0 - (stdDev / avgMs).clamp(0.0, 1.0));
    }

    final completion =
        (_holdDurations.length / _totalRounds).clamp(0.0, 1.0);

    return GameResultsScreen(
      gameIcon: '🕉️',
      title: 'Aum Complete!',
      performance: completion,
      score: ((completion * 400) +
              (consistency * 300) +
              (min(avgMs / 5000.0, 1.0) * 300))
          .clamp(0.0, 1000.0)
          .round(),
      scoreLabel: 'Vibration Score',
      isNewBest: _isNewBest,
      stats: [
        GameResultStat(
            'Avg Chant', '${(avgMs / 1000).round()}s'),
        GameResultStat(
            'Consistency', '${(consistency * 100).round()}%'),
        GameResultStat(
            'Rounds', '${_holdDurations.length}/$_totalRounds'),
      ],
      onRetry: _startGame,
      onDone: () => Navigator.pop(context),
    );
  }
}
