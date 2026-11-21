## face.gd — a leader's face in a circle: their photograph (see photo.gd for where the
## files go) or, until there is one, their initials on the party colour.
class_name Face
extends Control

var col := Color.GRAY
var initials := ""
var _photo: Photo = null

func _init(leader: String, color: Color, party_id := "", diameter := 42) -> void:
	col = color
	var parts: PackedStringArray = leader.split(" ", false)
	if parts.size(): initials = (parts[0][0] + (parts[-1][0] if parts.size() > 1 else "")).to_upper()
	custom_minimum_size = Vector2(diameter, diameter)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tooltip_text = leader
	var tex = Photo.portrait(leader, party_id)
	if tex:
		_photo = Photo.new(tex, true, true)
		_photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_photo)
	resized.connect(queue_redraw)

func _draw() -> void:
	var c = size / 2
	var r = minf(size.x, size.y) / 2
	if _photo == null:
		draw_circle(c, r, col.darkened(0.15))
		var f = Look.font("display_bold")
		var fs = int(r * 0.9)
		var w = f.get_string_size(initials, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, c + Vector2(-w / 2, fs * 0.36), initials, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	# a ring in the party's colour, drawn by a child so it sits over the photograph
	if _ring == null:
		_ring = Ring.new()
		_ring.col = Look.lit(col)
		_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_ring)

var _ring: Ring = null

class Ring extends Control:
	var col := Color.WHITE
	func _ready() -> void:
		resized.connect(queue_redraw)
	func _draw() -> void:
		draw_arc(size / 2, minf(size.x, size.y) / 2 - 0.75, 0, TAU, 48, col, 1.5, true)
