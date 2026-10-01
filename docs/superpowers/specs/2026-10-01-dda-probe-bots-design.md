# DDA + Probe bots → difficulty ML — Design

Approved 2026-10-01 (user: "ㄱㄱ 진행해", "봇 트래킹도 달아야 머신러닝이 되겠지").

## 1. Difficulty dial
Bots get one continuous `d ∈ [0,1]` mapped to all bot params (reaction delay, aim error, guard/dodge/tech/perfect
chances, aggression, special timing). Replaces slow/normal/busy presets (kept as named points on the dial).
Must be monotonic: higher d wins more (verified by bot-vs-bot sweeps).

## 2. Probe (first ~20–30 s vs a human)
Bot runs scripted probes: frontal attack (guard reaction), edge pressure (recovery/DI/tech), ranged pressure (dodge),
open punish window. Probe features → skill estimate → starting d. Later matches start from a persisted skill rating.

## 3. DDA (in match)
1 Hz: win-probability model (M2, exported to JSON, inferred in GDScript) → if player win prob leaves target band
(default 0.45–0.60) nudge d with max step, hysteresis, cooldown. Bot side only. Bots live outside src/sim (inputs only),
so replays/determinism are unaffected.

## 4. Bot tracking (required for ML)
Per bot slot: d start/mean/end, preset, params hash, probe stage results; `dda_adjusted` events (from, to, reason,
win_prob); bot decision log (sampled): intent (approach/retreat/attack/guard/dodge/special/item/getup), target slot,
distance, threat seen — stored raw in Supabase match_events (and synthetic CSV) and summarized per slot.
Experiment variant id (dda on/off) on matches for A/B.

## 5. ML (analysis/)
- Skill estimator: bot-vs-bot where the "player" bot has known d → regress d from probe features.
- Win prob (M2) retrained with d features; exported coefficients/trees → res://data/models/*.json.
- Later with real users: engagement-optimal difficulty (M1/M7 labels), contextual bandit.

## Verification
Monotonic d sweep, estimator MAE, DDA bot-vs-bot convergence into the target band, GUT + pytest.
