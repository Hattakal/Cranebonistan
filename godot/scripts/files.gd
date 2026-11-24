## files.gd — the planning files along the top bar. Each opens over the desk and the
## map as a briefing on a dark screen: the electorate, your platform, this month's
## moves, the country, the media, the polls and your diary. This is where the numbers
## live, so it is kept plain: clean type, quiet lines, colour only where it means something.
class_name Files
extends Control

signal changed            # the game state changed: save and redraw
signal toast(text: String)
signal open_country(id: String)
signal speak(id: String, side: String)   # open the sheet to pick your words
signal raise(opt: Dictionary)             # open the sheet to start a debate

const TITLES := {"debates": "The national debate", "electorate": "The electorate", "platform": "Platform, leader and offices",
	"parties": "The country", "media": "The media", "polls": "Parties and polls", "diary": "Campaign diary"}

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
	var manila = Look.box(Look.N900, 0, Color.TRANSPARENT, 0, 0)
	manila.content_margin_top = 46
	_folder.add_theme_stylebox_override("panel", manila)
	add_child(_folder)
	var paper = PanelContainer.new()
	var psb = Look.box(Look.N850, 0, Look.N600, 0, 0, 0)
	psb.border_width_top = 1
	paper.add_theme_stylebox_override("panel", psb)
	_folder.add_child(paper)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	paper.add_child(_scroll)
	var m = MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]: m.add_theme_constant_override("margin_" + side, 28)
	m.add_theme_constant_override("margin_top", 20)
	m.add_theme_constant_override("margin_bottom", 28)
	_scroll.add_child(m)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 14)
	m.add_child(_body)
	# the folder's tab and the close button
	var tabp = PanelContainer.new()
	var tsb = Look.box(Color(0, 0, 0, 0), 0, Look.LAMP, 0)
	tsb.border_width_left = 3
	tsb.content_margin_left = 12
	tabp.add_theme_stylebox_override("panel", tsb)
	tabp.position = Vector2(28, 11)
	_title = Look.dcaps("", 18, Look.TXT, 3, "display_bold")
	tabp.add_child(_title)
	add_child(tabp)
	var close = Button.new()
	close.text = "×"
	close.flat = true
	close.add_theme_font_size_override("font_size", Look.fs(30))
	close.add_theme_color_override("font_color", Look.DIM)
	close.add_theme_color_override("font_hover_color", Look.RED_HI)
	close.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close.position = Vector2(-52, -1)
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
		"debates": _debates()
		"electorate": _electorate()
		"platform": _platform()
		"parties": _country()
		"media": _media()
		"polls": _polls()
		"diary": _diary()
	# room at the bottom, so the last cards can be scrolled clear of Carlos in the corner
	var pad = Control.new(); pad.custom_minimum_size.y = 120
	_body.add_child(pad)
	await get_tree().process_frame
	_scroll.scroll_vertical = keep

# ---------- Small builders ----------
func _add(c: Control, to: Control = null) -> Control:
	(to if to else _body).add_child(c)
	return c

func _h(text: String, size := 24, to: Control = null):
	return _add(Look.dlabel(text, "display", size, Look.TXT, true), to)

func _eyebrow(text: String, to: Control = null):
	return _add(Look.dcaps(text, 11, Look.DIM, 2), to)

func _p(text: String, to: Control = null, col := Look.DIM, size := 13):
	return _add(Look.dlabel(text, "body", size, col, true), to)

func _rule(to: Control = null) -> void:
	var r = ColorRect.new()
	r.color = Look.N600
	r.custom_minimum_size.y = 1
	_add(r, to)

func _btn(text: String, cb: Callable, disabled := false, primary := false, toggled := false) -> Button:
	var b = Button.new()
	b.text = text
	b.disabled = disabled
	b.add_theme_font_override("font", Look.spaced("display", 1))
	b.add_theme_font_size_override("font_size", Look.fs(13))
	Look.dark_button(b, primary, toggled)
	b.pressed.connect(cb)
	return b

func _row(to: Control = null, sep := 8):
	var h = HFlowContainer.new()
	h.add_theme_constant_override("h_separation", sep)
	h.add_theme_constant_override("v_separation", sep)
	return _add(h, to)

func _card(to: Control = null) -> VBoxContainer:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", Look.glass(16))
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
		v.add_child(Look.dcaps(pr[0], 10, Look.FAINT, 1))
		v.add_child(Look.dlabel(pr[1], "display_bold", 22, Look.TXT))
		g.add_child(v)
	_add(g, to)

func _chip(text: String, to: Control, col := Look.TXT) -> void:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", Look.box(Color(1, 1, 1, 0.04), 2, Look.N500, 1, 0, 0))
	(p.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = 8
	(p.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_right = 8
	(p.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_top = 2
	(p.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_bottom = 2
	p.add_child(Look.dlabel(text, "body", 13, col))
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
		var nm = Look.dlabel(p.short, "body_bold" if p.isPlayer else "body", 13)
		nm.custom_minimum_size.x = 48
		row.add_child(nm)
		var bar = Bar.new(Look.lit(Color(p.color)), support[id] / mx)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size.y = 14
		row.add_child(bar)
		var txt = "%s%%" % Game.fmt1(support[id] * 100)
		var val = Look.dlabel(txt, "body_bold" if p.isPlayer else "body", 13)
		val.custom_minimum_size.x = 58
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val)
		if previous != null:
			var d: float = support[id] - previous.get(id, support[id])
			var dl = Look.dlabel(("+" if d >= 0 else "") + Game.fmt1(d * 100), "body", 12, Look.GOOD_HI if d >= 0 else Look.RED_HI)
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
		draw_rect(Rect2(Vector2.ZERO, size), Look.N700)
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * frac, size.y)), col)

static func leader_words(v: float) -> String:
	if v > 0.6: return "Adored"
	if v > 0.3: return "Popular"
	if v > 0.1: return "Liked"
	if v > -0.1: return "No opinion"
	if v > -0.3: return "Disliked"
	return "Despised"

## The leader's net rating as a number voters would recognise: -100 .. +100.
static func leader_score(v: float) -> String:
	var n = Game.jround(clampf(v, -1, 1) * 100)
	return ("+%d" % n) if n > 0 else str(n)

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
		b.add_theme_font_size_override("font_size", Look.fs(13))
		list.add_child(b)
	var d = VBoxContainer.new()
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d.add_theme_constant_override("separation", 12)
	cols.add_child(d)
	var sum: Dictionary = G.summarize(S, G.pops_matching(S, g.who))
	_eyebrow(k.label, d)
	_h(g.label, 28, d)
	_add(Look.dlabel("%s million adults%s" % [Game.fmt1(sum.size / 1e6), " (groups overlap)" if k.id == "views" else ""], "body", 14, Look.DIM), d)
	if k.id == "region":
		var r = Game.by_id(G.REGIONS, g.id)
		_p(r.blurb, d, Look.TXT, 14)
		_region_cities(g.id, d)
	var poll = S.polls[-1] if S.polls.size() else null
	var entry = poll.groups.get("%s:%s" % [k.id, g.id]) if poll else null
	var prev = S.polls[-2].groups.get("%s:%s" % [k.id, g.id]) if S.polls.size() > 1 else null
	var dis: float = sum.disaffection
	_facts([
		["Turnout", "%d%%" % Game.jround(sum.turnout * 100)],
		["Know your party", "%d%%" % Game.jround(sum.aware * 100)],
		["Your core supporters", "%dk" % Game.jround((entry.core.player if entry else 0.0) / 1000.0)],
		["View of " + G.player_party(S).leader, "%s (%s)" % [leader_words(sum.leader), leader_score(sum.leader)]],
		["Fed up with the system", "Very" if dis > 1.25 else ("Quite" if dis > 1.05 else ("Somewhat" if dis > 0.85 else "Hardly"))],
	], d)
	var wants: Array = G.group_wants(S, G.pops_matching(S, g.who))
	if wants.size() >= 2:
		var fitd: Dictionary = G.leader_fit(S, G.player_party(S))
		var you = func(t): return "you fit well" if float(fitd.get(t.id, 0)) >= 0.55 else ("you fit somewhat" if float(fitd.get(t.id, 0)) >= 0.35 else "not you, yet")
		_p("Wants %s (%s), or %s (%s)." % [wants[0].type.want, you.call(wants[0].type), wants[1].type.want, you.call(wants[1].type)], d, Look.TXT, 14)
	var gpops: Array = G.pops_matching(S, g.who)
	var follows: Array = G.group_media(S, gpops).filter(func(x): return x.reach >= 0.06).slice(0, 3)
	if follows.size():
		var bits = follows.map(func(x): return "%s (%s)" % [x.outlet.name, favour_word(float(S.media[x.outlet.id].get("favour", {}).get("player", 0))).to_lower()])
		_p("Follows: %s." % ", ".join(bits), d, Look.TXT, 14)
	var shield: float = G.group_shield(gpops, "player")
	if shield >= 0.2: _p("Their media is on your side: they'll forgive you a lot.", d, Look.GOOD_HI, 14)
	elif shield >= 0.08: _p("Their media gives you some cover: they'll forgive you a little.", d, Look.TXT, 14)
	var rival_cover = G.rivals(S).filter(func(p): return G.group_shield(gpops, p.id) >= 0.2)
	if rival_cover.size(): _p("Their media protects %s: hard to win over." % " and ".join(rival_cover.map(func(p): return p.short)), d, Look.RED_HI, 14)
	if sum.leaderPull > 1.12: _p("Votes on personality more than most.", d, Look.RED_HI)
	elif sum.leaderPull < 0.88: _p("Hard to win over with personality alone.", d, Look.RED_HI)
	_eyebrow("Cares most about", d)
	var issues: Array = Game.ssort(G.AXES.duplicate(), func(a, b): return sum.sal[b.id] - sum.sal[a.id]).slice(0, 3)
	var ir = _row(d, 6)
	for a in issues: _chip(a.issue, ir)
	_eyebrow("Leanings", d)
	var leans: Array = G.AXES.filter(func(a): return absf(sum.pos[a.id]) > 12)
	leans = Game.ssort(leans, func(a, b): return absf(sum.pos[b.id]) - absf(sum.pos[a.id])).slice(0, 4)
	if leans.is_empty(): _p("No strong leanings. A swing group.", d)
	for a in leans: _add(Look.dlabel(_lean_label(sum.pos[a.id], a), "body_bold", 15, Look.TXT), d)
	_eyebrow("Vote intention · " + (poll.label if poll else "no poll yet"), d)
	if entry: _bars(entry.support, prev.support if prev else null, d)


