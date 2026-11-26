## rules/rivals.gd — The rival parties: their moods and happenings, adapting to you, filling niches, their monthly turn, and relations with you.
extends "res://scripts/rules/scandals.gd"

# ---------- Rival parties ----------
func free_core_voters(s: Dictionary, party: Dictionary, share: float) -> float:
	var freed = 0.0
	for pop in s.pops:
		var lost: float = pop.loyal[party.id] * share
		pop.loyal[party.id] -= lost
		freed += lost * pop.size
	return freed

func biggest_differences(s: Dictionary, a: Dictionary, b: Dictionary, n := 2) -> Array:
	var list = AXES.map(func(ax): return {"ax": ax.id, "d": b.perceived[ax.id] - a.perceived[ax.id]})
	return ssort(list, func(x, y): return absf(y.d) - absf(x.d)).slice(0, n)

func _happening_weight(id: String, p: Dictionary) -> float:
	match id:
		"scandal": return 1 + (60 - p.stability) / 40.0
		"infighting": return 0.8 + (55 - p.stability) / 30.0
		"new_leader": return 1.2 if (p.charisma < 48 or p.stability < 40) else 0.3
		"rebound": return 0.7 if p.stability < 50 else 0.4
	return 0.0

func _happening_run(id: String, s: Dictionary, p: Dictionary) -> void:
	match id:
		"scandal":
			p.stability = clampf2(p.stability - 18, 0, 100)
			p.charisma = clampf2(p.charisma - 5, 10, 100)
			change_trust(s, -4)
			for pop in s.pops: pop.goodwill[p.id] = clampf2(pop.goodwill[p.id] - 0.25, -2, 2)
			push_news(s, merged({"party": p.id, "kind": "bad"}, news("RIVAL", "scandal", p)))
		"infighting":
			p.stability = clampf2(p.stability - 12, 0, 100)
			push_news(s, merged({"party": p.id, "kind": "bad"}, news("RIVAL", "infighting", p)))
		"new_leader":
			var old: String = p.leader
			var reach: Dictionary = by_id(PARTIES, p.id).get("reach", {}) if by_id(PARTIES, p.id) else {}
			var home_region: String = "alinni" if float(reach.get("alinni", 0)) >= 1 and float(reach.get("default", 1)) < 1 else ""
			var nxt: Dictionary = make_person(s, home_region, "alinnian" if home_region == "alinni" else "", "", 45 + int(rand(s) * 25))
			p.leader = nxt.name; p.leaderSex = nxt.sex; p.leaderAge = nxt.age; p.leaderHome = nxt.hometown
			p.charisma = float(jround(28 + rand(s) * 50))
			p.stability = 58.0
			var ax: String = pick(s, AXES).id
			var dir = -1 if rand(s) < 0.5 else 1
			p.perceived[ax] = clampf2(p.perceived[ax] + dir * 22, -100, 100)
			p.manifesto[ax] = p.perceived[ax]
			var a = by_id(AXES, ax)
			var styles: Dictionary = NEWS.get("RIVAL", {}).get("new_leader_style", {})
			var style: String = String(styles.get("star" if p.charisma >= 62 else ("dull" if p.charisma <= 40 else "plain"), ""))
			push_news(s, merged({"party": p.id, "kind": "good" if p.charisma >= 55 else "neutral"}, news("RIVAL", "new_leader", p, {"old": old, "style": style, "toward": (a.left if dir < 0 else a.right).to_lower()})))
		"rebound":
			p.stability = clampf2(p.stability + 15, 0, 100)
			p.charisma = clampf2(p.charisma + 6, 10, 100)
			for pop in s.pops:
				if pop.loyal[p.id] > 0.15: pop.goodwill[p.id] = clampf2(pop.goodwill[p.id] + 0.2, -2, 2)
			push_news(s, merged({"party": p.id, "kind": "good"}, news("RIVAL", "rebound", p)))

func rival_happening(s: Dictionary) -> void:
	var cands = []
	var total = 0.0
	for p in rivals(s):
		for h in HAPPENINGS:
			var w = maxf(0.05, _happening_weight(h, p))
			cands.append([p, h, w]); total += w
	var r = rand(s) * total
	for c in cands:
		r -= c[2]
		if r <= 0:
			_happening_run(c[1], s, c[0])
			return

