## rules/media.gd — The media: outlets, their audiences and slants, cover, the agenda, personalities and sponsorships, and foreign patrons.
extends "res://scripts/rules/districts.gd"

# ---------- Media ----------
func new_media(s: Dictionary) -> Dictionary:
	var out = {}
	for o in OUTLETS:
		out[o.id] = {"pos": o.get("pos", {}).duplicate(), "owner": "", "sponsor": "", "audience": 1.0, "buzz": 0.0, "favour": {}, "reachNat": 0.0,
			"subs": float(o.get("subs", 0))}
	return out

func outlet_by_id(id: String) -> Variant:
	return by_id(OUTLETS, id)

## The share of a group that follows an outlet.
func outlet_reach(s: Dictionary, o: Dictionary, pop: Dictionary) -> float:
	var st: Dictionary = s.media.get(o.id, {})
	var r: float = float(o.get("reach", {}).get("base", 0.1)) * float(st.get("audience", 1.0))
	if float(o.get("subs", 0)) > 0: r *= float(st.get("subs", o.subs)) / float(o.subs)   # a personality reaches as many as follow them
	var by: Dictionary = o.get("reach", {}).get("by", {})
	for key in ["age", "class", "region", "nationality"]:
		r *= float(by.get(key, {}).get(pop[key], 1.0))
	return clampf2(r, 0, 0.9)

## How honest an outlet is now: a party-owned one is less believed.
func outlet_honesty(s: Dictionary, o: Dictionary) -> float:
	var h: float = float(o.get("honesty", 0.5))
	return h * 0.5 if s.media[o.id].owner != "" else h

## How much an outlet's word counts with its audience: a paid voice a little less
## (everyone knows they're paid; nobody minds much).
func outlet_weight(s: Dictionary, o: Dictionary) -> float:
	return 0.75 if s.media[o.id].get("sponsor", "") != "" else 1.0

## A personality's price for a quarter, from their followers.
func sponsor_price(s: Dictionary, o: Dictionary) -> float:
	return snappedf(0.4 + float(s.media[o.id].get("subs", o.get("subs", 1))) * 1.0, 0.1)

## How an outlet treats a party, -1..1. Partisan outlets back whoever is closest to
## their slant; honest ones follow what you actually say and how it goes ("buzz").
func outlet_favour(s: Dictionary, o: Dictionary, p: Dictionary) -> float:
	var st: Dictionary = s.media[o.id]
	if st.owner != "": return 1.0 if st.owner == p.id else -0.3
	if st.get("sponsor", "") != "": return 1.0 if st.sponsor == p.id else -0.1
	# a foreign channel backs the party its government pays
	var pat = s.get("patron")
	if p.isPlayer and pat and o.kind == "foreign" and o.get("country", "") == pat.country: return 1.0
	var h: float = float(o.get("honesty", 0.5))
	var diff = 0.0
	var n = 0
	for ax in st.pos:
		diff += absf(float(p.perceived[ax]) - float(st.pos[ax]))
		n += 1
	var slant: float = clampf2(1.0 - (diff / n) / 60.0, -1, 1) if n else 0.0
	var f: float = slant * (1 - h)
	if p.isPlayer: f += h * float(st.buzz)
	return clampf2(f, -1, 1)

## A line you said, as each outlet plays it: tone, a viral clip, a gaffe.
func media_hear(s: Dictionary, tone: String, outcome: String, k := 1.0) -> void:
	if not s.has("media"): return
	for o in OUTLETS:
		var st: Dictionary = s.media[o.id]
		var d: float = (float(o.get("tones", {}).get(tone, 1.0)) - 1.0) * 0.4
		if outcome == "viral": d += 0.35 if o.kind == "platform" else 0.15
		elif outcome == "gaffe": d -= 0.4 * float(o.get("honesty", 0.5))   # partisan friends look away
		st.buzz = clampf2(float(st.buzz) + d * k, -1, 1)

