## board.gd — the desk: only what is current or urgent, in a column beside the map.
## The decision waiting for you is the one sheet of paper under the lamp; everything
## else is dark glass: what the country is arguing about, a message from Carlos, a
## note from Margaret when you've earned one, the wire, and trouble to watch.
## Behind it all, the office window: blinds, and Cranebo at night.
class_name Board
extends Control

signal open_decision
signal open_file(tab: String)

var game
var _flow: HFlowContainer
var _scroll: ScrollContainer
var _cards: Array = []
var _key = ""
var _last_front = ""

class Card extends PanelContainer:
	signal pressed
	var clickable = true
	var lit = false          # paper under the lamp; otherwise dark glass
	var _sb: StyleBoxFlat
	var _hover: StyleBoxFlat
	func _init(paper := false, accent := Color.TRANSPARENT) -> void:
		lit = paper
		if lit:
			_sb = Look.box(Look.PAPER, 2, Color.TRANSPARENT, 0, 0, 0)
			_sb.shadow_color = Color(Look.LAMP, 0.13)   # the pool of lamp light it lies in
			_sb.shadow_size = 34
		else:
			_sb = Look.glass(0, Color(Look.N800, 0.94))
		if accent.a > 0:
			_sb.border_width_left = 3
			_sb.border_color = accent
		_sb.content_margin_left = 18; _sb.content_margin_right = 18
		_sb.content_margin_top = 14; _sb.content_margin_bottom = 14
		_hover = _sb.duplicate()
		if lit:
			_hover.bg_color = Look.CARD
			_hover.shadow_color = Color(Look.LAMP, 0.22)
		else:
			_hover.bg_color = Look.N700
			if accent.a == 0: _hover.border_color = Look.LAMP_DIM
		add_theme_stylebox_override("panel", _sb)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func(): if clickable: add_theme_stylebox_override("panel", _hover))
		mouse_exited.connect(func(): add_theme_stylebox_override("panel", _sb))
	func _ready() -> void:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if clickable else Control.CURSOR_ARROW
	func _gui_input(e: InputEvent) -> void:
		if clickable and e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			pressed.emit(); accept_event()

## Somebody put a cup down on it.
class CoffeeRing extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c = Vector2(size.x - 74, 46)
		var col = Color(Look.LAMP_DIM, 0.22)
		draw_arc(c, 27, 0.5, 5.3, 48, col, 2.6, true)
		draw_arc(c, 24.5, 1.4, 4.2, 32, Color(col, 0.12), 1.4, true)
		draw_circle(c + Vector2(34, 17), 2.2, Color(col, 0.18))

## A small light that breathes: something is waiting.
class Pulse extends Control:
	var col := Look.RED
	var _t = 0.0
	func _init() -> void:
		custom_minimum_size = Vector2(14, 14)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(d: float) -> void:
		_t += d; queue_redraw()
	func _draw() -> void:
		var c = size / 2
		var k = fmod(_t, 1.6) / 1.6
		draw_circle(c, 4 + k * 7, Color(col, 0.5 * (1 - k)))
		draw_circle(c, 4, col)

