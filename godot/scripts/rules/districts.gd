## rules/districts.gd — The provinces: their seats, local standing, the leader's trips, results and seat allocation; the news queue and the election.
extends "res://scripts/rules/voters.gd"

# ---------- News ----------
func flush_news(s: Dictionary) -> void:
	if s.news.is_empty(): return
	# debate headlines only reach the ticker and the board; the rest stop the clock
	var loud = s.news.filter(func(n): return not n.get("quiet", false))
	if loud.size(): s.queue.push_front({"type": "news", "items": loud})
	for n in s.news:
		var t: String = n.title
		s.log.append({"week": n.week, "kind": "news", "text": t if t.right(1) in [".", "?", "!"] else t + "."})
	s.news = []

# ---------- Districts ----------
func _load_districts() -> void:
	DISTRICTS = MAP.get("districts", [])
	var data: Dictionary = {}
	var dd = Mods.data("districts")
	if dd is Dictionary: data = dd
	var over: Dictionary = data.get("DISTRICTS", {})
	var weight: Dictionary = data.get("REGION_WEIGHT", {})
	# overrides by id or by name: a new name, fixed seats, a lean of its own
	for d in DISTRICTS:
		var o: Dictionary = over.get(d.id, over.get(d.name, {}))
		if o.has("name"): d.name = o.name
		d.fixedSeats = int(o.get("seats", 0))
		d.fixedLean = o.get("lean", {})
	# seats by population, weighted by region (largest remainder), at least one each
	var total = 0.0
	var fixed_total = 0
	for d in DISTRICTS:
		d.people = float(by_id(REGIONS, d.region).adults) * float(d.share)
		if d.fixedSeats > 0: fixed_total += d.fixedSeats
		else: total += d.people * float(weight.get(d.region, 1.0))
	var seats_left: int = maxi(0, int(C.seats) - fixed_total)
	var rows = []
	for d in DISTRICTS:
		if d.fixedSeats > 0:
			d.seats = d.fixedSeats
			continue
		var exact: float = seats_left * d.people * float(weight.get(d.region, 1.0)) / total
		d.seats = maxi(1, int(floor(exact)))
		rows.append({"d": d, "rest": exact - floor(exact)})
	var given = 0
	for d in DISTRICTS: given += int(d.seats)
	for r in ssort(rows, func(a, b): return b.rest - a.rest).slice(0, maxi(0, int(C.seats) - given)): r.d.seats += 1

## Fresh local differences for a new game: a lean of its own (built into its voters) and rival strongholds.
func new_districts(s: Dictionary) -> Dictionary:
	var out = {}
	for d in DISTRICTS:
		var lean = {}
		for ax in AXES: lean[ax.id] = float(jround(rand_normal(s) * 6 + float(d.fixedLean.get(ax.id, 0))))
		var rivals = {}
		for p in s.parties:
			if not p.isPlayer: rivals[p.id] = fixed(rand_normal(s) * 0.12, 3)
		out[d.id] = {"lean": lean, "aware": 0.0, "goodwill": 0.0, "rivals": rivals, "visits": 0}
	return out

## Votes in one district: its own voters (build_pops), with its local standing (party_score).
func district_votes(s: Dictionary, d: Dictionary, ctx, cache = null, pops = null) -> Dictionary:
	var out = {}
	for p in s.parties: out[p.id] = 0.0
	for m in MINOR_PARTIES: out[m.id] = 0.0
	for pop in (pops if pops != null else s.pops):
		if pop.get("district", "") != d.id: continue
		var sup = cache[pop.id] if cache != null and cache.has(pop.id) else pop_support(s, pop, null, ctx)
		var votes = pop_votes(pop, sup)
		for id in votes: out[id] += votes[id]
	for pk in s.get("pacts", []):   # a party standing aside: most of its voters go to its partner
		if pk.district != d.id: continue
		var moved: float = float(out.get(pk.aside, 0.0)) * float(C.get("pacts", {}).get("share", 0.7))
		out[pk.aside] = float(out.get(pk.aside, 0.0)) - moved
		out[pk.gets] = float(out.get(pk.gets, 0.0)) + moved
	return out

