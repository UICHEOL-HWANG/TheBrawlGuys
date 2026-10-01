extends RefCounted
## Plays one synthetic bot-only match for scripts/gen_dataset.gd (A9) and feeds it through the
## game's own telemetry (TelemetrySetup -> MatchTelemetry -> RawRows/SlotStats/MatchFeatures), the
## same per-tick calls MatchTracking makes in the app, so the rows have the Supabase table shapes.
## Nothing is uploaded: the Amplitude sink is a no-op. Matches still running at MAX_TICKS end as
## abandoned (the analysis drops them). Slot 0 is the "player" (a dial bot with a known d); the
## other slots are a BotSquad facing it, so probe_stage / dda_adjusted / bot_intent rows and the
## bot tracking columns appear exactly as the app writes them.

const DatasetSpec := preload("res://scripts/dataset/dataset_spec.gd")
const TimelineSampler := preload("res://scripts/dataset/timeline_sampler.gd")

const MAX_TICKS := 60 * 60 * 6
## Synthetic rows are tagged so they never mix with real data in one table.
const PLATFORM := "synthetic"
const BUILD := "dataset"
## Synthetic matches start this far apart from BASE_UNIX (2026-10-01T00:00:00Z).
const BASE_UNIX := 1790812800
const START_SPACING_S := 300
## The slot that plays the "player" (the human stand-in the probe and DDA face).
const PLAYER := 0


## {match: matches row, players: match_players rows, events: match_events rows, timeline: rows}
## models: {win_prob, estimator} (LinearModel or null); variant overrides the spec's ("" = spec).
static func play(index: int, seed: int, config: GameConfig, models: Dictionary = {}, variant: String = "") -> Dictionary:
	var spec := DatasetSpec.make(seed)
	if not variant.is_empty():
		spec["variant"] = variant
	var setup := DatasetSpec.to_match_setup(spec)
	var world := setup.build_world(config)
	var d: Array[float] = spec["d"]
	var player := BotController.new(PLAYER, config, d[PLAYER])
	var squad := _squad(spec, config, models)
	var telemetry := MatchTelemetry.new(func(_name: String, _props: Variant) -> void: pass)
	telemetry.begin(_telemetry_setup(index, setup, config, squad))
	telemetry.set_slot_extras(func(slot: int) -> Dictionary: return _extras(slot, squad, player))
	var timeline: Array[Dictionary] = []
	var view := world.state_view()
	while not world.match_over and world.tick_count < MAX_TICKS:
		var inputs: Array[InputFrame] = [player.sample(view)]
		for i: int in range(1, d.size()):
			inputs.append(squad.sample(i, view))
		var prev := view
		world.tick(inputs)
		view = world.state_view()
		telemetry.on_frame(view["events"], ViewEvents.detect(prev["fighters"], view["fighters"], config), view, inputs)
		squad.after_tick(view, telemetry)
		if TimelineSampler.due(world.tick_count):
			timeline.append_array(TimelineSampler.rows(telemetry.match_id(), view, _skill(d.size(), squad, player)))
	telemetry.end(view, false, world.state_hash())
	return {"match": telemetry.match_row(), "players": telemetry.player_rows(),
		"events": telemetry.event_rows(), "timeline": timeline}


## Every slot but the player is a squad bot facing it (probe on; DDA when the variant is on).
static func _squad(spec: Dictionary, config: GameConfig, models: Dictionary) -> BotSquad:
	var d: Array[float] = spec["d"]
	var bots: Array[int] = []
	var by_slot := {}
	for i: int in range(1, d.size()):
		bots.append(i)
		by_slot[i] = d[i]
	return BotSquad.new(config, bots, [PLAYER] as Array[int], {"variant": spec["variant"], "d_by_slot": by_slot,
		"probe": true, "win_prob": models.get("win_prob"), "estimator": models.get("estimator")})


## The player's row carries its true d (the label of the skill estimator).
static func _extras(slot: int, squad: BotSquad, player: BotController) -> Dictionary:
	var out := squad.slot_summary(slot)
	if slot == PLAYER:
		var d := player.skill().d
		out.merge({"bot_d_start": d, "bot_d_mean": d, "bot_d_end": d, "dda_adjustments": 0,
			"bot_difficulty": BotDifficulty.preset_name(d), "bot_params_hash": player.skill().params_hash()}, true)
	return out


static func _skill(count: int, squad: BotSquad, player: BotController) -> Dictionary:
	var out := {PLAYER: player.skill().d}
	for i: int in range(1, count):
		out[i] = squad.bot(i).skill().d
	return out


## The app's TelemetrySetup, made reproducible: id from the index, fixed clock, dda variant.
static func _telemetry_setup(index: int, setup: MatchSetup, config: GameConfig, squad: BotSquad) -> Dictionary:
	var context := {"user_match_seq": index + 1}.merged(squad.context())
	var out := TelemetrySetup.from_match_setup(setup, config, context)
	out["match_id"] = match_uuid(index)
	out["started_at"] = Time.get_datetime_string_from_unix_time(BASE_UNIX + index * START_SPACING_S) + "Z"
	out["platform"] = PLATFORM
	out["build_version"] = BUILD
	return out


## Deterministic v4-shaped uuid for the index-th synthetic match.
static func match_uuid(index: int) -> String:
	return "5e7d0000-0000-4000-8000-%012d" % index
