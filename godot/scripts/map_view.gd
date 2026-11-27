## map_view.gd — the designer's map, seen at night: the country lit in party colours,
## its neighbours each in a muted colour of their own on a blue sea, cities as points of light, rivers and mountains. Shapes come from content.json (built from the Krita file).
## Scroll to zoom, drag to move, click a region or a neighbour.
class_name MapView
extends Control

signal region_clicked(id: String)
signal foreign_clicked(id: String)
signal district_clicked(id: String)
signal pin_clicked(id: String)

var W = 2480.0
var H = 1754.0
var areas: Array = []          # {id, kind, name, polys, label, small}
var waters: Array = []         # {name, x, y}: seas and lakes
var districts: Array = []      # {id, region, name, polys, label, seats}
var cities: Array = []
var capital = ""
var fills = {}                # area id -> Color
var stripes = {}              # district id -> [Color, 0..1]: your colour striped over the leader's, thicker as your vote grows
var shares = {}               # region id -> short text under the name
var hot = {}                  # foreign id -> bool (in conflict)
var communities = {}          # city name -> level of your party's community
var convoys: Array = []       # the campaign convoys this week: [{pos (map), color, short}], small cars
var route_stops: Array = []   # the convoy: [{pos (map), n, done}], drawn as a numbered line
var rival_tags: Array = []    # rivals campaigning: [{district, short, color, fresh}], small tags on the vote map
var pins: Array = []          # local stories and events: [{id, district, region, title}]; no district: the whole region
var _pin_rects = {}           # story id -> Rect2 (screen)
var party_color := Look.RED
var _shown = {}               # colours on screen, easing towards fills
var _flash = {}               # region id -> 1..0, after it changes hands
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
var capital_district = ""     # the capital's own small district: its star is a click target too
var _cap_spot = Rect2()       # screen area of the capital's star and name

func setup(game) -> void:
	var m: Dictionary = game.MAP
	W = m.w; H = m.h
	capital = m.capital
	cities = m.cities
	waters = m.get("waters", [])
	areas.clear()
	for r in game.REGIONS:
		areas.append({"id": r.id, "kind": "region", "name": r.name, "polys": _parse(m.regions[r.id].d), "label": m.regions[r.id].label, "small": false})
	for f in game.FOREIGN:
		areas.append({"id": f.id, "kind": "foreign", "name": f.name, "polys": _parse(m.foreign[f.id].d), "label": m.foreign[f.id].label, "small": f.get("small", false),
			"color": Look.mix(Look.LAND_FOREIGN, Color(f.get("mapColor", "#cdbe9c")), 0.3)})
	districts.clear()
	for d in game.DISTRICTS:
		districts.append({"id": d.id, "region": d.region, "name": d.name, "polys": _parse(d.d), "label": d.label, "seats": int(d.seats), "area": float(d.get("area", 1.0))})
		if d.cities.has(capital): capital_district = d.id
	# big districts first, so a small one inside another (the capital) is drawn on top and clicked first
	districts.sort_custom(func(a, b): return a.area > b.area)
	_features = Mods.texture("res://assets/map-features.png")
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	queue_redraw()

## A region changed hands: ring it for a moment.
func flash(id: String) -> void:
	_flash[id] = 1.0