## The region's cities: who lives there, how they lean, and your office (open or grow it here).
func _region_cities(region: String, to: Control) -> void:
	var cities: Array = G.country_cities().filter(func(c): return c.area == region)
	if cities.is_empty(): return
	_eyebrow("Cities", to)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_add(grid, to)
	var left: int = S.actionsLeft
	for c in Game.ssort(cities, func(a, b): return int(b.get("size", 1)) - int(a.get("size", 1))):
		var card = _card(grid)
		card.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var marks = (" ★" if c.name == G.MAP.capital else "") + ("  ⌂ your home" if S.get("home", "") == c.name else "")
		card.add_child(Look.dlabel(c.name + marks, "display", 20, Look.TXT))
		card.add_child(Look.dlabel("About %s people" % _people(G.city_population(c)), "body", 13, Look.DIM))
		var pos: Dictionary = G.city_leanings(S, c)
		var leans: Array = G.AXES.filter(func(a): return absf(pos[a.id]) > 12)
		leans = Game.ssort(leans, func(a, b): return absf(pos[b.id]) - absf(pos[a.id])).slice(0, 3)
		card.add_child(Look.dlabel(", ".join(leans.map(func(a): return _lean_label(pos[a.id], a))) if leans.size() else "No strong leanings", "body_bold", 14, Look.TXT, true))
		var fact: String = G.city_fact(c)
		if fact != "": card.add_child(Look.dlabel(fact, "body_italic", 13, Look.TXT, true))
		var lvl: int = G.community_level(S, c.name)
		var pips = "●".repeat(lvl) + "○".repeat(G.COMMUNITY_MAX - lvl)
		var row = _row(card, 8)
		row.add_child(Look.dlabel("Party office " + pips, "body", 13, Look.TXT))
		if lvl < G.COMMUNITY_MAX:
			var cost: float = G.COMMUNITY_COST[lvl]
			var b = _btn(("Open an office" if lvl == 0 else "Grow it") + " · ₱%sM" % Game.fmt1(cost), func(): _did(G.act_community(S, c.name)),
				S.result != null or left <= 0 or S.money < cost or G.in_campaign(S), lvl == 0)
			b.tooltip_text = "Uses one of this month's actions. A community works every month on its own province: it turns your supporters there into core voters and gets them to the polls."
			row.add_child(b)

