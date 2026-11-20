## look.gd — the look of the game: colours, fonts and small builders for UI pieces.
##
## The campaign at night. Everything around you is cold and dark (the office, the
## map, the files); what you hold in your hand is paper under a warm desk lamp
## (decisions, speeches, the morning clips). Colour is rationed: party colours,
## one warm light (LAMP) and one red (danger, and the thing to press next).
class_name Look
extends RefCounted

# ---------- Colours ----------
# Two palettes, the same roles in each; use() picks one before the screens are built.
#  "night": the campaign office at night: cold blue-black, steel, white paper (the first pass).
#  "study": the same office in an old building: warm dark wood and leather, a bottle-green
#           sea on the map, warm white paper. The Knives Out to night's Glass Onion.
const PALETTES := {
	"night": {"N950": "06080c", "N900": "0a0d13", "N850": "0f131b", "N800": "141923", "N700": "1b2230", "N600": "273042", "N500": "3a465b", "TXT": "e8ebf1", "DIM": "9aa5b7", "FAINT": "66738a", "LAMP": "f2b866", "LAMP_DIM": "a9844d", "RED": "d2392f", "RED_HI": "ff6a5c", "OXBLOOD": "8f231c", "GOOD": "1f7d55", "GOOD_HI": "5cc79a", "PAPER": "f1f2f3", "PAPER_2": "e4e6e9", "CARD": "fbfbfc", "INK": "14171d", "MUTED": "5b626e", "LINE": "c6cad0", "SEA": "0a0e15", "LAND": "1a212d", "LAND_FOREIGN": "121720", "BORDER": "06080c"},
	"study": {"N950": "0c0705", "N900": "130b07", "N850": "1a0f0a", "N800": "23150d", "N700": "301d12", "N600": "462b1b", "N500": "6a4630", "TXT": "f3e8d8", "DIM": "c0aa8e", "FAINT": "8a735d", "LAMP": "f2b552", "LAMP_DIM": "ad7d3f", "RED": "c3362a", "RED_HI": "f2735f", "OXBLOOD": "7a1f17", "GOOD": "2b7a4b", "GOOD_HI": "86cc9c", "PAPER": "f4f0e8", "PAPER_2": "e8e1d5", "CARD": "fbf8f2", "INK": "1e1712", "MUTED": "6b5e52", "LINE": "d4cbbc", "SEA": "0b1a15", "LAND": "2b2019", "LAND_FOREIGN": "1a120d", "BORDER": "0c0705"},
}
static var palette := "night"
# the night (backgrounds), from the deepest shadow up to a raised, hovered surface
static var N950: Color
static var N900: Color
static var N850: Color
static var N800: Color
static var N700: Color
static var N600: Color
static var N500: Color
# text on the dark
static var TXT: Color
static var DIM: Color
static var FAINT: Color
# the one warm light, and the one red
static var LAMP: Color
static var LAMP_DIM: Color
static var RED: Color
static var RED_HI: Color     # red text on the dark
static var OXBLOOD: Color
static var GOOD: Color       # on paper
static var GOOD_HI: Color    # on the dark
# paper under the lamp, and ink on it
static var PAPER: Color
static var PAPER_2: Color
static var CARD: Color
static var INK: Color
static var MUTED: Color
static var LINE: Color
# the map at night
static var SEA: Color
static var LAND: Color
static var LAND_FOREIGN: Color
static var BORDER: Color
# older names still used here and there
static var HEAD: Color
static var CREAM: Color
static var CREAM_DIM: Color
static var BRASS: Color
static var BRASS_DIM: Color
static var T900: Color
static var AMBER: Color

static func _static_init() -> void:
	use("night")

