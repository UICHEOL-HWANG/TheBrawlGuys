class_name BotSquadFactory
extends RefCounted
## Builds the app's BotSquad for a MatchSetup (PRD-BOT-06): humans are the non-bot slots, the
## dda variant comes from the [bots] dda setting ("on" / "off" / "auto"; auto = A/B bucket of the
## device id against dda_on_share), the probe runs while the device rating holds fewer than
## dda_probe_matches observations, and the models load once from res://data/models/.
## Headless and test runs never touch user:// (in-memory rating, fixed bucket key).

const WIN_PROB_PATH := "res://data/models/win_prob.json"
const ESTIMATOR_PATH := "res://data/models/skill_estimator.json"
const SETTINGS_SECTION := "bots"
const SETTINGS_KEY := "dda"
const AUTO := "auto"
const BUCKET_SALT := "dda"
const HEADLESS_KEY := "headless"

static var _models := {}
static var _rating: SkillRating = null


static func for_setup(setup: MatchSetup, config: GameConfig, rating: SkillRating = null) -> BotSquad:
	var humans: Array[int] = []
	for s: Dictionary in setup.slots:
		if s["controller"] != MatchSetup.CONTROLLER_BOT:
			humans.append(int(s["slot"]))
	var r := rating if rating != null else shared_rating()
	var live := PlatformEnv.is_live()
	var setting := String(SettingsStore.new().get_value(SETTINGS_SECTION, SETTINGS_KEY, AUTO)) if live else AUTO
	var key := DeviceId.load_or_create() if live else HEADLESS_KEY
	return BotSquad.new(config, setup.bot_slots(), humans, {
		"variant": variant(config, setting, key), "rating": r, "probe": r.matches() < config.dda_probe_matches,
		"win_prob": model(WIN_PROB_PATH), "estimator": model(ESTIMATOR_PATH)})


## "on" / "off" for a device: a forced setting wins, else the bucket of hash(device key).
static func variant(config: GameConfig, setting: String, device_key: String) -> String:
	if config.dda_enabled == 0:
		return BotSquad.OFF
	if setting == BotSquad.ON or setting == BotSquad.OFF:
		return setting
	var bucket := posmod(hash([device_key, BUCKET_SALT]), 100)
	return BotSquad.ON if bucket < int(round(config.dda_on_share * 100.0)) else BotSquad.OFF


## One rating store per run (live: user://skill.cfg).
static func shared_rating() -> SkillRating:
	if _rating == null:
		_rating = SkillRating.create_default()
	return _rating


## The model at path, loaded once (null when missing).
static func model(path: String) -> LinearModel:
	if not _models.has(path):
		_models[path] = LinearModel.load_json(path)
	return _models[path]
