## map_view.gd — the designer's map: regions, neighbours, cities, rivers and
## mountains. Shapes come from content.json (built from the Krita file).
## Scroll to zoom, drag to move, click a region or a neighbour.
class_name MapView
extends Control

signal region_clicked(id: String)
signal foreign_clicked(id: String)

var W = 2480.0
var H = 1754.0
var areas: Array = []          # {id, kind, name, polys, label, small}
var cities: Array = []
var capital = ""
var fills = {}                # area id -> Color
var shares = {}               # region id -> short text under the name
var hot = {}                  # foreign id -> bool (in conflict)
var tip_provider: Callable     # (id, kind) -> Array of lines; first is the title

var zoom = 1.0
var offset = Vector2.ZERO     # extra pan, in screen pixels
var hover = ""
var hover_kind = ""
var _mouse = Vector2.ZERO
var _drag_from = null
var _dragged = false
var _features: Texture2D
var _grain: Texture2D
var _plates = {}              # foreign id -> Rect2 (screen) for tiny countries

func setup(game) -> void:
	var m: Dictionary = game.MAP
	W = m.w; H = m.h
	capital = m.capital
	cities = m.cities
	areas.clear()
	for r in game.REGIONS:
		areas.append({"id": r.id, "kind": "region", "name": r.name, "polys": _parse(m.regions[r.id].d), "label": m.regions[r.id].label, "small": false})
	for f in game.FOREIGN:
		areas.append({"id": f.id, "kind": "foreign", "name": f.name, "polys": _parse(m.foreign[f.id].d), "label": m.foreign[f.id].label, "small": f.get("small", false)})
	_features = load("res://assets/map-features.png")
	_grain = Look.noise_texture(512, 512, Color(0.35, 0.25, 0.12, 0.0), Color(0.35, 0.25, 0.12, 0.22), 0.02, 4)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	queue_redraw()

## "M x y x y ... Z M ..." -> list of cleaned polygons
func _parse(d: String) -> Array:
	var out = []
	for part in d.split("M", false):
		var nums = part.replace("Z", "").strip_edges().split(" ", false)
		var pts = PackedVector2Array()
		for i in range(0, nums.size() - 1, 2):
			pts.append(Vector2(float(nums[i]), float(nums[i + 1])))
		if pts.size() < 3: continue
		if Geometry2D.triangulate_polygon(pts).is_empty():
			var fixed = Geometry2D.offset_polygon(pts, 0.01)
			for fp in fixed:
				if not Geometry2D.triangulate_polygon(fp).is_empty(): out.append(fp)
		else:
			out.append(pts)
	return out

# ---------- Coordinates ----------
func _scale() -> float:
	var fit = minf((size.x - 36) / W, (size.y - 36) / H)
	return fit * zoom

func _origin() -> Vector2:
	return (size - Vector2(W, H) * _scale()) / 2 + offset

func to_screen(p: Vector2) -> Vector2:
	return _origin() + p * _scale()

func to_map(p: Vector2) -> Vector2:
	return (p - _origin()) / _scale()

# ---------- Input ----------
func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and e.pressed:
			var before = to_map(e.position)
			zoom = clampf(zoom * (1.15 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1 / 1.15), 1.0, 4.0)
			offset += e.position - to_screen(before)
			_clamp_offset()
			queue_redraw()
			accept_event()
		elif e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_drag_from = e.position; _dragged = false
			else:
				if not _dragged: _click(e.position)
				_drag_from = null
	elif e is InputEventMouseMotion:
		_mouse = e.position
		if _drag_from != null and (e.button_mask & MOUSE_BUTTON_MASK_LEFT):
			if _dragged or e.position.distance_to(_drag_from) > 6:
				_dragged = true
				offset += e.relative
				_clamp_offset()
		_update_hover(e.position)
		queue_redraw()

func _clamp_offset() -> void:
	var s = _scale()
	var slack = (Vector2(W, H) * s - size) / 2 + Vector2(60, 60)
	slack = Vector2(maxf(slack.x, 0), maxf(slack.y, 0))
	offset = offset.clamp(-slack, slack)

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		hover = ""; queue_redraw()
	elif what == NOTIFICATION_RESIZED:
		_clamp_offset()

func _hit(screen: Vector2) -> Dictionary:
	for id in _plates:
		if _plates[id].has_point(screen): return {"id": id, "kind": "foreign"}
	var p = to_map(screen)
	for kind in ["region", "foreign"]:
		for a in areas:
			if a.kind != kind: continue
			for poly in a.polys:
				if Geometry2D.is_point_in_polygon(p, poly): return {"id": a.id, "kind": a.kind}
	return {}

func _update_hover(pos: Vector2) -> void:
	var h = _hit(pos)
	hover = h.get("id", "")
	hover_kind = h.get("kind", "")
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hover != "" else Control.CURSOR_ARROW

func _click(pos: Vector2) -> void:
	var h = _hit(pos)
	if h.is_empty(): return
	if h.kind == "region": region_clicked.emit(h.id)
	else: foreign_clicked.emit(h.id)