func _process(d: float) -> void:
	var moving = false
	# W A S D (or the arrow keys) move the map while the mouse is over it
	if get_viewport().gui_get_hovered_control() == self and get_viewport().gui_get_focus_owner() == null:
		var dir = Vector2.ZERO
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): dir.x += 1
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): dir.x -= 1
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): dir.y += 1
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): dir.y -= 1
		if dir != Vector2.ZERO:
			offset += dir * 700.0 * d
			_clamp_offset()
			moving = true
	for id in fills:
		var target: Color = fills[id]
		var cur: Color = _shown.get(id, target)
		if not _shown.has(id) or cur.is_equal_approx(target):
			_shown[id] = target
			continue
		var k = 1.0 - exp(-d * 3.5)
		cur = cur.lerp(target, k)
		if absf(cur.r - target.r) + absf(cur.g - target.g) + absf(cur.b - target.b) < 0.004: cur = target
		_shown[id] = cur
		moving = true
	for id in _flash.keys():
		_flash[id] -= d / 1.6
		if _flash[id] <= 0: _flash.erase(id)
		moving = true
	if moving: queue_redraw()

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
	for id in _pin_rects:
		if _pin_rects[id].has_point(screen): return {"id": id, "kind": "pin"}
	for id in _plates:
		if _plates[id].has_point(screen): return {"id": id, "kind": "foreign"}
	if capital_district != "" and _cap_spot.has_point(screen): return {"id": capital_district, "kind": "district"}
	var p = to_map(screen)
	for i in range(districts.size() - 1, -1, -1):
		var d: Dictionary = districts[i]
		for poly in d.polys:
			if Geometry2D.is_point_in_polygon(p, poly): return {"id": d.id, "kind": "district"}
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
	if h.kind == "pin": pin_clicked.emit(h.id)
	elif h.kind == "district": district_clicked.emit(h.id)
	elif h.kind == "region": region_clicked.emit(h.id)
	else: foreign_clicked.emit(h.id)