func collapse_party(s: Dictionary, p: Dictionary) -> void:
	var freed = free_core_voters(s, p, 0.3)
	for pop in s.pops: pop.goodwill[p.id] = clampf2(pop.goodwill[p.id] - 0.3, -2, 2)
	p.stability = 45.0
	p.charisma = clampf2(p.charisma - 8, 10, 100)
	p.collapses = int(p.get("collapses", 0)) + 1
	p.lastCollapse = s.week
	p.stability = 55.0
	change_trust(s, -3)
	push_news(s, merged({"party": p.id, "kind": "vacuum"}, news("RIVAL", "split", p, {"freed": fmt1(freed / 1e6)})))
	s.queue.append({"type": "event", "event": defector_event(s, p, freed)})

func defector_event(s: Dictionary, p: Dictionary, _freed: float) -> Dictionary:
	var diffs = biggest_differences(s, player_party(s), p)
	var shift = {}
	for x in diffs: shift[x.ax] = signf(x.d) * 10
	var small = {}
	for x in diffs.slice(0, 1): small[x.ax] = signf(x.d) * 5
	return {
		"id": "defectors_" + p.id, "kind": "opportunity", "title": "A wing of %s asks to join you" % p.short,
		"text": "The fifteen MPs who walked out of %s want a new home, and they have asked for yours. They would bring their local branches with them, and expect room for their views. The papers are already calling it rats leaving a sinking ship; your rivals will call you an opportunist either way." % p.name,
		"choices": [
			{"label": "Take them all in, MPs and branches", "effects": {"shift": shift, "awareness": 0.05, "defect": {"from": p.id, "share": 0.22},
				"goodwill": [{"who": {"loyalTo": p.id}, "amt": 0.3}]}},
			{"label": "Take the local branches, not the MPs", "effects": {"shift": small, "defect": {"from": p.id, "share": 0.1},
				"goodwill": [{"who": {"loyalTo": p.id}, "amt": 0.12}]}},
			{"label": "Refuse: we are not a home for failed politicians", "effects": {"awareness": 0.02, "trust": 1,
				"goodwill": [{"who": {"lean": {"system": "<-20"}}, "amt": 0.15}]}},
		],
	}

func defect(s: Dictionary, from_id: String, share: float) -> float:
	var from = party_of(s, from_id)
	var player = player_party(s)
	var moved = 0.0
	for pop in s.pops:
		var closeness = clampf2(1.4 - distance(s, pop, player.perceived) / 60.0, 0, 1)
		var m: float = pop.loyal[from_id] * share * closeness
		pop.loyal[from_id] -= m
		pop.loyal.player = clampf2(pop.loyal.player + m, 0, 0.9)
		pop.aware.player = maxf(pop.aware.player, minf(1, pop.aware.player + m * 2))
		moved += m * pop.size
	from.stability = clampf2(from.stability - 5, 0, 100)
	return moved

func rivals_adapt(s: Dictionary, before: Dictionary, now: Dictionary) -> void:
	var player = player_party(s)
	var nation = summarize(s, s.pops)
	for p in rivals(s):
		var lost: float = before[p.id] - now[p.id]
		var you_gained: float = now.player - before.player
		if lost < 0.015 or you_gained < 0.01: continue
		var scored = AXES.map(func(a): return {"a": a, "score": nation.sal[a.id] * absf(player.perceived[a.id] - p.perceived[a.id])})
		var ax: Dictionary = ssort(scored, func(x, y): return y.score - x.score)[0].a
		var d = clampf2(player.perceived[ax.id] - p.perceived[ax.id], -15, 15)
		p.perceived[ax.id] = clampf2(p.perceived[ax.id] + d, -100, 100)
		p.manifesto[ax.id] = p.perceived[ax.id]
		var side = "L" if d < 0 else "R"
		add_ownership(s, p.id, side_key(ax.id, side), 0.12)
		trim_claims(s, p.id, side_key(ax.id, side))
		push_news(s, merged({"party": p.id, "kind": "threat"}, news("RIVAL", "copies_you", p, {"issue": ax.issue.to_lower(), "toward": (ax.left if d < 0 else ax.right).to_lower()})))