# ---------- Drawing ----------
func _draw() -> void:
	var s = _scale()
	var o = _origin()
	var map_rect = Rect2(o, Vector2(W, H) * s)
	# the desk under the map
	draw_rect(Rect2(Vector2.ZERO, size), Color("1a130d"))
	draw_rect(map_rect.grow(10), Color(0, 0, 0, 0.35))
	draw_rect(map_rect.grow(4), Color(0, 0, 0, 0.5))
	# sea and its waves
	draw_rect(map_rect, Look.SEA)
	var wave = Color("40606a", 0.28)
	var step = 46.0
	var y = 20.0
	while y < H:
		var pts = PackedVector2Array()
		var x = 0.0
		while x <= W:
			pts.append(to_screen(Vector2(x, y + sin(x / 22.0 + y) * 5)))
			x += 18
		draw_polyline(pts, wave, maxf(1.0, 2.2 * s))
		y += step
	# land: neighbours, then regions
	for kind in ["foreign", "region"]:
		for a in areas:
			if a.kind != kind: continue
			var col: Color = fills.get(a.id, Look.LAND if kind == "region" else Look.LAND_FOREIGN)
			if kind == "foreign" and hot.get(a.id, false): col = Look.mix(col, Color("c0392b"), 0.35)
			if a.id == hover: col = col.lightened(0.12)
			for poly in a.polys:
				var sp = PackedVector2Array()
				for p in poly: sp.append(o + p * s)
				draw_colored_polygon(sp, col)
				if kind == "foreign": _hatch(sp)
	# borders in ink
	for kind in ["foreign", "region"]:
		for a in areas:
			if a.kind != kind: continue
			for poly in a.polys:
				var sp = PackedVector2Array()
				for p in poly: sp.append(o + p * s)
				sp.append(sp[0])
				var w = maxf(1.6, 5.0 * s) if kind == "region" else maxf(1.2, 3.5 * s)
				draw_polyline(sp, Look.BORDER, w, true)
	# the hovered region gets a warm outline
	if hover != "":
		for a in areas:
			if a.id != hover: continue
			for poly in a.polys:
				var sp = PackedVector2Array()
				for p in poly: sp.append(o + p * s)
				sp.append(sp[0])
				draw_polyline(sp, Color("ffe6a8", 0.9), maxf(2.0, 7.0 * s), true)
	# rivers and mountains from Krita
	if _features: draw_texture_rect(_features, map_rect, false, Color(1, 1, 1, 0.85))
	# cities
	for c in cities:
		var p = to_screen(Vector2(c.x, c.y))
		if c.name == capital:
			_star(p, maxf(7.0, 22 * s), Look.RED)
		else:
			var r = maxf(2.5, (5 + c.size * 2.5) * s)
			draw_circle(p, r + maxf(1.0, 2.5 * s), Color("f1e4c4"))
			draw_circle(p, r, Look.BORDER)
	_plates.clear()
	_labels(s)
	# paper grain over everything
	if _grain: draw_texture_rect(_grain, map_rect, true)
	_legend()
	if hover != "" and tip_provider.is_valid(): _tooltip()

var legend: Array = []   # [[short name, Color], ...]
var legend_note := ""

