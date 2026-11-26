## rules/coalition.gd — Forming a government after the election.
##
## Works on whichever parties won seats, however many. The talks run once, when the
## result is in, and are written down as a list of steps (s.result.coalition.log) that
## the coalition screen plays back; nothing is decided on screen.
##
## 1. A party with a majority of its own governs alone.
## 2. Every minimal majority (no member could leave and keep it) is listed; those
##    holding two enemies are crossed out.
## 3. The largest party tries first, approaching first the partners of the majority it
##    likes best (most of it allies, then the fewest seats to share), then the rest:
##    enemies are turned away, allies join for their fair share of the cabinet (by
##    seats), neutral parties want more, and walk away if the party forming the
##    government can't afford it. Then the second largest tries, then the third.
## 4. If no one manages, the party the others like least is shut out, the remaining
##    enmities count as neutral, and the talks start again. If that fails too, there
##    is no government.
## Settings and texts: data/coalition.json.
extends "res://scripts/rules/campaign.gd"

## A text from data/coalition.json TEXT. `you`: the player's party is the one it is
## about, so use the "<key>_you" version when there is one.
func coalition_text(key: String, fill := {}, you := false) -> String:
	var t: Dictionary = COALITION.get("TEXT", {})
	if you and t.has(key + "_you"): key += "_you"
	return String(t.get(key, key)).format(fill)

func _cset(key: String, default):
	return COALITION.get(key, default)

## "ally", "neutral" or "enemy". `relaxed`: after a shut-out, enemies count as neutral.
func party_stance(s: Dictionary, a: String, b: String, relaxed := false) -> String:
	var r: float = party_relation(s, a, b)
	var st: Dictionary = _cset("STANCE", {})
	if r >= float(st.get("ally", 20)): return "ally"
	if r <= float(st.get("enemy", -20)) and not relaxed: return "enemy"
	return "neutral"

## Why two parties are enemies, in a few words.
func enemy_reason(s: Dictionary, a: String, b: String) -> String:
	var pa = party_of(s, a)
	var pb = party_of(s, b)
	var names = {"a": pa.get("short", "You") if not pa.isPlayer else "You", "b": pb.get("short", "You") if not pb.isPlayer else "You"}
	if pa.isPlayer or pb.isPlayer:
		var other: String = b if pa.isPlayer else a
		var notes: Array = s.get("relationNotes", {}).get(other, []).filter(func(n): return float(n.delta) < 0)
		if notes.size(): return coalition_text("enemies", names) + " (%s)" % notes[-1].text
	var grudge: String = pair_grudge(s, a, b) if not (pa.isPlayer or pb.isPlayer) else ""
	if grudge != "": return coalition_text("enemies", names) + " (%s)" % grudge
	var diffs: Array = biggest_differences(s, pa, pb, 2)
	var issues: Array = diffs.map(func(x): return String(by_id(AXES, x.ax).issue).to_lower())
	return coalition_text("enemies", names) + " (" + coalition_text("enemies_policy", {"issues": " and ".join(issues)}) + ")"

func _short(s: Dictionary, id: String) -> String:
	var p = party_of(s, id)
	return "You" if p.isPlayer else String(p.get("short", p.get("name", id)))

## Every minimal majority among `ids`: a list of id lists, largest first.
func minimal_majorities(seats: Dictionary, ids: Array, need: int) -> Array:
	var n: int = mini(ids.size(), 16)
	var out = []
	for mask in range(1, 1 << n):
		var members = []
		var tot = 0
		for i in n:
			if mask & (1 << i):
				members.append(ids[i]); tot += int(seats[ids[i]])
		if tot < need: continue
		var minimal = true
		for m in members:
			if tot - int(seats[m]) >= need: minimal = false; break
		if minimal: out.append(members)
	return ssort(out, func(a, b): return _seats_of(seats, b) - _seats_of(seats, a))

func _seats_of(seats: Dictionary, members: Array) -> int:
	var t = 0
	for m in members: t += int(seats[m])
	return t

