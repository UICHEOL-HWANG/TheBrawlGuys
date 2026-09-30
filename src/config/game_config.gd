class_name GameConfig
extends Resource
## Value ownership: GameConfig holds gameplay/feel tunables exposed on the debug panel.
## Art-direction constants (prop counts, light energies, mesh sizes) stay as named consts
## in render code; colors and UI sizes live only in DS tokens (src/ui/theme/tokens.gd).
## Every tunable number lives here. The debug panel builds a slider for each @export_range.
## Initial values: docs/PRD.md §4.5. Camera rules: docs/design.md GD-CAM-01.

@export_group("Movement")
@export_range(1.0, 20.0, 0.1) var move_speed: float = 6.0
@export_range(1.0, 25.0, 0.1) var jump_velocity: float = 9.0
@export_range(-80.0, -5.0, 0.5) var gravity: float = -25.0
@export_range(1, 4, 1) var max_jumps: int = 2
## Airborne steering toward the input direction (m/s^2); with no input only air_drag applies,
## so launched fighters keep their momentum after hitstun ends.
@export_range(0.0, 80.0, 0.5) var air_acceleration: float = 20.0
@export_range(0.0, 40.0, 0.5) var air_drag: float = 2.0

@export_group("Fighter")
@export_range(0.2, 1.0, 0.01) var fighter_radius: float = 0.45
@export_range(0.8, 3.0, 0.05) var fighter_height: float = 1.6
@export_range(0.0, 1.0, 0.01) var hitstun_ground_friction: float = 0.85

@export_group("Arena")
@export_range(4.0, 20.0, 0.1) var arena_radius: float = 10.0
@export_range(-30.0, -2.0, 0.5) var kill_y: float = -8.0

@export_group("Rules")
@export_range(1, 9, 1) var stocks: int = 3
@export_range(1.0, 20.0, 0.5) var respawn_height: float = 6.0
@export_range(0.0, 5.0, 0.1) var respawn_invuln: float = 2.0
@export_range(2.0, 40.0, 0.5) var blast_margin: float = 12.0

@export_group("Knockback")
@export_range(0.0, 10.0, 0.01) var global_knockback_mul: float = 1.7
@export_range(0.0, 0.2, 0.001) var hitstun_factor: float = 0.04
@export_range(0.0, 0.3, 0.005) var hitstop_light: float = 0.06
@export_range(0.0, 0.3, 0.005) var hitstop_heavy: float = 0.1
@export_range(0.0, 1.0, 0.01) var guard_damage_mul: float = 0.2
@export_range(0.0, 1.0, 0.01) var guard_knockback_mul: float = 0.0

@export_group("LightAttack")
@export_range(0.0, 30.0, 0.5) var light_damage: float = 4.0
@export_range(0.0, 30.0, 0.1) var light_base_knockback: float = 3.0
@export_range(0.0, 0.5, 0.005) var light_knockback_scaling: float = 0.05
@export_range(0.0, 2.0, 0.05) var light_launch_angle_y: float = 0.6
@export_range(0, 30, 1) var light_startup_ticks: int = 3
@export_range(1, 30, 1) var light_active_ticks: int = 3
@export_range(0, 60, 1) var light_recovery_ticks: int = 8
@export_range(0.0, 3.0, 0.05) var light_hitbox_forward: float = 0.8
@export_range(0.0, 3.0, 0.05) var light_hitbox_up: float = 0.9
@export_range(0.1, 2.0, 0.05) var light_hitbox_half_width: float = 0.45
@export_range(0.1, 2.0, 0.05) var light_hitbox_half_height: float = 0.45

