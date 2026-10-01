# online — Tasks (Last Updated: 2026-10-01)
Spec: docs/superpowers/specs/2026-10-01-online-p2p-design.md · interface: src/net/net_transport.gd
- [ ] N1 netcode: protocol, loopback transport (lat/loss), host/client session, prediction+reconciliation, interpolation, disconnect→bot (feat/netcode)
- [x] N2 WebRTC transport + Supabase Realtime signaling + rooms migration 0005 + lobby/waiting-room UI + tracking (feat/online-lobby)
  - src/net/webrtc (WebRtcTransport, WebRtcPeerLink, WebRtcSupport), src/net/signaling (PhoenixMessage, RealtimeChannel, WsPort, RoomSignaling), src/net/rooms (RoomCode, RoomsApi)
  - src/app/online (LobbyModel, RoomPeers, OnlineRoom, OnlineFlow, **OnlineStart = the N3 seam: replace its body with NetMatch**), screens OnlineMenuScreen / WaitingRoomScreen, components RoomCodeInput (DS-CMP-11) / ConnectionBadge (DS-CMP-13)
  - verified: live Realtime smoke `godot --headless --path . -s scripts/smoke_realtime.gd` PASS; real browser WebRTC (web export, two transports in one page) PASS, rtt ~22 ms
  - known limits: Realtime join uses the access token captured at join (no mid-lobby token refresh; tokens last ~1 h); `reject` before the host is pinned is trusted (public channel, anyone with the code could kick a joining client); Toast (DS-CMP-13) not built
  - user: run supabase/migrations/0005_rooms.sql; Realtime broadcast must be on (default). Lobby `start` broadcast carries {seed, state}; clients call OnlineStart.begin on it.
- [ ] N3 integrate N1+N2, two-tab browser e2e on deploy
- [ ] N4 desktop/Android webrtc-native plugin (needs download approval)
