## photo.gd — a photograph, shown through the one treatment every picture in the game
## gets (shaders/photo.gdshader), so pictures from many sources look like one newspaper.
##
## Pictures are plain files in godot/assets/ (a mod may add or replace them):
##   events/<event id>.jpg      a picture for one event; else events/_<kind>.jpg (crisis,
##                              scandal, foreign...) is used for every event of that kind
##   portraits/<name>.jpg       a leader, by name in small letters with dashes
##                              ("aurel-mendrik.jpg"), or by party id ("nup.jpg");
##                              also carlos.jpg and margaret.jpg
##   tours/<region>_<kind>.jpg  the leader on the road; else tours/<kind>.jpg
##   places/<country id>.jpg    a neighbouring country, on its profile
## jpg, png and webp all work. Nothing is required: a missing picture is simply not shown.
class_name Photo
extends Control

const EXTS := ["jpg", "jpeg", "png", "webp"]

var texture: Texture2D
var on_screen := false       # true on a television: cold light and scan lines instead of paper and dots
var round := false
var _mat: ShaderMaterial

## The first of these files that exists (names without extension, under res://assets/), or null.
static func find(names: Array) -> Texture2D:
	for n in names:
		if n == "": continue
		for ext in EXTS:
			var p = "res://assets/%s.%s" % [n, ext]
			if Mods.has_asset(p): return Mods.texture(p)
	return null

## "Aurel Mendrik" -> "aurel-mendrik"
static func slug(name: String) -> String:
	var out = ""
	for ch in name.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"): out += ch
		elif not out.ends_with("-"): out += "-"
	return out.trim_prefix("-").trim_suffix("-")

static func event(ev: Dictionary) -> Texture2D:
	return find(["events/" + str(ev.get("id", "")), "events/_" + str(ev.get("kind", ""))])

static func portrait(leader: String, party_id := "") -> Texture2D:
	return find(["portraits/" + slug(leader), ("portraits/" + party_id) if party_id != "" else ""])

func _init(tex: Texture2D = null, screen := false, circle := false) -> void:
	texture = tex
	on_screen = screen
	round = circle
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = Look.material("photo", {"shadow": Look.mix(Look.N950, Look.INK, 0.5), "light": Look.PAPER})
	material = _mat
	if on_screen:
		_mat.set_shader_parameter("light", Color("e6ecf5"))
		_mat.set_shader_parameter("shadow", Look.N950)
		_mat.set_shader_parameter("dots", 0.0)
		_mat.set_shader_parameter("lines", 0.22)
	if round:
		_mat.set_shader_parameter("round", true)
		_mat.set_shader_parameter("vignette", 0.15)
	resized.connect(queue_redraw)

func _draw() -> void:
	if texture == null: return
	# fill the frame, cutting off whatever doesn't fit (a little more off the bottom than the top: faces are high)
	var ts: Vector2 = texture.get_size()
	var k = maxf(size.x / ts.x, size.y / ts.y)
	var shown = size / (ts * k)          # the share of the picture that fits, per axis
	var off = Vector2((1.0 - shown.x) / 2.0, (1.0 - shown.y) * 0.3)
	_mat.set_shader_parameter("crop", Vector4(off.x, off.y, shown.x, shown.y))
	_mat.set_shader_parameter("px", size)
	draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false)
