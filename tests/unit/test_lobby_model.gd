extends GutTest
## The online waiting room's state (Phase 6): seats, ready, bots, connection, when the host may
## start, the state round trip and the MatchSetup / slot map OnlineStart.begin receives.

var _m: LobbyModel


func before_each() -> void:
	_m = LobbyModel.new()


func _two_ready_connected() -> void:
	_m.add_human(1)
	_m.add_human(2)
	_m.set_conn(2, LobbyModel.CONN_CONNECTED, 30)
	_m.set_pick(1, CharacterData.KNIGHT, true)
	_m.set_pick(2, CharacterData.MAGE, true)


func test_humans_take_the_lowest_free_seats_and_four_fill_the_room() -> void:
	assert_eq(_m.add_human(1), 0)
	assert_eq(_m.slots[0]["conn"], LobbyModel.CONN_CONNECTED, "the host is here")
	assert_eq(_m.add_human(2), 1)
	assert_eq(_m.slots[1]["conn"], LobbyModel.CONN_CONNECTING)
	assert_eq(_m.add_human(2), 1, "same peer, same seat")
	_m.add_human(3)
	_m.add_human(4)
	assert_eq(_m.add_human(5), -1, "full")
	assert_eq(_m.remove_peer(2), 1)
	assert_eq(_m.add_human(5), 1, "a freed seat is reused")
	_m.remove_peer(5)
	assert_eq(_m.slot_of(0), -1, "an unassigned client (id 0) has no seat, even with an empty one")


func test_start_needs_two_ready_connected_humans() -> void:
	_m.add_human(1)
	assert_eq(_m.start_block(), LobbyModel.BLOCK_PLAYERS)
	_m.add_human(2)
	assert_eq(_m.start_block(), LobbyModel.BLOCK_READY)
	_m.set_pick(1, CharacterData.KNIGHT, true)
	_m.set_pick(2, CharacterData.MAGE, true)
	assert_eq(_m.start_block(), LobbyModel.BLOCK_CONNECTING)
	_m.set_conn(2, LobbyModel.CONN_CONNECTED, 30)
	assert_true(_m.can_start())
	_m.set_pick(2, CharacterData.MAGE, false)
	assert_false(_m.can_start())


func test_bots_fill_empty_seats_and_give_way_to_humans() -> void:
	_two_ready_connected()
	_m.set_bots(true)
	assert_eq(_m.bot_count(), 2)
	assert_true(_m.can_start(), "bots are always ready")
	assert_eq(_m.add_human(3), 2, "a human takes a bot seat")
	assert_eq(_m.bot_count(), 1)
	_m.set_bots(false)
	assert_eq(_m.bot_count(), 0)
	assert_eq(_m.human_count(), 3)


func test_unknown_picks_and_conn_states_are_ignored() -> void:
	_m.add_human(1)
	_m.set_pick(1, "dragon", true)
	assert_false(bool(_m.slots[0]["ready"]))
	_m.set_conn(1, "teleported")
	assert_eq(_m.slots[0]["conn"], LobbyModel.CONN_CONNECTED)


func test_state_round_trip_survives_json_and_sanitizes() -> void:
	_two_ready_connected()
	_m.rule = MatchRules.TIMED
	_m.arena = "log_bridge"
	var copy := LobbyModel.new()
	copy.from_state(JSON.parse_string(JSON.stringify(_m.to_state())))
	assert_eq(copy.rule, MatchRules.TIMED)
	assert_eq(copy.arena, "log_bridge")
	assert_eq(int(copy.slots[1]["peer"]), 2)
	assert_eq(copy.slots[1]["character"], CharacterData.MAGE)
	assert_eq(int(copy.slots[1]["rtt"]), 30)
	assert_true(copy.can_start())
	copy.from_state({"slots": ["junk", {"peer": 3, "character": "dragon", "conn": "??"}], "rule": "chess"})
	assert_eq(int(copy.slots[0]["peer"]), LobbyModel.EMPTY)
	assert_eq(copy.slots[1]["character"], CharacterData.IDS[0])
	assert_eq(copy.slots[1]["conn"], LobbyModel.CONN_NONE)
	assert_eq(copy.rule, MatchRules.TIMED, "an unknown rule keeps the last one")


func test_build_setup_and_slot_map_for_each_device() -> void:
	_two_ready_connected()
	_m.set_bots(true)
	var host := _m.build_setup(1, 77)
	assert_eq(host.mode, MatchSetup.MODE_ONLINE)
	assert_eq(host.seed, 77)
	assert_eq(host.validate().size(), 0, str(host.validate()))
	var controllers: Array = host.slots.map(func(s: Dictionary) -> String: return s["controller"])
	assert_eq(controllers, ["local", "remote", "bot", "bot"])
	var client := _m.build_setup(2, 77)
	assert_eq(client.slots.map(func(s: Dictionary) -> String: return s["controller"]), ["remote", "local", "bot", "bot"])
	assert_eq(client.characters(), host.characters(), "every device gets the same line-up")
	assert_eq(client.characters()[1], CharacterData.MAGE)
	assert_eq(_m.slot_map(), {1: 0, 2: 1})


func test_team_rule_fills_four_and_gaps_compact() -> void:
	_m.add_human(1)
	_m.add_human(2)
	_m.add_human(3)
	_m.remove_peer(2)
	_m.rule = MatchRules.TEAM
	var setup := _m.build_setup(1, 1)
	assert_eq(setup.player_count(), MatchRules.TEAM_PLAYERS)
	assert_eq(setup.validate().size(), 0)
	assert_eq(_m.slot_map(), {1: 0, 3: 1}, "the empty seat is skipped")
