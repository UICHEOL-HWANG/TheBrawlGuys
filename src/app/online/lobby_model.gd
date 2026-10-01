class_name LobbyModel
extends RefCounted
## The online waiting room's state (Phase 6, PRD-NET-03): up to MAX_SLOTS slots, each a human
## peer (peer id ≥ 1, the host is 1), a bot (BOT) or empty (EMPTY), with character, ready and the
## connection status + rtt. The host owns it and broadcasts to_state(); clients mirror it with
## from_state(). build_setup / slot_map are what OnlineStart.begin receives.

const MAX_SLOTS := 4
const MIN_HUMANS := 2
const HOST_ID := 1
const EMPTY := 0
const BOT := -1
const CONN_NONE := ""
const CONN_CONNECTING := "connecting"
const CONN_CONNECTED := "connected"
const CONN_FAILED := "failed"
const CONNS: Array[String] = [CONN_NONE, CONN_CONNECTING, CONN_CONNECTED, CONN_FAILED]
const BLOCK_PLAYERS := "2명 이상 모여야 시작할 수 있어요"
const BLOCK_READY := "모두 준비하면 시작할 수 있어요"
const BLOCK_CONNECTING := "연결 중인 플레이어가 있어요"

var slots: Array[Dictionary] = []
var rule: String = MatchRules.STOCK
var arena: String = ArenaCatalog.STAGE_IDS[0]


func _init() -> void:
	for i: int in MAX_SLOTS:
		slots.append(_slot(EMPTY))


## The lowest free slot for peer_id (or the one it has); -1 when the room is full.
func add_human(peer_id: int) -> int:
	var at := slot_of(peer_id)
	if at >= 0:
		return at
	for i: int in MAX_SLOTS:
		if int(slots[i]["peer"]) <= EMPTY:  # empty or a bot: a human takes the seat
			slots[i] = _slot(peer_id)
			slots[i]["conn"] = CONN_CONNECTED if peer_id == HOST_ID else CONN_CONNECTING
			return i
	return -1


func remove_peer(peer_id: int) -> int:
	var at := slot_of(peer_id)
	if at >= 0:
		slots[at] = _slot(EMPTY)
	return at


## The seat of a human peer (ids ≥ 1); -1 otherwise (0 = not assigned yet, never an empty seat).
func slot_of(peer_id: int) -> int:
	if peer_id < HOST_ID:
		return -1
	for i: int in MAX_SLOTS:
		if int(slots[i]["peer"]) == peer_id:
			return i
	return -1


func set_pick(peer_id: int, character: String, ready: bool) -> void:
	var at := slot_of(peer_id)
	if at < 0 or not CharacterData.IDS.has(character):
		return
	slots[at] = slots[at].merged({"character": character, "ready": ready}, true)


func set_conn(peer_id: int, conn: String, rtt: int = -1) -> void:
	var at := slot_of(peer_id)
	if at >= 0 and CONNS.has(conn):
		slots[at] = slots[at].merged({"conn": conn, "rtt": rtt}, true)


## Bots on every empty slot (on) or every bot slot emptied (off).
func set_bots(on: bool) -> void:
	for i: int in MAX_SLOTS:
		var peer := int(slots[i]["peer"])
		if on and peer == EMPTY:
			slots[i] = _slot(BOT)
		elif not on and peer == BOT:
			slots[i] = _slot(EMPTY)


func has_bots() -> bool:
	return bot_count() > 0


func human_count() -> int:
	return _count(func(peer: int) -> bool: return peer >= HOST_ID)


func bot_count() -> int:
	return _count(func(peer: int) -> bool: return peer == BOT)


func can_start() -> bool:
	return start_block().is_empty()


## "" when the host may start; otherwise why not (shown under 시작).
func start_block() -> String:
	if human_count() < MIN_HUMANS:
		return BLOCK_PLAYERS
	for s: Dictionary in slots:
		var peer := int(s["peer"])
		if peer >= HOST_ID and not bool(s["ready"]):
			return BLOCK_READY
		if peer > HOST_ID and s["conn"] != CONN_CONNECTED:
			return BLOCK_CONNECTING
	return ""


func to_state() -> Dictionary:
	return {"slots": slots.duplicate(true), "rule": rule, "arena": arena}


## Mirrors the host's state; malformed entries become empty slots.
func from_state(state: Dictionary) -> void:
	var raw: Variant = state.get("slots", [])
	for i: int in MAX_SLOTS:
		var s: Variant = (raw as Array)[i] if raw is Array and i < (raw as Array).size() else null
		slots[i] = _sanitized(s)
	if MatchRules.MODES.has(String(state.get("rule", ""))):
		rule = String(state["rule"])
	if ArenaCatalog.ids().has(String(state.get("arena", ""))):
		arena = String(state["arena"])


## The match line-up: occupied slots in order (team rule: bots fill up to four).
func build_setup(local_peer: int, seed: int) -> MatchSetup:
	var setup := MatchSetup.new()
	setup.mode = MatchSetup.MODE_ONLINE
	setup.seed = seed
	setup.rule = rule
	setup.arena_id = arena
	for s: Dictionary in slots:
		var peer := int(s["peer"])
		if peer == EMPTY:
			continue
		var controller := MatchSetup.CONTROLLER_BOT if peer == BOT else (
				MatchSetup.CONTROLLER_LOCAL if peer == local_peer else MatchSetup.CONTROLLER_REMOTE)
		var entry := MatchSetup.slot_entry(setup.slots.size(), controller,
				PlatformEnv.default_input_device() if peer == local_peer else MatchSetup.INPUT_BOT)
		entry["character"] = String(s["character"])
		setup.slots.append(entry)
	while rule == MatchRules.TEAM and setup.slots.size() < MatchRules.TEAM_PLAYERS:
		setup.slots.append(MatchSetup.slot_entry(setup.slots.size(), MatchSetup.CONTROLLER_BOT, MatchSetup.INPUT_BOT))
	return setup


## peer id -> slot index in build_setup's line-up, humans only.
func slot_map() -> Dictionary:
	var out := {}
	var index := 0
	for s: Dictionary in slots:
		var peer := int(s["peer"])
		if peer >= HOST_ID:
			out[peer] = index
		if peer != EMPTY:
			index += 1
	return out


func _count(pred: Callable) -> int:
	var n := 0
	for s: Dictionary in slots:
		if pred.call(int(s["peer"])):
			n += 1
	return n


static func _slot(peer: int) -> Dictionary:
	return {"peer": peer, "character": CharacterData.IDS[0], "ready": peer == BOT, "conn": CONN_NONE, "rtt": -1}


static func _sanitized(s: Variant) -> Dictionary:
	if not (s is Dictionary):
		return _slot(EMPTY)
	var d: Dictionary = s
	var out := _slot(maxi(int(d.get("peer", EMPTY)), BOT))
	if CharacterData.IDS.has(String(d.get("character", ""))):
		out["character"] = String(d["character"])
	out["ready"] = bool(d.get("ready", false))
	out["conn"] = String(d.get("conn", "")) if CONNS.has(String(d.get("conn", ""))) else CONN_NONE
	out["rtt"] = int(d.get("rtt", -1))
	return out
