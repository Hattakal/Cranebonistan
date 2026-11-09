## main.gd — headquarters: the top bar, the board, the map and the ticker.
## Holds the game state (S) and saves it after every change.
extends Control

const SAVE_PATH := "user://save.json"

var S: Dictionary
var G  # the rules (autoload "Game")

var _bar: PanelContainer
var _party_box: HBoxContainer
var _stats: HBoxContainer
var _date: Label
var _countdown: Label
var _btn_week: Button
var _btn_skip: Button
var _menu = {}
var _board: Board
var _map: MapView
var _ticker: Ticker
var _sheet_layer: Control

func _ready() -> void:
	G = Game
	_build()
	var args = _args()
	if args.has("shot"):
		await _shot(args)
		return
	S = _load() if FileAccess.file_exists(SAVE_PATH) else G.new_game({"partyName": "People's Awakening", "leaderName": "Dorin Vask", "manifesto": {"econ": 0, "immig": 4, "rev": 0, "gov": 3}})
	render()

func _args() -> Dictionary:
	var out = {}
	for a in OS.get_cmdline_user_args():
		var kv = a.trim_prefix("--").split("=", true, 1)
		out[kv[0]] = kv[1] if kv.size() > 1 else "1"
	return out

# ---------- Layout ----------
func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg = ColorRect.new()
	bg.color = Look.T900
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	root.add_child(_build_bar())
	var hq = HBoxContainer.new()
	hq.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hq.add_theme_constant_override("separation", 0)
	root.add_child(hq)
	_board = Board.new()
	_board.game = G
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.size_flags_stretch_ratio = 0.82
	_board.open_decision.connect(func(): _open_front())
	_board.open_file.connect(func(tab): _toast("The %s file arrives in the next stage." % tab))
	hq.add_child(_board)
	var right = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 0)
	hq.add_child(right)
	_map = MapView.new()
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.setup(G)
	_map.tip_provider = _tip
	_map.region_clicked.connect(func(id): _toast("%s: the electorate file arrives in the next stage." % Game.by_id(G.REGIONS, id).name))
	_map.foreign_clicked.connect(func(id): _toast("%s: country profiles arrive in the next stage." % " ".join(Game.by_id(G.FOREIGN, id).name)))
	right.add_child(_map)
	_ticker = Ticker.new()
	_ticker.custom_minimum_size.y = 34
	right.add_child(_ticker)
	_sheet_layer = Control.new()
	_sheet_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sheet_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sheet_layer)

