# DinCharya Ads System — Research-Backed Strategy 2025

**Goal**: Transform the ads system from a retention killer (0% D1, 48.81% exposure) into a high-revenue, user-friendly monetization engine.

**Research Date**: July 2025 | **Data Source**: Industry benchmarks, AdMob docs, successful app case studies

---

## Part 1: Industry Benchmarks & What We Learned

### eCPM Rankings (Highest Revenue per 1000 impressions)
1. **Offerwalls**: $400–$530 (not applicable for wellness)
2. **Rewarded video**: $15–$25 (best for wellness apps)
3. **Rewarded interstitial**: $12–$18 (NEW, no opt-in required)
4. **Interstitial**: $5–$15 (high but risky for retention)
5. **Native ads**: $2–$8 (good CTR, seamless)
6. **App open ads**: $3–$7 (highest for resume, 10–20% lower than interstitial)
7. **Banners**: $0.50–$2 (passive revenue, safe)

**Your current mix is weak**: You're showing mostly banners ($0.50–$2) with poor frequency strategy. Switching to rewarded + app open will 3x revenue.

### Retention vs. Revenue Trade-off

| Ad Exposure | D1 Retention | D7 Retention | D30 Retention | Revenue Impact |
|-------------|-------------|-------------|---------------|----------------|
| <20% | 50–60% | 25–35% | 10–15% | Low |
| 20–30% | 35–45% | 15–25% | 5–10% | Medium |
| 30–50% | 10–20% | 3–8% | <3% | High |
| >50% | <5% | <2% | <1% | Unsustainable |

**Your current 48.81% = doom**. You're in the "users uninstall" zone.

### Frequency Capping Best Practices
- **Interstitials**: 2–4 per session, 60–90 sec interval
- **Rewarded**: No hard cap (users opt-in, unlimited)
- **App open**: 1 per resume (30-min cooldown default)
- **Banners**: Always on, but fixed (no expand/collapse)
- **Native**: 1–2 per feed (not stacked)

**Your issue**: You have 2-action trigger for interstitials, but users average 1m 47s (not enough for 2 actions in 1 session).

### Successful App Models
- **Calm/Headspace**: Subscription-first (90% revenue), ads for free users only, <20% ad exposure
- **Duolingo**: Freemium + streaks, 41% D-to-M ratio, light ads, focuses on habit loops
- **MyFitnessPal**: Freemium + ads + premium, 20–30% ad exposure on free tier
- **Strava**: <10% revenue from ads (focuses on features for premium)

**Key insight**: Top apps focus on *retention first*, then monetize strategically.

### Meditation/Fitness App Segment
- **Day 30 retention baseline**: ~5% (industry standard horror)
- **Successful apps hit**: 10–15% D30 (requires strong habit loops)
- **Annual subscription**: $60–$120 LTV for median, $150–$300 for top performers
- **Premium removes all ads**: Critical conversion driver
- **Trial conversion**: 5–15% (with strong Day 0–7 engagement)

---

## Part 2: DinCharya Current State vs. Industry Best

### Current Issues
| Issue | Current | Industry Best | Impact |
|-------|---------|---------------|--------|
| Ad exposure | 48.81% | 20–30% | **Retention 0% → should be 35–45%** |
| Collapsible banners | 3 screens | Should be 0 | **Layout shift = accidental clicks, UX broken** |
| Native ad density | 3 per Routine Dashboard | 1 per screen | **Feels like ad app, not real app** |
| Interstitial frequency | 2 actions | 1 action per session | **Should show after task/session complete** |
| Rewarded ads | 9 slots, 1% use | 3–4 slots, opt-in | **Underutilized, should be highest revenue** |
| App open ads | Good (30-min cooldown) | ✅ Keep this | **Best performer at $0.05/show** |
| Premium tier | Free trial exists | Not properly gated | **Need to remove ads for paid users** |
| Mediation | Basic setup | Hybrid bidding + waterfall | **Missing 10–15% potential revenue** |

---

## Part 3: Proposed New Ad Strategy

### Phase 1 (Week 1): Emergency UX Fixes — Retention Rescue

**Goal**: Stop the bleeding. Move from 0% D1 retention to 10–15% within 30 days.

