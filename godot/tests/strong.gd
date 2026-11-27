extends SceneTree
## A competent player, to measure difficulty: a fixed manifesto and tone, a trip every month
## to the province where it matters most, every action spent speaking for the manifesto,
## a sensible budget. Usage: -- <style> <seed> [flags]
##   style: populist | centrist | left | provocative (the populist manifesto, every line
##   provocative) | hopeful (a hopeful, mildly anti-system progressive) | switch (provocative for two years, then fiery) | timed (fiery, but
##   provocative in a hot debate when earlier outrage has worn off), or a way of playing:
##   right | wrong80 | wrong (the best or worst choices and wordings), only_<style> (one style all
##   game), alinni (Alinni first), appease (keep the rivals sweet, every pact), dirt (money only
##   for digging), dirtymoney (every offer taken) | cleanmoney (only public money)
## flags (comma-separated) switch parts off: notrips,nospeak,nobudget,nomoney,nooffices,noclaim;
## image: most of the budget on TV and social media (recognition and the leader's image)
const STYLES := {
	"populist": {"m": {"nation": 0, "system": 0, "society": 3, "order": 1, "economy": 1, "welfare": 1, "foreign": 1}, "tone": "fiery"},
	"centrist": {"m": {"nation": 2, "system": 3, "society": 2, "order": 2, "economy": 2, "welfare": 2, "foreign": 2}, "tone": "statesman"},
	"left": {"m": {"nation": 3, "system": 1, "society": 1, "order": 3, "economy": 0, "welfare": 0, "foreign": 3}, "tone": "folksy"},
	"provocative": {"m": {"nation": 0, "system": 0, "society": 3, "order": 1, "economy": 1, "welfare": 1, "foreign": 1}, "tone": "provocative"},
	"timed": {"m": {"nation": 0, "system": 0, "society": 3, "order": 1, "economy": 1, "welfare": 1, "foreign": 1}, "tone": "fiery", "timed": true},
	"hopeful": {"m": {"nation": 2, "system": 1, "society": 1, "order": 2, "economy": 1, "welfare": 1, "foreign": 2}, "tone": "hopeful"},
	# choosing well or badly (populist manifesto, any style): every best choice and wording; the worst
	# 80% of the time; the worst always
	"right": {"m": {"nation": 0, "system": 0, "society": 3, "order": 1, "economy": 1, "welfare": 1, "foreign": 1}, "tone": "fiery", "pick": "best"},
	"wrong80": {"m": {"nation": 0, "system": 0, "society": 3, "order": 1, "economy": 1, "welfare": 1, "foreign": 1}, "tone": "fiery", "pick": "worst", "p": 0.8},
	"wrong": {"m": {"nation": 0, "system": 0, "society": 3, "order": 1, "economy": 1, "welfare": 1, "foreign": 1}, "tone": "fiery", "pick": "worst", "p": 1.0},
	# one style all game, the same populist manifesto
	"only_measured": {"m": {"nation": 0, "system": 0, "society": 3, "order": 1, "economy": 1, "welfare": 1, "foreign": 1}, "tone": "statesman"},
	"only_fiery": {"m": {"nation": 0, "system": 0, "society": 3, "order": 1, "economy": 1, "welfare": 1, "foreign": 1}, "tone": "fiery"},
	"only_folksy": {"m": {"nation": 0, "system": 0, "society": 3, "order": 1, "economy": 1, "welfare": 1, "foreign": 1}, "tone": "folksy"},
	"only_hopeful": {"m": {"nation": 0, "system": 0, "society": 3, "order": 1, "economy": 1, "welfare": 1, "foreign": 1}, "tone": "hopeful"},
	# Alinni first: their positions, trips there for the first two years, choices that please them
	"alinni": {"m": {"nation": 4, "system": 1, "society": 2, "order": 3, "economy": 2, "welfare": 1, "foreign": 3}, "tone": "statesman", "alinni": true},
	# keep the other parties sweet: a moderate manifesto, choices that move you toward them, every pact going
	"appease": {"m": {"nation": 2, "system": 3, "society": 2, "order": 2, "economy": 2, "welfare": 2, "foreign": 2}, "tone": "statesman", "appease": true},
	# money only for digging: no budget, no offices; investigate every month and release what you find
	"dirt": {"m": {"nation": 0, "system": 0, "society": 3, "order": 1, "economy": 1, "welfare": 1, "foreign": 1}, "tone": "fiery", "dirt": true},
	# every offer of money taken, secret foreign money included; or only the clean, public ones
	"dirtymoney": {"m": {"nation": 0, "system": 0, "society": 3, "order": 1, "economy": 1, "welfare": 1, "foreign": 1}, "tone": "fiery", "money": "all"},
	"cleanmoney": {"m": {"nation": 0, "system": 0, "society": 3, "order": 1, "economy": 1, "welfare": 1, "foreign": 1}, "tone": "fiery", "money": "clean"},
	# one voice, played as well as possible: its natural manifesto, the best event choices; a line
	# that would be a gaffe is swapped for another voice ("v_"), and with "vv_" also a line in
	# another voice that would go viral (the test player looks ahead on a copy of the game)
	"v_measured": {"m": {"nation": 2, "system": 3, "society": 2, "order": 2, "economy": 2, "welfare": 2, "foreign": 2}, "tone": "statesman", "oracle": "gaffe"},
	"v_fiery": {"m": {"nation": 0, "system": 0, "society": 3, "order": 1, "economy": 1, "welfare": 1, "foreign": 1}, "tone": "fiery", "oracle": "gaffe"},
	"v_folksy": {"m": {"nation": 3, "system": 1, "society": 1, "order": 3, "economy": 0, "welfare": 0, "foreign": 3}, "tone": "folksy", "oracle": "gaffe"},
	"v_hopeful": {"m": {"nation": 2, "system": 1, "society": 1, "order": 2, "economy": 1, "welfare": 1, "foreign": 2}, "tone": "hopeful", "oracle": "gaffe"},
	"vv_measured": {"m": {"nation": 2, "system": 3, "society": 2, "order": 2, "economy": 2, "welfare": 2, "foreign": 2}, "tone": "statesman", "oracle": "viral"},
	"vv_fiery": {"m": {"nation": 0, "system": 0, "society": 3, "order": 1, "economy": 1, "welfare": 1, "foreign": 1}, "tone": "fiery", "oracle": "viral"},
	"vv_folksy": {"m": {"nation": 3, "system": 1, "society": 1, "order": 3, "economy": 0, "welfare": 0, "foreign": 3}, "tone": "folksy", "oracle": "viral"},
	"vv_hopeful": {"m": {"nation": 2, "system": 1, "society": 1, "order": 2, "economy": 1, "welfare": 1, "foreign": 2}, "tone": "hopeful", "oracle": "viral"},
	# the designer's way: a fiery populist, hawkish nationalist and statist but for welfare and civil
	# liberties; Erland and Fauran first, then Yamlin and Cranbia ("_greedy": trips to the best close race)
	"ozan": {"m": {"nation": 1, "system": 1, "society": 2, "order": 3, "economy": 1, "welfare": 1, "foreign": 1}, "tone": "fiery", "phase": true},
	"ozan_greedy": {"m": {"nation": 1, "system": 1, "society": 2, "order": 3, "economy": 1, "welfare": 1, "foreign": 1}, "tone": "fiery"},
	# the same game, the words chosen well or at random: how much the wording is worth
	"wb_populist": {"m": {"nation": 0, "system": 0, "society": 3, "order": 1, "economy": 1, "welfare": 1, "foreign": 1}, "tone": "fiery", "pick": "best"},
	"wr_populist": {"m": {"nation": 0, "system": 0, "society": 3, "order": 1, "economy": 1, "welfare": 1, "foreign": 1}, "tone": "fiery", "pick": "random"},
	"wb_centrist": {"m": {"nation": 2, "system": 3, "society": 2, "order": 2, "economy": 2, "welfare": 2, "foreign": 2}, "tone": "statesman", "pick": "best"},
	"wr_centrist": {"m": {"nation": 2, "system": 3, "society": 2, "order": 2, "economy": 2, "welfare": 2, "foreign": 2}, "tone": "statesman", "pick": "random"},
	"switch": {"m": {"nation": 0, "system": 0, "society": 3, "order": 1, "economy": 1, "welfare": 1, "foreign": 1}, "tone": "provocative", "then": "fiery", "at": 96},
}
var G
var tone = "fiery"
var off = {}
var ST: Dictionary = {}
var rng := RandomNumberGenerator.new()
var _share_cache = {}
var dirty_taken = 0
var released = 0
var dug = 0
var pacts_made = 0

