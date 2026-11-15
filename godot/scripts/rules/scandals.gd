## rules/scandals.gd — Secrets and scandals, and political violence.
extends "res://scripts/rules/party.gd"

# ---------- Secrets and scandals ----------
## A secret is what the public doesn't know about you (data/scandals.json): the
## leader's small skeletons from the mayor years, dirty money, hypocrisy (words
## that contradict the record), what a hasty hire brings. Every month each one may
## leak; the bigger you are and the more honest outlets dislike you, the likelier.
## When one leaks it is a scandal, and what you say decides how much it costs.
func live_secrets(s: Dictionary) -> Array:
	return s.get("secrets", []).filter(func(x): return not x.get("closed", false) and not x.get("leaked", false))

func secret_by_id(s: Dictionary, id: String) -> Variant:
	for x in s.get("secrets", []):
		if x.id == id: return x
	return null

func add_secret(s: Dictionary, d: Dictionary) -> Dictionary:
	if not s.has("secrets"): s.secrets = []
	for x in s.secrets:
		if x.get("key", "") == d.get("key", "-") and not x.get("closed", false) and not x.get("leaked", false):
			x.size = minf(3.0, float(x.size) + float(d.get("grow", 0.0)))
			return x
	var sec = merged({"id": "sec%d" % (s.secrets.size() + 1), "week": s.week, "evidence": 0.15, "who": {}, "size": 1.0}, d)
	sec.erase("grow")
	s.secrets.append(sec)
	return sec

func _past_secrets(s: Dictionary) -> void:
	var pool: Array = shuffle(s, SCANDALS.get("PAST", []))
	var n = 2 if rand(s) < 0.4 else 1
	var f = {"leader": player_party(s).leader, "home": s.home if s.get("home", "") != "" else CAPITAL.get("name", "Cranebo")}
	for sk in pool.slice(0, n):
		add_secret(s, {"kind": "past", "key": "past:" + sk.id, "title": String(sk.title).format(f), "text": String(sk.text).format(f),
			"what": String(sk.what).format(f), "size": float(sk.size), "who": sk.get("who", {}), "evidence": 0.1})

func _money_secret(s: Dictionary, fx: Dictionary) -> void:
	var ev = event_by_id(fx.scandal.event)
	var foreign: bool = fx.scandal.event != "leak_tycoon"
	add_secret(s, {"kind": "money", "key": "money:" + fx.scandal.event, "title": ev.title if ev else "Where the money came from",
		"text": ev.text if ev else "", "what": "The money from %s." % ("abroad" if foreign else "the tycoon"),
		"size": clampf2(float(fx.scandal.chance) * 32, 1.2, 2.6), "amount": float(fx.get("money", 0)), "event": fx.scandal.event,
		"who": {"lean": {"nation": "<-25"}} if foreign else {"class": ["working", "middle"]}})

## Words that contradict the record make the gap wider.
func _hypocrisy(s: Dictionary, shift: Dictionary) -> void:
	if not SCANDALS.has("HYPOCRISY"): return
	var offers = s.record.money.map(func(m): return m.get("offer", ""))
	var f = {"leader": player_party(s).leader, "party": player_party(s).short}
	var hy: Dictionary = SCANDALS.HYPOCRISY
	if float(shift.get("system", 0)) < 0 and (offers.has("chamber") or offers.has("tycoon")):
		add_secret(s, {"kind": "hypocrisy", "key": "hyp:elites", "title": String(hy.elites.title).format(f), "text": String(hy.elites.text).format(f),
			"what": hy.elites.what, "size": 0.5, "grow": 0.25, "who": hy.elites.who})
	if float(shift.get("economy", 0)) < 0 and offers.has("chamber"):
		add_secret(s, {"kind": "hypocrisy", "key": "hyp:workers", "title": String(hy.workers.title).format(f), "text": String(hy.workers.text).format(f),
			"what": hy.workers.what, "size": 0.5, "grow": 0.25, "who": hy.workers.who})
	# a nationalist line from a party paid from abroad
	if float(shift.get("nation", 0)) < 0:
		for x in live_secrets(s):
			if x.kind == "money" and x.get("event", "") != "leak_tycoon": x.size = minf(3.0, float(x.size) + 0.2)

