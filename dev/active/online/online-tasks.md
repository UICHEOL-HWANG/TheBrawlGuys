# online — Tasks (Last Updated: 2026-10-01, N1 done)
Spec: docs/superpowers/specs/2026-10-01-online-p2p-design.md · interface: src/net/net_transport.gd
- [x] N1 netcode: protocol, loopback transport (lat/loss), host/client session, prediction+reconciliation, interpolation, disconnect→bot (feat/netcode)
  - src/net: protocol.gd (NetProtocol v1) · net_reader · setup_codec · loopback_hub/loopback_transport/net_delay_line · lagged_transport (debug sliders) · host_session + net_roster + remote_slot · client_session + prediction + interpolation · net_stats · net_match (extends main.gd; main.gd got `_step()`)
  - MatchSetup.CONTROLLER_REMOTE = "remote" (telemetry slots carry it); GameConfig "Net" group (NON_SIM, net_config.gd)
  - Measured: 4-player snapshot raw 6.8 KB → 1.3 KB zstd (≈38 KB/s per client at 30 Hz); INPUTS 31 B
  - Lobby API: host `var m := NetMatch.new(); m.host_match(transport, setup, {peer_id: slot}); add_child(m)` (setup: host slot "local", humans "remote", rest "bot"); client `m.join_match(transport)` (setup comes in WELCOME). Signals: menu_requested, connection_lost("host_left"). `net_stats()` → {net_host, rtt_p50, rtt_p95, corrections, disconnects} for N2 telemetry (no schema bump yet)
- [ ] N2 WebRTC transport + Supabase Realtime signaling + rooms migration 0005 + lobby/waiting-room UI + tracking (feat/online-lobby)
- [ ] N3 integrate N1+N2, two-tab browser e2e on deploy
- [ ] N4 desktop/Android webrtc-native plugin (needs download approval)
