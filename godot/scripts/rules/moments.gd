## rules/moments.gd — The big moments: the year-three flagship promise, the year-one interview, the final debate and the end-of-game profile.
extends "res://scripts/rules/laws.gd"

# ---------- The flagship promise (year three) ----------
## A year before the election the party commits to one tangible answer for the
## country's biggest issue: which promise, then the exact words. Afterwards the
## party owns that side of the issue, the issue stays in the news, and the
## promise keeps rallying the voters who like it, month after month.
func flagship_week() -> int:
	return 3 * WEEKS_PER_YEAR

## The issue the country cares most about now: how much voters care about it
## (a crisis raises that on its issues), plus how bad its numbers are.
func flagship_issue(s: Dictionary) -> Dictionary:
	var nation: Dictionary = summarize(s, s.pops)
	var best: Dictionary = FLAGSHIP[0]
	var best_score = -INF
	for it in FLAGSHIP:
		var sc: float = float(nation.sal[it.axis])
		for m in it.metrics: sc += metric_badness(s, m) * 0.8
		if sc > best_score:
			best_score = sc; best = it
	return best

func flagship_event(s: Dictionary) -> Dictionary:
	var it: Dictionary = flagship_issue(s)
	var choices: Array = it.promises.duplicate(true)
	for ch in choices: ch.lines = shuffle(s, ch.lines)   # so the plain bad one isn't always last
	return {"id": "flagship_" + it.id, "kind": "flagship", "flagship": it.id, "title": it.title, "text": it.text, "choices": choices}

## Every month until the election, the promise keeps its voters warm.
func flagship_monthly(s: Dictionary) -> void:
	var f = s.get("flagship")
	if f == null or typeof(f) != TYPE_DICTIONARY or f.is_empty(): return
	var sg = -1.0 if f.side == "L" else 1.0
	var k: float = moment_weight(s)
	for pop in s.pops:
		if sg * float(pop.pos[f.axis]) > 20: pop.goodwill.player = clampf2(pop.goodwill.player + 0.01 * k * minf(1.5, pop.sal[f.axis]), -2, 2)

# ---------- The final debate ----------
func debate_rounds(s: Dictionary) -> Array:
	var player = player_party(s)
	var rival: Dictionary = ssort(rivals(s), func(a, b): return float(s.lastSupport.get(b.id, 0)) - float(s.lastSupport.get(a.id, 0)))[0]
	var cons = contradictions(s)
	var con = cons[0] if cons.size() else null
	var blamed = s.record.blamed[0] if s.record.blamed.size() else null
	var dirty = null
	for m in s.record.money:
		if m.dirty: dirty = m; break
	var F: Dictionary = FINAL_DEBATE
	var fill = {"leader": player.leader, "party": player.name, "rival": rival.leader, "rival_party": rival.short, "rival_id": rival.id}
	if con: fill.merge({"first_date": date_label(con.first.week, false), "first": con.first.text, "second_date": date_label(con.second.week, false), "second": con.second.text})
	if blamed: fill.group = blamed.group
	var atk: Dictionary = F.ATTACK.attacks
	fill.attack = String(atk.contradiction if con else (atk.blamed if blamed else (atk.money if dirty else atk.default))).format(fill)
	var lines_of = func(round: Dictionary) -> Array:
		return round.lines.map(func(l):
			var x: Dictionary = l.duplicate(true)
			x.text = String(l.text).format(fill)
			for r in x.get("react", []):
				for k in r.get("who", {}):
					if r.who[k] is String: r.who[k] = String(r.who[k]).format(fill)
			return x)
	return [
		{"title": String(F.OPENING.title).format(fill), "prompt": String(F.OPENING.prompt).format(fill), "lines": lines_of.call(F.OPENING)},
		{"title": String(F.ATTACK.title).format(fill), "prompt": String(F.ATTACK.prompt).format(fill), "rival": rival.id,
			"hurt": F.ATTACK.get("hurt", []) if (con or blamed or dirty) else [], "lines": lines_of.call(F.ATTACK)},
		{"title": String(F.CLOSING.title).format(fill), "prompt": String(F.CLOSING.prompt).format(fill), "lines": lines_of.call(F.CLOSING)},
	]

