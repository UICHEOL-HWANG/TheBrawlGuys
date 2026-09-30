extends GutTest
## Form inputs (design.md DS-CMP-17 TextField, DS-CMP-18 CodeInput): states, DS styling, digit
## filtering with paste, mobile keyboard hints, signals and gallery registration.

const TEXT_FIELD := preload("res://src/ui/components/text_field/text_field.tscn")
const CODE_INPUT := preload("res://src/ui/components/code_input/code_input.tscn")


func _field() -> UiTextField:
	var f := TEXT_FIELD.instantiate() as UiTextField
	add_child_autofree(f)
	return f


func _code() -> CodeInput:
	var c := CODE_INPUT.instantiate() as CodeInput
	add_child_autofree(c)
	return c


func _type(c: CodeInput, text: String) -> void:
	c.field().text = c.field().text + text
	c.field().text_changed.emit(c.field().text)


func test_gallery_registers_both() -> void:
	var registered: Array[String] = []
	for entry: Array in (load("res://src/debug/ds_gallery.gd") as GDScript).get_script_constant_map()["COMPONENTS"]:
		registered.append(String(entry[1]))
	assert_true(registered.has("res://src/ui/components/text_field/text_field.tscn"))
	assert_true(registered.has("res://src/ui/components/code_input/code_input.tscn"))


func test_text_field_style_follows_state() -> void:
	var f := _field()
	assert_eq(f.custom_minimum_size.y, float(DS.FIELD_HEIGHT))
	var idle := f.get_theme_stylebox("normal") as StyleBoxFlat
	assert_eq(idle.corner_radius_top_left, DS.RADIUS_M)
	assert_eq(idle.bg_color, DS.UI_SURFACE)
	assert_eq(idle.border_width_top, 0)
	f.set_state(UiTextField.State.FOCUS)
	assert_eq((f.get_theme_stylebox("normal") as StyleBoxFlat).border_color, DS.PETAL_YELLOW)
	f.set_state(UiTextField.State.ERROR)
	var err := f.get_theme_stylebox("normal") as StyleBoxFlat
	assert_eq(err.border_color, DS.DANGER)
	assert_eq(err.border_width_top, DS.STROKE_FOCUS)
	f.set_state(UiTextField.State.DISABLED)
	assert_false(f.editable)
	assert_eq((f.get_theme_stylebox("read_only") as StyleBoxFlat).bg_color, DS.UI_SURFACE_DIM)


func test_typing_clears_the_error() -> void:
	var f := _field()
	f.set_state(UiTextField.State.ERROR)
	f.text_changed.emit("a")
	assert_ne(f.state(), UiTextField.State.ERROR)


func test_text_field_preview() -> void:
	var f := _field()
	f.set_preview()
	assert_ne(f.placeholder_text, "")


func test_digits_filter() -> void:
	assert_eq(CodeInput.digits("12 34-56"), "123456")
	assert_eq(CodeInput.digits("code: 9876543"), "987654", "never more than six")
	assert_eq(CodeInput.digits("abc"), "")


func test_code_input_keeps_only_six_digits_and_pastes() -> void:
	var c := _code()
	watch_signals(c)
	_type(c, "12a")
	assert_eq(c.code(), "12")
	assert_eq(c.field().text, "12", "letters never show")
	assert_signal_not_emitted(c, "completed")
	_type(c, " 34-56 78")
	assert_eq(c.code(), "123456")
	assert_signal_emitted_with_parameters(c, "completed", ["123456"])


func test_code_input_hints_the_numeric_keyboard() -> void:
	var c := _code()
	assert_eq(c.field().virtual_keyboard_type, LineEdit.KEYBOARD_TYPE_NUMBER)
	var width := CodeInput.LENGTH * DS.CODE_BOX_WIDTH + (CodeInput.LENGTH - 1) * DS.S3
	assert_eq(c.custom_minimum_size, Vector2(width, DS.CODE_BOX_HEIGHT))


func test_code_input_enter_submits() -> void:
	var c := _code()
	watch_signals(c)
	_type(c, "123456")
	c.field().text_submitted.emit(c.field().text)
	assert_signal_emitted_with_parameters(c, "submitted", ["123456"])


func test_code_input_states() -> void:
	var c := _code()
	_type(c, "123")
	c.set_state(CodeInput.State.ERROR)
	assert_eq(c.state(), CodeInput.State.ERROR)
	_type(c, "4")
	assert_ne(c.state(), CodeInput.State.ERROR, "typing clears the error")
	c.set_state(CodeInput.State.DISABLED)
	assert_false(c.field().editable)
	c.set_state(CodeInput.State.IDLE)
	assert_true(c.field().editable)
	c.clear()
	assert_eq(c.code(), "")


func test_code_input_preview_and_set_code() -> void:
	var c := _code()
	c.set_preview()
	assert_eq(c.code().length(), 4, "half typed in the gallery")
	c.set_code("98x7")
	assert_eq(c.code(), "987")
