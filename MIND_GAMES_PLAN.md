# Dincharya Mind Games — Build Plan
_Date: 2026-07-24 · 39 Games · 4 Tiers_

---

## ARCHITECTURE

```
Tapasya Tab → Sub-tab [🧠 Mind]
└── mind_games_hub.dart
    ├── Daily Challenge Card (hero)
    ├── Sadhana Streak 🔥
    ├── Brain Age Score 🧠
    └── Game Grid → individual games
```

### File structure
```
lib/presentation/tapasya/mind_games/
├── mind_games_hub.dart
├── games/
│   ├── stroop_test_game.dart
│   ├── number_search_game.dart
│   ├── breath_counting_game.dart
│   ├── recall_your_day.dart
│   ├── speed_match_game.dart
│   ├── reaction_time_game.dart
│   ├── memory_match_game.dart
│   ├── simon_says_game.dart
│   ├── odd_one_out_game.dart
│   ├── quick_math_game.dart
│   ├── hand_gesture_switch.dart
│   ├── blind_fold_challenge.dart
│   └── (more...)
├── widgets/
│   ├── game_card_widget.dart
│   ├── score_display.dart
│   ├── brain_age_widget.dart
│   └── streak_display.dart
├── services/
│   └── mind_games_service.dart
└── models/
    └── mind_game_score.dart
```

