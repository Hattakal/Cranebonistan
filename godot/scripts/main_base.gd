## main_base.gd — headquarters, part 1 of a chain (like the rules): the game state, the
## layout, the top bar, Options, Carlos and Margaret, saving and small pieces. Each file
## extends the one before (base → map → events → moments → places → story → main) and may
## only call functions in itself or earlier; a call that must go the other way is declared
## as a stub at the bottom of this file and filled in by the later one.
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
var _files: Files
var _map: MapView
var _ticker: Ticker
var _sheet_layer: Control

func _ready() -> void:
	G = Game
	Settings.load_all()   # the player's options: colour scheme, text size, grain, sound
	if _args().has("look"): Look.use(_args().look)
	if _args().has("mapedge"): Settings.values["mapedge"] = _args().mapedge   # --mapedge=fade in a screenshot
	if _args().has("text"): Look.text_boost = 2 if _args().text == "large" else 0   # --text=large in a screenshot
	_build()
	var args = _args()
	if args.has("shot"):
		await _shot(args)
		return
	var saved = _load() if FileAccess.file_exists(SAVE_PATH) else null
	if saved:
		S = saved
		render()
		if not Settings.reopen: _auto_open()   # back from Options: the desk, not the decision
	else:
		# no game yet: headquarters sits empty behind the founding sheet
		_founding = true
		S = G.new_game({"partyName": "People's Awakening", "leaderName": "Dorin Vask"})
		render()
		_founding_sheet()
		if not Settings.reopen: _title_card()
	if Settings.reopen:
		Settings.reopen = false
		_options_sheet()

## Options: how the game looks and sounds (settings.gd). A change of colour scheme or text
## size rebuilds the screen; the game itself carries on where it was.
func _options_sheet() -> void:
	var p = _paper(640, false)
	_options_build(p)

func _options_build(p: Paper) -> void:
	p.clear()
	p.kicker("Options")
	p.heading("How the game looks", 34)
	var rebuild = func(key, val):
		Settings.set_value(key, val)
		if S and not _founding: _save()
		Settings.reopen = true
		get_tree().reload_current_scene()
	_option_row(p, "Colour scheme", "The whole screen. Study: an old office, dark wood and leather. Night: cold steel and glass.",
		[["Study", "study"], ["Night", "night"]], "look", rebuild)
	_option_row(p, "Text size", "Every word in the game, a little bigger.", [["Normal", "normal"], ["Large", "large"]], "text", rebuild)
	_option_row(p, "Film grain", "A little grain and darker corners over everything.", [["On", true], ["Off", false]], "grain", func(k, val):
		Settings.set_value(k, val)
		_grain.visible = val
		_options_build(p))
	_option_row(p, "Map edges", "Whether the map ends clean at its edges or fades into the dark around it.", [["Clear", "clear"], ["Fade", "fade"]], "mapedge", func(k, val):
		Settings.set_value(k, val)
		if _map: _map.queue_redraw()
		_options_build(p))
	_option_row(p, "Window", "", [["Window", false], ["Full screen", true]], "fullscreen", func(k, val):
		Settings.set_value(k, val)
		_options_build(p))
	p.step("Sound", "Volume")
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var sl = HSlider.new()
	sl.min_value = 0; sl.max_value = 1; sl.step = 0.05
	sl.value = float(Settings.get_value("volume"))
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pct = Look.label("%d%%" % Game.jround(sl.value * 100), "display_bold", 18, Look.INK)
	pct.custom_minimum_size.x = 56
	sl.value_changed.connect(func(x):
		pct.text = "%d%%" % Game.jround(x * 100)
		Settings.set_value("volume", x))
	row.add_child(sl)
	row.add_child(pct)
	p.add(row)
	p.small("For now that is Carlos's voice, when his lines are recorded.")
	p.actions([p.button("Close", func(): p.close())])

## One option: its name, a line about it, and a button per choice (the current one in red).
func _option_row(p: Paper, title: String, note: String, choices: Array, key: String, cb: Callable) -> void:
	p.rule(1, Look.LINE)
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	info.add_child(Look.label(title, "body_bold", 15, Look.INK))
	if note != "": info.add_child(Look.label(note, "body", 12, Look.MUTED, true))
	h.add_child(info)
	for c in choices:
		var on: bool = Settings.get_value(key) == c[1]
		var val = c[1]
		var b = p.button(c[0], func(): if not on: cb.call(key, val), false)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if on:   # the current choice is filled in ink (red stays for the button to press)
			for st in ["normal", "hover", "pressed"]: b.add_theme_stylebox_override(st, Look.box(Look.INK, 2, Look.INK, 1, 0, 10))
			for fc in ["font_color", "font_hover_color", "font_focus_color"]: b.add_theme_color_override(fc, Look.CARD)
			b.mouse_default_cursor_shape = Control.CURSOR_ARROW
		h.add_child(b)
	p.add(h)