func _people(n: float) -> String:
	if n >= 1e6: return "%s million" % Game.fmt1(n / 1e6)
	return "%dk" % (Game.jround(n / 10000.0) * 10)

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
	if S.get("home", "") != "": _p("Former mayor of %s" % S.home, c1, Look.DIM, 13)
	var fl = S.get("flagship", {})
	if typeof(fl) == TYPE_DICTIONARY and not fl.is_empty():
		_add(Look.dlabel("Flagship promise: %s" % fl.label, "body_bold", 14, Look.RED_HI, true), c1)
		_add(Look.dlabel("“%s”" % fl.quote, "news_italic", 15, Look.TXT, true), c1)
	var seen = G.view_label(player.perceived)
	var meant = G.view_label(player.manifesto)
	_add(Look.dlabel("Voters see you as: %s%s" % [seen, "" if seen == meant else " (your manifesto says %s)" % meant.to_lower()], "body_bold", 14, Look.RED_HI if seen != meant else Look.TXT, true), c1)
	var dev: float = nation.devotion
	_facts([
		["Charisma", charisma_word(player.charisma)],
		["Personal image", "%s (%s)" % [leader_words(nation.leader), leader_score(nation.leader)]],
		["Speaking style", G.style_profile(S).label],
		["Comes across as", G.leader_image(S, player)[0].type.label if G.LEADER_TYPES.size() else "—"],
		["Devotion", "Fanatical" if dev > 0.4 else ("Strong" if dev > 0.2 else ("Growing" if dev > 0.08 else "Little"))],
		["Would follow you anywhere", ("%sM" % Game.fmt1(nation.followers / 1e6)) if nation.followers >= 1e6 else "%dk" % Game.jround(nation.followers / 1000.0)],
	], c1, 2)
	_p("Your style comes from the words you choose: a recognisable voice builds charisma. Devoted voters care less about your positions and forgive flip-flops. What kind of leader you come across as depends on your words, your record and your positions; each group wants a different kind (see the Electorate file), and a crisis, a war, hard times or low trust change what they want.", c1)
	var state: Array = ["Consistent", "Voters believe you mean what you say."] if inc < 0.5 else (["Wobbling", "A few voters have noticed you changing your tune."] if inc < 2 else (["Unreliable", "Your core supporters are leaving, and engaged voters punish you."] if inc < 5 else ["Flip-flopper", "Nobody knows what you stand for. Your base is collapsing."]))
	_add(Look.dlabel("Consistency: %s. %s" % [state[0], state[1]], "body_bold", 13, Look.RED_HI if inc >= 2 else Look.TXT, true), c1)
	var flips: Array = S.flips.filter(func(f): return f.party == "player" and S.week - f.week < G.C.flipMemoryWeeks)
	flips.reverse()
	if flips.size(): _add(Look.dlabel("Changed stance: " + "; ".join(flips.slice(0, 3).map(func(f): return "%s → %s (%s)" % [G.stance_name(f.axis, f.from).to_lower(), G.stance_name(f.axis, f.to).to_lower(), G.date_label(f.week, false)])), "body", 12, Look.DIM, true), c1)
	# party offices
	var c2 = _card(top)
	c2.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_eyebrow("Party offices", c2)
	var blocked_o: bool = S.queue.size() > 0 or S.result != null or S.actionsLeft <= 0 or G.in_campaign(S)
	_p("Open an office in a city, then grow it (one action, ₱1–2M). It works every month on its own province: supporters there become core voters and turn out, and members pay a little in dues; rent is ₱10–20k a quarter. You can also open one by clicking the province on the map.", c2)
	var up: Dictionary = G.C.upkeep
	var pr_row = HBoxContainer.new()
	pr_row.add_theme_constant_override("separation", 10)
	var pr_txt = Look.dlabel("Press office: %s" % ("open. Gaffes cost you a quarter less." if S.get("pressOffice", false) else "none. One would soften every gaffe by a quarter (rent ₱%dk a quarter)." % Game.jround(float(up.press) * 1000)), "body", 13, Look.TXT, true)
	pr_txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pr_row.add_child(pr_txt)
	if not S.get("pressOffice", false):
		var pb = _btn("Open a press office · ₱%sM" % Game.fmt1(float(up.pressCost)), func(): _did(G.act_press_office(S)), blocked_o or S.money < float(up.pressCost))
		pb.tooltip_text = "Uses one of this month's actions. It doesn't stop gaffes; it explains them away faster."
		pr_row.add_child(pb)
	c2.add_child(pr_row)
	for r in G.REGIONS:
		var line = HFlowContainer.new()
		line.add_theme_constant_override("h_separation", 6)
		line.add_theme_constant_override("v_separation", 6)
		var rl = Look.dcaps(r.name, 10, Look.DIM, 1)
		rl.custom_minimum_size.x = 70
		line.add_child(rl)
		for c in G.MAP.cities:
			if c.area != r.id: continue
			var lvl: int = G.community_level(S, c.name)
			var cost: float = G.COMMUNITY_COST[lvl] if lvl < G.COMMUNITY_MAX else 0.0
			var b = _btn("%s %s" % [c.name, "●".repeat(lvl) + "○".repeat(G.COMMUNITY_MAX - lvl)], func(): _did(G.act_community(S, c.name)), lvl >= G.COMMUNITY_MAX or blocked_o or S.money < cost, lvl > 0)
			b.tooltip_text = ("Full size." if lvl >= G.COMMUNITY_MAX else ("Open an office: ₱%sM" % Game.fmt1(cost) if lvl == 0 else "Grow it: ₱%sM" % Game.fmt1(cost)))
			b.add_theme_font_size_override("font_size", Look.fs(11))
			line.add_child(b)
		c2.add_child(line)
	_rule()
	var lg = _row(null, 14)
	lg.add_child(Look.dlabel("■ Manifesto", "body", 12, Look.RED_HI))
	lg.add_child(Look.dlabel("● How voters see you", "body", 12, Look.RED_HI))
	for p in G.rivals(S): lg.add_child(Look.dlabel("● " + p.short, "body", 12, Color(p.color)))
	var blocked: bool = S.queue.size() > 0 or S.result != null or S.actionsLeft <= 0
	if S.steer:
		var sax = Game.by_id(G.AXES, S.steer.axis)
		_p("Steering the party on %s toward %s: month %d of %d. The people who disagree get angrier every month." % [sax.issue.to_lower(), G.stance_name(S.steer.axis, G.stance_of(player.manifesto[S.steer.axis]) + S.steer.dir).to_lower(), S.steer.months + 1, G.STEER_MONTHS], null, Look.RED_HI, 14)
	else:
		_p("Steering the party moves the manifesto one stance. It takes three months and an action, and the politicians who care about the other side may quit. Once it's done, saying the new line no longer counts as drifting.", null, Look.DIM, 13)
	for ax in G.AXES:
		var t = AxisTrack.new(G, S, ax, player)
		t.custom_minimum_size.y = 62
		_add(t)
		var st: int = G.stance_of(player.manifesto[ax.id])
		var sr = _row(null, 8)
		for dir in [-1, 1]:
			if st + dir < 0 or st + dir > 4: continue
			var rx: Dictionary = G.steer_reactions(S, ax.id, dir)
			var b = _btn(("◀ Steer toward %s" if dir < 0 else "Steer toward %s ▶") % ax.stances[st + dir].to_lower(), func():
				var res: Dictionary = G.act_steer(S, ax.id, dir)
				toast.emit(res.text)
				changed.emit(), blocked or G.steer_block(S, ax.id, dir) != "")
			var tip = "One action, three months."
			if rx.angry.size(): tip += "\nAngers: " + ", ".join(rx.angry.map(func(f): return f.name))
			if rx.pleased.size(): tip += "\nPleases: " + ", ".join(rx.pleased.map(func(f): return f.name))
			b.tooltip_text = tip
			b.add_theme_font_size_override("font_size", Look.fs(11))
			sr.add_child(b)
	# what only you know
	var secs: Array = S.get("secrets", []).filter(func(x): return not x.get("closed", false) and not x.get("leaked", false))
	if secs.size():
		_rule()
		_eyebrow("What only you know")
		_p("Things the public doesn't know, and might one day. The bigger you get, and the more honest outlets dislike you, the likelier they come out. When one does, how you answer decides what it costs.", null, Look.DIM, 13)
		for x in secs:
			var c = _card()
			var srow = HBoxContainer.new()
			c.add_child(srow)
			var snm = Look.dlabel(x.title, "display", 17, Look.TXT, true)
			snm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			srow.add_child(snm)
			var r: float = G.secret_risk(S, x)
			srow.add_child(Look.dlabel(G.risk_word(r), "body_bold", 13, Look.RED_HI if r >= 0.025 else Look.TXT))
			c.add_child(Look.dlabel(x.get("what", ""), "body_italic", 13, Look.DIM, true))
	# the people in the party
	_rule()
	_eyebrow("Your party's politicians")
	_p("They are the party's faces in the regions, and they joined for the manifesto. Each cares most about one issue: keep to it and they stay; steer the manifesto or speak against their side and their loyalty drops. Below 25 they quit, and someone who agrees with you takes the chair: loyal, but usually less able.", null, Look.DIM, 13)
	var pg = GridContainer.new()
	pg.columns = 3 if size.x > 1100 else 1
	pg.add_theme_constant_override("h_separation", 12)
	pg.add_theme_constant_override("v_separation", 12)
	_add(pg)
	for f in S.figures:
		var c = _card(pg)
		c.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var top2 = HBoxContainer.new()
		c.add_child(top2)
		var nm = Look.dlabel(f.name, "display", 18, Look.TXT)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top2.add_child(nm)
		top2.add_child(Look.dlabel(G.loyalty_word(f.loyalty), "body_bold", 13, Look.RED_HI if f.loyalty < 40 else (Look.GOOD_HI if f.loyalty >= 55 else Look.TXT)))
		var from: String = (" · from %s" % f.hometown) if str(f.get("hometown", "")) != "" else ""
		c.add_child(Look.dlabel("%s · %s · %s%s" % [f.role, Game.by_id(G.REGIONS, f.region).name, G.skill_word(float(f.get("skill", 70))), from], "body", 12, Look.DIM, true))
		var lb = Bar.new(Look.RED if f.loyalty < 40 else Look.LAMP_DIM, f.loyalty / 100.0)
		lb.custom_minimum_size.y = 6
		c.add_child(lb)
		var fax = Game.by_id(G.AXES, f.axis)
		c.add_child(Look.dlabel("Cares about: %s" % (fax.left if f.side == "L" else fax.right).to_lower() + (" ★" if G.manifesto_side(S, f.axis) == f.side else (" (against your manifesto)" if G.manifesto_side(S, f.axis) != "" else "")), "body_bold", 12, Look.TXT, true))
		c.add_child(Look.dlabel(f.note, "body_italic", 12, Look.DIM, true))
		if f.get("doubter", false) and G.manifesto_side(S, f.axis) != "" and G.manifesto_side(S, f.axis) != f.side:
			c.add_child(Look.dlabel("Joined for you, not the manifesto. Losing patience every month; speaking up for their side buys time.", "body", 12, Look.RED_HI, true))
	if S.figuresLost.size():
		_p("Gone: " + ", ".join(S.figuresLost.map(func(x): return "%s (%s)" % [x.name, x.role.to_lower()])), null, Look.RED_HI, 13)

