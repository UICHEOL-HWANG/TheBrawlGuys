class_name BotTracker
extends RefCounted
## Bot tracking for ML (PRD-BOT-04): per bot slot the dial value at the start, its mean over the
## match (one sample per tick) and at the end; and sampled bot_intent rows — a row when a bot's
## intent changes, at least min_ticks after that bot's previous row, at most `cap` rows per match
## (upload size stays bounded: 300 rows ~ 30 KB).

var _cap: int
var _min_ticks: int
var _d_start := {}
var _d_sum := {}
var _d_n := {}
var _d_end := {}
var _last_intent := {}
var _last_row := {}
var _rows: int = 0


func _init(cap: int, min_ticks: int) -> void:
	_cap = cap
	_min_ticks = min_ticks


## One tick of a bot: records its d; returns a bot_intent event {tick, slot, intent, target,
## dist, threat} or {} when nothing is logged.
func sample(tick: int, slot: int, bot: BotController) -> Dictionary:
	var d := bot.skill().d
	if not _d_start.has(slot):
		_d_start[slot] = d
		_d_sum[slot] = 0.0
		_d_n[slot] = 0
	_d_sum[slot] += d
	_d_n[slot] += 1
	_d_end[slot] = d
	var intent := bot.intent()
	if intent.name == String(_last_intent.get(slot, "")) or _rows >= _cap:
		return {}
	if tick - int(_last_row.get(slot, -(1 << 30))) < _min_ticks:
		return {}
	_last_intent[slot] = intent.name
	_last_row[slot] = tick
	_rows += 1
	return intent.to_dict().merged({"tick": tick, "slot": slot})


func rows_logged() -> int:
	return _rows


## {bot_d_start, bot_d_mean, bot_d_end} of a tracked bot ({} for an untracked slot).
func summary(slot: int) -> Dictionary:
	if not _d_start.has(slot):
		return {}
	return {"bot_d_start": snappedf(float(_d_start[slot]), 0.001),
		"bot_d_mean": snappedf(float(_d_sum[slot]) / maxf(1.0, float(_d_n[slot])), 0.001),
		"bot_d_end": snappedf(float(_d_end[slot]), 0.001)}
