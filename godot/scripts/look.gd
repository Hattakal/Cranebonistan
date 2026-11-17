## look.gd — the look of the game: colours, fonts and small builders for UI pieces.
##
## The campaign at night. Everything around you is cold and dark (the office, the
## map, the files); what you hold in your hand is paper under a warm desk lamp
## (decisions, speeches, the morning clips). Colour is rationed: party colours,
## one warm light (LAMP) and one red (danger, and the thing to press next).
class_name Look
extends RefCounted

# ---------- Colours ----------
# the night: backgrounds, from the deepest shadow up to a raised, hovered surface
const N950 := Color("06080c")
const N900 := Color("0a0d13")
const N850 := Color("0f131b")
const N800 := Color("141923")
const N700 := Color("1b2230")
const N600 := Color("273042")
const N500 := Color("3a465b")
# text on the dark
const TXT := Color("e8ebf1")
const DIM := Color("9aa5b7")
const FAINT := Color("66738a")
# the one warm light, and the one red
const LAMP := Color("f2b866")
const LAMP_DIM := Color("a9844d")
const RED := Color("d2392f")
const RED_HI := Color("ff6a5c")     # red text on the dark
const OXBLOOD := Color("8f231c")
const GOOD := Color("1f7d55")       # on paper
const GOOD_HI := Color("5cc79a")    # on the dark
const AMBER := LAMP
# paper under the lamp, and ink on it
const PAPER := Color("efebe2")
const PAPER_2 := Color("e3ded3")
const CARD := Color("f8f5ee")
const INK := Color("14171d")
const MUTED := Color("5b626e")
const LINE := Color("c8c3b7")
const NEWSPRINT := Color("e7e1d1")   # cheaper, greyer paper: the newspapers
# the map at night
const SEA := Color("0a0e15")
const LAND := Color("1a212d")
const LAND_FOREIGN := Color("121720")
const BORDER := Color("06080c")
# older names still used here and there
const HEAD := TXT
const CREAM := TXT
const CREAM_DIM := DIM
const BRASS := N500
const BRASS_DIM := N600
const T900 := N900

# ---------- Fonts ----------
# display: Barlow Condensed (labels, numbers, buttons)     body: IBM Plex Sans Condensed
# news:    Newsreader (headlines, the papers, speeches)    type: IBM Plex Mono (memos, datelines)
# hand:    Caveat (a note in the margin)
# blackletter: Manufacturing Consent (a broadsheet's nameplate)   redtop: Barlow, heavy and slanted (a tabloid's)
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
		"blackletter": f = _file("res://assets/fonts/ManufacturingConsent.ttf")
		"redtop":   # a tabloid's nameplate: heavy, leaning forward
			var rt = FontVariation.new()
			rt.base_font = _file("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
			rt.variation_embolden = 0.35
			rt.variation_transform = Transform2D(Vector2(1, 0), Vector2(-0.2, 1), Vector2.ZERO)
			f = rt
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
