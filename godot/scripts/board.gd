## board.gd — the evidence board: only what is current or urgent.
## The decision waiting for you (red pin), the latest poll, staff notes,
## this week's headlines, trouble to watch and what comes next.
class_name Board
extends Control

signal open_decision
signal open_file(tab: String)

var game
var _flow: HFlowContainer
var _scroll: ScrollContainer
var _strings: Control
var _cards: Array = []
var _key = ""
var _last_front = ""
var _poll_fracs = {}   # party id -> bar length last shown
var _poll_seen = -1    # how many polls the board has already shown

class Card extends PanelContainer:
	signal pressed
	var pin = "red"
	var pulse = false
	var tilt = 0.0
	var clickable = true
	var string_to = false
	var _t = 0.0
	func _init(bg: Color, p := "red", t := 0.0) -> void:
		pin = p; tilt = t
		var sb = Look.box(bg, 1, Color.TRANSPARENT, 0, 9)
		sb.content_margin_left = 16; sb.content_margin_right = 16
		sb.content_margin_top = 22; sb.content_margin_bottom = 14
		add_theme_stylebox_override("panel", sb)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(_hover.bind(true))
		mouse_exited.connect(_hover.bind(false))
	func _ready() -> void:
		rotation_degrees = tilt
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if clickable else Control.CURSOR_ARROW
		set_process(pulse)
	func _hover(on: bool) -> void:
		if not clickable: return
		var tw = create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "rotation_degrees", 0.0 if on else tilt, 0.18)
		tw.tween_property(self, "scale", Vector2(1.03, 1.03) if on else Vector2.ONE, 0.18)
		z_index = 2 if on else 0
	func _gui_input(e: InputEvent) -> void:
		if clickable and e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			pressed.emit(); accept_event()
	func _process(d: float) -> void:
		_t += d; queue_redraw()
	func pin_point() -> Vector2:
		return Vector2(size.x / 2, 1)
	func _draw() -> void:
		var c: Color = Look.PIN_COLORS[pin]
		var p = pin_point()
		if pulse:
			var k = fmod(_t, 1.6) / 1.6
			draw_circle(p, 9 + k * 14, Color(0.75, 0.22, 0.17, 0.55 * (1 - k)))
		draw_circle(p + Vector2(1, 4), 9, Color(0, 0, 0, 0.35))
		draw_circle(p, 9, c.darkened(0.25))
		draw_circle(p - Vector2(1.5, 1.5), 7, c)
		draw_circle(p - Vector2(3, 3), 2.6, c.lightened(0.55))

class Strings extends Control:
	var board
	func _draw() -> void:
		if board == null: return
		var from = null
		for c in board._cards:
			if c.pulse or c.has_meta("decision"): from = c
		if from == null: return
		var a: Vector2 = get_global_transform().affine_inverse() * (from.get_global_transform() * from.pin_point())
		for c in board._cards:
			if not c.string_to: continue
			var b: Vector2 = get_global_transform().affine_inverse() * (c.get_global_transform() * c.pin_point())
			var sag = minf(60.0, a.distance_to(b) * 0.18)
			var mid = (a + b) / 2 + Vector2(0, sag)
			var pts = PackedVector2Array()
			for i in 25:
				var t = i / 24.0
				pts.append(a.lerp(mid, t).lerp(mid.lerp(b, t), t))
			draw_polyline(pts, Color(0, 0, 0, 0.3), 3.0, true)
			draw_polyline(pts, Color("b3261e"), 2.2, true)

func _ready() -> void:
	clip_contents = true
	var cork = TextureRect.new()
	cork.texture = Look.noise_texture(256, 256, Color("7f5630"), Color("b88a55"), 0.09, 7)
	cork.stretch_mode = TextureRect.STRETCH_TILE
	cork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cork)
	var shade = _Vignette.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_strings = Strings.new()
	_strings.board = self
	_strings.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_strings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_strings)
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var m = MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]: m.add_theme_constant_override("margin_" + side, 28)
	m.add_theme_constant_override("margin_top", 34)
	_scroll.add_child(m)
	_flow = HFlowContainer.new()
	_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flow.add_theme_constant_override("h_separation", 24)
	_flow.add_theme_constant_override("v_separation", 30)
	m.add_child(_flow)
	var frame = _Frame.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	resized.connect(_fit)
	_scroll.get_v_scroll_bar().value_changed.connect(func(_v): _strings.queue_redraw())

