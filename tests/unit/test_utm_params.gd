extends GutTest
## Campaign attribution (internal launch): utm_* query parameters of the web page become Amplitude
## user properties — the latest visit as utm_*, the first attributed visit as initial_utm_*.

const PATH := "user://test_install_utm.cfg"


func before_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_parse_keeps_only_utm_keys() -> void:
	var utm := UtmParams.parse("?utm_source=slack&utm_medium=internal&ref=x&utm_campaign=launch")
	assert_eq(utm, {"utm_source": "slack", "utm_medium": "internal", "utm_campaign": "launch"})


func test_parse_decodes_and_drops_empty_values() -> void:
	var utm := UtmParams.parse("utm_campaign=launch%20day&utm_term=&utm_content=a+b")
	assert_eq(utm, {"utm_campaign": "launch day", "utm_content": "a b"})


func test_parse_caps_value_length() -> void:
	var utm := UtmParams.parse("utm_source=" + "x".repeat(500))
	assert_eq(String(utm["utm_source"]).length(), UtmParams.MAX_LENGTH)


func test_parse_without_query_is_empty() -> void:
	assert_eq(UtmParams.parse(""), {})
	assert_eq(UtmParams.parse("?"), {})


func test_from_page_is_empty_outside_web() -> void:
	assert_eq(UtmParams.from_page(), {})


func test_attribution_stores_first_touch_once() -> void:
	var first := InstallInfo.new(PATH).attribution({"utm_source": "slack", "utm_campaign": "launch"})
	assert_eq(first, {"utm_source": "slack", "utm_campaign": "launch",
			"initial_utm_source": "slack", "initial_utm_campaign": "launch"})
	var later := InstallInfo.new(PATH).attribution({"utm_source": "email"})
	assert_eq(later, {"utm_source": "email",
			"initial_utm_source": "slack", "initial_utm_campaign": "launch"}, "first touch never moves")


func test_attribution_without_utm_keeps_first_touch_only() -> void:
	assert_eq(InstallInfo.new(PATH).attribution({}), {}, "organic visit sets nothing")
	InstallInfo.new(PATH).attribution({"utm_source": "slack"})
	assert_eq(InstallInfo.new(PATH).attribution({}), {"initial_utm_source": "slack"})
