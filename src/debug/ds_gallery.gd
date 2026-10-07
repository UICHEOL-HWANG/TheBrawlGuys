extends Control
## Design system gallery (design.md DS-GOV-02). Every token, component, shader sample, VFX and SFX is shown here.
## Run: godot --path . res://src/debug/ds_gallery.tscn
## Sections live in DsGalleryBasics (static) and DsGalleryPreviews (live 3D, VFX, SFX, BGM).

## Registered components: [display name, scene path]. Phase 1 adds DamageCounter, StockIcons, ...
const COMPONENTS: Array[Array] = [
	["DamageCounter · DS-CMP-01", "res://src/ui/components/damage_counter/damage_counter.tscn"],
	["StockIcons · DS-CMP-02", "res://src/ui/components/stock_icons/stock_icons.tscn"],
	["ResultBanner · DS-CMP-09", "res://src/ui/components/result_banner/result_banner.tscn"],
	["TouchStick · DS-CMP-03", "res://src/ui/components/touch_stick/touch_stick.tscn"],
	["TouchButton v2 · DS-CMP-04", "res://src/ui/components/touch_button/touch_button.tscn"],
	["ChargeGauge · DS-CMP-05", "res://src/ui/components/charge_gauge/charge_gauge.tscn"],
	["MenuButton · DS-CMP-06", "res://src/ui/components/menu_button/menu_button.tscn"],
	["Panel · DS-CMP-07", "res://src/ui/components/panel/panel.tscn"],
	["CrestLogo · DS-CMP-15", "res://src/ui/components/crest_logo/crest_logo.tscn"],
	["LoginPanel · DS-CMP-14", "res://src/ui/components/login_panel/login_panel.tscn"],
	["KeyHintBar · DS-CMP-16", "res://src/ui/components/key_hint_bar/key_hint_bar.tscn"],
	["SelectCard · DS-CMP-08", "res://src/ui/components/select_card/select_card.tscn"],
	["PlayerSlot · DS-CMP-10", "res://src/ui/components/player_slot/player_slot.tscn"],
	["TextField · DS-CMP-17", "res://src/ui/components/text_field/text_field.tscn"],
	["CodeInput · DS-CMP-18", "res://src/ui/components/code_input/code_input.tscn"],
	["TutorialCard · DS-CMP-19", "res://src/ui/tutorial/tutorial_card.tscn"],
	["RoomCodeInput · DS-CMP-11", "res://src/ui/components/room_code_input/room_code_input.tscn"],
	["ConnectionBadge · DS-CMP-13", "res://src/ui/components/connection_badge/connection_badge.tscn"],
]
## Pass `--components-only` after `--` to render just the components section (evidence capture).
const COMPONENTS_ONLY_ARG := "--components-only"
## Pass `--items-only` after `--` to render just the items preview (evidence capture).
const ITEMS_ONLY_ARG := "--items-only"
## Capture-only section switches, same idea as --items-only.
const VFX_ONLY_ARG := "--vfx-only"
const AUDIO_ONLY_ARG := "--audio-only"
const CHARACTERS_ONLY_ARG := "--characters-only"
var _sfx: SfxDirector
var _music: MusicDirector


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = DS.UI_SURFACE_DIM
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, DS.S7)
	scroll.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", DS.S6)
	margin.add_child(col)

	var config := GameConfig.new()
	_sfx = SfxDirector.new()
	add_child(_sfx)
	_sfx.setup(config)
	_music = MusicDirector.new()
	add_child(_music)
	_music.setup(config)
	var previews := DsGalleryPreviews.new()
	add_child(previews)
	previews.setup(_sfx, _music)

	var args := OS.get_cmdline_user_args()
	if args.has(CHARACTERS_ONLY_ARG):
		col.add_child(DsGalleryBasics.heading("Characters · DS-VIS-02"))
		col.add_child(previews.characters_preview())
		return
	if args.has(VFX_ONLY_ARG):
		col.add_child(DsGalleryBasics.heading("VFX · DS-VFX-01~06"))
		col.add_child(previews.vfx_preview())
		return
	if args.has(AUDIO_ONLY_ARG):
		col.add_child(DsGalleryBasics.heading("SFX · DS-SFX-01 / BGM · DS-SFX-02"))
		col.add_child(previews.audio_preview())
		return
	if args.has(ITEMS_ONLY_ARG):
		col.add_child(DsGalleryBasics.heading("Items · DS-VIS-05 (crate + shadow / bat fresh·cracked / bomb unlit·lit / rock resting·tumbling)"))
		col.add_child(previews.items_preview())
		return
	if not args.has(COMPONENTS_ONLY_ARG):
		col.add_child(DsGalleryBasics.heading("Palette · DS-TOK-01 (A 한낮 햇살)"))
		col.add_child(DsGalleryBasics.swatches())
		col.add_child(DsGalleryBasics.heading("Typography · DS-TOK-02"))
		col.add_child(DsGalleryBasics.type_scale())
		col.add_child(DsGalleryBasics.heading("Soft toon · DS-VIS-01 / DS-VIS-02"))
		col.add_child(DsGalleryBasics.toon_preview())
		col.add_child(DsGalleryBasics.heading("Items · DS-VIS-05 (crate + shadow / bat fresh·cracked / bomb unlit·lit / rock resting·tumbling)"))
		col.add_child(previews.items_preview())
		col.add_child(DsGalleryBasics.heading("Characters · DS-VIS-02"))
		col.add_child(previews.characters_preview())
		col.add_child(DsGalleryBasics.heading("VFX · DS-VFX-01~06"))
		col.add_child(previews.vfx_preview())
		col.add_child(DsGalleryBasics.heading("SFX · DS-SFX-01 / BGM · DS-SFX-02"))
		col.add_child(previews.audio_preview())
	col.add_child(DsGalleryBasics.heading("Components · DS-CMP"))
	col.add_child(DsGalleryBasics.components(COMPONENTS))