func media_monthly(s: Dictionary) -> void:
	if not s.has("media"): return
	patron_monthly(s)
	sponsors_monthly(s)
	var people = 0.0
	for pop in s.pops: people += float(pop.size)
	var keys = []
	for pop in s.pops:
		keys.append("%s|%s|%s|%s" % [pop.age, pop.class, pop.region, pop.nationality])
		if pop.has("base"):
			for ax in pop.base: pop.pos[ax] += (float(pop.base[ax]) - float(pop.pos[ax])) * VIEW_HOME
		var shd: Dictionary = pop.get("shield", {})
		for pid in shd: shd[pid] = float(shd[pid]) * 0.7
		pop.shield = shd
	for o in OUTLETS:
		var st: Dictionary = s.media[o.id]
		# a bought outlet turns toward its owner, and loses viewers to the others
		if st.owner != "":
			var owner = party_of(s, st.owner)
			if owner:
				for ax in st.pos: st.pos[ax] = float(st.pos[ax]) + (float(owner.perceived[ax]) - float(st.pos[ax])) * 0.08
			var lost: float = float(st.audience) * 0.04
			st.audience = float(st.audience) - lost
			var others = OUTLETS.filter(func(x): return x.id != o.id and x.kind != "platform")
			for x in others: s.media[x.id].audience = minf(1.6, float(s.media[x.id].audience) + lost / others.size())
		var fav = {}
		for p in s.parties: fav[p.id] = outlet_favour(s, o, p)
		st.favour = fav
		var h: float = outlet_honesty(s, o)
		var wgt: float = outlet_weight(s, o)
		var k: float = (0.15 + 0.6 * (1 - h)) * wgt     # how hard it moves a viewer
		var sk: float = (0.1 + 0.8 * (1 - h)) * wgt     # how much it shields its favourite
		var nat = 0.0
		# worked out once per outlet, not once per voter group: who it favours, what it pushes,
		# and its reach for each kind of person (reach depends only on age, class, region, nationality)
		var favs = []
		for pid in fav:
			if absf(float(fav[pid])) >= 0.05: favs.append([pid, k * float(fav[pid]) * MEDIA_WARM, sk * float(fav[pid]) * SHIELD_GAIN if float(fav[pid]) > 0 else 0.0])
		var pulls = []
		for ax in st.pos: pulls.append([ax, float(st.pos[ax]), k * MEDIA_VIEW])
		var reach_of = {}
		for i in s.pops.size():
			var pop: Dictionary = s.pops[i]
			var key: String = keys[i]
			var r: float
			if reach_of.has(key): r = reach_of[key]
			else:
				r = outlet_reach(s, o, pop)
				reach_of[key] = r
			if r < 0.01: continue
			nat += r * float(pop.size)
			var pos: Dictionary = pop.pos
			for pl in pulls: pos[pl[0]] = clampf2(pos[pl[0]] + (pl[1] - pos[pl[0]]) * r * pl[2], -100, 100)
			var gw: Dictionary = pop.goodwill
			var shd: Dictionary = pop.shield
			for fv in favs:
				gw[fv[0]] = clampf2(gw[fv[0]] + r * fv[1], -2, 2)
				if fv[2] > 0: shd[fv[0]] = minf(SHIELD_MAX, float(shd.get(fv[0], 0.0)) + r * fv[2])
		st.reachNat = nat / people if people > 0 else 0.0
		st.buzz = float(st.buzz) * 0.5
	media_agenda(s)

## The media decide what the country argues about: an outlet keeps the issues it
## cares about in the news and pulls the argument its way, in proportion to its
## reach and how hard it pushes.
func media_agenda(s: Dictionary) -> void:
	for o in OUTLETS:
		var st: Dictionary = s.media[o.id]
		if st.pos.is_empty(): continue
		var push: float = float(st.reachNat) * (0.4 + 0.8 * (1 - outlet_honesty(s, o))) * outlet_weight(s, o)
		for d in s.debates:
			if not st.pos.has(d.axis): continue
			d.heat = clampf2(d.heat + push * 14, 0, 100)
			d.lean = clampf2(d.lean + signf(float(st.pos[d.axis])) * push * 18, -100, 100)

