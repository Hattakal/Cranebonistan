## files.gd — the six planning files along the top bar. Each slides out over
## the board like a manila folder: the electorate, your platform, this month's
## moves, the country, the polls and your diary.
class_name Files
extends Control

signal changed            # the game state changed: save and redraw
signal toast(text: String)
signal open_country(id: String)

const TITLES := {"electorate": "The electorate", "platform": "Platform and leader", "actions": "This month's moves",
	"parties": "The country", "polls": "Polls", "diary": "Campaign diary"}

var G
var S: Dictionary
var tab = ""
var kind = "age"
var group = "18-29"
var champ = null          # {"axis", "side"} picked in the claims table

var _folder: PanelContainer
var _title: Label
var _scroll: ScrollContainer
var _body: VBoxContainer

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_folder = PanelContainer.new()
	_folder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var manila = Look.box(Color("d9bf86"), 0, Color.TRANSPARENT, 0, 18)
	manila.content_margin_left = 10; manila.content_margin_right = 10; manila.content_margin_top = 40; manila.content_margin_bottom = 10
	_folder.add_theme_stylebox_override("panel", manila)
	add_child(_folder)
	var paper = PanelContainer.new()
	paper.add_theme_stylebox_override("panel", Look.box(Look.PAPER, 0, Color("c9b78d"), 1, 0, 0))
	_folder.add_child(paper)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	paper.add_child(_scroll)
	var m = MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]: m.add_theme_constant_override("margin_" + side, 24)
	m.add_theme_constant_override("margin_top", 20)
	m.add_theme_constant_override("margin_bottom", 28)
	_scroll.add_child(m)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 14)
	m.add_child(_body)
	# the folder's tab and the close button
	var tabp = PanelContainer.new()
	var tsb = Look.box(Color("d9bf86"), 0)
	tsb.corner_radius_top_left = 8; tsb.corner_radius_top_right = 8
	tsb.content_margin_left = 18; tsb.content_margin_right = 18; tsb.content_margin_top = 6; tsb.content_margin_bottom = 4
	tabp.add_theme_stylebox_override("panel", tsb)
	tabp.position = Vector2(18, 2)
	_title = Look.caps("", 17, Color("3b2a12"), 2, "display_bold")
	tabp.add_child(_title)
	add_child(tabp)
	var close = Button.new()
	close.text = "×"
	close.flat = true
	close.add_theme_font_size_override("font_size", 30)
	close.add_theme_color_override("font_color", Color("3b2a12"))
	close.add_theme_color_override("font_hover_color", Look.RED)
	close.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close.position = Vector2(-46, -2)
	close.tooltip_text = "Close the file (Esc)"
	close.pressed.connect(func(): show_tab(""))
	add_child(close)

func _unhandled_input(e: InputEvent) -> void:
	if visible and e.is_action_pressed("ui_cancel"):
		show_tab(""); get_viewport().set_input_as_handled()

## Open a file (or close with ""). Opening the same file again closes it.
func show_tab(t: String) -> void:
	if t != "" and t == tab and visible: t = ""
	tab = t
	visible = t != ""
	if visible:
		_title.text = TITLES[t].to_upper()
		render()
		_scroll.scroll_vertical = 0
		modulate.a = 0
		position.x = -30
		var tw = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "modulate:a", 1.0, 0.2)
		tw.tween_property(self, "position:x", 0.0, 0.28)

func open_region(id: String) -> void:
	kind = "region"; group = id
	tab = ""
	show_tab("electorate")

func render() -> void:
	if not visible: return
	var keep = _scroll.scroll_vertical
	for c in _body.get_children(): c.queue_free()
	match tab:
		"electorate": _electorate()
		"platform": _platform()
		"actions": _actions()
		"parties": _country()
		"polls": _polls()
		"diary": _diary()
	await get_tree().process_frame
	_scroll.scroll_vertical = keep

# ---------- Small builders ----------
func _add(c: Control, to: Control = null) -> Control:
	(to if to else _body).add_child(c)
	return c

func _h(text: String, size := 24, to: Control = null):
	return _add(Look.label(text, "display", size, Look.INK, true), to)

func _eyebrow(text: String, to: Control = null):
	return _add(Look.caps(text, 11, Look.MUTED, 2), to)

func _p(text: String, to: Control = null, col := Look.MUTED, size := 13):
	return _add(Look.label(text, "body", size, col, true), to)

