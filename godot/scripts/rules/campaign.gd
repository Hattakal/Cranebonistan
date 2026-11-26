## rules/campaign.gd — The official campaign: the last weeks before the election (CONFIG.campaign).
##
## Played week by week: actions come every week, there is no building or steering, and
## the leader travels on a convoy that stops in one province a week along a route planned
## when the campaign starts (and changeable every turn). Each stop is a rally there, with a
## very small effect on the provinces close by. Every rival party runs its own convoy.
## The route may only move so far each week, measured on the map between provinces'
## centres (their biggest town, or the middle when they have none).
extends "res://scripts/rules/moments.gd"

func campaign_start_week() -> int:
	return ELECTION_WEEK - int(C.campaign.weeks)

## Which stop of the route is this week's (0 for the first campaign week).
func campaign_stop_index(s: Dictionary) -> int:
	return s.week - campaign_start_week()

## Can the convoy get from one province to the next in a week?
func convoy_reaches(a: String, b: String) -> bool:
	if a == "" or b == "": return true
	return district_centre(district_by_id(a)).distance_to(district_centre(district_by_id(b))) <= float(C.campaign.reach)

## How much a stop in province `d` is worth to party `pid`: close races, weighted by seats.
func _stop_value(s: Dictionary, pid: String, d: Dictionary) -> float:
	var x: Dictionary = s.get("projection", {}).get(d.id, {})
	if x.is_empty(): return 0.0
	var tot: float = dsum(x.votes)
	if tot <= 0: return 0.0
	var mine: float = float(x.votes.get(pid, 0)) / tot
	var gap: float = float(x.margin) if x.winner == pid else float(x.share) - mine
	return float(d.seats) * maxf(0.02, 0.2 - gap) * (0.5 + mine)

func _reach(pid: String) -> Dictionary:
	var p = by_id(PARTIES, pid)
	return p.get("reach", {}) if p else {}

## A route of `n` provinces for party `pid`, starting after `prev` (a province, or "" for
## anywhere): each stop the most valuable province within a week's reach that it hasn't
## visited yet (the nearest unvisited one, if none is in reach).
func plan_route(s: Dictionary, pid: String, n: int, prev := "", used := []) -> Array:
	var route = []
	var seen: Array = used.duplicate()
	for i in n:
		var best = null
		var best_v = -1.0
		for d in DISTRICTS:
			if seen.has(d.id) or not convoy_reaches(prev, d.id): continue
			if pid != "player" and float(_reach(pid).get(d.region, _reach(pid).get("default", 1))) < 0.5: continue   # a party tours where it organises
			var v: float = _stop_value(s, pid, d) * (0.85 + rand(s) * 0.3)
			if v > best_v: best_v = v; best = d
		if best == null:
			var near = INF
			for d in DISTRICTS:
				if seen.has(d.id): continue
				var dist: float = district_centre(d).distance_to(district_centre(district_by_id(prev))) if prev != "" else 0.0
				if dist < near: near = dist; best = d
		if best == null: break
		route.append(best.id)
		seen.append(best.id)
		prev = best.id
	return route

## The campaign begins: routes for everyone, and the plan on your desk.
func campaign_start(s: Dictionary) -> void:
	var n: int = int(C.campaign.stops)
	s.convoy = {"route": plan_route(s, "player", n)}
	s.rivalConvoys = {}
	for p in rivals(s): s.rivalConvoys[p.id] = plan_route(s, p.id, n)
	push_news(s, merged({"kind": "neutral"}, news("CAMPAIGN", "begins", null, {"weeks": int(C.campaign.weeks)})))
	s.queue.append({"type": "convoy"})

## Change your route from stop `from` on (the stops before it have happened).
func set_route(s: Dictionary, from: int, tail: Array) -> String:
	var route: Array = s.convoy.route
	var keep: Array = route.slice(0, from)
	var prev: String = keep[-1] if keep.size() else ""
	for id in tail:
		if keep.has(id): return "The convoy goes to each province once."
		if not convoy_reaches(prev, id): return "%s is too far from %s for one week on the road." % [district_by_id(id).name, district_by_id(prev).name]
		keep.append(id)
		prev = id
	s.convoy.route = keep.slice(0, int(C.campaign.stops))
	return ""

## A national advert campaign: everyone sees it; each one after the first does less.
func act_ad_campaign(s: Dictionary) -> Dictionary:
	if not in_campaign(s): return {"ok": false, "text": "Advert campaigns are for the official campaign."}
	var cost: float = float(C.campaign.adCost)
	var err = can_act(s, cost)
	if err: return {"ok": false, "text": err}
	spend_action(s, cost)
	var n: int = int(s.get("adCampaigns", 0))
	s.adCampaigns = n + 1
	var k: float = 1.0 / (1.0 + 0.5 * n)
	apply_effects(s, {"goodwill": [{"who": null, "amt": float(C.campaign.adGoodwill) * k}], "awareness": float(C.campaign.adAwareness) * k})
	var text = "Your adverts are on every channel and every phone this week." + (" People have seen a lot of them by now." if n >= 2 else "")
	_log(s, "action", "Ran a national advert campaign (₱%sM)." % fmt1(cost))
	return {"ok": true, "text": text}

