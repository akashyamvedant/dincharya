# Phase 1 — Exact Change Specifications

**Status**: Ready to implement  
**Risk Level**: LOW (changes 1 & 2), MEDIUM (change 3)  
**Total Time**: 4-5 hours including testing  
**Rollback Time**: 30 minutes

---

## Change 1: Remove Collapsible Banners from 3 Screens

### Why This Matters
- Current: Banners expand as users scroll → layout thrashing, 48.81% ad exposure
- Target: Fixed bottom banners → smooth UX, predictable ad placement
- Expected impact: Ad exposure 48.81% → 30-35%, perceived performance improves

### Screens Affected
1. **Routine Dashboard** — Morning/afternoon task list
2. **Guided Sessions Hub** — Session feed
3. **Tapasya Hub** — Challenge feed (may not need change if not collapsible)

### Current Code
```dart
// lib/widgets/ads/banner_ad_widget.dart (lines 97-105)
final isCollapsible = widget.placement == BannerPlacement.routineDashboard || 
                      widget.placement == BannerPlacement.guidedHub || 
                      widget.placement == BannerPlacement.journal;

_bannerAd = BannerAd(
  adUnitId: adUnitId,
  size: _adSize!,
  request: isCollapsible 
      ? const AdRequest(extras: {'collapsible': 'bottom'}) 
      : const AdRequest(),
  ...
);
```

### Change Required
**Line 97-98 in banner_ad_widget.dart:**

BEFORE:
```dart
final isCollapsible = widget.placement == BannerPlacement.routineDashboard || 
                      widget.placement == BannerPlacement.guidedHub || 
                      widget.placement == BannerPlacement.journal;
```

AFTER:
```dart
// PHASE 1 FIX: Remove collapsible banners (except journal which is safe)
// Rationale: Collapsible banners on task lists cause layout thrashing.
// Journal keeps collapsible=true because it's an infinite feed.
final isCollapsible = widget.placement == BannerPlacement.journal;
```

RESULT: Banners now fixed on Routine Dashboard & Guided Hub, collapsible only on Journal (safe).

---

## Change 2: Reduce Native Ads on Routine Dashboard (3 → 1)

### Why This Matters
- Current: 3 native ads (morning section + afternoon section + general)
- Target: 1 native ad (general section at bottom only)
- Expected impact: Ad density halved on main screen, users see more tasks than ads

### Current Code
```dart
// lib/presentation/routine_dashboard/routine_dashboard.dart
// Lines 982-1000

// Morning native (after morning tasks)
child: const NativeAdWidget(placement: NativePlacement.routineMorning),

// Afternoon native (after afternoon tasks)
child: const NativeAdWidget(placement: NativePlacement.routineAfternoon),

// General native (after evening tasks)
child: const NativeAdWidget(placement: NativePlacement.routineDashboard),
```

### Change Required
**Lines 975-989 and 995-1001 in routine_dashboard.dart:**

Comment out (do NOT delete) the morning and afternoon native ads:

BEFORE:
```dart
// After morning tasks
...
child: const NativeAdWidget(placement: NativePlacement.routineMorning),
...

// After afternoon tasks
...
child: const NativeAdWidget(placement: NativePlacement.routineAfternoon),
...

// After evening tasks
...
child: const NativeAdWidget(placement: NativePlacement.routineDashboard),
```

AFTER:
```dart
// After morning tasks
...
// [PHASE 1 FIX] Removed: morning native ad (reducing density 3→1)
// child: const NativeAdWidget(placement: NativePlacement.routineMorning),
...

// After afternoon tasks
...
// [PHASE 1 FIX] Removed: afternoon native ad (reducing density 3→1)
// child: const NativeAdWidget(placement: NativePlacement.routineAfternoon),
...

// After evening tasks
...
child: const NativeAdWidget(placement: NativePlacement.routineDashboard),  // Keep this one
```