func _rule(to: Control = null) -> void:
	var r = ColorRect.new()
	r.color = Look.INK
	r.custom_minimum_size.y = 2
	_add(r, to)

func _btn(text: String, cb: Callable, disabled := false, primary := false, toggled := false) -> Button:
	var b = Button.new()
	b.text = text
	b.disabled = disabled
	b.add_theme_font_override("font", Look.spaced("display", 1))
	b.add_theme_font_size_override("font_size", 13)
	var bg = Look.OXBLOOD if primary else (Look.INK if toggled else Color(1, 1, 1, 0.35))
	var fg = Look.HEAD if (primary or toggled) else Look.INK
	b.add_theme_stylebox_override("normal", Look.box(bg, 2, Look.INK if not primary else Look.OXBLOOD, 1, 0, 7))
	b.add_theme_stylebox_override("hover", Look.box(bg.lightened(0.12) if (primary or toggled) else Color("fff8e8"), 2, Look.INK, 1, 0, 7))
	b.add_theme_stylebox_override("pressed", Look.box(bg.darkened(0.1), 2, Look.INK, 1, 0, 7))
	b.add_theme_stylebox_override("disabled", Look.box(Color(0, 0, 0, 0.04), 2, Look.LINE, 1, 0, 7))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_disabled_color", Color(0, 0, 0, 0.3))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(cb)
	return b

func _row(to: Control = null, sep := 8):
	var h = HFlowContainer.new()
	h.add_theme_constant_override("h_separation", sep)
	h.add_theme_constant_override("v_separation", sep)
	return _add(h, to)

func _card(to: Control = null) -> VBoxContainer:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", Look.box(Color(1, 1, 1, 0.35), 0, Look.LINE, 1, 0, 14))
	_add(p, to)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	return v

func _facts(pairs: Array, to: Control = null, cols := 3) -> void:
	var g = GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 22)
	g.add_theme_constant_override("v_separation", 10)
	for pr in pairs:
		var v = VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(Look.caps(pr[0], 10, Look.MUTED, 1))
		v.add_child(Look.label(pr[1], "display", 19, Look.INK))
		g.add_child(v)
	_add(g, to)

func _chip(text: String, to: Control, col := Look.INK) -> void:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", Look.box(Color(1, 1, 1, 0.45), 1, Look.LINE, 1, 0, 0))
	(p.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = 8
	(p.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_right = 8
	(p.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_top = 2
	(p.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_bottom = 2
	p.add_child(Look.label(text, "body", 13, col))
	to.add_child(p)

func _bars(support: Dictionary, previous = null, to: Control = null) -> void:
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	var ids: Array = Game.ssort(support.keys(), func(a, b): return support[b] - support[a])
	var mx: float = support[ids[0]]
	for id in ids:
		var p = G.party_of(S, id)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.tooltip_text = p.name
		var nm = Look.label(p.short, "body_bold" if p.isPlayer else "body", 13)
		nm.custom_minimum_size.x = 48
		row.add_child(nm)
		var bar = Bar.new(Color(p.color), support[id] / mx)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size.y = 14
		row.add_child(bar)
		var txt = "%s%%" % Game.fmt1(support[id] * 100)
		var val = Look.label(txt, "body_bold" if p.isPlayer else "body", 13)
		val.custom_minimum_size.x = 58
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val)
		if previous != null:
			var d: float = support[id] - previous.get(id, support[id])
			var dl = Look.label(("+" if d >= 0 else "") + Game.fmt1(d * 100), "body", 12, Look.GOOD if d >= 0 else Look.RED)
			dl.custom_minimum_size.x = 40
			row.add_child(dl)
		v.add_child(row)
	_add(v, to)

class Bar extends Control:
	var col: Color
	var frac: float:
		set(v):
			frac = clampf(v, 0, 1)
			queue_redraw()
	func _init(c: Color, f: float) -> void:
		col = c; frac = clampf(f, 0, 1)
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.08))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * frac, size.y)), col)

static func leader_words(v: float) -> String:
	if v > 0.6: return "Adored"
	if v > 0.3: return "Popular"
	if v > 0.1: return "Liked"
	if v > -0.1: return "No opinion"
	if v > -0.3: return "Disliked"
	return "Despised"

static func charisma_word(c: float) -> String:
	if c >= 75: return "Magnetic"
	if c >= 60: return "Compelling"
	if c >= 45: return "Ordinary"
	if c >= 30: return "Bland"
	return "Awkward"