func rivals_fill_niche(s: Dictionary) -> void:
	var best = null
	var best_score = 0.0
	for ax in AXES:
		for side in ["L", "R"]:
			var key = side_key(ax.id, side)
			var held = 0.0
			for pid in s.ownership.get(key, {}): held += float(s.ownership[key][pid])
			if held >= 0.05: continue
			var sg = -1.0 if side == "L" else 1.0
			var demand = 0.0
			for pop in s.pops: demand += pop.size * maxf(0, sg * pop.pos[ax.id] / 100.0) * pop.sal[ax.id]
			# the party that can most credibly take it: already on that side, or near the middle
			for p in rivals(s):
				var lean: float = sg * p.perceived[ax.id]
				if lean < -25: continue
				var sc: float = demand * (1.0 + maxf(0, lean) / 100.0) * (0.6 + rand(s) * 0.8)
				if sc > best_score:
					best_score = sc; best = {"party": p, "ax": ax, "side": side, "key": key}
	if best == null: return
	var p: Dictionary = best.party
	var ax: Dictionary = best.ax
	var sg = -1.0 if best.side == "L" else 1.0
	p.perceived[ax.id] = clampf2(p.perceived[ax.id] + sg * 12, -100, 100)
	p.manifesto[ax.id] = p.perceived[ax.id]
	add_ownership(s, p.id, best.key, 0.12)
	trim_claims(s, p.id, best.key)
	var name = (ax.left if best.side == "L" else ax.right).to_lower()
	push_news(s, merged({"party": p.id, "kind": "threat"}, news("RIVAL", "fills_niche", p, {"side": name, "issue": ax.issue.to_lower()})))

func rivals_monthly(s: Dictionary, now_support: Dictionary) -> void:
	for p in rivals(s):
		var trend: float = now_support[p.id] - s.lastSupport[p.id] if s.lastSupport else 0.0
		var d: float = (60 - p.stability) * 0.08 + rand_normal(s) * 3 + clampf2(trend * 120, -4, 4)
		if p.ruling: d -= 0.8 + maxf(0, 35 - s.trust) * 0.05
		elif p.get("partner", false): d -= 0.4 + maxf(0, 35 - s.trust) * 0.025
		p.stability = clampf2(p.stability + d, 0, 100)
	if rand(s) < C.rivalEventChance: rival_happening(s)
	if rand(s) < NICHE_CHANCE: rivals_fill_niche(s)
	var falling = null
	for p in rivals(s):
		if p.stability < C.collapseAt and s.week - int(p.get("lastCollapse", -999)) > C.collapseCooldownMonths * WEEKS_PER_MONTH:
			falling = p; break
	if falling: collapse_party(s, falling)

# ---------- The rivals' turn ----------
func rival_move(s: Dictionary, p: Dictionary, text: String, loud := false) -> void:
	if not s.has("rivalMoves"): s.rivalMoves = []
	s.rivalMoves.append({"week": s.week, "party": p.id, "text": text})
	if s.rivalMoves.size() > 120: s.rivalMoves = s.rivalMoves.slice(-120)
	# the ticker carries every move; only what lands on you stops the clock
	push_news(s, {"party": p.id, "kind": "threat", "title": text.trim_suffix("."), "text": "", "quiet": not loud})

func rival_income(s: Dictionary, p: Dictionary, share: float) -> float:
	return C.incomeBase * 0.8 + share * C.incomePerShare + C.businessBase * (0.3 + 0.9 * float(p.get("establishment", 0.5))) * 0.8

func rivals_turn(s: Dictionary, now: Dictionary) -> void:
	var quarter: bool = calendar(s.week).isQuarterStart
	var proj: Dictionary = s.get("projection", {})
	for p in rivals(s):
		if not p.has("money"): p.money = 5.0 + 6.0 * float(p.get("establishment", 0.5))
		if quarter: p.money = float(p.money) + rival_income(s, p, float(now.get(p.id, 0)))
		if not in_campaign(s): _rival_trip(s, p, proj)   # in the campaign they tour on their convoy (campaign.gd)
		_rival_ads(s, p)
		_rival_media(s, p)
		_rival_dig(s, p, now)

