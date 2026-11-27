## rules/world.gd — The world: events, the state of the nation, initiatives, the major crisis, the national debate, the voice (delivery and the record) and polls.
extends "res://scripts/rules/rivals.gd"

# ---------- Events ----------
func eligible_events(s: Dictionary) -> Array:
	var year: int = calendar(s.week).year
	var out = []
	for e in EVENTS:
		if e.get("deck", true) == false: continue
		if e.get("minYear") and year < e.minYear: continue
		if not in_season(s, e): continue
		if e.get("requires") and not s.flags.has(e.requires): continue
		if e.get("minSerious") and serious_of(s) < float(e.minSerious): continue   # only once the country takes you seriously
		if e.get("minDemagogue") and demagoguery(s) < float(e.minDemagogue): continue   # only once you've been hateful enough to be noticed for it
		var seen = s.flags.get("seen:" + e.id)
		if e.get("once") and seen != null: continue
		if seen != null and s.week - seen < 18 * WEEKS_PER_MONTH: continue
		out.append(e)
	return out

## How much of a demagogue you have been: groups you blamed (3 each) and provocations
## that caused outrage (1.2 each). Events with "minDemagogue" wait for it.
func demagoguery(s: Dictionary) -> float:
	return s.record.blamed.size() * 3.0 + float(s.record.outrages) * 1.2

func event_weight(s: Dictionary, e: Dictionary) -> float:
	var w = float(e.get("weight", 1))
	if w == 0: w = 1
	var when: Dictionary = e.get("when", {})
	for k in when:
		var v: float = s.world[k]
		var cond: String = when[k]
		var n = float(cond.substr(1))
		if (v < n) if cond[0] == "<" else (v > n): w *= 3
	var ax = event_axis(e)
	for d in s.get("debates", []):
		if ax != "" and d.axis == ax and d.heat >= 50: w *= 2.5
	return w

func draw_event(s: Dictionary) -> Variant:
	for i in s.scheduled.size():
		if s.scheduled[i].week <= s.week:
			var id = s.scheduled[i].id
			s.scheduled.remove_at(i)
			return id
	var pool = eligible_events(s)
	if pool.is_empty(): return null
	var total = 0.0
	for e in pool: total += event_weight(s, e)
	var r = rand(s) * total
	for e in pool:
		r -= event_weight(s, e)
		if r <= 0: return e.id
	return pool[-1].id

func monthly_event(s: Dictionary) -> void:
	for q in s.queue:
		if q.type == "event" or q.type == "debate": return
	var forced = false
	for x in s.scheduled:
		if x.week <= s.week: forced = true
	for d in s.debates:
		if d.heat >= 75 and not d.get("sparked", false):
			d.sparked = true
			forced = true
	if not forced and s.quietMonths < C.maxQuietMonths and rand(s) > C.eventChance:
		s.quietMonths += 1
		return
	var id = draw_event(s)
	if id == null: return
	s.quietMonths = 0
	queue_event(s, id)

func event_of(front: Dictionary) -> Dictionary:
	return front.event if front.has("event") else event_by_id(front.id)

func event_news(s: Dictionary, ev: Dictionary) -> void:
	if ev.get("trust"): change_trust(s, ev.trust)
	if ev.get("world"): apply_effects(s, {"world": ev.world, "fromNews": true, "awareness": 0})
	if ev.get("government") and ev.government.get("world"): apply_effects(s, {"world": ev.government.world, "fromNews": true, "awareness": 0})
	for c in ev.get("country", []): note_country(s, c)

func queue_event(s: Dictionary, id) -> void:
	var ev = event_by_id(id)
	if ev == null: return
	event_news(s, ev)
	if ev.has("where"):   # it happens somewhere: pin it on the map
		var placed: Dictionary = placed_event(s, ev)
		s.queue.append({"type": "event", "id": id, "event": placed})
		if placed.has("place"):
			if not s.has("eventPins"): s.eventPins = []
			s.eventPins = s.eventPins.filter(func(e): return s.week - int(e.week) <= EVENT_PIN_MONTHS * WEEKS_PER_MONTH)
			s.eventPins.append({"id": str(id), "title": placed.title, "week": s.week, "district": placed.place.district, "region": placed.place.region})
		return
	s.queue.append({"type": "event", "id": id})

## choice_index: what you say. line_index: how you say it (-1 = no sound bite).
func resolve_event(s: Dictionary, choice_index: int, line_index := -1) -> Dictionary:
	var front: Dictionary = s.queue[0]
	var ev = event_of(front)
	var choice: Dictionary = ev.choices[choice_index]
	if ev.get("kind", "") == "flagship":   # a promise from a party nobody takes seriously moves fewer people
		choice = choice.duplicate(true)
		var k: float = moment_weight(s)
		for g in choice.effects.get("goodwill", []): g.amt = float(g.amt) * k
		for l in choice.get("lines", []):
			for g in l.get("react", []): g.amt = float(g.amt) * k
	var before: Dictionary = player_party(s).perceived.duplicate()
	var groups_before = snapshot_groups(s)
	var flips_before: int = s.flips.size()
	var fx: Dictionary = choice.effects
	apply_effects(s, fx)
	var extra = ""
	if fx.has("patron"): extra += patron_answer(s, fx.patron)
	if fx.has("secretAnswer"): extra += scandal_answer(s, fx.secretAnswer)
	if fx.has("violence"): extra += violence_answer(s, fx.violence)
	if fx.get("defect"):
		var moved = defect(s, fx.defect.from, fx.defect.share)
		change_relation(s, fx.defect.from, -10, "you took in their rebels")
		extra = " About %dk of their loyal voters followed them across." % jround(moved / 1000.0)
	var delivery = null
	var quote = null
	var tone = null
	var lines: Array = choice.get("lines", [])
	if lines.size() and line_index >= 0 and line_index < lines.size():
		var line: Dictionary = lines[line_index]
		delivery = deliver_line(s, line)
		quote = line.text
		tone = line.tone
	if ev.get("place"): heard_in(s, ev.place, String(ev.title))   # it happened there: they heard what you said
	var statement: bool = not fx.has("defect") and not str(ev.id).begins_with("defectors_") and ev.get("kind", "") != "secret"
	record_statement(s, {"text": quote if quote else choice.label, "title": ev.title, "effects": fx, "tone": tone, "spoken": quote != null, "statement": statement})
	s.flags["seen:" + str(ev.id)] = s.week
	if ev.get("kind", "") == "flagship": _flagship_made(s, ev, choice, quote)
	var eax = event_axis(ev)
	if eax != "" and not (ev.get("kind", "") in ["trap", "secret"]):
		var sh = float(fx.get("shift", {}).get(eax, 0))
		var ed = open_debate(s, "ev:" + str(ev.id), eax, ev.title, ev.text, "news", 28, signf(sh) * 20)
		if ev.get("kind", "") == "crisis" or str(ev.id).begins_with("crisis_"): ed.major = true
		# your answer to the event is already your statement in the debate it starts
		ed.you = {"side": ("L" if sh < 0 else "R") if sh != 0 else "", "week": s.week, "quote": quote if quote else choice.label}
	_log(s, "event", "%s: %s%s" % [ev.title, ("\"%s\"" % quote) if quote else (choice.label + "."), extra])
	finish_front(s, "event")
	return {"before": before, "after": player_party(s).perceived.duplicate(), "flips": s.flips.slice(flips_before), "extra": extra,
		"delivery": delivery, "quote": quote, "label": choice.label, "title": ev.title, "changes": group_changes(s, groups_before)}

