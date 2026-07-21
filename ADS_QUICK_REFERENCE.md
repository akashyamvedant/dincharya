# DinCharya Ads System — Quick Reference Card

## 🚨 Current Crisis
```
D1 Retention:  0.00% ❌ (should be 10-15%)
Ad Exposure:   48.81% ❌ (should be 20-30%)
Monthly Rev:   $0.74 ❌ (down 85%)
Active Users:  110 ❌ (down 24 this month)

Reason: Too many ads in wrong places, poor UX = immediate uninstall
```

---

## 💡 The Fix (4 Phases)

### Phase 1: UX Fixes (Week 1) — Stop Bleeding
**Do these 4 things:**
1. Remove collapsible banners (3 screens) → No more layout shift
2. Reduce natives from 3 to 1 on Routine Dashboard → Less ad overload
3. Change interstitial trigger 2→1 action → Ads show in short sessions
4. A/B test with 10% users → Validate before rollout

**Expected impact**: D1 retention 0% → 5–10%, ad exposure 48.81% → 30–35%
**Time**: 4–5 hours
**Revenue change**: Minimal (focus on retention recovery)

---

### Phase 2: Revenue Boost (Week 2–3) — 3x Revenue
**Do these 3 things:**
1. Add rewarded interstitial ads at 3 moments
   - After task completion (eCPM $12–$18 vs banner $0.50–$2 = 10x better)
   - After guided session
   - After journal entry
2. Consolidate banners 10 → 3 (higher eCPM per ad)
3. Move native ads to passive screens only (not core tasks)

**Expected impact**: Revenue $0.74 → $2–$4/month
**Time**: 6–8 hours
**User impact**: Neutral to positive (rewarded ads feel like earned rewards)

---

### Phase 3: Premium Tier (Week 4) — New Revenue Stream
**Do these 3 things:**
1. Remove all ads for premium subscribers
2. Show paywall after 2–3 ads viewed ("Remove ads forever")
3. Offer tiers: Monthly $2.99, Annual $19.99 (44% off), Lifetime $49.99

**Expected impact**: +$200–$500/month if 10–20 users convert
**Conversion benchmark**: 2–5% of free users
**Time**: 4–6 hours

---

### Phase 4: Optimize (Week 4+) — Stay Sharp
**Do these 2 things:**
1. Create analytics dashboard (D1/D7/D30 retention, ARPU, paywall conversion)
2. Run A/B tests weekly (frequency caps, paywall timing, etc.)

**Expected impact**: Continuous 5–10% improvement each week
**Time**: 3–4 hours setup, then ongoing monitoring

---

## 📊 Success Metrics

| Metric | Current | Week 1 | Week 3 | Week 4 |
|--------|---------|--------|--------|--------|
| D1 Retention | 0% | 5–10% | 8–12% | 10–15% |
| Ad Exposure | 48.81% | 30–35% | 25–30% | 25–30% |
| ARPU (ads) | $0.002 | $0.01 | $0.05 | $0.08 |
| Premium ARPU | $0 | $0 | $0 | $0.50+ |
| **Monthly Revenue** | **$0.74** | **$1–$2** | **$5–$10** | **$15–$30** |

---

## 🎯 Ad Format eCPM Ranking (Revenue per 1000 impressions)

```
Rewarded Video        $15–$25  ✅ HIGH — Use this
Rewarded Interstitial $12–$18  ✅ HIGH — Use this (new)
Interstitial          $5–$15   ⚠️  RISKY — Too aggressive
Native Ads            $2–$8    ✅ GOOD — Use selectively
App Open Ads          $3–$7    ✅ GOOD — Best for your app
Banners               $0.50–$2 ⚠️  WEAK — Passive revenue only

Current mix (wrong):  80% banners + natives
Target mix (right):   40% rewarded, 30% app open, 20% native, 10% banners
```

---

## 🚫 Don't Do This (Industry Mistakes)

