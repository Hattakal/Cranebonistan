extends SceneTree
## A competent player, to measure difficulty: a fixed manifesto and tone, a trip every month
## to the province where it matters most, every action spent speaking for the manifesto,
## a sensible budget. Usage: -- <style> <seed> [flags]
##   style: populist | centrist | left | provocative (the populist manifesto, every line
##   provocative) | switch (provocative for two years, then fiery) | timed (fiery, but
##   provocative in a hot debate when earlier outrage has worn off)
## flags (comma-separated) switch parts off: notrips,nospeak,nobudget,nomoney,nooffices,noclaim;
## image: most of the budget on TV and social media (recognition and the leader's image)
const STYLES := {
	"populist": {"m": {"nation": 0, "system": 0, "society": 3, "order": 1, "economy": 1, "welfare": 1, "foreign": 1}, "tone": "fiery"},
	"centrist": {"m": {"nation": 2, "system": 3, "society": 2, "order": 2, "economy": 2, "welfare": 2, "foreign": 2}, "tone": "statesman"},
	"left": {"m": {"nation": 3, "system": 1, "society": 1, "order": 3, "economy": 0, "welfare": 0, "foreign": 3}, "tone": "folksy"},
	"provocative": {"m": {"nation": 0, "system": 0, "society": 3, "order": 1, "economy": 1, "welfare": 1, "foreign": 1}, "tone": "provocative"},
	"timed": {"m": {"nation": 0, "system": 0, "society": 3, "order": 1, "economy": 1, "welfare": 1, "foreign": 1}, "tone": "fiery", "timed": true},
	"switch": {"m": {"nation": 0, "system": 0, "society": 3, "order": 1, "economy": 1, "welfare": 1, "foreign": 1}, "tone": "provocative", "then": "fiery", "at": 96},
}
var G
var tone = "fiery"
var off = {}

func line_of(lines: Array) -> int:
	for i in lines.size():
		if lines[i].get("tone", "") == tone and not lines[i].get("gaffe", false) and float(lines[i].get("risk", 0)) < 0.9: return i
	return 0

func side_for(s: Dictionary, axis: String) -> String:
	var m = G.manifesto_side(s, axis)
	return m

func best_choice(s: Dictionary, ev: Dictionary) -> int:
	var man: Dictionary = G.player_party(s).manifesto
	var best = 0
	var bv = -1e9
	for i in ev.choices.size():
		var fx: Dictionary = ev.choices[i].effects
		var v = 0.0
		for ax in fx.get("shift", {}): v += float(fx.shift[ax]) * signf(float(man.get(ax, 0))) if absf(float(man.get(ax, 0))) > 15 else -absf(float(fx.shift[ax])) * 0.3
		for g in fx.get("goodwill", []): v += float(g.amt) * 4
		if fx.has("secretAnswer"): v = {"deny": 1, "attack": 3, "own": 2}.get(fx.secretAnswer.how, 0)
		if fx.has("violence"): v = {"condemn": 2, "allsides": 3, "understand": 0}.get(fx.violence.how, 0)
		if v > bv: bv = v; best = i
	return best

