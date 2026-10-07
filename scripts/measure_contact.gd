extends SceneTree
## Finds the contact moment of each KayKit attack clip: the sample where the striking bone is
## farthest in front of the hips (+Z, the model's front). Prints clip, bone, contact s, length.
## Run: godot --headless --path . -s res://scripts/measure_contact.gd

const CLIPS := {
	"Unarmed_Melee_Attack_Punch_A": ["hand.r", "hand.l"], "Unarmed_Melee_Attack_Punch_B": ["hand.r", "hand.l"],
	"Unarmed_Melee_Attack_Kick": ["foot.r", "foot.l"], "1H_Melee_Attack_Chop": ["handslot.r"],
	"1H_Melee_Attack_Slice_Diagonal": ["handslot.r"], "1H_Melee_Attack_Slice_Horizontal": ["handslot.r"],
	"1H_Melee_Attack_Stab": ["handslot.r"], "2H_Melee_Attack_Chop": ["handslot.r"], "2H_Melee_Attack_Slice": ["handslot.r"],
	"2H_Melee_Attack_Stab": ["handslot.r"], "Dualwield_Melee_Attack_Stab": ["handslot.r", "handslot.l"],
	"Spellcast_Shoot": ["hand.r", "hand.l"], "Spellcast_Long": ["hand.r", "hand.l"], "1H_Ranged_Shoot": ["hand.r"],
	"Interact": ["hand.r", "hand.l"], "PickUp": ["hand.r", "hand.l"], "Throw": ["hand.r"], "Block_Attack": ["hand.r", "hand.l"],
	"Unarmed_Pose": ["hand.r", "hand.l"],
}
const STEP := 1.0 / 60.0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var scene := load("res://assets/characters/kaykit/Knight.glb") as PackedScene
	var root := scene.instantiate() as Node3D
	get_root().add_child(root)
	var player := root.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var skel := root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var hips := skel.find_bone("hips")
	for clip: String in CLIPS:
		if not player.has_animation(clip):
			print("missing ", clip)
			continue
		var length := player.get_animation(clip).length
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		player.play(clip)
		for bone_name: String in CLIPS[clip]:
			var b := skel.find_bone(bone_name)
			var best := -INF
			var best_t := 0.0
			var line := PackedStringArray()
			var t := 0.0
			while t <= length:
				player.seek(t, true)
				player.advance(0.0)
				skel.force_update_all_bone_transforms()
				var p := skel.get_bone_global_pose(b).origin - skel.get_bone_global_pose(hips).origin
				if p.z > best:
					best = p.z
					best_t = t
				if int(round(t / STEP)) % 6 == 0:
					line.append("%.2f:%.2f" % [t, p.z])
				t += STEP
			print("%s\t%s\tcontact=%.3f\tlen=%.3f\treach=%.2f" % [clip, bone_name, best_t, length, best])
			print("   ", " ".join(line))
	quit(0)