| ❌ Mistake | Impact | Why We're Fixing |
|-----------|--------|------------------|
| Collapsible banners on task screens | Layout shift → accidental clicks | Removed (Phase 1) |
| 3+ native ads per screen | Feels like ad app | Reduced to 1 (Phase 1) |
| Ad frequency >4/session | Users uninstall | Set to 1–3/session (Phase 1–2) |
| Ads to premium users | Kills conversion incentive | Gated with isPremium check (Phase 3) |
| No frequency capping | Ad fatigue | Added 120-sec cooldown (Phase 1) |

---

## ✅ Do This (Best Practices)

| ✅ Best Practice | Impact | Timeline |
|-----------------|--------|----------|
| Rewarded interstitials (opt-in reward) | Highest eCPM, high CTR | Phase 2 |
| Fixed banners (no expand/collapse) | Better UX, fewer accidental clicks | Phase 1 |
| Ads only after core action | Ad feels earned | Phase 1–2 |
| Premium removes all ads | Drives conversion | Phase 3 |
| Frequency cap 60–90 sec | No ad fatigue | Phase 1 |
| A/B test via Remote Config | Data-driven optimization | Phase 1–4 |

---

## 📁 Files Changed (By Phase)

**Phase 1** (5 files):
- `lib/widgets/ads/banner_ad_widget.dart`
- `lib/presentation/routine_dashboard/routine_dashboard.dart`
- `lib/presentation/guided_sessions_hub/guided_sessions_hub.dart`
- `lib/presentation/tapasya/tapasya_hub.dart`
- `lib/services/ads_service.dart`

**Phase 2** (7 files):
- `lib/services/ads_service.dart` (add rewarded interstitial)
- `lib/presentation/routine_dashboard/routine_dashboard.dart`
- `lib/presentation/media_player/media_player_mobile.dart`
- `lib/presentation/journal_mood_tracker/journal_mood_tracker.dart`
- `lib/presentation/profile/profile_screen.dart`
- `lib/presentation/history/history_screen.dart`
- Remove banners from 5 more screens

**Phase 3** (4 files):
- `lib/services/user_service.dart`
- `lib/services/ads_service.dart`
- `lib/presentation/paywall/paywall_screen.dart`
- `lib/services/payment_service.dart`

**Phase 4** (2 files):
- `lib/services/analytics_service.dart`
- Admin dashboard

---

## 📞 Questions?

1. **Why Phase 1 first?** 
   - User retention at 0% = app is broken. Fix UX before optimizing revenue.

2. **Why rewarded interstitials?**
   - $12–$18 eCPM (10x banners), users feel rewarded (not annoyed), no opt-in friction.

3. **What if retention doesn't improve?**
   - A/B test with 10% users validates changes before rollout to 100%.

4. **What's the premium conversion rate?**
   - Industry benchmark: 2–5% of free users. We'll measure and optimize paywall.

5. **Can I skip Phase 2 and do only Phase 3 (premium)?**
   - No — Phase 1 is required (fix retention first). Phase 2 & 3 can overlap.

---

## 🎬 Next Steps

**Right now**:
- [ ] Approve this plan
- [ ] Share with engineering team
- [ ] Get questions answered (see questions above)

**Today** (if approved):
- [ ] Start Phase 1 development (4–5 hours)
- [ ] Create 3 rewarded interstitial ad units in AdMob

**Tomorrow** (if approved):
- [ ] A/B test live with 10% of users
- [ ] Monitor D1 retention for 7 days

**Week 2**:
- [ ] Decision: Results good → rollout Phase 2
- [ ] Start Phase 2 development (6–8 hours)

**Week 4**:
- [ ] Phase 3 (premium gating) live

**Week 5+**:
- [ ] Analytics dashboard live
- [ ] Continuous A/B testing

---

## 📚 Full Documentation

- `ADS_IMPLEMENTATION_PLAN.md` — Step-by-step code changes (615 lines)
- `ADS_STRATEGY_RESEARCH_2025.md` — Research + industry data (277 lines)
- `ADS_SYSTEM_ANALYSIS.md` — Current state breakdown (314 lines)
- `ADS_SYSTEM_EXECUTIVE_SUMMARY.md` — For stakeholders (178 lines)

---

## 🎯 Success = 4 Weeks, $0.74 → $15–$30/month

**Revenue multiplier: 20–40x** if all phases executed well.
