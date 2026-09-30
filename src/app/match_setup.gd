class_name MatchSetup
extends RefCounted
## Everything a match needs to start (platform B1, docs/design.md DS-LAY-03): mode, arena, seed
## and one entry per slot {slot, character, controller: "local"|"bot", input_device}. Menu screens
## fill it (mode today, character and arena select later); MatchScene and telemetry only read it.

const MODE_BOT := "bot"
const MODE_LOCAL_2P := "local_2p"
const MODE_ONLINE := "online"
const ARENA_DEFAULT := ArenaCatalog.DEFAULT_ID
const CONTROLLER_LOCAL := "local"
const CONTROLLER_BOT := "bot"
const CONTROLLERS: Array[String] = [CONTROLLER_LOCAL, CONTROLLER_BOT]
const INPUT_BOT := "bot"
const DEFAULT_SEED := 1
const DEFAULT_PLAYERS := 2

var mode: String = MODE_BOT
var arena_id: String = ARENA_DEFAULT
var seed: int = DEFAULT_SEED
var slots: Array[Dictionary] = []


## One local player in local_slot_index, bots everywhere else (-1 = bots only).
static func vs_bots(player_count: int = DEFAULT_PLAYERS, p_seed: int = DEFAULT_SEED,
		local_slot_index: int = 0) -> MatchSetup:
	var s := MatchSetup.new()
	s.seed = p_seed
	for i: int in player_count:
		var is_local := i == local_slot_index
		s.slots.append(slot_entry(i, CONTROLLER_LOCAL if is_local else CONTROLLER_BOT,
				PlatformEnv.default_input_device() if is_local else INPUT_BOT))
	return s


## Bots only (menu backdrop, perf scenes).
static func all_bots(player_count: int, p_seed: int = DEFAULT_SEED) -> MatchSetup:
	return vs_bots(player_count, p_seed, -1)


static func slot_entry(slot: int, controller: String, input_device: String) -> Dictionary:
	return {"slot": slot, "character": String(CharacterCatalog.for_player(slot)["name"]),
		"controller": controller, "input_device": input_device}


## A fresh sim arena for arena_id (Phase 4 ArenaCatalog; unknown ids fall back to classic).
func build_arena(config: GameConfig) -> ArenaData:
	var arena := ArenaCatalog.build(arena_id, config) if ArenaCatalog.ids().has(arena_id) else null
	return arena if arena != null else ArenaCatalog.default(config)


func player_count() -> int:
	return slots.size()


## First local slot, or -1 when only bots play.
func local_slot() -> int:
	for s: Dictionary in slots:
		if s["controller"] == CONTROLLER_LOCAL:
			return int(s["slot"])
	return -1


func bot_slots() -> Array[int]:
	var out: Array[int] = []
	for s: Dictionary in slots:
		if s["controller"] == CONTROLLER_BOT:
			out.append(int(s["slot"]))
	return out


func copy() -> MatchSetup:
	var c := MatchSetup.new()
	c.mode = mode
	c.arena_id = arena_id
	c.seed = seed
	for s: Dictionary in slots:
		c.slots.append(s.duplicate())
	return c


## Empty when the setup can start a match; otherwise one message per problem.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if slots.is_empty():
		errors.append("no slots")
	if not ArenaCatalog.ids().has(arena_id):
		errors.append("unknown arena '%s'" % arena_id)
	for i: int in slots.size():
		var s := slots[i]
		if int(s.get("slot", -1)) != i:
			errors.append("slot %d: slot index must be %d" % [i, i])
		if not CONTROLLERS.has(String(s.get("controller", ""))):
			errors.append("slot %d: unknown controller '%s'" % [i, s.get("controller", "")])
	return errors
