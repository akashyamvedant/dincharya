// Sprint 2.5 — Hand Gesture Switch 🖐️
// "एक हाथ में मुट्ठी, दूसरे में V — SWITCH!"
// User sees left-hand ✊ + right-hand ✌️. On beep → switch.

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';

class HandGestureSwitchGame extends StatefulWidget {
  const HandGestureSwitchGame({super.key});
  @override
  State<HandGestureSwitchGame> createState() => _HandGestureSwitchGameState();
}

class _HandGestureSwitchGameState extends State<HandGestureSwitchGame> {
  final _rng = Random(), _svc = MindGamesService();
  static const _rounds = 10;
  static const _gestures = ['✊', '✌️', '✋', '👆']; // fist, V, open palm, point

  int _r = 0, _ok = 0, _totalMs = 0;
  int _leftG = 0, _rightG = 1; // current gesture indices
  bool _shouldSwitch = false, _started = false, _done = false;
  DateTime? _showTime;
  Timer? _switchTimer;

  @override
  void dispose() { _switchTimer?.cancel(); super.dispose(); }

  void _start() {
    setState(() { _r = 0; _ok = 0; _totalMs = 0; _started = true; _done = false; });
    _nextRound();
  }

  void _nextRound() {
    _leftG = _rng.nextInt(_gestures.length);
    do { _rightG = _rng.nextInt(_gestures.length); } while (_rightG == _leftG);
    _shouldSwitch = _rng.nextDouble() > 0.5;
    _showTime = DateTime.now();
    setState(() {});

    if (_shouldSwitch) {
      _switchTimer?.cancel();
      final delay = 800 + _rng.nextInt(1200); // 0.8-2.0 seconds
      _switchTimer = Timer(Duration(milliseconds: delay), () {
        if (mounted && _started && !_done) {
          final t = _leftG; _leftG = _rightG; _rightG = t;
          setState(() {});
        }
      });
    }
  }

  void _tapSwitch() {
    if (_done || !_started) return;
    final rt = DateTime.now().difference(_showTime!).inMilliseconds;
    _switchTimer?.cancel();

    if (_shouldSwitch) {
      // User was supposed to notice the auto-switch and tap
      _ok++; _totalMs += rt;
    } else {
      // User tapped too soon — no switch was coming
    }
    _r++;
    if (_r >= _rounds) { _finish(); } else { _nextRound(); }
  }

  void _tapWait() {
    if (_done || !_started) return;
    if (!_shouldSwitch) {
      _ok++; // Correct — waited when no switch was coming
    }
    _r++;
    if (_r >= _rounds) { _finish(); } else { _nextRound(); }
  }