## The province where a trip matters most: one they could take, or one they could lose.
func _rival_trip(s: Dictionary, p: Dictionary, proj: Dictionary) -> void:
	var best = null
	var best_v = 0.0
	var reach: Dictionary = by_id(PARTIES, p.id).get("reach", {}) if by_id(PARTIES, p.id) else {}
	for d in DISTRICTS:
		var x: Dictionary = proj.get(d.id, {})
		if x.is_empty(): continue
		if float(reach.get(d.region, reach.get("default", 1))) < 0.5: continue   # a party tours where it organises
		var tot: float = dsum(x.votes)
		if tot <= 0: continue
		var mine: float = float(x.votes.get(p.id, 0)) / tot
		var gap: float = absf(float(x.share) - mine) if x.winner != p.id else float(x.margin)
		if gap > 0.12: continue
		var v: float = float(d.seats) * (0.13 - gap) * (0.7 + rand(s) * 0.6)
		if v > best_v: best_v = v; best = d
	if best == null: return
	rival_visit(s, p, best)

## A rival's leader in a province: a monthly trip, or a stop of its campaign convoy.
func rival_visit(s: Dictionary, p: Dictionary, best: Dictionary, mult := 1.0) -> void:
	var st: Dictionary = s.districts[best.id]
	if not st.has("rtrip"): st.rtrip = {}
	var had: float = float(st.rtrip.get(p.id, 0))
	st.rtrip[p.id] = minf(0.8, had + mult * VISIT_GOODWILL * RIVAL_EDGE * sqrt(float(p.charisma) / 50.0) / (1.0 + 2.0 * had))
	if not st.has("rtripWeek"): st.rtripWeek = {}
	st.rtripWeek[p.id] = s.week   # shown on the map: who has been campaigning where
	rival_move(s, p, news("MOVE", "toured", p, {"place": best.name}))

## Adverts: some of the money goes on the groups the party wants most.
func _rival_ads(s: Dictionary, p: Dictionary) -> void:
	if float(p.money) < 2 or rand(s) > 0.8: return
	var spend: float = snappedf(minf(float(p.money) * 0.4, 1.0 + float(p.money) * 0.1), 0.5)
	if spend <= 0: return
	p.money = float(p.money) - spend
	var k: float = 0.012 * spend * RIVAL_EDGE
	var perc: Dictionary = p.perceived
	for pop in s.pops:
		# closer voters are the cheap ones to win (by what each group cares about)
		var d = 0.0
		var w = 0.0
		var sal: Dictionary = pop.sal
		var pp: Dictionary = pop.pos
		for ax in sal:
			d += sal[ax] * absf(pp[ax] - perc[ax])
			w += sal[ax]
		var near: float = clampf2(1.0 - (d / w if w > 0 else 0.0) / 60.0, 0, 1)
		pop.goodwill[p.id] = clampf2(pop.goodwill[p.id] + k * near, -2, 2)
	rival_move(s, p, news("MOVE", "adverts", p, {"amount": fmt1(spend)}))

## A personality whose line is close to theirs, and once in a while an outlet for sale.
func _rival_media(s: Dictionary, p: Dictionary) -> void:
	if not s.has("media"): return
	var have = false
	for o in OUTLETS:
		if s.media[o.id].get("sponsor", "") == p.id: have = true
	if not have and rand(s) < 0.2:
		var best = null
		var bf = 0.1
		for o in OUTLETS:
			if o.kind != "influencer" or s.media[o.id].get("sponsor", "") != "": continue
			var f: float = outlet_favour(s, o, p) + float(s.media[o.id].get("reachNat", 0)) * 2
			if f > bf and float(p.money) >= sponsor_price(s, o) * 2: bf = f; best = o
		if best:
			var price: float = sponsor_price(s, best)
			p.money = float(p.money) - price
			s.media[best.id].sponsor = p.id
			rival_move(s, p, news("MOVE", "sponsor", p, {"personality": best.name}))
	if rand(s) < 0.015:
		for o in OUTLETS:
			var st: Dictionary = s.media[o.id]
			var price: float = float(o.get("price", 0))
			if price <= 0 or st.owner != "" or float(p.money) < price * 1.3: continue
			if outlet_favour(s, o, p) < 0.2: continue
			p.money = float(p.money) - price
			st.owner = p.id
			rival_move(s, p, news("MOVE", "bought", p, {"outlet": o.name}))
			break