@export_group("Combo")
## A light press while the current light hit has at most this many ticks left queues the next hit (E2).
@export_range(0, 30, 1) var combo_buffer_ticks: int = 10
## Hits 1-2 of the light combo are link hits: small flat knockback plus a hitstun floor so the
## next hit connects. Hit 3 is the finisher and uses the LightAttack values above (E1).
@export_range(0.0, 30.0, 0.5) var light_link_damage: float = 3.0
@export_range(0.0, 30.0, 0.1) var light_link_base_knockback: float = 1.5
@export_range(0.0, 2.0, 0.05) var light_link_launch_angle_y: float = 0.0
@export_range(0, 60, 1) var light_link_hitstun_ticks: int = 18

@export_group("HeavyAttack")
@export_range(0.0, 40.0, 0.5) var heavy_damage: float = 12.0
@export_range(0.0, 30.0, 0.1) var heavy_base_knockback: float = 6.0
@export_range(0.0, 0.5, 0.005) var heavy_knockback_scaling: float = 0.12
@export_range(0.0, 2.0, 0.05) var heavy_launch_angle_y: float = 0.7
@export_range(0, 40, 1) var heavy_startup_ticks: int = 8
@export_range(1, 30, 1) var heavy_active_ticks: int = 4
@export_range(0, 60, 1) var heavy_recovery_ticks: int = 18
@export_range(0.0, 3.0, 0.05) var heavy_hitbox_forward: float = 1.0
@export_range(0.0, 3.0, 0.05) var heavy_hitbox_up: float = 0.9
@export_range(0.1, 2.0, 0.05) var heavy_hitbox_half_width: float = 0.6
@export_range(0.1, 2.0, 0.05) var heavy_hitbox_half_height: float = 0.55
## Holding heavy charges up to this long; the multiplier grows linearly to heavy_charge_max_mul (E3).
@export_range(0.1, 3.0, 0.05) var heavy_charge_max_time: float = 1.0
@export_range(1.0, 3.0, 0.05) var heavy_charge_max_mul: float = 1.6

@export_group("Grab")
@export_range(0, 30, 1) var grab_startup_ticks: int = 4
@export_range(1, 30, 1) var grab_active_ticks: int = 4
@export_range(0, 60, 1) var grab_recovery_ticks: int = 16
@export_range(0.0, 3.0, 0.05) var grab_forward: float = 0.8
@export_range(0.1, 2.0, 0.05) var grab_half_width: float = 0.45
## A hold that is not thrown ends by itself after this long (E5).
@export_range(0.2, 5.0, 0.1) var grab_hold_max_time: float = 1.5
## Distance from the holder to the held fighter while holding.
@export_range(0.5, 2.0, 0.05) var grab_hold_distance: float = 0.95
@export_range(0.0, 30.0, 0.5) var throw_damage: float = 8.0
@export_range(0.0, 30.0, 0.1) var throw_base_knockback: float = 7.0
@export_range(0.0, 0.5, 0.005) var throw_knockback_scaling: float = 0.1
@export_range(0.0, 2.0, 0.05) var throw_launch_angle_y: float = 0.5

