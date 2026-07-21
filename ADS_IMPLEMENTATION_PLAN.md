# DinCharya Ads System — Implementation Checklist

This document breaks down every file to change, every line of code to modify, and every metric to track.

---

## Phase 1: Emergency UX Fixes (Week 1)

### Task 1.1: Remove Collapsible Banners

**Why**: Collapsible banners cause Cumulative Layout Shift (CLS), accidental clicks, and make app feel janky. They're killing retention.

**Files to modify**:
1. `lib/widgets/ads/banner_ad_widget.dart` — Banner widget implementation
2. `lib/presentation/routine_dashboard/routine_dashboard.dart` — Routine tab banner
3. `lib/presentation/guided_sessions_hub/guided_sessions_hub.dart` — Guided sessions banner
4. `lib/presentation/tapasya/tapasya_hub.dart` — Tapasya tab banner

**Changes**:
- Remove all `collapsible: true` parameters from BannerAdWidget instantiations
- Change banner placement from `Positioned` (floating) to fixed bottom (Column with Expanded)
- Set fixed height: 50px for standard banner, no expansion
- Add `key: ValueKey('banner_${placement.id}')` to prevent rebuild fluttering

**Before** (Routine Dashboard):
```dart
Positioned(
  bottom: 0,
  left: 0,
  right: 0,
  child: BannerAdWidget(
    placement: BannerPlacement.routineDashboard,
    collapsible: true, // ❌ REMOVE THIS
  ),
)
```

**After** (Routine Dashboard):
```dart
SizedBox(
  height: 50,
  child: BannerAdWidget(
    placement: BannerPlacement.routineDashboard,
    // collapsible removed
  ),
)
```

**Timeline**: 30 min per screen (4 screens = 2 hours total)

---

### Task 1.2: Reduce Native Ad Density on Routine Dashboard

**Why**: 3 native ads on 1 screen = "this app is just ads". Reducing to 1 will cut ad exposure dramatically.

**Files to modify**:
1. `lib/presentation/routine_dashboard/routine_dashboard.dart` — Remove 2 native ad widgets

**Changes**:
- Find all `NativeAdWidget` calls in routine_dashboard.dart
- Keep: Morning section native (shows best habits)
- Remove: Afternoon section native, general section native
- Replace removed widgets with simple spacing/padding

**Before** (lines ~450, ~650, ~850):
```dart
// Morning section
NativeAdWidget(
  placement: NativePlacement.routineMorning,
  height: 150,
),
// Afternoon section
NativeAdWidget(
  placement: NativePlacement.routineAfternoon,
  height: 150,
),
// General section
NativeAdWidget(
  placement: NativePlacement.routineGeneral,
  height: 150,
),
```

**After**:
```dart
// Morning section
NativeAdWidget(
  placement: NativePlacement.routineMorning,
  height: 150,
),
// Afternoon section — removed native ad, add padding instead
SizedBox(height: 16),
// General section — removed native ad
```

**Timeline**: 20 min

**Measurement**: Track "native ad impressions by placement" in AdMob before/after.

---

### Task 1.3: Change Interstitial Frequency — 2 Actions → 1 Action

**Why**: Current 2-action trigger doesn't fire in short sessions (avg 1m 47s). Users see 0 interstitials = wasted inventory. Change to 1 action = ads show in every session.

**Files to modify**:
1. `lib/services/ads_service.dart` — AdsService interstitial logic
2. `lib/presentation/routine_dashboard/routine_dashboard.dart` — Task completion callback
3. `lib/presentation/journal_mood_tracker/journal_mood_tracker.dart` — Journal save callback
4. `lib/presentation/media_player/media_player_mobile.dart` — Session end callback

**Changes in ads_service.dart**:

**Before**:
```dart
class AdsService {
  int _interstitialActionsInSession = 0;
  static const int _INTERSTITIAL_ACTION_THRESHOLD = 2; // ❌ CHANGE TO 1
  
  void trackAction(String actionType) {
    _interstitialActionsInSession++;
    if (_interstitialActionsInSession >= _INTERSTITIAL_ACTION_THRESHOLD) {
      showInterstitialAd();
      _interstitialActionsInSession = 0; // Reset after showing
    }
  }
}
```

**After**:
```dart
class AdsService {
  int _interstitialActionsInSession = 0;
  static const int _INTERSTITIAL_ACTION_THRESHOLD = 1; // ✅ CHANGED
  static const int _INTERSTITIAL_COOLDOWN_MS = 120000; // Add 120-sec cooldown
  DateTime? _lastInterstitialTime;
  
  void trackAction(String actionType) {
    _interstitialActionsInSession++;
    
    // Check cooldown + threshold
    if (_interstitialActionsInSession >= _INTERSTITIAL_ACTION_THRESHOLD) {
      final now = DateTime.now();
      if (_lastInterstitialTime == null ||
          now.difference(_lastInterstitialTime!).inMilliseconds >= _INTERSTITIAL_COOLDOWN_MS) {
        showInterstitialAd();
        _lastInterstitialTime = now;
        _interstitialActionsInSession = 0;
      }
    }
  }
}
```

