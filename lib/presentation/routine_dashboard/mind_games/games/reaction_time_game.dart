// lib/presentation/routine_dashboard/mind_games/games/reaction_time_game.dart
// Simple reaction time — Red → Green → TAP! 5 trials.

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';

enum RTP { wait, ready, go, soon, done }

class ReactionTimeGame extends StatefulWidget {
  const ReactionTimeGame({super.key});
  @override
  State<ReactionTimeGame> createState() => _ReactionTimeGameState();
}

class _ReactionTimeGameState extends State<ReactionTimeGame> {
  final _rng = Random(), _service = MindGamesService();
  static const _trials = 5;

  RTP _p = RTP.wait;
  int _trial = 0, _best = 9999, _worst = 0, _total = 0;
  final List<int> _all = [];
  Timer? _timer;
  DateTime? _go;

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  void _start() { setState(() { _trial = 0; _best = 9999; _worst = 0; _total = 0; _all.clear(); }); _goTrial(); }
  void _goTrial() { setState(() => _p = RTP.ready); _timer?.cancel(); _timer = Timer(Duration(milliseconds: 1500 + _rng.nextInt(2500)), () { if (mounted) { setState(() => _p = RTP.go); _go = DateTime.now(); } }); }

  void _tap() {
    if (_p == RTP.ready) { _timer?.cancel(); setState(() => _p = RTP.soon); Timer(const Duration(seconds: 1), () { if (mounted) _goTrial(); }); return; }
    if (_p == RTP.go) {
      final rt = DateTime.now().difference(_go!).inMilliseconds; _all.add(rt); _total += rt; if (rt < _best) _best = rt; if (rt > _worst) _worst = rt;
      _trial++; if (_trial >= _trials) { _end(); } else { _goTrial(); }
    }
  }

  Future<void> _end() async { setState(() => _p = RTP.done); final avg = _total / _trials; await _service.saveScore(gameType: 'reaction_time', score: (1000 - avg).clamp(0.0, 1000.0), reactionTimeMs: avg.round(), roundsCompleted: _trials); }

  Color _bg(BuildContext ctx) => _p == RTP.ready ? Colors.red : _p == RTP.go ? GameColors.successGreen : _p == RTP.soon ? Colors.orange : GameTheme.bg(ctx);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _p == RTP.wait ? _start : _tap,
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: _bg(context),
        appBar: _p == RTP.wait || _p == RTP.done ? AppBar(backgroundColor: GameTheme.bg(context), elevation: 0, leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: GameTheme.textPrimary(context)), onPressed: () => Navigator.pop(context)), title: Text('Reaction Time', style: TextStyle(color: GameTheme.textPrimary(context), fontSize: 16.sp, fontWeight: FontWeight.bold)), centerTitle: true) : null,
        body: _p == RTP.wait ? _startScrn(context) : _p == RTP.done ? _result(context) : _play(context),
      ),
    );
  }

  Widget _startScrn(BuildContext ctx) => Center(child: Padding(padding: EdgeInsets.all(6.w), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Text('⏱️', style: TextStyle(fontSize: 56.sp)), SizedBox(height: 3.h),
    Text('Reaction Time', style: GameTheme.heading(ctx, size: 26)), SizedBox(height: 2.h),
    Text('Red = Wait.\nGreen = TAP as fast as you can!\n$_trials trials.', textAlign: TextAlign.center, style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 15.sp)), SizedBox(height: 4.h),
    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _start, style: ElevatedButton.styleFrom(backgroundColor: GameTheme.primary(ctx), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 1.8.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text('Tap to Start', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)))),
  ])));

  Widget _play(BuildContext ctx) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Text(_p == RTP.ready ? 'Wait...' : _p == RTP.go ? 'TAP NOW!' : 'Too soon!', style: TextStyle(fontSize: 40.sp, fontWeight: FontWeight.bold, color: Colors.white)),
    SizedBox(height: 2.h), Text('Trial ${_trial + 1}/$_trials', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14.sp)),
    if (_all.isNotEmpty) ...[SizedBox(height: 2.h), Text('Last: ${_all.last}ms', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16.sp))],
  ]));

  Widget _result(BuildContext ctx) {
    final avg = _total ~/ _trials; String r = avg < 250 ? '⚡ Lightning fast!' : avg < 350 ? '👍 Quick!' : avg < 500 ? '🙂 Average' : '🐢 Room to improve';
    return Center(child: Padding(padding: EdgeInsets.all(6.w), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('⏱️', style: TextStyle(fontSize: 48.sp)), SizedBox(height: 2.h),
      Text('Results', style: GameTheme.heading(ctx, size: 24)), SizedBox(height: 2.h),
      Text(r, style: TextStyle(color: GameTheme.textPrimary(ctx), fontSize: 18.sp)), SizedBox(height: 3.h),
      Container(padding: EdgeInsets.all(4.w), decoration: GameTheme.card(ctx), child: Column(children: [
        _row(ctx, 'Average', '${avg}ms'), SizedBox(height: 1.h), _row(ctx, 'Best', '${_best}ms'), SizedBox(height: 1.h), _row(ctx, 'Worst', '${_worst}ms'),
      ])), SizedBox(height: 2.h),
      Wrap(spacing: 2.w, runSpacing: 1.h, children: _all.map((rt) => Container(padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h), decoration: BoxDecoration(color: GameTheme.primary(ctx).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: GameTheme.primary(ctx).withValues(alpha: 0.2))), child: Text('${rt}ms', style: TextStyle(color: GameTheme.textPrimary(ctx), fontSize: 13.sp)))).toList()),
      SizedBox(height: 4.h),
      Row(children: [Expanded(child: OutlinedButton(onPressed: _start, style: OutlinedButton.styleFrom(foregroundColor: GameTheme.primary(ctx), side: BorderSide(color: GameTheme.primary(ctx).withValues(alpha: 0.5)), padding: EdgeInsets.symmetric(vertical: 1.5.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Retry', style: TextStyle(fontSize: 15.sp)))), SizedBox(width: 3.w), Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: GameTheme.primary(ctx), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 1.5.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Done', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold))))]),
    ])));
  }

  Widget _row(BuildContext ctx, String l, String v) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(l, style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 16.sp)),
    Text(v, style: TextStyle(color: GameTheme.accent(ctx), fontSize: 20.sp, fontWeight: FontWeight.bold)),
  ]);
}
