# Online match (WebRTC P2P, host-authoritative) — Design

Approved 2026-10-01 (user chose WebRTC P2P over Supabase relay / dedicated server; Vercel cannot host it).
Supersedes the dedicated-server topology of PRD §5.5 for now; code keeps the server seam so a headless
server can replace the host later.

## Topology
- Host peer (id 1) runs `World` at 60 Hz. Clients send `InputFrame`s (+ last N redundant) on CHANNEL_FAST.
- Host broadcasts snapshots 20–30 Hz (WorldCodec, delta/quantized) + sim events on CHANNEL_FAST; control on CHANNEL_RELIABLE.
- Client predicts its own fighter (restore last snapshot + reapply unacked inputs), interpolates others ~100 ms.
- Disconnect: grace period then bot takes the slot. Host leaving ends the match ("방장이 나갔습니다").

## Layers (src/net/, never imported by src/sim)
- `net_transport.gd` (interface, committed) · `loopback_transport.gd` (in-memory pair/star with latency/loss sim)
- `protocol.gd` (binary messages) · `host_session.gd` · `client_session.gd` · `prediction.gd` · `interpolation.gd`
- `webrtc/webrtc_transport.gd` (WebRTCMultiplayer-free raw WebRTCPeerConnection + data channels)
- `signaling/` Supabase Realtime broadcast channel per room for offer/answer/ICE; `rooms` table (code, host uid, status, player_count, expires_at) with RLS, migration 0005.
- ICE: public Google STUN; TURN servers configurable via secrets (empty by default).

## UI
Menu → 온라인 → 방 만들기 (6-char code) / 코드 입력 → 대기실 (players, character select, ready; host picks rule/arena, bots fill) → match → results → back to lobby.

## Tracking
Online match: controller "remote", rtt p50/p95, disconnects + reason, prediction corrections count, host flag.

## Platforms
Web first (browser WebRTC built in). Desktop/Android need the webrtc-native GDExtension (download needs user confirmation) — step 3.

## Testing
GUT with LoopbackTransport (latency/loss/jitter), determinism host vs client, two-tab browser e2e on the deployed build.

## Limits
Host can cheat (no ranked until a dedicated server). TURN absent → ~10% of networks may fail to connect.
