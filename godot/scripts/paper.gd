## paper.gd — the thing in your hands, lifted over headquarters.
## Most of the time it is a sheet of paper under the desk lamp: events as the morning
## paper, choices as cards, the exact words as drafts, the budget as a ledger.
## Anything the country watches is a television instead (screen()): the evening news,
## the interview, the debate, election night. Paper is warm and light; the screen is
## cold and dark.
class_name Paper
extends Control

signal closed
signal put_down

var _dim: ColorRect
var _scroll: ScrollContainer
var _paper: PanelContainer
var v: VBoxContainer          # the sheet's content; add to it freely
var _down_btn: Button = null  # "Set it aside"; survives clear() so every step of a decision has it
var on_air := false           # true once screen() has turned the sheet into a television
var _sheet_mat: ShaderMaterial

# the colours of whatever is being read: ink on paper, or light on the screen
var style := ""               # the newspaper being read ("tabloid", "broadsheet", "local"), or "" for any other sheet
var _root: VBoxContainer      # the sheet's content
var _print: Control = null    # the newsprint texture laid over a newspaper (see front_page)
var ink := Look.INK
var muted := Look.MUTED
var line := Look.LINE
var red := Look.RED
var good := Look.GOOD

func _init(width := 820, can_put_down := false) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim = ColorRect.new()
	_dim.color = Color(Look.N950, 0.8)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var center = MarginContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("margin_top", 34)
	center.add_theme_constant_override("margin_bottom", 34)
	_scroll.add_child(center)
	var hb = HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(hb)
	_paper = PanelContainer.new()
	_paper.custom_minimum_size.x = width
	_sheet_mat = Look.material("paper")
	_paper.material = _sheet_mat
	_paper.add_theme_stylebox_override("panel", _sheet_box(false))
	_paper.draw.connect(_draw_newsprint)
	hb.add_child(_paper)
	v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	_paper.add_child(v)
	_root = v
	if can_put_down:
		var b = Button.new()
		# a real button: it says what it does and looks pressable
		b.text = "SET IT ASIDE · LOOK AROUND FIRST"
		b.icon = Look.icon("pin")
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 16)
		b.add_theme_constant_override("h_separation", 8)
		b.add_theme_font_override("font", Look.spaced("display", 1))
		b.add_theme_font_size_override("font_size", Look.fs(13))
		b.add_theme_color_override("font_color", Look.INK)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		b.add_theme_color_override("icon_normal_color", Look.RED)
		b.add_theme_color_override("icon_hover_color", Color.WHITE)
		b.add_theme_stylebox_override("normal", Look.box(Color(1, 1, 1, 0.35), 2, Look.INK, 1, 0, 8))
		b.add_theme_stylebox_override("hover", Look.box(Look.INK, 2, Look.INK, 1, 0, 8))
		b.add_theme_stylebox_override("pressed", Look.box(Look.INK, 2, Look.INK, 1, 0, 8))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.tooltip_text = "The decision waits on your desk. Check the map and the files, then pick it up again (or press Open decision, top right)."
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(func(): put_down.emit(); close())
		b.size_flags_horizontal = Control.SIZE_SHRINK_END
		v.add_child(b)
		_down_btn = b

func _sheet_box(screen_on: bool) -> StyleBoxFlat:
	var sb: StyleBoxFlat
	if screen_on:
		sb = Look.box(Look.N850, 4, Look.N600, 1, 0, 0)
		sb.shadow_color = Color(0.35, 0.55, 1.0, 0.1)    # the glow of the set in a dark room
		sb.shadow_size = 60
	elif style != "":
		sb = Look.box(Color(0, 0, 0, 0))   # a newspaper draws its own, curled sheet (_draw_newsprint)
	else:
		sb = Look.box(Look.PAPER, 1, Color.TRANSPARENT, 0, 0, 0)
		sb.shadow_color = Color(0, 0, 0, 0.6)
		sb.shadow_size = 30
		sb.shadow_offset = Vector2(0, 14)
	sb.content_margin_left = 38; sb.content_margin_right = 38; sb.content_margin_top = 30; sb.content_margin_bottom = 30
	return sb