# ---------- Drawing ----------
func _draw() -> void:
	var s = _scale()
	var o = _origin()
	var map_rect = Rect2(o, Vector2(W, H) * s)
	# the sea is a deep night blue: no frame, only a faint grid, as on a situation-room wall
	draw_rect(Rect2(Vector2.ZERO, size), Look.SEA)
	var grid = Color(Look.N700, 0.55)
	var step = 155.0
	var gx = 0.0
	while gx <= W + 1:
		draw_line(to_screen(Vector2(gx, 0)), to_screen(Vector2(gx, H)), grid, 1.0)
		gx += step
	var gy = 0.0
	while gy <= H + 1:
		draw_line(to_screen(Vector2(0, gy)), to_screen(Vector2(W, gy)), grid, 1.0)
		gy += step
	# land: neighbours, then regions
	for kind in ["foreign", "region"]:
		if kind == "region":
			# the national border: light spilling over the edge of the country. Wide soft lines
			# round every region, half of them then hidden under the regions' own fill
			for a in areas:
				if a.kind != "region": continue
				for poly in a.polys:
					var sp = PackedVector2Array()
					for p in poly: sp.append(o + p * s)
					sp.append(sp[0])
					draw_polyline(sp, Color(Look.TXT, 0.05), maxf(14.0, 46.0 * s), true)
					draw_polyline(sp, Color(Look.TXT, 0.08), maxf(8.0, 24.0 * s), true)
					draw_polyline(sp, Color(Look.TXT, 0.5), maxf(3.0, 9.0 * s), true)
		for a in areas:
			if a.kind != kind: continue
			var col: Color = _shown.get(a.id, fills.get(a.id, Look.LAND if kind == "region" else a.get("color", Look.LAND_FOREIGN)))
			if kind == "foreign" and hot.get(a.id, false): col = Look.mix(col, Look.RED, 0.3)
			if a.id == hover: col = col.lightened(0.07)
			for poly in a.polys:
				var sp = PackedVector2Array()
				for p in poly: sp.append(o + p * s)
				draw_colored_polygon(sp, col)
	# districts: each painted in the colour of the party that would win it
	for d in districts:
		var col: Color = _shown.get(d.id, fills.get(d.id, Look.LAND))
		if d.id == hover: col = col.lightened(0.14)
		for poly in d.polys:
			var sp = PackedVector2Array()
			for p in poly: sp.append(o + p * s)
			draw_colored_polygon(sp, col)
			if stripes.has(d.id): _stripes(sp, stripes[d.id][0], float(stripes[d.id][1]))
	for d in districts:
		for poly in d.polys:
			var sp = PackedVector2Array()
			for p in poly: sp.append(o + p * s)
			sp.append(sp[0])
			draw_polyline(sp, Color(Look.BORDER, 0.6), maxf(1.0, 2.2 * s), true)
	# borders in ink
	for kind in ["foreign", "region"]:
		for a in areas:
			if a.kind != kind: continue
			for poly in a.polys:
				var sp = PackedVector2Array()
				for p in poly: sp.append(o + p * s)
				sp.append(sp[0])
				if kind == "region": draw_polyline(sp, Look.BORDER, maxf(1.8, 5.0 * s), true)
				else: draw_polyline(sp, Look.N600, maxf(1.0, 2.2 * s), true)
	# the hovered region gets a warm outline
	if hover != "":
		for a in areas + districts:
			if a.id != hover: continue
			for poly in a.polys:
				var sp = PackedVector2Array()
				for p in poly: sp.append(o + p * s)
				sp.append(sp[0])
				draw_polyline(sp, Color(Look.LAMP, 0.95), maxf(2.0, 5.0 * s), true)
	# regions that just changed hands ring outwards
	for id in _flash:
		var t: float = _flash[id]
		for a in areas + districts:
			if a.id != id: continue
			for poly in a.polys:
				var sp = PackedVector2Array()
				for p in poly: sp.append(o + p * s)
				sp.append(sp[0])
				var c: Color = fills.get(id, Look.RED).lightened(0.45)
				c.a = t
				draw_polyline(sp, c, maxf(2.0, (6.0 + (1.0 - t) * 18.0) * s), true)
	# rivers and mountains from Krita
	if _features: draw_texture_rect(_features, map_rect, false, Color(1, 1, 1, 0.5))
	# the map has no frame: its edges sink into the dark
	var fade = minf(90.0, map_rect.size.x * 0.06)
	var clear = Color(Look.SEA, 0.0)
	for side in 4:
		var q: PackedVector2Array
		var a0 = map_rect.position; var b0 = map_rect.end
		match side:
			0: q = PackedVector2Array([a0, Vector2(b0.x, a0.y), Vector2(b0.x, a0.y + fade), Vector2(a0.x, a0.y + fade)])
			1: q = PackedVector2Array([Vector2(a0.x, b0.y), b0, Vector2(b0.x, b0.y - fade), Vector2(a0.x, b0.y - fade)])
			2: q = PackedVector2Array([a0, Vector2(a0.x, b0.y), Vector2(a0.x + fade, b0.y), Vector2(a0.x + fade, a0.y)])
			_: q = PackedVector2Array([Vector2(b0.x, a0.y), b0, Vector2(b0.x - fade, b0.y), Vector2(b0.x - fade, a0.y)])
		draw_polygon(q, PackedColorArray([Look.SEA, Look.SEA, clear, clear]))
	# cities
	for c in cities:
		var p = to_screen(Vector2(c.x, c.y))
		# every city is a point of warm light; the capital is the brightest, with a ring round it
		if c.name == capital:
			var r = maxf(11.0, 28 * s)
			_light(p, r * 0.55)
			draw_arc(p, r, 0, TAU, 40, Color.WHITE if hover == capital_district and capital_district != "" else Color(Look.TXT, 0.85), maxf(1.5, 3.0 * s), true)
			_cap_spot = Rect2(p - Vector2(r, r) * 1.4, Vector2(r, r) * 2.8)
		else:
			_light(p, maxf(2.2, (4 + c.size * 2.2) * s))
		# your party's community there: a ring, thicker as it grows
		var lvl = int(communities.get(c.name, 0))
		if lvl > 0:
			var rr = maxf(8.0, (20 + lvl * 6) * s)
			draw_arc(p, rr, 0, TAU, 32, Look.lit(party_color), maxf(1.5, (2 + lvl) * s), true)
	_plates.clear()
	if zoom >= 1.5: _seat_badges(s)   # seat numbers only when zoomed in; the tooltip always has them
	_labels(s)
	_route(s)
	_convoy_cars(s)
	_rival_tags(s)
	_pins(s)
	if Settings.get_value("mapedge") == "fade": _fade_edges()
	_legend()
	if hover != "" and tip_provider.is_valid(): _tooltip()