@export_group("Items")
@export_range(1.0, 60.0, 0.5) var item_spawn_min_time: float = 10.0
@export_range(1.0, 60.0, 0.5) var item_spawn_max_time: float = 15.0
@export_range(0, 6, 1) var item_max_on_field: int = 2
## Boxes land within this fraction of the arena radius.
@export_range(0.1, 1.0, 0.05) var item_spawn_radius_ratio: float = 0.7
## Drop height; 12 m under the default gravity falls in about 1 s (DS-VIS-05 shadow warning).
@export_range(2.0, 30.0, 0.5) var item_drop_height: float = 12.0
@export_range(0.3, 3.0, 0.05) var item_pickup_radius: float = 1.2
@export_range(0.1, 1.0, 0.05) var item_radius: float = 0.35
@export_range(2.0, 40.0, 0.5) var item_throw_speed: float = 14.0
@export_range(0.0, 20.0, 0.5) var item_throw_up: float = 4.0
@export_range(1, 20, 1) var bat_uses: int = 5
@export_range(0.0, 40.0, 0.5) var bat_damage: float = 10.0
@export_range(0.0, 30.0, 0.1) var bat_base_knockback: float = 8.0
@export_range(0.0, 0.5, 0.005) var bat_knockback_scaling: float = 0.1
@export_range(0.0, 2.0, 0.05) var bat_launch_angle_y: float = 0.5
## Startup equals the light attack so a bat swung into a light attack trades instead of being
## interrupted (Phase 3 carry-over); the longer recovery keeps a whiffed swing punishable.
@export_range(0, 40, 1) var bat_startup_ticks: int = 3
@export_range(1, 30, 1) var bat_active_ticks: int = 4
@export_range(0, 60, 1) var bat_recovery_ticks: int = 18
@export_range(0.0, 3.0, 0.05) var bat_hitbox_forward: float = 1.2
@export_range(0.1, 2.0, 0.05) var bat_hitbox_half_width: float = 0.6
## Lit on throw; explodes this long after (the throw tick counts as the first tick, E7).
@export_range(0.5, 6.0, 0.1) var bomb_fuse_time: float = 2.0
@export_range(0.5, 8.0, 0.1) var bomb_radius: float = 2.5
@export_range(0.0, 40.0, 0.5) var bomb_damage: float = 15.0
@export_range(0.0, 30.0, 0.1) var bomb_base_knockback: float = 9.0
@export_range(0.0, 0.5, 0.005) var bomb_knockback_scaling: float = 0.12
@export_range(0.0, 2.0, 0.05) var bomb_launch_angle_y: float = 0.8
## Thrown rocks and thrown bats hit with these numbers.
@export_range(0.0, 40.0, 0.5) var rock_damage: float = 6.0
@export_range(0.0, 30.0, 0.1) var rock_base_knockback: float = 5.0
@export_range(0.0, 0.5, 0.005) var rock_knockback_scaling: float = 0.08
@export_range(0.0, 2.0, 0.05) var rock_launch_angle_y: float = 0.3

@export_group("Arena Gimmicks")
## Campfire (PRD-ARENA-01): touching it burns for burn_duration, burn_damage % at once and then
## every burn_interval while the burn lasts.
@export_range(0.0, 20.0, 0.5) var burn_damage: float = 2.0
@export_range(0.1, 3.0, 0.05) var burn_interval: float = 0.5
@export_range(0.1, 10.0, 0.1) var burn_duration: float = 2.0
## Feet higher than this above the fire (m) jump over it unharmed.
@export_range(0.1, 3.0, 0.05) var burn_reach_height: float = 1.0
## Log bridge planks (PRD-ARENA-02): first crack at start + order * interval, cracked for
## warn_time, gone for respawn_time, back for rebreak_time before cracking again.
@export_range(1.0, 120.0, 0.5) var platform_break_start_time: float = 20.0
@export_range(0.5, 60.0, 0.5) var platform_break_interval: float = 6.0
@export_range(0.1, 5.0, 0.05) var platform_warn_time: float = 1.5
@export_range(1.0, 60.0, 0.5) var platform_respawn_time: float = 12.0
@export_range(1.0, 120.0, 0.5) var platform_rebreak_time: float = 30.0
## Hits taken by fighters standing on a plank (and explosions over it) that crack it early.
@export_range(1, 40, 1) var platform_hits_to_break: int = 6
## Mushroom (PRD-ARENA-03) launch speed straight up (m/s); ~3x the jump height at 16.
@export_range(5.0, 40.0, 0.5) var bounce_speed: float = 16.0
## Fog (PRD-ARENA-04): first fog at first_time, lasting duration, repeating every period.
@export_range(0.0, 120.0, 0.5) var fog_first_time: float = 15.0
@export_range(1.0, 120.0, 0.5) var fog_period: float = 30.0
@export_range(0.5, 60.0, 0.5) var fog_duration: float = 10.0