func _enemy_pair(s: Dictionary, members: Array, relaxed: bool) -> Array:
	for i in members.size():
		for j in range(i + 1, members.size()):
			if party_stance(s, members[i], members[j], relaxed) == "enemy": return [members[i], members[j]]
	return []

func _cabinet_total() -> float:
	var t = 0.0
	for m in _cset("MINISTRIES", []): t += float(m.weight)
	return t

var _asks = null      # your answers when a party asks you to join ("f:round" -> {accept, ministries}); null: the talks run by themselves
var _round := 1
var _ask_pause = null # set when the talks stop to ask you

## Runs the talks and returns {log, government, outcome}. `seats`: party id -> seats.
## `asks`: when given, the talks stop the first time a party asks you to join and you
## haven't answered yet (the result is then {pending: true, ask: {...}}); see coalition_answer.
func form_government(s: Dictionary, seats: Dictionary = {}, asks = null) -> Dictionary:
	_asks = asks
	_ask_pause = null
	if seats.is_empty(): seats = s.result.seats.national
	var need: int = int(int(C.seats) / 2) + 1
	var ids: Array = ssort(seats.keys().filter(func(id): return int(seats[id]) > 0), func(a, b): return int(seats[b]) - int(seats[a]))
	var log = []
	var gov = null
	log.append({"t": "start", "seats": seats.duplicate(), "need": need, "parties": ids.duplicate()})
	if ids.size() and int(seats[ids[0]]) >= need:
		gov = {"members": [ids[0]], "cabinet": _share_cabinet(s, {ids[0]: 1.0}, ids[0]), "alone": true}
		log.append({"t": "majority", "party": ids[0]})
	var excluded = []
	var relaxed = false
	var rounds = 0
	var alive = []
	var in_play: Array = ids
	while gov == null and rounds < 2:
		rounds += 1
		_round = rounds
		in_play = ids.filter(func(id): return not excluded.has(id))
		var combos: Array = minimal_majorities(seats, in_play, need)
		log.append({"t": "combos", "list": combos, "round": rounds})
		alive = []
		for i in combos.size():
			var pair: Array = _enemy_pair(s, combos[i], relaxed)
			if pair.size(): log.append({"t": "cross", "i": i, "pair": pair, "why": enemy_reason(s, pair[0], pair[1])})
			else: alive.append(combos[i])
		var tries: Array = in_play.slice(0, int(_cset("MAX_FORMATEURS", 3)))
		for f in tries:
			gov = _try_formateur(s, f, in_play, seats, need, alive, relaxed, log)
			if _ask_pause != null:   # a party asks you to join: wait for your answer
				return {"log": log, "government": null, "excluded": excluded, "pending": true, "ask": _ask_pause, "asks": asks, "seats": seats.duplicate()}
			if gov: break
		if gov == null and rounds == 1 and in_play.size() > 2:
			var worst = ""
			var low = INF
			for id in in_play:
				var tot = 0.0
				for o in in_play:
					if o != id: tot += party_relation(s, id, o)
				if tot < low: low = tot; worst = id
			excluded.append(worst)
			relaxed = bool(_cset("SHUTOUT_RELAXES", true))
			log.append({"t": "shutout", "party": worst, "why": coalition_text("shutout", {"p": party_of(s, worst).get("name", _short(s, worst))})})
		elif gov == null: break
	# talks broke down only because partners asked too much, though a majority without
	# enemies is there: they settle, each for what its seats are worth
	if gov == null and bool(_cset("COMPROMISE", true)) and alive.size():
		gov = _compromise(s, in_play, seats, alive, relaxed, log)
	if gov == null: log.append({"t": "deadlock", "why": coalition_text("deadlock")})
	else: log.append({"t": "government", "members": gov.members, "cabinet": gov.cabinet, "pm": _pm_of(gov.cabinet)})
	var out = {"log": log, "government": gov, "excluded": excluded}
	out.outcome = coalition_outcome(s, out, seats, ids)
	return out

