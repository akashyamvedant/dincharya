// Sprint 2.6 — Blind Fold Challenge 👁️‍🗨️
// "Close your eyes. Tap the specified zone. Draw shapes blind."

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';

class BlindFoldChallengeGame extends StatefulWidget {
  const BlindFoldChallengeGame({super.key});
  @override
  State<BlindFoldChallengeGame> createState() => _BlindFoldChallengeGameState();
}

class _BlindFoldChallengeGameState extends State<BlindFoldChallengeGame> {
  final _rng = Random(), _svc = MindGamesService();
  static const _tasks = 5;

  int _t = 0, _score = 0, _totalMs = 0;
  String _instruction = '';
  bool _blind = false, _started = false, _done = false;
  DateTime? _startT;
  Offset? _tapPos;
  List<Offset> _drawPath = [];

  static const _zones = {
    'TOP-LEFT': Rect.fromLTWH(0, 0, 0.5, 0.5),
    'TOP-RIGHT': Rect.fromLTWH(0.5, 0, 0.5, 0.5),
    'BOTTOM-LEFT': Rect.fromLTWH(0, 0.5, 0.5, 0.5),
    'BOTTOM-RIGHT': Rect.fromLTWH(0.5, 0.5, 0.5, 0.5),
    'CENTER': Rect.fromLTWH(0.25, 0.25, 0.5, 0.5),
  };

  static const _shapes = ['circle', 'square', 'triangle'];

  void _start() {
    setState(() { _t = 0; _score = 0; _totalMs = 0; _started = true; _done = false; _blind = false; _tapPos = null; _drawPath = []; });
    _nextTask();
  }

