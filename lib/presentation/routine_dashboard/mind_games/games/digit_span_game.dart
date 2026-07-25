import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class DigitSpanGame extends StatefulWidget {
  const DigitSpanGame({super.key});
  @override
  State<DigitSpanGame> createState() => _DigitSpanGameState();
}

class _DigitSpanGameState extends State<DigitSpanGame> {
  final _service = MindGamesService(), _rng = Random();

  static const int _minSpan = 3;
  static const int _maxSpan = 9;
  static const int _attemptsPerSpan = 2;

  int _currentSpan = _minSpan;
  int _attemptNum = 0;
  int _maxSpanReached = _minSpan - 1;

  late List<int> _sequence;
  int _displayIndex = -1;
  String _userInput = '';

  // Phases
  bool _started = false;
  bool _showingCountdown = false;
  bool _displaying = false;
  bool _inputting = false;
  bool _isDone = false;
  bool _isNewBest = false;
  Timer? _displayTimer;

  @override
  void dispose() {
    _displayTimer?.cancel();
    super.dispose();
  }

  void _startGame() {
    _currentSpan = _minSpan;
    _attemptNum = 0;
    _maxSpanReached = _minSpan - 1;
    _isDone = false;
    _isNewBest = false;
    setState(() {
      _showingCountdown = true;
    });
  }

  void _onCountdownDone() {
    setState(() {
      _showingCountdown = false;
      _started = true;
    });
    _startSequence();
  }

  void _startSequence() {
    // Generate random digits (1-9)
    _sequence =
        List.generate(_currentSpan, (_) => _rng.nextInt(9) + 1);
    _userInput = '';
    _displayIndex = 0;

    setState(() {
      _displaying = true;
      _inputting = false;
    });

    _showNextDigit();
  }