# ---------- Polls ----------
func noisy(s: Dictionary, shares: Dictionary, sd: float) -> Dictionary:
	var out = {}
	var total = 0.0
	for id in shares:
		# like a real poll, the error shrinks for small parties (sd is the error at 25%)
		var p: float = clampf2(float(shares[id]), 0, 1)
		out[id] = maxf(0.001, shares[id] + rand_normal(s) * sd * sqrt(p * (1 - p)) / 0.433)
		total += out[id]
	for id in out: out[id] /= total
	return out

func poll_sample(s: Dictionary) -> Array:
	var by_d = {}
	for pop in s.pops:
		var id: String = pop.get("district", pop.region)
		if not by_d.has(id): by_d[id] = []
		by_d[id].append(pop)
	var out = []
	for id in by_d:
		var pool: Array = by_d[id].duplicate()
		var total = 0.0
		for pop in pool: total += float(pop.size)
		var picked = []
		while picked.size() < POLL_PER_DISTRICT and pool.size():
			var left = 0.0
			for pop in pool: left += float(pop.size)
			var r: float = rand(s) * left
			var k = 0
			while k < pool.size() - 1 and r > float(pool[k].size):
				r -= float(pool[k].size); k += 1
			picked.append(pool[k])
			pool.remove_at(k)
		# picked in proportion to size, so each one stands for an equal share of the province
		for pop in picked:
			var q: Dictionary = pop.duplicate(false)
			q.size = total / picked.size()
			out.append(q)
	return out

func take_poll(s: Dictionary, label: String, silent := false) -> void:
	var ctx = score_context(s)
	var cache = {}
	var sample: Array = poll_sample(s)
	var nation = summarize(s, sample, ctx, cache)
	var err: float = 0.0 if s.get("paidPolling", false) else float(C.pollError)   # paid-for polling: the same sample, no random noise
	var poll = {"week": s.week, "label": label, "national": noisy(s, nation.support, err * 0.5), "paid": s.get("paidPolling", false),
		"turnout": nation.turnout, "trust": s.trust, "regions": {}, "groups": {}}
	for kind in group_kinds():
		for g in kind.groups:
			var sm = summarize(s, sample.filter(func(p): return matches(p, g.who)), ctx, cache)
			if not sm.size: continue
			var entry = {"support": noisy(s, sm.support, err), "core": sm.core}
			poll.groups[kind.id + ":" + g.id] = entry
			if kind.id == "region": poll.regions[g.id] = entry.support
	poll.tracker = silent
	s.polls.append(poll)
	s.projection = district_results(s, cache, ctx, sample)   # who would win each district today, by this poll
	if silent: return
	var prev_annual = null
	var i: int = s.polls.size() - 2
	while i >= 0:
		if not s.polls[i].tracker:
			prev_annual = s.polls[i]; break
		i -= 1
	if prev_annual: rivals_adapt(s, prev_annual.national, poll.national)
	# a poll is news, not a decision: it goes in the diary and the ticker, and the Polls file has the detail
	s.log.append({"week": s.week, "kind": "poll", "text": "%s: %s on %s%%." % [label, player_party(s).short, fmt1(poll.national.player * 100)]})

# ---------- The flagship promise: what it changes ----------
func _flagship_made(s: Dictionary, ev: Dictionary, choice: Dictionary, quote) -> void:
	var it: Dictionary = by_id(FLAGSHIP, ev.flagship)
	var sh: float = float(choice.effects.shift.get(it.axis, 0))
	var axis: String = it.axis
	if sh == 0:
		for ax in choice.effects.shift:
			axis = ax; sh = float(choice.effects.shift[ax]); break
	var side = "L" if sh < 0 else "R"
	s.flagship = {"issue": it.id, "axis": axis, "side": side, "label": choice.label, "quote": quote if quote else choice.label, "week": s.week}
	add_ownership(s, "player", side_key(axis, side), float(C.get("flagshipOwnership", 0.05)) * moment_weight(s))
	s.salMod[axis] = clampf2(float(s.salMod.get(axis, 0)) + float(C.get("flagshipSalience", 0.05)), -0.5, 1.5)

# ---------- The state of the nation (world.js) ----------
func indicator_word(id: String, v: float) -> String:
	var ind = by_id(INDICATORS, id)
	for w in ind.words:
		if v >= w[0]: return w[1]
	return ind.words[-1][1]

func world_monthly(s: Dictionary) -> void:
	var w: Dictionary = s.world
	var prev = w.duplicate()
	var migration_target = 55.0 + (-12.0 if (s.crisis and s.crisis.id == "economy") else 0.0)
	w.migration += (migration_target - w.migration) * 0.08 + rand_normal(s) * 2.5
	w.jobs += (55 - w.jobs) * 0.06 + (w.migration - 55) * 0.03 - maxf(0, w.prices - 55) * 0.05 + rand_normal(s) * 1.8
	w.prices += (45 - w.prices) * 0.06 + maxf(0, w.border - 60) * 0.03 + rand_normal(s) * 1.8
	w.border += (40 - w.border) * 0.05 + rand_normal(s) * 2
	var anger: float = maxf(0, 50 - w.jobs) * 0.25 + maxf(0, w.prices - 50) * 0.2 + maxf(0, w.migration - 65) * 0.12 + maxf(0, 40 - s.trust) * 0.15
	w.unrest += (32 + anger - w.unrest) * 0.12 + rand_normal(s) * 1.5
	for k in w: w[k] = clampf2(w[k], 0, 100)
	if w.jobs < 42 or w.prices > 60: change_trust(s, -0.8)
	# hard times wear the government down, a border crisis rallies people behind it;
	# a junior partner in the government feels half of either
	for p in s.parties:
		var k: float = 1.0 if p.ruling else (0.5 if p.get("partner", false) else 0.0)
		if k == 0.0: continue
		if w.jobs < 42 or w.prices > 60 or w.unrest > 60: p.stability = clampf2(p.stability - 1.5 * k, 0, 100)
		if w.border > 65: p.stability = clampf2(p.stability + 1 * k, 0, 100)
	update_climate(s)
	s.worldPrev = prev
	if not s.has("worldHistory"): s.worldHistory = []
	s.worldHistory.append(merged(prev, {"week": s.week}))
	if s.worldHistory.size() > 48: s.worldHistory = s.worldHistory.slice(-48)
	debates_from_world(s)