func _init() -> void:
	var args = OS.get_cmdline_user_args()
	var style: String = args[0] if args.size() else "populist"
	var seed_n: int = int(args[1]) if args.size() > 1 else 1
	if args.size() > 2:
		for f in args[2].split(","): off[f] = true
	G = load("res://scripts/sim.gd").new()
	tone = STYLES[style].tone
	var s: Dictionary = G.new_game({"seed": seed_n, "partyName": "Test", "home": "Bayernal", "manifesto": STYLES[style].m})
	var track = []
	while s.result == null:
		if s.queue.size():
			var f: Dictionary = s.queue[0]
			match f.type:
				"event":
					var ev: Dictionary = G.event_of(f)
					var ci = best_choice(s, ev)
					var lines: Array = ev.choices[ci].get("lines", [])
					var b4 = G.summarize(s, s.pops).support.player if off.has("trace") else 0.0
					G.resolve_event(s, ci, line_of(lines) if lines.size() else -1)
					if off.has("trace") and s.week >= 136 and s.week <= 150: print("  EVENT w%d %s [%s] -> %s: %.1f -> %.1f" % [s.week, ev.title, ev.get("kind", ""), ev.choices[ci].label, b4 * 100, G.summarize(s, s.pops).support.player * 100])
				"budget":
					var take = [] if off.has("nomoney") else f.offers.filter(func(id): return id in ["chamber", "union", "tycoon"])
					var extra = 0.0
					for id in take: extra += float(G.by_id(G.FUNDING_OFFERS, id).effects.get("money", 0))
					var m: float = (s.money + extra) * 0.75
					var b5 = G.summarize(s, s.pops).support.player if off.has("trace") else 0.0
					var plan = {"road": m * 0.35, "social": m * 0.35, "tv": m * 0.3}
					if off.has("image"): plan = {"road": m * 0.1, "social": m * 0.45, "tv": m * 0.45}
					G.resolve_budget(s, {} if off.has("nobudget") else plan, take)
					if off.has("trace") and s.week >= 136 and s.week <= 150: print("  BUDGET w%d spent of %.1f, took %s: %.1f -> %.1f" % [s.week, m, str(take), b5 * 100, G.summarize(s, s.pops).support.player * 100])
				"debate": G.answer_debate(s, line_of(s.debate.rounds[s.debate.step].lines))
				"interview":
					var rd: Dictionary = s.interview.rounds[s.interview.step]
					var pick = 0
					for i in rd.lines.size():
						if rd.lines[i].get("kind", "") in ["clear", "own"] or (rd.lines[i].get("kind", "") == "style" and rd.lines[i].tone == tone): pick = i; break
					G.answer_interview(s, pick)
				"election": break
				_: G.dismiss_front(s)
			continue
		if STYLES[style].has("then") and s.week >= int(STYLES[style].at): tone = STYLES[style].then
		# a free month: trip, then actions
		if not off.has("notrips") and G.visit_block(s) == "" and s.get("projection", {}).size():
			var best = ""
			var bv = -1.0
			for d in G.DISTRICTS:
				var x: Dictionary = s.projection[d.id]
				var gap: float = (float(x.share) - float(x.you)) if x.winner != "player" else float(x.margin)
				if d.region == "alinni": continue
				var v: float = float(d.seats) * maxf(0.02, 0.2 - gap) / (1.0 + 0.3 * int(s.districts[d.id].visits))
				if v > bv: bv = v; best = d.id
			if best != "": G.act_visit(s, best)
		var guard = 0
		while s.actionsLeft > 0 and guard < 6 and s.queue.is_empty():
			guard += 1
			var did = false
			if not off.has("nospeak"):
				var ds: Array = G.ssort(s.debates.duplicate(), func(a, b): return b.heat - a.heat)
				for d in ds:
					var side = side_for(s, d.axis)
					if d.has("you") or side == "": continue
					var lines: Array = G.debate_lines(s, d, side)
					if lines.is_empty(): continue
					var keep = tone
					if STYLES[style].has("timed") and d.heat >= 38 and float(s.get("outrage", 0)) < 0.6: tone = "provocative"
					var r = G.act_speak(s, d.id, side, line_of(lines))
					tone = keep
					if r.ok:
						did = true
						if not off.has("noclaim") and G.claim_block(s, d.axis, side) == "": G.act_claim(s, d.axis, side)
						break
				if not did:
					for opt in G.raise_options(s):
						var side = side_for(s, opt.axis) if str(opt.get("side", "")) == "" else str(opt.side)
						if side == "" or side != G.manifesto_side(s, opt.axis): continue
						var lines: Array = G.raise_lines(s, opt, side)
						if lines.is_empty(): continue
						var r = G.act_raise(s, opt, side, line_of(lines))
						if r.ok: did = true; break
			if not did and not off.has("nooffices") and s.money > 4:
				for c in G.MAP.cities:
					if c.area in ["erland", "fauraifai", "cranbia"] and G.community_level(s, c.name) < G.COMMUNITY_MAX and s.money >= G.COMMUNITY_COST[G.community_level(s, c.name)] + 2:
						if G.act_community(s, c.name).ok: did = true; break
			if not did: break
		if s.week % 24 == 0 and s.lastSupport: track.append("%d%%" % int(s.lastSupport.player * 100))
		if off.has("trace") and s.week >= 136 and s.week <= 152 and s.week % 4 == 0 and s.lastSupport:
			var sm = G.summarize(s, s.pops)
			var gw = 0.0
			var ld = 0.0
			var tot = 0.0
			for p in s.pops:
				gw += p.size * p.goodwill.player; ld += p.size * p.leader.player; tot += p.size
			var own = ""
			for row in G.ownership_table(s):
				for o in row.owners:
					if o.party == "player": own += "%s %.2f " % [row.label, o.value if o.has("value") else 0.0]
			print("  m%d sup %.1f aware %.2f goodwill %.3f leader %.3f charisma %d trust %d crisis %s salMod %s | %s" % [s.week / 4, sm.support.player * 100, sm.aware, gw / tot, ld / tot, int(G.player_party(s).charisma), int(s.trust), str(s.crisis.id if s.crisis else "-"), str(s.salMod).substr(0, 90), own])
		G.advance_week(s)
	var r: Dictionary = s.result
	print("RESULT %s seed %d %s: you %.1f%% of the vote, %d of %d seats, rank %d%s | by year %s | gaffes %d viral %d | charisma %d | trust %d" % [style, seed_n, ",".join(off.keys()),
		r.votes.player * 100, r.seats.national.player, int(G.C.seats), r.ranking.find("player") + 1, " MAJORITY" if r.majority else "", " ".join(track), s.record.gaffes, s.record.memes, int(G.player_party(s).charisma), int(s.trust)])
	quit()