## Every district: votes, the winner, the runner-up and the winning margin (share points).
func district_results(s: Dictionary, cache = null, ctx = null, pops = null) -> Dictionary:
	if ctx == null: ctx = score_context(s)
	var out = {}
	for d in DISTRICTS: out[d.id] = district_result(s, d, ctx, cache, pops)
	_bar_small_parties(out)
	return out

## Parties under the national threshold win no seats: where one of them comes first
## or second in a district, the district goes to the best of the others.
func _bar_small_parties(res: Dictionary) -> void:
	var t: float = threshold()
	if t <= 0: return
	var nat = {}
	var all = 0.0
	for id in res:
		for k in res[id].votes:
			nat[k] = float(nat.get(k, 0.0)) + float(res[id].votes[k]); all += float(res[id].votes[k])
	if all <= 0: return
	var barred = []
	for k in nat:
		if nat[k] / all < t: barred.append(k)
	if barred.size() == nat.size(): return
	for id in res:
		var x: Dictionary = res[id]
		x.barred = barred
		if not (barred.has(x.winner) or barred.has(x.second)): continue
		var v: Dictionary = x.votes
		var tot = dsum(v)
		var ids: Array = ssort(v.keys().filter(func(k): return not barred.has(k)), func(a, b): return v[b] - v[a])
		x.winner = ids[0]
		x.second = ids[1] if ids.size() > 1 else ids[0]
		x.share = v[x.winner] / tot if tot else 0.0
		x.margin = (v[x.winner] - v[x.second]) / tot if tot else 0.0

func district_result(s: Dictionary, d: Dictionary, ctx, cache = null, pops = null) -> Dictionary:
	var v: Dictionary = district_votes(s, d, ctx, cache, pops)
	var tot = dsum(v)
	var ids: Array = ssort(v.keys(), func(a, b): return v[b] - v[a])
	return {"votes": v, "winner": ids[0], "second": ids[1], "seats": int(d.seats),
		"share": v[ids[0]] / tot if tot else 0.0, "margin": (v[ids[0]] - v[ids[1]]) / tot if tot else 0.0,
		"you": v.player / tot if tot else 0.0}

## A district's poll figures with one party's share moved to `share`, the others
## keeping their proportions (so the map and the trip page tell the same story).
func _with_share(res: Dictionary, d: Dictionary, pid: String, share: float) -> Dictionary:
	var v: Dictionary = res.votes.duplicate()
	var rest = 0.0
	for k in v:
		if k != pid: rest += float(v[k])
	if rest <= 0 or share >= 1: return res
	v[pid] = share / (1.0 - share) * rest
	var tot = dsum(v)
	var ids: Array = ssort(v.keys(), func(a, b): return v[b] - v[a])
	return {"votes": v, "winner": ids[0], "second": ids[1], "seats": int(d.seats),
		"share": v[ids[0]] / tot, "margin": (v[ids[0]] - v[ids[1]]) / tot, "you": float(v.get("player", 0)) / tot}

func visit_block(s: Dictionary) -> String:
	if s.result: return "The election is over."
	if in_campaign(s): return "%s is on the campaign convoy now." % player_party(s).leader
	if int(s.get("lastVisit", -99)) / WEEKS_PER_MONTH == s.week / WEEKS_PER_MONTH: return "%s has already been on the road this month." % player_party(s).leader
	return ""

