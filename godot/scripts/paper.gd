## paper.gd — a sheet of paper that zooms up over headquarters: events as a
## newspaper front page, choices as index cards, sound bites as typed slips,
## results as the evening news, the budget as a ledger.
class_name Paper
extends Control

signal closed
signal put_down

var _dim: ColorRect
var _scroll: ScrollContainer
var _paper: PanelContainer
var v: VBoxContainer          # the sheet's content; add to it freely
var _down_btn: Button = null  # "Put it down"; survives clear() so every step of a decision has it

func _init(width := 820, can_put_down := false) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim = ColorRect.new()
	_dim.color = Color(0.03, 0.02, 0.01, 0.84)
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
	var sb = Look.box(Look.PAPER, 0, Color.TRANSPARENT, 0, 26, 0)
	sb.content_margin_left = 34; sb.content_margin_right = 34; sb.content_margin_top = 30; sb.content_margin_bottom = 28
	_paper.add_theme_stylebox_override("panel", sb)
	_paper.custom_minimum_size.x = width
	hb.add_child(_paper)
	v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	_paper.add_child(v)
	if can_put_down:
		var b = Button.new()
		# a real button: it says what it does and looks pressable
		b.text = "PIN IT TO THE BOARD · LOOK AROUND FIRST"
		b.icon = Look.icon("pin")
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 16)
		b.add_theme_constant_override("h_separation", 8)
		b.add_theme_font_override("font", Look.spaced("display", 1))
		b.add_theme_font_size_override("font_size", Look.fs(13))
		b.add_theme_color_override("font_color", Look.INK)
		b.add_theme_color_override("font_hover_color", Look.HEAD)
		b.add_theme_color_override("font_pressed_color", Look.HEAD)
		b.add_theme_color_override("icon_normal_color", Look.RED)
		b.add_theme_color_override("icon_hover_color", Look.HEAD)
		b.add_theme_stylebox_override("normal", Look.box(Color("efe3c6"), 3, Look.INK, 1, 0, 8))
		b.add_theme_stylebox_override("hover", Look.box(Look.RED, 3, Look.RED, 1, 0, 8))
		b.add_theme_stylebox_override("pressed", Look.box(Look.OXBLOOD, 3, Look.OXBLOOD, 1, 0, 8))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.tooltip_text = "The decision waits on the board. Check the map and the files, then pick it up again (or press Open decision, top right)."
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(func(): put_down.emit(); close())
		b.size_flags_horizontal = Control.SIZE_SHRINK_END
		v.add_child(b)
		_down_btn = b

func _ready() -> void:
	_paper.resized.connect(func(): _paper.pivot_offset = Vector2(_paper.size.x / 2, 120))
	_paper.scale = Vector2(0.45, 0.45)
	_paper.rotation_degrees = -6
	modulate.a = 0
	var tw = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	tw.tween_property(_paper, "scale", Vector2.ONE, 0.42)
	tw.tween_property(_paper, "rotation_degrees", 0.0, 0.42)

func _draw() -> void:
	pass

func close() -> void:
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func(): closed.emit(); queue_free())

func clear() -> void:
	for c in v.get_children():
		if c != _down_btn: c.queue_free()

## Once the decision is made (the result is showing) there is nothing left to put down.
func decided() -> void:
	if _down_btn: _down_btn.visible = false

func top() -> void:
	_scroll.scroll_vertical = 0

# ---------- Building blocks ----------
func add(c: Control) -> Control:
	v.add_child(c)
	return c

func rule(thick := 2, col := Look.INK) -> void:
	var r = ColorRect.new()
	r.color = col
	r.custom_minimum_size.y = thick
	add(r)

func kicker(text: String, col := Look.RED) -> void:
	add(Look.caps(text, 12, col, 2))

func heading(text: String, size := 36, font := "news_bold") -> void:
	add(Look.label(text, font, size, Look.INK, true))

func text(t: String, size := 17, font := "news", col := Look.INK) -> Label:
	return add(Look.label(t, font, size, col, true))

func small(t: String, col := Look.MUTED) -> Label:
	return add(Look.label(t, "body", 13, col, true))

func masthead(left: String, name: String, right: String) -> void:
	var h = HBoxContainer.new()
	var l = Look.caps(left, 11, Look.INK, 2)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_END
	h.add_child(l)
	h.add_child(Look.label(name, "news_bold", 38, Look.INK))
	var r = Look.caps(right, 11, Look.RED, 2)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.size_flags_vertical = Control.SIZE_SHRINK_END
	h.add_child(r)
	add(h)
	rule(2)
	var gap = Control.new(); gap.custom_minimum_size.y = 1
	add(gap)
	rule(1)

func boxed(title: String, body: String, col := Look.INK) -> void:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", Look.box(Color(1, 1, 1, 0.35), 0, col, 2, 0, 12))
	var b = VBoxContainer.new()
	b.add_child(Look.caps(title, 11, col, 2))
	b.add_child(Look.label(body, "body", 14, Look.INK, true))
	p.add_child(b)
	add(p)

