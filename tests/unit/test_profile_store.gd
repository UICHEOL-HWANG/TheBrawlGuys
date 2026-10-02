extends GutTest
## Player profile (onboarding): the nickname cached on the device ([profile] nickname) and kept in
## Supabase profiles.display_name — GET for the prefill, PATCH on save (own row via RLS). HTTP is a fake.

const FakeHttp := preload("res://tests/unit/support/fake_http_transport.gd")
const URL := "https://proj.supabase.co"
const PATH := "user://test_profile_store.cfg"
const UID := "11111111-2222-3333-4444-555555555555"

var _http: FakeHttp
var _client: SupabaseClient
var _net_errors: Array = []


func before_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	_http = FakeHttp.new()
	_net_errors.clear()
	_client = SupabaseClient.new(URL, "anon-key", _http)
	_client.now_s = func() -> int: return 1_700_000_000
	_client.session = SupabaseSession.new("access-1", "refresh-1", 1_700_009_999, UID)
	_client.net_error_sink = func(endpoint: String, status: int) -> void: _net_errors.append([endpoint, status])


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _store(with_client: bool = true) -> ProfileStore:
	return ProfileStore.new(SettingsStore.new(PATH), ProfileApi.new(_client) if with_client else null)


func test_local_nickname_round_trips() -> void:
	var p := _store()
	assert_eq(p.nickname(), "")
	p.save("브롤왕")
	assert_eq(p.nickname(), "브롤왕")
	assert_eq(ProfileStore.new(SettingsStore.new(PATH)).nickname(), "브롤왕", "kept on the device")


func test_save_patches_the_own_profile_row() -> void:
	_store().save("브롤왕")
	var r := _http.last()
	assert_eq(r["method"], HTTPClient.METHOD_PATCH)
	assert_eq(r["url"], URL + "/rest/v1/profiles?id=eq." + UID)
	assert_eq(_http.last_json(), {"display_name": "브롤왕"})
	assert_eq(_http.header(r, "Authorization"), "Bearer access-1")
	assert_eq(_http.header(r, "apikey"), "anon-key")


func test_fetch_reads_the_display_name() -> void:
	var got: Array = []
	_store().fetch_remote(func(display_name: String) -> void: got.append(display_name))
	var r := _http.last()
	assert_eq(r["method"], HTTPClient.METHOD_GET)
	assert_eq(r["url"], URL + "/rest/v1/profiles?select=display_name&id=eq." + UID)
	_http.respond(200, "[{\"display_name\": \"Kim Minsu\"}]")
	assert_eq(got, ["Kim Minsu"])


func test_fetch_gives_empty_on_failure_or_no_row() -> void:
	var got: Array = []
	var p := _store()
	p.fetch_remote(func(display_name: String) -> void: got.append(display_name))
	_http.respond(200, "[]")
	p.fetch_remote(func(display_name: String) -> void: got.append(display_name))
	_http.respond(503, "")
	assert_eq(got, ["", ""])
	assert_eq(_net_errors, [["rest/profiles", 503]])


func test_offline_saves_locally_and_fetches_nothing() -> void:
	var p := _store(false)
	var got: Array = []
	p.fetch_remote(func(display_name: String) -> void: got.append(display_name))
	p.save("브롤왕")
	assert_eq(got, [""])
	assert_eq(p.nickname(), "브롤왕")
	assert_eq(_http.requests.size(), 0)


func test_without_a_session_nothing_is_sent() -> void:
	_client.session = null
	var got: Array = []
	var p := _store()
	p.fetch_remote(func(display_name: String) -> void: got.append(display_name))
	p.save("브롤왕")
	assert_eq(got, [""])
	assert_eq(_http.requests.size(), 0)
	assert_eq(p.nickname(), "브롤왕")


func test_forget_clears_the_device_nickname_only() -> void:
	var p := _store()
	p.save("브롤왕")
	var sent := _http.requests.size()
	p.forget()
	assert_eq(p.nickname(), "", "the next account on this device starts clean")
	assert_eq(_http.requests.size(), sent, "the account keeps its name")
