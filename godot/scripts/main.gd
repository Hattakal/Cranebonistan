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
	_build()
	var args = _args()
	if args.has("shot"):
		await _shot(args)
		return
	var saved = _load() if FileAccess.file_exists(SAVE_PATH) else null
	if saved:
		S = saved
		render()
		_auto_open()
	else:
		# no game yet: headquarters sits empty behind the founding sheet
		_founding = true
		S = G.new_game({"partyName": "People's Awakening", "leaderName": "Dorin Vask"})
		render()
		_founding_sheet()

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
	var left = Control.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.82
	hq.add_child(left)
	_board = Board.new()
	_board.game = G
	_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board.open_decision.connect(func(): _open_front())
	_board.open_file.connect(func(tab): _show_file(tab))
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
	_map.district_clicked.connect(func(id): _district_sheet(id))
	right.add_child(_map)
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
	_advisor.margaret_answered.connect(func(agreed):
		var t = G.teyl(S)
		if t: t.loyalty = clampf(t.loyalty + (6.0 if agreed else -8.0), 0, 100)
		_save())

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
	for m in [["debates", "flame", "Debates"], ["electorate", "users", "Electorate"], ["platform", "scroll-text", "Platform"], ["actions", "megaphone", "Actions"], ["parties", "landmark", "Country"], ["polls", "chart-line", "Polls"], ["diary", "book-open", "Diary"]]:
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
	_date = Look.label("", "display", 17, Look.HEAD)
	_date.add_theme_font_override("font", Look.spaced("display", 1))
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
	(tsec.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color(0, 0, 0, 0.22)
	h.add_child(tsec)
	return _bar

var _warned_month := -1   # the month we last reminded you about an unused trip or actions

func _time_pressed(to_decision: bool) -> void:
	if _sheet_open(): return
	if S.queue.size():
		_open_front()
		return
	if to_decision and _month_unused(): return
	if (G.advance_to_decision(S) if to_decision else G.advance_week(S)): _after_change()

## Before the clock runs past the end of the month: a reminder, once a month, if the
## leader hasn't been on the road yet or there are actions left. Press again to move on.
func _month_unused() -> bool:
	if S.result: return false
	var c: Dictionary = G.calendar(S.week)
	var month: int = c.year * 12 + c.monthIndex
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
	_toast("%s. Press Next decision again to move on." % "; ".join(parts))
	return true

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
	b.add_theme_font_size_override("font_size", Look.fs(11))
	b.tooltip_text = text
	for st in ["normal", "focus", "disabled"]: b.add_theme_stylebox_override(st, Look.box(Color(0, 0, 0, 0), 0, Color("33271d"), 0, 0, 6))
	var hov = Look.box(Color("3a2c20"), 0, Color.TRANSPARENT, 0, 0, 6)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", Look.box(Color("5a2a1d"), 0, Color.TRANSPARENT, 0, 0, 6))
	b.add_theme_color_override("font_color", Color("cdbb9b"))
	b.add_theme_color_override("font_hover_color", Look.HEAD)
	b.add_theme_color_override("icon_normal_color", Color("cdbb9b"))
	b.add_theme_color_override("icon_hover_color", Look.HEAD)
	b.custom_minimum_size.x = 72
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
		b.add_theme_font_size_override("font_size", Look.fs(13))
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
		"dirty": S.record.money.filter(func(m): return m.dirty).size()}

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
		_margaret("steer")
	if now.flips > was.flips: _margaret("flip")
	if now.dirty > was.dirty:
		_advisor.say("dirty_money", false, 0.7)
		_margaret("dirty_money")

## Margaret only appears now and then: at most once every two months.
func _margaret(trigger: String) -> void:
	if G.teyl(S) == null: return
	if S.week - int(S.flags.get("margaretLast", -999)) < 8: return
	S.flags["margaretLast"] = S.week
	_advisor.margaret(trigger)

func _show_file(tab: String) -> void:
	_files.S = S
	_files.show_tab(tab)
	_sync_menu()

func _sync_menu() -> void:
	for k in _menu:
		var on: bool = _files.visible and _files.tab == k
		_menu[k].add_theme_stylebox_override("normal", Look.box(Color("5a2a1d") if on else Color(0, 0, 0, 0), 0, Color.TRANSPARENT, 0, 0, 6))
		_menu[k].add_theme_color_override("font_color", Look.HEAD if on else Color("cdbb9b"))
		_menu[k].add_theme_color_override("icon_normal_color", Look.HEAD if on else Color("cdbb9b"))

func _country_sheet(id: String) -> void:
	var f = Game.by_id(G.FOREIGN, id)
	var st: Dictionary = S.countries.get(id, {})
	var p = _paper(760, false)
	p.masthead("Foreign desk", "Diplomatic Brief", st.get("relation", f.relation))
	p.heading(" ".join(f.name), 38)
	p.text(f.summary, 17)
	p.text("%s: %s" % [f.leader.title, f.leader.name], 15, "type")
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
	var mood: float = G.business_mood(S)
	var biz = "Hostile" if mood < 0.25 else ("Distant" if mood < 0.4 else ("Cautious" if mood < 0.7 else ("Willing" if mood < 1.1 else "Generous")))
	_chip("Funds", "₱%sM" % Game.fmt1(S.money), "Campaign money. Income arrives every quarter.", Color.TRANSPARENT,
		S.money, func(x): return "₱%sM" % Game.fmt1(x))
	var arrow = _polling().substr(_polling().find("%") + 1)
	_chip("Polling", _polling(), "Your national vote share in the latest poll.", Color.TRANSPARENT,
		S.polls[-1].national.player * 100 if S.polls.size() else null, func(x): return "%s%%%s" % [Game.fmt1(x), arrow])
	_chip("Known by", "%d%%" % Game.jround(G.national_awareness(S) * 100), "Share of adults who have heard of your party.", Color.TRANSPARENT,
		G.national_awareness(S) * 100, func(x): return "%d%%" % Game.jround(x))
	_chip("Business", biz, "Business donors are %s. Angry donors give less." % Game.business_word(mood), Look.RED.lightened(0.4) if mood < 0.4 else Color.TRANSPARENT)
	_chip("Trust in politics", Game.trust_label(S.trust), "How much people trust politicians and the system in general (not your party). Low trust helps outsiders.")
	_date.text = G.date_label(S.week, false).to_upper()
	var months_left = int(ceil(float(G.ELECTION_WEEK - S.week) / G.WEEKS_PER_MONTH))
	_countdown.text = "Election held" if S.result else "Election in %d month%s" % [months_left, "" if months_left == 1 else "s"]
	# a decision that was put down waits on the board; the time buttons take you back to it
	var waiting: bool = S.queue.size() > 0
	_btn_week.disabled = S.result != null and not waiting
	_btn_skip.disabled = S.result != null and not waiting
	_btn_skip.text = "OPEN DECISION" if waiting else "NEXT DECISION"
	_btn_week.tooltip_text = "A decision is waiting for you" if waiting else "Next week"
	_btn_skip.tooltip_text = "A decision is waiting for you" if waiting else "Next decision"

