## rules/party.gd — Your party: monthly actions, offices, your politicians, steering the manifesto and the quarterly budget.
extends "res://scripts/rules/media.gd"

# ---------- Actions ----------
func manifesto_side(s: Dictionary, axis: String) -> String:
	var st = stance_of(player_party(s).manifesto[axis])
	return "L" if st <= 1 else ("R" if st >= 3 else "")

func drop_signature(s: Dictionary, key: String) -> void:
	s.signature = s.signature.filter(func(k): return k != key)
	if s.ownership.has(key): s.ownership[key].erase("player")
	s.log.append({"week": s.week, "kind": "action", "text": "Stopped campaigning on %s." % side_label(key).to_lower()})

# ---------- Communities ----------
func act_community(s: Dictionary, city: String) -> Dictionary:
	if in_campaign(s): return {"ok": false, "text": "No time to build during the campaign."}
	var lvl = community_level(s, city)
	if lvl >= COMMUNITY_MAX: return {"ok": false, "text": "Your community in %s is as big as it gets." % city}
	var cost: float = COMMUNITY_COST[lvl]
	var err = can_act(s, cost)
	if err: return {"ok": false, "text": err}
	spend_action(s, cost)
	s.communities[city] = lvl + 1
	var c = city_by_name(city)
	_community_tick(s, c, 3.0)
	var text = ("You opened a party office in %s. Volunteers, a noticeboard and a kettle." if lvl == 0 else "Your community in %s is growing: more volunteers, more events, more people who'll knock on doors.") % city
	_log(s, "action", text)
	return {"ok": true, "text": text}

## One month of a community's work (k scales it, e.g. for the opening push).
func _community_tick(s: Dictionary, c: Dictionary, k := 1.0) -> void:
	var lvl = community_level(s, c.name)
	var weight = lvl * (1.0 + 0.5 * float(c.get("size", 0))) * (2.0 if c.name == MAP.capital else 1.0)
	# an office works on its own province: the people who can walk in through the door
	var d = district_of_city(c.name)
	var where: String = d.id if d else ""
	var ctx = score_context(s)
	for pop in s.pops:
		if where != "" and pop.get("district", "") != where: continue
		if where == "" and pop.region != c.area: continue
		var sup = pop_support(s, pop, null, ctx)
		var floating = maxf(0, sup.player - pop.loyal.player)
		pop.loyal.player = clampf2(pop.loyal.player + floating * 0.012 * weight * k, 0, 0.9)
		pop.mobilized = clampf2(pop.mobilized + 0.004 * weight * k, 0, 0.15)
		pop.aware.player = clampf2(pop.aware.player + (1 - pop.aware.player) * 0.006 * weight * k, 0, 1)

func communities_monthly(s: Dictionary) -> void:
	for name in s.communities:
		_community_tick(s, city_by_name(name))
	districts_monthly(s)

# ---------- The party's politicians ----------
## Named people in your party. Each cares most about one side of one issue.
## Steering the manifesto away from it costs their loyalty; below 25 they quit,
## and take a little of the party's reach and their region's goodwill with them.
## The founders joined for the manifesto, so they share it: each one's cause is the
## manifesto's side of their issue (the other side's note is in "noteOther"). One of
## them, picked at random, is the exception: in the party for other reasons, against
## the manifesto on their issue, and slowly losing patience unless you speak up for it.
func new_figures(s: Dictionary) -> Array:
	var out = []
	var others = FIGURES.filter(func(f): return f.id != "teyl")
	var odd: String = pick(s, others).id if others.size() else ""
	for f in FIGURES:
		var x = f.duplicate()
		x.skill = float(f.get("skill", 70))
		var mine = manifesto_side(s, f.axis)
		if f.id == "teyl":
			x.loyalty = 65.0
		elif f.id == odd:
			# the bad apple: on the other side from the manifesto (or their own, if the manifesto sits in the middle)
			if mine != "" and mine == f.side: _flip_figure(x)
			x.loyalty = 40.0
			x.doubter = true
		else:
			if mine != "" and mine != f.side: _flip_figure(x)
			x.loyalty = 72.0 if mine != "" else 60.0
		out.append(x)
	return out

func _flip_figure(x: Dictionary) -> void:
	x.side = "R" if x.side == "L" else "L"
	if x.has("noteOther"): x.note = x.noteOther

## Your words on an issue reach the politicians who care about it.
func figures_heard(s: Dictionary, axis: String, side: String) -> void:
	for f in s.figures:
		if f.axis != axis: continue
		f.loyalty = clampf2(f.loyalty + (3.0 if f.side == side else -5.0), 0, 100)

