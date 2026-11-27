## sim.gd — the rules of Cranbovia (autoload "Game"): the last link of the chain
## in scripts/rules/ (see rules/base.gd). Here: loading the content, starting a new
## game, the monthly update, the weekly clock and describing effects in words.
extends "res://scripts/rules/coalition.gd"

# ---------- Starting a new game ----------
func _init() -> void:
	load_content()

## Every data file comes through Mods.data(): the game's file with the enabled mods
## merged on top (see scripts/mods.gd and MODDING.md).
## The minor parties, ready to be looked up like any party (party_of): never the
## player's, seen exactly where their manifesto puts them, and nothing else changes them.
func _minor_parties(list: Array) -> Array:
	for p in list:
		p.isPlayer = false
		p.isMinor = true
		p.perceived = p.manifesto.duplicate()
		for k in ["ruling", "charisma", "stability", "establishment", "money"]:
			if not p.has(k): p[k] = {"ruling": false, "charisma": 20, "stability": 100, "establishment": 0.0, "money": 0.0}[k]
		if not p.has("leaderHome"): p.leaderHome = ""
	return list

func load_content(_unused := "") -> void:
	var d: Dictionary = Mods.data("content")
	C = d.CONFIG; AXES = d.AXES; AGES = d.AGES; CLASSES = d.CLASSES; NATIONALITIES = d.NATIONALITIES
	REGIONS = d.REGIONS; FOREIGN = d.FOREIGN; CAPITAL = d.CAPITAL; VIEW_GROUPS = d.VIEW_GROUPS
	PARTIES = d.PARTIES; PARTY_HISTORY = d.get("PARTY_HISTORY", []); STYLE_NOTES = d.get("STYLE_NOTES", {}); SMALL_TASKS = d.get("SMALL_TASKS", []); MINOR_PARTIES = _minor_parties(d.get("MINOR_PARTIES", [])); LEADER_POOL = d.LEADER_POOL; PARTY_TEMPLATES = d.PARTY_TEMPLATES
	PLAYER_COLORS = d.PLAYER_COLORS; PLAYER_EMBLEMS = d.PLAYER_EMBLEMS; PLAYER_PORTRAITS = d.PLAYER_PORTRAITS
	CAMPAIGN = d.CAMPAIGN; EVENTS = d.EVENTS; FUNDING_OFFERS = d.FUNDING_OFFERS; INITIATIVES = d.INITIATIVES
	CRISES = d.CRISES; INDICATORS = d.INDICATORS; TONES = d.TONES; TONE_RISK = d.TONE_RISK
	ARCHETYPES = d.ARCHETYPES; ACTIONS = d.ACTIONS; SCRUTINY_STORIES = d.SCRUTINY_STORIES
	MONTH_NAMES = d.MONTH_NAMES; FLAG_INFO = d.FLAG_INFO; COUNTRY = d.COUNTRY; FEEDBACK_GROUPS = d.FEEDBACK_GROUPS
	MAP = _data("map", d.get("MAP", {}))
	WEEKS_PER_MONTH = int(C.weeksPerMonth)
	WEEKS_PER_YEAR = int(C.weeksPerMonth) * int(C.monthsPerYear)
	ELECTION_WEEK = int(C.electionYears) * WEEKS_PER_YEAR
	BUDGET_KEYS = []
	# "road": money for the leader's trips this quarter (it used to be rallies by region)
	BUDGET_KEYS.append_array(["road", "social", "tv", "polling"])   # polling: better polls this quarter, on (pollCost) or off
	_events_by_id = {}
	for e in EVENTS: _events_by_id[e.id] = e
	TOPICS = _data("debates", {}).get("TOPICS", [])
	LAWS = _data("laws", {}).get("LAWS", [])
	LAWS_C = C.get("laws", {})
	LINES = _data("debate_lines", {})
	ISSUES = _data("issues", {}).get("ISSUES", [])
	FIGURES = _data("party", {}).get("FIGURES", [])
	CITY_INFO = _data("cities", {}).get("CITIES", {})
	FLAGSHIP = _data("flagship", {}).get("ISSUES", [])
	NAMES = _data("names", {})
	VIOLENCE = _data("violence", {})
	SCANDALS = _data("scandals", {})
	INTERVIEW = _data("interview", {})
	FINAL_DEBATE = _data("final_debate", {})
	COALITION = _data("coalition", {})
	var media_data: Dictionary = _data("media", {})
	OUTLETS = media_data.get("OUTLETS", [])
	FOREIGN_MONEY = media_data.get("FOREIGN_MONEY", [])
	INFLUENCER_SCANDALS = media_data.get("INFLUENCER_SCANDALS", [])
	LEADER_TYPES = _data("leader_types", {}).get("TYPES", [])
	TOURS = _data("tours", {})
	MAPMODES = _data("mapmodes", {})
	NEWS = _data("news", {})
	_load_districts()
	for c in MAP.cities:   # the designer's sizes beat the dot sizes on the map
		if CITY_INFO.get(c.name, {}).has("size"): c.size = int(CITY_INFO[c.name].size)
	_event_axis = {}

