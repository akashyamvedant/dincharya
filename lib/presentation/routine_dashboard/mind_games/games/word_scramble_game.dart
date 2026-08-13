import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class WordScrambleGame extends StatefulWidget {
  const WordScrambleGame({super.key});
  @override
  State<WordScrambleGame> createState() => _WordScrambleGameState();
}

class _WordScrambleGameState extends State<WordScrambleGame> {
  final _service = MindGamesService(), _rng = Random();

  static const _totalRounds = 10;
  static const _words = [
    'CALM', 'MIND', 'PEACE', 'FOCUS', 'BREATH', 'LIGHT', 'SPACE',
    'TRUTH', 'STILL', 'AWARE', 'HEART', 'GRACE', 'BLOOM', 'SHIFT',
    'ZENITH', 'SERENE', 'CLARITY', 'HARMONY', 'BALANCE', 'WISDOM',
    'SPIRIT', 'SILENCE', 'PURITY', 'DHARMA', 'KARMA', 'MANTRA',
    'SATTVA', 'RAJAS', 'TAMAS', 'PRANA', 'ASANA', 'MUDRA',
    'SUNRISE', 'FREEDOM', 'VICTORY', 'NATURE', 'COSMIC', 'DIVINE',
    'TEMPLE', 'LOTUS', 'SACRED', 'GENTLE', 'EMPATH', 'VISION',
  ];

  int _roundNum = 0;
  int _correctCount = 0;
  int _hintsUsed = 0;
  int _totalTimeMs = 0;
  DateTime? _roundStartTime;

  late String _answer;
  late String _scrambled;
  late Set<int> _hintRevealed;

  final _controller = TextEditingController();
  bool _started = false;
  bool _showingCountdown = false;
  bool _isDone = false;
  bool _isNewBest = false;
  bool _answered = false;
  String _feedback = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startGame() {
    _roundNum = 0;
    _correctCount = 0;
    _hintsUsed = 0;
    _totalTimeMs = 0;
    _isDone = false;
    _isNewBest = false;
    _controller.clear();
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
    _feedback = '';
    _hintRevealed = {};
    _controller.clear();

    // Pick word based on difficulty
    final minLen = 4 + (_roundNum ~/ 3);
    final maxLen = min(7, 4 + (_roundNum ~/ 3) + 1);
    final pool = _words.where((w) =>
        w.length >= minLen && w.length <= maxLen).toList();
    if (pool.isEmpty) {
      _answer = _words[_rng.nextInt(_words.length)];
    } else {
      _answer = pool[_rng.nextInt(pool.length)];
    }

    // Scramble (ensure it's different from original)
    List<String> letters;
    do {
      letters = _answer.split('')..shuffle(_rng);
      _scrambled = letters.join();
    } while (_scrambled == _answer);

    _roundStartTime = DateTime.now();
  }