func _chip(label: String, value: String, tip: String, warn := Color.TRANSPARENT, num = null, fmt := Callable()) -> void:
	# chips are built once and then updated, so a count in progress survives a refresh
	var base: Color = warn if warn.a > 0 else Look.HEAD
	if not _chips.has(label):
		var p = PanelContainer.new()
		var sb = Look.box(Color(0, 0, 0, 0.28), 5, Color("3f3024"), 1)
		sb.content_margin_left = 10; sb.content_margin_right = 10; sb.content_margin_top = 3; sb.content_margin_bottom = 3
		p.add_theme_stylebox_override("panel", sb)
		p.custom_minimum_size.x = 74
		var v = VBoxContainer.new()
		v.add_theme_constant_override("separation", -3)
		v.add_child(Look.caps(label, 10, Color("a8957a"), 1, "body"))
		var l = Look.label(value, "display", 17, base)
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
	var flash: Color = Color("7fd18b") if up else Color("ff7a66")
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

func _render_map() -> void:
	var poll = S.polls[-1] if S.polls.size() else null
	_map.fills = {}
	_map.stripes = {}
	_map.shares = {}
	_map.hot = {}
	_map.communities = S.communities
	_map.party_color = Color(G.player_party(S).color)
	if poll:
		for r in G.REGIONS:
			_map.shares[r.id] = "You %d%%" % Game.jround(poll.regions[r.id].player * 100)
	# each district in the colour of whoever would win it today: deep when safe, pale when close
	var proj: Dictionary = S.get("projection", {})
	for d in G.DISTRICTS:
		if not proj.has(d.id): continue
		var x: Dictionary = proj[d.id]
		if _leaders.has(d.id) and _leaders[d.id] != x.winner: _map.flash(d.id)
		_leaders[d.id] = x.winner
		var strength = clampf(0.28 + float(x.margin) * 2.6, 0.28, 0.85)
		_map.fills[d.id] = Look.mix(Look.LAND, Color(G.party_of(S, x.winner).color), strength * 0.85)
		# not yours yet: your colour in stripes, thicker the closer your vote is to the leader's
		if x.winner != "player" and float(x.you) > 0.02:
			var k: float = clampf(float(x.you) / maxf(0.01, float(x.share)), 0.0, 1.0)
			_map.stripes[d.id] = [Color(G.player_party(S).color), 0.08 + 0.72 * k * k]
	for f in G.FOREIGN:
		_map.hot[f.id] = S.countries.get(f.id, {}).get("hot", false)
	var seats: Dictionary = G.projected_seats(proj) if proj.size() else {}
	_map.legend = Game.ssort(S.parties.duplicate(), func(a, b): return int(seats.get(b.id, 0)) - int(seats.get(a.id, 0))).map(func(p): return ["%s %d" % [p.short, int(seats.get(p.id, 0))], Color(p.color)])
	_map.legend_note = ("Seats if the election were today · %s. %d to win." % [poll.label, int(G.C.seats / 2 + 1)]) if poll else "No poll yet."
	_map.queue_redraw()

func _tip(id: String, kind: String) -> Array:
	if kind == "district":
		var d = G.district_by_id(id)
		var w: int = G.winner_seats(int(d.seats))
		var lines = ["%s · %d seat%s" % [d.name, d.seats, "" if d.seats == 1 else "s"], Game.by_id(G.REGIONS, d.region).name + (" · the winner takes all" if w == int(d.seats) else " · the winner takes %d, %d shared by national vote" % [w, int(d.seats) - w])]
		var x: Dictionary = S.get("projection", {}).get(id, {})
		if x.size():
			var who: String = "You" if x.winner == "player" else G.party_of(S, x.winner).short
			var lead: float = float(x.margin) * 100
			lines.append("%s would win it today, %s" % [who, "safely" if lead >= 12 else ("comfortably" if lead >= 5 else "narrowly")])
			lines.append("Your vote here: %d%%" % Game.jround(float(x.you) * 100))
			if x.winner != "player":
				lines.append("You'd need about %d more points" % maxi(1, Game.jround((float(x.share) - float(x.you)) * 100)))
		lines.append("Click to campaign here")
		return lines
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

# ---------- Decisions: each one zooms up as paper ----------
var _down_key = ""        # the decision the player put down to look around first
var _budget = {}
var _offers = []
var _budget_for = ""

func _front_key() -> String:
	return JSON.stringify([S.week, S.queue[0]]) if S.queue.size() else ""

func _sheet_open() -> bool:
	for c in _sheet_layer.get_children():
		if not c.is_queued_for_deletion(): return true
	return false

func _paper(width := 820, can_down := true) -> Paper:
	var p = Paper.new(width, can_down)
	_sheet_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_sheet_layer.add_child(p)
	p.closed.connect(func(): if _sheet_layer.get_child_count() <= 1: _sheet_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE)
	p.put_down.connect(func(): _down_key = _front_key())
	return p

## Called after every change: a new decision zooms up by itself, unless it was put down.
func _auto_open() -> void:
	if S.queue.is_empty() or _sheet_open(): return
	if _front_key() == _down_key: return
	_open_front()

func _open_front() -> void:
	if S.queue.is_empty():
		if S.result: _election_sheet()
		return
	_down_key = ""
	var front: Dictionary = S.queue[0]
	match front.type:
		"event": _event_sheet(front)
		"budget": _budget_sheet(front)
		"poll": _poll_sheet(front)
		"news": _news_sheet(front)
		"debate": _debate_sheet()
		"election": _election_sheet()

func _done(p: Paper) -> void:
	p.close()
	await p.closed
	_after_change()

func _changes_chips(p: Paper, changes: Array) -> void:
	if changes.is_empty(): return
	p.chips(changes.slice(0, 6).map(func(c): return ["%s  %s%s" % [c.label, "+" if c.delta > 0 else "", Game.fmt1(c.delta)], Look.GOOD if c.delta > 0 else Look.RED]))

func _effects_lines(box: VBoxContainer, fx: Dictionary) -> void:
	var d: Dictionary = G.describe_choice(S, fx)
	if d.appeals.size(): box.add_child(Look.label("Appeals to: " + ", ".join(d.appeals.map(func(x): return x.text)), "body", 13, Look.GOOD, true))
	if d.angers.size(): box.add_child(Look.label("Angers: " + ", ".join(d.angers.map(func(x): return x.text)), "body", 13, Look.RED, true))
	var tags: Array = []
	for s in d.stances:
		if s.from != s.to: tags.append("Stance change: %s → %s" % [G.stance_name(s.axis, s.from), G.stance_name(s.axis, s.to)])
	tags.append_array(d.tags)
	if tags.size(): box.add_child(Look.label(" · ".join(tags), "body_italic", 12, Look.MUTED, true))

# ----- Events: the front page, what you say, how you say it, how it played -----
const KINDS := {"flagship": "Flagship promise", "crisis": "Crisis", "opportunity": "Opportunity", "trap": "Tricky moment", "scandal": "Scandal", "regional": "Regional issue", "foreign": "Foreign affairs", "followup": "Consequences"}