1. **Remove collapsible banners** (3 screens)
   - Routine Dashboard, Guided Hub, Tapasya Hub
   - Replace with fixed bottom banner (no layout shift)
   - Effect: Reduces accidental clicks, improves perceived quality
   - Timeline: 30 min per screen

2. **Reduce native ad density** on Routine Dashboard
   - From: Morning native + afternoon native + general native (3 total) + 1 banner = 4 ads on 1 screen
   - To: 1 native ad (only morning section) OR remove entirely for A/B test
   - Effect: Ad exposure drops from 48.81% → 30–35%
   - Timeline: 20 min

3. **Change interstitial trigger** from 2 actions → 1 core action
   - Core actions: Task marked complete, Session recorded, Journal saved
   - Trigger after first action in session (not second)
   - Add 120-second cooldown between interstitials (vs. current 2-action delay)
   - Effect: Ads show in short sessions, revenue lifts
   - Timeline: 15 min

4. **Test with 10% of users** (Firebase Remote Config)
   - Split: 90% old system, 10% new system
   - Measure: D1, D7 retention + revenue for both groups
   - Duration: 7 days
   - Timeline: 1 day to implement Remote Config gates

**Expected outcome**: D1 retention climbs from 0% → 5–10%, ad exposure feels natural, users don't bounce immediately.

---

### Phase 2 (Week 2–3): Revenue Optimization — Switch to High-eCPM Formats

**Goal**: Replace low-eCPM banners/natives with rewarded videos and rewarded interstitials (3x revenue).

1. **Replace rewarded slots** (currently underused 9 slots with 1% show rate)
   - Current: Guided sessions only, behind paywall, low adoption
   - New: Rewarded interstitial at 3 strategic points:
     - After routine completion (early morning)
     - After guided session (end of practice)
     - After journal entry (evening reflection)
   - No opt-in required (intro screen shows reward, user can skip)
   - Reward: +5 minutes guided session unlock, or +1 badge toward Tapasya achievement
   - eCPM uplift: From $0.50–$2 (banner) → $12–$18 (rewarded interstitial)
   - Timeline: 1 hour per placement

