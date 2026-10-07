# analysis/ — analytics → ML workspace (A9)

Python (≥ 3.11, uv) workspace for the models in `docs/analytics-strategy.md` §2:
**M2 win probability**, **M5 balance**, **M1 early churn** (pipeline only until real users exist).
Design: `docs/superpowers/specs/2026-10-01-analytics-ml-design.md` (Part 2).

Stack: pandas + pyarrow, scikit-learn (`HistGradientBoostingClassifier`, `LogisticRegression`),
matplotlib, pytest, ruff. Godot ignores this folder (`.gdignore`).

## Run

```bash
cd analysis
uv sync                                    # creates .venv
uv run pytest -q                           # tests on tests/fixtures/tiny (8 matches)
uv run python -m brawl_analysis report --data data/synthetic --out reports
```

## 1. Synthetic data (bot-vs-bot, headless Godot)

`scripts/gen_dataset.gd` plays bot-only matches with the shipped sim config and feeds every tick
through the game's own telemetry (`TelemetrySetup` → `MatchTelemetry` → `RawRows` / `SlotStats` /
`MatchFeatures`), so the CSVs have the Supabase table shapes. Per match (seed = `--seed + i`):
rule (stock 50 % / team 25 % / timed 25 %), arena (6, `ArenaCatalog.ids()`), player count (stock 2–4, timed 2–4,
team 4), a character per slot and a bot preset per slot (`slow` / `normal` / `busy` + swing-range
jitter, written to `match_players.bot_difficulty` and `bot_params_hash`). Only the bots' own
GameConfig copies change; the World runs the shipped config. Rows are tagged
`platform = "synthetic"`, ids `5e7d0000-0000-4000-8000-<index>`. ~1.2 s per match per core.

The dataset behind the committed reports (600 matches, ~2 min on 6 cores, ~80 MB, gitignored):

```bash
# from the repo root; 6 shards in parallel, the loader concatenates sub-directories
for s in 0 1 2 3 4 5; do
  godot --headless --path . -s res://scripts/gen_dataset.gd -- \
    --matches=100 --seed=1 --first=$((s*100)) --out-dir=analysis/data/synthetic/shard$s &
done; wait
```

Files per directory: `matches.csv`, `match_players.csv`, `match_events.csv` (incl. 0.5 s `pos`
rows) and `timeline.csv` — 1 Hz, one row per fighter: `match_id, tick, t, slot, damage, stocks,
x, y, z, edge_dist, gauge, state, holding_item, item_kind, on_ground, guard_hp_ratio, team,
score`. The outcome is **not** in the timeline; it is joined from `match_players.result`.
`edge_dist` = arena view radius − distance from centre (approximate on non-round arenas).
Matches still running after 6 minutes end as `abandoned` and are dropped (4 of 600).
`matches.result` is meaningless for bot-only rows (no local slot); use `match_players.result`.

## 1b. DDA models (difficulty dial, probe skill estimator, win probability with d)

Since event schema 9 every synthetic match has slot 0 as the "player" (a dial bot with a known
`bot_d_start`) that the other bots probe; `timeline.bot_d` holds each slot's dial value.

```bash
# from the repo root: training data with DDA off (bots keep their sampled d), no models needed
for s in 0 1 2 3 4 5 6 7; do
  godot --headless --path . -s res://scripts/gen_dataset.gd -- --matches=100 --seed=1 \
    --first=$((s*100)) --variant=off --models=none --out-dir=analysis/data/dda_train/shard$s &
done; wait
scripts/dda_sweep.sh 320                  # dial monotonicity -> analysis/reports/dda_sweep.csv
cd analysis && uv run python -m brawl_analysis export-models --data data/dda_train   # -> ../data/models/*.json + reports/dda.md
cd .. && scripts/dda_converge.sh 100       # DDA convergence (uses the exported models)
cd analysis && uv run python -m brawl_analysis export-models --data data/dda_train   # re-render dda.md with §4
```

`export-models` writes `data/models/skill_estimator.json` (Ridge, probe features -> d) and
`data/models/win_prob.json` (logistic over `DdaFeatures`) with fixtures the GUT test
`test_dda_controller` replays in GDScript. Results: `reports/dda.md`.

