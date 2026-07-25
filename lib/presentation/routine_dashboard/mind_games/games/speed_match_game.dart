// lib/presentation/routine_dashboard/mind_games/games/speed_match_game.dart
// Rapid visual comparison — SAME or DIFFERENT? 20 rounds.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';

class SpeedMatchGame extends StatefulWidget {
  const SpeedMatchGame({super.key});
  @override
  State<SpeedMatchGame> createState() => _SpeedMatchGameState();
}

class _SpeedMatchGameState extends State<SpeedMatchGame> {
  final _rng = Random(), _service = MindGamesService();
  static const _total = 20, _syms = ['★', '●', '◆', '▲', '⬟', '⬢', '✿', '❖', '♣', '♥'];

  int _r = 0, _ok = 0, _ng = 0, _rt = 0;
  bool _same = false, _started = false, _done = false;
  String _l = '', _ri = '';
  DateTime? _t;

  void _start() { setState(() { _r = 0; _ok = 0; _ng = 0; _rt = 0; _started = true; _done = false; _gen(); }); }
  void _gen() { _same = _rng.nextBool(); final s = _syms[_rng.nextInt(_syms.length)]; _l = s; _ri = _same ? s : _syms.where((x) => x != s).toList()[_rng.nextInt(_syms.length - 1)]; _t = DateTime.now(); }

  void _ans(bool u) { if (_done) return; _rt += DateTime.now().difference(_t!).inMilliseconds; if (u == _same) _ok++; else _ng++; _r++; if (_r >= _total) { _end(); } else { _gen(); setState(() {}); } }

  Future<void> _end() async { setState(() => _done = true); await _service.saveScore(gameType: 'speed_match', score: (_ok * 5.0), accuracy: _ok / _total, reactionTimeMs: _rt ~/ _total, roundsCompleted: _total); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameTheme.bg(context),
      appBar: AppBar(backgroundColor: GameTheme.bg(context), elevation: 0, leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: GameTheme.textPrimary(context)), onPressed: () => Navigator.pop(context)), title: Text('Speed Match', style: TextStyle(color: GameTheme.textPrimary(context), fontSize: 16.sp, fontWeight: FontWeight.bold)), centerTitle: true),
      body: !_started ? _startScrn(context) : _done ? _result(context) : _game(context),
    );
  }

  Widget _startScrn(BuildContext ctx) => Center(child: Padding(padding: EdgeInsets.all(6.w), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Text('⚡', style: TextStyle(fontSize: 56.sp)), SizedBox(height: 3.h),
    Text('Speed Match', style: GameTheme.heading(ctx, size: 26)), SizedBox(height: 2.h),
    Text('Same or Different?\n$_total rounds. Answer fast!', textAlign: TextAlign.center, style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 15.sp)), SizedBox(height: 4.h),
    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _start, style: ElevatedButton.styleFrom(backgroundColor: GameTheme.primary(ctx), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 1.8.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text('Start', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)))),
  ])));

  Widget _game(BuildContext ctx) => Column(children: [
    Padding(padding: EdgeInsets.all(4.w), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('${_r + 1}/$_total', style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 13.sp)),
      Text('$_ok ✓', style: TextStyle(color: GameColors.successGreen, fontSize: 13.sp)),
    ])),
    ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: _r / _total, backgroundColor: GameTheme.primary(ctx).withValues(alpha: 0.12), valueColor: AlwaysStoppedAnimation(GameTheme.primary(ctx)), minHeight: 4)),
    Expanded(child: Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(_l, style: TextStyle(fontSize: 56.sp, color: GameTheme.textPrimary(ctx))),
      SizedBox(width: 8.w), Text('?', style: TextStyle(fontSize: 36.sp, color: GameTheme.textSecondary(ctx))), SizedBox(width: 8.w),
      Text(_ri, style: TextStyle(fontSize: 56.sp, color: GameTheme.textPrimary(ctx))),
    ]))),
    Padding(padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 6.h), child: Row(children: [
      Expanded(child: ElevatedButton(onPressed: () => _ans(true), style: ElevatedButton.styleFrom(backgroundColor: GameColors.successGreen.withValues(alpha: 0.2), foregroundColor: GameColors.successGreen, padding: EdgeInsets.symmetric(vertical: 2.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text('SAME ✅', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)))),
      SizedBox(width: 3.w), Expanded(child: ElevatedButton(onPressed: () => _ans(false), style: ElevatedButton.styleFrom(backgroundColor: GameColors.errorRed.withValues(alpha: 0.12), foregroundColor: GameColors.errorRed, padding: EdgeInsets.symmetric(vertical: 2.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text('DIFFERENT ❌', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)))),
    ])),
  ]);

  Widget _result(BuildContext ctx) => Center(child: Padding(padding: EdgeInsets.all(6.w), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Text('⚡', style: TextStyle(fontSize: 48.sp)), SizedBox(height: 2.h),
    Text('Complete!', style: GameTheme.heading(ctx, size: 24)), SizedBox(height: 3.h),
    Row(children: [_stat(ctx, '$_ok/$_total', 'Accuracy'), SizedBox(width: 3.w), _stat(ctx, '${_rt ~/ _total}ms', 'Avg Speed')]),
    SizedBox(height: 4.h),
    Row(children: [Expanded(child: OutlinedButton(onPressed: _start, style: OutlinedButton.styleFrom(foregroundColor: GameTheme.primary(ctx), side: BorderSide(color: GameTheme.primary(ctx).withValues(alpha: 0.5)), padding: EdgeInsets.symmetric(vertical: 1.5.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Retry', style: TextStyle(fontSize: 15.sp)))), SizedBox(width: 3.w), Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: GameTheme.primary(ctx), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 1.5.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Done', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold))))]),
  ])));

  Widget _stat(BuildContext ctx, String v, String l) => Expanded(child: Container(padding: EdgeInsets.all(3.w), decoration: GameTheme.card(ctx), child: Column(children: [Text(v, style: TextStyle(color: GameTheme.accent(ctx), fontSize: 24.sp, fontWeight: FontWeight.bold)), Text(l, style: TextStyle(color: GameTheme.textPrimary(ctx).withValues(alpha: 0.6), fontSize: 12.sp))])));
}