## How much of the electorate a "who" covers (0..1).
func _share(s: Dictionary, who) -> float:
	var k: String = JSON.stringify(who)
	if _share_cache.has(k): return _share_cache[k]
	var a = 0.0
	var t = 0.0
	for pop in s.pops:
		t += pop.size
		if G.matches(pop, who): a += pop.size
	_share_cache[k] = a / maxf(1, t)
	return _share_cache[k]

## What a line should earn, roughly: its style's reactions (half, plus the provocative ones,
## for a sharp line) and its own, weighted by how many voters they reach, less its risk.
func line_score(s: Dictionary, line: Dictionary) -> float:
	var st: String = G.line_style(line)
	var reacts: Array = G.TONES[st].react.duplicate()
	if G.line_sharp(line):
		reacts = reacts.map(func(g): return {"who": g.who, "amt": float(g.amt) * 0.5})
		reacts.append_array(G.TONES.get("provocative", {}).get("react", []))
	reacts.append_array(line.get("react", []))
	var v = 0.0
	for g in reacts: v += float(g.amt) * _share(s, g.who)
	var risk = line.get("risk")
	if risk == null: risk = G.TONE_RISK.get("provocative" if G.line_sharp(line) else st, 0.2)
	return v * (1.0 - G.unheard_chance(float(risk))) - float(risk) * 0.03

