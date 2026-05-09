import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../core/constants/ad_constants.dart';
import '../../services/ads_service.dart';
import '../../services/subscription_manager.dart';
import '../../services/theme_provider.dart';

/// Native Ad Widget that matches Dincharya's warm brown theme
/// 
/// REACTIVE & VISIBILITY-AWARE: 
/// 1. Listens to SubscriptionManager — if user buys premium mid-session, ad is disposed.
/// 2. Uses VisibilityDetector — only requests ad when container is actually visible on screen.
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
  bool _hasRequestedAd = false; // Prevents multiple requests
  final SubscriptionManager _subManager = SubscriptionManager();

  @override
  void initState() {
    super.initState();
    // Listen for premium status changes
    _subManager.addListener(_onPremiumStatusChanged);
    // REMOVED _loadAd() from here. We now load lazily via VisibilityDetector.
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
    if (_hasRequestedAd) return;
    
    final adsService = AdsService();
    await adsService.waitForInitialization;
    
    if (!adsService.shouldShowAds) return;

    setState(() {
      _hasRequestedAd = true;
    });

    if (!mounted) return;

    final isDark = ThemeProvider().isDarkMode;
    
    debugPrint('👁️ VisibilityDetector: Triggering load for Native Ad [${widget.placement.name}]');

    _nativeAd = NativeAd(
      adUnitId: AdConstants.getNativeAdId(widget.placement),
      factoryId: 'dincharyaNativeAd',
      customOptions: {'isDarkMode': isDark},
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          debugPrint('✅ Native ad loaded for ${widget.placement.name}');
          if (mounted) setState(() => _isLoaded = true);
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
        onAdClicked: (ad) => debugPrint('👆 Native ad clicked: ${widget.placement.name}'),
        onAdImpression: (ad) => debugPrint('👀 Native ad [${widget.placement.name}]: ✅ IMPRESSION RECORDED'),
        onAdClosed: (ad) => debugPrint('🚪 Native ad closed: ${widget.placement.name}'),
        onAdOpened: (ad) => debugPrint('📭 Native ad opened: ${widget.placement.name}'),
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
    // If premium, return nothing. If ad failed to load completely, return nothing.
    if (_subManager.isPremium || (_hasRequestedAd && !_isLoaded && _nativeAd == null)) {
      return const SizedBox.shrink();
    }

    final maxAdHeight = widget.height ?? _getMaxHeight();

    return VisibilityDetector(
      key: Key('native_ad_${widget.placement.name}'),
      onVisibilityChanged: (visibilityInfo) {
        // Load ad when at least 10% visible
        if (visibilityInfo.visibleFraction >= 0.1 && !_hasRequestedAd) {
          _loadAd();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxAdHeight,
            minHeight: 120,
            maxWidth: double.infinity,
          ),
          child: _isLoaded && _nativeAd != null
              ? AdWidget(ad: _nativeAd!)
              : _buildLoadingPlaceholder(context), // Show placeholder while loading
        ),
      ),
    );
  }
  
  /// A subtle placeholder to prevent layout shifts while the ad loads
  Widget _buildLoadingPlaceholder(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
        ),
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
      case NativePlacement.sessionTheory:
        return 340;
    }
  }
}