## A data file through the mod loader, or a default when no file exists.
func _data(name: String, fallback):
	var v = Mods.data(name)
	return fallback if v == null else v

## opts: seed, partyName, leaderName, manifesto {axisId: 0..4}, color, emblem, portrait
func new_game(opts := {}) -> Dictionary:
	var seed: int = opts.get("seed", randi() % 2147483647)
	var party_name: String = opts.get("partyName", "New Dawn Movement")
	var leader_name: String = opts.get("leaderName", "Dorin Vask")
	var manifesto: Dictionary = opts.get("manifesto", {})
	var color: String = opts.get("color", "#c8402a")
	var emblem: String = opts.get("emblem", "star")
	var portrait: int = opts.get("portrait", 1)
	var player_point = {}
	for ax in AXES: player_point[ax.id] = C.stanceCenters[int(manifesto.get(ax.id, 2))]
	var pp: Dictionary = PLAYER_PORTRAITS[portrait - 1] if portrait - 1 < PLAYER_PORTRAITS.size() else PLAYER_PORTRAITS[0]
	var s = {
		"version": SAVE_VERSION, "seed": seed, "rng": seed & M32, "week": 0, "money": 0.0,
		"trust": float(C.trustStart), "trustHistory": [],
		"salMod": {}, "ownership": {}, "queue": [], "news": [], "polls": [], "log": [], "deck": [],
		"flips": [], "flags": {}, "scheduled": [], "scandals": [], "dossiers": [], "signature": [],
		"actionsLeft": int(C.actionsPerMonth), "lastSupport": null, "lastBudget": null,
		"world": {"jobs": 55.0, "prices": 45.0, "migration": 58.0, "border": 40.0, "unrest": 32.0},
		"climate": {}, "permSal": {}, "agenda": {"offered": [], "done": false, "used": []},
		"crisisPressure": {}, "crisis": null, "quietMonths": 0, "style": {},
		"record": {"quotes": [], "blamed": [], "betrayed": [], "promises": [], "money": [], "memes": 0, "gaffes": 0, "dossiers": 0, "outrages": 0},
		"result": null, "parties": [], "pops": [], "countries": {}, "story": {},
		"debates": [], "debatesPast": [], "bill": null, "lawsDone": {}, "lawShift": {}, "lawNext": int(C.get("laws", {}).get("firstMonth", 3)) * int(C.weeksPerMonth), "debateCooldown": {}, "spoke": {}, "issues": [], "issueCooldown": {}, "communities": {}, "figures": [], "figuresLost": [], "steer": null, "home": "", "districts": {}, "projection": {}, "lastVisit": -99, "relations": {}, "relationNotes": {}, "relScars": {}, "flagship": {}, "roadFund": 0.0, "roadPerTrip": 0.0,
	}
	for p in PARTIES:
		var me: bool = p.get("isPlayer", false)
		s.parties.append({
			"id": p.id,
			"name": party_name if me else p.name,
			"short": initials(party_name) if me else p.short,
			"leader": leader_name if me else p.leader,
			"leaderSex": pp.sex if me else p.get("leaderSex", "m"),
			"leaderHome": str(opts.get("home", "")) if me else str(p.get("leaderHome", "")),
			"leaderAge": pp.age if me else p.get("leaderAge", 60),
			"charisma": float(C.startCharisma) if me else float(p.get("charisma", 50)),
			"stability": float(p.get("stability", 60)),
			"establishment": float(p.get("establishment", 0.5)),
			"color": color if me else p.color,
			"emblem": emblem if me else p.get("emblem", "star"),
			"portraitSeed": pp.seed if me else null,
			"isPlayer": me,
			"ruling": p.get("ruling", false),
			"partner": p.get("partner", false),   # a junior partner in the government
			"manifesto": full_vector(player_point if me else p.manifesto),
			"perceived": full_vector(player_point if me else p.manifesto),
		})
	var ext = 0.0
	for ax in AXES: ext += absf(C.stanceCenters[int(manifesto.get(ax.id, 2))]) / 80.0
	player_party(s).extremity = ext / AXES.size()
	for p in PARTIES:
		var owns: Dictionary = p.get("owns", {})
		for key in owns:
			if not s.ownership.has(key): s.ownership[key] = {}
			s.ownership[key][p.id] = owns[key]
		trim_claims(s, p.id)
	s.districts = new_districts(s)
	s.relations = new_relations(s)
	new_pair_relations(s)
	s.pops = build_pops(s)
	_home_start(s, str(opts.get("home", "")))
	seed_loyalty(s)
	s.manifesto0 = player_party(s).manifesto.duplicate()   # what the party was founded on
	s.figures = new_figures(s)
	s.media = new_media(s)
	s.secrets = []
	_past_secrets(s)
	# the country is already arguing about something
	var general = TOPICS.filter(func(t): return not t.has("trigger"))
	for i in 2:
		var t: Dictionary = pick(s, general)
		general.erase(t)
		open_debate(s, t.id, t.axis, t.title, t.text, "news", 28.0 + rand(s) * 20, (rand(s) - 0.5) * 40)
	for i in 2:
		var it: Dictionary = pick(s, ISSUES.filter(func(x): return not s.issues.any(func(y): return y.id == x.id)))
		story_turns_up(s, it.id)
		s.issueCooldown[it.id] = s.week
	s.lastSupport = summarize(s, s.pops).support
	s.serious = float(C.serious.start)
	s.pastElection = past_election(s)   # the 2026 result: the starting map without your party
	s.mods = Mods.enabled().map(func(m): return "%s %s" % [m.name, m.version])   # what this game was started with
	run_hooks(s)
	return s