static func claim_word(v: float) -> String:
	if v >= 0.6: return "Owns it"
	if v >= 0.35: return "Strong"
	if v >= 0.15: return "Some"
	return "Weak"

static func stability_word(v: float) -> String:
	if v >= 65: return "United"
	if v >= 45: return "Stable"
	if v >= 30: return "Shaky"
	return "In crisis"

func _lean_label(v: float, ax: Dictionary) -> String:
	var side: String = ax.left if v < 0 else ax.right
	var a = absf(v)
	if a > 45: return "Strongly " + side.to_lower()
	if a > 25: return side
	return "Leans " + side.to_lower()

# ---------- The electorate ----------
func _electorate() -> void:
	var kinds: Array = G.group_kinds()
	var k: Dictionary = kinds[0]
	for x in kinds:
		if x.id == kind: k = x
	var g = null
	for x in k.groups:
		if x.id == group: g = x
	if g == null:
		g = k.groups[0]; group = g.id
	var kr = _row()
	for x in kinds:
		kr.add_child(_btn(x.label, func(): kind = x.id; group = ""; render(), false, false, x.id == k.id))
	var cols = HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	_add(cols)
	var list = VBoxContainer.new()
	list.custom_minimum_size.x = 170
	list.add_theme_constant_override("separation", 2)
	cols.add_child(list)
	for x in k.groups:
		var size: float = G.size_of(S, x.who)
		var b = _btn("%s   %sM" % [x.label, Game.fmt1(size / 1e6)], func(): group = x.id; render(), false, false, x.id == g.id)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", Look.font("body"))
		b.add_theme_font_size_override("font_size", 13)
		list.add_child(b)
	var d = VBoxContainer.new()
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d.add_theme_constant_override("separation", 12)
	cols.add_child(d)
	var sum: Dictionary = G.summarize(S, G.pops_matching(S, g.who))
	_eyebrow(k.label, d)
	_h(g.label, 28, d)
	_add(Look.label("%s million adults%s" % [Game.fmt1(sum.size / 1e6), " (groups overlap)" if k.id == "views" else ""], "body", 14, Look.MUTED), d)
	if k.id == "region":
		var r = Game.by_id(G.REGIONS, g.id)
		_p(r.blurb, d, Look.INK, 14)
	var poll = S.polls[-1] if S.polls.size() else null
	var entry = poll.groups.get("%s:%s" % [k.id, g.id]) if poll else null
	var prev = S.polls[-2].groups.get("%s:%s" % [k.id, g.id]) if S.polls.size() > 1 else null
	var dis: float = sum.disaffection
	_facts([
		["Turnout", "%d%%" % Game.jround(sum.turnout * 100)],
		["Know your party", "%d%%" % Game.jround(sum.aware * 100)],
		["Your core supporters", "%dk" % Game.jround((entry.core.player if entry else 0.0) / 1000.0)],
		["View of " + G.player_party(S).leader, leader_words(sum.leader)],
		["Fed up with the system", "Very" if dis > 1.25 else ("Quite" if dis > 1.05 else ("Somewhat" if dis > 0.85 else "Hardly"))],
	], d)
	if sum.leaderPull > 1.12: _p("Looks for a strong, charismatic leader.", d, Look.RED)
	elif sum.leaderPull < 0.88: _p("Hard to win over with personality alone.", d, Look.RED)
	_eyebrow("Cares most about", d)
	var issues: Array = Game.ssort(G.AXES.duplicate(), func(a, b): return sum.sal[b.id] - sum.sal[a.id]).slice(0, 3)
	var ir = _row(d, 6)
	for a in issues: _chip(a.issue, ir)
	_eyebrow("Leanings", d)
	var leans: Array = G.AXES.filter(func(a): return absf(sum.pos[a.id]) > 12)
	leans = Game.ssort(leans, func(a, b): return absf(sum.pos[b.id]) - absf(sum.pos[a.id])).slice(0, 4)
	if leans.is_empty(): _p("No strong leanings. A swing group.", d)
	for a in leans: _add(Look.label(_lean_label(sum.pos[a.id], a), "type", 15, Look.INK), d)
	_eyebrow("Vote intention · " + (poll.label if poll else "no poll yet"), d)
	if entry: _bars(entry.support, prev.support if prev else null, d)

