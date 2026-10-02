class_name MatchTracking
extends RefCounted
## Telemetry wiring of one match scene (platform A6/B1/A7/A8): a MatchTelemetry per match built from
## the MatchSetup, fed once per tick with that tick's inputs, ended on match over (flush + Supabase
## upload), on restart (abandoned, or rematch_clicked after the result) and when the scene leaves
## the tree. Also reports the scene's load time (first tick), a perf sample per match and how long
## the result stayed up before rematch / menu / quit. Reads the World and never writes to it.

const NONE := -1

## Online (NetMatch): the host's match id shared by every peer ("" = a fresh one per match), and the
## network summary (NetStats.props) added to match_ended / matches / match_players at the end.
var match_id: String = ""
var net_props: Callable = Callable()

var _track: Callable
var _recorder: MatchRecorder
var _counter: MatchCounter
var _clock: Callable
var _telemetry: MatchTelemetry = null
var _world: World = null
var _perf := PerfSampler.new()
var _load_started_ms: int = NONE
var _result_shown_ms: int = NONE


## Create it first thing in the scene's _ready: the match load time counts from here.
func _init(track: Callable, recorder: MatchRecorder, counter: MatchCounter = null,
		clock_ms: Callable = Time.get_ticks_msec) -> void:
	_track = track
	_recorder = recorder
	_counter = counter if counter != null else MatchCounter.create_default()
	_clock = clock_ms
	_load_started_ms = int(_clock.call())


func telemetry() -> MatchTelemetry:
	return _telemetry


## extra_context: more TelemetrySetup context (BotSquad.context(): dda_variant).
func begin(setup: MatchSetup, world: World, extra_context: Dictionary = {}) -> void:
	_world = world
	_perf = PerfSampler.new()
	_result_shown_ms = NONE
	_telemetry = MatchTelemetry.new(_track)
	_telemetry.begin(TelemetrySetup.from_match_setup(setup, world.config, _context().merged(extra_context)))


## inputs: what World.tick() got this tick, recorded for the replay log.
func on_tick(events: Array, view_events: Array, view: Dictionary, inputs: Array = []) -> void:
	if _load_started_ms != NONE:
		_track.call("load_timed", {"stage": "match_load", "ms": int(_clock.call()) - _load_started_ms})
		_load_started_ms = NONE
	if _telemetry != null:
		_telemetry.on_frame(events, view_events, view, inputs)


## Render frame time while the match runs (perf_sampled).
func on_frame_time(delta: float) -> void:
	if _telemetry != null and _telemetry.is_active():
		_perf.add_frame(delta)


func finish(view: Dictionary) -> void:
	if _telemetry == null:
		return
	_telemetry.end(view, false, _world.state_hash(), _net())
	_send_perf()
	_result_shown_ms = int(_clock.call())
	Analytics.flush()
	_recorder.record(_telemetry)


## The banner actually appeared (after the finishing replay, GD-CAM-02): result dwell starts here.
func on_result_shown() -> void:
	_result_shown_ms = int(_clock.call())


## The result banner's 메뉴로 was pressed.
func on_menu() -> void:
	_close_result("menu")


## Restart: an unfinished match is abandoned; after the result it is a rematch.
func close_for_restart(view: Dictionary, result_shown: bool) -> void:
	if _telemetry == null:
		return
	if _telemetry.is_active():
		_abandon(view)
	elif result_shown:
		_close_result("rematch")
		_track.call("rematch_clicked", {"match_id": _telemetry.match_id()})


## Leaving the scene mid-match abandons it; leaving from the result without 메뉴로 is a quit.
func close_for_exit(view: Dictionary) -> void:
	if _telemetry == null:
		return
	if _telemetry.is_active():
		_abandon(view)
	else:
		_close_result("quit")


func _abandon(view: Dictionary) -> void:
	_telemetry.end(view, true, _world.state_hash(), _net())
	_send_perf()


func _send_perf() -> void:
	_track.call("perf_sampled", _perf.props().merged({"match_id": _telemetry.match_id()}))


## result_viewed once per shown result: dwell time and what came next.
func _close_result(next: String) -> void:
	if _result_shown_ms == NONE or _telemetry == null:
		return
	var dwell := int(_clock.call()) - _result_shown_ms
	_result_shown_ms = NONE
	_track.call("result_viewed", {"match_id": _telemetry.match_id(), "dwell_ms": dwell, "next": next})


func _context() -> Dictionary:
	var seq := _counter.next(_user_id())
	Analytics.set_user_properties(user_props_for_seq(seq))
	return {"session_id": Analytics.session_id(), "user_match_seq": seq,
		"loss_streak": Analytics.loss_streak(), "match_id": match_id}


## matches_played user property: this install's match count for the user (user_match_seq).
static func user_props_for_seq(seq: int) -> Dictionary:
	return {"matches_played": seq} if seq > 0 else {}


func _net() -> Dictionary:
	return net_props.call() if net_props.is_valid() else {}


static func _user_id() -> String:
	var client := SupabaseHub.client()
	return client.session.user_id if client != null and client.session != null else ""
