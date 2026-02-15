import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import '../../services/supabase_service.dart';

class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  final Color warmBackground = const Color(0xFFFDF8F3);
  final Color softPeach = const Color(0xFFFAF0E6);
  final Color lightBrown = const Color(0xFFD4A574);
  final Color darkBrown = const Color(0xFF2C1810);
  final Color accentBrown = const Color(0xFF8B4513);
  final Color warmCream = const Color(0xFFFFF8F0);

  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _tickets = [];
  bool _isLoading = true;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    try {
      final client = await _supabaseService.client;
      if (client != null) {
        final userId = _supabaseService.currentUser?.id;
        if (userId != null) {
          var query = client
              .from('support_tickets')
              .select()
              .eq('user_id', userId)
              .order('created_at', ascending: false);

          final data = await query;
          setState(() {
            _tickets = List<Map<String, dynamic>>.from(data);
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint('Error loading tickets: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredTickets {
    if (_filterStatus == 'all') return _tickets;
    return _tickets.where((t) => t['status'] == _filterStatus).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: warmBackground,
      appBar: AppBar(
        backgroundColor: softPeach,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: darkBrown, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Tickets',
          style: TextStyle(
            color: darkBrown,
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: accentBrown),
            onPressed: _loadTickets,
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [accentBrown, const Color(0xFFA0522D)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: accentBrown.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () async {
            await Navigator.pushNamed(context, '/contact-support');
            _loadTickets();
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text(
            'New Ticket',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13.sp,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: accentBrown,
                      strokeWidth: 2.5,
                    ),
                  )
                : _filteredTickets.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: accentBrown,
                        onRefresh: _loadTickets,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                          itemCount: _filteredTickets.length,
                          itemBuilder: (context, index) {
                            return _buildTicketCard(_filteredTickets[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = [
      {'key': 'all', 'label': 'All', 'icon': Icons.list_rounded},
      {'key': 'open', 'label': 'Open', 'icon': Icons.circle_outlined},
      {'key': 'in_progress', 'label': 'In Progress', 'icon': Icons.autorenew_rounded},
      {'key': 'resolved', 'label': 'Resolved', 'icon': Icons.check_circle_outline},
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: filters.map((f) {
            final isSelected = _filterStatus == f['key'];
            final count = f['key'] == 'all'
                ? _tickets.length
                : _tickets.where((t) => t['status'] == f['key']).length;

            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _filterStatus = f['key'] as String);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: EdgeInsets.only(right: 2.w),
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(colors: [accentBrown, lightBrown])
                      : null,
                  color: isSelected ? null : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.transparent : lightBrown.withOpacity(0.3),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: accentBrown.withOpacity(0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      f['icon'] as IconData,
                      size: 16,
                      color: isSelected ? Colors.white : darkBrown.withOpacity(0.6),
                    ),
                    SizedBox(width: 1.5.w),
                    Text(
                      '${f['label']}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : darkBrown.withOpacity(0.7),
                      ),
                    ),
                    if (count > 0) ...[
                      SizedBox(width: 1.5.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.3.h),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white.withOpacity(0.25) : accentBrown.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : accentBrown,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentBrown.withOpacity(0.1), lightBrown.withOpacity(0.08)],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.confirmation_num_outlined,
              size: 50,
              color: accentBrown.withOpacity(0.5),
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            _filterStatus == 'all' ? 'कोई ticket नहीं है' : 'No $_filterStatus tickets',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: darkBrown,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            _filterStatus == 'all'
                ? 'New ticket बनाने के लिए + button दबाएं'
                : 'इस category में कोई ticket नहीं है',
            style: TextStyle(
              fontSize: 14.sp,
              color: darkBrown.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final status = ticket['status'] ?? 'open';
    final category = ticket['category'] ?? 'General';
    final subject = ticket['subject'] ?? '';
    final message = ticket['message'] ?? '';
    final createdAt = DateTime.tryParse(ticket['created_at'] ?? '') ?? DateTime.now();
    final priority = ticket['priority'] ?? 'medium';

    final statusConfig = _getStatusConfig(status);
    final categoryConfig = _getCategoryConfig(category);
    final priorityConfig = _getPriorityConfig(priority);

    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        await Navigator.pushNamed(
          context,
          '/ticket-detail',
          arguments: ticket,
        );
        _loadTickets();
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 2.h),
        decoration: BoxDecoration(
          color: Colors.white,
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
          children: [
            // Header row
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    (statusConfig['color'] as Color).withOpacity(0.08),
                    Colors.white,
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  // Category icon
                  Container(
                    padding: EdgeInsets.all(2.w),
                    decoration: BoxDecoration(
                      color: (categoryConfig['color'] as Color).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      categoryConfig['emoji'] as String,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  SizedBox(width: 3.w),
                  // Subject
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                            color: darkBrown,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 0.3.h),
                        Text(
                          category,
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: categoryConfig['color'] as Color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.6.h),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          (statusConfig['color'] as Color).withOpacity(0.15),
                          (statusConfig['color'] as Color).withOpacity(0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (statusConfig['color'] as Color).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusConfig['icon'] as IconData,
                          size: 14,
                          color: statusConfig['color'] as Color,
                        ),
                        SizedBox(width: 1.w),
                        Text(
                          statusConfig['label'] as String,
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                            color: statusConfig['color'] as Color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Message preview
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: darkBrown.withOpacity(0.6),
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Footer with priority and date
            Container(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
              decoration: BoxDecoration(
                color: warmCream.withOpacity(0.5),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  // Priority badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.3.h),
                    decoration: BoxDecoration(
                      color: (priorityConfig['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.flag_rounded,
                          size: 12,
                          color: priorityConfig['color'] as Color,
                        ),
                        SizedBox(width: 1.w),
                        Text(
                          priorityConfig['label'] as String,
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                            color: priorityConfig['color'] as Color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Date
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: darkBrown.withOpacity(0.4),
                      ),
                      SizedBox(width: 1.w),
                      Text(
                        _formatDate(createdAt),
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: darkBrown.withOpacity(0.4),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 2.w),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: darkBrown.withOpacity(0.3),
                  ),
                ],
              ),
            ),
          ],
        ),
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