## The fallback when every party forming a government failed but a majority without
## enemies exists: the largest party that is part of one takes the majority it likes
## best, and every member gets its fair share by seats, nothing on top.
func _compromise(s: Dictionary, in_play: Array, seats: Dictionary, alive: Array, relaxed: bool, log: Array):
	for f in in_play:
		var mine: Array = alive.filter(func(c): return c.has(f))
		if mine.is_empty(): continue
		var ranked: Array = ssort(mine, func(a, b):
			var d: float = _comfort(s, f, b, seats, relaxed) - _comfort(s, f, a, seats, relaxed)
			if absf(d) > 0.001: return d
			return _seats_of(seats, a) - _seats_of(seats, b))
		var members: Array = [f]
		for p in in_play:
			if p != f and ranked[0].has(p): members.append(p)
		var premium = {}
		for p in members:
			if p != f: premium[p] = 0.0
		var ent: Dictionary = _entitlements(seats, f, premium)
		var cab: Array = _share_cabinet(s, ent, _pm_holder(seats, f, ent))
		var names: Array = members.map(func(m): return "you" if party_of(s, m).isPlayer else _short(s, m))
		log.append({"t": "compromise", "party": f, "members": members,
			"why": coalition_text("compromise", {"parties": and_list(names)})})
		return {"members": members, "cabinet": cab, "formateur": f, "shares": ent, "compromise": true}
	return null

func _pm_of(cabinet: Array) -> String:
	for c in cabinet:
		if c.ministry == "pm": return c.party
	return ""

## The party `f` tries to build a majority, approaching the others from the largest down.
func _try_formateur(s: Dictionary, f: String, in_play: Array, seats: Dictionary, need: int, alive: Array, relaxed: bool, log: Array):
	log.append({"t": "formateur", "party": f})
	var mine: Array = alive.filter(func(c): return c.has(f))
	if mine.is_empty():
		log.append({"t": "fail", "party": f, "why": coalition_text("no_combination", {"f": _short(s, f)}, party_of(s, f).isPlayer)})
		return null
	var give_max: float = float(_cset("FORMATEUR_GIVES", 0.4))
	var members = [f]
	var premium = {}   # partner -> share of the cabinet it asks for beyond its seats (0..1)
	for p in approach_order(s, f, in_play, seats, mine, relaxed):
		if p == f: continue
		if _seats_of(seats, members) >= need: break
		var st: String = party_stance(s, f, p, relaxed)
		var step = {"t": "approach", "f": f, "p": p, "stance": st}
		if st == "enemy":
			step.verdict = "enemy"; step.why = enemy_reason(s, f, p)
			log.append(step); continue
		var clash: Array = members.filter(func(m): return m != f and party_stance(s, m, p, relaxed) == "enemy")
		if clash.size():
			step.verdict = "enemy"; step.why = enemy_reason(s, clash[0], p)
			log.append(step); continue
		# is there still a majority without enemies that has these members and this party?
		var with_p: Array = members + [p]
		if not mine.any(func(c): return with_p.all(func(m): return c.has(m))):
			step.verdict = "skip"; step.why = ""
			log.append(step); continue
		var extra: float = float(_cset("NEUTRAL_PREMIUM", 0.08)) if st == "neutral" else 0.0
		if party_of(s, p).isPlayer and _asks != null:   # you decide what you ask for
			var key: String = "%s:%d" % [f, _round]
			var dec = _asks.get(key)
			if dec == null:
				_ask_pause = _make_ask(s, f, members, mine, seats, alive, key)
				return null
			if not dec.accept:
				step.verdict = "refuse"; step.why = String(dec.why)
				log.append(step); continue
			premium[p] = extra
			members.append(p)
			step.verdict = "join"; step.why = String(dec.why)
			log.append(step)
			continue
		var trial: Dictionary = premium.duplicate()
		trial[p] = extra
		var ent: Dictionary = _entitlements(seats, f, trial)
		var f_fair: float = float(seats[f]) / float(_seats_of(seats, with_p))
		if ent[f] < f_fair * (1.0 - give_max):
			step.verdict = "refuse"; step.why = coalition_text("neutral_refuses", {"f": "you" if party_of(s, f).isPlayer else _short(s, f)}, party_of(s, p).isPlayer)
			log.append(step); continue
		premium[p] = extra
		members.append(p)
		step.verdict = "join"
		step.why = coalition_text("ally" if st == "ally" else "neutral_deal", {}, party_of(s, p).isPlayer)
		log.append(step)
	if _seats_of(seats, members) < need:
		log.append({"t": "fail", "party": f, "why": coalition_text("short", {"n": _seats_of(seats, members), "need": need})})
		return null
	var ent: Dictionary = _entitlements(seats, f, premium)
	var cab: Array = _share_cabinet(s, ent, _pm_holder(seats, f, ent))
	var mine_dec = _asks.get("%s:%d" % [f, _round]) if _asks != null else null
	if members.has("player") and mine_dec != null and mine_dec.accept:   # you got exactly what you asked for
		var others = {}
		for k in ent:
			if k != "player": others[k] = ent[k]
		cab = []
		for m in _cset("MINISTRIES", []):
			if mine_dec.ministries.has(m.id): cab.append({"ministry": m.id, "name": m.name, "party": "player", "weight": float(m.weight)})
		cab.append_array(_share_cabinet(s, others, "" if mine_dec.ministries.has("pm") else f, mine_dec.ministries))
	# the Prime Minister's office went to a partner: say so on that partner's step
	var pm: String = _pm_of(cab)
	if pm != f:
		for i in range(log.size() - 1, -1, -1):
			if log[i].t == "approach" and log[i].p == pm and log[i].verdict == "join":
				log[i].why = coalition_text("neutral_pm", {}, party_of(s, pm).isPlayer); break
	return {"members": members, "cabinet": cab, "formateur": f, "shares": ent}

