class_name MatchTelemetry
extends RefCounted
## Match tracking (platform A6, PRD-DATA-03/04). Consumes what the sim already reports —
## World.state_view() events, ViewEvents, fighter views and the tick's inputs, one call per tick —
## and never feeds anything back, so sim and replay hashes are untouched. Produces Amplitude key
## moments through the injected sink(name, props) and the raw Supabase rows sent by MatchRecorder.
## Combat reading lives in CombatTelemetry, the replay log in InputLog, behaviour features in
## MatchFeatures (A8).

## Position sample period for match_events ("pos" rows): 0.5 s at 60 Hz.
const SAMPLE_EVERY_TICKS := 30
const VIEW_ROW_TYPES: Array[String] = ["jumped", "landed", "respawned"]

var _sink: Callable
var _setup: Dictionary = {}
var _stats: Array[SlotStats] = []
var _combat: CombatTelemetry
var _inputs := InputLog.new()
var _features := MatchFeatures.new(0)
var _rows: Array[Dictionary] = []
var _active: bool = false
var _match_row: Dictionary = {}
var _player_rows: Array[Dictionary] = []


func _init(sink: Callable) -> void:
	_sink = sink
	_combat = CombatTelemetry.new(_stat, _emit)


## setup: match_id, mode, arena, seed, local_slot, started_at, build_version, platform,
## slots [{slot, is_bot, character, style, input_device, controller?, bot_difficulty?, bot_params_hash?}]
## and the optional reproducibility header (TelemetrySetup, RawRows.HEADER_KEYS).
func begin(setup: Dictionary) -> void:
	_setup = setup
	_active = true
	_stats.clear()
	_inputs = InputLog.new((setup["slots"] as Array).size())
	_features = MatchFeatures.new((setup["slots"] as Array).size())
	var characters: Array = []
	var bots := 0
	for s: Dictionary in setup["slots"]:
		_stats.append(SlotStats.new(int(s["slot"])))
		characters.append(s["character"])
		bots += 1 if bool(s["is_bot"]) else 0
	var local: Dictionary = setup["slots"][int(setup.get("local_slot", 0))]
	_emit("match_started", {"mode": setup["mode"], "rule": setup.get("rule", MatchRules.STOCK), "arena": setup["arena"], "player_count": characters.size(),
		"bot_count": bots, "characters": characters, "input_device": local["input_device"],
		"loss_streak": _int_or(setup.get("loss_streak"), 0), "user_match_seq": _int_or(setup.get("user_match_seq"), 0)})


## inputs: the InputFrames World.tick() got for this tick (slot order), recorded for replay (A7).
func on_frame(events: Array, view_events: Array, view: Dictionary, inputs: Array = []) -> void:
	if not _active:
		return
	if not inputs.is_empty():
		_inputs.record(inputs)
	var tick := int(view["tick"])
	var fighters: Array = view["fighters"]
	var radius := float(view["arena_radius"])
	_combat.begin_tick(fighters, tick)
	var enriched: Array = []
	for e: Dictionary in events:
		enriched.append(e.merged(_combat.on_event(e, tick, fighters, radius)))
		_rows.append(RawRows.event_row(match_id(), tick, enriched.back()))
	for e: Dictionary in view_events:
		if VIEW_ROW_TYPES.has(String(e["type"])):
			_rows.append(RawRows.event_row(match_id(), tick, e))
		if e["type"] == "jumped":
			_stat(int(e["id"])).add("jumps")
	_features.observe(tick, enriched, _combat.previous(), fighters, radius, inputs,
			(view.get("mode", {}) as Dictionary).get("teams", []))
	_combat.end_tick(fighters)
	if tick % SAMPLE_EVERY_TICKS == 0:
		for f: Dictionary in fighters:
			if int(f["state"]) != Fighter.State.KO:
				_rows.append(RawRows.position_row(match_id(), tick, f))


## Ends the match once: match_ended (or match_abandoned) with slot summaries and final rows.
## final_state_hash: World.state_hash() now, so an offline replay can be checked (A7).
func end(view: Dictionary, abandoned: bool = false, final_state_hash: Variant = null) -> void:
	if not _active:
		return
	_active = false
	_combat.finish()
	var over := bool(view.get("match_over", false)) and not abandoned
	var winner: Variant = int(view["winner"]) if over and int(view["winner"]) >= 0 else null
	var ticks := int(view["tick"])
	var teams: Array = (view.get("mode", {}) as Dictionary).get("teams", [])
	var players: Array = []
	for s: SlotStats in _stats:
		var summary := s.to_summary()
		var slot_setup: Dictionary = _setup["slots"][s.slot]
		summary["character"] = slot_setup["character"]
		summary["style"] = slot_setup["style"]
		summary["result"] = MatchSummary.result(s.slot, over, winner, teams)
		summary["stocks_left"] = MatchSummary.stocks_left(view, s.slot)
		summary.merge(MatchSummary.mode_fields(view, s.slot))
		summary.merge(_features.summary(s.slot, summary, ticks))
		players.append(summary)
		_player_rows.append(RawRows.player_row(match_id(), slot_setup, summary))
	var local_slot := int(_setup.get("local_slot", 0))
	var local_result := MatchSummary.result(local_slot, over, winner, teams)
	_match_row = RawRows.match_row(_setup, ticks, winner, local_result, final_state_hash)
	var props := {"mode": _setup["mode"], "rule": _setup.get("rule", MatchRules.STOCK), "arena": _setup["arena"], "duration_s": MatchSummary.seconds(ticks)}
	if abandoned:
		props.merge(_features.abandon_context(local_slot, view.get("fighters", []), ticks))
		_emit("match_abandoned", props)
		return
	props.merge({"result": local_result, "winner_slot": -1 if winner == null else winner, "players": players})
	_emit("match_ended", props)


func match_id() -> String:
	return String(_setup.get("match_id", ""))


func is_active() -> bool:
	return _active


func event_rows() -> Array[Dictionary]:
	return _rows


func match_row() -> Dictionary:
	return _match_row


func player_rows() -> Array[Dictionary]:
	return _player_rows


## match_inputs rows (A7): every slot's recorded inputs, encoded.
func input_rows() -> Array[Dictionary]:
	return _inputs.rows(match_id())


static func _int_or(v: Variant, fallback: int) -> int:
	return int(v) if v != null else fallback


## Out-of-range slots (an ownerless bomb) count into a throwaway accumulator.
func _stat(slot: int) -> SlotStats:
	return _stats[slot] if slot >= 0 and slot < _stats.size() else SlotStats.new(slot)


func _emit(event_name: String, props: Dictionary) -> void:
	props["match_id"] = match_id()
	_sink.call(event_name, JsonSafe.to_json_value(props))