func start_debate(s: Dictionary) -> void:
	s.debate = {"rounds": debate_rounds(s), "step": 0, "results": []}
	s.queue.append({"type": "debate"})

func answer_debate(s: Dictionary, line_index: int) -> Dictionary:
	var d: Dictionary = s.debate
	var round: Dictionary = d.rounds[d.step]
	var line: Dictionary = round.lines[line_index]
	var before = snapshot_groups(s)
	if round.get("hurt", []).size(): apply_effects(s, {"goodwill": round.hurt, "awareness": 0})
	var react: Array = line.get("react", []).duplicate()
	react.append_array(TONES[line.tone].react)
	var k: float = moment_weight(s)   # a party nobody takes seriously is heard by fewer people
	react = react.map(func(g): return merged(g, {"amt": float(g.amt) * k}))
	var res = deliver_line(s, merged(line, {"react": react}))
	apply_effects(s, {"awareness": 0.04})
	var text: String = line.text
	if text.begins_with("\""): text = text.substr(1)
	if text.ends_with("\""): text = text.substr(0, text.length() - 1)
	record_statement(s, {"text": text, "title": "The final debate", "tone": line.tone, "spoken": true})
	var result = merged(res, {"quote": line.text, "changes": group_changes(s, before), "round": round.title})
	d.results.append(result)
	d.step += 1
	if d.step >= d.rounds.size(): finish_front(s, "debate")
	return result

# ---------- The big interview (year one) ----------
## The country meets the leader: an hour with the most trusted outlet. Questions
## come from your manifesto and your record (data/interview.json); dodging or
## answering against your own manifesto costs you, plain answers in your own
## voice pay. The interviewer is impartial, so there is no friend to lean on.
func interview_week() -> int:
	return int(INTERVIEW.get("MONTH", 8)) * WEEKS_PER_MONTH

func interview_outlet(s: Dictionary) -> Dictionary:
	var best = OUTLETS[0] if OUTLETS.size() else {"id": "cbc", "name": "CBC"}
	var bv = -1.0
	for o in OUTLETS:
		if not (o.kind in ["public", "paper", "business", "regional"]): continue
		if float(o.get("honesty", 0)) < 0.7 or s.media[o.id].owner != "": continue
		var v: float = float(o.honesty) * (0.1 + float(s.media[o.id].get("reachNat", 0)))
		if v > bv: bv = v; best = o
	return best

func _iv_fill(text: String, fill: Dictionary) -> String:
	return text.format(fill)

func _iv_issue(s: Dictionary, q: Dictionary, ax: Dictionary, fill: Dictionary) -> Dictionary:
	var player = player_party(s)
	var side: String = manifesto_side(s, ax.id)
	var f = fill.duplicate()
	f.issue = String(ax.issue).to_lower()
	f.stance = stance_name(ax.id, stance_of(player.manifesto[ax.id])).to_lower()
	var quote = func(l: Dictionary, kind: String, sd: String) -> Dictionary:
		var t: String = String(l.text)
		if not t.begins_with("\""): t = "\"" + t + "\""
		return {"tone": l.tone, "text": t, "kind": kind, "side": sd}
	var lines = []
	# your own line, said in different voices (one each, never the dull or the sharp ones), and
	# a measured dodge: the interview tests whether you stand by your manifesto
	var sides: Array = [side] if side != "" else ["L", "R"]   # a manifesto in the middle can lean either way
	var seen = {}
	for sd in sides:
		for l in shuffle(s, LINES.AXIS_LINES[ax.id][sd]):
			var st: String = line_style(l)
			if line_sharp(l) or seen.has(st) or float(l.get("risk", 0.3)) <= 0.1: continue
			seen[st] = true
			lines.append(quote.call(l, "clear", sd))
	lines = lines.slice(0, 3)
	var dg: Dictionary = pick(s, INTERVIEW.DODGES)
	lines.append({"tone": dg.tone, "text": dg.text, "kind": "dodge", "side": "", "axisName": String(ax.issue).to_lower()})
	return {"title": q.title, "prompt": _iv_fill(q.prompt, f), "axis": ax.id, "lines": shuffle(s, lines)}