func update_climate(s: Dictionary) -> void:
	var w: Dictionary = s.world
	s.climate = {
		"economy": maxf(0, 55 - w.jobs) / 35.0 + maxf(0, w.prices - 50) / 50.0,
		"welfare": maxf(0, w.prices - 50) / 60.0,
		"nation": maxf(0, w.migration - 55) / 50.0 + maxf(0, w.border - 50) / 60.0,
		"foreign": maxf(0, w.border - 40) / 40.0,
		"system": maxf(0, w.unrest - 40) / 45.0,
		"order": maxf(0, w.unrest - 45) / 50.0,
	}
	s.regionClimate = {"yamlin": {"nation": maxf(0, w.migration - 50) / 30.0, "economy": maxf(0, w.migration - 55) / 50.0}}

# ---------- Initiatives ----------
func offer_initiatives(s: Dictionary) -> void:
	var used: Array = s.agenda.used
	var pool = INITIATIVES.filter(func(i): return not used.has(i.id) and (not i.get("minMonth") or float(s.week) / WEEKS_PER_MONTH >= i.minMonth))
	var weighted = pool.map(func(i): return {"i": i, "w": event_weight(s, i) * (0.5 + rand(s))})
	weighted = ssort(weighted, func(a, b): return b.w - a.w)
	s.agenda.offered = weighted.slice(0, 3).map(func(x): return x.i.id)
	s.agenda.done = false

# ---------- The national debate ----------
## The issue an event or initiative is mostly about: the axis its choices move most.
func event_axis(ev: Dictionary) -> String:
	if _event_axis.has(ev.id): return _event_axis[ev.id]
	var tot = {}
	var lists: Array = ev.get("choices", []).map(func(c): return c.get("effects", {}))
	if ev.has("effects"): lists.append(ev.effects)
	for fx in lists:
		for ax in fx.get("shift", {}): tot[ax] = float(tot.get(ax, 0)) + absf(float(fx.shift[ax]))
	var best = ""
	for ax in tot:
		if best == "" or tot[ax] > tot[best]: best = ax
	_event_axis[ev.id] = best
	return best

func debate_reach(s: Dictionary) -> float:
	return (0.6 + influence_of(s) * 0.5) * (0.85 + 0.15 * party_bench(s))

func _note_move(d: Dictionary, party: String, kind: String, side: String, week: int) -> void:
	d.moves.append({"party": party, "kind": kind, "side": side, "week": week})
	if d.moves.size() > 8: d.moves = d.moves.slice(-8)

## Who is pushing a debate lately (this month and last).
func debate_movers(s: Dictionary, d: Dictionary) -> Array:
	return d.moves.filter(func(m): return s.week - int(m.week) <= WEEKS_PER_MONTH * 2)

func debates_monthly(s: Dictionary) -> void:
	for d in s.debates.duplicate():
		# arguments tire with age: the longer one runs, the faster it cools
		var age: float = float(s.week - int(d.started)) / WEEKS_PER_MONTH
		d.heat = d.heat * maxf(0.6, 0.86 - 0.012 * age) - 2.0
		d.lean *= 0.92
		# like the headlines, the argument moves on after a few months, however hot it still is
		var life: float = DEBATE_LIFE_MAJOR if d.get("major", false) else DEBATE_LIFE
		if d.heat < 8 or age >= life:
			end_debate(s, d)
			continue
		d.history.append(d.heat)
		if d.history.size() > 12: d.history = d.history.slice(-12)
		s.salMod[d.axis] = clampf2(float(s.salMod.get(d.axis, 0)) + d.heat / 100.0 * 0.12, -0.5, 1.5)
		# a hot, one-sided debate moves what people believe
		if d.heat >= 25 and absf(d.lean) > 10:
			var push: float = d.lean / 100.0 * d.heat / 100.0 * 0.8
			for pop in s.pops:
				pop.pos[d.axis] = clampf2(pop.pos[d.axis] + push * minf(1.5, pop.sal[d.axis]), -100, 100)
	rivals_debate(s)
	# the news starts something new now and then, and always when the country has little to argue about
	if rand(s) < 0.55 or s.debates.size() < 3:
		var pool = TOPICS.filter(func(t): return not t.has("trigger") and debate_by_id(s, t.id) == null \
			and s.week - int(s.debateCooldown.get(t.id, -9999)) > 8 * WEEKS_PER_MONTH)
		if pool.size() and not media_start_debate(s, pool):
			var t: Dictionary = pick(s, pool)
			open_debate(s, t.id, t.axis, t.title, t.text, "news", 30)
			push_news(s, merged({"kind": "issue", "quiet": true}, news("WORLD", "new_argument", null, {"topic": t.title, "text": t.text})))

func debates_from_world(s: Dictionary) -> void:
	for t in TOPICS:
		if not t.has("trigger") or debate_by_id(s, t.id) != null: continue
		if s.week - int(s.debateCooldown.get(t.id, -9999)) < 6 * WEEKS_PER_MONTH: continue
		var ok = true
		for k in t.trigger:
			var cond: String = t.trigger[k]
			var n = float(cond.substr(1))
			if not ((s.world[k] < n) if cond[0] == "<" else (s.world[k] > n)): ok = false
		if not ok: continue
		open_debate(s, t.id, t.axis, t.title, t.text, "economy", 38)
		push_news(s, merged({"kind": "issue", "quiet": true}, news("WORLD", "everyone_talking", null, {"topic": t.title, "text": t.text})))

