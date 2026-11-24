## rules/voters.gd — The voters: who they are, what they think and want in a leader, how they choose a party, group summaries, effects on them, trust and issue ownership.
extends "res://scripts/rules/base.gd"

# ---------- Starting a new game ----------
## The leader was mayor of a city before splitting off to found the party:
## its region knows them and likes them, and there is already a party office there.
## Alinni's cities can't be chosen: Alinnians elect their own minority leaders.
func home_cities() -> Array:
	return country_cities().filter(func(c): return c.area != "alinni")

## Cranbovia's own cities (the map also has the neighbours' capitals).
func country_cities() -> Array:
	return MAP.cities.filter(func(c): return REGIONS.any(func(r): return r.id == c.area))

## City facts from data/cities.json (population in millions, a lean per axis
## on top of its region's, and a line about the place). Missing values fall back
## to an estimate from the region's size and the dot size on the map.
func city_population(c: Dictionary) -> float:
	var info: Dictionary = CITY_INFO.get(c.name, {})
	if info.has("population"): return float(info.population) * 1e6
	var r = by_id(REGIONS, c.area)
	var share: float = {3: 0.28, 2: 0.12, 1: 0.05}.get(int(c.get("size", 1)), 0.05)
	return float(r.adults) * 1e6 * 1.3 * share if r else 0.0

func city_fact(c: Dictionary) -> String:
	return str(CITY_INFO.get(c.name, {}).get("fact", ""))

## Where the city's people stand: its region's average, moved by the city's own lean.
func city_leanings(s: Dictionary, c: Dictionary) -> Dictionary:
	var hd = district_of_city(c.name)
	var pos: Dictionary = summarize(s, pops_matching(s, {"district": hd.id} if hd else {"region": c.area})).pos.duplicate()
	var lean: Dictionary = CITY_INFO.get(c.name, {}).get("lean", {})
	for ax in lean: pos[ax] = clampf2(float(pos.get(ax, 0)) + float(lean[ax]), -100, 100)
	return pos

func full_vector(v: Dictionary) -> Dictionary:
	var out = {}
	for ax in AXES: out[ax.id] = clampf2(float(v.get(ax.id, 0)), -100, 100)
	return out

func initials(name: String) -> String:
	var words = name.strip_edges().split(" ", false)
	var out = ""
	if words.size() > 1:
		for w in words: out += w[0]
	else:
		out = name.substr(0, 3)
	out = out.to_upper().substr(0, 4)
	return out if out != "" else "YOU"

## Each province's class and nationality mix: tilted by how urban it is (towns are
## more middle-class and more mixed), then fitted so that every region still adds
## up to the mix set for it in content.json.
func _province_mixes() -> Dictionary:
	var out = {}
	for d in DISTRICTS:
		var r = by_id(REGIONS, d.region)
		var people: float = float(r.adults) * 1e6 * float(d.share)
		var city_people = 0.0
		for name in d.cities:
			var c: Dictionary = city_by_name(name)
			if not c.is_empty(): city_people += city_population(c) * 0.75
		var urban: float = clampf2(city_people / people, 0, 1) if people > 0 else 0.0
		var cls = {}
		for c in CLASSES:
			var k: float = {"working": 1 - 0.35 * urban, "middle": 1 + 0.3 * urban, "upper": 1 + 0.6 * urban}.get(c.id, 1.0)
			cls[c.id] = float(r.classes.get(c.id, 0)) * k
		var big = 0.0
		for m in NATIONALITIES: big = maxf(big, float(r.nationalities.get(m.id, 0)))
		var nat = {}
		for n in NATIONALITIES:
			var share: float = float(r.nationalities.get(n.id, 0))
			if share > 0: nat[n.id] = share * (1.0 if share >= big else 1 + 0.5 * urban)   # minorities gather in towns
		out[d.id] = {"urban": urban, "cls": cls, "nat": nat, "share": float(d.share), "region": d.region}
	for kind in ["cls", "nat"]:
		for it in 4:
			for d_id in out:   # each province's mix sums to 1
				var m: Dictionary = out[d_id][kind]
				var t = dsum(m)
				for k in m: m[k] = m[k] / t if t > 0 else 0.0
			for r in REGIONS:   # each region's provinces add up to the region's mix
				var target: Dictionary = r.classes if kind == "cls" else r.nationalities
				for k in target:
					var have = 0.0
					for d_id in out:
						if out[d_id].region == r.id: have += out[d_id].share * float(out[d_id][kind].get(k, 0))
					if have <= 0: continue
					var f: float = float(target[k]) / have
					for d_id in out:
						if out[d_id].region == r.id and out[d_id][kind].has(k): out[d_id][kind][k] = float(out[d_id][kind][k]) * f
		for d_id in out:
			var m2: Dictionary = out[d_id][kind]
			var t2 = dsum(m2)
			for k in m2: m2[k] = m2[k] / t2 if t2 > 0 else 0.0
	return out

