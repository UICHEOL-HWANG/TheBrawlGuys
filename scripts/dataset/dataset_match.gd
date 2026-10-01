extends RefCounted
## Plays one synthetic bot-only match for scripts/gen_dataset.gd (A9) and feeds it through the
## game's own telemetry (TelemetrySetup -> MatchTelemetry -> RawRows/SlotStats/MatchFeatures), the
## same per-tick calls MatchTracking makes in the app, so the rows have the Supabase table shapes.
## Nothing is uploaded: the Amplitude sink is a no-op. Matches still running at MAX_TICKS end as
## abandoned (the analysis drops them).

const DatasetSpec := preload("res://scripts/dataset/dataset_spec.gd")
const TimelineSampler := preload("res://scripts/dataset/timeline_sampler.gd")

const MAX_TICKS := 60 * 60 * 6
## Synthetic rows are tagged so they never mix with real data in one table.
const PLATFORM := "synthetic"
const BUILD := "dataset"
## Synthetic matches start this far apart from BASE_UNIX (2026-10-01T00:00:00Z).
const BASE_UNIX := 1790812800
const START_SPACING_S := 300


## {match: matches row, players: match_players rows, events: match_events rows, timeline: rows}
static func play(index: int, seed: int, config: GameConfig) -> Dictionary:
	var spec := DatasetSpec.make(seed, config)
	var setup := DatasetSpec.to_match_setup(spec)
	var world := setup.build_world(config)
	var bots: Array[BotController] = []
	for i: int in setup.player_count():
		bots.append(BotController.new(i, spec["bot_configs"][i]))
	var telemetry := MatchTelemetry.new(func(_name: String, _props: Variant) -> void: pass)
	telemetry.begin(_telemetry_setup(index, setup, spec, config))
	var timeline: Array[Dictionary] = []
	var view := world.state_view()
	while not world.match_over and world.tick_count < MAX_TICKS:
		var inputs: Array[InputFrame] = []
		for b: BotController in bots:
			inputs.append(b.sample(view))
		var prev := view
		world.tick(inputs)
		view = world.state_view()
		var view_events := ViewEvents.detect(prev["fighters"], view["fighters"], config)
		telemetry.on_frame(view["events"], view_events, view, inputs)
		if TimelineSampler.due(world.tick_count):
			timeline.append_array(TimelineSampler.rows(telemetry.match_id(), view))
	telemetry.end(view, false, world.state_hash())
	return {"match": telemetry.match_row(), "players": telemetry.player_rows(),
		"events": telemetry.event_rows(), "timeline": timeline}


## The app's TelemetrySetup, made reproducible: id from the index, fixed clock, per-slot bot tuning.
static func _telemetry_setup(index: int, setup: MatchSetup, spec: Dictionary, config: GameConfig) -> Dictionary:
	var out := TelemetrySetup.from_match_setup(setup, config, {"user_match_seq": index + 1})
	out["match_id"] = match_uuid(index)
	out["started_at"] = Time.get_datetime_string_from_unix_time(BASE_UNIX + index * START_SPACING_S) + "Z"
	out["platform"] = PLATFORM
	out["build_version"] = BUILD
	var slots: Array = []
	for s: Dictionary in out["slots"]:
		var slot := int(s["slot"])
		slots.append(s.merged({"bot_difficulty": spec["difficulties"][slot],
			"bot_params_hash": TelemetrySetup.bot_params_hash(spec["bot_configs"][slot])}, true))
	out["slots"] = slots
	return out


## Deterministic v4-shaped uuid for the index-th synthetic match.
static func match_uuid(index: int) -> String:
	return "5e7d0000-0000-4000-8000-%012d" % index