## A campaign week: actions come weekly, and every convoy makes its stop. Your rally
## goes on the desk as the local paper's report.
func campaign_weekly(s: Dictionary) -> void:
	if not s.has("convoy"): campaign_start(s)
	s.actionsLeft = int(C.campaign.actionsPerWeek)
	var i: int = campaign_stop_index(s)
	var route: Array = s.convoy.route
	if i < route.size():
		var res: Dictionary = tour(s, route[i], float(C.campaign.rally), true)
		s.queue.append({"type": "rally", "res": res})
		_stronghold_stop(s, "player", route[i])
	pacts_weekly(s)
	for pid in s.get("rivalConvoys", {}):
		var p = party_of(s, pid)
		var r: Array = s.rivalConvoys[pid]
		if p and i < r.size():
			rival_visit(s, p, district_by_id(r[i]), float(C.campaign.rally))
			_stronghold_stop(s, pid, r[i])

## A convoy camped in another party's stronghold (a province it won clearly last time)
## is a small hostile act between the two (CONFIG.relations).
func _stronghold_stop(s: Dictionary, pid: String, did: String) -> void:
	var past: Dictionary = s.get("pastElection", {}).get(did, {})
	var owner: String = String(past.get("winner", ""))
	if owner == "" or owner == pid or float(past.get("margin", 0)) < float(C.relations.get("strongMargin", 0.12)): return
	var d = district_by_id(did)
	change_pair(s, owner, pid, float(C.relations.get("stronghold", -1.5)), "%s campaigned in %s stronghold, %s" % ["You" if pid == "player" else party_of(s, pid).short, "their" if pid == "player" else ("your" if owner == "player" else party_of(s, owner).short + "'s"), d.name if d else did])

# ---------- Pacts to stand aside (the official campaign only) ----------
## Two parties trade a province each: in one, A stands aside for B; in the other, B for A.
## There, the party standing aside keeps 30% of its voters; the rest go to its partner
## (CONFIG.pacts.share). A pact can't be broken. A party agrees when, in the province it
## gets, it isn't leading now but clearly would with its partner's voters, and in the one
## it gives up it isn't close to winning; and the two provinces must be worth about the
## same (fewer than 4 seats apart, and neither more than half as big again).

func _pc(key: String, default):
	return C.get("pacts", {}).get(key, default)

func _shares(s: Dictionary, did: String) -> Dictionary:
	var x: Dictionary = s.get("projection", {}).get(did, {})
	var v: Dictionary = x.get("votes", {})
	var tot: float = dsum(v)
	var out = {}
	for k in v: out[k] = float(v[k]) / tot if tot > 0 else 0.0
	return out

func in_pact(s: Dictionary, did: String) -> bool:
	return s.get("pacts", []).any(func(pk): return pk.district == did)

## Would party `pid` clearly win `did` if `other` stood aside for it there?
func pact_gain(s: Dictionary, pid: String, other: String, did: String) -> bool:
	var sh: Dictionary = _shares(s, did)
	if sh.is_empty(): return false
	var lead = ""
	for k in sh:
		if lead == "" or sh[k] > sh[lead]: lead = k
	if lead == pid: return false   # already winning: no need
	var mine: float = float(sh.get(pid, 0)) + float(sh.get(other, 0)) * float(_pc("share", 0.7))
	var best_other = 0.0
	for k in sh:
		if k == pid: continue
		var v: float = float(sh[k]) * (1.0 - float(_pc("share", 0.7)) if k == other else 1.0)
		best_other = maxf(best_other, v)
	return mine > best_other + float(_pc("clear", 0.03))

## Is party `pid` far enough from winning `did` to give it up?
func pact_can_give(s: Dictionary, pid: String, did: String) -> bool:
	var sh: Dictionary = _shares(s, did)
	if sh.is_empty(): return false
	var top = 0.0
	for k in sh: top = maxf(top, float(sh[k]))
	return top - float(sh.get(pid, 0)) > float(_pc("notClose", 0.08))

func pact_seats_ok(a: String, b: String) -> bool:
	var sa: float = float(district_by_id(a).seats)
	var sb: float = float(district_by_id(b).seats)
	return absf(sa - sb) < float(_pc("seatGap", 4)) and maxf(sa, sb) <= minf(sa, sb) * float(_pc("seatRatio", 1.5))

## Would `pid` take this trade: it gets `gets` (the partner stands aside there) and gives up `gives`?
func pact_acceptable(s: Dictionary, pid: String, other: String, gets: String, gives: String) -> bool:
	if gets == gives or in_pact(s, gets) or in_pact(s, gives): return false
	if not pact_seats_ok(gets, gives): return false
	return pact_gain(s, pid, other, gets) and pact_can_give(s, pid, gives)