## The title, over the city at night, before a new party is founded. Any click or key moves on.
func _title_card() -> void:
	var t = Control.new()
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.z_index = 80
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	t.focus_mode = Control.FOCUS_ALL
	var bg = ColorRect.new()
	bg.color = Look.N950
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_child(bg)
	var room = Board.Room.new()
	room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_child(room)
	var c = CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_child(c)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(v)
	var name = Look.label(str(ProjectSettings.get_setting("application/config/name")).to_upper(), "display_light", 78, Color.WHITE)
	name.add_theme_font_override("font", Look.spaced("display_light", 22))
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name)
	var rule = ColorRect.new()
	rule.color = Look.RED
	rule.custom_minimum_size = Vector2(0, 2)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(rule)
	var sub = Look.label("Four years to an election. Nobody has heard of you yet.", "news_italic", 26, Look.DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var gap = Control.new(); gap.custom_minimum_size.y = 40
	v.add_child(gap)
	var hint = Look.caps("Click to begin", 13, Look.FAINT, 4)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	add_child(t)
	for l in [name, sub, hint]: l.modulate.a = 0
	var tw = t.create_tween()
	tw.tween_property(name, "modulate:a", 1.0, 1.6).set_delay(0.4)
	tw.parallel().tween_property(rule, "custom_minimum_size:x", 220.0, 1.4).set_delay(0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(sub, "modulate:a", 1.0, 1.0)
	tw.tween_property(hint, "modulate:a", 1.0, 0.8).set_delay(0.6)
	var leave = func():
		if t.has_meta("leaving"): return
		t.set_meta("leaving", true)
		var out = t.create_tween()
		out.tween_property(t, "modulate:a", 0.0, 0.7)
		out.tween_callback(t.queue_free)
	t.gui_input.connect(func(e):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventKey and e.pressed): leave.call())
	t.grab_focus.call_deferred()

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
	bg.color = Look.SEA
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
	var left = Control.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.64
	hq.add_child(left)
	_board = Board.new()
	_board.game = G
	_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board.open_decision.connect(func(): _open_front())
	_board.open_file.connect(func(tab): _show_file(tab))
	_board.small_task.connect(func():
		var r: Dictionary = G.act_small_task(S)
		if r.ok: _toast(r.text)
		_after_change())
	left.add_child(_board)
	_files = Files.new()
	_files.G = G
	_files.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_files.changed.connect(func(): _after_change())
	_files.toast.connect(func(t): _toast(t))
	_files.open_country.connect(func(id): _country_sheet(id))
	_files.speak.connect(func(id, side): _speak_sheet(id, side))
	_files.raise.connect(func(opt): _raise_sheet(opt))
	var right = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 0)
	hq.add_child(right)
	_map = MapView.new()
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.setup(G)
	_map.tip_provider = _tip
	_map.region_clicked.connect(func(id): _files.S = S; _files.open_region(id); _sync_menu())
	_map.foreign_clicked.connect(func(id): _country_sheet(id))
	_map.district_clicked.connect(func(id): _route_pick(id) if _route_edit else _district_sheet(id))
	_map.pin_clicked.connect(func(id): _story_clicked(id))
	right.add_child(_map)
	_build_map_modes()
	_ticker = Ticker.new()
	_ticker.custom_minimum_size.y = 34
	right.add_child(_ticker)
	# planning files open over the whole desk, below the top bar
	add_child(_files)
	_files.offset_top = 62
	_files.z_index = 10
	_sheet_layer = Control.new()
	_sheet_layer.z_index = 20
	_sheet_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sheet_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sheet_layer)
	_advisor = Advisor.new()
	_advisor.z_index = 25
	add_child(_advisor)
	# over everything: film grain and darker corners
	var grain = ColorRect.new()
	grain.visible = Settings.get_value("grain")
	_grain = grain
	grain.material = Look.material("grain")
	grain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grain.z_index = 90
	add_child(grain)
	# the designer's cheat panel: ` or F12
	_cheats = preload("res://scripts/cheats.gd").new()
	_cheats.main = self
	add_child(_cheats)
	_advisor.margaret_answered.connect(func(agreed):
		var t = G.teyl(S)
		if t: t.loyalty = clampf(t.loyalty + (6.0 if agreed else -8.0), 0, 100)
		if agreed:
			S.flags["teylPromised:" + _margaret_said] = true
			if _margaret_said in ["dirty_money", "hypocrisy"]: S.teylClean = S.week   # she keeps the books for a year
		_save())

