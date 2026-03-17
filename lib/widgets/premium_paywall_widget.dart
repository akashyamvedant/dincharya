// lib/widgets/premium_paywall_widget.dart
//
// Reusable soft paywall widget shown when free users try to access premium features.
// Displays a beautiful bottom sheet with feature name, benefit text, and upgrade CTA.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../core/app_export.dart';
import '../presentation/payment/payment_plans_screen.dart';
import '../services/subscription_manager.dart';

/// Show a soft paywall bottom sheet. Returns true if user chose to navigate to upgrade.
Future<bool> showPremiumPaywall(
  BuildContext context, {
  required String featureName,
  required String description,
  IconData icon = Icons.workspace_premium,
}) async {
  HapticFeedback.mediumImpact();

  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _PremiumPaywallSheet(
      featureName: featureName,
      description: description,
      icon: icon,
    ),
  );

  return result ?? false;
}

class _PremiumPaywallSheet extends StatelessWidget {
  final String featureName;
  final String description;
  final IconData icon;

  const _PremiumPaywallSheet({
    required this.featureName,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final subManager = SubscriptionManager();
    final remaining = subManager.aiMessagesRemaining;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(6.w, 3.h, 6.w, 5.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 3.h),

          // Premium icon
          Container(
            padding: EdgeInsets.all(5.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFDAA520),
                  Color(0xFFFFD700),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0xFFDAA520).withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 36),
          ),
          SizedBox(height: 2.h),

          // Title
          Text(
            '🔒 $featureName',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 1.h),

          // Description
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              height: 1.5,
            ),
          ),
          SizedBox(height: 3.h),

          // Premium benefits compact list
          _buildBenefitRow(context, Icons.smart_toy, 'Unlimited AI Guide conversations'),
          _buildBenefitRow(context, Icons.self_improvement, 'Premium guided sessions'),
          _buildBenefitRow(context, Icons.analytics, 'Advanced analytics & insights'),
          _buildBenefitRow(context, Icons.block, 'Ad-free experience'),
          SizedBox(height: 3.h),

          // Upgrade button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
                // Navigate with MaterialPageRoute since PaymentPlansScreen needs userData
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PaymentPlansScreen(userData: const {}),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFDAA520),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 2.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.workspace_premium, size: 22),
                  SizedBox(width: 2.w),
                  Text(
                    'Upgrade to Premium',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 1.5.h),

          // Dismiss
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Maybe Later',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(BuildContext context, IconData benefitIcon, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.h),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Color(0xFFDAA520), size: 20),
          SizedBox(width: 3.w),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