func _event_header(p: Paper, ev: Dictionary) -> void:
	var crisis = ""
	if ev.get("kind", "") == "crisis" and S.crisis: crisis = Game.by_id(G.CRISES, S.crisis.id).name
	p.masthead(G.date_label(S.week, false), "The Morning Post", ("Crisis · " + crisis) if crisis != "" else KINDS.get(ev.get("kind", ""), "Event"))
	p.heading(ev.title, 42)
	p.text(ev.text, 18)
	if ev.get("government"):
		var gov = null
		for x in S.parties:
			if x.ruling: gov = x
		p.boxed("The government moved first · " + (gov.short if gov else ""), ev.government.text)
	var world: Dictionary = ev.get("world", {}).duplicate()
	if ev.get("government") and ev.government.get("world"):
		for k in ev.government.world: world[k] = float(world.get(k, 0)) + float(ev.government.world[k])
	if world.size():
		var items = []
		for ind in G.INDICATORS:
			var dv: float = float(world.get(ind.id, 0))
			if absf(dv) < 0.5: continue
			var bad = (ind.good == "high" and dv < 0) or (ind.good == "low" and dv > 0)
			var col = Look.MUTED if ind.good == null else (Look.RED if bad else Look.GOOD)
			items.append(["%s %s %d" % [ind.label, "▲" if dv > 0 else "▼", Game.jround(absf(dv))], col])
		if items.size():
			p.add(Look.caps("What this does to Cranebonistan", 11, Look.MUTED, 2))
			p.chips(items)
	if ev.get("crisisStart") and G.crisis_blames_you(S):
		p.callout("Your party's campaigning helped bring this about. For months you pushed the country toward exactly this.")
	if ev.get("echo") and S.record.blamed.size():
		var b: Dictionary = S.record.blamed[-1]
		p.quote(b.text, "%s, %s. Your words were quoted at the scene." % [G.player_party(S).leader, G.date_label(b.week, false)])

func _event_sheet(front: Dictionary) -> void:
	var ev: Dictionary = G.event_of(front)
	var p = _paper()
	_event_step1(p, ev)

func _event_step1(p: Paper, ev: Dictionary) -> void:
	p.clear()
	_event_header(p, ev)
	var any_lines = false
	for ch in ev.choices:
		if ch.get("lines", []).size(): any_lines = true
	p.step("Step 1 of 2" if any_lines else "Your decision", "What do you promise?" if ev.get("kind", "") == "flagship" else "What do you say?")
	for i in ev.choices.size():
		var ch: Dictionary = ev.choices[i]
		p.card("index", func(box):
			box.add_child(Look.label(ch.label, "type", 19, Color("1f2a44"), true))
			_effects_lines(box, ch.effects),
			func():
				if ch.get("lines", []).size(): _event_step2(p, ev, i)
				else: _event_result(p, G.resolve_event(S, i, -1)))
	p.top()

func _event_step2(p: Paper, ev: Dictionary, i: int) -> void:
	var ch: Dictionary = ev.choices[i]
	p.clear()
	_event_header(p, ev)
	p.step("Step 2 of 2", "How do you say it?")
	if ev.get("kind", "") == "flagship": p.text("Your promise: %s. This goes on every poster for a year." % ch.label, 15, "type")
	else: p.text("You will %s." % (ch.label.substr(0, 1).to_lower() + ch.label.substr(1).trim_suffix(".")), 15, "type")
	p.small("The wording matters. The same position can win people over or blow up in your face.")
	for j in ch.lines.size():
		var line: Dictionary = ch.lines[j]
		p.card("slip", func(box): box.add_child(Look.label("“%s”" % line.text, "news_italic", 21, Look.INK, true)),
			func(): _event_result(p, G.resolve_event(S, i, j)))
	var back = p.button("← Say something else", func(): _event_step1(p, ev), false)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.add(back)

func _event_result(p: Paper, res: Dictionary) -> void:
	p.clear()
	p.decided()
	_result_body(p, res.get("title", ""), res)
	p.actions([p.button("Back to work", func(): _done(p))])
	p.top()

func _result_body(p: Paper, title: String, res: Dictionary, strap := "CBC · Evening news") -> void:
	var player: Dictionary = G.player_party(S)
	p.tv_strap(strap, "How it played · " + title)
	if res.get("quote"):
		p.add(Look.label("%s: “%s”" % [player.leader, res.quote], "news_bold", 26, Look.INK, true))
	else:
		p.add(Look.label("You chose to %s." % (res.label.substr(0, 1).to_lower() + res.label.substr(1).trim_suffix(".")), "news_bold", 24, Look.INK, true))
	var dl = res.get("delivery")
	if dl:
		p.text(dl.press, 17, "news_italic")
		if dl.outcome == "viral": p.stamp("It went viral", Look.GOOD)
		elif dl.outcome == "gaffe": p.stamp("Gaffe", Look.RED)
		if dl.styleNote != "": p.small(dl.styleNote, Look.INK)
	if res.get("extra", "") != "": p.small(res.extra.strip_edges(), Look.INK)
	for f in res.get("flips", []):
		p.callout("Stance change on %s: %s → %s" % [Game.by_id(G.AXES, f.axis).issue.to_lower(), G.stance_name(f.axis, f.from), G.stance_name(f.axis, f.to)])
	if res.get("changes", []).size():
		p.add(Look.caps("Who moved", 11, Look.MUTED, 2))
		_changes_chips(p, res.changes)

# ----- Speaking in a debate -----
const TONE_NAMES := {"statesman": "Measured", "fiery": "Fiery", "folksy": "Folksy", "provocative": "Provocative"}

func _tone_tag(box: VBoxContainer, line: Dictionary, extra := "") -> void:
	var risky: bool = float(line.get("risk", G.TONE_RISK.get(line.tone, 0.3))) >= 0.6
	box.add_child(Look.caps(TONE_NAMES.get(line.tone, line.tone) + (" · risky" if risky else "") + extra, 10, Look.RED if risky else Look.MUTED, 1))

func _speak_sheet(id: String, side: String) -> void:
	var d = G.debate_by_id(S, id)
	if d == null: return
	var ax: Dictionary = Game.by_id(G.AXES, d.axis)
	var major: bool = G.is_major(d)
	var p = _paper(760, false)
	p.kicker(("Major debate · " if major else "The national debate · ") + ax.issue)
	p.heading(d.title, 34)
	p.text(d.text, 16)
	p.step("Speaking for", (ax.left if side == "L" else ax.right))
	if major: p.small("The whole country is watching. Your exact words will be quoted: they can go viral, or become a gaffe that helps the other side.")
	else: p.small("A smaller argument. Your line mostly shapes how people hear you; it won't make the evening news.")
	var lines: Array = G.debate_lines(d, side)
	for j in lines.size():
		var line: Dictionary = lines[j]
		p.card("slip", func(box):
			_tone_tag(box, line)
			box.add_child(Look.label("“%s”" % line.text, "news_italic", 20, Look.INK, true)),
			func():
				var res: Dictionary = G.act_speak(S, id, side, j)
				if not res.ok:
					_toast(res.text); return
				_after_speaking(res, line, d.axis, side)
				# every speech shows how it played; a smaller debate just doesn't make the evening news
				p.clear()
				_result_body(p, res.title, res, "CBC · Evening news" if res.major else "On the record")
				p.actions([p.button("Back to work", func(): _done(p))])
				p.top())
	p.actions([p.button("Back", func(): p.close())])