func rivals_debate(s: Dictionary) -> void:
	for p in rivals(s):
		var best = null
		var best_score = 0.0
		var best_kind = ""
		for d in s.debates:
			var ol = ownership_of(s, p.id, side_key(d.axis, "L"))
			var orr = ownership_of(s, p.id, side_key(d.axis, "R"))
			var sc = 0.0
			var kind = ""
			if ol + orr > 0.03:
				sc = (ol + orr) * (0.5 + d.heat / 100.0)
				kind = "fan:" + ("L" if ol > orr else "R")
			elif p.ruling and d.source == "economy":
				sc = d.heat / 100.0 * 0.4
				kind = "cool"
			if sc > best_score:
				best = d; best_score = sc; best_kind = kind
		if best and rand(s) < 0.7:
			if best_kind == "cool":
				best.heat = clampf2(best.heat - 9, 0, 100)
				_note_move(best, p.id, "cool", "", s.week)
			else:
				var side = best_kind.substr(4)
				var sg = -1.0 if side == "L" else 1.0
				best.heat = clampf2(best.heat + 8 * (1.0 - best.heat / 120.0), 0, 100)
				best.lean = clampf2(best.lean + sg * 10 * (1.0 - maxf(0, best.lean * sg) / 110.0), -100, 100)
				_note_move(best, p.id, "fan", side, s.week)
		elif rand(s) < 0.12:
			# start an argument on one of their own issues
			var claims = ownership_table(s).filter(func(r): return r.owners.any(func(o): return o.party == p.id))
			if claims.is_empty(): continue
			var row: Dictionary = claims[0]
			var pool = TOPICS.filter(func(t): return t.axis == row.axis and not t.has("trigger") and debate_by_id(s, t.id) == null \
				and s.week - int(s.debateCooldown.get(t.id, -9999)) > 6 * WEEKS_PER_MONTH)
			if pool.is_empty(): continue
			var t: Dictionary = pick(s, pool)
			var side: String = row.key.split(":")[1]
			var d = open_debate(s, t.id, t.axis, t.title, t.text, p.id, 30, -25.0 if side == "L" else 25.0)
			_note_move(d, p.id, "start", side, s.week)
			var foe = null
			for q in s.parties:
				if q.id == p.id: continue
				var v: float = float(q.perceived[t.axis]) * (1.0 if side == "L" else -1.0)   # how far on the other side
				if v > 30 and (foe == null or v > float(foe.perceived[t.axis]) * (1.0 if side == "L" else -1.0)): foe = q
			if foe: change_pair(s, foe.id, p.id, -3, "%s picked a fight with %s over %s" % [p.short, "you" if foe.isPlayer else foe.short, String(by_id(AXES, t.axis).issue).to_lower()])
			push_news(s, merged({"party": p.id, "kind": "threat", "quiet": true}, news("WORLD", "rival_fight", null, {"short": p.short, "topic": t.title, "text": t.text})))

func fan_preview(s: Dictionary, d: Dictionary, side: String) -> Dictionary:
	var reach = debate_reach(s)
	var key = side_key(d.axis, side)
	var owners: Array = ownership_table(s).filter(func(r): return r.key == key)
	var top = owners[0].owners[0].party if owners.size() and owners[0].owners.size() else ""
	var sign = -1.0 if side == "L" else 1.0
	var room_heat = 1.0 - d.heat / 120.0
	var room_lean = 1.0 - maxf(0, d.lean * sign) / 110.0
	return {"heat": DEBATE_FAN_HEAT * reach * room_heat, "lean": DEBATE_FAN_LEAN * reach * sign * room_lean, "mine": s.signature.has(key),
		"owner": top, "shift": preview_shift(s, {d.axis: sign * 4})[0], "side": by_id(AXES, d.axis).left if side == "L" else by_id(AXES, d.axis).right}

## A major debate is one the whole country is watching: your exact words get
## quoted, can go viral or become a gaffe. In smaller ones a line mostly
## shapes how you come across.
func is_major(d: Dictionary) -> bool:
	return d.heat >= 55 or d.source == "economy" or d.get("major", false)

## What the leader can say on one side of a debate.
func debate_lines(s: Dictionary, d: Dictionary, side: String) -> Array:
	var t = LINES.TOPIC_LINES.get(d.get("topic", d.id))
	if t: return t[side]
	if d.id.begins_with("issue:"): return story(s, d.id.trim_prefix("issue:")).lines[side]
	var pid: String = d.id.trim_prefix("ini:")
	if d.id.begins_with("ini:") and LINES.PROPOSAL_LINES.has(pid):
		var ini = by_id(INITIATIVES, pid)
		var own = "L" if float(ini.effects.shift[event_axis(ini)]) < 0 else "R"
		if side == own: return LINES.PROPOSAL_LINES[pid]
	return LINES.AXIS_LINES[d.axis][side]