func _ready() -> void:
	_paper.resized.connect(func():
		_paper.pivot_offset = Vector2(_paper.size.x / 2, 200)
		_sheet_mat.set_shader_parameter("sheet", _paper.size))
	# dropped on the desk in front of you: it lands a little crooked and settles
	_paper.scale = Vector2(0.94, 0.94)
	_paper.rotation_degrees = -2.2
	modulate.a = 0
	var tw = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.22)
	tw.tween_property(_paper, "scale", Vector2.ONE, 0.42)
	tw.tween_property(_paper, "rotation_degrees", 0.0, 0.5)

## Turn the sheet into a television: for what the country sees rather than what you read.
func screen() -> void:
	if on_air: return
	on_air = true
	style = ""
	_set_newsprint(false)
	ink = Look.TXT; muted = Look.DIM; line = Look.N600; red = Look.RED_HI; good = Look.GOOD_HI
	_sheet_mat = Look.material("screen", {"sheet": _paper.size})
	_paper.material = _sheet_mat
	_paper.add_theme_stylebox_override("panel", _sheet_box(true))
	_dim.color = Color(Look.N950, 0.9)

## And back to paper (the piece the paper runs the morning after the broadcast).
func paper() -> void:
	if not on_air: return
	on_air = false
	ink = Look.INK; muted = Look.MUTED; line = Look.LINE; red = Look.RED; good = Look.GOOD
	_sheet_mat = Look.material("paper", {"sheet": _paper.size})
	_paper.material = _sheet_mat
	_paper.add_theme_stylebox_override("panel", _sheet_box(false))
	_dim.color = Color(Look.N950, 0.8)

func close() -> void:
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func(): closed.emit(); queue_free())

func clear() -> void:
	v = _root
	if style != "":
		style = ""
		_set_newsprint(false)
		if not on_air: _paper.add_theme_stylebox_override("panel", _sheet_box(false))
	for c in v.get_children():
		if c != _down_btn: c.queue_free()

## Once the decision is made (the result is showing) there is nothing left to put down.
func decided() -> void:
	if _down_btn: _down_btn.visible = false

func top() -> void:
	_scroll.scroll_vertical = 0

## On the screen, ink turns to light: text built for paper is recoloured as it is added.
func _c(col: Color) -> Color:
	if not on_air: return col
	if col.is_equal_approx(Look.INK): return Look.TXT
	if col.is_equal_approx(Look.MUTED): return Look.DIM
	if col.is_equal_approx(Look.RED): return Look.RED_HI
	if col.is_equal_approx(Look.GOOD): return Look.GOOD_HI
	if col.is_equal_approx(Look.LINE): return Look.N600
	return col

func _recolour(c: Node) -> void:
	if c is Label and c.has_theme_color_override("font_color"):
		c.add_theme_color_override("font_color", _c(c.get_theme_color("font_color")))
	for k in c.get_children(): _recolour(k)

# ---------- Building blocks ----------
func add(c: Control) -> Control:
	if on_air: _recolour(c)
	v.add_child(c)
	return c

func rule(thick := 2, col := Look.INK) -> void:
	var r = ColorRect.new()
	r.color = _c(col) if thick < 2 or not on_air else Look.N500
	r.custom_minimum_size.y = thick
	v.add_child(r)

func kicker(text: String, col := Look.RED) -> void:
	add(Look.caps(text, 13, col, 2))

func heading(text: String, size := 36, font := "news_bold") -> void:
	var l: Label
	if style == "tabloid" and not on_air:
		# a tabloid shouts: heavy capitals, as big as will fit
		l = Look.label(text.to_upper(), "display_bold", int(size * 1.45), Look.INK, true)
		l.add_theme_constant_override("line_spacing", -12)
	else:
		l = Look.label(text, font, size, Look.INK, true)
		l.add_theme_constant_override("line_spacing", -4)
	add(l)

