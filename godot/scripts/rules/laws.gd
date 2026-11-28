## rules/laws.gd — The government at work, and the promises you make in return. The government: every few months it tables a bill from its own programme
## (data/laws.json). The bill opens a debate; after a few months parliament votes. Whether it
## passes depends on the coalition partner and on how the argument went, so speaking on it can
## sink it. A law that passes changes the country for good (where its numbers settle) and
## brings its own events later.
extends "res://scripts/rules/world.gd"

## The party of the government that would table this law: the ruling party if it agrees,
## else a partner. Nobody if no one in government is on the law's side.
func law_sponsor(s: Dictionary, law: Dictionary) -> Variant:
	var sign: float = -1.0 if law.side == "L" else 1.0
	var best = null
	for p in s.parties:
		if not (p.get("ruling", false) or p.get("partner", false)): continue
		if p.manifesto[law.axis] * sign < float(LAWS_C.get("agree", 15)): continue
		if best == null or p.get("ruling", false): best = p
	return best

## A partner in government on the other side of the law (its position past the "agree" line).
func law_opponents(s: Dictionary, law: Dictionary) -> Array:
	var sign: float = -1.0 if law.side == "L" else 1.0
	return s.parties.filter(func(p): return (p.get("ruling", false) or p.get("partner", false)) and p.manifesto[law.axis] * sign <= -float(LAWS_C.get("agree", 15)))

func law_by_id(id: String) -> Dictionary:
	return by_id(LAWS, id)

## Every month: vote on the bill when its time comes, else table a new one now and then.
func laws_monthly(s: Dictionary) -> void:
	if LAWS.is_empty() or s.result: return
	if s.get("bill") and s.week >= int(s.bill.vote):
		law_vote(s)
		return
	if s.get("bill") or s.week < int(s.get("lawNext", 0)): return
	var month: float = float(s.week) / WEEKS_PER_MONTH
	var pool: Array = LAWS.filter(func(l): return not s.lawsDone.has(l.id) and month >= float(l.get("minMonth", 0)) and law_sponsor(s, l) != null)
	if pool.is_empty(): return
	var total = 0.0
	for l in pool: total += event_weight(s, l)
	var r: float = rand(s) * total
	for l in pool:
		r -= event_weight(s, l)
		if r <= 0:
			table_law(s, l.id)
			return

func table_law(s: Dictionary, id: String) -> void:
	var law: Dictionary = law_by_id(id)
	var sp = law_sponsor(s, law)
	if sp == null: return
	var months: int = int(LAWS_C.get("voteMonths", 3))
	s.bill = {"id": id, "sponsor": sp.id, "week": s.week, "vote": s.week + months * WEEKS_PER_MONTH}
	var sign: float = -1.0 if law.side == "L" else 1.0
	var d: Dictionary = open_debate(s, "law_" + id, law.axis, law.title, law.text, sp.id, float(LAWS_C.get("heat", 45)), sign * float(LAWS_C.get("push", 20)))
	d.major = true
	d.law = id
	_note_move(d, sp.id, "start", law.side, s.week)
	push_news(s, {"kind": "issue", "title": "The government tables %s" % law.title, "text": "%s %s Parliament votes in %d months." % [String(law.get("tabled", "")).format({"short": sp.short, "leader": sp.leader}), law.text, months]})
	_log(s, "world", "%s tables %s." % [sp.short, law.title])

## The chance the bill passes, and why: [{why, d}] adding up from the base.
func law_odds(s: Dictionary) -> Dictionary:
	var out = {"p": 0.0, "parts": []}
	if not s.get("bill"): return out
	var law: Dictionary = law_by_id(s.bill.id)
	var sign: float = -1.0 if law.side == "L" else 1.0
	var p: float = float(LAWS_C.get("base", 0.5))
	out.parts.append({"why": "A government bill, with a majority on paper", "d": p})
	for opp in law_opponents(s, law):
		var k: float = -float(LAWS_C.get("partnerAgainst", 0.35))
		p += k
		out.parts.append({"why": "%s, in government, is against it" % opp.short, "d": k})
	var d = debate_by_id(s, "law_" + s.bill.id)
	if d and d.lean * sign < -float(LAWS_C.get("publicFrom", 10)):
		var k2: float = -float(LAWS_C.get("publicAgainst", 0.1))
		p += k2
		out.parts.append({"why": "The public argument is going against it", "d": k2})
	var sp = party_of(s, s.bill.sponsor)
	if sp and float(sp.stability) < float(LAWS_C.get("weakBelow", 40)):
		var k3: float = -float(LAWS_C.get("weakGov", 0.15))
		p += k3
		out.parts.append({"why": "%s's hold on power is weak" % sp.short, "d": k3})
	out.p = clampf2(p, 0.05, 0.97)
	return out

