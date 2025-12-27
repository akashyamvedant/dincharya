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

class _JournalEntryWidgetState extends State<JournalEntryWidget> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  String _getWritingTime() {
    if (widget.writingStartTime == null) return '0 min';
    final duration = DateTime.now().difference(widget.writingStartTime!);
    final minutes = duration.inMinutes;
    return minutes > 0 ? '$minutes min' : '< 1 min';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with metadata
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                CustomIconWidget(
                  iconName: 'edit_note',
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                SizedBox(width: 2.w),
                Text(
                  'Journal Entry',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                if (widget.isAutoSaving) ...[
                  SizedBox(
                    width: 4.w,
                    height: 4.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Text(
                    'Saving...',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ] else ...[
                  CustomIconWidget(
                    iconName: 'check_circle',
                    color: AppTheme.getSuccessColor(
                        Theme.of(context).brightness == Brightness.light),
                    size: 16,
                  ),
                  SizedBox(width: 1.w),
                  Text(
                    'Saved',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.getSuccessColor(
                              Theme.of(context).brightness == Brightness.light),
                        ),
                  ),
                ],
              ],
            ),
          ),

          // Text Input Area
          Padding(
            padding: EdgeInsets.all(4.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _isFocused
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).dividerColor,
                      width: _isFocused ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    maxLines: null,
                    minLines: 6,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText:
                          'How was your day? Share your thoughts, feelings, and experiences...',
                      hintStyle:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                              ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(4.w),
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                        ),
                  ),
                ),
                SizedBox(height: 2.h),

                // Writing Statistics
                Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildStatItem(
                        icon: 'text_fields',
                        label: 'Words',
                        value: '${widget.wordCount}',
                      ),
                      SizedBox(width: 4.w),
                      _buildStatItem(
                        icon: 'schedule',
                        label: 'Time',
                        value: _getWritingTime(),
                      ),
                      const Spacer(),
                      if (widget.controller.text.isNotEmpty) ...[
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 2.w, vertical: 1.w),
                          decoration: BoxDecoration(
                            color: AppTheme.getSuccessColor(
                                    Theme.of(context).brightness ==
                                        Brightness.light)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CustomIconWidget(
                                iconName: 'cloud_done',
                                color: AppTheme.getSuccessColor(
                                    Theme.of(context).brightness ==
                                        Brightness.light),
                                size: 14,
                              ),
                              SizedBox(width: 1.w),
                              Text(
                                'Auto-saved',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppTheme.getSuccessColor(
                                          Theme.of(context).brightness ==
                                              Brightness.light),
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomIconWidget(
          iconName: icon,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          size: 16,
        ),
        SizedBox(width: 1.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
            ),
          ],
        ),
      ],
    );
  }
}