## Switch palette. Screens read the colours when they are built, so rebuild after this
## (the cheat panel reloads the scene).
static func use(name: String) -> void:
	if not PALETTES.has(name): name = "night"
	palette = name
	var p: Dictionary = PALETTES[name]
	N950 = Color(p.N950)
	N900 = Color(p.N900)
	N850 = Color(p.N850)
	N800 = Color(p.N800)
	N700 = Color(p.N700)
	N600 = Color(p.N600)
	N500 = Color(p.N500)
	TXT = Color(p.TXT)
	DIM = Color(p.DIM)
	FAINT = Color(p.FAINT)
	LAMP = Color(p.LAMP)
	LAMP_DIM = Color(p.LAMP_DIM)
	RED = Color(p.RED)
	RED_HI = Color(p.RED_HI)
	OXBLOOD = Color(p.OXBLOOD)
	GOOD = Color(p.GOOD)
	GOOD_HI = Color(p.GOOD_HI)
	PAPER = Color(p.PAPER)
	PAPER_2 = Color(p.PAPER_2)
	CARD = Color(p.CARD)
	INK = Color(p.INK)
	MUTED = Color(p.MUTED)
	LINE = Color(p.LINE)
	SEA = Color(p.SEA)
	LAND = Color(p.LAND)
	LAND_FOREIGN = Color(p.LAND_FOREIGN)
	BORDER = Color(p.BORDER)
	HEAD = TXT; CREAM = TXT; CREAM_DIM = DIM; BRASS = N500; BRASS_DIM = N600; T900 = N900; AMBER = LAMP

## The palette chosen last time (user://look.txt), so a switch survives a restart.
static func load_choice() -> void:
	if FileAccess.file_exists("user://look.txt"):
		use(FileAccess.get_file_as_string("user://look.txt").strip_edges())

static func save_choice(name: String) -> void:
	var f = FileAccess.open("user://look.txt", FileAccess.WRITE)
	if f: f.store_string(name)
	use(name)

# ---------- Fonts ----------
# display: Barlow Condensed (labels, numbers, buttons)     body: IBM Plex Sans Condensed
# news:    Newsreader (headlines, the papers, speeches)    type: IBM Plex Mono (memos, datelines)
# hand:    Caveat (a note in the margin)
static var _fonts := {}

static func _file(path: String) -> FontFile:
	var p: String = Mods.asset_path(path)   # a mod may replace a font
	if p.begins_with("res://"): return load(p) as FontFile
	var f = FontFile.new()
	f.load_dynamic_font(p)
	return f

static func _variable(path: String, axes: Dictionary) -> FontVariation:
	var v = FontVariation.new()
	v.base_font = _file(path)
	var ts = TextServerManager.get_primary_interface()
	var tags = {}
	for k in axes: tags[ts.name_to_tag(k)] = axes[k]
	v.variation_opentype = tags
	return v

