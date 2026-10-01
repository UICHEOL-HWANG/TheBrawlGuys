class_name ModeConfig
extends Resource
## Match mode tunables (combat-depth D, PRD §4.1 modes), split out of GameConfig to keep files
## short. GameConfig extends StyleConfig extends SpecialConfig extends DefenseConfig extends
## KnockdownConfig extends this,
## so every value here is a GameConfig value (debug panel slider; "Modes" is a sim group and
## enters GameConfig.fingerprint()). The rules a match is played under are MatchRules, built from
## these values when the match starts.

@export_group("Modes")
## Timed FFA length in seconds.
@export_range(10.0, 600.0, 5.0) var timed_duration: float = 120.0
## Team 2v2: 1 = teammates' hits land, 0 = they pass through (default).
@export_range(0, 1, 1) var friendly_fire: int = 0
## A ring-out scores for the last fighter whose hit touched the victim within this many seconds;
## otherwise it is a self-destruct (-1). Matches the telemetry StockLoss window (180 ticks).
@export_range(0.5, 10.0, 0.5) var ringout_credit_time: float = 3.0