## Join a debate on one side, with one of the lines from debate_lines().
func act_speak(s: Dictionary, id: String, side: String, line_index: int) -> Dictionary:
	var err = can_act(s, 0)
	if err: return {"ok": false, "text": err}
	var d = debate_by_id(s, id)
	if d == null: return {"ok": false, "text": "That debate is over."}
	if d.has("you"): return {"ok": false, "text": "You've already had your say on this one."}
	var major = is_major(d)
	var line: Dictionary = debate_lines(s, d, side)[line_index]
	spend_action(s, 0)
	d.you = {"side": side, "week": s.week, "quote": line.text}
	var pv = fan_preview(s, d, side)
	var sign = -1.0 if side == "L" else 1.0
	var before = snapshot_groups(s)
	var perceived_before: Dictionary = player_party(s).perceived.duplicate()
	var flips_before: int = s.flips.size()
	var delivery = deliver_line(s, line, not major)
	var heat: float = pv.heat
	var lean: float = pv.lean
	if delivery.outcome == "viral":
		heat *= 1.6; lean *= 1.5
	elif delivery.outcome == "gaffe":
		heat *= 1.3; lean = -lean * 0.6   # the clip helps the other side
	d.heat = clampf2(d.heat + heat, 0, 100)
	d.peak = maxf(d.peak, d.heat)
	d.lean = clampf2(d.lean + lean, -100, 100)
	_note_move(d, "player", "fan", side, s.week)
	shift_perceived(s, {d.axis: sign * 4})
	var key = side_key(d.axis, side)
	if pv.mine: add_ownership(s, "player", key, 0.05 if major else 0.03)
	# parties notice when you take up their cause, or attack it
	var other_key = side_key(d.axis, "R" if side == "L" else "L")
	for rp in rivals(s):
		if ownership_of(s, rp.id, other_key) > 0.05: change_relation(s, rp.id, -3 if major else -1.5, "you attacked their line on %s" % by_id(AXES, d.axis).issue.to_lower())
		elif ownership_of(s, rp.id, key) > 0.05: change_relation(s, rp.id, 1.5 if major else 0.75, "you backed their line on %s" % by_id(AXES, d.axis).issue.to_lower())
	s.spoke[key] = s.week
	figures_heard(s, d.axis, side)
	if d.id.begins_with("issue:"): heard_locally(s, d.id.trim_prefix("issue:"))   # a local story: its province hears you
	# people have heard it: the same cause, again and again, wins less each time (fades over months)
	if not s.has("heard"): s.heard = {}
	var k = (1.0 if major else 0.6) / (1.0 + 0.35 * float(s.heard.get(key, 0)))
	s.heard[key] = float(s.heard.get(key, 0)) + 1.0
	for pop in s.pops:
		var p: float = pop.pos[d.axis]
		var on_side = p < -15 if side == "L" else p > 15
		var against = p > 25 if side == "L" else p < -25
		if on_side:
			pop.aware.player = clampf2(pop.aware.player + (1 - pop.aware.player) * 0.025 * k, 0, 1)
			pop.goodwill.player = clampf2(pop.goodwill.player + 0.05 * k * pop.sal[d.axis], -2, 2)
		elif against: pop.goodwill.player = clampf2(pop.goodwill.player - 0.04 * k * pop.sal[d.axis] * (1 - shield_of(pop, "player")), -2, 2)
	record_statement(s, {"text": line.text, "title": d.title, "effects": {"shift": {d.axis: sign * 4}}, "tone": line.tone, "spoken": true})
	var helps = ""
	if not pv.mine and pv.owner != "" and pv.owner != "player": helps = " %s owns that side, so the attention helps them too." % party_of(s, pv.owner).short
	_log(s, "action", "%s: \"%s\"" % [d.title, line.text])
	return {"ok": true, "major": major, "title": d.title, "quote": line.text, "delivery": delivery, "extra": helps,
		"text": "You spoke on %s, for %s.%s" % [d.title.to_lower(), pv.side.to_lower(), helps],
		"before": perceived_before, "after": player_party(s).perceived.duplicate(),
		"flips": s.flips.slice(flips_before), "changes": group_changes(s, before)}

## Make a side you have spoken for one of your two causes.
func claim_block(s: Dictionary, axis: String, side: String) -> String:
	var key = side_key(axis, side)
	if s.signature.has(key): return "It's already one of your causes."
	if not s.spoke.has(key): return "Speak for it in a debate first."
	if s.signature.size() >= C.maxSignatureIssues: return "You already have %d causes. Drop one first." % int(C.maxSignatureIssues)
	return ""

func act_claim(s: Dictionary, axis: String, side: String) -> Dictionary:
	var block = claim_block(s, axis, side)
	if block: return {"ok": false, "text": block}
	var key = side_key(axis, side)
	s.signature.append(key)
	add_ownership(s, "player", key, 0.12)
	var text = "%s is now one of your causes. Every time you speak for it, your claim grows." % side_label(key)
	_log(s, "action", text)
	return {"ok": true, "text": text}

## Taken seriously moves a little each month toward what your support, your name and
## your party machine are worth (CONFIG.serious).
func serious_monthly(s: Dictionary) -> void:
	var cs: Dictionary = C.serious
	var w: Dictionary = cs.weights
	var sup: float = float(s.lastSupport.player) if s.lastSupport else 0.0
	var machine = 0.0
	for c in s.communities: machine += float(s.communities[c])
	var target: float = 100.0 * clampf2(float(w.support) * minf(1.0, sup / float(cs.supportFull)) + float(w.known) * national_awareness(s)
		+ float(w.machine) * minf(1.0, machine / float(cs.machineFull)), 0, 1)
	s.serious = clampf2(serious_of(s) + (target - serious_of(s)) * float(cs.rate), 0, 100)

## Minor issues: local stories that sit in the news for a few months.
func issues_monthly(s: Dictionary) -> void:
	_stories_come_back(s)
	s.issues = s.issues.filter(func(x): return s.week - int(x.week) < 5 * WEEKS_PER_MONTH)
	if s.issues.size() >= 5 or rand(s) > 0.5: return
	var pool = []
	var weights = []
	for it in ISSUES:
		if s.issues.any(func(x): return x.id == it.id): continue
		if debate_by_id(s, "issue:" + it.id) != null: continue
		if s.week - int(s.issueCooldown.get(it.id, -9999)) < 18 * WEEKS_PER_MONTH: continue
		if not in_season(s, it): continue
		var w = 1.0
		for k in it.get("when", {}):
			var cond: String = it.when[k]
			var n = float(cond.substr(1))
			if (s.world[k] < n) if cond[0] == "<" else (s.world[k] > n): w *= 3
		pool.append(it); weights.append(w)
	if pool.is_empty(): return
	var total = 0.0
	for w in weights: total += w
	var r = rand(s) * total
	for i in pool.size():
		r -= weights[i]
		if r <= 0 or i == pool.size() - 1:
			var st: Dictionary = story_turns_up(s, pool[i].id)
			s.issueCooldown[pool[i].id] = s.week
			push_news(s, merged({"kind": "issue", "quiet": true}, news("WORLD", "in_the_news", null, {"topic": st.title, "text": st.text})))
			return

## Stories that leave the news without ever becoming a debate were never solved: each
## comes back once, a few months later, in the same place, and costs a little trust.
func _stories_come_back(s: Dictionary) -> void:
	if not s.has("storyReturns"): s.storyReturns = []
	var places: Dictionary = s.get("storyPlace", {})
	for x in s.issues:
		if s.week - int(x.week) < 5 * WEEKS_PER_MONTH: continue
		var pl: Dictionary = places.get(x.id, {})
		if pl.get("back", false) or not issue_by_id(x.id).has("returns"): continue
		if debate_by_id(s, "issue:" + x.id) != null: continue
		if rand(s) > STORY_RETURN_CHANCE: continue
		var lo: int = STORY_RETURN_MONTHS[0]
		var hi: int = STORY_RETURN_MONTHS[1]
		s.storyReturns.append({"id": x.id, "week": s.week + (lo + int(floor(rand(s) * (hi - lo + 1)))) * WEEKS_PER_MONTH})
	var later = []
	for r in s.storyReturns:
		if int(r.week) > s.week: later.append(r); continue
		if s.issues.any(func(y): return y.id == r.id and s.week - int(y.week) < 5 * WEEKS_PER_MONTH): continue
		if debate_by_id(s, "issue:" + r.id) != null: continue
		var pl: Dictionary = places.get(r.id, {})
		if pl.is_empty(): continue
		pl.back = true
		s.issues = s.issues.filter(func(y): return y.id != r.id)
		s.issues.append({"id": r.id, "week": s.week, "district": pl.get("district", ""), "back": true})
		change_trust(s, -STORY_RETURN_TRUST)
		var st: Dictionary = story(s, r.id)
		push_news(s, merged({"kind": "issue", "quiet": true}, news("WORLD", "still_not_fixed", null, {"topic": st.title, "text": st.text})))
	s.storyReturns = later