# ---------- Platform and leader ----------
func _platform() -> void:
	var player: Dictionary = G.player_party(S)
	var inc: float = G.inconsistency_of(S, player)
	var nation: Dictionary = G.summarize(S, S.pops)
	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	_add(top)
	var c1 = _card(top)
	c1.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_eyebrow("Your leader", c1)
	_h(player.leader, 26, c1)
	var dev: float = nation.devotion
	_facts([
		["Charisma", charisma_word(player.charisma)],
		["Personal image", leader_words(nation.leader)],
		["Speaking style", G.style_profile(S).label],
		["Devotion", "Fanatical" if dev > 0.4 else ("Strong" if dev > 0.2 else ("Growing" if dev > 0.08 else "Little"))],
		["Would follow you anywhere", ("%sM" % Game.fmt1(nation.followers / 1e6)) if nation.followers >= 1e6 else "%dk" % Game.jround(nation.followers / 1000.0)],
	], c1, 2)
	_p("Your style comes from the words you choose: a recognisable voice builds charisma. Devoted voters care less about your positions and forgive flip-flops.", c1)
	var c2 = _card(top)
	c2.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_eyebrow("Consistency", c2)
	var state: Array = ["Consistent", "Voters believe you mean what you say."] if inc < 0.5 else (["Wobbling", "A few voters have noticed you changing your tune."] if inc < 2 else (["Unreliable", "Your core supporters are leaving, and engaged voters punish you."] if inc < 5 else ["Flip-flopper", "Nobody knows what you stand for. Your base is collapsing."]))
	_h(state[0], 28, c2)
	var meter = DriftMeter.new(clampf(inc / 8.0, 0, 1))
	meter.custom_minimum_size.y = 18
	c2.add_child(meter)
	_p(state[1] + " Up to one stance away from your manifesto is free; two or more costs you.", c2)
	var flips: Array = S.flips.filter(func(f): return f.party == "player" and S.week - f.week < G.C.flipMemoryWeeks)
	flips.reverse()
	for f in flips.slice(0, 5):
		_add(Look.label("%s   %s → %s" % [G.date_label(f.week, false), G.stance_name(f.axis, f.from), G.stance_name(f.axis, f.to)], "type", 13, Look.INK), c2)
	_rule()
	var lg = _row(null, 14)
	lg.add_child(Look.label("■ Manifesto", "body", 12, Color("b3261e")))
	lg.add_child(Look.label("● How voters see you", "body", 12, Look.RED))
	for p in G.rivals(S): lg.add_child(Look.label("● " + p.short, "body", 12, Color(p.color)))
	for ax in G.AXES:
		var t = AxisTrack.new(G, S, ax, player)
		t.custom_minimum_size.y = 62
		_add(t)

class DriftMeter extends Control:
	var v: float
	func _init(x: float) -> void: v = x
	func _draw() -> void:
		var y = size.y / 2 - 5
		var cols = [Color("4f9a63"), Color("c9a227"), Color("d9772f"), Look.RED]
		var widths = [0.2, 0.2, 0.2, 0.4]
		var x = 0.0
		for i in 4:
			draw_rect(Rect2(x, y, size.x * widths[i], 10), cols[i])
			x += size.x * widths[i]
		draw_rect(Rect2(size.x * v - 2, 0, 4, size.y), Look.INK)

