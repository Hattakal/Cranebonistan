## main_story.gd — founding the party, and the ending (the column and the profile).
extends "res://scripts/main_places.gd"
# ---------- Founding the party (a new game) ----------

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
	var mods: Array = Mods.enabled()
	if mods.size(): p.small("Mods: " + ", ".join(mods.map(func(m): return "%s %s" % [m.name, m.version])), Look.RED)
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
		le.add_theme_font_override("font", Look.font("news"))
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


## The ending: an opinion column on the campaign (the columnist: coalition.json COLUMN).
func _profile_sheet() -> void:
	var pr: Dictionary = G.build_profile(S)
	var you: Dictionary = G.player_party(S)
	var r: Dictionary = S.result
	var col: Dictionary = G.COALITION.get("COLUMN", {})
	var oc: Dictionary = G.COALITION.get("OUTCOMES", {}).get(r.get("coalition", {}).get("outcome", ""), {})
	var fill = {"party": you.name, "leader": you.leader}
	var p = _paper(860, false)
	p.source(String(col.get("outlet", "The Cranebo Herald")), "Opinion · %s" % G.date_label(S.week, false))
	p.heading(String(oc.get("headline", pr.headline)).format(fill) if oc.has("headline") else String(pr.headline).capitalize(), 40)
	if oc.has("line"): p.text(String(oc.line).format(fill), 19, "news_italic")
	if col.has("author"): p.small("By %s, %s" % [col.author, col.get("role", "")], Look.INK)
	p.rule(1)
	# the result, and who governs now
	var tot: float = G.dsum(r.votes)
	var share: float = float(r.votes.get("player", 0)) / tot * 100 if tot > 0 else 0.0
	var seats: int = int(r.seats.national.get("player", 0))
	var rank: int = r.ranking.find("player") + 1
	var ords = ["", "the largest party", "second", "third", "fourth", "fifth", "sixth", "seventh"]
	var para: String = "%s took %s%% of the vote and %d of the %d seats%s." % [you.name, Game.fmt1(share), seats, int(G.C.seats), (", " + (ords[rank] if rank == 1 else "%s largest" % ords[mini(rank, ords.size() - 1)])) if seats > 0 else ""]
	var gov = r.get("coalition", {}).get("government")
	if gov:
		var pm = ""
		for c in gov.cabinet:
			if c.ministry == "pm": pm = c.party
		var names: Array = gov.members.map(func(id): return "you" if id == "player" else String(G.party_of(S, id).name))
		var pmp = G.party_of(S, pm)
		para += " The new government is %s, with %s as Prime Minister." % [("%s alone" % names[0]) if names.size() == 1 else "a coalition of " + Game.and_list(names), "you" if pm == "player" else ("%s of the %s" % [pmp.leader, pmp.short]) if pmp else "nobody yet"]
	elif r.has("coalition"): para += " Nobody could put a government together."
	p.text(para, 17)
	p.text("Four years ago almost nobody had heard of %s. This column's verdict: %s. %s" % [you.leader, pr.archetype.title, pr.archetype.line], 17)
	if pr.signature: p.quote(pr.signature.text, "%s, %s" % [you.leader, G.date_label(pr.signature.week, false)])
	if pr.contradictions.size():
		p.rule(1)
		p.add(Look.caps("Where you said one thing, then the opposite", 12, Look.RED, 2))
		for c in pr.contradictions:
			var ax = Game.by_id(G.AXES, c.axis)
			var side_of = func(q) -> String: return (ax.left if float(q.shift[c.axis]) < 0 else ax.right).to_lower()
			p.add(Look.label("On %s: first %s, then %s." % [ax.issue.to_lower(), side_of.call(c.first), side_of.call(c.second)], "news_bold", 19, Look.INK, true))
			p.add(_said_pair(c.first, c.second, side_of))
	if pr.betrayed.size():
		p.rule(1)
		p.add(Look.caps("Promises broken", 12, Look.RED, 2))
		for b in pr.betrayed:
			p.add(Look.label("To %s:" % b.group, "news_bold", 17, Look.INK, true))
			p.add(_said_pair({"text": b.promised, "week": b.promisedWeek, "spoken": b.get("promisedSpoken", true)}, {"text": b.now, "week": b.week, "spoken": b.get("nowSpoken", true)}, null))
	if pr.blamed.size(): p.text("Groups you blamed along the way: %s." % ", ".join(pr.blamed), 15)
	var dirty: Array = pr.money.filter(func(m): return m.dirty)
	if dirty.size(): p.text("You took money from %s." % ", ".join(dirty.map(func(m): return m.source)), 15)
	if pr.crisis: p.text("The crisis: %s.%s" % [pr.crisis.name, " Your own campaign helped bring it about." if pr.crisis.blamed else ""], 15)
	var pl = func(n: int, w: String) -> String: return "%d %s%s" % [n, w, "" if n == 1 else "s"]
	p.small("Speaking style: %s · %s · %s · %s" % [pr.style, pl.call(pr.statements, "statement"), pl.call(pr.memes, "viral moment"), pl.call(pr.gaffes, "gaffe")], Look.INK)
	p.actions([p.button("Found a new party", func():
		p.close()
		_founding_sheet(), false), p.button("Close", func(): p.close())])

## Two things the leader said, side by side: what came first and what came later.
func _said_pair(first: Dictionary, second: Dictionary, side_of) -> Control:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	var cols = [[first, "Then"], [second, "Later"]]
	for i in 2:
		var q: Dictionary = cols[i][0]
		var box = PanelContainer.new()
		var sb = Look.box(Color(Look.RED, 0.06) if i == 1 else Color(0, 0, 0, 0.04), 0, Look.RED if i == 1 else Look.MUTED, 0, 0, 12)
		sb.border_width_left = 4
		box.add_theme_stylebox_override("panel", sb)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.custom_minimum_size.x = 340
		var v = VBoxContainer.new()
		var head: String = "%s · %s" % [cols[i][1], G.date_label(int(q.week), false)]
		if side_of is Callable and q.has("shift"): head += " · for " + side_of.call(q)
		v.add_child(Look.caps(head, 11, Look.RED if i == 1 else Look.MUTED, 1))
		var t: String = String(q.text).strip_edges()
		var quoted: bool = q.get("spoken", true) or t.begins_with("\"") or t.begins_with("“")
		var told: String = ("“%s”" % t.trim_prefix("\"").trim_suffix("\"").trim_prefix("“").trim_suffix("”")) if quoted else ("Chose to " + t.substr(0, 1).to_lower() + t.substr(1).trim_suffix("."))
		if String(q.get("title", "")) != "": v.add_child(Look.label("On “%s”:" % q.title, "body", 13, Look.MUTED, true))
		v.add_child(Look.label(told, "news_italic", 16, Look.INK, true))
		box.add_child(v)
		h.add_child(box)
		if i == 0: h.add_child(Look.label("→", "display", 22, Look.RED))
	return h