## The office behind the desk: light through the blinds, and the city in the window.
class Room extends Control:
	var _t = 0.0
	func _ready() -> void:
		resized.connect(queue_redraw)
	func _process(d: float) -> void:
		var was = int(_t * 1.2)
		_t += d
		if int(_t * 1.2) != was: queue_redraw()   # only the beacon on the tower changes
	func _draw() -> void:
		# light through the blinds: faint warm bars, slanting down from the top left
		var bar = 15.0; var gap = 23.0
		for i in 9:
			var y0 = 34.0 + i * (bar + gap)
			var slant = size.x * 0.16
			var fade = 1.0 - i / 9.0
			draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(size.x, y0 + slant), Vector2(size.x, y0 + slant + bar), Vector2(0, y0 + bar)]),
				PackedColorArray([Color(Look.LAMP, 0.13 * fade), Color(Look.LAMP, 0.015), Color(Look.LAMP, 0.015), Color(Look.LAMP, 0.13 * fade)]))
		# Cranebo at night, low in the window
		var base = size.y
		var glow_h = 300.0
		draw_polygon(PackedVector2Array([Vector2(0, base - glow_h), Vector2(size.x, base - glow_h), Vector2(size.x, base), Vector2(0, base)]),
			PackedColorArray([Color(Look.N600, 0.0), Color(Look.N600, 0.0), Color(Look.N500, 0.5), Color(Look.N500, 0.5)]))
		# a big low moon, so the night isn't only grim
		var moon = Vector2(size.x * 0.78, base - 215)
		draw_circle(moon, 64, Color(Look.TXT, 0.03))
		draw_circle(moon, 46, Color(Look.TXT, 0.05))
		draw_circle(moon, 30, Color(Look.mix(Look.TXT, Look.LAMP, 0.25), 0.78))
		draw_circle(moon + Vector2(-9, -6), 6, Color(Look.N500, 0.16))
		draw_circle(moon + Vector2(8, 9), 4, Color(Look.N500, 0.14))
		var rng = RandomNumberGenerator.new()
		rng.seed = 1964
		var tallest = Vector2.ZERO
		for layer in 2:
			var col = Look.N700 if layer == 0 else Look.N900
			var x = -10.0
			while x < size.x:
				var w = rng.randf_range(26, 64) * (0.8 if layer == 0 else 1.0)
				var h = rng.randf_range(50, 170) * (1.0 if layer == 0 else 0.6)
				if layer == 0 and rng.randf() < 0.12: h += 60
				var r = Rect2(x, base - h, w, h)
				draw_rect(r, col)
				if layer == 0 and (tallest == Vector2.ZERO or r.position.y < tallest.y): tallest = Vector2(x + w / 2, r.position.y)
				# lit windows: a few, in a grid
				var wy = r.position.y + 8
				while wy < base - 8:
					var wx = x + 5
					while wx < x + w - 6:
						if rng.randf() < (0.16 if layer == 0 else 0.11):
							draw_rect(Rect2(wx, wy, 3, 4), Color(Look.LAMP, 0.32 if layer == 0 else 0.6))
						wx += 7
					wy += 10
				x += w + rng.randf_range(-4, 10)
		# the beacon on the tallest tower
		draw_rect(Rect2(tallest.x - 1, tallest.y - 16, 2, 16), Look.N800)
		if int(_t * 1.2) % 2 == 0:
			draw_circle(tallest + Vector2(0, -17), 6, Color(Look.RED, 0.25))
			draw_circle(tallest + Vector2(0, -17), 2.2, Look.RED_HI)

func _ready() -> void:
	clip_contents = true
	var room = Room.new()
	room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(room)
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var m = MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]: m.add_theme_constant_override("margin_" + side, 22)
	m.add_theme_constant_override("margin_bottom", 130)   # room for Carlos in the corner
	_scroll.add_child(m)
	_flow = HFlowContainer.new()
	_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flow.add_theme_constant_override("h_separation", 14)
	_flow.add_theme_constant_override("v_separation", 14)
	m.add_child(_flow)
	resized.connect(_fit)

func _fit() -> void:
	var inner = size.x - 44 - 8
	var gap = 14.0
	var cols = maxi(1, int((inner + gap) / (230 + gap)))
	var w = floorf((inner - gap * (cols - 1)) / cols) - 1
	for c in _cards:
		c.custom_minimum_size.x = maxf(200, inner) if c.has_meta("wide") else w