func figure_by_id(s: Dictionary, id: String) -> Variant:
	for f in s.figures:
		if f.id == id: return f
	return null

## How strong the party's bench is: 1.0 with everyone you started with.
func party_bench(s: Dictionary) -> float:
	var have = 0.0
	for f in s.figures: have += float(f.get("skill", 70)) / 70.0
	return clampf2(have / maxf(1, FIGURES.size()), 0.3, 1.3)

func figures_monthly(s: Dictionary) -> void:
	for f in s.figures.duplicate():
		if not s.figures.has(f): continue   # already gone (walked out with Margaret)
		# someone whose cause the manifesto is against loses patience a little every month
		var mine = manifesto_side(s, f.axis)
		if f.id != "teyl" and mine != "" and mine != f.side: f.loyalty = clampf2(f.loyalty - 1.5, 0, 100)
		if f.loyalty >= 25: continue
		s.figures.erase(f)
		s.figuresLost.append({"name": f.name, "role": f.role, "week": s.week})
		for pop in s.pops:
			if pop.region == f.region: pop.goodwill.player = clampf2(pop.goodwill.player - 0.06, -2, 2)
		push_news(s, {"kind": "threat", "title": "%s quits %s" % [f.name, player_party(s).short],
			"text": "%s, %s, says the party is no longer the one %s joined. %s local supporters are not happy either." % [f.name, f.role.to_lower(), "she" if f.get("sex", "m") == "f" else "he", "Her" if f.get("sex", "m") == "f" else "His"]})
		if f.id != "teyl": _replace_figure(s, f)
		else: _teyl_walkout(s)

## Someone who agrees with the manifesto takes the empty chair: loyal, because they
## owe the job to you, and usually less able than the person who left.
func _replace_figure(s: Dictionary, gone: Dictionary) -> void:
	var who: Dictionary = make_person(s, gone.region)
	var mine = manifesto_side(s, gone.axis)
	var side: String = mine if mine != "" else gone.side
	var lean_word: String = side_label(side_key(gone.axis, side)).to_lower()
	s.figures.append({"id": "new_%d_%s" % [s.week, gone.id], "name": who.name, "sex": who.get("sex", "m"), "role": gone.role, "region": gone.region, "hometown": who.hometown,
		"axis": gone.axis, "side": side, "loyalty": 78.0, "skill": 30.0 + rand(s) * 20.0, "yes": true,
		"note": "Took over from %s. Agrees with the manifesto on %s, and on most things you say." % [gone.name, lean_word]})
	_log(s, "action", "%s replaces %s as %s." % [who.name, gone.name, String(gone.role).to_lower()])
	if SCANDALS.has("PARTY") and rand(s) < 0.3:
		var sk: Dictionary = pick(s, SCANDALS.PARTY)
		var f = {"name": who.name, "party": player_party(s).short}
		add_secret(s, {"kind": "party", "key": "party:" + who.name, "title": String(sk.title).format(f), "text": String(sk.text).format(f),
			"what": "%s came with something in the past nobody checked." % who.name, "size": float(sk.size), "who": {}, "figure": who.name})

# ---------- Steering the party ----------
func steer_block(s: Dictionary, axis: String, dir: int) -> String:
	if in_campaign(s): return "No time to steer the party during the campaign."
	if s.steer: return "You are already steering the party on %s." % by_id(AXES, s.steer.axis).issue.to_lower()
	var st = stance_of(player_party(s).manifesto[axis])
	if st + dir < 0 or st + dir > 4: return "The manifesto can't go further that way."
	return ""

## Is this move a step back toward the manifesto the party was founded on?
func steer_returns(s: Dictionary, axis: String, dir: int) -> bool:
	var m0: Dictionary = s.get("manifesto0", {})
	if not m0.has(axis): return false
	var now: int = stance_of(player_party(s).manifesto[axis])
	var home: int = stance_of(m0[axis])
	return absi(now + dir - home) < absi(now - home)

## Who would be upset, and who pleased, by moving `axis` one stance in `dir`.
func steer_reactions(s: Dictionary, axis: String, dir: int) -> Dictionary:
	var toward = "L" if dir < 0 else "R"
	var angry = []
	var pleased = []
	for f in s.figures:
		if f.axis != axis: continue
		if f.side == toward: pleased.append(f)
		else: angry.append(f)
	return {"angry": angry, "pleased": pleased}