## What makes this trip bigger or smaller. Returns the multiplier and the reasons, in words.
func visit_power(s: Dictionary, id: String) -> Dictionary:
	var d = district_by_id(id)
	var st: Dictionary = s.districts[id]
	var why: Array = []
	# going back soon helps less; after CONFIG.revisitMonths they're glad to see you again
	var k = 1.0
	if st.has("lastVisit"):
		var since: float = float(s.week - int(st.lastVisit)) / WEEKS_PER_MONTH
		var span: float = float(C.get("revisitMonths", 8))
		if since < span:
			k = lerpf(float(C.get("revisitLow", 0.5)), 1.0, since / span)
			why.append("they saw you %s" % ("last month" if since < 1.5 else "%d months ago" % int(round(since))))
	# the money set aside for trips this quarter
	var m: float = minf(float(s.get("roadFund", 0)), float(s.get("roadPerTrip", 0)))
	if m > 0:
		k *= 1.0 + 0.6 * sqrt(m)
		why.append("bigger halls and buses (₱%sM)" % fmt1(m))
	# popularity: a party people have heard good things about draws crowds
	var sup: float = float(s.lastSupport.player) if s.lastSupport else 0.0
	var pop_k: float = clampf2(0.7 + sup * 3.0, 0.7, 1.6) * sqrt(player_party(s).charisma / 50.0)
	k *= pop_k
	if pop_k >= 1.1: why.append("people want to see you")
	elif pop_k <= 0.8: why.append("few people know who you are yet")
	# a base there: an office, and voters who already back you
	var office = 0
	for c in d.cities: office = maxi(office, community_level(s, c))
	var you: float = float(s.projection.get(id, {}).get("you", 0))
	var base_k: float = 1.0 + 0.15 * office + you
	k *= base_k
	if office > 0: why.append("your office there filled the hall")
	# you spoke up recently for something these voters lean toward and care about
	var local_pos: Dictionary = summarize(s, pops_matching(s, {"district": id})).pos
	var bonus = 0.0
	var topic = ""
	for key in s.spoke:
		if s.week - int(s.spoke[key]) > 2 * WEEKS_PER_MONTH: continue
		var ax: String = key.split(":")[0]
		var sg = -1.0 if key.ends_with(":L") else 1.0
		var lean: float = float(local_pos[ax])
		if sg * lean > 10:
			var b: float = clampf2(sg * lean / 60.0, 0, 0.5)
			if b > bonus: bonus = b; topic = side_label(key).to_lower()
	if bonus > 0:
		k *= 1.0 + bonus
		why.append("you spoke up for %s, and they noticed" % topic)
	# you spoke up about a story from this very province
	var ls = s.get("localSpoke", {}).get(id)
	if ls and s.week - int(ls.week) <= LOCAL_STORY_MONTHS * WEEKS_PER_MONTH:
		k *= 1.0 + LOCAL_STORY_BONUS
		why.append("you spoke up about %s, and they remember" % ls.title)
	return {"k": k, "money": m, "why": why}

func act_visit(s: Dictionary, id: String) -> Dictionary:
	var block = visit_block(s)
	if block: return {"ok": false, "text": block}
	s.lastVisit = s.week
	return tour(s, id)

## The leader in a province: a monthly trip, or (rally = true) the campaign convoy's stop,
## `mult` times as strong; a trip warms the rest of the region a little, a rally the
## provinces close by (CONFIG.campaign).
func tour(s: Dictionary, id: String, mult := 1.0, rally := false) -> Dictionary:
	var d = district_by_id(id)
	var st: Dictionary = s.districts[id]
	var exact_before: float = float(district_result(s, d, score_context(s)).you)
	# the number the player sees on the map is the poll's; the trip moves it by what really changed
	var before: float = float(s.projection.get(id, {}).get("you", exact_before))
	var pw: Dictionary = visit_power(s, id)
	var k: float = pw.k * mult
	st.visits = int(st.visits) + 1
	st.lastVisit = s.week
	s.roadFund = maxf(0, float(s.get("roadFund", 0)) - pw.money)
	district_boost(s, id, VISIT_AWARE * k, VISIT_GOODWILL * k)
	for o in DISTRICTS:
		if o.id == id: continue
		if rally:
			if district_centre(o).distance_to(district_centre(d)) <= float(C.campaign.nearReach):
				district_boost(s, o.id, VISIT_AWARE * k * float(C.campaign.near), VISIT_GOODWILL * k * float(C.campaign.near))
		elif o.region == d.region: district_boost(s, o.id, VISIT_AWARE * k * 0.1, VISIT_GOODWILL * k * 0.06)
	var real: Dictionary = district_result(s, d, score_context(s))
	var after: float = clampf2(before + (float(real.you) - exact_before), 0.0, 0.95)
	s.projection[id] = _with_share(s.projection.get(id, real), d, "player", after)
	var text = ("The convoy stopped in %s: a rally, a market walkabout, a local radio phone-in. Your vote there: %d%% → %d%%." % [d.name, jround(before * 100), jround(after * 100)]) if rally else ("%s spent the month in %s: town halls, a market walkabout, a local radio phone-in. Your vote there: %d%% → %d%%." % [player_party(s).leader, d.name, jround(before * 100), jround(after * 100)])
	if pw.why.size():
		var w: String = ", ".join(pw.why)
		text += " " + w.substr(0, 1).to_upper() + w.substr(1) + "."
	_log(s, "action", ("The convoy stopped in %s." if rally else "Toured %s.") % d.name)
	# a short story from the trip, by how well it went
	var gain: float = (after - before) * 100
	var kind = "great" if gain >= 4 else ("good" if gain >= 1.5 else "flat")
	var town: String = d.name
	var best = -1.0
	for c in d.cities:
		var pop: float = float(CITY_INFO.get(c, {}).get("population", 0))
		if pop > best: best = pop; town = c
	var story = {"text": "", "caption": ""}
	var pool: Array = TOURS.get(kind, [])
	if pool.size(): story = pick(s, pool)
	var fill = {"leader": player_party(s).leader, "place": d.name, "town": town}
	return {"ok": true, "text": text, "kind": kind, "place": d.name, "region": d.region, "before": before, "after": after, "rally": rally, "district": id,
		"why": pw.why, "story": String(story.text).format(fill), "caption": String(story.caption).format(fill),
		"vignette": _trip_vignette(s, d, fill)}

