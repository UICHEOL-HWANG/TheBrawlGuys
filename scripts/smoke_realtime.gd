extends SceneTree
## Live smoke test for online signaling (Phase 6): two RealtimeChannels open their own sockets to
## the project's Supabase Realtime (config/secrets.local.cfg, anon key, no user token), join one
## throwaway room topic, and each must receive the other's broadcast — then a RoomSignaling
## hello → offer round trip runs over them. Prints PASS / FAIL; exit code 0 / 1.
##   godot --headless --path . -s scripts/smoke_realtime.gd

const TIMEOUT_MS := 20_000

var _a: RealtimeChannel
var _b: RealtimeChannel
var _got: Array = []
var _deadline: int = 0
var _done: bool = false


func _init() -> void:
	var secrets := Secrets.load_from()
	if not secrets.has_supabase():
		_finish(false, "no supabase url / anon key in config/secrets.local.cfg")
		return
	var url := PhoenixMessage.socket_url(secrets.supabase_url, secrets.supabase_anon_key)
	var topic := PhoenixMessage.topic_for("room:SMK" + RoomCode.generate().substr(0, 3))
	print("smoke: ", topic)
	_a = _channel("a")
	_b = _channel("b")
	var now := Time.get_ticks_msec()
	_deadline = now + TIMEOUT_MS
	_a.open(url, topic, "", now)
	_b.open(url, topic, "", now)
	_wire_signaling()


func _channel(tag: String) -> RealtimeChannel:
	var ch := RealtimeChannel.new()
	ch.joined.connect(func() -> void: print("smoke: %s joined" % tag))
	ch.failed.connect(func(reason: String) -> void: _finish(false, "%s failed: %s" % [tag, reason]))
	ch.message.connect(func(event: String, payload: Dictionary) -> void: _got.append([tag, event, payload]))
	return ch


func _wire_signaling() -> void:
	var host := RoomSignaling.new(true, Uuid.v4())
	var client := RoomSignaling.new(false, Uuid.v4())
	host.send = _a.broadcast
	client.send = _b.broadcast
	_a.message.connect(host.handle)
	_b.message.connect(client.handle)
	host.peer_hello.connect(func(id: int, _info: Dictionary) -> void: host.send_description(id, "offer", "smoke-sdp"))
	client.assigned.connect(func(id: int) -> void: _got.append(["client", "assigned", {"id": id}]))
	_a.joined.connect(func() -> void: _maybe_hello(client))
	_b.joined.connect(func() -> void: _maybe_hello(client))


func _maybe_hello(client: RoomSignaling) -> void:
	if _a.is_joined() and _b.is_joined():
		_a.broadcast("ping", {"from": "a"})
		_b.broadcast("ping", {"from": "b"})
		client.hello({"name": "smoke"}, Time.get_ticks_msec())


func _process(_delta: float) -> bool:
	if _done:
		return true
	var now := Time.get_ticks_msec()
	for ch: RealtimeChannel in [_a, _b]:
		if ch != null:
			ch.poll(now)
	var tags := _got.map(func(g: Array) -> String: return "%s:%s" % [g[0], g[1]])
	if tags.has("a:ping") and tags.has("b:ping") and tags.has("client:assigned"):
		_finish(true, "both sides got each other's broadcast; hello → offer assigned a peer id")
	elif now > _deadline:
		_finish(false, "timeout; received %s" % [tags])
	return false


func _finish(ok: bool, message: String) -> void:
	if _done:
		return
	_done = true
	print("smoke: %s — %s" % ["PASS" if ok else "FAIL", message])
	for ch: RealtimeChannel in [_a, _b]:
		if ch != null:
			ch.close()
	quit(0 if ok else 1)
