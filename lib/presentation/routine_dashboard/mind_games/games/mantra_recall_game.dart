import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class MantraRecallGame extends StatefulWidget {
  const MantraRecallGame({super.key});
  @override
  State<MantraRecallGame> createState() => _MantraRecallGameState();
}

class _MantraRecallGameState extends State<MantraRecallGame> {
  final _service = MindGamesService(), _rng = Random();

  static const _totalRounds = 10;
  static const _mantras = [
    'ॐ',
    'ॐ नमः शिवाय',
    'ॐ मणि पद्मे हूं',
    'गायत्री मंत्र',
    'हरे कृष्ण हरे राम',
    'सर्वे भवन्तु सुखिनः',
    'लोकाः समस्ताः सुखिनो भवन्तु',
    'ॐ असतो मा सद्गमय',
    'ॐ भूर्भुवः स्वः',
    'त्वमेव माता च पिता त्वमेव',
    'ॐ शान्तिः शान्तिः शान्तिः',
    'वसुधैव कुटुम्बकम्',
    'सत्यमेव जयते',
    'अहिंसा परमो धर्मः',
    'ॐ तत् सत्',
  ];

  int _roundNum = 0;
  int _correctCount = 0;
  int _totalTimeMs = 0;
  DateTime? _roundStartTime;

  late String _targetMantra;
  late List<String> _options;
  int? _selectedOption;
  bool _answered = false;
  bool _showingMantra = false;

  bool _started = false;
  bool _showingCountdown = false;
  bool _isDone = false;
  bool _isNewBest = false;
  Timer? _displayTimer;

  int _charIndex = 0;

  @override
  void dispose() {
    _displayTimer?.cancel();
    super.dispose();
  }

  void _startGame() {
    _roundNum = 0;
    _correctCount = 0;
    _totalTimeMs = 0;
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
    _generateRound();
  }

  void _generateRound() {
    _answered = false;
    _selectedOption = null;
    _charIndex = 0;

    // Pick target mantra (increasing difficulty)
    final maxLen = min(_roundNum + 1, _mantras.length - 1);
    final pool = _mantras.sublist(0, maxLen + 1);
    _targetMantra = pool[_rng.nextInt(pool.length)];

    // Generate 4 options
    final opts = <String>{_targetMantra};
    while (opts.length < 4) {
      final fake = _mantras[_rng.nextInt(_mantras.length)];
      if (fake != _targetMantra) {
        opts.add(fake);
      }
    }
    _options = opts.toList()..shuffle(_rng);

    // Show mantra character by character
    setState(() {
      _showingMantra = true;
    });
    _animateText();
  }