func callout(t: String, col := Look.RED) -> void:
	var p = PanelContainer.new()
	var sb = Look.box(Color(col.r, col.g, col.b, 0.08), 0, col, 0, 0, 10)
	sb.border_width_left = 5
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(Look.label(t, "body_bold", 14, Look.INK, true))
	add(p)

func quote(t: String, cite: String) -> void:
	var p = PanelContainer.new()
	var sb = Look.box(Color(0.7, 0.15, 0.12, 0.06), 0, Look.RED, 0, 0, 12)
	sb.border_width_left = 4
	p.add_theme_stylebox_override("panel", sb)
	var b = VBoxContainer.new()
	b.add_child(Look.label("“%s”" % t, "news_italic", 19, Look.INK, true))
	b.add_child(Look.label(cite, "body", 12, Look.MUTED, true))
	p.add_child(b)
	add(p)

func step(n: String, title: String) -> void:
	rule(2)
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var s = Look.caps(n, 12, Look.RED, 2)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(s)
	h.add_child(Look.label(title, "display", 26, Look.INK))
	add(h)

## A clickable piece of paper. kind: "index" (lined card), "slip" (typed sound bite), "plain".
func card(kind: String, build: Callable, cb: Callable, disabled := false) -> PanelContainer:
	var p = PanelContainer.new()
	var sb: StyleBoxFlat
	match kind:
		"index":
			sb = Look.box(Color("fdfaf2"), 0, Color.TRANSPARENT, 0, 3, 14)
			sb.border_width_top = 3; sb.border_color = Color("d9534f")
		"slip":
			sb = Look.box(Color("efe3c6"), 0, Color.TRANSPARENT, 0, 3, 16)
			sb.border_width_left = 6; sb.border_color = Look.INK
		_:
			sb = Look.box(Color(1, 1, 1, 0.4), 0, Look.LINE, 1, 0, 12)
	p.add_theme_stylebox_override("panel", sb)
	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(inner)
	build.call(inner)
	for c in inner.get_children(): c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if disabled:
		p.modulate.a = 0.5
	else:
		var hv = sb.duplicate()
		hv.shadow_size = 10
		if kind == "slip": hv.border_color = Look.RED
		if kind == "index": hv.bg_color = Color("fffdf6")
		p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		p.mouse_entered.connect(func():
			p.add_theme_stylebox_override("panel", hv)
			if p.get_parent() == v: p.create_tween().tween_property(p, "position:x", 6.0, 0.12))   # only slide in a plain column; in a grid it would jump
		p.mouse_exited.connect(func():
			p.add_theme_stylebox_override("panel", sb)
			if p.get_parent() == v: p.create_tween().tween_property(p, "position:x", 0.0, 0.12))
		p.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				cb.call())
	add(p)
	return p

func tv_strap(left: String, right: String) -> void:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	for part in [[left, Look.RED], [right, Look.INK]]:
		var p = PanelContainer.new()
		p.add_theme_stylebox_override("panel", Look.box(part[1], 0, Color.TRANSPARENT, 0, 0, 6))
		p.add_child(Look.caps(part[0], 12, Look.HEAD, 2))
		h.add_child(p)
	add(h)

func stamp(t: String, col: Color) -> void:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", Look.box(Color(0, 0, 0, 0), 0, col, 3, 0, 6))
	p.add_child(Look.caps(t, 16, col, 3, "display_bold"))
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.rotation_degrees = -4
	add(p)
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
		p.add_theme_stylebox_override("panel", Look.box(Color(1, 1, 1, 0.45), 0, Look.LINE, 1, 0, 6))
		p.add_child(Look.label(it[0], "body_bold", 13, it[1]))
		f.add_child(p)
	add(f)

func button(t: String, cb: Callable, primary := true, disabled := false) -> Button:
	var b = Button.new()
	b.text = t.to_upper()
	b.disabled = disabled
	b.add_theme_font_override("font", Look.spaced("display", 2))
	b.add_theme_font_size_override("font_size", Look.fs(15))
	var bg = Look.OXBLOOD if primary else Color(1, 1, 1, 0.3)
	var fg = Look.HEAD if primary else Look.INK
	b.add_theme_stylebox_override("normal", Look.box(bg, 2, Look.OXBLOOD if primary else Look.INK, 1, 0, 10))
	b.add_theme_stylebox_override("hover", Look.box(Look.RED if primary else Color("fff8e8"), 2, Look.INK, 1, 0, 10))
	b.add_theme_stylebox_override("pressed", Look.box(bg.darkened(0.15), 2, Look.INK, 1, 0, 10))
	b.add_theme_stylebox_override("disabled", Look.box(Color(0, 0, 0, 0.05), 2, Look.LINE, 1, 0, 10))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", Look.HEAD if primary else Look.INK)
	b.add_theme_color_override("font_disabled_color", Color(0, 0, 0, 0.3))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(cb)
	if t.length() <= 2: b.custom_minimum_size = Vector2(38, 36)
	return b

func actions(buttons: Array) -> void:
	var h = HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_END
	h.add_theme_constant_override("separation", 10)
	for b in buttons: h.add_child(b)
	add(h)
