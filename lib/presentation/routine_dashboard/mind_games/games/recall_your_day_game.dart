// lib/presentation/routine_dashboard/mind_games/games/recall_your_day_game.dart
// Evening memory check-in. 15 question pool, 5 per session.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';

class RecallYourDayGame extends StatefulWidget {
  const RecallYourDayGame({super.key});
  @override
  State<RecallYourDayGame> createState() => _RecallYourDayGameState();
}

class _RecallYourDayGameState extends State<RecallYourDayGame> {
  final _rng = Random(), _service = MindGamesService();
  static const _total = 5;

  final _pool = const [
    _Q('🌅', 'What did you eat for breakfast?', ['Fruits/Yogurt', 'Bread/Toast', 'Cooked meal', 'Tea only', 'Skipped'], 2),
    _Q('⏰', 'What time did you wake up?', ['Before 5 AM', '5-6 AM', '6-7 AM', '7-8 AM', 'After 8 AM'], 2),
    _Q('👁️', 'First color you noticed today?', ['Red/Orange', 'Blue/Green', 'White/Gray', 'Brown/Yellow', 'Black'], 1),
    _Q('💬', 'Who did you talk to FIRST?', ['Family', 'Friend', 'Colleague', 'Service', 'No one'], 2),
    _Q('🏃', 'First activity after waking?', ['Brushed teeth', 'Drank water', 'Phone', 'Meditation', 'Other'], 1),
    _Q('🍛', 'What did you eat for lunch?', ['Home cooked', 'Ordered', 'Office food', 'Snack', 'Skipped'], 2),
    _Q('👕', 'What color shirt did you wear?', ['White', 'Blue/Black', 'Red/Orange', 'Green/Brown', 'Other'], 3),
    _Q('😊', 'How did you feel waking up?', ['Refreshed', 'Tired', 'Anxious', 'Neutral', 'Happy'], 1),
    _Q('🔊', 'First sound you heard?', ['Alarm', 'Birds', 'Voice', 'Vehicle', 'Silence'], 2),
    _Q('☀️', 'Weather when you went out?', ['Sunny', 'Cloudy', 'Rainy', 'Cool', "Didn't go out"], 1),
    _Q('💧', 'Glasses of water so far?', ['1-2', '3-4', '5-6', '7-8', '9+'], 2),
    _Q('😄', 'What made you SMILE today?', ['A person', 'A thought', 'Funny thing', 'Nature', "Can't recall"], 1),
    _Q('📱', 'First thing on your phone?', ['Messages', 'Social', 'News', 'Alarm', "Didn't check"], 1),
    _Q('👃', 'What smell do you recall?', ['Food', 'Fresh air', 'Perfume', 'Coffee', "Can't recall"], 3),
    _Q('🌙', 'What are you doing now?', ['Just finished work', 'Relaxing', 'About to sleep', 'Break', 'Other'], 1),
  ];

  late List<_Q> _qs;
  int _q = 0, _score = 0; bool _started = false, _done = false;

  void _begin() { setState(() { _qs = List.from(_pool)..shuffle(_rng); _qs = _qs.take(_total).toList(); _q = 0; _score = 0; _started = true; _done = false; }); }
  void _pick(int d) { setState(() { _score += d; _q++; if (_q >= _total) _end(); }); }

