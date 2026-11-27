## main_events.gd — decisions as paper: events, saying it (style, then words), speaking and starting debates.
extends "res://scripts/main_map.gd"
# ---------- Decisions: each one zooms up as paper ----------


func _sheet_open() -> bool:
	for c in _sheet_layer.get_children():
		if not c.is_queued_for_deletion(): return true
	return false


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
		"interview": _interview_sheet()
		"appearance": _appearance_sheet()
		"election": _election_sheet()
		"convoy": _convoy_sheet(true)
		"rally": _rally_sheet(front)

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
		if s.from != s.to:
			var mine: int = G.stance_of(G.player_party(S).manifesto[s.axis])
			var away: bool = absi(int(s.to) - mine) > absi(int(s.from) - mine)
			tags.append("Stance change: %s → %s%s" % [G.stance_name(s.axis, s.from), G.stance_name(s.axis, s.to), " (away from your manifesto)" if away else ""])
	tags.append_array(d.tags)
	if tags.size(): box.add_child(Look.label(" · ".join(tags), "body_italic", 12, Look.MUTED, true))

# ----- Events: the front page, what you say, how you say it, how it played -----

func _event_header(p: Paper, ev: Dictionary) -> void:
	var crisis = ""
	if ev.get("kind", "") == "crisis" and S.crisis: crisis = Game.by_id(G.CRISES, S.crisis.id).name
	p.source(_broke_it(ev), "%s · %s" % [("Crisis · " + crisis) if crisis != "" else KINDS.get(ev.get("kind", ""), "Event"), G.date_label(S.week, false)])
	p.heading(ev.title, 38)
	p.photo(Photo.event(ev), 280)
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
			p.add(Look.caps("What this does to %s" % G.COUNTRY.name, 11, Look.MUTED, 2))
			p.chips(items)
	if ev.get("crisisStart") and G.crisis_blames_you(S):
		p.callout("Your party's campaigning helped bring this about. For months you pushed the country toward exactly this.")
	if ev.get("echo") and S.record.blamed.size():
		var b: Dictionary = S.record.blamed[-1]
		p.quote(b.text, "%s, %s. Your words were quoted at the scene." % [G.player_party(S).leader, G.date_label(b.week, false)])

## The outlet that broke an event's news (media.json BREAKS), or your own people for
## what only you know about.
func _broke_it(ev: Dictionary) -> String:
	var id: String = str(ev.get("source", Mods.data("media").get("BREAKS", {}).get(ev.get("kind", ""), "")))
	var o = G.outlet_by_id(id) if id != "" else null
	if o == null: return "%s · internal" % G.player_party(S).name
	if id == "courier" and ev.get("sourceRegion"):
		var r = Game.by_id(G.REGIONS, ev.sourceRegion)
		if r: return "The %s Courier" % r.name
	return o.name

func _event_sheet(front: Dictionary) -> void:
	var ev: Dictionary = G.event_of(front)
	var p = _paper(820)
	_event_step1(p, ev)

func _event_step1(p: Paper, ev: Dictionary) -> void:
	p.clear()
	_event_header(p, ev)
	var any_lines = false
	for ch in ev.choices:
		if ch.get("lines", []).size(): any_lines = true
	p.step("Step 1" if any_lines else "Your decision", "What do you promise?" if ev.get("kind", "") == "flagship" else "What do you say?")
	for i in ev.choices.size():
		var ch: Dictionary = ev.choices[i]
		p.card("index", func(box):
			box.add_child(Look.label(ch.label, "news_bold", 21, Look.INK, true))
			if ch.has("note"): box.add_child(Look.label(ch.note, "body", 13, Look.MUTED, true))
			_effects_lines(box, ch.effects),
			func():
				if ch.get("lines", []).size(): _event_step2(p, ev, i)
				else: _event_result(p, G.resolve_event(S, i, -1), ev))
	p.top()

func _event_step2(p: Paper, ev: Dictionary, i: int) -> void:
	var ch: Dictionary = ev.choices[i]
	var head = func():
		_event_header(p, ev)
		if ev.get("kind", "") == "flagship": p.text("Your promise: %s. This goes on every poster for a year." % ch.label, 14, "type")
		else: p.text("You will %s." % (ch.label.substr(0, 1).to_lower() + ch.label.substr(1).trim_suffix(".")), 14, "type")
	_say_it(p, ch.lines, head, 2, func(j): _event_result(p, G.resolve_event(S, i, j), ev),
		func(): _event_step1(p, ev), "← Say something else")

func _event_result(p: Paper, res: Dictionary, ev := {}) -> void:
	p.clear()
	p.decided()
	_result_body(p, res.get("title", ""), res, "", Photo.event(ev) if ev.size() else null)
	p.actions([p.button("Back to work", func(): _done(p))])
	p.top()

