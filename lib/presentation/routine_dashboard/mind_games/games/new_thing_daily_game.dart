import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class NewThingDailyGame extends StatefulWidget {
  const NewThingDailyGame({super.key});
  @override
  State<NewThingDailyGame> createState() => _NewThingDailyGameState();
}

class _NewThingDailyGameState extends State<NewThingDailyGame> {
  final _service = MindGamesService();

  final _controller = TextEditingController();
  bool _started = false;
  bool _showingCountdown = false;
  bool _isDone = false;
  bool _isNewBest = false;
  int _streak = 0;

  static const _ideas = [
    'Learn a new word',
    'Try a new recipe',
    'Walk a different route',
    'Read a new book',
    'Learn a yoga pose',
    'Write with your other hand',
    'Talk to a stranger',
    'Try a new fruit',
    'Listen to new music',
    'Sketch something',
    'Read a Sanskrit shloka',
    'Try meditation',
    'Learn a new skill',
    'Visit a new place',
    'Cook without a recipe',
  ];

  @override
  void initState() {
    super.initState();
    _loadStreak();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadStreak() async {
    _streak = await _service.getStreak();
    if (mounted) {
      setState(() {});
    }
  }

  void _startGame() {
    _controller.clear();
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

  Future<void> _submit() async {
    if (_controller.text.trim().isEmpty) {
      return;
    }
    _isDone = true;
    _started = false;

    const finalScore = 400.0;
    await _service.saveScore(
      gameType: 'new_thing_daily',
      score: finalScore,
      accuracy: 1.0,
      roundsCompleted: 1,
      metadata: {'entry': _controller.text.trim()},
    );
    _isNewBest =
        await _service.submitLocalBest('new_thing_daily', finalScore);
    await _service.markGamePlayed();
    await _service.addXp(10);
    _streak = await _service.getStreak();
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
          'New Thing Daily',
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
      child: SingleChildScrollView(
        padding: EdgeInsets.all(6.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🌱', style: TextStyle(fontSize: 40.sp)),
            SizedBox(height: 3.h),
            Text('New Thing Daily',
                style: GameTheme.heading(ctx, size: 26)),
            SizedBox(height: 2.h),
            Text(
              'Every day, do or learn\nONE new thing.\n\nWrite what you did today.\nBuilds neuroplasticity!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: GameTheme.textSecondary(ctx),
                fontSize: 14.sp,
                height: 1.5,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              'Streak: $_streak days',
              style: TextStyle(
                color: GameColors.gold,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              'Need ideas?',
              style: TextStyle(
                color: GameTheme.textSecondary(ctx),
                fontSize: 12.sp,
              ),
            ),
            SizedBox(height: 1.h),
            Wrap(
              spacing: 2.w,
              runSpacing: 1.h,
              alignment: WrapAlignment.center,
              children: _ideas.take(6).map((idea) {
                return GestureDetector(
                  onTap: () =>
                      _controller.text = idea,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 3.w, vertical: 1.h),
                    decoration: BoxDecoration(
                      color: GameTheme.primary(ctx)
                          .withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                    child: Text(
                      idea,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: GameTheme.textSecondary(
                            ctx),
                      ),
                    ),
                  ),
                );
              }).toList(),
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
                  'Log Today\'s New Thing',
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
      child: Padding(
        padding: EdgeInsets.all(6.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '🌱',
              style: TextStyle(fontSize: 36.sp),
            ),
            SizedBox(height: 2.h),
            Text(
              'What new thing did you\ndo or learn today?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: GameTheme.textPrimary(ctx),
              ),
            ),
            SizedBox(height: 3.h),
            TextField(
              controller: _controller,
              maxLines: 3,
              style: TextStyle(
                color: GameTheme.textPrimary(ctx),
                fontSize: 16.sp,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. Learned to make chai...',
                hintStyle: TextStyle(
                  color: GameTheme.textMuted(ctx),
                  fontSize: 14.sp,
                ),
                filled: true,
                fillColor:
                    GameTheme.surface(ctx).withValues(alpha: 0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: GameTheme.primary(ctx)
                          .withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: GameTheme.accent(ctx), width: 2),
                ),
              ),
            ),
            SizedBox(height: 3.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GameTheme.primary(ctx),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 1.6.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Submit',
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

  Widget _resultScreen(BuildContext ctx) {
    return GameResultsScreen(
      gameIcon: '🌱',
      title: 'New Thing Logged!',
      performance: 1.0,
      score: 400,
      scoreLabel: 'Growth Score',
      isNewBest: _isNewBest,
      stats: [
        GameResultStat('Today', _controller.text),
        GameResultStat('Streak', '$_streak days'),
        GameResultStat('Brain', '🧠+'),
      ],
      onRetry: () {
        _controller.clear();
        _startGame();
      },
      onDone: () => Navigator.pop(context),
    );
  }
}