class AxisTrack extends Control:
	var G
	var S: Dictionary
	var ax: Dictionary
	var party: Dictionary
	func _init(g, s, a, p) -> void:
		G = g; S = s; ax = a; party = p
		mouse_filter = Control.MOUSE_FILTER_PASS
	func _draw() -> void:
		var f = Look.font("body")
		draw_string(f, Vector2(0, 14), ax.left, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Look.INK)
		var rw = f.get_string_size(ax.right, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(f, Vector2(size.x - rw, 14), ax.right, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Look.INK)
		var y = 20.0
		var h = 22.0
		var ms: int = G.stance_of(party.manifesto[ax.id])
		var ps: int = G.stance_of(party.perceived[ax.id])
		for i in 5:
			var r = Rect2(size.x * i / 5.0 + 1, y, size.x / 5.0 - 2, h)
			draw_rect(r, Color(0, 0, 0, 0.07))
			if i == ms:
				draw_rect(r, Color(0.7, 0.15, 0.12, 0.18))
				draw_rect(r, Look.RED, false, 2.0)
			elif i == ps:
				draw_rect(r, Color(0.7, 0.15, 0.12, 0.12))
		var px = func(v: float) -> float: return (v + 100) / 200.0 * size.x
		for p in G.rivals(S):
			draw_circle(Vector2(px.call(p.perceived[ax.id]), y + h / 2), 5, Look.PAPER)
			draw_circle(Vector2(px.call(p.perceived[ax.id]), y + h / 2), 4, Color(p.color))
		draw_circle(Vector2(px.call(party.perceived[ax.id]), y + h / 2), 8, Look.PAPER)
		draw_circle(Vector2(px.call(party.perceived[ax.id]), y + h / 2), 7, Look.RED)
		var off = absi(ps - ms)
		var txt = ("Seen as %s, manifesto says %s%s" % [ax.stances[ps], ax.stances[ms], " · serious" if off > 1 else ""]) if off else "%s, as promised" % ax.stances[ps]
		draw_string(f, Vector2(0, y + h + 16), txt, HORIZONTAL_ALIGNMENT_LEFT, size.x, 12, Look.RED if off else Look.MUTED)

# ---------- This month's moves ----------
func _actions() -> void:
	var blocked: bool = S.queue.size() > 0 or S.result != null
	var left: int = S.actionsLeft
	var dis = func(cost := 0.0) -> bool: return blocked or left <= 0 or S.money < cost
	# the agenda
	if not S.result:
		var c = _card()
		_h("This month's agenda", 20, c)
		if S.agenda.done:
			var last = ""
			for i in range(S.log.size() - 1, -1, -1):
				if S.log[i].kind == "initiative":
					last = S.log[i].text; break
			_p((last if last != "" else "You have set this month's agenda.") + " New debates open next month.", c)
		else:
			_p("Put a debate on the national agenda. It doesn't use an action, but what you raise will come back in the months ahead.", c)
			for id in S.agenda.offered:
				var ini = Game.by_id(G.INITIATIVES, id)
				_initiative_card(ini, c, blocked)
	if blocked and not S.result: _p("Finish the decision on the board first.", null, Look.RED, 14)
	var head = HBoxContainer.new()
	_add(head)
	var hl = VBoxContainer.new()
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hl)
	_eyebrow("Actions this month", hl)
	_add(Look.label("%d of %d left" % [left, int(G.C.actionsPerMonth)], "display", 26, Look.INK), hl)
	var hr = VBoxContainer.new()
	head.add_child(hr)
	_eyebrow("Funds", hr)
	_add(Look.label("₱%sM" % Game.fmt1(S.money), "display", 26, Look.INK), hr)
	_rule()
	# champion an issue
	_section(G.ACTIONS.champion.label, "Free", G.ACTIONS.champion.help + " Your manifesto's sides are outlined; each side shows who holds the strongest claim.")
	var sig = _row(null, 6)
	sig.add_child(Look.caps("Your issues (%d of %d)" % [S.signature.size(), int(G.C.maxSignatureIssues)], 11, Look.MUTED, 1))
	for key in S.signature:
		sig.add_child(_btn("★ %s · drop" % G.side_label(key), func(): G.drop_signature(S, key); changed.emit(), blocked))
	var table: Array = G.ownership_table(S)
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_add(grid)
	for ax in G.AXES:
		var heat = float(S.salMod.get(ax.id, 0))
		var il = Look.label(ax.issue + ("  · HOT" if heat > 0.45 else ""), "body_bold", 12, Look.RED if heat > 0.45 else Look.INK)
		il.custom_minimum_size.x = 120
		grid.add_child(il)
		for side in ["L", "R"]:
			var key: String = Game.side_key(ax.id, side)
			var owners: Array = []
			for r in table:
				if r.key == key: owners = r.owners
			var top = owners[0] if owners.size() else null
			var yours: bool = G.manifesto_side(S, ax.id) == side
			var sel: bool = champ != null and champ.axis == ax.id and champ.side == side
			var label: String = ("★ " if S.signature.has(key) else "") + (ax.left if side == "L" else ax.right)
			var owner_txt: String = ("%s · %s" % [G.party_of(S, top.party).short, claim_word(top.value)]) if top else "Unclaimed"
			var b = _btn("%s\n%s" % [label, owner_txt], func(): champ = {"axis": ax.id, "side": side}; render(), false, false, sel)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_font_override("font", Look.font("body"))
			b.add_theme_font_size_override("font_size", 12)
			if not yours: b.modulate.a = 0.6
			grid.add_child(b)
	if champ != null:
		var pv: Dictionary = G.champion_preview(S, champ.axis, champ.side)
		var c = _card()
		if pv.block != "":
			_p(pv.block, c, Look.RED, 14)
		else:
			_p("Single-issue voters on this side right now: %sM%s" % ["%.2f" % (pv.single / 1e6), " (it's in the news)" if pv.heat > 0.45 else ""], c, Look.INK, 14)
			_p("A smaller claim: everyone is already talking about it." if pv.heat > 0.25 else "A big claim: nobody is talking about it yet.", c)
			var st: Dictionary = pv.shift
			if st.from != st.to: _p("Stance change: %s → %s" % [G.stance_name(champ.axis, st.from), G.stance_name(champ.axis, st.to)], c, Look.RED)
			var side_name: String = (pv.ax.left if champ.side == "L" else pv.ax.right).to_lower()
			c.add_child(_btn("Champion " + side_name, func(): _did(G.act_champion(S, champ.axis, champ.side)), dis.call(), true))
	else:
		_p("Pick a side above to see what championing it would do.")
	# grassroots
	_section(G.ACTIONS.grassroots.label, "₱%sM" % str(G.ACTIONS.grassroots.cost), G.ACTIONS.grassroots.help)
	var gr = _row()
	for r in G.REGIONS: gr.add_child(_btn(r.name, func(): _did(G.act_grassroots(S, r.id)), dis.call(G.ACTIONS.grassroots.cost)))
	# opposition research
	_section(G.ACTIONS.research.label, "₱%sM" % str(G.ACTIONS.research.cost), G.ACTIONS.research.help + " About half the time you find something; one time in seven you get caught.")
	var rr = _row()
	for p in G.rivals(S): rr.add_child(_btn(p.short, func(): _did(G.act_research(S, p.id)), dis.call(G.ACTIONS.research.cost)))
	if S.dossiers.size():
		_eyebrow("Your dossiers")
		for i in S.dossiers.size():
			var dd: Dictionary = S.dossiers[i]
			var line = HBoxContainer.new()
			_add(line)
			var t = Look.label("%s: %s (%s)" % [G.party_of(S, dd.party).short, dd.what, ["", "minor", "damaging", "explosive"][int(dd.severity)]], "type", 14, Look.INK, true)
			t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_child(t)
			line.add_child(_btn("Release", func(): _did(G.act_release(S, i)), dis.call()))
	# poach
	_section(G.ACTIONS.poach.label, "₱%sM" % str(G.ACTIONS.poach.cost), G.ACTIONS.poach.help)
	var pr = _row()
	for p in G.rivals(S):
		var ok: bool = G.can_poach(S, p.id)
		var b = _btn("%s · %s" % [p.short, stability_word(p.stability)], func(): _did(G.act_poach(S, p.id)), (not ok) or dis.call(G.ACTIONS.poach.cost))
		b.tooltip_text = "Ready to defect" if ok else ("Raided recently" if p.stability < 40 else "Too stable")
		pr.add_child(b)
	# outrage
	_section(G.ACTIONS.outrage.label, "Free", G.ACTIONS.outrage.help + " Each stunt in the last six months makes the next one less effective.")
	_row().add_child(_btn("Say the unsayable", func(): _did(G.act_outrage(S)), dis.call()))