## Investigators: usually at whoever is closest to them in the polls.
func _rival_dig(s: Dictionary, p: Dictionary, now: Dictionary) -> void:
	if float(p.money) < 2 or rand(s) > 0.1: return
	p.money = float(p.money) - 2.0
	var target = null
	var close = 1.0
	for q in s.parties:
		if q.id == p.id: continue
		var gap: float = absf(float(now.get(q.id, 0)) - float(now.get(p.id, 0)))
		if q.isPlayer: gap *= 0.7   # the new party is everyone's favourite target
		gap *= clampf2(1.0 + (relation(s, p.id) if q.isPlayer else pair_relation(s, p.id, q.id)) / 100.0, 0.3, 1.7)   # and the ones they can't stand
		if gap < close: close = gap; target = q
	if target == null: return
	var r = rand(s)
	if r < 0.15:
		for pop in s.pops: pop.goodwill[p.id] = clampf2(pop.goodwill[p.id] - 0.08, -2, 2)
		rival_move(s, p, news("MOVE", "caught", p, {"target": target.short}), target.isPlayer)
		if target.isPlayer: change_relation(s, p.id, -4, "they spied on you")
		else: change_pair(s, target.id, p.id, -4, "%s were caught spying on %s" % [p.short, target.short])
		return
	if r > 0.6:
		rival_move(s, p, news("MOVE", "nothing", p, {"target": target.short}))
		return
	if target.isPlayer and live_secrets(s).size():
		var sec: Dictionary = ssort(live_secrets(s), func(a, b): return float(b.size) - float(a.size))[0]
		change_relation(s, p.id, -6, "they dug up dirt on you")
		rival_move(s, p, news("MOVE", "found", p, {"target": target.short}))
		leak_secret(s, sec, p.short)
		return
	if target.isPlayer:
		var dirty: Array = s.record.money.filter(func(m): return m.dirty)
		var hit: float = 0.22 if dirty.size() else 0.08
		var what: String = news("MOVE", "leak_you_money" if dirty.size() else "leak_you_expenses", null, {"target": target.short, "target_leader": target.leader})
		for pop in s.pops: pop.goodwill.player = clampf2(pop.goodwill.player - hit * (1 - shield_of(pop, "player")), -2, 2)
		for o in OUTLETS: s.media[o.id].buzz = clampf2(float(s.media[o.id].buzz) - hit * float(o.get("honesty", 0.5)), -1, 1)
		change_relation(s, p.id, -6, "they dug up dirt on you")
		rival_move(s, p, news("MOVE", "leak_you", p, {"what": what}), true)
	else:
		target.stability = clampf2(float(target.stability) - 6, 0, 100)
		for pop in s.pops: pop.goodwill[target.id] = clampf2(pop.goodwill[target.id] - 0.1 * (1 - shield_of(pop, target.id)), -2, 2)
		rival_move(s, p, news("MOVE", "leak", p, {"target": target.short}))
		change_pair(s, target.id, p.id, -5, "%s leaked a story about %s" % [p.short, target.short])

func frontrunner_scrutiny(s: Dictionary, now: Dictionary) -> void:
	if now.player < C.scrutinyFrom or rand(s) > C.scrutinyChance: return
	var story: Dictionary = pick(s, SCRUTINY_STORIES)
	apply_effects(s, merged(story.fx, {"awareness": 0.02}))
	push_news(s, {"kind": "threat", "title": story.title, "text": news("WORLD", "front_scrutiny", null, {"text": story.text})})

