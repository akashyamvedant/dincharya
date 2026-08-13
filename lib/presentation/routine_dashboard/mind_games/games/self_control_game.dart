import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class SelfControlGame extends StatefulWidget {
  const SelfControlGame({super.key});
  @override
  State<SelfControlGame> createState() => _SelfControlGameState();
}

class _SelfControlGameState extends State<SelfControlGame> {
  final _service = MindGamesService();

  static const _challenges = [
    ('🍬', 'No sugar today', 'Avoid all sweets and sugar'),
    ('📱', 'Phone limit', 'Max 30 min social media'),
    ('😤', 'No anger', 'Respond calmly all day'),
    ('🗣️', 'No gossip', 'Speak only positively'),
    ('🍽️', 'Fast today', 'Skip one meal mindfully'),
    ('☕', 'No caffeine', 'No tea/coffee today'),
    ('🛏️', 'Early wake', 'Wake at 5 AM today'),
    ('🧘', 'Extra meditation', 'Double meditation time'),
  ];

  int _selectedChallenge = 0;
  bool _started = false;
  bool _showingCountdown = false;
  bool _isDone = false;
  bool _isNewBest = false;
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _loadStreak();
  }

  Future<void> _loadStreak() async {
    _streak = await _service.getStreak();
    if (mounted) {
      setState(() {});
    }
  }

  void _startGame() {
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

  Future<void> _markDone() async {
    _isDone = true;
    _started = false;

    const finalScore = 600.0;
    await _service.saveScore(
      gameType: 'self_control',
      score: finalScore,
      accuracy: 1.0,
      roundsCompleted: 1,
      metadata: {
        'challenge': _challenges[_selectedChallenge].$2,
      },
    );
    _isNewBest =
        await _service.submitLocalBest('self_control', finalScore);
    await _service.markGamePlayed();
    await _service.addXp(15);
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
          'Self Control',
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
            Text('🧘', style: TextStyle(fontSize: 40.sp)),
            SizedBox(height: 3.h),
            Text('Higher Self Control',
                style: GameTheme.heading(ctx, size: 26)),
            SizedBox(height: 2.h),
            Text(
              'Practice self-restraint.\nPick a challenge and\nstick to it for the day.\nStrength comes from saying NO.',
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
            SizedBox(height: 2.h),
            Text(
              'Choose challenge:',
              style: TextStyle(
                color: GameTheme.textSecondary(ctx),
                fontSize: 13.sp,
              ),
            ),
            SizedBox(height: 2.h),
            ...List.generate(_challenges.length, (i) {
              final (emoji, title, desc) =
                  _challenges[i];
              final sel = _selectedChallenge == i;
              return GestureDetector(
                onTap: () => setState(
                    () => _selectedChallenge = i),
                child: Container(
                  width: double.infinity,
                  margin:
                      EdgeInsets.only(bottom: 1.2.h),
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: sel
                        ? GameTheme.primary(ctx)
                            .withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius:
                        BorderRadius.circular(12),
                    border: Border.all(
                      color: sel
                          ? GameTheme.primary(ctx)
                          : GameTheme.primary(ctx)
                              .withValues(alpha: 0.15),
                      width: sel ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        emoji,
                        style: TextStyle(fontSize: 24.sp),
                      ),
                      SizedBox(width: 3.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight:
                                    FontWeight.w600,
                                color: GameTheme
                                    .textPrimary(ctx),
                              ),
                            ),
                            Text(
                              desc,
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: GameTheme
                                    .textMuted(ctx),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (sel)
                        Icon(
                          Icons.check_circle,
                          color: GameTheme
                              .primary(ctx),
                          size: 20,
                        ),
                    ],
                  ),
                ),
              );
            }),
            SizedBox(height: 2.h),
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
                  'Accept Challenge',
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
    final (emoji, title, desc) =
        _challenges[_selectedChallenge];
    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            emoji,
            style: TextStyle(fontSize: 42.sp),
          ),
          SizedBox(height: 3.h),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 5.w),
            padding: EdgeInsets.all(6.w),
            decoration: GameTheme.heroCard(ctx),
            child: Column(
              children: [
                Text(
                  'Your Challenge:',
                  style: TextStyle(
                    color: GameTheme.textSecondary(ctx),
                    fontSize: 12.sp,
                  ),
                ),
                SizedBox(height: 1.5.h),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: GameTheme.primary(ctx),
                  ),
                ),
                SizedBox(height: 1.h),
                Text(
                  desc,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: GameTheme.textSecondary(ctx),
                    fontSize: 14.sp,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            'You have the power to say NO.\nStay strong all day.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.sp,
              color: GameTheme.textPrimary(ctx),
              height: 1.5,
            ),
          ),
          SizedBox(height: 4.h),
          SizedBox(
            width: 70.w,
            child: ElevatedButton(
              onPressed: _markDone,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    GameColors.successGreen,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 1.6.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'I Did It!',
                style: TextStyle(
                  fontSize: 18.sp,
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
    return GameResultsScreen(
      gameIcon: '🧘',
      title: 'Self Control Mastered!',
      performance: 1.0,
      score: 600,
      scoreLabel: 'Willpower',
      isNewBest: _isNewBest,
      stats: [
        GameResultStat(
            'Challenge', _challenges[_selectedChallenge].$2),
        GameResultStat('Streak', '$_streak days'),
        GameResultStat('XP', '+15'),
      ],
      onRetry: () {
        _selectedChallenge = 0;
        _startGame();
      },
      onDone: () => Navigator.pop(context),
    );
  }
}
