## main_moments.gd — the budget, polls, news, the TV debate, election night, the interview, the coalition talks.
extends "res://scripts/main_events.gd"
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
	var rent: float = float(inc.get("upkeep", 0.0))
	p.text("This quarter you raised ₱%sM: ₱%sM from members and small donors, who give more as your party grows, and ₱%sM from business, which is %s%s. %d%% of adults know your party. Whatever you don't spend is saved." % [Game.fmt1(inc.total), Game.fmt1(inc.grassroots), Game.fmt1(inc.business), Game.business_word(inc.mood), (", less ₱%dk in rent and wages for your offices" % Game.jround(rent * 1000)) if rent > 0 else "", Game.jround(pv.all.before * 100)], 16)
	var offers: Array = front.get("offers", [])
	if offers.size():
		p.add(Look.caps("Money on the table", 11, Look.MUTED, 2))
		for id in offers:
			var o = Game.by_id(G.FUNDING_OFFERS, id)
			var taken: bool = _offers.has(id)
			var dirty: bool = o.effects.has("scandal")
			p.card("index", func(box):
				box.add_child(Look.label(("✓ Taking it · " if taken else "") + o.title, "news_bold", 19, Look.RED if dirty else Look.INK, true))
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
	rows.append(["social", "Social media", "Voters under 46 hear of you and get to know %s. Cheap; the reaction is unpredictable." % player.leader, pv.young])
	rows.append(["tv", "TV and newspapers", "Voters over 45 across the country hear of you and get to know %s." % player.leader, pv.old])
	var pc: float = float(G.C.upkeep.get("pollCost", 1.0))
	rows.append(["polling", "Better polling", "Pay the pollsters for a careful job: this quarter's polls come without their random noise (they still only ask a sample, so they can still be a little off). ₱%sM a quarter." % Game.fmt1(pc), pv.all])
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
		elif row[0] == "polling":
			known = "This quarter: %s" % ("careful polls, no random noise" if _budget.polling >= pc - 0.001 else "the usual polls, give or take a point or two")
		else:
			known = "Know you: %s%%%s · Leader image: %s%s" % [Game.fmt1(pr.before * 100), (" → %s%%" % Game.fmt1(pr.after * 100)) if pr.after - pr.before > 0.0005 else "",
				Files.leader_score(pr.leaderBefore), (" → " + Files.leader_score(pr.leaderAfter)) if pr.leaderAfter - pr.leaderBefore > 0.005 else ""]
		info.add_child(Look.label(known, "body", 12, Look.INK))
		h.add_child(info)
		var k: String = row[0]
		var step: float = pc if k == "polling" else 0.5   # better polling is on or off
		h.add_child(p.button("−", func():
			_budget[k] = maxf(0, _budget[k] - step)
			_budget_build(p, front), false, _budget[k] <= 0))
		var amt = Look.label("₱%sM" % Game.fmt1(_budget[k]), "type", 17, Look.INK)
		amt.custom_minimum_size.x = 72
		amt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(amt)
		var full: bool = k == "polling" and _budget[k] >= pc - 0.001
		h.add_child(p.button("+", func():
			if left >= step - 1e-9 and not full: _budget[k] += step
			_budget_build(p, front), false, left < step - 1e-9 or full))
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
		p.add(Look.label("%s — %s leads with %d%%. You: %d%%." % [r.name, G.party_of(S, ids[0]).short, Game.jround(sh[ids[0]] * 100), Game.jround(sh.player * 100)], "body", 15, Look.INK, true))
	p.actions([p.button("File it", func(): G.dismiss_front(S); _done(p))])

func _news_sheet(front: Dictionary) -> void:
	var labels = {"vacuum": "Power vacuum", "bad": "Trouble", "good": "Comeback", "neutral": "Change", "threat": "Threat", "issue": "Hot issue"}
	var p = _paper(820)
	var lead: Dictionary = front.items[0]
	p.source(_outlet("herald"), "%s · %s" % [labels.get(lead.get("kind", ""), "News"), G.date_label(S.week, false)])
	p.heading(lead.title, 38)
	p.photo(Photo.find(["news/" + str(lead.get("kind", ""))]), 260)
	p.text(lead.text, 18)
	if front.items.size() > 1:
		p.rule(2)
		# the rest of the page, in columns under the lead
		var cols = HBoxContainer.new()
		cols.add_theme_constant_override("separation", 16)
		var rest: Array = front.items.slice(1)
		for i in rest.size():
			var it: Dictionary = rest[i]
			if i > 0:
				var cr = ColorRect.new(); cr.color = Look.INK; cr.custom_minimum_size.x = 1
				cols.add_child(cr)
			var col = VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_theme_constant_override("separation", 6)
			col.add_child(Look.caps(labels.get(it.get("kind", ""), "News"), 11, Look.RED, 2))
			col.add_child(Look.label(it.title, "news_bold", 21, Look.INK, true))
			var body = Look.label(it.text, "news", 15, Look.INK, true)
			body.horizontal_alignment = HORIZONTAL_ALIGNMENT_FILL
			col.add_child(body)
			cols.add_child(col)
		p.add(cols)
	p.actions([p.button("Read on", func(): G.dismiss_front(S); _done(p))])

func _debate_sheet() -> void:
	var p = _paper(860)
	p.screen()
	_debate_round(p)

func _debate_round(p: Paper) -> void:
	p.clear()
	var d: Dictionary = S.debate
	var rd: Dictionary = d.rounds[d.step]
	p.tv_strap(_tv("Live"), "The final debate · question %d of %d" % [d.step + 1, d.rounds.size()])
	p.heading(rd.title, 36)
	p.text(rd.prompt, 18)
	p.step("Your answer", "What do you say?")
	for j in rd.lines.size():
		var line: Dictionary = rd.lines[j]
		p.card("slip", func(box):
			_tone_tag(box, line, "", true)
			box.add_child(Look.label(line.text, "news_italic", 20, Look.INK, true)), func():
			var res: Dictionary = G.answer_debate(S, j)
			p.clear()
			p.decided()
			p.tv_strap(_tv("Live"), "The final debate · " + res.round)
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

# ---------- The big interview ----------
func _interview_sheet() -> void:
	var p = _paper(860)
	p.screen()
	_interview_round(p)

func _interview_round(p: Paper) -> void:
	p.clear()
	var iv: Dictionary = S.interview
	var rd: Dictionary = iv.rounds[iv.step]
	p.tv_strap(iv.outletName, "The big interview · question %d of %d" % [iv.step + 1, iv.rounds.size()])
	if iv.step == 0: p.text("An hour with %s on %s: the first time most of the country hears %s properly. %s doesn't take sides, and doesn't let a dodge go." % [iv.who, iv.outletName, G.player_party(S).leader, iv.who], 15, "news_italic")
	p.heading(rd.title, 36)
	p.text(rd.prompt, 18)
	p.step("Your answer", "What do you say?")
	for j in rd.lines.size():
		var line: Dictionary = rd.lines[j]
		p.card("slip", func(box):
			_tone_tag(box, line, "", true)
			box.add_child(Look.label(line.text, "news_italic", 20, Look.INK, true)), func():
			var res: Dictionary = G.answer_interview(S, j)
			p.clear()
			p.decided()
			p.tv_strap(iv.outletName, "The big interview · " + res.round)
			p.add(Look.label(res.quote, "news_bold", 24, Look.INK, true))
			p.text(res.press, 17, "news_italic")
			if res.note != "": p.small(res.note, Look.INK)
			if res.outcome == "viral": p.stamp("The clip of the year", Look.GOOD)
			elif res.outcome == "gaffe": p.stamp("Gaffe", Look.RED)
			_changes_chips(p, res.changes)
			var more: bool = S.queue.size() and S.queue[0].type == "interview"
			p.actions([p.button("Next question" if more else "Read the piece", func():
				if more: _interview_round(p)
				else: _interview_piece(p))])
			p.top())
	p.top()

# ---------- Going on a programme (the campaign) ----------
func _appearance_sheet() -> void:
	var p = _paper(860)
	p.screen()
	_appearance_round(p)

func _appearance_round(p: Paper) -> void:
	p.clear()
	var ap: Dictionary = S.appearance
	var rd: Dictionary = ap.rounds[ap.step]
	p.tv_strap(ap.outletName, "Tonight's guest · question %d of %d" % [ap.step + 1, ap.rounds.size()])
	p.heading(rd.title, 32)
	p.text(rd.prompt, 18)
	p.step("Your answer", "What do you say?")
	for j in rd.lines.size():
		var line: Dictionary = rd.lines[j]
		p.card("slip", func(box):
			_tone_tag(box, line, "", true)
			box.add_child(Look.label(line.text, "news_italic", 20, Look.INK, true)), func():
			var res: Dictionary = G.answer_appearance(S, j)
			p.clear()
			p.decided()
			p.tv_strap(ap.outletName, "Tonight's guest · " + res.round)
			p.add(Look.label(res.quote, "news_bold", 24, Look.INK, true))
			p.text(res.press, 17, "news_italic")
			if res.note != "": p.small(res.note, Look.INK)
			if res.outcome == "viral": p.stamp("The clip of the week", Look.GOOD)
			elif res.outcome == "gaffe": p.stamp("Gaffe", Look.RED)
			_changes_chips(p, res.changes)
			var more: bool = S.queue.size() and S.queue[0].type == "appearance"
			p.actions([p.button("Next question" if more else "Off air", func():
				if more: _appearance_round(p)
				else: _done(p))])
			p.top())
	p.top()

## The piece the outlet runs the next morning.
func _interview_piece(p: Paper) -> void:
	p.clear()
	p.decided()
	p.paper()
	var iv: Dictionary = S.interview
	var v: Dictionary = iv.get("verdict", {}) if iv.get("verdict") else {"title": "", "text": ""}
	p.source(iv.outletName, "The big interview · %s" % G.date_label(S.week, false))
	p.kicker("%s meets %s" % [iv.who, G.player_party(S).leader])
	p.heading(v.title, 40)
	p.text(v.text, 18, "news_italic")
	for n in v.get("notes", []): p.text(String(n), 16)
	var best = null
	for r in iv.results:
		if best == null or r.outcome == "viral": best = r
	if best: p.quote(String(best.quote).trim_prefix("\"").trim_suffix("\""), "%s, %s" % [G.player_party(S).leader, iv.outletName])
	p.small("Most of the country now knows who %s is. What they think of it is another matter." % G.player_party(S).leader, Look.INK)
	p.actions([p.button("Back to work", func(): _done(p))])
	p.top()

func _election_sheet() -> void:
	var r: Dictionary = S.result
	var p = _paper(860, false)
	p.screen()
	p.tv_strap(_tv("Election night"), "The results")
	var you: Dictionary = G.player_party(S)
	var first = G.party_of(S, r.ranking[0])
	var alone: bool = int(r.seats.national[r.ranking[0]]) > int(G.C.seats) / 2
	p.heading(("%s wins a majority" if alone else "%s is the largest party") % (you.name if r.playerWon else first.name), 38)
	_bars_into(p, r.votes, null)
	p.add(Look.caps("Seats (%d to win)" % int(G.C.seats / 2 + 1), 11, Look.MUTED, 2))
	var seatbar = SeatBar.new(r.ranking.map(func(id): return [Color(G.party_of(S, id).color), r.seats.national[id]]), int(G.C.seats))
	seatbar.custom_minimum_size.y = 30
	p.add(seatbar)
	var out_of: Array = []
	for id in r.ranking:
		if int(r.seats.national[id]) > 0: p.add(Look.label("%s — %d seats" % [G.party_of(S, id).name, r.seats.national[id]], "body", 15, Look.INK))
		else: out_of.append("%s (%s%%)" % [G.party_of(S, id).name, Game.fmt1(float(r.votes.get(id, 0)) * 100)])
	if out_of.size(): p.small("Under %d%% of the vote, no seats: %s." % [Game.jround(G.threshold() * 100), ", ".join(out_of)])
	var talks: bool = r.has("coalition") and not r.coalition.log.any(func(st): return st.t == "majority")
	var co_out: Dictionary = G.COALITION.get("OUTCOMES", {}).get(r.get("coalition", {}).get("outcome", ""), {})
	if r.has("coalition") and not talks and co_out.has("line"): p.small(String(co_out.line), Look.INK)
	elif talks: p.small("No party has a majority of its own. The parties now bargain over who governs.", Look.INK)
	p.actions([
		p.button("Watch the coalition talks", func():
			p.close()
			_coalition_view(), true) if talks else p.button("Read what the papers say", func(): _profile_sheet(), false),
		p.button("Found a new party", func():
			p.close()
			_founding_sheet(), false) if (not talks or r.get("talksSeen", false)) else null,
		p.button("Close", func():
			if S.queue.size() and S.queue[0].type == "election": G.dismiss_front(S)
			_done(p)),
	])

## The coalition talks, played back on their own screen; afterwards, the papers.
func _coalition_view() -> CoalitionView:
	var v = CoalitionView.new()
	v.setup(G, S)
	if S.result: S.result.talksSeen = true   # a new party can be founded once the talks have been seen
	_sheet_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_sheet_layer.add_child(v)
	_advisor.visible = false   # nothing but the parties on this screen
	v.finished.connect(func():
		v.queue_free()
		_advisor.visible = true
		_profile_sheet())
	return v