## Choosing well or badly this time?
func _bad() -> bool:
	return ST.get("pick", "") == "worst" and rng.randf() < float(ST.get("p", 1.0))

## The looking-ahead player: `try` plays line j on a copy of the game and returns its outcome
## ("viral", "normal", "gaffe"). Own voice first, a line in it going viral if one would; a
## gaffe is swapped for the best other line that isn't one; with "viral", another voice's
## line that would go viral beats an ordinary line in your own.
var swaps = {"gaffe": 0, "viral": 0}
func oracle_line(s: Dictionary, lines: Array, try: Callable) -> int:
	var mine = []
	var other = []
	for i in lines.size():
		var l: Dictionary = lines[i]
		if float(l.get("risk", 0.3)) <= 0.1 and l.get("react", []).any(func(g): return g.who is Dictionary and g.who.is_empty() and float(g.amt) < 0): continue   # the dull, evasive ones
		(mine if G.line_style(l) == tone and not G.line_sharp(l) else other).append(i)
	var outc = {}
	for i in mine + other: outc[i] = try.call(s.duplicate(true), i)
	var by_score = func(xs: Array) -> Array: return G.ssort(xs, func(a, b): return line_score(s, lines[b]) - line_score(s, lines[a]))
	mine = by_score.call(mine)
	other = by_score.call(other)
	for i in mine:
		if outc[i] == "viral": return i
	if ST.oracle == "viral":
		for i in other:
			if outc[i] == "viral": swaps.viral += 1; return i
	for i in mine:
		if outc[i] != "gaffe": return i
	for i in other:
		if outc[i] != "gaffe":
			if mine.size(): swaps.gaffe += 1
			return i
	return mine[0] if mine.size() else (other[0] if other.size() else 0)