## What a stance change means against the manifesto: one stance off is noticed a little,
## two or more is a real break (CONFIG.stepPenalty).
func _drift_note(f: Dictionary) -> String:
	var mine: int = G.stance_of(G.player_party(S).manifesto[f.axis])
	var was: int = absi(int(f.from) - mine)
	var now: int = absi(int(f.to) - mine)
	if now == 0: return " Back in line with your manifesto."
	if now < was: return " Closer to your manifesto again."
	if now == 1: return " Your manifesto says %s: people who care about this notice, a little." % G.stance_name(f.axis, mine).to_lower()
	return " Your manifesto says %s. That's a real break with it, and the people who care about it will hold it against you." % G.stance_name(f.axis, mine).to_lower()

## `strap` "" is the evening news (the sheet becomes a screen); anything else stays on paper.
func _result_body(p: Paper, title: String, res: Dictionary, strap := "", picture: Texture2D = null) -> void:
	var player: Dictionary = G.player_party(S)
	if strap == "":   # it made the evening news
		strap = _tv("Evening news")
		p.screen()
	p.photo(picture, 240)
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
		p.callout("Stance change on %s: %s → %s.%s" % [Game.by_id(G.AXES, f.axis).issue.to_lower(), G.stance_name(f.axis, f.from), G.stance_name(f.axis, f.to), _drift_note(f)])
	if res.get("changes", []).size():
		p.add(Look.caps("Who moved", 11, Look.MUTED, 2))
		_changes_chips(p, res.changes)

# ----- Saying it: a style, then the exact words -----
## How you say something comes in two choices: the style (Measured, Fiery, Folksy,
## Hopeful: content.json TONES), then the exact words in it, some sharp, some simply
## better put than others. A step with only one option is skipped.


func _styles_in(lines: Array) -> Array:
	var by = {}
	for j in lines.size():
		var t: String = G.line_style(lines[j])
		if not by.has(t): by[t] = []
		by[t].append(j)
	var out = []
	for t in G.TONES:
		if by.has(t): out.append({"tone": t, "idx": by[t]})
	return out

func _tone_name(t: String) -> String:
	return String(G.TONES.get(t, {}).get("name", t.capitalize()))

func _risky(line: Dictionary) -> bool:
	var r = line.get("risk")
	if r == null: r = G.TONE_RISK.get("provocative" if G.line_sharp(line) else G.line_style(line), 0.3)
	return float(r) >= 0.6

## The small caps over a line: its style (when `style`), whether it is sharp or risky, and `extra`.
func _tone_tag(box: VBoxContainer, line: Dictionary, extra := "", style := false) -> void:
	var parts = []
	if style: parts.append(_tone_name(G.line_style(line)))
	if G.line_sharp(line): parts.append(_tone_name("provocative"))
	if _risky(line): parts.append("risky")
	if extra != "": parts.append(extra)
	if parts.is_empty(): return
	var t: String = " · ".join(parts)
	box.add_child(Look.caps(t.substr(0, 1).to_upper() + t.substr(1), 10, Look.RED if _risky(line) else Look.MUTED, 1))

## Say it: choose a style, then the words. `head` draws the top of the sheet again, `step`
## numbers the first of these steps (0: unnumbered), `pick` gets the chosen line's index in
## `lines`, `back` goes to whatever came before. `extra` adds to a line's tag.
func _say_it(p: Paper, lines: Array, head: Callable, step: int, pick: Callable, back: Callable, back_label: String, extra := Callable()) -> void:
	var styles: Array = _styles_in(lines)
	if _shot_words:   # a screenshot of the wording step (--words=1)
		_shot_words = false
		for st in styles:
			if st.idx.size() > 1:
				_say_words(p, lines, st.idx, head, step + 1 if step > 0 else 0, pick, back, back_label, extra); return
	if styles.size() == 1:
		_say_words(p, lines, styles[0].idx, head, step, pick, back, back_label, extra)
		return
	p.clear()
	head.call()
	p.step("Step %d" % step if step > 0 else "Your voice", "How do you come across?")
	for st in styles:
		var tone: Dictionary = G.TONES.get(st.tone, {})
		var idx: Array = st.idx
		var c = p.card("index" if idx.size() > 1 else "slip", func(box):
			if idx.size() == 1:   # one wording in this voice: show the words themselves
				var line: Dictionary = lines[idx[0]]
				_tone_tag(box, line, extra.call(line) if extra.is_valid() else "", true)
				box.add_child(Look.label("“%s”" % line.text, "news_italic", 20, Look.INK, true))
			else:
				box.add_child(Look.label(_tone_name(st.tone), "display", 22, Look.INK))
				if tone.has("pitch"): box.add_child(Look.label(tone.pitch, "body", 13, Look.MUTED, true))
				box.add_child(Look.label("%d ways to put it" % idx.size(), "body_italic", 12, Look.MUTED)),
			func():
				if idx.size() == 1: pick.call(idx[0])
				else: _say_words(p, lines, idx, head, step + 1 if step > 0 else 0, pick,
					func(): _say_it(p, lines, head, step, pick, back, back_label, extra), "← Another style", extra))
		if tone.has("pitch"): c.tooltip_text = "%s: %s" % [_tone_name(st.tone), tone.pitch]
	_back_button(p, back, back_label)
	p.top()