func law_odds_word(p: float) -> String:
	return "Likely to pass" if p >= 0.6 else ("In doubt" if p >= 0.4 else ("Likely to fall" if p >= 0.15 else "Almost sure to fall"))

func law_vote(s: Dictionary) -> void:
	var bill: Dictionary = s.bill
	var law: Dictionary = law_by_id(bill.id)
	var odds: float = float(law_odds(s).p)
	var d = debate_by_id(s, "law_" + bill.id)
	var you: String = ""
	if d and d.has("you"): you = "for" if d.you.side == law.side else "against"
	if d: end_debate(s, d)
	s.bill = null
	s.lawNext = s.week + int(LAWS_C.get("gapMonths", 2)) * WEEKS_PER_MONTH + int(floor(rand(s) * 3)) * WEEKS_PER_MONTH
	var sp = party_of(s, bill.sponsor)
	var passed: bool = rand(s) < odds
	s.lawsDone[bill.id] = {"passed": passed, "week": s.week, "you": you}
	if passed:
		var fx: Dictionary = law.get("passed", {})
		if fx.get("world"): apply_effects(s, {"world": fx.world, "fromNews": true, "awareness": 0})
		for k in fx.get("lasting", {}): s.lawShift[k] = float(s.lawShift.get(k, 0)) + float(fx.lasting[k])
		for sd in law.get("seeds", []):
			var lo = int(sd.months[0])
			var hi = int(sd.months[1])
			s.scheduled.append({"id": sd.event, "week": s.week + (lo + int(floor(rand(s) * (hi - lo + 1)))) * WEEKS_PER_MONTH})
		if sp: sp.stability = clampf2(float(sp.stability) + 2, 0, 100)
		var tail: String = " You backed it, and get a little of the credit." if you == "for" else (" You fought it and lost." if you == "against" else "")
		push_news(s, {"kind": "issue", "title": "%s passes" % law.title, "text": String(fx.get("text", "Parliament passes the bill.")) + tail})
		if you == "for": s.serious = clampf2(serious_of(s) + 1.0, 0, 100)
	else:
		if sp: sp.stability = clampf2(float(sp.stability) - float(LAWS_C.get("failStability", 5)), 0, 100)
		change_trust(s, -1)
		var tail2: String = " You led the fight against it, and the papers say so." if you == "against" else (" You had backed it." if you == "for" else "")
		push_news(s, {"kind": "issue", "title": "%s falls" % law.title, "text": String(law.get("failed", "Parliament votes the bill down. The government is embarrassed.")) + tail2})
		if you == "against": s.serious = clampf2(serious_of(s) + float(LAWS_C.get("sinkSerious", 4)), 0, 100)
	_log(s, "world", "%s %s." % [law.title, "passes" if passed else "falls"])
	_pledges_after_vote(s, bill, passed)

func _pledges_after_vote(s: Dictionary, bill: Dictionary, passed: bool) -> void:
	for pl in s.pledges:   # promises to undo this bill
		var pd = pledge_by_id(pl.id)
		if pd and String(pd.get("law", "")) == bill.id and pl.status == "open" and not passed:
			pl.status = "kept"
			pl.weekDone = s.week

# ---------- Pledges ----------
## Promises made in debates (data/pledges.json): concrete, remembered, and costly to break.
func pledge_by_id(id: String) -> Variant:
	return by_id(PLEDGES, id)

func pledge_of(s: Dictionary, id: String) -> Variant:
	for pl in s.pledges:
		if pl.id == id: return pl
	return null

## The promises on offer after speaking in this debate, on this side.
func pledges_for(s: Dictionary, d: Dictionary, side: String) -> Array:
	var topic: String = String(d.get("topic", d.id))
	return PLEDGES.filter(func(p): return p.topic == topic and p.side == side and pledge_of(s, p.id) == null)

func pledge_axis(pd: Dictionary) -> String:
	if pd.has("law"): return String(law_by_id(pd.law).axis)
	var t = by_id(TOPICS, pd.topic)
	return String(t.axis) if t else ""

