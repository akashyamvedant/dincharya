import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import './supabase_service.dart';
import './subscription_manager.dart';
import '../core/constants/ad_constants.dart';

// lib/services/ads_service.dart

class AdsService {
  static final AdsService _instance = AdsService._internal();
  factory AdsService() => _instance;
  AdsService._internal();

  final SupabaseService _supabase = SupabaseService();

  // Ad instances
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  AppOpenAd? _appOpenAd;

  bool _isInitialized = false;
  bool _isPremiumUser = false;
  
  // Completer so widgets can await initialization
  Completer<void> _initCompleter = Completer<void>();
  
  /// Await this to ensure AdsService is ready before checking shouldShowAds
  Future<void> get waitForInitialization => _initCompleter.future;
  
  // Frequency capping for interstitial
  int _interstitialActionCount = 0;
  DateTime? _lastInterstitialTime;
  
  // App Open ad expiry tracking (4 hours max)
  DateTime? _appOpenAdLoadTime;

  // Check if ads should be shown (not for premium users)
  // Delegates to SubscriptionManager as single source of truth
  bool get shouldShowAds => _isInitialized && !SubscriptionManager().isPremium && !kIsWeb;
  
  bool get isInitialized => _isInitialized;

  // Initialize ads service
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('📢 AdsService already initialized');
      return;
    }
    
    debugPrint('📢 AdsService.initialize() starting...');
    
    try {
      // Skip ads initialization on web platform
      if (kIsWeb) {
        debugPrint('📢 Ads: Skipping on web platform');
        _isInitialized = true;
        return;
      }

      // FIRST: Initialize AdMob SDK
      debugPrint('📢 Initializing AdMob SDK...');
      await _initializeAdMob();
      debugPrint('✅ AdMob SDK ready');
      
      // Mark as initialized so ads can start loading
      _isInitialized = true;
      
      // SECOND: Pre-load ALL ads (don't wait for premium check)
      debugPrint('📢 Pre-loading ads...');
      
      // Load ads in parallel for faster loading
      await Future.wait([
        loadInterstitialAd(),
        loadRewardedAd(),
        loadAppOpenAd(),
      ]);
      
      debugPrint('✅ All ads pre-loaded');
      
      // THIRD: Sync premium status from SubscriptionManager
      await _syncPremiumStatus();
      
      debugPrint('✅ AdsService fully initialized');
      if (!_initCompleter.isCompleted) _initCompleter.complete();
    } catch (e) {
      debugPrint('❌ AdsService init error: $e');
      _isInitialized = true; // Continue without blocking
      if (!_initCompleter.isCompleted) _initCompleter.complete();
    }
  }
  
  // Sync premium status from SubscriptionManager
  Future<void> _syncPremiumStatus() async {
    try {
      final subManager = SubscriptionManager();
      await subManager.initialize();
      _isPremiumUser = subManager.isPremium;
      debugPrint('👤 Premium status synced from SubscriptionManager: $_isPremiumUser');
      
      // Dispose loaded ads if user is premium (save memory)
      if (_isPremiumUser) {
        _disposeAllAds();
        debugPrint('🧹 Ads disposed — premium user');
      }
    } catch (e) {
      debugPrint('❌ Premium sync error: $e');
      _isPremiumUser = false;
    }
  }

  // Dispose all loaded ads to save memory for premium users
  void _disposeAllAds() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _appOpenAd?.dispose();
    _appOpenAd = null;
  }
  
  // Refresh premium status (call after subscription changes)
  Future<void> refreshPremiumStatus() async {
    await _syncPremiumStatus();
    debugPrint('🔄 AdsService premium status refreshed: shouldShowAds=$shouldShowAds');
  }

  // Update ad settings from admin panel
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
      
      // Note: We use AdConstants for actual ad loading now
      // Admin settings are stored for reference/future use
      
      return {
        'success': true,
        'message': 'Ad settings saved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to save settings: $e',
      };
    }
  }

  // Initialize Google AdMob
  Future<void> _initializeAdMob() async {
    try {
      await MobileAds.instance.initialize();
      
      // Configure for 16+ audience (non-child-directed app)
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          // Not directed at children - don't need COPPA treatment
          tagForChildDirectedTreatment: TagForChildDirectedTreatment.no,
          
          // App is for 16+ users
          tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.no,
          
          // Maximum ad content rating (all content allowed for 16+)
          maxAdContentRating: MaxAdContentRating.ma,
          
          // Test devices - add device IDs during development
          testDeviceIds: kDebugMode ? [
            // Add your test device IDs here from logcat/console
            // 'YOUR_DEVICE_ID_HERE',
          ] : [],
        ),
      );
      
      debugPrint('✅ AdMob SDK initialized with 16+ config');
    } catch (e) {
      debugPrint('❌ Failed to initialize AdMob: $e');
    }
  }

  // ==================== BANNER AD ====================
  
  Future<BannerAd?> loadBannerAd({AdSize size = AdSize.banner}) async {
    if (!shouldShowAds) return null;

    try {
      _bannerAd?.dispose();
      _bannerAd = BannerAd(
        adUnitId: AdConstants.bannerAdId,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) => debugPrint('✅ Banner ad loaded'),
          onAdFailedToLoad: (ad, error) {
            debugPrint('❌ Banner failed: $error');
            ad.dispose();
            _bannerAd = null;
          },
        ),
      );

      await _bannerAd!.load();
      return _bannerAd;
    } catch (e) {
      debugPrint('❌ Error loading banner: $e');
      return null;
    }
  }
  
  BannerAd? get bannerAd => _bannerAd;

  // ==================== INTERSTITIAL AD ====================
  
  Future<void> loadInterstitialAd([InterstitialPlacement? placement]) async {
    debugPrint('📢 loadInterstitialAd called for ${placement?.name ?? "default"}');
    if (kIsWeb) return;
    if (_interstitialAd != null) {
      debugPrint('📢 Interstitial already loaded');
      return;
    }

    try {
      final adUnitId = placement != null 
          ? AdConstants.getInterstitialAdId(placement)
          : AdConstants.interstitialAdId;
      
      await InterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            debugPrint('✅ Interstitial ad loaded for ${placement?.name ?? "default"}');
          },
          onAdFailedToLoad: (error) {
            debugPrint('❌ Interstitial failed: $error');
            _interstitialAd = null;
          },
        ),
      );
    } catch (e) {
      debugPrint('❌ Error loading interstitial: $e');
    }
  }

  // Show interstitial with frequency capping
  Future<bool> showInterstitialAdWithCapping([InterstitialPlacement? placement]) async {
    if (!shouldShowAds) return false;
    
    _interstitialActionCount++;
    
    // Check frequency cap
    if (_interstitialActionCount < AdConstants.interstitialFrequency) {
      debugPrint('📊 Interstitial [${placement?.name ?? "default"}]: ${_interstitialActionCount}/${AdConstants.interstitialFrequency} actions');
      return false;
    }
    
    // Check time gap
    if (_lastInterstitialTime != null) {
      final secondsSinceLast = DateTime.now().difference(_lastInterstitialTime!).inSeconds;
      if (secondsSinceLast < AdConstants.minSecondsBetweenInterstitials) {
        debugPrint('⏳ Interstitial [${placement?.name ?? "default"}]: Too soon (${secondsSinceLast}s < ${AdConstants.minSecondsBetweenInterstitials}s)');
        return false;
      }
    }
    
    // Show ad
    final shown = await showInterstitialAd();
    if (shown) {
      _interstitialActionCount = 0;
      _lastInterstitialTime = DateTime.now();
      debugPrint('📺 Interstitial shown for placement: ${placement?.name ?? "default"}');
      // Preload next ad with same placement
      loadInterstitialAd(placement);
    }
    return shown;
  }

  Future<bool> showInterstitialAd() async {
    if (_interstitialAd == null) {
      debugPrint('⚠️ Interstitial not ready');
      await loadInterstitialAd();
      return false;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('❌ Interstitial show failed: $error');
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd();
      },
    );

    await _interstitialAd!.show();
    debugPrint('📺 Interstitial ad shown');
    return true;
  }

  // ==================== REWARDED AD ====================
  
  // Map to store rewarded ads per placement
  final Map<RewardedPlacement, RewardedAd> _rewardedAds = {};
  
  /// Load rewarded ad for a specific placement
  Future<void> loadRewardedAdForPlacement(RewardedPlacement placement) async {
    debugPrint('📢 loadRewardedAd called for ${placement.name}');
    if (kIsWeb) return;
    if (_rewardedAds.containsKey(placement)) {
      debugPrint('📢 Rewarded [${placement.name}] already loaded');
      return;
    }

    try {
      final adUnitId = AdConstants.getRewardedAdId(placement);
      debugPrint('🎯 Loading rewarded ad: ${placement.name} with ID: $adUnitId');
      
      await RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAds[placement] = ad;
            debugPrint('✅ Rewarded [${placement.name}] loaded');
          },
          onAdFailedToLoad: (error) {
            debugPrint('❌ Rewarded [${placement.name}] failed: $error');
            _rewardedAds.remove(placement);
          },
        ),
      );
    } catch (e) {
      debugPrint('❌ Error loading rewarded [${placement.name}]: $e');
    }
  }
  
  /// Check if rewarded ad is ready for specific placement
  bool isRewardedAdReadyFor(RewardedPlacement placement) => _rewardedAds.containsKey(placement);
  
  /// Show rewarded ad for specific placement
  Future<bool> showRewardedAdForPlacement(RewardedPlacement placement, {Function()? onRewarded}) async {
    if (!_rewardedAds.containsKey(placement)) {
      debugPrint('⚠️ Rewarded [${placement.name}] not ready, loading...');
      await loadRewardedAdForPlacement(placement);
      return false;
    }

    final ad = _rewardedAds[placement]!;
    bool rewarded = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAds.remove(placement);
        // Preload next ad for same placement
        loadRewardedAdForPlacement(placement);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('❌ Rewarded [${placement.name}] show failed: $error');
        ad.dispose();
        _rewardedAds.remove(placement);
        loadRewardedAdForPlacement(placement);
      },
    );

    await ad.show(
      onUserEarnedReward: (ad, reward) {
        rewarded = true;
        debugPrint('🎁 Reward earned [${placement.name}]: ${reward.amount} ${reward.type}');
        onRewarded?.call();
      },
    );

    return rewarded;
  }
  
  // Legacy methods for backward compatibility
  Future<void> loadRewardedAd() async {
    debugPrint('📢 loadRewardedAd (legacy) called');
    if (kIsWeb) return;
    if (_rewardedAd != null) {
      debugPrint('📢 Rewarded already loaded');
      return;
    }

    try {
      await RewardedAd.load(
        adUnitId: AdConstants.rewardedAdId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            debugPrint('✅ Rewarded ad loaded (legacy)');
          },
          onAdFailedToLoad: (error) {
            debugPrint('❌ Rewarded failed: $error');
            _rewardedAd = null;
          },
        ),
      );
    } catch (e) {
      debugPrint('❌ Error loading rewarded: $e');
    }
  }

  bool get isRewardedAdReady => _rewardedAd != null;

  Future<bool> showRewardedAd({Function()? onRewarded}) async {
    if (_rewardedAd == null) {
      debugPrint('⚠️ Rewarded ad not ready');
      await loadRewardedAd();
      return false;
    }

    bool rewarded = false;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('❌ Rewarded show failed: $error');
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        rewarded = true;
        debugPrint('🎁 Reward earned: ${reward.amount} ${reward.type}');
        onRewarded?.call();
      },
    );

    return rewarded;
  }

  // ==================== APP OPEN AD ====================
  
  /// Check if app open ad is still valid (not expired after 4 hours)
  bool _isAppOpenAdValid() {
    if (_appOpenAdLoadTime == null) return false;
    // App Open ads expire after 4 hours per Google policy
    final loadTime = _appOpenAdLoadTime!;
    final now = DateTime.now();
    return now.difference(loadTime).inHours < 4;
  }
  
  Future<void> loadAppOpenAd() async {
    debugPrint('📢 loadAppOpenAd called');
    if (kIsWeb) return;
    
    // Check if we have a valid (non-expired) ad
    if (_appOpenAd != null && _isAppOpenAdValid()) {
      debugPrint('📢 App Open already loaded and valid');
      return;
    }
    
    // Dispose expired ad
    if (_appOpenAd != null) {
      debugPrint('🕐 App Open ad expired, reloading...');
      _appOpenAd!.dispose();
      _appOpenAd = null;
      _appOpenAdLoadTime = null;
    }

    try {
      await AppOpenAd.load(
        adUnitId: AdConstants.appOpenAdId,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            _appOpenAd = ad;
            _appOpenAdLoadTime = DateTime.now();  // Track load time for expiry
            debugPrint('✅ App Open ad loaded');
          },
          onAdFailedToLoad: (error) {
            debugPrint('❌ App Open failed: $error');
            _appOpenAd = null;
            _appOpenAdLoadTime = null;
          },
        ),
      );
    } catch (e) {
      debugPrint('❌ Error loading App Open: $e');
    }
  }

  Future<void> showAppOpenAd() async {
    // Check for valid (non-expired) ad
    if (_appOpenAd == null || !_isAppOpenAdValid()) {
      debugPrint('⚠️ App Open ad not ready or expired');
      await loadAppOpenAd();  // Reload if expired
      return;
    }

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _appOpenAd = null;
        _appOpenAdLoadTime = null;
        loadAppOpenAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('❌ App Open show failed: $error');
        ad.dispose();
        _appOpenAd = null;
        _appOpenAdLoadTime = null;
        loadAppOpenAd();
      },
    );

    await _appOpenAd!.show();
    debugPrint('📺 App Open ad shown');
  }

  // ==================== CLEANUP ====================
  
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _appOpenAd?.dispose();
    _bannerAd = null;
    _interstitialAd = null;
    _rewardedAd = null;
    _appOpenAd = null;
  }
}

