## rules/base.gd — Shared ground for every rule: the content tables, settings, small helpers, random numbers, the calendar and stances, plus helpers every system uses (news, the diary, the action check).
##
## The rules are split over a chain of files, each extending the one before:
## base → voters → districts → media → party → scandals → rivals → world → moments → coalition → sim.gd
## sim.gd, at the end, is the autoload "Game": everything is reached as Game.<name>.
## A file can call anything in itself or earlier in the chain; the few calls that
## must go the other way are declared as hooks at the bottom of this file.
## No drawing and no buttons here: the rules read the content in data/*.json and
## change the game state, one Dictionary `s`; saving is JSON.stringify(s).
extends Node

const SAVE_VERSION := 40

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
var MINOR_PARTIES: Array    # small parties with a fixed share of the vote (content.json MINOR_PARTIES)
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
var COALITION: Dictionary    # data/coalition.json: ministries and how parties bargain
var COUNTRY: Dictionary      # the country's name: {name, national, nationals}
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
var FINAL_DEBATE: Dictionary = {}  # the final debate's questions and answers (data/final_debate.json)
var LEADER_TYPES: Array = []   # the kinds of leader voters want (data/leader_types.json)
var OUTLETS: Array = []        # newspapers, channels and platforms (data/media.json)
var INTERVIEW: Dictionary = {}  # the big interview in year one (data/interview.json)
var SCANDALS: Dictionary = {}   # secrets and how they come out (data/scandals.json)
var VIOLENCE: Dictionary = {}   # political violence and rivals' labels (data/violence.json)
var NAMES: Dictionary = {}      # name pools by background (data/names.json)
var FOREIGN_MONEY: Array = []  # what comes with secret foreign money (data/media.json)
var INFLUENCER_SCANDALS: Array = []   # what goes wrong for personalities (data/media.json)
var _event_axis = {}

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
	for p in MINOR_PARTIES:
		if p.id == id: return p
	return null

## The share of the vote below which a party wins no seats (CONFIG.threshold).
func threshold() -> float:
	return float(C.get("threshold", 0.0))

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
## Voters: one group for every province, age, class and nationality that lives
## there. A province takes its region's people and views, then its own character:
## towns are more middle-class, more mixed and more progressive than the
## countryside, a city's own lean (cities.json) counts for its share of the
## province, and every game adds a little local difference (s.districts[id].lean).
const POP_MIN := 3000.0

static func _or1(v) -> float:
	return 1.0 if v == null or float(v) == 0.0 else float(v)

# ---------- Shared helpers (every system uses these) ----------
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

# ---------- Effects ----------
static func _leader_list(v) -> Array:
	if v == null: return []
	if v is Array: return v
	return [v]

# ---------- Trust ----------
static func trust_label(t: float) -> String:
	if t >= 60: return "High"
	if t >= 45: return "Steady"
	if t >= 30: return "Low"
	if t >= 15: return "Very low"
	return "Collapsed"

# ---------- Shared helpers (every system uses these) ----------
func push_news(s: Dictionary, item: Dictionary) -> void:
	s.news.append(merged({"week": s.week}, item))

# ---------- Rival parties ----------
const HAPPENINGS := ["scandal", "infighting", "new_leader", "rebound"]

## Rivals don't only copy you: now and then one moves into an empty niche,
## a side of an issue many voters care about that no party speaks for.
const NICHE_CHANCE := 0.12

# ---------- The rivals' turn ----------
## Rivals play the same game as you, a little less freely: a budget every quarter,
## a trip a month to a province they want, adverts, personalities, now and then an
## outlet, and investigators digging into other parties (you included).
const RIVAL_EDGE := 0.7     # how much of the player's effect a rival's move has

# ---------- Media ----------
## Each outlet works on its audience every month (data/media.json): it pulls their
## views toward its slant, warms them to the party it favours, and shields that
## party. Views are pulled back toward where they started, so nobody runs away.
const VIEW_HOME := 0.04       # monthly pull of every group's views back to where it started
const MEDIA_VIEW := 0.03      # how far a full-time viewer moves toward an outlet's slant each month
const MEDIA_WARM := 0.05      # goodwill a full-time viewer gains for the favoured party each month
const SHIELD_MAX := 0.6
const SHIELD_GAIN := 0.3      # how fast friendly coverage builds cover (it fades by 30% a month)

static func shield_of(pop: Dictionary, pid: String) -> float:
	return float(pop.get("shield", {}).get(pid, 0.0))

# ---------- Personalities: sponsoring them ----------
const SPONSOR_LEAK := 0.03    # monthly chance a sponsorship comes out

## Followers come and go; fees are paid every quarter; now and then a personality
## has a scandal of their own and loses a share of their followers.
const INFLUENCER_SCANDAL := 0.025   # monthly chance, each

# ---------- Shared helpers (every system uses these) ----------
func can_act(s: Dictionary, cost := 0.0) -> String:
	if s.result: return "The election is over."
	if s.actionsLeft <= 0: return "No actions left this month."
	if s.money < cost: return "Needs ₱%sM." % str(cost)
	return ""