func _home_start(s: Dictionary, city: String) -> void:
	var c: Dictionary = city_by_name(city)
	if c.is_empty() or c.area == "alinni": return
	s.home = c.name
	s.communities[c.name] = 1
	var hd = district_of_city(c.name)
	if hd: district_boost(s, hd.id, 0.3, 0.35)   # the old constituency knows you best
	for pop in s.pops:
		if pop.region != c.area: continue
		var k: float = 1.0 if pop.nationality == "cranebonian" else 0.4
		pop.aware.player = clampf2(pop.aware.player + 0.35 * k, 0, 1)
		pop.goodwill.player = clampf2(pop.goodwill.player + 0.3 * k, -2, 2)
		pop.leader.player = clampf2(pop.leader.player + 0.4 * k, -2, 2)
	s.log.append({"week": 0, "kind": "action", "text": "%s, former mayor of %s, founds %s." % [player_party(s).leader, c.name, player_party(s).name]})

# ---------- Monthly dynamics ----------
func monthly_update(s: Dictionary) -> void:
	_close_move_report(s)
	for ax in s.salMod: s.salMod[ax] *= C.salienceDecay
	var hd: Dictionary = s.get("heard", {})
	for k in hd: hd[k] = float(hd[k]) * 0.75
	var wm: Dictionary = s.get("wantMod", {})
	for k in wm: wm[k] = float(wm[k]) * 0.85
	debates_monthly(s)
	laws_monthly(s)
	issues_monthly(s)
	s.outrage = float(s.get("outrage", 0.0)) * float(C.serious.get("provocative", {}).get("decay", 0.5))   # outrage wears off
	serious_monthly(s)
	communities_monthly(s)
	relations_monthly(s)
	flagship_monthly(s)
	steer_monthly(s)
	figures_monthly(s)
	media_monthly(s)
	secrets_monthly(s)
	violence_monthly(s)
	labels_monthly(s)
	if rand(s) < C.newsWaveChance:
		var ax: Dictionary = pick(s, AXES)
		s.salMod[ax.id] = clampf2(float(s.salMod.get(ax.id, 0)) + C.newsWaveSize, -0.5, 1.5)
		var owners = ownership_table(s).filter(func(r): return r.axis == ax.id and r.owners.size())
		var who = " and ".join(owners.map(func(r): return "%s (%s)" % [party_of(s, r.owners[0].party).short, r.label.to_lower()]))
		push_news(s, {"kind": "issue", "title": "All eyes on %s" % ax.issue.to_lower(),
			"text": "Everyone is suddenly talking about %s, and for many voters it is now the only issue that matters. %s" % [ax.issue.to_lower(), ("The parties that own it gain most: %s." % who) if who != "" else "Nobody owns this issue yet."]})
	for key in s.ownership:
		for pid in s.ownership[key]: s.ownership[key][pid] *= C.ownDecay
	s.trust += (50 - s.trust) * C.trustRecovery
	s.actionsLeft = int(C.actionsPerMonth)
	var player = player_party(s)
	var pull = {}
	for ax in AXES: pull[ax.id] = (player.manifesto[ax.id] - player.perceived[ax.id]) * C.perceivedPull
	shift_perceived(s, pull, false)
	var ctx = score_context(s)
	for pop in s.pops:
		var sup = pop_support(s, pop, null, ctx)
		var dev = devotion_of(pop, player)
		if dev > 0.5:
			for ax in AXES: pop.pos[ax.id] += (player.perceived[ax.id] - pop.pos[ax.id]) * C.cultPull * dev
		pop.mobilized *= C.mobilizeDecay
		var loyal_total = 0.0
		for p in s.parties:
			pop.goodwill[p.id] *= C.goodwillDecay
			pop.leader[p.id] *= C.leaderDecay
			if p.isPlayer:
				pop.aware[p.id] = C.awarenessFloor + (pop.aware[p.id] - C.awarenessFloor) * C.awarenessDecay
			var floating: float = sup[p.id] - pop.loyal[p.id]
			var core: float = pop.loyal[p.id] * (1 - C.loyaltyChurn) + floating * C.loyaltyGain
			var erosion: float = C.coreErosion * maxf(0, ctx.inc[p.id] - C.inconsistencyTolerance)
			core *= 1 - erosion * (1 - devotion_of(pop, p)) * (1 - shield_of(pop, p.id))
			pop.loyal[p.id] = clampf2(core, 0, 0.9)
			loyal_total += pop.loyal[p.id]
		if loyal_total > 0.85:
			for p in s.parties: pop.loyal[p.id] *= 0.85 / loyal_total
	var now: Dictionary = summarize(s, s.pops).support
	rivals_monthly(s, now)
	rivals_turn(s, now)
	frontrunner_scrutiny(s, now)
	s.trustHistory.append({"week": s.week, "trust": s.trust})
	s.lastSupport = now

