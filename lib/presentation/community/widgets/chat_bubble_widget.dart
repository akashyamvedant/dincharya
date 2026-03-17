import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../../theme/app_theme.dart';

/// World-class chat bubble with slide-in animation, auto-sizing media,
/// premium WhatsApp-style design with proper video playback.
class ChatBubbleWidget extends StatefulWidget {
  final String messageId;
  final String userName;
  final String? userAvatarUrl;
  final String message;
  final String? mediaUrl;
  final String? mediaType;
  final DateTime createdAt;
  final bool isOwnMessage;
  final bool isAdmin;
  final bool isSenderAdmin;
  final bool isPinned;
  final VoidCallback? onDelete;
  final VoidCallback? onPin;
  final VoidCallback? onUnpin;

  const ChatBubbleWidget({
    super.key,
    required this.messageId,
    required this.userName,
    this.userAvatarUrl,
    required this.message,
    this.mediaUrl,
    this.mediaType,
    required this.createdAt,
    required this.isOwnMessage,
    this.isAdmin = false,
    this.isSenderAdmin = false,
    this.isPinned = false,
    this.onDelete,
    this.onPin,
    this.onUnpin,
  });

  @override
  State<ChatBubbleWidget> createState() => _ChatBubbleWidgetState();
}

class _ChatBubbleWidgetState extends State<ChatBubbleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // Video thumbnail controller — just grab first frame
  VideoPlayerController? _thumbController;
  bool _thumbReady = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(widget.isOwnMessage ? 0.15 : -0.15, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
      ),
    );

    _animController.forward();

    // Initialize video thumbnail if it's a video
    if (widget.mediaType == 'video' && widget.mediaUrl != null) {
      _initVideoThumbnail();
    }
  }

  Future<void> _initVideoThumbnail() async {
    try {
      _thumbController = VideoPlayerController.networkUrl(
        Uri.parse(widget.mediaUrl!),
      );
      await _thumbController!.initialize();
      // Seek to 0 to get the first frame
      await _thumbController!.seekTo(Duration.zero);
      if (mounted) {
        setState(() => _thumbReady = true);
      }
    } catch (e) {
      debugPrint('Video thumbnail init failed: $e');
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _thumbController?.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Color(0xFF8B4513);
    final adminGold = const Color(0xFFD4A017);
    final bool hasMedia =
        widget.mediaUrl != null && widget.mediaUrl!.isNotEmpty;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          alignment:
              widget.isOwnMessage ? Alignment.centerRight : Alignment.centerLeft,
          child: Align(
            alignment: widget.isOwnMessage
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: GestureDetector(
              onLongPress: () {
                HapticFeedback.mediumImpact();
                _showOptions(context);
              },
              child: Container(
                constraints: BoxConstraints(maxWidth: 78.w),
                margin: EdgeInsets.only(
                  left: widget.isOwnMessage ? 12.w : 2.w,
                  right: widget.isOwnMessage ? 2.w : 12.w,
                  top: 0.3.h,
                  bottom: 0.3.h,
                ),
                child: Column(
                  crossAxisAlignment: widget.isOwnMessage
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    // WhatsApp-style pinned indicator
                    if (widget.isPinned)
                      Container(
                        margin: EdgeInsets.only(bottom: 0.3.h),
                        padding: EdgeInsets.symmetric(
                          horizontal: 2.5.w,
                          vertical: 0.25.h,
                        ),
                        decoration: BoxDecoration(
                          color: adminGold.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: adminGold.withOpacity(0.25),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.push_pin,
                                size: 10.sp, color: adminGold),
                            SizedBox(width: 1.w),
                            Text(
                              'Pinned',
                              style: TextStyle(
                                fontSize: 9.5.sp,
                                color: adminGold,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Avatar + Bubble row
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Avatar for others' messages
                        if (!widget.isOwnMessage) ...[
                          _buildAvatar(),
                          SizedBox(width: 2.w),
                        ],

                        // Bubble
                        Flexible(
                          child: Container(
                            padding: hasMedia
                                ? EdgeInsets.all(0.8.w)
                                : EdgeInsets.symmetric(
                                    horizontal: 3.5.w,
                                    vertical: 1.2.h,
                                  ),
                            decoration: BoxDecoration(
                              color: widget.isOwnMessage
                                  ? primaryColor
                                  : Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: Radius.circular(
                                    widget.isOwnMessage ? 18 : 4),
                                bottomRight: Radius.circular(
                                    widget.isOwnMessage ? 4 : 18),
                              ),
                              border: widget.isOwnMessage
                                  ? null
                                  : Border.all(
                                      color: widget.isSenderAdmin
                                          ? adminGold.withOpacity(0.4)
                                          : const Color(0xFFEDE6DC).withOpacity(0.3),
                                      width: widget.isSenderAdmin ? 1.5 : 0.8,
                                    ),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.isOwnMessage
                                      ? primaryColor.withOpacity(0.25)
                                      : Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                  spreadRadius: widget.isOwnMessage ? 1 : 0,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Sender name
                                if (!widget.isOwnMessage)
                                  Padding(
                                    padding: hasMedia
                                        ? EdgeInsets.only(
                                            left: 2.5.w,
                                            top: 0.8.h,
                                            bottom: 0.3.h,
                                          )
                                        : EdgeInsets.only(bottom: 0.4.h),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            widget.userName,
                                            style: TextStyle(
                                              fontSize: 13.sp,
                                              fontWeight: FontWeight.w700,
                                              color: widget.isSenderAdmin
                                                  ? adminGold
                                                  : primaryColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (widget.isSenderAdmin) ...[
                                          SizedBox(width: 1.5.w),
                                          _buildAdminBadge(),
                                        ],
                                      ],
                                    ),
                                  ),

                                // Media
                                if (hasMedia) _buildMediaPreview(context),

                                // Message text
                                if (widget.message.isNotEmpty)
                                  Padding(
                                    padding: hasMedia
                                        ? EdgeInsets.only(
                                            left: 2.5.w,
                                            right: 2.5.w,
                                            top: 0.6.h,
                                          )
                                        : EdgeInsets.zero,
                                    child: Text(
                                      widget.message,
                                      style: TextStyle(
                                        fontSize: 14.5.sp,
                                        color: widget.isOwnMessage
                                            ? Colors.white
                                            : Theme.of(context).colorScheme.onSurface,
                                        height: 1.35,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),

                                SizedBox(height: 0.3.h),

                                // Timestamp row
                                Padding(
                                  padding: hasMedia
                                      ? EdgeInsets.only(
                                          left: 2.5.w,
                                          right: 2.5.w,
                                          bottom: 0.5.h,
                                        )
                                      : EdgeInsets.zero,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (widget.isOwnMessage &&
                                          widget.isSenderAdmin) ...[
                                        _buildOwnAdminBadge(),
                                        SizedBox(width: 1.5.w),
                                      ],
                                      Text(
                                        _formatTime(widget.createdAt),
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          color: widget.isOwnMessage
                                              ? Colors.white.withOpacity(0.7)
                                              : const Color(0xFFA09585),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (widget.isOwnMessage) ...[
                                        SizedBox(width: 1.w),
                                        Icon(
                                          Icons.done_all,
                                          size: 14,
                                          color:
                                              Colors.white.withOpacity(0.7),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ──── Sub widgets ────

  Widget _buildAvatar() {
    return Container(
      width: 8.w,
      height: 8.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.isSenderAdmin
              ? const Color(0xFFD4A017).withOpacity(0.5)
              : Theme.of(context).colorScheme.outline.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: (widget.userAvatarUrl != null &&
                widget.userAvatarUrl!.isNotEmpty)
            ? Image.network(
                widget.userAvatarUrl!,
                width: 8.w,
                height: 8.w,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
              )
            : _buildDefaultAvatar(),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    final primaryColor = Color(0xFF8B4513);
    return Container(
      width: 8.w,
      height: 8.w,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withOpacity(0.35),
            primaryColor.withOpacity(0.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          widget.userName.isNotEmpty
              ? widget.userName[0].toUpperCase()
              : '?',
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildAdminBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1.8.w, vertical: 0.2.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD4A017), Color(0xFFF0C040)],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4A017).withOpacity(0.25),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 10.sp, color: Colors.white),
          SizedBox(width: 0.5.w),
          Text(
            'Admin',
            style: TextStyle(
              fontSize: 10.sp,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnAdminBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1.5.w, vertical: 0.15.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 10.sp, color: Colors.white),
          SizedBox(width: 0.5.w),
          Text(
            'Admin',
            style: TextStyle(
              fontSize: 10.sp,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ──── Media Preview ────

  Widget _buildMediaPreview(BuildContext context) {
    final borderRadius = BorderRadius.circular(14);

    if (widget.mediaType == 'video') {
      return _buildVideoPreview(context, borderRadius);
    }

    // Image — auto-sizing
    return _buildImagePreview(context, borderRadius);
  }

  /// Video preview with real thumbnail from VideoPlayerController
  Widget _buildVideoPreview(BuildContext context, BorderRadius borderRadius) {
    return GestureDetector(
      onTap: () => _openVideoPlayer(context),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            minHeight: 18.h,
            maxHeight: 30.h,
          ),
          color: const Color(0xFF1A1A1A),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Real video thumbnail (first frame)
              if (_thumbReady && _thumbController != null)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _thumbController!.value.size.width,
                    height: _thumbController!.value.size.height,
                    child: VideoPlayer(_thumbController!),
                  ),
                )
              else
                // Loading state / fallback
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.videocam_rounded,
                        color: Colors.white.withOpacity(0.25),
                        size: 12.w,
                      ),
                      SizedBox(height: 1.h),
                      SizedBox(
                        width: 6.w,
                        height: 6.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ],
                  ),
                ),

              // Bottom gradient
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.5),
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
              ),

              // Play button
              Center(
                child: Container(
                  padding: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 9.w,
                  ),
                ),
              ),

              // Video badge + duration
              Positioned(
                bottom: 1.h,
                left: 2.w,
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 2.w, vertical: 0.35.h),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam_rounded,
                          color: Colors.white, size: 3.5.w),
                      SizedBox(width: 1.w),
                      Text(
                        _thumbReady && _thumbController != null
                            ? _formatDuration(_thumbController!.value.duration)
                            : 'Video',
                        style: TextStyle(
                          fontSize: 8.5.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Image preview — auto-sizing based on aspect ratio
  Widget _buildImagePreview(BuildContext context, BorderRadius borderRadius) {
    return GestureDetector(
      onTap: () => _showFullImage(context),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Image.network(
          widget.mediaUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            final percent = progress.expectedTotalBytes != null
                ? (progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes! *
                        100)
                    .toInt()
                : null;
            return Container(
              height: 22.h,
              width: double.infinity,
              decoration: BoxDecoration(
                color: widget.isOwnMessage
                    ? Colors.white.withOpacity(0.08)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 10.w,
                    height: 10.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: widget.isOwnMessage
                          ? Colors.white.withOpacity(0.7)
                          : Theme.of(context).colorScheme.primary,
                      value: percent != null ? percent / 100 : null,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    percent != null ? '$percent%' : 'Loading...',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: widget.isOwnMessage
                          ? Colors.white.withOpacity(0.6)
                          : const Color(0xFF8B7355),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          },
          errorBuilder: (_, __, ___) => Container(
            height: 14.h,
            width: double.infinity,
            decoration: BoxDecoration(
              color: widget.isOwnMessage
                  ? Colors.white.withOpacity(0.08)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_outlined,
                    size: 8.w,
                    color: widget.isOwnMessage
                        ? Colors.white54
                        : Colors.grey[400]),
                SizedBox(height: 0.5.h),
                Text(
                  'Image unavailable',
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: widget.isOwnMessage
                        ? Colors.white54
                        : Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ──── Fullscreen Video Player ────

  void _openVideoPlayer(BuildContext context) {
    if (widget.mediaUrl == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenVideoPlayer(
          videoUrl: widget.mediaUrl!,
          userName: widget.userName,
        ),
      ),
    );
  }

  // ──── Fullscreen Image Viewer ────

  void _showFullImage(BuildContext context) {
    if (widget.mediaUrl == null) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        pageBuilder: (ctx, anim, secondaryAnim) {
          return FadeTransition(
            opacity: anim,
            child: Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(ctx),
                ),
                title: Text(
                  widget.userName,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              body: Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    widget.mediaUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image,
                          color: Colors.white54, size: 48),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  // ──── Duration formatter ────

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  // ──── Options bottom sheet ────

  void _showOptions(BuildContext context) {
    final canDelete = widget.isOwnMessage || widget.isAdmin;
    final canPin = widget.isAdmin;

    if (!canDelete && !canPin) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 1.5.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 10.w,
                  height: 0.4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey[350],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                SizedBox(height: 1.h),

                // Message preview
                if (widget.message.isNotEmpty)
                  Container(
                    margin:
                        EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
                    padding:
                        EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.message.length > 80
                          ? '${widget.message.substring(0, 80)}...'
                          : widget.message,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                SizedBox(height: 0.5.h),

                if (canPin)
                  _buildOptionTile(
                    icon: widget.isPinned
                        ? Icons.push_pin_outlined
                        : Icons.push_pin,
                    label: widget.isPinned ? 'Unpin Message' : 'Pin Message',
                    color: const Color(0xFFD4A017),
                    onTap: () {
                      Navigator.pop(ctx);
                      if (widget.isPinned) {
                        widget.onUnpin?.call();
                      } else {
                        widget.onPin?.call();
                      }
                    },
                  ),

                if (canDelete)
                  _buildOptionTile(
                    icon: Icons.delete_outline,
                    label: widget.isOwnMessage
                        ? 'Delete Message'
                        : 'Delete (Admin)',
                    color: Colors.red,
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onDelete?.call();
                    },
                  ),

                SizedBox(height: 0.5.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.8.h),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              SizedBox(width: 4.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Full-screen video player with Chewie
// ──────────────────────────────────────────────

class _FullScreenVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String userName;

  const _FullScreenVideoPlayer({
    required this.videoUrl,
    required this.userName,
  });

  @override
  State<_FullScreenVideoPlayer> createState() =>
      _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<_FullScreenVideoPlayer> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );

      await _videoController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF8B4513),
          handleColor: const Color(0xFF8B4513),
          bufferedColor: Colors.white.withOpacity(0.3),
          backgroundColor: Colors.white.withOpacity(0.1),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    color: Colors.white54, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Failed to load video',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      );

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('❌ Video player init error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: Colors.white, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.userName,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: Center(
        child: _isLoading
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                    strokeWidth: 2.5,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Loading video...',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              )
            : _errorMessage != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Failed to play video',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _errorMessage = null;
                          });
                          _initPlayer();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  )
                : _chewieController != null
                    ? Chewie(controller: _chewieController!)
                    : const SizedBox.shrink(),
      ),
    );
  }
}