func build_pops(s: Dictionary) -> Array:
	var pops = []
	var mixes: Dictionary = _province_mixes()
	for d in DISTRICTS:
		var r = by_id(REGIONS, d.region)
		var people: float = float(r.adults) * 1e6 * float(d.share)
		var st: Dictionary = s.districts.get(d.id, {})
		# how urban: the share of the province living in its cities
		var city_people = 0.0
		var city_lean = {}
		for name in d.cities:
			var c: Dictionary = city_by_name(name)
			if c.is_empty(): continue
			var cp: float = city_population(c) * 0.75
			city_people += cp
			var cl: Dictionary = CITY_INFO.get(name, {}).get("lean", {})
			for ax in cl: city_lean[ax] = float(city_lean.get(ax, 0)) + float(cl[ax]) * cp
		var urban: float = mixes[d.id].urban
		var cls: Dictionary = mixes[d.id].cls
		var nats: Dictionary = mixes[d.id].nat
		var ctot = 1.0
		var ntot = 1.0
		var local_lean = {}
		for ax in AXES:
			var v: float = float(st.get("lean", {}).get(ax.id, 0))
			if city_people > 0: v += float(city_lean.get(ax.id, 0)) / people
			local_lean[ax.id] = v
		local_lean.society = float(local_lean.get("society", 0)) + (0.4 - urban) * 20   # countryside more traditional
		local_lean.nation = float(local_lean.get("nation", 0)) + (urban - 0.4) * 15     # towns more mixed
		for a in AGES:
			for c in CLASSES:
				# a group too small to model joins the biggest group of its age and class there, so nobody is lost
				var main_nat = ""
				for nid in nats:
					if main_nat == "" or float(nats[nid]) > float(nats[main_nat]): main_nat = nid
				var folded = 0.0
				for nid in nats:
					if nid != main_nat and people * float(a.share) * cls[c.id] / ctot * nats[nid] / ntot < POP_MIN:
						folded += people * float(a.share) * cls[c.id] / ctot * nats[nid] / ntot
				for nid in nats:
					var n = by_id(NATIONALITIES, nid)
					var size: float = people * float(a.share) * cls[c.id] / ctot * nats[nid] / ntot
					if nid == main_nat: size += folded
					elif size < POP_MIN: continue
					if size <= 0: continue
					var local: Dictionary = r.get("local", {}).get(nid, {})
					var pos = {}
					var sal = {}
					for ax in AXES:
						var lean: float = float(r.lean.get(ax.id, 0)) + float(a.lean.get(ax.id, 0)) + float(c.lean.get(ax.id, 0)) \
							+ float(n.lean.get(ax.id, 0)) + float(local.get("lean", {}).get(ax.id, 0)) + float(local_lean.get(ax.id, 0))
						pos[ax.id] = float(jround(clampf2(lean + rand_normal(s) * 7, -100, 100)))
						sal[ax.id] = fixed(_or1(r.sal.get(ax.id)) * _or1(a.sal.get(ax.id)) * _or1(c.sal.get(ax.id)) \
							* _or1(n.sal.get(ax.id)) * _or1(local.get("sal", {}).get(ax.id)), 2)
					var pop = {
						"id": "%s/%s/%s/%s" % [d.id, a.id, c.id, nid],
						"region": r.id, "district": d.id, "age": a.id, "class": c.id, "nationality": nid,
						"size": float(jround(size)), "pos": pos, "base": pos.duplicate(), "sal": sal, "shield": {},
						"turnout": clampf2(a.turnout + c.turnout + n.turnout + float(r.get("turnout", 0)), 0.25, 0.95),
						"engagement": a.engagement * c.engagement,
						"leaderPull": fixed(_or1(a.get("leaderAppeal")) * _or1(c.get("leaderAppeal")) * _or1(n.get("leaderAppeal")) * _or1(r.get("leaderAppeal")), 2),
						"disaffection": fixed(clampf2(1 + (-pos.system) / 60.0 + float(c.get("disaffect", 0)) + float(r.get("disaffect", 0)), 0.3, 2), 2),
						"mobilized": 0.0,
						"loyal": {}, "goodwill": {}, "aware": {}, "leader": {},
					}
					for p in s.parties:
						var reach: Dictionary = by_id(PARTIES, p.id).get("reach", {})
						pop.loyal[p.id] = 0.0
						pop.goodwill[p.id] = 0.0
						pop.leader[p.id] = 0.0
						pop.aware[p.id] = float(C.startAwareness) if p.isPlayer else float(reach.get(r.id, reach.get("default", 1)))
					pops.append(pop)
	return pops

func seed_loyalty(s: Dictionary) -> void:
	var ctx = score_context(s)
	for pop in s.pops:
		var sup = pop_support(s, pop, "player", ctx)
		for id in sup: pop.loyal[id] = C.startLoyalty * sup[id]

# ---------- Consistency ----------
func inconsistency_of(s: Dictionary, party: Dictionary) -> float:
	var steps = 0.0
	for ax in AXES:
		var off: int = absi(stance_of(party.perceived[ax.id]) - stance_of(party.manifesto[ax.id]))
		steps += C.stepPenalty[off]
	return steps

