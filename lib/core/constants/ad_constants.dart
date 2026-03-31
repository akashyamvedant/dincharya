// lib/core/constants/ad_constants.dart
// AdMob Ad Unit IDs
// Production IDs: Replace YOUR_ID placeholders with real IDs from AdMob dashboard
// Test IDs: Google's official test IDs (always work, no policy violations)
// 
// NOTE: Using separate IDs per placement is RECOMMENDED by Google for:
// - Better analytics (track performance per screen)
// - Better optimization (AdMob optimizes per placement)
// - NOT against policy - Google RECOMMENDS this approach

import 'dart:io';
import 'package:flutter/foundation.dart';

/// Banner placement types for different screens
enum BannerPlacement {
  journal,           // Journal/Mood Tracker screen
  meTab,             // Me Tab (Profile Settings)
  editProfile,       // Edit Profile screen
  yourJourney,       // History/Your Journey screen
  changeProfile,     // Profile Selection screen
  routineDashboard,  // Routine Dashboard anchored banner
  guidedHub,         // Guided Sessions Hub anchored banner
  sessionDetail,     // Media Player (Theory + Fallback) detail page
  programDetail,     // Program Detail screen
}

/// Interstitial placement types for different user actions
enum InterstitialPlacement {
  taskAdded,       // After adding a task in Routine Dashboard
  journalSaved,    // After saving a journal entry
  sessionEnded,    // After finishing a guided session
}

/// Native Ad placement types for different screens
enum NativePlacement {
  sessionFeed,        // Guided Sessions list feed (between session cards)
  meTab,              // Me Tab profile screen (card style)
  routineDashboard,   // Routine task list (after evening tasks)
  routineMorning,     // After morning task section
  routineAfternoon,   // After afternoon task section
  sessionTheory,      // Media Player Theory tab (between content sections)
}

/// Rewarded Ad placement types for Guided Sessions
/// Each tab (Meditation, Breathe, Yoga) has 3 sessions that can be unlocked
enum RewardedPlacement {
  // Meditation tab - 3 sessions
  meditationSession1,  // First meditation session unlock
  meditationSession2,  // Second meditation session unlock
  meditationSession3,  // Third meditation session unlock
  
  // Breathe tab - 3 sessions
  breatheSession1,     // First breathe session unlock
  breatheSession2,     // Second breathe session unlock
  breatheSession3,     // Third breathe session unlock
  
  // Yoga tab - 3 sessions
  yogaSession1,        // First yoga session unlock
  yogaSession2,        // Second yoga session unlock
  yogaSession3,        // Third yoga session unlock
}

class AdConstants {
  AdConstants._();

  // ════════════════════════════════════════════════════════════════
  // PRODUCTION BANNER AD UNIT IDs - One per placement (recommended)
  // Get these from AdMob Console: Apps > Dincharya > Ad units
  // ════════════════════════════════════════════════════════════════
  static const String _prodBannerJournalAndroid = 'ca-app-pub-6276884053063994/2514578501';
  static const String _prodBannerMeTabAndroid = 'ca-app-pub-6276884053063994/4355563733';
  static const String _prodBannerEditProfileAndroid = 'ca-app-pub-6276884053063994/5267629654';
  static const String _prodBannerYourJourneyAndroid = 'ca-app-pub-6276884053063994/1352495447';
  static const String _prodBannerChangeProfileAndroid = 'ca-app-pub-6276884053063994/5076057962';
  static const String _prodBannerRoutineDashboardAndroid = 'ca-app-pub-6276884053063994/5140568691';
  static const String _prodBannerGuidedHubAndroid = 'ca-app-pub-6276884053063994/3827487020';
  static const String _prodBannerSessionDetailAndroid = 'ca-app-pub-6276884053063994/3827487020';
  static const String _prodBannerProgramDetailAndroid = 'ca-app-pub-6276884053063994/4317144444';

  // ════════════════════════════════════════════════════════════════
  // PRODUCTION INTERSTITIAL AD UNIT IDs - One per placement
  // ════════════════════════════════════════════════════════════════
  static const String _prodInterstitialTaskAddedAndroid = 'ca-app-pub-6276884053063994/8888415167';
  static const String _prodInterstitialJournalSavedAndroid = 'ca-app-pub-6276884053063994/6728885130';
  static const String _prodInterstitialSessionEndedAndroid = 'ca-app-pub-6276884053063994/6150360709';

  // ════════════════════════════════════════════════════════════════
  // PRODUCTION NATIVE AD UNIT IDs - One per placement
  // ════════════════════════════════════════════════════════════════
  static const String _prodNativeSessionFeedAndroid = 'ca-app-pub-6276884053063994/8970291749';
  static const String _prodNativeMeTabAndroid = 'ca-app-pub-6276884053063994/7361835177';
  static const String _prodNativeRoutineDashboardAndroid = 'ca-app-pub-6276884053063994/6713407416';
  static const String _prodNativeRoutineMorningAndroid = 'ca-app-pub-6276884053063994/7910243828';
  static const String _prodNativeRoutineAfternoonAndroid = 'ca-app-pub-6276884053063994/1970848987';
  
