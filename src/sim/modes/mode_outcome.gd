class_name ModeOutcome
extends RefCounted
## Who has won after a tick, per mode (combat-depth D): stock = Rules.winner; team = the only
## team with fighters left (winner id = its lowest surviving id, ModeState.winner_team set); timed
## = runs the clock and at time up the single highest score wins, a tie starts sudden death (tied
## fighters on one stock, everyone else out) which then plays as stock.


## Rules.ONGOING, Rules.DRAW or the winner id; appends a "sudden_death" event when one starts.
static func resolve(fighters: Array[Fighter], state: ModeState, events: Array[Dictionary]) -> int:
	match state.rules.mode:
		MatchRules.TEAM:
			return _team_winner(fighters, state)
		MatchRules.TIMED:
			if not state.sudden_death:
				return _clock(fighters, state, events)
	return Rules.winner(fighters)


static func _team_winner(fighters: Array[Fighter], state: ModeState) -> int:
	var first_alive := {}  # team -> lowest alive id
	for f: Fighter in fighters:
		var t := state.rules.team_of(f.id)
		if f.is_alive() and not first_alive.has(t):
			first_alive[t] = f.id
	if first_alive.is_empty():
		return Rules.DRAW
	if first_alive.size() > 1:
		return Rules.ONGOING
	state.winner_team = int(first_alive.keys()[0])
	return int(first_alive.values()[0])


static func _clock(fighters: Array[Fighter], state: ModeState, events: Array[Dictionary]) -> int:
	state.ticks_left = maxi(state.ticks_left - 1, 0)
	if state.ticks_left > 0:
		return Rules.ONGOING
	var leaders := _leaders(state.scores)
	if leaders.size() == 1:
		return leaders[0]
	_start_sudden_death(fighters, state, leaders)
	events.append({"type": "sudden_death", "ids": leaders})
	return Rules.ONGOING


## Ids sharing the highest score.
static func _leaders(scores: Array[int]) -> Array[int]:
	var top := -2147483648
	var out: Array[int] = []
	for i: int in scores.size():
		if scores[i] > top:
			top = scores[i]
			out = [i]
		elif scores[i] == top:
			out.append(i)
	return out


static func _start_sudden_death(fighters: Array[Fighter], state: ModeState, leaders: Array[int]) -> void:
	state.sudden_death = true
	for f: Fighter in fighters:
		if leaders.has(f.id):
			f.stocks = 1
		elif f.is_alive():
			f.stocks = 0
			f.vel = Vector3.ZERO
			Rules.clear_actions(f)
			f.set_state(Fighter.State.KO)