# ---------- Building the cards ----------
func render(s: Dictionary) -> void:
	var key = JSON.stringify([s.week, s.queue.size(), s.queue[0] if s.queue.size() else null, s.log.size(), s.polls.size(), s.actionsLeft, s.agenda.done, s.money, s.debates.map(func(d): return [d.id, int(d.heat), int(d.lean)])])
	if key == _key: return
	_key = key
	for c in _cards: c.queue_free()
	_cards.clear()
	var G = game
	var front = s.queue[0] if s.queue.size() else null
	var sum = _front_summary(s, front)
	# 1. the decision waiting for you: the one sheet of paper on the desk
	if not sum.is_empty() or s.result:
		if sum.is_empty(): sum = {"kicker": "Election night", "title": "The results", "text": "", "stamp": "Open"}
		var c = _card(true)
		c.set_meta("wide", true)
		var v = _vbox(c)
		if not sum.get("picture"):
			var ring = CoffeeRing.new()
			ring.top_level = false
			c.add_child(ring)
			c.move_child(ring, 0)
		if sum.get("picture"):
			var ph = Photo.new(sum.picture)
			ph.custom_minimum_size.y = 150
			v.add_child(ph)
		v.add_child(Look.caps("%s · %s" % [sum.kicker, G.date_label(s.week, false)], 12, Look.RED))
		v.add_child(Look.label(sum.title, "news_bold", 29, Look.INK, true))
		if sum.text != "": v.add_child(_clamp_lines(Look.label(sum.text, "news", 16, Look.MUTED, true), 3))
		var foot = HBoxContainer.new()
		foot.add_theme_constant_override("separation", 8)
		foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		foot.add_child(Pulse.new())
		var st = Look.caps(sum.stamp, 13, Look.RED, 2, "display_bold")
		st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.add_child(st)
		var go = PanelContainer.new()
		go.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var gsb = Look.box(Look.INK, 2, Color.TRANSPARENT, 0, 0, 5)
		gsb.content_margin_left = 12; gsb.content_margin_right = 12
		go.add_theme_stylebox_override("panel", gsb)
		go.add_child(Look.caps("Open  →", 12, Look.PAPER, 2, "display_bold"))
		foot.add_child(go)
		var gapc = Control.new(); gapc.custom_minimum_size.y = 2
		v.add_child(gapc)
		v.add_child(foot)
		c.pressed.connect(func(): open_decision.emit())
		if _last_front != sum.title:
			_last_front = sum.title
			c.modulate.a = 0
			c.create_tween().tween_property(c, "modulate:a", 1.0, 0.45)
	else:
		var c = _card()
		c.clickable = false
		c.set_meta("wide", true)
		var v = _vbox(c)
		v.add_child(Look.dcaps(G.date_label(s.week), 12, Look.FAINT))
		v.add_child(Look.dlabel("Nothing on fire", "news_bold", 26))
		v.add_child(Look.dlabel("Plan your month in the files above, or move the clock forward.", "news", 16, Look.DIM, true))
	# 2. what the country is arguing about
	var tc = _card()
	var tv = _vbox(tc)
	tv.add_child(_head("The national debate"))
	var list: Array = Game.ssort(s.debates.duplicate(), func(x, y): return y.heat - x.heat).slice(0, 4)
	if list.is_empty(): tv.add_child(Look.dlabel("Nobody is arguing about anything. Start something.", "body", 14, Look.DIM, true))
	for d in list:
		var ax = Game.by_id(G.AXES, d.axis)
		var hot: bool = d.heat >= 50
		var tl = Look.dlabel(d.title, "body_bold", 14)
		tl.clip_text = true
		tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tv.add_child(tl)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var bar = _Bar.new(Look.RED if hot else Look.LAMP_DIM, d.heat / 100.0)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size.y = 4
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var lean_txt = "even" if absf(d.lean) < 15 else ("%s ahead" % (ax.left if d.lean < 0 else ax.right).to_lower())
		var ll = Look.dlabel(lean_txt, "body", 11, Look.FAINT)
		ll.custom_minimum_size.x = 112
		ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ll.clip_text = true
		row.add_child(ll)
		tv.add_child(row)
	tc.pressed.connect(func(): open_file.emit("debates"))
	# 3. a message from Carlos
	var pim = _card(false, Look.LAMP)
	var pv = _vbox(pim)
	pv.add_child(_head("Carlos Martin", Look.LAMP, "message"))
	pv.add_child(Look.dlabel(_pim_note(s), "body", 15, Look.TXT, true))
	# speaking is free; the other actions cost money, so a poor party is sent to the debates
	pim.pressed.connect(func(): open_file.emit("debates"))
	# 4. Margaret's note, only when earned
	var teyl = _teyl_note(s)
	if teyl != "":
		var c = _card(false, Look.RED)
		c.clickable = false
		var v = _vbox(c)
		v.add_child(_head("Margaret Perkins", Look.RED_HI, "note"))
		v.add_child(Look.dlabel(teyl, "type", 13, Look.TXT, true))
	# 5. the wire: this week's headlines
	if s.log.size():
		var c = _card()
		var v = _vbox(c)
		v.add_child(_head("The Cranebo Herald", Look.DIM, "latest"))
		var n = 0
		for i in range(s.log.size() - 1, -1, -1):
			if n >= 3: break
			var l: Dictionary = s.log[i]
			if n > 0: v.add_child(_rule())
			v.add_child(_clamp_lines(Look.dlabel(l.text, "news", 15, Look.TXT if n == 0 else Look.DIM, true), 4))
			n += 1
		c.pressed.connect(func(): open_file.emit("diary"))
	# 6. trouble to watch
	var watch = _watch(s)
	if watch.size():
		var c = _card(false, Look.RED)
		var v = _vbox(c)
		v.add_child(_head("Watch", Look.RED_HI))
		for w in watch:
			v.add_child(Look.dcaps(w[0], 14, Look.TXT, 1, "display_bold"))
			v.add_child(Look.dlabel(w[1], "body", 13, Look.DIM, true))
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
		draw_rect(Rect2(Vector2.ZERO, size), Look.N600)
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * frac, size.y)), col)

func _card(paper := false, accent := Color.TRANSPARENT) -> Card:
	var c = Card.new(paper, accent)
	c.custom_minimum_size.x = 210
	c.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_flow.add_child(c)
	_cards.append(c)
	return c

func _vbox(c: Control) -> VBoxContainer:
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(v)
	return v

