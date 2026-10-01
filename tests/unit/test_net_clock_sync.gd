extends GutTest
## Client clock drift (Phase 6 netcode, NetClockSync): a client whose clock runs 1 % fast or slow
## for 60 s keeps the host's input queue near its target when synced — no starving (held inputs)
## and no folding (backlog drain) — while the same drift unsynced starves or piles up.

const NetRig := preload("res://tests/unit/support/net_rig.gd")
const HALF_MINUTE_TICKS := 1800
## Unsynced contrast runs: 2 × 15 s is enough to show the queue starving or piling up.
const SHORT_TICKS := 900


func _run(rate: float, sync: bool, settle: int = HALF_MINUTE_TICKS, measure: int = HALF_MINUTE_TICKS) -> Dictionary:
	var config := (load("res://src/config/default_config.tres") as GameConfig).duplicate() as GameConfig
	var rig := NetRig.new(config, 2, 1, 50.0, 10.0)
	rig.use_sync = sync
	rig.client_rates[0] = rate
	rig.connect_all()
	for t: int in settle:
		rig.tick()
	var slot := rig.host.roster.at(1)
	var starved := slot.starved
	var merged := slot.merged
	var queued := 0
	for t: int in measure:
		rig.tick()
		queued += slot.queued()
	return {"starved": slot.starved - starved, "merged": slot.merged - merged,
		"avg_queue": float(queued) / measure, "scale": rig.clients[0].tick_rate_scale()}


func test_scale_follows_the_reported_queue() -> void:
	var s := NetClockSync.new()
	assert_eq(s.scale(), 1.0, "no change before the first report")
	for i: int in 50:
		s.observe(6)
	assert_lt(s.scale(), 1.0, "queue too long: tick slower")
	assert_gte(s.scale(), 1.0 - NetClockSync.MAX_NUDGE)
	for i: int in 100:
		s.observe(0)
	assert_gt(s.scale(), 1.0, "starving: tick faster")
	assert_lte(s.scale(), 1.0 + NetClockSync.MAX_NUDGE)


func test_fast_client_stays_in_step_when_synced() -> void:
	var synced := _run(1.01, true)
	var free := _run(1.01, false, SHORT_TICKS, SHORT_TICKS)
	gut.p("1%% fast, 60 s: synced %s / unsynced %s" % [str(synced), str(free)])
	assert_lte(int(synced["merged"]), 3, "no backlog to drain")
	assert_lte(int(synced["starved"]), 3)
	assert_between(float(synced["avg_queue"]), 0.5, 4.0)
	assert_lt(float(synced["scale"]), 1.0, "the client slowed down")
	assert_gt(int(free["merged"]), 3, "without sync the extra inputs pile up and get folded")


func test_slow_client_stays_in_step_when_synced() -> void:
	var synced := _run(0.99, true)
	var free := _run(0.99, false, SHORT_TICKS, SHORT_TICKS)
	gut.p("1%% slow, 60 s: synced %s / unsynced %s" % [str(synced), str(free)])
	assert_lte(int(synced["starved"]), 3, "the host never runs out of inputs")
	assert_lte(int(synced["merged"]), 3)
	assert_gt(float(synced["scale"]), 1.0, "the client sped up")
	assert_gt(int(free["starved"]), 3, "without sync the host starves")