func _say_words(p: Paper, lines: Array, idx: Array, head: Callable, step: int, pick: Callable, back: Callable, back_label: String, extra := Callable()) -> void:
	p.clear()
	head.call()
	p.step("Step %d" % step if step > 0 else "Your words", "How exactly do you put it?")
	p.small("%s. The same voice can be put well or badly: some of these will land better than others." % _tone_name(G.line_style(lines[idx[0]])))
	for j in idx:
		var line: Dictionary = lines[j]
		p.card("slip", func(box):
			_tone_tag(box, line, extra.call(line) if extra.is_valid() else "")
			box.add_child(Look.label("“%s”" % line.text, "news_italic", 20, Look.INK, true)),
			func(): pick.call(j))
	_back_button(p, back, back_label)
	p.top()

func _back_button(p: Paper, back: Callable, label: String) -> void:
	if not back.is_valid(): return
	if label.begins_with("←"):
		var b = p.button(label, back, false)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		p.add(b)
	else: p.actions([p.button(label, back)])

# ----- Speaking in a debate -----
func _speak_sheet(id: String, side: String) -> void:
	var d = G.debate_by_id(S, id)
	if d == null: return
	var ax: Dictionary = Game.by_id(G.AXES, d.axis)
	var major: bool = G.is_major(d)
	var p = _paper(760, false)
	var head = func():
		p.kicker(("Major debate · " if major else "The national debate · ") + ax.issue)
		p.heading(d.title, 34)
		p.text(d.text, 16)
		p.text("Your side: %s." % (ax.left if side == "L" else ax.right), 14, "type")
		if major: p.scribble("The whole country is watching. Your exact words will be quoted: they can go viral, or become a gaffe that helps the other side.  — C.")
		else: p.small("A smaller argument. Your line mostly shapes how people hear you; it won't make the evening news.")
	var lines: Array = G.debate_lines(S, d, side)
	_say_it(p, lines, head, 0, func(j):
		var line: Dictionary = lines[j]
		var res: Dictionary = G.act_speak(S, id, side, j)
		if not res.ok:
			_toast(res.text); return
		_after_speaking(res, line, d.axis, side)
		# every speech shows how it played; a smaller debate just doesn't make the evening news
		p.clear()
		_result_body(p, res.title, res, "" if res.major else "On the record")
		p.actions([p.button("Back to work", func(): _done(p))])
		p.top(),
		func(): p.close(), "Back")

func _after_speaking(res: Dictionary, line: Dictionary, axis: String, side: String) -> void:
	var outcome: String = res.delivery.outcome
	if outcome == "viral": _advisor.say("viral", true)
	elif outcome == "gaffe":
		_advisor.say("gaffe", false, 0.35)   # only now and then, so it stays funny
		if G.line_sharp(line): _margaret("provocative_gaffe")
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
	p.step("Step 1", "Which side are you on?")
	var ax: Dictionary = Game.by_id(G.AXES, opt.axis)
	var mine = G.manifesto_side(S, opt.axis)
	for side in ["L", "R"]:
		p.card("index", func(box):
			box.add_child(Look.label(("★ " if mine == side else "") + (ax.left if side == "L" else ax.right), "display", 22, Look.INK))
			if mine != "" and mine != side: box.add_child(Look.label("Against your manifesto", "body", 13, Look.RED)),
			func(): _raise_words(p, opt, side))
	p.actions([p.button("Not now", func(): p.close())])

func _raise_words(p: Paper, opt: Dictionary, side: String) -> void:
	var ax: Dictionary = Game.by_id(G.AXES, opt.axis)
	var head = func():
		_raise_head(p, opt)
		p.text("Your side: %s." % (ax.left if side == "L" else ax.right), 14, "type")
		p.small("Whether it catches on depends on your reach and on how you say it. Bold lines catch more easily, and blow up more easily.")
	var lines: Array = G.raise_lines(S, opt, side)
	var pick = func(j):
		var line: Dictionary = lines[j]
		var res: Dictionary = G.act_raise(S, opt, side, j)
		if not res.ok:
			_toast(res.text); return
		_after_speaking(res, line, opt.axis, side)
		if res.delivery.outcome == "normal": _advisor.say("raise_caught" if res.caught else "raise_fizzled", false, 0.8)
		p.clear()
		_result_body(p, opt.title, res)
		p.stamp("The debate caught on" if res.caught else "Nobody took it up", Look.GOOD if res.caught else Look.MUTED)
		p.actions([p.button("Back to work", func(): _done(p))])
		p.top()
	var chance = func(line): return "%d%% chance it catches on" % Game.jround(G.raise_chance(S, opt, line) * 100)
	if opt.side == "": _say_it(p, lines, head, 2, pick, func(): _raise_side(p, opt), "← Other side", chance)
	else: _say_it(p, lines, head, 0, pick, func(): p.close(), "Not now", chance)
