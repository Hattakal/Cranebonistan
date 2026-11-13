## cheats.gd — the designer's cheat panel. Open and close it with ` (backtick) or F12.
## Moves time forward (decisions on the way are settled with the first answer and
## last quarter's budget), and changes the main numbers. Not for players.
extends PanelContainer

var main          # the headquarters (main.gd): its S, G and _after_change()
var _body: VBoxContainer
var _events: OptionButton
var _status: Label

func _ready() -> void:
	visible = false
	z_index = 40
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sb = Look.box(Color(0.08, 0.06, 0.04, 0.96), 4, Look.BRASS, 2, 0, 12)
	add_theme_stylebox_override("panel", sb)
	# pinned to the right edge, under the top bar
	anchor_left = 1.0; anchor_right = 1.0; anchor_top = 0.0; anchor_bottom = 1.0
	offset_left = -480; offset_right = -12; offset_top = 72; offset_bottom = -12
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_body = VBoxContainer.new()
	_body.custom_minimum_size.x = 400
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 6)
	scroll.add_child(_body)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and (e.keycode == KEY_QUOTELEFT or e.keycode == KEY_F12):
		visible = not visible
		if visible: _build()
		get_viewport().set_input_as_handled()

# ---------- Building the panel ----------
func _head(t: String) -> void:
	var l = Look.caps(t, 11, Look.BRASS, 2)
	_body.add_child(l)

func _row(buttons: Array) -> void:
	var h = HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 4)
	h.add_theme_constant_override("v_separation", 4)
	for b in buttons:
		var btn = Button.new()
		btn.text = b[0]
		btn.add_theme_font_size_override("font_size", Look.fs(12))
		var cb: Callable = b[1]
		btn.pressed.connect(func(): cb.call(); _done(b[0]))
		h.add_child(btn)
	_body.add_child(h)

func _build() -> void:
	for c in _body.get_children(): c.queue_free()
	var t = Look.caps("Cheats · ` or F12 to close", 13, Look.HEAD, 2, "display_bold")
	_body.add_child(t)
	_status = Look.label("", "body", 12, Look.CREAM_DIM, true)
	_status.custom_minimum_size.x = 380
	_body.add_child(_status)
	_head("Time (decisions on the way get the first answer)")
	_row([["Next month", func(): _play_months(1)], ["+3 months", func(): _play_months(3)], ["+6 months", func(): _play_months(6)],
		["+1 year", func(): _play_months(12)]])
	_row([["To the last month", func(): _play_to(main.G.ELECTION_WEEK - main.G.WEEKS_PER_MONTH)],
		["To the election", func(): _play_to(main.G.ELECTION_WEEK)]])
	_row([["Settle this decision", func(): _settle_one()], ["Clear all decisions", func(): main.S.queue.clear()]])
	_head("Your party")
	_row([["Money +5", func(): main.S.money += 5.0], ["+20", func(): main.S.money += 20.0], ["Money 0", func(): main.S.money = 0.0]])
	_row([["Actions back to 3", func(): main.S.actionsLeft = int(main.G.C.actionsPerMonth)], ["Trip again", func(): main.S.lastVisit = -99]])
	_row([["Everyone likes you more", func(): _goodwill(0.3)], ["…less", func(): _goodwill(-0.3)], ["Better known +10%", func(): _aware(0.1)]])
	_row([["Charisma +10", func(): _charisma(10)], ["Charisma −10", func(): _charisma(-10)]])
	_head("The country")
	_row([["Trust +10", func(): main.S.trust = clampf(main.S.trust + 10, 0, 100)], ["Trust −10", func(): main.S.trust = clampf(main.S.trust - 10, 0, 100)]])
	for k in ["jobs", "prices", "migration", "border", "unrest"]:
		_row([[k.capitalize() + " +10", func(): _world(k, 10)], [k.capitalize() + " −10", func(): _world(k, -10)]])
	_row([["Start the crisis now", func(): main.G.start_crisis(main.S)], ["Budget now", func(): main.S.queue.append({"type": "budget", "offers": main.G.draw_offers(main.S)})]])
	_row([["Foreign money on offer", func(): _foreign_offer()], ["A random event", func(): _random_event()]])
	_head("Rivals")
	for p in main.G.rivals(main.S):
		var pid: String = p.id
		_row([[p.short + " stability +15", func(): _stab(pid, 15)], ["−15", func(): _stab(pid, -15)], ["money +10", func(): _rival_money(pid, 10)]])
	_head("Queue an event")
	_events = OptionButton.new()
	_events.add_theme_font_size_override("font_size", Look.fs(12))
	_events.fit_to_longest_item = false
	_events.clip_text = true
	_events.custom_minimum_size.x = 380
	_events.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var evs: Array = main.G.EVENTS.duplicate()
	evs = Game.ssort(evs, func(a, b): return -1 if str(a.title) < str(b.title) else (1 if str(a.title) > str(b.title) else 0))
	for e in evs:
		_events.add_item("%s  (%s)" % [e.title, e.id])
		_events.set_item_metadata(_events.item_count - 1, e.id)
	_body.add_child(_events)
	_row([["Queue it", func():
		if _events.selected >= 0: main.G.queue_event(main.S, _events.get_item_metadata(_events.selected))]])
	_show_status()