func start_interview(s: Dictionary) -> void:
	var o: Dictionary = interview_outlet(s)
	var who: String = INTERVIEW.get("INTERVIEWERS", {}).get(o.id, "The interviewer")
	var player = player_party(s)
	var fill = {"interviewer": who, "leader": player.leader, "party": player.name, "home": s.get("home", "")}
	var rounds = []
	var op: Dictionary = INTERVIEW.OPENING
	rounds.append({"title": op.title, "prompt": _iv_fill(op.prompt, fill), "axis": "", "lines": op.lines.map(func(l): return merged(l, {"kind": "style", "side": ""}))})
	var axes: Array = ssort(AXES.duplicate(), func(a, b): return absf(float(player.manifesto[b.id])) - absf(float(player.manifesto[a.id])))
	var sal: Dictionary = summarize(s, s.pops).sal
	var big = null
	for ax in ssort(AXES.duplicate(), func(a, b): return float(sal[b.id]) - float(sal[a.id])):
		if ax.id != axes[0].id and ax.id != axes[1].id: big = ax; break
	rounds.append(_iv_issue(s, INTERVIEW.BOLD, axes[0], fill))
	if big: rounds.append(_iv_issue(s, INTERVIEW.BIG, big, fill))
	rounds.append(_iv_issue(s, INTERVIEW.SECOND, axes[1], fill))
	# the record: a U-turn on file, dirty money, or the years as mayor
	var rq = null
	var f2 = fill.duplicate()
	var cons = contradictions(s)
	var dirty: Array = s.record.money.filter(func(m): return m.dirty)
	if cons.size():
		rq = INTERVIEW.RECORD_FLIP
		f2.first = "\"%s\"" % cons[0].first.text
		f2.second = "\"%s\"" % cons[0].second.text
		f2.first_date = date_label(cons[0].first.week)
		f2.second_date = date_label(cons[0].second.week)
	elif dirty.size():
		rq = INTERVIEW.RECORD_MONEY
		f2.source = dirty[0].source
	elif s.get("home", "") != "":
		rq = INTERVIEW.RECORD_HOME
	if rq:
		rounds.append({"title": rq.title, "prompt": _iv_fill(rq.prompt, f2), "axis": "",
			"lines": rq.lines.map(func(l): return merged(l, {"text": _iv_fill(l.text, f2), "side": ""}))})
	s.interview = {"outlet": o.id, "outletName": o.name, "who": who, "rounds": rounds, "step": 0, "results": [], "score": 0, "verdict": null}
	s.queue.append({"type": "interview"})

