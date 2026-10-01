extends GutTest
## Room signaling state machine (Phase 6): hello → id + offer → answer / ice → leave, routed over
## an in-memory broadcast bus that delivers each send to every other side (like Realtime with
## self: false).

var _host: RoomSignaling
var _a: RoomSignaling
var _b: RoomSignaling
var _log: Array = []
var _sent: Array = []


func before_each() -> void:
	_log.clear()
	_sent.clear()
	_host = _side(true, "s-host", "host")
	_a = _side(false, "s-a", "a")
	_b = _side(false, "s-b", "b")


func _side(is_host: bool, session: String, tag: String) -> RoomSignaling:
	var s := RoomSignaling.new(is_host, session)
	s.send = func(event: String, payload: Dictionary) -> bool:
		_sent.append([tag, event, payload])
		for other: RoomSignaling in [_host, _a, _b]:
			if other != s:
				other.handle(event, JSON.parse_string(JSON.stringify(payload)))  # JSON numbers, like the wire
		return true
	s.peer_hello.connect(func(id: int, info: Dictionary) -> void: _log.append([tag, "hello", id, info.get("name")]))
	s.assigned.connect(func(id: int) -> void: _log.append([tag, "assigned", id]))
	s.rejected.connect(func(reason: String) -> void: _log.append([tag, "rejected", reason]))
	s.description.connect(func(id: int, type: String, sdp: String) -> void: _log.append([tag, type, id, sdp]))
	s.candidate.connect(func(id: int, mid: String, i: int, n: String) -> void: _log.append([tag, "ice", id, mid, i, n]))
	s.peer_left.connect(func(id: int) -> void: _log.append([tag, "left", id]))
	s.pick.connect(func(id: int, choice: Dictionary) -> void: _log.append([tag, "pick", id, choice]))
	s.lobby_state.connect(func(state: Dictionary) -> void: _log.append([tag, "lobby", state]))
	return s


func _events_of(tag: String) -> Array:
	return _log.filter(func(e: Array) -> bool: return e[0] == tag)


func test_hello_gets_the_next_id_and_the_offer_assigns_it() -> void:
	_a.hello({"name": "A"}, 0)
	_b.hello({"name": "B"}, 0)
	assert_eq(_events_of("host"), [["host", "hello", 2, "A"], ["host", "hello", 3, "B"]])
	_host.send_description(3, "offer", "sdp-b")
	assert_eq(_events_of("b"), [["b", "assigned", 3], ["b", "offer", 1, "sdp-b"]])
	assert_eq(_events_of("a"), [], "an offer for another session is not ours")
	assert_eq(_b.local_id, 3)
	assert_eq(_a.local_id, 0)


func test_repeated_hello_is_one_peer_and_hello_repeats_until_assigned() -> void:
	_a.hello({"name": "A"}, 0)
	_a.tick(RoomSignaling.HELLO_REPEAT_MS - 1)
	_a.tick(RoomSignaling.HELLO_REPEAT_MS)
	assert_eq(_sent.filter(func(s: Array) -> bool: return s[1] == "hello").size(), 2)
	assert_eq(_events_of("host").size(), 1, "the host counts one peer")
	_host.send_description(2, "offer", "x")
	_a.tick(RoomSignaling.HELLO_REPEAT_MS * 5)
	assert_eq(_sent.filter(func(s: Array) -> bool: return s[1] == "hello").size(), 2, "assigned: no more hello")


func test_answer_and_ice_reach_the_addressed_side_only() -> void:
	_a.hello({}, 0)
	_b.hello({}, 0)
	_host.send_description(2, "offer", "o")
	_host.send_description(3, "offer", "o")
	_log.clear()
	_a.send_description(1, "answer", "ans-a")
	_a.send_candidate(1, "0", 0, "cand-a")
	_host.send_candidate(3, "0", 1, "cand-h")
	assert_eq(_events_of("host"), [["host", "answer", 2, "ans-a"], ["host", "ice", 2, "0", 0, "cand-a"]])
	assert_eq(_events_of("b"), [["b", "ice", 1, "0", 1, "cand-h"]])
	assert_eq(_events_of("a"), [])


func test_spoofed_sender_is_ignored_by_the_host() -> void:
	_a.hello({}, 0)
	_host.send_description(2, "offer", "o")
	_log.clear()
	_host.handle("answer", {"from": 2, "to": 1, "session": "s-evil", "sdp": "x"})
	assert_eq(_events_of("host"), [])


func test_reject_reaches_only_that_client_and_is_forgotten() -> void:
	_a.hello({}, 0)
	_host.reject(2, "full")
	assert_eq(_events_of("a").back(), ["a", "rejected", "full"])
	assert_eq(_events_of("b"), [])
	_a.hello({}, 10_000)
	assert_eq(_events_of("host").back()[2], 3, "a later hello is a new peer")


func test_leave_lobby_pick_and_start() -> void:
	_a.hello({}, 0)
	_host.send_description(2, "offer", "o")
	_a.send_pick({"character": "rogue", "ready": true})
	assert_eq(_events_of("host").back(), ["host", "pick", 2, {"character": "rogue", "ready": true}])
	_host.send_lobby({"rule": "stock"})
	assert_eq(_events_of("a").back(), ["a", "lobby", {"rule": "stock"}])
	_a.leave()
	assert_eq(_events_of("host").back(), ["host", "left", 2])
	_host.leave()
	assert_eq(_events_of("a").back(), ["a", "left", 1], "the host leaving reaches clients")


func test_a_client_only_trusts_the_host_session_it_pinned() -> void:
	_a.hello({}, 0)
	_host.send_description(2, "offer", "o")
	_log.clear()
	for event: String in ["leave", "lobby", "start"]:
		_a.handle(event, {"from": 1, "to": 0, "session": "s-evil", "state": {}, "data": {}})
	_a.handle("offer", {"from": 1, "to": 3, "session": "s-evil", "to_session": "s-a", "sdp": "x"})
	_a.handle("reject", {"from": 1, "to": 0, "session": "s-evil", "to_session": "s-a", "reason": "full"})
	assert_eq(_events_of("a"), [], "a fake host is ignored")
	assert_eq(_a.local_id, 2)


func test_a_first_offer_must_come_from_peer_1_with_a_client_id() -> void:
	_b.handle("offer", {"from": 3, "to": 2, "session": "s-x", "to_session": "s-b", "sdp": "x"})
	_b.handle("offer", {"from": 1, "to": 1, "session": "s-x", "to_session": "s-b", "sdp": "x"})
	assert_eq(_events_of("b"), [])
	assert_eq(_b.local_id, 0)


func test_own_echo_is_ignored() -> void:
	_host.handle("hello", {"from": 0, "to": 1, "session": "s-host"})
	assert_eq(_log, [])