## The order in which `f` approaches the others: first the partners of the majority it
## likes best (the most of it made of itself and its allies, then the fewest seats it
## must share), largest first; then everyone else, largest first.
func approach_order(s: Dictionary, f: String, in_play: Array, seats: Dictionary, mine: Array, relaxed: bool) -> Array:
	var ranked: Array = ssort(mine, func(a, b):
		var d: float = _comfort(s, f, b, seats, relaxed) - _comfort(s, f, a, seats, relaxed)
		if absf(d) > 0.001: return d
		return _seats_of(seats, a) - _seats_of(seats, b))
	var out = []
	if ranked.size():
		for p in in_play:
			if p != f and ranked[0].has(p): out.append(p)
	for p in in_play:
		if p != f and not out.has(p): out.append(p)
	return out

## How much of a majority is made of `f` and its allies (0..1).
func _comfort(s: Dictionary, f: String, members: Array, seats: Dictionary, relaxed: bool) -> float:
	var mine = 0
	for m in members:
		if m == f or party_stance(s, f, m, relaxed) == "ally": mine += int(seats[m])
	return float(mine) / float(maxi(1, _seats_of(seats, members)))

## Each member's share of the cabinet: its share of the coalition's seats, plus
## what neutral partners asked for on top, paid by the party forming the government.
func _entitlements(seats: Dictionary, f: String, premium: Dictionary) -> Dictionary:
	var members: Array = [f] + premium.keys()
	var tot: float = float(maxi(1, _seats_of(seats, members)))
	var out = {}
	var paid = 0.0
	for m in premium:
		out[m] = float(seats[m]) / tot + float(premium[m]); paid += float(premium[m])
	out[f] = float(seats[f]) / tot - paid
	return out