**Changes in screens** (routine_dashboard.dart example):

**Before**:
```dart
void _onTaskComplete(Task task) {
  adsService.trackAction('task_added'); // Tracked but might not trigger
  // ... update UI
}
```

**After**:
```dart
void _onTaskComplete(Task task) {
  adsService.trackAction('task_complete');
  // ... update UI
}
```

**Timeline**: 45 min

**Measurement**: Track "interstitial impressions per session" before/after.

---

### Task 1.4: A/B Test with Remote Config

**Why**: Validate that new system improves retention before rolling out to 100%.

**Files to modify**:
1. `lib/main.dart` — Initialize Firebase Remote Config
2. `lib/services/ads_service.dart` — Check Remote Config flag

**Changes in main.dart**:

**Add to initializeApp()**:
```dart
// Initialize Firebase Remote Config
final remoteConfig = FirebaseRemoteConfig.instance;
await remoteConfig.setConfigSettings(
  RemoteConfigSettings(
    fetchTimeout: const Duration(minutes: 1),
    minimumFetchInterval: const Duration(hours: 1),
  ),
);

// Fetch and activate remote config
await remoteConfig.fetchAndActivate();

// Store in a global variable or service
GetIt.I.registerSingleton(remoteConfig);
```

**Changes in ads_service.dart**:

```dart
class AdsService {
  final FirebaseRemoteConfig _remoteConfig = GetIt.I<FirebaseRemoteConfig>();
  
  bool get _useNewAdStrategy {
    return _remoteConfig.getBool('use_new_ads_strategy') ?? false;
  }
  
  void trackAction(String actionType) {
    if (_useNewAdStrategy) {
      // New: 1 action, 120-sec cooldown
      _trackActionNewStrategy(actionType);
    } else {
      // Old: 2 actions, no cooldown
      _trackActionOldStrategy(actionType);
    }
  }
}
```

**Firebase Console Setup**:
1. Go to Firebase Console → Remote Config
2. Create parameter: `use_new_ads_strategy` (Boolean)
3. Set conditional rule: User in "beta-testers" audience → value: true
4. Create audience: "beta-testers" = 10% of users (Firebase → Audience)

**Timeline**: 1 hour

**Measurement period**: 7 days. Measure:
- D1 retention (new vs. old)
- Interstitial impressions
- Revenue per user

---

## Phase 2: High-eCPM Format Switch (Week 2–3)

### Task 2.1: Rewarded Interstitial at 3 Placements

**Why**: Rewarded interstitial eCPM is $12–$18 vs. banner $0.50–$2. 10x better. No opt-in required (intro screen is enough).

**Google AdMob Setup** (do this first):
1. Create 3 new ad units (Rewarded Interstitial format):
   - `ca-app-pub-xxx-xxx-ria-routine-completion` (after task marked complete)
   - `ca-app-pub-xxx-xxx-ria-session-end` (after guided session recorded)
   - `ca-app-pub-xxx-xxx-ria-journal-save` (after journal entry saved)

**Files to modify**:
1. `lib/services/ads_service.dart` — Add rewarded interstitial loading/showing
2. `lib/presentation/routine_dashboard/routine_dashboard.dart` — Trigger after task completion
3. `lib/presentation/media_player/media_player_mobile.dart` — Trigger after session end
4. `lib/presentation/journal_mood_tracker/journal_mood_tracker.dart` — Trigger after journal save

**Implementation in ads_service.dart**:

```dart
RewardedInterstitialAd? _rewardedInterstitialAd;

Future<void> loadRewardedInterstitialAd(String adUnitId) async {
  await RewardedInterstitialAd.load(
    adUnitId: adUnitId,
    request: const AdRequest(),
    rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
      onAdLoaded: (RewardedInterstitialAd ad) {
        _rewardedInterstitialAd = ad;
        ad.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) {
            ad.dispose();
            _rewardedInterstitialAd = null;
          },
        );
      },
    ),
  );
}

Future<void> showRewardedInterstitialAd(
  String adUnitId,
  String rewardMessage, {
  required VoidCallback onRewarded,
}) async {
  if (_rewardedInterstitialAd == null) {
    await loadRewardedInterstitialAd(adUnitId);
  }

  if (_rewardedInterstitialAd != null) {
    _rewardedInterstitialAd!.show(
      onUserEarnedReward: (ad, reward) {
        // Award the user (e.g., +5 min guided session)
        print('[v0] User earned reward: ${reward.amount} ${reward.type}');
        onRewarded();
      },
    );
  }
}
```