func _legend() -> void:
	if legend.is_empty(): return
	var head := Look.spaced("display", 2)
	var body := Look.font("body_bold")
	var x := 16.0
	var w := 0.0
	for item in legend: w += 22 + body.get_string_size(item[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	w = maxf(w, Look.font("body").get_string_size(legend_note, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x) + 28
	var rect := Rect2(Vector2(14, 14), Vector2(w, 78))
	draw_rect(rect, Color(0.08, 0.06, 0.04, 0.88))
	draw_rect(rect, Look.BRASS, false, 1.0)
	draw_string(head, rect.position + Vector2(14, 24), "WHO LEADS WHERE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Look.HEAD)
	var cx := rect.position.x + 14
	for item in legend:
		draw_circle(Vector2(cx + 5, rect.position.y + 42), 5, item[1])
		draw_string(body, Vector2(cx + 14, rect.position.y + 47), item[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Look.CREAM)
		cx += 22 + body.get_string_size(item[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(Look.font("body"), rect.position + Vector2(14, 68), legend_note, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Look.CREAM_DIM)

func _hatch(poly: PackedVector2Array) -> void:
	var bb = Rect2(poly[0], Vector2.ZERO)
	for p in poly: bb = bb.expand(p)
	var gap = 14.0
	var c = Color("6b5a40", 0.22)
	var d = -bb.size.y
	while d < bb.size.x:
		var a = bb.position + Vector2(d, bb.size.y)
		var b = bb.position + Vector2(d + bb.size.y, 0)
		var segs = Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, b]), poly)
		for sg in segs: draw_polyline(sg, c, 1.0)
		d += gap

func _star(c: Vector2, r: float, col: Color) -> void:
	var pts = PackedVector2Array()
	for i in 10:
		var ang = -PI / 2 + i * PI / 5
		var rr = r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
	draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, Color("fff3dc"), maxf(1.0, r * 0.12), true)

func _text(pos: Vector2, text: String, font: Font, fsize: int, col: Color, halo := Color.TRANSPARENT, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	var p = pos - Vector2(w / 2.0 if align == HORIZONTAL_ALIGNMENT_CENTER else 0.0, 0)
	if halo.a > 0: draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, maxi(2, fsize / 5), halo)
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)

func _labels(s: float) -> void:
	var halo = Color(0.92, 0.86, 0.73, 0.75)
	# city names
	var type_font = Look.font("type")
	for c in cities:
		var is_cap: bool = c.name == capital
		var fs = int(maxf(10, (32 if is_cap else 25) * s))
		_text(to_screen(Vector2(c.lx, c.ly + 9)), c.name, type_font, fs, Look.BORDER, halo)
	# neighbours
	for a in areas:
		if a.kind != "foreign": continue
		if a.small:
			_plate(a, s)
			continue
		var k: float = a.label[2] if a.label.size() > 2 else 1.0
		var fs = int(maxf(11, 46 * k * s))
		var lines: Array = a.name
		var lh = 62 * k
		var y0: float = a.label[1] - (lines.size() - 1) * lh / 2 + 16
		var x = clampf(a.label[0], 140, W - 140)
		for i in lines.size():
			_text(to_screen(Vector2(x, y0 + i * lh)), lines[i].to_upper(), Look.spaced("display_light", int(fs * 0.24)), fs, Color("5e4e36"))
	# regions with your share
	for a in areas:
		if a.kind != "region": continue
		var k: float = a.label[2] if a.label.size() > 2 else 1.0
		var fs = int(maxf(12, 62 * k * s))
		_text(to_screen(Vector2(a.label[0], a.label[1] + 2 * k)), a.name.to_upper(), Look.spaced("display_bold", int(fs * 0.14)), fs, Look.BORDER, halo)
		var sh: String = shares.get(a.id, "")
		if sh != "":
			_text(to_screen(Vector2(a.label[0], a.label[1] + 44 * k)), sh, type_font, int(maxf(10, 32 * maxf(k, 0.75) * s)), Color("3b2a1a"), halo)

func _plate(a: Dictionary, s: float) -> void:
	var c = to_screen(Vector2(a.label[0], a.label[1]))
	var p = to_screen(Vector2(a.label[0] + 190, a.label[1] + 85))
	var text: String = " ".join(a.name).to_upper()
	var fs = int(maxf(11, 30 * s))
	var font = Look.spaced("display", int(fs * 0.16))
	var tw = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var rect = Rect2(p - Vector2(tw / 2 + 12, fs * 0.9), Vector2(tw + 24, fs * 1.6))
	var hot_now: bool = hot.get(a.id, false)
	draw_line(c, rect.position + Vector2(0, rect.size.y / 2), Look.BORDER, maxf(1.0, 3 * s), true)
	draw_circle(c, maxf(2.5, 7 * s), Look.BORDER)
	draw_rect(Rect2(rect.position + Vector2(0, 3), rect.size), Color(0, 0, 0, 0.3))
	var bg = Look.mix(Look.PAPER, Color("c0392b"), 0.3) if hot_now else (Color("fff8e6") if hover == a.id else Look.PAPER)
	draw_rect(rect, bg)
	draw_rect(rect, Look.RED if hover == a.id else Look.BORDER, false, maxf(1.0, 2.5 * s))
	draw_string(font, Vector2(rect.position.x + 12, rect.position.y + rect.size.y * 0.5 + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Look.BORDER)
	_plates[a.id] = rect

func _tooltip() -> void:
	var lines: Array = tip_provider.call(hover, hover_kind)
	if lines.is_empty(): return
	var title_font = Look.font("display_bold")
	var body = Look.font("body")
	var w = 0.0
	for i in lines.size():
		var f = title_font if i == 0 else body
		w = maxf(w, f.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 16 if i == 0 else 13).x)
	w = minf(w, 300)
	var h = 26.0 + 19.0 * (lines.size() - 1) + 10
	var pos = _mouse + Vector2(18, 18)
	if pos.x + w + 24 > size.x: pos.x = _mouse.x - w - 30
	if pos.y + h > size.y: pos.y = _mouse.y - h - 10
	var rect = Rect2(pos, Vector2(w + 24, h))
	draw_rect(Rect2(rect.position + Vector2(3, 5), rect.size), Color(0, 0, 0, 0.35))
	draw_rect(rect, Look.PAPER)
	draw_rect(rect, Look.BORDER, false, 1.0)
	draw_string(title_font, rect.position + Vector2(12, 24), lines[0], HORIZONTAL_ALIGNMENT_LEFT, w, 16, Look.INK)
	for i in range(1, lines.size()):
		draw_string(body, rect.position + Vector2(12, 26 + 19 * i), lines[i], HORIZONTAL_ALIGNMENT_LEFT, w, 13, Look.MUTED)