## Who becomes Prime Minister: the party forming the government, unless a partner is
## bigger than it (the post is then that partner's price) or it can no longer afford
## the post with what it has left.
func _pm_holder(seats: Dictionary, f: String, ent: Dictionary) -> String:
	var biggest: String = f
	for m in ent:
		if int(seats[m]) > int(seats[biggest]): biggest = m
	if biggest != f: return biggest
	var pm_share = 0.0
	for m in _cset("MINISTRIES", []):
		if m.id == "pm": pm_share = float(m.weight) / _cabinet_total()
	if float(ent[f]) >= pm_share * 0.75: return f
	var best: String = f
	for m in ent:
		if float(ent[m]) > float(ent[best]): best = m
	return best

## Shares out the ministries by entitlement (party -> share of the cabinet). The
## Prime Minister's office goes to `pm_to`; the rest are picked in turns.
func _share_cabinet(s: Dictionary, ent: Dictionary, pm_to := "", taken := []) -> Array:
	var left: Array = _cset("MINISTRIES", []).duplicate(true).filter(func(m): return not taken.has(m.id))
	var out = []
	if pm_to == "": pm_to = ent.keys()[0]
	var picks = {}
	for k in ent: picks[k] = 0
	for i in left.size():
		if left[i].id == "pm":
			out.append({"ministry": "pm", "name": left[i].name, "party": pm_to, "weight": float(left[i].weight)})
			picks[pm_to] += 1
			left.remove_at(i)
			break
	# turns go by share, as in seat counting (share / (posts taken + 1)); on its turn
	# a party takes the post worth most to it: its weight, more if it serves its issues
	while left.size():
		var who = ""
		for k in ent:
			if who == "" or float(ent[k]) / (picks[k] + 1) > float(ent[who]) / (picks[who] + 1): who = k
		var best = 0
		var score = -INF
		for i in left.size():
			var sc: float = float(left[i].weight) * (0.5 + _ministry_want(s, who, left[i]))
			if sc > score: score = sc; best = i
		var m: Dictionary = left[best]
		left.remove_at(best)
		out.append({"ministry": m.id, "name": m.name, "party": who, "weight": float(m.weight)})
		picks[who] += 1
	return out

## How much a party cares about the issues a ministry serves (0..1): its strongest position on them.
func _ministry_want(s: Dictionary, pid: String, m: Dictionary) -> float:
	var p = party_of(s, pid)
	if p == null: return 0.0
	var best = 0.0
	for ax in m.get("axes", []):
		best = maxf(best, absf(float(p.perceived.get(ax, 0))) / 100.0)
	return best

## How the election ended for the player: "no_seats", "majority", "leads" (largest
## party, leading the government), "pm" (Prime Minister without being the largest),
## "senior" (largest, governing, but the Prime Minister is a partner's), "partner", "robbed" (largest, shut out while others govern), "opposition", "deadlock".
func coalition_outcome(s: Dictionary, co: Dictionary, seats: Dictionary, ranking: Array) -> String:
	var me: String = player_party(s).id
	if int(seats.get(me, 0)) <= 0: return "no_seats"
	var gov = co.government
	var largest: bool = ranking.size() > 0 and ranking[0] == me
	if gov == null: return "deadlock"
	if gov.get("alone", false) and gov.members[0] == me: return "majority"
	if gov.members.has(me):
		if _pm_of(gov.cabinet) == me: return "leads" if largest else "pm"
		return "senior" if largest else "partner"
	return "robbed" if largest else "opposition"

# ---------- When you are the largest party: you negotiate ----------
## The talks wait for you (s.result.coalition.pending). Each round, every majority without
## enemies that includes you is an option. You offer ministries to each option's partners
## at once; they counter (a bloc of partners agrees its shares first, an abstraction);
## you make a final offer, which each accepts or rejects; then you form one of the
## governments that accepted, or force the next round, in which the party the others
## like least is shut out and the rest must get along. If that is you, the others govern.

