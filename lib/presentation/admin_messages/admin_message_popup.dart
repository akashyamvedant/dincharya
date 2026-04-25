// lib/presentation/admin_messages/admin_message_popup.dart
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/admin_message_service.dart';

/// Displays admin messages as beautiful popups, banners, or bottom sheets.
class AdminMessagePopup {
  static final AdminMessageService _service = AdminMessageService();

  /// Show all pending messages one by one.
  /// [triggerPage] — which page is requesting (e.g., 'dashboard', 'guided').
  static Future<void> showPendingMessages(BuildContext context, {String triggerPage = 'dashboard'}) async {
    final messages = await _service.checkForMessages(triggerPage: triggerPage);
    if (messages.isEmpty || !context.mounted) return;

    // Show highest priority message first
    final message = messages.first;
    final type = message['type'] as String? ?? 'popup';

    switch (type) {
      case 'banner':
        _showBanner(context, message);
        break;
      case 'bottomsheet':
        _showBottomSheet(context, message);
        break;
      case 'popup':
      default:
        _showPopupDialog(context, message);
        break;
    }
  }

  /// Show a centered popup dialog.
  static void _showPopupDialog(BuildContext context, Map<String, dynamic> msg) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (context, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(
            opacity: anim1,
            child: _PopupDialogContent(message: msg),
          ),
        );
      },
    ).then((_) {
      // Mark as read when dismissed
      _service.markAsRead(msg['id']);
    });
  }

  /// Show a top banner.
  static void _showBanner(BuildContext context, Map<String, dynamic> msg) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    bool isDismissed = false; // Guard against double-dismiss race condition
    
    // Store parent context for navigation (overlay context can't navigate)
    final parentContext = context;

    entry = OverlayEntry(
      builder: (_) => _BannerWidget(
        message: msg,
        onDismiss: () {
          if (isDismissed) return;
          isDismissed = true;
          entry.remove();
          _service.markAsRead(msg['id']);
        },
        onAction: () {
          if (isDismissed) return;
          isDismissed = true;
          entry.remove();
          _service.markActionTaken(msg['id']);
          _handleAction(parentContext, msg);
        },
      ),
    );

    overlay.insert(entry);

    // Auto-dismiss after 8 seconds
    Future.delayed(const Duration(seconds: 8), () {
      if (!isDismissed && entry.mounted) {
        isDismissed = true;
        entry.remove();
        _service.markAsRead(msg['id']);
      }
    });
  }

  /// Show a bottom sheet.
  static void _showBottomSheet(BuildContext context, Map<String, dynamic> msg) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BottomSheetContent(message: msg),
    ).then((_) {
      _service.markAsRead(msg['id']);
    });
  }

  /// Handle action button tap.
  static void _handleAction(BuildContext context, Map<String, dynamic> msg) {
    final actionType = msg['action_type'] as String? ?? 'none';
    final actionValue = msg['action_value'] as String? ?? '';

    _service.markActionTaken(msg['id']);

    switch (actionType) {
      case 'url':
        if (actionValue.isNotEmpty) {
          launchUrl(Uri.parse(actionValue), mode: LaunchMode.externalApplication);
        }
        break;
      case 'route':
        if (actionValue.isNotEmpty && context.mounted) {
          Navigator.pushNamed(context, actionValue);
        }
        break;
      case 'premium':
        if (context.mounted) {
          Navigator.pushNamed(context, '/payment-plans', arguments: {});
        }
        break;
      case 'none':
      default:
        break;
    }
  }
}

// ============================================================
// POPUP DIALOG CONTENT
// ============================================================
class _PopupDialogContent extends StatelessWidget {
  final Map<String, dynamic> message;
  const _PopupDialogContent({required this.message});