## Now and then a trip has a small aside (data/tours.json VIGNETTES): flavour, with at most
## a tiny effect. Each happens once a game at most.
func _trip_vignette(s: Dictionary, d: Dictionary, fill: Dictionary) -> String:
	if rand(s) >= float(TOURS.get("VIGNETTE_CHANCE", 0.25)): return ""
	if not s.has("vignettesSeen"): s.vignettesSeen = []
	var pool: Array = TOURS.get("VIGNETTES", []).filter(func(v):
		return not s.vignettesSeen.has(v.id) and (not v.has("regions") or v.regions.has(d.region)))
	if pool.is_empty(): return ""
	var v: Dictionary = pick(s, pool)
	s.vignettesSeen.append(v.id)
	var fx: Dictionary = v.get("effects", {})
	if fx.has("goodwill") or fx.has("aware"): district_boost(s, d.id, float(fx.get("aware", 0)), float(fx.get("goodwill", 0)))
	if fx.has("charisma"):
		var me = player_party(s)
		me.charisma = clampf2(float(me.charisma) + float(fx.charisma), 0, 100)
	if fx.has("money"): s.money = maxf(0.0, float(s.money) + float(fx.money))
	return String(v.text).format(fill)

## Local standing fades a little every month; offices keep their own district warm.
func districts_monthly(s: Dictionary) -> void:
	for id in s.districts:
		var st: Dictionary = s.districts[id]
		st.aware = float(st.aware) * 0.985
		st.goodwill = float(st.goodwill) * 0.95
		var rt: Dictionary = st.get("rtrip", {})
		for pid in rt: rt[pid] = float(rt[pid]) * 0.95
	for name in s.communities:
		var d = district_of_city(name)
		if d: district_boost(s, d.id, 0.006 * int(s.communities[name]), 0.018 * int(s.communities[name]))

