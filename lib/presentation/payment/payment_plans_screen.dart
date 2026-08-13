import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../admin_messages/admin_message_popup.dart';

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
    // Check for admin in-app messages targeting this page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAdminMessages();
    });
  }

  /// Check for unread admin popup messages targeting this page.
  Future<void> _checkAdminMessages() async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      await AdminMessagePopup.showPendingMessages(context, triggerPage: 'payment');
    } catch (e) {
      debugPrint('⚠️ Admin message check failed: $e');
    }
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
            backgroundColor: Theme.of(context).colorScheme.primary,
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close,
              color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Premium Plans',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _restorePurchases,
            child: Text(
              'Restore',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
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
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'Get unlimited access to all features',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface
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
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Loading plans...',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
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

      // Bottom purchase button (safely clamp index in case plans list changed)
      bottomNavigationBar: _buildPurchaseButton(
        _plans[_selectedPlanIndex.clamp(0, _plans.length - 1)],
      ),
    );
  }

  Widget _buildPremiumIcon() {
    return Container(
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.tertiary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
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
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Color(0xFF8B4513)
                : Theme.of(context).colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary
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
                      ? Color(0xFF8B4513)
                      : Theme.of(context).colorScheme.outline,
                  width: 2,
                ),
                color: isSelected
                    ? Color(0xFF8B4513)
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
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).colorScheme.onSurface,
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
                            style: Theme.of(context).textTheme.labelSmall
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
                        Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface
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
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
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
                        Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What you get',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
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
                        color: Theme.of(context).colorScheme.primary
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        feature['icon'] as IconData,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Text(
                        feature['text'] as String,
                        style: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
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
            color: Theme.of(context).colorScheme.tertiary
                .withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon,
              color: Theme.of(context).colorScheme.tertiary,
              size: 24),
        ),
        SizedBox(height: 1.h),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface
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
        color: Theme.of(context).colorScheme.surface,
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
                      backgroundColor: Theme.of(context).colorScheme.primary,
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
                                style: Theme.of(context).textTheme.titleMedium
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
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface
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
        color: Theme.of(context).colorScheme.surface,
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
            style: Theme.of(context).textTheme.headlineSmall
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
                  Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface
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
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: EdgeInsets.symmetric(vertical: 2.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Start Exploring',
                  style: Theme.of(context).textTheme.titleMedium
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
