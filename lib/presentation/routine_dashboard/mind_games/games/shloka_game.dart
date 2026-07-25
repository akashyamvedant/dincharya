import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class ShlokaGame extends StatefulWidget {
  const ShlokaGame({super.key});
  @override
  State<ShlokaGame> createState() => _ShlokaGameState();
}

class _ShlokaGameState extends State<ShlokaGame> {
  final _service = MindGamesService(), _rng = Random();

  static const _totalRounds = 10;
  static const _shlokas = [
    (
      'ॐ असतो मा __ गमय',
      'सद्',
      ['सद्', 'ज्योतिः', 'मृत्योः', 'तमः']
    ),
    (
      'ॐ भूर् भुवः __',
      'स्वः',
      ['स्वः', 'महः', 'जनः', 'तपः']
    ),
    (
      'सर्वे भवन्तु __',
      'सुखिनः',
      ['सुखिनः', 'दुःखिनः', 'धनिनः', 'बलिनः']
    ),
    (
      'वसुधैव __',
      'कुटुम्बकम्',
      ['कुटुम्बकम्', 'परिवारः', 'समाजः', 'ग्रामः']
    ),
    (
      'सत्यमेव __',
      'जयते',
      ['जयते', 'भवति', 'अस्ति', 'धर्मः']
    ),
    (
      'अहिंसा परमो __',
      'धर्मः',
      ['धर्मः', 'कर्मः', 'योगः', 'पथः']
    ),
    (
      'त्वमेव माता च __ त्वमेव',
      'पिता',
      ['पिता', 'गुरुः', 'बन्धुः', 'सखा']
    ),
    (
      'ॐ शान्तिः शान्तिः __',
      'शान्तिः',
      ['शान्तिः', 'प्रेम', 'ज्योतिः', 'सत्यम्']
    ),
    (
      'लोकाः समस्ताः सुखिनो __',
      'भवन्तु',
      ['भवन्तु', 'भवन्ति', 'स्युः', 'सन्तु']
    ),
    (
      'गुरुर्ब्रह्मा गुरुर्विष्णुः __ देवो महेश्वरः',
      'गुरुः',
      ['गुरुः', 'शिवः', 'हरिः', 'प्रभुः']
    ),
    (
      'ॐ नमः __',
      'शिवाय',
      ['शिवाय', 'विष्णवे', 'देव्यै', 'गणेशाय']
    ),
    (
      'यतो धर्मः ततो __',
      'जयः',
      ['जयः', 'सत्यम्', 'धनम्', 'यशः']
    ),
  ];

  int _roundNum = 0;
  int _correctCount = 0;
  late int _currentShlokaIdx;
  late String _displayText;
  late String _answer;
  late List<String> _options;

  bool _started = false;
  bool _showingCountdown = false;
  bool _isDone = false;
  bool _isNewBest = false;
  bool _answered = false;
  int? _selectedOption;

  void _startGame() {
    _roundNum = 0;
    _correctCount = 0;
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

    _currentShlokaIdx = _rng.nextInt(_shlokas.length);
    final (template, answer, opts) = _shlokas[_currentShlokaIdx];
    _answer = answer;
    _displayText = template;
    _options = List<String>.from(opts)..shuffle(_rng);
  }