func seat_allocation(res: Dictionary) -> Dictionary:
	var out = {"national": {}, "regions": {}, "districts": {}, "votes": {}}
	var party_ids: Array = []
	for d in DISTRICTS:
		for id in res[d.id].votes:
			if not party_ids.has(id): party_ids.append(id)
	for id in party_ids:
		out.national[id] = 0
		out.votes[id] = 0.0
	for r in REGIONS:
		out.regions[r.id] = {}
		for id in party_ids: out.regions[r.id][id] = 0
	var pool = 0
	var total = 0.0
	for d in DISTRICTS:
		var x: Dictionary = res[d.id]
		var w: int = winner_seats(int(d.seats))
		out.districts[d.id] = {"winner": x.winner, "won": w, "shared": {}}
		out.national[x.winner] += w
		out.regions[d.region][x.winner] += w
		pool += int(d.seats) - w
		for id in x.votes:
			out.votes[id] += x.votes[id]
			total += x.votes[id]
	# the shared seats, by national vote, among the parties over the threshold
	var share = {}
	var rows = []
	var given = 0
	var t: float = threshold()
	var counted = 0.0
	for id in party_ids:
		if total <= 0 or out.votes[id] / total >= t: counted += out.votes[id]
	for id in party_ids:
		share[id] = out.votes[id] / total if total else 0.0
		var exact: float = pool * (out.votes[id] / counted if counted > 0 and share[id] >= t else 0.0)
		share[id + ":n"] = int(floor(exact))
		given += int(floor(exact))
		rows.append({"id": id, "rest": exact - floor(exact)})
	for r in ssort(rows, func(a, b): return b.rest - a.rest).slice(0, pool - given): share[r.id + ":n"] += 1
	# place each party's shared seats where it did best
	var slots = {}
	for d in DISTRICTS: slots[d.id] = int(d.seats) - winner_seats(int(d.seats))
	var cand = []
	for d in DISTRICTS:
		if slots[d.id] <= 0: continue
		var tot = dsum(res[d.id].votes)
		for id in party_ids: cand.append({"d": d, "id": id, "v": res[d.id].votes[id] / tot if tot else 0.0})
	cand = ssort(cand, func(a, b): return b.v - a.v)
	var left = {}
	for id in party_ids: left[id] = share[id + ":n"]
	var placed = true
	while placed:
		placed = false
		for c in cand:
			if left[c.id] <= 0 or slots[c.d.id] <= 0: continue
			var sh: Dictionary = out.districts[c.d.id].shared
			sh[c.id] = int(sh.get(c.id, 0)) + 1
			out.national[c.id] += 1
			out.regions[c.d.region][c.id] += 1
			left[c.id] -= 1
			slots[c.d.id] -= 1
			placed = true
	for id in party_ids: out.votes[id] = share[id]
	return out

## Seats each party would win if the election were today.
## Where a province is on the map: its biggest town, or the middle of it when it has none.
func district_centre(d: Dictionary) -> Vector2:
	for c in MAP.get("cities", []):
		if d.cities.size() and c.name == d.cities[0]: return Vector2(float(c.x), float(c.y))
	return Vector2(float(d.label[0]), float(d.label[1]))

# ---------- Local stories: where they happen ----------
## Picks the province a story happens in, from its "where" (data/issues.json): one named
## province, or any province of the listed regions ("city": true for one with a town).
func place_story(s: Dictionary, it: Dictionary) -> Dictionary:
	var w: Dictionary = it.get("where", {})
	if w.has("region"):   # the whole region, no one province
		var r = by_id(REGIONS, String(w.region))
		if r == null: return {}
		return {"district": "", "city": String(r.name), "province": String(r.name), "region": String(r.id), "whole": true}
	var pool: Array = []
	if w.has("province"): pool = DISTRICTS.filter(func(d): return d.id == String(w.province))
	elif w.has("provinces"):   # one of a few named provinces (a border, a coast)
		var ids: Array = w.provinces
		pool = DISTRICTS.filter(func(d): return ids.has(d.id))
	elif w.has("regions"):
		var regs: Array = w.regions
		var need_city: bool = bool(w.get("city", false))
		pool = DISTRICTS.filter(func(d): return regs.has(d.region) and (not need_city or d.cities.size() > 0))
	if pool.is_empty(): pool = DISTRICTS.filter(func(d): return d.region == String(it.get("region", "")))
	if pool.is_empty(): return {}
	var d: Dictionary = pick(s, pool)
	var city: String = String(d.cities[int(floor(rand(s) * d.cities.size()))]) if d.cities.size() else String(d.name)
	return {"district": d.id, "city": city, "province": String(d.name), "region": String(d.region)}