func _after_speaking(res: Dictionary, line: Dictionary, axis: String, side: String) -> void:
	var outcome: String = res.delivery.outcome
	if outcome == "viral": _advisor.say("viral", true)
	elif outcome == "gaffe":
		_advisor.say("gaffe", false, 0.35)   # only now and then, so it stays funny
		if line.tone == "provocative": _margaret("provocative_gaffe")
	elif res.get("major", false): _advisor.say("speak", false, 0.4)
	var mine = G.manifesto_side(S, axis)
	if mine != "" and mine != side: _margaret("against_manifesto")

func _raise_sheet(opt: Dictionary) -> void:
	var p = _paper(760, false)
	if opt.side != "": _raise_words(p, opt, opt.side)
	else: _raise_side(p, opt)

func _raise_head(p: Paper, opt: Dictionary) -> void:
	var ax: Dictionary = Game.by_id(G.AXES, opt.axis)
	p.kicker(("Proposal · " if opt.kind == "proposal" else "Start a debate · ") + ax.issue)
	p.heading(opt.title, 34)
	p.text(opt.text, 16)

func _raise_side(p: Paper, opt: Dictionary) -> void:
	p.clear()
	_raise_head(p, opt)
	p.step("Step 1 of 2", "Which side are you on?")
	var ax: Dictionary = Game.by_id(G.AXES, opt.axis)
	var mine = G.manifesto_side(S, opt.axis)
	for side in ["L", "R"]:
		p.card("index", func(box):
			box.add_child(Look.label(("★ " if mine == side else "") + (ax.left if side == "L" else ax.right), "display", 22, Look.INK))
			if mine != "" and mine != side: box.add_child(Look.label("Against your manifesto", "body", 13, Look.RED)),
			func(): _raise_words(p, opt, side))
	p.actions([p.button("Not now", func(): p.close())])

func _raise_words(p: Paper, opt: Dictionary, side: String) -> void:
	p.clear()
	_raise_head(p, opt)
	var ax: Dictionary = Game.by_id(G.AXES, opt.axis)
	p.step("Step 2 of 2" if opt.side == "" else "Your words", "How do you put it to the country?")
	p.small("Arguing for %s. Whether it catches on depends on your reach and on how you say it. Bold lines catch more easily, and blow up more easily." % (ax.left if side == "L" else ax.right).to_lower())
	var lines: Array = G.raise_lines(opt, side)
	for j in lines.size():
		var line: Dictionary = lines[j]
		p.card("slip", func(box):
			_tone_tag(box, line, " · %d%% chance it catches on" % Game.jround(G.raise_chance(S, opt, line) * 100))
			box.add_child(Look.label("“%s”" % line.text, "news_italic", 20, Look.INK, true)),
			func():
				var res: Dictionary = G.act_raise(S, opt, side, j)
				if not res.ok:
					_toast(res.text); return
				_after_speaking(res, line, opt.axis, side)
				if res.delivery.outcome == "normal": _advisor.say("raise_caught" if res.caught else "raise_fizzled", false, 0.8)
				p.clear()
				_result_body(p, opt.title, res)
				p.stamp("It caught on" if res.caught else "It fizzled", Look.GOOD if res.caught else Look.MUTED)
				p.actions([p.button("Back to work", func(): _done(p))])
				p.top())
	if opt.side == "":
		var back = p.button("← Other side", func(): _raise_side(p, opt), false)
		back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		p.add(back)
	else:
		p.actions([p.button("Not now", func(): p.close())])

# ----- The budget: a ledger -----
func _budget_sheet(front: Dictionary, keep_scroll := 0) -> void:
	var key = _front_key()
	if _budget_for != key:
		_budget_for = key
		_budget = {}
		for k in G.BUDGET_KEYS: _budget[k] = 0.0
		_offers = []
		if S.lastBudget: _same_as_last()
	var p = _paper(860)
	_budget_build(p, front)

func _same_as_last() -> void:
	var avail = _available()
	for k in G.BUDGET_KEYS: _budget[k] = 0.0
	var spent = 0.0
	for k in G.BUDGET_KEYS:
		var want = float(S.lastBudget.get(k, 0))
		var take = minf(want, maxf(0, avail - spent))
		take = floorf(take * 2) / 2.0
		_budget[k] = take
		spent += take

func _available() -> float:
	var extra = 0.0
	for id in _offers: extra += float(Game.by_id(G.FUNDING_OFFERS, id).effects.get("money", 0))
	return S.money + extra

func _budget_build(p: Paper, front: Dictionary) -> void:
	var sc: int = p._scroll.scroll_vertical
	p.clear()
	var c: Dictionary = G.calendar(S.week)
	var spent = 0.0
	for k in _budget: spent += _budget[k]
	var left = _available() - spent
	var pv: Dictionary = G.preview_budget(S, _budget)
	var inc: Dictionary = S.get("lastIncome", {"total": 0.0, "grassroots": 0.0, "business": 0.0, "mood": 0.0})
	p.kicker("Quarterly budget · Q%d %d" % [c.monthIndex / 3 + 1, c.year])
	p.heading("Where does the money go?", 38)
	p.text("This quarter you raised ₱%sM: ₱%sM from members and small donors, who give more as your party grows, and ₱%sM from business, which is %s. %d%% of adults know your party. Whatever you don't spend is saved." % [Game.fmt1(inc.total), Game.fmt1(inc.grassroots), Game.fmt1(inc.business), Game.business_word(inc.mood), Game.jround(pv.all.before * 100)], 16)
	var offers: Array = front.get("offers", [])
	if offers.size():
		p.add(Look.caps("Money on the table", 11, Look.MUTED, 2))
		for id in offers:
			var o = Game.by_id(G.FUNDING_OFFERS, id)
			var taken: bool = _offers.has(id)
			var dirty: bool = o.effects.has("scandal")
			p.card("index", func(box):
				box.add_child(Look.label(("✓ Taking it · " if taken else "") + o.title, "type", 17, Look.RED if dirty else Color("1f2a44"), true))
				box.add_child(Look.label(o.note, "body", 13, Look.MUTED, true)),
				func():
					if taken: _offers.erase(id)
					else: _offers.append(id)
					_budget_build(p, front))
	var tools = HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	tools.add_child(p.button("Same as last quarter", func(): _same_as_last(); _budget_build(p, front), false, S.lastBudget == null))
	tools.add_child(p.button("Clear", func():
		for k in _budget: _budget[k] = 0.0
		_budget_build(p, front), false))
	p.add(tools)
	p.rule(2)
	var player: Dictionary = G.player_party(S)
	var rows = []
	rows.append(["road", "On the road", "Money for %s's trips this quarter: bigger halls, buses, posters. Each month's trip uses a third of it." % player.leader, pv.all])
	rows.append(["social", "Social media", "Cheap reach to voters under 46. The reaction is unpredictable.", pv.young])
	rows.append(["tv", "TV and newspapers", "Reaches voters over 45 across the country.", pv.old])
	rows.append(["tour", player.leader + "'s national tour", "Builds the leader as a person. Strongest with the young, the working class and Fauran.", pv.all])
	for row in rows:
		var h = HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 1)
		info.add_child(Look.label(row[1], "body_bold", 15, Look.INK))
		info.add_child(Look.label(row[2], "body", 12, Look.MUTED, true))
		var pr: Dictionary = row[3]
		var known: String
		if row[0] == "road":
			var per: float = (float(S.get("roadFund", 0)) + _budget.road) / 3.0
			known = "Each trip this quarter: %s" % ("×%s as strong" % Game.fmt1(1.0 + 0.6 * sqrt(per)) if per > 0 else "on foot, with a megaphone")
		elif row[0] == "tour":
			known = "Leader image: %s%s (%s)" % [Files.leader_score(pr.leaderBefore), (" → " + Files.leader_score(pr.leaderAfter)) if pr.leaderAfter - pr.leaderBefore > 0.005 else "", Files.leader_words(pr.leaderAfter)]
		else:
			known = "Know you: %s%%%s" % [Game.fmt1(pr.before * 100), (" → %s%%" % Game.fmt1(pr.after * 100)) if pr.after - pr.before > 0.0005 else ""]
		info.add_child(Look.label(known, "body", 12, Look.INK))
		h.add_child(info)
		var k: String = row[0]
		h.add_child(p.button("−", func():
			_budget[k] = maxf(0, _budget[k] - 0.5)
			_budget_build(p, front), false, _budget[k] <= 0))
		var amt = Look.label("₱%sM" % Game.fmt1(_budget[k]), "type", 17, Look.INK)
		amt.custom_minimum_size.x = 72
		amt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(amt)
		h.add_child(p.button("+", func():
			if left >= 0.5 - 1e-9: _budget[k] += 0.5
			_budget_build(p, front), false, left < 0.5 - 1e-9))
		p.add(h)
		p.rule(1, Look.LINE)
	var foot = HBoxContainer.new()
	var lt = Look.label("Unspent: ₱%sM" % Game.fmt1(left), "type", 20, Look.INK)
	lt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(lt)
	foot.add_child(p.button("Confirm spending", func():
		var before: Dictionary = G.preview_budget(S, {})
		var res: Dictionary = G.resolve_budget(S, _budget, _offers)
		var after: Dictionary = G.preview_budget(S, {})
		_budget_for = ""
		var msg = "Spent ₱%sM. People who know your party: %s%% → %s%%." % [Game.fmt1(res.spent), Game.fmt1(before.all.before * 100), Game.fmt1(after.all.before * 100)]
		if res.socialSwing: msg += " Your social media posts went down well." if res.socialSwing > 0 else " Your social media posts backfired."
		_toast(msg)
		_done(p)))
	p.add(foot)
	await get_tree().process_frame
	p._scroll.scroll_vertical = sc

