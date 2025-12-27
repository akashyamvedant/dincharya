import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import './supabase_service.dart';

// lib/services/ads_service.dart

class AdsService {
  static final AdsService _instance = AdsService._internal();
  factory AdsService() => _instance;
  AdsService._internal();

  final SupabaseService _supabase = SupabaseService();

  // Current ad network settings
  String _currentAdNetwork = 'admob';
  Map<String, dynamic> _adMobSettings = {};

  // Ad instances
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  AppOpenAd? _appOpenAd;

  bool _isInitialized = false;

  // Initialize ads service
  Future<void> initialize() async {
    try {
      // Skip ads initialization on web platform
      if (kIsWeb) {
        debugPrint('Ads service: Skipping initialization on web platform');
        _isInitialized = true;
        return;
      }

      await _loadAdSettings();

      if (_currentAdNetwork == 'admob') {
        await _initializeAdMob();
      }

      _isInitialized = true;
      debugPrint('Ads service initialized with $_currentAdNetwork');
    } catch (e) {
      debugPrint('Failed to initialize ads service: $e');
    }
  }

  // Load ad settings from Supabase
  Future<void> _loadAdSettings() async {
    try {
      final settings = await _supabase.getAdminSettings();
      if (settings.isNotEmpty) {
        final adminSettings = settings.first;
        _currentAdNetwork = adminSettings['ad_network'] ?? 'admob';
        _adMobSettings = adminSettings['admob_settings'] ?? {};
      }
    } catch (e) {
      debugPrint('Failed to load ad settings: $e');
      // Use default settings
      _currentAdNetwork = 'admob';
      _adMobSettings = {};
    }
  }

  // Initialize Google AdMob
  Future<void> _initializeAdMob() async {
    try {
      await MobileAds.instance.initialize();

      // Set test device IDs for development
      if (kDebugMode) {
        await MobileAds.instance.updateRequestConfiguration(
            RequestConfiguration(testDeviceIds: ['TEST_DEVICE_ID']));
      }

      debugPrint('AdMob initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize AdMob: $e');
    }
  }

  // Update ad network settings (Admin only)
  Future<Map<String, dynamic>> updateAdSettings({
    required String adNetwork,
    required Map<String, dynamic> adMobSettings,
  }) async {
    try {
      final settings = {
        'ad_network': adNetwork,
        'admob_settings': adMobSettings,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase.updateAdminSettings(settings);

      // Update local settings
      _currentAdNetwork = adNetwork;
      _adMobSettings = adMobSettings;

      // Reinitialize with new settings
      await initialize();

      return {
        'success': true,
        'message': 'Ad settings updated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update ad settings: ${e.toString()}',
      };
    }
  }

  // Load banner ad - Fixed adUnitId parameter
  Future<BannerAd?> loadBannerAd() async {
    if (!_isInitialized || _currentAdNetwork != 'admob') return null;

    try {
      final bannerId = _adMobSettings['banner_id'] as String?;
      if (bannerId == null || bannerId.isEmpty) return null;

      _bannerAd = BannerAd(
          adUnitId: bannerId, // Fixed: Added required adUnitId parameter
          size: AdSize.banner,
          request: const AdRequest(),
          listener: BannerAdListener(
              onAdLoaded: (ad) => debugPrint('Banner ad loaded'),
              onAdFailedToLoad: (ad, error) {
                debugPrint('Banner ad failed to load: $error');
                ad.dispose();
              }));

      await _bannerAd!.load();
      return _bannerAd;
    } catch (e) {
      debugPrint('Failed to load banner ad: $e');
      return null;
    }
  }

  // Load interstitial ad - Fixed adUnitId parameter
  Future<void> loadInterstitialAd() async {
    if (!_isInitialized || _currentAdNetwork != 'admob') return;

    try {
      final interstitialId = _adMobSettings['interstitial_id'] as String?;
      if (interstitialId == null || interstitialId.isEmpty) return;

      await InterstitialAd.load(
          adUnitId: interstitialId, // Fixed: Added required adUnitId parameter
          request: const AdRequest(),
          adLoadCallback: InterstitialAdLoadCallback(onAdLoaded: (ad) {
            _interstitialAd = ad;
            debugPrint('Interstitial ad loaded');
          }, onAdFailedToLoad: (error) {
            debugPrint('Interstitial ad failed to load: $error');
          }));
    } catch (e) {
      debugPrint('Failed to load interstitial ad: $e');
    }
  }

  // Show interstitial ad
  Future<void> showInterstitialAd() async {
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback =
          FullScreenContentCallback(onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd(); // Load next ad
      }, onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Failed to show interstitial ad: $error');
        ad.dispose();
        _interstitialAd = null;
      });

