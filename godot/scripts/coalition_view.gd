## coalition_view.gd — the coalition talks after the election, played back step by step.
##
## The rules decide everything first (rules/coalition.gd writes s.result.coalition.log);
## this screen only shows it: every majority that could govern, those holding enemies
## crossed out, then each party trying to form a government, approaching the others
## one by one at the table. Click to speed it up; "Skip to the result" jumps to the end.
## Works for any number of parties.
class_name CoalitionView
extends Control

signal finished

var G            # the rules (autoload "Game")
var S: Dictionary
var co: Dictionary
var _stage: Control
var _caption: Label
var _title: Label
var _sub: Label
var _bar: CoalitionBar
var _skip_btn: Button
var _speed := 1.0
var _skipped := false
var _done := false

const CARD_W := 250
const BIG_W := 300

func setup(game, state: Dictionary) -> void:
	G = game
	S = state
	co = S.result.coalition

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg = ColorRect.new()
	bg.color = Color(Look.T900, 0.97)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_title = Look.label("Forming a government", "display_bold", 34, Look.HEAD)
	_title.position = Vector2(60, 30)
	add_child(_title)
	_sub = Look.label("", "body_italic", 16, Look.CREAM_DIM)
	_sub.position = Vector2(62, 78)
	add_child(_sub)
	_bar = CoalitionBar.new()
	_bar.total = int(G.C.seats)
	_bar.need = int(co.log[0].need) if co.log.size() else int(G.C.seats / 2) + 1
	_bar.position = Vector2(60, 124)
	_bar.size = Vector2(_w() - 120, 26)
	add_child(_bar)
	_caption = Look.label("", "body", 18, Look.CREAM, true)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.custom_minimum_size = Vector2(_w() - 240, 0)
	_caption.position = Vector2(120, _h() - 150)
	add_child(_caption)
	_skip_btn = Button.new()
	_skip_btn.text = "Skip to the result"
	_skip_btn.add_theme_font_size_override("font_size", Look.fs(14))
	_skip_btn.position = Vector2(_w() - 240, 30)
	_skip_btn.pressed.connect(_skip)
	add_child(_skip_btn)
	var hint = Look.label("Click anywhere to speed it up", "body_italic", 13, Look.CREAM_DIM)
	hint.name = "Hint"
	hint.position = Vector2(_w() - 240, 70)
	add_child(hint)
	_play()

func _w() -> float: return get_viewport_rect().size.x
func _h() -> float: return get_viewport_rect().size.y

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and not _done: _speed = 3.0

func _skip() -> void:
	if _done: return
	_skipped = true
	_show_end()

## Waits, unless the talks were skipped; false means stop playing.
func _pause(t: float) -> bool:
	if _skipped: return false
	await get_tree().create_timer(t / _speed).timeout
	return not _skipped

func _tween() -> Tween:
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.set_speed_scale(_speed)
	return tw

func _clear() -> void:
	for c in _stage.get_children(): c.queue_free()
	_caption.text = ""

# ---------- Party cards ----------
func _party(id: String) -> Dictionary:
	return G.party_of(S, id)

func _name(id: String) -> String:
	var p = _party(id)
	return "You" if p.isPlayer else String(p.get("short", id))

## The party's two strongest leanings ("Nationalist · Traditional").
func _leanings(p: Dictionary) -> String:
	var axes: Array = G.AXES.map(func(ax): return {"id": ax.id, "v": float(p.perceived[ax.id])})
	axes = Game.ssort(axes, func(a, b): return absf(b.v) - absf(a.v))
	var out = []
	for a in axes.slice(0, 2):
		if absf(a.v) < 15: continue
		out.append(G.stance_name(a.id, G.stance_of(a.v)))
	return " · ".join(out) if out.size() else "Centrist"

func _card(id: String, big := false) -> PanelContainer:
	var p: Dictionary = _party(id)
	var col = Color(p.color)
	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", Look.box(Look.PAPER, 4, col, 4 if big else 3, 8, 14))
	card.custom_minimum_size.x = BIG_W if big else CARD_W
	card.size.x = card.custom_minimum_size.x
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.pivot_offset = Vector2(card.size.x / 2, 60)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)
	var top = HBoxContainer.new()
	var sh = Look.caps(_name(id), 13 if big else 12, col.darkened(0.2), 2, "display_bold")
	sh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sh)
	var seats: int = int(co.log[0].seats.get(id, 0)) if co.log.size() else 0
	top.add_child(Look.label("%d seats" % seats, "news_bold", 17 if big else 15, Look.INK))
	v.add_child(top)
	var nm = Look.label(String(p.get("name", "")), "news_bold", 20 if big else 17, Look.INK, true)
	nm.custom_minimum_size.x = card.size.x - 28
	v.add_child(nm)
	v.add_child(Look.label(_leanings(p), "body_italic", 13, Look.MUTED))
	var badge = Look.caps("", 11, Look.MUTED, 2, "display_bold")
	badge.name = "Badge"
	v.add_child(badge)
	_stage.add_child(card)
	return card