func _build_bar() -> Control:
	_bar = PanelContainer.new()
	var sb = Look.box(Look.N850)
	sb.border_color = Look.N600
	sb.border_width_bottom = 1
	sb.shadow_color = Color(0, 0, 0, 0.7); sb.shadow_size = 14; sb.shadow_offset = Vector2(0, 4)
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
	_stats.add_theme_constant_override("separation", 0)
	h.add_child(_section(_stats, 4))
	var menu = HBoxContainer.new()
	menu.add_theme_constant_override("separation", 0)
	for m in [["debates", "flame", "Debates"], ["electorate", "users", "Electorate"], ["platform", "scroll-text", "Platform"], ["parties", "landmark", "Country"], ["media", "newspaper", "Media"], ["polls", "chart-line", "Parties"], ["diary", "book-open", "Diary"]]:
		var b = _menu_button(m[1], m[2])
		b.pressed.connect(func(): _show_file(m[0]))
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
	_date = Look.label("", "display", 18, Look.HEAD)
	_date.add_theme_font_override("font", Look.spaced("display", 2))
	_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_countdown = Look.label("", "body", 12, Look.AMBER)
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dates.add_child(_date); dates.add_child(_countdown)
	time.add_child(dates)
	_btn_week = _speed_button("play", "Next week")
	_btn_week.pressed.connect(func(): _time_pressed(false))
	_btn_week.visible = false   # weeks still tick underneath; the player moves decision to decision
	time.add_child(_btn_week)
	_btn_skip = _speed_button("fast-forward", "Next decision", true)
	_btn_skip.pressed.connect(func(): _time_pressed(true))
	time.add_child(_btn_skip)
	var tsec = _section(time, 14)
	(tsec.get_theme_stylebox("panel") as StyleBoxFlat).border_width_right = 0
	h.add_child(tsec)
	var opt = _speed_button("settings", "Options")
	opt.pressed.connect(func(): _options_sheet())
	var osec = _section(opt, 6)
	(osec.get_theme_stylebox("panel") as StyleBoxFlat).border_width_right = 0
	h.add_child(osec)
	return _bar

var _cheats   # the cheat panel (cheats.gd)
var _grain: ColorRect   # film grain over everything (Options can switch it off)
var _warned_month := -1   # the month we last reminded you about an unused trip or actions

func _time_pressed(to_decision: bool) -> void:
	if _sheet_open(): return
	if S.queue.size():
		_open_front()
		return
	if to_decision and _month_unused(): return
	if (G.advance_to_next_turn(S) if to_decision else G.advance_week(S)): _after_change()

## Before the clock runs past the end of the month: a reminder, once a month, if the
## leader hasn't been on the road yet or there are actions left. Press again to move on.
func _month_unused() -> bool:
	if S.result: return false
	var c: Dictionary = G.calendar(S.week)
	var month: int = (c.year * 12 + c.monthIndex) if not G.in_campaign(S) else 100000 + S.week   # in the campaign: each week
	if month == _warned_month: return false
	var trip: bool = G.visit_block(S) == ""
	var left: int = S.actionsLeft
	if not trip and left <= 0: return false
	_warned_month = month
	var parts = []
	if trip: parts.append("%s hasn't been on the road this month: pick a province on the map" % G.player_party(S).leader)
	if left > 0:
		parts.append("%d action%s left" % [left, "" if left == 1 else "s"])
		if not trip: _show_file("debates")   # the trip is picked on the map, so keep it in view
	_toast("%s. Press %s again to move on." % ["; ".join(parts), "Next week" if G.in_campaign(S) else "Next month"])
	return true

func _section(inner: Control, pad: int) -> PanelContainer:
	var p = PanelContainer.new()
	var sb = Look.box(Color(0, 0, 0, 0))
	sb.content_margin_left = pad; sb.content_margin_right = pad
	sb.border_color = Look.N700; sb.border_width_right = 1
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
	b.add_theme_font_size_override("font_size", Look.fs(11))
	b.tooltip_text = text
	for st in ["normal", "focus", "disabled"]: b.add_theme_stylebox_override(st, _menu_box(false))
	b.add_theme_stylebox_override("hover", _menu_box(false, Color(1, 1, 1, 0.05)))
	b.add_theme_stylebox_override("pressed", _menu_box(true))
	b.add_theme_color_override("font_color", Look.DIM)
	b.add_theme_color_override("font_hover_color", Look.HEAD)
	b.add_theme_color_override("font_pressed_color", Look.HEAD)
	b.add_theme_color_override("font_focus_color", Look.DIM)
	b.add_theme_color_override("icon_normal_color", Look.DIM)
	b.add_theme_color_override("icon_hover_color", Look.HEAD)
	b.add_theme_color_override("icon_pressed_color", Look.HEAD)
	b.add_theme_color_override("icon_focus_color", Look.DIM)
	b.custom_minimum_size.x = 70
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b

