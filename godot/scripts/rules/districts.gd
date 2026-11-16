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
	for pop in (pops if pops != null else s.pops):
		if pop.get("district", "") != d.id: continue
		var sup = cache[pop.id] if cache != null and cache.has(pop.id) else pop_support(s, pop, null, ctx)
		var votes = pop_votes(pop, sup, ctx)
		for id in votes: out[id] += votes[id]
	return out

## Every district: votes, the winner, the runner-up and the winning margin (share points).
func district_results(s: Dictionary, cache = null, ctx = null, pops = null) -> Dictionary:
	if ctx == null: ctx = score_context(s)
	var out = {}
	for d in DISTRICTS: out[d.id] = district_result(s, d, ctx, cache, pops)
	return out

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
	if int(s.get("lastVisit", -99)) / WEEKS_PER_MONTH == s.week / WEEKS_PER_MONTH: return "%s has already been on the road this month." % player_party(s).leader
	return ""

## What makes this trip bigger or smaller. Returns the multiplier and the reasons, in words.
func visit_power(s: Dictionary, id: String) -> Dictionary:
	var d = district_by_id(id)
	var st: Dictionary = s.districts[id]
	var why: Array = []
	var k: float = 1.0 / (1.0 + 0.3 * int(st.visits))          # going back helps less each time
	if int(st.visits) > 0: why.append("they've seen you before")
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
	return {"k": k, "money": m, "why": why}

func act_visit(s: Dictionary, id: String) -> Dictionary:
	var block = visit_block(s)
	if block: return {"ok": false, "text": block}
	var d = district_by_id(id)
	var st: Dictionary = s.districts[id]
	var exact_before: float = float(district_result(s, d, score_context(s)).you)
	# the number the player sees on the map is the poll's; the trip moves it by what really changed
	var before: float = float(s.projection.get(id, {}).get("you", exact_before))
	var pw: Dictionary = visit_power(s, id)
	var k: float = pw.k
	st.visits = int(st.visits) + 1
	s.roadFund = maxf(0, float(s.get("roadFund", 0)) - pw.money)
	district_boost(s, id, VISIT_AWARE * k, VISIT_GOODWILL * k)
	for o in DISTRICTS:
		if o.region == d.region and o.id != id: district_boost(s, o.id, VISIT_AWARE * k * 0.1, VISIT_GOODWILL * k * 0.06)
	s.lastVisit = s.week
	var real: Dictionary = district_result(s, d, score_context(s))
	var after: float = clampf2(before + (float(real.you) - exact_before), 0.0, 0.95)
	s.projection[id] = _with_share(s.projection.get(id, real), d, "player", after)
	var text = "%s spent the month in %s: town halls, a market walkabout, a local radio phone-in. Your vote there: %d%% → %d%%." % [player_party(s).leader, d.name, jround(before * 100), jround(after * 100)]
	if pw.why.size():
		var w: String = ", ".join(pw.why)
		text += " " + w.substr(0, 1).to_upper() + w.substr(1) + "."
	_log(s, "action", "Toured %s." % d.name)
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
	return {"ok": true, "text": text, "kind": kind, "place": d.name, "region": d.region, "before": before, "after": after,
		"why": pw.why, "story": String(story.text).format(fill), "caption": String(story.caption).format(fill)}

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
	# the shared seats, by national vote
	var share = {}
	var rows = []
	var given = 0
	for id in party_ids:
		share[id] = out.votes[id] / total if total else 0.0
		var exact: float = pool * share[id]
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
	s.queue.append({"type": "election"})