func issue_by_id(id: String) -> Dictionary:
	return by_id(ISSUES, id)

## Things the player can put up for debate this month.
func raise_options(s: Dictionary) -> Array:
	var out = []
	for x in s.issues:
		var it = story(s, x.id)
		var fresh = s.week - int(x.week) < WEEKS_PER_MONTH * 2
		out.append({"kind": "issue", "ref": it.id, "title": it.title, "text": it.text, "axis": it.axis, "side": "",
			"region": it.region, "district": it.get("district", ""), "province": it.get("province", ""), "fresh": fresh, "chance": 0.75 if fresh else 0.5})
	for ind in METRIC_TOPIC:
		var t = by_id(TOPICS, METRIC_TOPIC[ind])
		if debate_by_id(s, t.id) != null: continue
		var bad = metric_badness(s, ind)
		if bad < 0.25: continue
		out.append({"kind": "metric", "ref": t.id, "metric": ind, "title": t.title, "text": t.text, "axis": t.axis, "side": "", "chance": 0.15 + 0.6 * bad})
	var gov = null
	for p in s.parties:
		if p.ruling: gov = p
	if gov:
		var axes: Array = ssort(AXES.duplicate(), func(x, y): return absf(gov.manifesto[y.id]) - absf(gov.manifesto[x.id])).slice(0, 3)
		for ax in axes:
			if debate_by_id(s, "gov:" + ax.id) != null: continue
			out.append({"kind": "gov", "ref": ax.id, "title": "The government's record on %s" % ax.issue.to_lower(),
				"text": "%s is %s on %s. Hold them to it, or hold it against them." % [gov.short, stance_name(ax.id, stance_of(gov.manifesto[ax.id])).to_lower(), ax.issue.to_lower()],
				"axis": ax.id, "side": "", "chance": 0.4})
	for id in s.agenda.offered:
		var ini = by_id(INITIATIVES, id)
		var ax = event_axis(ini)
		if ax == "": continue
		out.append({"kind": "proposal", "ref": id, "title": ini.title, "text": ini.text, "axis": ax,
			"side": "L" if float(ini.effects.shift[ax]) < 0 else "R", "chance": 0.55})
	return out

func raise_chance(s: Dictionary, opt: Dictionary, line: Dictionary) -> float:
	var tone_k = 1.25 if (line.get("sharp", false) or line.get("tone", "") == "provocative") else {"statesman": 0.85, "folksy": 1.0, "fiery": 1.1, "hopeful": 1.0}.get(line.get("tone", ""), 1.0)
	return clampf2(opt.chance * (0.6 + 0.5 * debate_reach(s)) * tone_k, 0.1, 0.95)

func raise_lines(s: Dictionary, opt: Dictionary, side: String) -> Array:
	if opt.kind == "topic" or opt.kind == "metric": return LINES.TOPIC_LINES[opt.ref][side]
	if opt.kind == "issue": return story(s, opt.ref).lines[side]
	if opt.kind == "proposal" and LINES.PROPOSAL_LINES.has(opt.ref): return LINES.PROPOSAL_LINES[opt.ref]
	return LINES.AXIS_LINES[opt.axis][side]

## Try to start a debate. It can fizzle: nobody picks it up.
func act_raise(s: Dictionary, opt: Dictionary, side: String, line_index: int) -> Dictionary:
	if s.agenda.done: return {"ok": false, "text": "You have already tried to start a debate this month."}
	var err = can_act(s, 0)
	if err: return {"ok": false, "text": err}
	spend_action(s, 0)
	s.agenda.done = true
	var line: Dictionary = raise_lines(s, opt, side)[line_index]
	var before = snapshot_groups(s)
	var perceived_before: Dictionary = player_party(s).perceived.duplicate()
	var flips_before: int = s.flips.size()
	var delivery = deliver_line(s, line)
	var chance = raise_chance(s, opt, line)
	if delivery.outcome == "viral": chance = 1.0
	elif delivery.outcome == "gaffe": chance *= 0.5
	var caught = rand(s) < chance
	var sign = -1.0 if side == "L" else 1.0
	shift_perceived(s, {opt.axis: sign * 4})
	s.spoke[side_key(opt.axis, side)] = s.week
	figures_heard(s, opt.axis, side)
	if opt.kind == "issue": heard_locally(s, opt.ref)
	record_statement(s, {"text": line.text, "title": opt.title, "effects": {"shift": {opt.axis: sign * 4}}, "tone": line.tone, "spoken": true})
	var text = ""
	if caught:
		var heat = 30 + 15 * debate_reach(s) + (15 if delivery.outcome == "viral" else 0)
		var lean = sign * (35 if delivery.outcome != "gaffe" else -10)
		var id = {"proposal": "ini:", "issue": "issue:", "gov": "gov:"}.get(opt.kind, "") + opt.ref
		var d = open_debate(s, id, opt.axis, opt.title, opt.text, "player", heat, lean)
		d.topic = opt.ref if opt.kind in ["topic", "metric"] else id
		if opt.kind == "issue": s.issues = s.issues.filter(func(x): return x.id != opt.ref)
		_note_move(d, "player", "start", side, s.week)
		d.you = {"side": side, "week": s.week, "quote": line.text}   # starting it was your statement
		if opt.kind == "proposal": _launch_proposal(s, opt.ref)
		text = "It caught on. Everyone is arguing about %s, and you started it." % opt.title.to_lower()
	else:
		for pop in s.pops: pop.aware.player = clampf2(pop.aware.player + (1 - pop.aware.player) * 0.005, 0, 1)
		text = "Nobody picked it up. The papers ran it on page eleven, under the weather."
	_log(s, "initiative", "Tried to start a debate on %s: %s" % [opt.title.to_lower(), "it caught on." if caught else "it fizzled."])
	return {"ok": true, "caught": caught, "title": opt.title, "quote": line.text, "delivery": delivery, "text": text, "extra": text,
		"before": perceived_before, "after": player_party(s).perceived.duplicate(),
		"flips": s.flips.slice(flips_before), "changes": group_changes(s, before)}