func answer_interview(s: Dictionary, line_index: int) -> Dictionary:
	var iv: Dictionary = s.interview
	var rd: Dictionary = iv.rounds[iv.step]
	var line: Dictionary = rd.lines[line_index]
	var before = snapshot_groups(s)
	var res = deliver_line(s, line)
	var kind: String = line.get("kind", "style")
	var note = ""
	var d = 0
	match kind:
		"clear":
			d = 1
			var sg = -1.0 if line.side == "L" else 1.0
			shift_perceived(s, {rd.axis: sg * 4})
			s.spoke[side_key(rd.axis, line.side)] = s.week
			figures_heard(s, rd.axis, line.side)
			for pop in s.pops:
				var p: float = pop.pos[rd.axis]
				if (line.side == "L" and p < -15) or (line.side == "R" and p > 15):
					pop.goodwill.player = clampf2(pop.goodwill.player + 0.05 * pop.sal[rd.axis], -2, 2)
			note = "A straight answer. Whatever people made of it, they knew where you stood."
		"uturn":
			d = -1
			shift_perceived(s, {rd.axis: (-6.0 if line.side == "L" else 6.0)})
			figures_heard(s, rd.axis, line.side)
			note = "Against your own manifesto, live on air. The clip will be played back for years."
		"dodge":
			d = -1
			for o in OUTLETS: s.media[o.id].buzz = clampf2(float(s.media[o.id].buzz) - 0.15 * float(o.get("honesty", 0.5)), -1, 1)
			note = "%s asked again. And again." % iv.who
		"own":
			d = 1
			note = "Owning it went down better than anyone expected."
		"attack":
			for o in OUTLETS: s.media[o.id].buzz = clampf2(float(s.media[o.id].buzz) + (0.2 if float(o.get("honesty", 0.5)) < 0.5 else -0.2), -1, 1)
			note = "Your fans loved it. The rest of the room went quiet."
		"deny":
			d = -2
			note = "The programme had the footage, and showed it."
		"deflect":
			note = "A laugh, and no answer. It got the laugh."
	iv.score = int(iv.score) + d
	if kind in ["clear", "uturn"]:
		var t: String = String(line.text).trim_prefix("\"").trim_suffix("\"")
		record_statement(s, {"text": t, "title": "The big interview", "effects": {"shift": {rd.axis: (-5 if line.side == "L" else 5)}}, "tone": line.tone, "spoken": true})
	var result = merged(res, {"quote": line.text, "note": note, "changes": group_changes(s, before), "round": rd.title, "kind": kind, "tone": line.tone,
		"issue": String(by_id(AXES, rd.axis).issue).to_lower() if rd.axis != "" else ""})
	iv.results.append(result)
	iv.step = int(iv.step) + 1
	if iv.step >= iv.rounds.size():
		_interview_done(s)
		finish_front(s, "interview")
	return result

# ---------- Appearances (the campaign): a programme or a personality has you on ----------
## Two questions on the issues the outlet cares about (its own slant, or what the country
## is arguing about), your own line in different voices or a dodge. One action; nobody
## books a party under the national threshold. Its audience hears it most.
func appearance_block(s: Dictionary, oid: String) -> String:
	var o = outlet_by_id(oid)
	if o == null or o.kind in ["platform", "foreign"]: return "Not a programme that has guests."
	if not in_campaign(s): return "Appearances are for the official campaign."
	if s.media[oid].owner != "" and s.media[oid].owner != "player": return "%s belongs to a rival now." % o.name
	var share: float = float(s.lastSupport.get("player", 0)) if s.get("lastSupport") else 0.0
	if share < maxf(threshold(), 0.01): return "%s won't book a party under %d%% in the polls." % [o.name, jround(threshold() * 100)]
	if int(s.get("appeared", {}).get(oid, -99)) >= s.week - 4 * WEEKS_PER_MONTH: return "You were on %s not long ago." % o.name
	return ""

func start_appearance(s: Dictionary, oid: String) -> Dictionary:
	var err: String = appearance_block(s, oid)
	if err != "": return {"ok": false, "text": err}
	var e2 = can_act(s, 0)
	if e2: return {"ok": false, "text": e2}
	spend_action(s, 0)
	var o: Dictionary = outlet_by_id(oid)
	if not s.has("appeared"): s.appeared = {}
	s.appeared[oid] = s.week
	var player = player_party(s)
	var host: String = String(o.name) if o.kind == "influencer" else String(INTERVIEW.get("INTERVIEWERS", {}).get(oid, o.name))
	var fill = {"interviewer": host, "leader": player.leader, "party": player.name, "home": s.get("home", "")}
	# its own issues first, then the hottest arguments
	var axes = []
	var slant: Dictionary = s.media[oid].get("pos", {})
	var cands: Array = ssort(slant.keys(), func(a, b): return absf(float(slant[b])) - absf(float(slant[a])))
	cands.append_array(ssort(s.debates.duplicate(), func(a, b): return b.heat - a.heat).map(func(d): return d.axis))
	cands.append_array(AXES.map(func(ax): return ax.id))
	for ax in cands:
		if not axes.has(ax): axes.append(ax)
	var q: Dictionary = INTERVIEW.get("APPEARANCE", INTERVIEW.BIG)
	var rounds = []
	for ax in axes.slice(0, 2): rounds.append(_iv_issue(s, q, by_id(AXES, ax), fill))
	s.appearance = {"outlet": oid, "outletName": o.name, "who": host, "rounds": rounds, "step": 0, "results": []}
	s.queue.push_front({"type": "appearance"})
	_log(s, "action", "Went on %s." % o.name)
	return {"ok": true, "text": "%s has you on tonight." % o.name}