  void _submitAnswer() {
    if (_answered || !_started || _isDone) {
      return;
    }

    final elapsedMs =
        DateTime.now().difference(_roundStartTime!).inMilliseconds;
    final guess = _controller.text.trim().toUpperCase();

    if (guess.isEmpty) {
      return;
    }

    setState(() {
      _answered = true;
    });

    if (guess == _answer) {
      _correctCount++;
      _totalTimeMs += elapsedMs;
      _feedback = 'Correct!';
      GameHaptics.correct();
    } else {
      _feedback = 'Answer: $_answer';
      GameHaptics.wrong();
    }

    Future.delayed(const Duration(milliseconds: 1200), () {
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

  void _useHint() {
    if (_answered || !_started || _isDone) {
      return;
    }
    final hidden = <int>[];
    for (int i = 0; i < _answer.length; i++) {
      if (!_hintRevealed.contains(i)) {
        hidden.add(i);
      }
    }
    if (hidden.isEmpty) {
      return;
    }
    setState(() {
      _hintsUsed++;
      _hintRevealed.add(hidden[_rng.nextInt(hidden.length)]);
    });
  }

  Future<void> _finishGame() async {
    _isDone = true;
    _started = false;

    final accuracy = _correctCount / _totalRounds;
    final avgTimeMs = _correctCount > 0
        ? _totalTimeMs ~/ _correctCount
        : 99999;
    final finalScore =
        ((accuracy * 700) + max(0, 300 - avgTimeMs * 0.03) - _hintsUsed * 20)
            .clamp(0.0, 1000.0);

    await _service.saveScore(
      gameType: 'word_scramble',
      score: finalScore,
      accuracy: accuracy,
      reactionTimeMs: avgTimeMs,
      roundsCompleted: _totalRounds,
      metadata: {
        'correct': _correctCount,
        'hints': _hintsUsed,
      },
    );
    _isNewBest =
        await _service.submitLocalBest('word_scramble', finalScore);
    await _service.addXp(10 + (accuracy * 20.0).round());
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
          'Word Scramble',
          style: TextStyle(
            color: GameTheme.textPrimary(context),
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_started && !_answered)
            IconButton(
              icon: Icon(Icons.lightbulb_outline_rounded,
                  color: GameColors.gold),
              onPressed: _useHint,
              tooltip: 'Hint',
            ),
        ],
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
            Text('🔤', style: TextStyle(fontSize: 40.sp)),
            SizedBox(height: 3.h),
            Text('Word Scramble',
                style: GameTheme.heading(ctx, size: 26)),
            SizedBox(height: 2.h),
            Text(
              'Unscramble the letters to form a word.\nType your answer and submit.\n$_totalRounds rounds, words get longer!',
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
    // Build display letters with hints
    final displayLetters = _scrambled.split('');
    final hintDisplay = List.generate(_answer.length, (i) {
      if (_answered && _scrambled[i] != ' ') {
        return _answer[i];
      }
      if (_hintRevealed.contains(i)) {
        return _answer[i];
      }
      return null;
    });

    return SafeArea(
      child: SingleChildScrollView(
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
            SizedBox(height: 3.h),
            // Scrambled letters
            Wrap(
              spacing: 2.w,
              runSpacing: 2.w,
              alignment: WrapAlignment.center,
              children: List.generate(displayLetters.length, (i) {
                final isHint = hintDisplay[i] != null;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding:
                      EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
                  decoration: BoxDecoration(
                    color: isHint
                        ? GameColors.gold.withValues(alpha: 0.2)
                        : GameTheme.primary(ctx).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isHint
                          ? GameColors.gold
                          : GameTheme.primary(ctx).withValues(alpha: 0.2),
                      width: isHint ? 2.0 : 1.0,
                    ),
                  ),
                  child: Text(
                    isHint ? hintDisplay[i]! : displayLetters[i],
                    style: TextStyle(
                      color: isHint
                          ? GameColors.gold
                          : GameTheme.textPrimary(ctx),
                      fontSize: 28.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }),
            ),
            SizedBox(height: 3.h),
            // Input field
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              child: TextField(
                controller: _controller,
                enabled: !_answered,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                style: TextStyle(
                  color: GameTheme.textPrimary(ctx),
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  hintText: 'Type your answer',
                  hintStyle: TextStyle(
                    color: GameTheme.textMuted(ctx),
                    fontSize: 16.sp,
                    letterSpacing: 2,
                  ),
                  filled: true,
                  fillColor: GameTheme.surface(ctx).withValues(alpha: 0.4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: GameTheme.primary(ctx).withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: GameTheme.primary(ctx).withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: GameTheme.accent(ctx),
                      width: 2,
                    ),
                  ),
                ),
                onSubmitted: (_) => _submitAnswer(),
              ),
            ),
            SizedBox(height: 2.h),
            // Feedback
            if (_feedback.isNotEmpty)
              Text(
                _feedback,
                style: TextStyle(
                  color: _feedback == 'Correct!'
                      ? GameColors.successGreen
                      : GameColors.errorRed,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            SizedBox(height: 2.h),
            // Submit button
            if (!_answered)
              SizedBox(
                width: 60.w,
                child: ElevatedButton(
                  onPressed: _submitAnswer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GameTheme.primary(ctx),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 1.4.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Submit',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            SizedBox(height: 4.h),
          ],
        ),
      ),
    );
  }

  Widget _resultScreen(BuildContext ctx) {
    final accuracy = _correctCount / _totalRounds;
    final avgTimeMs = _correctCount > 0
        ? _totalTimeMs ~/ _correctCount
        : 99999;
    return GameResultsScreen(
      gameIcon: '🔤',
      title: 'Scramble Complete!',
      performance: accuracy,
      score: ((accuracy * 700) +
              max(0, 300 - avgTimeMs * 0.03) -
              _hintsUsed * 20)
          .clamp(0.0, 1000.0)
          .round(),
      scoreLabel: 'Verbal Score',
      isNewBest: _isNewBest,
      stats: [
        GameResultStat('Accuracy', '${(accuracy * 100).round()}%'),
        GameResultStat('Avg Time', '${avgTimeMs}ms'),
        GameResultStat('Hints', '$_hintsUsed'),
      ],
      onRetry: _startGame,
      onDone: () => Navigator.pop(context),
    );
  }
}