## Opens the talks for you (instead of form_government): the majorities, crossed-out ones
## included, as the screen plays them; nothing decided yet.
func coalition_open(s: Dictionary, seats: Dictionary) -> Dictionary:
	var need: int = int(int(C.seats) / 2) + 1
	var ids: Array = ssort(seats.keys().filter(func(id): return int(seats[id]) > 0), func(a, b): return int(seats[b]) - int(seats[a]))
	var co = {"log": [{"t": "start", "seats": seats.duplicate(), "need": need, "parties": ids.duplicate()}], "government": null,
		"excluded": [], "pending": true, "round": 1, "relaxed": false, "need": need, "seats": seats.duplicate(), "ids": ids}
	_coalition_round_log(s, co)
	return co

func _coalition_in_play(co: Dictionary) -> Array:
	return co.ids.filter(func(id): return not co.excluded.has(id))

func _coalition_round_log(s: Dictionary, co: Dictionary) -> void:
	var combos: Array = minimal_majorities(co.seats, _coalition_in_play(co), int(co.need))
	co.log.append({"t": "combos", "list": combos, "round": int(co.round)})
	co.alive = []
	for i in combos.size():
		var pair: Array = _enemy_pair(s, combos[i], co.relaxed)
		if pair.size(): co.log.append({"t": "cross", "i": i, "pair": pair, "why": enemy_reason(s, pair[0], pair[1])})
		else: co.alive.append(combos[i])

## Your options this round: the majorities without enemies that include you, the ones
## most made of your allies first, then the fewest seats to share.
func coalition_options(s: Dictionary) -> Array:
	var co: Dictionary = s.result.coalition
	var mine: Array = co.get("alive", []).filter(func(c): return c.has("player"))
	return ssort(mine, func(a, b):
		var d: float = _comfort(s, "player", b, co.seats, co.relaxed) - _comfort(s, "player", a, co.seats, co.relaxed)
		if absf(d) > 0.001: return d
		return _seats_of(co.seats, a) - _seats_of(co.seats, b))

## A ministry as a party sees it: its weight, twice that for one of its favourites.
func _ministry_value(s: Dictionary, pid: String, m: Dictionary) -> float:
	return float(m.weight) * (float(_cset("FAVOURITE_WORTH", 2.0)) if favourite_ministries(s, pid).has(m.get("id", "")) else 1.0)

## A party's two favourite ministries: set in content.json (PARTIES "ministries"), or the
## two (not the Prime Minister's office) that serve its strongest issues.
func favourite_ministries(s: Dictionary, pid: String) -> Array:
	var p = by_id(PARTIES, pid)
	if p and p.has("ministries"): return p.ministries
	var ms: Array = _cset("MINISTRIES", []).filter(func(m): return m.id != "pm")
	ms = ssort(ms, func(a, b):
		var d: float = _ministry_want(s, pid, b) - _ministry_want(s, pid, a)
		if absf(d) > 0.001: return d
		return float(b.weight) - float(a.weight))
	return ms.slice(0, 2).map(func(m): return m.id)

func _ministry(id: String) -> Dictionary:
	for m in _cset("MINISTRIES", []):
		if m.id == id: return m
	return {}

## What each partner in `combo` needs, as a share of the cabinet's weight: its share of the
## coalition's seats, and more if it is only neutral toward you. `ask`: what it opens with.
func coalition_needs(s: Dictionary, combo: Array) -> Dictionary:
	var co: Dictionary = s.result.coalition
	var tot: float = float(_seats_of(co.seats, combo))
	var out = {}
	for p in combo:
		if p == "player": continue
		var fair: float = float(co.seats[p]) / tot
		var st: String = party_stance(s, "player", p, co.relaxed)
		var need: float = fair + (float(_cset("NEUTRAL_PREMIUM", 0.08)) if st == "neutral" else 0.0)
		out[p] = {"need": need * _cabinet_total(), "ask": need * float(_cset("OPENING_ASK", 1.15)) * _cabinet_total(), "stance": st}
	return out

## What an offer (ministry id -> party id) is worth to party `pid`.
func offer_value(s: Dictionary, offer: Dictionary, pid: String) -> float:
	var v = 0.0
	for mid in offer:
		if offer[mid] == pid: v += _ministry_value(s, pid, _ministry(mid))
	return v

