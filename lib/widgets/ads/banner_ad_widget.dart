// lib/widgets/ads/banner_ad_widget.dart
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/constants/ad_constants.dart';
import '../../services/ads_service.dart';

/// Reusable Banner Ad Widget with placement support
/// Uses adaptive banner sizing per AdMob 2025 best practices
/// Reference: https://developers.google.com/admob/flutter/banner/adaptive
class BannerAdWidget extends StatefulWidget {
  final AdSize? adSize;
  final BannerPlacement placement;
  final bool useAdaptiveSize;
  
  const BannerAdWidget({
    super.key,
    this.adSize,
    this.placement = BannerPlacement.journal,
    this.useAdaptiveSize = true, // Default to adaptive sizing
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  AdSize? _adSize;

  @override
  void initState() {
    super.initState();
    // Delay to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBannerAd();
    });
  }

  Future<void> _loadBannerAd() async {
    final adsService = AdsService();
    
    // Wait for AdsService initialization (replaces fragile 2-second delay)
    await adsService.waitForInitialization;
    
    // Check if we should show ads
    if (!adsService.shouldShowAds) {
      debugPrint('🎯 Banner [${widget.placement.name}]: Premium user, skipping');
      return;
    }

    // Get adaptive ad size based on screen width
    if (widget.useAdaptiveSize && widget.adSize == null) {
      final width = MediaQuery.of(context).size.width.truncate();
      _adSize = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
      if (_adSize == null) {
        debugPrint('❌ Banner [${widget.placement.name}]: Unable to get adaptive size');
        // Fallback to standard banner
        _adSize = AdSize.banner;
      }
    } else {
      _adSize = widget.adSize ?? AdSize.banner;
    }

    try {
      final adUnitId = AdConstants.getBannerAdId(widget.placement);
      debugPrint('🎯 Banner [${widget.placement.name}]: Loading adaptive size ${_adSize!.width}x${_adSize!.height}');
      
      _bannerAd = BannerAd(
        adUnitId: adUnitId,
        size: _adSize!,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            debugPrint('✅ Banner [${widget.placement.name}]: Loaded (${_adSize!.width}x${_adSize!.height})');
            if (mounted) {
              setState(() => _isLoaded = true);
            }
          },
          onAdFailedToLoad: (ad, error) {
            debugPrint('❌ Banner [${widget.placement.name}]: Failed - ${error.message}');
            ad.dispose();
            _bannerAd = null;
          },
          onAdOpened: (ad) => debugPrint('🎯 Banner [${widget.placement.name}]: Opened'),
          onAdClosed: (ad) => debugPrint('🎯 Banner [${widget.placement.name}]: Closed'),
          onAdClicked: (ad) => debugPrint('👆 Banner [${widget.placement.name}]: Clicked'),
          onAdImpression: (ad) => debugPrint('👀 Banner [${widget.placement.name}]: Impression'),
        ),
      );

      await _bannerAd!.load();
    } catch (e) {
      debugPrint('❌ Banner [${widget.placement.name}]: Error - $e');
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Don't show anything if not loaded
    if (!_isLoaded || _bannerAd == null || _adSize == null) {
      return const SizedBox.shrink();
    }

    // Full-width themed container — centers the ad properly
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF8F3),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B4513).withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Subtle "Ad" indicator — AdMob policy compliance
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 10),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Ad',
                style: TextStyle(
                  fontSize: 10,
                  color: const Color(0xFF8B4513).withOpacity(0.4),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          // AdWidget with correct height, centered
          SizedBox(
            width: _adSize!.width.toDouble(),
            height: _adSize!.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// Adaptive Banner Ad Widget - Auto-sizes to screen width
/// Best for top/bottom placement per AdMob 2025 guidelines
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