class _Vignette extends Control:
	func _draw() -> void:
		var r = Rect2(Vector2.ZERO, size)
		for i in 12:
			var k = i / 12.0
			draw_rect(r.grow(-k * 40), Color(0, 0, 0, 0.035), false, 40.0 / 12 + 1)

class _Frame extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("4a2f1a"), false, 12.0)
		draw_rect(Rect2(Vector2(6, 6), size - Vector2(12, 12)), Color(0, 0, 0, 0.35), false, 2.0)

func _fit() -> void:
	var inner = size.x - 56 - 6
	var gap = 24.0
	var cols = maxi(1, int((inner + gap) / (230 + gap)))
	var w = floorf((inner - gap * (cols - 1)) / cols) - 1
	for c in _cards:
		c.custom_minimum_size.x = maxf(200, inner - 8) if c.has_meta("wide") else w
		c.get_parent()._sync()
	_strings.queue_redraw()

func _process(_d: float) -> void:
	_strings.queue_redraw()

# ---------- Building the cards ----------
func render(s: Dictionary) -> void:
	var key = JSON.stringify([s.week, s.queue.size(), s.queue[0] if s.queue.size() else null, s.log.size(), s.polls.size(), s.actionsLeft, s.agenda.done, s.money, s.debates.map(func(d): return [d.id, int(d.heat), int(d.lean)])])
	if key == _key: return
	_key = key
	for c in _cards: c.get_parent().queue_free()
	_cards.clear()
	var G = game
	var front = s.queue[0] if s.queue.size() else null
	var sum = _front_summary(s, front)
	# 1. the decision waiting for you
	if not sum.is_empty():
		var c = _card(Color("efe3c6"), "red", -1.0)
		c.pulse = true
		c.set_meta("decision", true)
		c.set_meta("wide", true)
		var v = _vbox(c)
		v.add_child(Look.caps("%s · %s" % [sum.kicker, G.date_label(s.week, false)], 11, Color("6d5d4a")))
		v.add_child(Look.label(sum.title, "news_bold", 30, Look.INK, true))
		if sum.text != "": v.add_child(_clamp_lines(Look.label(sum.text, "news", 15, Color("3a3128"), true), 3))
		var stamp = Look.caps(sum.stamp, 15, Look.RED, 2, "display_bold")
		var sp = PanelContainer.new()
		sp.add_theme_stylebox_override("panel", Look.box(Color(0.94, 0.89, 0.78, 0.9), 0, Look.RED, 3, 0, 4))
		sp.add_child(stamp)
		sp.size_flags_horizontal = Control.SIZE_SHRINK_END
		sp.rotation_degrees = -8
		v.add_child(sp)
		c.pressed.connect(func(): open_decision.emit())
		if _last_front != sum.title:
			_last_front = sum.title
			c.modulate.a = 0
			c.scale = Vector2(1.15, 1.15)
			var tw = c.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(c, "modulate:a", 1.0, 0.3)
			tw.tween_property(c, "scale", Vector2.ONE, 0.5)
	elif s.result:
		var c = _card(Color("efe3c6"), "red", -1.0)
		c.set_meta("wide", true)
		var v = _vbox(c)
		v.add_child(Look.caps("Election night", 11, Color("6d5d4a")))
		v.add_child(Look.label("The results", "news_bold", 30))
		c.pressed.connect(func(): open_decision.emit())
	else:
		var c = _card(Color("e9dfc8"), "black", -0.6)
		c.clickable = false
		c.set_meta("wide", true)
		var v = _vbox(c)
		v.add_child(Look.caps(G.date_label(s.week), 11, Color("6d5d4a")))
		v.add_child(Look.label("Nothing on fire", "news_bold", 26))
		v.add_child(Look.label("Plan your month in the files above, or move the clock forward.", "news", 15, Color("3a3128"), true))
	# 2. what the country is arguing about
	var tc = _card(Color("f4ecd9"), "blue", 2.0)
	tc.string_to = true
	var tv = _vbox(tc)
	tv.add_child(Look.caps("The national debate", 11, Color("6d5d4a")))
	var list: Array = Game.ssort(s.debates.duplicate(), func(x, y): return y.heat - x.heat).slice(0, 4)
	if list.is_empty(): tv.add_child(Look.label("Nobody is arguing about anything. Start something.", "news", 14, Look.INK, true))
	for d in list:
		var ax = Game.by_id(G.AXES, d.axis)
		var hot: bool = d.heat >= 50
		var tl = Look.label(d.title, "news_bold", 14, Look.INK)
		tl.clip_text = true
		tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tv.add_child(tl)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var bar = _Bar.new(Look.RED if hot else Color("c08a3e"), d.heat / 100.0)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size.y = 7
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var lean_txt = "even" if absf(d.lean) < 15 else ("%s ahead" % (ax.left if d.lean < 0 else ax.right).to_lower())
		var ll = Look.label(lean_txt, "body", 11, Color("6d5d4a"))
		ll.custom_minimum_size.x = 118
		ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ll.clip_text = true
		row.add_child(ll)
		tv.add_child(row)
	tc.pressed.connect(func(): open_file.emit("debates"))
	# 3. Carlos's note
	var pim = _card(Color("f8dc58"), "green", -3.0)
	pim.custom_minimum_size.y = 150
	var pv = _vbox(pim)
	pv.add_child(Look.label(_pim_note(s), "type", 15, Color("3b2a12"), true))
	var sign = Look.label("— Carlos", "type", 14, Color("3b2a12"))
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pv.add_child(sign)
	# speaking is free; the other actions cost money, so a poor party is sent to the debates
	pim.pressed.connect(func(): open_file.emit("debates" if s.money < 1.5 else "actions"))
	# 4. Margaret's note, only when earned
	var teyl = _teyl_note(s)
	if teyl != "":
		var c = _card(Color("fdfaf2"), "black", 1.5)
		c.clickable = false
		c.string_to = true
		var v = _vbox(c)
		v.add_child(Look.label(teyl, "type", 15, Color("8b1e1e"), true))
		var sg = Look.label("— Margaret", "type", 14, Color("8b1e1e"))
		sg.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.add_child(sg)
	# 5. this week's headlines
	if s.log.size():
		var c = _card(Color("f3ead6"), "yellow", -1.2)
		var v = _vbox(c)
		var mast = Look.label("The Cranebo Herald", "news_bold", 17)
		mast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(mast)
		v.add_child(_rule())
		var n = 0
		for i in range(s.log.size() - 1, -1, -1):
			if n >= 3: break
			var l: Dictionary = s.log[i]
			v.add_child(Look.caps(G.date_label(l.week, false), 10, Color("7a6a52"), 1))
			v.add_child(_clamp_lines(Look.label(l.text, "news_bold" if n == 0 else "news", 14 if n == 0 else 13, Look.INK, true), 4))
			n += 1
		c.pressed.connect(func(): open_file.emit("diary"))
	# 6. trouble to watch
	var watch = _watch(s)
	if watch.size():
		var c = _card(Color("fbf7ee"), "red", 2.4)
		c.string_to = true
		var v = _vbox(c)
		v.add_child(Look.caps("⚠ Watch", 11, Look.RED))
		for w in watch:
			v.add_child(Look.caps(w[0], 13, Look.INK, 1, "display_bold"))
			v.add_child(Look.label(w[1], "body", 13, Look.INK, true))
		c.pressed.connect(func(): open_file.emit("parties"))
	_fit()