## A proposal that caught on: its consequences start rolling.
func _launch_proposal(s: Dictionary, id: String) -> void:
	var ini = by_id(INITIATIVES, id)
	var fx: Dictionary = ini.effects.duplicate(true)
	fx.erase("shift")   # the stance change came with the words
	apply_effects(s, fx)
	for sd in ini.get("seeds", []):
		var lo = int(sd.months[0])
		var hi = int(sd.months[1])
		s.scheduled.append({"id": sd.event, "week": s.week + (lo + int(floor(rand(s) * (hi - lo + 1)))) * WEEKS_PER_MONTH})
	s.flags["initiative:" + id] = s.week
	s.agenda.used.append(id)


# ---------- The major crisis ----------
func crisis_odds(s: Dictionary) -> Dictionary:
	var weights = []
	var total = 0.0
	for c in CRISES:
		var b = clampf2(float(s.crisisPressure.get(c.id, 0)) / C.crisisBoostAt, 0, C.crisisBoostMax)
		weights.append(1 + b); total += 1 + b
	var out = {}
	for i in CRISES.size(): out[CRISES[i].id] = weights[i] / total
	return out

func start_crisis(s: Dictionary) -> void:
	if s.crisis: return
	var odds = crisis_odds(s)
	var r = rand(s)
	var id: String = CRISES[-1].id
	for cc in CRISES:
		r -= odds[cc.id]
		if r <= 0:
			id = cc.id; break
	var c = by_id(CRISES, id)
	s.crisis = {"id": id, "odds": odds[id], "start": s.week, "phase": 0}
	apply_effects(s, merged(c.onStart, {"fromNews": true, "awareness": 0}))
	for i in c.phases.size():
		var p: Dictionary = c.phases[i]
		if i == 0: queue_event(s, p.event)
		else: s.scheduled.append({"id": p.event, "week": s.week + int(p.month) * WEEKS_PER_MONTH})
	_log(s, "crisis", "Crisis: %s." % c.name)

func crisis_blames_you(s: Dictionary) -> bool:
	return s.crisis != null and s.crisis.odds > C.crisisBlameFrom

func _crisis_hook(s: Dictionary) -> void:
	if s.crisis: return
	if not s.has("crisisMonth"):
		var a = int(C.crisisMonths[0])
		var b = int(C.crisisMonths[1])
		s.crisisMonth = a + int(floor(rand(s) * (b - a + 1)))
	if s.week / WEEKS_PER_MONTH >= s.crisisMonth: start_crisis(s)

# ---------- Voice: groups, the record, delivery (voice.js) ----------
func snapshot_groups(s: Dictionary) -> Array:
	var ctx = score_context(s)
	var sup = []
	for p in s.pops: sup.append(pop_support(s, p, null, ctx).player)
	var out = []
	for g in FEEDBACK_GROUPS:
		var size = 0.0
		var v = 0.0
		for i in s.pops.size():
			if matches(s.pops[i], g.who):
				size += s.pops[i].size
				v += s.pops[i].size * sup[i]
		out.append(v / size if size else 0.0)
	return out

func group_changes(s: Dictionary, before: Array) -> Array:
	var after = snapshot_groups(s)
	var list = []
	for i in FEEDBACK_GROUPS.size():
		var d: float = (after[i] - before[i]) * 100
		if absf(d) >= 0.15: list.append({"label": FEEDBACK_GROUPS[i].label, "delta": d})
	return ssort(list, func(a, b): return absf(b.delta) - absf(a.delta))

func record_statement(s: Dictionary, o: Dictionary) -> void:
	var rec: Dictionary = s.record
	var week: int = s.week
	var text: String = o.text
	var fx: Dictionary = o.get("effects", {})
	var spoken: bool = o.get("spoken", true)
	var statement: bool = o.get("statement", true)
	rec.quotes.append({"week": week, "text": text, "title": o.get("title", ""), "tone": o.get("tone"), "spoken": spoken, "statement": statement, "shift": fx.get("shift", {})})
	if statement: _hypocrisy(s, fx.get("shift", {}))
	if fx.get("blame"): rec.blamed.append({"week": week, "group": fx.blame, "text": text})
	for g in fx.get("goodwill", []):
		if g.amt <= -0.8 and g.get("who", {}).get("nationality") and not fx.get("blame"):
			rec.blamed.append({"week": week, "group": describe_who(g.who), "text": text})
	var takes_position: bool = statement and fx.get("shift", {}).size() > 0
	if not takes_position: return
	for g in fx.get("goodwill", []):
		var key = describe_who(g.get("who"))
		if g.amt <= -0.3:
			var found = -1
			for i in rec.promises.size():
				if rec.promises[i].key == key and week - rec.promises[i].week < 72:
					found = i; break
			if found >= 0:
				var p: Dictionary = rec.promises[found]
				rec.betrayed.append({"group": key, "promised": p.text, "promisedSpoken": p.spoken, "promisedWeek": p.week, "now": text, "nowSpoken": spoken, "week": week})
				rec.promises.remove_at(found)
				for pop in s.pops:
					if matches(pop, g.get("who")): pop.goodwill.player = clampf2(pop.goodwill.player - 0.15, -2, 2)
		if g.amt >= 0.35: rec.promises.append({"key": key, "week": week, "text": text, "spoken": spoken})

## Pairs of statements that pulled the same issue in opposite directions.
func contradictions(s: Dictionary) -> Array:
	var q: Array = s.record.quotes.filter(func(x): return x.get("statement", true) != false)
	var all = []
	for i in q.size():
		for j in range(i + 1, q.size()):
			for ax in q[i].shift:
				var a: float = q[i].shift[ax]
				var b: float = float(q[j].shift.get(ax, 0))
				if absf(a) >= 8 and absf(b) >= 8 and signf(a) != signf(b) and q[j].week - q[i].week >= 12:
					var spoken = int(q[i].get("spoken", true) != false) + int(q[j].get("spoken", true) != false)
					all.append({"axis": ax, "first": q[i], "second": q[j], "fi": i, "si": j, "size": absf(a) + absf(b) + spoken * 6})
	all = ssort(all, func(x, y): return y.size - x.size)
	var used = {}
	var axes = {}
	var out = []
	for pass_first in [true, false]:
		for c in all:
			if used.has(c.fi) or used.has(c.si): continue
			if pass_first and axes.has(c.axis): continue
			out.append(c); used[c.fi] = true; used[c.si] = true; axes[c.axis] = true
	return out