func _badge(card: Control, text: String, col: Color) -> void:
	var b: Label = card.find_child("Badge", true, false)
	if b:
		b.text = text
		b.add_theme_color_override("font_color", col)

func _stamp(card: Control, text: String, col: Color) -> Label:
	var l = Look.label(text, "display_bold", 26, col)
	l.rotation = -0.12
	l.position = card.position + Vector2(card.size.x - 150, -16)
	l.modulate.a = 0.0
	_stage.add_child(l)
	var tw = _tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.25)
	return l

func _cross(target: Control, at: Vector2, sz: Vector2) -> void:
	var x = XMark.new()
	x.position = at
	x.size = sz
	_stage.add_child(x)
	var tw = create_tween()
	tw.set_speed_scale(_speed)
	tw.tween_property(x, "progress", 1.0, 0.45)
	if target: target.modulate = Color(1, 1, 1, 0.8)

func _leave_up(nodes: Array) -> void:
	var tw = _tween()
	for n in nodes:
		if is_instance_valid(n):
			tw.tween_property(n, "position:y", n.position.y - 160, 0.6)
			tw.tween_property(n, "modulate:a", 0.0, 0.6)
	await tw.finished
	for n in nodes:
		if is_instance_valid(n): n.queue_free()

# ---------- Playing the log ----------
func _play() -> void:
	await get_tree().process_frame
	var log: Array = co.log
	var i = 0
	while i < log.size():
		if _skipped: return
		var st: Dictionary = log[i]
		match st.t:
			"majority":
				_sub.text = "%s has a majority of its own." % String(_party(st.party).name)
				if not await _pause(1.0): return
			"combos":
				var crosses = []
				var j = i + 1
				while j < log.size() and log[j].t == "cross":
					crosses.append(log[j]); j += 1
				if not await _show_combos(st, crosses): return
				i = j
				continue
			"formateur":
				var j = i + 1
				var steps = []
				while j < log.size() and log[j].t == "approach":
					steps.append(log[j]); j += 1
				var fail = log[j] if j < log.size() and log[j].t == "fail" else null
				if not await _show_talks(st.party, steps, fail): return
				i = j + (1 if fail else 0)
				continue
			"shutout":
				if not await _show_shutout(st): return
			"government", "deadlock":
				break
		i += 1
	if not _skipped: _show_end()

func _show_combos(st: Dictionary, crosses: Array) -> bool:
	_clear()
	_bar.parts = []
	_bar.queue_redraw()
	var list: Array = st.list
	_sub.text = ("Every majority that could govern: %d." % list.size()) if st.round == 1 else "Talks start again without them: %d possible majorities." % list.size()
	var cols: int = clampi(int((_w() - 120) / 290), 1, 6)
	var chips = []
	var shown: int = mini(list.size(), cols * 5)
	var left0: float = (_w() - cols * 290 + 30) / 2
	for k in shown:
		var chip = ComboChip.new()
		chip.parts = list[k].map(func(id): return [Color(_party(id).color), int(co.log[0].seats[id]), _name(id)])
		chip.total = int(G.C.seats)
		chip.need = _bar.need
		chip.size = Vector2(260, 58)
		chip.position = Vector2(left0 + (k % cols) * 290, 180 + int(k / cols) * 86)
		chip.modulate.a = 0.0
		_stage.add_child(chip)
		chips.append(chip)
	var tw = _tween()
	for k in chips.size(): tw.tween_property(chips[k], "modulate:a", 1.0, 0.3).set_delay(0.04 * k)
	if not await _pause(1.4): return false
	if crosses.is_empty():
		_caption.text = "No enemies among them."
		if not await _pause(1.2): return false
	# the same pair of enemies crosses out all its majorities at once
	var by_pair = {}
	var order = []
	for c in crosses:
		var key = "+".join(c.pair)
		if not by_pair.has(key):
			by_pair[key] = []; order.append(key)
		by_pair[key].append(c)
	for key in order:
		var gone = []
		for c in by_pair[key]:
			if int(c.i) >= chips.size(): continue
			var chip: Control = chips[int(c.i)]
			if not is_instance_valid(chip) or chip.is_queued_for_deletion(): continue
			_cross(chip, chip.position + Vector2(-6, -6), chip.size + Vector2(12, 12))
			gone.append(chip)
		_caption.text = by_pair[key][0].why
		if not await _pause(1.6): return false
		var marks = _stage.get_children().filter(func(n): return n is XMark)
		_leave_up(gone + marks)
		if not await _pause(0.7): return false
	var alive: int = list.size() - crosses.size()
	_caption.text = "%d possible government%s left." % [alive, "" if alive == 1 else "s"] if alive > 0 else "No majority without enemies in it."
	return await _pause(1.6)