# ---------- Opinion ----------
func salience_of(s: Dictionary, pop: Dictionary, axis: String) -> float:
	var climate: float = float(s.climate.get(axis, 0)) + float(s.get("regionClimate", {}).get(pop.region, {}).get(axis, 0))
	return pop.sal[axis] * maxf(0.3, 1 + float(s.salMod.get(axis, 0)) + climate + float(s.permSal.get(axis, 0)))

func distance(s: Dictionary, pop: Dictionary, pos: Dictionary) -> float:
	var d = 0.0
	var w = 0.0
	for ax in AXES:
		var sa = salience_of(s, pop, ax.id)
		d += sa * absf(pop.pos[ax.id] - pos[ax.id])
		w += sa
	return d / w

func devotion_of(pop: Dictionary, party: Dictionary) -> float:
	if not party.isPlayer: return 0.0
	var attachment: float = pop.leader[party.id] * pop.leaderPull * (party.charisma / 50.0) * (0.85 + 0.4 * float(party.get("extremity", 0)))
	return clampf2((attachment - C.devotionStart) / C.devotionRange, 0, 1)

func score_context(s: Dictionary) -> Dictionary:
	var inc = {}
	var own = {}
	for p in s.parties:
		inc[p.id] = inconsistency_of(s, p)
		own[p.id] = []
	for key in s.ownership:
		var owners: Dictionary = s.ownership[key]
		var total = dsum(owners)
		var parts: PackedStringArray = key.split(":")
		for pid in owners:
			var v: float = owners[pid]
			if v < 0.02 or not own.has(pid): continue
			own[pid].append({"axis": parts[0], "side": parts[1], "value": v / maxf(total, C.ownShareFloor + v * 0.5)})
	var distrust: float = (50.0 - s.trust) / 50.0
	var fit = {}
	for p in s.parties: fit[p.id] = leader_fit(s, p)
	var cs: Dictionary = C.serious
	var serious: float = float(cs.vote) * (serious_of(s) - float(cs.mid)) / (100.0 - float(cs.mid) if serious_of(s) > float(cs.mid) else float(cs.mid))
	return {"inc": inc, "own": own, "distrust": distrust, "fit": fit, "clim": leader_climate(s, distrust), "serious": serious}

# ---------- What kind of leader people want ----------
## A group's wish for each kind of leader (data/leader_types.json), summing to 1.
## It comes from who they are; the climate (leader_climate) then raises some wishes.
func pop_wants(pop: Dictionary) -> Dictionary:
	var w = {}
	var tot = 0.0
	for t in LEADER_TYPES:
		var v: float = float(t.get("base", 1))
		var by: Dictionary = t.get("by", {})
		v += float(by.get("age", {}).get(pop.age, 0)) + float(by.get("class", {}).get(pop.class, 0))
		v += float(by.get("region", {}).get(pop.region, 0)) + float(by.get("nationality", {}).get(pop.nationality, 0))
		var lean: Dictionary = t.get("lean", {})
		for key in lean:
			var parts: PackedStringArray = String(key).split(":")
			var x: float = float(pop.pos[parts[0]])
			if (parts[1] == "L" and x < -25) or (parts[1] == "R" and x > 25): v += float(lean[key])
		v += float(t.get("disaffected", 0)) * maxf(0, float(pop.disaffection) - 1)
		v += float(t.get("pull", 0)) * (float(pop.leaderPull) - 1)
		w[t.id] = maxf(0.05, v)
		tot += w[t.id]
	for k in w: w[k] = w[k] / tot
	return w

## How the times change what people want: a crisis, a hot border, hard times, low trust,
## and anything events added (s.wantMod, which fades).
func leader_climate(s: Dictionary, distrust: float) -> Dictionary:
	var war = false
	for f in FOREIGN:
		if s.countries.get(f.id, {}).get("hot", false): war = true
	var hard: float = maxf(metric_badness(s, "jobs"), metric_badness(s, "prices")) if s.has("world") else 0.0
	var mods: Dictionary = s.get("wantMod", {})
	var out = {}
	for t in LEADER_TYPES:
		var cl: Dictionary = t.get("climate", {})
		var k: float = 1.0 + float(mods.get(t.id, 0))
		if s.get("crisis"): k += float(cl.get("crisis", 0))
		if war: k += float(cl.get("war", 0))
		k += float(cl.get("hard_times", 0)) * hard
		k += float(cl.get("distrust", 0)) * maxf(0, distrust)
		out[t.id] = maxf(0.2, k)
	return out

