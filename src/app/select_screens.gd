class_name SelectScreens
extends RefCounted
## Builds the App's select step screens (App.SELECT_STEPS, split out of App): rule (sets the
## MatchSetup rule and line-up size), team (the 2v2 split, team rule only), character (fills the
## characters) and arena. Each screen calls `next` once it has filled the setup and emits
## `cancelled` when backed out (App pops it).


## A new local match setup for mode, seeded from new_seed(), or null (온라인 goes through OnlineFlow).
static func new_setup(mode: String, new_seed: Callable) -> MatchSetup:
	match mode:
		MatchSetup.MODE_BOT:
			return MatchSetup.vs_bots(MatchSetup.DEFAULT_PLAYERS, int(new_seed.call()))
		MatchSetup.MODE_LOCAL_2P:  # both humans pick characters
			return MatchSetup.local_versus(MatchSetup.DEFAULT_PLAYERS, int(new_seed.call()))
	return null


## The first step at or after from_step that applies to setup (steps.size() when none is left).
static func next_step(steps: Array[String], setup: MatchSetup, from_step: int) -> int:
	var step := from_step
	while step < steps.size() and not applies(steps[step], setup):
		step += 1
	return step


## The team step only runs for the team rule; every other step always runs.
static func applies(step_id: String, setup: MatchSetup) -> bool:
	return step_id != App.TEAM or setup.rule == MatchRules.TEAM


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
		App.TEAM:
			var teams := TeamSelectScreen.new()
			teams.track = track
			teams.setup = setup
			teams.teams_chosen.connect(func(split: Array[int]) -> void:
				setup.set_teams(split)
				next.call())
			return teams
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