# ----- Polls, news, the debate and election night -----
func _bars_into(p: Paper, support: Dictionary, prev) -> void:
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var ids: Array = Game.ssort(support.keys(), func(a, b): return support[b] - support[a])
	var mx: float = support[ids[0]]
	for id in ids:
		var party = G.party_of(S, id)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var nm = Look.label(party.name, "body_bold" if party.isPlayer else "body", 14, Look.INK)
		nm.custom_minimum_size.x = 220
		row.add_child(nm)
		var bar = Files.Bar.new(Color(party.color), support[id] / mx)
		bar.custom_minimum_size.y = 18
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bar)
		var val = Look.label("%s%%" % Game.fmt1(support[id] * 100), "display", 18, Look.INK)
		val.custom_minimum_size.x = 64
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val)
		if prev != null:
			var d: float = support[id] - prev.get(id, support[id])
			var dl = Look.label(("+" if d >= 0 else "") + Game.fmt1(d * 100), "body_bold", 13, Look.GOOD if d >= 0 else Look.RED)
			dl.custom_minimum_size.x = 44
			row.add_child(dl)
		box.add_child(row)
		bar.frac = 0.0
		bar.create_tween().tween_property(bar, "frac", support[id] / mx, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		bar.set_process(true)
	p.add(box)

func _poll_sheet(front: Dictionary) -> void:
	var poll: Dictionary = S.polls[front.index]
	var prev = null
	for i in range(int(front.index) - 1, -1, -1):
		prev = S.polls[i]; break
	var p = _paper(820)
	p.kicker("%s · %s" % [poll.label, G.date_label(poll.week, false)])
	p.heading("The poll is in", 38)
	_bars_into(p, poll.national, prev.national if prev else null)
	p.small("Expected turnout %d%%. Margin of error about ±%s points." % [Game.jround(poll.turnout * 100), Game.fmt1(G.C.pollError * 200)])
	p.add(Look.caps("Region by region", 11, Look.MUTED, 2))
	for r in G.REGIONS:
		var sh: Dictionary = poll.regions[r.id]
		var ids: Array = Game.ssort(sh.keys(), func(a, b): return sh[b] - sh[a])
		p.add(Look.label("%s — %s leads with %d%%. You: %d%%." % [r.name, G.party_of(S, ids[0]).short, Game.jround(sh[ids[0]] * 100), Game.jround(sh.player * 100)], "type", 15, Look.INK, true))
	p.actions([p.button("Pin it to the board", func(): G.dismiss_front(S); _done(p))])

func _news_sheet(front: Dictionary) -> void:
	var labels = {"vacuum": "Power vacuum", "bad": "Trouble", "good": "Comeback", "neutral": "Change", "threat": "Threat", "issue": "Hot issue"}
	var p = _paper(820)
	p.masthead(G.date_label(S.week, false), "The Cranebo Herald", "Late edition")
	var lead: Dictionary = front.items[0]
	p.kicker(labels.get(lead.get("kind", ""), "News"))
	p.heading(lead.title, 40)
	p.text(lead.text, 18)
	if front.items.size() > 1:
		p.rule(1)
		p.add(Look.caps("Also in this edition", 11, Look.MUTED, 2))
		for it in front.items.slice(1):
			p.add(Look.caps(labels.get(it.get("kind", ""), "News"), 11, Look.RED, 2))
			p.add(Look.label(it.title, "news_bold", 20, Look.INK, true))
			p.text(it.text, 15)
	p.actions([p.button("Read on", func(): G.dismiss_front(S); _done(p))])

func _debate_sheet() -> void:
	var p = _paper(860)
	_debate_round(p)

func _debate_round(p: Paper) -> void:
	p.clear()
	var d: Dictionary = S.debate
	var rd: Dictionary = d.rounds[d.step]
	p.tv_strap("CBC · Live", "The final debate · question %d of %d" % [d.step + 1, d.rounds.size()])
	p.heading(rd.title, 36)
	p.text(rd.prompt, 18)
	p.step("Your answer", "What do you say?")
	for j in rd.lines.size():
		var line: Dictionary = rd.lines[j]
		p.card("slip", func(box): box.add_child(Look.label(line.text, "news_italic", 20, Look.INK, true)), func():
			var res: Dictionary = G.answer_debate(S, j)
			p.clear()
			p.decided()
			p.tv_strap("CBC · Live", "The final debate · " + res.round)
			p.add(Look.label(res.quote, "news_bold", 24, Look.INK, true))
			p.text(res.press, 17, "news_italic")
			if res.outcome == "viral": p.stamp("The clip of the night", Look.GOOD)
			elif res.outcome == "gaffe": p.stamp("Gaffe", Look.RED)
			_changes_chips(p, res.changes)
			var more: bool = S.queue.size() and S.queue[0].type == "debate"
			p.actions([p.button("Next question" if more else "Leave the studio", func():
				if more: _debate_round(p)
				else: _done(p))])
			p.top())
	p.top()

func _election_sheet() -> void:
	var r: Dictionary = S.result
	var p = _paper(860, false)
	p.tv_strap("CBC · Election night", "The results")
	var you: Dictionary = G.player_party(S)
	var first = G.party_of(S, r.ranking[0])
	p.heading("%s wins the election" % first.name if not r.playerWon else ("%s wins a majority" % you.name if r.majority else "%s becomes the largest party" % you.name), 38)
	_bars_into(p, r.votes, null)
	p.add(Look.caps("Seats (%d to win)" % int(G.C.seats / 2 + 1), 11, Look.MUTED, 2))
	var seatbar = SeatBar.new(r.ranking.map(func(id): return [Color(G.party_of(S, id).color), r.seats.national[id]]), int(G.C.seats))
	seatbar.custom_minimum_size.y = 30
	p.add(seatbar)
	for id in r.ranking:
		p.add(Look.label("%s — %d seats" % [G.party_of(S, id).name, r.seats.national[id]], "type", 15, Look.INK))
	p.actions([
		p.button("Read what the papers say", func(): _profile_sheet(), false),
		p.button("Found a new party", func():
			p.close()
			_founding_sheet(), false),
		p.button("Close", func():
			if S.queue.size() and S.queue[0].type == "election": G.dismiss_front(S)
			_done(p)),
	])

# ---------- A district: who would win it, and the leader's visit ----------
func _district_sheet(id: String) -> void:
	var d = G.district_by_id(id)
	var r = Game.by_id(G.REGIONS, d.region)
	var x: Dictionary = S.get("projection", {}).get(id, {})
	var p = _paper(640, false)
	p.kicker("District · %s · %d seat%s" % [r.name, d.seats, "" if d.seats == 1 else "s"])
	p.heading(d.name, 36)
	if d.cities.size(): p.small("Includes " + ", ".join(d.cities) + ".")
	if x.size():
		var ids: Array = Game.ssort(x.votes.keys(), func(a, b): return x.votes[b] - x.votes[a])
		var tot: float = 0.0
		for k in x.votes: tot += x.votes[k]
		var shares = {}
		for k in ids: shares[k] = x.votes[k] / tot if tot else 0.0
		var w: int = G.winner_seats(int(d.seats))
		p.add(Look.caps("If the election were today · " + ("the winner takes all %d seats" % d.seats if w == int(d.seats) else "the winner takes %d of %d seats" % [w, d.seats]), 11, Look.MUTED, 2))
		var shown: Array = ids.slice(0, 3)
		if not shown.has("player"): shown.append("player")
		for k in shown:
			var name: String = "You" if k == "player" else G.party_of(S, k).short
			p.add(Look.label("%s%s  %d%%" % ["★ " if k == x.winner else "", name, Game.jround(shares[k] * 100)], "type", 17, Color(G.party_of(S, k).color).darkened(0.25) if k != "player" else Look.RED))
		if x.winner == "player":
			p.small("Yours today, by %d points. Votes beyond what wins it are wasted: if it's safe, campaign elsewhere." % maxi(1, Game.jround(float(x.margin) * 100)), Look.INK)
		else:
			p.small("You'd need about %d more points to take it." % maxi(1, Game.jround((float(x.share) - float(x.you)) * 100)), Look.INK)
		if w < int(d.seats): p.small("The other %d seat%s go to parties by their vote across the whole country, so every vote here still counts toward them." % [int(d.seats) - w, "" if int(d.seats) - w == 1 else "s"])
	var st: Dictionary = S.districts.get(id, {})
	if int(st.get("visits", 0)) > 0: p.small("%s has toured here %d time%s." % [G.player_party(S).leader, int(st.visits), "" if int(st.visits) == 1 else "s"])
	var block: String = G.visit_block(S)
	var go = p.button("Tour %s this month" % d.name, func():
		var res: Dictionary = G.act_visit(S, id)
		if not res.ok:
			_toast(res.text); return
		_tour_result(p, res)
		_after_change(), true, block != "")
	go.tooltip_text = block if block != "" else "Free, once a month. People here hear of you and warm to you, and the rest of %s a little. Going back keeps helping, but less each time." % r.name
	p.actions([p.button("Region's voters", func():
		p.close()
		_files.S = S; _files.open_region(d.region); _sync_menu(), false), p.button("Close", func(): p.close(), false), go])

## The trip, as the local paper ran it: a photo, a short story, and what it did to the vote.
func _tour_result(p: Paper, res: Dictionary) -> void:
	p.clear()
	p._paper.custom_minimum_size.x = 860   # the district sheet is narrow; the story gets a full page
	var r = Game.by_id(G.REGIONS, res.region)
	p.masthead(G.date_label(S.week), "The %s Courier" % r.name, "On the road")
	p.kicker("%s in %s" % [G.player_party(S).leader, res.place])
	var heads = {"great": "%s packs the halls in %s", "good": "%s makes the rounds in %s", "flat": "A quiet visit to %s for %s"}
	var head: String = heads.get(res.kind, "%s in %s")
	p.heading(head % ([G.player_party(S).leader, res.place] if res.kind != "flat" else [res.place, G.player_party(S).leader]), 34)
	var photo = TourPhoto.new()
	photo.kind = res.kind
	photo.party_color = Color(G.player_party(S).color)
	photo.custom_minimum_size = Vector2(0, 260)
	p.add(photo)
	if res.caption != "": p.small(res.caption)
	if res.story != "": p.text(res.story, 18, "news")
	var b: int = Game.jround(float(res.before) * 100)
	var a: int = Game.jround(float(res.after) * 100)
	p.add(Look.label("Your vote in %s: %d%% → %d%%" % [res.place, b, a], "news_bold", 24, Look.RED if a > b else Look.INK))
	if res.why.size():
		var w: String = ", ".join(res.why)
		p.small(w.substr(0, 1).to_upper() + w.substr(1) + ".", Look.INK)
	p.small("The rest of %s heard about it too, a little." % r.name)
	p.actions([p.button("Back to work", func(): _done(p))])
	p.top()

## A placeholder photo until the real pictures exist (godot/assets/tours/<kind>.png):
## a hall, a stage, and a crowd as big as the trip went well.
class TourPhoto extends Control:
	var kind := "good"
	var party_color := Color("b03a2e")
	var _tex: Texture2D = null
	func _ready() -> void:
		var path = "res://assets/tours/%s.png" % kind
		if ResourceLoader.exists(path): _tex = load(path)
	func _draw() -> void:
		var r = Rect2(Vector2.ZERO, size)
		if _tex:
			draw_texture_rect(_tex, r, false)
			return
		draw_rect(r, Color("2b2621"))
		var inner = r.grow(-8)
		draw_rect(inner, Color("6f675c"))
		# back wall, banner and stage
		draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.55)), Color("8a8174"))
		var bw = inner.size.x * 0.42
		draw_rect(Rect2(inner.position + Vector2((inner.size.x - bw) / 2, inner.size.y * 0.1), Vector2(bw, inner.size.y * 0.16)), Look.mix(Color("8a8174"), party_color, 0.65))
		draw_rect(Rect2(inner.position + Vector2(inner.size.x * 0.3, inner.size.y * 0.45), Vector2(inner.size.x * 0.4, inner.size.y * 0.08)), Color("4a443c"))
		draw_circle(inner.position + Vector2(inner.size.x * 0.5, inner.size.y * 0.33), inner.size.y * 0.05, Color("3a352f"))
		draw_rect(Rect2(inner.position + Vector2(inner.size.x * 0.5 - inner.size.y * 0.04, inner.size.y * 0.37), Vector2(inner.size.y * 0.08, inner.size.y * 0.09)), Color("3a352f"))
		# the crowd: heads in rows, more of them the better it went
		var row_n = {"great": 5, "good": 3, "flat": 1}
		var fill_n = {"great": 1.0, "good": 0.75, "flat": 0.3}
		var rows: int = int(row_n.get(kind, 3))
		var fill: float = float(fill_n.get(kind, 0.7))
		var rng = RandomNumberGenerator.new()
		rng.seed = 7
		for row in rows:
			var y = inner.position.y + inner.size.y * (0.98 - row * 0.085)
			var rad = inner.size.y * (0.075 - row * 0.008)
			var x = inner.position.x + rad
			while x < inner.end.x - rad:
				if rng.randf() < fill: draw_circle(Vector2(x + rng.randf() * 4, y), rad, Color(0.16 + rng.randf() * 0.08, 0.15, 0.14))
				x += rad * 1.7
		# old newsprint: soften it
		draw_rect(inner, Color(0.85, 0.8, 0.7, 0.18))

