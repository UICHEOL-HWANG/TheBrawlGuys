class_name OnlineStart
extends RefCounted
## The one seam between the online lobby (src/app/online) and the netcode (src/net, NetMatch).
## The waiting room calls begin() on every device when the host presses 시작 (the host directly,
## clients on the signaling `start` broadcast); it returns that device's NetMatch scene.
##
## What begin receives:
## - transport: a connected WebRtcTransport (NetTransport). Host: local_id() 1, peers() = every
##   client whose data channels are open. Client: local_id() = its assigned id (≥ 2), peers() =
##   [1]. The lobby keeps calling transport.service() until the scene it gets back takes over;
##   from then on the match must call poll() every frame (it drains everything received so far,
##   including messages the host sent before the client's match existed). rtt_ms(peer) is live.
## - is_host: true on peer 1 (runs the authoritative World).
## - setup: MatchSetup with mode "online", the host's seed, rule and arena_id, and one slot per
##   fighter in slot order: controller "local" (this device's player), "remote" (a human on
##   another device) or "bot" (simulated by the host); character set for every slot (bots
##   included); input_device is this device's default for the local slot, "bot" otherwise.
##   Every device gets the same line-up (only which slot is "local" differs).
## - slot_map: peer id (int) -> slot index (int) for every human, host included, e.g.
##   {1: 0, 2: 1}. Bots are not in it.
## Returns the NetMatch to push (the App shows it like a local match and connects its
## `menu_requested` signal; a lost connection asks for the menu too), or null to stay in the lobby.
## The host waits up to net_join_wait for every client's HELLO before its World starts.

const START_FAILED_TEXT := "온라인 대전을 시작하지 못했어요 — 다시 시도해 주세요"


static func begin(transport: NetTransport, is_host: bool, setup: MatchSetup, slot_map: Dictionary) -> Node:
	if transport == null or (is_host and setup == null):
		return null
	var scene := NetMatch.new()
	if is_host:
		var peer_slots := slot_map.duplicate()
		peer_slots.erase(transport.local_id())  # the host's own slot is "local"
		scene.host_match(transport, setup, peer_slots)
	else:
		scene.join_match(transport)  # the setup comes from the host in WELCOME
	scene.connection_lost.connect(scene.menu_requested.emit.unbind(1))
	return scene
