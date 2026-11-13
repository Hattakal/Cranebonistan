## sim.gd — the rules of Cranebonistan (autoload "Game").
##
## A line-for-line port of the browser version's sim.js, world.js and voice.js.
## No drawing and no buttons: it reads the content in data/content.json and
## changes the game state. The whole game is one Dictionary, `s`; saving is
## JSON.stringify(s).
##
## Sections: helpers · random · calendar · stances · new game & pops ·
## consistency · opinion · groups · effects · countries · trust · ownership ·
## rivals · monthly update · actions · budget · events · news · polls ·
## elections · world · initiatives · crisis · voice · debate · profile ·
## time · descriptions
extends Node

const SAVE_VERSION := 27

# ---------- Content (from data/content.json) ----------
var C: Dictionary            # CONFIG
var AXES: Array
var AGES: Array
var CLASSES: Array
var NATIONALITIES: Array
var REGIONS: Array
var FOREIGN: Array
var CAPITAL: Dictionary
var VIEW_GROUPS: Array
var PARTIES: Array
var LEADER_POOL: Array
var PARTY_TEMPLATES: Array
var PLAYER_COLORS: Array
var PLAYER_EMBLEMS: Array
var PLAYER_PORTRAITS: Array
var CAMPAIGN: Dictionary
var EVENTS: Array
var FUNDING_OFFERS: Array
var INITIATIVES: Array
var CRISES: Array
var INDICATORS: Array
var TONES: Dictionary
var TONE_RISK: Dictionary
var ARCHETYPES: Dictionary
var ACTIONS: Dictionary
var SCRUTINY_STORIES: Array
var MONTH_NAMES: Array
var MAP: Dictionary
var FLAG_INFO: Dictionary
var FEEDBACK_GROUPS: Array

var WEEKS_PER_MONTH: int
var WEEKS_PER_YEAR: int
var ELECTION_WEEK: int
var BUDGET_KEYS: Array = []
var _events_by_id = {}
var TOPICS: Array = []        # debate topics (data/debates.json)
var LINES: Dictionary = {}    # what the leader can say in them (data/debate_lines.json)
var ISSUES: Array = []        # minor issues: local stories (data/issues.json)
var FIGURES: Array = []       # your party's politicians (data/party.json)
var CITY_INFO: Dictionary = {} # population, lean and a line per city (data/cities.json)
var FLAGSHIP: Array = []       # the year-three flagship promise (data/flagship.json)
var TOURS: Dictionary = {}     # short stories from the leader's trips (data/tours.json)
var LEADER_TYPES: Array = []   # the kinds of leader voters want (data/leader_types.json)
var OUTLETS: Array = []        # newspapers, channels and platforms (data/media.json)
var _event_axis = {}

func _init() -> void:
	load_content("res://data/content.json")