func _build_bar() -> Control:
	_bar = PanelContainer.new()
	var sb = Look.box(Color("221a13"))
	sb.border_color = Look.BRASS
	sb.border_width_bottom = 2
	sb.shadow_color = Color(0, 0, 0, 0.6); sb.shadow_size = 10; sb.shadow_offset = Vector2(0, 4)
	_bar.add_theme_stylebox_override("panel", sb)
	_bar.custom_minimum_size.y = 62
	_bar.z_index = 5
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	_bar.add_child(h)
	_party_box = HBoxContainer.new()
	_party_box.add_theme_constant_override("separation", 10)
	h.add_child(_section(_party_box, 16))
	_stats = HBoxContainer.new()
	_stats.add_theme_constant_override("separation", 6)
	h.add_child(_section(_stats, 10))
	var menu = HBoxContainer.new()
	menu.add_theme_constant_override("separation", 0)
	for m in [["electorate", "users", "Electorate"], ["platform", "scroll-text", "Platform"], ["actions", "megaphone", "Actions"], ["parties", "landmark", "Country"], ["polls", "chart-line", "Polls"], ["diary", "book-open", "Diary"]]:
		var b = _menu_button(m[1], m[2])
		b.pressed.connect(func(): _toast("The %s file arrives in the next stage." % m[2].to_lower()))
		menu.add_child(b)
		_menu[m[0]] = b
	h.add_child(menu)
	var sp = Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	var time = HBoxContainer.new()
	time.add_theme_constant_override("separation", 12)
	var dates = VBoxContainer.new()
	dates.alignment = BoxContainer.ALIGNMENT_CENTER
	dates.add_theme_constant_override("separation", -2)
	_date = Look.label("", "display", 17, Look.HEAD)
	_date.add_theme_font_override("font", Look.spaced("display", 1))
	_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_countdown = Look.label("", "body", 12, Look.AMBER)
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dates.add_child(_date); dates.add_child(_countdown)
	time.add_child(dates)
	_btn_week = _speed_button("play", "Next week")
	_btn_week.pressed.connect(func(): if G.advance_week(S): _after_change())
	time.add_child(_btn_week)
	_btn_skip = _speed_button("fast-forward", "Next decision", true)
	_btn_skip.pressed.connect(func(): if G.advance_to_decision(S): _after_change())
	time.add_child(_btn_skip)
	var tsec = _section(time, 14)
	(tsec.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color(0, 0, 0, 0.22)
	h.add_child(tsec)
	return _bar

func _section(inner: Control, pad: int) -> PanelContainer:
	var p = PanelContainer.new()
	var sb = Look.box(Color(0, 0, 0, 0))
	sb.content_margin_left = pad; sb.content_margin_right = pad
	sb.border_color = Color("45352a"); sb.border_width_right = 1
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(inner)
	return p

func _menu_button(icon_name: String, text: String) -> Button:
	var b = Button.new()
	b.icon = Look.icon(icon_name)
	b.text = text.to_upper()
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 20)
	b.add_theme_font_override("font", Look.spaced("display", 1))
	b.add_theme_font_size_override("font_size", 11)
	b.tooltip_text = text
	for st in ["normal", "focus", "disabled"]: b.add_theme_stylebox_override(st, Look.box(Color(0, 0, 0, 0), 0, Color("33271d"), 0, 0, 6))
	var hov = Look.box(Color("3a2c20"), 0, Color.TRANSPARENT, 0, 0, 6)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", Look.box(Color("5a2a1d"), 0, Color.TRANSPARENT, 0, 0, 6))
	b.add_theme_color_override("font_color", Color("cdbb9b"))
	b.add_theme_color_override("font_hover_color", Look.HEAD)
	b.add_theme_color_override("icon_normal_color", Color("cdbb9b"))
	b.add_theme_color_override("icon_hover_color", Look.HEAD)
	b.custom_minimum_size.x = 82
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b

func _speed_button(icon_name: String, tip: String, primary := false) -> Button:
	var b = Button.new()
	b.icon = Look.icon(icon_name)
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 18)
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(40 if not primary else 0, 36)
	if primary:
		b.text = tip.to_upper()
		b.add_theme_font_override("font", Look.spaced("display", 1))
		b.add_theme_font_size_override("font_size", 13)
	var base = Color("6b1f14") if primary else Color(0, 0, 0, 0.2)
	b.add_theme_stylebox_override("normal", Look.box(base, 5, Look.BRASS if primary else Color("5a4632"), 1, 0, 8))
	b.add_theme_stylebox_override("hover", Look.box(base.lightened(0.15), 5, Look.BRASS, 1, 0, 8))
	b.add_theme_stylebox_override("pressed", Look.box(base.darkened(0.2), 5, Look.BRASS, 1, 0, 8))
	b.add_theme_stylebox_override("disabled", Look.box(Color(0, 0, 0, 0.15), 5, Color("3a2c20"), 1, 0, 8))
	b.add_theme_color_override("font_color", Look.HEAD)
	b.add_theme_color_override("icon_normal_color", Look.HEAD if primary else Color("cdbb9b"))
	b.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.25))
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b

# ---------- Rendering ----------
func render() -> void:
	_render_bar()
	_render_map()
	_board.render(S)
	_ticker.set_items(_ticker_items())

func _after_change() -> void:
	_save()
	render()