# ---------- Relations with the other parties (skeleton) ----------
## How each rival party feels about yours, -100 (bitter) to +100 (friendly).
## It starts from how close your policies are, drifts back there slowly, and is
## moved by what you do to them. Nothing uses it yet: later, parties standing
## aside in each other's districts, and forming a government.
func relation_base(s: Dictionary, pid: String) -> float:
	return pair_base(s, player_party(s), party_of(s, pid))

## How cut off a party is: how far its positions are from everyone else's, 0..1.
## Two parties nobody else will touch warm to each other (CONFIG.relations.isolated).
func isolation(s: Dictionary, p: Dictionary) -> float:
	var tot = 0.0
	var n = 0
	for q in s.parties:
		if q.id == p.id: continue
		tot += policy_relation(p, q); n += 1
	return clampf2(-(tot / maxf(1, n)) / 30.0, 0, 1)

## What two parties' positions alone earn them, plus the pull between two outcasts.
func pair_base(s: Dictionary, a: Dictionary, b: Dictionary) -> float:
	return policy_relation(a, b) + float(C.get("relations", {}).get("isolated", 25)) * isolation(s, a) * isolation(s, b)

## How party a and party b see each other, -100..100. The player's relations are
## the ones built during the campaign; between two rivals, how close they stand.
func party_relation(s: Dictionary, a: String, b: String) -> float:
	if a == b: return 100.0
	var pa = party_of(s, a)
	var pb = party_of(s, b)
	if pa == null or pb == null: return 0.0
	if pa.isPlayer: return relation(s, b)
	if pb.isPlayer: return relation(s, a)
	return pair_relation(s, a, b)

# ----- Between two rival parties: the same model as yours, the same both ways -----
func _pair_key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a

func pair_relation(s: Dictionary, a: String, b: String) -> float:
	var pa = party_of(s, a)
	var pb = party_of(s, b)
	if pa == null or pb == null: return 0.0
	var st: Dictionary = s.get("pairRel", {}).get(_pair_key(a, b), {})
	return clampf2(float(st.get("fade", pair_base(s, pa, pb))) + float(st.get("scar", 0.0)), -100, 100)

## A hostile act between two rivals leaves a scar; a favour heals scars first.
func change_pair(s: Dictionary, a: String, b: String, delta: float, why: String) -> void:
	var pa = party_of(s, a)
	var pb = party_of(s, b)
	if pa == null or pb == null or a == b: return
	if pa.isPlayer: change_relation(s, b, delta, why); return
	if pb.isPlayer: change_relation(s, a, delta, why); return
	if not s.has("pairRel"): s.pairRel = {}
	var k: String = _pair_key(a, b)
	var st: Dictionary = s.pairRel.get(k, {"fade": pair_base(s, pa, pb), "scar": 0.0, "notes": []})
	var fade: float = float(st.fade)
	var scar: float = float(st.scar)
	if delta < 0:
		scar += delta * SCAR_SHARE
		fade += delta * (1 - SCAR_SHARE)
	else:
		var heal: float = minf(delta, -scar)
		scar += heal
		fade += delta - heal
	st.fade = clampf2(fade, -100, 100)
	st.scar = clampf2(scar, -100, 0)
	var notes: Array = st.get("notes", [])
	notes.append({"week": s.week, "text": why, "delta": delta, "by": a})
	st.notes = notes.slice(-6)
	s.pairRel[k] = st

## The worst blood between two rivals, in a few words ("" when there is none worth saying).
func pair_grudge(s: Dictionary, a: String, b: String) -> String:
	var st: Dictionary = s.get("pairRel", {}).get(_pair_key(a, b), {})
	if float(st.get("scar", 0)) > -4: return ""
	var worst = null
	for n in st.get("notes", []):
		if float(n.delta) < 0 and (worst == null or float(n.delta) <= float(worst.delta)): worst = n
	return String(worst.text) if worst else ""

## At the start: what the parties remember from before the game (content.json PARTY_HISTORY).
func new_pair_relations(s: Dictionary) -> void:
	s.pairRel = {}
	for h in PARTY_HISTORY:
		var ids: Array = h.get("parties", [])
		if ids.size() == 2: change_pair(s, ids[0], ids[1], float(h.get("amt", -20)), String(h.get("why", "")))

