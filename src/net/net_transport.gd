class_name NetTransport
extends RefCounted
## Peer-to-peer message transport for online matches (Phase 6, docs/superpowers/specs/
## 2026-10-01-online-p2p-design.md). The host is peer 1; clients get ids from the transport.
## Netcode (HostSession / ClientSession) only talks to this interface, so tests use
## LoopbackTransport and the game uses WebRtcTransport. Never touched by src/sim.

## Unreliable, ordered: inputs and snapshots (late data is dropped, not resent).
const CHANNEL_FAST := 0
## Reliable, ordered: join/leave, setup, match start/end, chat-free control messages.
const CHANNEL_RELIABLE := 1

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)


## This side's peer id (1 = host).
func local_id() -> int:
	return 0


func peers() -> PackedInt32Array:
	return PackedInt32Array()


## Sends bytes to one peer (0 = every connected peer).
func send(_peer_id: int, _channel: int, _bytes: PackedByteArray) -> void:
	pass


## Drains received messages since the last call: [{"from": int, "channel": int, "bytes": PackedByteArray}].
func poll() -> Array[Dictionary]:
	return []


## Round-trip estimate to a peer in ms (-1 when unknown).
func rtt_ms(_peer_id: int) -> float:
	return -1.0


func close() -> void:
	pass