**Implementation in screens** (routine_dashboard.dart example):

```dart
void _onTaskComplete(Task task) {
  print('[v0] Task completed: ${task.name}');
  
  // Update UI, etc.
  _updateRoutineUI();
  
  // Show rewarded interstitial after task completion
  adsService.showRewardedInterstitialAd(
    'ca-app-pub-xxx-xxx-ria-routine-completion',
    'Watch a short ad to unlock +5 minutes of guided sessions!',
    onRewarded: () {
      // Grant user the reward
      sessionService.addBonusMinutes(5);
      _showSnackBar('You earned 5 bonus minutes!');
    },
  );
}
```

**Timeline**: 3 hours (1 hour per placement)

**Measurement**: Track rewarded interstitial impressions, completion rate, reward claims in AdMob.

---

### Task 2.2: Consolidate Banner Placements (10 → 3)

**Why**: Fewer banners = higher eCPM per banner (Google rewards focus), better user experience, easier to manage.

**Current placements** (remove 7):
1. ✅ Profile → Keep (browsing screen, low urgency)
2. ✅ History → Keep (looking back, passive)
3. ✅ Help Center → Keep (support, low engagement)
4. ❌ Routine Dashboard → Remove (CORE engagement)
5. ❌ Media Player → Remove (CORE engagement)
6. ❌ Journal → Remove (CORE engagement)
7. ❌ Guided Sessions Hub → Remove (CORE engagement)
8. ❌ Tapasya Hub → Remove (CORE engagement)
9. ❌ Meditation Timer → Remove (CORE engagement)
10. ❌ Yoga Practice → Remove (CORE engagement)

**Files to modify**:
1. `lib/presentation/profile/profile_screen.dart` — Keep banner
2. `lib/presentation/history/history_screen.dart` — Keep banner
3. `lib/presentation/help_center/help_center_screen.dart` — Keep banner
4. All other screens with banners — Remove them

**Timeline**: 2 hours

**Measurement**: Track banner impressions (should consolidate on 3 screens).

---

### Task 2.3: Native Ad Repositioning

**Why**: Move native ads from core engagement screens (Routine) to passive browsing screens (History, Profile).

**Current placements** (remove 4, add 2):
1. ❌ Routine Dashboard (morning, afternoon, general) — Remove all 3
2. ✅ Guided Sessions Hub (1 native) — Keep, it's passive browsing
3. ✅ Media Player (1 native at end) — Keep
4. ✅ Profile achievements section (1 native) → Add here
5. ✅ History feed (1 native, mid-feed) → Add here

**Timeline**: 1 hour

**Measurement**: Track CTR, completion rate for native ads by placement in AdMob.

---

## Phase 3: Premium Tier Gating (Week 4)

### Task 3.1: Add Premium User Ad-Removal Checks

**Why**: If users pay for premium, they should see zero ads. This is the conversion hook.

**Files to modify**:
1. `lib/services/user_service.dart` — Add `isPremium` flag
2. `lib/services/ads_service.dart` — Check `isPremium` before showing any ad
3. All banner/native/interstitial calls — Add guard

**Changes in user_service.dart**:

```dart
class UserService {
  Future<bool> isPremiumUser() async {
    // Check Supabase or in-app purchase status
    final user = await supabase
        .from('user_subscriptions')
        .select('status')
        .eq('user_id', currentUser.id)
        .single();
    
    return user['status'] == 'active';
  }
}
```

**Changes in ads_service.dart**:

```dart
class AdsService {
  Future<void> showBannerAd(BannerPlacement placement) async {
    // Guard: Don't show ads to premium users
    if (await userService.isPremiumUser()) {
      return;
    }
    
    // ... show banner
  }
  
  Future<void> showNativeAd(NativePlacement placement) async {
    if (await userService.isPremiumUser()) {
      return;
    }
    
    // ... show native
  }
  
  Future<void> showInterstitialAd() async {
    if (await userService.isPremiumUser()) {
      return;
    }
    
    // ... show interstitial
  }
}
```

**Timeline**: 1 hour

---

### Task 3.2: Paywall Implementation

**Why**: After 2–3 ads viewed, show a paywall offering premium (ad-free + extra features).

**Files to modify**:
1. `lib/presentation/paywall/paywall_screen.dart` — Create paywall UI (or update existing)
2. `lib/services/ads_service.dart` — Track ad views, trigger paywall
3. `lib/services/payment_service.dart` — Handle subscription purchase

**Implementation in ads_service.dart**:

