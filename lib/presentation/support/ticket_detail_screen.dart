import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import '../../services/supabase_service.dart';

class TicketDetailScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;

  const TicketDetailScreen({super.key, required this.ticket});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final Color warmBackground = const Color(0xFFFDF8F3);
  final Color softPeach = const Color(0xFFFAF0E6);
  final Color lightBrown = Color(0xFFD4A574);
  final Color darkBrown = const Color(0xFF2C1810);
  final Color accentBrown = Color(0xFF8B4513);
  final Color warmCream = Color(0xFFFFF8F0);

  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _replies = [];
  bool _isLoading = true;
  bool _isSending = false;
  late Map<String, dynamic> _ticket;

  @override
  void initState() {
    super.initState();
    _ticket = Map<String, dynamic>.from(widget.ticket);
    _loadReplies();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadReplies() async {
    setState(() => _isLoading = true);
    try {
      final client = await _supabaseService.client;
      if (client != null) {
        // Also refresh ticket status
        final ticketData = await client
            .from('support_tickets')
            .select()
            .eq('id', _ticket['id'])
            .single();
        
        final data = await client
            .from('ticket_replies')
            .select()
            .eq('ticket_id', _ticket['id'])
            .order('created_at', ascending: true);

        setState(() {
          _ticket = Map<String, dynamic>.from(ticketData);
          _replies = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error loading replies: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    try {
      final client = await _supabaseService.client;
      if (client != null) {
        await client.from('ticket_replies').insert({
          'ticket_id': _ticket['id'],
          'sender_type': 'user',
          'sender_id': _supabaseService.currentUser?.id,
          'message': text,
        });

        _replyController.clear();
        await _loadReplies();
      }
    } catch (e) {
      debugPrint('Error sending reply: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reply भेजने में error हुआ'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = _ticket['status'] ?? 'open';
    final statusConfig = _getStatusConfig(status);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).colorScheme.onSurface, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ticket Details',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 17.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusConfig['color'] as Color,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 1.w),
                Text(
                  statusConfig['label'] as String,
                  style: TextStyle(
                    color: statusConfig['color'] as Color,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: accentBrown),
            onPressed: _loadReplies,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: accentBrown,
                      strokeWidth: 2.5,
                    ),
                  )
                : ListView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                    children: [
                      _buildTicketInfoCard(),
                      SizedBox(height: 2.h),
                      _buildOriginalMessage(),
                      if (_replies.isNotEmpty) ...[
                        SizedBox(height: 2.h),
                        _buildConversationHeader(),
                        SizedBox(height: 1.h),
                        ..._replies.map((reply) => _buildReplyBubble(reply)),
                      ],
                      if (_replies.isEmpty && status == 'open') ...[
                        SizedBox(height: 4.h),
                        _buildWaitingMessage(),
                      ],
                      SizedBox(height: 2.h),
                    ],
                  ),
          ),
          if (status != 'closed' && status != 'resolved') _buildReplyInput(),
        ],
      ),
    );
  }

  Widget _buildTicketInfoCard() {
    final category = _ticket['category'] ?? 'General';
    final priority = _ticket['priority'] ?? 'medium';
    final createdAt = DateTime.tryParse(_ticket['created_at'] ?? '') ?? DateTime.now();
    final updatedAt = DateTime.tryParse(_ticket['updated_at'] ?? '') ?? DateTime.now();
    final categoryConfig = _getCategoryConfig(category);
    final priorityConfig = _getPriorityConfig(priority);
    final status = _ticket['status'] ?? 'open';
    final statusConfig = _getStatusConfig(status);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: lightBrown.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: darkBrown.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject header
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (statusConfig['color'] as Color).withOpacity(0.08),
                  Theme.of(context).colorScheme.surface,
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Text(
                  categoryConfig['emoji'] as String,
                  style: const TextStyle(fontSize: 22),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Text(
                    _ticket['subject'] ?? '',
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Info chips row
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
            child: Wrap(
              spacing: 2.w,
              runSpacing: 1.h,
              children: [
                _buildInfoChip(
                  Icons.category_rounded,
                  category,
                  categoryConfig['color'] as Color,
                ),
                _buildInfoChip(
                  Icons.flag_rounded,
                  priorityConfig['label'] as String,
                  priorityConfig['color'] as Color,
                ),
                _buildInfoChip(
                  Icons.calendar_today_rounded,
                  _formatFullDate(createdAt),
                  Colors.grey,
                ),
                _buildInfoChip(
                  Icons.update_rounded,
                  'Updated: ${_formatDate(updatedAt)}',
                  Colors.grey,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.5.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color.withOpacity(0.7)),
          SizedBox(width: 1.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOriginalMessage() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentBrown.withOpacity(0.08),
            lightBrown.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: lightBrown.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(1.5.w),
                decoration: BoxDecoration(
                  color: accentBrown.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.edit_note_rounded, size: 18, color: accentBrown),
              ),
              SizedBox(width: 2.w),
              Text(
                'Original Message',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: accentBrown,
                ),
              ),
            ],
          ),
          SizedBox(height: 1.5.h),
          Text(
            _ticket['message'] ?? '',
            style: TextStyle(
              fontSize: 14.sp,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationHeader() {
    return Row(
      children: [
        Container(
          height: 1,
          width: 8.w,
          color: lightBrown.withOpacity(0.3),
        ),
        SizedBox(width: 2.w),
        Text(
          'Conversation (${_replies.length})',
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
        SizedBox(width: 2.w),
        Expanded(
          child: Container(
            height: 1,
            color: lightBrown.withOpacity(0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildReplyBubble(Map<String, dynamic> reply) {
    final isUser = reply['sender_type'] == 'user';
    final message = reply['message'] ?? '';
    final createdAt = DateTime.tryParse(reply['created_at'] ?? '') ?? DateTime.now();

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 1.5.h,
          left: isUser ? 15.w : 0,
          right: isUser ? 0 : 15.w,
        ),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Sender label
            Padding(
              padding: EdgeInsets.only(
                left: isUser ? 0 : 3.w,
                right: isUser ? 3.w : 0,
                bottom: 0.5.h,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isUser ? Icons.person_rounded : Icons.support_agent_rounded,
                    size: 14,
                    color: isUser ? accentBrown.withOpacity(0.5) : Colors.blue.withOpacity(0.5),
                  ),
                  SizedBox(width: 1.w),
                  Text(
                    isUser ? 'You' : 'Support Team',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                      color: isUser ? accentBrown.withOpacity(0.5) : Colors.blue.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            // Message bubble
            Container(
              padding: EdgeInsets.all(3.5.w),
              decoration: BoxDecoration(
                gradient: isUser
                    ? LinearGradient(
                        colors: [accentBrown, const Color(0xFFA0522D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [Theme.of(context).colorScheme.surface, Theme.of(context).colorScheme.surfaceContainerHighest],
                      ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser ? null : Border.all(color: lightBrown.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: (isUser ? accentBrown : Colors.grey).withOpacity(0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: isUser ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.85),
                  height: 1.5,
                ),
              ),
            ),
            // Timestamp
            Padding(
              padding: EdgeInsets.only(
                top: 0.4.h,
                left: isUser ? 0 : 3.w,
                right: isUser ? 3.w : 0,
              ),
              child: Text(
                _formatTime(createdAt),
                style: TextStyle(
                  fontSize: 9.sp,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingMessage() {
    return Center(
      child: Container(
        padding: EdgeInsets.all(5.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue.withOpacity(0.06),
              Colors.purple.withOpacity(0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.hourglass_top_rounded,
              size: 40,
              color: Colors.blue.withOpacity(0.4),
            ),
            SizedBox(height: 1.5.h),
            Text(
              'प्रतीक्षा में... ⏳',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: darkBrown,
              ),
            ),
            SizedBox(height: 0.5.h),
            Text(
              'हमारी team 24-48 hours में respond करेगी\nआप नीचे reply भी भेज सकते हैं',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(3.w, 1.5.h, 3.w, MediaQuery.of(context).padding.bottom + 1.5.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: lightBrown.withOpacity(0.15)),
        ),
        boxShadow: [
          BoxShadow(
            color: darkBrown.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: lightBrown.withOpacity(0.2)),
              ),
              child: TextField(
                controller: _replyController,
                maxLines: 3,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Reply लिखें...',
                  hintStyle: TextStyle(
                    fontSize: 14.sp,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 1.5.h),
                ),
              ),
            ),
          ),
          SizedBox(width: 2.w),
          GestureDetector(
            onTap: _isSending ? null : _sendReply,
            child: Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isSending
                      ? [Colors.grey, Colors.grey.shade400]
                      : [accentBrown, const Color(0xFFA0522D)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: _isSending
                    ? []
                    : [
                        BoxShadow(
                          color: accentBrown.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              child: _isSending
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatFullDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    return '${_formatDate(date)} · ${hour == 0 ? 12 : hour}:${date.minute.toString().padLeft(2, '0')} $amPm';
  }

  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status) {
      case 'open':
        return {'color': Colors.orange, 'label': 'Open', 'icon': Icons.circle_outlined};
      case 'in_progress':
        return {'color': Colors.blue, 'label': 'In Progress', 'icon': Icons.autorenew_rounded};
      case 'resolved':
        return {'color': Colors.green, 'label': 'Resolved', 'icon': Icons.check_circle};
      case 'closed':
        return {'color': Colors.grey, 'label': 'Closed', 'icon': Icons.cancel_outlined};
      default:
        return {'color': Colors.orange, 'label': 'Open', 'icon': Icons.circle_outlined};
    }
  }

  Map<String, dynamic> _getCategoryConfig(String category) {
    switch (category) {
      case 'Bug':
        return {'color': Colors.red, 'emoji': '🐛'};
      case 'Feature':
        return {'color': Colors.amber.shade700, 'emoji': '✨'};
      case 'Account':
        return {'color': Colors.purple, 'emoji': '👤'};
      case 'Subscription':
        return {'color': Colors.green, 'emoji': '💳'};
      case 'Other':
        return {'color': Colors.grey, 'emoji': '📝'};
      default:
        return {'color': Colors.blue, 'emoji': '❓'};
    }
  }

  Map<String, dynamic> _getPriorityConfig(String priority) {
    switch (priority) {
      case 'low':
        return {'color': Colors.green, 'label': 'Low'};
      case 'medium':
        return {'color': Colors.orange, 'label': 'Medium'};
      case 'high':
        return {'color': Colors.red, 'label': 'High'};
      case 'urgent':
        return {'color': Colors.red.shade900, 'label': 'Urgent'};
      default:
        return {'color': Colors.orange, 'label': 'Medium'};
    }
  }
}
