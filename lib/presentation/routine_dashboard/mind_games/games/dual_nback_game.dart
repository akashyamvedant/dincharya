import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class DualNBackGame extends StatefulWidget {
  const DualNBackGame({super.key});
  @override
  State<DualNBackGame> createState() => _DualNBackGameState();
}

class _DualNBackGameState extends State<DualNBackGame> {
  final _service = MindGamesService(), _rng = Random();

  int _n = 2;            // N-back level
  int _round = 0;        // Current round number
  static const _totalRounds = 20;

  // History of positions and letters
  final List<int> _posHistory = [];
  final List<String> _letterHistory = [];

  // Current stimulus
  int _currentPos = -1;
  String _currentLetter = '';

  // Player responses
  bool _posMatchResponse = false;
  bool _letterMatchResponse = false;

  // Results
  int _posHits = 0, _posMisses = 0, _posFalseAlarms = 0;
  int _letterHits = 0, _letterMisses = 0, _letterFalseAlarms = 0;

  bool _showingStimulus = false;
  bool _waitingForResponse = false;
  bool _started = false, _done = false, _showingCountdown = false;
  bool _isNewBest = false;

  // 3x3 grid position indices: 0=top-left, ..., 8=bottom-right
  static const _gridPositions = 9;
  final _letters = const [
    'A','B','C','D','E','F','G','H','K','L','M','N','P','R','S','T','W','Y'
  ];

  @override
  void initState() {
    super.initState();
    _generateSequence();
  }

  void _generateSequence() {
    _posHistory.clear();
    _letterHistory.clear();

    for (int i = 0; i < _totalRounds + _n; i++) {
      _posHistory.add(_rng.nextInt(_gridPositions));
      _letterHistory.add(_letters[_rng.nextInt(_letters.length)]);
    }
  }

  void _start() {
    _generateSequence();
    _round = _n; // Start showing from index n (first comparable)
    _posHits = 0; _posMisses = 0; _posFalseAlarms = 0;
    _letterHits = 0; _letterMisses = 0; _letterFalseAlarms = 0;
    _currentPos = -1; _currentLetter = '';
    _posMatchResponse = false; _letterMatchResponse = false;
    _showingStimulus = false; _waitingForResponse = false;
    _done = false;
    setState(() => _showingCountdown = true);
  }

  void _countdownDone() {
    setState(() { _showingCountdown = false; _started = true; });
    _showStimulus();
  }