class _Bar extends Control:
	var col: Color
	var frac: float:
		set(x): frac = x; queue_redraw()
	var from = -1.0
	func _init(c: Color, f: float) -> void:
		col = c; frac = f
	func _ready() -> void:
		if from < 0: return
		var to = frac
		frac = from
		var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.35)
		tw.tween_property(self, "frac", to, 0.9)
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.08))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * frac, size.y)), col)

## Containers straighten their children, so each card sits in a plain holder
## that the flow lays out; the card inside is free to tilt.
class Holder extends Control:
	var card: Control
	func _init(c: Control) -> void:
		card = c
		add_child(c)
		mouse_filter = Control.MOUSE_FILTER_PASS
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		c.minimum_size_changed.connect(_sync)
		resized.connect(_layout)
	func _sync() -> void:
		custom_minimum_size = card.get_combined_minimum_size()
	func _layout() -> void:
		card.position = Vector2.ZERO
		card.size = size
		card.pivot_offset = size / 2

func _card(bg: Color, pin: String, tilt: float) -> Card:
	var c = Card.new(bg, pin, tilt)
	c.custom_minimum_size.x = 210
	var h = Holder.new(c)
	_flow.add_child(h)
	_cards.append(c)
	return c

func _vbox(c: Control) -> VBoxContainer:
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(v)
	return v

