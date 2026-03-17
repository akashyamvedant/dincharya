import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

/// Animated checkbox widget for task completion with celebration effects
class AnimatedTaskCheckbox extends StatefulWidget {
  final bool isCompleted;
  final double progress;
  final VoidCallback onTap;
  final Color? completedColor;
  final double size;

  const AnimatedTaskCheckbox({
    super.key,
    required this.isCompleted,
    this.progress = 0.0,
    required this.onTap,
    this.completedColor,
    this.size = 48,
  });

  @override
  State<AnimatedTaskCheckbox> createState() => _AnimatedTaskCheckboxState();
}

class _AnimatedTaskCheckboxState extends State<AnimatedTaskCheckbox>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _checkController;
  late AnimationController _celebrationController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;
  late Animation<double> _celebrationAnimation;
  
  bool _showCelebration = false;

  @override
  void initState() {
    super.initState();
    
    // Scale bounce animation
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    // Checkmark draw animation
    _checkController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.easeOut),
    );

    // Celebration animation
    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _celebrationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _celebrationController, curve: Curves.easeOut),
    );

    // Initialize state based on completion
    if (widget.isCompleted) {
      _checkController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(AnimatedTaskCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCompleted != oldWidget.isCompleted) {
      if (widget.isCompleted) {
        _playCompletionAnimation();
      } else {
        _checkController.reverse();
      }
    }
  }

  void _playCompletionAnimation() async {
    // Scale down
    await _scaleController.forward();
    await _scaleController.reverse();
    
    // Draw checkmark
    _checkController.forward();
    
    // Show celebration
    setState(() => _showCelebration = true);
    await _celebrationController.forward();
    
    // Hide celebration after delay
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      _celebrationController.reset();
      setState(() => _showCelebration = false);
    }
  }

  void _handleTap() {
    // Play tap animation
    _scaleController.forward().then((_) {
      _scaleController.reverse();
    });
    
    widget.onTap();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _checkController.dispose();
    _celebrationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final completedColor = widget.completedColor ?? 
        Color(0xFF8B4513);
    
    return GestureDetector(
      onTap: _handleTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Celebration particles
          if (_showCelebration) _buildCelebrationEffect(completedColor),
          
          // Main checkbox
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              );
            },
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isCompleted 
                    ? completedColor 
                    : Colors.transparent,
                border: Border.all(
                  color: widget.isCompleted 
                      ? completedColor 
                      : Colors.grey[400]!,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.isCompleted
                        ? completedColor.withOpacity(0.4)
                        : Colors.grey.withOpacity(0.2),
                    blurRadius: widget.isCompleted ? 12 : 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _buildCheckboxContent(completedColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckboxContent(Color completedColor) {
    if (widget.isCompleted) {
      return AnimatedBuilder(
        animation: _checkAnimation,
        builder: (context, child) {
          return CustomPaint(
            painter: _CheckmarkPainter(
              progress: _checkAnimation.value,
              color: Colors.white,
              strokeWidth: 3,
            ),
            child: const SizedBox.expand(),
          );
        },
      );
    } else if (widget.progress > 0) {
      return Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: widget.progress,
            strokeWidth: 3,
            backgroundColor: Theme.of(context).colorScheme.outline
                .withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(completedColor),
          ),
          Text(
            '${(widget.progress * 100).toInt()}%',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 8.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    } else {
      return Center(
        child: Icon(
          Icons.circle_outlined,
          color: Colors.grey[300],
          size: 20,
        ),
      );
    }
  }

  Widget _buildCelebrationEffect(Color color) {
    return AnimatedBuilder(
      animation: _celebrationAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: _CelebrationPainter(
            progress: _celebrationAnimation.value,
            color: color,
          ),
          child: SizedBox(
            width: widget.size * 2,
            height: widget.size * 2,
          ),
        );
      },
    );
  }
}

/// Custom painter for animated checkmark
class _CheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _CheckmarkPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final checkSize = size.width * 0.35;

    final path = Path();
    
    // Checkmark path: starting point, corner point, end point
    final startPoint = Offset(centerX - checkSize * 0.5, centerY);
    final cornerPoint = Offset(centerX - checkSize * 0.1, centerY + checkSize * 0.4);
    final endPoint = Offset(centerX + checkSize * 0.5, centerY - checkSize * 0.3);

    path.moveTo(startPoint.dx, startPoint.dy);
    
    // First segment (start to corner)
    if (progress <= 0.4) {
      final segmentProgress = progress / 0.4;
      final currentPoint = Offset.lerp(startPoint, cornerPoint, segmentProgress)!;
      path.lineTo(currentPoint.dx, currentPoint.dy);
    } else {
      path.lineTo(cornerPoint.dx, cornerPoint.dy);
      
      // Second segment (corner to end)
      final segmentProgress = (progress - 0.4) / 0.6;
      final currentPoint = Offset.lerp(cornerPoint, endPoint, segmentProgress)!;
      path.lineTo(currentPoint.dx, currentPoint.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Custom painter for celebration effect (expanding ring)
class _CelebrationPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CelebrationPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final currentRadius = maxRadius * progress;
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    final paint = Paint()
      ..color = color.withOpacity(opacity * 0.5)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, currentRadius, paint);

    // Second ring (delayed)
    if (progress > 0.2) {
      final secondProgress = ((progress - 0.2) / 0.8).clamp(0.0, 1.0);
      final secondRadius = maxRadius * secondProgress;
      final secondOpacity = (1.0 - secondProgress).clamp(0.0, 1.0);
      
      canvas.drawCircle(
        center, 
        secondRadius, 
        paint..color = color.withOpacity(secondOpacity * 0.3),
      );
    }
  }

  @override
  bool shouldRepaint(_CelebrationPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
