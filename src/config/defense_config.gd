class_name DefenseConfig
extends Resource
## Combat-depth track A defense tunables (PRD §4.3): rolls, air dodges, guard durability and
## perfect guard, split out of GameConfig to keep files short. GameConfig extends StyleConfig
## extends SpecialConfig extends this, so every value here is a GameConfig value: the debug panel
## shows each @export_range and the sim groups enter GameConfig.fingerprint().
## Frames are sim ticks (60 Hz), distances metres. Guard points are out of GuardMeter.MAX (100).

@export_group("Dodge")
## Ground roll (guard pressed with a move input): moves roll_distance over roll_move_ticks, is
## intangible (hits and grabs pass through) from roll_intangible_start for roll_intangible_ticks,
## then stands still for roll_recovery_ticks.
@export_range(0.5, 8.0, 0.1) var roll_distance: float = 3.2
@export_range(1, 60, 1) var roll_move_ticks: int = 16
@export_range(0, 30, 1) var roll_intangible_start: int = 2
@export_range(0, 60, 1) var roll_intangible_ticks: int = 12
@export_range(0, 60, 1) var roll_recovery_ticks: int = 10
## A roll started within roll_spam_window_ticks of the previous one ending adds
## roll_spam_recovery_ticks of recovery per repeat, stacking up to roll_spam_max_stack.
@export_range(0, 240, 1) var roll_spam_window_ticks: int = 60
@export_range(0, 60, 1) var roll_spam_recovery_ticks: int = 8
@export_range(0, 10, 1) var roll_spam_max_stack: int = 3
## Air dodge (guard pressed in the air, once per airtime): a short hovering burst along the move
## input (in place when neutral), intangible like a roll, then falls straight down to recover.
@export_range(0.0, 6.0, 0.1) var air_dodge_distance: float = 2.2
@export_range(1, 60, 1) var air_dodge_move_ticks: int = 10
@export_range(0, 30, 1) var air_dodge_intangible_start: int = 1
@export_range(0, 60, 1) var air_dodge_intangible_ticks: int = 10
@export_range(0, 60, 1) var air_dodge_recovery_ticks: int = 12

@export_group("GuardMeter")
## Guard points lost per tick while guard is held, and per point of blocked (unscaled) damage.
@export_range(0.0, 2.0, 0.01) var guard_hold_drain: float = 0.12
@export_range(0.0, 10.0, 0.1) var guard_block_mul: float = 2.0
## Ticks without guarding before the meter refills, then points regained per tick.
@export_range(0, 240, 1) var guard_regen_delay_ticks: int = 40
@export_range(0.0, 5.0, 0.01) var guard_regen_per_tick: float = 0.35
## Guard break (meter at 0 while guarding): pops up at guard_break_pop_speed and is stunned for
## guard_break_stun_ticks; the meter restarts at guard_break_refill points.
@export_range(0, 300, 1) var guard_break_stun_ticks: int = 100
@export_range(0.0, 20.0, 0.1) var guard_break_pop_speed: float = 5.0
@export_range(0.0, 100.0, 1.0) var guard_break_refill: float = 30.0
## Perfect guard: a hit within perfect_guard_ticks of the guard press deals no chip damage and
## costs no guard points; a melee attacker is frozen perfect_guard_stagger_ticks longer.
@export_range(0, 30, 1) var perfect_guard_ticks: int = 5
@export_range(0, 60, 1) var perfect_guard_stagger_ticks: int = 8

@export_group("BotDefense")
## Bots react to a new threat this many ticks late (not frame-perfect, so few perfect guards) and stop
## guarding below this guard-meter ratio (BotDefense).
@export_range(0, 60, 1) var bot_guard_react_ticks: int = 1
@export_range(0.0, 1.0, 0.05) var bot_guard_min_ratio: float = 0.35