@export_group("Bot")
@export_range(0.5, 5.0, 0.1) var bot_attack_range: float = 1.4
## Bot n swings at bot_attack_range - n % 4 * spread, so mirrored bots do not trade forever.
@export_range(0.0, 0.5, 0.01) var bot_attack_range_spread: float = 0.1
@export_range(0, 120, 1) var bot_attack_cooldown_ticks: int = 30
@export_range(0.3, 1.0, 0.01) var bot_edge_ratio: float = 0.8
@export_range(0.5, 6.0, 0.1) var bot_guard_range: float = 2.2
@export_range(1, 90, 1) var bot_guard_ticks: int = 20
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
@export_range(30.0, 85.0, 0.5) var cam_pitch: float = 60.0
@export_range(0.0, 10.0, 0.1) var cam_margin: float = 3.0
## Fraction of the arena radius the camera always keeps in frame (1 = whole arena).
@export_range(0.2, 1.0, 0.05) var cam_arena_share: float = 0.6
@export_range(5.0, 40.0, 0.5) var cam_zoom_min: float = 14.0
@export_range(10.0, 150.0, 0.5) var cam_zoom_max: float = 70.0
@export_range(0.0, 20.0, 0.1) var cam_smooth: float = 6.0
@export_range(10.0, 70.0, 0.5) var cam_fov: float = 40.0
## Menu backdrop orbit (design.md DS-LAY-03): yaw speed and the arena share kept in frame.
@export_range(0.0, 30.0, 0.5) var menu_orbit_deg_per_s: float = 6.0
@export_range(0.5, 1.5, 0.05) var menu_orbit_arena_share: float = 1.0

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


## Groups whose values change the simulation. Only these enter the fingerprint (context F1):
## camera, touch, feel, bot, loop and later presentation groups never alter a replay, so they
## can be tuned or added without invalidating snapshots and replay hashes.
const SIM_GROUPS: Array[String] = [
	"Movement", "Fighter", "Arena", "Rules", "Knockback", "LightAttack", "Combo", "HeavyAttack", "Grab", "Items",
	"Arena Gimmicks",
]

@export_group("Audio")
@export_range(-40.0, 6.0, 0.5) var sfx_volume_db: float = 0.0
@export_range(-40.0, 6.0, 0.5) var music_volume_db: float = -6.0
@export_range(-40.0, 6.0, 0.5) var ui_volume_db: float = -3.0
## Hit pitch drops by this much per knockback unit (heavier = lower, design.md DS-SFX-01).
@export_range(0.0, 0.1, 0.001) var sfx_pitch_per_knockback: float = 0.02
## Seconds for the last-stock intensity layer to fade in or out (context F10).
@export_range(0.1, 5.0, 0.1) var music_intense_fade: float = 1.2

const NON_SIM_GROUPS: Array[String] = ["Bot", "Feel", "Loop", "Camera", "Touch", "Look", "Quality", "FeelVfx", "Audio"]


## Hash of every sim-group variable (Phase 1 D1, scoped in Phase 3 F1). Snapshots and replays
## store it so a run can only be restored or verified against the same sim tuning.
func fingerprint() -> int:
	var values: Array = []
	var group := ""
	for p: Dictionary in get_property_list():
		var usage := int(p["usage"])
		if usage & PROPERTY_USAGE_GROUP:
			group = String(p["name"])
			continue
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and SIM_GROUPS.has(group):
			values.append([p["name"], get(p["name"])])
	return hash(values)


static func group_names() -> Array[String]:
	var names: Array[String] = []
	var in_script := false
	for p: Dictionary in GameConfig.new().get_property_list():
		var usage := int(p["usage"])
		if usage & PROPERTY_USAGE_CATEGORY:
			in_script = String(p["name"]) == "game_config.gd"
		elif in_script and usage & PROPERTY_USAGE_GROUP:
			names.append(String(p["name"]))
	return names