# ---------- Founding the party (a new game) ----------
var _found = {}
var _founding := false   # the founding sheet is up; nothing else should talk yet

func _founding_sheet() -> void:
	_founding = true
	var t0: Dictionary = G.PARTY_TEMPLATES[0]
	_found = {"template": t0.id, "partyName": t0.name, "leaderName": t0.leader, "manifesto": t0.manifesto.duplicate(),
		"color": t0.color, "emblem": t0.emblem, "portrait": int(t0.portrait), "home": ""}
	var p = _paper(1000, false)
	_founding_build(p)

func _founding_pick(t: Dictionary) -> void:
	_found.template = t.id
	if t.id != "custom":
		_found.partyName = t.name; _found.leaderName = t.leader
		_found.manifesto = t.manifesto.duplicate()
		_found.color = t.color; _found.emblem = t.emblem; _found.portrait = int(t.portrait)

func _founding_build(p: Paper) -> void:
	var keep_scroll: int = p._scroll.scroll_vertical
	p.clear()
	p.kicker("A new party")
	p.heading("Founding night", 42)
	p.text("Until last month you were a mayor, and a member of somebody else's party. You walked out. Tonight, in a back room above a print shop, you start your own: four years to become the largest party in the National Assembly.", 17)
	# 1. who you are
	p.step("One", "Who are you?")
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for t in G.PARTY_TEMPLATES:
		var on: bool = _found.template == t.id
		var c = p.card("index", func(box):
			box.add_child(Look.label(("✓ " if on else "") + (t.name if t.name != "" else "Your own party"), "display", 20, Look.RED if on else Look.INK))
			box.add_child(Look.caps(t.tagline, 11, Look.MUTED, 1))
			if t.get("pitch", "") != "": box.add_child(Look.label(t.pitch, "body", 13, Look.INK, true)),
			func():
				_founding_pick(t)
				_founding_build(p))
		c.custom_minimum_size.x = 290
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.v.remove_child(c)
		grid.add_child(c)
	p.add(grid)
	var names = HBoxContainer.new()
	names.add_theme_constant_override("separation", 16)
	for f in [["Party", "partyName"], ["Leader", "leaderName"]]:
		var col = VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(Look.caps(f[0], 11, Look.MUTED, 2))
		var le = LineEdit.new()
		le.text = _found[f[1]]
		le.max_length = 32
		le.add_theme_font_override("font", Look.font("type"))
		le.add_theme_font_size_override("font_size", Look.fs(18))
		le.add_theme_color_override("font_color", Look.INK)
		le.add_theme_stylebox_override("normal", Look.box(Color(1, 1, 1, 0.5), 0, Look.INK, 1, 0, 8))
		le.add_theme_stylebox_override("focus", Look.box(Color(1, 1, 1, 0.8), 0, Look.RED, 1, 0, 8))
		var key: String = f[1]
		le.text_changed.connect(func(tx): _found[key] = tx)
		col.add_child(le)
		names.add_child(col)
	p.add(names)
	# 2. the manifesto
	p.step("Two", "What do you stand for?")
	p.small("One stance on each issue. Later, saying things one stance away from it costs nothing; further than that, voters start to notice.")
	var point = {}
	for ax in G.AXES:
		var cur: int = int(_found.manifesto.get(ax.id, 2))
		point[ax.id] = G.C.stanceCenters[cur]
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var lab = Look.label(ax.issue, "body_bold", 14, Look.INK)
		lab.custom_minimum_size.x = 210
		row.add_child(lab)
		for i in ax.stances.size():
			var axid: String = ax.id
			var b = p.button(ax.stances[i], func():
				_found.manifesto[axid] = i
				_founding_build(p), i == cur)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.add_theme_font_size_override("font_size", Look.fs(12))
			row.add_child(b)
		p.add(row)
	p.add(Look.label("Voters will see you as: %s" % G.view_label(point), "body_bold", 15, Look.RED, true))
	# 3. home
	p.step("Three", "Where were you mayor?")
	p.small("Your old city is your head start: people across its region know you and like you, and the party opens with an office there. Alinni's cities are not open to you: Alinnians elect their own minority leaders.")
	for r in G.REGIONS:
		var cities: Array = G.home_cities().filter(func(c): return c.area == r.id)
		if cities.is_empty(): continue
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var lab = Look.label(r.name, "body_bold", 14, Look.INK)
		lab.custom_minimum_size.x = 210
		row.add_child(lab)
		for c in cities:
			var nm: String = c.name
			row.add_child(p.button(nm + (" ★" if nm == G.MAP.capital else ""), func():
				_found.home = nm
				_founding_build(p), _found.home == nm))
		p.add(row)
	# found it
	var can_go: bool = _found.home != ""
	var go = p.button("Found the party" if can_go else "Choose your city first", func():
		var opts: Dictionary = _found.duplicate(true)
		opts.erase("template")
		if str(opts.partyName).strip_edges() == "": opts.partyName = "New Dawn Movement"
		if str(opts.leaderName).strip_edges() == "": opts.leaderName = "Dorin Vask"
		S = G.new_game(opts)
		_founding = false
		_snap = null   # so Carlos greets the new party
		_done(p), true, not can_go)
	p.actions([go])
	await get_tree().process_frame
	p._scroll.scroll_vertical = keep_scroll