func _render_bar() -> void:
	var player: Dictionary = G.player_party(S)
	for c in _party_box.get_children(): c.queue_free()
	var por = Portrait.new()
	por.setup(player)
	por.custom_minimum_size = Vector2(42, 42)
	_party_box.add_child(por)
	var names = VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", -2)
	var pn = Look.label(player.name.to_upper(), "display", 16, Look.HEAD)
	pn.add_theme_font_override("font", Look.spaced("display", 1))
	names.add_child(pn)
	names.add_child(Look.label("Leader: " + player.leader, "body", 12, Look.CREAM_DIM))
	_party_box.add_child(names)
	for c in _stats.get_children(): c.queue_free()
	var mood: float = G.business_mood(S)
	var biz = "Hostile" if mood < 0.25 else ("Distant" if mood < 0.4 else ("Cautious" if mood < 0.7 else ("Willing" if mood < 1.1 else "Generous")))
	_chip("Funds", "₱%sM" % Game.fmt1(S.money), "Campaign money. Income arrives every quarter.")
	_chip("Polling", _polling(), "Your national vote share in the latest poll.")
	_chip("Known by", "%d%%" % Game.jround(G.national_awareness(S) * 100), "Share of adults who have heard of your party.")
	_chip("Business", biz, "Business donors are %s. Angry donors give less." % Game.business_word(mood), Look.RED.lightened(0.4) if mood < 0.4 else Color.TRANSPARENT)
	_chip("Trust", Game.trust_label(S.trust), "Trust in the political system. Low trust helps outsiders.")
	_date.text = G.date_label(S.week).to_upper()
	var months_left = int(ceil(float(G.ELECTION_WEEK - S.week) / G.WEEKS_PER_MONTH))
	_countdown.text = "Election held" if S.result else "Election in %d month%s" % [months_left, "" if months_left == 1 else "s"]
	var blocked: bool = S.queue.size() > 0 or S.result != null
	_btn_week.disabled = blocked
	_btn_skip.disabled = blocked

func _chip(label: String, value: String, tip: String, warn := Color.TRANSPARENT) -> void:
	var p = PanelContainer.new()
	var sb = Look.box(Color(0, 0, 0, 0.28), 5, Color("3f3024"), 1)
	sb.content_margin_left = 10; sb.content_margin_right = 10; sb.content_margin_top = 3; sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	p.tooltip_text = tip
	p.custom_minimum_size.x = 74
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", -3)
	v.add_child(Look.caps(label, 10, Color("a8957a"), 1, "body"))
	var val = Look.label(value, "display", 17, warn if warn.a > 0 else Look.HEAD)
	v.add_child(val)
	p.add_child(v)
	_stats.add_child(p)

func _polling() -> String:
	if S.polls.is_empty(): return "?"
	var cur: Dictionary = S.polls[-1]
	var now: float = cur.national.player
	var txt = "%s%%" % Game.fmt1(now * 100)
	if S.polls.size() > 1:
		var d: float = now - S.polls[-2].national.player
		if absf(d) >= 0.002: txt += (" ▲" if d > 0 else " ▼")
	return txt

func _render_map() -> void:
	var poll = S.polls[-1] if S.polls.size() else null
	_map.fills = {}
	_map.shares = {}
	_map.hot = {}
	if poll:
		for r in G.REGIONS:
			var sh: Dictionary = poll.regions[r.id]
			var ids: Array = Game.ssort(sh.keys(), func(a, b): return sh[b] - sh[a])
			var lead: String = ids[0]
			var margin: float = sh[ids[0]] - sh[ids[1]]
			var strength = clampf(0.3 + margin * 3, 0.3, 0.75)
			_map.fills[r.id] = Look.mix(Look.LAND, Color(G.party_of(S, lead).color), strength * 0.8)
			_map.shares[r.id] = "You %d%%" % Game.jround(sh.player * 100)
	for f in G.FOREIGN:
		_map.hot[f.id] = S.countries.get(f.id, {}).get("hot", false)
	_map.legend = S.parties.map(func(p): return [p.short, Color(p.color)])
	_map.legend_note = ("%s, %s. Scroll to zoom, drag to move." % [poll.label, G.date_label(poll.week, false)]) if poll else "No poll yet."
	_map.queue_redraw()

