import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class DailyTriviaGame extends StatefulWidget {
  const DailyTriviaGame({super.key});
  @override
  State<DailyTriviaGame> createState() => _DailyTriviaGameState();
}

class _DailyTriviaGameState extends State<DailyTriviaGame> {
  final _service = MindGamesService();

  static const _totalQuestions = 10;

  // Question bank
  static const _questions = [
    (
      'Science',
      'What is the powerhouse of the cell?',
      ['Nucleus', 'Mitochondria', 'Ribosome', 'Golgi Body'],
      1
    ),
    (
      'Science',
      'How many bones are in the adult human body?',
      ['186', '206', '226', '246'],
      1
    ),
    (
      'Science',
      'What planet is known as the Red Planet?',
      ['Venus', 'Jupiter', 'Mars', 'Saturn'],
      2
    ),
    (
      'Science',
      'What gas do plants absorb from the atmosphere?',
      ['Oxygen', 'Nitrogen', 'Hydrogen', 'Carbon Dioxide'],
      3
    ),
    (
      'History',
      'Who was the first Prime Minister of India?',
      ['Mahatma Gandhi', 'Jawaharlal Nehru', 'Sardar Patel', 'B.R. Ambedkar'],
      1
    ),
    (
      'History',
      'In which year did India gain independence?',
      ['1945', '1946', '1947', '1948'],
      2
    ),
    (
      'History',
      'The Indus Valley Civilization was discovered in which year?',
      ['1901', '1911', '1921', '1931'],
      2
    ),
    (
      'Geography',
      'What is the largest continent by area?',
      ['Africa', 'North America', 'Asia', 'Europe'],
      2
    ),
    (
      'Geography',
      'Which is the longest river in the world?',
      ['Amazon', 'Nile', 'Yangtze', 'Mississippi'],
      1
    ),
    (
      'Geography',
      'What is the capital of Australia?',
      ['Sydney', 'Melbourne', 'Canberra', 'Perth'],
      2
    ),
    (
      'Yoga',
      'What does the word "Yoga" mean?',
      ['Exercise', 'Union', 'Strength', 'Breathing'],
      1
    ),
    (
      'Yoga',
      'Which asana is known as the "King of Asanas"?',
      ['Padmasana', 'Sarvangasana', 'Shirshasana', 'Vajrasana'],
      2
    ),
    (
      'Yoga',
      'How many limbs of Yoga are described by Patanjali?',
      ['5', '6', '7', '8'],
      3
    ),
    (
      'General',
      'What is the chemical symbol for gold?',
      ['Ag', 'Au', 'Fe', 'Cu'],
      1
    ),
    (
      'General',
      'How many colors are in a rainbow?',
      ['5', '6', '7', '8'],
      2
    ),
    (
      'General',
      'Which Indian festival is known as the Festival of Lights?',
      ['Holi', 'Diwali', 'Navratri', 'Eid'],
      1
    ),
    (
      'Yoga',
      'What is the energy center at the base of the spine called?',
      ['Ajna', 'Anahata', 'Muladhara', 'Sahasrara'],
      2
    ),
    (
      'Science',
      'What element has the chemical symbol "O"?',
      ['Osmium', 'Oxygen', 'Oganesson', 'Ozone'],
      1
    ),
    (
      'Geography',
      'Which country has the most people?',
      ['USA', 'India', 'China', 'Indonesia'],
      1
    ),
    (
      'General',
      'How many days are in a leap year?',
      ['364', '365', '366', '367'],
      2
    ),
  ];

  late List<int> _questionIndices;
  int _currentIdx = 0;
  int _correctCount = 0;
  int? _selectedOption;
  bool _answered = false;

  bool _started = false;
  bool _showingCountdown = false;
  bool _isDone = false;
  bool _isNewBest = false;

  void _startGame() {
    // Deterministic shuffle based on date for daily rotation
    final now = DateTime.now();
    final daySeed = now.year * 1000 + now.month * 100 + now.day;
    final seededRng = Random(daySeed);

    _questionIndices =
        List.generate(_questions.length, (i) => i)..shuffle(seededRng);
    _questionIndices = _questionIndices.take(_totalQuestions).toList();
    _currentIdx = 0;
    _correctCount = 0;
    _selectedOption = null;
    _answered = false;
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
  }