class SeatBar extends Control:
	var parts: Array
	var total: int
	func _init(p: Array, t: int) -> void:
		parts = p; total = t
	func _draw() -> void:
		var x = 0.0
		for part in parts:
			var w: float = size.x * part[1] / total
			draw_rect(Rect2(x, 0, w, size.y), part[0])
			x += w
		draw_rect(Rect2(Vector2.ZERO, size), Look.INK, false, 2.0)
		draw_line(Vector2(size.x / 2, -4), Vector2(size.x / 2, size.y + 4), Look.INK, 2.0)

func _profile_sheet() -> void:
	var pr: Dictionary = G.build_profile(S)
	var you: Dictionary = G.player_party(S)
	var p = _paper(860, false)
	p.masthead(G.date_label(S.week, false), "The Cranebo Herald", "Profile")
	p.heading(pr.headline, 40)
	p.text("%s: %s" % [pr.archetype.title, pr.archetype.line], 19, "news_italic")
	if pr.signature: p.quote(pr.signature.text, "%s, %s" % [you.leader, G.date_label(pr.signature.week, false)])
	if pr.contradictions.size():
		p.rule(1)
		p.add(Look.caps("Said and unsaid", 12, Look.RED, 2))
		for c in pr.contradictions:
			p.add(Look.caps("On " + Game.by_id(G.AXES, c.axis).issue.to_lower(), 11, Look.MUTED, 2))
			for q in [c.first, c.second]:
				var told: String = ("“%s”" % q.text) if q.get("spoken", true) else ("Chose to " + q.text.substr(0, 1).to_lower() + q.text.substr(1))
				p.add(Look.label("%s — %s" % [G.date_label(q.week, false), told], "news", 16, Look.INK, true))
	if pr.betrayed.size():
		p.rule(1)
		p.add(Look.caps("Promises broken", 12, Look.RED, 2))
		for b in pr.betrayed: p.text("To %s: first “%s”, then “%s”." % [b.group, b.promised, b.now], 15)
	if pr.blamed.size(): p.text("Blamed along the way: %s." % ", ".join(pr.blamed), 15)
	var dirty: Array = pr.money.filter(func(m): return m.dirty)
	if dirty.size(): p.text("Took money from %s." % ", ".join(dirty.map(func(m): return m.source)), 15)
	if pr.crisis: p.text("The crisis: %s.%s" % [pr.crisis.name, " Its campaign helped bring it about." if pr.crisis.blamed else ""], 15)
	p.small("Speaking style: %s · %d statements · %d viral moments · %d gaffes" % [pr.style, pr.statements, pr.memes, pr.gaffes], Look.INK)
	p.actions([p.button("Close", func(): p.close())])

