class_name SfxLimiter
extends RefCounted
## Keeps repeated combat sounds from piling up (design.md DS-SFX-01): a listed sound plays at most
## once per gap and never on more than its voice cap at once, so four players spamming bolts
## stay clear instead of clipping. Swings are keyed per fighter, which also swallows a whoosh
## re-read when a rollback replays the same ticks. Unlisted sounds play freely.

## Sound name -> [minimum gap between plays (ms), voices it may hold at once].
const LIMITS := {
	"zap_bolt": [45, 3], "zap_heavy": [60, 2], "fireball_launch": [120, 2],
	"bolt_pop": [40, 3], "fireball_boom": [120, 2], "special_charge": [150, 2],
	"grab": [60, 2], "grab_release": [60, 2], "toss": [80, 2],
	"swing_blade": [100, 3], "swing_air": [100, 3],
}

var _last_ms: Dictionary = {}


## key: what the gap is counted on (the name, or name + fighter id). playing: voices already
## sounding `name`. Records the play when it is allowed.
func allow(name: String, key: String, now_ms: int, playing: int) -> bool:
	if not LIMITS.has(name):
		return true
	if playing >= max_voices(name):
		return false
	if _last_ms.has(key) and now_ms - int(_last_ms[key]) < gap_ms(name):
		return false
	_last_ms[key] = now_ms
	return true


static func gap_ms(name: String) -> int:
	return int((LIMITS.get(name, [0, 0]) as Array)[0])


static func max_voices(name: String) -> int:
	return int((LIMITS.get(name, [0, 0]) as Array)[1])