## How well a party's leader fits each kind (0..1): your leader from the words you
## choose, your record and how voters see you; rivals from their party.
func leader_fit(s: Dictionary, p: Dictionary) -> Dictionary:
	var pos: Dictionary = p.perceived
	var ch: float = clampf2((float(p.charisma) - 30) / 50.0, 0, 1)
	var est: float = float(p.get("establishment", 0.5))
	var radical: float = clampf2(-float(pos.system) / 70.0, 0, 1)
	var auth: float = clampf2(-float(pos.order) / 70.0, 0, 1)
	var hawk: float = clampf2(-float(pos.foreign) / 70.0, 0, 1)
	var ext = 0.0
	for ax in AXES: ext += absf(float(pos[ax.id])) / 80.0
	var calm: float = clampf2(1 - ext / AXES.size(), 0, 1)
	var tone = {"statesman": 0.25 + 0.5 * est, "fiery": 0.15 + 0.3 * maxf(radical, auth), "folksy": 0.2, "provocative": 0.1 * radical}
	var visits = 0
	var stains = 0.0
	var slips = 0.0
	var memes = 0.0
	if p.isPlayer:
		est = clampf2(0.5 + float(pos.system) / 140.0, 0, 1)
		var sh: Dictionary = style_profile(s).shares
		if sh.size(): tone = {"statesman": float(sh.get("statesman", 0)), "fiery": float(sh.get("fiery", 0)), "folksy": float(sh.get("folksy", 0)), "provocative": float(sh.get("provocative", 0))}
		for id in s.get("districts", {}): visits += int(s.districts[id].get("visits", 0))
		stains = s.record.money.filter(func(m): return m.dirty).size() * 0.35 + float(s.record.outrages) * 0.1
		slips = float(s.record.gaffes)
		memes = float(s.record.memes)
	else:
		stains = clampf2((60 - float(p.get("stability", 60))) / 60.0, 0, 1)
	var f = {
		"star": 0.6 * ch + 0.3 * (tone.folksy + tone.provocative) + minf(0.2, memes * 0.04),
		"statesman": 0.45 * tone.statesman + 0.3 * calm + 0.25 * (1 - radical) - minf(0.4, slips * 0.06),
		"revolutionary": 0.55 * radical + 0.3 * (tone.fiery + tone.provocative) + 0.15 * (1 - est),
		"strongman": 0.35 * auth + 0.15 * hawk + 0.3 * tone.fiery + 0.2 * ch,
		"one_of_us": 0.5 * tone.folksy + 0.3 * (1 - est) + 0.2 * minf(1, visits / 12.0),
		"clean": 0.5 * (1 - est) + 0.5 * (1 - minf(1, stains)),
		"expert": 0.45 * tone.statesman + 0.35 * calm + 0.2 * (1 - minf(1, tone.provocative * 2)) - minf(0.3, slips * 0.05),
	}
	for k in f: f[k] = clampf2(f[k], 0, 1)
	return f

## What a set of voters wants in a leader today, strongest first: [{type, share}].
func group_wants(s: Dictionary, pops: Array) -> Array:
	var clim: Dictionary = leader_climate(s, (50.0 - s.trust) / 50.0)
	var sum = {}
	var tot = 0.0
	for pop in pops:
		if not pop.has("wants"): pop.wants = pop_wants(pop)
		for k in pop.wants:
			var v: float = float(pop.size) * float(pop.wants[k]) * float(clim.get(k, 1.0))
			sum[k] = float(sum.get(k, 0)) + v
			tot += v
	var out = []
	for t in LEADER_TYPES: out.append({"type": t, "share": float(sum.get(t.id, 0)) / tot if tot else 0.0})
	return ssort(out, func(a, b): return b.share - a.share)

## How a party's leader comes across, best fit first: [{type, fit}].
func leader_image(s: Dictionary, p: Dictionary) -> Array:
	var f: Dictionary = leader_fit(s, p)
	var out = []
	for t in LEADER_TYPES: out.append({"type": t, "fit": float(f.get(t.id, 0))})
	return ssort(out, func(a, b): return b.fit - a.fit)

## What doesn't depend on the party, worked out once per group (pop_support).
func pop_prep(s: Dictionary, pop: Dictionary, ctx: Dictionary) -> Dictionary:
	var sal = {}
	var sw = 0.0
	for ax in AXES:
		var v: float = salience_of(s, pop, ax.id)
		sal[ax.id] = v
		sw += v
	var lw = {}
	if LEADER_TYPES.size() and ctx.has("clim"):
		if not pop.has("wants"): pop.wants = pop_wants(pop)
		var den = 0.0
		for k in pop.wants:
			lw[k] = float(pop.wants[k]) * float(ctx.clim.get(k, 1.0))
			den += lw[k]
		for k in lw: lw[k] = lw[k] / den if den > 0 else 0.0
	return {"sal": sal, "sw": sw, "lw": lw}