  Future<void> _finish() async {
    setState(() => _done = true); _switchTimer?.cancel();
    final acc = _ok / _rounds; final avgMs = _ok > 0 ? _totalMs ~/ _ok : 0;
    await _svc.saveScore(gameType: 'hand_gesture', score: (_ok * 10.0), accuracy: acc, reactionTimeMs: avgMs, roundsCompleted: _rounds);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameTheme.bg(context),
      appBar: AppBar(backgroundColor: GameTheme.bg(context), elevation: 0, leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: GameTheme.textPrimary(context)), onPressed: () => Navigator.pop(context)), title: Text('Gesture Switch', style: TextStyle(color: GameTheme.textPrimary(context), fontSize: 16.sp, fontWeight: FontWeight.bold)), centerTitle: true),
      body: !_started ? _startScrn(context) : _done ? _result(context) : _game(context),
    );
  }

  Widget _startScrn(BuildContext ctx) => Center(child: Padding(padding: EdgeInsets.all(6.w), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 60, height: 60, decoration: BoxDecoration(shape: BoxShape.circle, color: GameTheme.primary(ctx).withValues(alpha: 0.1)), child: Center(child: Text('✊', style: TextStyle(fontSize: 28.sp)))),
      SizedBox(width: 4.w),
      Text('↔️', style: TextStyle(fontSize: 24.sp, color: GameTheme.accent(ctx))),
      SizedBox(width: 4.w),
      Container(width: 60, height: 60, decoration: BoxDecoration(shape: BoxShape.circle, color: GameTheme.primary(ctx).withValues(alpha: 0.1)), child: Center(child: Text('✌️', style: TextStyle(fontSize: 28.sp)))),
    ]),
    SizedBox(height: 3.h),
    Text('Hand Gesture Switch', style: GameTheme.heading(ctx, size: 22)), SizedBox(height: 2.h),
    Text('Hands switch randomly!\nTap SWITCH when they change.\nWait if they stay the same.', textAlign: TextAlign.center, style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 15.sp)), SizedBox(height: 4.h),
    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _start, style: ElevatedButton.styleFrom(backgroundColor: GameTheme.primary(ctx), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 1.8.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text('Start', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)))),
  ])));

  Widget _game(BuildContext ctx) => Padding(
    padding: EdgeInsets.all(4.w),
    child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('${_r + 1}/$_rounds', style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 14.sp)),
        Text('$_ok ✓', style: TextStyle(color: GameColors.successGreen, fontSize: 14.sp, fontWeight: FontWeight.w600)),
      ]),
      SizedBox(height: 1.h),
      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: _r / _rounds, backgroundColor: GameTheme.primary(ctx).withValues(alpha: 0.12), valueColor: AlwaysStoppedAnimation(GameTheme.primary(ctx)), minHeight: 4)),
      Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Column(children: [Text('LEFT', style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 12.sp)), SizedBox(height: 1.h), _hand(ctx, _gestures[_leftG], 'L')]),
          SizedBox(width: 8.w),
          Text('↕️', style: TextStyle(fontSize: 28.sp, color: GameTheme.accent(ctx))),
          SizedBox(width: 8.w),
          Column(children: [Text('RIGHT', style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 12.sp)), SizedBox(height: 1.h), _hand(ctx, _gestures[_rightG], 'R')]),
        ]),
      ]))),
      Padding(padding: EdgeInsets.fromLTRB(2.w, 0, 2.w, 6.h), child: Row(children: [
        Expanded(child: ElevatedButton(onPressed: _tapSwitch, style: ElevatedButton.styleFrom(backgroundColor: GameColors.successGreen.withValues(alpha: 0.15), foregroundColor: GameColors.successGreen, padding: EdgeInsets.symmetric(vertical: 2.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text('SWITCH!', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)))),
        SizedBox(width: 3.w),
        Expanded(child: OutlinedButton(onPressed: _tapWait, style: OutlinedButton.styleFrom(foregroundColor: GameTheme.textSecondary(ctx), side: BorderSide(color: GameTheme.textSecondary(ctx).withValues(alpha: 0.3)), padding: EdgeInsets.symmetric(vertical: 2.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text('WAIT', style: TextStyle(fontSize: 18.sp)))),
      ])),
    ]),
  );

  Widget _hand(BuildContext ctx, String gesture, String side) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    width: 70,
    height: 70,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: GameTheme.accent(ctx).withValues(alpha: 0.1),
      border: Border.all(color: GameTheme.accent(ctx).withValues(alpha: 0.3), width: 2),
    ),
    child: Center(child: Text(gesture, style: TextStyle(fontSize: 32.sp))),
  );

  Widget _result(BuildContext ctx) {
    final acc = (_ok / _rounds * 100).round();
    return Center(child: Padding(padding: EdgeInsets.all(6.w), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('🖐️', style: TextStyle(fontSize: 48.sp)), SizedBox(height: 2.h),
      Text('Complete!', style: GameTheme.heading(ctx, size: 24)), SizedBox(height: 3.h),
      Container(padding: EdgeInsets.all(4.w), decoration: GameTheme.card(ctx), child: Column(children: [
        Text('$_ok / $_rounds', style: TextStyle(color: GameTheme.accent(ctx), fontSize: 36.sp, fontWeight: FontWeight.bold)),
        Text('$acc% accuracy', style: TextStyle(color: GameTheme.textPrimary(ctx).withValues(alpha: 0.5), fontSize: 14.sp)),
      ])),
      SizedBox(height: 3.h),
      Text('Train bimanual coordination 🧠', style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 13.sp)),
      SizedBox(height: 3.h),
      Row(children: [Expanded(child: OutlinedButton(onPressed: _start, style: OutlinedButton.styleFrom(foregroundColor: GameTheme.primary(ctx), side: BorderSide(color: GameTheme.primary(ctx).withValues(alpha: 0.5)), padding: EdgeInsets.symmetric(vertical: 1.5.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Retry', style: TextStyle(fontSize: 15.sp)))), SizedBox(width: 3.w), Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: GameTheme.primary(ctx), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 1.5.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Done', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold))))]),
    ])));
  }
}
