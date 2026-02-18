import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:sizer/sizer.dart';

import '../../core/constants/ad_constants.dart';
import '../../services/ads_service.dart';

/// Native Ad Widget that matches Dincharya's warm brown theme
/// Displays native ads that blend seamlessly with app content
/// 
/// IMPORTANT: Based on Google's official documentation:
/// https://developers.google.com/admob/flutter/native/platforms
/// 
/// AdWidget MUST be placed in a Container with explicit WIDTH and HEIGHT
/// to prevent "Advertiser assets outside native ad view" error
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

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() async {
    final adsService = AdsService();
    
    // Wait for AdsService initialization before checking premium status
    await adsService.waitForInitialization;
    
    // Don't load if premium user
    if (!adsService.shouldShowAds) {
      return;
    }

    _nativeAd = NativeAd(
      adUnitId: AdConstants.getNativeAdId(widget.placement),
      factoryId: 'dincharyaNativeAd',
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          debugPrint('✅ Native ad loaded for ${widget.placement.name}');
          if (mounted) {
            setState(() => _isLoaded = true);
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ Native ad failed to load: ${error.message}');
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
          debugPrint('👀 Native ad impression: ${widget.placement.name}');
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
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading skeleton while ad is loading (prevents content jump)
    if (!_isLoaded || _nativeAd == null) {
      return Container(
        width: MediaQuery.of(context).size.width - 32,
        height: 120,
        margin: EdgeInsets.symmetric(vertical: 1.5.h, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFDF8F3),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B4513).withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: const Color(0xFF8B4513).withValues(alpha: 0.3),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Loading...',
                style: TextStyle(
                  fontSize: 11,
                  color: const Color(0xFF8B4513).withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Get screen width for explicit sizing
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Max height based on placement (flexible — no empty space)
    final maxAdHeight = widget.height ?? _getMaxHeight();

    // CRITICAL: AdWidget MUST be in a Container with EXPLICIT width AND height
    // Reference: https://developers.google.com/admob/flutter/native/platforms
    // No border — the XML layout already provides its own Dincharya-themed background
    return Container(
      width: screenWidth - 32,
      constraints: BoxConstraints(
        maxHeight: maxAdHeight,
        minHeight: 120,
      ),
      alignment: Alignment.center,
      margin: EdgeInsets.symmetric(vertical: 1.5.h, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B4513).withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AdWidget(ad: _nativeAd!),
      ),
    );
  }

  double _getMaxHeight() {
    // Max heights — ad content fills what it needs, no extra empty space
    switch (widget.placement) {
      case NativePlacement.sessionFeed:
        return 340;
      case NativePlacement.meTab:
        return 320;
      case NativePlacement.routineDashboard:
        return 330;
    }
  }
}