func act_steer(s: Dictionary, axis: String, dir: int) -> Dictionary:
	var block = steer_block(s, axis, dir)
	if block: return {"ok": false, "text": block}
	var err = can_act(s, 0)
	if err: return {"ok": false, "text": err}
	spend_action(s, 0)
	s.steer = {"axis": axis, "dir": dir, "started": s.week, "months": 0}
	var back: bool = steer_returns(s, axis, dir)
	s.steer.back = back
	var rx = steer_reactions(s, axis, dir)
	# going back to what the party was founded on angers nobody much
	for f in rx.angry: f.loyalty = clampf2(f.loyalty - (4 if back else 15), 0, 100)
	for f in rx.pleased: f.loyalty = clampf2(f.loyalty + 5, 0, 100)
	var t = teyl(s)
	if t: t.loyalty = clampf2(t.loyalty + (4 if back else -5), 0, 100)
	var ax = by_id(AXES, axis)
	var to_name = stance_name(axis, stance_of(player_party(s).manifesto[axis]) + dir)
	var text = ("You told the party's leadership it is time to go back to \"%s\" on %s, where the party started. It will take three months." if back else "You told the party's leadership it is time to move toward \"%s\" on %s. It will take three months, and not everyone is happy.") % [to_name.to_lower(), ax.issue.to_lower()]
	_log(s, "action", text)
	return {"ok": true, "text": text}

func steer_monthly(s: Dictionary) -> void:
	if not s.steer: return
	var st: Dictionary = s.steer
	st.months += 1
	var rx = steer_reactions(s, st.axis, st.dir)
	for f in rx.angry: f.loyalty = clampf2(f.loyalty - (2 if st.get("back", false) else 8), 0, 100)
	if st.months < STEER_MONTHS: return
	var player = player_party(s)
	var cur = stance_of(player.manifesto[st.axis])
	player.manifesto[st.axis] = C.stanceCenters[clampi(cur + st.dir, 0, 4)]
	shift_perceived(s, {st.axis: st.dir * 6}, false)
	var ax = by_id(AXES, st.axis)
	push_news(s, {"kind": "issue", "quiet": true, "title": "%s changes course on %s" % [player.short, ax.issue.to_lower()],
		"text": "The party's manifesto now says %s." % stance_name(st.axis, stance_of(player.manifesto[st.axis])).to_lower()})
	_log(s, "action", "The party's new line on %s is %s." % [ax.issue.to_lower(), stance_name(st.axis, stance_of(player.manifesto[st.axis])).to_lower()])
	s.steer = null

func teyl(s: Dictionary) -> Variant:
	return figure_by_id(s, "teyl")

# ---------- Campaign budget ----------
func campaign_impact(s: Dictionary, alloc: Dictionary) -> Dictionary:
	# pop index -> {aware, goodwill, leader}
	var impact = {}
	var pops: Array = s.pops
	var add = func(i: int, k: String, v: float) -> void:
		if not impact.has(i): impact[i] = {"aware": pops[i].aware.player, "goodwill": 0.0, "leader": 0.0}
		impact[i][k] += v
	var aware_gain = func(i: int, rate: float) -> void:
		var cur: float = impact[i].aware if impact.has(i) else pops[i].aware.player
		add.call(i, "aware", (1 - cur) * clampf2(rate, 0, 0.6))
	for key in BUDGET_KEYS:
		var m = float(alloc.get(key, 0))
		if m <= 0: continue
		var region = by_id(REGIONS, key)
		if region:
			var f: float = m / region.adults
			for i in pops.size():
				if pops[i].region == key:
					aware_gain.call(i, CAMPAIGN.rally.aware * f)
					add.call(i, "goodwill", CAMPAIGN.rally.goodwill * f)
					add.call(i, "leader", CAMPAIGN.rally.leader * f)
		elif key == "social" or key == "tv":
			var c: Dictionary = CAMPAIGN[key]
			for i in pops.size():
				if c.ages.has(pops[i].age): aware_gain.call(i, c.aware * m)
		elif key == "tour":
			# the leader's image: each million buys less, it works better for a party people take
			# seriously, and less on voters who already like the leader (CAMPAIGN.tour)
			var t: Dictionary = CAMPAIGN.tour
			var sc: float = float(t.get("scale", 1.5))
			var eff: float = sc * log(1.0 + m / sc)
			var smin: float = float(t.get("seriousMin", 0.5))
			var k: float = smin + (1.0 - smin) * serious_of(s) / 100.0
			for i in pops.size():
				aware_gain.call(i, t.aware * m)
				var full: float = clampf2(float(pops[i].leader.player) / 2.0, 0, 1) * float(t.get("saturate", 0.6))
				add.call(i, "leader", float(t.leader) * eff * k * (1.0 - full) * pops[i].leaderPull)
	return impact