func answer_appearance(s: Dictionary, line_index: int) -> Dictionary:
	var ap: Dictionary = s.appearance
	var rd: Dictionary = ap.rounds[ap.step]
	var line: Dictionary = rd.lines[line_index]
	var before = snapshot_groups(s)
	var res = deliver_line(s, line)
	var o: Dictionary = outlet_by_id(ap.outlet)
	var kind: String = line.get("kind", "clear")
	var note = ""
	# its audience hears it most
	var aw = 0.0
	for pop in s.pops:
		var r: float = outlet_reach(s, o, pop)
		if r <= 0: continue
		pop.aware.player = clampf2(pop.aware.player + float(C.get("appearance", {}).get("aware", 0.04)) * r, 0, 1)
		if kind == "clear":
			var p: float = pop.pos[rd.axis]
			if (line.side == "L" and p < -15) or (line.side == "R" and p > 15):
				pop.goodwill.player = clampf2(pop.goodwill.player + float(C.get("appearance", {}).get("goodwill", 0.06)) * r * pop.sal[rd.axis], -2, 2)
	if kind == "clear":
		shift_perceived(s, {rd.axis: (-3.0 if line.side == "L" else 3.0)})
		s.spoke[side_key(rd.axis, line.side)] = s.week
		s.media[o.id].buzz = clampf2(float(s.media[o.id].buzz) + 0.05, -1, 1)
		note = "A straight answer. Its audience knew where you stood."
		record_statement(s, {"text": String(line.text).trim_prefix("\"").trim_suffix("\""), "title": "On %s" % o.name, "effects": {"shift": {rd.axis: (-3 if line.side == "L" else 3)}}, "tone": line.tone, "spoken": true})
	else:
		s.media[o.id].buzz = clampf2(float(s.media[o.id].buzz) - 0.1, -1, 1)
		note = "%s let it go. The audience didn't." % ap.who
	var result = merged(res, {"quote": line.text, "note": note, "changes": group_changes(s, before), "round": rd.title})
	ap.results.append(result)
	ap.step = int(ap.step) + 1
	if ap.step >= ap.rounds.size(): finish_front(s, "appearance")
	return result

## The piece runs: the country now knows who you are, for better or worse.
func _interview_done(s: Dictionary) -> void:
	var iv: Dictionary = s.interview
	var score: int = int(iv.score)
	var gaffes: int = iv.results.filter(func(r): return r.outcome == "gaffe").size()
	var v: Dictionary = INTERVIEW.VERDICTS[-1]
	for x in INTERVIEW.VERDICTS:
		if score >= int(x.from): v = x; break
	if gaffes >= 2 and INTERVIEW.has("LOOSE"): v = INTERVIEW.LOOSE
	# the piece follows what was said: the voice that carried it, a straight answer, a dodge, the record
	var P: Dictionary = INTERVIEW.get("PIECE", {})
	var f = {"leader": player_party(s).leader}
	var notes = []
	var tones = {}
	for r in iv.results: tones[r.tone] = int(tones.get(r.tone, 0)) + 1
	var main_tone = ""
	for k in tones:
		if main_tone == "" or tones[k] > tones[main_tone]: main_tone = k
	if P.get("voice", {}).has(main_tone): notes.append(String(P.voice[main_tone]).format(f))
	for r in iv.results:
		if r.kind == "clear" and P.has("clear"): notes.append(String(P.clear).format(merged(f, {"issue": r.issue, "quote": r.quote}))); break
	for r in iv.results:
		if r.kind == "dodge" and P.has("dodge"): notes.append(String(P.dodge).format(merged(f, {"issue": r.issue}))); break
	for r in iv.results:
		if P.get("record", {}).has(r.kind): notes.append(String(P.record[r.kind]).format(f))
	if gaffes >= 1 and P.has("gaffe"): notes.append(String(P.gaffe).format(f))
	iv.verdict = {"title": v.title, "text": v.text, "notes": notes}
	var reach: float = float(s.media.get(iv.outlet, {}).get("reachNat", 0.3))
	for pop in s.pops:
		pop.aware.player = clampf2(pop.aware.player + (0.12 + reach * 0.3) * (1 - pop.aware.player), 0, 1)
		pop.leader.player = clampf2(pop.leader.player + 0.05 * clampf2(score, -3, 4) * pop.leaderPull, -2, 2)
	for o in OUTLETS:
		if float(o.get("honesty", 0.5)) >= 0.55: s.media[o.id].buzz = clampf2(float(s.media[o.id].buzz) + 0.1 * clampf2(score, -3, 4), -1, 1)
	_log(s, "event", "The big interview on %s: \"%s\"" % [iv.outletName, v.title])

