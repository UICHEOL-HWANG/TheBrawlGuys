extends GutTest
## End to end without credentials (event schema 8): a real all-bot match runs through
## MatchTelemetry; every Amplitude event it sends validates against EventCatalog and survives the
## AnalyticsClient request body, the slot counters agree with the raw match_events rows, and the
## match_players rows carry the defense columns that migration 0004 declares.

const BotMatchRun := preload("res://tests/unit/support/bot_match_run.gd")
const FakeHttp := preload("res://tests/unit/support/fake_http_transport.gd")
const PLAYERS := 3
const SEED := 11
const MAX_TICKS := 60 * 240
## Raw event (type, kind or "") -> the slot counter it feeds and the row column naming the slot.
const RAW_TO_COUNTER: Array = [
	["dodge", "roll", "dodges_roll", "actor_slot"], ["dodge", "air", "dodges_air", "actor_slot"],
	["perfect_guard", "", "perfect_guards", "target_slot"], ["guard_break", "", "guard_breaks", "actor_slot"],
	["knockdown", "", "knockdowns", "actor_slot"], ["tech", "", "techs", "actor_slot"],
	["getup", "stand", "getups_stand", "actor_slot"], ["getup", "roll", "getups_roll", "actor_slot"],
	["getup", "attack", "getups_attack", "actor_slot"], ["hit", "", "hits_taken", "target_slot"],
]

var _run: Dictionary


func before_all() -> void:
	_run = BotMatchRun.play(ArenaCatalog.DEFAULT_ID, PLAYERS, SEED, MAX_TICKS)


func _telemetry() -> MatchTelemetry:
	return _run["telemetry"]


func _raw_count(type: String, kind: String, slot_key: String, slot: int) -> int:
	var n := 0
	for r: Dictionary in _telemetry().event_rows():
		if r["type"] == type and r[slot_key] == slot and (kind.is_empty() or r["payload"].get("kind") == kind):
			n += 1
	return n


func test_slot_counters_match_the_raw_rows() -> void:
	var rows := _telemetry().player_rows()
	assert_eq(rows.size(), PLAYERS)
	for spec: Array in RAW_TO_COUNTER:
		var total := 0
		for row: Dictionary in rows:
			var slot := int(row["slot"])
			assert_eq(int(row[spec[2]]), _raw_count(spec[0], spec[1], spec[3], slot), "%s slot %d" % [spec[2], slot])
			total += int(row[spec[2]])
		gut.p("%s = %d" % [spec[2], total])
	var hits_taken: int = rows.reduce(func(acc: int, r: Dictionary) -> int: return acc + int(r["hits_taken"]), 0)
	assert_gt(hits_taken, 0, "bots land hits in a full match")


func test_di_inputs_never_exceed_launches() -> void:
	for row: Dictionary in _telemetry().player_rows():
		assert_between(int(row["di_inputs"]), 0, int(row["hits_taken"]))
		gut.p("slot %d di_inputs %d / hits_taken %d" % [row["slot"], row["di_inputs"], row["hits_taken"]])


func test_the_match_finishes_with_knockdowns_tracked() -> void:
	assert_true((_run["world"] as World).match_over, "seed %d ends inside %d ticks" % [SEED, MAX_TICKS])
	var knockdowns := _telemetry().event_rows().filter(func(r: Dictionary) -> bool: return r["type"] == "knockdown")
	assert_gt(knockdowns.size(), 0, "launches tumble into knockdowns in a full bot match")


func test_every_amplitude_event_survives_the_request_body() -> void:
	var http := FakeHttp.new()
	var client := AnalyticsClient.new("test-key", "device-e2e", http, BatchQueue.new("", 500))
	var names: Array[String] = []
	for s: Array in _run["sent"]:
		assert_eq(EventCatalog.validate(s[0], s[1]), PackedStringArray(), String(s[0]))
		assert_true(client.track(s[0], s[1]), String(s[0]))
		names.append(String(s[0]))
		while http.pending_count() > 0:
			http.respond(200)
	var end_name := "match_ended" if names.has("match_ended") else "match_abandoned"
	assert_true(names.has(end_name))
	client.flush()
	while http.pending_count() > 0:
		http.respond(200)
	assert_eq(client.queued(), 0, "everything went out")
	var sent_end: Array = []
	for r: Dictionary in http.requests:
		var body: Dictionary = JSON.parse_string(String(r["body"]))
		sent_end.append_array((body["events"] as Array).filter(func(e: Dictionary) -> bool:
			return e["event_type"] == end_name))
	assert_eq(sent_end.size(), 1)
	if end_name == "match_ended":
		for p: Dictionary in sent_end[0]["event_properties"]["players"]:
			for key: String in EventCatalog.PLAYER_DEFENSE_KEYS:
				assert_true(p.has(key), "players[] carries %s" % key)