```dart
class AdsService {
  int _adsViewedInSession = 0;
  static const int _PAYWALL_TRIGGER_THRESHOLD = 2; // After 2 ads
  
  void _trackAdView() {
    _adsViewedInSession++;
    
    if (_adsViewedInSession >= _PAYWALL_TRIGGER_THRESHOLD) {
      _showPaywall();
    }
  }
  
  Future<void> _showPaywall() async {
    // Show paywall modal
    Get.to(() => PaywallScreen(
      reason: 'Remove ads + unlock premium features',
    ));
    
    // Reset counter
    _adsViewedInSession = 0;
  }
}
```

**Paywall screen tiers** (copy from `lib/presentation/paywall/paywall_screen.dart`):
1. Monthly: $2.99
2. Annual: $19.99 (save 44%)
3. Lifetime: $49.99

**Timeline**: 2 hours

---

## Phase 4: Analytics & Optimization (Ongoing)

### Setup Firebase Analytics Tracking

**Files to modify**:
1. `lib/services/analytics_service.dart` — Add new custom events

**Custom events to track**:

```dart
class AnalyticsService {
  // Ad impressions
  void logAdImpression(String format, String placement, double ecpm) {
    _analytics.logEvent(
      name: 'ad_impression',
      parameters: {
        'format': format, // 'banner', 'native', 'interstitial', 'rewarded'
        'placement': placement,
        'ecpm': ecpm,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }
  
  // Ad clicks
  void logAdClick(String format, String placement) {
    _analytics.logEvent(
      name: 'ad_click',
      parameters: {
        'format': format,
        'placement': placement,
      },
    );
  }
  
  // Paywall impressions
  void logPaywallImpression(String reason) {
    _analytics.logEvent(
      name: 'paywall_impression',
      parameters: {'reason': reason},
    );
  }
  
  // Paywall conversions
  void logPaywallConversion(String tier, double price) {
    _analytics.logEvent(
      name: 'paywall_conversion',
      parameters: {
        'tier': tier,
        'price': price,
      },
    );
  }
  
  // Ad-free session
  void logAdFreeSession(String reason) {
    _analytics.logEvent(
      name: 'ad_free_session',
      parameters: {'reason': reason}, // 'premium', 'trial', 'beta'
    );
  }
}
```

**Dashboard to create** (in admin dashboard):
1. ARPU by day
2. Ad impressions by format
3. Paywall conversion rate
4. D1/D7/D30 retention

---

## Files Changed Summary

### Phase 1 (Week 1)
- `lib/widgets/ads/banner_ad_widget.dart` (update banner rendering)
- `lib/presentation/routine_dashboard/routine_dashboard.dart` (remove collapsible, remove 2 natives)
- `lib/presentation/guided_sessions_hub/guided_sessions_hub.dart` (remove collapsible)
- `lib/presentation/tapasya/tapasya_hub.dart` (remove collapsible)
- `lib/services/ads_service.dart` (add Remote Config, change threshold)
- `lib/main.dart` (init Remote Config)

### Phase 2 (Week 2–3)
- `lib/services/ads_service.dart` (add rewarded interstitial methods)
- `lib/presentation/routine_dashboard/routine_dashboard.dart` (trigger RIA on task complete)
- `lib/presentation/media_player/media_player_mobile.dart` (trigger RIA on session end)
- `lib/presentation/journal_mood_tracker/journal_mood_tracker.dart` (trigger RIA on journal save)
- `lib/presentation/profile/profile_screen.dart` (add native ad)
- `lib/presentation/history/history_screen.dart` (add native ad)
- Remove banners from: media_player, guided_sessions_hub, tapasya_hub, meditation_timer, yoga_practice

### Phase 3 (Week 4)
- `lib/services/user_service.dart` (add isPremiumUser check)
- `lib/services/ads_service.dart` (guard all ad calls with isPremium)
- `lib/presentation/paywall/paywall_screen.dart` (update or create)
- `lib/services/payment_service.dart` (handle subscriptions)

### Phase 4 (Ongoing)
- `lib/services/analytics_service.dart` (add custom events)
- Admin dashboard updates (new analytics cards)

---

## Estimated Timeline

| Phase | Duration | Complexity |
|-------|----------|-----------|
| Phase 1 (UX fixes) | 4–5 hours | Low–Medium |
| Phase 2 (High-eCPM) | 6–8 hours | Medium |
| Phase 3 (Premium) | 4–6 hours | Medium–High |
| Phase 4 (Analytics) | 3–4 hours | Low |
| **Total** | **17–23 hours** | - |

**Realistic sprint**: 2–3 developers, 2 weeks (with testing/QA).

---

## Success Checkpoints

- [ ] Phase 1 complete, A/B test running (7 days)
- [ ] Retention improving in test group (D1 > 5%)
- [ ] Phase 2 deployed to 100% (week 2)
- [ ] Rewarded interstitial impressions tracked
- [ ] Phase 3 paywall live (week 4)
- [ ] Premium conversion tracked
- [ ] Analytics dashboard live
- [ ] 30-day metrics review meeting