  void _showStimulus() {
    if (_round >= _posHistory.length) {
      _finish();
      return;
    }
    setState(() {
      _currentPos = _posHistory[_round];
      _currentLetter = _letterHistory[_round];
      _showingStimulus = true;
      _waitingForResponse = false;
      _posMatchResponse = false;
      _letterMatchResponse = false;
    });

    // Show for 2 seconds, then wait for response
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted && _started && !_done) {
        setState(() => _waitingForResponse = true);
      }
    });
  }

  bool get _isPosMatch =>
      _round >= _n && _posHistory[_round] == _posHistory[_round - _n];

  bool get _isLetterMatch =>
      _round >= _n && _letterHistory[_round] == _letterHistory[_round - _n];

  void _answerPosMatch() {
    if (!_waitingForResponse || _done) return;
    setState(() => _posMatchResponse = true);
  }

  void _answerLetterMatch() {
    if (!_waitingForResponse || _done) return;
    setState(() => _letterMatchResponse = true);
  }

  void _submitResponse() {
    if (!_waitingForResponse || _done) return;
    GameHaptics.tap();

    // Check position
    if (_isPosMatch) {
      if (_posMatchResponse) {
        _posHits++;
      } else {
        _posMisses++;
      }
    } else {
      if (_posMatchResponse) _posFalseAlarms++;
    }
    // Check letter
    if (_isLetterMatch) {
      if (_letterMatchResponse) {
        _letterHits++;
      } else {
        _letterMisses++;
      }
    } else {
      if (_letterMatchResponse) _letterFalseAlarms++;
    }

    setState(() { _round++; _waitingForResponse = false; _showingStimulus = false; });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && _started && !_done) _showStimulus();
    });
  }

  Future<void> _finish() async {
    _done = true; _started = false;
    GameHaptics.win();

    final totalPos = _posHits + _posMisses + _posFalseAlarms;
    final totalLetter = _letterHits + _letterMisses + _letterFalseAlarms;
    final posAccuracy = totalPos > 0 ? (_posHits / (totalPos)).clamp(0.0, 1.0) : 0.0;
    final letterAccuracy = totalLetter > 0 ? (_letterHits / (totalLetter)).clamp(0.0, 1.0) : 0.0;
    final composite = (posAccuracy + letterAccuracy) / 2;
    final score = (composite * 1000).round();

    await _service.saveScore(
        gameType: 'dual_nback', score: score.toDouble(),
        accuracy: composite, roundsCompleted: _totalRounds,
        metadata: {'n': _n, 'pos_hits': _posHits, 'letter_hits': _letterHits});
    _isNewBest = await _service.submitLocalBest('dual_nback', score.toDouble());
    await _service.addXp(15 + (composite * 30).round());
    if (mounted) setState(() {});
  }

  void _changeN(int delta) {
    _n = (_n + delta).clamp(1, 5);
    setState(() {});
  }

  Widget _buildGrid(BuildContext ctx) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3),
      itemCount: _gridPositions,
      itemBuilder: (_, idx) {
        final isActive = _showingStimulus && _currentPos == idx;
        final isPrevMatch = _isPosMatch && _currentPos == idx && _showingStimulus;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: EdgeInsets.all(1.w),
          decoration: BoxDecoration(
            color: isActive
                ? (isPrevMatch ? GameColors.gold : GameTheme.primary(ctx).withValues(alpha: 0.7))
                : GameTheme.surface(ctx).withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: isActive
                    ? Colors.white.withValues(alpha: 0.8)
                    : GameTheme.primary(ctx).withValues(alpha: 0.15)),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameTheme.bg(context),
      appBar: AppBar(
        backgroundColor: GameTheme.bg(context), elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: GameTheme.textPrimary(context)), onPressed: () => Navigator.pop(context)),
        title: Text('$_n-Back', style: TextStyle(color: GameTheme.textPrimary(context), fontSize: 16.sp, fontWeight: FontWeight.bold)), centerTitle: true,
      ),
      body: Stack(children: [
        if (!_started && !_done && !_showingCountdown) _startScreen(context),
        if (_showingCountdown) GameCountdown(onDone: _countdownDone),
        if (_started) _gameView(context),
        if (_done) _resultScreen(context),
      ]),
    );
  }

  Widget _startScreen(BuildContext ctx) => Center(child: SingleChildScrollView(padding: EdgeInsets.all(6.w), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    SizedBox(height: 4.h),
    Text('🔊', style: TextStyle(fontSize: 54.sp)), SizedBox(height: 3.h),
    Text('Dual N-Back', style: GameTheme.heading(ctx, size: 26)), SizedBox(height: 2.h),
    Text('Remember position AND letter from\n$_n steps ago. Gold square = position match.', textAlign: TextAlign.center,
        style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 14.sp, height: 1.5)),
    SizedBox(height: 3.h),
    Text('N-Level', style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 13.sp)),
    SizedBox(height: 1.h),
    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      IconButton(onPressed: () => _changeN(-1), icon: Icon(Icons.remove_circle_outline, color: GameTheme.primary(ctx)), iconSize: 28),
      Container(padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h), decoration: BoxDecoration(color: GameTheme.primary(ctx).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: GameTheme.primary(ctx).withValues(alpha: 0.3))), child: Text('$_n', style: TextStyle(color: GameTheme.primary(ctx), fontSize: 28.sp, fontWeight: FontWeight.bold))),
      IconButton(onPressed: () => _changeN(1), icon: Icon(Icons.add_circle_outline, color: GameTheme.primary(ctx)), iconSize: 28),
    ]),
    SizedBox(height: 1.h),
    Text('1=easy, 5=expert', style: TextStyle(color: GameTheme.textMuted(ctx), fontSize: 11.sp)),
    SizedBox(height: 4.h),
    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _start, style: ElevatedButton.styleFrom(backgroundColor: GameTheme.primary(ctx), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 1.6.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text('Start Training', style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold)))),
  ])));

  Widget _gameView(BuildContext ctx) {
    return SafeArea(
      child: Column(children: [
        // Header
        Padding(padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('$_n-Back', style: TextStyle(color: GameTheme.accent(ctx), fontSize: 16.sp, fontWeight: FontWeight.bold)),
            Text('Round ${_round - _n + 1}/$_totalRounds', style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 14.sp)),
            Text('Position: $_posHits✓ $_posMisses✗', style: TextStyle(color: GameTheme.textSecondary(ctx).withValues(alpha: 0.7), fontSize: 11.sp)),
          ])),
        // Grid (position stimulus)
        Expanded(
          flex: 3,
          child: Padding(padding: EdgeInsets.all(4.w),
            child: _buildGrid(ctx)),
        ),
        // Letter (letter stimulus)
        Expanded(
          flex: 1,
          child: Center(
            child: _showingStimulus
                ? AnimatedOpacity(
                    opacity: _showingStimulus ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Text(_currentLetter,
                        style: TextStyle(fontSize: 64.sp, fontWeight: FontWeight.w900,
                            color: _isLetterMatch ? GameColors.gold : GameTheme.textPrimary(ctx))))
                : SizedBox(height: 16.sp),
          ),
        ),
        // Response buttons
        if (_waitingForResponse && !_done)
          Padding(padding: EdgeInsets.all(4.w), child: Column(children: [
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: _answerPosMatch,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: EdgeInsets.symmetric(vertical: 2.h),
                    decoration: BoxDecoration(
                      color: _posMatchResponse ? GameColors.gold.withValues(alpha: 0.25) : GameTheme.surface(ctx),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _posMatchResponse ? GameColors.gold : GameTheme.primary(ctx).withValues(alpha: 0.3),
                          width: _posMatchResponse ? 2.5 : 1.5),
                    ),
                    child: Column(children: [
                      Icon(Icons.grid_view_rounded, color: _posMatchResponse ? GameColors.gold : GameTheme.textSecondary(ctx), size: 24),
                      SizedBox(height: 0.5.h),
                      Text('Position Match', style: TextStyle(color: _posMatchResponse ? GameColors.gold : GameTheme.textSecondary(ctx), fontSize: 12.sp, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: GestureDetector(
                  onTap: _answerLetterMatch,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: EdgeInsets.symmetric(vertical: 2.h),
                    decoration: BoxDecoration(
                      color: _letterMatchResponse ? GameColors.gold.withValues(alpha: 0.25) : GameTheme.surface(ctx),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _letterMatchResponse ? GameColors.gold : GameTheme.primary(ctx).withValues(alpha: 0.3),
                          width: _letterMatchResponse ? 2.5 : 1.5),
                    ),
                    child: Column(children: [
                      Icon(Icons.text_fields_rounded, color: _letterMatchResponse ? GameColors.gold : GameTheme.textSecondary(ctx), size: 24),
                      SizedBox(height: 0.5.h),
                      Text('Letter Match', style: TextStyle(color: _letterMatchResponse ? GameColors.gold : GameTheme.textSecondary(ctx), fontSize: 12.sp, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
            ]),
            SizedBox(height: 2.h),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: _submitResponse,
              style: ElevatedButton.styleFrom(backgroundColor: GameTheme.primary(ctx), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 1.4.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text('Submit', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold)),
            )),
          ])),
        if (!_waitingForResponse && _started)
          Padding(padding: EdgeInsets.all(4.w), child: Text('Watch the grid and letter...', style: TextStyle(color: GameTheme.textMuted(ctx), fontSize: 13.sp))),
      ]));
  }

  Widget _resultScreen(BuildContext ctx) {
    final posTotal = _posHits + _posMisses + _posFalseAlarms;
    final letterTotal = _letterHits + _letterMisses + _letterFalseAlarms;
    final posAcc = posTotal > 0 ? (_posHits / posTotal) : 0.0;
    final letAcc = letterTotal > 0 ? (_letterHits / letterTotal) : 0.0;
    final composite = (posAcc + letAcc) / 2;

    return GameResultsScreen(
      gameIcon: '🔊', title: 'Training Complete!',
      performance: composite, score: (composite * 1000).round(),
      scoreLabel: 'Dual Score',
      isNewBest: _isNewBest,
      stats: [
        GameResultStat('Pos', '${(posAcc * 100).round()}%'),
        GameResultStat('Letter', '${(letAcc * 100).round()}%'),
        GameResultStat('N-Level', '$_n'),
      ],
      onRetry: _start, onDone: () => Navigator.pop(context),
    );
  }
}