func _rule() -> Control:
	var r = ColorRect.new()
	r.color = Look.INK
	r.custom_minimum_size.y = 2
	return r

func _clamp_lines(l: Label, n: int) -> Label:
	l.max_lines_visible = n
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l

func _cal_row(a: String, b: String, big := false) -> Control:
	var h = HBoxContainer.new()
	var col = Color("6b1a12") if big else Color("3b2a12")
	h.add_child(Look.label(a, "type", 16 if big else 14, col))
	var sp = Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	h.add_child(Look.label(b, "type", 16 if big else 14, col))
	return h

func _next_week(s: Dictionary, test: Callable) -> int:
	for w in range(s.week + 1, game.ELECTION_WEEK + 1):
		if test.call(game.calendar(w)): return w
	return -1

func _front_summary(s: Dictionary, front) -> Dictionary:
	if front == null: return {}
	match front.type:
		"event":
			var ev: Dictionary = game.event_of(front)
			var kinds = {"flagship": "Flagship promise", "crisis": "Crisis", "opportunity": "Opportunity", "trap": "Tricky moment", "scandal": "Scandal", "regional": "Regional issue", "foreign": "Foreign affairs", "followup": "Consequences"}
			return {"kicker": kinds.get(ev.get("kind", ""), "Event"), "title": ev.title, "text": ev.text, "stamp": "Decision needed"}
		"budget":
			return {"kicker": "Quarterly budget", "title": "Where does the money go?", "text": "₱%sM in the account. Rallies, social media, TV and the national tour are waiting for a decision." % Game.fmt1(s.money), "stamp": "Sign off"}
		"poll":
			return {"kicker": s.polls[front.index].label, "title": "The poll is in", "text": "The numbers for every party, and the map, are updated.", "stamp": "Read it"}
		"news":
			return {"kicker": "Breaking", "title": front.items[0].title, "text": front.items[0].text, "stamp": "Read it"}
		"debate":
			return {"kicker": "Live on CBC", "title": "The final debate", "text": "Seven million people are watching. Your rivals have been reading your old quotes.", "stamp": "Tonight"}
		"election":
			return {"kicker": "Election night", "title": "The results are in", "text": "", "stamp": "Open"}
	return {}

func _pim_note(s: Dictionary) -> String:
	var n: int = s.actionsLeft
	var agenda: bool = not s.agenda.done
	var nb = _next_week(s, func(c): return c.isQuarterStart)
	if s.result: return "Whatever happens next, it was an honour, boss. Really."
	var hottest = null
	for d in s.debates:
		if hottest == null or d.heat > hottest.heat: hottest = d
	if game.visit_block(s) == "" and s.week < 8: return "First things first, boss: pick a district on the map and go and shake some hands. Once a month, and it costs us nothing."
	if n > 0 and hottest and hottest.heat >= 50: return "Everyone's talking about %s. %d action%s left. Whatever you say about it, I'm sure it'll be the right thing." % [hottest.title.to_lower(), n, "" if n == 1 else "s"]
	if n > 0 and agenda: return "%d action%s left this month, and nobody has started this month's argument yet. Could be you, boss." % [n, "" if n == 1 else "s"]
	if n > 0: return "%d action%s left this month. Whenever you're ready." % [n, "" if n == 1 else "s"]
	if s.money > 6 and nb >= 0: return "We're sitting on ₱%sM. Next budget in %s. I've kept the donors happy." % [Game.fmt1(s.money), game.date_label(nb, false)]
	return "Quiet week. I've moved the bad news to Monday."

func _teyl_note(s: Dictionary) -> String:
	if game.inconsistency_of(s, game.player_party(s)) >= 2: return "Pick a position and keep it. People are starting to notice."
	if s.record.outrages >= 3: return "Shouting gets you noticed. It doesn't get you trusted."
	for m in s.record.money:
		if m.dirty: return "I saw the donor list. We'll talk."
	return ""

func _watch(s: Dictionary) -> Array:
	var items = []
	if s.crisis:
		var c = Game.by_id(game.CRISES, s.crisis.id)
		items.append([c.name, c.blurb])
	for f in game.FOREIGN:
		var st: Dictionary = s.countries.get(f.id, {})
		if st.get("hot", false): items.append([" ".join(f.name), st.get("relation", "Trouble on the border")])
	return items.slice(0, 3)