func _toast(text: String) -> void:
	var t = Look.label(text, "type", 15, Look.INK, true)
	t.custom_minimum_size.x = 520
	var p = PanelContainer.new()
	var sb = Look.box(Look.PAPER, 0, Look.RED, 0, 10, 12)
	sb.border_width_left = 5; sb.border_color = Look.RED
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
	return d

# ---------- Screenshots for checking the look (godot ... -- --shot=path --weeks=N) ----------
func _shot(args: Dictionary) -> void:
	S = G.new_game({"seed": 42, "partyName": "People's Awakening", "leaderName": "Dorin Vask", "manifesto": {"nation": 2, "economy": 1, "society": 2, "foreign": 3, "welfare": 1, "system": 1, "order": 2}})
	var weeks = int(args.get("weeks", "20"))
	var guard = 0
	while S.week < weeks and guard < 500:
		guard += 1
		if S.queue.is_empty():
			pass
			G.advance_week(S); continue
		var f: Dictionary = S.queue[0]
		match f.type:
			"event": G.resolve_event(S, 0, 0 if G.event_of(f).choices[0].get("lines", []).size() else -1)
			"budget": G.resolve_budget(S, {"tour": S.money * 0.5, "road": S.money * 0.3}, [])
			"debate": G.answer_debate(S, 0)
			_: G.dismiss_front(S)
	# stop on the next decision so the board shows one (or on a given kind)
	G.advance_to_decision(S)
	var until: String = args.get("until", "")
	var g2 = 0
	while until != "" and g2 < 400 and not (S.queue.size() and S.queue[0].type == until):
		g2 += 1
		if S.queue.is_empty():
			G.advance_week(S); continue
		var f2: Dictionary = S.queue[0]
		match f2.type:
			"event": G.resolve_event(S, 0, -1)
			"budget": G.resolve_budget(S, {"tour": S.money * 0.5}, [])
			"debate": G.answer_debate(S, 0)
			_: G.dismiss_front(S)
	render()
	for i in 20: await get_tree().process_frame
	if args.has("hover"): _map.hover = args.hover; _map._mouse = _map.to_screen(Vector2(1300, 980)); _map.queue_redraw()
	if args.has("flagship"):
		S.queue.push_front({"type": "event", "event": G.flagship_event(S)})
	if args.has("open"): _open_front()
	if args.has("found"):
		_founding_sheet()
		if args.has("home"): _found.home = args.home; _founding_build(_sheet_layer.get_child(-1))
		if args.has("scroll"):
			for i in 3: await get_tree().process_frame
			(_sheet_layer.get_child(-1) as Paper)._scroll.scroll_vertical = int(args.scroll)
	await get_tree().process_frame
	if args.has("step2"):
		var ev: Dictionary = G.event_of(S.queue[0])
		var ci = -1
		for i in ev.choices.size():
			if ev.choices[i].get("lines", []).size(): ci = i
		if ci >= 0: _event_step2(_sheet_layer.get_child(-1), ev, ci)
	if args.has("result"):
		var ev2: Dictionary = G.event_of(S.queue[0])
		_event_result(_sheet_layer.get_child(-1), G.resolve_event(S, 0, 0 if ev2.choices[0].get("lines", []).size() else -1))
	if args.has("file"):
		if args.has("clear"): S.queue.clear()
		_show_file(args.file)
		if args.has("scroll"):
			await get_tree().process_frame
			await get_tree().process_frame
			_files._scroll.scroll_vertical = int(args.scroll)
	if args.has("region"): _files.S = S; _files.open_region(args.region)
	if args.has("district"): _district_sheet(args.district)
	if args.has("country"): _country_sheet(args.country)
	if args.has("margaret"):
		_advisor.margaret(args.margaret)
	if args.has("carlos"):
		_advisor.say(args.carlos, true)
	if args.has("build"):
		for name in ["Cranebo", "Tarropolis", "Bayernal"]:
			S.actionsLeft = 3; S.money = 9.0
			G.act_community(S, name)
			if name == "Cranebo": G.act_community(S, name)
		render()
	if args.has("speak"):
		S.queue.clear()
		var ds: Array = Game.ssort(S.debates.duplicate(), func(a, b): return b.heat - a.heat)
		_speak_sheet(ds[int(args.speak)].id, "L")
	if args.has("raise"):
		S.queue.clear()
		_raise_sheet(G.raise_options(S)[int(args.raise)])
	if args.has("then"):
		# move on to the next poll and catch the motion part-way
		var target = S.polls.size() + 1
		var g3 = 0
		while S.polls.size() < target and g3 < 200:
			g3 += 1
			if S.queue.is_empty(): G.advance_week(S); continue
			match S.queue[0].type:
				"event": G.resolve_event(S, 0, -1)
				"budget": G.resolve_budget(S, {"tour": S.money * 0.5}, [])
				"debate": G.answer_debate(S, 0)
				_: G.dismiss_front(S)
		render()
		await get_tree().create_timer(float(args.then)).timeout
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