## When the news starts an argument, an outlet often picks it: one of the issues it
## cares about, leaning its way. Returns false if no outlet took it up.
func media_start_debate(s: Dictionary, pool: Array) -> bool:
	var cands = []
	var total = 0.0
	for o in OUTLETS:
		var st: Dictionary = s.media.get(o.id, {})
		if st.is_empty() or st.pos.is_empty(): continue
		var w: float = float(st.reachNat) * (0.4 + 0.8 * (1 - outlet_honesty(s, o)))
		if w <= 0: continue
		cands.append([o, w]); total += w
	if cands.is_empty() or rand(s) > 0.6: return false
	var r: float = rand(s) * total
	var o: Dictionary = cands[-1][0]
	for c in cands:
		r -= c[1]
		if r <= 0: o = c[0]; break
	var st: Dictionary = s.media[o.id]
	var mine = pool.filter(func(t): return st.pos.has(t.axis))
	if mine.is_empty(): return false
	var t: Dictionary = pick(s, mine)
	open_debate(s, t.id, t.axis, t.title, t.text, "media:" + o.id, 30, signf(float(st.pos[t.axis])) * 25)
	push_news(s, merged({"kind": "issue", "quiet": true}, news("WORLD", "media_argument", null, {"outlet": o.name, "topic": t.title, "text": t.text})))
	return true

# ---------- Personalities: sponsoring them ----------
func act_sponsor(s: Dictionary, id: String) -> Dictionary:
	var o = outlet_by_id(id)
	if o == null or o.kind != "influencer": return {"ok": false, "text": "No such personality."}
	var st: Dictionary = s.media[id]
	if st.sponsor != "": return {"ok": false, "text": "%s already has a deal." % o.name}
	var price: float = sponsor_price(s, o)
	var err = can_act(s, price)
	if err: return {"ok": false, "text": err}
	spend_action(s, price)
	st.sponsor = "player"
	var text = "%s has signed a \"content partnership\" with friends of the party: ₱%sM a quarter. Everyone will guess; nobody will mind much." % [o.name, fmt1(price)]
	_log(s, "action", "Sponsored %s." % o.name)
	return {"ok": true, "text": text}

func act_end_sponsor(s: Dictionary, id: String) -> Dictionary:
	var o = outlet_by_id(id)
	if o == null or s.media[id].sponsor != "player": return {"ok": false, "text": "No deal to end."}
	s.media[id].sponsor = ""
	_log(s, "action", "Ended the deal with %s." % o.name)
	return {"ok": true, "text": "The deal with %s is over. No hard feelings, officially." % o.name}

func sponsors_monthly(s: Dictionary) -> void:
	var quarter: bool = calendar(s.week).isQuarterStart
	for o in OUTLETS:
		if o.kind != "influencer": continue
		var st: Dictionary = s.media[o.id]
		st.subs = maxf(0.05, float(st.get("subs", o.subs)) * (1.0 + 0.012 + rand_normal(s) * 0.01))
		if INFLUENCER_SCANDALS.size() and rand(s) < INFLUENCER_SCANDAL:
			var sc: Dictionary = pick(s, INFLUENCER_SCANDALS)
			st.subs = float(st.subs) * (1 - float(sc.get("loss", 0.3)))
			push_news(s, {"kind": "issue", "quiet": st.get("sponsor", "") != "player", "title": String(sc.title).format({"name": o.name}),
				"text": String(sc.text).format({"name": o.name}) + (" Your party's deal with them was mentioned, briefly." if st.get("sponsor", "") == "player" else "")})
		var spon: String = st.get("sponsor", "")
		if spon == "" or not quarter: continue
		var price: float = sponsor_price(s, o)
		if spon == "player":
			if s.money < price:
				st.sponsor = ""
				push_news(s, merged({"kind": "issue", "quiet": true}, news("WORLD", "sponsor_dropped", null, {"outlet": o.name})))
				continue
			s.money -= price
		else:
			var rp = party_of(s, spon)
			if rp == null or float(rp.get("money", 0)) < price: st.sponsor = ""
			else: rp.money = float(rp.money) - price

# ---------- Foreign money: patrons ----------
func foreign_deal(offer_id: String) -> Variant:
	for f in FOREIGN_MONEY:
		if f.offer == offer_id: return f
	return null

## Taking a secret foreign offer: the money keeps coming, their channel and their
## bot farms are on your side, and now and then they ask for something.
func start_patron(s: Dictionary, offer_id: String) -> void:
	var f = foreign_deal(offer_id)
	if f == null or s.get("patron"): return
	s.patron = {"offer": offer_id, "country": f.country, "since": s.week, "lastAsk": s.week, "asked": 0}