2. **Restructure banner placements** (consolidate from 10 → 3)
   - Keep: Profile, History, Help Center (low-engagement screens where banners won't hurt retention)
   - Remove: Journal, Media Player, Tapasya (core engagement screens)
   - Rationale: Protect high-engagement content, monetize browsing screens
   - Timeline: 30 min

3. **Native ad overhaul**
   - Remove 2 native ads from Routine Dashboard
   - Keep 1 native (morning section) as test
   - Add 2 new native placements in lower-urgency screens:
     - History feed (looking back is passive)
     - Profile achievements (browsing, not doing)
   - Timeline: 1 hour

4. **App open ad optimization** (already good, just tweak)
   - Current: 30-min cooldown, 20% show rate ($0.05/show)
   - New: Keep as-is, but ensure mediation is enabled
   - Revenue: Likely $0.10–$0.20/show with proper mediation setup
   - Timeline: 30 min

**Expected outcome**: Revenue 2–3x uplift. Ad exposure drops to 25–30%. Retention starts improving.

---

### Phase 3 (Week 4): Premium Tier Gating + Subscription Push

**Goal**: Implement proper ads-removal for premium subscribers, drive conversions.

1. **Add premium tier flag checks**
   - All ad placements check: `if (user.isPremium) return null;`
   - Rationale: Premium users don't see ads = conversion incentive
   - Timeline: 2 hours (global service update)

2. **Create paywall triggers**
   - After 2–3 ads viewed in session, show paywall: "Remove ads forever + unlock premium"
   - A/B test: 30% of users get paywall after 2 ads, 70% after 3
   - Offer: Monthly ($2.99), Annual ($19.99, save 44%), Lifetime ($49.99)
   - Timeline: 2 hours

3. **Measure conversion funnel**
   - Track: Paywall impressions → conversions → D7 retention (premium vs. free)
   - Expected: 2–5% conversion (industry avg)
   - Timeline: Ongoing

**Expected outcome**: New revenue stream. Premium users stay (no ad fatigue). Free users face clearer monetization path.

---

### Phase 4 (Ongoing): Analytics & Optimization Loop

**Metrics to track (Firebase + AdMob)**:

1. **Retention**
   - D1, D7, D30 (primary signal)
   - Target: D1 = 10–15%, D7 = 5–8%, D30 = 2–3%

2. **Ad Revenue**
   - ARPU (average revenue per user): Target $0.05–$0.15/day
   - ARPPU (premium): Target $2–$5/month
   - eCPM by format (track separately)

3. **Ad Engagement**
   - Impressions, clicks, conversion rate by format
   - Native vs. rewarded vs. interstitial
   - Frequency cap violations (how many users see >4 ads/session)

4. **User Quality**
   - Session length, DAU/MAU ratio
   - Core engagement (task completion, session count)
   - Churn by segment (free vs. trial vs. premium)

5. **A/B Tests**
   - Run at least 2–3 concurrent tests
   - Compare old vs. new banner strategy
   - Test frequency caps (2 vs. 3 vs. 4 ads/session)
   - Paywall timing (after 2 vs. 3 ads)

---

## Part 5: Implementation Roadmap

| Week | Task | Owner | Status |
|------|------|-------|--------|
| 1 | Remove collapsible banners (3 screens) | Eng | To-do |
| 1 | Reduce native ad density | Eng | To-do |
| 1 | Change interstitial trigger (2 → 1 action) | Eng | To-do |
| 1 | Launch A/B test (10% users) | Data + Eng | To-do |
| 2 | Rewarded interstitial at 3 placements | Eng | To-do |
| 2 | Consolidate banners (10 → 3) | Eng | To-do |
| 2 | Native ad overhaul | Eng | To-do |
| 2 | Mediation optimization review | Eng | To-do |
| 3 | Premium tier ad-removal checks | Eng | To-do |
| 3 | Paywall trigger implementation | Eng | To-do |
| 4+ | Analytics dashboard setup | Data | To-do |
| 4+ | Weekly A/B test review | Data + Eng | To-do |

---

## Part 6: Success Metrics (30-Day Goals)

| Metric | Current | 30-Day Target | 90-Day Target |
|--------|---------|---------------|---------------|
| D1 Retention | 0% | 8–12% | 15–20% |
| D7 Retention | Unknown | 4–6% | 8–10% |
| Ad Exposure | 48.81% | 25–30% | 20–25% |
| ARPU (ads) | $0.002/day | $0.05–$0.10/day | $0.10–$0.15/day |
| Premium conversion | Unknown | 1–2% | 3–5% |
| Revenue | $0.74/month | $5–$10/month | $20–$50/month |
| Active users | 110 | 120–140 | 180–250 |

---

## Part 7: Competitive Reference

**DinCharya positioning**:
- **Like Calm/Headspace**: Meditation + guided sessions + community
- **Like Strava**: Social tapasya challenges + streaks + badges
- **Like Duolingo**: Gamified habits + daily routines

**Monetization model**: Hybrid (ads + premium subscription), leaning on premium for revenue.

**Revenue sources** (target distribution):
- 40% rewarded video + rewarded interstitial
- 20% premium subscriptions (ad-free)
- 20% app open ads
- 15% native ads (contextual, high-quality)
- 5% banners

**Current distribution** (wrong):
- 80% banners + native (low eCPM)
- 20% rewarded (underutilized)

---

## Next Steps

1. **Approve this strategy** (you are here)
2. **Implement Phase 1** (week 1, FRI) — Emergency UX fixes
3. **Launch A/B test** (week 1, MON) — 10% users on new system
4. **Measure results** (week 2–3) — D1/D7 retention + revenue
5. **Implement Phase 2** (week 2–3) — Rewarded interstitial rollout
6. **Scale Phase 3** (week 4) — Premium tier gating
7. **Iterate** based on data

---

## Questions Before We Start?

1. Can we gate ads for premium users (requires checking subscription status)?
2. Do you have Firebase Remote Config enabled for A/B testing?
3. What's your current premium subscription setup (In-app Purchase vs. Supabase)?
4. Should we prioritize retention or revenue first (I recommend retention = 3-month play)?