# ---------- Time: weekly ticks and hooks ----------
## The calendar, in order. The first hook to match on election week ends the run.
func run_hooks(s: Dictionary) -> void:
	var c = calendar(s.week)
	if c.week == ELECTION_WEEK:
		run_election(s); return
	if c.week == 0: take_poll(s, "Opening poll")
	if c.isMonthStart and c.week > 0: monthly_update(s)
	if c.isMonthStart and c.week > 0: world_monthly(s)
	if c.isMonthStart: offer_initiatives(s)
	if c.isMonthStart: _crisis_hook(s)
	if c.isQuarterStart:
		var inc = quarterly_income(s)
		s.lastIncome = inc
		s.money += inc.total
		# trip money not spent last quarter goes back into the pot, not into this quarter's trips
		s.money += float(s.get("roadFund", 0))
		s.roadFund = 0.0
		s.queue.append({"type": "budget", "offers": draw_offers(s)})
	if c.week == ELECTION_WEEK - WEEKS_PER_MONTH: start_debate(s)
	if INTERVIEW.size() and c.week == interview_week(): start_interview(s)
	if c.week == flagship_week() and FLAGSHIP.size(): s.queue.append({"type": "event", "event": flagship_event(s)})
	if c.isMonthStart: monthly_event(s)
	# the official campaign: the plan the week before, then a convoy stop every week
	if c.week == campaign_start_week() - 1: campaign_start(s)
	if in_campaign(s): campaign_weekly(s)
	if c.weekOfMonth == 2 and not c.isYearEnd: take_poll(s, "Tracking poll", true)
	if c.isYearEnd: take_poll(s, "Annual poll %d" % calendar(s.week).year)
	flush_news(s)

