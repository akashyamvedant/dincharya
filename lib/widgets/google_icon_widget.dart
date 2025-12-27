import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GoogleIconWidget extends StatelessWidget {
  final double size;
  final Color? color;

  const GoogleIconWidget({
    super.key,
    this.size = 24.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding:
            EdgeInsets.all(size * 0.08), // Small padding for better proportions
        child: SvgPicture.asset(
          'assets/images/google_logo.svg',
          width: size * 0.84, // Account for padding
          height: size * 0.84,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
