class_name DS
extends RefCounted
## Design tokens — the only place colors and UI sizes are defined (docs/design.md §3).
## Palette: option A "한낮 햇살", confirmed 2026-09-28.

# --- World (DS-TOK-01) ---
const GRASS_SUN := Color("#D6EE7C")
const GRASS := Color("#A5D65A")
const GRASS_MID := Color("#7CC04B")
const GRASS_SHADE := Color("#4F9A48")
const CANOPY := Color("#2E8C86")
const CANOPY_DEEP := Color("#17525A")
const WATER := Color("#3A9FE3")
const WATER_DEEP := Color("#2A72C9")
const STONE_CREAM := Color("#F3EEE7")
const STONE_SHADE := Color("#BDB1AC")
const BARK := Color("#6C5A66")
const DIRT := Color("#8A6B55")
const SKY := Color("#C4E8F6")

# --- Arena theme variants (DS-THM-02): 3D environment only, the UI never uses them ---
## Log bridge: bright noon, pale sky.
const SKY_PALE := Color("#DDF1F8")
## Mushroom forest: late-afternoon gold (DS-TOK-01 B-plan values), desaturated floor.
const GRASS_DUSK := Color("#98B25C")
const GRASS_GOLD := Color("#BFD35A")
const CANOPY_GOLD := Color("#3E8A6A")
const SUN_GOLD := Color("#FFD89A")
const SKY_GOLD := Color("#F4E3B5")
## Foggy forest: cold early morning, gray-green floor, mist.
const GRASS_MIST := Color("#9CB79A")
const GRASS_MIST_DEEP := Color("#7E9C80")
const CANOPY_MIST := Color("#4E7F78")
const SUN_COOL := Color("#E6F2F7")
const FOG_MIST := Color("#DCEBEF")
## Fog veil sheets over the arena while the fog is in (fog_mist 55%).
const FOG_VEIL := Color("#DCEBEF8C")

# --- Hazard marking (DS-VIS-04) ---
## Campfire burn radius glowing on the ground (fire 40%).
const FIRE_RING := Color("#FF9A2E66")
## Mushroom rebound hint ring (petal_yellow 50%).
const BOUNCE_RING := Color("#F5D53D80")

# --- Accents ---
const PETAL_PINK := Color("#F27DB6")
const PETAL_BLUE := Color("#3E6FE3")
const PETAL_YELLOW := Color("#F5D53D")
const BERRY := Color("#7B5AD8")
const FIRE := Color("#FF9A2E")
const GLOW := Color("#FFF3C4")
const DANGER := Color("#F0584A")

# --- UI ---
const UI_SURFACE := Color("#FFFDF6")
const UI_SURFACE_DIM := Color("#EAF2DC")
const UI_TEXT := CANOPY_DEEP
const UI_TEXT_SOFT := Color("#3F7470")
const UI_SHADOW := Color("#17525A40")
const UI_ACCENT := FIRE
const TRANSPARENT := Color("#FFFFFF00")
## Multiplier identity for textured materials (soft toon albedo), not a UI color.
const WHITE := Color("#FFFFFF")
## Translucent cream surfaces for touch controls over the 3D scene (design.md DS-LAY-01).
const UI_SURFACE_50 := Color("#FFFDF680")
const UI_SURFACE_70 := Color("#FFFDF6B3")
## Menu haze (design.md DS-LAY-03): warm light sage-gray fog over the backdrop diorama.
const HAZE := Color("#DAD9CB")
## Frosted glass card (DS-CMP-14): sage tint over the blurred scene, thin light edge.
const GLASS_TINT := Color("#B9C9B0")
const GLASS_EDGE := Color("#F4F7EEB3")
## Soft text shadow for white titles over the scene (canopy_deep 35%).
const TEXT_SHADOW := Color("#17525A59")
## Google "G" brand colors — only for the Google mark on the sign-in button (brand rule).
const GOOGLE_BLUE := Color("#4285F4")
const GOOGLE_RED := Color("#EA4335")
const GOOGLE_YELLOW := Color("#FBBC05")
const GOOGLE_GREEN := Color("#34A853")
## Soft ground shadows under falling boxes (design.md DS-VIS-05): deep teal at 40%.
const GROUND_SHADOW := Color("#17525A66")