func party_score(s: Dictionary, pop: Dictionary, party: Dictionary, ctx: Dictionary, pre = null) -> float:
	if pre == null: pre = pop_prep(s, pop, ctx)
	var dev = devotion_of(pop, party)
	var d = 0.0
	var sal: Dictionary = pre.sal
	var perc: Dictionary = party.perceived
	var pp: Dictionary = pop.pos
	for ax in sal: d += sal[ax] * absf(pp[ax] - perc[ax])
	d = d / pre.sw if pre.sw > 0 else 0.0
	var sc = -d / C.distanceScale * (1 - C.devotionBlind * dev)
	var gw: float = pop.goodwill[party.id]
	var aw: float = pop.aware[party.id]
	var st = s.districts.get(pop.get("district", ""), null)
	if st:
		if party.isPlayer:
			gw += float(st.goodwill)
			aw = aw + float(st.aware) * (1 - aw)
		else: gw += float(st.rivals.get(party.id, 0)) + float(st.get("rtrip", {}).get(party.id, 0))
	sc += gw
	sc += log(maxf(aw, 0.001))
	if party.isPlayer:
		sc += C.leaderWeight * pop.leader[party.id] * pop.leaderPull * (party.charisma / 50.0)
		sc += float(ctx.get("serious", 0.0))   # people vote more readily for a party they take seriously
	else: sc += C.rivalLeaderWeight * ((party.charisma - 50) / 50.0) * pop.leaderPull
	# the kind of leader they want, against the kind this one is
	if not pre.lw.is_empty():
		var fit: Dictionary = ctx.fit[party.id]
		var m = 0.0
		for k in pre.lw: m += pre.lw[k] * float(fit.get(k, 0.4))
		sc += C.typeWeight * (m - 0.4) * pop.leaderPull
	var penalty = maxf(0, ctx.inc[party.id] - C.inconsistencyTolerance) / 4.0
	sc -= penalty * pop.engagement * (1 - C.devotionBlind * dev)
	sc += C.trustWeight * ctx.distrust * (0.5 - party.establishment) * pop.disaffection
	for o in ctx.own[party.id]:
		var p: float = pop.pos[o.axis]
		if (o.side == "L" and p < -15) or (o.side == "R" and p > 15):
			var care = sal[o.axis] - C.singleIssueFrom
			if care > 0: sc += C.ownWeight * o.value * care
	return sc

func pop_support(s: Dictionary, pop: Dictionary, exclude, ctx = null) -> Dictionary:
	if ctx == null: ctx = score_context(s)
	var parties: Array = s.parties.filter(func(p): return p.id != exclude)
	var scores = []
	var top = -INF
	var pre = pop_prep(s, pop, ctx)
	for p in parties:
		var v = party_score(s, pop, p, ctx, pre)
		scores.append(v)
		top = maxf(top, v)
	var weights = []
	var total = 0.0
	for v in scores:
		var w = exp(v - top)
		weights.append(w); total += w
	var loyal_total = 0.0
	for p in parties: loyal_total += pop.loyal[p.id]
	var out = {}
	for i in parties.size():
		out[parties[i].id] = pop.loyal[parties[i].id] + (1 - loyal_total) * (weights[i] / total)
	return out

func pop_votes(pop: Dictionary, sup: Dictionary) -> Dictionary:
	var out = {}
	for id in sup:
		var t: float = minf(0.97, pop.turnout + pop.mobilized) if id == "player" else pop.turnout
		out[id] = pop.size * t * sup[id]
	# the minor parties' true believers: a fixed share of every group's votes
	if MINOR_PARTIES.size():
		var total = 0.0
		var fixed = 0.0
		for id in out: total += out[id]
		for m in MINOR_PARTIES: fixed += float(m.share)
		for id in out: out[id] *= 1.0 - fixed
		for m in MINOR_PARTIES: out[m.id] = total * float(m.share)
	return out

# ---------- Groups ----------
func group_kinds() -> Array:
	var ages = AGES.map(func(a): return {"id": a.id, "label": a.label, "who": {"age": a.id}})
	var nats = NATIONALITIES.map(func(n): return {"id": n.id, "label": n.label, "who": {"nationality": n.id}})
	var classes = CLASSES.map(func(c): return {"id": c.id, "label": c.label, "who": {"class": c.id}})
	var regions = REGIONS.map(func(r): return {"id": r.id, "label": r.name, "who": {"region": r.id}})
	return [
		{"id": "age", "label": "Age groups", "groups": ages},
		{"id": "views", "label": "Political views", "groups": VIEW_GROUPS},
		{"id": "nationality", "label": "Nationality", "groups": nats},
		{"id": "class", "label": "Social class", "groups": classes},
		{"id": "region", "label": "Region", "groups": regions},
	]

func pops_matching(s: Dictionary, who) -> Array:
	return s.pops.filter(func(p): return matches(p, who))

func size_of(s: Dictionary, who) -> float:
	var t = 0.0
	for p in pops_matching(s, who): t += p.size
	return t

