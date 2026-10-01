class_name OnlineStart
extends RefCounted
## The one seam between the online lobby (feat/online-lobby) and the netcode (feat/netcode,
## NetMatch). The waiting room calls begin() on every device when the host presses 시작 (the host
## directly, clients on the signaling `start` broadcast). Integration = replace this file's body.
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
## Returns the match scene to push (the App shows it like a local match and connects its
## `menu_requested` signal), or null to stay in the lobby — the stub always returns null.

const PENDING_TEXT := "온라인 대전 준비 중이에요 — 곧 열려요"


static func begin(transport: NetTransport, is_host: bool, setup: MatchSetup, slot_map: Dictionary) -> Node:
	print("OnlineStart.begin (stub until NetMatch): host=%s local=%d peers=%s rule=%s arena=%s slots=%d map=%s"
			% [is_host, transport.local_id(), transport.peers(), setup.rule, setup.arena_id,
				setup.player_count(), slot_map])
	return null
