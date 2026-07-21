# Phase 1 Safety & Rollback Plan

## ⚠️ CRITICAL: Live App on Play Store

**Status**: Production app, 110 active users, -0% D1 retention  
**Change Type**: Non-breaking, low-risk UX improvements  
**Rollback Time**: 30 min (git revert + rebuild)  
**Testing**: All changes tested in preview before commit

---

## Implementation Checklist

### Change 1: Remove Collapsible Banners (3 screens)
**Screens**: Routine Dashboard, Guided Hub, Tapasya Hub  
**Risk**: LOW (just removes banner expansion, keeps fixed bottom banner)  
**Files to modify**: 
- `lib/presentation/routine_dashboard/routine_dashboard.dart`
- `lib/presentation/guided_sessions_hub/guided_sessions_hub.dart`
- `lib/presentation/tapasya/tapasya_hub.dart`
- `lib/widgets/ads/banner_ad_widget.dart` (if needed)

**Rollback**: `git diff` these 3 files, revert individual lines if needed

---

### Change 2: Reduce Native Ads on Routine (3→1)
**Current**: 3 natives (morning, afternoon, general)  
**Target**: 1 native (general only, at bottom)  
**Risk**: LOW (just commenting out 2 placements)  
**File**: `lib/presentation/routine_dashboard/routine_dashboard.dart`

**Rollback**: Uncomment the 2 removed native ad widgets

---

### Change 3: Lower Interstitial Frequency (2→1 action)
**Current**: Show after 2 user actions  
**Target**: Show after 1 action  
**Risk**: MEDIUM (will increase ad frequency, monitor CTR)  
**File**: `lib/services/ads_service.dart`

**Rollback**: Revert `actionCount` threshold back to 2

---

## Pre-Flight Checks

- [ ] Create feature branch: `feature/ads-phase1-uiux-fixes`
- [ ] Read EACH file before editing
- [ ] Make isolated, single-purpose edits
- [ ] Test in preview after EACH change
- [ ] Commit separately (1 commit per change)
- [ ] Document commit messages clearly

---

## Testing in Preview

For each change, verify:
- [ ] App loads without errors
- [ ] No layout shifts or blank screens
- [ ] Banners/natives render correctly
- [ ] Scroll performance is smooth
- [ ] No console errors

---

## Commit Messages (for rollback reference)

```
feat(ads): Remove collapsible banners from Routine Dashboard
- Switch from expandable to fixed bottom banner
- Fixes layout thrashing, improves perceived performance
- Risk: LOW

feat(ads): Reduce native ad count on Routine Dashboard (3→1)
- Keep only general native at bottom
- Comment out morning/afternoon natives
- Reduces ad density, improves UX
- Risk: LOW

feat(ads): Lower interstitial trigger threshold (2→1 action)
- Show interstitial after first action instead of second
- Increases ad frequency slightly, test CTR impact
- Risk: MEDIUM, monitor metrics

```

---

## Rollback Instructions

If anything breaks:

```bash
# Option 1: Rollback entire Phase 1
git revert HEAD~2..HEAD  # Revert 3 commits

# Option 2: Rollback single change
git revert <commit-hash>

# Option 3: Force push (if not merged to main yet)
git reset --hard origin/main

# Then rebuild and test
flutter pub get
flutter run
```

---

## Post-Deployment Monitoring (First 7 Days)

Track these metrics in AdMob:
- [ ] Ad exposure % (target: 30-35%, currently 48.81%)
- [ ] D1 retention % (target: 5-10%, currently 0%)
- [ ] eCPM (should stay stable or improve)
- [ ] Match rate (target: 50%+)
- [ ] Crash rate (must stay 0%)

If any metric degrades:
- **Ad exposure increases** → Rollback interstitial frequency
- **Retention stays 0%** → Rollback collapsible removal, try fixed banner instead
- **eCPM drops >20%** → Rollback native ad reduction
- **Crashes detected** → Immediate rollback + investigate

---

## Go/No-Go Decision Criteria

**GO to next phase if:**
- ✅ All 3 changes deployed without errors
- ✅ App is stable (no crashes)
- ✅ Ad exposure is trending down (toward 35%)
- ✅ No user complaints in week 1

**HOLD if:**
- ❌ Any crashes or critical bugs
- ❌ Ad exposure increases instead of decreases
- ❌ D1 retention stays 0% (might mean ads aren't the only issue)

---

## Next: Code Review

Ready for change #1 review?