func advance_week(s: Dictionary) -> bool:
	if s.queue.size() or s.result: return false
	s.week += 1
	run_hooks(s)
	return true

## On to the next turn: the start of next month, or next week in the campaign (and the
## week before it, when the convoy is planned); stops early when a decision arrives.
func advance_to_next_turn(s: Dictionary) -> bool:
	var moved = false
	while advance_week(s):
		moved = true
		if s.queue.size(): break
		if in_campaign(s) or s.week == campaign_start_week() - 1: break
		if calendar(s.week).isMonthStart: break
	return moved

func advance_to_decision(s: Dictionary) -> bool:
	var moved = false
	while advance_week(s):
		moved = true
		if s.queue.size(): break
	return moved

func dismiss_front(s: Dictionary) -> void:
	s.queue.pop_front()
	flush_news(s)

# ---------- Starting a new game ----------
func describe_choice(s: Dictionary, fx: Dictionary) -> Dictionary:
	var groups = []
	for g in fx.get("goodwill", []):
		if g.get("party"): continue
		var who: Dictionary = g.get("who", {})
		var size = 0.0
		if who.has("loyalTo"):
			for p in s.pops: size += p.size * float(p.loyal.get(who.loyalTo, 0))
		else: size = size_of(s, who)
		groups.append({"text": describe_who(who), "amt": g.amt, "size": size, "weight": absf(g.amt) * size})
	groups = ssort(groups, func(a, b): return b.weight - a.weight)
	var strength = func(amt: float) -> String:
		return "strongly" if absf(amt) >= 0.5 else ("slightly" if absf(amt) < 0.2 else "")
	var tags = []
	if fx.get("leader"):
		var total = 0.0
		for g in _leader_list(fx.leader): total += float(g) if (g is float or g is int) else g.amt
		tags.append("Builds your leader's image" if total >= 0 else "Hurts your leader's image")
	var aw = fx.get("awareness")
	if (aw if aw != null else C.eventAwareness) >= 0.05: tags.append("Big media coverage")
	if aw != null and aw == 0: tags.append("No media coverage")
	if fx.get("money"): tags.append(("+₱%sM" % str(fx.money)) if fx.money > 0 else ("Costs ₱%sM" % str(-fx.money)))
	if fx.get("scandal"): tags.append("Scandal risk")
	if fx.get("trust"): tags.append("Lowers trust in politics" if fx.trust < 0 else "Raises trust in politics")
	if fx.get("defect"): tags.append("Gains %s core voters" % party_of(s, fx.defect.from).short)
	var fmt = func(g): return {"text": g.text, "size": g.size, "strength": strength.call(g.amt)}
	return {
		"appeals": groups.filter(func(g): return g.amt > 0 and g.size > 0).map(fmt),
		"angers": groups.filter(func(g): return g.amt < 0 and g.size > 0).map(fmt),
		"stances": preview_shift(s, fx.get("shift")),
		"tags": tags,
	}