## A card's heading: small capitals, with a quieter word on the right.
func _head(text: String, col := Look.DIM, right := "") -> Control:
	var h = HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l = Look.dcaps(text, 12, col)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	if right != "": h.add_child(Look.dcaps(right, 10, Look.FAINT, 1))
	return h

func _rule() -> Control:
	var r = ColorRect.new()
	r.color = Look.N600
	r.custom_minimum_size.y = 1
	return r

func _clamp_lines(l: Label, n: int) -> Label:
	l.max_lines_visible = n
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l

func _next_week(s: Dictionary, test: Callable) -> int:
	for w in range(s.week + 1, game.ELECTION_WEEK + 1):
		if test.call(game.calendar(w)): return w
	return -1

func _front_summary(s: Dictionary, front) -> Dictionary:
	if front == null: return {}
	match front.type:
		"event":
			var ev: Dictionary = game.event_of(front)
			var kinds = {"flagship": "Flagship promise", "crisis": "Crisis", "opportunity": "Opportunity", "trap": "Tricky moment", "scandal": "Scandal", "regional": "Regional issue", "foreign": "Foreign affairs", "followup": "Consequences", "secret": "In confidence", "violence": "Political violence"}
			return {"kicker": kinds.get(ev.get("kind", ""), "Event"), "title": ev.title, "text": ev.text, "stamp": "Decision needed", "picture": Photo.event(ev)}
		"budget":
			return {"kicker": "Quarterly budget", "title": "Where does the money go?", "text": "₱%sM in the account. Trips, social media, TV and the national tour are waiting for a decision." % Game.fmt1(s.money), "stamp": "Sign off"}
		"poll":
			return {"kicker": s.polls[front.index].label, "title": "The poll is in", "text": "The numbers for every party, and the map, are updated.", "stamp": "Read it"}
		"news":
			return {"kicker": "Breaking", "title": front.items[0].title, "text": front.items[0].text, "stamp": "Read it"}
		"interview":
			return {"kicker": "Year one", "title": "The big interview", "text": "An hour on %s with %s. The country is about to meet you." % [s.interview.outletName, s.interview.who], "stamp": "On air"}
		"debate":
			return {"kicker": "Live on CBC", "title": "The final debate", "text": "Seven million people are watching. Your rivals have been reading your old quotes.", "stamp": "Tonight"}
		"convoy":
			return {"kicker": "The campaign", "title": "Plan the convoy", "text": "%d weeks to go. Where does the convoy stop each week?" % int(game.C.campaign.weeks), "stamp": "Plan it"}
		"rally":
			return {"kicker": "On the road", "title": "The convoy in %s" % front.res.place, "text": "Your vote there: %s%% → %s%%." % [Game.fmt1(float(front.res.before) * 100), Game.fmt1(float(front.res.after) * 100)], "stamp": "Read it"}
		"election":
			return {"kicker": "Election night", "title": "The results are in", "text": "", "stamp": "Open"}
	return {}

func _pim_note(s: Dictionary) -> String:
	var n: int = s.actionsLeft
	var agenda: bool = not s.agenda.done
	var nb = _next_week(s, func(c): return c.isQuarterStart)
	var hottest = null
	for d in s.debates:
		if hottest == null or d.heat > hottest.heat: hottest = d
	# the lines are in data/carlos.json DESK; the first that fits wins
	var fill = {"n": n, "s": "" if n == 1 else "s", "topic": hottest.title.to_lower() if hottest else "", "money": Game.fmt1(s.money), "when": game.date_label(nb, false) if nb >= 0 else ""}
	var key = "quiet"
	if s.result: key = "over"
	elif game.visit_block(s) == "" and s.week < 8: key = "first_trip"
	elif n > 0 and hottest and hottest.heat >= 50: key = "hot"
	elif n > 0 and agenda: key = "agenda"
	elif n > 0 and game.in_campaign(s): key = "campaign"
	elif n > 0: key = "actions"
	elif s.money > 6 and nb >= 0: key = "money"
	return String(_desk_lines("carlos").get(key, "")).format(fill)

## The desk notes of Carlos or Margaret (data/<who>.json DESK).
var _desk_cache = {}
func _desk_lines(who: String) -> Dictionary:
	if not _desk_cache.has(who): _desk_cache[who] = Mods.data(who).get("DESK", {})
	return _desk_cache[who]

func _teyl_note(s: Dictionary) -> String:
	if game.teyl(s) == null: return ""   # she has left the party
	var lines: Dictionary = _desk_lines("margaret")
	if game.inconsistency_of(s, game.player_party(s)) >= 2: return String(lines.get("drift", ""))
	if s.record.outrages >= 3: return String(lines.get("outrage", ""))
	for m in s.record.money:
		if m.dirty: return String(lines.get("money", ""))
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
