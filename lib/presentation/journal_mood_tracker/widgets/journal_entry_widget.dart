import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class JournalEntryWidget extends StatefulWidget {
  final TextEditingController controller;
  final int wordCount;
  final bool isAutoSaving;
  final DateTime? writingStartTime;

  const JournalEntryWidget({
    super.key,
    required this.controller,
    required this.wordCount,
    required this.isAutoSaving,
    this.writingStartTime,
  });

  @override
  State<JournalEntryWidget> createState() => _JournalEntryWidgetState();
}

class _JournalEntryWidgetState extends State<JournalEntryWidget>
    with TickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  static const List<String> _prompts = [
    "What made you smile today? ✨",
    "What are you grateful for? 🙏",
    "Describe a moment of peace today 🌿",
    "What lesson did today teach you? 💡",
    "How did you nourish your soul? 🕊️",
  ];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  String _getWritingTime() {
    if (widget.writingStartTime == null) return '0m';
    final duration = DateTime.now().difference(widget.writingStartTime!);
    final minutes = duration.inMinutes;
    return '${minutes}m';
  }

  String _getRandomPrompt() {
    return _prompts[DateTime.now().day % _prompts.length];
  }

  @override
  Widget build(BuildContext context) {
    final warmBrown = Theme.of(context).colorScheme.primary;
    final warmAmber = Theme.of(context).colorScheme.secondary;
    final parchment = Theme.of(context).scaffoldBackgroundColor;
    final inkBrown = Theme.of(context).colorScheme.onSurface;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).cardColor,
            parchment,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isFocused
              ? warmBrown.withOpacity(0.5)
              : warmAmber.withOpacity(0.25),
          width: _isFocused ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _isFocused
                ? warmBrown.withOpacity(0.12)
                : Colors.black.withOpacity(0.06),
            blurRadius: _isFocused ? 20 : 12,
            offset: const Offset(0, 4),
          ),
          if (_isFocused)
            BoxShadow(
              color: warmAmber.withOpacity(0.1),
              blurRadius: 30,
              spreadRadius: 2,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and save indicator
          _buildHeader(warmBrown, warmAmber),

          // Writing prompt (when empty & not focused)
          if (widget.controller.text.isEmpty && !_isFocused)
            _buildPrompt(warmBrown, warmAmber),

          // Text editing area — parchment style
          _buildTextArea(warmBrown, inkBrown, parchment),

          // Stats footer
          _buildStatsBar(warmBrown, warmAmber),
        ],
      ),
    );
  }

  Widget _buildHeader(Color warmBrown, Color warmAmber) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            warmBrown.withOpacity(0.06),
            warmAmber.withOpacity(0.03),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
      ),
      child: Row(
        children: [
          // Pen icon
          Container(
            padding: EdgeInsets.all(1.5.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  warmBrown.withOpacity(0.12),
                  warmAmber.withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.edit_note_rounded, color: warmBrown, size: 20),
          ),
          SizedBox(width: 2.w),
          Text(
            'Your Thoughts',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: warmBrown,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),

          // Auto-save indicator
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.6.h),
            decoration: BoxDecoration(
              color: widget.isAutoSaving
                  ? warmBrown.withOpacity(0.08)
                  : Colors.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.isAutoSaving
                    ? warmBrown.withOpacity(0.15)
                    : Colors.green.withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isAutoSaving) ...[
                  SizedBox(
                    width: 10, height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation(warmBrown),
                    ),
                  ),
                  SizedBox(width: 1.w),
                  Text('Saving',
                    style: TextStyle(fontSize: 9.sp, color: warmBrown, fontWeight: FontWeight.w600),
                  ),
                ] else ...[
                  Icon(Icons.cloud_done_rounded, size: 12, color: Colors.green[600]),
                  SizedBox(width: 1.w),
                  Text('Saved',
                    style: TextStyle(fontSize: 9.sp, color: Colors.green[600], fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrompt(Color warmBrown, Color warmAmber) {
    return Container(
      margin: EdgeInsets.fromLTRB(4.w, 1.5.h, 4.w, 0),
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            warmBrown.withOpacity(0.04),
            warmAmber.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: warmBrown.withOpacity(0.90)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(1.5.w),
            decoration: BoxDecoration(
              color: warmBrown.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('💡', style: TextStyle(fontSize: 16)),
          ),
          SizedBox(width: 2.5.w),
          Expanded(
            child: Text(
              _getRandomPrompt(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: warmBrown.withOpacity(0.6),
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextArea(Color warmBrown, Color inkBrown, Color parchment) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: warmBrown.withOpacity(0.12),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme.copyWith(
            bodyLarge: TextStyle(color: inkBrown),
            bodyMedium: TextStyle(color: inkBrown),
            titleMedium: TextStyle(color: inkBrown),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            border: InputBorder.none,
          ),
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          maxLines: null,
          minLines: 6,
          textInputAction: TextInputAction.newline,
          cursorColor: warmBrown,
          cursorWidth: 2,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontSize: 14.sp,
            height: 1.9,
            color: inkBrown,
            letterSpacing: 0.2,
          ),
          decoration: InputDecoration(
            hintText: 'Start writing here...',
            hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 14.sp,
              color: warmBrown.withOpacity(0.35),
              fontStyle: FontStyle.italic,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 1.h),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsBar(Color warmBrown, Color warmAmber) {
    return Container(
      margin: EdgeInsets.fromLTRB(3.w, 0, 3.w, 2.w),
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            warmBrown.withOpacity(0.04),
            warmAmber.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Word count
          _buildStatChip(
            icon: Icons.text_fields_rounded,
            value: '${widget.wordCount}',
            label: 'words',
            color: warmBrown,
          ),
          SizedBox(width: 4.w),

          // Writing time
          _buildStatChip(
            icon: Icons.schedule_rounded,
            value: _getWritingTime(),
            label: 'writing',
            color: warmBrown,
          ),

          const Spacer(),

          // On fire badge
          if (widget.controller.text.length > 50)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.5.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.withOpacity(0.15),
                    Colors.deepOrange.withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 1.w),
                  Text('On fire!',
                    style: TextStyle(
                      fontSize: 9.sp,
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(1.2.w),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        SizedBox(width: 1.5.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12.sp,
                color: color.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
