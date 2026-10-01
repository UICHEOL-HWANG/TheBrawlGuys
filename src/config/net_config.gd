class_name NetConfig
extends Resource
## Online match tunables (Phase 6 netcode, src/net). GameConfig extends StyleConfig extends ... extends
## ModeConfig extends this, so every value is a GameConfig value with a debug panel slider. "Net" is a
## NON_SIM group: none of it changes how a World ticks, only how often it is sent and how it is shown.

@export_group("Net")
## Host snapshot rate (per second); the host ticks at 60 Hz and sends every 60 / rate ticks.
@export_range(10, 60, 1) var net_snapshot_hz: int = 30
## Seconds a disconnected player's slot waits for a reconnect before a bot takes it over.
@export_range(0.0, 30.0, 0.5) var net_disconnect_grace: float = 5.0
## Remote fighters are drawn this far behind the newest snapshot (ms).
@export_range(0.0, 300.0, 5.0) var net_interp_delay_ms: float = 100.0
## Most unacknowledged inputs a client re-simulates after a snapshot (PRD §5.6 budget).
@export_range(1, 60, 1) var net_max_resim_ticks: int = 15
## Own-fighter position error (m) after a snapshot that counts as a prediction correction.
@export_range(0.0, 1.0, 0.01) var net_correction_threshold: float = 0.05
## Past inputs repeated in every INPUTS message (covers lost packets).
@export_range(1, 30, 1) var net_input_redundancy: int = 8
## Inputs the host keeps queued per client before dropping the oldest (bounds added latency).
@export_range(1, 30, 1) var net_input_buffer_max: int = 6
## Debug network conditions added on this side (LaggedTransport): one-way latency, jitter, and
## loss of the unreliable channel. 0 = off.
@export_range(0.0, 500.0, 5.0) var net_sim_latency_ms: float = 0.0
@export_range(0.0, 200.0, 5.0) var net_sim_jitter_ms: float = 0.0
@export_range(0.0, 50.0, 0.5) var net_sim_loss_pct: float = 0.0