func _section(title: String, cost: String, help: String) -> void:
	_rule()
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	_add(h)
	h.add_child(Look.label(title, "display", 20, Look.INK))
	var c = Look.label(cost, "body", 12, Look.MUTED)
	c.size_flags_vertical = Control.SIZE_SHRINK_END
	h.add_child(c)
	_p(help)

func _did(res: Dictionary) -> void:
	toast.emit(res.text)
	if res.ok: champ = null if res.text.begins_with("You are campaigning") else champ
	changed.emit()

func _initiative_card(ini: Dictionary, to: Control, blocked: bool) -> void:
	var d: Dictionary = G.describe_choice(S, ini.effects)
	var card = PanelContainer.new()
	var sb = Look.box(Color("fdfaf2"), 0, Color.TRANSPARENT, 0, 3, 12)
	sb.border_width_top = 3; sb.border_color = Color("d9534f")
	var hv = sb.duplicate(); hv.bg_color = Color("fffdf6"); hv.shadow_size = 8
	card.add_theme_stylebox_override("panel", sb)
	card.mouse_default_cursor_shape = Control.CURSOR_ARROW if blocked else Control.CURSOR_POINTING_HAND
	if blocked: card.modulate.a = 0.55
	var v = VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	v.add_child(Look.label(ini.title, "type", 17, Color("1f2a44"), true))
	v.add_child(Look.label(ini.text, "body", 13, Look.MUTED, true))
	if d.appeals.size(): v.add_child(Look.label("Appeals to: " + ", ".join(d.appeals.map(func(x): return x.text)), "body", 13, Look.GOOD, true))
	if d.angers.size(): v.add_child(Look.label("Angers: " + ", ".join(d.angers.map(func(x): return x.text)), "body", 13, Look.RED, true))
	var tags: Array = d.tags.duplicate()
	for s in d.stances:
		if s.from != s.to: tags.push_front("Stance change: %s → %s" % [G.stance_name(s.axis, s.from), G.stance_name(s.axis, s.to)])
	tags.append("Expect consequences")
	v.add_child(Look.label(" · ".join(tags), "body_italic", 12, Look.MUTED, true))
	for c in v.get_children(): c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	if not blocked:
		card.mouse_entered.connect(func(): card.add_theme_stylebox_override("panel", hv))
		card.mouse_exited.connect(func(): card.add_theme_stylebox_override("panel", sb))
		card.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				var res: Dictionary = G.take_initiative(S, ini.id)
				if res.ok:
					var txt: String = "On the agenda: %s." % res.title
					if res.changes.size(): txt += " " + ", ".join(res.changes.slice(0, 3).map(func(x): return "%s %s%s" % [x.label, "+" if x.delta > 0 else "", Game.fmt1(x.delta)]))
					toast.emit(txt)
				else: toast.emit(res.text)
				changed.emit())
	to.add_child(card)