# ---------- A newspaper's front page ----------
## The paper's look, from papers.json, by the name the game uses for it.
static func paper_info(name: String, region := "") -> Dictionary:
	var data: Dictionary = Mods.data("papers")
	var out: Dictionary = data.DEFAULT.duplicate()
	for pp in data.PAPERS:
		if String(pp.name).replace("{region}", region) == name:
			out = pp.duplicate()
	out.name = name
	out.motto = String(out.get("motto", "")).replace("{region}", region)
	return out

## The top of a front page: the nameplate in the paper's own style, then the line with
## the date, the issue number and the price. Everything after it on the sheet is set as
## that newspaper would set it (see heading() and story()).
func front_page(name: String, date: String, section: String, week := 0, region := "") -> void:
	var info: Dictionary = paper_info(name, region)
	style = info.style
	_paper.add_theme_stylebox_override("panel", _sheet_box(false))
	_set_newsprint(true)
	var year = int(date.right(4)) if date.right(4).is_valid_int() else 2027
	var issue = "No. %d" % (int(info.get("founded", 1990)) % 97 * 113 + week * 6 + 1)
	var vol = "Vol. %d" % maxi(1, year - int(info.get("founded", 1990)))
	match style:
		"tabloid":
			var h = HBoxContainer.new()
			h.add_theme_constant_override("separation", 16)
			var block = PanelContainer.new()
			var bsb = Look.box(Look.RED, 0, Color.TRANSPARENT, 0, 0, 0)
			bsb.content_margin_left = 18; bsb.content_margin_right = 22; bsb.content_margin_top = 0; bsb.content_margin_bottom = 2
			block.add_theme_stylebox_override("panel", bsb)
			block.add_child(Look.label(name.to_upper(), "redtop", 46, Color.WHITE))
			h.add_child(block)
			var side = VBoxContainer.new()
			side.alignment = BoxContainer.ALIGNMENT_CENTER
			side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			side.add_theme_constant_override("separation", 0)
			var mt = Look.label(info.motto, "body_italic", 13, Look.INK, true)
			mt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			side.add_child(mt)
			var pr = Look.caps("%s · %s" % [date, info.price], 12, Look.MUTED, 1)
			pr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			side.add_child(pr)
			h.add_child(side)
			add(h)
			var strip = PanelContainer.new()
			var ssb = Look.box(Look.INK, 0, Color.TRANSPARENT, 0, 0, 4)
			ssb.content_margin_left = 10
			strip.add_theme_stylebox_override("panel", ssb)
			strip.add_child(Look.caps(section, 14, Color.WHITE, 3, "display_bold"))
			v.add_child(strip)
		"local":
			rule(3)
			var nm = Look.caps(name, 34, Look.INK, 5, "news_bold")
			nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			add(nm)
			if info.motto != "":
				var mo = Look.label(info.motto, "news_italic", 14, Look.MUTED)
				mo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				add(mo)
			_dateline(vol + " · " + issue, date, section + " · " + info.price)
		_:
			# a broadsheet: a blackletter nameplate
			var mid = VBoxContainer.new()
			mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			mid.add_theme_constant_override("separation", -4)
			var nm = Look.label(name, "blackletter", 54, Look.INK)
			nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mid.add_child(nm)
			if info.motto != "":
				var mo = Look.label(info.motto, "news_italic", 13, Look.MUTED)
				mo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				mid.add_child(mo)
			add(mid)
			_dateline(vol + " · " + issue, date, section + " · " + info.price)

