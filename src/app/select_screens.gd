class_name SelectScreens
extends RefCounted
## Builds the App's select step screens (App.SELECT_STEPS, split out of App): rule (sets the
## MatchSetup rule and line-up size), character (fills the characters) and arena. Each screen
## calls `next` once it has filled the setup and emits `cancelled` when backed out (App pops it).


static func build(step_id: String, setup: MatchSetup, next: Callable, config: GameConfig,
		track: Callable) -> Control:
	match step_id:
		App.RULE:
			var rules := RuleSelectScreen.new()
			rules.track = track
			rules.config = config
			rules.rule_chosen.connect(func(rule: String) -> void:
				setup.set_rule(rule)
				next.call())
			return rules
		App.CHARACTER:
			var chars := CharacterSelectScreen.new()
			chars.track = track
			chars.config = config
			chars.setup = setup
			chars.characters_chosen.connect(next)
			return chars
	assert(step_id == App.ARENA, "SelectScreens: no select screen for step '%s'" % step_id)
	var arenas := ArenaSelectScreen.new()
	arenas.track = track
	arenas.config = config
	arenas.arena_chosen.connect(func(arena_id: String) -> void:
		setup.arena_id = arena_id
		next.call())
	return arenas
