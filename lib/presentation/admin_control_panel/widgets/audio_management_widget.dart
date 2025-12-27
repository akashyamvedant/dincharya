import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../services/supabase_service.dart';

// lib/presentation/admin_control_panel/widgets/audio_management_widget.dart

class AudioManagementWidget extends StatefulWidget {
  final List<Map<String, dynamic>> audioSessions;
  final Function() onRefresh;

  const AudioManagementWidget({
    super.key,
    required this.audioSessions,
    required this.onRefresh,
  });

  @override
  State<AudioManagementWidget> createState() => _AudioManagementWidgetState();
}

class _AudioManagementWidgetState extends State<AudioManagementWidget> {
  final SupabaseService _supabase = SupabaseService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Audio Management',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: _isLoading ? null : widget.onRefresh,
                  icon: _isLoading
                      ? SizedBox(
                          width: 20.w,
                          height: 20.w,
                          child:
                              const CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            if (widget.audioSessions.isEmpty)
              Center(
                child: Text(
                  'No audio sessions found',
                  style: TextStyle(fontSize: 14.sp),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.audioSessions.length,
                itemBuilder: (context, index) {
                  final session = widget.audioSessions[index];
                  return _buildAudioSessionTile(session);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioSessionTile(Map<String, dynamic> session) {
    return ListTile(
      leading: const Icon(Icons.audiotrack),
      title: Text(session['title'] ?? 'Untitled'),
      subtitle: Text(
        'By: ${session['user_profiles']?['full_name'] ?? 'Unknown'} • '
        '${session['duration'] ?? 0} min',
      ),
      trailing: PopupMenuButton(
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit),
                SizedBox(width: 8),
                Text('Edit'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
        onSelected: (value) => _handleSessionAction(value, session),
      ),
    );
  }

  void _handleSessionAction(String action, Map<String, dynamic> session) {
    switch (action) {
      case 'edit':
        _showEditDialog(session);
        break;
      case 'delete':
        _showDeleteDialog(session);
        break;
    }
  }

  void _showEditDialog(Map<String, dynamic> session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Audio Session'),
        content: const Text('Edit functionality would be implemented here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement edit functionality
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Audio Session'),
        content: Text('Are you sure you want to delete "${session['title']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSession(session['id']);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSession(String sessionId) async {
    setState(() => _isLoading = true);
    try {
      final client = await _supabase.client;
      if (client != null) {
        await client.from('audio_sessions').delete().eq('id', sessionId);
      }
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio session deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete session: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
