class_name TutorialProgress
extends RefCounted
## Whether this device still owes the player the onboarding tutorial (Phase 5 T11): SettingsStore
## user://settings.cfg [onboarding] tutorial = "completed" | "skipped"; missing = pending. The app
## starts the tutorial after a sign-in only while it is pending; a replay from the title never
## changes a finished status back.

const SECTION := "onboarding"
const KEY := "tutorial"
const COMPLETED := "completed"
const SKIPPED := "skipped"
const PENDING := ""

var _store: SettingsStore


func _init(store: SettingsStore = null) -> void:
	_store = store if store != null else SettingsStore.new()


func status() -> String:
	var v: Variant = _store.get_value(SECTION, KEY, PENDING)
	return String(v) if typeof(v) == TYPE_STRING and (v == COMPLETED or v == SKIPPED) else PENDING


func is_pending() -> bool:
	return status() == PENDING


## Completing beats skipping: a replay that is skipped keeps an earlier "completed".
func mark(p_status: String) -> void:
	assert(p_status == COMPLETED or p_status == SKIPPED, "TutorialProgress: bad status '%s'" % p_status)
	if p_status == SKIPPED and status() == COMPLETED:
		return
	_store.set_value(SECTION, KEY, p_status)