func pledge_block(s: Dictionary, pd: Dictionary) -> String:
	if pledge_of(s, pd.id) != null: return "You've already promised it."
	return ""

## Speaking in a debate is a promise, where the debate has one: the big promise in a
## major debate, the small one in a smaller argument. Null if there is none (or it's made).
func speech_pledge(s: Dictionary, d: Dictionary, side: String) -> Variant:
	var want: String = "big" if is_major(d) else "small"
	for pd in pledges_for(s, d, side):
		if pd.size == want: return pd
	return null

## How much the country cares about this promise's issue, 0 to 1 and in words.
func pledge_care(s: Dictionary, pd: Dictionary) -> Array:
	var ax: String = pledge_axis(pd)
	var sal: float = float(summarize(s, s.pops).sal.get(ax, 1.0))
	return [sal, "a great deal" if sal >= 1.4 else ("quite a lot" if sal >= 1.0 else ("a little" if sal >= 0.7 else "hardly at all"))]

## Who warms to it and who cools: [pleased who, angered who] for showing.
func pledge_groups(pd: Dictionary) -> Array:
	var ax: String = pledge_axis(pd)
	var mine = {"lean": {ax: "<-25" if pd.side == "L" else ">25"}}
	var theirs = {"lean": {ax: ">25" if pd.side == "L" else "<-25"}}
	return [mine, theirs]

func act_pledge(s: Dictionary, id: String) -> Dictionary:
	var pd = pledge_by_id(id)
	if pd == null: return {"ok": false, "text": "No such promise."}
	var block = pledge_block(s, pd)
	if block: return {"ok": false, "text": block}
	var big: bool = pd.size == "big"
	var k: float = float(PLEDGES_C.get("big", 0.25)) if big else float(PLEDGES_C.get("small", 0.1))
	var ax: String = pledge_axis(pd)
	var gs: Array = pledge_groups(pd)
	for pop in s.pops:
		var sal: float = minf(1.5, float(pop.sal.get(ax, 1.0)))
		if matches(pop, gs[0]): pop.goodwill.player = clampf2(pop.goodwill.player + k * sal, -2, 2)
		elif matches(pop, gs[1]): pop.goodwill.player = clampf2(pop.goodwill.player - k * 0.7 * sal * (1 - shield_of(pop, "player")), -2, 2)
	for r in pd.get("react", []):
		for pop in pops_matching(s, r.who): pop.goodwill.player = clampf2(pop.goodwill.player + float(r.amt), -2, 2)
	add_ownership(s, "player", side_key(ax, pd.side), 0.04 if big else 0.015)
	s.pledges.append({"id": id, "week": s.week, "status": "open"})
	var text = "You promised: %s." % pd.title
	_log(s, "action", text)
	return {"ok": true, "text": text}

## You spoke (or started a debate) for one side: promises to the other side of the same
## debate, or big ones on the same issue, are broken, and those they pleased remember.
func break_pledges(s: Dictionary, axis: String, side: String, topic: String) -> Array:
	var broken = []
	for pl in s.pledges:
		if pl.status != "open": continue
		var pd = pledge_by_id(pl.id)
		if pd == null or pd.side == side or pledge_axis(pd) != axis: continue
		if pd.topic != topic and pd.size != "big": continue
		pl.status = "broken"
		pl.weekDone = s.week
		var k: float = float(PLEDGES_C.get("breakBig", 0.35)) if pd.size == "big" else float(PLEDGES_C.get("breakSmall", 0.12))
		if pl.get("flagship", false): k *= float(PLEDGES_C.get("breakFlagship", 2))   # the one on every poster
		var gs: Array = pledge_groups(pd)
		for pop in pops_matching(s, gs[0]): pop.goodwill.player = clampf2(pop.goodwill.player - k * minf(1.5, float(pop.sal.get(pledge_axis(pd), 1.0))) * (1 - 0.5 * devotion_of(pop, player_party(s))), -2, 2)
		push_news(s, {"kind": "bad", "title": "You promised: %s" % pd.title, "text": ("It was on every poster. " if pl.get("flagship", false) else "") + "Your own words, played back on every channel next to today's. The people who believed it are the ones who mind."})
		_log(s, "action", "Broke a promise: %s." % pd.title)
		broken.append(pd.title)
	return broken