func load_content(path: String) -> void:
	var f = FileAccess.open(path, FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	C = d.CONFIG; AXES = d.AXES; AGES = d.AGES; CLASSES = d.CLASSES; NATIONALITIES = d.NATIONALITIES
	REGIONS = d.REGIONS; FOREIGN = d.FOREIGN; CAPITAL = d.CAPITAL; VIEW_GROUPS = d.VIEW_GROUPS
	PARTIES = d.PARTIES; LEADER_POOL = d.LEADER_POOL; PARTY_TEMPLATES = d.PARTY_TEMPLATES
	PLAYER_COLORS = d.PLAYER_COLORS; PLAYER_EMBLEMS = d.PLAYER_EMBLEMS; PLAYER_PORTRAITS = d.PLAYER_PORTRAITS
	CAMPAIGN = d.CAMPAIGN; EVENTS = d.EVENTS; FUNDING_OFFERS = d.FUNDING_OFFERS; INITIATIVES = d.INITIATIVES
	CRISES = d.CRISES; INDICATORS = d.INDICATORS; TONES = d.TONES; TONE_RISK = d.TONE_RISK
	ARCHETYPES = d.ARCHETYPES; ACTIONS = d.ACTIONS; SCRUTINY_STORIES = d.SCRUTINY_STORIES
	MONTH_NAMES = d.MONTH_NAMES; MAP = d.MAP; FLAG_INFO = d.FLAG_INFO; FEEDBACK_GROUPS = d.FEEDBACK_GROUPS
	WEEKS_PER_MONTH = int(C.weeksPerMonth)
	WEEKS_PER_YEAR = int(C.weeksPerMonth) * int(C.monthsPerYear)
	ELECTION_WEEK = int(C.electionYears) * WEEKS_PER_YEAR
	BUDGET_KEYS = []
	# "road": money for the leader's trips this quarter (it used to be rallies by region)
	BUDGET_KEYS.append_array(["road", "social", "tv", "tour"])
	_events_by_id = {}
	for e in EVENTS: _events_by_id[e.id] = e
	TOPICS = JSON.parse_string(FileAccess.get_file_as_string("res://data/debates.json")).TOPICS
	LINES = JSON.parse_string(FileAccess.get_file_as_string("res://data/debate_lines.json"))
	ISSUES = JSON.parse_string(FileAccess.get_file_as_string("res://data/issues.json")).ISSUES
	FIGURES = JSON.parse_string(FileAccess.get_file_as_string("res://data/party.json")).FIGURES
	CITY_INFO = JSON.parse_string(FileAccess.get_file_as_string("res://data/cities.json")).CITIES if FileAccess.file_exists("res://data/cities.json") else {}
	FLAGSHIP = JSON.parse_string(FileAccess.get_file_as_string("res://data/flagship.json")).ISSUES if FileAccess.file_exists("res://data/flagship.json") else []
	OUTLETS = JSON.parse_string(FileAccess.get_file_as_string("res://data/media.json")).OUTLETS if FileAccess.file_exists("res://data/media.json") else []
	LEADER_TYPES = JSON.parse_string(FileAccess.get_file_as_string("res://data/leader_types.json")).TYPES if FileAccess.file_exists("res://data/leader_types.json") else []
	if not C.has("typeWeight"): C.typeWeight = 0.8
	TOURS = JSON.parse_string(FileAccess.get_file_as_string("res://data/tours.json")) if FileAccess.file_exists("res://data/tours.json") else {}
	_load_districts()
	for c in MAP.cities:   # the designer's sizes beat the dot sizes on the map
		if CITY_INFO.get(c.name, {}).has("size"): c.size = int(CITY_INFO[c.name].size)
	_event_axis = {}
	# Godot rules: the national debate is the main game, events are rarer
	C.actionsPerMonth = 3
	C.eventChance = 0.22
	C.maxQuietMonths = 3
	C.newsWaveChance = 0.0

# ---------- Small helpers ----------
static func clampf2(v: float, lo: float, hi: float) -> float:
	return maxf(lo, minf(hi, v))

static func by_id(list: Array, id) -> Variant:
	for x in list:
		if x.id == id: return x
	return null

func player_party(s: Dictionary) -> Dictionary:
	for p in s.parties:
		if p.isPlayer: return p
	return {}

func party_of(s: Dictionary, id) -> Variant:
	for p in s.parties:
		if p.id == id: return p
	return null

func rivals(s: Dictionary) -> Array:
	return s.parties.filter(func(p): return not p.isPlayer)

## JavaScript's Math.round: halves round up (toward +infinity).
static func jround(x: float) -> int:
	return int(floor(x + 0.5))

## JavaScript's +x.toFixed(n)
static func fixed(x: float, n: int) -> float:
	return float(("%." + str(n) + "f") % x)

static func fmt1(x: float) -> String:
	return "%.1f" % x

static func merged(a: Dictionary, b: Dictionary) -> Dictionary:
	var out = a.duplicate()
	for k in b: out[k] = b[k]
	return out

static func dsum(d: Dictionary) -> float:
	var t = 0.0
	for k in d: t += d[k]
	return t

## A stable sort like JavaScript's Array.sort: cmp(a, b) < 0 puts a first.
static func ssort(arr: Array, cmp: Callable) -> Array:
	if arr.size() <= 1: return arr.duplicate()
	var mid = arr.size() / 2
	var left = ssort(arr.slice(0, mid), cmp)
	var right = ssort(arr.slice(mid), cmp)
	var out = []
	var i = 0
	var j = 0
	while i < left.size() and j < right.size():
		if cmp.call(left[i], right[j]) <= 0:
			out.append(left[i]); i += 1
		else:
			out.append(right[j]); j += 1
	while i < left.size(): out.append(left[i]); i += 1
	while j < right.size(): out.append(right[j]); j += 1
	return out

# ---------- Random numbers (mulberry32, same sequence as the browser version) ----------
const M32 := 0xFFFFFFFF

static func _imul(a: int, b: int) -> int:
	a &= M32; b &= M32
	var lo = (a & 0xFFFF) * b
	var hi = ((a >> 16) * b) & 0xFFFF
	return (lo + (hi << 16)) & M32

func rand(s: Dictionary) -> float:
	var t: int = (int(s.rng) + 0x6D2B79F5) & M32
	s.rng = t
	t = _imul(t ^ (t >> 15), t | 1)
	t = (t ^ ((t + _imul(t ^ (t >> 7), t | 61)) & M32)) & M32
	return float((t ^ (t >> 14)) & M32) / 4294967296.0

func rand_normal(s: Dictionary) -> float:
	var u = maxf(rand(s), 1e-9)
	var v = rand(s)
	return sqrt(-2.0 * log(u)) * cos(2.0 * PI * v)

func shuffle(s: Dictionary, arr: Array) -> Array:
	var i = arr.size() - 1
	while i > 0:
		var j = int(floor(rand(s) * (i + 1)))
		var t = arr[i]; arr[i] = arr[j]; arr[j] = t
		i -= 1
	return arr

func pick(s: Dictionary, arr: Array) -> Variant:
	return arr[int(floor(rand(s) * arr.size()))]

# ---------- Calendar ----------
func calendar(week: int) -> Dictionary:
	var month = week / WEEKS_PER_MONTH
	return {
		"week": week,
		"weekOfMonth": week % WEEKS_PER_MONTH,
		"monthIndex": month % int(C.monthsPerYear),
		"year": int(C.startYear) + month / int(C.monthsPerYear),
		"isMonthStart": week % WEEKS_PER_MONTH == 0,
		"isQuarterStart": week % (WEEKS_PER_MONTH * 3) == 0,
		"isYearEnd": week % WEEKS_PER_YEAR == WEEKS_PER_YEAR - 1,
	}

func date_label(week: int, with_week := false) -> String:
	var c = calendar(week)
	var base = "%s %d" % [MONTH_NAMES[c.monthIndex], c.year]
	return ("Week %d · %s" % [c.weekOfMonth + 1, base]) if with_week else base

# ---------- Stances ----------
## A short name for a set of positions, the way a commentator would put it.
## It describes; it is never a goal. Pass `perceived` for how voters see a party.
func view_label(pos: Dictionary) -> String:
	var st = {}
	for ax in AXES: st[ax.id] = stance_of(float(pos.get(ax.id, 0)))
	var nat = st.nation <= 1
	var multi = st.nation >= 3
	var state = st.economy <= 1
	var market = st.economy >= 3
	var welf = st.welfare <= 1
	var prog = st.society <= 1
	var trad = st.society >= 3
	var auth = st.order <= 1
	var lib = st.order >= 3
	var radical = st.system <= 1
	var estab = st.system >= 3
	if nat and auth and radical and (st.nation == 0 or st.order == 0): return "Far right"
	if nat and radical and (welf or state): return "National populist"
	if nat and radical: return "Right-wing populist"
	if state and radical: return "Left populist"
	if radical: return "Anti-system"
	if nat and trad: return "National conservative"
	if trad and market: return "Conservative"
	if auth and estab: return "Law-and-order conservative"
	if market and lib: return "Liberal"
	if state and st.economy == 0: return "Socialist"
	if state or welf: return "Social democrat"
	if multi and prog: return "Progressive"
	if nat: return "Nationalist"
	if trad: return "Traditionalist"
	if market: return "Free marketeer"
	return "Centrist"

func stance_of(value: float) -> int:
	var i = 0
	for b in C.stanceBounds:
		if value >= b: i += 1
	return i

func stance_name(axis_id: String, index: int) -> String:
	return by_id(AXES, axis_id).stances[index]

static func side_key(axis: String, side: String) -> String:
	return axis + ":" + side

func side_label(key: String) -> String:
	var parts = key.split(":")
	var a = by_id(AXES, parts[0])
	return a.left if parts[1] == "L" else a.right

# ---------- Starting a new game ----------
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
		"debates": [], "debatesPast": [], "debateCooldown": {}, "spoke": {}, "issues": [], "issueCooldown": {}, "communities": {}, "figures": [], "figuresLost": [], "steer": null, "home": "", "districts": {}, "projection": {}, "lastVisit": -99, "relations": {}, "relationNotes": {}, "relScars": {}, "flagship": {}, "roadFund": 0.0, "roadPerTrip": 0.0,
	}
	for p in PARTIES:
		var me: bool = p.get("isPlayer", false)
		s.parties.append({
			"id": p.id,
			"name": party_name if me else p.name,
			"short": initials(party_name) if me else p.short,
			"leader": leader_name if me else p.leader,
			"leaderSex": pp.sex if me else p.get("leaderSex", "m"),
			"leaderAge": pp.age if me else p.get("leaderAge", 60),
			"charisma": float(C.startCharisma) if me else float(p.get("charisma", 50)),
			"stability": float(p.get("stability", 60)),
			"establishment": float(p.get("establishment", 0.5)),
			"color": color if me else p.color,
			"emblem": emblem if me else p.get("emblem", "star"),
			"portraitSeed": pp.seed if me else null,
			"isPlayer": me,
			"ruling": p.get("ruling", false),
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
	s.pops = build_pops(s)
	_home_start(s, str(opts.get("home", "")))
	seed_loyalty(s)
	s.figures = new_figures(s)
	s.media = new_media(s)
	# the country is already arguing about something
	var general = TOPICS.filter(func(t): return not t.has("trigger"))
	for i in 2:
		var t: Dictionary = pick(s, general)
		general.erase(t)
		open_debate(s, t.id, t.axis, t.title, t.text, "news", 28.0 + rand(s) * 20, (rand(s) - 0.5) * 40)
	for i in 2:
		var it: Dictionary = pick(s, ISSUES.filter(func(x): return not s.issues.any(func(y): return y.id == x.id)))
		s.issues.append({"id": it.id, "week": s.week})
		s.issueCooldown[it.id] = s.week
	s.lastSupport = summarize(s, s.pops).support
	run_hooks(s)
	return s

## The leader was mayor of a city before splitting off to found the party:
## its region knows them and likes them, and there is already a party office there.
## Alinni's cities can't be chosen: Alinnians elect their own minority leaders.
func home_cities() -> Array:
	return country_cities().filter(func(c): return c.area != "alinni")

## Cranebonistan's own cities (the map also has the neighbours' capitals).
func country_cities() -> Array:
	return MAP.cities.filter(func(c): return REGIONS.any(func(r): return r.id == c.area))

## City facts from data/cities.json (population in millions, a lean per axis
## on top of its region's, and a line about the place). Missing values fall back
## to an estimate from the region's size and the dot size on the map.
func city_population(c: Dictionary) -> float:
	var info: Dictionary = CITY_INFO.get(c.name, {})
	if info.has("population"): return float(info.population) * 1e6
	var r = by_id(REGIONS, c.area)
	var share: float = {3: 0.28, 2: 0.12, 1: 0.05}.get(int(c.get("size", 1)), 0.05)
	return float(r.adults) * 1e6 * 1.3 * share if r else 0.0

func city_fact(c: Dictionary) -> String:
	return str(CITY_INFO.get(c.name, {}).get("fact", ""))

## Where the city's people stand: its region's average, moved by the city's own lean.
func city_leanings(s: Dictionary, c: Dictionary) -> Dictionary:
	var hd = district_of_city(c.name)
	var pos: Dictionary = summarize(s, pops_matching(s, {"district": hd.id} if hd else {"region": c.area})).pos.duplicate()
	var lean: Dictionary = CITY_INFO.get(c.name, {}).get("lean", {})
	for ax in lean: pos[ax] = clampf2(float(pos.get(ax, 0)) + float(lean[ax]), -100, 100)
	return pos

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

func full_vector(v: Dictionary) -> Dictionary:
	var out = {}
	for ax in AXES: out[ax.id] = clampf2(float(v.get(ax.id, 0)), -100, 100)
	return out

func initials(name: String) -> String:
	var words = name.strip_edges().split(" ", false)
	var out = ""
	if words.size() > 1:
		for w in words: out += w[0]
	else:
		out = name.substr(0, 3)
	out = out.to_upper().substr(0, 4)
	return out if out != "" else "YOU"

## Voters: one group for every province, age, class and nationality that lives
## there. A province takes its region's people and views, then its own character:
## towns are more middle-class, more mixed and more progressive than the
## countryside, a city's own lean (cities.json) counts for its share of the
## province, and every game adds a little local difference (s.districts[id].lean).
const POP_MIN := 3000.0

func build_pops(s: Dictionary) -> Array:
	var pops = []
	for d in DISTRICTS:
		var r = by_id(REGIONS, d.region)
		var people: float = float(r.adults) * 1e6 * float(d.share)
		var st: Dictionary = s.districts.get(d.id, {})
		# how urban: the share of the province living in its cities
		var city_people = 0.0
		var city_lean = {}
		for name in d.cities:
			var c: Dictionary = city_by_name(name)
			if c.is_empty(): continue
			var cp: float = city_population(c) * 0.75
			city_people += cp
			var cl: Dictionary = CITY_INFO.get(name, {}).get("lean", {})
			for ax in cl: city_lean[ax] = float(city_lean.get(ax, 0)) + float(cl[ax]) * cp
		var urban: float = clampf2(city_people / people, 0, 1) if people > 0 else 0.0
		var cls = {}
		var ctot = 0.0
		for c in CLASSES:
			var k: float = {"working": 1 - 0.35 * urban, "middle": 1 + 0.3 * urban, "upper": 1 + 0.6 * urban}.get(c.id, 1.0)
			cls[c.id] = float(r.classes.get(c.id, 0)) * k
			ctot += cls[c.id]
		var nats = {}
		var ntot = 0.0
		for n in NATIONALITIES:
			var share: float = float(r.nationalities.get(n.id, 0))
			if share <= 0: continue
			# minorities gather in towns
			var big = 0.0
			for m in NATIONALITIES: big = maxf(big, float(r.nationalities.get(m.id, 0)))
			nats[n.id] = share * (1.0 if share >= big else 1 + 0.5 * urban)
			ntot += nats[n.id]
		var local_lean = {}
		for ax in AXES:
			var v: float = float(st.get("lean", {}).get(ax.id, 0))
			if city_people > 0: v += float(city_lean.get(ax.id, 0)) / people
			local_lean[ax.id] = v
		local_lean.society = float(local_lean.get("society", 0)) + (0.4 - urban) * 20   # countryside more traditional
		local_lean.nation = float(local_lean.get("nation", 0)) + (urban - 0.4) * 15     # towns more mixed
		for a in AGES:
			for c in CLASSES:
				for nid in nats:
					var n = by_id(NATIONALITIES, nid)
					var size: float = people * float(a.share) * cls[c.id] / ctot * nats[nid] / ntot
					if size < POP_MIN: continue
					var local: Dictionary = r.get("local", {}).get(nid, {})
					var pos = {}
					var sal = {}
					for ax in AXES:
						var lean: float = float(r.lean.get(ax.id, 0)) + float(a.lean.get(ax.id, 0)) + float(c.lean.get(ax.id, 0)) \
							+ float(n.lean.get(ax.id, 0)) + float(local.get("lean", {}).get(ax.id, 0)) + float(local_lean.get(ax.id, 0))
						pos[ax.id] = float(jround(clampf2(lean + rand_normal(s) * 7, -100, 100)))
						sal[ax.id] = fixed(_or1(r.sal.get(ax.id)) * _or1(a.sal.get(ax.id)) * _or1(c.sal.get(ax.id)) \
							* _or1(n.sal.get(ax.id)) * _or1(local.get("sal", {}).get(ax.id)), 2)
					var pop = {
						"id": "%s/%s/%s/%s" % [d.id, a.id, c.id, nid],
						"region": r.id, "district": d.id, "age": a.id, "class": c.id, "nationality": nid,
						"size": float(jround(size)), "pos": pos, "base": pos.duplicate(), "sal": sal, "shield": {},
						"turnout": clampf2(a.turnout + c.turnout + n.turnout + float(r.get("turnout", 0)), 0.25, 0.95),
						"engagement": a.engagement * c.engagement,
						"leaderPull": fixed(_or1(a.get("leaderAppeal")) * _or1(c.get("leaderAppeal")) * _or1(n.get("leaderAppeal")) * _or1(r.get("leaderAppeal")), 2),
						"disaffection": fixed(clampf2(1 + (-pos.system) / 60.0 + float(c.get("disaffect", 0)) + float(r.get("disaffect", 0)), 0.3, 2), 2),
						"mobilized": 0.0,
						"loyal": {}, "goodwill": {}, "aware": {}, "leader": {},
					}
					for p in s.parties:
						var reach: Dictionary = by_id(PARTIES, p.id).get("reach", {})
						pop.loyal[p.id] = 0.0
						pop.goodwill[p.id] = 0.0
						pop.leader[p.id] = 0.0
						pop.aware[p.id] = float(C.startAwareness) if p.isPlayer else float(reach.get(r.id, reach.get("default", 1)))
					pops.append(pop)
	return pops

static func _or1(v) -> float:
	return 1.0 if v == null or float(v) == 0.0 else float(v)

func seed_loyalty(s: Dictionary) -> void:
	var ctx = score_context(s)
	for pop in s.pops:
		var sup = pop_support(s, pop, "player", ctx)
		for id in sup: pop.loyal[id] = C.startLoyalty * sup[id]

# ---------- Consistency ----------
func inconsistency_of(s: Dictionary, party: Dictionary) -> float:
	var steps = 0.0
	for ax in AXES:
		var off: int = absi(stance_of(party.perceived[ax.id]) - stance_of(party.manifesto[ax.id]))
		steps += C.stepPenalty[off]
	return steps

# ---------- Opinion ----------
func salience_of(s: Dictionary, pop: Dictionary, axis: String) -> float:
	var climate: float = float(s.climate.get(axis, 0)) + float(s.get("regionClimate", {}).get(pop.region, {}).get(axis, 0))
	return pop.sal[axis] * maxf(0.3, 1 + float(s.salMod.get(axis, 0)) + climate + float(s.permSal.get(axis, 0)))

func distance(s: Dictionary, pop: Dictionary, pos: Dictionary) -> float:
	var d = 0.0
	var w = 0.0
	for ax in AXES:
		var sa = salience_of(s, pop, ax.id)
		d += sa * absf(pop.pos[ax.id] - pos[ax.id])
		w += sa
	return d / w

func devotion_of(pop: Dictionary, party: Dictionary) -> float:
	if not party.isPlayer: return 0.0
	var attachment: float = pop.leader[party.id] * pop.leaderPull * (party.charisma / 50.0) * (0.85 + 0.4 * float(party.get("extremity", 0)))
	return clampf2((attachment - C.devotionStart) / C.devotionRange, 0, 1)

func score_context(s: Dictionary) -> Dictionary:
	var inc = {}
	var own = {}
	for p in s.parties:
		inc[p.id] = inconsistency_of(s, p)
		own[p.id] = []
	for key in s.ownership:
		var owners: Dictionary = s.ownership[key]
		var total = dsum(owners)
		var parts: PackedStringArray = key.split(":")
		for pid in owners:
			var v: float = owners[pid]
			if v < 0.02 or not own.has(pid): continue
			own[pid].append({"axis": parts[0], "side": parts[1], "value": v / maxf(total, C.ownShareFloor + v * 0.5)})
	var distrust: float = (50.0 - s.trust) / 50.0
	var fit = {}
	for p in s.parties: fit[p.id] = leader_fit(s, p)
	return {"inc": inc, "own": own, "distrust": distrust, "fit": fit, "clim": leader_climate(s, distrust)}

# ---------- What kind of leader people want ----------
## A group's wish for each kind of leader (data/leader_types.json), summing to 1.
## It comes from who they are; the climate (leader_climate) then raises some wishes.
func pop_wants(pop: Dictionary) -> Dictionary:
	var w = {}
	var tot = 0.0
	for t in LEADER_TYPES:
		var v: float = float(t.get("base", 1))
		var by: Dictionary = t.get("by", {})
		v += float(by.get("age", {}).get(pop.age, 0)) + float(by.get("class", {}).get(pop.class, 0))
		v += float(by.get("region", {}).get(pop.region, 0)) + float(by.get("nationality", {}).get(pop.nationality, 0))
		var lean: Dictionary = t.get("lean", {})
		for key in lean:
			var parts: PackedStringArray = String(key).split(":")
			var x: float = float(pop.pos[parts[0]])
			if (parts[1] == "L" and x < -25) or (parts[1] == "R" and x > 25): v += float(lean[key])
		v += float(t.get("disaffected", 0)) * maxf(0, float(pop.disaffection) - 1)
		v += float(t.get("pull", 0)) * (float(pop.leaderPull) - 1)
		w[t.id] = maxf(0.05, v)
		tot += w[t.id]
	for k in w: w[k] = w[k] / tot
	return w

## How the times change what people want: a crisis, a hot border, hard times, low trust,
## and anything events added (s.wantMod, which fades).
func leader_climate(s: Dictionary, distrust: float) -> Dictionary:
	var war = false
	for f in FOREIGN:
		if s.countries.get(f.id, {}).get("hot", false): war = true
	var hard: float = maxf(metric_badness(s, "jobs"), metric_badness(s, "prices")) if s.has("world") else 0.0
	var mods: Dictionary = s.get("wantMod", {})
	var out = {}
	for t in LEADER_TYPES:
		var cl: Dictionary = t.get("climate", {})
		var k: float = 1.0 + float(mods.get(t.id, 0))
		if s.get("crisis"): k += float(cl.get("crisis", 0))
		if war: k += float(cl.get("war", 0))
		k += float(cl.get("hard_times", 0)) * hard
		k += float(cl.get("distrust", 0)) * maxf(0, distrust)
		out[t.id] = maxf(0.2, k)
	return out

## How well a party's leader fits each kind (0..1): your leader from the words you
## choose, your record and how voters see you; rivals from their party.
func leader_fit(s: Dictionary, p: Dictionary) -> Dictionary:
	var pos: Dictionary = p.perceived
	var ch: float = clampf2((float(p.charisma) - 30) / 50.0, 0, 1)
	var est: float = float(p.get("establishment", 0.5))
	var radical: float = clampf2(-float(pos.system) / 70.0, 0, 1)
	var auth: float = clampf2(-float(pos.order) / 70.0, 0, 1)
	var hawk: float = clampf2(-float(pos.foreign) / 70.0, 0, 1)
	var ext = 0.0
	for ax in AXES: ext += absf(float(pos[ax.id])) / 80.0
	var calm: float = clampf2(1 - ext / AXES.size(), 0, 1)
	var tone = {"statesman": 0.25 + 0.5 * est, "fiery": 0.15 + 0.3 * maxf(radical, auth), "folksy": 0.2, "provocative": 0.1 * radical}
	var visits = 0
	var stains = 0.0
	var slips = 0.0
	var memes = 0.0
	if p.isPlayer:
		est = clampf2(0.5 + float(pos.system) / 140.0, 0, 1)
		var sh: Dictionary = style_profile(s).shares
		if sh.size(): tone = {"statesman": float(sh.get("statesman", 0)), "fiery": float(sh.get("fiery", 0)), "folksy": float(sh.get("folksy", 0)), "provocative": float(sh.get("provocative", 0))}
		for id in s.get("districts", {}): visits += int(s.districts[id].get("visits", 0))
		stains = s.record.money.filter(func(m): return m.dirty).size() * 0.35 + float(s.record.outrages) * 0.1
		slips = float(s.record.gaffes)
		memes = float(s.record.memes)
	else:
		stains = clampf2((60 - float(p.get("stability", 60))) / 60.0, 0, 1)
	var f = {
		"star": 0.6 * ch + 0.3 * (tone.folksy + tone.provocative) + minf(0.2, memes * 0.04),
		"statesman": 0.45 * tone.statesman + 0.3 * calm + 0.25 * (1 - radical) - minf(0.4, slips * 0.06),
		"revolutionary": 0.55 * radical + 0.3 * (tone.fiery + tone.provocative) + 0.15 * (1 - est),
		"strongman": 0.35 * auth + 0.15 * hawk + 0.3 * tone.fiery + 0.2 * ch,
		"one_of_us": 0.5 * tone.folksy + 0.3 * (1 - est) + 0.2 * minf(1, visits / 12.0),
		"clean": 0.5 * (1 - est) + 0.5 * (1 - minf(1, stains)),
		"expert": 0.45 * tone.statesman + 0.35 * calm + 0.2 * (1 - minf(1, tone.provocative * 2)) - minf(0.3, slips * 0.05),
	}
	for k in f: f[k] = clampf2(f[k], 0, 1)
	return f

## What a set of voters wants in a leader today, strongest first: [{type, share}].
func group_wants(s: Dictionary, pops: Array) -> Array:
	var clim: Dictionary = leader_climate(s, (50.0 - s.trust) / 50.0)
	var sum = {}
	var tot = 0.0
	for pop in pops:
		if not pop.has("wants"): pop.wants = pop_wants(pop)
		for k in pop.wants:
			var v: float = float(pop.size) * float(pop.wants[k]) * float(clim.get(k, 1.0))
			sum[k] = float(sum.get(k, 0)) + v
			tot += v
	var out = []
	for t in LEADER_TYPES: out.append({"type": t, "share": float(sum.get(t.id, 0)) / tot if tot else 0.0})
	return ssort(out, func(a, b): return b.share - a.share)

## How a party's leader comes across, best fit first: [{type, fit}].
func leader_image(s: Dictionary, p: Dictionary) -> Array:
	var f: Dictionary = leader_fit(s, p)
	var out = []
	for t in LEADER_TYPES: out.append({"type": t, "fit": float(f.get(t.id, 0))})
	return ssort(out, func(a, b): return b.fit - a.fit)

## How well a party's leader matches what this group wants (0..1).
func leader_match(pop: Dictionary, fit: Dictionary, clim: Dictionary) -> float:
	if not pop.has("wants"): pop.wants = pop_wants(pop)
	var num = 0.0
	var den = 0.0
	for k in pop.wants:
		var w: float = float(pop.wants[k]) * float(clim.get(k, 1.0))
		num += w * float(fit.get(k, 0.4))
		den += w
	return num / den if den > 0 else 0.4

func party_score(s: Dictionary, pop: Dictionary, party: Dictionary, ctx: Dictionary) -> float:
	var dev = devotion_of(pop, party)
	var sc = -distance(s, pop, party.perceived) / C.distanceScale * (1 - C.devotionBlind * dev)
	var gw: float = pop.goodwill[party.id]
	var aw: float = pop.aware[party.id]
	var st = s.districts.get(pop.get("district", ""), null)
	if st:
		if party.isPlayer:
			gw += float(st.goodwill)
			aw = aw + float(st.aware) * (1 - aw)
		else: gw += float(st.rivals.get(party.id, 0))
	sc += gw
	sc += log(maxf(aw, 0.001))
	if party.isPlayer: sc += C.leaderWeight * pop.leader[party.id] * pop.leaderPull * (party.charisma / 50.0)
	else: sc += C.rivalLeaderWeight * ((party.charisma - 50) / 50.0) * pop.leaderPull
	# the kind of leader they want, against the kind this one is
	if LEADER_TYPES.size() and ctx.has("fit"): sc += C.typeWeight * (leader_match(pop, ctx.fit[party.id], ctx.clim) - 0.4) * pop.leaderPull
	var penalty = maxf(0, ctx.inc[party.id] - C.inconsistencyTolerance) / 4.0
	sc -= penalty * pop.engagement * (1 - C.devotionBlind * dev)
	sc += C.trustWeight * ctx.distrust * (0.5 - party.establishment) * pop.disaffection
	for o in ctx.own[party.id]:
		var p: float = pop.pos[o.axis]
		if (o.side == "L" and p < -15) or (o.side == "R" and p > 15):
			var care = salience_of(s, pop, o.axis) - C.singleIssueFrom
			if care > 0: sc += C.ownWeight * o.value * care
	return sc

func pop_support(s: Dictionary, pop: Dictionary, exclude, ctx = null) -> Dictionary:
	if ctx == null: ctx = score_context(s)
	var parties: Array = s.parties.filter(func(p): return p.id != exclude)
	var scores = []
	var top = -INF
	for p in parties:
		var v = party_score(s, pop, p, ctx)
		scores.append(v)
		top = maxf(top, v)
	var weights = []
	var total = 0.0
	for v in scores:
		var w = exp(v - top)
		weights.append(w); total += w
	var loyal_total = 0.0
	for p in parties: loyal_total += pop.loyal[p.id]
	var out = {}
	for i in parties.size():
		out[parties[i].id] = pop.loyal[parties[i].id] + (1 - loyal_total) * (weights[i] / total)
	return out

func pop_votes(pop: Dictionary, sup: Dictionary) -> Dictionary:
	var out = {}
	for id in sup:
		var t: float = minf(0.97, pop.turnout + pop.mobilized) if id == "player" else pop.turnout
		out[id] = pop.size * t * sup[id]
	return out

# ---------- Groups ----------
func group_kinds() -> Array:
	var ages = AGES.map(func(a): return {"id": a.id, "label": a.label, "who": {"age": a.id}})
	var nats = NATIONALITIES.map(func(n): return {"id": n.id, "label": n.label, "who": {"nationality": n.id}})
	var classes = CLASSES.map(func(c): return {"id": c.id, "label": c.label, "who": {"class": c.id}})
	var regions = REGIONS.map(func(r): return {"id": r.id, "label": r.name, "who": {"region": r.id}})
	return [
		{"id": "age", "label": "Age groups", "groups": ages},
		{"id": "views", "label": "Political views", "groups": VIEW_GROUPS},
		{"id": "nationality", "label": "Nationality", "groups": nats},
		{"id": "class", "label": "Social class", "groups": classes},
		{"id": "region", "label": "Region", "groups": regions},
	]

func matches(pop: Dictionary, who) -> bool:
	if who == null: return true
	for key in who:
		var val = who[key]
		if key == "lean":
			for ax in val:
				var cond: String = val[ax]
				var n = float(cond.substr(1))
				if cond[0] == ">":
					if not (pop.pos[ax] > n): return false
				elif not (pop.pos[ax] < n): return false
		elif key == "loyalTo":
			if not (float(pop.loyal.get(val, 0)) > 0.2): return false
		elif val is Array:
			if not val.has(pop[key]): return false
		elif pop.get(key) != val: return false
	return true

func pops_matching(s: Dictionary, who) -> Array:
	return s.pops.filter(func(p): return matches(p, who))

func size_of(s: Dictionary, who) -> float:
	var t = 0.0
	for p in pops_matching(s, who): t += p.size
	return t

func summarize(s: Dictionary, pops: Array, ctx = null) -> Dictionary:
	if ctx == null: ctx = score_context(s)
	var res = {"size": 0.0, "voters": 0.0, "turnout": 0.0, "support": {}, "core": {}, "pos": {}, "sal": {},
		"aware": 0.0, "leader": 0.0, "leaderPull": 0.0, "backers": 0.0, "devotion": 0.0, "followers": 0.0,
		"disaffection": 0.0, "mobilized": 0.0}
	var player = player_party(s)
	for p in s.parties:
		res.support[p.id] = 0.0
		res.core[p.id] = 0.0
	for ax in AXES:
		res.pos[ax.id] = 0.0
		res.sal[ax.id] = 0.0
	for pop in pops:
		var sup = pop_support(s, pop, null, ctx)
		var votes = pop_votes(pop, sup)
		res.size += pop.size
		for p in s.parties:
			res.support[p.id] += votes[p.id]
			res.voters += votes[p.id]
			res.core[p.id] += pop.size * pop.loyal[p.id]
		for ax in AXES:
			res.pos[ax.id] += pop.size * pop.pos[ax.id]
			res.sal[ax.id] += pop.size * salience_of(s, pop, ax.id)
		var dev = devotion_of(pop, player)
		res.aware += pop.size * pop.aware.player
		res.leader += pop.size * pop.leader.player
		res.leaderPull += pop.size * pop.leaderPull
		res.disaffection += pop.size * pop.disaffection
		res.mobilized += pop.size * pop.mobilized
		res.backers += pop.size * sup.player
		res.devotion += pop.size * sup.player * dev
		if dev >= 0.8: res.followers += pop.size * sup.player
	if res.size:
		var voters: float = res.voters if res.voters else 1.0
		for id in res.support: res.support[id] /= voters
		for ax in AXES:
			res.pos[ax.id] /= res.size
			res.sal[ax.id] /= res.size
		res.turnout = res.voters / res.size
		for k in ["aware", "leader", "leaderPull", "disaffection", "mobilized"]: res[k] /= res.size
		res.devotion = res.devotion / res.backers if res.backers else 0.0
	return res

# ---------- Effects ----------
func shift_perceived(s: Dictionary, shift, record := true) -> void:
	if shift == null: return
	var player = player_party(s)
	for ax in shift:
		var before = stance_of(player.perceived[ax])
		player.perceived[ax] = clampf2(player.perceived[ax] + shift[ax], -100, 100)
		var after = stance_of(player.perceived[ax])
		if record and before != after:
			s.flips.append({"party": player.id, "week": s.week, "axis": ax, "from": before, "to": after})

func preview_shift(s: Dictionary, shift) -> Array:
	var player = player_party(s)
	var out = []
	if shift == null: return out
	for ax in shift:
		out.append({"axis": ax, "delta": shift[ax], "from": stance_of(player.perceived[ax]),
			"to": stance_of(clampf2(player.perceived[ax] + shift[ax], -100, 100)), "manifesto": stance_of(player.manifesto[ax])})
	return out

func influence_of(s: Dictionary) -> float:
	var share: float = s.lastSupport.player if s.lastSupport else 0.03
	return clampf2(share / C.influenceAt, C.influenceMin, C.influenceMax)

func influence_label(s: Dictionary) -> String:
	var i = influence_of(s)
	if i < 0.4: return "Fringe voice"
	if i < 0.8: return "Getting noticed"
	if i < 1.2: return "Agenda-setter"
	return "Sets the national debate"

static func _leader_list(v) -> Array:
	if v == null: return []
	if v is Array: return v
	return [v]

func apply_effects(s: Dictionary, fx: Dictionary) -> void:
	var player = player_party(s)
	var ext: float = player.get("extremity", 0.0)
	var inf = influence_of(s)
	var from_news: bool = fx.get("fromNews", false)
	shift_perceived(s, fx.get("shift"))
	for g in fx.get("goodwill", []):
		var party: String = g.get("party", player.id)
		var amt: float = g.amt
		if amt < 0 and party == player.id: amt = amt * (1 - C.extremeAnger / 2.0 + C.extremeAnger * ext)
		for pop in s.pops:
			if matches(pop, g.get("who")):
				var a2: float = amt * (1 - shield_of(pop, party)) if amt < 0 else amt   # friendly media explain it away
				pop.goodwill[party] = clampf2(pop.goodwill[party] + a2 * C.goodwillScale, -2, 2)
	for id in fx.get("crisis", {}):
		if s.crisis: break
		s.crisisPressure[id] = maxf(-3, float(s.crisisPressure.get(id, 0)) + fx.crisis[id] * inf)
	for k in fx.get("world", {}):
		if s.world.has(k): s.world[k] = clampf2(s.world[k] + fx.world[k] * (1.0 if from_news else inf), 0, 100)
	for ax in fx.get("permSal", {}): s.permSal[ax] = float(s.permSal.get(ax, 0)) + fx.permSal[ax]
	if fx.get("leader"):
		var scale: float = player.charisma / 50.0 * (1 - C.extremeLeader / 2.0 + C.extremeLeader * ext)
		var list = _leader_list(fx.leader)
		for pop in s.pops:
			for g in list:
				var who = {} if (g is float or g is int) else g.get("who")
				var amt: float = float(g) if (g is float or g is int) else g.amt
				if matches(pop, who): pop.leader.player = clampf2(pop.leader.player + amt * scale, -2, 2)
	if fx.get("charisma"): player.charisma = clampf2(player.charisma + fx.charisma, 10, 100)
	# events can make people want a different kind of leader for a while: {"wants": {"strongman": 0.4}}
	if fx.has("wants"):
		if not s.has("wantMod"): s.wantMod = {}
		for k in fx.wants: s.wantMod[k] = clampf2(float(s.wantMod.get(k, 0)) + float(fx.wants[k]), -0.6, 1.5)
	for ax in fx.get("salience", {}):
		s.salMod[ax] = clampf2(float(s.salMod.get(ax, 0)) + fx.salience[ax] * (1.0 if from_news else inf), -0.5, 1.5)
	if fx.get("trust"): change_trust(s, fx.trust * (1.0 if (from_news or fx.trust > 0) else inf))
	for pid in fx.get("stability", {}):
		var p = party_of(s, pid)
		if p: p.stability = clampf2(p.stability + fx.stability[pid], 0, 100)
	var coverage: float = fx.awareness if fx.has("awareness") and fx.awareness != null else C.eventAwareness
	for pop in s.pops:
		pop.aware[player.id] = clampf2(pop.aware[player.id] + (1 - pop.aware[player.id]) * coverage, 0.01, 1)
	if fx.get("money"): s.money = maxf(0, s.money + fx.money)
	for c in fx.get("country", []): note_country(s, c)
	if fx.get("flag"): s.flags[fx.flag] = s.week
	if fx.get("scandal"): s.scandals.append(merged(fx.scandal, {"week": s.week}))
	if fx.get("followup"):
		var lo: int = int(fx.followup.months[0])
		var hi: int = int(fx.followup.months[1])
		var months = lo + int(floor(rand(s) * (hi - lo + 1)))
		s.scheduled.append({"id": fx.followup.event, "week": s.week + months * WEEKS_PER_MONTH})

# ---------- Neighbouring countries ----------
func note_country(s: Dictionary, c: Dictionary) -> void:
	if not s.has("countries"): s.countries = {}
	if not s.countries.has(c.id): s.countries[c.id] = {"notes": []}
	var st: Dictionary = s.countries[c.id]
	if c.get("note"): st.notes.append({"week": s.week, "text": c.note})
	if c.get("relation"): st.relation = c.relation
	if c.has("hot") and c.hot != null: st.hot = c.hot

# ---------- Trust ----------
func change_trust(s: Dictionary, d: float) -> void:
	s.trust = clampf2(s.trust + d, 0, 100)

static func trust_label(t: float) -> String:
	if t >= 60: return "High"
	if t >= 45: return "Steady"
	if t >= 30: return "Low"
	if t >= 15: return "Very low"
	return "Collapsed"

# ---------- Issue ownership ----------
func add_ownership(s: Dictionary, party_id: String, key: String, amount: float) -> void:
	if not s.ownership.has(key): s.ownership[key] = {}
	var owners: Dictionary = s.ownership[key]
	owners[party_id] = clampf2(float(owners.get(party_id, 0)) + amount, 0, 1)

func ownership_table(s: Dictionary) -> Array:
	var rows = []
	for key in s.ownership:
		var owners: Dictionary = s.ownership[key]
		var total = dsum(owners)
		var list = []
		for pid in owners:
			if owners[pid] >= 0.02: list.append([pid, owners[pid]])
		list = ssort(list, func(a, b): return b[1] - a[1])
		var owners_out = list.map(func(x): return {"party": x[0], "value": x[1], "share": x[1] / total if total else 0.0})
		var axis: String = key.split(":")[0]
		if owners_out.size():
			rows.append({"key": key, "axis": axis, "label": side_label(key), "heat": float(s.salMod.get(axis, 0)), "owners": owners_out})
	return rows

## Every party campaigns on at most two issues. Anything beyond the strongest
## two (always keeping `keep`) is lost completely.
func trim_claims(s: Dictionary, party_id: String, keep := "") -> void:
	var held = []
	for key in s.ownership:
		if float(s.ownership[key].get(party_id, 0)) > 0: held.append(key)
	held = ssort(held, func(a, b):
		if a == keep: return -1
		if b == keep: return 1
		return s.ownership[b][party_id] - s.ownership[a][party_id])
	for key in held.slice(int(C.maxSignatureIssues)): s.ownership[key].erase(party_id)

func ownership_of(s: Dictionary, party_id: String, key: String) -> float:
	return float(s.ownership.get(key, {}).get(party_id, 0))

# ---------- Rival parties ----------
func push_news(s: Dictionary, item: Dictionary) -> void:
	s.news.append(merged({"week": s.week}, item))

func free_core_voters(s: Dictionary, party: Dictionary, share: float) -> float:
	var freed = 0.0
	for pop in s.pops:
		var lost: float = pop.loyal[party.id] * share
		pop.loyal[party.id] -= lost
		freed += lost * pop.size
	return freed

func biggest_differences(s: Dictionary, a: Dictionary, b: Dictionary, n := 2) -> Array:
	var list = AXES.map(func(ax): return {"ax": ax.id, "d": b.perceived[ax.id] - a.perceived[ax.id]})
	return ssort(list, func(x, y): return absf(y.d) - absf(x.d)).slice(0, n)

func _happening_weight(id: String, p: Dictionary) -> float:
	match id:
		"scandal": return 1 + (60 - p.stability) / 40.0
		"infighting": return 0.8 + (55 - p.stability) / 30.0
		"new_leader": return 1.2 if (p.charisma < 48 or p.stability < 40) else 0.3
		"rebound": return 0.7 if p.stability < 50 else 0.4
	return 0.0

func _happening_run(id: String, s: Dictionary, p: Dictionary) -> void:
	match id:
		"scandal":
			p.stability = clampf2(p.stability - 18, 0, 100)
			p.charisma = clampf2(p.charisma - 5, 10, 100)
			change_trust(s, -4)
			for pop in s.pops: pop.goodwill[p.id] = clampf2(pop.goodwill[p.id] - 0.25, -2, 2)
			push_news(s, {"party": p.id, "kind": "bad", "title": "%s rocked by scandal" % p.short,
				"text": "Leaked messages show %s arranging state contracts for party donors. %s is in turmoil and trust in politics has fallen." % [p.leader, p.short]})
		"infighting":
			p.stability = clampf2(p.stability - 12, 0, 100)
			push_news(s, {"party": p.id, "kind": "bad", "title": "Open infighting in %s" % p.short,
				"text": "A faction inside %s is openly attacking %s. Party members are taking sides." % [p.name, p.leader]})
		"new_leader":
			var old: String = p.leader
			var used = s.parties.map(func(x): return x.leader)
			var nxt: Dictionary = pick(s, LEADER_POOL.filter(func(n): return not used.has(n.name)))
			p.leader = nxt.name; p.leaderSex = nxt.sex; p.leaderAge = nxt.age
			p.charisma = float(jround(28 + rand(s) * 50))
			p.stability = 58.0
			var ax: String = pick(s, AXES).id
			var dir = -1 if rand(s) < 0.5 else 1
			p.perceived[ax] = clampf2(p.perceived[ax] + dir * 22, -100, 100)
			p.manifesto[ax] = p.perceived[ax]
			var a = by_id(AXES, ax)
			var style = "a charismatic crowd-pleaser" if p.charisma >= 62 else ("a dull party insider" if p.charisma <= 40 else "a capable but unexciting figure")
			push_news(s, {"party": p.id, "kind": "good" if p.charisma >= 55 else "neutral", "title": "%s replaces %s with %s" % [p.short, old, p.leader],
				"text": "%s is %s, and is moving %s toward %s." % [p.leader, style, p.short, (a.left if dir < 0 else a.right).to_lower()]})
		"rebound":
			p.stability = clampf2(p.stability + 15, 0, 100)
			p.charisma = clampf2(p.charisma + 6, 10, 100)
			for pop in s.pops:
				if pop.loyal[p.id] > 0.15: pop.goodwill[p.id] = clampf2(pop.goodwill[p.id] + 0.2, -2, 2)
			push_news(s, {"party": p.id, "kind": "good", "title": "%s wins back the room" % p.leader,
				"text": "A strong conference speech has united %s again. Its base is energised." % p.short})

const HAPPENINGS := ["scandal", "infighting", "new_leader", "rebound"]

func rival_happening(s: Dictionary) -> void:
	var cands = []
	var total = 0.0
	for p in rivals(s):
		for h in HAPPENINGS:
			var w = maxf(0.05, _happening_weight(h, p))
			cands.append([p, h, w]); total += w
	var r = rand(s) * total
	for c in cands:
		r -= c[2]
		if r <= 0:
			_happening_run(c[1], s, c[0])
			return

func collapse_party(s: Dictionary, p: Dictionary) -> void:
	var freed = free_core_voters(s, p, 0.3)
	for pop in s.pops: pop.goodwill[p.id] = clampf2(pop.goodwill[p.id] - 0.3, -2, 2)
	p.stability = 45.0
	p.charisma = clampf2(p.charisma - 8, 10, 100)
	p.collapses = int(p.get("collapses", 0)) + 1
	p.lastCollapse = s.week
	p.stability = 55.0
	change_trust(s, -3)
	push_news(s, {"party": p.id, "kind": "vacuum", "title": "%s splits apart" % p.name,
		"text": "After months of infighting, a third of %s's MPs have walked out. About %s million of its loyal voters are now up for grabs. Whoever stands closest to them will pick them up." % [p.short, fmt1(freed / 1e6)]})
	s.queue.append({"type": "event", "event": defector_event(s, p, freed)})

func defector_event(s: Dictionary, p: Dictionary, _freed: float) -> Dictionary:
	var diffs = biggest_differences(s, player_party(s), p)
	var shift = {}
	for x in diffs: shift[x.ax] = signf(x.d) * 10
	var small = {}
	for x in diffs.slice(0, 1): small[x.ax] = signf(x.d) * 5
	return {
		"id": "defectors_" + p.id, "kind": "opportunity", "title": "%s rebels want to join you" % p.short,
		"text": "Fifteen MPs who walked out of %s are offering to join your party, with their local organisations. They expect you to make room for their views." % p.name,
		"choices": [
			{"label": "Welcome all of them", "effects": {"shift": shift, "awareness": 0.05, "defect": {"from": p.id, "share": 0.22},
				"goodwill": [{"who": {"loyalTo": p.id}, "amt": 0.3}]}},
			{"label": "Take only the local organisers, not the MPs", "effects": {"shift": small, "defect": {"from": p.id, "share": 0.1},
				"goodwill": [{"who": {"loyalTo": p.id}, "amt": 0.12}]}},
			{"label": "Refuse: we are not a home for failed politicians", "effects": {"awareness": 0.02, "trust": 1,
				"goodwill": [{"who": {"lean": {"system": "<-20"}}, "amt": 0.15}]}},
		],
	}

func defect(s: Dictionary, from_id: String, share: float) -> float:
	var from = party_of(s, from_id)
	var player = player_party(s)
	var moved = 0.0
	for pop in s.pops:
		var closeness = clampf2(1.4 - distance(s, pop, player.perceived) / 60.0, 0, 1)
		var m: float = pop.loyal[from_id] * share * closeness
		pop.loyal[from_id] -= m
		pop.loyal.player = clampf2(pop.loyal.player + m, 0, 0.9)
		pop.aware.player = maxf(pop.aware.player, minf(1, pop.aware.player + m * 2))
		moved += m * pop.size
	from.stability = clampf2(from.stability - 5, 0, 100)
	return moved

func rivals_adapt(s: Dictionary, before: Dictionary, now: Dictionary) -> void:
	var player = player_party(s)
	var nation = summarize(s, s.pops)
	for p in rivals(s):
		var lost: float = before[p.id] - now[p.id]
		var you_gained: float = now.player - before.player
		if lost < 0.015 or you_gained < 0.01: continue
		var scored = AXES.map(func(a): return {"a": a, "score": nation.sal[a.id] * absf(player.perceived[a.id] - p.perceived[a.id])})
		var ax: Dictionary = ssort(scored, func(x, y): return y.score - x.score)[0].a
		var d = clampf2(player.perceived[ax.id] - p.perceived[ax.id], -15, 15)
		p.perceived[ax.id] = clampf2(p.perceived[ax.id] + d, -100, 100)
		p.manifesto[ax.id] = p.perceived[ax.id]
		var side = "L" if d < 0 else "R"
		add_ownership(s, p.id, side_key(ax.id, side), 0.12)
		trim_claims(s, p.id, side_key(ax.id, side))
		push_news(s, {"party": p.id, "kind": "threat", "title": "%s copies your line on %s" % [p.short, ax.issue.to_lower()],
			"text": "Worried about losing voters to you, %s has moved %s toward %s. They will compete for the same voters." % [p.leader, p.short, (ax.left if d < 0 else ax.right).to_lower()]})

## Rivals don't only copy you: now and then one moves into an empty niche,
## a side of an issue many voters care about that no party speaks for.
const NICHE_CHANCE := 0.12
func rivals_fill_niche(s: Dictionary) -> void:
	var best = null
	var best_score = 0.0
	for ax in AXES:
		for side in ["L", "R"]:
			var key = side_key(ax.id, side)
			var held = 0.0
			for pid in s.ownership.get(key, {}): held += float(s.ownership[key][pid])
			if held >= 0.05: continue
			var sg = -1.0 if side == "L" else 1.0
			var demand = 0.0
			for pop in s.pops: demand += pop.size * maxf(0, sg * pop.pos[ax.id] / 100.0) * pop.sal[ax.id]
			# the party that can most credibly take it: already on that side, or near the middle
			for p in rivals(s):
				var lean: float = sg * p.perceived[ax.id]
				if lean < -25: continue
				var sc: float = demand * (1.0 + maxf(0, lean) / 100.0) * (0.6 + rand(s) * 0.8)
				if sc > best_score:
					best_score = sc; best = {"party": p, "ax": ax, "side": side, "key": key}
	if best == null: return
	var p: Dictionary = best.party
	var ax: Dictionary = best.ax
	var sg = -1.0 if best.side == "L" else 1.0
	p.perceived[ax.id] = clampf2(p.perceived[ax.id] + sg * 12, -100, 100)
	p.manifesto[ax.id] = p.perceived[ax.id]
	add_ownership(s, p.id, best.key, 0.12)
	trim_claims(s, p.id, best.key)
	var name = (ax.left if best.side == "L" else ax.right).to_lower()
	push_news(s, {"party": p.id, "kind": "threat", "title": "%s takes up %s" % [p.short, name],
		"text": "Nobody was speaking for %s voters on %s, so %s has started to. Expect to hear a lot more about it from them." % [name, ax.issue.to_lower(), p.leader]})

func rivals_monthly(s: Dictionary, now_support: Dictionary) -> void:
	for p in rivals(s):
		var trend: float = now_support[p.id] - s.lastSupport[p.id] if s.lastSupport else 0.0
		var d: float = (60 - p.stability) * 0.08 + rand_normal(s) * 3 + clampf2(trend * 120, -4, 4)
		if p.ruling: d -= 0.8 + maxf(0, 35 - s.trust) * 0.05
		p.stability = clampf2(p.stability + d, 0, 100)
	if rand(s) < C.rivalEventChance: rival_happening(s)
	if rand(s) < NICHE_CHANCE: rivals_fill_niche(s)
	var falling = null
	for p in rivals(s):
		if p.stability < C.collapseAt and s.week - int(p.get("lastCollapse", -999)) > C.collapseCooldownMonths * WEEKS_PER_MONTH:
			falling = p; break
	if falling: collapse_party(s, falling)

func frontrunner_scrutiny(s: Dictionary, now: Dictionary) -> void:
	if now.player < C.scrutinyFrom or rand(s) > C.scrutinyChance: return
	var story: Dictionary = pick(s, SCRUTINY_STORIES)
	apply_effects(s, merged(story.fx, {"awareness": 0.02}))
	push_news(s, {"kind": "threat", "title": story.title, "text": story.text + " Leading the polls makes you a target."})

# ---------- Monthly dynamics ----------
func monthly_update(s: Dictionary) -> void:
	for ax in s.salMod: s.salMod[ax] *= C.salienceDecay
	var wm: Dictionary = s.get("wantMod", {})
	for k in wm: wm[k] = float(wm[k]) * 0.85
	debates_monthly(s)
	issues_monthly(s)
	communities_monthly(s)
	relations_monthly(s)
	flagship_monthly(s)
	steer_monthly(s)
	figures_monthly(s)
	media_monthly(s)
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
	frontrunner_scrutiny(s, now)
	s.trustHistory.append({"week": s.week, "trust": s.trust})
	s.lastSupport = now

# ---------- Media ----------
## Each outlet works on its audience every month (data/media.json): it pulls their
## views toward its slant, warms them to the party it favours, and shields that
## party. Views are pulled back toward where they started, so nobody runs away.
const VIEW_HOME := 0.04       # monthly pull of every group's views back to where it started
const MEDIA_VIEW := 0.03      # how far a full-time viewer moves toward an outlet's slant each month
const MEDIA_WARM := 0.05      # goodwill a full-time viewer gains for the favoured party each month
const SHIELD_MAX := 0.6

func new_media(s: Dictionary) -> Dictionary:
	var out = {}
	for o in OUTLETS:
		out[o.id] = {"pos": o.get("pos", {}).duplicate(), "owner": "", "audience": 1.0, "buzz": 0.0, "favour": {}}
	return out

func outlet_by_id(id: String) -> Variant:
	return by_id(OUTLETS, id)

## The share of a group that follows an outlet.
func outlet_reach(s: Dictionary, o: Dictionary, pop: Dictionary) -> float:
	var st: Dictionary = s.media.get(o.id, {})
	var r: float = float(o.get("reach", {}).get("base", 0.1)) * float(st.get("audience", 1.0))
	var by: Dictionary = o.get("reach", {}).get("by", {})
	for key in ["age", "class", "region", "nationality"]:
		r *= float(by.get(key, {}).get(pop[key], 1.0))
	return clampf2(r, 0, 0.9)

## How honest an outlet is now: a party-owned one is less believed.
func outlet_honesty(s: Dictionary, o: Dictionary) -> float:
	var h: float = float(o.get("honesty", 0.5))
	return h * 0.5 if s.media[o.id].owner != "" else h

## How an outlet treats a party, -1..1. Partisan outlets back whoever is closest to
## their slant; honest ones follow what you actually say and how it goes ("buzz").
func outlet_favour(s: Dictionary, o: Dictionary, p: Dictionary) -> float:
	var st: Dictionary = s.media[o.id]
	if st.owner != "": return 1.0 if st.owner == p.id else -0.3
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

static func shield_of(pop: Dictionary, pid: String) -> float:
	return float(pop.get("shield", {}).get(pid, 0.0))

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
	for pop in s.pops:
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
		var k: float = 0.15 + 0.6 * (1 - h)     # how hard it moves a viewer
		var sk: float = 0.1 + 0.8 * (1 - h)     # how much it shields its favourite
		for pop in s.pops:
			var r: float = outlet_reach(s, o, pop)
			if r < 0.01: continue
			for ax in st.pos: pop.pos[ax] = clampf2(float(pop.pos[ax]) + (float(st.pos[ax]) - float(pop.pos[ax])) * r * k * MEDIA_VIEW, -100, 100)
			for pid in fav:
				var f: float = fav[pid]
				if absf(f) < 0.05: continue
				pop.goodwill[pid] = clampf2(pop.goodwill[pid] + r * k * f * MEDIA_WARM, -2, 2)
				if f > 0: pop.shield[pid] = minf(SHIELD_MAX, shield_of(pop, pid) + r * sk * f)
		st.buzz = float(st.buzz) * 0.5

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
	push_news(s, {"kind": "issue", "title": "%s changes hands" % o.name, "text": "Buyers close to %s have taken over %s. Its journalists say nothing will change." % [player_party(s).short, o.name]})
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

# ---------- Actions ----------
func can_act(s: Dictionary, cost := 0.0) -> String:
	if s.result: return "The election is over."
	if s.actionsLeft <= 0: return "No actions left this month."
	if s.money < cost: return "Needs ₱%sM." % str(cost)
	return ""

func spend_action(s: Dictionary, cost: float) -> void:
	s.actionsLeft -= 1
	s.money -= cost

func manifesto_side(s: Dictionary, axis: String) -> String:
	var st = stance_of(player_party(s).manifesto[axis])
	return "L" if st <= 1 else ("R" if st >= 3 else "")

func drop_signature(s: Dictionary, key: String) -> void:
	s.signature = s.signature.filter(func(k): return k != key)
	if s.ownership.has(key): s.ownership[key].erase("player")
	s.log.append({"week": s.week, "kind": "action", "text": "Stopped campaigning on %s." % side_label(key).to_lower()})

func _log(s: Dictionary, kind: String, text: String) -> void:
	s.log.append({"week": s.week, "kind": kind, "text": text})

# ---------- Communities ----------
## A local chapter in one city: slow to grow, and it lasts. It turns
## supporters in that region into core voters, gets them to the polls, and
## pays a little in members' dues.
const COMMUNITY_COST := [1.0, 1.5, 2.0]
const COMMUNITY_MAX := 3

func community_level(s: Dictionary, city: String) -> int:
	return int(s.communities.get(city, 0))

func city_by_name(name: String) -> Dictionary:
	for c in MAP.cities:
		if c.name == name: return c
	return {}

func act_community(s: Dictionary, city: String) -> Dictionary:
	var lvl = community_level(s, city)
	if lvl >= COMMUNITY_MAX: return {"ok": false, "text": "Your community in %s is as big as it gets." % city}
	var cost: float = COMMUNITY_COST[lvl]
	var err = can_act(s, cost)
	if err: return {"ok": false, "text": err}
	spend_action(s, cost)
	s.communities[city] = lvl + 1
	var c = city_by_name(city)
	_community_tick(s, c, 3.0)
	var text = ("You opened a party office in %s. Volunteers, a noticeboard and a kettle." if lvl == 0 else "Your community in %s is growing: more volunteers, more events, more people who'll knock on doors.") % city
	_log(s, "action", text)
	return {"ok": true, "text": text}

## One month of a community's work (k scales it, e.g. for the opening push).
func _community_tick(s: Dictionary, c: Dictionary, k := 1.0) -> void:
	var lvl = community_level(s, c.name)
	var weight = lvl * (1.0 + 0.5 * float(c.get("size", 0))) * (2.0 if c.name == MAP.capital else 1.0)
	var ctx = score_context(s)
	for pop in s.pops:
		if pop.region != c.area: continue
		var sup = pop_support(s, pop, null, ctx)
		var floating = maxf(0, sup.player - pop.loyal.player)
		pop.loyal.player = clampf2(pop.loyal.player + floating * 0.006 * weight * k, 0, 0.9)
		pop.mobilized = clampf2(pop.mobilized + 0.002 * weight * k, 0, 0.15)
		pop.aware.player = clampf2(pop.aware.player + (1 - pop.aware.player) * 0.003 * weight * k, 0, 1)

func communities_monthly(s: Dictionary) -> void:
	for name in s.communities:
		_community_tick(s, city_by_name(name))
	districts_monthly(s)

# ---------- The party's politicians ----------
## Named people in your party. Each cares most about one side of one issue.
## Steering the manifesto away from it costs their loyalty; below 25 they quit,
## and take a little of the party's reach and their region's goodwill with them.
## The founders joined for the manifesto, so they share it: each one's cause is the
## manifesto's side of their issue (the other side's note is in "noteOther"). One of
## them, picked at random, is the exception: in the party for other reasons, against
## the manifesto on their issue, and slowly losing patience unless you speak up for it.
func new_figures(s: Dictionary) -> Array:
	var out = []
	var others = FIGURES.filter(func(f): return f.id != "teyl")
	var odd: String = pick(s, others).id if others.size() else ""
	for f in FIGURES:
		var x = f.duplicate()
		x.skill = float(f.get("skill", 70))
		var mine = manifesto_side(s, f.axis)
		if f.id == "teyl":
			x.loyalty = 65.0
		elif f.id == odd:
			# the bad apple: on the other side from the manifesto (or their own, if the manifesto sits in the middle)
			if mine != "" and mine == f.side: _flip_figure(x)
			x.loyalty = 40.0
			x.doubter = true
		else:
			if mine != "" and mine != f.side: _flip_figure(x)
			x.loyalty = 72.0 if mine != "" else 60.0
		out.append(x)
	return out

func _flip_figure(x: Dictionary) -> void:
	x.side = "R" if x.side == "L" else "L"
	if x.has("noteOther"): x.note = x.noteOther

## Your words on an issue reach the politicians who care about it.
func figures_heard(s: Dictionary, axis: String, side: String) -> void:
	for f in s.figures:
		if f.axis != axis: continue
		f.loyalty = clampf2(f.loyalty + (3.0 if f.side == side else -5.0), 0, 100)

func figure_by_id(s: Dictionary, id: String) -> Variant:
	for f in s.figures:
		if f.id == id: return f
	return null

## How strong the party's bench is: 1.0 with everyone you started with.
func party_bench(s: Dictionary) -> float:
	var have = 0.0
	for f in s.figures: have += float(f.get("skill", 70)) / 70.0
	return clampf2(have / maxf(1, FIGURES.size()), 0.3, 1.3)

static func skill_word(k: float) -> String:
	if k >= 75: return "Gifted"
	if k >= 60: return "Able"
	if k >= 45: return "Ordinary"
	return "Green"

static func loyalty_word(l: float) -> String:
	if l >= 75: return "Devoted"
	if l >= 55: return "Loyal"
	if l >= 40: return "Uneasy"
	if l >= 25: return "Unhappy"
	return "Leaving"

func figures_monthly(s: Dictionary) -> void:
	for f in s.figures.duplicate():
		# someone whose cause the manifesto is against loses patience a little every month
		var mine = manifesto_side(s, f.axis)
		if f.id != "teyl" and mine != "" and mine != f.side: f.loyalty = clampf2(f.loyalty - 1.5, 0, 100)
		if f.loyalty >= 25: continue
		s.figures.erase(f)
		s.figuresLost.append({"name": f.name, "role": f.role, "week": s.week})
		for pop in s.pops:
			if pop.region == f.region: pop.goodwill.player = clampf2(pop.goodwill.player - 0.06, -2, 2)
		push_news(s, {"kind": "threat", "title": "%s quits %s" % [f.name, player_party(s).short],
			"text": "%s, %s, says the party is no longer the one %s joined. %s local supporters are not happy either." % [f.name, f.role.to_lower(), "she" if f.get("sex", "m") == "f" else "he", "Her" if f.get("sex", "m") == "f" else "His"]})
		if f.id != "teyl": _replace_figure(s, f)

## Someone who agrees with the manifesto takes the empty chair: loyal, because they
## owe the job to you, and usually less able than the person who left.
func _replace_figure(s: Dictionary, gone: Dictionary) -> void:
	var pool = LEADER_POOL.filter(func(x): return not s.figures.any(func(f): return f.name == x.name) and not s.parties.any(func(q): return q.leader == x.name) and not s.figuresLost.any(func(l): return l.name == x.name))
	if pool.is_empty(): return
	var who: Dictionary = pick(s, pool)
	var mine = manifesto_side(s, gone.axis)
	var side: String = mine if mine != "" else gone.side
	var lean_word: String = side_label(side_key(gone.axis, side)).to_lower()
	s.figures.append({"id": "new_%d_%s" % [s.week, gone.id], "name": who.name, "sex": who.get("sex", "m"), "role": gone.role, "region": gone.region,
		"axis": gone.axis, "side": side, "loyalty": 78.0, "skill": 30.0 + rand(s) * 20.0, "yes": true,
		"note": "Took over from %s. Agrees with the manifesto on %s, and on most things you say." % [gone.name, lean_word]})
	_log(s, "action", "%s replaces %s as %s." % [who.name, gone.name, String(gone.role).to_lower()])

# ---------- Steering the party ----------
## Moving the manifesto one stance takes three months. The politicians who
## care about the other side get angrier every month it goes on.
const STEER_MONTHS := 3

func steer_block(s: Dictionary, axis: String, dir: int) -> String:
	if s.steer: return "You are already steering the party on %s." % by_id(AXES, s.steer.axis).issue.to_lower()
	var st = stance_of(player_party(s).manifesto[axis])
	if st + dir < 0 or st + dir > 4: return "The manifesto can't go further that way."
	return ""

## Who would be upset, and who pleased, by moving `axis` one stance in `dir`.
func steer_reactions(s: Dictionary, axis: String, dir: int) -> Dictionary:
	var toward = "L" if dir < 0 else "R"
	var angry = []
	var pleased = []
	for f in s.figures:
		if f.axis != axis: continue
		if f.side == toward: pleased.append(f)
		else: angry.append(f)
	return {"angry": angry, "pleased": pleased}

func act_steer(s: Dictionary, axis: String, dir: int) -> Dictionary:
	var block = steer_block(s, axis, dir)
	if block: return {"ok": false, "text": block}
	var err = can_act(s, 0)
	if err: return {"ok": false, "text": err}
	spend_action(s, 0)
	s.steer = {"axis": axis, "dir": dir, "started": s.week, "months": 0}
	var rx = steer_reactions(s, axis, dir)
	for f in rx.angry: f.loyalty = clampf2(f.loyalty - 15, 0, 100)
	for f in rx.pleased: f.loyalty = clampf2(f.loyalty + 5, 0, 100)
	var t = teyl(s)
	if t: t.loyalty = clampf2(t.loyalty - 5, 0, 100)
	var ax = by_id(AXES, axis)
	var to_name = stance_name(axis, stance_of(player_party(s).manifesto[axis]) + dir)
	var text = "You told the party's leadership it is time to move toward \"%s\" on %s. It will take three months, and not everyone is happy." % [to_name.to_lower(), ax.issue.to_lower()]
	_log(s, "action", text)
	return {"ok": true, "text": text}

func steer_monthly(s: Dictionary) -> void:
	if not s.steer: return
	var st: Dictionary = s.steer
	st.months += 1
	var rx = steer_reactions(s, st.axis, st.dir)
	for f in rx.angry: f.loyalty = clampf2(f.loyalty - 8, 0, 100)
	if st.months < STEER_MONTHS: return
	var player = player_party(s)
	var cur = stance_of(player.manifesto[st.axis])
	player.manifesto[st.axis] = C.stanceCenters[clampi(cur + st.dir, 0, 4)]
	shift_perceived(s, {st.axis: st.dir * 6}, false)
	var ax = by_id(AXES, st.axis)
	push_news(s, {"kind": "issue", "quiet": true, "title": "%s changes course on %s" % [player.short, ax.issue.to_lower()],
		"text": "The party's manifesto now says %s." % stance_name(st.axis, stance_of(player.manifesto[st.axis])).to_lower()})
	_log(s, "action", "The party's new line on %s is %s." % [ax.issue.to_lower(), stance_name(st.axis, stance_of(player.manifesto[st.axis])).to_lower()])
	s.steer = null

func teyl(s: Dictionary) -> Variant:
	return figure_by_id(s, "teyl")

# ---------- Relations with the other parties (skeleton) ----------
## How each rival party feels about yours, -100 (bitter) to +100 (friendly).
## It starts from how close your policies are, drifts back there slowly, and is
## moved by what you do to them. Nothing uses it yet: later, parties standing
## aside in each other's districts, and forming a government.
func relation_base(s: Dictionary, pid: String) -> float:
	var me: Dictionary = player_party(s).perceived
	var them: Dictionary = party_of(s, pid).perceived
	var dist = 0.0
	for ax in AXES: dist += absf(float(me[ax.id]) - float(them[ax.id]))
	return clampf2(40.0 - dist / AXES.size() * 1.1, -40, 40)

## The everyday relationship (it fades back toward the base) plus scars (they don't).
func relation(s: Dictionary, pid: String) -> float:
	return clampf2(_rel_fading(s, pid) + relation_scar(s, pid), -100, 100)

func _rel_fading(s: Dictionary, pid: String) -> float:
	return float(s.get("relations", {}).get(pid, relation_base(s, pid)))

func relation_scar(s: Dictionary, pid: String) -> float:
	return float(s.get("relScars", {}).get(pid, 0.0))

const SCAR_SHARE := 0.4   # of every hostile act, the part that never fades

static func relation_word(v: float) -> String:
	if v >= 45: return "Friendly"
	if v >= 15: return "Cordial"
	if v > -15: return "Wary"
	if v > -45: return "Hostile"
	return "Bitter"

## Hostile acts leave a scar; favours heal scars first, then warm things up.
func change_relation(s: Dictionary, pid: String, delta: float, why: String) -> void:
	if not s.has("relations"): s.relations = {}
	if not s.has("relScars"): s.relScars = {}
	var fading: float = _rel_fading(s, pid)
	var scar: float = relation_scar(s, pid)
	if delta < 0:
		scar += delta * SCAR_SHARE
		fading += delta * (1 - SCAR_SHARE)
	else:
		var heal: float = minf(delta, -scar)
		scar += heal
		fading += delta - heal
	s.relations[pid] = clampf2(fading, -100, 100)
	s.relScars[pid] = clampf2(scar, -100, 0)
	if not s.has("relationNotes"): s.relationNotes = {}
	var notes: Array = s.relationNotes.get(pid, [])
	notes.append({"week": s.week, "text": why, "delta": delta})
	s.relationNotes[pid] = notes.slice(-6)

func new_relations(s: Dictionary) -> Dictionary:
	var out = {}
	for p in rivals(s): out[p.id] = relation_base(s, p.id)
	return out

## Monthly: the everyday part moves a tenth of the way back toward what your
## policies alone would earn. Scars stay until favours heal them.
func relations_monthly(s: Dictionary) -> void:
	for p in rivals(s):
		var v = _rel_fading(s, p.id)
		s.relations[p.id] = v + (relation_base(s, p.id) - v) * 0.1

func act_research(s: Dictionary, party_id: String) -> Dictionary:
	var cost: float = ACTIONS.research.cost
	var err = can_act(s, cost)
	if err: return {"ok": false, "text": err}
	spend_action(s, cost)
	var p = party_of(s, party_id)
	var r = rand(s)
	var text: String
	if r < 0.15:
		apply_effects(s, {"awareness": 0.03, "leader": -0.08,
			"goodwill": [{"who": {"class": ["middle", "upper"]}, "amt": -0.25}, {"who": {}, "amt": -0.05}]})
		text = "Your investigators were caught going through %s's bins. The press is calling it a dirty trick." % p.short
		change_relation(s, party_id, -15, "caught spying on them")
	elif r < 0.65:
		var severity = 3 if rand(s) < 0.3 else (2 if rand(s) < 0.6 else 1)
		var what: String = ["an unpaid tax bill", "an expenses fiddle", "secret payments from a tycoon"][severity - 1]
		s.dossiers.append({"party": party_id, "severity": severity, "what": what, "week": s.week})
		text = "Found it: %s involving %s. The dossier is ready to release whenever you choose." % [what, p.leader]
	else:
		text = "Your investigators found nothing useful on %s." % p.short
	_log(s, "action", text)
	return {"ok": true, "text": text}

func act_release(s: Dictionary, index: int) -> Dictionary:
	var err = can_act(s, 0)
	if err: return {"ok": false, "text": err}
	if index < 0 or index >= s.dossiers.size(): return {"ok": false, "text": "No such dossier."}
	var dos: Dictionary = s.dossiers[index]
	spend_action(s, 0)
	s.dossiers.remove_at(index)
	s.record.dossiers += 1
	var p = party_of(s, dos.party)
	var sev: float = dos.severity
	p.stability = clampf2(p.stability - 5 * sev, 0, 100)
	p.charisma = clampf2(p.charisma - 3 * sev, 10, 100)
	for pop in s.pops:
		pop.goodwill[p.id] = clampf2(pop.goodwill[p.id] - 0.12 * sev, -2, 2)
		pop.loyal[p.id] *= 1 - 0.03 * sev
	change_trust(s, -2 * sev)
	apply_effects(s, {"awareness": 0.03})
	var text = "The story broke: %s involving %s. %s is reeling." % [dos.what, p.leader, p.short]
	change_relation(s, p.id, -8.0 * sev, "you leaked a dossier on %s" % p.leader)
	_log(s, "action", text)
	return {"ok": true, "text": text}

const POACH_FIGURE_CHANCE := 0.2

func can_poach(s: Dictionary, party_id: String) -> bool:
	var p = party_of(s, party_id)
	return p.stability < 40 and s.week - int(p.get("lastPoached", -999)) >= C.poachCooldownMonths * WEEKS_PER_MONTH

func act_poach(s: Dictionary, party_id: String) -> Dictionary:
	var cost: float = ACTIONS.poach.cost
	var err = can_act(s, cost)
	if err: return {"ok": false, "text": err}
	if not can_poach(s, party_id): return {"ok": false, "text": "Nobody in that party is ready to leave right now."}
	spend_action(s, cost)
	var p = party_of(s, party_id)
	p.lastPoached = s.week
	var moved = defect(s, party_id, 0.07)
	var diffs = biggest_differences(s, player_party(s), p, 1)
	shift_perceived(s, {diffs[0].ax: signf(diffs[0].d) * 5})
	var text = "Local %s organisers crossed over to you, bringing about %dk core voters. Your image moved a little toward theirs." % [p.short, jround(moved / 1000.0)]
	change_relation(s, party_id, -10, "you poached their organisers")
	var claims = ownership_table(s).filter(func(r): return r.owners.any(func(o): return o.party == party_id))
	var pool = LEADER_POOL.filter(func(x): return not s.figures.any(func(f): return f.name == x.name) and not s.parties.any(func(q): return q.leader == x.name))
	# organisers cross over easily; one of their politicians only rarely comes with them
	if claims.size() and pool.size() and rand(s) < POACH_FIGURE_CHANCE:
		var who: Dictionary = pick(s, pool)
		var key: String = claims[0].key
		s.figures.append({"id": "poach_%d" % s.week, "name": who.name, "sex": who.sex, "role": "Former %s politician" % p.short, "region": pick(s, REGIONS).id,
			"axis": key.split(":")[0], "side": key.split(":")[1], "loyalty": 45.0, "note": "Came over from %s. Still thinks like them on %s." % [p.short, side_label(key).to_lower()]})
		text += " %s, one of their politicians, came with them." % who.name
		change_relation(s, party_id, -8, "%s defected to you" % who.name)
	_log(s, "action", text)
	return {"ok": true, "text": text}

func national_awareness(s: Dictionary) -> float:
	var size = 0.0
	var a = 0.0
	for pop in s.pops:
		size += pop.size
		a += pop.size * pop.aware.player
	return a / size

# ---------- Campaign budget ----------
func campaign_impact(s: Dictionary, alloc: Dictionary) -> Dictionary:
	# pop index -> {aware, goodwill, leader}
	var impact = {}
	var pops: Array = s.pops
	var add = func(i: int, k: String, v: float) -> void:
		if not impact.has(i): impact[i] = {"aware": pops[i].aware.player, "goodwill": 0.0, "leader": 0.0}
		impact[i][k] += v
	var aware_gain = func(i: int, rate: float) -> void:
		var cur: float = impact[i].aware if impact.has(i) else pops[i].aware.player
		add.call(i, "aware", (1 - cur) * clampf2(rate, 0, 0.6))
	for key in BUDGET_KEYS:
		var m = float(alloc.get(key, 0))
		if m <= 0: continue
		var region = by_id(REGIONS, key)
		if region:
			var f: float = m / region.adults
			for i in pops.size():
				if pops[i].region == key:
					aware_gain.call(i, CAMPAIGN.rally.aware * f)
					add.call(i, "goodwill", CAMPAIGN.rally.goodwill * f)
					add.call(i, "leader", CAMPAIGN.rally.leader * f)
		elif key == "social" or key == "tv":
			var c: Dictionary = CAMPAIGN[key]
			for i in pops.size():
				if c.ages.has(pops[i].age): aware_gain.call(i, c.aware * m)
		elif key == "tour":
			for i in pops.size():
				aware_gain.call(i, CAMPAIGN.tour.aware * m)
				add.call(i, "leader", CAMPAIGN.tour.leader * m * pops[i].leaderPull)
	return impact

func preview_budget(s: Dictionary, alloc: Dictionary) -> Dictionary:
	var impact = campaign_impact(s, alloc)
	var rows = {}
	var groups = REGIONS.map(func(r): return {"id": r.id, "who": {"region": r.id}})
	groups.append_array([{"id": "young", "who": {"age": ["18-29", "30-45"]}}, {"id": "old", "who": {"age": ["46-60", "61+"]}}, {"id": "all", "who": {}}])
	for g in groups:
		var size = 0.0
		var before = 0.0
		var after = 0.0
		var lb = 0.0
		var la = 0.0
		for i in s.pops.size():
			var pop: Dictionary = s.pops[i]
			if not matches(pop, g.who): continue
			var imp = impact.get(i)
			size += pop.size
			before += pop.size * pop.aware.player
			after += pop.size * (imp.aware if imp else pop.aware.player)
			lb += pop.size * pop.leader.player
			la += pop.size * (pop.leader.player + (imp.leader if imp else 0.0))
		rows[g.id] = {"before": before / size, "after": after / size, "leaderBefore": lb / size, "leaderAfter": la / size}
	return rows

func resolve_budget(s: Dictionary, alloc: Dictionary, offers_taken := []) -> Dictionary:
	var player = player_party(s)
	var notes = []
	for id in offers_taken:
		var offer = by_id(FUNDING_OFFERS, id)
		if offer == null: continue
		apply_effects(s, merged(offer.effects, {"awareness": 0}))
		notes.append(offer.source)
		s.record.money.append({"week": s.week, "source": offer.source, "amount": float(offer.effects.get("money", 0)), "dirty": offer.effects.has("scandal")})
	var clean = {}
	var spent = 0.0
	for key in BUDGET_KEYS:
		var m = clampf2(float(alloc.get(key, 0)), 0, maxf(0, s.money - spent))
		clean[key] = m
		spent += m
	var preview = preview_budget(s, clean)
	var impact = campaign_impact(s, clean)
	var swing = (rand(s) * 2 - 0.8) * CAMPAIGN.social.swing * clean.social if clean.social > 0 else 0.0
	for i in impact:
		var pop: Dictionary = s.pops[i]
		var imp: Dictionary = impact[i]
		pop.aware.player = clampf2(imp.aware, 0.01, 1)
		pop.goodwill.player = clampf2(pop.goodwill.player + imp.goodwill, -2, 2)
		pop.leader.player = clampf2(pop.leader.player + imp.leader * (player.charisma / 50.0) * (1 - C.extremeLeader / 2.0 + C.extremeLeader * float(player.get("extremity", 0))), -2, 2)
	if swing:
		for pop in s.pops:
			if CAMPAIGN.social.ages.has(pop.age): pop.goodwill.player = clampf2(pop.goodwill.player + swing, -2, 2)
	s.money -= spent
	s.roadFund = float(s.get("roadFund", 0)) + float(clean.get("road", 0))
	s.roadPerTrip = s.roadFund / 3.0   # a quarter has three trips
	s.lastBudget = clean.duplicate()
	_log(s, "budget", "Spent ₱%sM on campaigning%s." % [fmt1(spent), (". Took money from " + ", ".join(notes)) if notes.size() else ""])
	finish_front(s, "budget")
	return {"spent": spent, "preview": preview, "socialSwing": swing}

func business_mood(s: Dictionary) -> float:
	var ctx = score_context(s)
	var size = 0.0
	var sup = 0.0
	var gw = 0.0
	for pop in s.pops:
		if pop.class != "upper": continue
		size += pop.size
		sup += pop.size * pop_support(s, pop, null, ctx).player
		gw += pop.size * pop.goodwill.player
	return clampf2(0.25 + (sup / size) * 5 + (gw / size) * 0.8, 0, 1.6)

func quarterly_income(s: Dictionary) -> Dictionary:
	var share: float = s.lastSupport.player if s.lastSupport else 0.03
	var dues = 0.0
	for name in s.get("communities", {}): dues += 0.12 * s.communities[name]
	var grassroots: float = C.incomeBase + share * C.incomePerShare + dues
	var mood = business_mood(s)
	var business: float = C.businessBase * mood
	return {"grassroots": grassroots, "business": business, "mood": mood, "total": grassroots + business}

static func business_word(mood: float) -> String:
	if mood >= 1.1: return "generous"
	if mood >= 0.7: return "willing"
	if mood >= 0.4: return "cautious"
	return "keeping their distance"

func draw_offers(s: Dictionary) -> Array:
	var mood = business_mood(s)
	var pool = []
	for o in FUNDING_OFFERS:
		var chance: float = o.chance * minf(1.3, mood) if o.id == "chamber" else o.chance
		if rand(s) < chance: pool.append(o)
	return shuffle(s, pool).slice(0, 2).map(func(o): return o.id)

# ---------- Events ----------
func event_by_id(id) -> Variant:
	return _events_by_id.get(id)

func eligible_events(s: Dictionary) -> Array:
	var year: int = calendar(s.week).year
	var out = []
	for e in EVENTS:
		if e.get("deck", true) == false: continue
		if e.get("minYear") and year < e.minYear: continue
		if e.get("requires") and not s.flags.has(e.requires): continue
		var seen = s.flags.get("seen:" + e.id)
		if e.get("once") and seen != null: continue
		if seen != null and s.week - seen < 18 * WEEKS_PER_MONTH: continue
		out.append(e)
	return out

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
	for i in s.scandals.size():
		var sc: Dictionary = s.scandals[i]
		if rand(s) < sc.chance * C.scandalChanceScale:
			s.scandals.remove_at(i)
			return sc.event
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
	s.queue.append({"type": "event", "id": id})

## choice_index: what you say. line_index: how you say it (-1 = no sound bite).
func resolve_event(s: Dictionary, choice_index: int, line_index := -1) -> Dictionary:
	var front: Dictionary = s.queue[0]
	var ev = event_of(front)
	var choice: Dictionary = ev.choices[choice_index]
	var before: Dictionary = player_party(s).perceived.duplicate()
	var groups_before = snapshot_groups(s)
	var flips_before: int = s.flips.size()
	var fx: Dictionary = choice.effects
	apply_effects(s, fx)
	var extra = ""
	if fx.get("defect"):
		var moved = defect(s, fx.defect.from, fx.defect.share)
		change_relation(s, fx.defect.from, -10, "you took in their rebels")
		extra = " About %dk core voters came with them." % jround(moved / 1000.0)
	var delivery = null
	var quote = null
	var tone = null
	var lines: Array = choice.get("lines", [])
	if lines.size() and line_index >= 0 and line_index < lines.size():
		var line: Dictionary = lines[line_index]
		delivery = deliver_line(s, line)
		quote = line.text
		tone = line.tone
	var statement: bool = not fx.has("defect") and not str(ev.id).begins_with("defectors_")
	record_statement(s, {"text": quote if quote else choice.label, "title": ev.title, "effects": fx, "tone": tone, "spoken": quote != null, "statement": statement})
	s.flags["seen:" + str(ev.id)] = s.week
	if ev.get("kind", "") == "flagship": _flagship_made(s, ev, choice, quote)
	var eax = event_axis(ev)
	if eax != "" and ev.get("kind", "") != "trap":
		var sh = float(fx.get("shift", {}).get(eax, 0))
		var ed = open_debate(s, "ev:" + str(ev.id), eax, ev.title, ev.text, "news", 28, signf(sh) * 20)
		if ev.get("kind", "") == "crisis" or str(ev.id).begins_with("crisis_"): ed.major = true
		# your answer to the event is already your statement in the debate it starts
		ed.you = {"side": ("L" if sh < 0 else "R") if sh != 0 else "", "week": s.week, "quote": quote if quote else choice.label}
	_log(s, "event", "%s: %s%s" % [ev.title, ("\"%s\"" % quote) if quote else (choice.label + "."), extra])
	finish_front(s, "event")
	return {"before": before, "after": player_party(s).perceived.duplicate(), "flips": s.flips.slice(flips_before), "extra": extra,
		"delivery": delivery, "quote": quote, "label": choice.label, "title": ev.title, "changes": group_changes(s, groups_before)}

# ---------- News ----------
func flush_news(s: Dictionary) -> void:
	if s.news.is_empty(): return
	# debate headlines only reach the ticker and the board; the rest stop the clock
	var loud = s.news.filter(func(n): return not n.get("quiet", false))
	if loud.size(): s.queue.push_front({"type": "news", "items": loud})
	for n in s.news:
		var t: String = n.title
		s.log.append({"week": n.week, "kind": "news", "text": t if t.right(1) in [".", "?", "!"] else t + "."})
	s.news = []

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

func take_poll(s: Dictionary, label: String, silent := false) -> void:
	var ctx = score_context(s)
	var nation = summarize(s, s.pops, ctx)
	var poll = {"week": s.week, "label": label, "national": noisy(s, nation.support, C.pollError),
		"turnout": nation.turnout, "trust": s.trust, "regions": {}, "groups": {}}
	for kind in group_kinds():
		for g in kind.groups:
			var sm = summarize(s, pops_matching(s, g.who), ctx)
			if not sm.size: continue
			var entry = {"support": noisy(s, sm.support, C.pollError * 2), "core": sm.core}
			poll.groups[kind.id + ":" + g.id] = entry
			if kind.id == "region": poll.regions[g.id] = entry.support
	poll.tracker = silent
	s.polls.append(poll)
	s.projection = district_results(s)   # who would win each district today
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

# ---------- Districts ----------
## Each region is split into districts (MAP.districts, drawn by tools/build_districts.py;
## names, seats and leans can be changed in data/districts.json). A district has its
## own voters (built from its region's people, see build_pops), rival strongholds,
## and whatever you have done there (home city, offices, the leader's visits).
var DISTRICTS: Array = []

func _load_districts() -> void:
	DISTRICTS = MAP.get("districts", [])
	var data: Dictionary = {}
	if FileAccess.file_exists("res://data/districts.json"):
		data = JSON.parse_string(FileAccess.get_file_as_string("res://data/districts.json"))
	var over: Dictionary = data.get("DISTRICTS", {})
	var weight: Dictionary = data.get("REGION_WEIGHT", {})
	# overrides by id or by name: a new name, fixed seats, a lean of its own
	for d in DISTRICTS:
		var o: Dictionary = over.get(d.id, over.get(d.name, {}))
		if o.has("name"): d.name = o.name
		d.fixedSeats = int(o.get("seats", 0))
		d.fixedLean = o.get("lean", {})
	# seats by population, weighted by region (largest remainder), at least one each
	var total = 0.0
	var fixed_total = 0
	for d in DISTRICTS:
		d.people = float(by_id(REGIONS, d.region).adults) * float(d.share)
		if d.fixedSeats > 0: fixed_total += d.fixedSeats
		else: total += d.people * float(weight.get(d.region, 1.0))
	var seats_left: int = maxi(0, int(C.seats) - fixed_total)
	var rows = []
	for d in DISTRICTS:
		if d.fixedSeats > 0:
			d.seats = d.fixedSeats
			continue
		var exact: float = seats_left * d.people * float(weight.get(d.region, 1.0)) / total
		d.seats = maxi(1, int(floor(exact)))
		rows.append({"d": d, "rest": exact - floor(exact)})
	var given = 0
	for d in DISTRICTS: given += int(d.seats)
	for r in ssort(rows, func(a, b): return b.rest - a.rest).slice(0, maxi(0, int(C.seats) - given)): r.d.seats += 1

func district_by_id(id: String) -> Variant:
	for d in DISTRICTS:
		if d.id == id: return d
	return null

## Fresh local differences for a new game: a lean of its own (built into its voters) and rival strongholds.
func new_districts(s: Dictionary) -> Dictionary:
	var out = {}
	for d in DISTRICTS:
		var lean = {}
		for ax in AXES: lean[ax.id] = float(jround(rand_normal(s) * 6 + float(d.fixedLean.get(ax.id, 0))))
		var rivals = {}
		for p in s.parties:
			if not p.isPlayer: rivals[p.id] = fixed(rand_normal(s) * 0.12, 3)
		out[d.id] = {"lean": lean, "aware": 0.0, "goodwill": 0.0, "rivals": rivals, "visits": 0}
	return out

func district_of_city(city: String) -> Variant:
	for d in DISTRICTS:
		if d.cities.has(city): return d
	return null

## Your standing in one district grows (home city, offices, the leader's visits).
func district_boost(s: Dictionary, id: String, aware: float, goodwill: float) -> void:
	var st: Dictionary = s.districts[id]
	st.aware = clampf2(st.aware + aware, 0, 0.6)
	st.goodwill = clampf2(st.goodwill + goodwill, -1, 1.2)

## Votes in one district: its own voters (build_pops), with its local standing (party_score).
func district_votes(s: Dictionary, d: Dictionary, ctx) -> Dictionary:
	var out = {}
	for p in s.parties: out[p.id] = 0.0
	for pop in s.pops:
		if pop.get("district", "") != d.id: continue
		var votes = pop_votes(pop, pop_support(s, pop, null, ctx))
		for id in votes: out[id] += votes[id]
	return out

## Every district: votes, the winner, the runner-up and the winning margin (share points).
func district_results(s: Dictionary) -> Dictionary:
	var ctx = score_context(s)
	var out = {}
	for d in DISTRICTS:
		var v: Dictionary = district_votes(s, d, ctx)
		var tot = dsum(v)
		var ids: Array = ssort(v.keys(), func(a, b): return v[b] - v[a])
		out[d.id] = {"votes": v, "winner": ids[0], "second": ids[1], "seats": int(d.seats),
			"share": v[ids[0]] / tot if tot else 0.0, "margin": (v[ids[0]] - v[ids[1]]) / tot if tot else 0.0,
			"you": v.player / tot if tot else 0.0}
	return out

## The leader on the road: once a month, free, one district. People there hear
## of you and warm to you; the rest of the region a little. Going back to the same
## place keeps helping, but less each time. Local goodwill fades slowly.
const VISIT_AWARE := 0.12
const VISIT_GOODWILL := 0.16

func visit_block(s: Dictionary) -> String:
	if s.result: return "The election is over."
	if int(s.get("lastVisit", -99)) / WEEKS_PER_MONTH == s.week / WEEKS_PER_MONTH: return "%s has already been on the road this month." % player_party(s).leader
	return ""

## What makes this trip bigger or smaller. Returns the multiplier and the reasons, in words.
func visit_power(s: Dictionary, id: String) -> Dictionary:
	var d = district_by_id(id)
	var st: Dictionary = s.districts[id]
	var why: Array = []
	var k: float = 1.0 / (1.0 + 0.3 * int(st.visits))          # going back helps less each time
	if int(st.visits) > 0: why.append("they've seen you before")
	# the money set aside for trips this quarter
	var m: float = minf(float(s.get("roadFund", 0)), float(s.get("roadPerTrip", 0)))
	if m > 0:
		k *= 1.0 + 0.6 * sqrt(m)
		why.append("bigger halls and buses (₱%sM)" % fmt1(m))
	# popularity: a party people have heard good things about draws crowds
	var sup: float = float(s.lastSupport.player) if s.lastSupport else 0.0
	var pop_k: float = clampf2(0.7 + sup * 3.0, 0.7, 1.6) * sqrt(player_party(s).charisma / 50.0)
	k *= pop_k
	if pop_k >= 1.1: why.append("people want to see you")
	elif pop_k <= 0.8: why.append("few people know who you are yet")
	# a base there: an office, and voters who already back you
	var office = 0
	for c in d.cities: office = maxi(office, community_level(s, c))
	var you: float = float(s.projection.get(id, {}).get("you", 0))
	var base_k: float = 1.0 + 0.15 * office + you
	k *= base_k
	if office > 0: why.append("your office there filled the hall")
	# you spoke up recently for something these voters lean toward and care about
	var local_pos: Dictionary = summarize(s, pops_matching(s, {"district": id})).pos
	var bonus = 0.0
	var topic = ""
	for key in s.spoke:
		if s.week - int(s.spoke[key]) > 2 * WEEKS_PER_MONTH: continue
		var ax: String = key.split(":")[0]
		var sg = -1.0 if key.ends_with(":L") else 1.0
		var lean: float = float(local_pos[ax])
		if sg * lean > 10:
			var b: float = clampf2(sg * lean / 60.0, 0, 0.5)
			if b > bonus: bonus = b; topic = side_label(key).to_lower()
	if bonus > 0:
		k *= 1.0 + bonus
		why.append("you spoke up for %s, and they noticed" % topic)
	return {"k": k, "money": m, "why": why}

func act_visit(s: Dictionary, id: String) -> Dictionary:
	var block = visit_block(s)
	if block: return {"ok": false, "text": block}
	var d = district_by_id(id)
	var st: Dictionary = s.districts[id]
	var before: float = float(s.projection.get(id, {}).get("you", 0))
	var pw: Dictionary = visit_power(s, id)
	var k: float = pw.k
	st.visits = int(st.visits) + 1
	s.roadFund = maxf(0, float(s.get("roadFund", 0)) - pw.money)
	district_boost(s, id, VISIT_AWARE * k, VISIT_GOODWILL * k)
	for o in DISTRICTS:
		if o.region == d.region and o.id != id: district_boost(s, o.id, VISIT_AWARE * k * 0.1, VISIT_GOODWILL * k * 0.06)
	s.lastVisit = s.week
	s.projection = district_results(s)
	var after: float = float(s.projection[id].you)
	var text = "%s spent the month in %s: town halls, a market walkabout, a local radio phone-in. Your vote there: %d%% → %d%%." % [player_party(s).leader, d.name, jround(before * 100), jround(after * 100)]
	if pw.why.size():
		var w: String = ", ".join(pw.why)
		text += " " + w.substr(0, 1).to_upper() + w.substr(1) + "."
	_log(s, "action", "Toured %s." % d.name)
	# a short story from the trip, by how well it went
	var gain: float = (after - before) * 100
	var kind = "great" if gain >= 4 else ("good" if gain >= 1.5 else "flat")
	var town: String = d.name
	var best = -1.0
	for c in d.cities:
		var pop: float = float(CITY_INFO.get(c, {}).get("population", 0))
		if pop > best: best = pop; town = c
	var story = {"text": "", "caption": ""}
	var pool: Array = TOURS.get(kind, [])
	if pool.size(): story = pick(s, pool)
	var fill = {"leader": player_party(s).leader, "place": d.name, "town": town}
	return {"ok": true, "text": text, "kind": kind, "place": d.name, "region": d.region, "before": before, "after": after,
		"why": pw.why, "story": String(story.text).format(fill), "caption": String(story.caption).format(fill)}

## Local standing fades a little every month; offices keep their own district warm.
func districts_monthly(s: Dictionary) -> void:
	for id in s.districts:
		var st: Dictionary = s.districts[id]
		st.aware = float(st.aware) * 0.985
		st.goodwill = float(st.goodwill) * 0.95
	for name in s.communities:
		var d = district_of_city(name)
		if d: district_boost(s, d.id, 0.006 * int(s.communities[name]), 0.018 * int(s.communities[name]))

## Seats each party would win if the election were today.
## The district's winner takes two-thirds of its seats (rounded up); the rest
## are shared out by national vote. Those shared seats are counted across the
## whole country (largest remainder), then placed in the districts where each
## party did best, so a small party's votes everywhere add up to something.
const WINNER_SHARE := 2.0 / 3.0

static func winner_seats(n: int) -> int:
	return mini(n, int(ceil(n * WINNER_SHARE - 0.0001)))

func seat_allocation(res: Dictionary) -> Dictionary:
	var out = {"national": {}, "regions": {}, "districts": {}, "votes": {}}
	var party_ids: Array = []
	for d in DISTRICTS:
		for id in res[d.id].votes:
			if not party_ids.has(id): party_ids.append(id)
	for id in party_ids:
		out.national[id] = 0
		out.votes[id] = 0.0
	for r in REGIONS:
		out.regions[r.id] = {}
		for id in party_ids: out.regions[r.id][id] = 0
	var pool = 0
	var total = 0.0
	for d in DISTRICTS:
		var x: Dictionary = res[d.id]
		var w: int = winner_seats(int(d.seats))
		out.districts[d.id] = {"winner": x.winner, "won": w, "shared": {}}
		out.national[x.winner] += w
		out.regions[d.region][x.winner] += w
		pool += int(d.seats) - w
		for id in x.votes:
			out.votes[id] += x.votes[id]
			total += x.votes[id]
	# the shared seats, by national vote
	var share = {}
	var rows = []
	var given = 0
	for id in party_ids:
		share[id] = out.votes[id] / total if total else 0.0
		var exact: float = pool * share[id]
		share[id + ":n"] = int(floor(exact))
		given += int(floor(exact))
		rows.append({"id": id, "rest": exact - floor(exact)})
	for r in ssort(rows, func(a, b): return b.rest - a.rest).slice(0, pool - given): share[r.id + ":n"] += 1
	# place each party's shared seats where it did best
	var slots = {}
	for d in DISTRICTS: slots[d.id] = int(d.seats) - winner_seats(int(d.seats))
	var cand = []
	for d in DISTRICTS:
		if slots[d.id] <= 0: continue
		var tot = dsum(res[d.id].votes)
		for id in party_ids: cand.append({"d": d, "id": id, "v": res[d.id].votes[id] / tot if tot else 0.0})
	cand = ssort(cand, func(a, b): return b.v - a.v)
	var left = {}
	for id in party_ids: left[id] = share[id + ":n"]
	var placed = true
	while placed:
		placed = false
		for c in cand:
			if left[c.id] <= 0 or slots[c.d.id] <= 0: continue
			var sh: Dictionary = out.districts[c.d.id].shared
			sh[c.id] = int(sh.get(c.id, 0)) + 1
			out.national[c.id] += 1
			out.regions[c.d.region][c.id] += 1
			left[c.id] -= 1
			slots[c.d.id] -= 1
			placed = true
	for id in party_ids: out.votes[id] = share[id]
	return out

## Seats each party would win if the election were today.
func projected_seats(proj: Dictionary) -> Dictionary:
	return seat_allocation(proj).national

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

func _flagship_made(s: Dictionary, ev: Dictionary, choice: Dictionary, quote) -> void:
	var it: Dictionary = by_id(FLAGSHIP, ev.flagship)
	var sh: float = float(choice.effects.shift.get(it.axis, 0))
	var axis: String = it.axis
	if sh == 0:
		for ax in choice.effects.shift:
			axis = ax; sh = float(choice.effects.shift[ax]); break
	var side = "L" if sh < 0 else "R"
	s.flagship = {"issue": it.id, "axis": axis, "side": side, "label": choice.label, "quote": quote if quote else choice.label, "week": s.week}
	add_ownership(s, "player", side_key(axis, side), 0.25)
	s.salMod[axis] = clampf2(float(s.salMod.get(axis, 0)) + 0.3, -0.5, 1.5)

## Every month until the election, the promise keeps its voters warm.
func flagship_monthly(s: Dictionary) -> void:
	var f = s.get("flagship")
	if f == null or typeof(f) != TYPE_DICTIONARY or f.is_empty(): return
	var sg = -1.0 if f.side == "L" else 1.0
	for pop in s.pops:
		if sg * float(pop.pos[f.axis]) > 20: pop.goodwill.player = clampf2(pop.goodwill.player + 0.01 * minf(1.5, pop.sal[f.axis]), -2, 2)

# ---------- Elections ----------
func run_election(s: Dictionary) -> void:
	var res: Dictionary = district_results(s)
	var alloc: Dictionary = seat_allocation(res)
	var seats = {"national": alloc.national, "regions": alloc.regions, "districts": res, "split": alloc.districts}
	var national: Dictionary = alloc.votes
	var ranking = ssort(seats.national.keys(), func(a, b): return seats.national[b] - seats.national[a])
	s.result = {"votes": national, "seats": seats, "ranking": ranking, "playerWon": ranking[0] == "player",
		"majority": seats.national.player > C.seats / 2.0}
	s.queue.append({"type": "election"})

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
	var ruling = null
	for p in s.parties:
		if p.ruling: ruling = p; break
	if ruling and (w.jobs < 42 or w.prices > 60 or w.unrest > 60): ruling.stability = clampf2(ruling.stability - 1.5, 0, 100)
	if ruling and w.border > 65: ruling.stability = clampf2(ruling.stability + 1, 0, 100)
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
## What the country argues about. Each debate has heat (how much people talk
## about it, 0-100) and a lean (which side is winning the argument: -100 is
## the axis's left side, +100 its right). Heat raises the issue's salience,
## so whoever owns that side gains; a debate that stays hot and one-sided
## slowly moves what voters believe. The economy, the news, events, rival
## parties and the player all start, fan or cool debates.
const DEBATE_MAX := 6
const DEBATE_FAN_HEAT := 14.0
const DEBATE_FAN_LEAN := 15.0
const DEBATE_LIFE := 4.0         # months a debate runs before the country moves on
const DEBATE_LIFE_MAJOR := 6.0   # crises and other major debates last a little longer

func debate_by_id(s: Dictionary, id: String) -> Variant:
	for d in s.debates:
		if d.id == id: return d
	return null

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

func side_of_lean(axis: String, lean: float) -> String:
	var ax = by_id(AXES, axis)
	return ax.left if lean < 0 else ax.right

func debate_reach(s: Dictionary) -> float:
	return (0.6 + influence_of(s) * 0.5) * (0.85 + 0.15 * party_bench(s))

func open_debate(s: Dictionary, id: String, axis: String, title: String, text: String, source: String, heat: float, lean := 0.0) -> Dictionary:
	var d = debate_by_id(s, id)
	if d:
		d.heat = clampf2(d.heat + heat * 0.6, 0, 100)
		d.lean = clampf2(d.lean + lean * 0.5, -100, 100)
		return d
	d = {"id": id, "topic": id, "axis": axis, "title": title, "text": text, "source": source, "heat": heat, "lean": lean,
		"started": s.week, "peak": heat, "moves": [], "history": [heat]}
	s.debates.append(d)
	if s.debates.size() > DEBATE_MAX:
		var coolest = null
		for x in s.debates:
			if x != d and (coolest == null or x.heat < coolest.heat): coolest = x
		end_debate(s, coolest)
	return d

func end_debate(s: Dictionary, d: Dictionary) -> void:
	s.debates.erase(d)
	s.debateCooldown[d.id] = s.week
	s.debatesPast.append({"title": d.title, "axis": d.axis, "lean": d.lean, "peak": d.peak, "week": s.week})
	if d.peak >= 40 and absf(d.lean) >= 35:
		push_news(s, {"kind": "issue", "quiet": true, "title": "%s: the argument is settling" % d.title,
			"text": "The country has stopped shouting about it, but the %s side won the argument. Voters' minds moved, and they won't move back quickly." % side_of_lean(d.axis, d.lean).to_lower()})

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
		if pool.size():
			var t: Dictionary = pick(s, pool)
			open_debate(s, t.id, t.axis, t.title, t.text, "news", 30)
			push_news(s, {"kind": "issue", "quiet": true, "title": "New argument: " + t.title, "text": t.text})

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
		push_news(s, {"kind": "issue", "quiet": true, "title": "Everyone is talking about it: " + t.title, "text": t.text})

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
			push_news(s, {"party": p.id, "kind": "threat", "quiet": true, "title": "%s starts a fight: %s" % [p.short, t.title], "text": t.text})

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
func debate_lines(d: Dictionary, side: String) -> Array:
	var t = LINES.TOPIC_LINES.get(d.get("topic", d.id))
	if t: return t[side]
	if d.id.begins_with("issue:"): return issue_by_id(d.id.trim_prefix("issue:")).lines[side]
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
	var line: Dictionary = debate_lines(d, side)[line_index]
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
	var k = 1.0 if major else 0.6
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

## Minor issues: local stories that sit in the news for a few months.
func issues_monthly(s: Dictionary) -> void:
	s.issues = s.issues.filter(func(x): return s.week - int(x.week) < 5 * WEEKS_PER_MONTH)
	if s.issues.size() >= 5 or rand(s) > 0.5: return
	var pool = []
	var weights = []
	for it in ISSUES:
		if s.issues.any(func(x): return x.id == it.id): continue
		if debate_by_id(s, "issue:" + it.id) != null: continue
		if s.week - int(s.issueCooldown.get(it.id, -9999)) < 18 * WEEKS_PER_MONTH: continue
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
			s.issues.append({"id": pool[i].id, "week": s.week})
			s.issueCooldown[pool[i].id] = s.week
			push_news(s, {"kind": "issue", "quiet": true, "title": "In the news: " + pool[i].title, "text": pool[i].text})
			return

func issue_by_id(id: String) -> Dictionary:
	return by_id(ISSUES, id)

## How bad an indicator is for the country, 0 (fine) to 1 (dire).
const METRIC_TOPIC := {"jobs": "where_jobs", "prices": "cost_of_living", "migration": "how_many", "border": "border_safe", "unrest": "safe_streets"}

func metric_badness(s: Dictionary, ind: String) -> float:
	var w = s.world
	var b = {"jobs": (60 - w.jobs) / 40.0, "prices": (w.prices - 40) / 40.0, "migration": (w.migration - 45) / 40.0,
		"border": (w.border - 35) / 45.0, "unrest": (w.unrest - 35) / 45.0}
	return clampf2(b[ind], 0, 1)

## Things the player can put up for debate this month.
func raise_options(s: Dictionary) -> Array:
	var out = []
	for x in s.issues:
		var it = issue_by_id(x.id)
		var fresh = s.week - int(x.week) < WEEKS_PER_MONTH * 2
		out.append({"kind": "issue", "ref": it.id, "title": it.title, "text": it.text, "axis": it.axis, "side": "",
			"region": it.region, "fresh": fresh, "chance": 0.75 if fresh else 0.5})
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
	var tone_k = {"statesman": 0.85, "folksy": 1.0, "fiery": 1.1, "provocative": 1.25}.get(line.tone, 1.0)
	return clampf2(opt.chance * (0.6 + 0.5 * debate_reach(s)) * tone_k, 0.1, 0.95)

func raise_lines(opt: Dictionary, side: String) -> Array:
	if opt.kind == "topic" or opt.kind == "metric": return LINES.TOPIC_LINES[opt.ref][side]
	if opt.kind == "issue": return issue_by_id(opt.ref).lines[side]
	if opt.kind == "proposal" and LINES.PROPOSAL_LINES.has(opt.ref): return LINES.PROPOSAL_LINES[opt.ref]
	return LINES.AXIS_LINES[opt.axis][side]

## Try to start a debate. It can fizzle: nobody picks it up.
func act_raise(s: Dictionary, opt: Dictionary, side: String, line_index: int) -> Dictionary:
	if s.agenda.done: return {"ok": false, "text": "You have already tried to start a debate this month."}
	var err = can_act(s, 0)
	if err: return {"ok": false, "text": err}
	spend_action(s, 0)
	s.agenda.done = true
	var line: Dictionary = raise_lines(opt, side)[line_index]
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
func deliver_line(s: Dictionary, line: Dictionary, quick := false) -> Dictionary:
	var player = player_party(s)
	var tone: String = line.tone if TONES.has(line.get("tone", "")) else "statesman"
	var risk: float = line.risk if line.has("risk") and line.risk != null else TONE_RISK[tone]
	var r = rand(s)
	var charm: float = player.charisma / 100.0
	var outcome = "normal"
	if quick: pass
	elif r < risk * (0.3 + charm * 0.6): outcome = "viral"
	elif r > 1 - risk * (0.55 - charm * 0.35): outcome = "gaffe"
	var pos = 1.6 if outcome == "viral" else 1.0
	var neg = 1.8 if outcome == "gaffe" else (1.3 if outcome == "viral" else 1.0)
	var reacts: Array = TONES[tone].react.duplicate()
	reacts.append_array(line.get("react", []))
	var qk = 0.4 if quick else 1.0
	var scaled = reacts.map(func(g): return {"who": g.get("who"), "amt": g.amt * qk * (pos if g.amt > 0 else neg)})
	apply_effects(s, {"goodwill": scaled, "awareness": 0.06 if outcome == "viral" else (0.035 if outcome == "gaffe" else 0.01)})
	for g in scaled:
		for pop in s.pops:
			if matches(pop, g.who): pop.leader.player = clampf2(pop.leader.player + g.amt * 0.35, -2, 2)
	for k in s.style: s.style[k] *= C.styleMemory
	s.style[tone] = float(s.style.get(tone, 0)) + 1
	var total = dsum(s.style)
	var entries = []
	for k in s.style: entries.append([k, s.style[k]])
	var top: Array = ssort(entries, func(a, b): return b[1] - a[1])[0]
	var share: float = top[1] / total
	var style_note = ""
	if total > 3 and tone == top[0] and share > 0.45:
		player.charisma = clampf2(player.charisma + 0.8, 10, 100)
		style_note = "It sounded like you. People are starting to recognise your voice."
	elif total > 3 and tone != top[0] and share > 0.5:
		player.charisma = clampf2(player.charisma - 0.6, 10, 100)
		style_note = "It didn't sound like you. Some voters wonder who the real you is."
	media_hear(s, tone, outcome, 0.5 if quick else 1.0)
	if outcome == "viral":
		s.record.memes += 1
		player.charisma = clampf2(player.charisma + 1.5, 10, 100)
	if outcome == "gaffe":
		s.record.gaffes += 1
		player.charisma = clampf2(player.charisma - 1, 10, 100)
	return {"outcome": outcome, "press": TONES[tone].press[outcome], "styleNote": style_note}

func style_profile(s: Dictionary) -> Dictionary:
	var total = dsum(s.style)
	if total < 2: return {"label": "Still finding a voice", "shares": {}}
	var shares = {}
	for k in s.style: shares[k] = s.style[k] / total
	var sh = func(k): return float(shares.get(k, 0))
	var label = "A bit of everything"
	if sh.call("folksy") + sh.call("provocative") > 0.65 and sh.call("provocative") > 0.25: label = "Charismatic buffoon"
	elif sh.call("fiery") + sh.call("provocative") > 0.65: label = "Firebrand"
	elif sh.call("statesman") > 0.55: label = "Statesman"
	elif sh.call("folksy") > 0.5: label = "Man of the people"
	elif sh.call("statesman") + sh.call("fiery") > 0.7: label = "Strongman"
	elif sh.call("statesman") + sh.call("folksy") > 0.7: label = "Reassuring uncle"
	if label == "Man of the people" and player_party(s).leaderSex == "f": label = "Woman of the people"
	if label == "Reassuring uncle" and player_party(s).leaderSex == "f": label = "Reassuring aunt"
	return {"label": label, "shares": shares}

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
	var attack: String
	if con: attack = "\"In %s you said: '%s' In %s you said: '%s' Which one do you actually believe?\"" % [date_label(con.first.week, false), con.first.text, date_label(con.second.week, false), con.second.text]
	elif blamed: attack = "\"Your whole campaign has been about blaming %s. Is that all you have to offer?\"" % blamed.group
	elif dirty: attack = "\"Where does your party's money come from? Because it isn't from ordinary Cranebonians.\""
	else: attack = "\"You have never run anything in your life. Why should anyone trust you with a country?\""
	var hurt = [{"who": {"class": "middle"}, "amt": -0.12}, {"who": {"age": "61+"}, "amt": -0.08}] if (con or blamed or dirty) else []
	return [
		{"title": "Opening statement", "prompt": "The moderator turns to %s: \"Your party didn't exist four years ago. Why should anyone vote for it?\"" % player.leader,
			"lines": [
				{"tone": "statesman", "text": "\"Because Cranebonistan deserves a government that keeps its word. That is all %s has ever asked for.\"" % player.name},
				{"tone": "fiery", "text": "\"Because for thirty years the people on this stage have robbed you blind, and tonight that ends.\""},
				{"tone": "folksy", "text": "\"I'm not a career politician. I'm someone who got tired of waiting for a bus that never comes.\""},
				{"tone": "provocative", "text": "\"Look at the people next to me. Would you lend any of them your car?\""},
			]},
		{"title": "%s attacks" % rival.leader, "prompt": "%s of the %s turns to you: %s" % [rival.leader, rival.short, attack], "rival": rival.id, "hurt": hurt,
			"lines": [
				{"tone": "statesman", "text": "\"I have listened and I have learned. A leader who never changes their mind isn't listening.\""},
				{"tone": "fiery", "text": "\"How dare you lecture anyone? Your party has lied to this country for a generation.\""},
				{"tone": "folksy", "text": "\"At least I change my mind now and then. %s hasn't changed a thing since the cassette tape.\"" % rival.leader, "react": [{"who": {"loyalTo": rival.id}, "amt": -0.1}]},
				{"tone": "provocative", "text": "\"That's invented. Everybody knows your people make things up.\"", "react": [{"who": {"class": "middle"}, "amt": -0.1}]},
			]},
		{"title": "Closing statement", "prompt": "\"You have thirty seconds. Speak to the voters.\"",
			"lines": [
				{"tone": "statesman", "text": "\"On election day, vote for the country you want your children to grow up in.\""},
				{"tone": "fiery", "text": "\"They are afraid of you. On election day, prove them right.\""},
				{"tone": "folksy", "text": "\"If you want more of the same, you know who to vote for. If you don't, you know where to find me.\""},
				{"tone": "provocative", "text": "\"If they win again, don't say I didn't warn you.\""},
			]},
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
		"clown": (sh.call("folksy") + sh.call("provocative")) * 7 + rec.memes * 1.5 + rec.gaffes * 1.5,
		"technocrat": sh.call("statesman") * 9 + (1 - ext) * 3,
		"fixer": dirty.size() * 3 + rec.dossiers * 2,
		"demagogue": rec.blamed.size() * 3 + rec.outrages * 1.2,
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
	if c.week == flagship_week() and FLAGSHIP.size(): s.queue.append({"type": "event", "event": flagship_event(s)})
	if c.isMonthStart: monthly_event(s)
	if c.weekOfMonth == 2 and not c.isYearEnd: take_poll(s, "Tracking poll", true)
	if c.isYearEnd: take_poll(s, "Annual poll %d" % calendar(s.week).year)
	flush_news(s)

func advance_week(s: Dictionary) -> bool:
	if s.queue.size() or s.result: return false
	s.week += 1
	run_hooks(s)
	return true

func advance_to_decision(s: Dictionary) -> bool:
	var moved = false
	while advance_week(s):
		moved = true
		if s.queue.size(): break
	return moved

func finish_front(s: Dictionary, type: String) -> void:
	if s.queue.size() and s.queue[0].type == type: s.queue.pop_front()

func dismiss_front(s: Dictionary) -> void:
	s.queue.pop_front()
	flush_news(s)

# ---------- Describing effects in plain words ----------
func describe_who(who) -> String:
	if who == null or who.is_empty(): return "everyone"
	var listf = func(v, f: Callable) -> String:
		var arr: Array = v if v is Array else [v]
		return " or ".join(arr.map(f))
	var noun = "voters"
	if who.has("nationality"): noun = listf.call(who.nationality, func(id): return by_id(NATIONALITIES, id).plural)
	if who.has("lean"):
		var parts = []
		for ax in who.lean:
			var a = by_id(AXES, ax)
			parts.append(a.leftGroup if who.lean[ax][0] == "<" else a.rightGroup)
		noun = " and ".join(parts)
	if who.has("loyalTo"): noun = "your core supporters" if who.loyalTo == "player" else "%s core supporters" % by_id(PARTIES, who.loyalTo).short
	var text = noun
	if who.has("class"): text = "%s %s" % [listf.call(who["class"], func(id): return by_id(CLASSES, id).adj), text]
	if who.has("age"): text += " aged %s" % listf.call(who.age, func(id): return by_id(AGES, id).label)
	if who.has("region"):
		var regions: String = listf.call(who.region, func(id): return by_id(REGIONS, id).name).replace(" or ", " and ")
		text = regions if (noun == "voters" and not who.has("class") and not who.has("age")) else "%s in %s" % [text, regions]
	return text

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
