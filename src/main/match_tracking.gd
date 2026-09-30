class_name MatchTracking
extends RefCounted
## Telemetry wiring of one match scene (platform A6/B1/A7): a MatchTelemetry per match built from the
## MatchSetup, fed once per tick with that tick's inputs, ended on match over (flush + Supabase
## upload), on restart (abandoned, or rematch_clicked after the result) and when the scene leaves
## the tree. Reads the World (config, state_hash) and never writes to it.

var _track: Callable
var _recorder: MatchRecorder
var _counter: MatchCounter
var _telemetry: MatchTelemetry = null
var _world: World = null


func _init(track: Callable, recorder: MatchRecorder, counter: MatchCounter = null) -> void:
	_track = track
	_recorder = recorder
	_counter = counter if counter != null else MatchCounter.create_default()


func telemetry() -> MatchTelemetry:
	return _telemetry


func begin(setup: MatchSetup, world: World) -> void:
	_world = world
	_telemetry = MatchTelemetry.new(_track)
	_telemetry.begin(TelemetrySetup.from_match_setup(setup, world.config, _context()))


## inputs: what World.tick() got this tick, recorded for the replay log.
func on_tick(events: Array, view_events: Array, view: Dictionary, inputs: Array = []) -> void:
	if _telemetry != null:
		_telemetry.on_frame(events, view_events, view, inputs)


func finish(view: Dictionary) -> void:
	if _telemetry == null:
		return
	_telemetry.end(view, false, _world.state_hash())
	Analytics.flush()
	_recorder.record(_telemetry)


## Restart: an unfinished match is abandoned; after the result it is a rematch.
func close_for_restart(view: Dictionary, result_shown: bool) -> void:
	if _telemetry == null:
		return
	if _telemetry.is_active():
		_telemetry.end(view, true, _world.state_hash())
	elif result_shown:
		_track.call("rematch_clicked", {"match_id": _telemetry.match_id()})


## Leaving the scene (menu, quit) mid-match abandons it.
func close_for_exit(view: Dictionary) -> void:
	if _telemetry != null and _telemetry.is_active():
		_telemetry.end(view, true, _world.state_hash())


func _context() -> Dictionary:
	return {"session_id": Analytics.session_id(), "user_match_seq": _counter.next(_user_id())}


static func _user_id() -> String:
	var client := SupabaseHub.client()
	return client.session.user_id if client != null and client.session != null else ""
