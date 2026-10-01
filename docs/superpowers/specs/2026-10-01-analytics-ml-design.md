# Analytics → ML prediction — Design

Approved 2026-10-01 (user: "고고 빨리 진행해"). Builds on `docs/analytics-strategy.md` (models M1–M8, A9 step).

## Goal
Log every gameplay signal needed for analysis and train first prediction models end to end, even before real users exist.

## Part 1 — Game-side logging (extends telemetry, render/app only, sim untouched)
- Combat-depth counters per slot (dodges roll/air, guard breaks suffered/caused, perfect guards, knockdowns, techs, getup kinds) → `match_ended.players[]` + `match_players`.
- Skill signals: reaction ticks (opponent attack start → guard/dodge press), defensive choice outcome (guard/roll/perfect success), tech attempts vs successes, DI used (stick perpendicular at launch) and survived-launch flag.
- Danger context: choices taken at edge (outside 80% radius) and at high damage (≥100%).
- Modes: team assists (teammate ring-out within N s of own hit), mode select funnel (focused vs chosen).
- Frustration: last-context on abandon, loss streak, retry latency (fill gaps only).
- DB: columns added to unapplied `0004_match_rules.sql` (idempotent). `event_schema_version` bump, EventCatalog + tracking-plan updated.

## Part 2 — `analysis/` Python workspace
- Stack: Python + **pandas** (user choice), scikit-learn `HistGradientBoosting*`, matplotlib; managed per `data-science-python-stack` (uv, pyproject).
- Data sources: (a) Supabase export (matches, match_players, match_events, match_inputs); (b) **synthetic**: headless Godot script runs N bot-vs-bot matches across characters/arenas/modes and writes the same tables as CSV/parquet.
- Replay feature extractor: headless Godot replays inputs with the real sim → 1 Hz timeline rows (damage, stocks, positions, edge distance, gauge, items, state) + per-match features.
- Models: M2 win probability (timeline → winner, grouped CV by match), M5 balance (character/arena/style effects on win & ring-outs), M1 early churn (pipeline + schema only until real users exist).
- Output: `analysis/reports/*.md` with metrics (log-loss/AUC/calibration), feature importance, balance tables.

## Testing
- Godot: GUT tests for new counters/rows/catalog; `scripts/test.sh` + `scripts/check-all.sh`.
- Python: pytest for feature builders and a smoke train on a tiny synthetic set.

## Out of scope
Online model serving, real-time in-game prediction UI, M6 behaviour cloning (later).