class DriftMeter extends Control:
	var v: float
	func _init(x: float) -> void: v = x
	func _draw() -> void:
		var y = size.y / 2 - 5
		var cols = [Look.GOOD_HI, Look.LAMP, Color("e8843c"), Look.RED]
		var widths = [0.2, 0.2, 0.2, 0.4]
		var x = 0.0
		for i in 4:
			draw_rect(Rect2(x, y, size.x * widths[i], 10), cols[i])
			x += size.x * widths[i]
		draw_rect(Rect2(size.x * v - 2, 0, 4, size.y), Look.TXT)

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
		draw_string(f, Vector2(0, 14), ax.left, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Look.TXT)
		var rw = f.get_string_size(ax.right, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(f, Vector2(size.x - rw, 14), ax.right, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Look.TXT)
		var y = 20.0
		var h = 22.0
		var ms: int = G.stance_of(party.manifesto[ax.id])
		var ps: int = G.stance_of(party.perceived[ax.id])
		for i in 5:
			var r = Rect2(size.x * i / 5.0 + 1, y, size.x / 5.0 - 2, h)
			draw_rect(r, Look.N700)
			if i == ms:
				draw_rect(r, Color(Look.RED, 0.3))
				draw_rect(r, Look.RED_HI, false, 2.0)
			elif i == ps:
				draw_rect(r, Color(Look.RED, 0.2))
		var px = func(v: float) -> float: return (v + 100) / 200.0 * size.x
		for p in G.rivals(S):
			draw_circle(Vector2(px.call(p.perceived[ax.id]), y + h / 2), 5, Look.N850)
			draw_circle(Vector2(px.call(p.perceived[ax.id]), y + h / 2), 4, Look.lit(Color(p.color)))
		draw_circle(Vector2(px.call(party.perceived[ax.id]), y + h / 2), 8, Look.N850)
		draw_circle(Vector2(px.call(party.perceived[ax.id]), y + h / 2), 7, Look.RED_HI)
		var off = absi(ps - ms)
		var txt = ("Seen as %s, manifesto says %s%s" % [ax.stances[ps], ax.stances[ms], " · serious" if off > 1 else ""]) if off else "%s, as promised" % ax.stances[ps]
		draw_string(f, Vector2(0, y + h + 16), txt, HORIZONTAL_ALIGNMENT_LEFT, size.x, 12, Look.RED_HI if off else Look.DIM)

# ---------- This month's moves ----------
func _section(title: String, cost: String, help: String) -> void:
	_rule()
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	_add(h)
	h.add_child(Look.dlabel(title, "display", 20, Look.TXT))
	var c = Look.dlabel(cost, "body", 12, Look.DIM)
	c.size_flags_vertical = Control.SIZE_SHRINK_END
	h.add_child(c)
	_p(help)

func _did(res: Dictionary) -> void:
	toast.emit(res.text)
	changed.emit()

# ---------- The national debate ----------
func _who(id: String) -> String:
	if id == "player": return "you"
	if id == "news": return "the news"
	if id == "economy": return "the economy"
	if id.begins_with("media:"):
		var o = G.outlet_by_id(id.trim_prefix("media:"))
		return o.name if o else "the media"
	var p = G.party_of(S, id)
	return p.short if p else id

func _debates() -> void:
	var blocked: bool = S.queue.size() > 0 or S.result != null
	var left: int = S.actionsLeft
	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 40)
	_add(head)
	var hl = VBoxContainer.new()
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hl)
	_eyebrow("What %s is arguing about" % G.COUNTRY.name, hl)
	_p("Join a debate by speaking for one side. In a major debate the whole country is watching: your exact words get quoted, and can go viral or become a gaffe. In smaller ones a line mostly shapes how you come across.", hl, Look.TXT, 14)
	var cs = _row(hl, 6)
	cs.add_child(Look.dcaps("Your causes (%d of %d)" % [S.signature.size(), int(G.C.maxSignatureIssues)], 11, Look.DIM, 1))
	if S.signature.is_empty(): cs.add_child(Look.dlabel("None yet. Speak for a side, then make it yours.", "body", 12, Look.DIM))
	for key in S.signature:
		cs.add_child(_btn("★ %s · drop" % G.side_label(key), func(): G.drop_signature(S, key); changed.emit(), blocked))
	for pr in [["Actions this month", "%d of %d left" % [left, int(G.C.actionsPerMonth)]], ["Your reach", "%s (×%s)" % [G.influence_label(S), Game.fmt1(G.debate_reach(S))]]]:
		var b = VBoxContainer.new()
		b.add_child(Look.dcaps(pr[0], 10, Look.DIM, 1))
		b.add_child(Look.dlabel(pr[1], "display", 24, Look.TXT))
		head.add_child(b)
	if blocked and not S.result: _p("Finish the decision on your desk first.", null, Look.RED_HI, 14)
	var grid = GridContainer.new()
	grid.columns = 2 if size.x > 1100 else 1
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	_add(grid)
	var list: Array = Game.ssort(S.debates.duplicate(), func(a, b): return b.heat - a.heat)
	if list.is_empty(): _p("The country is quiet. Nobody is arguing about anything in particular. Start something.", null, Look.TXT, 15)
	for d in list: _debate_card(d, grid, blocked or left <= 0)
	# start a debate
	_rule()
	var sh = HBoxContainer.new()
	sh.add_theme_constant_override("separation", 10)
	_add(sh)
	sh.add_child(Look.dlabel("Start a debate", "display", 22, Look.TXT))
	var cost = Look.dlabel("One action · one try a month", "body", 12, Look.DIM)
	cost.size_flags_vertical = Control.SIZE_SHRINK_END
	sh.add_child(cost)
	if S.agenda.done:
		_p("You have tried to start this month's debate. New ideas next month.", null, Look.TXT, 14)
	else:
		_p("Put something in front of the country. It may catch on, or nobody may pick it up: your reach and your words decide. A story already in the headlines catches most easily. Proposals have consequences that come back in the months ahead.", null, Look.DIM, 13)
		var opts: Array = G.raise_options(S)
		for grp in [["issue", "In the news"], ["metric", "The state of the country"], ["gov", "The government's record"], ["proposal", "Proposals"]]:
			var these = opts.filter(func(o): return o.kind == grp[0])
			if these.is_empty(): continue
			_eyebrow(grp[1])
			var ig = GridContainer.new()
			ig.columns = 3 if size.x > 1100 else 1
			ig.add_theme_constant_override("h_separation", 14)
			ig.add_theme_constant_override("v_separation", 14)
			_add(ig)
			for opt in these: _raise_card(opt, ig, blocked or left <= 0)
	# settled arguments
	if S.debatesPast.size():
		_rule()
		_eyebrow("Arguments that have settled")
		var n = 0
		for i in range(S.debatesPast.size() - 1, -1, -1):
			if n >= 6: break
			var x: Dictionary = S.debatesPast[i]
			var verdict = "nobody won" if absf(x.lean) < 20 else ("%s won" % G.side_of_lean(x.axis, x.lean).to_lower())
			_p("%s · %s — %s (peak heat %d)" % [G.date_label(x.week, false), x.title, verdict, Game.jround(x.peak)], null, Look.TXT, 13)
			n += 1

func _debate_card(d: Dictionary, to: Control, blocked: bool) -> void:
	var ax: Dictionary = Game.by_id(G.AXES, d.axis)
	var p = PanelContainer.new()
	var hot: bool = d.heat >= 50
	var sb = Look.box(Look.N800, 2, Color.TRANSPARENT, 0, 0, 16)
	sb.border_width_top = 2; sb.border_color = Look.RED if hot else Look.N500
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	to.add_child(p)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var hist: Array = d.history
	var trend = ""
	if hist.size() > 1:
		var dd: float = d.heat - hist[-2]
		trend = "rising" if dd > 3 else ("cooling" if dd < -3 else "steady")
	v.add_child(Look.dcaps("%s · started by %s · %s" % [ax.issue, _who(d.source), G.date_label(d.started, false)], 10, Look.DIM, 1))
	v.add_child(Look.dlabel(d.title, "news_bold", 22, Look.TXT, true))
	var tx = Look.dlabel(d.text, "body", 13, Look.DIM, true)
	tx.max_lines_visible = 3
	v.add_child(tx)
	# heat
	var hr = HBoxContainer.new()
	hr.add_theme_constant_override("separation", 8)
	var hl = Look.dcaps("Heat", 10, Look.DIM, 1)
	hl.custom_minimum_size.x = 46
	hr.add_child(hl)
	var bar = Bar.new(Look.RED if hot else Look.LAMP_DIM, d.heat / 100.0)
	bar.custom_minimum_size.y = 12
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hr.add_child(bar)
	var hv = Look.dlabel("%d %s" % [Game.jround(d.heat), trend], "body_bold", 12, Look.RED_HI if trend == "rising" else Look.TXT)
	hv.custom_minimum_size.x = 84
	hr.add_child(hv)
	v.add_child(hr)
	# tug of war
	var owners = {}
	for r in G.ownership_table(S):
		if r.axis == d.axis and r.owners.size(): owners[r.key.split(":")[1]] = r.owners
	var mine: String = G.manifesto_side(S, d.axis)
	var tug = Tug.new(d.lean)
	tug.custom_minimum_size.y = 16
	v.add_child(tug)
	var sides = HBoxContainer.new()
	for side in ["L", "R"]:
		var b = VBoxContainer.new()
		b.add_theme_constant_override("separation", 0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name: String = ax.left if side == "L" else ax.right
		var nl = Look.dlabel(("★ " if mine == side else "") + name, "body_bold", 13, Look.TXT)
		var own_txt = "owned by " + ", ".join(owners[side].slice(0, 2).map(func(o): return G.party_of(S, o.party).short)) if owners.has(side) else "nobody owns it"
		var ol = Look.dlabel(own_txt, "body", 11, Look.DIM)
		if side == "R":
			nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			ol.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.add_child(nl); b.add_child(ol)
		sides.add_child(b)
	v.add_child(sides)
	var movers: Array = G.debate_movers(S, d)
	if movers.size():
		var words = []
		for m in movers:
			var who = _who(m.party)
			var w = "%s %s" % [who.substr(0, 1).to_upper() + who.substr(1), {"fan": "fanned it", "cool": "played it down", "start": "started it"}[m.kind]]
			if m.side != "" and m.kind != "cool": w += " (%s)" % (ax.left if m.side == "L" else ax.right).to_lower()
			if not words.has(w): words.append(w)
		v.add_child(Look.dlabel(" · ".join(words.slice(-3)), "body_italic", 12, Look.TXT, true))
	# moves
	if G.is_major(d): v.add_child(Look.dcaps("Major debate · your exact words will be quoted", 10, Look.RED_HI, 1))
	var row = HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 6)
	# one statement per debate: once you've spoken (or answered the event behind it), that's your position
	if d.has("you"):
		var said: String = "You spoke for %s." % (ax.left if d.you.side == "L" else ax.right).to_lower() if d.you.side != "" else "You've had your say."
		v.add_child(Look.dlabel("%s “%s”" % [said, d.you.quote], "body_italic", 13, Look.TXT, true))
	for side in ([] if d.has("you") else ["L", "R"]):
		var pv: Dictionary = G.fan_preview(S, d, side)
		var tip = "Heat +%d, pushes the argument toward %s." % [Game.jround(pv.heat), pv.side.to_lower()]
		if pv.shift.from != pv.shift.to: tip += "\nVoters will see you move from %s to %s on %s." % [G.stance_name(d.axis, pv.shift.from), G.stance_name(d.axis, pv.shift.to), ax.issue.to_lower()]
		if mine != "" and mine != side: tip += "\nThis is against your manifesto."
		if pv.mine: tip += "\nIt's one of your causes: your claim on it grows."
		elif pv.owner != "" and pv.owner != "player": tip += "\n%s owns this side, so the attention helps them too." % G.party_of(S, pv.owner).short
		var b = _btn("Speak for " + pv.side.to_lower(), func(): speak.emit(d.id, side), blocked, mine == side)
		b.tooltip_text = tip
		row.add_child(b)
	for side in ["L", "R"]:
		var key = Game.side_key(d.axis, side)
		if S.spoke.has(key) and not S.signature.has(key):
			var mb = _btn("Make %s our cause" % (ax.left if side == "L" else ax.right).to_lower(), func():
				var res: Dictionary = G.act_claim(S, d.axis, side)
				toast.emit(res.text)
				changed.emit(), G.claim_block(S, d.axis, side) != "")
			mb.tooltip_text = G.claim_block(S, d.axis, side) if G.claim_block(S, d.axis, side) != "" else "Free. Every time you speak for it, your claim on the issue grows, and heat on it helps you most."
			row.add_child(mb)
	v.add_child(row)