## A local story as it happened this time: title, text and lines with its place filled in.
func story(s: Dictionary, id: String) -> Dictionary:
	var it: Dictionary = by_id(ISSUES, id).duplicate(true)
	if it.is_empty(): return it
	var pl: Dictionary = s.get("storyPlace", {}).get(id, {})
	var reg = by_id(REGIONS, String(pl.get("region", it.get("region", ""))))
	var names = {"city": pl.get("city", reg.name if reg else ""), "province": pl.get("province", reg.name if reg else ""), "region": reg.name if reg else ""}
	if pl.get("back", false) and it.has("returns"):   # it came back, still unsolved
		it.title = it.returns.title
		it.text = it.returns.text
	it.title = String(it.title).format(names)
	it.text = String(it.text).format(names)
	for side in it.get("lines", {}):
		for l in it.lines[side]: l.text = String(l.text).format(names)
	if pl.size():
		it.region = pl.region
		it.district = pl.district
		it.province = pl.province
	return it

## A story turns up: where it happens is decided now and kept (its debate may outlive it).
func story_turns_up(s: Dictionary, id: String) -> Dictionary:
	if not s.has("storyPlace"): s.storyPlace = {}
	s.storyPlace[id] = place_story(s, by_id(ISSUES, id))
	s.issues.append({"id": id, "week": s.week, "district": s.storyPlace[id].get("district", "")})
	return story(s, id)

## You spoke up about a local story: its province hears you, and remembers for a trip.
func heard_locally(s: Dictionary, id: String) -> void:
	var it: Dictionary = story(s, id)
	heard_in(s, {"district": it.get("district", "")}, String(it.title))

## You spoke up about something that happened in a place: a province (or every province
## of a region, each half as much) hears you, and remembers it for a trip there.
func heard_in(s: Dictionary, place: Dictionary, title: String) -> void:
	var ids: Array = []
	var k = 1.0
	if String(place.get("district", "")) != "": ids = [String(place.district)]
	elif place.get("whole", false):
		ids = DISTRICTS.filter(func(d): return d.region == String(place.get("region", ""))).map(func(d): return d.id)
		k = LOCAL_REGION_SHARE
	if ids.is_empty(): return
	if not s.has("localSpoke"): s.localSpoke = {}
	for did in ids:
		s.localSpoke[did] = {"week": s.week, "title": title.substr(0, 1).to_lower() + title.substr(1)}
		district_boost(s, did, LOCAL_STORY_AWARE * k, LOCAL_STORY_GOODWILL * k)

## An event that happens somewhere ("where" in content.json EVENTS): its place is picked
## now, and a copy with the names filled in goes on the desk.
func placed_event(s: Dictionary, ev: Dictionary) -> Dictionary:
	var out: Dictionary = ev.duplicate(true)
	var pl: Dictionary = place_story(s, ev)
	if pl.is_empty(): return out
	out.place = pl
	var reg = by_id(REGIONS, String(pl.region))
	var names = {"city": pl.city, "province": pl.province, "region": reg.name if reg else ""}
	out.title = String(out.title).format(names)
	out.text = String(out.text).format(names)
	if out.get("government"): out.government.text = String(out.government.text).format(names)
	for ch in out.get("choices", []):
		ch.label = String(ch.label).format(names)
		for l in ch.get("lines", []): l.text = String(l.text).format(names)
	return out

## The last election (2026): the country as it stands at the start, without your party,
## which didn't exist yet. Stored once, when the game begins.
func past_election(s: Dictionary) -> Dictionary:
	var out = {}
	for d in DISTRICTS:
		var v: Dictionary = district_votes(s, d, score_context(s)).duplicate()
		v.erase("player")
		var tot = dsum(v)
		var ids: Array = ssort(v.keys(), func(a, b): return v[b] - v[a])
		out[d.id] = {"votes": v, "winner": ids[0], "second": ids[1], "seats": int(d.seats),
			"share": v[ids[0]] / tot if tot else 0.0, "margin": (v[ids[0]] - v[ids[1]]) / tot if tot else 0.0, "you": 0.0}
	_bar_small_parties(out)
	return out

