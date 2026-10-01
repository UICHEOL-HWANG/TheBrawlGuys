class_name RoomCodeInput
extends CodeInput
## Online room code input (design.md DS-CMP-11): the CodeInput boxes (DS-CMP-18) for a 6-character
## room code — letters are upper-cased, characters outside RoomCode.ALPHABET (and the look-alikes
## I, O, 0, 1) are dropped, paste works, and phones get the full keyboard. Same states: idle ·
## focus · error · disabled.


func _clean(text: String) -> String:
	return RoomCode.normalize(text)


func _keyboard_type() -> LineEdit.VirtualKeyboardType:
	return LineEdit.KEYBOARD_TYPE_DEFAULT


func set_preview() -> void:
	if not is_node_ready():
		await ready
	set_code("K7Q")
