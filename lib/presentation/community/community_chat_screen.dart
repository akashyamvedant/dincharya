import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sizer/sizer.dart';

import '../../theme/app_theme.dart';
import '../../services/community_service.dart';
import '../../services/supabase_service.dart';
import 'widgets/chat_bubble_widget.dart';

class CommunityChatScreen extends StatefulWidget {
  const CommunityChatScreen({super.key});

  @override
  State<CommunityChatScreen> createState() => _CommunityChatScreenState();
}

class _CommunityChatScreenState extends State<CommunityChatScreen>
    with TickerProviderStateMixin {
  final CommunityService _communityService = CommunityService();
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();

  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _pinnedMessages = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isSending = false;
  bool _isUploadingMedia = false;
  bool _isAdmin = false;
  String? _currentUserId;
  bool _showPinned = false;

  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _initialize();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _communityService.unsubscribe();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    _currentUserId = _supabaseService.currentUser?.id;
    _isAdmin = await _communityService.isCurrentUserAdmin();

    final messages = await _communityService.loadMessages();
    final pinned = await _communityService.loadPinnedMessages();

    if (mounted) {
      setState(() {
        _messages = messages;
        _pinnedMessages = pinned;
        _isLoading = false;
      });

      _fadeController.forward();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }

    _communityService.subscribeToMessages(
      onInsert: (newMessage) {
        if (mounted) {
          setState(() {
            _messages.add(newMessage);
          });
          _scrollToBottom();
        }
      },
      onDelete: (oldMessage) {
        if (mounted) {
          setState(() {
            _messages.removeWhere((m) => m['id'] == oldMessage['id']);
            _pinnedMessages.removeWhere((m) => m['id'] == oldMessage['id']);
          });
        }
      },
      onUpdate: (updatedMessage) {
        if (mounted) {
          setState(() {
            final index =
                _messages.indexWhere((m) => m['id'] == updatedMessage['id']);
            if (index != -1) {
              _messages[index] = updatedMessage;
            }
            _loadPinned();
          });
        }
      },
    );
  }

  Future<void> _loadPinned() async {
    final pinned = await _communityService.loadPinnedMessages();
    if (mounted) {
      setState(() => _pinnedMessages = pinned);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels <=
            _scrollController.position.minScrollExtent + 50 &&
        !_isLoadingMore &&
        _messages.isNotEmpty) {
      _loadOlderMessages();
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    final oldest = _messages.first['created_at'];
    final before = DateTime.parse(oldest);
    final older = await _communityService.loadMessages(before: before);

    if (mounted) {
      setState(() {
        _messages.insertAll(0, older);
        _isLoadingMore = false;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendMessage({String? mediaUrl, String? mediaType}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && mediaUrl == null) return;
    if (_isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    final success = await _communityService.sendMessage(
      text,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
    );

    if (mounted) {
      setState(() => _isSending = false);
      if (!success) {
        _messageController.text = text;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to send message',
                style: TextStyle(fontSize: 14)),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _pickMedia() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(4.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12.w,
                height: 0.5.h,
                decoration: BoxDecoration(
                  color: Colors.grey[350],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                'Share Media',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 2.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMediaOption(
                    ctx,
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    color: const Color(0xFF6D4C41),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImageFromGallery();
                    },
                  ),
                  _buildMediaOption(
                    ctx,
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: const Color(0xFF8B6914),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImageFromCamera();
                    },
                  ),
                  _buildMediaOption(
                    ctx,
                    icon: Icons.videocam_rounded,
                    label: 'Video',
                    color: const Color(0xFF5D4037),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickVideo();
                    },
                  ),
                ],
              ),
              SizedBox(height: 2.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaOption(
    BuildContext ctx, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Icon(icon, color: color, size: 7.w),
          ),
          SizedBox(height: 0.8.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImageFromGallery() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (image != null) {
      await _uploadAndSendMedia(File(image.path), 'image');
    }
  }

  Future<void> _pickImageFromCamera() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (image != null) {
      await _uploadAndSendMedia(File(image.path), 'image');
    }
  }

  Future<void> _pickVideo() async {
    final video = await _imagePicker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );
    if (video != null) {
      await _uploadAndSendMedia(File(video.path), 'video');
    }
  }

  Future<void> _uploadAndSendMedia(File file, String type) async {
    setState(() => _isUploadingMedia = true);

    final mediaUrl = await _communityService.uploadMedia(file, type);

    if (mounted) {
      setState(() => _isUploadingMedia = false);
      if (mediaUrl != null) {
        await _sendMessage(mediaUrl: mediaUrl, mediaType: type);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to upload media',
                style: TextStyle(fontSize: 14)),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
        ),
        title: Text('Delete Message',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface, fontSize: 16.sp)),
        content: Text('Are you sure you want to delete this message?',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 13.sp)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 13.sp)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Delete', style: TextStyle(fontSize: 13.sp)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _communityService.deleteMessage(messageId);
    }
  }

  Future<void> _togglePin(String messageId, bool pin) async {
    await _communityService.togglePin(messageId, pin);
  }

  bool _isSenderAdminByUserId(String? senderUserId) {
    if (_isAdmin && senderUserId == _currentUserId) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Color(0xFF8B4513);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(8.h),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor, primaryColor.withOpacity(0.85)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 2.w),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 26),
                    onPressed: () => Navigator.pop(context),
                  ),
                  // Group icon
                  Container(
                    padding: EdgeInsets.all(2.w),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.groups_rounded,
                        color: Colors.white, size: 5.5.w),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dincharya Community',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18.sp,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(height: 0.3.h),
                        Row(
                          children: [
                            Container(
                              width: 1.8.w,
                              height: 1.8.w,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4ADE80),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                            ),
                            SizedBox(width: 1.5.w),
                            Text(
                              'Online',
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: const Color(0xFF4ADE80),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 2.w),
                            Text(
                              '•',
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                            SizedBox(width: 2.w),
                            Text(
                              'wellness community',
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: Colors.white.withOpacity(0.7),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_pinnedMessages.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        _showPinned
                            ? Icons.push_pin
                            : Icons.push_pin_outlined,
                        color: _showPinned
                            ? const Color(0xFFFFD700)
                            : Colors.white.withOpacity(0.8),
                        size: 22,
                      ),
                      onPressed: () =>
                          setState(() => _showPinned = !_showPinned),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Pinned messages
          if (_showPinned && _pinnedMessages.isNotEmpty) _buildPinnedSection(),

          // Upload indicator
          if (_isUploadingMedia)
            Container(
              padding: EdgeInsets.symmetric(vertical: 1.h, horizontal: 4.w),
              color: Theme.of(context).colorScheme.surface,
              child: Row(
                children: [
                  SizedBox(
                    width: 4.w,
                    height: 4.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primaryColor,
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Text(
                    'Uploading media...',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Messages
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: primaryColor,
                          strokeWidth: 2.5,
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Loading messages...',
                          style: TextStyle(
                            color: primaryColor.withOpacity(0.7),
                            fontSize: 14.sp,
                          ),
                        ),
                      ],
                    ),
                  )
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : FadeTransition(
                        opacity: _fadeController,
                        child: _buildMessagesList(),
                      ),
          ),

          // Input bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildPinnedSection() {
    final adminGold = const Color(0xFFD4A017);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  adminGold.withOpacity(0.08),
                  adminGold.withOpacity(0.03),
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(1.5.w),
                  decoration: BoxDecoration(
                    color: adminGold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.push_pin, size: 14, color: adminGold),
                ),
                SizedBox(width: 2.5.w),
                Text(
                  '${_pinnedMessages.length} Pinned',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: adminGold,
                  ),
                ),
                const Spacer(),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() => _showPinned = false),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: EdgeInsets.all(1.5.w),
                      child: Icon(Icons.keyboard_arrow_up,
                          size: 22, color: Colors.grey[500]),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Pinned messages - compact WhatsApp-style
          ..._pinnedMessages.take(2).map((msg) => IntrinsicHeight(
                child: Container(
                  margin: EdgeInsets.symmetric(
                      horizontal: 3.w, vertical: 0.4.h),
                  child: Row(
                    children: [
                      // Gold left accent bar
                      Container(
                        width: 1.w,
                        decoration: BoxDecoration(
                          color: adminGold,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(width: 2.5.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg['user_name'] ?? 'User',
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            SizedBox(height: 0.1.h),
                            Text(
                              msg['message'] ?? '',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                height: 1.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )),
          SizedBox(height: 0.5.h),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(7.w),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.forum_rounded,
              size: 14.w,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            'Welcome to the Community! 🙏',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Be the first to send a message.\nShare your journey, tips, or just say hi!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.sp,
              color: const Color(0xFF5D4037),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
      itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isLoadingMore && index == 0) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(2.h),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          );
        }

        final msgIndex = _isLoadingMore ? index - 1 : index;
        final msg = _messages[msgIndex];
        final senderId = msg['user_id']?.toString() ?? '';
        final isOwn = senderId == _currentUserId;
        final createdAt =
            DateTime.tryParse(msg['created_at'] ?? '') ?? DateTime.now();
        final isPinned = msg['is_pinned'] == true;

        Widget? dateSeparator;
        if (msgIndex == 0 ||
            _isDifferentDay(
              DateTime.tryParse(
                      _messages[msgIndex - 1]['created_at'] ?? '') ??
                  DateTime.now(),
              createdAt,
            )) {
          dateSeparator = _buildDateSeparator(createdAt);
        }

        return Column(
          children: [
            if (dateSeparator != null) dateSeparator,
            ChatBubbleWidget(
              messageId: msg['id']?.toString() ?? '',
              userName: msg['user_name']?.toString() ?? 'User',
              userAvatarUrl: msg['user_avatar_url']?.toString(),
              message: msg['message']?.toString() ?? '',
              mediaUrl: msg['media_url']?.toString(),
              mediaType: msg['media_type']?.toString(),
              createdAt: createdAt,
              isOwnMessage: isOwn,
              isAdmin: _isAdmin,
              isSenderAdmin: _isSenderAdminByUserId(senderId),
              isPinned: isPinned,
              onDelete: () => _deleteMessage(msg['id'].toString()),
              onPin: () => _togglePin(msg['id'].toString(), true),
              onUnpin: () => _togglePin(msg['id'].toString(), false),
            ),
          ],
        );
      },
    );
  }

  bool _isDifferentDay(DateTime a, DateTime b) {
    return a.year != b.year || a.month != b.month || a.day != b.day;
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    String label;

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      label = 'Today';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      label = 'Yesterday';
    } else {
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      label = '${date.day} ${months[date.month - 1]} ${date.year}';
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 0.5,
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
          ),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 4.w),
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.6.h),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 0.5,
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final primaryColor = Color(0xFF8B4513);

    return Container(
      padding: EdgeInsets.fromLTRB(3.w, 1.2.h, 2.w, 1.2.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Attachment button
            Padding(
              padding: EdgeInsets.only(bottom: 0.3.h),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _isUploadingMedia ? null : _pickMedia,
                  child: Container(
                    padding: EdgeInsets.all(2.5.w),
                    child: Icon(
                      Icons.attach_file_rounded,
                      color: _isUploadingMedia
                          ? Colors.grey[400]
                          : const Color(0xFF8B6914),
                      size: 6.w,
                    ),
                  ),
                ),
              ),
            ),

            // Message input
            Expanded(
              child: Container(
                constraints: BoxConstraints(maxHeight: 16.h),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _messageController,
                  focusNode: _focusNode,
                  maxLines: 5,
                  minLines: 1,
                  maxLength: 1000,
                  textCapitalization: TextCapitalization.sentences,
                  cursorColor: Theme.of(context).colorScheme.primary,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      fontSize: 13.sp,
                    ),
                    // Override global theme's fill color
                    filled: true,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 4.5.w,
                      vertical: 1.3.h,
                    ),
                    counterText: '',
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),

            SizedBox(width: 2.w),

            // Send button
            Padding(
              padding: EdgeInsets.only(bottom: 0.3.h),
              child: Material(
                color: primaryColor,
                shape: const CircleBorder(),
                elevation: 3,
                shadowColor: primaryColor.withOpacity(0.4),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _isSending ? null : () => _sendMessage(),
                  child: Container(
                    padding: EdgeInsets.all(3.2.w),
                    child: _isSending
                        ? SizedBox(
                            width: 5.5.w,
                            height: 5.5.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 5.5.w,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
