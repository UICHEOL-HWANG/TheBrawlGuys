class_name GoogleButton
extends UiMenuButton
## Google sign-in pill for the login card (design.md DS-CMP-14): a DS-CMP-06 MenuButton in the
## white surface kind with the Google "G" drawn at its left edge, text beside it.

const G_SIZE := DS.S6
const G_GAP := DS.S3


func _init() -> void:
	kind = Kind.SECONDARY


## Room for the G on the left of the label.
func _box(s: int) -> StyleBoxFlat:
	var sb := super._box(s)
	sb.content_margin_left += G_SIZE + G_GAP
	return sb


func _draw() -> void:
	var sb := _box(state())  # the face (and its label) lifts / sinks with the state
	var text_width := get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			get_theme_font_size("font_size")).x
	var content_left := (size.x - text_width - sb.content_margin_right + sb.content_margin_left) * 0.5
	var face_mid := (sb.content_margin_top + size.y - sb.content_margin_bottom) * 0.5
	var center := Vector2(content_left - G_GAP - G_SIZE * 0.5, face_mid)
	LoginIcon.draw_google_g(self, center, G_SIZE * 0.5)