  Future<void> _end() async { setState(() => _done = true); await _service.saveScore(gameType: 'recall_day', score: _score.toDouble(), accuracy: _score / (_total * 3.0), roundsCompleted: _total); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameTheme.bg(context),
      appBar: AppBar(backgroundColor: GameTheme.bg(context), elevation: 0, leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: GameTheme.textPrimary(context)), onPressed: () => Navigator.pop(context)), title: Text('Recall Your Day', style: TextStyle(color: GameTheme.textPrimary(context), fontSize: 16.sp, fontWeight: FontWeight.bold)), centerTitle: true),
      body: !_started ? _startScrn(context) : _done ? _result(context) : _question(context),
    );
  }

  Widget _startScrn(BuildContext ctx) => Center(child: Padding(padding: EdgeInsets.all(6.w), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Text('📝', style: TextStyle(fontSize: 38.sp)), SizedBox(height: 3.h),
    Text('Recall Your Day', style: GameTheme.heading(ctx, size: 26)), SizedBox(height: 2.h),
    Text('Evening memory check-in.\n$_total questions. Be honest!', textAlign: TextAlign.center, style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 15.sp)), SizedBox(height: 4.h),
    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _begin, style: ElevatedButton.styleFrom(backgroundColor: GameTheme.primary(ctx), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 1.8.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text('Begin Recall', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)))),
  ])));

  Widget _question(BuildContext ctx) {
    final qq = _qs[_q];
    return Column(children: [
      Padding(padding: EdgeInsets.all(4.w), child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${_q + 1}/$_total', style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 13.sp)),
          Text('Score: $_score', style: TextStyle(color: GameTheme.accent(ctx), fontSize: 13.sp)),
        ]), SizedBox(height: 0.8.h),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: _q / _total, backgroundColor: GameTheme.primary(ctx).withValues(alpha: 0.12), valueColor: AlwaysStoppedAnimation(GameTheme.primary(ctx)), minHeight: 4)),
      ])),
      Expanded(child: Center(child: SingleChildScrollView(padding: EdgeInsets.all(6.w), child: Column(children: [
        Text(qq.icon, style: TextStyle(fontSize: 40.sp)), SizedBox(height: 2.h),
        Text(qq.q, textAlign: TextAlign.center, style: TextStyle(color: GameTheme.textPrimary(ctx), fontSize: 19.sp, fontWeight: FontWeight.w600)), SizedBox(height: 4.h),
        ...qq.opts.map((o) => Padding(padding: EdgeInsets.only(bottom: 1.5.h), child: SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => _pick(qq.d), style: ElevatedButton.styleFrom(backgroundColor: GameTheme.primary(ctx).withValues(alpha: 0.08), foregroundColor: GameTheme.textPrimary(ctx), padding: EdgeInsets.symmetric(vertical: 1.5.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(o, style: TextStyle(fontSize: 15.sp)))))),
      ])))),
    ]);
  }

  Widget _result(BuildContext ctx) {
    String ins = _score >= 13 ? '🌟 Excellent memory! Your brain is sharp.' : _score >= 9 ? '👍 Good recall. Keep practicing daily.' : '🧠 Room to grow. Notice more details tomorrow.';
    return Center(child: Padding(padding: EdgeInsets.all(6.w), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('📝', style: TextStyle(fontSize: 36.sp)), SizedBox(height: 2.h),
      Text('Recall Complete!', style: GameTheme.heading(ctx, size: 24)), SizedBox(height: 2.h),
      Container(padding: EdgeInsets.all(3.w), decoration: GameTheme.card(ctx), width: double.infinity, child: Column(children: [
        Text('$_score / ${_total * 3}', style: TextStyle(color: GameTheme.accent(ctx), fontSize: 26.sp, fontWeight: FontWeight.bold)),
        Text('Detail Score', style: TextStyle(color: GameTheme.textPrimary(ctx).withValues(alpha: 0.6), fontSize: 12.sp)),
      ])), SizedBox(height: 2.h),
      Container(padding: EdgeInsets.all(3.w), decoration: GameTheme.card(ctx), child: Text(ins, textAlign: TextAlign.center, style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 13.sp))),
      SizedBox(height: 4.h),
      Row(children: [Expanded(child: OutlinedButton(onPressed: _begin, style: OutlinedButton.styleFrom(foregroundColor: GameTheme.primary(ctx), side: BorderSide(color: GameTheme.primary(ctx).withValues(alpha: 0.5)), padding: EdgeInsets.symmetric(vertical: 1.5.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Retry', style: TextStyle(fontSize: 15.sp)))), SizedBox(width: 3.w), Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: GameTheme.primary(ctx), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 1.5.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Done', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold))))]),
    ])));
  }
}

class _Q { final String icon, q; final List<String> opts; final int d; const _Q(this.icon, this.q, this.opts, this.d); }