## cache: optional {pop id: support}, shared by several summaries of the same moment (a poll).
func summarize(s: Dictionary, pops: Array, ctx = null, cache = null) -> Dictionary:
	if ctx == null: ctx = score_context(s)
	var res = {"size": 0.0, "voters": 0.0, "turnout": 0.0, "support": {}, "core": {}, "pos": {}, "sal": {},
		"aware": 0.0, "leader": 0.0, "leaderPull": 0.0, "backers": 0.0, "devotion": 0.0, "followers": 0.0,
		"disaffection": 0.0, "mobilized": 0.0}
	var player = player_party(s)
	for p in s.parties:
		res.support[p.id] = 0.0
		res.core[p.id] = 0.0
	for m in MINOR_PARTIES:
		res.support[m.id] = 0.0
		res.core[m.id] = 0.0
	for ax in AXES:
		res.pos[ax.id] = 0.0
		res.sal[ax.id] = 0.0
	for pop in pops:
		var sup
		if cache != null and cache.has(pop.id): sup = cache[pop.id]
		else:
			sup = pop_support(s, pop, null, ctx)
			if cache != null: cache[pop.id] = sup
		var votes = pop_votes(pop, sup)
		res.size += pop.size
		for p in s.parties:
			res.support[p.id] += votes[p.id]
			res.voters += votes[p.id]
			res.core[p.id] += pop.size * pop.loyal[p.id]
		for m in MINOR_PARTIES:
			res.support[m.id] += votes[m.id]
			res.voters += votes[m.id]
		for ax in AXES:
			res.pos[ax.id] += pop.size * pop.pos[ax.id]
			res.sal[ax.id] += pop.size * salience_of(s, pop, ax.id)
		var dev = devotion_of(pop, player)
		res.aware += pop.size * pop.aware.player
		res.leader += pop.size * pop.leader.player
		res.leaderPull += pop.size * pop.leaderPull
		res.disaffection += pop.size * pop.disaffection
		res.mobilized += pop.size * pop.mobilized
		res.backers += pop.size * sup.player
		res.devotion += pop.size * sup.player * dev
		if dev >= 0.8: res.followers += pop.size * sup.player
	if res.size:
		var voters: float = res.voters if res.voters else 1.0
		for id in res.support: res.support[id] /= voters
		for ax in AXES:
			res.pos[ax.id] /= res.size
			res.sal[ax.id] /= res.size
		res.turnout = res.voters / res.size
		for k in ["aware", "leader", "leaderPull", "disaffection", "mobilized"]: res[k] /= res.size
		res.devotion = res.devotion / res.backers if res.backers else 0.0
	return res

# ---------- Effects ----------
func shift_perceived(s: Dictionary, shift, record := true) -> void:
	if shift == null: return
	var player = player_party(s)
	for ax in shift:
		var before = stance_of(player.perceived[ax])
		player.perceived[ax] = clampf2(player.perceived[ax] + shift[ax], -100, 100)
		var after = stance_of(player.perceived[ax])
		if record and before != after:
			s.flips.append({"party": player.id, "week": s.week, "axis": ax, "from": before, "to": after})

func preview_shift(s: Dictionary, shift) -> Array:
	var player = player_party(s)
	var out = []
	if shift == null: return out
	for ax in shift:
		out.append({"axis": ax, "delta": shift[ax], "from": stance_of(player.perceived[ax]),
			"to": stance_of(clampf2(player.perceived[ax] + shift[ax], -100, 100)), "manifesto": stance_of(player.manifesto[ax])})
	return out

## Taken seriously, 0-100 (CONFIG.serious): how seriously the country takes your party.
func serious_of(s: Dictionary) -> float:
	return float(s.get("serious", C.serious.start))

## How far your words carry: grows with how seriously you are taken.
func influence_of(s: Dictionary) -> float:
	return lerpf(float(C.influenceMin), float(C.influenceMax), clampf2(serious_of(s) / 100.0, 0, 1))

func influence_label(s: Dictionary) -> String:
	var t = serious_of(s)
	if t < 20: return "Fringe voice"
	if t < 45: return "Getting noticed"
	if t < 70: return "Agenda-setter"
	return "Sets the national debate"

## How much the big moments (the flagship promise, the final debate) move voters: a third
## for a party nobody takes seriously, all of it for one the country does (CONFIG.serious.moments).
func moment_weight(s: Dictionary) -> float:
	var m: Dictionary = C.serious.get("moments", {})
	var lo: float = float(m.get("from", 15))
	var t: float = clampf2((serious_of(s) - lo) / maxf(1.0, float(m.get("full", 60)) - lo), 0, 1)
	return lerpf(float(m.get("low", 0.33)), 1.0, t)

func change_serious(s: Dictionary, d: float) -> void:
	s.serious = clampf2(serious_of(s) + d, 0, 100)