# ---------- The country ----------
func _country() -> void:
	var w: Dictionary = S.world
	var prev: Dictionary = S.get("worldPrev", {})
	var c = _card()
	_eyebrow("The state of the nation", c)
	var g = GridContainer.new()
	g.columns = 5
	g.add_theme_constant_override("h_separation", 18)
	c.add_child(g)
	for ind in G.INDICATORS:
		var v = VBoxContainer.new()
		v.add_child(Look.caps(ind.label, 10, Look.MUTED, 1))
		v.add_child(Look.label(G.indicator_word(ind.id, w[ind.id]), "display", 17, Look.INK, true))
		if prev.has(ind.id):
			var dlt: float = w[ind.id] - prev[ind.id]
			var txt = "steady" if absf(dlt) < 1.5 else ("↑ rising" if dlt > 0 else "↓ falling")
			var good = null if ind.good == null else ((dlt > 0) if ind.good == "high" else (dlt < 0))
			v.add_child(Look.label(txt, "body", 12, Look.MUTED if (good == null or absf(dlt) < 1.5) else (Look.GOOD if good else Look.RED)))
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(v)
	if S.crisis:
		var cr = Game.by_id(G.CRISES, S.crisis.id)
		_p("%s: %s" % [cr.name, cr.blurb], c, Look.RED, 14)
	_p("Your statements move these a little, more as your party grows. Your influence: %s." % G.influence_label(S), c)
	var t = _card()
	_eyebrow("Trust in the political system", t)
	_h(Game.trust_label(S.trust), 26, t)
	var sp = Spark.new(S.trustHistory.slice(-36).map(func(x): return x.trust))
	sp.custom_minimum_size = Vector2(0, 46)
	t.add_child(sp)
	_p("Low trust sends fed-up voters to outsiders. It slowly recovers toward the middle on its own.", t)
	_eyebrow("The parties")
	var poll = S.polls[-1] if S.polls.size() else null
	var nation: Dictionary = G.summarize(S, S.pops)
	for p in S.parties:
		var pc = _card()
		var top = HBoxContainer.new()
		pc.add_child(top)
		var nm = VBoxContainer.new()
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.add_theme_constant_override("separation", 0)
		top.add_child(nm)
		nm.add_child(Look.label(p.name, "display", 19, Color(p.color).darkened(0.25)))
		nm.add_child(Look.label(p.leader + (" · governing" if p.ruling else ""), "body", 13, Look.MUTED))
		if poll: top.add_child(Look.label("%s%%" % Game.fmt1(poll.national[p.id] * 100), "display", 22, Look.INK))
		var est: float = p.establishment
		var meta = "%s leader · %s · %sM core voters" % [charisma_word(p.charisma), "The establishment" if est >= 0.8 else ("Mainstream" if est >= 0.55 else ("Semi-outsider" if est >= 0.3 else "Outsider")), "%.2f" % (nation.core[p.id] / 1e6)]
		if not p.isPlayer: meta += " · " + stability_word(p.stability)
		_p(meta, pc, Look.INK)
	_eyebrow("Neighbours")
	var nr = _row()
	for f in G.FOREIGN:
		var st: Dictionary = S.countries.get(f.id, {})
		nr.add_child(_btn(" ".join(f.name) + (" · " + st.relation if st.get("relation") else ""), func(): open_country.emit(f.id)))

