// lib/widgets/ads/banner_ad_widget.dart
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/constants/ad_constants.dart';
import '../../services/ads_service.dart';
import '../../services/subscription_manager.dart';

/// Reusable Banner Ad Widget with placement support
/// Uses adaptive banner sizing per AdMob 2026 best practices
///
/// REACTIVE: Listens to SubscriptionManager — if user buys premium mid-session,
/// the loaded ad is disposed immediately without requiring app restart.
class BannerAdWidget extends StatefulWidget {
  final AdSize? adSize;
  final BannerPlacement placement;
  final bool useAdaptiveSize;
  
  const BannerAdWidget({
    super.key,
    this.adSize,
    this.placement = BannerPlacement.journal,
    this.useAdaptiveSize = true,
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  AdSize? _adSize;
  final SubscriptionManager _subManager = SubscriptionManager();

  @override
  void initState() {
    super.initState();
    // Listen for premium status changes (e.g., user buys premium mid-session)
    _subManager.addListener(_onPremiumStatusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBannerAd();
    });
  }

  /// React to premium status changes — dispose ad immediately
  void _onPremiumStatusChanged() {
    if (_subManager.isPremium && _bannerAd != null) {
      debugPrint('👑 Banner [${widget.placement.name}]: Premium activated — disposing ad');
      _bannerAd?.dispose();
      if (mounted) {
        setState(() {
          _bannerAd = null;
          _isLoaded = false;
        });
      }
    }
  }

  Future<void> _loadBannerAd() async {
    final adsService = AdsService();
    
    // Wait for AdsService initialization
    await adsService.waitForInitialization;
    
    // Check if we should show ads
    if (!adsService.shouldShowAds) {
      debugPrint('🎯 Banner [${widget.placement.name}]: Premium user, skipping');
      return;
    }

    if (!mounted) return;

    // Get adaptive ad size based on AVAILABLE width
    if (widget.useAdaptiveSize && widget.adSize == null) {
      final screenWidth = MediaQuery.of(context).size.width;
      final availableWidth = screenWidth.truncate();
      
      _adSize = await AdSize.getAnchoredAdaptiveBannerAdSize(
        Orientation.portrait,
        availableWidth,
      );
      if (_adSize == null) {
        debugPrint('❌ Banner [${widget.placement.name}]: Unable to get adaptive size, using largeBanner');
        _adSize = AdSize.largeBanner;
      }
    } else {
      _adSize = widget.adSize ?? AdSize.largeBanner;
    }

    if (!mounted) return;

    try {
      final adUnitId = AdConstants.getBannerAdId(widget.placement);
      debugPrint('🎯 Banner [${widget.placement.name}]: Loading size ${_adSize!.width}x${_adSize!.height}');
      
      final isCollapsible = widget.placement == BannerPlacement.routineDashboard || 
                            widget.placement == BannerPlacement.guidedHub || 
                            widget.placement == BannerPlacement.journal;
      
      _bannerAd = BannerAd(
        adUnitId: adUnitId,
        size: _adSize!,
        request: isCollapsible 
            ? const AdRequest(extras: {'collapsible': 'bottom'}) 
            : const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            debugPrint('✅ Banner [${widget.placement.name}]: Loaded (${_adSize!.width}x${_adSize!.height})');
            if (mounted) {
              setState(() => _isLoaded = true);
            }
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('❌ Banner [${widget.placement.name}]: Failed - code=${error.code}, domain=${error.domain}, message=${error.message}');
            ad.dispose();
            if (mounted) {
              setState(() {
                _bannerAd = null;
                _isLoaded = false;
              });
            }
          },
          onAdOpened: (ad) => debugPrint('🎯 Banner [${widget.placement.name}]: Opened'),
          onAdClosed: (ad) => debugPrint('🎯 Banner [${widget.placement.name}]: Closed'),
          onAdClicked: (ad) => debugPrint('👆 Banner [${widget.placement.name}]: Clicked'),
          onAdImpression: (ad) => debugPrint('👀 Banner [${widget.placement.name}]: ✅ IMPRESSION RECORDED'),
        ),
      );

      await _bannerAd!.load();
    } catch (e) {
      debugPrint('❌ Banner [${widget.placement.name}]: Error - $e');
    }
  }

  @override
  void dispose() {
    _subManager.removeListener(_onPremiumStatusChanged);
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null || _adSize == null) {
      return const SizedBox(height: 4);
    }

    return SafeArea(
      child: SizedBox(
        width: _adSize!.width.toDouble(),
        height: _adSize!.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}

/// Adaptive Banner Ad Widget - Auto-sizes to screen width
class AdaptiveBannerAdWidget extends StatelessWidget {
  final BannerPlacement placement;
  
  const AdaptiveBannerAdWidget({
    super.key,
    this.placement = BannerPlacement.journal,
  });

  @override
  Widget build(BuildContext context) {
    return BannerAdWidget(
      useAdaptiveSize: true,
      placement: placement,
    );
  }
}

/// Large Banner Ad Widget (320x100)
class LargeBannerAdWidget extends StatelessWidget {
  final BannerPlacement placement;
  
  const LargeBannerAdWidget({
    super.key,
    this.placement = BannerPlacement.journal,
  });

  @override
  Widget build(BuildContext context) {
    return BannerAdWidget(
      adSize: AdSize.largeBanner,
      useAdaptiveSize: false,
      placement: placement,
    );
  }
}

/// Medium Rectangle Ad Widget (300x250) - Good for in-feed
class MediumRectangleAdWidget extends StatelessWidget {
  final BannerPlacement placement;
  
  const MediumRectangleAdWidget({
    super.key,
    this.placement = BannerPlacement.journal,
  });

  @override
  Widget build(BuildContext context) {
    return BannerAdWidget(
      adSize: AdSize.mediumRectangle,
      useAdaptiveSize: false,
      placement: placement,
    );
  }
}

/// Leaderboard Ad Widget (728x90) - For tablets
class LeaderboardAdWidget extends StatelessWidget {
  final BannerPlacement placement;
  
  const LeaderboardAdWidget({
    super.key,
    this.placement = BannerPlacement.journal,
  });

  @override
  Widget build(BuildContext context) {
    return BannerAdWidget(
      adSize: AdSize.leaderboard,
      useAdaptiveSize: false,
      placement: placement,
    );
  }
}