## The trades two parties would both take: [{a_gets, b_gets}], best (most seats) first.
func pact_trades(s: Dictionary, a: String, b: String, limit := 4) -> Array:
	var out = []
	for x in DISTRICTS:   # a gets x
		if not pact_gain(s, a, b, x.id) or in_pact(s, x.id): continue
		for y in DISTRICTS:   # b gets y
			if pact_acceptable(s, a, b, x.id, y.id) and pact_acceptable(s, b, a, y.id, x.id):
				out.append({"a_gets": x.id, "b_gets": y.id, "seats": float(x.seats) + float(y.seats)})
	out = ssort(out, func(p, q): return q.seats - p.seats)
	return out.slice(0, limit)

## Parties that can deal at all: not enemies (CONFIG.coalition STANCE).
func can_pact(s: Dictionary, a: String, b: String) -> bool:
	return party_relation(s, a, b) > float(COALITION.get("STANCE", {}).get("enemy", -20))

func make_pact(s: Dictionary, pk: Dictionary) -> void:
	if not s.has("pacts"): s.pacts = []
	if in_pact(s, pk.a_gets) or in_pact(s, pk.b_gets): return
	s.pacts.append({"district": pk.a_gets, "aside": pk.b, "gets": pk.a, "week": s.week})
	s.pacts.append({"district": pk.b_gets, "aside": pk.a, "gets": pk.b, "week": s.week})
	change_pair(s, pk.a, pk.b, float(_pc("warmth", 6)), "a pact to stand aside for each other")
	var pa = party_of(s, pk.a)
	var pb = party_of(s, pk.b)
	var fill = {"a": "you" if pa.isPlayer else pa.short, "b": "you" if pb.isPlayer else pb.short,
		"x": district_by_id(pk.a_gets).name, "y": district_by_id(pk.b_gets).name}
	var item: Dictionary = news("WORLD", "pact", null, fill)
	push_news(s, {"kind": "issue", "quiet": not (pa.isPlayer or pb.isPlayer), "title": item.title, "text": item.text})

## You offer a rival a trade (one action): you get `you_get`, they get `they_get`.
func act_pact(s: Dictionary, rival_id: String, you_get: String, they_get: String) -> Dictionary:
	if not in_campaign(s): return {"ok": false, "text": "Pacts are made in the official campaign."}
	if not can_pact(s, "player", rival_id): return {"ok": false, "text": "%s won't deal with you." % party_of(s, rival_id).short}
	if not pact_acceptable(s, rival_id, "player", they_get, you_get): return {"ok": false, "text": "%s turned it down." % party_of(s, rival_id).short}
	var err = can_act(s, 0)
	if err: return {"ok": false, "text": err}
	spend_action(s, 0)
	make_pact(s, {"a": "player", "b": rival_id, "a_gets": you_get, "b_gets": they_get})
	var text = "%s stands aside for you in %s; you stand aside for them in %s." % [party_of(s, rival_id).short, district_by_id(you_get).name, district_by_id(they_get).name]
	_log(s, "action", "Pact with %s: %s" % [party_of(s, rival_id).short, text])
	return {"ok": true, "text": text}

## What you could offer a rival: trades they would take, where you gain too.
func pact_offers(s: Dictionary, rival_id: String) -> Array:
	if not in_campaign(s) or not can_pact(s, "player", rival_id): return []
	return pact_trades(s, "player", rival_id, 3).map(func(t): return {"you_get": t.a_gets, "they_get": t.b_gets})

## Each campaign week: rivals deal with each other, and now and then one comes to you.
func pacts_weekly(s: Dictionary) -> void:
	var rs: Array = rivals(s)
	for i in rs.size():
		for j in range(i + 1, rs.size()):
			var a: Dictionary = rs[i]
			var b: Dictionary = rs[j]
			if not can_pact(s, a.id, b.id) or rand(s) > float(_pc("rivalChance", 0.25)): continue
			var tr: Array = pact_trades(s, a.id, b.id, 1)
			if tr.size(): make_pact(s, {"a": a.id, "b": b.id, "a_gets": tr[0].a_gets, "b_gets": tr[0].b_gets})
	for p in rs:
		if not can_pact(s, p.id, "player") or rand(s) > float(_pc("askChance", 0.1)): continue
		var tr: Array = pact_trades(s, p.id, "player", 1)
		if tr.is_empty(): continue
		var t: Dictionary = tr[0]
		var fill = {"short": p.short, "leader": p.leader, "x": district_by_id(t.a_gets).name, "y": district_by_id(t.b_gets).name,
			"xs": int(district_by_id(t.a_gets).seats), "ys": int(district_by_id(t.b_gets).seats)}
		var o: Dictionary = news("WORLD", "pact_offer", null, fill)
		s.queue.append({"type": "event", "event": {"id": "pact_offer", "kind": "opportunity", "deck": false, "source": "", "title": o.title, "text": o.text,
			"choices": [{"label": o.accept, "effects": {"pact": {"a": p.id, "b": "player", "a_gets": t.a_gets, "b_gets": t.b_gets}}},
				{"label": o.decline, "effects": {}}]}})
		break