# ---------- Why your support moved: every move you make, measured ----------
## Your support across the whole electorate right now (not a poll: no noise).
func true_support(s: Dictionary) -> float:
	return float(summarize(s, s.pops).support.get("player", 0.0))

func _track(s: Dictionary, what: String, before: float) -> void:
	if not s.has("moves"): s.moves = []
	var d: float = true_support(s) - before
	if absf(d) >= 0.0005: s.moves.append({"what": what, "d": d, "week": s.week})

## At the start of each month: last month's change, the moves that made it, and the rest
## (rivals, the media, time) as one line (s.moveReport, shown on the top bar).
func _close_move_report(s: Dictionary) -> void:
	var now: float = true_support(s)
	var mark: float = float(s.get("supportMark", now))
	var moves: Array = s.get("moves", [])
	var sum = 0.0
	for m in moves: sum += float(m.d)
	s.moveReport = {"total": now - mark, "moves": moves, "other": now - mark - sum, "week": s.week}
	s.moves = []
	s.supportMark = now

func resolve_event(s: Dictionary, choice_index: int, line_index := -1) -> Dictionary:
	var what: String = String(event_of(s.queue[0]).get("title", "An event")) if s.queue.size() else "An event"
	var b: float = true_support(s)
	var r: Dictionary = super(s, choice_index, line_index)
	_track(s, "Your answer: " + what, b)
	return r

func act_speak(s: Dictionary, id: String, side: String, line_index: int) -> Dictionary:
	var d = debate_by_id(s, id)
	var b: float = true_support(s)
	var r: Dictionary = super(s, id, side, line_index)
	if r.get("ok", false): _track(s, "Speaking on " + (String(d.title) if d else "a debate"), b)
	return r

func act_raise(s: Dictionary, opt: Dictionary, side: String, line_index: int) -> Dictionary:
	var b: float = true_support(s)
	var r: Dictionary = super(s, opt, side, line_index)
	if r.get("ok", false): _track(s, "Starting a debate: " + String(opt.title), b)
	return r

func act_visit(s: Dictionary, id: String) -> Dictionary:
	var b: float = true_support(s)
	var r: Dictionary = super(s, id)
	if r.get("ok", false): _track(s, "Trip to " + String(district_by_id(id).name), b)
	return r

func resolve_budget(s: Dictionary, alloc: Dictionary, offers_taken := []) -> Dictionary:
	var b: float = true_support(s)
	var r: Dictionary = super(s, alloc, offers_taken)
	_track(s, "The budget and its money", b)
	return r

func answer_debate(s: Dictionary, line_index: int) -> Dictionary:
	var b: float = true_support(s)
	var r: Dictionary = super(s, line_index)
	_track(s, "The final debate", b)
	return r

func answer_interview(s: Dictionary, line_index: int) -> Dictionary:
	var b: float = true_support(s)
	var r: Dictionary = super(s, line_index)
	_track(s, "The big interview", b)
	return r

func answer_appearance(s: Dictionary, line_index: int) -> Dictionary:
	var name: String = String(s.appearance.outletName)
	var b: float = true_support(s)
	var r: Dictionary = super(s, line_index)
	_track(s, "On " + name, b)
	return r

func act_release(s: Dictionary, index: int) -> Dictionary:
	var b: float = true_support(s)
	var r: Dictionary = super(s, index)
	if r.get("ok", false): _track(s, "Releasing a dossier", b)
	return r