## A first offer: every member's fair share by seats, the Prime Minister's office yours.
func coalition_default_offer(s: Dictionary, combo: Array) -> Dictionary:
	var co: Dictionary = s.result.coalition
	var tot: float = float(_seats_of(co.seats, combo))
	var ent = {}
	for p in combo: ent[p] = float(co.seats[p]) / tot
	var out = {}
	for c in _share_cabinet(s, ent, "player"): out[c.ministry] = c.party
	return out

## The partners' answer: they keep what you offered and take, from your ministries (never
## the Prime Minister's office), the ones worth most to them until they have what they ask.
func coalition_counter(s: Dictionary, combo: Array, offer: Dictionary) -> Dictionary:
	var counter: Dictionary = offer.duplicate()
	var needs: Dictionary = coalition_needs(s, combo)
	for p in ssort(needs.keys(), func(a, b): return int(s.result.coalition.seats[b]) - int(s.result.coalition.seats[a])):
		var guard = 0
		while offer_value(s, counter, p) < float(needs[p].ask) and guard < 20:
			guard += 1
			var best = ""
			var bv = -1.0
			for mid in counter:
				if counter[mid] != "player" or mid == "pm": continue
				var v: float = _ministry_value(s, p, _ministry(mid))
				if v > bv: bv = v; best = mid
			if best == "": break
			counter[best] = p
	return counter

## Your final offer: each partner accepts if it gets at least what it needs.
func coalition_verdict(s: Dictionary, combo: Array, offer: Dictionary) -> Dictionary:
	var needs: Dictionary = coalition_needs(s, combo)
	var short = []
	for p in needs:
		if offer_value(s, offer, p) + 0.001 < float(needs[p].need): short.append(p)
	return {"accepted": short.is_empty(), "short": short}

## You form the government with this option and offer. The talks are over.
func coalition_form(s: Dictionary, combo: Array, offer: Dictionary) -> void:
	var co: Dictionary = s.result.coalition
	var cab = []
	for m in _cset("MINISTRIES", []):
		cab.append({"ministry": m.id, "name": m.name, "party": offer.get(m.id, "player"), "weight": float(m.weight)})
	co.government = {"members": combo.duplicate(), "cabinet": cab, "formateur": "player"}
	co.log.append({"t": "government", "members": combo.duplicate(), "cabinet": cab, "pm": _pm_of(cab)})
	_coalition_close(s)

func _coalition_close(s: Dictionary) -> void:
	var co: Dictionary = s.result.coalition
	co.pending = false
	co.outcome = coalition_outcome(s, co, co.seats, co.ids)

## The party the others like least this round (the one a forced round shuts out).
func coalition_least_liked(s: Dictionary) -> String:
	var co: Dictionary = s.result.coalition
	var in_play: Array = _coalition_in_play(co)
	var worst = ""
	var low = INF
	for id in in_play:
		var tot = 0.0
		for o in in_play:
			if o != id: tot += party_relation(s, id, o)
		if tot < low: low = tot; worst = id
	return worst

## You reject every option. In the first round, the party the others like least is shut
## out and the rest must get along: if that is you, the others form a government without
## you. Otherwise (or in the second round) the others take their turn at forming one.
func coalition_force(s: Dictionary) -> void:
	var co: Dictionary = s.result.coalition
	if int(co.round) == 1 and _coalition_in_play(co).size() > 2:
		var worst: String = coalition_least_liked(s)
		co.excluded.append(worst)
		co.relaxed = bool(_cset("SHUTOUT_RELAXES", true))
		co.round = 2
		co.log.append({"t": "shutout", "party": worst, "why": coalition_text("shutout", {"p": party_of(s, worst).get("name", _short(s, worst))})})
		_coalition_round_log(s, co)
		if worst == "player": _coalition_others(s)
		return
	_coalition_others(s)

