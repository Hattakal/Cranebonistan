## main_places.gd — a province, a trip and the campaign convoy.
extends "res://scripts/main_moments.gd"
# ---------- A district: who would win it, and the leader's visit ----------
func _district_sheet(id: String) -> void:
	var d = G.district_by_id(id)
	var r = Game.by_id(G.REGIONS, d.region)
	var x: Dictionary = S.get("projection", {}).get(id, {})
	var p = _paper(640, false)
	p.kicker("District · %s · %d seat%s" % [r.name, d.seats, "" if d.seats == 1 else "s"])
	p.heading(d.name, 36)
	if d.cities.size(): p.small("Includes " + ", ".join(d.cities) + ".")
	for pk in S.get("pacts", []):
		if pk.district != d.id: continue
		var nm = func(id): return "you" if id == "player" else String(G.party_of(S, id).short)
		p.small("Pact: %s stand%s aside here for %s." % [nm.call(pk.aside).capitalize() if pk.aside == "player" else nm.call(pk.aside), "" if pk.aside == "player" else "s", nm.call(pk.gets)], Look.INK)
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
			p.add(Look.label("%s%s  %d%%" % ["★ " if k == x.winner else "", name, Game.jround(shares[k] * 100)], "body_bold", 17, Color(G.party_of(S, k).color).darkened(0.25) if k != "player" else Look.RED))
		if x.winner == "player":
			p.small("Yours today, by %d points. Votes beyond what wins it are wasted: if it's safe, campaign elsewhere." % maxi(1, Game.jround(float(x.margin) * 100)), Look.INK)
		else:
			p.small("You'd need about %d more points to take it." % maxi(1, Game.jround((float(x.share) - float(x.you)) * 100)), Look.INK)
		if w < int(d.seats): p.small("The other %d seat%s go to parties by their vote across the whole country, so every vote here still counts toward them." % [int(d.seats) - w, "" if int(d.seats) - w == 1 else "s"])
	var st: Dictionary = S.districts.get(id, {})
	if int(st.get("visits", 0)) > 0: p.small("%s has toured here %d time%s." % [G.player_party(S).leader, int(st.visits), "" if int(st.visits) == 1 else "s"])
	# rivals campaigning here: why your share can fall without you doing anything
	var here: Array = _rivals_here(id)
	if here.size(): p.callout("%s %s been campaigning here. When a rival's leader tours a province, people there warm to them, and every other party's share shrinks, yours included. It fades over a few months; a trip or an office of your own answers it." % [" and ".join(here), "has" if here.size() == 1 else "have"], Look.MUTED)
	# offices in this province's cities
	for cname in d.cities:
		var lvl: int = G.community_level(S, cname)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var lab = Look.label("%s · party office %s" % [cname, "●".repeat(lvl) + "○".repeat(G.COMMUNITY_MAX - lvl)], "body", 15, Look.INK)
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lab)
		if lvl < G.COMMUNITY_MAX:
			var cost: float = G.COMMUNITY_COST[lvl]
			var ob = p.button(("Open an office · ₱%sM" if lvl == 0 else "Grow it · ₱%sM") % Game.fmt1(cost), func():
				var res: Dictionary = G.act_community(S, cname)
				_toast(res.text)
				p.close()
				_after_change()
				if res.ok: _district_sheet(id), false, G.can_act(S, cost) != "" or S.queue.size() > 0 or G.in_campaign(S))
			ob.tooltip_text = "One action. An office works every month on this province: it turns your supporters here into core voters, gets them to the polls and pays a little in dues."
			row.add_child(ob)
		p.add(row)
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
func _tour_result(p: Paper, res: Dictionary, from_desk := false) -> void:
	p.clear()
	p._paper.custom_minimum_size.x = 860   # the district sheet is narrow; the story gets a full page
	var r = Game.by_id(G.REGIONS, res.region)
	var rally: bool = res.get("rally", false)
	p.source("The %s Courier" % r.name, "%s · %s" % ["The campaign" if rally else "On the road", G.date_label(S.week, false)])
	p.kicker(("The convoy in %s · week %d of %d" % [res.place, G.campaign_stop_index(S) + 1, int(G.C.campaign.weeks)]) if rally else ("%s in %s" % [G.player_party(S).leader, res.place]))
	var heads = {"great": "%s packs the square in %s", "good": "%s rallies %s", "flat": "A thin crowd in %s for %s"} if rally else {"great": "%s packs the halls in %s", "good": "%s makes the rounds in %s", "flat": "A quiet visit to %s for %s"}
	var head: String = heads.get(res.kind, "%s in %s")
	p.heading(head % ([G.player_party(S).leader, res.place] if res.kind != "flat" else [res.place, G.player_party(S).leader]), 34)
	var photo = TourPhoto.new()
	photo.kind = res.kind
	photo.region = res.region
	photo.party_color = Color(G.player_party(S).color)
	photo.custom_minimum_size = Vector2(0, 260)
	p.add(photo)
	if res.caption != "": p.small(res.caption)
	if res.story != "": p.text(res.story, 18)
	if String(res.get("vignette", "")) != "": p.boxed("Also on the road", res.vignette)
	var b: int = Game.jround(float(res.before) * 100)
	var a: int = Game.jround(float(res.after) * 100)
	# small moves in big provinces: one decimal, so a real gain doesn't read as nothing
	var bt: String = ("%d%%" % b) if a != b else "%s%%" % Game.fmt1(float(res.before) * 100)
	var at: String = ("%d%%" % a) if a != b else "%s%%" % Game.fmt1(float(res.after) * 100)
	p.add(Look.label("Your vote in %s: %s → %s" % [res.place, bt, at], "news_bold", 24, Look.GOOD if float(res.after) > float(res.before) + 0.0005 else Look.INK))
	if res.why.size():
		var w: String = ", ".join(res.why)
		p.small(w.substr(0, 1).to_upper() + w.substr(1) + ".", Look.INK)
	p.small(("The provinces close by heard about it too, a little.") if rally else ("The rest of %s heard about it too, a little." % r.name))
	p.actions([p.button("Back to work", func():
		if from_desk and S.queue.size() and S.queue[0].type == "rally": G.dismiss_front(S)
		_done(p))])
	p.top()