## A file's button on the top bar: nothing behind it, and a line of lamp light under the open one.
func _menu_box(on: bool, bg := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb = Look.box(Color(1, 1, 1, 0.04) if on else bg, 0, Look.LAMP, 0, 0, 6)
	sb.border_width_bottom = 2
	if not on: sb.border_color = Color(0, 0, 0, 0)
	return sb

func _speed_button(icon_name: String, tip: String, primary := false) -> Button:
	var b = Button.new()
	b.icon = Look.icon(icon_name)
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 18)
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(40 if not primary else 0, 36)
	if primary:
		b.text = tip.to_upper()
		b.add_theme_font_override("font", Look.spaced("display_bold", 2))
		b.add_theme_font_size_override("font_size", Look.fs(14))
		b.add_theme_constant_override("h_separation", 8)
	Look.dark_button(b, primary, false, 10 if primary else 8)
	return b

# ---------- Rendering ----------
func render() -> void:
	_render_bar()
	_render_map()
	_board.render(S)
	_ticker.set_items(_ticker_items())
	_files.S = S
	_files.render()
	_sync_menu()
	_react()

# ---------- Carlos and Margaret react to what changed ----------
var _advisor: Advisor
var _snap = null

func _snapshot() -> Dictionary:
	var c: Dictionary = G.calendar(S.week)
	var comm = 0
	for k in S.communities: comm += int(S.communities[k])
	return {"month": c.year * 12 + c.monthIndex, "polls": S.polls.size(), "front": S.queue[0].type if S.queue.size() else "",
		"lost": S.figuresLost.size(), "comm": comm, "steer": S.steer != null, "result": S.result != null,
		"flips": S.flips.filter(func(f): return f.party == "player").size(),
		"dirty": S.record.money.filter(func(m): return m.dirty).size(),
		"hyp": S.get("secrets", []).filter(func(x): return x.kind == "hypocrisy").size(),
		"deny": int(S.record.get("denials", 0)), "scape": int(S.record.get("scapegoats", 0)), "under": int(S.record.get("understood", 0))}

func _react() -> void:
	if _advisor == null or _founding: return   # Carlos waits until the party exists
	var now = _snapshot()
	var was = _snap
	_snap = now
	if was == null:
		if not S.flags.has("tutorial") and S.week < 8:
			S.flags["tutorial"] = true
			_advisor.call_deferred("tutorial")
		return
	if now.result and not was.result:
		_advisor.say("won" if S.result.playerWon else "lost", true)
		return
	if now.lost > was.lost:
		_advisor.say("figure_quit", false, 0.8)
		_margaret("figure_quit")
	if now.front != was.front:
		match now.front:
			"budget": _advisor.say("budget", false, 0.8)
			"event": _advisor.say("event", false, 0.5)
			"debate": _advisor.say("debate_night", true)
			"interview": _advisor.say("event", false, 0.8)
	if now.polls > was.polls and S.polls.size() > 1:
		var d: float = S.polls[-1].national.player - S.polls[-2].national.player
		if not S.polls[-1].get("tracker", true): _advisor.say("annual_poll", false, 0.9)
		elif d > 0.004: _advisor.say("poll_up", false, 0.8)
		elif d < -0.004: _advisor.say("poll_down", false, 0.8)
		else: _advisor.say("poll_flat", false, 0.4)
	elif now.month != was.month:
		var left = int(ceil(float(G.ELECTION_WEEK - S.week) / G.WEEKS_PER_MONTH))
		if left == 3: _advisor.say("election_near", true)
		else: _advisor.say("month_start", false, 0.35)
	if now.comm > was.comm: _advisor.say("community", false, 0.7)
	if now.steer and not was.steer:
		_advisor.say("steer", false, 0.8)
		if not S.steer.get("back", false): _margaret("steer")   # going back to the founding manifesto is fine by her
	if now.flips > was.flips: _margaret("flip")
	if now.dirty > was.dirty:
		_advisor.say("dirty_money", false, 0.7)
		_margaret("dirty_money")
	if now.hyp > was.hyp: _margaret("hypocrisy")
	if now.deny > was.deny: _margaret("deny")
	if now.scape > was.scape: _margaret("scapegoat", true)   # she always speaks then
	if now.under > was.under: _margaret("violence", true)

## Margaret only appears now and then: at most once every two months.
var _margaret_said := ""   # what Margaret's latest note was about