## How likely a secret is to come out this month.
func secret_risk(s: Dictionary, sec: Dictionary) -> float:
	var sup: float = float(s.lastSupport.player) if s.lastSupport else 0.03
	var prominence: float = clampf2(sup * 5, 0.3, 2.0)
	var dig = 0.0
	for o in OUTLETS:
		if o.kind in ["foreign", "influencer", "platform"] or float(o.get("honesty", 0.5)) < 0.55: continue
		dig += float(s.media[o.id].get("reachNat", 0)) * maxf(0, -float(s.media[o.id].get("favour", {}).get("player", 0))) * 3
	var age: float = float(s.week - int(sec.week)) / WEEKS_PER_MONTH
	var r: float = 0.012 * (0.5 + float(sec.size) * 0.5) * prominence * (1 + dig) * (1 + age * 0.03)
	if sec.kind in ["past", "party"] and s.figures.any(func(f): return f.loyalty < 35): r *= 1.5   # unhappy insiders talk
	if sec.kind == "money":
		var t = teyl(s)
		if t and t.loyalty >= 55: r *= 0.6   # Margaret keeps the books
		if s.week - int(s.get("teylClean", -9999)) < 12 * WEEKS_PER_MONTH: r *= 0.5
	if s.get("teylGone", false): r *= 1.6   # she took people who know things
	return r

func risk_word(r: float) -> String:
	if r < 0.01: return "Nobody's asking"
	if r < 0.025: return "A journalist has been asking around"
	if r < 0.05: return "Someone is getting close"
	return "It could break any day"

func secrets_monthly(s: Dictionary) -> void:
	if not s.has("secrets") or s.result: return
	for sec in s.secrets:
		# a denial that didn't hold comes back as the lie
		if sec.get("lieAt", -1) >= 0 and s.week >= int(sec.lieAt):
			sec.lieAt = -1
			_queue_lie(s, sec)
	var leaked = false
	for sec in live_secrets(s):
		sec.evidence = minf(1.0, float(sec.evidence) + 0.03)
		if not leaked and rand(s) < secret_risk(s, sec):
			leaked = true
			leak_secret(s, sec, "")

func _breaking_outlet(s: Dictionary) -> Dictionary:
	var best = null
	var bv = -9.0
	for o in OUTLETS:
		if o.kind in ["foreign", "influencer", "platform"] or float(o.get("honesty", 0.5)) < 0.55: continue
		var v: float = float(s.media[o.id].get("reachNat", 0)) - float(s.media[o.id].get("favour", {}).get("player", 0)) + rand(s) * 0.2
		if v > bv: bv = v; best = o
	return best if best else {"id": "", "name": "the papers"}

## Who could take the fall, and their price: the most loyal are the cheapest.
func scapegoat_for(s: Dictionary, sec: Dictionary) -> Dictionary:
	var best = null
	for f in s.figures:
		if f.id == "teyl": continue
		if sec.get("figure", "") == f.name: best = f; break
		if best == null or f.loyalty > best.loyalty: best = f
	if best == null: return {}
	var price: float = snappedf(1.0 + float(sec.size) * 1.5 + (100 - float(best.loyalty)) / 25.0, 0.5)
	return {"figure": best, "price": price}

func leak_secret(s: Dictionary, sec: Dictionary, by: String) -> void:
	sec.leaked = true
	var o: Dictionary = _breaking_outlet(s)
	var ev_strength: float = clampf2(float(sec.evidence) + rand(s) * 0.3 - 0.1, 0, 1)
	var ew: Dictionary = SCANDALS.EVIDENCE[-1]
	for e in SCANDALS.EVIDENCE:
		if ev_strength >= float(e.from): ew = e; break
	sec.strength = ev_strength
	sec.outlet = o.name
	var player = player_party(s)
	var who_broke: String = ("%s's investigators handed it to %s." % [by, o.name]) if by != "" else ("%s ran the story." % o.name)
	var choices = []
	var R: Dictionary = SCANDALS.RESPONSES
	var fill = {"leader": player.leader, "party": player.short, "home": s.get("home", ""), "figure": ""}
	var line_list = func(key: String, f: Dictionary) -> Array:
		return R[key].lines.map(func(l): return merged(l, {"text": "\"%s\"" % String(l.text).format(f)}))
	for key in ["deny", "own", "attack"]:
		var lines: Array = line_list.call(key, fill)
		if key == "attack" and sec.kind == "money" and SCANDALS.get("GAFFES", {}).has("money"):
			var g: Dictionary = SCANDALS.GAFFES.money
			lines.append({"tone": g.tone, "text": "\"%s\"" % g.text, "risk": 0.95})
		choices.append({"label": R[key].label, "effects": {"secretAnswer": {"id": sec.id, "how": key}}, "lines": lines, "note": R[key].help})
	if s.actionsLeft > 0:
		choices.append({"label": R.subject.label, "effects": {"secretAnswer": {"id": sec.id, "how": "subject"}}, "lines": line_list.call("subject", fill), "note": R.subject.help})
	var sg: Dictionary = scapegoat_for(s, sec)
	if not sg.is_empty() and s.money >= sg.price:
		var f2 = fill.duplicate()
		f2.figure = sg.figure.name
		sec.scapegoat = sg.figure.id
		sec.price = sg.price
		choices.append({"label": "%s (₱%sM)" % [String(R.scapegoat.label).format(f2), fmt1(sg.price)], "effects": {"secretAnswer": {"id": sec.id, "how": "scapegoat"}},
			"lines": line_list.call("scapegoat", f2), "note": String(R.scapegoat.help).format(f2)})
	var text: String = "%s %s\n\n%s Carlos: \"%s\"" % [sec.text, who_broke, ew.word, ew.carlos]
	s.queue.append({"type": "event", "event": {"id": "scandal_" + sec.id, "kind": "scandal", "title": sec.title, "text": text, "choices": choices}})
	push_news(s, {"kind": "bad", "quiet": true, "title": sec.title, "text": sec.text})