func _done(what: String) -> void:
	main._after_change()
	_show_status(what)

func _show_status(what := "") -> void:
	if _status == null: return
	var S: Dictionary = main.S
	var sup = S.lastSupport.player if S.lastSupport else 0.0
	_status.text = "%s%s · ₱%sM · %d actions · polling %s%% · trust %d%s" % [("Done: %s. " % what) if what != "" else "", main.G.date_label(S.week),
		Game.fmt1(S.money), S.actionsLeft, Game.fmt1(sup * 100), int(S.trust), (" · %d decision(s) waiting" % S.queue.size()) if S.queue.size() else ""]

# ---------- Doing things ----------
func _close_sheets() -> void:
	for c in main._sheet_layer.get_children(): c.queue_free()
	main._sheet_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

## Settle the decision at the front of the queue the quick way.
func _settle_one() -> bool:
	var G = main.G
	var S: Dictionary = main.S
	if S.queue.is_empty(): return true
	var f: Dictionary = S.queue[0]
	match f.type:
		"event":
			var ev: Dictionary = G.event_of(f)
			G.resolve_event(S, 0, 0 if ev.choices[0].get("lines", []).size() else -1)
		"budget":
			var last = S.lastBudget if S.lastBudget else {}
			var alloc = {}
			var left: float = S.money
			for k in G.BUDGET_KEYS:
				alloc[k] = minf(float(last.get(k, 0)), maxf(0, left))
				left -= alloc[k]
			G.resolve_budget(S, alloc, [])
		"debate": G.answer_debate(S, 0)
		"election": return false
		_: G.dismiss_front(S)
	return true

func _play_to(week: int) -> void:
	_close_sheets()
	var G = main.G
	var S: Dictionary = main.S
	var guard = 0
	while S.week < week and S.result == null and guard < 5000:
		guard += 1
		if S.queue.size():
			if not _settle_one(): break
			continue
		G.advance_week(S)
	# land on a clean desk, unless the election itself is waiting
	while S.queue.size() and S.queue[0].type != "election" and guard < 6000:
		guard += 1
		if not _settle_one(): break

func _play_months(n: int) -> void:
	var G = main.G
	var start: int = int(main.S.week / G.WEEKS_PER_MONTH) * G.WEEKS_PER_MONTH
	_play_to(mini(G.ELECTION_WEEK, start + n * G.WEEKS_PER_MONTH))

func _goodwill(d: float) -> void:
	for pop in main.S.pops: pop.goodwill.player = clampf(pop.goodwill.player + d, -2, 2)
	main.S.lastSupport = main.G.summarize(main.S, main.S.pops).support
	main.G.take_poll(main.S, "Cheat poll", true)

func _aware(d: float) -> void:
	for pop in main.S.pops: pop.aware.player = clampf(pop.aware.player + d * (1 - pop.aware.player), 0, 1)
	main.G.take_poll(main.S, "Cheat poll", true)

func _charisma(d: float) -> void:
	var p: Dictionary = main.G.player_party(main.S)
	p.charisma = clampf(p.charisma + d, 10, 100)

func _world(k: String, d: float) -> void:
	main.S.world[k] = clampf(float(main.S.world[k]) + d, 0, 100)

func _stab(pid: String, d: float) -> void:
	var p = main.G.party_of(main.S, pid)
	if p: p.stability = clampf(p.stability + d, 0, 100)

func _rival_money(pid: String, d: float) -> void:
	var p = main.G.party_of(main.S, pid)
	if p: p.money = float(p.get("money", 0)) + d

func _foreign_offer() -> void:
	var G = main.G
	var ids = []
	for f in G.FOREIGN_MONEY: ids.append(f.offer)
	if ids.is_empty(): return
	ids.shuffle()
	main.S.queue.append({"type": "budget", "offers": ids.slice(0, 2)})

func _random_event() -> void:
	var id = main.G.draw_event(main.S)
	if id != null: main.G.queue_event(main.S, id)