  void _animateText() {
    _displayTimer?.cancel();
    if (_charIndex < _targetMantra.length) {
      _displayTimer =
          Timer(const Duration(milliseconds: 150), () {
        if (mounted) {
          setState(() {
            _charIndex++;
          });
          _animateText();
        }
      });
    } else {
      // Display complete for a moment, then hide
      _displayTimer =
          Timer(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _showingMantra = false;
          });
          _roundStartTime = DateTime.now();
        }
      });
    }
  }

  void _selectOption(int opt) {
    if (_answered || !_started || _isDone || _showingMantra) {
      return;
    }
    final correctIdx =
        _options.indexOf(_targetMantra);
    final isCorrect = opt == correctIdx;

    final elapsedMs = DateTime.now()
        .difference(_roundStartTime!)
        .inMilliseconds;

    if (isCorrect) {
      _correctCount++;
      _totalTimeMs += elapsedMs;
      GameHaptics.correct();
    } else {
      GameHaptics.wrong();
    }

    setState(() {
      _selectedOption = opt;
      _answered = true;
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) {
        return;
      }
      _roundNum++;
      if (_roundNum >= _totalRounds) {
        _finishGame();
      } else {
        _generateRound();
      }
    });
  }

  Future<void> _finishGame() async {
    _displayTimer?.cancel();
    _isDone = true;
    _started = false;

    final accuracy = _correctCount / _totalRounds;
    final avgTimeMs = _correctCount > 0
        ? _totalTimeMs ~/ _correctCount
        : 99999;
    final finalScore =
        ((accuracy * 600) + max(0, 400 - avgTimeMs * 0.05))
            .clamp(0.0, 1000.0);

    await _service.saveScore(
      gameType: 'mantra_recall',
      score: finalScore,
      accuracy: accuracy,
      reactionTimeMs: avgTimeMs,
      roundsCompleted: _totalRounds,
      metadata: {'correct': _correctCount},
    );
    _isNewBest =
        await _service.submitLocalBest('mantra_recall', finalScore);
    await _service.addXp(10 + (accuracy * 20.0).round());
    if (mounted) {
      setState(() {});
    }
  }

  Color _optionColor(int opt) {
    if (!_answered) {
      return Colors.transparent;
    }
    final correctIdx = _options.indexOf(_targetMantra);
    if (opt == correctIdx) {
      return GameColors.successGreen.withValues(alpha: 0.2);
    }
    if (opt == _selectedOption && opt != correctIdx) {
      return GameColors.errorRed.withValues(alpha: 0.2);
    }
    return Colors.transparent;
  }

  Color _optionBorder(int opt) {
    if (!_answered) {
      return GameTheme.primary(context).withValues(alpha: 0.2);
    }
    final correctIdx = _options.indexOf(_targetMantra);
    if (opt == correctIdx) {
      return GameColors.successGreen;
    }
    if (opt == _selectedOption && opt != correctIdx) {
      return GameColors.errorRed;
    }
    return GameTheme.primary(context).withValues(alpha: 0.1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameTheme.bg(context),
      appBar: _buildAppBar(),
      body: _buildBody(context),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: GameTheme.bg(context),
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_rounded,
            color: GameTheme.textPrimary(context)),
        onPressed: () {
          _displayTimer?.cancel();
          Navigator.pop(context);
        },
      ),
      title: Text(
        'Mantra Recall',
        style: TextStyle(
          color: GameTheme.textPrimary(context),
          fontSize: 16.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
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
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(6.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🕉️', style: TextStyle(fontSize: 40.sp)),
            SizedBox(height: 3.h),
            Text('Mantra Recall',
                style: GameTheme.heading(ctx, size: 26)),
            SizedBox(height: 2.h),
            Text(
              'A mantra appears briefly.\nMemorize it, then pick it\nfrom the options.\n$_totalRounds rounds.',
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
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Round ${_roundNum + 1}/$_totalRounds',
                  style: TextStyle(
                    color: GameTheme.textSecondary(ctx),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Score: $_correctCount',
                  style: TextStyle(
                    color: GameTheme.accent(ctx),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: _showingMantra
                  ? Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Text(
                          '🕉️',
                          style: TextStyle(fontSize: 36.sp),
                        ),
                        SizedBox(height: 2.h),
                        Container(
                          padding: EdgeInsets.all(5.w),
                          decoration: GameTheme.heroCard(ctx),
                          child: Text(
                            _targetMantra
                                .substring(0, _charIndex),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22.sp,
                              fontWeight: FontWeight.bold,
                              color: GameTheme.primary(ctx),
                              height: 1.8,
                            ),
                          ),
                        ),
                        if (_charIndex >=
                            _targetMantra.length)
                          Padding(
                            padding:
                                EdgeInsets.only(top: 2.h),
                            child: Text(
                              'Memorize...',
                              style: TextStyle(
                                color: GameTheme
                                    .textMuted(ctx),
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                      ],
                    )
                  : _answered
                      ? Center(
                          child: Text(
                            _selectedOption ==
                                    _options.indexOf(
                                        _targetMantra)
                                ? '✓ Correct!'
                                : '✗ The mantra was:\n$_targetMantra',
                            textAlign:
                                TextAlign.center,
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight:
                                  FontWeight.bold,
                              color: _selectedOption ==
                                      _options.indexOf(
                                          _targetMantra)
                                  ? GameColors
                                      .successGreen
                                  : GameColors.errorRed,
                            ),
                          ),
                        )
                      : Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Text(
                              'Recall the mantra:',
                              style: TextStyle(
                                color: GameTheme
                                    .textSecondary(ctx),
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(height: 2.h),
                          ],
                        ),
            ),
          ),
          if (!_showingMantra)
            Expanded(
              flex: 3,
              child: Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 4.w),
                child: ListView(
                  physics:
                      const NeverScrollableScrollPhysics(),
                  children: List.generate(
                      _options.length, (i) {
                    return Padding(
                      padding:
                          EdgeInsets.only(bottom: 1.5.h),
                      child: GestureDetector(
                        onTap: () =>
                            _selectOption(i),
                        child: AnimatedContainer(
                          duration: const Duration(
                              milliseconds: 300),
                          padding:
                              EdgeInsets.symmetric(
                            vertical: 1.8.h,
                            horizontal: 4.w,
                          ),
                          decoration:
                              BoxDecoration(
                            color: _optionColor(i),
                            borderRadius:
                                BorderRadius
                                    .circular(12),
                            border: Border.all(
                              color:
                                  _optionBorder(i),
                              width: 2,
                            ),
                          ),
                          child: Text(
                            _options[i],
                            textAlign:
                                TextAlign.center,
                            style: TextStyle(
                              fontSize: 16.sp,
                              color: GameTheme
                                  .textPrimary(
                                      ctx),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _resultScreen(BuildContext ctx) {
    final accuracy = _correctCount / _totalRounds;
    final avgTimeMs = _correctCount > 0
        ? _totalTimeMs ~/ _correctCount
        : 99999;
    return GameResultsScreen(
      gameIcon: '🕉️',
      title: 'Mantra Complete!',
      performance: accuracy,
      score: ((accuracy * 600) +
              max(0, 400 - avgTimeMs * 0.05))
          .clamp(0.0, 1000.0)
          .round(),
      scoreLabel: 'Recall Score',
      isNewBest: _isNewBest,
      stats: [
        GameResultStat(
            'Accuracy', '${(accuracy * 100).round()}%'),
        GameResultStat(
            'Avg Time', '${avgTimeMs}ms'),
        GameResultStat(
            'Correct', '$_correctCount/$_totalRounds'),
      ],
      onRetry: _startGame,
      onDone: () => Navigator.pop(context),
    );
  }
}