func spend_action(s: Dictionary, cost: float) -> void:
	s.actionsLeft -= 1
	s.money -= cost

func _log(s: Dictionary, kind: String, text: String) -> void:
	s.log.append({"week": s.week, "kind": kind, "text": text})

# ---------- Communities ----------
## A local chapter in one city: slow to grow, and it lasts. It turns
## supporters in that region into core voters, gets them to the polls, and
## pays a little in members' dues.
const COMMUNITY_COST := [1.0, 1.5, 2.0]
const COMMUNITY_MAX := 3

# ---------- Shared helpers (every system uses these) ----------
func community_level(s: Dictionary, city: String) -> int:
	return int(s.communities.get(city, 0))

func city_by_name(name: String) -> Dictionary:
	for c in MAP.cities:
		if c.name == name: return c
	return {}

# ---------- The party's politicians ----------
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

# ---------- Steering the party ----------
## Moving the manifesto one stance takes three months. The politicians who
## care about the other side get angrier every month it goes on.
const STEER_MONTHS := 3

# ---------- Relations with the other parties (skeleton) ----------
const SCAR_SHARE := 0.4   # of every hostile act, the part that never fades

static func relation_word(v: float) -> String:
	if v >= 45: return "Friendly"
	if v >= 15: return "Cordial"
	if v > -15: return "Wary"
	if v > -45: return "Hostile"
	return "Bitter"

const POACH_FIGURE_CHANCE := 0.2

# ---------- Campaign budget ----------
static func business_word(mood: float) -> String:
	if mood >= 1.1: return "generous"
	if mood >= 0.7: return "willing"
	if mood >= 0.4: return "cautious"
	return "keeping their distance"

# ---------- Shared helpers (every system uses these) ----------
func event_by_id(id) -> Variant:
	return _events_by_id.get(id)

# ---------- Polls ----------
## A poll asks a sample, not everyone: a few groups in every province, picked at
## random by size and weighted up to the province's people. It is quick, and it can
## be wrong in the way real polls are. The election itself counts everyone.
const POLL_PER_DISTRICT := 8

# ---------- Districts ----------
## Each region is split into districts (MAP.districts, drawn by tools/build_districts.py;
## names, seats and leans can be changed in data/districts.json). A district has its
## own voters (built from its region's people, see build_pops), rival strongholds,
## and whatever you have done there (home city, offices, the leader's visits).
var DISTRICTS: Array = []

# ---------- Shared helpers (every system uses these) ----------
func district_by_id(id: String) -> Variant:
	for d in DISTRICTS:
		if d.id == id: return d
	return null

func district_of_city(city: String) -> Variant:
	for d in DISTRICTS:
		if d.cities.has(city): return d
	return null

## Your standing in one district grows (home city, offices, the leader's visits).
func district_boost(s: Dictionary, id: String, aware: float, goodwill: float) -> void:
	var st: Dictionary = s.districts[id]
	st.aware = clampf2(st.aware + aware, 0, 0.6)
	st.goodwill = clampf2(st.goodwill + goodwill, -1, 1.2)

# ---------- Districts ----------
## The leader on the road: once a month, free, one district. People there hear
## of you and warm to you; the rest of the region a little. Going back to the same
## place keeps helping, but less each time. Local goodwill fades slowly.
const VISIT_AWARE := 0.12
const VISIT_GOODWILL := 0.16

## Seats each party would win if the election were today.
## The district's winner takes two-thirds of its seats (rounded up); the rest
## are shared out by national vote. Those shared seats are counted across the
## whole country (largest remainder), then placed in the districts where each
## party did best, so a small party's votes everywhere add up to something.
const WINNER_SHARE := 2.0 / 3.0

static func winner_seats(n: int) -> int:
	return mini(n, int(ceil(n * WINNER_SHARE - 0.0001)))

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

## How bad an indicator is for the country, 0 (fine) to 1 (dire).
const METRIC_TOPIC := {"jobs": "where_jobs", "prices": "cost_of_living", "migration": "how_many", "border": "border_safe", "unrest": "safe_streets"}

# ---------- Shared helpers (every system uses these) ----------
func metric_badness(s: Dictionary, ind: String) -> float:
	var w = s.world
	var b = {"jobs": (60 - w.jobs) / 40.0, "prices": (w.prices - 40) / 40.0, "migration": (w.migration - 45) / 40.0,
		"border": (w.border - 35) / 45.0, "unrest": (w.unrest - 35) / 45.0}
	return clampf2(b[ind], 0, 1)

func finish_front(s: Dictionary, type: String) -> void:
	if s.queue.size() and s.queue[0].type == type: s.queue.pop_front()

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


# ---------- Hooks: defined later in the chain ----------
## Called by earlier files (the money and the party set these off), defined in rules/scandals.gd.
func add_secret(s: Dictionary, d: Dictionary) -> Dictionary:
	return {}

func _money_secret(s: Dictionary, fx: Dictionary) -> void:
	pass

func _teyl_walkout(s: Dictionary) -> void:
	pass

## Called when the election result is in (rules/districts.gd), defined in rules/coalition.gd.
func form_government(s: Dictionary, seats: Dictionary = {}) -> Dictionary:
	return {}