## The map dissolving into the dark at its edges, like light falling off a desk lamp
## (an option: Settings "mapedge").
func _fade_edges() -> void:
	var dark: Color = Look.N950
	var clear: Color = Color(dark, 0.0)
	var w: float = size.x * 0.14
	var h: float = size.y * 0.14
	var R = Rect2(Vector2.ZERO, size)
	var quads = [
		[R.position, Vector2(R.position.x + w, R.position.y), Vector2(R.position.x + w, R.end.y), Vector2(R.position.x, R.end.y), [dark, clear, clear, dark]],
		[Vector2(R.end.x - w, R.position.y), Vector2(R.end.x, R.position.y), R.end, Vector2(R.end.x - w, R.end.y), [clear, dark, dark, clear]],
		[R.position, Vector2(R.end.x, R.position.y), Vector2(R.end.x, R.position.y + h), Vector2(R.position.x, R.position.y + h), [dark, dark, clear, clear]],
		[Vector2(R.position.x, R.end.y - h), Vector2(R.end.x, R.end.y - h), R.end, Vector2(R.position.x, R.end.y), [clear, clear, dark, dark]],
	]
	for q in quads: draw_polygon(PackedVector2Array([q[0], q[1], q[2], q[3]]), PackedColorArray(q[4]))

var legend: Array = []   # [[short name and seats, Color, seats], ...]; without seats, just a key
var legend_note := ""
var legend_title := "IF THE ELECTION WERE TODAY"
var legend_ramp: Array = []   # a colour scale instead: [low Color, high Color, low word, high word]

