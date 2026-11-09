## look.gd — the back-room look: colours, fonts and small builders for UI pieces.
## Chrome is dark tobacco and brass; everything you read is paper.
class_name Look
extends RefCounted

# ---------- Colours ----------
const T900 := Color("110c08")
const T800 := Color("1b140e")
const T700 := Color("2a1f16")
const T600 := Color("3a2b1f")
const BRASS := Color("c9a45c")
const BRASS_DIM := Color("8a6f3e")
const CREAM := Color("f3e7cc")
const CREAM_DIM := Color("b9a583")
const HEAD := Color("fbefd2")
const RED := Color("b3261e")
const OXBLOOD := Color("7d2219")
const AMBER := Color("e0a64a")
const GOOD := Color("2f7a45")
const PAPER := Color("f6efdc")
const PAPER_2 := Color("efe3c6")
const INK := Color("221c15")
const MUTED := Color("6b5d4b")
const LINE := Color("d3c4a3")
const SEA := Color("8ea4a0")
const LAND := Color("eadcb9")
const LAND_FOREIGN := Color("cdbe9c")
const BORDER := Color("2c1e12")
const CORK := Color("9c6f41")

const PIN_COLORS := {"red": Color("c0392b"), "yellow": Color("d4a017"), "blue": Color("2c6db3"), "green": Color("2f8a4c"), "black": Color("2b2b2b")}

# ---------- Fonts ----------
static var _fonts := {}

static func _file(path: String) -> FontFile:
	return load(path) as FontFile

static func font(name: String) -> Font:
	if _fonts.has(name): return _fonts[name]
	var f: Font
	match name:
		"display", "display_bold", "display_light":
			var v = FontVariation.new()
			v.base_font = _file("res://assets/fonts/Oswald.ttf")
			var w = {"display": 500, "display_bold": 650, "display_light": 400}[name]
			v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): w}
			f = v
		"type": f = _file("res://assets/fonts/SpecialElite.ttf")
		"news": f = _file("res://assets/fonts/OldStandard-Regular.ttf")
		"news_bold": f = _file("res://assets/fonts/OldStandard-Bold.ttf")
		"news_italic": f = _file("res://assets/fonts/OldStandard-Italic.ttf")
		"body": f = _file("res://assets/fonts/Plex-Regular.ttf")
		"body_bold": f = _file("res://assets/fonts/Plex-SemiBold.ttf")
		"body_italic": f = _file("res://assets/fonts/Plex-Italic.ttf")
		_: f = _file("res://assets/fonts/Plex-Regular.ttf")
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
static func label(text: String, font_name := "body", size := 15, color := INK, wrap := false) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_override("font", font(font_name))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func caps(text: String, size := 12, color := MUTED, spacing := 2, font_name := "display") -> Label:
	var l = label(text.to_upper(), font_name, size, color)
	l.add_theme_font_override("font", spaced(font_name, spacing))
	return l

static func box(bg: Color, radius := 0, border := Color.TRANSPARENT, border_w := 0, shadow := 0, pad := 0) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if border_w > 0:
		s.border_color = border
		s.set_border_width_all(border_w)
	if shadow > 0:
		s.shadow_color = Color(0, 0, 0, 0.45)
		s.shadow_size = shadow
		s.shadow_offset = Vector2(0, shadow * 0.5)
	if pad > 0: s.set_content_margin_all(pad)
	return s

static func icon(name: String) -> Texture2D:
	var p = "res://assets/icons/%s.svg" % name
	return load(p) if ResourceLoader.exists(p) else null

static func mix(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, clampf(t, 0, 1))

## Paper and cork textures made from noise, so nothing needs to be painted.
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