  // ════════════════════════════════════════════════════════════════
  // PRODUCTION REWARDED AD UNIT IDs - 9 placements for Guided Sessions
  // ════════════════════════════════════════════════════════════════
  
  // Meditation Tab - 3 sessions
  static const String _prodRewardedMeditation1Android = 'ca-app-pub-6276884053063994/4867236020';
  static const String _prodRewardedMeditation2Android = 'ca-app-pub-6276884053063994/3554154359';
  static const String _prodRewardedMeditation3Android = 'ca-app-pub-6276884053063994/6997014842';
  
  // Breathe Tab - 3 sessions
  static const String _prodRewardedBreathe1Android = 'ca-app-pub-6276884053063994/6758902193';
  static const String _prodRewardedBreathe2Android = 'ca-app-pub-6276884053063994/6100426644';
  static const String _prodRewardedBreathe3Android = 'ca-app-pub-6276884053063994/8389987560';
  
  // Yoga Tab - 3 sessions
  static const String _prodRewardedYoga1Android = 'ca-app-pub-6276884053063994/8614909347';
  static const String _prodRewardedYoga2Android = 'ca-app-pub-6276884053063994/8765392083';
  static const String _prodRewardedYoga3Android = 'ca-app-pub-6276884053063994/4332448782';
  
  // Legacy single rewarded (for backward compatibility)
  static const String _prodRewardedAndroid = 'ca-app-pub-6276884053063994/7657210076';
  static const String _prodRewardedIOS = 'ca-app-pub-6276884053063994/YOUR_REWARDED_IOS';
  
  // ════════════════════════════════════════════════════════════════
  // APP OPEN AD UNIT IDs
  // ════════════════════════════════════════════════════════════════
  static const String _prodAppOpenAndroid = 'ca-app-pub-6276884053063994/1201496833';
  static const String _prodAppOpenIOS = 'ca-app-pub-6276884053063994/YOUR_APP_OPEN_IOS';

  // ════════════════════════════════════════════════════════════════
  // TEST AD UNIT IDs - Official Google Test IDs (always work)
  // All placements use the same test ID during development
  // ════════════════════════════════════════════════════════════════
  static const String _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testBannerIOS = 'ca-app-pub-3940256099942544/2934735716';
  
  static const String _testInterstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testInterstitialIOS = 'ca-app-pub-3940256099942544/4411468910';
  
  static const String _testRewardedAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const String _testRewardedIOS = 'ca-app-pub-3940256099942544/1712485313';
  
  static const String _testAppOpenAndroid = 'ca-app-pub-3940256099942544/9257395921';
  static const String _testAppOpenIOS = 'ca-app-pub-3940256099942544/5575463023';
  
  static const String _testNativeAndroid = 'ca-app-pub-3940256099942544/2247696110';
  static const String _testNativeIOS = 'ca-app-pub-3940256099942544/3986624511';

  // ════════════════════════════════════════════════════════════════
  // SMART ID GETTERS - Automatically use test IDs in debug mode
  // ════════════════════════════════════════════════════════════════
  
  /// Get banner ad unit ID for a specific placement
  static String getBannerAdId(BannerPlacement placement) {
    if (kDebugMode) {
      return Platform.isAndroid ? _testBannerAndroid : _testBannerIOS;
    }
    
    if (!Platform.isAndroid) {
      return _testBannerIOS; // iOS uses test ID until real IDs are added
    }
    
    switch (placement) {
      case BannerPlacement.journal:
        return _prodBannerJournalAndroid;
      case BannerPlacement.meTab:
        return _prodBannerMeTabAndroid;
      case BannerPlacement.editProfile:
        return _prodBannerEditProfileAndroid;
      case BannerPlacement.yourJourney:
        return _prodBannerYourJourneyAndroid;
      case BannerPlacement.changeProfile:
        return _prodBannerChangeProfileAndroid;
      case BannerPlacement.routineDashboard:
        return _prodBannerRoutineDashboardAndroid;
      case BannerPlacement.guidedHub:
        return _prodBannerGuidedHubAndroid;
      case BannerPlacement.sessionDetail:
        return _prodBannerSessionDetailAndroid;
      case BannerPlacement.programDetail:
        return _prodBannerProgramDetailAndroid;
    }
  }
  