func _legend() -> void:
	if legend.is_empty() and legend_ramp.is_empty(): return
	var head := Look.spaced("display", 2)
	var body := Look.font("body_bold")
	var w := 0.0
	for item in legend: w += 22 + body.get_string_size(item[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	w = maxf(w, Look.font("body").get_string_size(legend_note, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x) + 28
	w = maxf(w, head.get_string_size(legend_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 28)
	if legend_ramp.size(): w = maxf(w, 340)
	var rect := Rect2(Vector2(14, size.y - 96 - 14), Vector2(w, 96))   # bottom left: open sea on the designer's map
	draw_rect(rect, Color(Look.N850, 0.92))
	draw_rect(rect, Look.N600, false, 1.0)
	draw_string(head, rect.position + Vector2(14, 24), legend_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Look.DIM)
	if legend_ramp.size():
		# a colour scale, low to high, with a word at each end
		var rb := Rect2(rect.position + Vector2(14, 36), Vector2(w - 28, 10))
		var steps := 24
		for i in steps:
			var c: Color = Look.mix(legend_ramp[0], legend_ramp[1], float(i) / (steps - 1))
			draw_rect(Rect2(rb.position.x + rb.size.x * i / steps, rb.position.y, rb.size.x / steps + 1, rb.size.y), c)
		draw_string(body, rect.position + Vector2(14, 65), String(legend_ramp[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Look.CREAM)
		var hw: float = body.get_string_size(String(legend_ramp[3]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(body, Vector2(rect.end.x - 14 - hw, rect.position.y + 65), String(legend_ramp[3]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Look.CREAM)
		draw_string(Look.font("body"), rect.position + Vector2(14, 85), legend_note, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Look.FAINT)
		return
	# the Assembly as one strip, largest party first, with a tick at the majority
	var total := 0
	for item in legend: total += int(item[2]) if item.size() > 2 else 0
	var bar := Rect2(rect.position + Vector2(14, 34), Vector2(w - 28, 7))
	if total > 0: draw_rect(bar, Look.N600)
	if total > 0:
		var bx := bar.position.x
		for item in legend:
			var bw: float = bar.size.x * float(item[2]) / total
			draw_rect(Rect2(bx, bar.position.y, maxf(0.0, bw - 1.0), bar.size.y), item[1])
			bx += bw
		draw_rect(Rect2(bar.position.x + bar.size.x / 2 - 1, bar.position.y - 3, 2, bar.size.y + 6), Color.WHITE)
	var cx := rect.position.x + 14
	for item in legend:
		draw_circle(Vector2(cx + 5, rect.position.y + 60), 5, item[1])
		draw_string(body, Vector2(cx + 14, rect.position.y + 65), item[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Look.CREAM)
		cx += 22 + body.get_string_size(item[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(Look.font("body"), rect.position + Vector2(14, 85), legend_note, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Look.FAINT)

func _hatch(poly: PackedVector2Array) -> void:
	var bb = Rect2(poly[0], Vector2.ZERO)
	for p in poly: bb = bb.expand(p)
	var gap = 14.0
	var c = Color(1, 1, 1, 0.035)
	var d = -bb.size.y
	while d < bb.size.x:
		var a = bb.position + Vector2(d, bb.size.y)
		var b = bb.position + Vector2(d + bb.size.y, 0)
		var segs = Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, b]), poly)
		for sg in segs: draw_polyline(sg, c, 1.0)
		d += gap

## Diagonal bands of one colour over a shape; `k` (0..1) is how much of it they cover.
func _stripes(poly: PackedVector2Array, col: Color, k: float) -> void:
	if k <= 0.01: return
	var bb = Rect2(poly[0], Vector2.ZERO)
	for p in poly: bb = bb.expand(p)
	var gap = 24.0
	var w = maxf(2.0, gap * clampf(k, 0, 0.95))   # the band's share of each repeat is the share of the vote
	var d = -bb.size.y
	while d < bb.size.x:
		var a = bb.position + Vector2(d, bb.size.y)
		var b = bb.position + Vector2(d + bb.size.y, 0)
		for sg in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, b]), poly):
			draw_polyline(sg, col, w)
		d += gap

## A point of light with its glow.
func _light(c: Vector2, r: float) -> void:
	draw_circle(c, r * 4.5, Color(Look.LAMP, 0.05))
	draw_circle(c, r * 3.0, Color(Look.LAMP, 0.09))
	draw_circle(c, r * 1.9, Color(Look.LAMP, 0.2))
	draw_circle(c, r * 1.15, Color(Look.LAMP, 0.9))
	draw_circle(c, r * 0.7, Look.LAMP.lerp(Color.WHITE, 0.85))   # the white-hot middle of a light

func _text(pos: Vector2, text: String, font: Font, fsize: int, col: Color, halo := Color.TRANSPARENT, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	var p = pos - Vector2(w / 2.0 if align == HORIZONTAL_ALIGNMENT_CENTER else 0.0, 0)
	if halo.a > 0: draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, maxi(2, fsize / 5), halo)
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)

func _labels(s: float) -> void:
	var halo = Color(Look.N950, 0.8)
	# city names
	var type_font = Look.font("body")
	for c in cities:
		var is_cap: bool = c.name == capital
		var fs = int(maxf(14 if is_cap else 11, (36 if is_cap else 25) * s))
		var lp = to_screen(Vector2(c.lx, c.ly + 9))
		_text(lp, c.name, Look.font("body_bold") if is_cap else type_font, fs, Color.WHITE if is_cap else Color(Look.TXT, 0.82), halo)
		if is_cap:
			var tw = type_font.get_string_size(c.name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			_cap_spot = _cap_spot.merge(Rect2(lp - Vector2(tw / 2.0, fs), Vector2(tw, fs * 1.3)))
	# seas and lakes, as drawn on the Krita map
	var water_font = Look.font("body_italic")
	for w in waters:
		# one word to a line, so a small lake's name stays on the water
		var words: PackedStringArray = String(w.name).split(" ", false)
		var lake: bool = String(w.name).contains("Lake")   # a lake's name is smaller than a sea's
		var wfs = int(maxf(9, (20.0 if lake else 30.0) * s))
		var at: Vector2 = Vector2(w.x, w.y) + Vector2(float(w.get("dx", 6 if lake else 0)), float(w.get("dy", 6 if lake else 0)))
		for i in words.size():
			_text(to_screen(at) + Vector2(0, (i - (words.size() - 1) / 2.0) * wfs * 1.05), words[i], water_font, wfs, Look.WATER_TXT)
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
			_text(to_screen(Vector2(x, y0 + i * lh)), lines[i].to_upper(), Look.spaced("display_light", int(fs * 0.3)), fs, Look.FAINT)
	# regions with your share
	for a in areas:
		if a.kind != "region": continue
		var k: float = a.label[2] if a.label.size() > 2 else 1.0
		var fs = int(maxf(12, 62 * k * s))
		_text(to_screen(Vector2(a.label[0], a.label[1] + 2 * k)), a.name.to_upper(), Look.spaced("display_bold", int(fs * 0.22)), fs, Color.WHITE, halo)
		var sh: String = shares.get(a.id, "")
		if sh != "":
			_text(to_screen(Vector2(a.label[0], a.label[1] + 44 * k)), sh, Look.font("display"), int(maxf(12, 34 * maxf(k, 0.75) * s)), Color(Look.TXT, 0.8), halo)

## The convoy's route: a line through its stops, each numbered by week; the ones already
## made are faint, the next one ringed.
func _route(s: float) -> void:
	if route_stops.is_empty(): return
	var col: Color = Look.lit(party_color)
	var pts = route_stops.map(func(r): return to_screen(r.pos))
	for i in range(1, pts.size()):
		var done: bool = route_stops[i].done
		draw_line(pts[i - 1], pts[i], Color(Look.N950, 0.8), maxf(4.0, 7 * s), true)
		draw_line(pts[i - 1], pts[i], Color(col, 0.45 if done else 0.95), maxf(2.0, 3.5 * s), true)
	var f = Look.font("display_bold")
	var r = maxf(9.0, 17 * s)
	var next_shown = false
	for i in pts.size():
		var st: Dictionary = route_stops[i]
		draw_circle(pts[i], r + 2, Look.N950)
		draw_circle(pts[i], r, Color(col, 0.5) if st.done else col)
		if not st.done and not next_shown:
			draw_arc(pts[i], r + 5, 0, TAU, 32, Look.LAMP, 2.0, true)
			next_shown = true
		_text(pts[i] + Vector2(0, r * 0.45), str(st.n), f, int(r * 1.2), Look.N950)

## This week's rallies: a small car in each party's colour at its stop, side by side where
## two convoys meet.
func _convoy_cars(s: float) -> void:
	var w = maxf(22.0, 44 * s)
	var h = w * 0.42
	var at = {}
	for cv in convoys:
		var key: String = str(cv.pos)
		var n: int = int(at.get(key, 0))
		at[key] = n + 1
		var c: Vector2 = to_screen(cv.pos) + Vector2(-w * 0.5 + n * (w + 4) - w * 0.9, -h * 2.4)
		var body = Rect2(c + Vector2(0, h * 0.35), Vector2(w, h * 0.65))
		var cabin = Rect2(c + Vector2(w * 0.22, 0), Vector2(w * 0.5, h * 0.45))
		draw_rect(body.grow(2), Color(Look.N950, 0.85))
		draw_rect(cabin.grow(2), Color(Look.N950, 0.85))
		draw_rect(body, cv.color)
		draw_rect(cabin, cv.color.lightened(0.25))
		for x in [0.22, 0.78]:
			draw_circle(c + Vector2(w * x, h * 1.02), h * 0.24, Look.N950)

## Rival parties campaigning in a province lately: a small pennant in their colour, solid
## when they were there this month, faint the month after (the tooltip names them).
func _rival_tags(s: float) -> void:
	var h = maxf(14.0, 34 * s)
	var per = {}
	for t in rival_tags:
		var d = null
		for x in districts:
			if x.id == t.district: d = x
		if d == null: continue
		var n: int = int(per.get(t.district, 0))
		per[t.district] = n + 1
		var base = to_screen(Vector2(d.label[0] + 34, d.label[1] + 30)) + Vector2(n * h * 0.8, 0)
		var a: float = 1.0 if t.fresh else 0.5
		var top = base - Vector2(0, h * 1.6)
		draw_line(base, top, Color(Look.N950, 0.85 * a), maxf(3.0, 5 * s), true)
		draw_line(base, top, Color(Look.TXT, 0.9 * a), maxf(1.5, 2.5 * s), true)
		var flag = PackedVector2Array([top, top + Vector2(h * 0.9, h * 0.32), top + Vector2(0, h * 0.64)])
		draw_polyline(PackedVector2Array([flag[0], flag[1], flag[2], flag[0]]), Color(Look.N950, 0.9 * a), maxf(3.0, 4 * s), true)
		draw_colored_polygon(flag, Color(t.color.lightened(0.15), a))

## Local stories: a pin on the province, with the story's title beside it.
func _pins(s: float) -> void:
	_pin_rects.clear()
	var per = {}
	var f = Look.font("body_bold")
	var fs = int(maxf(11, 24 * s))
	var halo = Color(Look.N950, 0.85)
	for p in pins:
		var spot = null   # where the pin goes: the province's label, or the region's (under its name)
		var key: String = String(p.get("district", ""))
		if key != "":
			for x in districts:
				if x.id == key: spot = Vector2(x.label[0], x.label[1] - 30)
		else:
			key = String(p.get("region", ""))
			for a in areas:
				if a.kind == "region" and a.id == key: spot = Vector2(a.label[0], a.label[1] + 40)
		if spot == null: continue
		var n: int = int(per.get(key, 0))
		per[key] = n + 1
		var c = to_screen(spot) + Vector2(0, n * fs * 1.6)
		var r = maxf(6.0, 12 * s)
		var on: bool = hover == p.id
		draw_circle(c, r + 3, Color(Look.N950, 0.7))
		draw_circle(c, r, Look.LAMP if not on else Color.WHITE)
		_text(c + Vector2(0, r * 0.45), "!", Look.font("display_bold"), int(r * 1.4), Look.N950)
		var t: String = p.title
		var tw = f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_text(c + Vector2(r + 6, fs * 0.36), t, f, fs, Look.TXT if not on else Look.LAMP, halo, HORIZONTAL_ALIGNMENT_LEFT)
		_pin_rects[p.id] = Rect2(c - Vector2(r, r), Vector2(r * 2 + 6 + tw, r * 2))

## Each district's number of seats, small, on its quietest spot.
func _seat_badges(s: float) -> void:
	var f = Look.font("display_bold")
	var fs = int(maxf(10, 26 * s))
	for d in districts:
		var p = to_screen(Vector2(d.label[0], d.label[1] + 40))
		var r = fs * 0.75
		draw_circle(p, r, Color(Look.N950, 0.8))
		draw_arc(p, r, 0, TAU, 24, Color(Look.TXT, 0.5), 1.0, true)
		_text(p + Vector2(0, fs * 0.36), str(d.seats), f, fs, Look.TXT)

func _plate(a: Dictionary, s: float) -> void:
	var c = to_screen(Vector2(a.label[0], a.label[1]))
	var p = to_screen(Vector2(a.label[0] + 200, a.label[1] + 95))
	var text: String = " ".join(a.name).to_upper()
	var fs = int(maxf(17, 44 * s))
	var font = Look.spaced("display", int(fs * 0.16))
	var tw = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var rect = Rect2(p - Vector2(tw / 2 + 24, fs * 1.05), Vector2(tw + 48, fs * 2.0))
	var hot_now: bool = hot.get(a.id, false)
	draw_line(c, rect.position + Vector2(0, rect.size.y / 2), Look.N500, maxf(1.0, 2 * s), true)
	draw_circle(c, maxf(2.5, 6 * s), Look.DIM)
	var bg = Look.mix(Look.N700, Look.RED, 0.4) if hot_now else (Look.N600 if hover == a.id else Look.N700)
	draw_rect(rect, bg)
	draw_rect(rect, Look.LAMP if hover == a.id else Look.N500, false, 1.0)
	draw_string(font, Vector2(rect.position.x + 24, rect.position.y + rect.size.y * 0.5 + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Look.TXT)
	_plates[a.id] = rect

func _tooltip() -> void:
	var lines: Array = tip_provider.call(hover, hover_kind)
	if lines.is_empty(): return
	var title_font = Look.font("display_bold")
	var body = Look.font("body")
	# long lines wrap at 300 pixels
	var wrapped = [lines[0]]
	for i in range(1, lines.size()):
		var cur = ""
		for word in String(lines[i]).split(" ", false):
			var t = word if cur == "" else cur + " " + word
			if cur != "" and body.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x > 300:
				wrapped.append(cur); cur = word
			else: cur = t
		wrapped.append(cur)
	lines = wrapped
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
	draw_rect(Rect2(rect.position + Vector2(0, 6), rect.size).grow(4), Color(0, 0, 0, 0.35))
	draw_rect(rect, Look.N700)
	draw_rect(rect, Look.N500, false, 1.0)
	draw_rect(Rect2(rect.position, Vector2(3, rect.size.y)), Look.LAMP)
	draw_string(title_font, rect.position + Vector2(12, 24), lines[0], HORIZONTAL_ALIGNMENT_LEFT, w, 16, Look.TXT)
	for i in range(1, lines.size()):
		draw_string(body, rect.position + Vector2(12, 26 + 19 * i), lines[i], HORIZONTAL_ALIGNMENT_LEFT, w, 13, Look.DIM)