func pick_line(s: Dictionary, lines: Array) -> int:
	if lines.is_empty(): return -1
	if ST.get("pick", "") == "":
		return line_of(lines)
	if ST.pick == "random": return rng.randi() % lines.size()
	var bad: bool = _bad()
	var best = 0
	var bv = INF if bad else -INF
	for i in lines.size():
		var v: float = line_score(s, lines[i])
		if (bad and v < bv) or (not bad and v > bv): bv = v; best = i
	return best

func line_of(lines: Array) -> int:
	# "provocative" means a sharp line in any style (a fiery one if there is one)
	var best = -1
	for i in lines.size():
		var l: Dictionary = lines[i]
		if l.get("gaffe", false) or float(l.get("risk", 0)) >= 0.9: continue
		var sharp: bool = G.line_sharp(l)
		if tone == "provocative":
			if sharp and (best < 0 or G.line_style(l) == "fiery"): best = i
		elif not sharp and G.line_style(l) == tone: return i
	return best if best >= 0 else 0

func side_for(s: Dictionary, axis: String) -> String:
	var m = G.manifesto_side(s, axis)
	return m

func best_choice(s: Dictionary, ev: Dictionary) -> int:
	var man: Dictionary = G.player_party(s).manifesto
	var bad: bool = _bad()
	var best = 0
	var bv = 1e9 if bad else -1e9
	for i in ev.choices.size():
		var fx: Dictionary = ev.choices[i].effects
		var v = 0.0
		for ax in fx.get("shift", {}): v += float(fx.shift[ax]) * signf(float(man.get(ax, 0))) if absf(float(man.get(ax, 0))) > 15 else -absf(float(fx.shift[ax])) * 0.3
		for g in fx.get("goodwill", []): v += float(g.amt) * 4
		if fx.has("secretAnswer"): v = {"deny": 1, "attack": 3, "own": 2}.get(fx.secretAnswer.how, 0)
		if fx.has("violence"): v = {"condemn": 2, "allsides": 3, "understand": 0}.get(fx.violence.how, 0)
		if ST.has("alinni"):
			for g in fx.get("goodwill", []):
				var w = g.who
				if w is Dictionary and (w.get("nationality", "") == "alinnian" or w.get("region", "") == "alinni"): v += float(g.amt) * 12
		if ST.has("appease"):   # stay close to where the other parties stand; blame nobody
			var rv: Array = G.rivals(s)
			for ax in fx.get("shift", {}):
				var mean = 0.0
				for p in rv: mean += float(p.perceived[ax])
				mean /= maxf(1, rv.size())
				var me: float = float(G.player_party(s).perceived[ax])
				v += (absf(me - mean) - absf(me + float(fx.shift[ax]) - mean)) * 0.2
			if fx.has("blame"): v -= 5
		if (bad and v < bv) or (not bad and v > bv): bv = v; best = i
	return best

