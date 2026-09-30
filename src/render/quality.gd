class_name Quality
extends RefCounted
## Render quality levels (PRD-NFR-01, context F7). -1 in GameConfig.quality_level means the
## platform default: mobile MEDIUM, web LOW, desktop HIGH.

enum Level { LOW, MEDIUM, HIGH }

const TABLE := {
	Level.LOW: {"max_fps": 30, "shadows": false, "glow": false, "particle_scale": 0.5, "blob_shadows": true},
	Level.MEDIUM: {"max_fps": 60, "shadows": true, "glow": false, "particle_scale": 1.0, "blob_shadows": false},
	Level.HIGH: {"max_fps": 60, "shadows": true, "glow": true, "particle_scale": 1.0, "blob_shadows": false},
}
const AUTO := -1


static func resolve(config_level: int, platform_name: String) -> int:
	if config_level != AUTO:
		return clampi(config_level, Level.LOW, Level.HIGH)
	match platform_name:
		"mobile":
			return Level.MEDIUM
		"web":
			return Level.LOW
	return Level.HIGH


static func platform() -> String:
	if OS.has_feature("web"):
		return "web"
	if OS.has_feature("mobile"):
		return "mobile"
	return "desktop"


static func settings(level: int) -> Dictionary:
	return TABLE[clampi(level, Level.LOW, Level.HIGH)]


static func particle_scale(config: GameConfig) -> float:
	return float(settings(resolve(config.quality_level, platform()))["particle_scale"])
