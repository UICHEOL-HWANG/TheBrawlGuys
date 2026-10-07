class_name SwingTiming
extends RefCounted
## Where a swing clip should be for the sim's attack progress (combat-motion A1). The clip is not
## stretched evenly: the startup eases in from the cocked pose to the strike (the swing speeds
## up into the hit), the active ticks barely move off the strike pose so the impact reads, and
## the recovery eases out to the plan's end, where the animator blends back to idle.
## progress: attack_ticks plus the render fraction of the next tick (the first attack tick is 1).

## Share of the follow-through (contact -> end) spent while the hitbox is live.
const ACTIVE_SHARE := 0.15


static func clip_time(progress: float, frames: AttackData, plan: Dictionary) -> float:
	var start := float(plan["start"])
	var contact := float(plan["contact"])
	var follow := float(plan["end"]) - contact
	var elapsed := maxf(progress - 1.0, 0.0)  # ticks since the attack began
	var startup := float(frames.startup_ticks)
	if elapsed < startup:
		var u := elapsed / startup
		return lerpf(start, contact, u * u)
	elapsed -= startup
	var active := float(maxi(frames.active_ticks, 1))
	if elapsed < active:
		return contact + follow * ACTIVE_SHARE * (elapsed / active)
	elapsed -= active
	var w := clampf(elapsed / float(maxi(frames.recovery_ticks, 1)), 0.0, 1.0)
	var eased := 1.0 - (1.0 - w) * (1.0 - w)
	return contact + follow * (ACTIVE_SHARE + (1.0 - ACTIVE_SHARE) * eased)