func apply_effects(s: Dictionary, fx: Dictionary) -> void:
	var player = player_party(s)
	var ext: float = player.get("extremity", 0.0)
	var inf = influence_of(s)
	var from_news: bool = fx.get("fromNews", false)
	shift_perceived(s, fx.get("shift"))
	for g in fx.get("goodwill", []):
		var party: String = g.get("party", player.id)
		var amt: float = g.amt
		if amt < 0 and party == player.id: amt = amt * (1 - C.extremeAnger / 2.0 + C.extremeAnger * ext)
		for pop in s.pops:
			if matches(pop, g.get("who")):
				var a2: float = amt * (1 - shield_of(pop, party)) if amt < 0 else amt   # friendly media explain it away
				pop.goodwill[party] = clampf2(pop.goodwill[party] + a2 * C.goodwillScale, -2, 2)
	for id in fx.get("crisis", {}):
		if s.crisis: break
		s.crisisPressure[id] = maxf(-3, float(s.crisisPressure.get(id, 0)) + fx.crisis[id] * inf)
	for k in fx.get("world", {}):
		if s.world.has(k): s.world[k] = clampf2(s.world[k] + fx.world[k] * (1.0 if from_news else inf), 0, 100)
	for ax in fx.get("permSal", {}): s.permSal[ax] = float(s.permSal.get(ax, 0)) + fx.permSal[ax]
	if fx.get("leader"):
		var scale: float = player.charisma / 50.0 * (1 - C.extremeLeader / 2.0 + C.extremeLeader * ext)
		var list = _leader_list(fx.leader)
		for pop in s.pops:
			for g in list:
				var who = {} if (g is float or g is int) else g.get("who")
				var amt: float = float(g) if (g is float or g is int) else g.amt
				if matches(pop, who): pop.leader.player = clampf2(pop.leader.player + amt * scale, -2, 2)
	if fx.get("charisma"): player.charisma = clampf2(player.charisma + fx.charisma, 10, 100)
	# events can make people want a different kind of leader for a while: {"wants": {"strongman": 0.4}}
	if fx.has("wants"):
		if not s.has("wantMod"): s.wantMod = {}
		for k in fx.wants: s.wantMod[k] = clampf2(float(s.wantMod.get(k, 0)) + float(fx.wants[k]), -0.6, 1.5)
	for ax in fx.get("salience", {}):
		s.salMod[ax] = clampf2(float(s.salMod.get(ax, 0)) + fx.salience[ax] * (1.0 if from_news else inf), -0.5, 1.5)
	if fx.get("trust"): change_trust(s, fx.trust * (1.0 if (from_news or fx.trust > 0) else inf))
	for pid in fx.get("stability", {}):
		var p = party_of(s, pid)
		if p: p.stability = clampf2(p.stability + fx.stability[pid], 0, 100)
	var coverage: float = fx.awareness if fx.has("awareness") and fx.awareness != null else C.eventAwareness
	for pop in s.pops:
		pop.aware[player.id] = clampf2(pop.aware[player.id] + (1 - pop.aware[player.id]) * coverage, 0.01, 1)
	if fx.get("money"): s.money = maxf(0, s.money + fx.money)
	for c in fx.get("country", []): note_country(s, c)
	if fx.get("flag"): s.flags[fx.flag] = s.week
	if fx.get("scandal"): _money_secret(s, fx)
	if fx.get("followup"):
		var lo: int = int(fx.followup.months[0])
		var hi: int = int(fx.followup.months[1])
		var months = lo + int(floor(rand(s) * (hi - lo + 1)))
		s.scheduled.append({"id": fx.followup.event, "week": s.week + months * WEEKS_PER_MONTH})

# ---------- Neighbouring countries ----------
func note_country(s: Dictionary, c: Dictionary) -> void:
	if not s.has("countries"): s.countries = {}
	if not s.countries.has(c.id): s.countries[c.id] = {"notes": []}
	var st: Dictionary = s.countries[c.id]
	if c.get("note"): st.notes.append({"week": s.week, "text": c.note})
	if c.get("relation"): st.relation = c.relation
	if c.has("hot") and c.hot != null: st.hot = c.hot

# ---------- Trust ----------
func change_trust(s: Dictionary, d: float) -> void:
	s.trust = clampf2(s.trust + d, 0, 100)

# ---------- Issue ownership ----------
func add_ownership(s: Dictionary, party_id: String, key: String, amount: float) -> void:
	if not s.ownership.has(key): s.ownership[key] = {}
	var owners: Dictionary = s.ownership[key]
	owners[party_id] = clampf2(float(owners.get(party_id, 0)) + amount, 0, 1)

func ownership_table(s: Dictionary) -> Array:
	var rows = []
	for key in s.ownership:
		var owners: Dictionary = s.ownership[key]
		var total = dsum(owners)
		var list = []
		for pid in owners:
			if owners[pid] >= 0.02: list.append([pid, owners[pid]])
		list = ssort(list, func(a, b): return b[1] - a[1])
		var owners_out = list.map(func(x): return {"party": x[0], "value": x[1], "share": x[1] / total if total else 0.0})
		var axis: String = key.split(":")[0]
		if owners_out.size():
			rows.append({"key": key, "axis": axis, "label": side_label(key), "heat": float(s.salMod.get(axis, 0)), "owners": owners_out})
	return rows

## Every party campaigns on at most two issues. Anything beyond the strongest
## two (always keeping `keep`) is lost completely.
func trim_claims(s: Dictionary, party_id: String, keep := "") -> void:
	var held = []
	for key in s.ownership:
		if float(s.ownership[key].get(party_id, 0)) > 0: held.append(key)
	held = ssort(held, func(a, b):
		if a == keep: return -1
		if b == keep: return 1
		return s.ownership[b][party_id] - s.ownership[a][party_id])
	for key in held.slice(int(C.maxSignatureIssues)): s.ownership[key].erase(party_id)

func ownership_of(s: Dictionary, party_id: String, key: String) -> float:
	return float(s.ownership.get(key, {}).get(party_id, 0))