func patron_monthly(s: Dictionary) -> void:
	var pat = s.get("patron")
	if not pat: return
	var f = foreign_deal(pat.offer)
	if f == null: return
	# bot farms: free noise on social media
	for o in OUTLETS:
		if o.kind == "platform": s.media[o.id].buzz = clampf2(float(s.media[o.id].buzz) + 0.3, -1, 1)
	if calendar(s.week).isQuarterStart: s.money += float(f.get("quarterly", 0))
	# a favour asked, every five months or so
	var demands: Array = f.get("demands", [])
	var gap: int = 5 if int(pat.asked) < demands.size() else 9   # once they've asked everything, less often
	if demands.size() and s.week - int(pat.lastAsk) >= gap * WEEKS_PER_MONTH and rand(s) < 0.5:
		pat.lastAsk = s.week
		var dm: Dictionary = demands[int(pat.asked) % demands.size()]
		pat.asked = int(pat.asked) + 1
		s.queue.append({"type": "event", "event": {"id": "patron_%s_%d" % [pat.offer, pat.asked], "kind": "secret", "title": dm.title, "text": dm.text,
			"choices": [{"label": dm.comply.label, "effects": merged(dm.comply.get("effects", {}), {"patron": "comply"})},
				{"label": dm.refuse.label, "effects": {"patron": "refuse"}}]}})

func patron_answer(s: Dictionary, answer: String) -> String:
	var pat = s.get("patron")
	if not pat: return ""
	if answer == "refuse":
		s.patron = null
		return " The money stops. Nobody says why, and nobody needs to."
	return " Your friends are pleased. The money keeps coming."

## Friendly journalists: your best friend among the honest outlets (0..1).
func friendly_press(s: Dictionary) -> Dictionary:
	var best = null
	var bf = 0.0
	if not s.has("media"): return {"outlet": null, "k": 0.0}
	for o in OUTLETS:
		if outlet_honesty(s, o) < 0.55 or o.kind in ["platform", "foreign", "influencer"]: continue
		var f: float = float(s.media[o.id].get("favour", {}).get("player", 0))
		if f > bf: bf = f; best = o
	return {"outlet": best, "k": clampf2(bf, 0, 1)}

## Buy an outlet outright. It turns your way and is believed less; viewers drift off.
func act_buy_outlet(s: Dictionary, id: String) -> Dictionary:
	var o = outlet_by_id(id)
	if o == null: return {"ok": false, "text": "No such outlet."}
	var price: float = float(o.get("price", 0))
	if price <= 0: return {"ok": false, "text": "%s is not for sale." % o.name}
	if s.media[id].owner != "": return {"ok": false, "text": "%s already has an owner." % o.name}
	var err = can_act(s, price)
	if err: return {"ok": false, "text": err}
	spend_action(s, price)
	s.media[id].owner = "player"
	var text = "%s now belongs to friends of the party. Its line will move your way; some of its readers will notice and leave." % o.name
	push_news(s, merged({"kind": "issue"}, news("WORLD", "outlet_bought", null, {"outlet": o.name, "you": player_party(s).short})))
	_log(s, "action", text)
	return {"ok": true, "text": text}

## What a group follows, biggest first: [{outlet, reach}] (share of the group).
func group_media(s: Dictionary, pops: Array) -> Array:
	var out = []
	var tot = 0.0
	for pop in pops: tot += float(pop.size)
	if tot <= 0 or not s.has("media"): return out
	for o in OUTLETS:
		var r = 0.0
		for pop in pops: r += float(pop.size) * outlet_reach(s, o, pop)
		out.append({"outlet": o, "reach": r / tot})
	return ssort(out, func(a, b): return b.reach - a.reach)

## How much a group's media shields a party (0..SHIELD_MAX), size-weighted.
func group_shield(pops: Array, pid: String) -> float:
	var tot = 0.0
	var v = 0.0
	for pop in pops:
		tot += float(pop.size)
		v += float(pop.size) * shield_of(pop, pid)
	return v / tot if tot else 0.0