func _queue_lie(s: Dictionary, sec: Dictionary) -> void:
	var L: Dictionary = SCANDALS.LIE
	var f = {"source": sec.get("outlet", "the papers")}
	var R: Dictionary = SCANDALS.RESPONSES
	var choices = []
	for key in ["own", "attack"]:
		choices.append({"label": R[key].label, "effects": {"secretAnswer": {"id": sec.id, "how": key, "lie": true}},
			"lines": R[key].lines.map(func(l): return merged(l, {"text": "\"%s\"" % String(l.text)})), "note": R[key].help})
	s.queue.append({"type": "event", "event": {"id": "lie_" + sec.id, "kind": "scandal", "title": L.title, "text": String(L.text).format(f) + "\n\n" + sec.title + ".", "choices": choices}})

## What the scandal costs, by the answer you gave.
func scandal_answer(s: Dictionary, a: Dictionary) -> String:
	var sec = secret_by_id(s, a.id)
	if sec == null: return ""
	var press = 0.6
	for o in OUTLETS:
		if float(o.get("honesty", 0.5)) >= 0.55 and not (o.kind in ["foreign", "influencer", "platform"]) and float(s.media[o.id].get("favour", {}).get("player", 0)) < 0.3:
			press += float(s.media[o.id].get("reachNat", 0))
	var D: float = 0.32 * float(sec.size) * minf(1.6, press) * (1.7 if a.get("lie", false) else 1.0)
	var hit = func(mult: float, attack: bool) -> void:
		for pop in s.pops:
			var m: float = mult
			if attack: m = maxf(0.0, mult - 1.0 * shield_of(pop, "player") - 0.6 * maxf(0, float(pop.disaffection) - 1))
			var d: float = D * m * (2.0 if not sec.who.is_empty() and matches(pop, sec.who) else 1.0) * (1 - shield_of(pop, "player") * (0.0 if attack else 1.0))
			pop.goodwill.player = clampf2(pop.goodwill.player - d, -2, 2)
	sec.closed = true
	var out = ""
	match a.how:
		"deny":
			s.record.denials = int(s.record.get("denials", 0)) + 1
			var hold: float = 0.7 if float(sec.strength) < 0.35 else (0.45 if float(sec.strength) < 0.65 else 0.15)
			if rand(s) < hold:
				hit.call(0.3, false)
				out = " The denial held. The story ran for a day and died."
			else:
				hit.call(0.5, false)
				sec.lieAt = s.week + WEEKS_PER_MONTH * (1 + int(rand(s) * 2))
				out = " For now, people are waiting to see what else comes out."
		"own":
			hit.call(0.7, false)
			for o in OUTLETS:
				if float(o.get("honesty", 0.5)) >= 0.55: s.media[o.id].buzz = clampf2(float(s.media[o.id].buzz) + 0.2, -1, 1)
			for pop in s.pops:
				if pop.age in ["46-60", "61+"]: pop.goodwill.player = clampf2(pop.goodwill.player + 0.03, -2, 2)
			if sec.kind == "money":
				var back: float = minf(float(sec.get("amount", 0)), s.money)
				s.money -= back
				var pat = s.get("patron")
				if pat and by_id(FUNDING_OFFERS, pat.offer) and by_id(FUNDING_OFFERS, pat.offer).effects.get("scandal", {}).get("event", "") == sec.get("event", ""): s.patron = null
				out = " You gave back ₱%sM. It hurt, and then it was over." % fmt1(back)
			else:
				out = " It hurt, and then it was over."
		"attack":
			hit.call(0.75 - 0.35 * maxf(0, (50.0 - s.trust) / 50.0), true)
			for o in OUTLETS:
				s.media[o.id].buzz = clampf2(float(s.media[o.id].buzz) + (0.3 if float(o.get("honesty", 0.5)) < 0.5 else -0.4), -1, 1)
			out = " Your own people closed ranks. Everyone else noticed you didn't answer."
		"subject":
			if s.actionsLeft > 0:
				s.actionsLeft -= 1
				hit.call(0.6, false)
				var hot = null
				for d in s.debates:
					if hot == null or d.heat > hot.heat: hot = d
				if hot: hot.heat = clampf2(hot.heat + 15, 0, 100)
				out = " By the evening news, everyone was arguing about something else."
			else:
				hit.call(0.9, false)
		"scapegoat":
			var f = figure_by_id(s, sec.get("scapegoat", ""))
			if f and s.money >= float(sec.get("price", 0)):
				s.money -= float(sec.price)
				hit.call(0.35, false)
				s.figures.erase(f)
				s.figuresLost.append({"name": f.name, "role": f.role, "week": s.week, "why": "took the fall"})
				s.record.scapegoats = int(s.record.get("scapegoats", 0)) + 1
				var t = teyl(s)
				if t: t.loyalty = clampf2(t.loyalty - 15, 0, 100)
				_replace_figure(s, f)
				add_secret(s, {"kind": "payoff", "key": "payoff:" + f.name, "title": "%s was paid to take the fall" % f.name,
					"text": "%s resigned 'for personal reasons' over %s. Bank records now show a generous 'consultancy' from friends of %s." % [f.name, sec.title.to_lower(), player_party(s).short],
					"what": "%s took the blame for %s, for ₱%sM." % [f.name, sec.title.to_lower(), fmt1(sec.price)], "size": 0.9, "who": {}, "figure": f.name})
				out = " %s resigned the same afternoon. The story went with the job." % f.name
			else:
				hit.call(0.9, false)
	return out

