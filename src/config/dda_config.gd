class_name DdaConfig
extends ItemExtrasConfig
## Dynamic difficulty tunables (PRD-BOT-06), near the base of the GameConfig chain (NetConfig
## extends this; this extends ItemExtrasConfig). "DDA" is a NON_SIM group: bots live outside the sim, so these never enter the
## fingerprint and never change a replay.

@export_group("DDA")
## 1 = DDA may run (the experiment variant still decides per device); 0 = never.
@export_range(0, 1, 1) var dda_enabled: int = 1
## Share of devices whose "auto" setting lands in the dda = on arm (A/B, DdaVariant).
@export_range(0.0, 1.0, 0.05) var dda_on_share: float = 0.5
## Target band of the human's win probability (relative to a fair share, 0.5 in 1v1).
@export_range(0.0, 1.0, 0.01) var dda_target_low: float = 0.45
@export_range(0.0, 1.0, 0.01) var dda_target_high: float = 0.60
## Adjusting starts only once the probability leaves the band by this much; it stops back inside.
@export_range(0.0, 0.3, 0.01) var dda_hysteresis: float = 0.05
## d change per adjustment: gain x distance from the band middle, capped at max_step.
@export_range(0.0, 2.0, 0.05) var dda_gain: float = 0.6
@export_range(0.01, 0.5, 0.01) var dda_max_step: float = 0.1
## Seconds between model evaluations and the least time between two adjustments.
@export_range(0.25, 10.0, 0.25) var dda_interval_s: float = 1.0
@export_range(0.0, 60.0, 0.5) var dda_cooldown_s: float = 4.0
## The range DDA may move a bot's d within.
@export_range(0.0, 1.0, 0.05) var dda_min_d: float = 0.0
@export_range(0.0, 1.0, 0.05) var dda_max_d: float = 1.0
## Probe (PRD-BOT-05): seconds per stage (4 stages), matches probed before the stored rating is
## trusted alone, and the weight of a new observation in the stored rating (EMA).
@export_range(1.0, 15.0, 0.5) var dda_probe_stage_s: float = 6.0
@export_range(0, 20, 1) var dda_probe_matches: int = 3
@export_range(0.0, 1.0, 0.05) var dda_rating_weight: float = 0.3
## Rating observation = bots' d moved this much up after a human win, down after a loss.
@export_range(0.0, 0.5, 0.01) var dda_rating_result_step: float = 0.15
## bot_intent tracking: at most this many rows per match, at least this many ticks apart per bot.
@export_range(0, 5000, 10) var dda_intent_cap: int = 300
@export_range(1, 600, 1) var dda_intent_min_ticks: int = 20
