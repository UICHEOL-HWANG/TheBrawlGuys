class_name PlatformEnv
extends RefCounted
## Where the game runs (platform A): decides whether network services may run and fills the
## common Amplitude context. Headless runs (tests, CI, server) never talk to the network.

const GUT_ARG := "gut_cmdln"
const DEFAULT_VERSION := "dev"


## False for headless runs and GUT test runs: analytics, Supabase and login stay offline.
static func is_live() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	for arg: String in OS.get_cmdline_args():
		if arg.contains(GUT_ARG):
			return false
	return true


## "web" | "mobile" | "desktop" (same split as Quality defaults).
static func kind() -> String:
	return Quality.platform()


static func app_version() -> String:
	var v := String(ProjectSettings.get_setting("application/config/version", ""))
	return v if not v.is_empty() else DEFAULT_VERSION


static func default_input_device() -> String:
	return "touch" if kind() == "mobile" else "keyboard"


## Amplitude top-level event fields shared by every event.
static func amplitude_context() -> Dictionary:
	return {
		"platform": kind(), "os_name": OS.get_name(), "app_version": app_version(),
		"language": OS.get_locale_language(),
	}