## What each province is like right now, for the map's modes: how many know your party,
## the issues it cares about most, how fed up it is with the system, and its distress
## (hard times and distrust together; settings in data/mapmodes.json). One pass over the voters.
func district_profiles(s: Dictionary) -> Dictionary:
	var dcfg: Dictionary = MAPMODES.get("DISTRESS", {})
	var hcfg: Dictionary = dcfg.get("hardship", {})
	var acc = {}
	for pop in s.pops:
		var id: String = String(pop.get("district", ""))
		if not acc.has(id):
			acc[id] = {"size": 0.0, "known": 0.0, "fed": 0.0, "hard": 0.0, "sal": {}}
			for ax in AXES: acc[id].sal[ax.id] = 0.0
		var a: Dictionary = acc[id]
		var n: float = pop.size
		var aw: float = pop.aware.player
		var st = s.districts.get(id, null)
		if st: aw = aw + float(st.aware) * (1 - aw)
		a.size += n
		a.known += n * aw
		a.fed += n * float(pop.disaffection)
		a.hard += n * float(hcfg.get(pop["class"], 0.5))
		for ax in AXES: a.sal[ax.id] += n * salience_of(s, pop, ax.id)
	# hard times now (0..1), and how far trust has fallen (0..1)
	var bad: float = clampf2(0.5 * metric_badness(s, "jobs") + 0.5 * metric_badness(s, "prices"), 0, 1)
	var distrust: float = clampf2((60.0 - s.trust) / 60.0, 0, 1)
	var hb: float = float(hcfg.get("base", 0.4))
	var tb: float = float(dcfg.get("distrust", {}).get("base", 0.4))
	var wh: float = float(dcfg.get("weights", {}).get("hardship", 0.5))
	var wt: float = float(dcfg.get("weights", {}).get("distrust", 0.5))
	var out = {}
	for id in acc:
		var a: Dictionary = acc[id]
		if a.size <= 0: continue
		var sal = {}
		for ax in AXES: sal[ax.id] = a.sal[ax.id] / a.size
		var top: Array = ssort(sal.keys(), func(x, y): return sal[y] - sal[x])
		var fed: float = a.fed / a.size                                 # about 0.3..2, 1 is ordinary
		var hardship: float = (a.hard / a.size) * (hb + (1 - hb) * bad)
		var distrusting: float = clampf2(fed / 2.0, 0, 1) * (tb + (1 - tb) * distrust)
		out[id] = {"known": a.known / a.size, "fed": fed, "sal": sal, "top": top.slice(0, 2),
			"hardship": hardship, "distrust": distrusting,
			"distress": clampf2((wh * hardship + wt * distrusting) / maxf(0.01, wh + wt), 0, 1), "size": a.size}
	return out

## A level from 0 to 1 in words (data/mapmodes.json LEVELS: "Hardly" ... "Very").
func level_word(v: float) -> String:
	var words: Array = MAPMODES.get("LEVELS", ["Low", "Medium", "High"])
	return String(words[clampi(int(v * words.size()), 0, words.size() - 1)])

func projected_seats(proj: Dictionary) -> Dictionary:
	return seat_allocation(proj).national

# ---------- Elections ----------
func run_election(s: Dictionary) -> void:
	var res: Dictionary = district_results(s)
	var alloc: Dictionary = seat_allocation(res)
	var seats = {"national": alloc.national, "regions": alloc.regions, "districts": res, "split": alloc.districts}
	var national: Dictionary = alloc.votes
	var ranking = ssort(seats.national.keys(), func(a, b): return seats.national[b] - seats.national[a])
	s.result = {"votes": national, "seats": seats, "ranking": ranking, "playerWon": ranking[0] == "player",
		"majority": seats.national.player > C.seats / 2.0}
	# the largest party without a majority bargains; if that is you, the talks wait for you
	var ranked: Array = ranking.filter(func(id): return int(seats.national.get(id, 0)) > 0)
	if ranked.size() and ranked[0] == "player" and int(seats.national.player) < int(C.seats / 2) + 1: s.result.coalition = coalition_open(s, seats.national)
	else: s.result.coalition = form_government(s, seats.national, {})   # {}: if a party asks you to join, the talks wait for your answer
	s.queue.append({"type": "election"})