func _tip(id: String, kind: String) -> Array:
	if kind == "region":
		var r = Game.by_id(G.REGIONS, id)
		var lines = [r.name, r.blurb if r.has("blurb") else ""]
		if S.polls.size():
			var sh: Dictionary = S.polls[-1].regions[id]
			lines.append("Your support: %d%%" % Game.jround(sh.player * 100))
		lines.append("Click for its voters")
		return lines.filter(func(x): return x != "")
	var f = Game.by_id(G.FOREIGN, id)
	var st: Dictionary = S.countries.get(id, {})
	var lines = [" ".join(f.name), st.get("relation", f.get("relation", ""))]
	if st.get("notes", []).size(): lines.append(st.notes[-1].text)
	lines.append("Click for its profile")
	return lines.filter(func(x): return x != "")

func _ticker_items() -> Array:
	var out = []
	for i in range(S.log.size() - 1, maxi(-1, S.log.size() - 7), -1): out.append(S.log[i].text)
	return out if out.size() else ["Welcome to the campaign."]

# ---------- Decisions (a plain sheet for now; stage 3 gives them their real look) ----------
func _open_front() -> void:
	if S.result and S.queue.is_empty(): return
	var front: Dictionary = S.queue[0]
	var sheet = Sheet.new()
	_sheet_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_sheet_layer.add_child(sheet)
	sheet.closed.connect(func():
		_sheet_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_after_change())
	match front.type:
		"event":
			var ev: Dictionary = G.event_of(front)
			sheet.title(ev.title, ev.text)
			for i in ev.choices.size():
				var ch: Dictionary = ev.choices[i]
				sheet.choice(ch.label, func():
					var lines: Array = ch.get("lines", [])
					if lines.size():
						sheet.clear_choices()
						sheet.note("You will %s. How do you say it?" % ch.label.to_lower())
						for j in lines.size():
							sheet.choice("“%s”" % lines[j].text, func(): _result(sheet, G.resolve_event(S, i, j)))
					else:
						_result(sheet, G.resolve_event(S, i, -1)))
		"budget":
			sheet.title("The quarterly budget", "₱%sM to spend. (The full budget screen arrives in the next stage.)" % Game.fmt1(S.money))
			sheet.choice("Spread it across the country", func():
				var alloc = {}
				var tot = 0.0
				for r in G.REGIONS: tot += r.adults
				for r in G.REGIONS: alloc[r.id] = S.money * 0.55 * r.adults / tot
				alloc.social = S.money * 0.15; alloc.tv = S.money * 0.15; alloc.tour = S.money * 0.15
				G.resolve_budget(S, alloc, [])
				sheet.close())
			sheet.choice("Save it for later", func(): G.resolve_budget(S, {}, []); sheet.close())
		"poll":
			var p: Dictionary = S.polls[front.index]
			sheet.title(p.label, "You: %s%%. The map and the board are updated." % Game.fmt1(p.national.player * 100))
			sheet.choice("Pin it to the board", func(): G.dismiss_front(S); sheet.close())
		"news":
			sheet.title(front.items[0].title, front.items[0].text)
			sheet.choice("Read on", func(): G.dismiss_front(S); sheet.close())
		"debate":
			var rd: Dictionary = S.debate.rounds[S.debate.step]
			sheet.title(rd.title, rd.prompt)
			for j in rd.lines.size():
				sheet.choice(rd.lines[j].text, func(): G.answer_debate(S, j); sheet.close())
		"election":
			var r: Dictionary = S.result
			sheet.title("Election night", "You won %s%% of the vote and %d seats." % [Game.fmt1(r.votes.player * 100), r.seats.national.player])
			sheet.choice("Close", func(): G.dismiss_front(S); sheet.close())