## A newspaper is cheap paper that has been rolled up and folded: the sheet is drawn with
## wavy edges and lifted ends, and a texture (shaders/newsprint.gdshader) is multiplied
## over everything printed on it.
func _set_newsprint(on: bool) -> void:
	if on and _print == null:
		# the sheet lays its content out inside its margins; this holder sits there too,
		# and the texture inside it reaches back out to the sheet's edges
		_print = Control.new()
		_print.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb: StyleBox = _paper.get_theme_stylebox("panel")
		var tex = ColorRect.new()
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.offset_left = -sb.content_margin_left; tex.offset_top = -sb.content_margin_top
		tex.offset_right = sb.content_margin_right; tex.offset_bottom = sb.content_margin_bottom
		var m = Look.material("newsprint")
		tex.material = m
		tex.resized.connect(func(): m.set_shader_parameter("sheet", tex.size))
		_print.add_child(tex)
		_paper.add_child(_print)
	elif not on and _print != null:
		_print.queue_free()
		_print = null
	_paper.queue_redraw()

func _draw_newsprint() -> void:
	if _print == null: return
	var s: Vector2 = _paper.size
	var pts = PackedVector2Array()
	# the sides remember the roll: a slow wave; the ends lift, pulling the corners in a little
	var n = 160
	for i in n + 1:
		var t = float(i) / n
		pts.append(Vector2(1.6 * sin(t * s.y / 260.0) + 3.0 * pow(abs(t * 2 - 1), 4), t * s.y))
	for i in range(n, -1, -1):
		var t = float(i) / n
		pts.append(Vector2(s.x - 1.6 * sin(t * s.y / 260.0 + 1.3) - 3.0 * pow(abs(t * 2 - 1), 4), t * s.y))
	# the ends bow: the middle of the top and bottom edge sits a few pixels in from the corners
	for i in pts.size():
		var t = clampf(pts[i].x / s.x, 0, 1)
		var bow = 4.0 * (1.0 - pow(t * 2 - 1, 2))
		if pts[i].y <= 0.5: pts[i].y = bow
		elif pts[i].y >= s.y - 0.5: pts[i].y = s.y - bow
	# its shadow on the desk: soft, and further out where the ends lift
	for k in 6:
		var grow = 4.0 + k * 6.0
		var sh = PackedVector2Array()
		for q in pts: sh.append((q - s / 2) * Vector2(1 + grow / s.x, 1 + grow * 1.6 / s.y) + s / 2 + Vector2(0, 10 + k * 2))
		_paper.draw_colored_polygon(sh, Color(0, 0, 0, 0.1))
	_paper.draw_colored_polygon(pts, Look.NEWSPRINT)

## Between two rules: volume and number, the date, the section.
func _dateline(left: String, mid: String, right: String) -> void:
	rule(3)
	var h = HBoxContainer.new()
	var parts = [[left, HORIZONTAL_ALIGNMENT_LEFT], [mid, HORIZONTAL_ALIGNMENT_CENTER], [right, HORIZONTAL_ALIGNMENT_RIGHT]]
	for part in parts:
		var l = Look.caps(part[0], 11, Look.INK, 2)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = part[1]
		h.add_child(l)
	v.add_child(h)
	rule(1)