func _margaret(trigger: String, force := false) -> void:
	if G.teyl(S) == null: return
	if not force and S.week - int(S.flags.get("margaretLast", -999)) < 8: return
	S.flags["margaretLast"] = S.week
	_margaret_said = trigger
	# she remembers being promised: doing it again after agreeing with her costs far more
	if S.flags.get("teylPromised:" + trigger, false):
		var t0 = G.teyl(S)
		if t0: t0.loyalty = clampf(t0.loyalty - 12, 0, 100)
	_advisor.margaret(trigger)

func _show_file(tab: String) -> void:
	_files.S = S
	_files.show_tab(tab)
	_sync_menu()

func _sync_menu() -> void:
	for k in _menu:
		var on: bool = _files.visible and _files.tab == k
		for st in ["normal", "focus"]: _menu[k].add_theme_stylebox_override(st, _menu_box(on))
		for c in ["font_color", "font_focus_color", "icon_normal_color", "icon_focus_color"]: _menu[k].add_theme_color_override(c, Look.HEAD if on else Look.DIM)

func _country_sheet(id: String) -> void:
	var f = Game.by_id(G.FOREIGN, id)
	var st: Dictionary = S.countries.get(id, {})
	var p = _paper(760, false)
	p.masthead("Foreign desk", "Diplomatic Brief", st.get("relation", f.relation))
	p.heading(" ".join(f.name), 38)
	p.photo(Photo.find(["places/" + id]), 260)
	p.text(f.summary, 17)
	p.text("%s: %s" % [f.leader.title, f.leader.name], 15, "body_bold")
	p.rule(1)
	p.kicker("Background")
	for x in f.facts: p.text("•  " + x, 15)
	var notes: Array = st.get("notes", [])
	if notes.size():
		p.rule(1)
		p.kicker("Recent developments")
		for i in range(notes.size() - 1, -1, -1):
			p.small(G.date_label(notes[i].week, false).to_upper(), Look.RED)
			p.text(notes[i].text, 15)
	p.actions([p.button("Close", func(): p.close(), true)])

func _after_change() -> void:
	_save()
	render()
	_auto_open()

func _render_bar() -> void:
	var player: Dictionary = G.player_party(S)
	for c in _party_box.get_children(): c.queue_free()
	_party_box.add_child(Face.new(player.leader, Color(player.color), player.id, 42))
	var names = VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", -2)
	var pn = Look.label(player.name.to_upper(), "display_bold", 17, Look.HEAD)
	pn.add_theme_font_override("font", Look.spaced("display_bold", 2))
	names.add_child(pn)
	names.add_child(Look.label(player.leader, "body", 12, Look.DIM))
	_party_box.add_child(names)
	var mood: float = G.business_mood(S)
	var biz = "Hostile" if mood < 0.25 else ("Distant" if mood < 0.4 else ("Cautious" if mood < 0.7 else ("Willing" if mood < 1.1 else "Generous")))
	_chip("Funds", "₱%sM" % Game.fmt1(S.money), "Campaign money. Income arrives every quarter.", Color.TRANSPARENT,
		S.money, func(x): return "₱%sM" % Game.fmt1(x))
	var arrow = _polling().substr(_polling().find("%") + 1)
	var paid: bool = S.polls.size() > 0 and S.polls[-1].get("paid", false)
	_chip("Polling", _polling(), "Your national vote share in the latest poll." + (" A careful, paid-for poll: no random noise." if paid else "") + _why_moved(), Color.TRANSPARENT,
		S.polls[-1].national.player * 100 if S.polls.size() else null, func(x): return "%s%%%s" % [Game.fmt1(x), arrow])
	_chip("Known by", "%d%%" % Game.jround(G.national_awareness(S) * 100), "Share of adults who know your party and roughly what it stands for: they could place you on the issues. Nobody votes for a party they can't place.", Color.TRANSPARENT,
		G.national_awareness(S) * 100, func(x): return "%d%%" % Game.jround(x))
	_chip("Taken seriously", "%d" % Game.jround(G.serious_of(S)), "How seriously the public, the media and the other parties take your party (0-100): %s. It grows with your support, your name and your party machine, and the higher it is, the further your words carry and the readier people are to vote for you." % G.influence_label(S).to_lower(), Color.TRANSPARENT,
		G.serious_of(S), func(x): return "%d" % Game.jround(x))
	var per: int = int(G.C.campaign.actionsPerWeek) if G.in_campaign(S) else int(G.C.actionsPerMonth)
	_chip("Actions", "%d of %d" % [S.actionsLeft, per], "Actions left %s: speaking in a debate, starting one, opening an office, digging, winning over a branch, a pact. They come back %s." % [G.period_word(S), "every week in the campaign" if G.in_campaign(S) else "every month"], Look.RED_HI if S.actionsLeft <= 0 else Color.TRANSPARENT)
	_chip("Business", biz, "Business donors are %s. Angry donors give less." % Game.business_word(mood), Look.RED_HI if mood < 0.4 else Color.TRANSPARENT)
	_chip("Trust in politics", Game.trust_label(S.trust), "How much people trust politicians and the system in general (not your party). Low trust helps outsiders.")
	_date.text = G.date_label(S.week, false).to_upper()
	var months_left = int(ceil(float(G.ELECTION_WEEK - S.week) / G.WEEKS_PER_MONTH))
	_countdown.text = "Election held" if S.result else "Election in %d month%s" % [months_left, "" if months_left == 1 else "s"]
	# a decision that was put down waits on the board; the time buttons take you back to it
	var waiting: bool = S.queue.size() > 0
	_btn_week.disabled = S.result != null and not waiting
	_btn_skip.disabled = S.result != null and not waiting
	var step: String = "next week" if G.in_campaign(S) or G.campaign_stop_index(S) == -1 else "next month"
	_btn_skip.text = "OPEN DECISION" if waiting else step.to_upper()
	_btn_week.tooltip_text = "A decision is waiting for you" if waiting else "Next week"
	_btn_skip.tooltip_text = "A decision is waiting for you" if waiting else "On to the %s (it stops early if something needs a decision)" % step

