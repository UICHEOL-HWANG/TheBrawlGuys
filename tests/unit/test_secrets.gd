extends GutTest
## Client key loader (platform A1): only public keys, missing values reported, never a service key.

const TMP_PATH := "user://test_secrets.cfg"


func after_each() -> void:
	if FileAccess.file_exists(TMP_PATH):
		DirAccess.remove_absolute(TMP_PATH)


func _cfg(amp: String, url: String, anon: String) -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.set_value("amplitude", "api_key", amp)
	cfg.set_value("supabase", "url", url)
	cfg.set_value("supabase", "anon_key", anon)
	cfg.set_value("auth", "redirect_web", "https://example.test/")
	cfg.set_value("auth", "loopback_port", 50000)
	return cfg


## A JWT-shaped token built at runtime so no token literal lives in a tracked file.
func _jwt(role: String) -> String:
	var head := _b64url(JSON.stringify({"alg": "HS256"}))
	return "%s.%s.sig" % [head, _b64url(JSON.stringify({"role": role}))]


func _b64url(text: String) -> String:
	return Marshalls.utf8_to_base64(text).replace("=", "").replace("+", "-").replace("/", "_")


func test_full_config_is_configured() -> void:
	var s := Secrets.from_config(_cfg("amp-key", "https://abc.supabase.co/", "sb_publishable_x"))
	assert_true(s.is_configured())
	assert_true(s.has_analytics())
	assert_true(s.has_supabase())
	assert_eq(s.supabase_url, "https://abc.supabase.co", "trailing slash trimmed")
	assert_eq(s.loopback_port, 50000)
	assert_eq(s.redirect_web, "https://example.test/")
	assert_eq(s.missing().size(), 0)


func test_missing_values_are_listed() -> void:
	var s := Secrets.from_config(_cfg("", "https://abc.supabase.co", ""))
	assert_false(s.is_configured())
	assert_false(s.has_analytics())
	assert_false(s.has_supabase())
	assert_eq(s.missing(), PackedStringArray(["amplitude.api_key", "supabase.anon_key"]))


func test_default_port_when_absent() -> void:
	assert_eq(Secrets.from_config(ConfigFile.new()).loopback_port, Secrets.DEFAULT_LOOPBACK_PORT)


func test_invalid_port_falls_back() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("auth", "loopback_port", "abc")
	assert_eq(Secrets.from_config(cfg).loopback_port, Secrets.DEFAULT_LOOPBACK_PORT)


func test_service_jwt_is_refused() -> void:
	var s := Secrets.from_config(_cfg("amp", "https://abc.supabase.co", _jwt(Secrets.SERVICE_ROLE)))
	assert_false(s.has_supabase(), "a service-role key must never be used by the client")
	assert_true(s.missing().has("supabase.anon_key"))
	assert_push_error("service-role")


func test_secret_key_prefix_is_refused() -> void:
	var s := Secrets.from_config(_cfg("amp", "https://abc.supabase.co", Secrets.SECRET_KEY_PREFIX + "abc"))
	assert_false(s.has_supabase())
	assert_push_error("service-role")


func test_anon_jwt_is_accepted() -> void:
	var s := Secrets.from_config(_cfg("amp", "https://abc.supabase.co", _jwt("anon")))
	assert_true(s.has_supabase())


func test_load_from_file() -> void:
	_cfg("amp", "https://abc.supabase.co", "sb_publishable_x").save(TMP_PATH)
	assert_true(Secrets.load_from(TMP_PATH).is_configured())


func test_missing_file_is_not_configured() -> void:
	var s := Secrets.load_from("user://does_not_exist.cfg")
	assert_false(s.is_configured())
	assert_eq(s.missing().size(), 3)


func test_example_file_is_committed_and_empty() -> void:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://config/secrets.example.cfg"), OK)
	assert_eq(String(cfg.get_value("amplitude", "api_key", "x")), "")
	assert_eq(String(cfg.get_value("supabase", "anon_key", "x")), "")
	assert_eq(int(cfg.get_value("auth", "loopback_port", 0)), Secrets.DEFAULT_LOOPBACK_PORT)


func test_local_file_is_ignored_and_exported() -> void:
	assert_true(FileAccess.get_file_as_string("res://.gitignore").contains("config/secrets.local.cfg"))
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	assert_gt(presets.count("include_filter="), 0)
	assert_eq(presets.count("include_filter=\"config/*.cfg\""), presets.count("include_filter="),
			"every preset exports config/*.cfg")


func test_check_all_runs_the_secret_scan() -> void:
	assert_true(FileAccess.get_file_as_string("res://scripts/check-all.sh").contains("check-secrets.sh"))
