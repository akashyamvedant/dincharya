import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class FiveSensesGame extends StatefulWidget {
  const FiveSensesGame({super.key});
  @override
  State<FiveSensesGame> createState() => _FiveSensesGameState();
}

class _FiveSensesGameState extends State<FiveSensesGame> {
  final _service = MindGamesService(), _rng = Random();

  static const _senses = [
    ('👁️', 'Sight', 'Close your eyes and imagine:\n'),
    ('👂', 'Sound', 'Listen carefully:\n'),
    ('👃', 'Smell', 'Breathe deeply:\n'),
    ('👅', 'Taste', 'Focus on your tongue:\n'),
    ('🤚', 'Touch', 'Feel with your fingertips:\n'),
  ];

  static const _prompts = [
    'A bright sunrise over mountains',
    'Ocean waves crashing on rocks',
    'A blooming red rose in a garden',
    'Raindrops falling on green leaves',
    'A candle flame in a dark room',
    'A bird singing at dawn',
    'Wind rustling through bamboo',
    'A temple bell ringing in distance',
    'Your own heartbeat, steady and calm',
    'The scent of fresh earth after rain',
    'Incense burning in a quiet room',
    'Freshly cut grass on a sunny day',
    'The aroma of chai brewing',
    'Sweet honey on your tongue',
    'A ripe mango, juicy and warm',
    'Dark chocolate melting slowly',
    'Cool water on a hot day',
    'Warm sunlight on your skin',
    'Soft sand between your toes',
    'A gentle breeze on your face',
    'The texture of smooth stone',
  ];

  int _senseIdx = 0;
  int _vividness = 3;
  int _totalVividness = 0;
  bool _started = false;
  bool _showingCountdown = false;
  bool _isDone = false;
  bool _isNewBest = false;
  String _prompt = '';

  @override
  void initState() {
    super.initState();
  }

  void _startGame() {
    _senseIdx = 0;
    _vividness = 3;
    _totalVividness = 0;
    _isDone = false;
    _isNewBest = false;
    _prompt = _prompts[_rng.nextInt(_prompts.length)];
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

  void _nextSense() {
    _totalVividness += _vividness;
    _senseIdx++;
    if (_senseIdx >= _senses.length) {
      _finishGame();
    } else {
      _vividness = 3;
      _prompt = _prompts[_rng.nextInt(_prompts.length)];
      setState(() {});
    }
  }

  Future<void> _finishGame() async {
    _isDone = true;
    _started = false;

    final avgVividness =
        _totalVividness / _senses.length;
    final finalScore = (avgVividness / 5.0 * 1000.0);

    await _service.saveScore(
      gameType: 'five_senses',
      score: finalScore,
      accuracy: avgVividness / 5.0,
      roundsCompleted: _senses.length,
      metadata: {'vividness': avgVividness},
    );
    _isNewBest =
        await _service.submitLocalBest('five_senses', finalScore);
    await _service.addXp(5 + (avgVividness / 5.0 * 15.0).round());
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
                '5 Senses',
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
            Text('👁️', style: TextStyle(fontSize: 40.sp)),
            SizedBox(height: 3.h),
            Text('5 Senses Imagination',
                style: GameTheme.heading(ctx, size: 26)),
            SizedBox(height: 2.h),
            Text(
              'Train your imagination power.\nClose your eyes and vividly\nimagine each prompt.\nRate how clearly you can\nsee, hear, smell, taste, feel.',
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

  Widget _gameScreen(BuildContext ctx) {
    final (emoji, senseName, _) = _senses[_senseIdx];
    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            emoji,
            style: TextStyle(fontSize: 36.sp),
          ),
          SizedBox(height: 1.h),
          Text(
            '${_senseIdx + 1}/5 — $senseName',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: GameTheme.accent(ctx),
            ),
          ),
          SizedBox(height: 2.h),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 5.w),
            padding: EdgeInsets.all(5.w),
            decoration: GameTheme.heroCard(ctx),
            child: Column(
              children: [
                if (_senseIdx == 0)
                  Text(
                    'Close your eyes.\nImagine vividly:\n\n',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: GameTheme.textSecondary(ctx),
                      fontSize: 13.sp,
                    ),
                  ),
                if (_senseIdx == 1)
                  Text(
                    'Still with eyes closed.\nHear in your mind:\n\n',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: GameTheme.textSecondary(ctx),
                      fontSize: 13.sp,
                    ),
                  ),
                if (_senseIdx == 2)
                  Text(
                    'Breathe deeply.\nImagine the smell of:\n\n',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: GameTheme.textSecondary(ctx),
                      fontSize: 13.sp,
                    ),
                  ),
                if (_senseIdx == 3)
                  Text(
                    'Focus on your tongue.\nImagine the taste of:\n\n',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: GameTheme.textSecondary(ctx),
                      fontSize: 13.sp,
                    ),
                  ),
                if (_senseIdx == 4)
                  Text(
                    'Feel with your mind:\n\n',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: GameTheme.textSecondary(ctx),
                      fontSize: 13.sp,
                    ),
                  ),
                Text(
                  _prompt,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: GameTheme.primary(ctx),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            'How clearly can you imagine it?',
            style: TextStyle(
              color: GameTheme.textSecondary(ctx),
              fontSize: 13.sp,
            ),
          ),
          SizedBox(height: 1.5.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              return GestureDetector(
                onTap: () =>
                    setState(() => _vividness = i + 1),
                child: AnimatedContainer(
                  duration:
                      const Duration(milliseconds: 200),
                  margin: EdgeInsets.symmetric(horizontal: 1.w),
                  width: 12.w,
                  height: 12.w,
                  decoration: BoxDecoration(
                    color: i < _vividness
                        ? GameTheme.accent(ctx)
                        : GameTheme.primary(ctx)
                            .withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: i < _vividness
                          ? GameTheme.accent(ctx)
                          : GameTheme.primary(ctx)
                              .withValues(alpha: 0.3),
                    ),
                  ),
                ),
              );
            }),
          ),
          SizedBox(height: 0.5.h),
          Text(
            ['Faint', 'Blurry', 'Clear', 'Vivid', 'Crystal'][
                _vividness - 1],
            style: TextStyle(
              color: GameTheme.accent(ctx),
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4.h),
          SizedBox(
            width: 70.w,
            child: ElevatedButton(
              onPressed: _nextSense,
              style: ElevatedButton.styleFrom(
                backgroundColor: GameTheme.primary(ctx),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 1.4.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _senseIdx < _senses.length - 1
                    ? 'Next Sense'
                    : 'Finish',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultScreen(BuildContext ctx) {
    final avgVividness =
        _totalVividness / _senses.length;
    return GameResultsScreen(
      gameIcon: '👁️',
      title: 'Senses Complete!',
      performance: avgVividness / 5.0,
      score: (avgVividness / 5.0 * 1000.0).round(),
      scoreLabel: 'Imagination',
      isNewBest: _isNewBest,
      stats: [
        GameResultStat(
            'Vividness', '${(avgVividness / 5.0 * 100).round()}%'),
        GameResultStat('Senses', '5/5'),
        GameResultStat('Brain', '🧠+'),
      ],
      onRetry: _startGame,
      onDone: () => Navigator.pop(context),
    );
  }
}
