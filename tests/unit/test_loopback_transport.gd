extends GutTest
## LoopbackHub / LoopbackTransport / NetDelayLine / LaggedTransport (Phase 6 netcode).

const FAST := NetTransport.CHANNEL_FAST
const RELIABLE := NetTransport.CHANNEL_RELIABLE


func _bytes(n: int) -> PackedByteArray:
	return PackedByteArray([n])


func _values(msgs: Array[Dictionary]) -> Array:
	return msgs.map(func(m: Dictionary) -> int: return int((m["bytes"] as PackedByteArray)[0]))


func test_star_topology_and_room_limit() -> void:
	var hub := LoopbackHub.new()
	var host := hub.host()
	var clients: Array[LoopbackTransport] = []
	for i: int in LoopbackHub.MAX_CLIENTS:
		clients.append(hub.join())
	assert_null(hub.join(), "a fourth client does not fit")
	assert_eq(host.local_id(), 1)
	assert_eq(host.peers(), PackedInt32Array([2, 3, 4]))
	assert_eq(clients[0].peers(), PackedInt32Array([1]))
	host.send(0, RELIABLE, _bytes(9))
	for c: LoopbackTransport in clients:
		assert_eq(_values(c.poll()), [9], "broadcast reaches every client")
	clients[1].send(0, RELIABLE, _bytes(5))
	assert_eq(_values(host.poll()), [5])
	assert_eq(_values(clients[0].poll()), [], "clients never hear each other")


func test_latency_holds_messages_until_due() -> void:
	var hub := LoopbackHub.new()
	hub.set_conditions(100.0)
	var host := hub.host()
	var c := hub.join()
	c.send(1, FAST, _bytes(1))
	hub.advance(99.0)
	assert_eq(host.poll().size(), 0)
	hub.advance(1.0)
	assert_eq(_values(host.poll()), [1])
	assert_eq(host.rtt_ms(c.local_id()), 200.0)


func test_loss_hits_only_the_fast_channel() -> void:
	var hub := LoopbackHub.new(3)
	hub.set_conditions(0.0, 0.0, 50.0)
	var host := hub.host()
	var c := hub.join()
	for i: int in 200:
		c.send(1, FAST, _bytes(i % 256))
		c.send(1, RELIABLE, _bytes(i % 256))
	var fast := 0
	var reliable := 0
	for m: Dictionary in host.poll():
		if int(m["channel"]) == FAST:
			fast += 1
		else:
			reliable += 1
	assert_eq(reliable, 200)
	assert_between(fast, 60, 140, "about half the fast messages are lost")


func test_jitter_keeps_reliable_order_and_drops_overtaken_fast() -> void:
	var hub := LoopbackHub.new(5)
	hub.set_conditions(20.0, 80.0)
	var host := hub.host()
	var c := hub.join()
	for i: int in 50:
		c.send(1, RELIABLE, _bytes(i))
		c.send(1, FAST, _bytes(i))
		hub.advance(5.0)
	hub.advance(500.0)
	var reliable := []
	var fast := []
	for m: Dictionary in host.poll():
		(fast if int(m["channel"]) == FAST else reliable).append(int((m["bytes"] as PackedByteArray)[0]))
	assert_eq(reliable, range(50))
	var sorted := fast.duplicate()
	sorted.sort()
	assert_eq(fast, sorted, "fast messages never arrive out of order")
	assert_lt(fast.size(), 50, "overtaken fast messages were dropped")


func test_same_seed_same_run() -> void:
	assert_eq(_lossy_run(11), _lossy_run(11))


func _lossy_run(seed: int) -> Array:
	var hub := LoopbackHub.new(seed)
	hub.set_conditions(10.0, 30.0, 20.0)
	var host := hub.host()
	var c := hub.join()
	for i: int in 100:
		c.send(1, FAST, _bytes(i))
		hub.advance(3.0)
	hub.advance(100.0)
	return _values(host.poll())


func test_disconnect_signals_the_other_side() -> void:
	var hub := LoopbackHub.new()
	var host := hub.host()
	var c := hub.join()
	watch_signals(host)
	c.send(1, RELIABLE, _bytes(1))
	c.send(1, FAST, _bytes(2))
	host.send(2, RELIABLE, _bytes(3))
	c.close()
	assert_signal_emitted_with_parameters(host, "peer_disconnected", [2])
	assert_eq(_values(host.poll()), [1], "a graceful close still delivers the leaver's reliable messages only")
	assert_eq(host.peers().size(), 0)
	var c2 := hub.join()
	watch_signals(c2)
	host.close()
	assert_signal_emitted_with_parameters(c2, "peer_disconnected", [1])


func test_lagged_transport_delays_both_ways() -> void:
	var hub := LoopbackHub.new()
	var host := hub.host()
	var c := hub.join()
	var config := (load("res://src/config/default_config.tres") as GameConfig).duplicate() as GameConfig
	config.net_sim_latency_ms = 50.0
	var now := [0]
	var lagged := LaggedTransport.new(c, config, func() -> int: return now[0])
	assert_true(LaggedTransport.wanted(config))
	lagged.send(1, RELIABLE, _bytes(1))
	assert_eq(host.poll().size(), 0, "held back on the way out")
	now[0] = 50
	lagged.poll()
	assert_eq(_values(host.poll()), [1])
	host.send(2, RELIABLE, _bytes(2))
	assert_eq(lagged.poll().size(), 0, "held back on the way in")
	now[0] = 100
	assert_eq(_values(lagged.poll()), [2])
	config.net_sim_latency_ms = 0.0
	lagged.send(1, RELIABLE, _bytes(3))
	assert_eq(_values(host.poll()), [3], "no lag configured: sent at once")