RESULT: Only 1 native ad shows on Routine Dashboard (general section), morning/afternoon removed.

---

## Change 3: Lower Interstitial Frequency Trigger (2 → 1 action)

### Why This Matters
- Current: Interstitial shows after 2 user actions
- Problem: Avg session is 1m 47s with only 2.05 actions/session → most users only do 1-2 things, ad never shows
- Target: Show after 1 action → ads show for ~90% of sessions instead of 10-15%
- Risk: MEDIUM (will increase ad frequency, could affect retention further if not good quality)

### Current Code
```dart
// lib/core/constants/ad_constants.dart (line ~261)
static const int interstitialFrequency = 2;
```

### Change Required
**Line 261 in ad_constants.dart:**

BEFORE:
```dart
static const int interstitialFrequency = 2;
```

AFTER:
```dart
/// [PHASE 1 FIX] Lowered from 2→1 to increase show rate (was ~10%, target ~90%)
/// Risk: Monitor CTR + retention closely (if retention worsens, revert to 2)
static const int interstitialFrequency = 1;
```

RESULT: Interstitial ads now show after the first action instead of second (e.g., after adding 1st task, saving 1st journal).

---

## Verification Checklist (After Each Change)

### Change 1 Verification
- [ ] App builds without errors
- [ ] Routine Dashboard loads (no crashes)
- [ ] Banner ad renders at bottom, doesn't expand on scroll
- [ ] No layout shifts when banner loads/unloads
- [ ] Guided Hub loads, same fixed banner behavior
- [ ] Journal screen still has collapsible banner (collapsing should still work)

### Change 2 Verification
- [ ] Routine Dashboard loads
- [ ] Only 1 native ad appears (at bottom, after evening section)
- [ ] Morning/afternoon sections have no native ads
- [ ] Scroll performance feels smooth (no jank from ad placement)
- [ ] No crashes or blank spaces where native ads were removed

### Change 3 Verification
- [ ] App builds without errors
- [ ] Add a task → interstitial should show (was: needed 2 tasks)
- [ ] Save a journal → interstitial should show (was: needed 2 journals)
- [ ] Verify frequency capping still works (ads don't show every 5 seconds)
- [ ] No crashes, frequency cap throttles as expected

---

## Commit Plan

3 separate commits (1 per change):

```bash
# Commit 1
git add lib/widgets/ads/banner_ad_widget.dart
git commit -m "feat(ads): Remove collapsible banners from Routine & Guided Hub

- Switch Routine Dashboard & Guided Hub to fixed bottom banners
- Reduces layout thrashing, improves perceived performance
- Journal keeps collapsible (safe for infinite feed)
- [PHASE_1: Change 1/3]"

# Commit 2
git add lib/presentation/routine_dashboard/routine_dashboard.dart
git commit -m "feat(ads): Reduce native ads on Routine Dashboard (3→1)

- Remove morning & afternoon native ads
- Keep only general native ad (bottom of page)
- Reduces ad density, improves UX
- [PHASE_1: Change 2/3]"

# Commit 3
git add lib/core/constants/ad_constants.dart
git commit -m "feat(ads): Lower interstitial trigger frequency (2→1 action)

- Interstitials now show after 1 action instead of 2
- Increases show rate from ~15% to ~90%
- Risk: Monitor retention + CTR closely
- [PHASE_1: Change 3/3]"
```

---

## Monitoring After Deployment

First 7 days, track:
- Ad exposure % (target: 30-35%)
- D1 retention % (target: 5-10%, currently 0%)
- Interstitial show rate (target: 90%+)
- Interstitial CTR (target: 20%+)
- Crash rate (target: 0%)

If retention doesn't improve → might indicate ads aren't the only issue.

---

## Go/No-Go Criteria

✅ **GO if**: All changes deploy cleanly, app is stable, ad exposure trending down  
❌ **HOLD if**: Crashes detected, retention stays 0%, ad exposure increases

Ready to start Change 1?