  void _selectOption(int opt) {
    if (_answered || !_started || _isDone) {
      return;
    }
    final questionData = _questions[_questionIndices[_currentIdx]];
    final correctIdx = questionData.$4;

    setState(() {
      _selectedOption = opt;
      _answered = true;
    });

    if (opt == correctIdx) {
      _correctCount++;
      GameHaptics.correct();
    } else {
      GameHaptics.wrong();
    }

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) {
        return;
      }
      _currentIdx++;
      if (_currentIdx >= _totalQuestions) {
        _finishGame();
      } else {
        setState(() {
          _selectedOption = null;
          _answered = false;
        });
      }
    });
  }

  Future<void> _finishGame() async {
    _isDone = true;
    _started = false;

    final accuracy = _correctCount / _totalQuestions;
    final finalScore = (accuracy * 1000.0);

    await _service.saveScore(
      gameType: 'daily_trivia',
      score: finalScore,
      accuracy: accuracy,
      roundsCompleted: _totalQuestions,
      metadata: {
        'correct': _correctCount,
      },
    );
    _isNewBest =
        await _service.submitLocalBest('daily_trivia', finalScore);
    await _service.addXp(10 + (accuracy * 20.0).round());
    if (mounted) {
      setState(() {});
    }
  }

  Color _optionColor(int opt, BuildContext ctx) {
    if (!_answered) {
      return Colors.transparent;
    }
    final correctIdx =
        _questions[_questionIndices[_currentIdx]].$4;
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
    final correctIdx =
        _questions[_questionIndices[_currentIdx]].$4;
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
      appBar: AppBar(
        backgroundColor: GameTheme.bg(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: GameTheme.textPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Daily Trivia',
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
            Text('📚', style: TextStyle(fontSize: 54.sp)),
            SizedBox(height: 3.h),
            Text('Daily Trivia',
                style: GameTheme.heading(ctx, size: 26)),
            SizedBox(height: 2.h),
            Text(
              '$_totalQuestions questions across\nScience, History, Geography,\nYoga & General Knowledge.\nNew questions every day!',
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
                  'Start Quiz',
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
    final questionData =
        _questions[_questionIndices[_currentIdx]];
    final category = questionData.$1;
    final question = questionData.$2;
    final options = questionData.$3;
    final correctIdx = questionData.$4;

    return SafeArea(
      child: Column(
        children: [
          // Progress bar
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
            child: Row(
              children: [
                Text(
                  'Q${_currentIdx + 1}/$_totalQuestions',
                  style: TextStyle(
                    color: GameTheme.textSecondary(ctx),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_currentIdx + 1) / _totalQuestions,
                      minHeight: 6,
                      backgroundColor: GameTheme.primary(ctx)
                          .withValues(alpha: 0.1),
                      color: GameTheme.accent(ctx),
                    ),
                  ),
                ),
                SizedBox(width: 3.w),
                Text(
                  '$_correctCount',
                  style: TextStyle(
                    color: GameColors.successGreen,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 1.h),
          // Category badge
          Container(
            padding:
                EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.6.h),
            decoration: BoxDecoration(
              color: GameTheme.primary(ctx).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              category,
              style: TextStyle(
                color: GameTheme.primary(ctx),
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: 2.h),
          // Question
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 5.w),
            child: Text(
              question,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: GameTheme.textPrimary(ctx),
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
          SizedBox(height: 3.h),
          // Options
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 5.w),
              child: Column(
                children: List.generate(options.length, (i) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 2.h),
                    child: GestureDetector(
                      onTap: () => _selectOption(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                            vertical: 1.8.h, horizontal: 4.w),
                        decoration: BoxDecoration(
                          color: _optionColor(i, ctx),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _optionBorder(i),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 9.w,
                              height: 9.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _answered
                                    ? (i == correctIdx
                                        ? GameColors.successGreen
                                        : i == _selectedOption
                                            ? GameColors.errorRed
                                            : GameTheme.primary(ctx)
                                                .withValues(alpha: 0.2))
                                    : GameTheme.primary(ctx)
                                        .withValues(alpha: 0.15),
                              ),
                              child: Center(
                                child: Text(
                                  String.fromCharCode(
                                      65 + i), // A, B, C, D
                                  style: TextStyle(
                                    color: _answered &&
                                            (i == correctIdx ||
                                                i == _selectedOption)
                                        ? Colors.white
                                        : GameTheme.textPrimary(ctx),
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Expanded(
                              child: Text(
                                options[i],
                                style: TextStyle(
                                  color: GameTheme.textPrimary(ctx),
                                  fontSize: 15.sp,
                                ),
                              ),
                            ),
                          ],
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
    final accuracy = _correctCount / _totalQuestions;
    String grade;
    if (accuracy >= 0.9) {
      grade = 'Trivia Master!';
    } else if (accuracy >= 0.7) {
      grade = 'Great Knowledge!';
    } else if (accuracy >= 0.5) {
      grade = 'Good Effort!';
    } else {
      grade = 'Keep Learning!';
    }

    return GameResultsScreen(
      gameIcon: '📚',
      title: grade,
      performance: accuracy,
      score: (accuracy * 1000.0).round(),
      scoreLabel: 'Trivia Score',
      isNewBest: _isNewBest,
      stats: [
        GameResultStat(
            'Accuracy', '${(accuracy * 100).round()}%'),
        GameResultStat(
            'Correct', '$_correctCount/$_totalQuestions'),
        GameResultStat('Grade',
            accuracy >= 0.9 ? 'A+' : accuracy >= 0.7 ? 'B' : 'C'),
      ],
      onRetry: _startGame,
      onDone: () => Navigator.pop(context),
    );
  }
}