func preview_budget(s: Dictionary, alloc: Dictionary) -> Dictionary:
	var impact = campaign_impact(s, alloc)
	var rows = {}
	var groups = REGIONS.map(func(r): return {"id": r.id, "who": {"region": r.id}})
	groups.append_array([{"id": "young", "who": {"age": ["18-29", "30-45"]}}, {"id": "old", "who": {"age": ["46-60", "61+"]}}, {"id": "all", "who": {}}])
	for g in groups:
		var size = 0.0
		var before = 0.0
		var after = 0.0
		var lb = 0.0
		var la = 0.0
		for i in s.pops.size():
			var pop: Dictionary = s.pops[i]
			if not matches(pop, g.who): continue
			var imp = impact.get(i)
			size += pop.size
			before += pop.size * pop.aware.player
			after += pop.size * (imp.aware if imp else pop.aware.player)
			lb += pop.size * pop.leader.player
			la += pop.size * (pop.leader.player + (imp.leader if imp else 0.0))
		rows[g.id] = {"before": before / size, "after": after / size, "leaderBefore": lb / size, "leaderAfter": la / size}
	return rows

func resolve_budget(s: Dictionary, alloc: Dictionary, offers_taken := []) -> Dictionary:
	var player = player_party(s)
	var notes = []
	for id in offers_taken:
		var offer = by_id(FUNDING_OFFERS, id)
		if offer == null: continue
		apply_effects(s, merged(offer.effects, {"awareness": 0}))
		notes.append(offer.source)
		s.record.money.append({"week": s.week, "source": offer.source, "amount": float(offer.effects.get("money", 0)), "dirty": offer.effects.has("scandal"), "offer": offer.id})
		start_patron(s, offer.id)
	var clean = {}
	var spent = 0.0
	for key in BUDGET_KEYS:
		var m = clampf2(float(alloc.get(key, 0)), 0, maxf(0, s.money - spent))
		clean[key] = m
		spent += m
	var preview = preview_budget(s, clean)
	var impact = campaign_impact(s, clean)
	var swing = (rand(s) * 2 - 0.8) * CAMPAIGN.social.swing * clean.social if clean.social > 0 else 0.0
	for i in impact:
		var pop: Dictionary = s.pops[i]
		var imp: Dictionary = impact[i]
		pop.aware.player = clampf2(imp.aware, 0.01, 1)
		pop.goodwill.player = clampf2(pop.goodwill.player + imp.goodwill, -2, 2)
		pop.leader.player = clampf2(pop.leader.player + imp.leader * (player.charisma / 50.0) * (1 - C.extremeLeader / 2.0 + C.extremeLeader * float(player.get("extremity", 0))), -2, 2)
	if swing:
		for pop in s.pops:
			if CAMPAIGN.social.ages.has(pop.age): pop.goodwill.player = clampf2(pop.goodwill.player + swing, -2, 2)
	s.money -= spent
	s.roadFund = float(s.get("roadFund", 0)) + float(clean.get("road", 0))
	s.roadPerTrip = s.roadFund / 3.0   # a quarter has three trips
	s.lastBudget = clean.duplicate()
	_log(s, "budget", "Spent ₱%sM on campaigning%s." % [fmt1(spent), (". Took money from " + ", ".join(notes)) if notes.size() else ""])
	finish_front(s, "budget")
	return {"spent": spent, "preview": preview, "socialSwing": swing}

func business_mood(s: Dictionary) -> float:
	var ctx = score_context(s)
	var size = 0.0
	var sup = 0.0
	var gw = 0.0
	for pop in s.pops:
		if pop.class != "upper": continue
		size += pop.size
		sup += pop.size * pop_support(s, pop, null, ctx).player
		gw += pop.size * pop.goodwill.player
	return clampf2(0.25 + (sup / size) * 5 + (gw / size) * 0.8, 0, 1.6)

func quarterly_income(s: Dictionary) -> Dictionary:
	var share: float = s.lastSupport.player if s.lastSupport else 0.03
	var dues = 0.0
	for name in s.get("communities", {}): dues += 0.12 * s.communities[name]
	var grassroots: float = C.incomeBase + share * C.incomePerShare + dues
	var mood = business_mood(s)
	var business: float = C.businessBase * mood
	return {"grassroots": grassroots, "business": business, "mood": mood, "total": grassroots + business}

func draw_offers(s: Dictionary) -> Array:
	var mood = business_mood(s)
	var pool = []
	for o in FUNDING_OFFERS:
		if s.get("patron") and foreign_deal(o.id) != null: continue
		var chance: float = o.chance * minf(1.3, mood) if o.id == "chamber" else o.chance
		if rand(s) < chance: pool.append(o)
	return shuffle(s, pool).slice(0, 2).map(func(o): return o.id)
