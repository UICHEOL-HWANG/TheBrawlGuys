class_name PresentationConfig
extends StyleConfig
## The non-sim GameConfig groups (bot, feel, loop, camera, touch, look, quality, VFX, audio),
## split out of game_config.gd to keep it short. None of them is in GameConfig.SIM_GROUPS, so
## moving them changes no fingerprint; every value is still a GameConfig value with a debug
## panel slider.

@export_group("Bot")
@export_range(0.5, 5.0, 0.1) var bot_attack_range: float = 1.4
## Bot n swings at bot_attack_range - n % 4 * spread, so mirrored bots do not trade forever.
@export_range(0.0, 0.5, 0.01) var bot_attack_range_spread: float = 0.1
@export_range(0, 120, 1) var bot_attack_cooldown_ticks: int = 30
@export_range(0.3, 1.0, 0.01) var bot_edge_ratio: float = 0.8
@export_range(0.5, 6.0, 0.1) var bot_guard_range: float = 2.2
@export_range(1, 90, 1) var bot_guard_ticks: int = 34
@export_range(0.0, 20.0, 0.5) var bot_item_seek_range: float = 8.0
@export_range(1.0, 15.0, 0.5) var bot_throw_range: float = 6.0
## Bots never walk where this far ahead of them has no floor (bridge gaps, edges).
@export_range(0.1, 3.0, 0.05) var bot_ground_lookahead: float = 0.6

@export_group("Feel")
@export_range(0.0, 0.2, 0.001) var shake_per_knockback: float = 0.02
@export_range(0.0, 3.0, 0.05) var shake_max: float = 0.6
@export_range(0.5, 30.0, 0.5) var shake_decay: float = 8.0
@export_range(1.0, 30.0, 0.5) var blink_hz: float = 10.0
@export_range(1.0, 40.0, 0.5) var blink_hz_end: float = 20.0
@export_range(0.0, 40.0, 0.5) var spark_large_threshold: float = 8.0

@export_group("Loop")
@export_range(1, 10, 1) var max_ticks_per_frame: int = 5

@export_group("Camera")
@export_range(30.0, 85.0, 0.5) var cam_pitch: float = 42.0
@export_range(0.0, 10.0, 0.1) var cam_margin: float = 1.5
## Fraction of the arena radius the camera always keeps in frame (1 = whole arena).
@export_range(0.2, 1.0, 0.05) var cam_arena_share: float = 0.2
@export_range(5.0, 40.0, 0.5) var cam_zoom_min: float = 7.0
@export_range(10.0, 150.0, 0.5) var cam_zoom_max: float = 70.0
@export_range(0.0, 20.0, 0.1) var cam_smooth: float = 6.0
@export_range(10.0, 70.0, 0.5) var cam_fov: float = 40.0
## Share of the top HUD's height the match camera keeps the fight out of (HudSafeFrame); 0 = off.
@export_range(0.0, 1.5, 0.05) var cam_hud_reserve: float = 1.0
## Menu backdrop orbit (design.md DS-LAY-03): yaw speed, a lower pitch than the match camera so
## the fighters read, the arena core kept in frame, the zoom floor of that close framing, and how
## fast the orbit pivot drifts after the fight (per second, slower than cam_smooth).
@export_range(0.0, 30.0, 0.5) var menu_orbit_deg_per_s: float = 6.0
@export_range(10.0, 60.0, 0.5) var menu_orbit_pitch: float = 24.0
@export_range(0.2, 1.5, 0.05) var menu_orbit_arena_share: float = 0.5
@export_range(4.0, 40.0, 0.5) var menu_orbit_zoom_min: float = 8.0
@export_range(0.0, 10.0, 0.1) var menu_orbit_follow: float = 1.2
## Menu depth fog (design.md DS-LAY-03 haze): exponential density.
@export_range(0.0, 0.2, 0.002) var menu_fog_density: float = 0.03

@export_group("Touch")
@export_range(0.05, 0.5, 0.01) var touch_hold_threshold: float = 0.15
@export_range(60.0, 300.0, 5.0) var touch_stick_radius: float = 140.0
@export_range(0.0, 0.5, 0.01) var touch_stick_deadzone: float = 0.15
@export_range(96.0, 300.0, 2.0) var touch_attack_diameter: float = 170.0
@export_range(96.0, 300.0, 2.0) var touch_jump_diameter: float = 130.0
## 0 = arc around attack, 1 = diamond, 2 = 2x2 grid (design.md DS-LAY-01, E9).
@export_range(0, 2, 1) var touch_layout: int = 0
@export_range(96.0, 300.0, 2.0) var touch_side_diameter: float = 116.0

@export_group("Look")
## Character look preset for the gate: 0 = A, 1 = B, 2 = C (context F6).
@export_range(0, 2, 1) var look_preset: int = 0

@export_group("Quality")
## -1 = platform default (mobile MEDIUM, web LOW, desktop HIGH); 0 LOW, 1 MEDIUM, 2 HIGH (context F7).
@export_range(-1, 2, 1) var quality_level: int = -1

@export_group("FeelVfx")
## Knockback trail (design.md GD-FEEL-04): off below threshold, full strength at full (m/s).
@export_range(1.0, 40.0, 0.5) var trail_speed_threshold: float = 9.0
@export_range(2.0, 60.0, 0.5) var trail_speed_full: float = 20.0
## Landing dust (DS-VFX-03) by fall speed (m/s).
@export_range(0.0, 20.0, 0.5) var dust_min_fall_speed: float = 4.0
@export_range(1.0, 40.0, 0.5) var dust_full_fall_speed: float = 14.0
## Comic hit impact (DS-VFX-01 v2): knockback at or above this is a medium hit (heavy starts at
## spark_large_threshold). Heavy hits punch the camera in by this fraction of the ring-out punch.
@export_range(0.0, 40.0, 0.5) var impact_medium_threshold: float = 4.0
@export_range(0.0, 1.0, 0.05) var impact_heavy_punch: float = 0.35
## Floating damage numbers above the victim (DS-VFX-09): 1 = on, 0 = off.
@export_range(0, 1, 1) var damage_popups: int = 1

@export_group("Audio")
@export_range(-40.0, 6.0, 0.5) var sfx_volume_db: float = 0.0
@export_range(-40.0, 6.0, 0.5) var music_volume_db: float = -6.0
@export_range(-40.0, 6.0, 0.5) var ui_volume_db: float = -3.0
## Hit pitch drops by this much per knockback unit (heavier = lower, design.md DS-SFX-01).
@export_range(0.0, 0.1, 0.001) var sfx_pitch_per_knockback: float = 0.02
## Seconds for the last-stock intensity layer to fade in or out (context F10).
@export_range(0.1, 5.0, 0.1) var music_intense_fade: float = 1.2
