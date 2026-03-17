import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class WelcomeStepWidget extends StatelessWidget {
  const WelcomeStepWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration with enhanced visual appeal
          Container(
            width: 60.w,
            height: 30.h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary
                      .withValues(alpha: 0.08),
                  Theme.of(context).colorScheme.secondary
                      .withValues(alpha: 0.12),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary
                      .withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated sun icon
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 2000),
                  tween: Tween(begin: 0.8, end: 1.0),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: CustomIconWidget(
                        iconName: 'wb_sunny',
                        color: Theme.of(context).colorScheme.primary,
                        size: 64,
                      ),
                    );
                  },
                ),
                SizedBox(height: 2.h),
                // Meditation icon with subtle animation
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 1500),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 10 * (1 - value)),
                        child: CustomIconWidget(
                          iconName: 'self_improvement',
                          color: Theme.of(context).colorScheme.secondary,
                          size: 48,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          SizedBox(height: 4.h),

          // Headline
          Text(
            'Welcome to DinCharya',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 2.h),

          // Description
          Text(
            'Discover the ancient wisdom of daily routines. DinCharya helps you build discipline, peace, and productivity through personalized practices rooted in yogic traditions.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 3.h),

          // Features list
          Column(
            children: [
              _buildFeatureItem(
                context,
                'self_improvement',
                'Guided Meditation & Yoga',
              ),
              SizedBox(height: 1.h),
              _buildFeatureItem(
                context,
                'schedule',
                'Personalized Daily Routines',
              ),
              SizedBox(height: 1.h),
              _buildFeatureItem(
                context,
                'book',
                'Daily Journal & Mood Tracking',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context, String iconName, String text) {
    return Row(
      children: [
        CustomIconWidget(
          iconName: iconName,
          color: Theme.of(context).colorScheme.primary,
          size: 24,
        ),
        SizedBox(width: 3.w),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
