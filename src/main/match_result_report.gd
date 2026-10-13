class_name MatchResultReport
extends RefCounted
## The result banner's match record (design.md DS-CMP-09): closes the match telemetry, then shows
## the local players' highlights (ResultHighlights) and, for a counted bot match, the BotProgress
## XP / level line with the character's progress gauges.


static func apply(banner: ResultBanner, setup: MatchSetup, view: Dictionary, tracking: MatchTracking,
		progress: BotProgress) -> void:
	tracking.finish(view)
	var telemetry := tracking.telemetry()
	var highlights := ResultHighlights.lines(telemetry.player_rows(), setup.local_slots())
	var reward := progress.record(setup, view, telemetry.match_id(), telemetry.player_rows())
	banner.set_highlights(highlights + ("\n" + reward if not reward.is_empty() else ""))
	if not reward.is_empty():
		banner.set_progress(progress.summary(setup.characters()[0]))