func _show_talks(f: String, steps: Array, fail) -> bool:
	_clear()
	_sub.text = _sub_for(f)
	var lead = _card(f, true)
	lead.position = Vector2(80, 200)
	lead.modulate.a = 0.0
	var head = Look.caps("Forming the government", 12, Look.BRASS, 2)
	head.position = Vector2(82, 172)
	_stage.add_child(head)
	var table = Look.caps("At the table", 12, Look.BRASS, 2)
	table.position = Vector2(_w() / 2 - CARD_W / 2.0, 172)
	_stage.add_child(table)
	var tw = _tween()
	tw.tween_property(lead, "modulate:a", 1.0, 0.4)
	var members = [f]
	_set_bar(members)
	# the queue of parties to approach, largest first, on the right
	var queue = []
	for k in steps.size():
		var c = _card(steps[k].p)
		c.position = Vector2(_w() - CARD_W - 70, 200 + k * 92)
		c.scale = Vector2(0.85, 0.85)
		c.modulate.a = 0.0
		queue.append(c)
		tw.tween_property(c, "modulate:a", 0.9, 0.3).set_delay(0.06 * k)
	if not await _pause(1.0): return false
	var stack_y: float = 200 + 170
	for k in steps.size():
		var st: Dictionary = steps[k]
		var c: PanelContainer = queue[k]
		var mv = _tween()
		mv.tween_property(c, "position", Vector2(_w() / 2 - CARD_W / 2.0, 200), 0.5)
		mv.tween_property(c, "scale", Vector2.ONE, 0.5)
		mv.tween_property(c, "modulate:a", 1.0, 0.3)
		for q in range(k + 1, queue.size()):
			mv.tween_property(queue[q], "position:y", 200 + (q - k - 1) * 92, 0.5)
		if not await _pause(0.6): return false
		var cols = {"ally": Look.GOOD, "neutral": Look.AMBER, "enemy": Look.RED}
		_badge(c, st.stance, cols.get(st.stance, Look.MUTED))
		if not await _pause(0.4): return false
		match st.verdict:
			"enemy":
				_cross(c, c.position + Vector2(-6, -6), c.size + Vector2(12, 12))
				_caption.text = st.why
				if not await _pause(1.6): return false
				await _leave_up([c] + _stage.get_children().filter(func(n): return n is XMark))
			"refuse":
				var s1 = _stamp(c, "Walks away", Look.CREAM_DIM)
				_caption.text = st.why
				if not await _pause(1.5): return false
				await _leave_up([c, s1])
			"skip":
				_caption.text = "%s is not needed: no majority without enemies has room for it with these partners." % _name(st.p)
				if not await _pause(0.8): return false
				await _leave_up([c])
			"join":
				var s2 = _stamp(c, "Joins", Look.GOOD)
				_caption.text = "%s: %s" % [_name(st.p), st.why]
				members.append(st.p)
				_set_bar(members)
				if not await _pause(1.4): return false
				s2.queue_free()
				var j = _tween()
				j.tween_property(c, "position", Vector2(80, stack_y), 0.5)
				j.tween_property(c, "scale", Vector2(0.85, 0.85), 0.5)
				stack_y += 92
				if not await _pause(0.6): return false
	if fail:
		_caption.text = "%s gives up. %s" % [_name(f), fail.why]
		if not await _pause(2.0): return false
		await _leave_up(_stage.get_children())
	return true

func _sub_for(f: String) -> String:
	return "You try to form a government." if _party(f).isPlayer else "%s tries to form a government." % String(_party(f).name)

func _set_bar(members: Array) -> void:
	_bar.parts = members.map(func(id): return [Color(_party(id).color), int(co.log[0].seats[id]), _name(id)])
	_bar.queue_redraw()

func _show_shutout(st: Dictionary) -> bool:
	_clear()
	_sub.text = "No one managed."
	var c = _card(st.party, true)
	c.position = Vector2(_w() / 2 - BIG_W / 2.0, 230)
	_stamp(c, "Shut out", Look.RED)
	_caption.text = st.why
	if not await _pause(2.6): return false
	await _leave_up(_stage.get_children())
	return true