## This week's convoy stop, as the local paper ran it.
func _rally_sheet(front: Dictionary) -> void:
	var p = _paper(860)
	_tour_result(p, front.res, true)

# ---------- The campaign convoy ----------

## The first stop that can still be changed (the ones before it have happened).
func _route_open_from() -> int:
	return maxi(0, G.campaign_stop_index(S) + 1) if G.in_campaign(S) else 0

## The convoy's route: where it has been and where it goes next.
func _convoy_sheet(from_desk := false) -> void:
	var p = _paper(720)
	var weeks: int = int(G.C.campaign.weeks)
	p.source("Campaign headquarters", "The campaign · %s" % G.date_label(S.week, false))
	p.heading("The convoy", 34)
	p.text("One rally a week, in a different province each time. The convoy can only travel so far in a week, so the route runs from neighbour to neighbour. The rest of the country hears a little about each stop; the provinces close by a little more.", 15)
	var route: Array = S.get("convoy", {}).get("route", [])
	var open_from: int = _route_open_from()
	var lines = []
	for i in route.size():
		var d = G.district_by_id(route[i])
		var mark: String = "✓ " if i < open_from else ""
		lines.append("%sWeek %d · %s · %d seat%s" % [mark, i + 1, d.name, int(d.seats), "" if int(d.seats) == 1 else "s"])
	p.text("\n".join(lines), 15)
	if S.get("rivalConvoys", {}).size():
		var rl = []
		for pid in S.rivalConvoys:
			var pr = G.party_of(S, pid)
			var nx: Array = S.rivalConvoys[pid].slice(open_from, open_from + 3).map(func(id): return G.district_by_id(id).name)
			if pr and nx.size(): rl.append("%s: %s" % [pr.short, ", ".join(nx)])
		if rl.size(): p.small("Next on the rivals' convoys: " + "; ".join(rl) + ".")
	if G.in_campaign(S):
		p.rule(2)
		p.heading("Adverts", 24)
		p.text("A national advert campaign: every channel, every phone, for a week. Everyone sees it; each one after the first does a little less. Uses one of this week's actions.", 15)
		var cost: float = float(G.C.campaign.adCost)
		var blocked: String = G.can_act(S, cost)
		if S.queue.size() and not from_desk: blocked = "Finish the decision on your desk first."
		var ad = p.button("Run a national advert campaign · ₱%sM" % Game.fmt1(cost), func():
			var r: Dictionary = G.act_ad_campaign(S)
			_toast(r.text)
			p.close()
			_after_change(), false)
		ad.disabled = blocked != ""
		ad.tooltip_text = blocked
		p.add(ad)
	var acts = []
	if open_from < weeks:
		acts.append(p.button("Change the route", func():
			p.close()
			_route_edit = true
			_route_from = open_from
			_route_draft = route.slice(0, open_from)
			_toast("Click the provinces in order. Lit ones are within a week's reach.")
			_render_map(), false))
	acts.append(p.button("Keep this route", func():
		if from_desk and S.queue.size() and S.queue[0].type == "convoy": G.dismiss_front(S)
		_done(p)))
	p.actions(acts)

func _route_undo() -> void:
	if _route_draft.size() > _route_from: _route_draft.pop_back()
	_render_map()

## A province clicked while choosing the route.
func _route_pick(id: String) -> void:
	if _route_draft.has(id): _toast("The convoy goes to each province once."); return
	var prev: String = _route_draft[-1] if _route_draft.size() else ""
	if not G.convoy_reaches(prev, id): _toast("Too far from %s for one week on the road." % G.district_by_id(prev).name); return
	_route_draft.append(id)
	if _route_draft.size() >= int(G.C.campaign.stops): _route_finish(true)
	else: _render_map()

## Done choosing (or cancelled): stops not chosen are planned to follow on.
func _route_finish(keep: bool) -> void:
	if keep and _route_draft.size() > _route_from:
		var tail: Array = _route_draft.slice(_route_from)
		var n_left: int = int(G.C.campaign.stops) - _route_draft.size()
		if n_left > 0: tail.append_array(G.plan_route(S, "player", n_left, _route_draft[-1], _route_draft))
		var err: String = G.set_route(S, _route_from, tail)
		if err != "": _toast(err)
		else: _save()
	_route_edit = false
	_render_map()
	_after_change()