func _result(sheet: Sheet, res: Dictionary) -> void:
	sheet.clear_choices()
	var txt = ""
	if res.delivery: txt += res.delivery.press + " "
	for c in res.changes.slice(0, 4): txt += "%s %s%.1f. " % [c.label, "+" if c.delta > 0 else "", c.delta]
	sheet.note(txt)
	sheet.choice("Pin it to the board", func(): sheet.close())

func _toast(text: String) -> void:
	var t = Look.label(text, "type", 15, Look.INK, true)
	var p = PanelContainer.new()
	var sb = Look.box(Look.PAPER, 0, Look.RED, 0, 10, 12)
	sb.border_width_left = 5; sb.border_color = Look.RED
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(t)
	p.custom_minimum_size.x = 420
	add_child(p)
	await get_tree().process_frame
	p.position = Vector2((size.x - p.size.x) / 2, size.y - p.size.y - 60)
	var tw = p.create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)

# ---------- Saving ----------
func _save() -> void:
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(S))

func _load() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(d) != TYPE_DICTIONARY or int(d.get("version", 0)) != G.SAVE_VERSION:
		return G.new_game({})
	# JSON turns whole numbers into floats; the rules expect ints in a few places
	d.week = int(d.week); d.rng = int(d.rng); d.actionsLeft = int(d.actionsLeft); d.quietMonths = int(d.quietMonths)
	return d

# ---------- Screenshots for checking the look (godot ... -- --shot=path --weeks=N) ----------
func _shot(args: Dictionary) -> void:
	S = G.new_game({"seed": 42, "partyName": "People's Awakening", "leaderName": "Dorin Vask", "manifesto": {"econ": 0, "immig": 4, "rev": 0, "gov": 3}})
	var weeks = int(args.get("weeks", "20"))
	var guard = 0
	while S.week < weeks and guard < 500:
		guard += 1
		if S.queue.is_empty():
			if S.actionsLeft > 0 and S.week % 8 == 0: G.act_outrage(S)
			G.advance_week(S); continue
		var f: Dictionary = S.queue[0]
		match f.type:
			"event": G.resolve_event(S, 0, 0 if G.event_of(f).choices[0].get("lines", []).size() else -1)
			"budget": G.resolve_budget(S, {"tour": S.money * 0.5, "cranbia": S.money * 0.3}, [])
			"debate": G.answer_debate(S, 0)
			_: G.dismiss_front(S)
	# stop on the next decision so the board shows one
	G.advance_to_decision(S)
	render()
	for i in 20: await get_tree().process_frame
	if args.has("hover"): _map.hover = args.hover; _map._mouse = _map.to_screen(Vector2(1300, 980)); _map.queue_redraw()
	if args.has("open"): _open_front()
	for i in 10: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(args.shot)
	print("shot saved ", args.shot)
	get_tree().quit()

# ---------- Small pieces ----------
class Ticker extends Control:
	var items: Array = []
	var _x = 0.0
	var _w = 0.0
	func set_items(list: Array) -> void:
		if list == items: return
		items = list
		_w = 0
	func _ready() -> void:
		clip_contents = true
	func _process(d: float) -> void:
		_x -= d * 60
		if _w > 0 and _x < -_w: _x += _w
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Look.RED)
		draw_rect(Rect2(0, 0, size.x, 2), Color("f2c14e"))
		var f = Look.font("display")
		var tag_w = 100.0
		var x = tag_w + 20 + _x
		var gap = 48.0
		var total = 0.0
		for t in items: total += f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + gap
		_w = total
		while x < size.x:
			for t in items:
				draw_string(f, Vector2(x, size.y / 2 + 6), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("fff6e6"))
				x += f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + gap
			if total <= 0: break
		draw_rect(Rect2(0, 0, tag_w, size.y), Color("f2c14e"))
		draw_string(Look.spaced("display_bold", 2), Vector2(12, size.y / 2 + 6), "CBC NEWS", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("2a1d12"))

