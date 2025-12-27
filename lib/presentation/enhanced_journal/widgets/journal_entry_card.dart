import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

// lib/presentation/enhanced_journal/widgets/journal_entry_card.dart

class JournalEntryCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const JournalEntryCard({
    super.key,
    required this.entry,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final createdAt = entry['created_at'] != null
        ? DateTime.tryParse(entry['created_at'])
        : DateTime.now();
    final mood = entry['mood'] ?? 'neutral';
    final hasAudio = entry['audio_url'] != null;
    final hasImages =
        entry['images'] != null && (entry['images'] as List).isNotEmpty;

    return Card(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        _buildMoodIcon(mood),
                        SizedBox(width: 12.w),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(entry['title'] ?? 'Untitled Entry',
                                  style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              SizedBox(height: 4.h),
                              Text(_formatDate(createdAt),
                                  style: TextStyle(
                                      fontSize: 12.sp,
                                      color: Colors.grey[600])),
                            ])),
                        PopupMenuButton(
                            itemBuilder: (context) => [
                                  const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(children: [
                                        Icon(Icons.edit),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ])),
                                  const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(children: [
                                        Icon(Icons.delete, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete',
                                            style:
                                                TextStyle(color: Colors.red)),
                                      ])),
                                ],
                            onSelected: (value) {
                              switch (value) {
                                case 'edit':
                                  onEdit?.call();
                                  break;
                                case 'delete':
                                  onDelete?.call();
                                  break;
                              }
                            }),
                      ]),
                      if (entry['content'] != null &&
                          entry['content'].isNotEmpty) ...[
                        SizedBox(height: 12.h),
                        Text(entry['content'],
                            style: TextStyle(
                                fontSize: 14.sp, color: Colors.grey[700]),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis),
                      ],
                      SizedBox(height: 12.h),
                      Row(children: [
                        if (hasAudio)
                          _buildMediaChip(Icons.mic, 'Audio', Colors.red),
                        if (hasImages) ...[
                          if (hasAudio) SizedBox(width: 8.w),
                          _buildMediaChip(Icons.image, 'Images', Colors.blue),
                        ],
                        const Spacer(),
                        _buildMoodChip(mood),
                      ]),
                    ]))));
  }

  Widget _buildMoodIcon(String mood) {
    return Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
            color: _getMoodColor(mood).withAlpha(26), shape: BoxShape.circle),
        child: Icon(_getMoodIcon(mood), color: _getMoodColor(mood), size: 20));
  }

  Widget _buildMediaChip(IconData icon, String label, Color color) {
    return Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 4.w),
          Text(label,
              style: TextStyle(
                  fontSize: 10.sp, color: color, fontWeight: FontWeight.w500)),
        ]));
  }

  Widget _buildMoodChip(String mood) {
    return Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        decoration: BoxDecoration(
            color: _getMoodColor(mood).withAlpha(26),
            borderRadius: BorderRadius.circular(12)),
        child: Text(mood.toUpperCase(),
            style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.bold,
                color: _getMoodColor(mood))));
  }

  IconData _getMoodIcon(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':
        return Icons.sentiment_very_satisfied;
      case 'sad':
        return Icons.sentiment_very_dissatisfied;
      case 'angry':
        return Icons.sentiment_dissatisfied;
      case 'excited':
        return Icons.celebration;
      case 'calm':
        return Icons.self_improvement;
      case 'anxious':
        return Icons.warning;
      case 'grateful':
        return Icons.favorite;
      default:
        return Icons.sentiment_neutral;
    }
  }

  Color _getMoodColor(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':
        return Colors.green;
      case 'sad':
        return Colors.blue;
      case 'angry':
        return Colors.red;
      case 'excited':
        return Colors.orange;
      case 'calm':
        return Colors.purple;
      case 'anxious':
        return Colors.amber;
      case 'grateful':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown date';

    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return 'Today, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
