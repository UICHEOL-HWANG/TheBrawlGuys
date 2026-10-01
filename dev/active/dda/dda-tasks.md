# DDA + probe bots — tasks

Spec: `docs/superpowers/specs/2026-10-01-dda-probe-bots-design.md` · PRD `PRD-BOT-03~06` · results `analysis/reports/dda.md`
Last Updated: 2026-10-01

## Done (branch feat/dda-bots)
- [x] Dial `src/input/bot_difficulty.gd` + `bot_skill.gd`: d ∈ [0,1] → reaction, guard / perfect / tech / DI chances, getup choice, cadence, aim error, hesitation, special delay. Presets slow 0.2 / normal 0.5 / busy 0.8. Bot reads the skill every tick (`BotController.set_difficulty`)
- [x] Monotonic sweep `scripts/dda_sweep.sh` (bot(d) vs bot(0.5), 16 character pairs, slots swapped) → `analysis/reports/dda_sweep.csv`. Fix of the "busy loses" finding: ablation showed over-eager guarding (fast reaction + guard every threat → plain blocks that get grabbed) and short attack cadence lose; anchors now cap guard_chance at 0.7, react at 8 ticks, cadence at 34 ticks
- [x] Probe `bot_probe.gd` + `probe_observer.gd` (frontal / edge / ranged / punish, 6 s each) → features → `skill_estimator.json` → start d. Device rating `skill_rating.gd` (user://skill.cfg, EMA, Elo-like result step)
- [x] DDA `dda_controller.gd` (1 Hz, logistic win prob over `dda_features.gd`, band 0.45–0.60, hysteresis 0.05, max step 0.1, cooldown 4 s), only bots facing humans; `DDA` config group (NON_SIM); A/B `dda_variant` on/off (`bot_squad_factory.gd`, setting `[bots] dda`)
- [x] Bot tracking: `bot_squad.gd` / `bot_tracker.gd` → players[] + match_players (schema 9, migration 0006), match_events `probe_stage` / `dda_adjusted` / `bot_intent` (≤ 300 rows / match); generator emits them (slot 0 = player with known d)
- [x] ML: `python -m brawl_analysis export-models` (estimator Ridge, win prob logistic with d) → `data/models/*.json` (+ export include_filter)
- [x] Tests: GUT `test_bot_difficulty`, `test_bot_probe`, `test_dda_controller` (incl. Python parity fixtures), `test_bot_squad`; pytest `test_dda_models`
- [x] Convergence `scripts/dda_converge.sh` → `analysis/reports/dda_converge.csv`

## Next
- [ ] User: run `supabase/migrations/0006_bot_tracking.sql` (uploads from schema 9 builds fail until then)
- [ ] Real users: compare dda_variant arms on rematch / D1 return (M1/M7 labels) → engagement-optimal band, then a contextual bandit over the band
- [ ] Settings UI toggle for `[bots] dda` (key exists, no screen yet)
- [ ] Estimator underestimates high d (probe saturates); add a longer punish stage or in-match features if real data agrees
