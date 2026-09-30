class_name MatchTelemetry
extends RefCounted
## Match tracking (platform A6, PRD-DATA-03/04). Consumes what the sim already reports —
## World.state_view() events, ViewEvents and fighter views, one call per tick — and never feeds
## anything back, so sim and replay hashes are untouched. Produces Amplitude key moments through
## the injected sink(name, props) and the raw Supabase rows sent by MatchRecorder at the end.

## Position sample period for match_events ("pos" rows): 0.5 s at 60 Hz.
const SAMPLE_EVERY_TICKS := 30
const VIEW_ROW_TYPES: Array[String] = ["jumped", "landed", "respawned"]
const GIMMICK_TYPES: Array[String] = ["platform_break", "bounce"]
const GIMMICK_PREFIX := "gimmick_"

var _sink: Callable
var _setup: Dictionary = {}
var _stats: Array[SlotStats] = []
var _loss := StockLoss.new()
var _attacks := AttackTracker.new()
var _items := ItemTelemetry.new()
var _rows: Array[Dictionary] = []
var _prev: Array = []
var _dealer: Dictionary = {}  # target -> attacker of this tick's last hit
var _active: bool = false
var _match_row: Dictionary = {}
var _player_rows: Array[Dictionary] = []


func _init(sink: Callable) -> void:
	_sink = sink


## setup: match_id, mode, arena, seed, local_slot, started_at, build_version, platform,
## slots [{slot, is_bot, character, style, input_device}].
func begin(setup: Dictionary) -> void:
	_setup = setup
	_active = true
	_stats.clear()
	var characters: Array = []
	var bots := 0
	for s: Dictionary in setup["slots"]:
		_stats.append(SlotStats.new(int(s["slot"])))
		characters.append(s["character"])
		bots += 1 if bool(s["is_bot"]) else 0
	var local: Dictionary = setup["slots"][int(setup.get("local_slot", 0))]
	_emit("match_started", {"mode": setup["mode"], "arena": setup["arena"], "player_count": characters.size(),
		"bot_count": bots, "characters": characters, "input_device": local["input_device"]})


func on_frame(events: Array, view_events: Array, view: Dictionary) -> void:
	if not _active:
		return
	var tick := int(view["tick"])
	var fighters: Array = view["fighters"]
	_observe_attacks(fighters)
	_dealer.clear()
	for e: Dictionary in events:
		_rows.append(RawRows.event_row(match_id(), tick, e))
		_on_sim_event(e, tick, float(view["arena_radius"]))
	for e: Dictionary in view_events:
		if VIEW_ROW_TYPES.has(String(e["type"])):
			_rows.append(RawRows.event_row(match_id(), tick, e))
		if e["type"] == "jumped":
			_stat(int(e["id"])).add("jumps")
	_track_damage(fighters)
	if tick % SAMPLE_EVERY_TICKS == 0:
		for f: Dictionary in fighters:
			if int(f["state"]) != Fighter.State.KO:
				_rows.append(RawRows.position_row(match_id(), tick, f))
	_prev = fighters


## Ends the match once: match_ended (or match_abandoned) with slot summaries and final rows.
func end(view: Dictionary, abandoned: bool = false) -> void:
	if not _active:
		return
	_active = false
	for slot: int in _attacks.close_all():
		_stat(slot).add("whiffs")
	var over := bool(view.get("match_over", false)) and not abandoned
	var winner: Variant = int(view["winner"]) if over and int(view["winner"]) >= 0 else null
	var players: Array = []
	for s: SlotStats in _stats:
		var summary := s.to_summary()
		summary["result"] = MatchSummary.result(s.slot, over, winner)
		summary["stocks_left"] = MatchSummary.stocks_left(view, s.slot)
		players.append(summary)
		_player_rows.append(RawRows.player_row(match_id(), _setup["slots"][s.slot], summary))
	var ticks := int(view["tick"])
	var local_result := MatchSummary.result(int(_setup.get("local_slot", 0)), over, winner)
	_match_row = RawRows.match_row(_setup, ticks, winner, local_result)
	var props := {"mode": _setup["mode"], "arena": _setup["arena"], "duration_s": MatchSummary.seconds(ticks)}
	if abandoned:
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


func _on_sim_event(e: Dictionary, tick: int, arena_radius: float) -> void:
	var type := String(e["type"])
	match type:
		"hit", "guard_hit":
			var attacker := int(e["attacker"])
			var target := int(e["target"])
			_attacks.mark_hit(attacker)
			_loss.note_attack(target, attacker, tick)
			_dealer[target] = attacker
			_stat(target if type == "guard_hit" else attacker).add("guards" if type == "guard_hit" else "hits")
		"grab":
			_stat(int(e["attacker"])).add("grabs")
			_loss.note_attack(int(e["target"]), int(e["attacker"]), tick)
		"ringout":
			_on_ringout(e, tick, arena_radius)
	if type.begins_with(GIMMICK_PREFIX) or GIMMICK_TYPES.has(type):
		var victim := MatchSummary.fighter_of(e)
		if victim >= 0:
			_loss.note_gimmick(victim, String(e.get("kind", type)), tick)
		_emit("gimmick_triggered", {"kind": String(e.get("kind", type)), "victim_slot": victim})
	_items.on_event(e, _emit, _count)


func _on_ringout(e: Dictionary, tick: int, arena_radius: float) -> void:
	var victim := int(e["id"])
	var pos: Vector3 = e["pos"]
	var why := _loss.classify(victim, tick)
	var attacker := int(why["attacker_slot"])
	_stat(victim).add("falls")
	if attacker >= 0:
		_stat(attacker).add("ringouts_scored")
	_emit("stock_lost", {"victim_slot": victim, "attacker_slot": attacker, "cause": why["cause"],
		"damage_at_death": MatchSummary.damage_of(_prev, victim), "angle_deg": StockLoss.angle_deg(pos),
		"zone": StockLoss.zone(pos, arena_radius), "stocks_left": int(e["stocks_left"])})
	if why["cause"] == "gimmick":
		_stat(victim).add("falls_by_gimmick")
		_emit("gimmick_ringout", {"kind": why["gimmick_kind"], "victim_slot": victim})


func _observe_attacks(fighters: Array) -> void:
	var seen := _attacks.observe(_prev, fighters)
	for slot: int in seen["whiffs"]:
		_stat(slot).add("whiffs")
	for opened: Array in seen["opened"]:
		_items.on_swing(int(opened[0]), int(opened[1]), _emit, _count)


## Damage rises between ticks of the same life are taken by the victim and dealt by this tick's hitter.
func _track_damage(fighters: Array) -> void:
	for i: int in mini(_prev.size(), fighters.size()):
		var a: Dictionary = _prev[i]
		var b: Dictionary = fighters[i]
		var delta := float(b["damage"]) - float(a["damage"])
		if int(a["spawn_id"]) != int(b["spawn_id"]) or delta <= 0.0:
			continue
		var victim := int(b["id"])
		_stat(victim).damage_taken += delta
		if _dealer.has(victim) and int(_dealer[victim]) != victim:
			_stat(int(_dealer[victim])).damage_dealt += delta


## Out-of-range slots (an ownerless bomb) count into a throwaway accumulator.
func _stat(slot: int) -> SlotStats:
	return _stats[slot] if slot >= 0 and slot < _stats.size() else SlotStats.new(slot)


func _count(slot: int, counter: String) -> void:
	_stat(slot).add(counter)


func _emit(event_name: String, props: Dictionary) -> void:
	props["match_id"] = match_id()
	_sink.call(event_name, JsonSafe.to_json_value(props))
