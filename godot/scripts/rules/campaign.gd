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
	for pid in s.get("rivalConvoys", {}):
		var p = party_of(s, pid)
		var r: Array = s.rivalConvoys[pid]
		if p and i < r.size(): rival_visit(s, p, district_by_id(r[i]), float(C.campaign.rally))