## How two parties feel about each other from their positions alone, -40..40.
func policy_relation(a: Dictionary, b: Dictionary) -> float:
	var dist = 0.0
	for ax in AXES: dist += absf(float(a.perceived[ax.id]) - float(b.perceived[ax.id]))
	return clampf2(40.0 - dist / AXES.size() * 1.1, -40, 40)

## The everyday relationship (it fades back toward the base) plus scars (they don't).
func relation(s: Dictionary, pid: String) -> float:
	return clampf2(_rel_fading(s, pid) + relation_scar(s, pid), -100, 100)

func _rel_fading(s: Dictionary, pid: String) -> float:
	return float(s.get("relations", {}).get(pid, relation_base(s, pid)))

func relation_scar(s: Dictionary, pid: String) -> float:
	return float(s.get("relScars", {}).get(pid, 0.0))

## Hostile acts leave a scar; favours heal scars first, then warm things up.
func change_relation(s: Dictionary, pid: String, delta: float, why: String) -> void:
	if not s.has("relations"): s.relations = {}
	if not s.has("relScars"): s.relScars = {}
	var fading: float = _rel_fading(s, pid)
	var scar: float = relation_scar(s, pid)
	if delta < 0:
		scar += delta * SCAR_SHARE
		fading += delta * (1 - SCAR_SHARE)
	else:
		var heal: float = minf(delta, -scar)
		scar += heal
		fading += delta - heal
	s.relations[pid] = clampf2(fading, -100, 100)
	s.relScars[pid] = clampf2(scar, -100, 0)
	if not s.has("relationNotes"): s.relationNotes = {}
	var notes: Array = s.relationNotes.get(pid, [])
	notes.append({"week": s.week, "text": why, "delta": delta})
	s.relationNotes[pid] = notes.slice(-6)

func new_relations(s: Dictionary) -> Dictionary:
	var out = {}
	for p in rivals(s): out[p.id] = relation_base(s, p.id)
	return out

## Monthly: the everyday part moves a tenth of the way back toward what your
## policies alone would earn. Scars stay until favours heal them.
func relations_monthly(s: Dictionary) -> void:
	for p in rivals(s):
		var v = _rel_fading(s, p.id)
		s.relations[p.id] = v + (relation_base(s, p.id) - v) * 0.1
	for k in s.get("pairRel", {}):
		var ids: PackedStringArray = k.split("|")
		var pa = party_of(s, ids[0])
		var pb = party_of(s, ids[1])
		if pa == null or pb == null: continue
		var st: Dictionary = s.pairRel[k]
		st.fade = float(st.fade) + (pair_base(s, pa, pb) - float(st.fade)) * 0.1

func act_research(s: Dictionary, party_id: String) -> Dictionary:
	var cost: float = ACTIONS.research.cost
	var err = can_act(s, cost)
	if err: return {"ok": false, "text": err}
	spend_action(s, cost)
	var p = party_of(s, party_id)
	# friendly journalists at an honest outlet dig better, and cover your tracks
	var press: Dictionary = friendly_press(s)
	var pk: float = press.k
	var by: String = ("Journalists at %s" % press.outlet.name) if press.outlet and pk >= 0.15 else "Your investigators"
	var r = rand(s)
	var text: String
	if r < 0.15 * (1 - 0.6 * pk):
		apply_effects(s, {"awareness": 0.03, "leader": -0.08,
			"goodwill": [{"who": {"class": ["middle", "upper"]}, "amt": -0.25}, {"who": {}, "amt": -0.05}]})
		text = "%s were caught going through %s's bins. The press is calling it a dirty trick." % [by, p.short]
		change_relation(s, party_id, -15, "caught spying on them")
	elif r < 0.65 + 0.2 * pk:
		var severity = 3 if rand(s) < 0.3 else (2 if rand(s) < 0.6 else 1)
		var what: String = ["an unpaid tax bill", "an expenses fiddle", "secret payments from a tycoon"][severity - 1]
		s.dossiers.append({"party": party_id, "severity": severity, "what": what, "week": s.week})
		text = "%s found it: %s involving %s. The dossier is ready to release whenever you choose." % [by, what, p.leader]
	else:
		text = "%s found nothing useful on %s." % [by, p.short]
	_log(s, "action", text)
	return {"ok": true, "text": text}

