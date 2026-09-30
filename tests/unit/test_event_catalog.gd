extends GutTest
## Amplitude event schema (platform A2, docs/tracking-plan.md): names and required properties.

const PLAN_EVENTS: Array[String] = [
	"app_opened", "app_backgrounded", "app_closed", "perf_sampled",
	"login_viewed", "login_started", "login_completed", "login_failed", "login_skipped", "session_restored",
	"logout",
	"screen_viewed", "mode_selected", "character_selected", "arena_selected", "select_cancelled",
	"match_started", "match_ended", "match_abandoned", "rematch_clicked",
	"stock_lost", "special_used", "special_hit", "gauge_full",
	"item_picked_up", "item_used", "item_hit", "gimmick_triggered", "gimmick_ringout",
	"settings_changed", "quality_changed", "input_device_changed", "touch_layout_changed", "net_error",
]


func test_catalog_covers_the_plan() -> void:
	for name: String in PLAN_EVENTS:
		assert_true(EventCatalog.has(name), "%s is in the catalog" % name)
	assert_eq(EventCatalog.names().size(), PLAN_EVENTS.size(), "no event outside the plan")


func test_valid_event_has_no_errors() -> void:
	assert_eq(EventCatalog.validate("screen_viewed", {"screen": "title"}).size(), 0)
	assert_eq(EventCatalog.validate("app_opened", {}).size(), 0)


func test_unknown_event_is_an_error() -> void:
	var errors := EventCatalog.validate("made_up", {})
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "made_up")


func test_missing_property_is_an_error() -> void:
	var errors := EventCatalog.validate("login_failed", {"provider": "google"})
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "reason")


func test_extra_properties_are_allowed() -> void:
	assert_eq(EventCatalog.validate("screen_viewed", {"screen": "title", "from": "login"}).size(), 0)


func test_values_must_be_json_safe() -> void:
	var errors := EventCatalog.validate("screen_viewed", {"screen": Vector3.ONE})
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "screen")
	assert_eq(EventCatalog.validate("net_error", {"endpoint": "x", "status": 0, "extra": {"a": [1, 2.5, "b"]}}).size(), 0)


func test_null_required_value_is_an_error() -> void:
	assert_eq(EventCatalog.validate("screen_viewed", {"screen": null}).size(), 1)
