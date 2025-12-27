import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../payment/payment_plans_screen.dart';

class SubscriptionCardWidget extends StatefulWidget {
  final Map<String, dynamic> userData;

  const SubscriptionCardWidget({
    super.key,
    required this.userData,
  });

  @override
  State<SubscriptionCardWidget> createState() => _SubscriptionCardWidgetState();
}

class _SubscriptionCardWidgetState extends State<SubscriptionCardWidget> {
  final PaymentService _paymentService = PaymentService();
  bool _isPremium = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkSubscriptionStatus();
  }

  Future<void> _checkSubscriptionStatus() async {
    final isActive = await _paymentService.isSubscriptionActive();
    if (mounted) {
      setState(() {
        _isPremium = isActive;
        _isLoading = false;
      });
    }
  }

  void _handleSubscriptionAction(BuildContext context) async {
    if (_isPremium) {
      // Show subscription management dialog
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
                title: Text('Manage Subscription',
                    style: AppTheme.lightTheme.textTheme.titleMedium),
                content: Text(
                    'Your premium subscription is active. You can manage your subscription through your payment method or contact support for assistance.',
                    style: AppTheme.lightTheme.textTheme.bodyMedium),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close')),
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showCancelSubscriptionDialog();
                      },
                      child: Text('Cancel Subscription',
                          style: TextStyle(color: Colors.red))),
                ]);
          });
    } else {
      // Navigate to payment plans screen
      final result = await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  PaymentPlansScreen(userData: widget.userData)));

      if (result == true) {
        // Refresh subscription status after successful payment
        _checkSubscriptionStatus();
      }
    }
  }

  void _showCancelSubscriptionDialog() {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
              title: Text('Cancel Subscription',
                  style: AppTheme.lightTheme.textTheme.titleMedium),
              content: Text(
                  'Are you sure you want to cancel your premium subscription? You will lose access to all premium features.',
                  style: AppTheme.lightTheme.textTheme.bodyMedium),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Keep Subscription')),
                ElevatedButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _paymentService.clearSubscription();
                      _checkSubscriptionStatus();
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white),
                    child: const Text('Cancel')),
              ]);
        });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                  color: AppTheme.lightTheme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppTheme.lightTheme.colorScheme.outline
                          .withValues(alpha: 0.2),
                      width: 1)),
              child: const Center(child: CircularProgressIndicator())));
    }

    return Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _isPremium
                        ? [
                            AppTheme.lightTheme.colorScheme.tertiary
                                .withValues(alpha: 0.1),
                            AppTheme.lightTheme.colorScheme.primary
                                .withValues(alpha: 0.1),
                          ]
                        : [
                            AppTheme.lightTheme.colorScheme.surface,
                            AppTheme.lightTheme.colorScheme.surface
                                .withValues(alpha: 0.8),
                          ]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: _isPremium
                        ? AppTheme.lightTheme.colorScheme.primary
                            .withValues(alpha: 0.3)
                        : AppTheme.lightTheme.colorScheme.outline
                            .withValues(alpha: 0.2),
                    width: _isPremium ? 2 : 1),
                boxShadow: [
                  BoxShadow(
                      color: AppTheme.lightTheme.colorScheme.shadow
                          .withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4)),
                ]),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                    padding: EdgeInsets.all(2.w),
                    decoration: BoxDecoration(
                        color: _isPremium
                            ? AppTheme.lightTheme.colorScheme.tertiary
                                .withValues(alpha: 0.2)
                            : AppTheme.lightTheme.colorScheme.outline
                                .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12)),
                    child: CustomIconWidget(
                        iconName:
                            _isPremium ? 'workspace_premium' : 'account_circle',
                        color: _isPremium
                            ? AppTheme.lightTheme.colorScheme.tertiary
                            : AppTheme.lightTheme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                        size: 24)),
                SizedBox(width: 3.w),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        Text('${_isPremium ? 'Premium' : 'Free'} Plan',
                            style: AppTheme.lightTheme.textTheme.titleMedium
                                ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: _isPremium
                                        ? AppTheme
                                            .lightTheme.colorScheme.primary
                                        : AppTheme
                                            .lightTheme.colorScheme.onSurface)),
                        if (_isPremium) ...[
                          SizedBox(width: 2.w),
                          Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 2.w, vertical: 0.5.h),
                              decoration: BoxDecoration(
                                  color:
                                      AppTheme.lightTheme.colorScheme.tertiary,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text('ACTIVE',
                                  style: AppTheme
                                      .lightTheme.textTheme.labelSmall
                                      ?.copyWith(
                                          color: AppTheme.lightTheme.colorScheme
                                              .onTertiary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 10.sp))),
                        ],
                      ]),
                      SizedBox(height: 0.5.h),
                      Text(
                          _isPremium
                              ? 'Enjoy unlimited access to all premium features'
                              : 'Upgrade to Premium for the complete DinCharya experience with Razorpay secure payments.',
                          style: AppTheme.lightTheme.textTheme.bodySmall
                              ?.copyWith(
                                  color: AppTheme
                                      .lightTheme.colorScheme.onSurface
                                      .withValues(alpha: 0.7)),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis),
                    ])),
              ]),

              SizedBox(height: 2.h),

              // Features or Benefits
              if (!_isPremium) ...[
                Text('Premium Benefits:',
                    style: AppTheme.lightTheme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
                SizedBox(height: 1.h),
                Column(children: [
                  _buildFeatureItem('Ad-free experience', 'block'),
                  _buildFeatureItem('Offline content access', 'download'),
                  _buildFeatureItem('Advanced analytics', 'analytics'),
                  _buildFeatureItem('Priority support', 'support_agent'),
                ]),
                SizedBox(height: 1.h),
                Container(
                    padding: EdgeInsets.all(2.w),
                    decoration: BoxDecoration(
                        color: AppTheme.lightTheme.colorScheme.primary
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      CustomIconWidget(
                          iconName: 'payment',
                          color: AppTheme.lightTheme.colorScheme.primary,
                          size: 16),
                      SizedBox(width: 2.w),
                      Expanded(
                          child: Text(
                              'Secure payments powered by Razorpay. Perfect for Indian users!',
                              style: AppTheme.lightTheme.textTheme.bodySmall
                                  ?.copyWith(
                                      color: AppTheme
                                          .lightTheme.colorScheme.primary))),
                    ])),
                SizedBox(height: 2.h),
              ],

              // Action Button
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                      onPressed: () => _handleSubscriptionAction(context),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _isPremium
                              ? AppTheme.lightTheme.colorScheme.surface
                              : AppTheme.lightTheme.colorScheme.primary,
                          foregroundColor: _isPremium
                              ? AppTheme.lightTheme.colorScheme.primary
                              : AppTheme.lightTheme.colorScheme.onPrimary,
                          side: _isPremium
                              ? BorderSide(
                                  color:
                                      AppTheme.lightTheme.colorScheme.primary)
                              : null,
                          padding: EdgeInsets.symmetric(vertical: 1.5.h),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CustomIconWidget(
                                iconName: _isPremium ? 'settings' : 'upgrade',
                                color: _isPremium
                                    ? AppTheme.lightTheme.colorScheme.primary
                                    : AppTheme.lightTheme.colorScheme.onPrimary,
                                size: 20),
                            SizedBox(width: 2.w),
                            Text(
                                _isPremium
                                    ? 'Manage Subscription'
                                    : 'Upgrade to Premium',
                                style: AppTheme.lightTheme.textTheme.labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                          ]))),
            ])));
  }

  Widget _buildFeatureItem(String text, String iconName) {
    return Padding(
        padding: EdgeInsets.only(bottom: 0.8.h),
        child: Row(children: [
          CustomIconWidget(
              iconName: iconName,
              color: AppTheme.lightTheme.colorScheme.primary
                  .withValues(alpha: 0.7),
              size: 16),
          SizedBox(width: 2.w),
          Expanded(
              child: Text(text,
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.lightTheme.colorScheme.onSurface
                          .withValues(alpha: 0.7)))),
        ]));
  }
}