  void _showNextDigit() {
    _displayTimer?.cancel();
    if (_displayIndex >= _sequence.length) {
      // Done displaying, switch to input
      setState(() {
        _displaying = false;
        _inputting = true;
      });
      return;
    }

    // Schedule next digit
    _displayTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _displayIndex++;
        });
        _showNextDigit();
      }
    });
  }

  void _enterDigit(int digit) {
    if (!_inputting || _isDone) {
      return;
    }
    if (_userInput.length >= _sequence.length) {
      return;
    }
    setState(() {
      _userInput += digit.toString();
    });
    GameHaptics.tap();
  }

  void _clearLastDigit() {
    if (!_inputting || _isDone) {
      return;
    }
    if (_userInput.isEmpty) {
      return;
    }
    setState(() {
      _userInput = _userInput.substring(0, _userInput.length - 1);
    });
  }

  void _submitAnswer() {
    if (!_inputting || _isDone) {
      return;
    }
    if (_userInput.length < _sequence.length) {
      return;
    }

    // Check if user input matches reverse of sequence
    final expected = _sequence.reversed.join();
    final isCorrect = _userInput == expected;

    if (isCorrect) {
      GameHaptics.correct();
      _maxSpanReached = _currentSpan;
      _attemptNum = 0;

      if (_currentSpan >= _maxSpan) {
        _finishGame();
      } else {
        _currentSpan++;
        _startSequence();
      }
    } else {
      GameHaptics.wrong();
      _attemptNum++;
      if (_attemptNum >= _attemptsPerSpan) {
        _finishGame();
      } else {
        // Retry same span with new sequence
        _startSequence();
      }
    }
  }

  Future<void> _finishGame() async {
    _displayTimer?.cancel();
    _isDone = true;
    _started = false;

    final perf = (_maxSpanReached - _minSpan + 1) /
        (_maxSpan - _minSpan + 1);
    final finalScore = (_maxSpanReached * 120.0).clamp(0.0, 1000.0);

    await _service.saveScore(
      gameType: 'digit_span',
      score: finalScore,
      accuracy: perf.clamp(0.0, 1.0),
      roundsCompleted: _maxSpanReached,
      metadata: {
        'max_span': _maxSpanReached,
        'attempts': _attemptNum + 1,
      },
    );
    _isNewBest =
        await _service.submitLocalBest('digit_span', finalScore);
    await _service.addXp(10 + (perf * 25.0).round());
    if (mounted) {
      setState(() {});
    }
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
        title: Text(
          'Digit Span Reverse',
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
    return _gameScreen(context);
  }

  Widget _startScreen(BuildContext ctx) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(6.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🔢', style: TextStyle(fontSize: 54.sp)),
            SizedBox(height: 3.h),
            Text('Digit Span Reverse',
                style: GameTheme.heading(ctx, size: 26)),
            SizedBox(height: 2.h),
            Text(
              'Numbers flash one at a time.\nEnter them in REVERSE order.\nSequence grows from $_minSpan→$_maxSpan digits.',
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
                  'Start',
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

  Widget _gameScreen(BuildContext ctx) {
    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 1.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Span: $_currentSpan digits',
                  style: TextStyle(
                    color: GameTheme.textSecondary(ctx),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Attempt ${_attemptNum + 1}/$_attemptsPerSpan',
                  style: TextStyle(
                    color: GameTheme.accent(ctx),
                    fontSize: 13.sp,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 2.h),
          // Display area
          Expanded(
            flex: 2,
            child: Center(
              child: _displaying
                  ? _displayIndex < _sequence.length
                      ? TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.3, end: 1.0),
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutBack,
                          builder: (_, scale, __) => Transform.scale(
                            scale: scale,
                            child: Text(
                              '${_sequence[_displayIndex]}',
                              style: TextStyle(
                                fontSize: 72.sp,
                                fontWeight: FontWeight.w900,
                                color: GameTheme.accent(ctx),
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink()
                  : const SizedBox.shrink(),
            ),
          ),
          // User input display
          if (_inputting)
            Expanded(
              flex: 1,
              child: Center(
                child: Text(
                  _userInput.isEmpty
                      ? 'Enter in reverse...'
                      : _userInput.split('').join(' '),
                  style: TextStyle(
                    color: _userInput.isEmpty
                        ? GameTheme.textMuted(ctx)
                        : GameTheme.textPrimary(ctx),
                    fontSize: _userInput.isEmpty ? 16.sp : 32.sp,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
              ),
            ),
          // Number pad
          if (_inputting)
            Padding(
              padding: EdgeInsets.all(4.w),
              child: Column(
                children: [
                  // Digits 1-9
                  for (int row = 0; row < 3; row++)
                    Padding(
                      padding: EdgeInsets.only(bottom: 1.h),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceEvenly,
                        children: List.generate(3, (col) {
                          final digit = row * 3 + col + 1;
                          return _numPadButton(ctx, digit);
                        }),
                      ),
                    ),
                  // Bottom row: clear, 0, submit
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceEvenly,
                    children: [
                      _actionButton(ctx, '⌫', _clearLastDigit),
                      _numPadButton(ctx, 0),
                      _actionButton(ctx, '✓', _submitAnswer,
                          isPrimary: true),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _numPadButton(BuildContext ctx, int digit) {
    return GestureDetector(
      onTap: () => _enterDigit(digit),
      child: Container(
        width: 17.w,
        height: 17.w,
        decoration: BoxDecoration(
          color: GameTheme.surface(ctx).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: GameTheme.primary(ctx).withValues(alpha: 0.2),
          ),
        ),
        child: Center(
          child: Text(
            '$digit',
            style: TextStyle(
              color: GameTheme.textPrimary(ctx),
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(
      BuildContext ctx, String label, VoidCallback onTap,
      {bool isPrimary = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 17.w,
        height: 17.w,
        decoration: BoxDecoration(
          color: isPrimary
              ? GameTheme.primary(ctx).withValues(alpha: 0.2)
              : GameTheme.surface(ctx).withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary
                ? GameTheme.primary(ctx)
                : GameTheme.primary(ctx).withValues(alpha: 0.2),
            width: isPrimary ? 2.0 : 1.0,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isPrimary
                  ? GameTheme.primary(ctx)
                  : GameTheme.textSecondary(ctx),
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultScreen(BuildContext ctx) {
    final perf = (_maxSpanReached - _minSpan + 1) /
        (_maxSpan - _minSpan + 1);
    return GameResultsScreen(
      gameIcon: '🔢',
      title: 'Span Complete!',
      performance: perf.clamp(0.0, 1.0),
      score: (_maxSpanReached * 120.0).clamp(0.0, 1000.0).round(),
      scoreLabel: 'Working Memory',
      isNewBest: _isNewBest,
      stats: [
        GameResultStat('Max Span', '$_maxSpanReached'),
        GameResultStat('Max Possible', '$_maxSpan'),
        GameResultStat('Score', '${(_maxSpanReached * 120.0).round()}'),
      ],
      onRetry: _startGame,
      onDone: () => Navigator.pop(context),
    );
  }
}
