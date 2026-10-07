class_name ReactionCues
extends RefCounted
## Render cues from sim events that a single view frame cannot show (polish-pass 7): a throw
## (the sim drops the thrower to standing in one tick, so the toss is asked for by the throw
## hit) and a flinch (a combo hit on a fighter already in hitstun keeps the same state, so the
## flinch is replayed on every hit). Each request is used up by the next animator frame.

## View states a toss may play over (anything else, e.g. getting hit, cuts it short).
const STANDING: Array[int] = [AnimMap.Anim.IDLE, AnimMap.Anim.RUN, AnimMap.Anim.JUMP]
## Hurt states a flinch replays in.
const HURT: Array[int] = [AnimMap.Anim.HIT, AnimMap.Anim.LAUNCHED]
## Flinch clips: a quick one for light hits, a big rock back for the rest.
const LIGHT_FLINCH := "Hit_A"
const HEAVY_FLINCH := "Hit_B"

var _toss_asked: bool = false
var _flinch_asked: bool = false
var _heavy: bool = false


func toss() -> void:
	_toss_asked = true


func flinch(heavy: bool) -> void:
	_flinch_asked = true
	_heavy = heavy


## The clip the next ground flinch plays.
func flinch_clip() -> String:
	return HEAVY_FLINCH if _heavy else LIGHT_FLINCH


## True (once) when a hurt state should restart its flinch this frame.
func take_flinch(anim: int) -> bool:
	var asked := _flinch_asked
	_flinch_asked = false
	return asked and HURT.has(anim)


## The toss plays from the throw cue, or from the frozen frame right after a hold if the cue
## was missed, until its follow-through ends (toss_done) or the fighter does something else.
func tossing(anim: int, current: int, hitstop: int, toss_done: bool) -> bool:
	var asked := _toss_asked
	_toss_asked = false
	if not STANDING.has(anim):
		return false
	if asked or (current == AnimMap.Anim.HOLD and hitstop > 0):
		return current != AnimMap.Anim.THROW or toss_done
	return current == AnimMap.Anim.THROW and not toss_done