  void _nextTask() {
    _blind = false; _tapPos = null; _drawPath = [];
    if (_t.isEven) {
      // Tap challenge
      _instruction = _zones.keys.toList()[_rng.nextInt(_zones.keys.length)];
    } else {
      // Draw challenge
      _instruction = _shapes[_rng.nextInt(_shapes.length)];
    }
    _startT = DateTime.now();
    setState(() {});
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _started && !_done) setState(() => _blind = true);
    });
  }

  void _onTapUp(TapUpDetails d, Size screen) {
    if (_done || !_blind) return;
    final pos = Offset(d.localPosition.dx / screen.width, d.localPosition.dy / screen.height);

    if (_t.isEven) {
      // Tap challenge — did they hit the right zone?
      final zone = _zones[_instruction]!;
      final hit = zone.contains(pos);
      if (hit) _score += 3; else _score += 1;
      _tapPos = d.localPosition;
      setState(() {});
    }
    final ms = DateTime.now().difference(_startT!).inMilliseconds; _totalMs += ms;
    _t++;
    if (_t >= _tasks) { _finish(); } else {
      Future.delayed(const Duration(milliseconds: 1200), _nextTask);
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_blind && _t.isOdd) {
      _drawPath.add(d.localPosition);
      setState(() {});
    }
  }

  void _onPanEnd(DragEndDetails d) {
    if (_t.isOdd && _blind) {
      final pos = _tapPos ?? Offset.zero;
      final shape = _instruction;
      int pts = 0;

      if (_drawPath.length > 20) pts = 2; // they drew something
      // Rough shape scoring
      if (shape == 'circle' && _drawPath.length > 30) pts = 3;
      if (shape == 'square' && _drawPath.length > 20) pts = 2;
      if (shape == 'triangle' && _drawPath.length > 15) pts = 2;

      _score += pts;
      final ms = DateTime.now().difference(_startT!).inMilliseconds; _totalMs += ms;
      _t++;
      if (_t >= _tasks) { _finish(); } else {
        Future.delayed(const Duration(milliseconds: 1200), _nextTask);
      }
    }
  }

  Future<void> _finish() async {
    setState(() => _done = true);
    await _svc.saveScore(gameType: 'blind_fold', score: _score.toDouble(), accuracy: _score / (_tasks * 3.0), roundsCompleted: _tasks);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapUp: (d) { final s = MediaQuery.of(context).size; _onTapUp(d, s); },
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Scaffold(
        backgroundColor: _blind ? Colors.black : GameTheme.bg(context),
        appBar: AppBar(backgroundColor: GameTheme.bg(context), elevation: 0, leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: GameTheme.textPrimary(context)), onPressed: () => Navigator.pop(context)), title: Text('Blind Fold', style: TextStyle(color: GameTheme.textPrimary(context), fontSize: 16.sp, fontWeight: FontWeight.bold)), centerTitle: true),
        body: !_started ? _startScrn(context) : _done ? _result(context) : _game(context),
      ),
    );
  }

  Widget _startScrn(BuildContext ctx) => Center(child: Padding(padding: EdgeInsets.all(6.w), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Text('👁️‍🗨️', style: TextStyle(fontSize: 56.sp)), SizedBox(height: 3.h),
    Text('Blind Fold Challenge', style: GameTheme.heading(ctx, size: 24)), SizedBox(height: 2.h),
    Text('Close your eyes (or face away).\nTap where instructed.\nDraw shapes blind!', textAlign: TextAlign.center, style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 15.sp)),
    SizedBox(height: 3.h),
    Container(padding: EdgeInsets.all(3.w), decoration: GameTheme.card(ctx), child: Text('🧠 Neurobic exercise — creates new neural pathways!', textAlign: TextAlign.center, style: TextStyle(color: GameColors.brainPurple, fontSize: 13.sp, fontWeight: FontWeight.w600))),
    SizedBox(height: 4.h),
    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _start, style: ElevatedButton.styleFrom(backgroundColor: GameTheme.primary(ctx), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 1.8.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text('Start', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)))),
  ])));

  Widget _game(BuildContext ctx) {
    return Stack(
      children: [
        // Content area
        Center(
          child: AnimatedOpacity(
            opacity: _blind ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_t.isEven) ...[
                  Text('TAP', style: TextStyle(color: GameTheme.accent(ctx), fontSize: 20.sp, fontWeight: FontWeight.bold)),
                  SizedBox(height: 1.h),
                  Text(_instruction, style: TextStyle(color: GameTheme.textPrimary(ctx), fontSize: 28.sp, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2.h),
                  _buildZoneMap(ctx),
                ] else ...[
                  Text('DRAW', style: TextStyle(color: GameTheme.accent(ctx), fontSize: 20.sp, fontWeight: FontWeight.bold)),
                  SizedBox(height: 1.h),
                  Text(_instruction.toUpperCase(), style: TextStyle(color: GameTheme.textPrimary(ctx), fontSize: 28.sp, fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ),
        ),
        // Blind overlay (tappable)
        if (_blind) Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🧠', style: TextStyle(fontSize: 36.sp)),
                SizedBox(height: 1.h),
                Text(_t.isEven ? 'Tap $_instruction' : 'Draw a $_instruction',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 18.sp)),
                SizedBox(height: 2.h),
                if (_tapPos != null && _t.isEven)
                  Icon(Icons.check_circle, color: GameColors.successGreen, size: 40),
                // Draw path visualization
                if (_drawPath.isNotEmpty)
                  Text('✏️ Drawing...', style: TextStyle(color: Colors.white38, fontSize: 14.sp)),
              ],
            ),
          ),
        ),
        // Progress
        Positioned(top: 2.h, left: 0, right: 0, child: Center(
          child: Text('${_t + 1}/$_tasks', style: TextStyle(color: _blind ? Colors.white38 : GameTheme.textSecondary(ctx), fontSize: 13.sp)),
        )),
      ],
    );
  }

  Widget _buildZoneMap(BuildContext ctx) {
    return Container(
      width: 50.w,
      height: 50.w,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GameTheme.primary(ctx).withValues(alpha: 0.2)),
      ),
      child: Stack(
        children: _zones.entries.map((e) {
          final z = e.value;
          final isTarget = e.key == _instruction;
          return Positioned(
            left: z.left * 50.w,
            top: z.top * 50.w,
            width: z.width * 50.w,
            height: z.height * 50.w,
            child: Container(
              decoration: BoxDecoration(
                color: isTarget ? GameTheme.accent(ctx).withValues(alpha: 0.3) : GameTheme.primary(ctx).withValues(alpha: 0.05),
                border: Border.all(color: isTarget ? GameTheme.accent(ctx).withValues(alpha: 0.6) : GameTheme.primary(ctx).withValues(alpha: 0.1), width: isTarget ? 2 : 0.5),
              ),
              child: Center(child: Text(e.key, style: TextStyle(color: isTarget ? GameTheme.accent(ctx) : GameTheme.textSecondary(ctx).withValues(alpha: 0.3), fontSize: 8.sp))),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _result(BuildContext ctx) => Center(child: Padding(padding: EdgeInsets.all(6.w), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Text('👁️‍🗨️', style: TextStyle(fontSize: 48.sp)), SizedBox(height: 2.h),
    Text('Challenge Complete!', style: GameTheme.heading(ctx, size: 24)), SizedBox(height: 2.h),
    Container(padding: EdgeInsets.all(4.w), decoration: GameTheme.card(ctx), child: Column(children: [
      Text('$_score / ${_tasks * 3}', style: TextStyle(color: GameTheme.accent(ctx), fontSize: 36.sp, fontWeight: FontWeight.bold)),
      Text('Score', style: TextStyle(color: GameTheme.textPrimary(ctx).withValues(alpha: 0.5), fontSize: 13.sp)),
    ])),
    SizedBox(height: 3.h),
    Container(padding: EdgeInsets.all(3.w), decoration: GameTheme.card(ctx), child: Text('🧠 Spatial memory + sensory integration\nBlind exercises build new neural pathways!', textAlign: TextAlign.center, style: TextStyle(color: GameColors.brainPurple, fontSize: 12.sp))),
    SizedBox(height: 4.h),
    Row(children: [Expanded(child: OutlinedButton(onPressed: _start, style: OutlinedButton.styleFrom(foregroundColor: GameTheme.primary(ctx), side: BorderSide(color: GameTheme.primary(ctx).withValues(alpha: 0.5)), padding: EdgeInsets.symmetric(vertical: 1.5.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Retry', style: TextStyle(fontSize: 15.sp)))), SizedBox(width: 3.w), Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: GameTheme.primary(ctx), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 1.5.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Done', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold))))]),
  ])));
}
