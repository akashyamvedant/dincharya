import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class MudraSpeedGame extends StatefulWidget {
  const MudraSpeedGame({super.key});
  @override
  State<MudraSpeedGame> createState() => _MudraSpeedGameState();
}

class _MudraSpeedGameState extends State<MudraSpeedGame> {
  final _service = MindGamesService(), _rng = Random();

  static const _totalRounds = 15;
  static const _mudras = [
    ('Gyan Mudra', '🤏'),
    ('Prana Mudra', '🖖'),
    ('Apana Mudra', '🤞'),
    ('Vayu Mudra', '☝️'),
    ('Shunya Mudra', '👇'),
    ('Surya Mudra', '🫰'),
    ('Varun Mudra', '🤙'),
    ('Linga Mudra', '🤝'),
    ('Dhyana Mudra', '🤲'),
    ('Anjali Mudra', '🙏'),
    ('Prithvi Mudra', '🫳'),
    ('Hridaya Mudra', '💖'),
  ];

  int _roundNum = 0;
  int _correctCount = 0;
  int _totalTimeMs = 0;

  late String _targetName;
  late int _correctIdx;
  late List<int> _optionIndices;
  int? _selectedOption;
  bool _answered = false;
  DateTime? _roundStartTime;

  bool _started = false;
  bool _showingCountdown = false;
  bool _isDone = false;
  bool _isNewBest = false;

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

    final targetIdx = _rng.nextInt(_mudras.length);
    _targetName = _mudras[targetIdx].$1;

    // Generate 4 options including correct
    final opts = <int>{targetIdx};
    while (opts.length < 4) {
      opts.add(_rng.nextInt(_mudras.length));
    }
    _optionIndices = opts.toList()..shuffle(_rng);
    _correctIdx = _optionIndices.indexOf(targetIdx);

    _roundStartTime = DateTime.now();
  }

  void _selectOption(int opt) {
    if (_answered || !_started || _isDone) {
      return;
    }
    final isCorrect = opt == _correctIdx;
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

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) {
        return;
      }
      _roundNum++;
      if (_roundNum >= _totalRounds) {
        _finishGame();
      } else {
        _generateRound();
        if (mounted) {
          setState(() {});
        }
      }
    });
  }

  Future<void> _finishGame() async {
    _isDone = true;
    _started = false;

    final accuracy = _correctCount / _totalRounds;
    final avgTimeMs = _correctCount > 0
        ? _totalTimeMs ~/ _correctCount
        : 9999;
    final finalScore =
        ((accuracy * 500) + max(0, 500 - avgTimeMs))
            .clamp(0.0, 1000.0);

    await _service.saveScore(
      gameType: 'mudra_speed',
      score: finalScore,
      accuracy: accuracy,
      reactionTimeMs: avgTimeMs,
      roundsCompleted: _totalRounds,
      metadata: {'correct': _correctCount},
    );
    _isNewBest =
        await _service.submitLocalBest('mudra_speed', finalScore);
    await _service.addXp(10 + (accuracy * 20.0).round());
    if (mounted) {
      setState(() {});
    }
  }

  Color _optionColor(int opt) {
    if (!_answered) {
      return Colors.transparent;
    }
    if (opt == _correctIdx) {
      return GameColors.successGreen.withValues(alpha: 0.2);
    }
    if (opt == _selectedOption && opt != _correctIdx) {
      return GameColors.errorRed.withValues(alpha: 0.2);
    }
    return Colors.transparent;
  }

  Color _optionBorder(int opt) {
    if (!_answered) {
      return GameTheme.primary(context).withValues(alpha: 0.2);
    }
    if (opt == _correctIdx) {
      return GameColors.successGreen;
    }
    if (opt == _selectedOption && opt != _correctIdx) {
      return GameColors.errorRed;
    }
    return GameTheme.primary(context).withValues(alpha: 0.1);
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
          'Mudra Speed',
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
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(6.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🤏', style: TextStyle(fontSize: 40.sp)),
            SizedBox(height: 3.h),
            Text('Mudra Speed',
                style: GameTheme.heading(ctx, size: 26)),
            SizedBox(height: 2.h),
            Text(
              'See a mudra name, pick its\nhand gesture fast!\n$_totalRounds rounds.',
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
          SizedBox(height: 2.h),
          // Target mudra name
          Container(
            margin: EdgeInsets.symmetric(horizontal: 5.w),
            padding: EdgeInsets.all(4.w),
            decoration: GameTheme.heroCard(ctx),
            child: Column(
              children: [
                Text(
                  'Which mudra is this?',
                  style: TextStyle(
                    color: GameTheme.textSecondary(ctx),
                    fontSize: 12.sp,
                  ),
                ),
                SizedBox(height: 1.h),
                Text(
                  _targetName,
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: GameTheme.primary(ctx),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 2.h),
          // Options grid
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(3.w),
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 2.h,
                crossAxisSpacing: 3.w,
                childAspectRatio: 1.2,
                physics: const NeverScrollableScrollPhysics(),
                children: List.generate(4, (i) {
                  final mudraIdx = _optionIndices[i];
                  final (_, emoji) = _mudras[mudraIdx];
                  return GestureDetector(
                    onTap: () => _selectOption(i),
                    child: AnimatedContainer(
                      duration:
                          const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        color: _optionColor(i),
                        borderRadius:
                            BorderRadius.circular(14),
                        border: Border.all(
                          color: _optionBorder(i),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Text(
                            emoji,
                            style: TextStyle(fontSize: 40.sp),
                          ),
                          SizedBox(height: 1.h),
                          Text(
                            _mudras[mudraIdx].$1,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: GameTheme
                                  .textSecondary(ctx),
                            ),
                          ),
                        ],
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
        : 9999;
    return GameResultsScreen(
      gameIcon: '🤏',
      title: 'Mudra Complete!',
      performance: accuracy,
      score: ((accuracy * 500) +
              max(0, 500 - avgTimeMs))
          .clamp(0.0, 1000.0)
          .round(),
      scoreLabel: 'Mudra Score',
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