func _raise_card(opt: Dictionary, to: Control, blocked: bool) -> void:
	var ax: Dictionary = Game.by_id(G.AXES, opt.axis)
	var card = PanelContainer.new()
	var sb = Look.box(Look.N800, 2, Color.TRANSPARENT, 0, 0, 14)
	sb.border_width_top = 2; sb.border_color = Look.RED if opt.kind == "proposal" else Look.N500
	var hv = sb.duplicate(); hv.bg_color = Look.N700; hv.border_color = Look.LAMP
	card.add_theme_stylebox_override("panel", sb)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_default_cursor_shape = Control.CURSOR_ARROW if blocked else Control.CURSOR_POINTING_HAND
	if blocked: card.modulate.a = 0.55
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var kind_word = {"proposal": "Proposal", "issue": ("In the headlines" if opt.get("fresh", false) else "Fading from the news"), "metric": "The state of the country", "gov": "The government's record"}.get(opt.kind, "Topic")
	var where = (" · " + Game.by_id(G.REGIONS, opt.region).name) if opt.has("region") else ""
	v.add_child(Look.dcaps("%s · %s%s · about %d%% to catch on" % [kind_word, ax.issue, where, Game.jround(opt.chance * 100)], 10, Look.RED_HI if opt.get("fresh", false) else Look.DIM, 1))
	v.add_child(Look.dlabel(opt.title, "news_bold", 19, Look.TXT, true))
	var tx = Look.dlabel(opt.text, "body", 13, Look.DIM, true)
	tx.max_lines_visible = 3
	v.add_child(tx)
	if opt.kind == "proposal":
		var dsc: Dictionary = G.describe_choice(S, Game.by_id(G.INITIATIVES, opt.ref).effects)
		if dsc.appeals.size(): v.add_child(Look.dlabel("Appeals to: " + ", ".join(dsc.appeals.map(func(x): return x.text)), "body", 12, Look.GOOD_HI, true))
		if dsc.angers.size(): v.add_child(Look.dlabel("Angers: " + ", ".join(dsc.angers.map(func(x): return x.text)), "body", 12, Look.RED_HI, true))
		v.add_child(Look.dlabel("You argue for %s · expect consequences" % (ax.left if opt.side == "L" else ax.right).to_lower(), "body_italic", 12, Look.DIM, true))
	for c in v.get_children(): c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	if not blocked:
		card.mouse_entered.connect(func(): card.add_theme_stylebox_override("panel", hv))
		card.mouse_exited.connect(func(): card.add_theme_stylebox_override("panel", sb))
		card.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: raise.emit(opt))
	to.add_child(card)

## Which side is winning: a marker between the two ends.
class Tug extends Control:
	var lean := 0.0
	func _init(l: float) -> void:
		lean = l
	func _draw() -> void:
		var y = size.y / 2
		draw_rect(Rect2(0, y - 3, size.x, 6), Look.N700)
		var mid = size.x / 2
		var x = mid + lean / 100.0 * mid
		draw_rect(Rect2(minf(mid, x), y - 3, absf(x - mid), 6), Look.RED if absf(lean) > 35 else Look.LAMP_DIM)
		draw_line(Vector2(mid, 0), Vector2(mid, size.y), Look.DIM, 1)
		draw_circle(Vector2(x, y), 7, Look.TXT)
		draw_circle(Vector2(x, y), 4, Look.N850)

# ---------- The country ----------
const IND_EFFECT := {
	"jobs": "When jobs are scarce, jobs and the economy matter more to voters, trust falls and the government suffers.",
	"prices": "Rising prices make the economy and public services matter more, cost the government support and push up unrest.",
	"migration": "High migration makes immigration a bigger issue, especially in Yamlin, and holds down wages.",
	"border": "Border tension makes defence and national identity matter more, and pushes prices up. Governments gain a little from a crisis.",
	"unrest": "An angry public makes the political system itself the issue. Outsiders feed on it.",
}

## The country's problems, big and small. Any of them can be raised as a debate.
func _country_issues() -> void:
	var blocked: bool = S.queue.size() > 0 or S.result != null or S.agenda.done or S.actionsLeft <= 0
	var opts: Array = G.raise_options(S)
	var two = HBoxContainer.new()
	two.add_theme_constant_override("separation", 12)
	_add(two)
	# major issues
	var mc = _card(two)
	mc.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mc.get_parent().size_flags_stretch_ratio = 1.0
	_eyebrow("Major issues", mc)
	var majors = []
	if S.crisis:
		var cr = Game.by_id(G.CRISES, S.crisis.id)
		majors.append([cr.name, cr.blurb, null])
	for ind in G.METRIC_TOPIC:
		var bad: float = G.metric_badness(S, ind)
		if bad < 0.25: continue
		var lbl = Game.by_id(G.INDICATORS, ind).label
		var opt = null
		for o in opts:
			if o.kind == "metric" and o.metric == ind: opt = o
		majors.append(["%s: %s" % [lbl, G.indicator_word(ind, w_of(ind)).to_lower()], IND_EFFECT.get(ind, ""), opt, bad])
	if majors.is_empty(): _p("Nothing is badly wrong. For now.", mc, Look.TXT, 14)
	for m in majors:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var tv = VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_theme_constant_override("separation", 0)
		tv.add_child(Look.dlabel(m[0], "body_bold", 15, Look.RED_HI if m.size() > 3 and m[3] > 0.6 else Look.TXT, true))
		tv.add_child(Look.dlabel(m[1], "body", 12, Look.DIM, true))
		row.add_child(tv)
		if m[2] != null:
			var opt: Dictionary = m[2]
			var b = _btn("Raise issue", func(): raise.emit(opt), blocked)
			b.tooltip_text = "Start a national debate about it. About %d%% chance it catches on." % Game.jround(opt.chance * 100)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(b)
		elif m.size() > 3:
			var t = Look.dcaps("Being debated", 10, Look.RED_HI, 1)
			t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(t)
		mc.add_child(row)
	# minor issues
	var nc = _card(two)
	nc.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_eyebrow("Smaller issues in the news", nc)
	var minors = opts.filter(func(o): return o.kind == "issue")
	if minors.is_empty(): _p("A quiet month in the local papers.", nc, Look.TXT, 14)
	for opt in minors:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var tv = VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_theme_constant_override("separation", 0)
		tv.add_child(Look.dcaps("%s · %s" % [opt.province if String(opt.get("province", "")) != "" else Game.by_id(G.REGIONS, opt.region).name, "in the headlines" if opt.fresh else "fading"], 10, Look.RED_HI if opt.fresh else Look.DIM, 1))
		tv.add_child(Look.dlabel(opt.title, "body_bold", 15, Look.TXT, true))
		var tx = Look.dlabel(opt.text, "body", 12, Look.DIM, true)
		tv.add_child(tx)
		row.add_child(tv)
		var b = _btn("Raise issue", func(): raise.emit(opt), blocked)
		b.tooltip_text = "Make it a national debate. About %d%% chance it catches on." % Game.jround(opt.chance * 100)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
		nc.add_child(row)
	if blocked and not S.agenda.done and S.actionsLeft > 0 and S.queue.size(): _p("Finish the decision on your desk first.", null, Look.RED_HI, 13)
	elif S.agenda.done: _p("You've already tried to start a debate this month.", null, Look.DIM, 13)

func w_of(ind: String) -> float:
	return S.world[ind]

