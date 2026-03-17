import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/constants/ad_constants.dart';
import '../../services/ads_service.dart';
import '../../services/subscription_manager.dart';
import '../../services/theme_provider.dart';

/// Native Ad Widget that matches Dincharya's warm brown theme
/// 
/// REACTIVE: Listens to SubscriptionManager — if user buys premium mid-session,
/// the loaded ad is disposed immediately without requiring app restart.
class NativeAdWidget extends StatefulWidget {
  final NativePlacement placement;
  final double? height;

  const NativeAdWidget({
    super.key,
    required this.placement,
    this.height,
  });

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;
  final SubscriptionManager _subManager = SubscriptionManager();

  @override
  void initState() {
    super.initState();
    // Listen for premium status changes (e.g., user buys premium mid-session)
    _subManager.addListener(_onPremiumStatusChanged);
    _loadAd();
  }

  /// React to premium status changes — dispose ad immediately
  void _onPremiumStatusChanged() {
    if (_subManager.isPremium && _nativeAd != null) {
      debugPrint('👑 Native [${widget.placement.name}]: Premium activated — disposing ad');
      _nativeAd?.dispose();
      if (mounted) {
        setState(() {
          _nativeAd = null;
          _isLoaded = false;
        });
      }
    }
  }

  void _loadAd() async {
    final adsService = AdsService();
    
    // Wait for AdsService initialization before checking premium status
    await adsService.waitForInitialization;
    
    // Don't load if premium user
    if (!adsService.shouldShowAds) {
      return;
    }

    if (!mounted) return;

    final isDark = ThemeProvider().isDarkMode;

    _nativeAd = NativeAd(
      adUnitId: AdConstants.getNativeAdId(widget.placement),
      factoryId: 'dincharyaNativeAd',
      customOptions: {'isDarkMode': isDark},
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          debugPrint('✅ Native ad loaded for ${widget.placement.name}');
          if (mounted) {
            setState(() => _isLoaded = true);
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ Native ad failed: code=${error.code}, domain=${error.domain}, message=${error.message}');
          ad.dispose();
          if (mounted) {
            setState(() {
              _nativeAd = null;
              _isLoaded = false;
            });
          }
        },
        onAdClicked: (ad) {
          debugPrint('👆 Native ad clicked: ${widget.placement.name}');
        },
        onAdImpression: (ad) {
          debugPrint('👀 Native ad [${widget.placement.name}]: ✅ IMPRESSION RECORDED');
        },
        onAdClosed: (ad) {
          debugPrint('🚪 Native ad closed: ${widget.placement.name}');
        },
        onAdOpened: (ad) {
          debugPrint('📭 Native ad opened: ${widget.placement.name}');
        },
      ),
      request: const AdRequest(),
    );

    _nativeAd!.load();
  }

  @override
  void dispose() {
    _subManager.removeListener(_onPremiumStatusChanged);
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _nativeAd == null) {
      return const SizedBox(height: 4);
    }

    final maxAdHeight = widget.height ?? _getMaxHeight();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxAdHeight,
          minHeight: 120,
          maxWidth: double.infinity,
        ),
        child: AdWidget(ad: _nativeAd!),
      ),
    );
  }

  double _getMaxHeight() {
    switch (widget.placement) {
      case NativePlacement.sessionFeed:
        return 340;
      case NativePlacement.meTab:
        return 320;
      case NativePlacement.routineDashboard:
      case NativePlacement.routineMorning:
      case NativePlacement.routineAfternoon:
        return 330;
    }
  }
}
