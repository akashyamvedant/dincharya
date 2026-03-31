// cached_pose_image.dart
// Reusable widget: offline-cached pose image with smooth animations
// Uses cached_network_image for disk caching + subtle entrance/breathing animations

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

/// A cached, animated pose image widget.
/// - Auto-caches images on disk for offline use (via cached_network_image)
/// - Smooth fade-in entrance animation
/// - Optional subtle "pulse" breathing effect (for active practice step)
/// - Shimmer loading placeholder
class CachedPoseImage extends StatefulWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final bool animate; // Enable entrance animation
  final bool breathe; // Enable subtle pulse (active step)
  final Color? placeholderColor;
  final IconData placeholderIcon;
  final double placeholderIconSize;

  const CachedPoseImage({
    super.key,
    required this.imageUrl,
    this.width = double.infinity,
    this.height = 180,
    this.fit = BoxFit.contain,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(20)),
    this.animate = true,
    this.breathe = false,
    this.placeholderColor,
    this.placeholderIcon = Icons.self_improvement,
    this.placeholderIconSize = 64,
  });

  @override
  State<CachedPoseImage> createState() => _CachedPoseImageState();
}

class _CachedPoseImageState extends State<CachedPoseImage>
    with TickerProviderStateMixin {
  // Entrance animation
  late AnimationController _entranceController;
  late Animation<double> _fadeIn;
  late Animation<double> _scaleIn;

  // Breathing pulse animation (optional)
  AnimationController? _breatheController;
  Animation<double>? _breatheScale;

  @override
  void initState() {
    super.initState();

    // Entrance: fade + scale from 0.95 → 1.0
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
    );
    _scaleIn = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutBack),
    );

    // Breathing pulse (subtle scale 1.0 → 1.02)
    if (widget.breathe) {
      _breatheController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 3000),
      );
      _breatheScale = Tween<double>(begin: 1.0, end: 1.015).animate(
        CurvedAnimation(parent: _breatheController!, curve: Curves.easeInOut),
      );
      _breatheController!.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(CachedPoseImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If image URL changed, re-trigger entrance
    if (oldWidget.imageUrl != widget.imageUrl) {
      _entranceController.reset();
    }
    // Toggle breathe
    if (widget.breathe && _breatheController == null) {
      _breatheController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 3000),
      );
      _breatheScale = Tween<double>(begin: 1.0, end: 1.015).animate(
        CurvedAnimation(parent: _breatheController!, curve: Curves.easeInOut),
      );
      _breatheController!.repeat(reverse: true);
    } else if (!widget.breathe && _breatheController != null) {
      _breatheController!.dispose();
      _breatheController = null;
      _breatheScale = null;
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _breatheController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final placeholderColor = widget.placeholderColor ?? primary.withValues(alpha: 0.08);

    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      return _buildPlaceholder(placeholderColor, primary);
    }

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: CachedNetworkImage(
        imageUrl: widget.imageUrl!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        // ── Loading: shimmer skeleton ──
        placeholder: (context, url) => _buildShimmer(placeholderColor, primary),
        // ── Error: placeholder icon ──
        errorWidget: (context, url, error) =>
            _buildPlaceholder(placeholderColor, primary),
        // ── Success: animate in ──
        imageBuilder: (context, imageProvider) {
          // Trigger entrance animation
          if (!_entranceController.isAnimating &&
              _entranceController.status != AnimationStatus.completed) {
            _entranceController.forward();
          }

          Widget imageWidget = AnimatedBuilder(
            animation: _entranceController,
            builder: (context, child) {
              return Opacity(
                opacity: widget.animate ? _fadeIn.value : 1.0,
                child: Transform.scale(
                  scale: widget.animate ? _scaleIn.value : 1.0,
                  child: child,
                ),
              );
            },
            child: Image(
              image: imageProvider,
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
            ),
          );

          // Wrap with breathing pulse if active
          if (widget.breathe && _breatheScale != null) {
            imageWidget = AnimatedBuilder(
              animation: _breatheController!,
              builder: (context, child) {
                return Transform.scale(
                  scale: _breatheScale!.value,
                  child: child,
                );
              },
              child: imageWidget,
            );
          }

          return imageWidget;
        },
      ),
    );
  }

  /// Shimmer loading skeleton
  Widget _buildShimmer(Color bgColor, Color primary) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
        color: bgColor,
      ),
      child: _ShimmerEffect(
        child: Container(
          width: widget.width,
          height: widget.height,
          color: bgColor,
        ),
      ),
    );
  }

  /// Static placeholder
  Widget _buildPlaceholder(Color bgColor, Color primary) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
        color: bgColor,
      ),
      child: Icon(
        widget.placeholderIcon,
        size: widget.placeholderIconSize,
        color: primary.withValues(alpha: 0.3),
      ),
    );
  }
}

/// Simple shimmer effect widget
class _ShimmerEffect extends StatefulWidget {
  final Widget child;
  const _ShimmerEffect({required this.child});

  @override
  State<_ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<_ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.grey.shade300,
                Colors.grey.shade100,
                Colors.grey.shade300,
              ],
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value,
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Thumbnail variant for grid view — smaller, no breathing, quick animation
class CachedPoseThumbnail extends StatelessWidget {
  final String? imageUrl;
  final int index;
  final Color? borderColor;

  const CachedPoseThumbnail({
    super.key,
    required this.imageUrl,
    required this.index,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: primary.withValues(alpha: 0.08),
          border: Border.all(color: borderColor ?? primary.withValues(alpha: 0.2)),
        ),
        child: Center(
          child: Text(
            '${index + 1}',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: primary.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor ?? primary.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: primary.withValues(alpha: 0.06),
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: primary.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          color: primary.withValues(alpha: 0.08),
          child: Center(
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: primary.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