func _country() -> void:
	var w: Dictionary = S.world
	var hist: Array = S.get("worldHistory", [])
	_country_issues()
	_eyebrow("The state of the nation")
	var g = GridContainer.new()
	g.columns = 5 if size.x > 1200 else 2
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	_add(g)
	for ind in G.INDICATORS:
		var c = _card(g)
		c.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.add_child(Look.dcaps(ind.label, 10, Look.DIM, 1))
		var top = HBoxContainer.new()
		var wl = Look.dlabel(G.indicator_word(ind.id, w[ind.id]), "display", 20, Look.TXT, true)
		wl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(wl)
		top.add_child(Look.dlabel(str(Game.jround(w[ind.id])), "display", 20, Look.DIM))
		c.add_child(top)
		var vals: Array = hist.slice(-24).map(func(x): return x[ind.id])
		vals.append(w[ind.id])
		var bad_up = ind.good == "low"
		var sp = Spark.new(vals, Look.RED_HI if (ind.good != null and ((vals[-1] > vals[0]) == bad_up) and absf(vals[-1] - vals[0]) > 2) else Look.TXT)
		sp.custom_minimum_size = Vector2(0, 40)
		c.add_child(sp)
		var dl: float = vals[-1] - (vals[-2] if vals.size() > 1 else vals[-1])
		var good = null if ind.good == null else ((dl > 0) if ind.good == "high" else (dl < 0))
		c.add_child(Look.dlabel("steady this month" if absf(dl) < 1.5 else ("%s %d this month" % ["▲" if dl > 0 else "▼", Game.jround(absf(dl))]), "body_bold", 12, Look.DIM if (good == null or absf(dl) < 1.5) else (Look.GOOD_HI if good else Look.RED_HI)))
		c.add_child(Look.dlabel(IND_EFFECT.get(ind.id, ""), "body", 12, Look.DIM, true))
	if S.crisis:
		var cr = Game.by_id(G.CRISES, S.crisis.id)
		_p("%s: %s" % [cr.name, cr.blurb], null, Look.RED_HI, 15)
	_p("Your statements nudge these a little, more the more seriously you are taken. Taken seriously: %d of 100 (%s)." % [Game.jround(G.serious_of(S)), G.influence_label(S).to_lower()])
	# government and trust
	var two = HBoxContainer.new()
	two.add_theme_constant_override("separation", 12)
	_add(two)
	var gov = null
	var partners = []
	for p in S.parties:
		if p.ruling: gov = p
		elif p.get("partner", false): partners.append(p.short)
	var gc = _card(two)
	gc.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_eyebrow("The government", gc)
	if gov:
		gc.add_child(Look.dlabel("%s · %s" % [gov.name, gov.leader], "display", 22, Look.lit(Color(gov.color)), true))
		if partners.size(): gc.add_child(Look.dlabel("In coalition with the %s, the junior partner" % " and the ".join(partners), "body", 14, Look.DIM))
		var unsolved: Array = S.issues.filter(func(x): return x.get("back", false)).map(func(x): return String(G.story(S, x.id).title))
		if unsolved.size(): gc.add_child(Look.dlabel("Still unsolved: " + "; ".join(unsolved), "body", 14, Look.TXT, true))
		var troubles = []
		if w.jobs < 42: troubles.append("jobs")
		if w.prices > 60: troubles.append("prices")
		if w.unrest > 60: troubles.append("the public mood")
		_facts([["Hold on power", stability_word(gov.stability)], ["Blamed for", ", ".join(troubles).capitalize() if troubles.size() else "Nothing in particular"], ["Border crisis", "Rallies people behind it" if w.border > 65 else "No effect"]], gc)
		_p("A government in trouble loses voters to whoever looks ready to replace it, and its parties get restless (a junior partner half as much).", gc)
	var tc = _card(two)
	tc.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_eyebrow("Trust in politics", tc)
	var th = HBoxContainer.new()
	var tl = Look.dlabel(Game.trust_label(S.trust), "display", 22, Look.TXT)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(tl)
	th.add_child(Look.dlabel(str(Game.jround(S.trust)), "display", 22, Look.DIM))
	tc.add_child(th)
	var sp2 = Spark.new(S.trustHistory.slice(-36).map(func(x): return x.trust))
	sp2.custom_minimum_size = Vector2(0, 46)
	tc.add_child(sp2)
	_p("How much people trust politicians and the system, not any one party. Low trust sends fed-up voters to outsiders. It slowly recovers toward the middle on its own.", tc)
	# the regions
	_eyebrow("The regions")
	var poll = S.polls[-1] if S.polls.size() else null
	var rg = GridContainer.new()
	rg.columns = 6
	rg.add_theme_constant_override("h_separation", 18)
	rg.add_theme_constant_override("v_separation", 8)
	var rc = _card()
	rc.add_child(rg)
	for h in ["Region", "Adults", "Leading", "You", "Cares most about", "Fed up with the system"]:
		rg.add_child(Look.dcaps(h, 10, Look.DIM, 1))
	for r in G.REGIONS:
		var sum: Dictionary = G.summarize(S, G.pops_matching(S, {"region": r.id}))
		var nb = _btn(r.name, func(): open_region(r.id))
		nb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		rg.add_child(nb)
		rg.add_child(Look.dlabel("%sM" % Game.fmt1(r.adults), "body", 14, Look.TXT))
		var lead_txt = "—"
		var you_txt = "—"
		if poll:
			var sh: Dictionary = poll.regions[r.id]
			var ids: Array = Game.ssort(sh.keys(), func(x, y): return sh[y] - sh[x])
			var lp = G.party_of(S, ids[0])
			lead_txt = "%s %d%%" % [lp.short, Game.jround(sh[ids[0]] * 100)]
			you_txt = "%d%%" % Game.jround(sh.player * 100)
		rg.add_child(Look.dlabel(lead_txt, "body_bold", 14, Look.TXT))
		rg.add_child(Look.dlabel(you_txt, "body", 14, Look.TXT))
		var issues: Array = Game.ssort(G.AXES.duplicate(), func(x, y): return sum.sal[y.id] - sum.sal[x.id]).slice(0, 2)
		var il = Look.dlabel(", ".join(issues.map(func(x): return x.issue)), "body", 14, Look.TXT)
		il.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rg.add_child(il)
		var dis: float = sum.disaffection
		rg.add_child(Look.dlabel("Very" if dis > 1.25 else ("Quite" if dis > 1.05 else ("Somewhat" if dis > 0.85 else "Hardly")), "body", 14, Look.TXT))
	# the parties
	_eyebrow("The parties")
	var nation: Dictionary = G.summarize(S, S.pops)
	var pg = GridContainer.new()
	pg.columns = 2 if size.x > 1100 else 1
	pg.add_theme_constant_override("h_separation", 12)
	pg.add_theme_constant_override("v_separation", 12)
	_add(pg)
	for p in S.parties:
		var pc = _card(pg)
		pc.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var top = HBoxContainer.new()
		top.add_theme_constant_override("separation", 10)
		pc.add_child(top)
		top.add_child(Face.party(p, 38))
		var nm = VBoxContainer.new()
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.add_theme_constant_override("separation", 0)
		top.add_child(nm)
		nm.add_child(Look.dlabel(p.name, "display", 19, Look.lit(Color(p.color))))
		nm.add_child(Look.dlabel("%s · %s%s" % [G.view_label(p.perceived), p.leader, " · governing" if p.ruling else (" · junior partner in government" if p.get("partner", false) else "")], "body", 13, Look.DIM))
		if poll: top.add_child(Look.dlabel("%s%%" % Game.fmt1(poll.national[p.id] * 100), "display", 22, Look.TXT))
		var est: float = p.establishment
		var meta = "%s leader · %s · %sM core voters" % [charisma_word(p.charisma), "The establishment" if est >= 0.8 else ("Mainstream" if est >= 0.55 else ("Semi-outsider" if est >= 0.3 else "Outsider")), "%.2f" % (nation.core[p.id] / 1e6)]
		if not p.isPlayer: meta += " · " + stability_word(p.stability)
		_p(meta, pc, Look.TXT)
		var claims = G.ownership_table(S).filter(func(r): return r.owners.any(func(o): return o.party == p.id))
		_p("Campaigns on: " + (", ".join(claims.map(func(r): return r.label.to_lower())) if claims.size() else "nothing in particular"), pc)
		if not p.isPlayer:
			var rel: float = G.relation(S, p.id)
			var scar: float = G.relation_scar(S, p.id)
			_add(Look.dlabel("Relations with you: %s (%+d)%s" % [G.relation_word(rel), Game.jround(rel), (" · old wounds %d" % Game.jround(scar)) if scar <= -1 else ""], "body_bold", 13, Look.GOOD_HI if rel >= 15 else (Look.RED_HI if rel <= -15 else Look.TXT)), pc)
			var notes: Array = S.get("relationNotes", {}).get(p.id, [])
			if notes.size(): _p(" · ".join(notes.slice(-3).map(func(n): return "%s (%+d)" % [n.text, Game.jround(n.delta)])), pc, Look.DIM, 12)
	# the small parties: fixed support, no campaign, no seats under the threshold
	if G.MINOR_PARTIES.size():
		_eyebrow("Small parties")
		_p("True believers vote for them whatever happens. Under %d%% of the national vote a party wins no seats at all." % Game.jround(G.threshold() * 100), null, Look.DIM, 13)
		var mg = GridContainer.new()
		mg.columns = 2 if size.x > 1100 else 1
		mg.add_theme_constant_override("h_separation", 12)
		mg.add_theme_constant_override("v_separation", 12)
		_add(mg)
		for p in G.MINOR_PARTIES:
			var mc = _card(mg)
			mc.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var mt = HBoxContainer.new()
			mt.add_theme_constant_override("separation", 10)
			mc.add_child(mt)
			var mn = VBoxContainer.new()
			mn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			mn.add_theme_constant_override("separation", 0)
			mt.add_child(mn)
			mn.add_child(Look.dlabel(p.name, "display", 17, Look.lit(Color(p.color))))
			mn.add_child(Look.dlabel("%s · %s" % [G.view_label(p.perceived), p.leader], "body", 13, Look.DIM))
			if poll: mt.add_child(Look.dlabel("%s%%" % Game.fmt1(float(poll.national.get(p.id, 0)) * 100), "display", 20, Look.TXT))
			_p(String(p.blurb), mc, Look.TXT, 13)
	# the small parties: fixed support, no campaign, no seats under the threshold
	if G.MINOR_PARTIES.size():
		_eyebrow("Small parties")
		_p("True believers vote for them whatever happens. Under %d%% of the national vote a party wins no seats at all." % Game.jround(G.threshold() * 100), null, Look.DIM, 13)
		var mg = GridContainer.new()
		mg.columns = 2 if size.x > 1100 else 1
		mg.add_theme_constant_override("h_separation", 12)
		mg.add_theme_constant_override("v_separation", 12)
		_add(mg)
		for p in G.MINOR_PARTIES:
			var mc = _card(mg)
			mc.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var mt = HBoxContainer.new()
			mt.add_theme_constant_override("separation", 10)
			mc.add_child(mt)
			var mn = VBoxContainer.new()
			mn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			mn.add_theme_constant_override("separation", 0)
			mt.add_child(mn)
			mn.add_child(Look.dlabel(p.name, "display", 17, Look.lit(Color(p.color))))
			mn.add_child(Look.dlabel("%s · %s" % [G.view_label(p.perceived), p.leader], "body", 13, Look.DIM))
			if poll: mt.add_child(Look.dlabel("%s%%" % Game.fmt1(float(poll.national.get(p.id, 0)) * 100), "display", 20, Look.TXT))
			_p(String(p.blurb), mc, Look.TXT, 13)
	# neighbours
	_eyebrow("Neighbours")
	var ng = GridContainer.new()
	ng.columns = 4 if size.x > 1100 else 2
	ng.add_theme_constant_override("h_separation", 12)
	ng.add_theme_constant_override("v_separation", 12)
	_add(ng)
	for f in G.FOREIGN:
		var st: Dictionary = S.countries.get(f.id, {})
		var fc = _card(ng)
		fc.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fc.add_child(Look.dlabel(" ".join(f.name), "display", 18, Look.TXT, true))
		fc.add_child(Look.dlabel(st.get("relation", f.relation) + (" · trouble on the border" if st.get("hot", false) else ""), "body_bold", 12, Look.RED_HI if st.get("hot", false) else Look.DIM, true))
		var notes: Array = st.get("notes", [])
		fc.add_child(Look.dlabel(notes[-1].text if notes.size() else f.blurb, "body", 12, Look.TXT, true))
		fc.add_child(_btn("Read the brief", func(): open_country.emit(f.id)))