func _chip(label: String, value: String, tip: String, warn := Color.TRANSPARENT, num = null, fmt := Callable()) -> void:
	# chips are built once and then updated, so a count in progress survives a refresh
	var base: Color = warn if warn.a > 0 else Look.HEAD
	if not _chips.has(label):
		var p = PanelContainer.new()
		var sb = Look.box(Color(0, 0, 0, 0))
		sb.content_margin_left = 8; sb.content_margin_right = 8
		p.add_theme_stylebox_override("panel", sb)
		p.custom_minimum_size.x = 60
		var v = VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", -4)
		v.add_child(Look.caps(label, 10, Look.DIM, 1))
		var l = Look.label(value, "display_bold", 21, base)
		l.pivot_offset = Vector2(0, 12)
		v.add_child(l)
		p.add_child(v)
		_stats.add_child(p)
		_chips[label] = {"panel": p, "val": l, "tw": null}
	var c: Dictionary = _chips[label]
	var val: Label = c.val
	c.panel.tooltip_text = tip
	var last = _chip_last.get(label, null)
	_chip_last[label] = num
	if num == null or last == null or absf(float(num) - float(last)) < 0.0005:
		if c.tw == null or not c.tw.is_running():
			val.text = value
			val.add_theme_color_override("font_color", base)
		return
	# count from the old number to the new one, and flash the direction
	if c.tw: c.tw.kill()
	var up: bool = float(num) > float(last)
	var flash: Color = Look.GOOD_HI if up else Look.RED_HI
	val.add_theme_color_override("font_color", flash)
	val.text = fmt.call(float(last))
	val.scale = Vector2(1.15, 1.15)
	var tw = val.create_tween().set_parallel()
	tw.tween_method(func(x): val.text = fmt.call(x), float(last), float(num), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(col): val.add_theme_color_override("font_color", col), flash, base, 1.4).set_delay(0.8)
	tw.tween_property(val, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func(): val.text = value)
	c.tw = tw

func _polling() -> String:
	if S.polls.is_empty(): return "?"
	var cur: Dictionary = S.polls[-1]
	var now: float = cur.national.player
	var txt = "%s%%" % Game.fmt1(now * 100)
	if S.polls.size() > 1:
		var d: float = now - S.polls[-2].national.player
		if absf(d) >= 0.002: txt += (" ▲" if d > 0 else " ▼")
	return txt

var _leaders = {}       # region id -> leading party, to spot a change of hands
var _chip_last = {}     # chip label -> last number shown
var _chips = {}         # chip label -> {panel, val, tw}

var _map_mode := "vote"
var _mode_buttons := {}
var _profiles := {}     # district id -> what it is like now (G.district_profiles), for the modes and tooltips
var _convoy_btn: Button
var _route_bar: HBoxContainer
var _route_note: Label
var _down_key = ""        # the decision the player put down to look around first
var _budget = {}
var _offers = []
var _budget_for = ""
func _front_key() -> String:
	return JSON.stringify([S.week, S.queue[0]]) if S.queue.size() else ""
func _paper(width := 820, can_down := true) -> Paper:
	var p = Paper.new(width, can_down)
	_sheet_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_sheet_layer.add_child(p)
	p.closed.connect(func(): if _sheet_layer.get_child_count() <= 1: _sheet_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE)
	p.put_down.connect(func(): _down_key = _front_key())
	return p