## Guard bubble (design.md DS-VFX-02): sky at 40%, a soap bubble around the guarding fighter.
const GUARD_BUBBLE := Color("#C4E8F666")
## Respawn light pillar (design.md DS-VFX-06): glow at 40%.
const RESPAWN_BEAM := Color("#FFF3C466")

# --- Players (always paired with a shape, DS-VIS-03) ---
const P1 := Color("#3E7BF0")
const P2 := Color("#F25C5C")
const P3 := Color("#FFC93C")
const P4 := Color("#B46CF0")

## DamageCounter color stops at 0 / 50 / 100 / 150+ percent.
const DAMAGE_RAMP := [UI_SURFACE, PETAL_YELLOW, FIRE, DANGER]

const PALETTE := {
	"grass_sun": GRASS_SUN, "grass": GRASS, "grass_mid": GRASS_MID, "grass_shade": GRASS_SHADE,
	"canopy": CANOPY, "canopy_deep": CANOPY_DEEP, "water": WATER, "water_deep": WATER_DEEP,
	"stone_cream": STONE_CREAM, "stone_shade": STONE_SHADE, "bark": BARK, "dirt": DIRT, "sky": SKY,
	"petal_pink": PETAL_PINK, "petal_blue": PETAL_BLUE, "petal_yellow": PETAL_YELLOW,
	"berry": BERRY, "fire": FIRE, "glow": GLOW, "danger": DANGER,
	"ui_surface": UI_SURFACE, "ui_surface_dim": UI_SURFACE_DIM, "ui_text": UI_TEXT, "ui_text_soft": UI_TEXT_SOFT,
	"p1": P1, "p2": P2, "p3": P3, "p4": P4,
}

# --- Typography (DS-TOK-02), sizes at 1920x1080 ---
const FONT_DISPLAY_PATH := "res://assets/fonts/Jua-Regular.ttf"
const FONT_BODY_PATH := "res://assets/fonts/Pretendard-SemiBold.otf"
const FONT_CAPTION_PATH := "res://assets/fonts/Pretendard-Medium.otf"
const SIZE_DISPLAY_XL := 96
const SIZE_DISPLAY_L := 64
const SIZE_TITLE := 40
const SIZE_BODY := 28
const SIZE_CAPTION := 22
const TEXT_OUTLINE := 3

# --- Spacing (DS-TOK-03) ---
const S1 := 4
const S2 := 8
const S3 := 12
const S4 := 16
const S5 := 24
const S6 := 32
const S7 := 48
const S8 := 64

# --- Radius, stroke, shadow (DS-TOK-04) ---
const RADIUS_S := 12
const RADIUS_M := 20
const RADIUS_L := 32
const RADIUS_PILL := 999
const STROKE_FOCUS := 4
const SHADOW_SOFT_OFFSET := Vector2(0, 8)
const SHADOW_SOFT_SIZE := 16
const SHADOW_PRESSED_OFFSET := Vector2(0, 2)
const SHADOW_PRESSED_SIZE := 4

# --- Motion (DS-TOK-05), seconds ---
const MOTION_FAST := 0.08
const MOTION_BASE := 0.18
const MOTION_SQUISH := 0.28
const MOTION_SLOW := 0.40
## Calm menu entrances: haze clearing, login card rising (design.md DS-TOK-05).
const MOTION_CALM := 0.70
## Button press squish (design.md DS-TOK-05).
const PRESS_SQUISH := Vector2(1.04, 0.92)

# --- Menu layout sizes (DS-TOK-03 menu sizes), at 1920x1080 ---
const BUTTON_MIN_WIDTH := 400
const BUTTON_HEIGHT := 80
## Frosted login card (DS-CMP-14): width and the extra-large corner radius.
const LOGIN_CARD_WIDTH := 560
const RADIUS_XL := 40
## Letter spacing of spaced-out taglines.
const TRACKING_WIDE := 4

# --- Glass & haze strengths (DS-CMP-14, DS-LAY-03), 0..1 ---
## How much sage tint covers the blurred scene in the card (Compatibility: no blur, more tint).
const GLASS_TINT_STRENGTH := 0.5
const GLASS_TINT_STRENGTH_NO_BLUR := 0.82
## Blur mip level of the screen texture behind the card.
const GLASS_BLUR_LOD := 3.5
## Resting haze over the backdrop and its desaturation; the entrance starts fully hazed.
const HAZE_AMOUNT := 0.34
const HAZE_DESATURATE := 0.4