class Spark extends Control:
	var vals: Array
	var col := Look.RED_HI
	func _init(v: Array, c := Look.RED_HI) -> void:
		vals = v; col = c
	func _draw() -> void:
		if vals.size() < 2: return
		var pts = PackedVector2Array()
		for i in vals.size():
			pts.append(Vector2(i / float(vals.size() - 1) * (size.x - 6) + 3, size.y - 4 - vals[i] / 100.0 * (size.y - 8)))
		var mid = size.y - 4 - 0.5 * (size.y - 8)
		draw_dashed_line(Vector2(0, mid), Vector2(size.x, mid), Look.N600, 1.0, 4.0)
		draw_polyline(pts, col, 2.0, true)
		draw_circle(pts[-1], 3, col)

# ---------- Media ----------
const KIND_NAMES := {"public": "Public broadcaster", "paper": "Broadsheet", "tabloid": "Tabloid", "business": "Business paper",
	"network": "TV network", "online": "Online", "regional": "Local papers", "platform": "Social media", "foreign": "Foreign channel", "influencer": "Personality"}
const TONE_WORDS := {"statesman": "measured", "folksy": "folksy", "fiery": "fiery", "provocative": "provocative"}

static func favour_word(f: float) -> String:
	if f >= 0.45: return "Backs you"
	if f >= 0.15: return "Friendly"
	if f > -0.15: return "Neutral"
	if f > -0.45: return "Critical"
	return "Hostile"

func _media() -> void:
	_p("Every outlet works on its audience month after month: it pulls their views toward its own line, warms them to the party it favours, and makes them forgive that party. Honest outlets reach many and report what you actually say; partisan ones reach fewer but move and protect their audience more. Measured and folksy lines play best in the press and on television, fiery and provocative ones on social media. Hover a name for more.", null, Look.DIM, 13)
	var pat = S.get("patron")
	if pat:
		var since: int = int((S.week - int(pat.since)) / G.WEEKS_PER_MONTH)
		_p("Your friends abroad (%s) have been paying for %d month%s: money every quarter, their channel on your side and help on social media. Every month it runs, someone else might find out." % [str(pat.country).capitalize(), since, "" if since == 1 else "s"], null, Look.RED_HI, 14)
	var nation: Array = G.group_media(S, S.pops)
	var blocked: bool = S.queue.size() > 0 or S.result != null or S.actionsLeft <= 0
	var cols = HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	_add(cols)
	var left = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 4)
	cols.add_child(left)
	var right = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 4)
	cols.add_child(right)
	_eyebrow("Press and television", left)
	_media_head(left)
	for row in nation:
		if not (row.outlet.kind in ["platform", "influencer"]): _media_row(left, row, blocked)
	_eyebrow("Social media", right)
	_media_head(right)
	for row in nation:
		if row.outlet.kind == "platform": _media_row(right, row, blocked)
	var gap = Control.new(); gap.custom_minimum_size.y = 10
	right.add_child(gap)
	_eyebrow("Personalities", right)
	_add(Look.dlabel("Their reach and price follow their followers, who leave in numbers after a scandal. Sponsoring one is an open secret: they back whoever pays, a little less believably.", "body", 12, Look.DIM, true), right)
	_media_head(right)
	for row in nation:
		if row.outlet.kind == "influencer": _media_row(right, row, blocked)

const MEDIA_COLS := [150, 70, 62, 66]   # on you, reach, style, favours

func _media_head(to: Control) -> void:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var n = Look.dcaps("", 9, Look.DIM, 1)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(n)
	var heads = ["On you", "Reach", "Style", "Favours"]
	for i in 4:
		var l = Look.dcaps(heads[i], 9, Look.DIM, 1)
		l.custom_minimum_size.x = MEDIA_COLS[i] if i > 0 else 70
		h.add_child(l)
	var sp = Control.new(); sp.custom_minimum_size.x = 150
	h.add_child(sp)
	to.add_child(h)

## One outlet on one line: name, how it treats you, reach, style, whom it favours, and what you can do.
func _media_row(to: Control, row: Dictionary, blocked: bool) -> void:
	var o: Dictionary = row.outlet
	var st: Dictionary = S.media[o.id]
	var fav: Dictionary = st.get("favour", {})
	var mine: float = float(fav.get("player", 0))
	var best = ""
	var best_f = 0.15
	for pid in fav:
		if pid != "player" and float(fav[pid]) > best_f: best_f = float(fav[pid]); best = pid
	var h: float = G.outlet_honesty(S, o)
	var plays = []
	for t in o.get("tones", {}):
		if float(o.tones[t]) >= 1.15: plays.append(TONE_WORDS.get(t, t))
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Look.glass(6))
	var line = HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	panel.add_child(line)
	var name_box = VBoxContainer.new()
	name_box.add_theme_constant_override("separation", -2)
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm = Look.dlabel(o.name, "display", 16, Look.TXT)
	nm.clip_text = true
	name_box.add_child(nm)
	var sub: String = KIND_NAMES.get(o.kind, o.kind)
	if o.kind == "influencer": sub = "%sM followers" % Game.fmt1(float(st.get("subs", o.get("subs", 0))))
	if plays.size(): sub += " · likes " + ", ".join(plays)
	var sl = Look.dlabel(sub, "body", 11, Look.DIM)
	sl.clip_text = true
	name_box.add_child(sl)
	line.add_child(name_box)
	panel.tooltip_text = "%s\nOwner: %s." % [o.blurb, "friends of your party" if st.owner == "player" else o.owner]
	var reach_word = "Huge" if row.reach >= 0.25 else ("Large" if row.reach >= 0.12 else ("Medium" if row.reach >= 0.05 else "Small"))
	var fw: String = favour_word(mine)
	var cells = [[fw, Look.GOOD_HI if mine >= 0.15 else (Look.RED_HI if mine <= -0.15 else Look.TXT)], [reach_word, Look.TXT],
		["Honest" if h >= 0.65 else ("Slanted" if h >= 0.35 else "Partisan"), Look.TXT], [G.party_of(S, best).short if best != "" else "—", Look.TXT]]
	for i in 4:
		var l = Look.dlabel(cells[i][0], "body_bold", 13, cells[i][1])
		l.custom_minimum_size.x = MEDIA_COLS[i] if i > 0 else 70
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(l)
	var act = HBoxContainer.new()
	act.custom_minimum_size.x = 150
	act.alignment = BoxContainer.ALIGNMENT_END
	line.add_child(act)
	var price: float = float(o.get("price", 0))
	if st.owner == "player":
		act.add_child(Look.dlabel("Yours", "body_bold", 12, Look.RED_HI))
	elif st.owner != "":
		act.add_child(Look.dlabel("Owned by %s" % (G.party_of(S, st.owner).short if G.party_of(S, st.owner) else "a party"), "body", 12, Look.DIM))
	elif price > 0:
		var b = _btn("Buy · ₱%sM" % Game.fmt1(price), func():
			var res: Dictionary = G.act_buy_outlet(S, o.id)
			toast.emit(res.text)
			changed.emit(), blocked or S.money < price)
		b.tooltip_text = "Uses one of this month's actions. A bought outlet turns your way and shields your voters, but it is believed less and loses readers to the others."
		b.add_theme_font_size_override("font_size", Look.fs(11))
		act.add_child(b)
	if o.kind == "influencer":
		var spon: String = st.get("sponsor", "")
		var fee: float = G.sponsor_price(S, o)
		if spon == "player":
			var eb = _btn("End deal (₱%sM/q)" % Game.fmt1(fee), func():
				var res: Dictionary = G.act_end_sponsor(S, o.id)
				toast.emit(res.text)
				changed.emit(), S.result != null)
			eb.add_theme_font_size_override("font_size", Look.fs(11))
			act.add_child(eb)
		elif spon != "":
			var rp = G.party_of(S, spon)
			act.add_child(Look.dlabel("Paid by %s" % (rp.short if rp else "someone"), "body", 12, Look.DIM))
		else:
			var sb = _btn("Sponsor · ₱%sM/q" % Game.fmt1(fee), func():
				var res: Dictionary = G.act_sponsor(S, o.id)
				toast.emit(res.text)
				changed.emit(), blocked or S.money < fee)
			sb.tooltip_text = "Uses one of this month's actions; the fee is paid now and every quarter, and follows their followers. Everyone knows they're paid, so their word counts a little less, but it is no scandal."
			sb.add_theme_font_size_override("font_size", Look.fs(11))
			act.add_child(sb)
	to.add_child(panel)