      await _interstitialAd!.show();
    } else {
      debugPrint('Interstitial ad not ready');
    }
  }

  // Load rewarded ad - Fixed adUnitId parameter
  Future<void> loadRewardedAd() async {
    if (!_isInitialized || _currentAdNetwork != 'admob') return;

    try {
      final rewardedId = _adMobSettings['rewarded_id'] as String?;
      if (rewardedId == null || rewardedId.isEmpty) return;

      await RewardedAd.load(
          adUnitId: rewardedId, // Fixed: Added required adUnitId parameter
          request: const AdRequest(),
          rewardedAdLoadCallback: RewardedAdLoadCallback(onAdLoaded: (ad) {
            _rewardedAd = ad;
            debugPrint('Rewarded ad loaded');
          }, onAdFailedToLoad: (error) {
            debugPrint('Rewarded ad failed to load: $error');
          }));
    } catch (e) {
      debugPrint('Failed to load rewarded ad: $e');
    }
  }

  // Show rewarded ad
  Future<bool> showRewardedAd() async {
    if (_rewardedAd != null) {
      bool rewarded = false;

      _rewardedAd!.fullScreenContentCallback =
          FullScreenContentCallback(onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd(); // Load next ad
      }, onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Failed to show rewarded ad: $error');
        ad.dispose();
        _rewardedAd = null;
      });

      await _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
        rewarded = true;
        debugPrint('User earned reward: ${reward.amount} ${reward.type}');
      });

      return rewarded;
    } else {
      debugPrint('Rewarded ad not ready');
      return false;
    }
  }

  // Load app open ad - Fixed adUnitId parameter
  Future<void> loadAppOpenAd() async {
    if (!_isInitialized || _currentAdNetwork != 'admob') return;

    try {
      final appOpenId = _adMobSettings['open_app_id'] as String?;
      if (appOpenId == null || appOpenId.isEmpty) return;

      await AppOpenAd.load(
          adUnitId: appOpenId, // Fixed: Added required adUnitId parameter
          request: const AdRequest(),
          adLoadCallback: AppOpenAdLoadCallback(onAdLoaded: (ad) {
            _appOpenAd = ad;
            debugPrint('App open ad loaded');
          }, onAdFailedToLoad: (error) {
            debugPrint('App open ad failed to load: $error');
          }));
    } catch (e) {
      debugPrint('Failed to load app open ad: $e');
    }
  }

  // Show app open ad
  Future<void> showAppOpenAd() async {
    if (_appOpenAd != null) {
      _appOpenAd!.fullScreenContentCallback =
          FullScreenContentCallback(onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _appOpenAd = null;
        loadAppOpenAd(); // Load next ad
      }, onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Failed to show app open ad: $error');
        ad.dispose();
        _appOpenAd = null;
      });

      await _appOpenAd!.show();
    }
  }

  // Get current ad settings (for admin panel)
  Map<String, dynamic> getCurrentAdSettings() {
    return {
      'ad_network': _currentAdNetwork,
      'admob_settings': _adMobSettings,
    };
  }

  // Dispose resources
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _appOpenAd?.dispose();
  }
}