## Margaret walks out, and the people who were loyal to her more than to you go too.
func _teyl_walkout(s: Dictionary) -> void:
	s.teylGone = true
	var went = []
	for f in s.figures.duplicate():
		if f.get("yes", false) or f.get("doubter", false): continue
		if f.loyalty >= 75: continue
		s.figures.erase(f)
		s.figuresLost.append({"name": f.name, "role": f.role, "week": s.week, "why": "left with Margaret Teyl"})
		went.append(f.name)
		_replace_figure(s, f)
	if went.size():
		push_news(s, {"kind": "threat", "title": "%s walks out of %s" % ["Margaret Teyl", player_party(s).short],
			"text": "The party secretary has resigned, and %s went with her. The people who built the party are leaving it to the people who owe it their jobs." % " and ".join(went)})

# ---------- Political violence ----------
## Violence happens in the world, never by the player's hand. It becomes likelier
## as trust in politics falls, unrest rises and the debate gets hotter; the leader
## only chooses how to react (data/violence.json).
func violence_monthly(s: Dictionary) -> void:
	if VIOLENCE.is_empty() or s.result: return
	if s.week - int(s.get("lastViolence", -9999)) < 4 * WEEKS_PER_MONTH: return
	var distrust: float = maxf(0, (50.0 - s.trust) / 50.0)
	var heat = 0.0
	for d in s.debates: heat = maxf(heat, float(d.heat))
	var chance: float = 0.015 + 0.06 * distrust + 0.04 * metric_badness(s, "unrest") + 0.02 * heat / 100.0
	if rand(s) > chance: return
	s.lastViolence = s.week
	# which camp: nationalist anger when migration and the border are in the news, the other when money is
	var right_w: float = 1.0 + metric_badness(s, "migration") + metric_badness(s, "border")
	var left_w: float = 1.0 + metric_badness(s, "jobs") + metric_badness(s, "prices")
	var camp: String = "right" if rand(s) * (right_w + left_w) < right_w else "left"
	var pool: Array = VIOLENCE.EVENTS.filter(func(e): return e.camp == camp and not s.flags.has("seen:violence:" + e.title))
	if pool.is_empty(): pool = VIOLENCE.EVENTS.filter(func(e): return e.camp == camp)
	var ev: Dictionary = pick(s, pool)
	s.flags["seen:violence:" + ev.title] = s.week
	change_trust(s, -3)
	s.world.unrest = clampf2(float(s.world.unrest) + 5, 0, 100)
	var R: Dictionary = VIOLENCE.REACTIONS
	var choices = []
	for key in ["condemn", "allsides", "understand"]:
		choices.append({"label": R[key].label, "note": R[key].help, "effects": {"violence": {"how": key, "camp": camp}},
			"lines": R[key].lines.map(func(l): return merged(l, {"text": "\"%s\"" % l.text}))})
	s.queue.append({"type": "event", "event": {"id": "violence_%d" % s.week, "kind": "violence", "title": ev.title, "text": ev.text + "\n\nEveryone wants to know what the party leaders will say.", "choices": choices}})

