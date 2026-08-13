// lib/presentation/tapasya/circle_detail_screen.dart
//
// Circle detail screen showing members, stats, public/circle challenges, and invite options.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/tapasya_service.dart';

class CircleDetailScreen extends StatefulWidget {
  const CircleDetailScreen({super.key});

  @override
  State<CircleDetailScreen> createState() => _CircleDetailScreenState();
}

class _CircleDetailScreenState extends State<CircleDetailScreen> with SingleTickerProviderStateMixin {
  final TapasyaService _tapasyaService = TapasyaService();
  Map<String, dynamic>? _circle;
  bool _isLoading = true;
  bool _isLeaving = false;
  late TabController _tabController;
  List<Map<String, dynamic>> _liveRooms = [];

    @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic> && _circle == null) {
      _circle = args;
      _loadDetail();
    }
  }

  Future<void> _loadDetail() async {
    if (_circle == null) return;
    setState(() => _isLoading = true);

    final detail = await _tapasyaService.getCircleDetail(_circle!['id']);
    final liveRooms = await _tapasyaService.getActiveLiveRooms(_circle!['id']);

    if (detail != null && mounted) {
      setState(() {
        _circle = detail;
        _liveRooms = liveRooms;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _leaveCircle() async {
    if (_circle == null || _isLeaving) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Circle?'),
        content: Text('Are you sure you want to leave "${_circle!['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLeaving = true);
    final success = await _tapasyaService.leaveCircle(_circle!['id']);
    setState(() => _isLeaving = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Left circle "${_circle!['name']}"'),
        ),
      );
      Navigator.pop(context);
    }
  }

  void _shareCircle() {
    if (_circle == null) return;
    final shareText = TapasyaService.generateCircleShareText(_circle!);
    Share.share(shareText);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_circle == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Circle')),
        body: const Center(child: Text('Circle not found')),
      );
    }

    final name = _circle!['name'] ?? 'Circle';
    final desc = _circle!['description'] ?? 'No description';
    final memberCount = _circle!['member_count'] ?? 1;
    final code = _circle!['invite_code'] ?? '';
    final members = _circle!['members'] as List<Map<String, dynamic>>? ?? [];
    final challenges = _circle!['challenges'] as List<Map<String, dynamic>>? ?? [];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 22.h,
              pinned: true,
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.7)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(4.w, 6.h, 4.w, 2.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text('👥', style: TextStyle(fontSize: 32)),
                          SizedBox(height: 0.5.h),
                          Text(
                            name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            desc,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12.sp,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white),
                  onPressed: _shareCircle,
                ),
                PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'leave') _leaveCircle();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'leave',
                      child: Text('Leave Circle', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: TabBar(
                controller: _tabController,
                indicatorColor: theme.colorScheme.primary,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                isScrollable: true,
                tabs: const [
                  Tab(text: 'Members 👥'),
                  Tab(text: 'Circle Challenges 🏆'),
                  Tab(text: 'Live Sadhana 🔴'),
                ],
              ),
            ),
          ];
        },
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
            : TabBarView(
                controller: _tabController,
                children: [
                  // ── Members Tab ──
                  ListView.builder(
                    padding: EdgeInsets.all(4.w),
                    itemCount: members.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Container(
                          margin: EdgeInsets.only(bottom: 2.h),
                          padding: EdgeInsets.all(4.w),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Invite Code: $code',
                                    style: TextStyle(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    'Share code to invite new members',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              IconButton(
                                icon: Icon(Icons.copy, color: theme.colorScheme.primary),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: code));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('✅ Invite code copied!')),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      }

                      final member = members[index - 1];
                      final mName = member['display_name'] ?? 'User';
                      final role = member['role'] ?? 'member';
                      final isMe = member['is_me'] == true;
                      final avatarUrl = member['avatar_url'] as String?;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isMe ? theme.colorScheme.primary.withValues(alpha: 0.2) : theme.colorScheme.surfaceContainerHighest,
                          backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
                          child: (avatarUrl == null || avatarUrl.isEmpty)
                              ? Text(
                                  mName.isNotEmpty ? mName[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    color: isMe ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        title: Text(isMe ? '$mName (You)' : mName),
                        trailing: role == 'admin'
                            ? Container(
                                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Admin',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              )
                            : null,
                      );
                    },
                  ),

                  // ── Challenges Tab ──
                  ListView.builder(
                    padding: EdgeInsets.all(4.w),
                    itemCount: challenges.length + 1,
                    itemBuilder: (context, index) {
                      if (index == challenges.length) {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 2.h),
                          child: Center(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  '/tapasya/create-challenge',
                                  arguments: {'circle_id': _circle!['id']},
                                ).then((_) => _loadDetail());
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Create Circle Challenge'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.5.h),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        );
                      }

                      final ch = challenges[index];
                      return Card(
                        margin: EdgeInsets.only(bottom: 1.5.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          title: Text(ch['title'] ?? 'Challenge'),
                          subtitle: Text('Goal: ${ch['goal_value']} ${ch['goal_type']}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/tapasya/challenge',
                              arguments: ch,
                            ).then((_) => _loadDetail());
                          },
                        ),
                      );
                    },
                  ),

                   // ── Live Sadhana Tab ──
                  _buildLiveSadhanaTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildLiveSadhanaTab() {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _loadDetail,
      child: ListView(
        padding: EdgeInsets.all(4.w),
        children: [
          // Banner/Notice card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            child: Padding(
              padding: EdgeInsets.all(4.w),
              child: Row(
                children: [
                  const Text('🔴', style: TextStyle(fontSize: 28)),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sadhana Sangha Live',
                          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                        ),
                        SizedBox(height: 0.5.h),
                        Text(
                          'Practice in real-time with circle members. Shared synchronized timer keeps everyone in sync.',
                          style: TextStyle(fontSize: 11.sp, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 2.h),

          if (_liveRooms.isEmpty) ...[
            SizedBox(height: 4.h),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.podcasts_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                  SizedBox(height: 2.h),
                  Text(
                    'No Active Live Rooms',
                    style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 1.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    child: Text(
                      'Be the first to start a live room and invite other members to practice now!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.sp, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  SizedBox(height: 3.h),
                  ElevatedButton.icon(
                    onPressed: _showStartLiveRoomSheet,
                    icon: const Icon(Icons.radio_button_checked, size: 18),
                    label: const Text('Start Live Sadhana'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.5.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              'Active Rooms',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 1.5.h),
            ..._liveRooms.map((room) {
              final startedAt = DateTime.tryParse(room['started_at'] ?? '')?.toLocal();
              final durationMin = (room['duration_seconds'] ?? 600) ~/ 60;
              final categoryEmoji = room['category'] == 'yoga'
                  ? '🧘'
                  : room['category'] == 'pranayama'
                      ? '🌬️'
                      : room['category'] == 'meditation'
                          ? '🕉️'
                          : '🔥';

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                margin: EdgeInsets.only(bottom: 2.h),
                elevation: 2,
                child: Padding(
                  padding: EdgeInsets.all(4.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Text(categoryEmoji, style: const TextStyle(fontSize: 24)),
                          ),
                          SizedBox(width: 3.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  room['title'] ?? 'Live Practice',
                                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 0.5.h),
                                Text(
                                  'Category: ${room['category'].toString().toUpperCase()} • Duration: $durationMin Min',
                                  style: TextStyle(fontSize: 11.sp, color: theme.colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.5.h),
                            decoration: BoxDecoration(
                              color: Colors.red.shade900.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.circle, color: Colors.red, size: 10),
                                SizedBox(width: 1.w),
                                Text(
                                  'LIVE',
                                  style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.bold, color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '👥 ${room['participant_count'] ?? 1} practicing now',
                            style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/tapasya/live-room',
                                arguments: {
                                  'room': room,
                                  'circle': _circle,
                                },
                              ).then((_) => _loadDetail());
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade800,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Join Room'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            SizedBox(height: 2.h),
            Center(
              child: TextButton.icon(
                onPressed: _showStartLiveRoomSheet,
                icon: Icon(Icons.add, color: theme.colorScheme.primary),
                label: Text('Start Another Room', style: TextStyle(color: theme.colorScheme.primary)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showStartLiveRoomSheet() {
    final titleController = TextEditingController(text: 'Group Sadhana Practice');
    String selectedCategory = 'yoga';
    int selectedDurationMin = 15;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 6.w,
                right: 6.w,
                top: 3.h,
                bottom: MediaQuery.of(context).viewInsets.bottom + 4.h,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 12.w,
                      height: 5,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '🔴 Start Live Sadhana Room',
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 2.5.h),

                  // Title input
                  Text(
                    'Room Title',
                    style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  SizedBox(height: 1.h),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      hintText: 'Enter room title...',
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
                    ),
                  ),
                  SizedBox(height: 2.5.h),

                  // Category Selector
                  Text(
                    'Practice Category',
                    style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  SizedBox(height: 1.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildCategoryBtn('yoga', '🧘 Yoga', selectedCategory, (cat) {
                        setSheetState(() => selectedCategory = cat);
                      }),
                      _buildCategoryBtn('pranayama', '🌬️ Pranayama', selectedCategory, (cat) {
                        setSheetState(() => selectedCategory = cat);
                      }),
                      _buildCategoryBtn('meditation', '🕉️ Meditation', selectedCategory, (cat) {
                        setSheetState(() => selectedCategory = cat);
                      }),
                    ],
                  ),
                  SizedBox(height: 2.5.h),

                  // Duration Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Practice Duration',
                        style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant),
                      ),
                      Text(
                        '$selectedDurationMin Minutes',
                        style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                      ),
                    ],
                  ),
                  Slider(
                    value: selectedDurationMin.toDouble(),
                    min: 5,
                    max: 60,
                    divisions: 11,
                    activeColor: theme.colorScheme.primary,
                    inactiveColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                    onChanged: (val) {
                      setSheetState(() => selectedDurationMin = val.toInt());
                    },
                  ),
                  SizedBox(height: 4.h),

                  // Start room CTA
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final room = await _tapasyaService.startLiveRoom(
                          circleId: _circle!['id'],
                          title: titleController.text.trim().isEmpty
                              ? 'Live practice room'
                              : titleController.text.trim(),
                          category: selectedCategory,
                          durationSeconds: selectedDurationMin * 60,
                        );

                        if (room != null && context.mounted) {
                          Navigator.pop(ctx); // Close sheet
                          // Navigate to live room screen
                          Navigator.pushNamed(
                            context,
                            '/tapasya/live-room',
                            arguments: {
                              'room': room,
                              'circle': _circle,
                            },
                          ).then((_) => _loadDetail());
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 2.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Launch Live Room 🚀', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryBtn(String value, String label, String current, Function(String) onTap) {
    final isSelected = value == current;
    final theme = Theme.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 1.w),
          padding: EdgeInsets.symmetric(vertical: 1.5.h),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.12) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? theme.colorScheme.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