## The story under a headline, as a newspaper sets it: a place and a dash, then
## justified text.
func story(t: String, place := "", size := 17) -> Label:
	var l = Look.label((place.to_upper() + " — " if place != "" else "") + t, "news", size, Look.INK, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_FILL
	l.justification_flags = TextServer.JUSTIFICATION_WORD_BOUND | TextServer.JUSTIFICATION_KASHIDA | TextServer.JUSTIFICATION_SKIP_LAST_LINE
	return add(l)

func text(t: String, size := 17, font := "news", col := Look.INK) -> Label:
	return add(Look.label(t, font, size, col, true))

func small(t: String, col := Look.MUTED) -> Label:
	return add(Look.label(t, "body", 13, col, true))

## A note in the margin, in somebody's handwriting.
func scribble(t: String, col := Look.OXBLOOD) -> Label:
	var l = Look.label(t, "hand", 23, col, true)
	l.add_theme_constant_override("line_spacing", -3)
	return add(l)

## A photograph across the sheet (nothing at all if there is no picture). On paper it is
## printed in the paper's two inks; on the screen it is the broadcast.
func photo(tex: Texture2D, height := 280, caption := "") -> void:
	if tex == null: return
	var ph = Photo.new(tex, on_air)
	ph.custom_minimum_size.y = height
	v.add_child(ph)
	if caption != "": small(caption)

func masthead(left: String, name: String, right: String) -> void:
	var h = HBoxContainer.new()
	var l = Look.caps(left, 12, Look.MUTED, 2)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_END
	h.add_child(l)
	h.add_child(Look.label(name, "news_bold", 40, Look.INK))
	var r = Look.caps(right, 12, Look.RED, 2)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.size_flags_vertical = Control.SIZE_SHRINK_END
	h.add_child(r)
	add(h)
	rule(3)
	var gap = Control.new(); gap.custom_minimum_size.y = 1
	add(gap)
	rule(1)

func boxed(title: String, body: String, col := Look.INK) -> void:
	var p = PanelContainer.new()
	var sb = Look.box(Color(1, 1, 1, 0.04) if on_air else Color(1, 1, 1, 0.4), 0, _c(col), 0, 0, 12)
	sb.border_width_left = 3
	p.add_theme_stylebox_override("panel", sb)
	var b = VBoxContainer.new()
	b.add_child(Look.caps(title, 11, col, 2))
	b.add_child(Look.label(body, "body", 14, Look.INK, true))
	p.add_child(b)
	add(p)

func callout(t: String, col := Look.RED) -> void:
	var p = PanelContainer.new()
	var cc = _c(col)
	var sb = Look.box(Color(cc.r, cc.g, cc.b, 0.1), 0, cc, 0, 0, 10)
	sb.border_width_left = 4
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(Look.label(t, "body_bold", 14, Look.INK, true))
	add(p)

func quote(t: String, cite: String) -> void:
	var p = PanelContainer.new()
	var sb = Look.box(Color(red.r, red.g, red.b, 0.07), 0, red, 0, 0, 14)
	sb.border_width_left = 4
	p.add_theme_stylebox_override("panel", sb)
	var b = VBoxContainer.new()
	b.add_child(Look.label("“%s”" % t, "news_italic", 20, Look.INK, true))
	b.add_child(Look.label(cite, "body", 12, Look.MUTED, true))
	p.add_child(b)
	add(p)

func step(n: String, title: String) -> void:
	rule(2)
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var s = Look.caps(n, 13, Look.RED, 2)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(s)
	h.add_child(Look.label(title, "news_bold", 26, Look.INK))
	add(h)

## A clickable piece of paper. kind: "index" (a choice), "slip" (a draft of the exact words), "plain".
func card(kind: String, build: Callable, cb: Callable, disabled := false) -> PanelContainer:
	var p = PanelContainer.new()
	var sb: StyleBoxFlat
	if on_air:
		sb = Look.box(Look.N800, 2, Look.N600, 1, 0, 16)
		sb.border_width_left = 3
	else:
		match kind:
			"index":
				sb = Look.box(Look.CARD, 2, Look.LINE, 1, 4, 16)
				sb.shadow_color = Color(0, 0, 0, 0.12)
			"slip":
				sb = Look.box(Look.CARD, 0, Look.INK, 0, 4, 18)
				sb.shadow_color = Color(0, 0, 0, 0.12)
				sb.border_width_left = 3
			_:
				sb = Look.box(Color(1, 1, 1, 0.4), 0, Look.LINE, 1, 0, 12)
	p.add_theme_stylebox_override("panel", sb)
	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 5)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(inner)
	build.call(inner)
	for c in inner.get_children(): c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if disabled:
		p.modulate.a = 0.5
	else:
		var hv = sb.duplicate()
		if on_air:
			hv.bg_color = Look.N700
			hv.border_color = Look.RED_HI
		else:
			hv.bg_color = Color.WHITE
			hv.shadow_size = 12
			hv.shadow_color = Color(0, 0, 0, 0.22)
			hv.border_color = Look.RED if kind == "slip" else Look.INK
		p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		p.mouse_entered.connect(func():
			p.add_theme_stylebox_override("panel", hv)
			if p.get_parent() == v: p.create_tween().tween_property(p, "position:x", 5.0, 0.12))   # only slide in a plain column; in a grid it would jump
		p.mouse_exited.connect(func():
			p.add_theme_stylebox_override("panel", sb)
			if p.get_parent() == v: p.create_tween().tween_property(p, "position:x", 0.0, 0.12))
		p.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				cb.call())
	add(p)
	return p

