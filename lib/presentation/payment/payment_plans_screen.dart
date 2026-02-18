import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../models/payment_models.dart';

class PaymentPlansScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const PaymentPlansScreen({
    super.key,
    required this.userData,
  });

  @override
  State<PaymentPlansScreen> createState() => _PaymentPlansScreenState();
}

class _PaymentPlansScreenState extends State<PaymentPlansScreen>
    with TickerProviderStateMixin {
  final PaymentService _paymentService = PaymentService();
  late List<PaymentPlan> _plans;
  int _selectedPlanIndex = 1; // Default yearly (best value)
  bool _isProcessing = false;
  bool _isLoading = true;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _paymentService.initialize();

    // Start with local fallback plans (show immediately)
    _plans = PaymentPlan.getLocalizedPlans();

    _pulseController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // Load Google Play products in background
    _loadGooglePlayProducts();
  }

  /// Load products from Google Play and update UI
  Future<void> _loadGooglePlayProducts() async {
    try {
      // Wait a moment for PaymentService to fully initialize
      await Future.delayed(const Duration(milliseconds: 500));

      final googleProducts = _paymentService.products;
      if (googleProducts.isNotEmpty) {
        if (mounted) {
          setState(() {
            _plans = PaymentPlan.fromGooglePlayProducts(googleProducts);
            _isLoading = false;
            // Ensure selected index is valid
            if (_selectedPlanIndex >= _plans.length) {
              _selectedPlanIndex = _plans.length - 1;
            }
          });
          debugPrint('✅ UI updated with ${_plans.length} Google Play products');
        }
      } else {
        // Products might still be loading, retry once
        await Future.delayed(const Duration(seconds: 2));
        await _paymentService.loadProducts();
        final retryProducts = _paymentService.products;
        if (retryProducts.isNotEmpty && mounted) {
          setState(() {
            _plans = PaymentPlan.fromGooglePlayProducts(retryProducts);
            _isLoading = false;
            if (_selectedPlanIndex >= _plans.length) {
              _selectedPlanIndex = _plans.length - 1;
            }
          });
          debugPrint('✅ UI updated after retry with ${_plans.length} products');
        } else if (mounted) {
          setState(() => _isLoading = false);
          debugPrint('⚠️ Using local fallback pricing (Google Play products not available)');
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading Google Play products: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _selectPlan(int index) {
    HapticFeedback.selectionClick();
    setState(() => _selectedPlanIndex = index);
  }

  Future<void> _processPurchase() async {
    final plan = _plans[_selectedPlanIndex];

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    try {
      _paymentService.initiatePayment(
        plan: plan,
        userEmail: '', // Google Play handles user identity
        userPhone: '',
        userName: '',
        onResult: (result) {
          if (!mounted) return;
          setState(() => _isProcessing = false);
          if (result.success) {
            _showSuccessSheet(plan);
          } else {
            if (result.errorCode != 'USER_CANCELLED') {
              _showErrorSnackbar(result.errorMessage ?? 'Payment failed');
            }
          }
        },
      );

      // Safety timeout — in case callback never fires
      await Future.delayed(const Duration(seconds: 30));
      if (mounted && _isProcessing) {
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      _showErrorSnackbar('Unable to process payment: ${e.toString()}');
    }
  }

  Future<void> _restorePurchases() async {
    HapticFeedback.lightImpact();
    try {
      await _paymentService.restorePurchases();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.refresh, color: Colors.white),
                SizedBox(width: 8),
                Text('Checking for previous purchases...'),
              ],
            ),
            backgroundColor: AppTheme.lightTheme.colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackbar('Failed to restore purchases');
    }
  }

  void _showSuccessSheet(PaymentPlan plan) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildSuccessSheet(plan),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close,
              color: AppTheme.lightTheme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Premium Plans',
          style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.lightTheme.colorScheme.primary,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _restorePurchases,
            child: Text(
              'Restore',
              style: AppTheme.lightTheme.textTheme.labelLarge?.copyWith(
                color: AppTheme.lightTheme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        child: Column(
          children: [
            SizedBox(height: 2.h),

            // Premium icon
            _buildPremiumIcon(),
            SizedBox(height: 3.h),

            // Title
            Text(
              'Unlock Premium',
              style: AppTheme.lightTheme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.lightTheme.colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'Get unlimited access to all features',
              style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                color: AppTheme.lightTheme.colorScheme.onSurface
                    .withOpacity(0.7),
              ),
            ),
            SizedBox(height: 4.h),

            // Plan cards
            if (_isLoading)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 4.h),
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      color: AppTheme.lightTheme.colorScheme.primary,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Loading plans...',
                      style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.lightTheme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(_plans.length, (index) =>
                _buildPlanCard(_plans[index], index),
              ),
            SizedBox(height: 2.h),

            // Features list
            _buildFeaturesList(),
            SizedBox(height: 3.h),

            // Trust badges
            _buildTrustBadges(),
            SizedBox(height: 12.h),
          ],
        ),
      ),

      // Bottom purchase button
      bottomNavigationBar: _buildPurchaseButton(_plans[_selectedPlanIndex]),
    );
  }

  Widget _buildPremiumIcon() {
    return Container(
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.lightTheme.colorScheme.primary,
            AppTheme.lightTheme.colorScheme.tertiary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color:
                AppTheme.lightTheme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child:
          Icon(Icons.workspace_premium, color: Colors.white, size: 48),
    );
  }

  Widget _buildPlanCard(PaymentPlan plan, int index) {
    final isSelected = index == _selectedPlanIndex;
    final isYearly = plan.duration == 'year';
    final isLifetime = plan.duration == 'lifetime';

    // Use Google Play's localized price if available, else fallback
    final String displayPrice = plan.googlePlayPrice ??
        '${_getCurrencySymbol(plan.currency)}${plan.price.toInt()}';

    // Monthly equivalent for yearly
    String monthlyEquiv = '';
    if (isYearly) {
      if (plan.googlePlayPrice != null) {
        // Calculate from raw price
        final monthlyPrice = (plan.price / 12).round();
        monthlyEquiv = '${_getCurrencySymbol(plan.currency)}$monthlyPrice/month';
      } else {
        final monthlyPrice = (plan.price / 12).round();
        monthlyEquiv = '${_getCurrencySymbol(plan.currency)}$monthlyPrice/month';
      }
    }

    // Plan-specific tag
    String? tagText;
    Color tagColor = Colors.green;
    if (isYearly && plan.isPopular) {
      tagText = 'BEST VALUE';
      tagColor = Colors.green;
    } else if (isLifetime) {
      tagText = 'ONE TIME';
      tagColor = Colors.deepPurple;
    }

    return GestureDetector(
      onTap: () => _selectPlan(index),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        margin: EdgeInsets.only(bottom: 2.h),
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.lightTheme.colorScheme.primary.withOpacity(0.1)
              : AppTheme.lightTheme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.lightTheme.colorScheme.primary
                : AppTheme.lightTheme.colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.lightTheme.colorScheme.primary
                        .withOpacity(0.2),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Radio button
            AnimatedContainer(
              duration: Duration(milliseconds: 200),
              width: 7.w,
              height: 7.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppTheme.lightTheme.colorScheme.primary
                      : AppTheme.lightTheme.colorScheme.outline,
                  width: 2,
                ),
                color: isSelected
                    ? AppTheme.lightTheme.colorScheme.primary
                    : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
            SizedBox(width: 4.w),

            // Plan info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          plan.name,
                          style: AppTheme.lightTheme.textTheme.titleMedium
                              ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color:
                                AppTheme.lightTheme.colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (tagText != null) ...[
                        SizedBox(width: 1.5.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 1.5.w, vertical: 0.3.h),
                          decoration: BoxDecoration(
                            color: tagColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tagText,
                            style: AppTheme
                                .lightTheme.textTheme.labelSmall
                                ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 8,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    isLifetime
                        ? 'Pay once, yours forever'
                        : isYearly
                            ? 'Best value for committed users'
                            : 'Perfect for trying out',
                    style:
                        AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.lightTheme.colorScheme.onSurface
                          .withOpacity(0.6),
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            SizedBox(width: 2.w),

            // Price
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 25.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      displayPrice,
                      style: AppTheme.lightTheme.textTheme.headlineSmall
                          ?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.lightTheme.colorScheme.primary,
                      ),
                    ),
                  ),
                  Text(
                    isLifetime
                        ? 'one-time'
                        : isYearly
                            ? monthlyEquiv
                            : '/month',
                    style:
                        AppTheme.lightTheme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.lightTheme.colorScheme.onSurface
                          .withOpacity(0.5),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get currency symbol from code
  String _getCurrencySymbol(String code) {
    switch (code.toUpperCase()) {
      case 'INR': return '₹';
      case 'USD': return '\$';
      case 'EUR': return '€';
      case 'GBP': return '£';
      case 'JPY': return '¥';
      default: return '$code ';
    }
  }

  Widget _buildFeaturesList() {
    final features = [
      {'icon': Icons.block, 'text': 'Ad-free experience'},
      {'icon': Icons.smart_toy, 'text': 'Unlimited AI Guide conversations'},
      {'icon': Icons.self_improvement, 'text': 'Premium guided sessions'},
      {'icon': Icons.analytics, 'text': 'Advanced analytics & insights'},
      {'icon': Icons.download, 'text': 'Offline content access'},
      {'icon': Icons.support_agent, 'text': 'Priority customer support'},
    ];

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              AppTheme.lightTheme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What you get',
            style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.lightTheme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 2.h),
          ...features.map((feature) => Padding(
                padding: EdgeInsets.only(bottom: 1.5.h),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(2.w),
                      decoration: BoxDecoration(
                        color: AppTheme.lightTheme.colorScheme.primary
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        feature['icon'] as IconData,
                        color:
                            AppTheme.lightTheme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Text(
                        feature['text'] as String,
                        style: AppTheme.lightTheme.textTheme.bodyLarge
                            ?.copyWith(
                          color: AppTheme
                              .lightTheme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildTrustBadges() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildTrustBadge(Icons.lock, 'Secure\nPayment'),
        _buildTrustBadge(Icons.replay, 'Cancel\nAnytime'),
        _buildTrustBadge(Icons.verified_user, 'Google Play\nProtected'),
      ],
    );
  }

  Widget _buildTrustBadge(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(3.w),
          decoration: BoxDecoration(
            color: AppTheme.lightTheme.colorScheme.tertiary
                .withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon,
              color: AppTheme.lightTheme.colorScheme.tertiary,
              size: 24),
        ),
        SizedBox(height: 1.h),
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTheme.lightTheme.textTheme.labelMedium?.copyWith(
            color: AppTheme.lightTheme.colorScheme.onSurface
                .withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildPurchaseButton(PaymentPlan plan) {
    final isLifetime = plan.duration == 'lifetime';

    // Use Google Play price or fallback
    final priceDisplay = plan.googlePlayPrice ??
        '${_getCurrencySymbol(plan.currency)}${plan.price.toInt()}';

    return Container(
      padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 4.h),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Purchase button
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_pulseController.value * 0.02),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _isProcessing ? null : _processPurchase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          AppTheme.lightTheme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 2.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: _isProcessing
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock_open, size: 22),
                              SizedBox(width: 2.w),
                              Text(
                                isLifetime
                                    ? 'Get Lifetime Access • $priceDisplay'
                                    : 'Start Premium • $priceDisplay/${plan.duration}',
                                style: AppTheme
                                    .lightTheme.textTheme.titleMedium
                                    ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 1.5.h),

          // Terms
          Text(
            isLifetime
                ? 'One-time payment • Secured by Google Play'
                : 'Cancel anytime • Managed by Google Play',
            style: AppTheme.lightTheme.textTheme.labelMedium?.copyWith(
              color: AppTheme.lightTheme.colorScheme.onSurface
                  .withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessSheet(PaymentPlan plan) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 3.h),

          // Success icon
          Container(
            padding: EdgeInsets.all(5.w),
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            child:
                Icon(Icons.check, color: Colors.white, size: 48),
          ),
          SizedBox(height: 2.h),

          Text(
            'Welcome to Premium! 🎉',
            style: AppTheme.lightTheme.textTheme.headlineSmall
                ?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 1.h),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            child: Text(
              plan.duration == 'lifetime'
                  ? 'Your Lifetime Access is now active. Enjoy all premium features forever!'
                  : 'Your ${plan.name} subscription is now active. Enjoy all premium features!',
              textAlign: TextAlign.center,
              style:
                  AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                color: AppTheme.lightTheme.colorScheme.onSurface
                    .withOpacity(0.7),
              ),
            ),
          ),
          SizedBox(height: 3.h),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close sheet
                  Navigator.pop(context, true); // Return success
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      AppTheme.lightTheme.colorScheme.primary,
                  padding: EdgeInsets.symmetric(vertical: 2.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Start Exploring',
                  style: AppTheme.lightTheme.textTheme.titleMedium
                      ?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 4.h),
        ],
      ),
    );
  }
}
