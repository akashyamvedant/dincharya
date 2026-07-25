// Sprint 2.4 — Quick Math
// Rapid arithmetic. 15 problems. + → - → × → mix.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';

class QuickMathGame extends StatefulWidget {
  const QuickMathGame({super.key});
  @override
  State<QuickMathGame> createState() => _QuickMathGameState();
}

class _QuickMathGameState extends State<QuickMathGame> {
  final _rng = Random(), _svc = MindGamesService();
  static const _total = 15;
  int _q = 0, _ok = 0, _totalMs = 0;
  int _a = 0, _b = 0, _ans = 0; String _op = '+';
  final _tc = TextEditingController();
  final _fn = FocusNode();
  bool _started = false, _done = false; DateTime? _t;

  @override
  void dispose() { _tc.dispose(); _fn.dispose(); super.dispose(); }

  void _start() { setState(() { _q = 0; _ok = 0; _totalMs = 0; _started = true; _done = false; _gen(); }); }

  void _gen() {
    final types = ['+', '-', '×'];
    _op = types[_rng.nextInt(types.length)];
    switch (_op) {
      case '+': _a = _rng.nextInt(50) + 10; _b = _rng.nextInt(50) + 5; _ans = _a + _b; break;
      case '-': _a = _rng.nextInt(80) + 20; _b = _rng.nextInt(_a); _ans = _a - _b; break;
      case '×': _a = _rng.nextInt(12) + 2; _b = _rng.nextInt(12) + 2; _ans = _a * _b; break;
    }
    _tc.clear(); _t = DateTime.now();
    Future.delayed(const Duration(milliseconds: 100), () => _fn.requestFocus());
    setState(() {});
  }

  void _submit(String v) {
    if (_done) return;
    final ms = DateTime.now().difference(_t!).inMilliseconds; _totalMs += ms;
    final parsed = int.tryParse(v.trim());
    if (parsed == _ans) _ok++;
    _q++;
    if (_q >= _total) { _finish(); } else { _gen(); }
  }

  Future<void> _finish() async {
    setState(() => _done = true); _fn.unfocus();
    final avg = _totalMs ~/ _total; final acc = _ok / _total;
    await _svc.saveScore(gameType: 'quick_math', score: (_ok * 100.0 / _total), accuracy: acc, reactionTimeMs: avg, roundsCompleted: _total);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameTheme.bg(context),
      appBar: AppBar(backgroundColor: GameTheme.bg(context), elevation: 0, leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: GameTheme.textPrimary(context)), onPressed: () => Navigator.pop(context)), title: Text('Quick Math', style: TextStyle(color: GameTheme.textPrimary(context), fontSize: 16.sp, fontWeight: FontWeight.bold)), centerTitle: true),
      body: !_started ? _startScrn(context) : _done ? _result(context) : _game(context),
    );
  }

  Widget _startScrn(BuildContext ctx) => Center(child: Padding(padding: EdgeInsets.all(6.w), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Text('🔢', style: TextStyle(fontSize: 56.sp)), SizedBox(height: 3.h),
    Text('Quick Math', style: GameTheme.heading(ctx, size: 26)), SizedBox(height: 2.h),
    Text('Solve $_total problems as fast as you can.\nAddition, subtraction & multiplication.', textAlign: TextAlign.center, style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 15.sp)), SizedBox(height: 4.h),
    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _start, style: ElevatedButton.styleFrom(backgroundColor: GameTheme.primary(ctx), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 1.8.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text('Start', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)))),
  ])));

  Widget _game(BuildContext ctx) => Column(children: [
    Padding(padding: EdgeInsets.all(4.w), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('${_q + 1}/$_total', style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 14.sp)),
      Text('$_ok ✓', style: TextStyle(color: GameColors.successGreen, fontSize: 14.sp, fontWeight: FontWeight.w600)),
    ])),
    ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: _q / _total, backgroundColor: GameTheme.primary(ctx).withValues(alpha: 0.12), valueColor: AlwaysStoppedAnimation(GameTheme.primary(ctx)), minHeight: 4)),
    Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('$_a $_op $_b = ?', style: TextStyle(color: GameTheme.textPrimary(ctx), fontSize: 40.sp, fontWeight: FontWeight.bold)),
      SizedBox(height: 4.h),
      SizedBox(width: 50.w, child: TextField(controller: _tc, focusNode: _fn, keyboardType: TextInputType.number, textAlign: TextAlign.center, autofocus: true, style: TextStyle(color: GameTheme.textPrimary(ctx), fontSize: 32.sp, fontWeight: FontWeight.bold), decoration: InputDecoration(enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: GameTheme.primary(ctx).withValues(alpha: 0.4))), focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: GameTheme.primary(ctx), width: 2))), onSubmitted: _submit)),
    ]))),
  ]);

  Widget _result(BuildContext ctx) {
    final acc = (_ok / _total * 100).round(); final avg = _totalMs ~/ _total;
    return Center(child: Padding(padding: EdgeInsets.all(6.w), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('🔢', style: TextStyle(fontSize: 48.sp)), SizedBox(height: 2.h),
      Text('Complete!', style: GameTheme.heading(ctx, size: 24)), SizedBox(height: 3.h),
      Row(children: [_s(ctx, '$_ok/$_total', '$acc%'), SizedBox(width: 3.w), _s(ctx, '${avg}ms', 'Avg speed')]),
      SizedBox(height: 4.h),
      Row(children: [Expanded(child: OutlinedButton(onPressed: _start, style: OutlinedButton.styleFrom(foregroundColor: GameTheme.primary(ctx), side: BorderSide(color: GameTheme.primary(ctx).withValues(alpha: 0.5)), padding: EdgeInsets.symmetric(vertical: 1.5.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Retry', style: TextStyle(fontSize: 15.sp)))), SizedBox(width: 3.w), Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: GameTheme.primary(ctx), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 1.5.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Done', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold))))]),
    ])));
  }

  Widget _s(BuildContext ctx, String v, String l) => Expanded(child: Container(padding: EdgeInsets.all(3.w), decoration: GameTheme.card(ctx), child: Column(children: [Text(v, style: TextStyle(color: GameTheme.accent(ctx), fontSize: 22.sp, fontWeight: FontWeight.bold)), Text(l, style: TextStyle(color: GameTheme.textPrimary(ctx).withValues(alpha: 0.5), fontSize: 11.sp))])));
}