const KINDS := {"flagship": "Flagship promise", "crisis": "Crisis", "opportunity": "Opportunity", "trap": "Tricky moment", "scandal": "Scandal", "regional": "Regional issue", "foreign": "Foreign affairs", "followup": "Consequences", "secret": "In confidence", "violence": "Political violence"}
## The styles among `lines`, in the order of TONES: [{"tone", "idx": indices into lines}].
var _shot_words := false
var _route_edit := false     # choosing stops on the map
var _route_from := 0         # the first stop being chosen
var _route_draft: Array = [] # the route as it stands while choosing
## The picture with the story: godot/assets/tours/<region>_<kind>.jpg, or tours/<kind>.jpg
## (kind: great, good, flat). Until those exist, a drawn stand-in in the same two inks:
## a hall, a stage, and a crowd as big as the trip went well.
class TourPhoto extends Control:
	var kind := "good"
	var region := ""
	var party_color := Look.RED
	var _tex: Texture2D = null
	func _ready() -> void:
		_tex = Photo.find(["tours/%s_%s" % [region, kind], "tours/" + kind])
		if _tex:
			var ph = Photo.new(_tex)
			ph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			add_child(ph)
	func _draw() -> void:
		var r = Rect2(Vector2.ZERO, size)
		if _tex: return
		var inner = r
		var ink = Look.N900
		draw_rect(inner, Look.mix(ink, Look.PAPER, 0.5))
		# back wall, banner and stage
		draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.55)), Look.mix(ink, Look.PAPER, 0.68))
		var bw = inner.size.x * 0.42
		draw_rect(Rect2(inner.position + Vector2((inner.size.x - bw) / 2, inner.size.y * 0.1), Vector2(bw, inner.size.y * 0.16)), party_color)
		draw_rect(Rect2(inner.position + Vector2(inner.size.x * 0.3, inner.size.y * 0.45), Vector2(inner.size.x * 0.4, inner.size.y * 0.08)), Look.mix(ink, Look.PAPER, 0.25))
		draw_circle(inner.position + Vector2(inner.size.x * 0.5, inner.size.y * 0.33), inner.size.y * 0.05, ink)
		draw_rect(Rect2(inner.position + Vector2(inner.size.x * 0.5 - inner.size.y * 0.04, inner.size.y * 0.37), Vector2(inner.size.y * 0.08, inner.size.y * 0.09)), ink)
		# the crowd: heads in rows, more of them the better it went
		var row_n = {"great": 5, "good": 3, "flat": 1}
		var fill_n = {"great": 1.0, "good": 0.75, "flat": 0.3}
		var rows: int = int(row_n.get(kind, 3))
		var fill: float = float(fill_n.get(kind, 0.7))
		var rng = RandomNumberGenerator.new()
		rng.seed = 7
		for row in rows:
			var rad = inner.size.y * (0.075 - row * 0.008)
			var y = inner.end.y - rad * 0.6 - row * inner.size.y * 0.085
			var x = inner.position.x + rad
			while x < inner.end.x - rad:
				if rng.randf() < fill: draw_circle(Vector2(x + rng.randf() * 4, y), rad, Look.mix(ink, Look.PAPER, rng.randf() * 0.14))
				x += rad * 1.7
var _found = {}
var _founding := false   # the founding sheet is up; nothing else should talk yet
class SeatBar extends Control:
	var parts: Array
	var total: int
	func _init(p: Array, t: int) -> void:
		parts = p; total = t
	func _draw() -> void:
		var x = 0.0
		for part in parts:
			var w: float = size.x * part[1] / total
			draw_rect(Rect2(x, 0, maxf(0.0, w - 2.0), size.y), Look.lit(part[0]))
			x += w
		draw_rect(Rect2(size.x / 2 - 1.5, -5, 3, size.y + 10), Color.WHITE)   # the majority line
func _toast(text: String) -> void:
	var t = Look.label(text, "body", 15, Look.TXT, true)
	t.custom_minimum_size.x = 520
	var p = PanelContainer.new()
	var sb = Look.box(Look.N700, 2, Look.N500, 1, 14, 14)
	sb.border_width_left = 4; sb.border_color = Look.RED
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(t)
	p.z_index = 30
	add_child(p)
	await get_tree().process_frame
	p.reset_size()
	p.position = Vector2((size.x - p.size.x) / 2, size.y - p.size.y - 60)
	var tw = p.create_tween()
	tw.tween_interval(2.6 + text.length() / 40.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)
# ---------- Saving ----------
func _save() -> void:
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(S))