  /// Get interstitial ad unit ID for a specific placement
  static String getInterstitialAdId(InterstitialPlacement placement) {
    if (kDebugMode) {
      return Platform.isAndroid ? _testInterstitialAndroid : _testInterstitialIOS;
    }
    
    if (!Platform.isAndroid) {
      return _testInterstitialIOS; // iOS uses test ID until real IDs are added
    }
    
    switch (placement) {
      case InterstitialPlacement.taskAdded:
        return _prodInterstitialTaskAddedAndroid;
      case InterstitialPlacement.journalSaved:
        return _prodInterstitialJournalSavedAndroid;
      case InterstitialPlacement.sessionEnded:
        return _prodInterstitialSessionEndedAndroid;
    }
  }
  
  /// Get native ad unit ID for a specific placement
  static String getNativeAdId(NativePlacement placement) {
    if (kDebugMode) {
      return Platform.isAndroid ? _testNativeAndroid : _testNativeIOS;
    }
    
    if (!Platform.isAndroid) {
      return _testNativeIOS; // iOS uses test ID until real IDs are added
    }
    
    switch (placement) {
      case NativePlacement.sessionFeed:
        return _prodNativeSessionFeedAndroid;
      case NativePlacement.meTab:
        return _prodNativeMeTabAndroid;
      case NativePlacement.routineDashboard:
        return _prodNativeRoutineDashboardAndroid;
      case NativePlacement.routineMorning:
        return _prodNativeRoutineMorningAndroid;
      case NativePlacement.routineAfternoon:
        return _prodNativeRoutineAfternoonAndroid;
      case NativePlacement.sessionTheory:
        return _prodNativeSessionFeedAndroid; // Reuses sessionFeed — never on-screen simultaneously
    }
  }
  
  /// Legacy getter for backward compatibility
  static String get bannerAdId => getBannerAdId(BannerPlacement.journal);
  
  /// Legacy getter for backward compatibility
  static String get interstitialAdId => getInterstitialAdId(InterstitialPlacement.taskAdded);
  
  /// Legacy getter for backward compatibility
  static String get nativeAdId => getNativeAdId(NativePlacement.sessionFeed);

  /// Get rewarded ad unit ID for a specific placement
  /// Used for Guided Sessions - Meditation, Breathe, Yoga tabs
  static String getRewardedAdId(RewardedPlacement placement) {
    if (kDebugMode) {
      return Platform.isAndroid ? _testRewardedAndroid : _testRewardedIOS;
    }
    
    if (!Platform.isAndroid) {
      return _testRewardedIOS; // iOS uses test ID until real IDs are added
    }
    
    switch (placement) {
      // Meditation tab
      case RewardedPlacement.meditationSession1:
        return _prodRewardedMeditation1Android;
      case RewardedPlacement.meditationSession2:
        return _prodRewardedMeditation2Android;
      case RewardedPlacement.meditationSession3:
        return _prodRewardedMeditation3Android;
      
      // Breathe tab
      case RewardedPlacement.breatheSession1:
        return _prodRewardedBreathe1Android;
      case RewardedPlacement.breatheSession2:
        return _prodRewardedBreathe2Android;
      case RewardedPlacement.breatheSession3:
        return _prodRewardedBreathe3Android;
      
      // Yoga tab
      case RewardedPlacement.yogaSession1:
        return _prodRewardedYoga1Android;
      case RewardedPlacement.yogaSession2:
        return _prodRewardedYoga2Android;
      case RewardedPlacement.yogaSession3:
        return _prodRewardedYoga3Android;
    }
  }

  /// Legacy rewarded ad - fallback for backward compatibility
  static String get rewardedAdId {
    if (kDebugMode) {
      return Platform.isAndroid ? _testRewardedAndroid : _testRewardedIOS;
    }
    return Platform.isAndroid ? _prodRewardedAndroid : _prodRewardedIOS;
  }

  /// App Open ad unit ID - shows when app comes to foreground
  static String get appOpenAdId {
    if (kDebugMode) {
      return Platform.isAndroid ? _testAppOpenAndroid : _testAppOpenIOS;
    }
    return Platform.isAndroid ? _prodAppOpenAndroid : _prodAppOpenIOS;
  }

  // ════════════════════════════════════════════════════════════════
  // FREQUENCY CAPPING - AdMob 2026 Policy Compliant
  // Google recommends: max 1 interstitial per hour per user
  // Wellness apps should be even more conservative to avoid
  // negative reviews and user churn
  // ════════════════════════════════════════════════════════════════
  
  /// Show interstitial after this many user actions (natural transitions)
  /// 3 actions = optimal for typical 1-3 action sessions
  static const int interstitialFrequency = 3;
  
  /// Minimum seconds between interstitial ads (any placement)
  /// 2 minutes (120s) = conservative but allows impressions within sessions
  static const int minSecondsBetweenInterstitials = 120;
  
  /// Minimum minutes between App Open ads (time-based cooldown)
  /// 60 minutes = allows re-engagement ads without being intrusive
  static const int minMinutesBetweenAppOpenAds = 60;
  
  /// App Open ad expiry in hours (Google policy: max 4 hours)
  static const int appOpenAdExpiryHours = 4;
}