class Spark extends Control:
	var vals: Array
	func _init(v: Array) -> void: vals = v
	func _draw() -> void:
		if vals.size() < 2: return
		var pts = PackedVector2Array()
		for i in vals.size():
			pts.append(Vector2(i / float(vals.size() - 1) * (size.x - 6) + 3, size.y - 4 - vals[i] / 100.0 * (size.y - 8)))
		var mid = size.y - 4 - 0.5 * (size.y - 8)
		draw_dashed_line(Vector2(0, mid), Vector2(size.x, mid), Look.LINE, 1.0, 4.0)
		draw_polyline(pts, Look.RED, 2.0, true)
		draw_circle(pts[-1], 3, Look.RED)

# ---------- Polls ----------
func _polls() -> void:
	if S.polls.is_empty():
		_p("No polls yet."); return
	var poll: Dictionary = S.polls[-1]
	var prev = S.polls[-2] if S.polls.size() > 1 else null
	_eyebrow("National vote intention · %s · %s" % [poll.label, G.date_label(poll.week, false)])
	_bars(poll.national, prev.national if prev else null)
	_p("Expected turnout %d%%. Margin of error about ±%s points." % [Game.jround(poll.turnout * 100), Game.fmt1(G.C.pollError * 200)])
	_eyebrow("Poll history")
	var ch = Chart.new(G, S)
	ch.custom_minimum_size.y = 240
	_add(ch)
	_p("A tracking poll comes out every month, with a detailed poll of every group each December.")

class Chart extends Control:
	var G
	var S: Dictionary
	func _init(g, s) -> void:
		G = g; S = s
	func _draw() -> void:
		var pad = {"l": 40.0, "r": 12.0, "t": 10.0, "b": 26.0}
		var n: int = S.polls.size()
		var mx = 0.4
		for p in S.polls:
			for k in p.national: mx = maxf(mx, p.national[k])
		var X = func(i: int) -> float: return pad.l + ((size.x - pad.l - pad.r) / 2 if n == 1 else i / float(n - 1) * (size.x - pad.l - pad.r))
		var Y = func(v: float) -> float: return pad.t + (1 - v / mx) * (size.y - pad.t - pad.b)
		var f = Look.font("body")
		for t in [0.0, 0.1, 0.2, 0.3, 0.4]:
			if t > mx: continue
			draw_dashed_line(Vector2(pad.l, Y.call(t)), Vector2(size.x - pad.r, Y.call(t)), Look.LINE, 1.0, 4.0)
			draw_string(f, Vector2(4, Y.call(t) + 4), "%d%%" % int(t * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Look.MUTED)
		for i in n:
			if i == 0 or not S.polls[i].tracker:
				var lab = "Start" if i == 0 else str(G.calendar(S.polls[i].week).year)
				draw_string(f, Vector2(X.call(i) - 14, size.y - 6), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Look.MUTED)
		for p in S.parties:
			var pts = PackedVector2Array()
			for i in n: pts.append(Vector2(X.call(i), Y.call(S.polls[i].national[p.id])))
			if pts.size() > 1: draw_polyline(pts, Color(p.color), 3.0 if p.isPlayer else 1.6, true)
			draw_circle(pts[-1], 5 if p.isPlayer else 3.5, Color(p.color))

# ---------- Diary ----------
func _diary() -> void:
	if S.log.is_empty():
		_p("Nothing has happened yet."); return
	for i in range(S.log.size() - 1, -1, -1):
		var e: Dictionary = S.log[i]
		var h = HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		var when = Look.caps(G.date_label(e.week, false), 11, Look.MUTED, 1)
		when.custom_minimum_size.x = 110
		h.add_child(when)
		var t = Look.label(e.text, "type", 14, Look.INK, true)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(t)
		_add(h)
		var r = ColorRect.new(); r.color = Look.LINE; r.custom_minimum_size.y = 1
		_add(r)
