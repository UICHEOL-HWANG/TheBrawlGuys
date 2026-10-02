class_name ProfileStore
extends RefCounted
## The player's nickname (onboarding): cached on the device in SettingsStore [profile] nickname so
## the HUD and title can show it at once, and saved to the account (ProfileApi) so it follows the
## player. Remote calls are fire-and-forget; offline (no api) everything stays local.

## The device nickname changed (saved, forgotten or restored from the account).
signal changed

const SECTION := "profile"
const KEY := "nickname"

var _store: SettingsStore
var _api: ProfileApi


## api: null when there is no Supabase client (offline, tests).
func _init(store: SettingsStore = null, api: ProfileApi = null) -> void:
	_store = store if store != null else SettingsStore.new()
	_api = api


## The live profile on the shared Supabase client, or a local-only one offline.
static func create_default() -> ProfileStore:
	var client := SupabaseHub.client()
	return ProfileStore.new(SettingsStore.new(), ProfileApi.new(client) if client != null else null)


func nickname() -> String:
	var v: Variant = _store.get_value(SECTION, KEY, "")
	return String(v) if typeof(v) == TYPE_STRING else ""


## Keeps a (valid) nickname on the device and sends it to the account.
func save(nick: String) -> void:
	_store.set_value(SECTION, KEY, nick)
	changed.emit()
	if _api != null:
		_api.save(nick, func(ok: bool, _name: String) -> void:
			if not ok:  # kept on the device; the account keeps its old name until the next save
				push_warning("ProfileStore: nickname not saved to the account"))


## Logout: the next account on this device starts without this nickname.
func forget() -> void:
	_store.set_value(SECTION, KEY, "")
	changed.emit()


## Sign-in on a device without a nickname (another account, a new device after onboarding): take
## the account's name as the device nickname when it is usable. Never writes to the account.
func restore_from_account() -> void:
	if not nickname().is_empty():
		return
	fetch_remote(func(display_name: String) -> void:
		var nick := Nickname.prefill(display_name)
		if not nick.is_empty() and nickname().is_empty():
			_store.set_value(SECTION, KEY, nick)
			changed.emit())


## done(display_name: String): the account's display name ("" offline, signed out or on failure).
func fetch_remote(done: Callable) -> void:
	if _api == null:
		done.call("")
		return
	_api.fetch(func(_ok: bool, display_name: String) -> void: done.call(display_name))