  @override
  Widget build(BuildContext context) {
    final title = message['title'] as String? ?? '';
    final body = message['body'] as String? ?? '';
    final imageUrl = message['image_url'] as String?;
    final actionType = message['action_type'] as String? ?? 'none';
    final hasAction = actionType != 'none';

    return Center(
      child: Container(
        width: 85.w,
        constraints: BoxConstraints(maxHeight: 75.h),
        margin: EdgeInsets.symmetric(horizontal: 5.w),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Material(
            color: Colors.transparent,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Image header
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      height: 22.h,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        height: 22.h,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        height: 15.h,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        child: Icon(Icons.campaign, size: 40, color: Theme.of(context).colorScheme.primary),
                      ),
                    )
                  else
                    // Gradient header when no image
                    Container(
                      height: 10.h,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.primary.withOpacity(0.7),
                          ],
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Decorative circles
                          Positioned(
                            right: -20,
                            top: -20,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                          ),
                          Positioned(
                            left: -10,
                            bottom: -10,
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.08),
                              ),
                            ),
                          ),
                          Center(
                            child: Icon(
                              Icons.campaign_rounded,
                              size: 40,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Content
                  Padding(
                    padding: EdgeInsets.all(5.w),
                    child: Column(
                      children: [
                        // Title
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 19.sp,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.3,
                          ),
                        ),

                        SizedBox(height: 1.5.h),

                        // Body
                        Text(
                          body,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15.sp,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            height: 1.5,
                          ),
                        ),

                        SizedBox(height: 3.h),

                        // Action button
                        if (hasAction)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                AdminMessagePopup._handleAction(context, message);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 1.8.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 2,
                              ),
                              child: Text(
                                _getActionLabel(actionType, message),
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                        if (hasAction) SizedBox(height: 1.5.h),

                        // Dismiss button
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'बाद में / Dismiss',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                              fontSize: 14.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getActionLabel(String actionType, Map<String, dynamic> msg) {
    // Use custom label if admin set one
    final customLabel = msg['action_label'] as String?;
    if (customLabel != null && customLabel.isNotEmpty) return customLabel;
    switch (actionType) {
      case 'url':
        return 'Open Link 🔗';
      case 'route':
        return 'Let\'s Go! →';
      case 'premium':
        return 'Upgrade to Premium ⭐';
      default:
        return 'OK';
    }
  }
}

// ============================================================
// BANNER WIDGET
// ============================================================
class _BannerWidget extends StatefulWidget {
  final Map<String, dynamic> message;
  final VoidCallback onDismiss;
  final VoidCallback onAction;

  const _BannerWidget({
    required this.message,
    required this.onDismiss,
    required this.onAction,
  });

  @override
  State<_BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<_BannerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.message['title'] as String? ?? '';
    final body = widget.message['body'] as String? ?? '';
    final actionType = widget.message['action_type'] as String? ?? 'none';

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: SafeArea(
          child: Container(
            margin: EdgeInsets.all(3.w),
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.campaign_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),

                SizedBox(width: 3.w),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15.sp,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 0.5.h),
                      Text(
                        body,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (actionType != 'none') ...[
                        SizedBox(height: 1.h),
                        GestureDetector(
                          onTap: widget.onAction,
                          child: Text(
                            'View →',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14.sp,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Close button
                GestureDetector(
                  onTap: widget.onDismiss,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// BOTTOM SHEET CONTENT
// ============================================================
class _BottomSheetContent extends StatelessWidget {
  final Map<String, dynamic> message;
  const _BottomSheetContent({required this.message});

  @override
  Widget build(BuildContext context) {
    final title = message['title'] as String? ?? '';
    final body = message['body'] as String? ?? '';
    final imageUrl = message['image_url'] as String?;
    final actionType = message['action_type'] as String? ?? 'none';
    final hasAction = actionType != 'none';

    return Container(
      constraints: BoxConstraints(maxHeight: 70.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: EdgeInsets.only(top: 1.5.h),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Image
            if (imageUrl != null && imageUrl.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    height: 20.h,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 20.h,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),

            Padding(
              padding: EdgeInsets.all(5.w),
              child: Column(
                children: [
                  // Title
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 19.sp,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),

                  SizedBox(height: 1.5.h),

                  // Body
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15.sp,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      height: 1.5,
                    ),
                  ),

                  SizedBox(height: 3.h),

                  // Action button
                  if (hasAction)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          AdminMessagePopup._handleAction(context, message);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 1.8.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _getActionLabel(actionType, message),
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  SizedBox(height: 1.5.h),

                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'बाद में / Dismiss',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        fontSize: 14.sp,
                      ),
                    ),
                  ),

                  SizedBox(height: 2.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getActionLabel(String actionType, Map<String, dynamic> msg) {
    // Use custom label if admin set one
    final customLabel = msg['action_label'] as String?;
    if (customLabel != null && customLabel.isNotEmpty) return customLabel;
    switch (actionType) {
      case 'url':
        return 'Open Link 🔗';
      case 'route':
        return 'Let\'s Go! →';
      case 'premium':
        return 'Upgrade to Premium ⭐';
      default:
        return 'OK';
    }
  }
}