# ---------- People the game creates ----------
## A new person: a name from the pool that fits their background (data/names.json)
## and a hometown in their region. region "" picks one by population; nationality ""
## picks one by the region's mix. Names already in use are skipped.
func make_person(s: Dictionary, region := "", nationality := "", sex := "", age := 0) -> Dictionary:
	if region == "":
		var tot = 0.0
		for r in REGIONS: tot += float(r.adults)
		var x: float = rand(s) * tot
		region = REGIONS[-1].id
		for r in REGIONS:
			x -= float(r.adults)
			if x <= 0: region = r.id; break
	var reg = by_id(REGIONS, region)
	if nationality == "" and reg:
		var x2: float = rand(s)
		nationality = "cranebonian"
		for nid in reg.nationalities:
			x2 -= float(reg.nationalities[nid])
			if x2 <= 0: nationality = nid; break
	if sex == "": sex = "f" if rand(s) < 0.5 else "m"
	if age <= 0: age = 32 + int(rand(s) * 30)
	var key: String = "alinni" if nationality == "alinnian" else ("norbanian" if nationality == "norbanian" else String(NAMES.get("REGIONS", {}).get(region, "cranbia")))
	var pool: Dictionary = NAMES.get("POOLS", {}).get(key, {})
	var name = ""
	var used = {}
	for p in s.parties: used[p.leader] = true
	for f in s.figures: used[f.name] = true
	for l in s.get("figuresLost", []): used[l.name] = true
	if pool.is_empty():
		var lp = LEADER_POOL.filter(func(n): return not used.has(n.name))
		name = pick(s, lp).name if lp.size() else "Alex Mercer"
	else:
		for i in 30:
			name = "%s %s" % [pick(s, pool[sex]), pick(s, pool.last)]
			if not used.has(name): break
	var towns = MAP.cities.filter(func(c): return c.area == region)
	var home: String = pick(s, towns).name if towns.size() and rand(s) < 0.8 else (reg.name if reg else "")
	return {"name": name, "sex": sex, "age": age, "region": region, "nationality": nationality, "hometown": home}

## Someone from abroad (a minister, an envoy, a businessman): a name from their
## country's pool (names.json FOREIGN).
func make_foreign_person(s: Dictionary, country: String, sex := "") -> Dictionary:
	if sex == "": sex = "f" if rand(s) < 0.5 else "m"
	var key: String = String(NAMES.get("FOREIGN", {}).get(country, ""))
	var pool: Dictionary = NAMES.get("POOLS", {}).get(key, {})
	if pool.is_empty(): return {"name": "", "sex": sex, "country": country}
	return {"name": "%s %s" % [pick(s, pool[sex]), pick(s, pool.last)], "sex": sex, "country": country}

# ---------- Opening and closing debates ----------
func debate_by_id(s: Dictionary, id: String) -> Variant:
	for d in s.debates:
		if d.id == id: return d
	return null

func side_of_lean(axis: String, lean: float) -> String:
	var ax = by_id(AXES, axis)
	return ax.left if lean < 0 else ax.right

func open_debate(s: Dictionary, id: String, axis: String, title: String, text: String, source: String, heat: float, lean := 0.0) -> Dictionary:
	var d = debate_by_id(s, id)
	if d:
		d.heat = clampf2(d.heat + heat * 0.6, 0, 100)
		d.lean = clampf2(d.lean + lean * 0.5, -100, 100)
		return d
	d = {"id": id, "topic": id, "axis": axis, "title": title, "text": text, "source": source, "heat": heat, "lean": lean,
		"started": s.week, "peak": heat, "moves": [], "history": [heat]}
	s.debates.append(d)
	if s.debates.size() > DEBATE_MAX:
		var coolest = null
		for x in s.debates:
			if x != d and (coolest == null or x.heat < coolest.heat): coolest = x
		end_debate(s, coolest)
	return d

func end_debate(s: Dictionary, d: Dictionary) -> void:
	s.debates.erase(d)
	s.debateCooldown[d.id] = s.week
	s.debatesPast.append({"title": d.title, "axis": d.axis, "lean": d.lean, "peak": d.peak, "week": s.week})
	if d.peak >= 40 and absf(d.lean) >= 35:
		push_news(s, {"kind": "issue", "quiet": true, "title": "%s: the argument is settling" % d.title,
			"text": "The country has stopped shouting about it, but the %s side won the argument. Voters' minds moved, and they won't move back quickly." % side_of_lean(d.axis, d.lean).to_lower()})

func style_profile(s: Dictionary) -> Dictionary:
	var total = dsum(s.style)
	if total < 2: return {"label": "Still finding a voice", "shares": {}}
	var shares = {}
	for k in s.style: shares[k] = s.style[k] / total
	var sh = func(k): return float(shares.get(k, 0))
	var label = "A bit of everything"
	if sh.call("folksy") + sh.call("provocative") > 0.65 and sh.call("provocative") > 0.25: label = "Charismatic buffoon"
	elif sh.call("fiery") + sh.call("provocative") > 0.65: label = "Firebrand"
	elif sh.call("statesman") > 0.55: label = "Statesman"
	elif sh.call("folksy") > 0.5: label = "Man of the people"
	elif sh.call("statesman") + sh.call("fiery") > 0.7: label = "Strongman"
	elif sh.call("statesman") + sh.call("folksy") > 0.7: label = "Reassuring uncle"
	if label == "Man of the people" and player_party(s).leaderSex == "f": label = "Woman of the people"
	if label == "Reassuring uncle" and player_party(s).leaderSex == "f": label = "Reassuring aunt"
	return {"label": label, "shares": shares}