func _init() -> void:
	var args = OS.get_cmdline_user_args()
	var style: String = args[0] if args.size() else "populist"
	var seed_n: int = int(args[1]) if args.size() > 1 else 1
	if args.size() > 2:
		for f in args[2].split(","): off[f] = true
	G = load("res://scripts/sim.gd").new()
	ST = STYLES[style]
	rng.seed = seed_n * 7919
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
					var li: int = pick_line(s, lines) if lines.size() else -1
					if ST.has("oracle") and lines.size():
						li = oracle_line(s, lines, func(c, j): return String(G.resolve_event(c, ci, j).get("delivery", {}).get("outcome", "normal")))
					G.resolve_event(s, ci, li)
					if off.has("trace") and s.week >= 136 and s.week <= 150: print("  EVENT w%d %s [%s] -> %s: %.1f -> %.1f" % [s.week, ev.title, ev.get("kind", ""), ev.choices[ci].label, b4 * 100, G.summarize(s, s.pops).support.player * 100])
				"budget":
					var take = [] if off.has("nomoney") else f.offers.filter(func(id): return id in ["chamber", "union", "tycoon"])
					if ST.get("money", "") == "all": take = f.offers.duplicate()
					elif ST.get("money", "") == "clean": take = f.offers.filter(func(id): return id in ["chamber", "union"])
					for id in take:
						if G.by_id(G.FUNDING_OFFERS, id).effects.has("scandal"): dirty_taken += 1
					var extra = 0.0
					for id in take: extra += float(G.by_id(G.FUNDING_OFFERS, id).effects.get("money", 0))
					var m: float = (s.money + extra) * 0.75
					var b5 = G.summarize(s, s.pops).support.player if off.has("trace") else 0.0
					var plan = {"road": m * 0.35, "social": m * 0.35, "tv": m * 0.3}
					if off.has("image"): plan = {"road": m * 0.1, "social": m * 0.45, "tv": m * 0.45}
					G.resolve_budget(s, {} if (off.has("nobudget") or ST.has("dirt")) else plan, take)
					if off.has("trace") and s.week >= 136 and s.week <= 150: print("  BUDGET w%d spent of %.1f, took %s: %.1f -> %.1f" % [s.week, m, str(take), b5 * 100, G.summarize(s, s.pops).support.player * 100])
				"debate":
					var dl: Array = s.debate.rounds[s.debate.step].lines
					var dj: int = pick_line(s, dl)
					if ST.has("oracle"): dj = oracle_line(s, dl, func(c, j): return String(G.answer_debate(c, j).get("outcome", "normal")))
					G.answer_debate(s, dj)
				"interview":
					var rd: Dictionary = s.interview.rounds[s.interview.step]
					var pick = 0
					if _bad():
						for i in rd.lines.size():
							if rd.lines[i].get("kind", "") in ["dodge", "deny", "deflect"]: pick = i; break
					else:
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
				if d.region == "alinni" and not ST.has("alinni"): continue
				if ST.has("alinni") and s.week < 96 and d.region != "alinni": continue
				if ST.has("phase") and s.week < 96 and not (d.region in ["erland", "fauraifai"]): continue
				if ST.has("phase") and s.week >= 96 and not (d.region in ["yamlin", "cranbia"]): continue
				var v: float = float(d.seats) * maxf(0.02, 0.2 - gap) / (1.0 + 0.3 * int(s.districts[d.id].visits))
				if v > bv: bv = v; best = d.id
			if best != "": G.act_visit(s, best)
		var guard = 0
		while s.actionsLeft > 0 and guard < 6 and s.queue.is_empty():
			guard += 1
			var did = false
			if ST.has("dirt"):
				for i in s.dossiers.size():
					if G.act_release(s, i).get("ok", false): did = true; released += 1; break
				if not did and s.money >= float(G.ACTIONS.research.cost):
					var tgt = G.ssort(G.rivals(s), func(a, b): return float(s.lastSupport.get(b.id, 0) if s.lastSupport else 0) - float(s.lastSupport.get(a.id, 0) if s.lastSupport else 0))[0]
					if G.act_research(s, tgt.id).ok: did = true; dug += 1
			if not did and ST.has("appease") and G.in_campaign(s):
				for p in G.rivals(s):
					var offs: Array = G.pact_offers(s, p.id)
					if offs.size() and G.act_pact(s, p.id, offs[0].you_get, offs[0].they_get).ok: did = true; pacts_made += 1; break
			if not did and not off.has("nospeak"):
				var ds: Array = G.ssort(s.debates.duplicate(), func(a, b): return b.heat - a.heat)
				for d in ds:
					var side = side_for(s, d.axis)
					if d.has("you") or side == "": continue
					var lines: Array = G.debate_lines(s, d, side)
					if lines.is_empty(): continue
					var keep = tone
					if STYLES[style].has("timed") and d.heat >= 38 and float(s.get("outrage", 0)) < 0.6: tone = "provocative"
					var sj: int = pick_line(s, lines)
					if ST.has("oracle") and G.is_major(d):
						var did_id: String = d.id
						sj = oracle_line(s, lines, func(c, j): return String(G.act_speak(c, did_id, side, j).get("delivery", {}).get("outcome", "normal")))
					var r = G.act_speak(s, d.id, side, sj)
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
						var rj: int = pick_line(s, lines)
						if ST.has("oracle"):
							var o2: Dictionary = opt
							rj = oracle_line(s, lines, func(c, j): return String(G.act_raise(c, o2, side, j).get("delivery", {}).get("outcome", "normal")))
						var r = G.act_raise(s, opt, side, rj)
						if r.ok: did = true; break
			if not did and not off.has("nooffices") and not ST.has("dirt") and s.money > 4:
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
	var rels = []
	for p in G.rivals(s): rels.append("%s %d" % [p.short, int(G.relation(s, p.id))])
	# your share of the vote in Alinni's provinces, as projected at the end
	var alv = 0.0
	var alt = 0.0
	for d in G.DISTRICTS:
		if d.region != "alinni": continue
		var x: Dictionary = s.get("projection", {}).get(d.id, {})
		for k in x.get("votes", {}): alt += float(x.votes[k])
		alv += float(x.get("votes", {}).get("player", 0))
	var visits = {}
	for d in G.DISTRICTS:
		var n: int = int(s.districts[d.id].get("visits", 0))
		if n: visits[d.region] = int(visits.get(d.region, 0)) + n
	var regshare = []
	for d in ["cranbia", "yamlin", "erland", "fauraifai", "alinni"]:
		var v = 0.0
		var tt = 0.0
		for dd in G.DISTRICTS:
			if dd.region != d: continue
			var x: Dictionary = s.get("projection", {}).get(dd.id, {})
			for k in x.get("votes", {}): tt += float(x.votes[k])
			v += float(x.get("votes", {}).get("player", 0))
		regshare.append("%s %.0f%%" % [d.substr(0, 4), v / maxf(1, tt) * 100])
	var top = G.ssort(G.DISTRICTS.filter(func(d): return int(s.districts[d.id].get("visits", 0)) > 0), func(a, b): return int(s.districts[b.id].visits) - int(s.districts[a.id].visits)).slice(0, 4).map(func(d): return "%s %d" % [d.name, int(s.districts[d.id].visits)])
	print("TRIPS %s seed %d | by region %s | most visited %s | your vote by region %s" % [style, seed_n, str(visits), ", ".join(top), " ".join(regshare)])
	if ST.has("oracle"): print("SWAPS %s seed %d gaffes dodged %d, viral swaps %d" % [style, seed_n, swaps.gaffe, swaps.viral])
	print("EXTRA %s seed %d | Alinni vote %.1f%% | relations: %s | pacts %d (all: %d) | dirty money taken %d, leaked %s | dug %d, released %d" % [style, seed_n, alv / maxf(1, alt) * 100, ", ".join(rels), pacts_made, s.get("pacts", []).size() / 2,
		dirty_taken, "%d (any scandal leaked: %d)" % [s.get("secrets", []).filter(func(x): return x.get("kind", "") == "money" and x.get("leaked", false)).size(), s.get("secrets", []).filter(func(x): return x.get("leaked", false)).size()], dug, released])
	print("RESULT %s seed %d %s: you %.1f%% of the vote, %d of %d seats, rank %d%s | by year %s | gaffes %d viral %d | charisma %d | trust %d" % [style, seed_n, ",".join(off.keys()),
		r.votes.player * 100, r.seats.national.player, int(G.C.seats), r.ranking.find("player") + 1, " MAJORITY" if r.majority else "", " ".join(track), s.record.gaffes, s.record.memes, int(G.player_party(s).charisma), int(s.trust)])
	quit()