  void _selectOption(int opt) {
    if (_answered || !_started || _isDone) {
      return;
    }
    final isCorrect = _options[opt] == _answer;
    if (isCorrect) {
      _correctCount++;
      GameHaptics.correct();
    } else {
      GameHaptics.wrong();
    }

    setState(() {
      _selectedOption = opt;
      _answered = true;
    });

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
      gameType: 'shloka',
      score: finalScore,
      accuracy: accuracy,
      roundsCompleted: _totalRounds,
      metadata: {'correct': _correctCount},
    );
    _isNewBest =
        await _service.submitLocalBest('shloka', finalScore);
    await _service.addXp(10 + (accuracy * 20.0).round());
    if (mounted) {
      setState(() {});
    }
  }

  Color _optionColor(int opt) {
    if (!_answered) {
      return Colors.transparent;
    }
    if (_options[opt] == _answer) {
      return GameColors.successGreen.withValues(alpha: 0.2);
    }
    if (opt == _selectedOption && _options[opt] != _answer) {
      return GameColors.errorRed.withValues(alpha: 0.2);
    }
    return Colors.transparent;
  }

  Color _optionBorder(int opt) {
    if (!_answered) {
      return GameTheme.primary(context).withValues(alpha: 0.2);
    }
    if (_options[opt] == _answer) {
      return GameColors.successGreen;
    }
    if (opt == _selectedOption && _options[opt] != _answer) {
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
          'Shloka Complete',
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
            Text('📜', style: TextStyle(fontSize: 54.sp)),
            SizedBox(height: 3.h),
            Text('Shloka Complete',
                style: GameTheme.heading(ctx, size: 26)),
            SizedBox(height: 2.h),
            Text(
              'Complete the Sanskrit shloka\nby choosing the correct\nmissing word.\n$_totalRounds rounds.',
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
          // Shloka display
          Container(
            margin: EdgeInsets.symmetric(horizontal: 5.w),
            padding: EdgeInsets.all(5.w),
            decoration: GameTheme.heroCard(ctx),
            child: Column(
              children: [
                Text(
                  'Complete the shloka:',
                  style: TextStyle(
                    color: GameTheme.textSecondary(ctx),
                    fontSize: 12.sp,
                  ),
                ),
                SizedBox(height: 2.h),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: GameTheme.textPrimary(ctx),
                      height: 1.8,
                    ),
                    children: _buildDisplaySpans(ctx),
                  ),
                ),
                if (_answered)
                  Padding(
                    padding: EdgeInsets.only(top: 2.h),
                    child: Text(
                      _options[_selectedOption!] == _answer
                          ? '✓ Correct!'
                          : 'Answer: $_answer',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: _options[_selectedOption!] ==
                                _answer
                            ? GameColors.successGreen
                            : GameColors.errorRed,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 3.h),
          // Options
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                children: List.generate(_options.length, (i) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 1.5.h),
                    child: GestureDetector(
                      onTap: () => _selectOption(i),
                      child: AnimatedContainer(
                        duration:
                            const Duration(milliseconds: 300),
                        padding: EdgeInsets.symmetric(
                            vertical: 1.8.h, horizontal: 4.w),
                        decoration: BoxDecoration(
                          color: _optionColor(i),
                          borderRadius:
                              BorderRadius.circular(12),
                          border: Border.all(
                            color: _optionBorder(i),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _options[i],
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w600,
                              color: GameTheme
                                  .textPrimary(ctx),
                            ),
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

  List<TextSpan> _buildDisplaySpans(BuildContext ctx) {
    final parts = _displayText.split('__');
    final spans = <TextSpan>[];

    for (int i = 0; i < parts.length; i++) {
      spans.add(TextSpan(text: parts[i]));
      if (i < parts.length - 1) {
        spans.add(TextSpan(
          text: _answered ? ' $_answer ' : ' ___ ',
          style: TextStyle(
            color: _answered
                ? (_options[_selectedOption!] == _answer
                    ? GameColors.successGreen
                    : GameColors.errorRed)
                : GameColors.gold,
            decoration: TextDecoration.underline,
            decorationColor: GameColors.gold,
          ),
        ));
      }
    }
    return spans;
  }

  Widget _resultScreen(BuildContext ctx) {
    final accuracy = _correctCount / _totalRounds;
    return GameResultsScreen(
      gameIcon: '📜',
      title: 'Shloka Complete!',
      performance: accuracy,
      score: (accuracy * 1000.0).round(),
      scoreLabel: 'Shloka Score',
      isNewBest: _isNewBest,
      stats: [
        GameResultStat(
            'Accuracy', '${(accuracy * 100).round()}%'),
        GameResultStat(
            'Correct', '$_correctCount/$_totalRounds'),
        GameResultStat('Shlokas',
            '${_shlokas.length} in bank'),
      ],
      onRetry: _startGame,
      onDone: () => Navigator.pop(context),
    );
  }
}