## 2. Real data (Supabase export)

```bash
export SUPABASE_URL=https://<project>.supabase.co
export SUPABASE_SERVICE_ROLE_KEY=...      # shell or untracked analysis/.env — NEVER commit
uv sync --extra export
uv run python -m brawl_analysis export --out data/supabase [--with-inputs]
uv run python -m brawl_analysis report --data data/supabase --out reports/supabase
```

RLS gives a user key only its own matches, so a full export needs the **service role** key (or
use the Supabase SQL editor → CSV with the same file names). Tables and columns read:

| file | columns used |
|---|---|
| `matches.csv` | `id, user_id, session_id, started_at, mode, rule, arena, player_count, duration_ticks, platform` (0001/0002/0004) |
| `match_players.csv` | `match_id, slot, controller, is_bot, character, style, input_device, result, falls, damage_taken, bot_difficulty, team, score` + A8 feature columns |
| `match_events.csv` | `match_id, tick, type, actor_slot, target_slot, payload` (jsonb as JSON text) |
| `match_inputs.csv` | optional L0 replay log (`--with-inputs`) for the future replay timeline extractor |

Filter `platform != 'synthetic'` if both ever share a directory. Real exports have no
`timeline.csv` yet, so the win-probability report is skipped until a replay extractor exists
(replay `match_inputs` like `ReplayVerifier` and sample with `scripts/dataset/timeline_sampler.gd`).

## 3. Code map

| module | role |
|---|---|
| `io.py` | load a dataset dir (CSV/parquet, shards concatenated), normalise rule / bools / payload JSON |
| `features.py` | `player_table` (slot rows + chance share), `timeline_table` (state + side/foe features), `timeline_matrix` |
| `models/win_prob.py` | M2: HGB vs prior and logistic baselines, 5-fold GroupKFold by match, calibration, permutation importance |
| `models/balance.py` | M5: Wilson win rates vs chance, logistic regression with match-bootstrap CIs, ring-out cause tables |
| `models/churn.py` | M1: first-session user table from a Supabase export + model; generated stub otherwise |
| `report.py`, `charts.py`, `markdown.py` | `reports/*.md` + PNGs |
| `export.py` | PostgREST export (env credentials only) |

## 4. Findings on the synthetic set (2026-10-01, 600 matches, 596 finished)

Read every number as **"how the bots play"**: no human data exists yet.

- **M2 win probability** (124 k timeline rows, out-of-fold): HGB log-loss 0.443 / AUC 0.860 /
  Brier 0.147 vs logistic on stock/damage/score diff 0.461 / 0.849 / 0.152 and the 1/n prior
  0.639 / 0.626. The boosted model adds little over the diffs; `score_diff` and `stock_diff`
  dominate importance. AUC rises from 0.70 (first 15 s) to 0.94 (60–120 s). Slightly
  over-confident above 0.7 (predicted 0.85 → observed 0.80).
  Leakage check: features are tick-local; duration, final counters and later rows are excluded,
  and CV groups by match. Rows after a fighter is eliminated (stocks 0) are easy and inflate
  late-phase AUC.
- **M5 balance**: **mage (ranged)** wins clearly above chance: +9.7 pp overall, OR 1.64
  [1.24, 2.17] vs barbarian, controlling for rule, player count, arena and bot preset. In 1v1
  stock the gap is +6 pp but within noise (n = 75). Rogue trends low (−5 pp, CI crosses 1).
  Arena main effects are ~1 by construction (every match has winners); arenas matter through
  ring-outs: log_bridge 80 % water, lakeside 8 % lake + 8 % gimmick, the mushroom bounce almost
  never kills (2 of 1,487). 5 % of all ring-outs are self-destructs.
- **Bot presets**: `busy` (more swings, longer guards) **loses** (32 % vs 49 % for `slow`), so
  more aggression is not "harder". This matters for bot difficulty design.
- **M1 churn**: stub only (AUC 0.63 on generated users). Needs real users.

## 5. Needs real user data

M1 churn (labels are real returns), every human-behaviour conclusion in M5 (bots do not play
characters like people), M2 calibration on human matches (needs the replay timeline
extractor), M3 rating / M4 styles / M6 behaviour cloning (out of scope here).
