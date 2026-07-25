import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class NumberSequenceGame extends StatefulWidget {
  const NumberSequenceGame({super.key});
  @override
  State<NumberSequenceGame> createState() => _NumberSequenceGameState();
}

class _NumberSequenceGameState extends State<NumberSequenceGame> {
  final _service = MindGamesService(), _rng = Random();

  static const _totalRounds = 10;
  int _roundNum = 0;
  int _correctCount = 0;

  late List<int> _sequence;
  late int _answer;
  late List<int> _options;

  bool _started = false;
  bool _showingCountdown = false;
  bool _isDone = false;
  bool _isNewBest = false;
  bool _answered = false;
  int? _selectedOption;

  int _difficulty = 0;

  @override
  void initState() {
    super.initState();
  }

  void _startGame() {
    _roundNum = 0;
    _correctCount = 0;
    _difficulty = 0;
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
    _difficulty = _roundNum ~/ 2;
    _answered = false;
    _selectedOption = null;

    final type = _rng.nextInt(min(4, _difficulty + 1));
    final step = _rng.nextInt(9) + 1;
    final start = _rng.nextInt(20) + 1;

    List<int> seq;
    int ans;

    switch (type) {
      case 0: // Arithmetic: +N each step
        seq = List.generate(5, (i) => start + i * step);
        ans = start + 5 * step;
        break;
      case 1: // Arithmetic with offset: start + offset, then +N
        final offset = _rng.nextInt(10) + 2;
        seq = [start];
        for (int i = 1; i < 5; i++) {
          seq.add(seq[i - 1] + step + (i % 2) * offset);
        }
        ans = seq[4] + step + (5 % 2) * offset;
        break;
      case 2: // Geometric: ×N each step
        final mult = _rng.nextInt(3) + 2;
        seq = List.generate(5, (i) => start * pow(mult, i).toInt());
        ans = start * pow(mult, 5).toInt();
        break;
      case 3: // Squares or cubes
      default:
        final base = _rng.nextInt(6) + 2;
        seq = List.generate(5, (i) => (base + i) * (base + i));
        ans = (base + 5) * (base + 5);
        break;
    }

    // Generate 4 options including correct answer
    final opts = <int>{ans};
    while (opts.length < 4) {
      final fake = ans + (_rng.nextInt(21) - 10);
      if (fake > 0 && fake != ans) {
        opts.add(fake);
      }
    }
    final optionsList = opts.toList()..shuffle(_rng);

    _sequence = seq;
    _answer = ans;
    _options = optionsList;
  }

  void _selectOption(int value) {
    if (_answered || !_started || _isDone) {
      return;
    }
    setState(() {
      _selectedOption = value;
      _answered = true;
    });

    if (value == _answer) {
      _correctCount++;
      GameHaptics.correct();
    } else {
      GameHaptics.wrong();
    }

    Future.delayed(const Duration(milliseconds: 800), () {
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
    final finalScore = (accuracy * 1000.0);

    await _service.saveScore(
      gameType: 'number_sequence',
      score: finalScore,
      accuracy: accuracy,
      roundsCompleted: _totalRounds,
      metadata: {
        'correct': _correctCount,
      },
    );
    _isNewBest =
        await _service.submitLocalBest('number_sequence', finalScore);
    await _service.addXp(10 + (accuracy * 25.0).round());
    if (mounted) {
      setState(() {});
    }
  }

  Color _optionColor(int value, BuildContext ctx) {
    if (!_answered) {
      return Colors.transparent;
    }
    if (value == _answer) {
      return GameColors.successGreen.withValues(alpha: 0.2);
    }
    if (value == _selectedOption && value != _answer) {
      return GameColors.errorRed.withValues(alpha: 0.2);
    }
    return Colors.transparent;
  }

  Color _optionBorder(int value) {
    if (!_answered) {
      return GameTheme.primary(context).withValues(alpha: 0.2);
    }
    if (value == _answer) {
      return GameColors.successGreen;
    }
    if (value == _selectedOption && value != _answer) {
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
          'Number Sequence',
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
            Text('Number Sequence',
                style: GameTheme.heading(ctx, size: 26)),
            SizedBox(height: 2.h),
            Text(
              'Find the next number in the pattern.\n"2, 4, 6, 8, ?"\n$_totalRounds rounds of increasing difficulty.',
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
                  'Round ${_roundNum + 1}/$_totalRounds',
                  style: TextStyle(
                    color: GameTheme.textSecondary(ctx),
                    fontSize: 14.sp,
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
          // Sequence display
          Container(
            margin: EdgeInsets.symmetric(horizontal: 5.w),
            padding: EdgeInsets.all(4.w),
            decoration: GameTheme.heroCard(ctx),
            child: Column(
              children: [
                Text(
                  'What comes next?',
                  style: TextStyle(
                    color: GameTheme.textSecondary(ctx),
                    fontSize: 13.sp,
                  ),
                ),
                SizedBox(height: 1.5.h),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 3.w,
                  runSpacing: 1.h,
                  children: [
                    ..._sequence.map((n) => Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 3.w, vertical: 1.h),
                          decoration: BoxDecoration(
                            color: GameTheme.primary(ctx)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$n',
                            style: TextStyle(
                              color: GameTheme.textPrimary(ctx),
                              fontSize: 22.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 3.w, vertical: 1.h),
                      decoration: BoxDecoration(
                        color: GameTheme.accent(ctx).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: GameTheme.accent(ctx).withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        '?',
                        style: TextStyle(
                          color: GameTheme.accent(ctx),
                          fontSize: 22.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 3.h),
          // Options
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 5.w),
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 2.h,
                crossAxisSpacing: 3.w,
                childAspectRatio: 2.5,
                physics: const NeverScrollableScrollPhysics(),
                children: _options.map((opt) {
                  return GestureDetector(
                    onTap: () => _selectOption(opt),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        color: _optionColor(opt, ctx),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _optionBorder(opt),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$opt',
                          style: TextStyle(
                            color: _answered && opt == _answer
                                ? GameColors.successGreen
                                : _answered &&
                                        opt == _selectedOption &&
                                        opt != _answer
                                    ? GameColors.errorRed
                                    : GameTheme.textPrimary(ctx),
                            fontSize: 24.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultScreen(BuildContext ctx) {
    final accuracy = _correctCount / _totalRounds;
    return GameResultsScreen(
      gameIcon: '🔢',
      title: 'Sequence Complete!',
      performance: accuracy,
      score: (accuracy * 1000.0).round(),
      scoreLabel: 'IQ Score',
      isNewBest: _isNewBest,
      stats: [
        GameResultStat('Accuracy', '${(accuracy * 100).round()}%'),
        GameResultStat('Correct', '$_correctCount/$_totalRounds'),
        GameResultStat('Difficulty', 'Lv ${_difficulty + 1}'),
      ],
      onRetry: _startGame,
      onDone: () => Navigator.pop(context),
    );
  }
}