### Supabase table
```sql
CREATE TABLE mind_game_scores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  game_type VARCHAR(50),
  score NUMERIC,
  accuracy NUMERIC,
  reaction_time_ms INTEGER,
  rounds_completed INTEGER,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## TIER 1 (P0) — BUILD FIRST — 12 GAMES

_From user's psychology research + high engagement_

---

### #1 · Stroop Color Test 🎨
| | |
|---|---|
| **Domain** | Selective Attention + Cognitive Inhibition (Stroop, 1935) |
| **Research** | "अलग-अलग कलर में अलग-अलग कलर के नाम लिखे होते है, word के बजाय कलर के नाम बोलना है" |
| **Gameplay** | Color word "RED" appears in BLUE ink. Tap the INK color, not the word. 20 words, 30 seconds. |
| **Scoring** | Accuracy %, reaction time, Stroop interference score |
| **Build** | 3 hrs |
| **Daily** | ✅ |

### #2 · Number Search 🔢
| | |
|---|---|
| **Domain** | Processing Speed + Visual Scanning |
| **Research** | "25 नंबरों की एक Table, 30 सेकंड के अंदर serial number से ढूंढना है" |
| **Gameplay** | 5×5 grid, numbers 1-25 random. Tap in ascending order as fast as possible. |
| **Scoring** | Completion time (seconds) |
| **Build** | 2 hrs |
| **Daily** | ✅ (new grid daily) |

### #3 · Breath Counting Focus 🧘
| | |
|---|---|
| **Domain** | Sustained Attention + Interoception |
| **Research** | "Breathlessness, Heart Health (दिल दिमाग), Practice Higher Self Control" |
| **Gameplay** | Breathe naturally. Tap each exhale. Count 1→10 silently. Mind wanders → tap "wandered" → restart. |
| **Scoring** | Rounds completed without wandering, longest streak |
| **Build** | 2 hrs |
| **Daily** | ✅ (3 rounds/day) |

### #4 · Recall Your Day 📝
| | |
|---|---|
| **Domain** | Episodic + Autobiographical Memory |
| **Research** | "Recall your day — अपने दिनभर की चीजों को याद करना" |
| **Gameplay** | Evening check-in. Prompts: "What did you eat for breakfast?", "Who did you talk to?", "What color was the first thing you saw?" |
| **Scoring** | Detail richness, consistency over days |
| **Build** | 1 hr |
| **Daily** | ✅ (new prompts daily) |

### #5 · Speed Match ⚡
| | |
|---|---|
| **Domain** | Processing Speed (Lumosity-style) |
| **Gameplay** | Two symbols appear. SAME or DIFFERENT? Tap fast! 20 rounds. |
| **Scoring** | Correct/min, reaction time |
| **Build** | 1 hr |

### #6 · Simple Reaction Time ⏱️
| | |
|---|---|
| **Domain** | Alertness + Neural Speed |
| **Gameplay** | Red screen → wait → GREEN → TAP! 5 trials. |
| **Scoring** | Average milliseconds |
| **Build** | 30 min |

### #7 · Memory Card Match 🃏
| | |
|---|---|
| **Domain** | Short-term Memory + Visual Paired-Associate |
| **Research** | "किसी 10 चीजों की Image लेकर list लेनी और याद करनी है" |
| **Gameplay** | Grid of face-down cards (6→8→10 pairs). Flip two, find matches. Theme: yoga poses, chakras, mudras. |
| **Scoring** | Moves count, completion time |
| **Build** | 4 hrs |
| **Daily** | ✅ |

### #8 · Simon Says 🟢🔴🔵🟡
| | |
|---|---|
| **Domain** | Working Memory + Sequential Pattern |
| **Gameplay** | 4 colored circles (chakra colors). App blinks sequence. User repeats. Grows: 3→5→7→9... |
| **Scoring** | Max sequence length |
| **Build** | 3 hrs |
| **Daily** | ✅ |

### #9 · Odd One Out 🔍
| | |
|---|---|
| **Domain** | Visual Discrimination |
| **Gameplay** | Grid of similar items. One is different. Find it! Increasing difficulty. |
| **Scoring** | Time per find, difficulty level |
| **Build** | 2 hrs |

### #10 · Quick Math 🔢
| | |
|---|---|
| **Domain** | Mental Arithmetic + Processing Speed |
| **Gameplay** | "23 + 47 = ?" Rapid problems. + → − → × → ÷ → mixed. |
| **Scoring** | Accuracy %, speed |
| **Build** | 1 hr |

### #11 · Hand Gesture Switch 🖐️
| | |
|---|---|
| **Domain** | Visuomotor + Bimanual Coordination |
| **Research** | "एक हाथ में मुट्ठी बांधना और दूसरे हाथ से V बनाना, Switch करते रहना" |
| **Gameplay** | Screen: left=✊ right=✌️. Timer beeps → SWITCH! Speed increases. On-screen rhythm tap mode. |
| **Scoring** | Switch accuracy, max speed level |
| **Build** | 5 hrs |
| **Daily** | ✅ |

### #12 · Blind Fold Challenge 👁️‍🗨️
| | |
|---|---|
| **Domain** | Sensory Integration + Spatial Memory |
| **Research** | "आँख बंद करके कोई छोटा-मोटा काम करना, Blind Fold exercises" |
| **Gameplay** | Audio-guided: "Close eyes. Tap the TOP-RIGHT corner 3 times." Or "Draw a circle with your finger." Touch accuracy scoring. |
| **Scoring** | Spatial accuracy, task completion |
| **Build** | 4 hrs |
| **Daily** | ✅ |

---

## TIER 2 (P1) — POPULAR + SCIENTIFIC — 13 GAMES

| # | Game | Domain | Build | Daily |
|---|---|---|---|---|
| 13 | **2048** | Strategic Planning | 6h | ✅ |
| 14 | **Sudoku** | Logic + Pattern | 5h | ✅ |
| 15 | **Wordle-Style Daily Word** | Deductive Reasoning | 3h | ✅ |
| 16 | **Block Puzzle (Tetris)** | Spatial Planning | 5h | — |
| 17 | **Flow Free / Pipe Connect** | Path Planning | 5h | ✅ |
| 18 | **Dual N-Back 🧪** | Working Memory (Gold Standard — Jaeggi 2008) | 5h | — |
| 19 | **Memory Matrix** | Visual Working Memory (Lumosity #1) | 3h | — |
| 20 | **Visual Search** | Selective Attention (Treisman 1980) | 2h | — |
| 21 | **Number Sequence** | Fluid Intelligence (WAIS-IV) | 2h | ✅ |
| 22 | **Word Scramble / Anagrams** | Verbal Reasoning | 2h | — |
| 23 | **Digit Span Reverse 🧪** | Verbal Working Memory | 1h | — |
| 24 | **Tile Match / Mahjong** | Visual Pattern | 5h | ✅ |
| 25 | **Daily Trivia / Quiz** | Knowledge + Memory | 2h | ✅ |

---

## TIER 3 (P2) — DINCHARYA EXCLUSIVE — 10 GAMES 🕉️

| # | Game | Domain | Build |
|---|---|---|---|
| 26 | **Mantra Recall 🕉️** | Auditory Working Memory | Low |
| 27 | **Asana Sequence 🕉️** | Visual Sequential Memory | Medium |
| 28 | **Mudra Speed 🕉️** | Processing Speed + Yoga Knowledge | Low |
| 29 | **Thought Watch 🕉️** | Inhibition + Meta-Awareness (Vipassana) | Very Low |
| 30 | **Mantra Japa Counter 🕉️** | Divided Attention (chant + count) | Very Low |
| 31 | **Color Filter (Trataka) 🕉️** | Selective Attention + Gaze Meditation | Medium |
| 32 | **Guna Balance 🕉️** | Logical Reasoning (Sattva/Rajas/Tamas) | Low |
| 33 | **Mandala Mirror 🕉️** | Visual-Spatial + Art Therapy | Medium |
| 34 | **Sanskrit Shloka Complete 🕉️** | Verbal Memory + Cultural | Low |
| 35 | **Aum Vibration Game 🕉️** | Sustained Attention + Biofeedback (mic) | Medium |

---

## TIER 4 (P3) — REAL-WORLD NEUROBIC — 7 GAMES

_Inspired by user's research — exercises that happen OFF the screen_

| # | Game | Research Source |
|---|---|---|
| 36 | **Non-Dominant Hand Challenge ✋** | "किसी भी काम को Right के बजाय Left से करना" |
| 37 | **5 Senses Imagination 👁️👂👃👅🤚** | "अपने पांचों इंद्रियों से कल्पना शक्ति बढ़ाना" |
| 38 | **Fist Clench Power ✊** | "पूरी ताकत से मुट्ठी बंद करके रखनी है, Right=encoding, Left=recall" |
| 39 | **Circle-Triangle Switch 🔺⭕** | "एक हाथ से Circle, दूसरे से Triangle बनाना और उलट-पलट करना" |
| 40 | **New Thing Daily 🌱** | "हर दिन कुछ न कुछ नया करना और सीखना" |
| 41 | **Stop Tech Challenge 📵** | "तकनीक पर निर्भर रहना बंद करें" |
| 42 | **Higher Self Control 🧘** | "उच्च आत्म नियंत्रण का अभ्यास करना" |

---

## YOUR RESEARCH → GAME MAPPING

| आपका Research Concept | Game # |
|---|---|
| Multi Colour Text / Colour Games | **#1 Stroop** |
| 25 Numbers Table / Serial Search | **#2 Number Search** |
| Breathlessness / Heart Health / Self Control | **#3 Breath Counting** |
| Recall your day | **#4 Recall Your Day** |
| 10 Images याद करना / Memory Power | **#7 Memory Card Match** |
| Hand Gestures / मुट्ठी-V Switch | **#11 Hand Gesture Switch** |
| Blind Fold / आँख बंद करके काम | **#12 Blind Fold Challenge** |
| Use Non-Dominant Hand | **#36 Non-Dominant Hand** |
| 5 Senses Imagination | **#37 5 Senses** |
| Clench Your Fist (Right/Left) | **#38 Fist Clench** |
| Circle + Triangle Switch | **#39 Circle-Triangle** |
| New Creative Daily | **#40 New Thing Daily** |
| Stop Tech Relying | **#41 Stop Tech** |
| Higher Self Control | **#42 Self Control** |
| Chess / Rubik's Cube | **#14 Sudoku, #13 2048** |

---

## ENGAGEMENT LAYER

| Feature | Description |
|---|---|
| **Daily Challenge** | 1 featured game on hero card. "Today: Stroop Test!" |
| **Sadhana Streak 🔥** | "Complete 1 mind game → maintain streak" with freeze mechanic |
| **Brain Age 🧠** | Lumosity LPI-style composite score from all games |
| **Leaderboard** | Weekly friends + global ranking per game |
| **XP → Dashboard** | Games earn XP → feed into main level system |
| **Badges** | "Stroop Master" (95%+), "Speed Demon" (<200ms), "Iron Fist" (60s clench) |

---

## BUILD ORDER

### 🔴 SPRINT 1 — NOW (6 games, ~10 hrs)
| # | Game | Time |
|---|---|---|
| 1 | Stroop Color Test 🎨 | 3h |
| 2 | Number Search 🔢 | 2h |
| 3 | Breath Counting Focus 🧘 | 2h |
| 4 | Recall Your Day 📝 | 1h |
| 5 | Speed Match ⚡ | 1h |
| 6 | Simple Reaction Time ⏱️ | 30m |

**+ Sprint 1 infra**: mind_games_hub.dart + mind_games_service.dart + Supabase table + Tapasya sub-tab restructure

### 🟠 SPRINT 2 (6 games, ~19 hrs)
| # | Game | Time |
|---|---|---|
| 7 | Memory Card Match 🃏 | 4h |
| 8 | Simon Says 🟢🔴 | 3h |
| 9 | Odd One Out 🔍 | 2h |
| 10 | Quick Math 🔢 | 1h |
| 11 | Hand Gesture Switch 🖐️ | 5h |
| 12 | Blind Fold Challenge 👁️‍🗨️ | 4h |

### 🟡 SPRINT 3 (13 games, ~46 hrs)
Games #13-25: Popular + Scientific — 2048, Sudoku, Wordle, Block Puzzle, Flow Free, Dual N-Back, Memory Matrix, Visual Search, Number Sequence, Word Scramble, Digit Span, Tile Match, Daily Trivia

### 🟢 SPRINT 4 (10 games, ~25 hrs)
Games #26-35: Dincharya Exclusive — Mantra Recall, Asana Sequence, Mudra Speed, Thought Watch, Mantra Japa, Trataka, Guna Balance, Mandala Mirror, Sanskrit Shloka, Aum Vibration

### 🔵 SPRINT 5 (7 games, ~10 hrs)
Games #36-42: Real-World Neurobic Challenges (simple UI, mostly content/copy)

---

## QUICK STATS

| | |
|---|---|
| Total games | **42** |
| From YOUR research directly | **14** |
| Very Low build (<2 hrs) | 12 |
| Low build (2-5 hrs) | 16 |
| Medium build (1-3 days) | 14 |
| Daily challenge ready | 25 |
| Sprint 1 build time | ~10 hrs |

---

**READY TO BUILD. Sprint 1 → Stroop Color Test first.**