func act_release(s: Dictionary, index: int) -> Dictionary:
	var err = can_act(s, 0)
	if err: return {"ok": false, "text": err}
	if index < 0 or index >= s.dossiers.size(): return {"ok": false, "text": "No such dossier."}
	var dos: Dictionary = s.dossiers[index]
	spend_action(s, 0)
	s.dossiers.remove_at(index)
	s.record.dossiers += 1
	var p = party_of(s, dos.party)
	# a story run by a respected outlet that likes you lands harder, and isn't traced back to you
	var press: Dictionary = friendly_press(s)
	var sev: float = float(dos.severity) * (1 + 0.5 * float(press.k))
	p.stability = clampf2(p.stability - 5 * sev, 0, 100)
	p.charisma = clampf2(p.charisma - 3 * sev, 10, 100)
	for pop in s.pops:
		pop.goodwill[p.id] = clampf2(pop.goodwill[p.id] - 0.12 * sev, -2, 2)
		pop.loyal[p.id] *= 1 - 0.03 * sev
	change_trust(s, -2 * sev)
	apply_effects(s, {"awareness": 0.03})
	var ran: String = (" %s ran it on the front page." % press.outlet.name) if press.outlet and press.k >= 0.15 else ""
	var text = "The story broke: %s involving %s. %s is reeling.%s" % [dos.what, p.leader, p.short, ran]
	change_relation(s, p.id, -8.0 * sev * (1 - 0.5 * float(press.k)), "you leaked a dossier on %s" % p.leader)
	_log(s, "action", text)
	return {"ok": true, "text": text}

func can_poach(s: Dictionary, party_id: String) -> bool:
	var p = party_of(s, party_id)
	return p.stability < 40 and s.week - int(p.get("lastPoached", -999)) >= C.poachCooldownMonths * WEEKS_PER_MONTH

func act_poach(s: Dictionary, party_id: String) -> Dictionary:
	var cost: float = ACTIONS.poach.cost
	var err = can_act(s, cost)
	if err: return {"ok": false, "text": err}
	if not can_poach(s, party_id): return {"ok": false, "text": "Nobody in that party is ready to leave right now."}
	spend_action(s, cost)
	var p = party_of(s, party_id)
	p.lastPoached = s.week
	var moved = defect(s, party_id, 0.07)
	var diffs = biggest_differences(s, player_party(s), p, 1)
	shift_perceived(s, {diffs[0].ax: signf(diffs[0].d) * 5})
	var text = "A local %s branch has crossed over to you: its organisers, and about %dk of its loyal voters. Your image moved a little toward theirs." % [p.short, jround(moved / 1000.0)]
	change_relation(s, party_id, -10, "you poached their organisers")
	var claims = ownership_table(s).filter(func(r): return r.owners.any(func(o): return o.party == party_id))
	# organisers cross over easily; one of their politicians only rarely comes with them
	if claims.size() and rand(s) < POACH_FIGURE_CHANCE:
		var who: Dictionary = make_person(s, "")
		var key: String = claims[0].key
		s.figures.append({"id": "poach_%d" % s.week, "name": who.name, "sex": who.sex, "role": "Former %s politician" % p.short, "region": who.region, "hometown": who.hometown,
			"axis": key.split(":")[0], "side": key.split(":")[1], "loyalty": 45.0, "note": "Came over from %s. Still thinks like them on %s." % [p.short, side_label(key).to_lower()]})
		text += " %s, one of their politicians, came with them." % who.name
		change_relation(s, party_id, -8, "%s defected to you" % who.name)
	_log(s, "action", text)
	return {"ok": true, "text": text}

func national_awareness(s: Dictionary) -> float:
	var size = 0.0
	var a = 0.0
	for pop in s.pops:
		size += pop.size
		a += pop.size * pop.aware.player
	return a / size