## quick: a line in a smaller debate. No viral clip or gaffe; it mostly
## shapes your speaking style, and groups react less.
## Charisma is harder to gain the more of it you have: half speed at 75, a crawl past 90.
func gain_charisma(player: Dictionary, d: float) -> void:
	player.charisma = clampf2(player.charisma + d * clampf2((100.0 - player.charisma) / 50.0, 0.05, 1.0), 10, 100)

func deliver_line(s: Dictionary, line: Dictionary, quick := false) -> Dictionary:
	var player = player_party(s)
	# a sharp line: the provocative edge on a style (its voice still counts as that style).
	# An old "provocative" line counts as a sharp fiery one.
	var sharp: bool = line_sharp(line)
	var tone: String = line_style(line)
	var risk: float = line.risk if line.has("risk") and line.risk != null else float(TONE_RISK.get("provocative" if sharp else tone, 0.2))
	var r = rand(s)
	var charm: float = player.charisma / 100.0
	var outcome = "normal"
	if quick: pass
	elif r < risk * (0.3 + charm * 0.3): outcome = "viral"     # charm helps, but a risky line stays risky
	elif r > 1 - risk * (0.5 - charm * 0.2): outcome = "gaffe"
	var dc: Dictionary = C.get("delivery", {})
	var pos = float(dc.get("viralPos", 2.0)) if outcome == "viral" else (float(dc.get("gaffePos", 0.3)) if outcome == "gaffe" else 1.0)   # viral: its good effects hit hard; a gaffe drowns them out
	var neg = float(dc.get("gaffeNeg", 1.8)) if outcome == "gaffe" else (float(dc.get("viralNeg", 1.3)) if outcome == "viral" else 1.0)
	var press: float = 1.0 - (float(C.upkeep.get("pressSoften", 0.25)) if s.get("pressOffice", false) else 0.0)   # the press office softens a gaffe
	if outcome == "gaffe": neg *= press
	var reacts: Array = TONES[tone].react.duplicate()
	if sharp:   # the edge: half the style's own reactions, all of the provocative ones
		reacts = reacts.map(func(g): return merged(g, {"amt": float(g.amt) * 0.5}))
		reacts.append_array(TONES.get("provocative", {}).get("react", []))
	reacts.append_array(line.get("react", []))
	var qk = 0.4 if quick else 1.0
	var scaled = reacts.map(func(g): return {"who": g.get("who"), "amt": g.amt * qk * (pos if g.amt > 0 else neg)})
	apply_effects(s, {"goodwill": scaled, "awareness": 0.06 if outcome == "viral" else (0.035 if outcome == "gaffe" else 0.01)})
	if outcome == "viral": change_serious(s, float(C.serious.viral))
	elif outcome == "gaffe": change_serious(s, float(C.serious.gaffe))
	# a sharp line that lands gets you noticed, less so when you have been at it lately
	if sharp:
		var pc: Dictionary = C.serious.get("provocative", {})
		var fresh: float = 1.0 / (1.0 + float(pc.get("fatigue", 0.6)) * float(s.get("outrage", 0.0)))
		if outcome != "gaffe":
			change_serious(s, float(pc.get("serious", 1.5)) * fresh * qk)
			apply_effects(s, {"awareness": float(pc.get("aware", 0.025)) * fresh * qk})
		s.outrage = float(s.get("outrage", 0.0)) + 1.0
		s.record.outrages = int(s.record.get("outrages", 0)) + 1   # remembered for good: the demagogue, the clean image
	for g in scaled:
		for pop in s.pops:
			if matches(pop, g.who): pop.leader.player = clampf2(pop.leader.player + g.amt * 0.35, -2, 2)
	for k in s.style: s.style[k] *= C.styleMemory
	s.style[tone] = float(s.style.get(tone, 0)) + 1
	s.sharp = float(s.get("sharp", 0.0)) * C.styleMemory + (1.0 if sharp else 0.0)   # how often you've been sharp lately
	var total = dsum(s.style)
	var entries = []
	for k in s.style: entries.append([k, s.style[k]])
	var top: Array = ssort(entries, func(a, b): return b[1] - a[1])[0]
	var share: float = top[1] / total
	var style_note = ""
	if total > 3 and tone == top[0] and share > 0.45:
		gain_charisma(player, 0.25 if quick else 0.5)
		style_note = "It sounded like you. People are starting to recognise your voice."
	elif total > 3 and tone != top[0] and share > 0.5:
		player.charisma = clampf2(player.charisma - 0.6, 10, 100)
		style_note = "It didn't sound like you. Some voters wonder who the real you is."
	media_hear(s, "provocative" if sharp else tone, outcome, 0.5 if quick else 1.0)
	if outcome == "viral":
		s.record.memes += 1
		gain_charisma(player, float(dc.get("viralCharisma", 2.0)))
	if outcome == "gaffe":
		s.record.gaffes += 1
		player.charisma = clampf2(player.charisma - float(dc.get("gaffeCharisma", 2.5)) * press, 10, 100)
		# a gaffe is remembered: everyone thinks a little less of the leader, not only the offended
		for pop in s.pops:
			pop.leader.player = clampf2(pop.leader.player - float(dc.get("gaffeLeader", 0.04)) * press, -2, 2)
			pop.goodwill.player = clampf2(pop.goodwill.player - float(dc.get("gaffeGoodwill", 0.03)) * press * (1 - shield_of(pop, "player")), -2, 2)
	return {"outcome": outcome, "press": TONES["provocative" if sharp and TONES.has("provocative") else tone].press[outcome], "styleNote": style_note, "sharp": sharp}

## The style a line is said in (statesman, fiery, folksy, hopeful); an old "provocative" line is fiery.
## Is a line the sharp edge of its style (said to start a fight)?
func line_sharp(line: Dictionary) -> bool:
	return bool(line.get("sharp", false)) or line.get("tone", "") == "provocative"

func line_style(line: Dictionary) -> String:
	var t: String = String(line.get("tone", "statesman"))
	if t == "provocative": return "fiery"
	return t if TONES.has(t) else "statesman"
