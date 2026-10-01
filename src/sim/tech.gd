class_name Tech
extends RefCounted
## Tech presses (combat-depth C, PRD §4.3). A fresh guard press (GuardMeter.track_presses set
## guard_press_age = 0) while tumbling starts the fighter's tech_clock at tech_window_ticks +
## tech_lockout_ticks, unless the clock is still running: a tech is armed while more than
## tech_lockout_ticks remain, and no new press counts until it reaches 0 (a missed press locks
## the next ones out). Knockdown.land techs instead of lying down while armed.


## Every tick, right after GuardMeter.track_presses: run the clocks down, start them on presses.
static func track(fighters: Array[Fighter], config: GameConfig) -> void:
	for f: Fighter in fighters:
		if f.tech_clock > 0:
			f.tech_clock -= 1
		if f.guard_press_age == 0 and f.tumble and f.tech_clock == 0:
			f.tech_clock = config.tech_window_ticks + config.tech_lockout_ticks


static func armed(f: Fighter, config: GameConfig) -> bool:
	return f.tech_clock > config.tech_lockout_ticks