# ---------- The result ----------
func _show_end() -> void:
	_done = true
	_clear()
	_skip_btn.visible = false
	var h = find_child("Hint", false, false)
	if h: h.visible = false
	var gov = co.government
	var out: Dictionary = G.COALITION.get("OUTCOMES", {}).get(co.outcome, {})
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.position = Vector2(80, 170)
	box.custom_minimum_size.x = _w() - 160
	_stage.add_child(box)
	if gov:
		_title.text = "The new government"
		_set_bar(gov.members)
		var pm = ""
		for c in gov.cabinet:
			if c.ministry == "pm": pm = c.party
		_sub.text = "%s governs alone." % String(_party(gov.members[0]).name) if gov.members.size() == 1 else "A coalition of %s." % _and_list(gov.members.map(func(id): return String(_party(id).name)))
		var grid = GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 40)
		grid.add_theme_constant_override("v_separation", 6)
		for c in gov.cabinet:
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			var dot = ColorRect.new()
			dot.color = Color(_party(c.party).color)
			dot.custom_minimum_size = Vector2(14, 14)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(dot)
			var m = Look.label(String(c.name), "news_bold" if c.ministry == "pm" else "news", 19 if c.ministry == "pm" else 17, Look.CREAM)
			m.custom_minimum_size.x = 260
			row.add_child(m)
			row.add_child(Look.label(_name(c.party), "type", 16, Color(_party(c.party).color).lightened(0.25)))
			grid.add_child(row)
		box.add_child(Look.caps("The cabinet", 12, Look.BRASS, 2))
		box.add_child(grid)
	else:
		_title.text = "No government"
		_sub.text = co.log[-1].get("why", "") if co.log.size() else ""
	var sep = Control.new()
	sep.custom_minimum_size.y = 18
	box.add_child(sep)
	var you: Dictionary = G.player_party(S)
	var fill = {"party": you.name, "leader": you.leader}
	if out.size():
		box.add_child(Look.label(String(out.get("headline", "")).format(fill).to_upper(), "display_bold", 30, Look.HEAD, true))
		box.add_child(Look.label(String(out.get("line", "")).format(fill), "body_italic", 19, Look.CREAM, true))
	var go = Button.new()
	go.text = "Read what the papers say"
	go.add_theme_font_size_override("font_size", Look.fs(16))
	go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	go.pressed.connect(func(): finished.emit())
	box.add_child(go)

func _and_list(xs: Array) -> String:
	if xs.size() <= 1: return "".join(xs)
	return ", ".join(xs.slice(0, -1)) + " and " + xs[-1]

# ---------- Drawing ----------
## A seat bar: the parties of a (possible) government, and the line a majority must cross.
class CoalitionBar extends Control:
	var parts: Array = []   # [color, seats, label]
	var total := 300
	var need := 151
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.06))
		var x = 0.0
		var f = Look.font("display_bold")
		var sum = 0
		for p in parts:
			var w: float = size.x * float(p[1]) / total
			draw_rect(Rect2(x, 0, w, size.y), p[0])
			if w > 40: draw_string(f, Vector2(x + 6, size.y - 7), "%s %d" % [p[2], p[1]], HORIZONTAL_ALIGNMENT_LEFT, w - 8, 13, Color.WHITE)
			x += w
			sum += int(p[1])
		var mx: float = size.x * float(need) / total
		draw_line(Vector2(mx, -6), Vector2(mx, size.y + 6), Look.HEAD, 2.0)
		draw_string(f, Vector2(mx + 6, -8), "%d to govern" % need, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Look.CREAM_DIM)
		if parts.size(): draw_string(f, Vector2(size.x - 160, size.y + 18), "%d seats" % sum, HORIZONTAL_ALIGNMENT_RIGHT, 160, 13, Look.HEAD if sum >= need else Look.CREAM_DIM)

## One possible majority: its parties side by side, as wide as their seats.
class ComboChip extends Control:
	var parts: Array = []
	var total := 300
	var need := 151
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Look.PAPER)
		var f = Look.font("display_bold")
		var sum = 0
		for p in parts: sum += int(p[1])
		var x = 6.0
		var w_all: float = size.x - 12
		for p in parts:
			var w: float = w_all * float(p[1]) / maxf(1, sum)
			draw_rect(Rect2(x, 6, w - 2, 26), p[0])
			if w > 30: draw_string(f, Vector2(x + 4, 25), p[2], HORIZONTAL_ALIGNMENT_LEFT, w - 6, 12, Color.WHITE)
			x += w
		draw_string(Look.font("type"), Vector2(8, size.y - 8), "%d seats" % sum, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Look.INK)
		draw_rect(Rect2(Vector2.ZERO, size), Look.BORDER, false, 1.5)

## A red X drawn stroke by stroke (progress 0..1).
class XMark extends Control:
	var progress := 0.0:
		set(v):
			progress = v
			queue_redraw()
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var a: float = clampf(progress * 2, 0, 1)
		var b: float = clampf(progress * 2 - 1, 0, 1)
		var w: float = 5.0
		if a > 0: draw_line(Vector2.ZERO, size * a, Look.RED, w, true)
		if b > 0: draw_line(Vector2(size.x, 0), Vector2(size.x, 0).lerp(Vector2(0, size.y), b), Look.RED, w, true)
