class_name MatchSetup
extends RefCounted
## Everything a match needs to start (platform B1, docs/design.md DS-LAY-03): mode, arena, seed
## and one entry per slot {slot, character, controller: "local"|"bot"|"remote", input_device}. Menu screens
## fill it (mode, then the SELECT_STEPS: characters and arena); MatchScene and telemetry only read
## it. character is a CharacterData id ("" = the classic fighter). rule is the MatchRules mode
## (stock / team / timed, combat-depth D) picked on the rule select step; it sets the fighter
## count (RULE_PLAYERS, bots fill new slots) and build_rules turns it into the sim's MatchRules.

const MODE_BOT := "bot"
const MODE_LOCAL_2P := "local_2p"
const MODE_ONLINE := "online"
const ARENA_DEFAULT := ArenaCatalog.DEFAULT_ID
const CONTROLLER_LOCAL := "local"
const CONTROLLER_BOT := "bot"
## Online (Phase 6): a human on another device; its inputs arrive over the network (src/net).
const CONTROLLER_REMOTE := "remote"
const CONTROLLERS: Array[String] = [CONTROLLER_LOCAL, CONTROLLER_BOT, CONTROLLER_REMOTE]
const INPUT_BOT := "bot"
const INPUT_KEYBOARD := "keyboard"
## Humans in a local 2-player match (PRD-LOCAL-01): P1 and P2, always the first two slots.
const LOCAL_2P_HUMANS := 2
const DEFAULT_SEED := 1
const DEFAULT_PLAYERS := 2
## Fighters per rule: team 2v2 needs four, timed FFA plays four, stock keeps the 1v1 default.
const RULE_PLAYERS := {
	MatchRules.STOCK: DEFAULT_PLAYERS, MatchRules.TEAM: MatchRules.TEAM_PLAYERS, MatchRules.TIMED: 4,
}

var mode: String = MODE_BOT
var arena_id: String = ARENA_DEFAULT
var seed: int = DEFAULT_SEED
var rule: String = MatchRules.STOCK
var slots: Array[Dictionary] = []


## One local player in local_slot_index, bots everywhere else (-1 = bots only). Every slot starts
## as the classic fighter (CharacterData.DEFAULT) until the character select assigns characters.
static func vs_bots(player_count: int = DEFAULT_PLAYERS, p_seed: int = DEFAULT_SEED,
		local_slot_index: int = 0) -> MatchSetup:
	var s := MatchSetup.new()
	s.seed = p_seed
	for i: int in player_count:
		var is_local := i == local_slot_index
		s.slots.append(slot_entry(i, CONTROLLER_LOCAL if is_local else CONTROLLER_BOT,
				PlatformEnv.default_input_device() if is_local else INPUT_BOT))
	return s


## Local 2-player (PRD-LOCAL-01): P1 and P2 on slots 0 and 1 (P2 on the keyboard until a pad is
## assigned at match start), bots fill any slot after them.
static func local_versus(player_count: int = DEFAULT_PLAYERS, p_seed: int = DEFAULT_SEED) -> MatchSetup:
	var s := vs_bots(player_count, p_seed)
	s.mode = MODE_LOCAL_2P
	if player_count > 1:
		s.slots[1] = slot_entry(1, CONTROLLER_LOCAL, INPUT_KEYBOARD)
	return s


## Bots only (menu backdrop, perf scenes).
static func all_bots(player_count: int, p_seed: int = DEFAULT_SEED) -> MatchSetup:
	return vs_bots(player_count, p_seed, -1)


static func slot_entry(slot: int, controller: String, input_device: String) -> Dictionary:
	return {"slot": slot, "character": CharacterData.DEFAULT, "controller": controller,
		"input_device": input_device}


## Picks the rule (unknown ids play stock) and sizes the line-up for it: existing slots keep
## their controller and device, missing ones become bots, extra ones are dropped.
func set_rule(p_rule: String) -> void:
	rule = p_rule if MatchRules.MODES.has(p_rule) else MatchRules.STOCK
	var count: int = RULE_PLAYERS[rule]
	slots.resize(mini(slots.size(), count))
	for i: int in range(slots.size(), count):
		slots.append(slot_entry(i, CONTROLLER_BOT, INPUT_BOT))


## The sim rules for this setup (World.new), with the config's mode defaults.
func build_rules(config: GameConfig) -> MatchRules:
	return MatchRules.for_mode(rule, player_count(), config)


## A fresh World for this setup: seed, line-up, characters, arena and rules.
func build_world(config: GameConfig) -> World:
	return World.new(config, seed, player_count(), build_arena(config), characters(), build_rules(config))


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


## Every local slot in slot order (P1, P2, ...).
func local_slots() -> Array[int]:
	var out: Array[int] = []
	for s: Dictionary in slots:
		if s["controller"] == CONTROLLER_LOCAL:
			out.append(int(s["slot"]))
	return out


## slot -> input_device for local slots (the device each human plays with at match start); bot
## slots and unknown slots are left alone. Slot entries are replaced, never edited in place.
func set_input_devices(devices: Dictionary) -> void:
	for i: int in slots.size():
		var s := slots[i]
		if s["controller"] == CONTROLLER_LOCAL and devices.has(int(s["slot"])):
			var updated := s.duplicate()
			updated["input_device"] = String(devices[int(s["slot"])])
			slots[i] = updated


## Each slot's CharacterData id in slot order (what World.new and the fighter views take).
func characters() -> Array[String]:
	var out: Array[String] = []
	for s: Dictionary in slots:
		out.append(String(s["character"]))
	return out


## slot -> CharacterData id for the listed slots; others keep theirs. Entries are replaced.
func set_characters(picks: Dictionary) -> void:
	for i: int in slots.size():
		var slot := int(slots[i]["slot"])
		if picks.has(slot):
			slots[i] = slots[i].merged({"character": String(picks[slot])}, true)


## The humans' picks (slot -> id), then every bot slot gets a character the humans did not take,
## all different, drawn from the match seed (CharacterPicks): same seed and picks, same bots.
func assign_characters(human_picks: Dictionary) -> void:
	set_characters(human_picks)
	var taken: Array[String] = []
	for slot: Variant in human_picks:
		taken.append(String(human_picks[slot]))
	var bots := bot_slots()
	var drawn := CharacterPicks.for_bots(seed, taken, bots.size())
	var picks := {}
	for i: int in bots.size():
		picks[bots[i]] = drawn[i]
	set_characters(picks)


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
	c.rule = rule
	for s: Dictionary in slots:
		c.slots.append(s.duplicate())
	return c


## Empty when the setup can start a match; otherwise one message per problem.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if slots.is_empty():
		errors.append("no slots")
	if not MatchRules.MODES.has(rule):
		errors.append("unknown rule '%s'" % rule)
	elif rule == MatchRules.TEAM and slots.size() != MatchRules.TEAM_PLAYERS:
		errors.append("team rule needs %d slots" % MatchRules.TEAM_PLAYERS)
	if not ArenaCatalog.ids().has(arena_id):
		errors.append("unknown arena '%s'" % arena_id)
	for i: int in slots.size():
		var s := slots[i]
		if int(s.get("slot", -1)) != i:
			errors.append("slot %d: slot index must be %d" % [i, i])
		if not CONTROLLERS.has(String(s.get("controller", ""))):
			errors.append("slot %d: unknown controller '%s'" % [i, s.get("controller", "")])
		var character := String(s.get("character", CharacterData.DEFAULT))
		if character != CharacterData.DEFAULT and not CharacterData.IDS.has(character):
			errors.append("slot %d: unknown character '%s'" % [i, character])
	return errors