## The saved game, or null when there is none the current rules can read (then a new party is founded).
func _load() -> Variant:
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(d) != TYPE_DICTIONARY or int(d.get("version", 0)) != G.SAVE_VERSION:
		return null
	# JSON turns whole numbers into floats; the rules expect ints in a few places
	d.week = int(d.week); d.rng = int(d.rng); d.actionsLeft = int(d.actionsLeft); d.quietMonths = int(d.quietMonths)
	var now_mods: Array = Mods.enabled().map(func(m): return "%s %s" % [m.name, m.version])
	if d.get("mods", []) != now_mods: push_warning("This save was started with mods %s; now loaded: %s. It may behave oddly." % [str(d.get("mods", [])), str(now_mods)])
	return d

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
		# a news channel left on with the sound off: a dark strap, the channel's red tag, a live light
		draw_rect(Rect2(Vector2.ZERO, size), Look.N950)
		draw_rect(Rect2(0, 0, size.x, 1), Look.N600)
		var f = Look.spaced("display", 1)
		var tag_w = 132.0
		var x = tag_w + 24 + _x
		var gap = 56.0
		var total = 0.0
		for t in items: total += f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + gap
		_w = total
		while x < size.x:
			for t in items:
				draw_rect(Rect2(x - gap / 2 - 2, size.y / 2 - 2, 4, 4), Look.RED)
				draw_string(f, Vector2(x, size.y / 2 + 6), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Look.DIM)
				x += f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + gap
			if total <= 0: break
		draw_rect(Rect2(0, 0, tag_w + 14, size.y), Look.N950)
		draw_rect(Rect2(0, 1, tag_w, size.y - 1), Look.RED)
		draw_string(Look.spaced("display_bold", 2), Vector2(12, size.y / 2 + 6), (String(Game.outlet_by_id("cbc").name if Game.outlet_by_id("cbc") else "") + " news").to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
		var blink = 0.35 + 0.65 * absf(sin(Time.get_ticks_msec() / 700.0))
		draw_circle(Vector2(tag_w - 16, size.y / 2), 3.5, Color(1, 1, 1, blink))

## An outlet's name by id (media.json): "cbc" is the state broadcaster (the evening news,
## the debates, election night), "herald" the paper of record.
func _outlet(id: String) -> String:
	var o = G.outlet_by_id(id)
	return String(o.name) if o else id.to_upper()

## The evening news strap, on the state broadcaster.
func _tv(what: String) -> String:
	return "%s · %s" % [_outlet("cbc"), what]

## Why your support moved last month: the moves you made, biggest first, and the rest
## (rivals, the media, time) in one line. Your true support, not the poll.
func _why_moved() -> String:
	var rep = S.get("moveReport")
	if rep == null: return ""
	var pts = func(d: float) -> String: return "%+.1f" % (d * 100)
	var lines = ["", "", "Last month your true support moved %s points:" % pts.call(float(rep.total))]
	var moves: Array = Game.ssort(rep.moves.duplicate(), func(a, b): return absf(float(b.d)) - absf(float(a.d)))
	for m in moves.slice(0, 6): lines.append("  %s  %s" % [pts.call(float(m.d)), m.what])
	if moves.size() > 6: lines.append("  …and %d smaller moves" % (moves.size() - 6))
	lines.append("  %s  everything else: rivals, the media, the economy, time" % pts.call(float(rep.other)))
	lines.append("The poll adds its own margin of error on top.")
	return "\n".join(lines)

# ---------- Hooks: filled in by later files of the chain ----------
func _appearance_sheet() -> void: pass
func _auto_open() -> void: pass
func _budget_sheet(_front: Dictionary, _keep_scroll := 0) -> void: pass
func _build_map_modes() -> void: pass
func _convoy_sheet(_from_desk := false) -> void: pass
func _debate_sheet() -> void: pass
func _district_sheet(_id: String) -> void: pass
func _election_sheet() -> void: pass
func _founding_sheet() -> void: pass
func _interview_sheet() -> void: pass
func _news_sheet(_front: Dictionary) -> void: pass
func _open_front() -> void: pass
func _poll_sheet(_front: Dictionary) -> void: pass
func _profile_sheet() -> void: pass
func _raise_sheet(_opt: Dictionary) -> void: pass
func _rally_sheet(_front: Dictionary) -> void: pass
func _render_map() -> void: pass
func _route_finish(_keep: bool) -> void: pass
func _route_open_from() -> int: return 0
func _route_pick(_id: String) -> void: pass
func _sheet_open() -> bool: return false
func _shot(_args: Dictionary) -> void: pass
func _speak_sheet(_id: String, _side: String) -> void: pass
func _story_clicked(_id: String) -> void: pass
func _ticker_items() -> Array: return []
func _tip(_id: String, _kind: String) -> Array: return []
func _route_undo() -> void: pass