# ---------- The end-of-game profile ----------
func build_profile(s: Dictionary) -> Dictionary:
	var player = player_party(s)
	var rec: Dictionary = s.record
	var cons = contradictions(s)
	var shares: Dictionary = style_profile(s).shares
	var sh = func(k): return float(shares.get(k, 0))
	var nation = summarize(s, s.pops)
	var dirty: Array = rec.money.filter(func(m): return m.dirty)
	var drift = inconsistency_of(s, player)
	var ext: float = player.get("extremity", 0.0)
	var player_flips: int = s.flips.filter(func(f): return f.party == "player").size()
	var scores = {
		"weathervane": mini(cons.size(), 6) * 0.8 + mini(rec.betrayed.size(), 5) * 1.2 + mini(player_flips, 10) * 0.3,
		"believer": ext * 8 + (3.0 if drift < 1 else 0.0) - mini(cons.size(), 6),
		"strongman": sh.call("fiery") * 8 + sh.call("statesman") * 3 + nation.devotion * 20,
		"clown": (sh.call("folksy") + sh.call("sharp")) * 7 + rec.memes * 1.5 + rec.gaffes * 1.5,
		"technocrat": sh.call("statesman") * 9 + (1 - ext) * 3,
		"fixer": dirty.size() * 3 + rec.dossiers * 2,
		"demagogue": demagoguery(s),
	}
	var entries = []
	for k in scores: entries.append([k, scores[k]])
	var archetype: String = ssort(entries, func(a, b): return b[1] - a[1])[0][0]
	var r: Dictionary = s.result
	var L: String = player.leader.to_upper()
	var P: String = player.name.to_upper()
	var headline: String
	if r.majority: headline = "%s SWEEPS TO POWER" % L
	elif r.playerWon: headline = "%s BECOMES THE LARGEST PARTY" % P
	elif r.votes.player < 0.1: headline = "%s FADES INTO THE FOOTNOTES" % P
	else: headline = "%s'S GAMBLE FALLS SHORT" % L
	# after the coalition talks, the headline says how it ended (data/coalition.json OUTCOMES)
	var oc: Dictionary = COALITION.get("OUTCOMES", {}).get(r.get("coalition", {}).get("outcome", ""), {})
	if oc.has("headline"): headline = String(oc.headline).format({"party": player.name, "leader": player.leader}).to_upper()
	var quotes: Array = rec.quotes.filter(func(q): return q.title != "The final debate" and q.spoken)
	var signature = null
	var best = -1.0
	for q in quotes:
		var sz = 0.0
		for k in q.shift: sz += absf(q.shift[k])
		if sz > best:
			best = sz; signature = q
	var blamed = []
	for b in rec.blamed:
		if not blamed.has(b.group): blamed.append(b.group)
	var crisis = by_id(CRISES, s.crisis.id) if s.crisis else null
	return {
		"archetype": ARCHETYPES[archetype], "headline": headline,
		"contradictions": cons.slice(0, 3), "blamed": blamed, "betrayed": rec.betrayed.slice(0, 3),
		"money": rec.money,
		"crisis": {"name": crisis.name, "odds": s.crisis.odds, "blamed": crisis_blames_you(s)} if crisis else null,
		"memes": rec.memes, "gaffes": rec.gaffes, "statements": rec.quotes.size(),
		"style": style_profile(s).label, "signature": signature,
	}