static func font(name: String) -> Font:
	if _fonts.has(name): return _fonts[name]
	var f: Font
	match name:
		"display_light": f = _file("res://assets/fonts/BarlowCondensed-Regular.ttf")
		"display": f = _file("res://assets/fonts/BarlowCondensed-Medium.ttf")
		"display_bold": f = _file("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
		"type": f = _file("res://assets/fonts/PlexMono-Regular.ttf")
		"type_bold": f = _file("res://assets/fonts/PlexMono-Medium.ttf")
		"news": f = _variable("res://assets/fonts/Newsreader.ttf", {"wght": 420, "opsz": 16})
		"news_bold": f = _variable("res://assets/fonts/Newsreader.ttf", {"wght": 640, "opsz": 40})
		"news_italic": f = _variable("res://assets/fonts/Newsreader-Italic.ttf", {"wght": 420, "opsz": 24})
		"hand": f = _variable("res://assets/fonts/Caveat.ttf", {"wght": 560})
		"body": f = _file("res://assets/fonts/Plex-Regular.ttf")
		"body_bold": f = _file("res://assets/fonts/Plex-SemiBold.ttf")
		"body_italic": f = _file("res://assets/fonts/Plex-Italic.ttf")
		_: f = _file("res://assets/fonts/Plex-Regular.ttf")
	# signs a font lacks (the pezo sign, arrows, ticks) come from Plex, so they always look the same
	if not name.begins_with("body"):
		var fb: Array[Font] = [font("body_bold") if name.ends_with("_bold") else font("body")]
		f.fallbacks = fb
	_fonts[name] = f
	return f

## A font with extra letter spacing (for small capitals and labels).
static func spaced(name: String, px: int) -> Font:
	var key = "%s+%d" % [name, px]
	if _fonts.has(key): return _fonts[key]
	var v = FontVariation.new()
	v.base_font = font(name)
	v.spacing_glyph = px
	_fonts[key] = v
	return v

# ---------- Builders ----------
## Small text reads better a little larger: every font size in the code goes through this.
static func fs(size: int) -> int:
	if size <= 13: return size + 2
	if size <= 16: return size + 1
	return size

## Text on paper (ink by default).
static func label(text: String, font_name := "body", size := 15, color := INK, wrap := false) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_override("font", font(font_name))
	l.add_theme_font_size_override("font_size", fs(size))
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func caps(text: String, size := 12, color := MUTED, spacing := 2, font_name := "display") -> Label:
	var l = label(text.to_upper(), font_name, size, color)
	l.add_theme_font_override("font", spaced(font_name, spacing))
	return l

## The same two for the dark surfaces (the desk, the files): light text by default.
static func dlabel(text: String, font_name := "body", size := 15, color := TXT, wrap := false) -> Label:
	return label(text, font_name, size, color, wrap)

static func dcaps(text: String, size := 12, color := DIM, spacing := 2, font_name := "display") -> Label:
	return caps(text, size, color, spacing, font_name)

static func box(bg: Color, radius := 0, border := Color.TRANSPARENT, border_w := 0, shadow := 0, pad := 0) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if border_w > 0:
		s.border_color = border
		s.set_border_width_all(border_w)
	if shadow > 0:
		s.shadow_color = Color(0, 0, 0, 0.5)
		s.shadow_size = shadow
		s.shadow_offset = Vector2(0, shadow * 0.5)
	if pad > 0: s.set_content_margin_all(pad)
	return s

## A dark panel with a hairline edge: the standard surface for anything that isn't paper.
static func glass(pad := 14, bg := N800, edge := N600) -> StyleBoxFlat:
	return box(bg, 3, edge, 1, 0, pad)

## One look for every button on the dark: "primary" is the red one you are meant to press,
## "on" a selected tab or toggle.
static func dark_button(b: Button, primary := false, on := false, pad := 7) -> void:
	var bg = OXBLOOD if primary else (TXT if on else Color(1, 1, 1, 0.03))
	var edge = RED if primary else (TXT if on else N500)
	var fg = TXT if (primary or not on) else N900
	b.add_theme_stylebox_override("normal", box(bg, 2, edge, 1, 0, pad))
	b.add_theme_stylebox_override("hover", box(RED if primary else (Color.WHITE if on else Color(1, 1, 1, 0.1)), 2, RED_HI if primary else TXT, 1, 0, pad))
	b.add_theme_stylebox_override("pressed", box(bg.darkened(0.15), 2, edge, 1, 0, pad))
	b.add_theme_stylebox_override("disabled", box(Color(1, 1, 1, 0.015), 2, N600, 1, 0, pad))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(k, fg)
	b.add_theme_color_override("font_disabled_color", FAINT)
	for k in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]: b.add_theme_color_override(k, fg)
	b.add_theme_color_override("icon_disabled_color", FAINT)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

static func icon(name: String) -> Texture2D:
	return Mods.texture("res://assets/icons/%s.svg" % name)

static func mix(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, clampf(t, 0, 1))

## A party colour as it shows on the dark: a little brighter, so deep blues and browns still read.
static func lit(c: Color) -> Color:
	return Color.from_hsv(c.h, minf(c.s, 0.78), maxf(c.v, 0.78), c.a)

static var _shaders := {}

## A material from res://shaders/<name>.gdshader. Each call gives its own material, so
## its settings can differ from one picture or panel to the next.
static func material(name: String, params := {}) -> ShaderMaterial:
	if not _shaders.has(name): _shaders[name] = load("res://shaders/%s.gdshader" % name)
	var m = ShaderMaterial.new()
	m.shader = _shaders[name]
	for k in params: m.set_shader_parameter(k, params[k])
	return m

## Textures made from noise, so nothing needs to be painted.
static func noise_texture(w: int, h: int, c1: Color, c2: Color, freq := 0.05, seed := 1) -> NoiseTexture2D:
	var n = FastNoiseLite.new()
	n.seed = seed
	n.frequency = freq
	n.fractal_octaves = 4
	var g = Gradient.new()
	g.set_color(0, c1)
	g.set_color(1, c2)
	var t = NoiseTexture2D.new()
	t.width = w
	t.height = h
	t.noise = n
	t.color_ramp = g
	t.seamless = true
	return t