# ---------- Polls ----------
static func funds_word(m: float) -> String:
	if m >= 30: return "Flush"
	if m >= 12: return "Comfortable"
	if m >= 4: return "Getting by"
	return "Tight"

## A party's three strongest leanings ("Nationalist · Traditional · Authority").
func _leans(p: Dictionary) -> String:
	var axes: Array = G.AXES.map(func(ax): return {"id": ax.id, "v": float(p.perceived[ax.id])})
	axes = Game.ssort(axes, func(a, b): return absf(b.v) - absf(a.v))
	var out = []
	for a in axes.slice(0, 3):
		if absf(a.v) >= 15: out.append(G.stance_name(a.id, G.stance_of(a.v)))
	return " · ".join(out) if out.size() else "centrist on everything"

func _polls() -> void:
	if S.polls.is_empty():
		_p("No polls yet."); return
	var poll: Dictionary = S.polls[-1]
	var prev = S.polls[-2] if S.polls.size() > 1 else null
	# the parties, and what they have been up to
	var seats: Dictionary = G.projected_seats(S.projection) if S.get("projection", {}).size() else {}
	var order: Array = Game.ssort(S.parties.duplicate(), func(a, b): return float(poll.national.get(b.id, 0)) - float(poll.national.get(a.id, 0)))
	var g = GridContainer.new()
	g.columns = 3 if size.x > 1100 else 1
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	_add(g)
	var moves: Array = S.get("rivalMoves", [])
	var act_blocked: bool = S.queue.size() > 0 or S.result != null or S.actionsLeft <= 0
	_p("A rival's tour warms the voters of that province to them, so every other party's share there shrinks for a few months, yours included. Their adverts do the same more thinly, everywhere.", null, Look.DIM, 13)
	for p in order:
		var c = _card(g)
		c.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var top = HBoxContainer.new()
		top.add_theme_constant_override("separation", 10)
		c.add_child(top)
		top.add_child(Face.party(p, 38))
		var nm = Look.dlabel(("You · " if p.isPlayer else "") + p.name, "display", 19, Look.lit(Color(p.color)), true)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(nm)
		var now: float = float(poll.national.get(p.id, 0)) * 100
		var was: float = float(prev.national.get(p.id, 0)) * 100 if prev else now
		top.add_child(Look.dlabel("%s%% %s" % [Game.fmt1(now), "▲" if now - was > 0.4 else ("▼" if now - was < -0.4 else "")], "display", 19, Look.TXT))
		var lhome: String = str(p.get("leaderHome", ""))
		var lfrom: String = (", from " + lhome) if lhome != "" else ""
		var fw: String = funds_word(float(S.money) if p.isPlayer else float(p.get("money", 0))).to_lower()
		_add(Look.dlabel("Leader: %s%s · %d seats if the election were today · funds: %s" % [p.leader, lfrom, int(seats.get(p.id, 0)), fw], "body", 12, Look.DIM, true), c)
		# where they stand, and who they would and wouldn't govern with
		_add(Look.dlabel("Leans: " + _leans(p), "body_bold", 13, Look.TXT, true), c)
		var allies = []
		var enemies = []
		for q in S.parties:
			if q.id == p.id: continue
			var st: String = G.party_stance(S, p.id, q.id)
			var nm2: String = "you" if q.isPlayer else String(q.short)
			if st == "ally": allies.append(nm2)
			elif st == "enemy": enemies.append(nm2)
		_add(Look.dlabel("Allies: %s · Enemies: %s" % [", ".join(allies) if allies.size() else "none", ", ".join(enemies) if enemies.size() else "none"], "body", 13, Look.TXT, true), c)
		if p.isPlayer:
			_add(Look.dlabel("%d of %d actions left this month." % [S.actionsLeft, int(G.C.actionsPerMonth)], "body", 12, Look.TXT, true), c)
			for i in S.dossiers.size():
				var dd: Dictionary = S.dossiers[i]
				var dl = HBoxContainer.new()
				c.add_child(dl)
				var dt = Look.dlabel("Dossier on %s: %s (%s)" % [G.party_of(S, dd.party).short, dd.what, ["", "minor", "damaging", "explosive"][int(dd.severity)]], "type", 13, Look.TXT, true)
				dt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				dl.add_child(dt)
				var rb = _btn("Release", func(): _did(G.act_release(S, i)), act_blocked)
				rb.tooltip_text = G.ACTIONS.release.help
				dl.add_child(rb)
			continue
		var mine: Array = moves.filter(func(m): return m.party == p.id and S.week - int(m.week) < 2 * G.WEEKS_PER_MONTH)
		if mine.is_empty():
			_add(Look.dlabel("Quiet lately.", "body_italic", 12, Look.DIM, true), c)
		for m in mine.slice(-4):
			_add(Look.dlabel("· " + m.text, "body", 13, Look.TXT, true), c)
		var acts = _row(c, 6)
		var ib = _btn("Investigate · ₱%sM" % str(G.ACTIONS.research.cost), func(): _did(G.act_research(S, p.id)), act_blocked or S.money < float(G.ACTIONS.research.cost))
		ib.tooltip_text = G.ACTIONS.research.help + " About half the time you find something; one time in seven you get caught."
		acts.add_child(ib)
		var can: bool = G.can_poach(S, p.id)
		var pb = _btn("Win over a branch · ₱%sM" % str(G.ACTIONS.poach.cost), func(): _did(G.act_poach(S, p.id)), (not can) or act_blocked or S.money < float(G.ACTIONS.poach.cost))
		pb.tooltip_text = G.ACTIONS.poach.help + ("" if can else ("\nThey were raided recently." if p.stability < 40 else "\nThe party is too stable for anyone to leave: %s." % stability_word(p.stability).to_lower()))
		acts.add_child(pb)
	_rule()
	_eyebrow("National vote intention · %s · %s" % [poll.label, G.date_label(poll.week, false)])
	_bars(poll.national, prev.national if prev else null)
	_p("Expected turnout %d%%. %s" % [Game.jround(poll.turnout * 100), "A careful poll you paid for: no random noise, only the error of asking a sample." if poll.get("paid", false) else "Margin of error about ±%s points." % Game.fmt1(G.C.pollError * 200)])
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
			draw_dashed_line(Vector2(pad.l, Y.call(t)), Vector2(size.x - pad.r, Y.call(t)), Look.N600, 1.0, 4.0)
			draw_string(f, Vector2(4, Y.call(t) + 4), "%d%%" % int(t * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Look.DIM)
		for i in n:
			if i == 0 or not S.polls[i].tracker:
				var lab = "Start" if i == 0 else str(G.calendar(S.polls[i].week).year)
				draw_string(f, Vector2(X.call(i) - 14, size.y - 6), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Look.DIM)
		for p in S.parties:
			var pts = PackedVector2Array()
			for i in n: pts.append(Vector2(X.call(i), Y.call(S.polls[i].national[p.id])))
			if pts.size() > 1: draw_polyline(pts, Look.lit(Color(p.color)), 3.0 if p.isPlayer else 1.6, true)
			draw_circle(pts[-1], 5 if p.isPlayer else 3.5, Look.lit(Color(p.color)))

# ---------- Diary ----------
func _diary() -> void:
	if S.log.is_empty():
		_p("Nothing has happened yet."); return
	for i in range(S.log.size() - 1, -1, -1):
		var e: Dictionary = S.log[i]
		var h = HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		var when = Look.dcaps(G.date_label(e.week, false), 11, Look.DIM, 1)
		when.custom_minimum_size.x = 110
		h.add_child(when)
		var t = Look.dlabel(e.text, "news", 15, Look.TXT, true)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(t)
		_add(h)
		var r = ColorRect.new(); r.color = Look.N600; r.custom_minimum_size.y = 1
		_add(r)