func violence_answer(s: Dictionary, a: Dictionary) -> String:
	var symp: Dictionary = VIOLENCE.get("SYMPATHY", {}).get(a.camp, {})
	var who_symp = {"lean": symp}
	var hon = func(d: float) -> void:
		for o in OUTLETS:
			if float(o.get("honesty", 0.5)) >= 0.55: s.media[o.id].buzz = clampf2(float(s.media[o.id].buzz) + d, -1, 1)
	match a.how:
		"condemn":
			hon.call(0.15)
			for pop in s.pops:
				if matches(pop, who_symp): pop.goodwill.player = clampf2(pop.goodwill.player - 0.05, -2, 2)
				elif absf(float(pop.pos.system)) < 40: pop.goodwill.player = clampf2(pop.goodwill.player + 0.04, -2, 2)
			return " The papers quoted you in full."
		"allsides":
			hon.call(-0.1)
			for pop in s.pops:
				if matches(pop, who_symp): pop.goodwill.player = clampf2(pop.goodwill.player + 0.03, -2, 2)
			return " Everyone heard what they wanted to hear. The honest press noticed what you didn't say."
		"understand":
			hon.call(-0.4)
			change_trust(s, -2)
			s.record.understood = int(s.record.get("understood", 0)) + 1
			s.flags["edge:" + a.camp] = int(s.flags.get("edge:" + a.camp, 0)) + 1
			for pop in s.pops:
				if matches(pop, who_symp):
					pop.goodwill.player = clampf2(pop.goodwill.player + 0.1, -2, 2)
					pop.leader.player = clampf2(pop.leader.player + 0.05, -2, 2)
				else: pop.goodwill.player = clampf2(pop.goodwill.player - 0.08 * (1 - shield_of(pop, "player")), -2, 2)
			return " Some people will never forget you said it. Some of them will vote for you because of it."
	return ""

## Rivals call you names when your record puts you near an edge: positions, and how
## you reacted to violence. It polarises: their voters go cold, yours dig in.
func labels_monthly(s: Dictionary) -> void:
	if VIOLENCE.is_empty() or rand(s) > 0.25: return
	var me: Dictionary = player_party(s).perceived
	var right: float = maxf(0, -float(me.nation)) / 100.0 + maxf(0, -float(me.order)) / 100.0 + maxf(0, -float(me.system)) / 100.0 + maxf(0, float(me.society)) / 100.0 + 0.5 * int(s.flags.get("edge:right", 0))
	var left: float = maxf(0, -float(me.economy)) / 100.0 + maxf(0, -float(me.welfare)) / 100.0 + maxf(0, -float(me.system)) / 100.0 + 0.5 * int(s.flags.get("edge:left", 0))
	var camp: String = "right" if right >= left else "left"
	if maxf(right, left) < 1.5: return
	# the rival furthest from you on what you're accused of says it
	var axis: String = "nation" if camp == "right" else "economy"
	var who = null
	for p in rivals(s):
		if who == null or absf(float(p.perceived[axis]) - float(me[axis])) > absf(float(who.perceived[axis]) - float(me[axis])): who = p
	if who == null: return
	var word: String = pick(s, VIOLENCE.LABELS[camp])
	for pop in s.pops:
		if float(pop.loyal.get(who.id, 0)) > 0.2: pop.goodwill.player = clampf2(pop.goodwill.player - 0.04, -2, 2)
		elif devotion_of(pop, player_party(s)) > 0.3 or float(pop.disaffection) > 1.2: pop.goodwill.player = clampf2(pop.goodwill.player + 0.02, -2, 2)
	push_news(s, {"party": who.id, "kind": "threat", "quiet": true, "title": "%s calls %s %s" % [who.short, player_party(s).short, word], "text": ""})