## The strap along the bottom of a news broadcast: the channel in red, the story beside it.
func tv_strap(left: String, right: String) -> void:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	for part in [[left, Look.RED], [right, Look.N600 if on_air else Look.INK]]:
		var p = PanelContainer.new()
		var sb = Look.box(part[1], 0, Color.TRANSPARENT, 0, 0, 7)
		sb.content_margin_left = 12; sb.content_margin_right = 12
		p.add_theme_stylebox_override("panel", sb)
		p.add_child(Look.caps(part[0], 13, Color.WHITE, 2, "display_bold" if part[1] == Look.RED else "display"))
		h.add_child(p)
	v.add_child(h)

func stamp(t: String, col: Color) -> void:
	var p = PanelContainer.new()
	var cc = _c(col)
	p.add_theme_stylebox_override("panel", Look.box(Color(0, 0, 0, 0), 2, cc, 3, 0, 6))
	p.add_child(Look.caps(t, 17, cc, 3, "display_bold"))
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.rotation_degrees = -4
	v.add_child(p)
	p.scale = Vector2(2.2, 2.2)
	p.modulate.a = 0
	p.resized.connect(func(): p.pivot_offset = p.size / 2)
	var tw = p.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.25)
	tw.chain().tween_property(p, "scale", Vector2.ONE, 0.3)
	tw.parallel().tween_property(p, "modulate:a", 1.0, 0.15)

func chips(items: Array) -> void:
	# items: [[text, Color], ...]
	var f = HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 6)
	f.add_theme_constant_override("v_separation", 6)
	for it in items:
		var p = PanelContainer.new()
		var sb = Look.box(Color(1, 1, 1, 0.05) if on_air else Color(1, 1, 1, 0.5), 2, line, 1, 0, 6)
		sb.content_margin_left = 10; sb.content_margin_right = 10
		p.add_theme_stylebox_override("panel", sb)
		p.add_child(Look.label(it[0], "body_bold", 13, it[1]))
		f.add_child(p)
	add(f)

func button(t: String, cb: Callable, primary := true, disabled := false) -> Button:
	var b = Button.new()
	b.text = t.to_upper()
	b.disabled = disabled
	b.add_theme_font_override("font", Look.spaced("display_bold" if primary else "display", 2))
	b.add_theme_font_size_override("font_size", Look.fs(15))
	if on_air:
		Look.dark_button(b, primary, false, 10)
	else:
		var bg = Look.RED if primary else Color(1, 1, 1, 0.3)
		b.add_theme_stylebox_override("normal", Look.box(bg, 2, Look.RED if primary else Look.INK, 1, 0, 10))
		b.add_theme_stylebox_override("hover", Look.box(Look.OXBLOOD if primary else Look.INK, 2, Look.OXBLOOD if primary else Look.INK, 1, 0, 10))
		b.add_theme_stylebox_override("pressed", Look.box(Look.OXBLOOD if primary else Look.INK, 2, Look.INK, 1, 0, 10))
		b.add_theme_stylebox_override("disabled", Look.box(Color(0, 0, 0, 0.05), 2, Look.LINE, 1, 0, 10))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_color_override("font_color", Color.WHITE if primary else Look.INK)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		b.add_theme_color_override("font_focus_color", Color.WHITE if primary else Look.INK)
		b.add_theme_color_override("font_disabled_color", Color(0, 0, 0, 0.3))
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(cb)
	if t.length() <= 2:
		b.custom_minimum_size = Vector2(38, 36)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b

func actions(buttons: Array) -> void:
	var h = HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_END
	h.add_theme_constant_override("separation", 10)
	for b in buttons: h.add_child(b)
	v.add_child(h)