class Portrait extends Control:
	var col = Color.GRAY
	var initials = ""
	func setup(p: Dictionary) -> void:
		col = Color(p.color)
		var parts: PackedStringArray = p.leader.split(" ")
		initials = (parts[0][0] + (parts[-1][0] if parts.size() > 1 else "")).to_upper()
	func _draw() -> void:
		var c = size / 2
		var r = minf(size.x, size.y) / 2
		draw_circle(c, r + 2, Look.BRASS_DIM)
		draw_circle(c, r, col.darkened(0.1))
		var f = Look.font("display_bold")
		var fs = int(r * 0.9)
		var w = f.get_string_size(initials, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, c + Vector2(-w / 2, fs * 0.36), initials, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("fff3dc"))

class Sheet extends Control:
	signal closed
	var _paper: PanelContainer
	var _v: VBoxContainer
	var _choices: VBoxContainer
	func _init() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var dim = ColorRect.new()
		dim.color = Color(0.03, 0.02, 0.01, 0.82)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(dim)
		var center = CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(center)
		_paper = PanelContainer.new()
		_paper.add_theme_stylebox_override("panel", Look.box(Look.PAPER, 0, Color.TRANSPARENT, 0, 24, 30))
		_paper.custom_minimum_size.x = 720
		center.add_child(_paper)
		_v = VBoxContainer.new()
		_v.add_theme_constant_override("separation", 14)
		_paper.add_child(_v)
		_choices = VBoxContainer.new()
		_choices.add_theme_constant_override("separation", 10)
	func _ready() -> void:
		_v.add_child(_choices)
		_paper.pivot_offset = _paper.size / 2
		_paper.scale = Vector2(0.5, 0.5)
		_paper.rotation_degrees = -5
		modulate.a = 0
		var tw = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "modulate:a", 1.0, 0.2)
		tw.tween_property(_paper, "scale", Vector2.ONE, 0.4)
		tw.tween_property(_paper, "rotation_degrees", 0.0, 0.4)
		_paper.resized.connect(func(): _paper.pivot_offset = _paper.size / 2)
	func title(t: String, text: String) -> void:
		_v.add_child(Look.label(t, "news_bold", 34, Look.INK, true))
		if text != "": _v.add_child(Look.label(text, "news", 17, Look.INK, true))
		if _choices.get_parent() == _v: _v.move_child(_choices, -1)
	func note(t: String) -> void:
		var l = Look.label(t, "type", 15, Look.INK, true)
		_v.add_child(l)
		if _choices.get_parent() == _v: _v.move_child(_choices, -1)
	func clear_choices() -> void:
		for c in _choices.get_children(): c.queue_free()
	func choice(text: String, cb: Callable) -> void:
		var b = Button.new()
		b.text = text
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_override("font", Look.font("type"))
		b.add_theme_font_size_override("font_size", 16)
		b.add_theme_color_override("font_color", Color("1f2a44"))
		b.add_theme_color_override("font_hover_color", Look.RED)
		var sb = Look.box(Color("fdfaf2"), 0, Color.TRANSPARENT, 0, 3, 12)
		sb.border_width_top = 3; sb.border_color = Color("d9534f")
		b.add_theme_stylebox_override("normal", sb)
		var hv = sb.duplicate(); hv.bg_color = Color("fffdf6")
		b.add_theme_stylebox_override("hover", hv)
		b.add_theme_stylebox_override("pressed", hv)
		b.add_theme_stylebox_override("focus", sb)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(cb)
		_choices.add_child(b)
	func close() -> void:
		var tw = create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.15)
		tw.tween_callback(func(): closed.emit(); queue_free())