## The other parties try, largest first (you may still be asked to join as a partner).
func _coalition_others(s: Dictionary) -> void:
	var co: Dictionary = s.result.coalition
	var in_play: Array = _coalition_in_play(co)
	var gov = null
	for f in in_play.filter(func(id): return id != "player").slice(0, int(_cset("MAX_FORMATEURS", 3))):
		gov = _try_formateur(s, f, in_play, co.seats, int(co.need), co.get("alive", []), co.relaxed, co.log)
		if gov: break
	if gov == null and bool(_cset("COMPROMISE", true)) and co.get("alive", []).size():
		gov = _compromise(s, in_play.filter(func(id): return id != "player"), co.seats, co.alive.filter(func(c): return not c.has("player")), co.relaxed, co.log)
	if gov == null: co.log.append({"t": "deadlock", "why": coalition_text("deadlock")})
	else: co.log.append({"t": "government", "members": gov.members, "cabinet": gov.cabinet, "pm": _pm_of(gov.cabinet)})
	co.government = gov
	_coalition_close(s)


# ---------- When a party asks you to join ----------
## What a party forming a government offers you: the majority it aims at, the ministries
## a fair share by seats would give you, and whether it is desperate enough to hand you
## the Prime Minister's office (a coalition with you alone is its only way in, and the
## others could govern without it).
func _make_ask(s: Dictionary, f: String, members: Array, mine: Array, seats: Dictionary, alive: Array, key: String) -> Dictionary:
	var with_you: Array = members + ["player"]
	var aims: Array = mine.filter(func(c): return with_you.all(func(m): return c.has(m)))
	var combo: Array = aims[0] if aims.size() else with_you
	var tot: float = float(_seats_of(seats, combo))
	var ent = {}
	for p in combo: ent[p] = float(seats[p]) / tot
	var offer = []
	for c in _share_cabinet(s, ent, f):
		if c.party == "player": offer.append(c.ministry)
	var desperate: bool = mine.size() == 1 and mine[0].size() == 2 and mine[0].has("player") and alive.any(func(c): return not c.has(f))
	var st: String = party_stance(s, f, "player", false)
	var need: float = (float(seats.player) / tot + (float(_cset("NEUTRAL_PREMIUM", 0.08)) if st == "neutral" else 0.0)) * _cabinet_total()
	return {"f": f, "key": key, "combo": combo, "offer": offer, "desperate": desperate, "need": need, "round": _round}

## Would they take your demands (a list of ministry ids)? Up to a little more than your
## fair share, never the Prime Minister's office unless they are desperate, and then only
## if you ask for little else. They don't haggle.
func coalition_ask_verdict(s: Dictionary, ask: Dictionary, demands: Array) -> Dictionary:
	var v = 0.0
	for id in demands:
		if id != "pm": v += float(_ministry(id).get("weight", 0))
	var f: String = _short(s, ask.f)
	if demands.has("pm"):
		if not ask.desperate: return {"accept": false, "why": coalition_text("you_no_pm", {"f": f})}
		if v > float(ask.need) * float(_cset("PM_PRICE", 0.5)): return {"accept": false, "why": coalition_text("you_too_much", {"f": f})}
		return {"accept": true, "why": coalition_text("you_pm", {"f": f})}
	if v > float(ask.need) * float(_cset("DEMAND_SLACK", 1.1)): return {"accept": false, "why": coalition_text("you_too_much", {"f": f})}
	return {"accept": true, "why": coalition_text("you_join", {"f": f})}

## Your answer: your demands (ministry ids), or null to stay out. The talks then run on.
func coalition_answer(s: Dictionary, demands) -> void:
	var co: Dictionary = s.result.coalition
	var ask: Dictionary = co.ask
	var asks: Dictionary = co.get("asks", {}).duplicate()
	var dec: Dictionary = {"accept": false, "ministries": [], "why": coalition_text("you_stay_out", {"f": _short(s, ask.f)})} if demands == null else coalition_ask_verdict(s, ask, demands)
	dec.ministries = demands if demands != null else []
	asks[ask.key] = dec
	s.result.coalition = form_government(s, co.seats, asks)
