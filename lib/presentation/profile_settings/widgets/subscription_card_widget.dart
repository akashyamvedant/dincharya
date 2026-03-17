import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_export.dart';
import '../../payment/payment_plans_screen.dart';
import '../../../models/payment_models.dart';
import '../../../services/subscription_manager.dart';

class SubscriptionCardWidget extends StatefulWidget {
  final Map<String, dynamic> userData;

  const SubscriptionCardWidget({
    super.key,
    required this.userData,
  });

  @override
  State<SubscriptionCardWidget> createState() => _SubscriptionCardWidgetState();
}

class _SubscriptionCardWidgetState extends State<SubscriptionCardWidget>
    with TickerProviderStateMixin {
  final PaymentService _paymentService = PaymentService();
  bool _isPremium = false;
  bool _isLoading = true;
  int _selectedPlanIndex = 1; // Default to yearly (best value)
  late PageController _pageController;
  late AnimationController _shimmerController;
  List<PaymentPlan> _plans = []; // Loaded from Google Play or local fallback

  static const Color warmBrown = Color(0xFF8B4513);
  static const Color warmAmber = Color(0xFFD4A574);
  static const Color premiumGold = Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    _plans = PaymentPlan.getLocalizedPlans(); // Immediate fallback
    _pageController = PageController(
      viewportFraction: 0.85,
      initialPage: _selectedPlanIndex,
    );
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _checkSubscriptionStatus();
    _loadGooglePlayPlans();
  }

  /// Load plans from Google Play products, fallback to local pricing
  Future<void> _loadGooglePlayPlans() async {
    try {
      await _paymentService.initialize();
      await Future.delayed(const Duration(milliseconds: 500));
      final googleProducts = _paymentService.products;
      if (googleProducts.isNotEmpty && mounted) {
        setState(() {
          _plans = PaymentPlan.fromGooglePlayProducts(googleProducts);
          if (_selectedPlanIndex >= _plans.length) {
            _selectedPlanIndex = _plans.length - 1;
          }
        });
        debugPrint('✅ SubscriptionCard: loaded ${_plans.length} Google Play products');
      } else {
        // Retry once
        await Future.delayed(const Duration(seconds: 2));
        await _paymentService.loadProducts();
        final retryProducts = _paymentService.products;
        if (retryProducts.isNotEmpty && mounted) {
          setState(() {
            _plans = PaymentPlan.fromGooglePlayProducts(retryProducts);
            if (_selectedPlanIndex >= _plans.length) {
              _selectedPlanIndex = _plans.length - 1;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('⚠️ SubscriptionCard: using local fallback pricing: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _checkSubscriptionStatus() async {
    // Use SubscriptionManager as single source of truth (always refresh from DB)
    final subManager = SubscriptionManager();
    await subManager.refresh();
    if (mounted) {
      setState(() {
        _isPremium = subManager.isPremium;
        _isLoading = false;
      });
    }
  }

  void _onPlanSelected(int index) {
    HapticFeedback.selectionClick();
    setState(() => _selectedPlanIndex = index);
    _pageController.animateToPage(
      index,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _navigateToPayment(PaymentPlan plan) async {
    HapticFeedback.mediumImpact();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentPlansScreen(userData: widget.userData),
      ),
    );
    if (result == true) {
      _checkSubscriptionStatus();
    }
  }

  void _showManageDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildManageSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingCard();
    }

    if (_isPremium) {
      return _buildPremiumActiveCard();
    }

    return _buildUpgradeCard();
  }

  Widget _buildLoadingCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: warmBrown.withOpacity(0.2)),
      ),
      child: Center(
        child: CircularProgressIndicator(color: warmBrown),
      ),
    );
  }

  Widget _buildPremiumActiveCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [warmBrown.withOpacity(0.15), warmAmber.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: premiumGold.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: premiumGold.withOpacity(0.2),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Shimmer effect
            AnimatedBuilder(
              animation: _shimmerController,
              builder: (context, child) {
                return Positioned(
                  left: -100 + (_shimmerController.value * 400),
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0),
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            
            Padding(
              padding: EdgeInsets.all(4.w),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Premium badge
                      Container(
                        padding: EdgeInsets.all(3.w),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [premiumGold, warmAmber],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: premiumGold.withOpacity(0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Icon(Icons.workspace_premium, color: Colors.white, size: 24),
                      ),
                      SizedBox(width: 3.w),
                      
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Premium Active',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                SizedBox(width: 2.w),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.3.h),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '✓ ACTIVE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 0.5.h),
                            Text(
                              'Enjoy all premium features!',
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  
                  // Manage button
                  GestureDetector(
                    onTap: _showManageDialog,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 1.5.h),
                      decoration: BoxDecoration(
                        color: warmBrown.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: warmBrown.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.settings, color: warmBrown, size: 18),
                          SizedBox(width: 2.w),
                          Text(
                            'Manage Subscription',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpgradeCard() {
    final plans = _plans;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [warmBrown.withOpacity(0.1), warmAmber.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: warmBrown.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: warmBrown.withOpacity(0.1),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: EdgeInsets.all(4.w),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(2.5.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [warmBrown, warmAmber]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.diamond, color: Colors.white, size: 20),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upgrade to Premium',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Text(
                        'Unlock all features',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                // Plan toggle
                _buildPlanToggle(),
              ],
            ),
          ),

          // Plans Slider
          SizedBox(
            height: 22.h,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _selectedPlanIndex = index),
              itemCount: plans.length,
              itemBuilder: (context, index) => _buildPlanCard(plans[index], index),
            ),
          ),

          // Page indicators
          Padding(
            padding: EdgeInsets.symmetric(vertical: 1.5.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(plans.length, (index) {
                final isSelected = index == _selectedPlanIndex;
                return AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  margin: EdgeInsets.symmetric(horizontal: 1.w),
                  width: isSelected ? 6.w : 2.w,
                  height: 0.8.h,
                  decoration: BoxDecoration(
                    color: isSelected ? warmBrown : warmBrown.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanToggle() {
    return Container(
      padding: EdgeInsets.all(0.5.w),
      decoration: BoxDecoration(
        color: warmBrown.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _buildToggleButton('Monthly', 0),
          _buildToggleButton('Yearly', 1),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, int index) {
    final isSelected = _selectedPlanIndex == index;
    return GestureDetector(
      onTap: () => _onPlanSelected(index),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.8.h),
        decoration: BoxDecoration(
          color: isSelected ? warmBrown : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Theme.of(context).colorScheme.primary,
            fontSize: 9.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(PaymentPlan plan, int index) {
    final isSelected = index == _selectedPlanIndex;
    final isYearly = plan.duration == 'year';
    
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      margin: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                colors: isYearly
                    ? [warmBrown.withOpacity(0.15), premiumGold.withOpacity(0.1)]
                    : [warmBrown.withOpacity(0.1), warmAmber.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isSelected ? null : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? warmBrown : warmBrown.withOpacity(0.2),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: warmBrown.withOpacity(0.2),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(3.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plan header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            plan.name,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          if (plan.isPopular) ...[
                            SizedBox(width: 2.w),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 1.5.w, vertical: 0.3.h),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [premiumGold, warmAmber]),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'BEST VALUE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 7.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 0.5.h),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            plan.googlePlayPrice ?? '${GeoPricing.getPricing(GeoPricing.detectTier()).currencySymbol}${plan.price.toInt()}',
                            style: TextStyle(
                              fontSize: 22.sp,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Text(
                            plan.duration == 'lifetime' ? '' : '/${plan.duration}',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                            ),
                          ),
                          if (isYearly) ...[
                            SizedBox(width: 2.w),
                            Builder(builder: (context) {
                              // Calculate actual savings vs monthly plan
                              final monthlyPlan = _plans.where((p) => p.duration == 'month').firstOrNull;
                              final savingsPercent = monthlyPlan != null
                                  ? ((1 - (plan.price / 12) / monthlyPlan.price) * 100).round()
                                  : 0;
                              if (savingsPercent <= 0) return SizedBox.shrink();
                              return Container(
                                padding: EdgeInsets.symmetric(horizontal: 1.5.w, vertical: 0.2.h),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Save $savingsPercent%',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 8.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 1.5.h),
            
            // Features (compact)
            Expanded(
              child: Wrap(
                spacing: 2.w,
                runSpacing: 0.5.h,
                children: plan.features.take(4).map((feature) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 12),
                    SizedBox(width: 1.w),
                    Text(
                      feature,
                      style: TextStyle(fontSize: 9.sp, color: Theme.of(context).colorScheme.primary.withOpacity(0.7)),
                    ),
                  ],
                )).toList(),
              ),
            ),
            
            // Select button
            GestureDetector(
              onTap: () => _navigateToPayment(plan),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 1.2.h),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(colors: [warmBrown, warmAmber])
                      : null,
                  color: isSelected ? null : warmBrown.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    isSelected ? 'Subscribe Now' : 'Select Plan',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.sp,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManageSheet() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 12.w,
            height: 0.5.h,
            margin: EdgeInsets.symmetric(vertical: 2.h),
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Padding(
            padding: EdgeInsets.all(4.w),
            child: Column(
              children: [
                // Premium status
                Container(
                  padding: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [warmBrown.withOpacity(0.1), warmAmber.withOpacity(0.05)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: premiumGold.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(3.w),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [premiumGold, warmAmber]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.workspace_premium, color: Colors.white, size: 24),
                      ),
                      SizedBox(width: 3.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Premium Member',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            Text(
                              'Your subscription is active',
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 2.h),
                
                // Options
                _buildManageOption(
                  icon: Icons.receipt_long,
                  title: 'View Receipt',
                  subtitle: 'Download payment receipt',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Receipt feature coming soon!')),
                    );
                  },
                ),
                
                _buildManageOption(
                  icon: Icons.support_agent,
                  title: 'Contact Support',
                  subtitle: 'Get help with your subscription',
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Open support
                  },
                ),
                
                _buildManageOption(
                  icon: Icons.cancel,
                  title: 'Cancel Subscription',
                  subtitle: 'You will lose premium access',
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(context);
                    _showCancelDialog();
                  },
                ),
                
                SizedBox(height: 2.h),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManageOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? Colors.red : warmBrown;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(3.w),
        margin: EdgeInsets.only(bottom: 1.h),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Subscription?'),
        content: Text(
          'To cancel your subscription, you need to manage it through Google Play Store. '
          'This will open your Play Store subscriptions page.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Keep Premium'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Open Google Play subscriptions management page
              // Users MUST cancel through Play Store for Google Play Billing
              final url = Uri.parse(
                'https://play.google.com/store/account/subscriptions?package=com.akashyam.dincharya',
              );
              try {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              } catch (e) {
                // Fallback: open generic subscriptions page
                await launchUrl(
                  Uri.parse('https://play.google.com/store/account/subscriptions'),
                  mode: LaunchMode.externalApplication,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Open Play Store'),
          ),
        ],
      ),
    );
  }
}
