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

      // FIRST: Initialize AdMob SDK + mediation adapters
      debugPrint('📢 Initializing AdMob SDK...');
      final initStatus = await _initializeAdMob();
      debugPrint('✅ AdMob SDK ready');
      
      // Log mediation adapter initialization statuses
      if (initStatus != null) {
        initStatus.adapterStatuses.forEach((adapter, status) {
          debugPrint('📡 Adapter [$adapter]: ${status.state.name} — ${status.description}');
        });
      }
      
      // SECOND: Request UMP consent (GDPR/privacy compliance)
      debugPrint('📢 Checking UMP consent status...');
      await _requestConsentIfRequired();
      debugPrint('✅ UMP consent check complete');
      
      // Mark as initialized FIRST so shouldShowAds returns true
      _isInitialized = true;
      
      // THIRD: Sync premium status from SubscriptionManager
      await _syncPremiumStatus();
      
      debugPrint('✅ AdsService fully initialized');
      if (!_initCompleter.isCompleted) _initCompleter.complete();
      
      // FOURTH: Pre-load full-screen ads with a delay
      // In release mode, the SDK needs time to warm up after initialize()
      // Banner/Native ads work because they load lazily when screens mount
      // Interstitial/Rewarded/AppOpen load immediately — need delay to succeed
      _preloadFullScreenAds();
    } catch (e) {
      debugPrint('❌ AdsService init error: $e');
      _isInitialized = true; // Continue without blocking
      if (!_initCompleter.isCompleted) _initCompleter.complete();
    }
  }
  
  /// Pre-load full-screen ads with a delay to let SDK warm up
  /// This runs AFTER initialize() completes, not blocking the app
  void _preloadFullScreenAds() async {
    // Wait 2 seconds for SDK to fully warm up (critical for release mode)
    await Future.delayed(const Duration(seconds: 2));
    
    if (!shouldShowAds) {
      debugPrint('👑 Premium user — skipping ad pre-load');
      return;
    }
    
    debugPrint('📢 Pre-loading full-screen ads (delayed)...');
    
    // Load each ad type independently — don't let one failure block others
    try { await loadInterstitialAd(); } catch (e) { debugPrint('⚠️ Interstitial pre-load error: $e'); }
    // NOTE: Rewarded ads are loaded on-demand per placement in guided_sessions_hub
    // No need to pre-load legacy rewarded ad here
    try { await loadAppOpenAd(); } catch (e) { debugPrint('⚠️ App Open pre-load error: $e'); }
    
    debugPrint('✅ Full-screen ads pre-load initiated');
  }
  
  // Sync premium status from SubscriptionManager and dispose ads if premium
  Future<void> _syncPremiumStatus() async {
    try {
      final subManager = SubscriptionManager();
      // SubscriptionManager should already be initialized (main.dart does it first)
      // But call initialize() with forceRefresh=false just to be safe
      await subManager.initialize();
      debugPrint('👤 Premium status: ${subManager.isPremium}');
      
      // Dispose loaded ads if user is premium (save memory)
      if (subManager.isPremium) {
        _disposeAllAds();
        debugPrint('🧹 Ads disposed — premium user');
      }
    } catch (e) {
      debugPrint('❌ Premium sync error: $e');
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
    _appOpenAdLoadTime = null;
    // Dispose ALL placement-based rewarded ads
    for (final ad in _rewardedAds.values) {
      ad.dispose();
    }
    _rewardedAds.clear();
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

  // Initialize Google AdMob + mediation adapters
  Future<InitializationStatus?> _initializeAdMob() async {
    try {
      final initStatus = await MobileAds.instance.initialize();
      
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
      return initStatus;
    } catch (e) {
      debugPrint('❌ Failed to initialize AdMob: $e');
      return null;
    }
  }
  
  // UMP Consent Framework — GDPR/Privacy compliance
  // Required for EU/EEA/UK users and US state privacy laws
  // Without this, Google may block or reduce ad serving
  Future<void> _requestConsentIfRequired() async {
    try {
      // Set consent parameters
      final params = ConsentRequestParameters(
        // Use debug settings only in debug mode
        consentDebugSettings: kDebugMode 
          ? ConsentDebugSettings(
              debugGeography: DebugGeography.debugGeographyEea,
              // testIdentifiers: ['YOUR_TEST_DEVICE_HASH'],
            )
          : null,
      );
      
      // Request consent info update
      final completer = Completer<void>();
      
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          // Success — check if form is available and needed
          debugPrint('📋 Consent status: ${await ConsentInformation.instance.getConsentStatus()}');
          
          if (await ConsentInformation.instance.isConsentFormAvailable()) {
            // Load and show the consent form if needed
            final status = await ConsentInformation.instance.getConsentStatus();
            if (status == ConsentStatus.required) {
              debugPrint('📋 Consent required — loading form...');
              ConsentForm.loadConsentForm(
                (consentForm) {
                  consentForm.show((formError) {
                    if (formError != null) {
                      debugPrint('⚠️ Consent form error: ${formError.message}');
                    } else {
                      debugPrint('✅ Consent form completed');
                    }
                    if (!completer.isCompleted) completer.complete();
                  });
                },
                (formError) {
                  debugPrint('⚠️ Failed to load consent form: ${formError.message}');
                  if (!completer.isCompleted) completer.complete();
                },
              );
            } else {
              debugPrint('✅ Consent already obtained or not required (status: $status)');
              if (!completer.isCompleted) completer.complete();
            }
          } else {
            debugPrint('ℹ️ Consent form not available (likely non-EEA region)');
            if (!completer.isCompleted) completer.complete();
          }
        },
        (formError) {
          // Failed to get consent info — proceed anyway (non-blocking)
          debugPrint('⚠️ Consent info update failed: ${formError.message}');
          if (!completer.isCompleted) completer.complete();
        },
      );
      
      // Wait for consent flow to complete (with timeout)
      await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⏱️ Consent check timed out — proceeding without');
        },
      );
    } catch (e) {
      // Non-blocking — don't prevent ads from loading if consent fails
      debugPrint('⚠️ Consent check error: $e');
    }
  }

  // ==================== BANNER AD ====================
  // NOTE: BannerAdWidget creates its own BannerAd instances per-placement.
  // No centralized banner loading needed here.
  
  BannerAd? get bannerAd => _bannerAd;

  // ==================== INTERSTITIAL AD ====================
  
  /// Max retry attempts for loading full-screen ads
  static const int _maxLoadRetries = 3;
  
  Future<void> loadInterstitialAd([InterstitialPlacement? placement]) async {
    debugPrint('📢 loadInterstitialAd called for ${placement?.name ?? "default"}');
    if (kIsWeb) return;
    if (_interstitialAd != null) {
      debugPrint('📢 Interstitial already loaded');
      return;
    }

    final adUnitId = placement != null 
        ? AdConstants.getInterstitialAdId(placement)
        : AdConstants.interstitialAdId;
    
    // Retry loop with exponential backoff
    for (int attempt = 1; attempt <= _maxLoadRetries; attempt++) {
      try {
        final completer = Completer<bool>();
        
        await InterstitialAd.load(
          adUnitId: adUnitId,
          request: const AdRequest(),
          adLoadCallback: InterstitialAdLoadCallback(
            onAdLoaded: (ad) {
              _interstitialAd = ad;
              debugPrint('✅ Interstitial loaded (attempt $attempt) for ${placement?.name ?? "default"}');
              if (!completer.isCompleted) completer.complete(true);
            },
            onAdFailedToLoad: (error) {
              debugPrint('❌ Interstitial failed (attempt $attempt): code=${error.code}, domain=${error.domain}, message=${error.message}');
              _interstitialAd = null;
              if (!completer.isCompleted) completer.complete(false);
            },
          ),
        );
        
        // Wait for the callback (with timeout)
        final success = await completer.future.timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            debugPrint('⏱️ Interstitial load timed out (attempt $attempt)');
            return false;
          },
        );
        
        if (success) return; // Ad loaded successfully
        
        // Wait before retry (exponential backoff: 3s, 6s, 12s)
        if (attempt < _maxLoadRetries) {
          final delay = Duration(seconds: 3 * attempt);
          debugPrint('🔄 Retrying interstitial in ${delay.inSeconds}s...');
          await Future.delayed(delay);
        }
      } catch (e) {
        debugPrint('❌ Interstitial load exception (attempt $attempt): $e');
        if (attempt < _maxLoadRetries) {
          await Future.delayed(Duration(seconds: 3 * attempt));
        }
      }
    }
    debugPrint('⚠️ Interstitial: All $_maxLoadRetries attempts failed for ${placement?.name ?? "default"}');
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
    // SAFETY GUARD: Never show to premium users
    if (!shouldShowAds) {
      debugPrint('👑 Interstitial blocked — premium user or not initialized');
      return false;
    }
    
    if (_interstitialAd == null) {
      debugPrint('⚠️ Interstitial not ready');
      await loadInterstitialAd();
      return false;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('📺 Interstitial: Full screen content shown');
      },
      onAdImpression: (ad) {
        debugPrint('👀 Interstitial: ✅ IMPRESSION RECORDED');
      },
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

    final adUnitId = AdConstants.getRewardedAdId(placement);
    debugPrint('🎯 Loading rewarded ad: ${placement.name} with ID: $adUnitId');
    
    for (int attempt = 1; attempt <= _maxLoadRetries; attempt++) {
      try {
        final completer = Completer<bool>();
        
        await RewardedAd.load(
          adUnitId: adUnitId,
          request: const AdRequest(),
          rewardedAdLoadCallback: RewardedAdLoadCallback(
            onAdLoaded: (ad) {
              _rewardedAds[placement] = ad;
              debugPrint('✅ Rewarded [${placement.name}] loaded (attempt $attempt)');
              if (!completer.isCompleted) completer.complete(true);
            },
            onAdFailedToLoad: (error) {
              debugPrint('❌ Rewarded [${placement.name}] failed (attempt $attempt): code=${error.code}, domain=${error.domain}, message=${error.message}');
              _rewardedAds.remove(placement);
              if (!completer.isCompleted) completer.complete(false);
            },
          ),
        );
        
        final success = await completer.future.timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            debugPrint('⏱️ Rewarded [${placement.name}] timed out (attempt $attempt)');
            return false;
          },
        );
        
        if (success) return;
        
        if (attempt < _maxLoadRetries) {
          final delay = Duration(seconds: 3 * attempt);
          debugPrint('🔄 Retrying rewarded [${placement.name}] in ${delay.inSeconds}s...');
          await Future.delayed(delay);
        }
      } catch (e) {
        debugPrint('❌ Rewarded [${placement.name}] exception (attempt $attempt): $e');
        if (attempt < _maxLoadRetries) {
          await Future.delayed(Duration(seconds: 3 * attempt));
        }
      }
    }
    debugPrint('⚠️ Rewarded [${placement.name}]: All $_maxLoadRetries attempts failed');
  }
  
  /// Check if rewarded ad is ready for specific placement
  bool isRewardedAdReadyFor(RewardedPlacement placement) => _rewardedAds.containsKey(placement);
  
  /// Show rewarded ad for specific placement
  Future<bool> showRewardedAdForPlacement(RewardedPlacement placement, {Function()? onRewarded}) async {
    if (!_rewardedAds.containsKey(placement)) {
      debugPrint('⚠️ Rewarded [${placement.name}] not ready, loading...');
      await loadRewardedAdForPlacement(placement);
      if (!_rewardedAds.containsKey(placement)) {
        return false; // Still not loaded after retry
      }
    }

    final ad = _rewardedAds[placement]!;
    bool rewarded = false;
    
    // Use Completer to await ad dismissal/failure before returning
    // ad.show() returns immediately — we must wait for callbacks
    final completer = Completer<bool>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('📺 Rewarded [${placement.name}]: Full screen content shown');
      },
      onAdImpression: (ad) {
        debugPrint('👀 Rewarded [${placement.name}]: ✅ IMPRESSION RECORDED');
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAds.remove(placement);
        // Preload next ad for same placement
        loadRewardedAdForPlacement(placement);
        if (!completer.isCompleted) completer.complete(rewarded);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('❌ Rewarded [${placement.name}] show failed: $error');
        ad.dispose();
        _rewardedAds.remove(placement);
        loadRewardedAdForPlacement(placement);
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    await ad.show(
      onUserEarnedReward: (ad, reward) {
        rewarded = true;
        debugPrint('🎁 Reward earned [${placement.name}]: ${reward.amount} ${reward.type}');
        onRewarded?.call();
      },
    );

    // Wait for ad to be dismissed or fail (with safety timeout)
    return await completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        debugPrint('⏱️ Rewarded [${placement.name}]: Timed out waiting for ad dismissal');
        return rewarded;
      },
    );
  }
  
  // Legacy methods for backward compatibility
  Future<void> loadRewardedAd() async {
    debugPrint('📢 loadRewardedAd (legacy) called');
    if (kIsWeb) return;
    if (_rewardedAd != null) {
      debugPrint('📢 Rewarded already loaded');
      return;
    }

    for (int attempt = 1; attempt <= _maxLoadRetries; attempt++) {
      try {
        final completer = Completer<bool>();
        
        await RewardedAd.load(
          adUnitId: AdConstants.rewardedAdId,
          request: const AdRequest(),
          rewardedAdLoadCallback: RewardedAdLoadCallback(
            onAdLoaded: (ad) {
              _rewardedAd = ad;
              debugPrint('✅ Rewarded (legacy) loaded (attempt $attempt)');
              if (!completer.isCompleted) completer.complete(true);
            },
            onAdFailedToLoad: (error) {
              debugPrint('❌ Rewarded (legacy) failed (attempt $attempt): code=${error.code}, domain=${error.domain}, message=${error.message}');
              _rewardedAd = null;
              if (!completer.isCompleted) completer.complete(false);
            },
          ),
        );
        
        final success = await completer.future.timeout(
          const Duration(seconds: 15),
          onTimeout: () => false,
        );
        if (success) return;
        
        if (attempt < _maxLoadRetries) {
          await Future.delayed(Duration(seconds: 3 * attempt));
        }
      } catch (e) {
        debugPrint('❌ Rewarded (legacy) exception (attempt $attempt): $e');
        if (attempt < _maxLoadRetries) {
          await Future.delayed(Duration(seconds: 3 * attempt));
        }
      }
    }
    debugPrint('⚠️ Rewarded (legacy): All $_maxLoadRetries attempts failed');
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
      onAdShowedFullScreenContent: (ad) {
        debugPrint('📺 Rewarded (legacy): Full screen content shown');
      },
      onAdImpression: (ad) {
        debugPrint('👀 Rewarded (legacy): ✅ IMPRESSION RECORDED');
      },
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

    for (int attempt = 1; attempt <= _maxLoadRetries; attempt++) {
      try {
        final completer = Completer<bool>();
        
        await AppOpenAd.load(
          adUnitId: AdConstants.appOpenAdId,
          request: const AdRequest(),
          adLoadCallback: AppOpenAdLoadCallback(
            onAdLoaded: (ad) {
              _appOpenAd = ad;
              _appOpenAdLoadTime = DateTime.now();
              debugPrint('✅ App Open loaded (attempt $attempt)');
              if (!completer.isCompleted) completer.complete(true);
            },
            onAdFailedToLoad: (error) {
              debugPrint('❌ App Open failed (attempt $attempt): code=${error.code}, domain=${error.domain}, message=${error.message}');
              _appOpenAd = null;
              _appOpenAdLoadTime = null;
              if (!completer.isCompleted) completer.complete(false);
            },
          ),
        );
        
        final success = await completer.future.timeout(
          const Duration(seconds: 15),
          onTimeout: () => false,
        );
        if (success) return;
        
        if (attempt < _maxLoadRetries) {
          await Future.delayed(Duration(seconds: 3 * attempt));
        }
      } catch (e) {
        debugPrint('❌ App Open exception (attempt $attempt): $e');
        if (attempt < _maxLoadRetries) {
          await Future.delayed(Duration(seconds: 3 * attempt));
        }
      }
    }
    debugPrint('⚠️ App Open: All $_maxLoadRetries attempts failed');
  }

  Future<bool> showAppOpenAd() async {
    // SAFETY GUARD: Never show to premium users
    if (!shouldShowAds) {
      debugPrint('👑 App Open ad blocked — premium user or not initialized');
      return false;
    }
    
    // If ad is null or expired, try to load first
    if (_appOpenAd == null || !_isAppOpenAdValid()) {
      debugPrint('⚠️ App Open ad not ready or expired — loading now...');
      await loadAppOpenAd();
      
      // After loading, check again — if still no ad, give up
      if (_appOpenAd == null || !_isAppOpenAdValid()) {
        debugPrint('❌ App Open ad could not be loaded');
        return false;
      }
    }

    // Use Completer to wait for ad dismissal (same pattern as rewarded ads)
    final completer = Completer<bool>();
    bool shown = false;

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        shown = true;
        debugPrint('📺 App Open: Full screen content shown');
      },
      onAdImpression: (ad) {
        debugPrint('👀 App Open: ✅ IMPRESSION RECORDED');
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _appOpenAd = null;
        _appOpenAdLoadTime = null;
        loadAppOpenAd(); // Pre-load for next time
        if (!completer.isCompleted) completer.complete(shown);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('❌ App Open show failed: $error');
        ad.dispose();
        _appOpenAd = null;
        _appOpenAdLoadTime = null;
        loadAppOpenAd(); // Pre-load for next time
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    await _appOpenAd!.show();
    debugPrint('📺 App Open ad show() called, waiting for dismissal...');
    
    // Wait for ad lifecycle to complete (with 5 min safety timeout)
    final result = await completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () => shown,
    );
    
    return result;
  }

  // ==================== CLEANUP ====================
  
  void dispose() {
    _disposeAllAds();
  }
}

