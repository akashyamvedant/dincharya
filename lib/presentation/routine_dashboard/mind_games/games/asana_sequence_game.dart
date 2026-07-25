import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class AsanaSequenceGame extends StatefulWidget {
  const AsanaSequenceGame({super.key});
  @override
  State<AsanaSequenceGame> createState() => _AsanaSequenceGameState();
}

class _AsanaSequenceGameState extends State<AsanaSequenceGame> {
  final _service = MindGamesService(), _rng = Random();

  static const _asanas = [
    '🧘', '🧎', '🤸', '🕴️', '💪', '🙏', '🦵', '🤲',
    '🕉️', '🌿', '🪷', '☸️',
  ];

  static const _minLen = 3;
  static const _maxLen = 8;

  int _seqLen = _minLen;
  int _attemptNum = 0;
  int _maxLenReached = _minLen - 1;

  late List<int> _sequence;
  int _displayIdx = 0;
  List<int> _userInput = [];

  bool _started = false;
  bool _showingCountdown = false;
  bool _displaying = false;
  bool _inputting = false;
  bool _isDone = false;
  bool _isNewBest = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startGame() {
    _seqLen = _minLen;
    _attemptNum = 0;
    _maxLenReached = _minLen - 1;
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
    _sequence = List.generate(
        _seqLen, (_) => _rng.nextInt(_asanas.length));
    _userInput = [];
    _displayIdx = 0;
    setState(() {
      _displaying = true;
      _inputting = false;
    });
    _showNext();
  }

  void _showNext() {
    _timer?.cancel();
    if (_displayIdx >= _sequence.length) {
      setState(() {
        _displaying = false;
        _inputting = true;
      });
      return;
    }
    _timer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _displayIdx++;
        });
        _showNext();
      }
    });
  }

  void _tapAsana(int idx) {
    if (!_inputting || _isDone) {
      return;
    }
    if (_userInput.length >= _sequence.length) {
      return;
    }
    setState(() {
      _userInput.add(idx);
    });
    GameHaptics.tap();
    if (_userInput.length >= _sequence.length) {
      _checkAnswer();
    }
  }

  void _checkAnswer() {
    bool correct = _userInput.length == _sequence.length;
    if (correct) {
      for (int i = 0; i < _sequence.length; i++) {
        if (_userInput[i] != _sequence[i]) {
          correct = false;
          break;
        }
      }
    }

    if (correct) {
      GameHaptics.correct();
      _maxLenReached = _seqLen;
      _attemptNum = 0;
      if (_seqLen >= _maxLen) {
        _finishGame();
      } else {
        _seqLen++;
        Future.delayed(
            const Duration(milliseconds: 800), () {
          if (mounted) {
            _startSequence();
          }
        });
      }
    } else {
      GameHaptics.wrong();
      _attemptNum++;
      if (_attemptNum >= 2) {
        _finishGame();
      } else {
        Future.delayed(
            const Duration(milliseconds: 800), () {
          if (mounted) {
            _startSequence();
          }
        });
      }
    }
  }

  Future<void> _finishGame() async {
    _timer?.cancel();
    _isDone = true;
    _started = false;

    final perf = (_maxLenReached - _minLen + 1) /
        (_maxLen - _minLen + 1);
    final finalScore =
        (_maxLenReached * 120.0).clamp(0.0, 1000.0);

    await _service.saveScore(
      gameType: 'asana_sequence',
      score: finalScore,
      accuracy: perf.clamp(0.0, 1.0),
      roundsCompleted: _maxLenReached,
      metadata: {'max_seq': _maxLenReached},
    );
    _isNewBest =
        await _service.submitLocalBest('asana_sequence', finalScore);
    await _service.addXp(10 + (perf * 20.0).round());
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
          onPressed: () {
            _timer?.cancel();
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Asana Sequence',
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
            Text('🧘', style: TextStyle(fontSize: 54.sp)),
            SizedBox(height: 3.h),
            Text('Asana Sequence',
                style: GameTheme.heading(ctx, size: 26)),
            SizedBox(height: 2.h),
            Text(
              'Watch the asana sequence.\nRepeat it in the same order.\nSequence grows 3→$_maxLen poses.',
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
                  'Sequence: $_seqLen poses',
                  style: TextStyle(
                    color: GameTheme.textSecondary(ctx),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Best: $_maxLenReached',
                  style: TextStyle(
                    color: GameTheme.accent(ctx),
                    fontSize: 13.sp,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: _displaying
                  ? _displayIdx < _sequence.length
                      ? TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.3, end: 1.0),
                          duration:
                              const Duration(milliseconds: 300),
                          curve: Curves.easeOutBack,
                          builder: (_, scale, __) =>
                              Transform.scale(
                            scale: scale,
                            child: Text(
                              _asanas[
                                  _sequence[_displayIdx]],
                              style:
                                  TextStyle(fontSize: 64.sp),
                            ),
                          ),
                        )
                      : const SizedBox.shrink()
                  : const SizedBox.shrink(),
            ),
          ),
          if (_displaying)
            Text(
              'Watch carefully...',
              style: TextStyle(
                color: GameTheme.textMuted(ctx),
                fontSize: 13.sp,
              ),
            ),
          if (_inputting)
            Expanded(
              flex: 1,
              child: Center(
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: List.generate(_sequence.length, (i) {
                    return Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 1.w),
                      child: Container(
                        width: 10.w,
                        height: 10.w,
                        decoration: BoxDecoration(
                          color: i < _userInput.length
                              ? GameTheme.primary(ctx)
                                  .withValues(alpha: 0.2)
                              : GameTheme.primary(ctx)
                                  .withValues(alpha: 0.05),
                          borderRadius:
                              BorderRadius.circular(8),
                          border: Border.all(
                            color: GameTheme.primary(ctx)
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Center(
                          child: i < _userInput.length
                              ? Text(
                                  _asanas[_userInput[i]],
                                  style: TextStyle(
                                      fontSize: 18.sp),
                                )
                              : null,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          if (_inputting)
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(2.w),
                child: GridView.count(
                  crossAxisCount: 4,
                  physics:
                      const NeverScrollableScrollPhysics(),
                  children: List.generate(_asanas.length, (i) {
                    return GestureDetector(
                      onTap: () => _tapAsana(i),
                      child: Container(
                        margin: EdgeInsets.all(1.w),
                        decoration: BoxDecoration(
                          color: GameTheme.surface(ctx)
                              .withValues(alpha: 0.3),
                          borderRadius:
                              BorderRadius.circular(10),
                          border: Border.all(
                            color: GameTheme.primary(ctx)
                                .withValues(alpha: 0.15),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _asanas[i],
                            style: TextStyle(fontSize: 24.sp),
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
    final perf = (_maxLenReached - _minLen + 1) /
        (_maxLen - _minLen + 1);
    return GameResultsScreen(
      gameIcon: '🧘',
      title: 'Sequence Complete!',
      performance: perf.clamp(0.0, 1.0),
      score: (_maxLenReached * 120.0)
          .clamp(0.0, 1000.0)
          .round(),
      scoreLabel: 'Sequence Score',
      isNewBest: _isNewBest,
      stats: [
        GameResultStat('Max Seq', '$_maxLenReached'),
        GameResultStat('Max Possible', '$_maxLen'),
        GameResultStat(
            'Level', '${_maxLenReached - _minLen + 1}'),
      ],
      onRetry: _startGame,
      onDone: () => Navigator.pop(context),
    );
  }
}
