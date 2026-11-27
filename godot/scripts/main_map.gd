## main_map.gd — the map: its modes, the route on it, the pins.
extends "res://scripts/main_base.gd"
# ---------- Map modes (data/mapmodes.json) ----------


func _build_map_modes() -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.position = Vector2(14, 14)
	_map.add_child(row)
	# the campaign convoy: its plan, and the bar shown while choosing stops on the map
	_convoy_btn = Button.new()
	_convoy_btn.text = "THE CAMPAIGN"
	_convoy_btn.focus_mode = Control.FOCUS_NONE
	_convoy_btn.add_theme_font_override("font", Look.spaced("display_bold", 2))
	_convoy_btn.add_theme_font_size_override("font_size", Look.fs(12))
	Look.dark_button(_convoy_btn, false, false, 5)
	_convoy_btn.pressed.connect(func(): _convoy_sheet(false))
	_convoy_btn.visible = false
	row.add_child(_convoy_btn)
	_route_bar = HBoxContainer.new()
	_route_bar.add_theme_constant_override("separation", 8)
	_route_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_route_bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_route_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_route_bar.position -= Vector2(14, 14)
	_route_bar.visible = false
	_map.add_child(_route_bar)
	_route_note = Look.dlabel("", "display_bold", 15, Look.TXT)
	_route_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_route_bar.add_child(_route_note)
	for spec in [["Undo", _route_undo, false], ["Cancel", func(): _route_finish(false), false], ["Done", func(): _route_finish(true), true]]:
		var b = Button.new()
		b.text = String(spec[0]).to_upper()
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", Look.spaced("display_bold", 2))
		b.add_theme_font_size_override("font_size", Look.fs(13))
		Look.dark_button(b, spec[2], false, 7)
		b.pressed.connect(spec[1])
		_route_bar.add_child(b)
	for m in G.MAPMODES.get("MODES", []):
		var b = Button.new()
		b.text = String(m.name).to_upper()
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", Look.spaced("display_bold", 2))
		b.add_theme_font_size_override("font_size", Look.fs(12))
		b.tooltip_text = String(m.get("title", m.name)).capitalize()
		var id: String = m.id
		b.pressed.connect(func(): _set_map_mode(id))
		row.add_child(b)
		_mode_buttons[id] = b
	_style_mode_buttons()

func _style_mode_buttons() -> void:
	for id in _mode_buttons: Look.dark_button(_mode_buttons[id], false, id == _map_mode, 5)

func _set_map_mode(id: String) -> void:
	_map_mode = id
	_style_mode_buttons()
	if S: _render_map()

func _mode_info() -> Dictionary:
	for m in G.MAPMODES.get("MODES", []):
		if m.id == _map_mode: return m
	return {}

## Each province by the current mode; the vote mode is the default map.
func _render_map() -> void:
	var poll = S.polls[-1] if S.polls.size() else null
	_map.fills = {}
	_map.stripes = {}
	_map.shares = {}
	_map.hot = {}
	_map.legend_ramp = []
	_map.route_stops = []
	_map.convoys = []
	_map.pins = []
	_map.rival_tags = []
	_map.communities = S.communities
	_map.party_color = Color(G.player_party(S).color)
	for f in G.FOREIGN:
		_map.hot[f.id] = S.countries.get(f.id, {}).get("hot", false)
	# what each province is like: only the modes that colour by it (and their tooltips) need it
	_profiles = G.district_profiles(S) if _map_mode in ["known", "issues", "fed", "distress"] else {}
	_convoy_btn.visible = S.has("convoy") and not S.result
	_route_bar.visible = _route_edit
	if _route_edit:
		_paint_route_edit()
		_map.queue_redraw()
		return
	var info: Dictionary = _mode_info()
	_map.legend_title = String(info.get("title", "IF THE ELECTION WERE TODAY"))
	if _map_mode == "local":
		_paint_local(info)
		_map.queue_redraw()
		return
	if _map_mode != "vote" and _map_mode != "past":
		_paint_profile_mode(info)
		_map.queue_redraw()
		return
	if _map_mode == "past":
		_paint_result(S.get("pastElection", {}), false)
		var past_seats: Dictionary = G.projected_seats(S.get("pastElection", {})) if S.get("pastElection", {}).size() else {}
		_map.legend = _seat_legend(past_seats)
		_map.legend_note = String(info.get("note", ""))
		_map.queue_redraw()
		return
	if poll:
		for r in G.REGIONS:
			_map.shares[r.id] = "You %d%%" % Game.jround(poll.regions[r.id].player * 100)
	var proj: Dictionary = S.get("projection", {})
	_paint_result(proj, true)
	if S.has("convoy") and not S.result: _map.route_stops = _route_marks(S.convoy.route, _route_open_from())
	# this week's rallies: a car for every party at its stop
	var wi: int = G.campaign_stop_index(S)
	if G.in_campaign(S) and not S.result:
		var r0: Array = S.get("convoy", {}).get("route", [])
		if wi < r0.size(): _map.convoys.append({"pos": G.district_centre(G.district_by_id(r0[wi])), "color": Look.lit(Color(G.player_party(S).color)), "short": G.player_party(S).short})
		for pid in S.get("rivalConvoys", {}):
			var rr: Array = S.rivalConvoys[pid]
			var pr = G.party_of(S, pid)
			if pr and wi < rr.size(): _map.convoys.append({"pos": G.district_centre(G.district_by_id(rr[wi])), "color": Look.lit(Color(pr.color)), "short": pr.short})
	# where the other parties have been campaigning (in the campaign: their convoys instead)
	for d in (G.DISTRICTS if not G.in_campaign(S) else []):
		var st: Dictionary = S.districts.get(d.id, {})
		var rt: Dictionary = st.get("rtrip", {})
		for pid in rt:
			var p = G.party_of(S, pid)
			var since: int = S.week - int(st.get("rtripWeek", {}).get(pid, -999))
			if p == null or since >= 2 * G.WEEKS_PER_MONTH: continue
			var fresh: bool = since < G.WEEKS_PER_MONTH
			_map.rival_tags.append({"district": d.id, "short": p.short, "color": Look.lit(Color(p.color)), "fresh": fresh})
	var seats: Dictionary = G.projected_seats(proj) if proj.size() else {}
	_map.legend = _seat_legend(seats)
	_map.legend_note = ("Seats each party would win, by the %s. %d for a majority; under %d%% of the vote, none. %s" % [str(poll.label).to_lower(), int(G.C.seats / 2 + 1), Game.jround(G.threshold() * 100), "Cars: this week's rallies." if G.in_campaign(S) else "Flags: other parties on tour lately."]) if poll else "No poll yet."
	_map.queue_redraw()

func _route_marks(route: Array, open_from: int) -> Array:
	var out = []
	for i in route.size(): out.append({"pos": G.district_centre(G.district_by_id(route[i])), "n": i + 1, "done": i < open_from})
	return out

## Choosing the convoy's stops: the provinces within a week's reach of the last stop lit,
## the rest dark, and the route so far drawn over them.
func _paint_route_edit() -> void:
	var prev: String = _route_draft[-1] if _route_draft.size() else ""
	for d in G.DISTRICTS:
		var ok: bool = not _route_draft.has(d.id) and G.convoy_reaches(prev, d.id)
		_map.fills[d.id] = Look.mix(Look.LAND, Look.LAMP, 0.45) if ok else Look.mix(Look.LAND, Look.N500, 0.2)
	_map.route_stops = _route_marks(_route_draft, _route_from)
	_route_note.text = "STOP %d OF %d · PICK A LIT PROVINCE" % [mini(_route_draft.size() + 1, int(G.C.campaign.stops)), int(G.C.campaign.stops)]
	_map.legend = []
	_map.legend_title = "PLANNING THE CONVOY"
	_map.legend_note = "Lit: within a week's reach of the last stop. Done fills the rest of the route for you."
	_map.legend_ramp = []

## Each district in the colour of whoever wins it: deep when safe, pale when close. `live`:
## today's projection (flash on a change of hands, your share as stripes) or a past result.
func _paint_result(proj: Dictionary, live: bool) -> void:
	for d in G.DISTRICTS:
		if not proj.has(d.id): continue
		var x: Dictionary = proj[d.id]
		if live:
			if _leaders.has(d.id) and _leaders[d.id] != x.winner: _map.flash(d.id)
			_leaders[d.id] = x.winner
		# the leader's colour, a little deeper when the lead is safe (a narrow range, so a province
		# won with 41% and one won with 50% read as the same party at a glance)
		var strength = clampf(0.66 + float(x.margin) * 0.9, 0.66, 0.85)
		_map.fills[d.id] = Look.mix(Look.LAND, Look.lit(Color(G.party_of(S, x.winner).color)), strength * 0.8)
		# not yours yet: stripes in your colour covering your share of the vote there (30% of the
		# vote, 30% of the province), never more than the leader's own band
		if live and x.winner != "player" and float(x.you) >= 0.10:
			_map.stripes[d.id] = [_stripe_colour(_map.fills[d.id]), minf(float(x.you), 0.45)]

## Your stripes over another party's province: your colour, pushed lighter or darker when it
## sits too close to theirs to be seen.
func _stripe_colour(under: Color) -> Color:
	var mine: Color = Look.mix(Look.LAND, Look.lit(Color(G.player_party(S).color)), 0.8)
	var dist: float = absf(mine.get_luminance() - under.get_luminance()) + Vector3(mine.r - under.r, mine.g - under.g, mine.b - under.b).length() * 0.5
	if dist >= 0.25: return mine
	return mine.lightened(0.45) if under.get_luminance() < 0.45 else mine.darkened(0.45)

func _seat_legend(seats: Dictionary) -> Array:
	var ps: Array = S.parties.filter(func(p): return int(seats.get(p.id, 0)) > 0 or p.isPlayer and _map_mode == "vote")
	return Game.ssort(ps, func(a, b): return int(seats.get(b.id, 0)) - int(seats.get(a.id, 0))).map(func(p): return ["%s %d" % [p.short, int(seats.get(p.id, 0))], Look.lit(Color(p.color)), int(seats.get(p.id, 0))])

## Local stories: their provinces lit, a pin on each; the rest of the country dim.
func _paint_local(info: Dictionary) -> void:
	var dim := Look.mix(Look.LAND, Look.N500, 0.25)
	for d in G.DISTRICTS: _map.fills[d.id] = dim
	var n = 0
	for opt in G.raise_options(S):
		if opt.kind != "issue" or String(opt.get("district", "")) == "": continue
		_map.fills[opt.district] = Look.mix(Look.LAND, Look.LAMP, 0.45 if opt.fresh else 0.3)
		_map.pins.append({"id": opt.ref, "district": opt.district, "title": opt.title})
		n += 1
	# events that happened somewhere, lately
	for e in S.get("eventPins", []):
		if S.week - int(e.week) > G.EVENT_PIN_MONTHS * G.WEEKS_PER_MONTH: continue
		if String(e.district) != "": _map.fills[e.district] = Look.mix(Look.LAND, Look.LAMP, 0.45)
		else:
			for d in G.DISTRICTS:
				if d.region == e.region and _map.fills.get(d.id) == dim: _map.fills[d.id] = Look.mix(Look.LAND, Look.LAMP, 0.22)
		_map.pins.append({"id": "ev:" + String(e.id), "district": e.district, "region": e.region, "title": e.title})
		n += 1
	var heard: Dictionary = S.get("localSpoke", {})
	for did in heard:
		if S.week - int(heard[did].week) <= G.LOCAL_STORY_MONTHS * G.WEEKS_PER_MONTH and not _map.pins.any(func(p): return p.district == did):
			_map.fills[did] = Look.mix(Look.LAND, Look.lit(Color(G.player_party(S).color)), 0.4)
	_map.legend = [["In the news", Look.mix(Look.LAND, Look.LAMP, 0.6)], ["You spoke up here lately", Look.mix(Look.LAND, Look.lit(Color(G.player_party(S).color)), 0.6)]]
	_map.legend_note = String(info.get("note", "")) if n else "A quiet month in the local papers."

## A pin clicked: the story, ready to raise as a national debate.
func _story_clicked(id: String) -> void:
	if id.begins_with("ev:"):   # an event: on the desk if it is still waiting, otherwise the debates
		var eid: String = id.trim_prefix("ev:")
		if S.queue.size() and String(S.queue[0].get("id", "")) == eid: _open_front()
		elif S.queue.any(func(q): return String(q.get("id", "")) == eid): _toast("Finish the decision on your desk first.")
		else: _show_file("debates")
		return
	var opt = null
	for o in G.raise_options(S):
		if o.kind == "issue" and o.ref == id: opt = o
	if opt == null: return
	if S.queue.size() > 0: _toast("Finish the decision on your desk first."); return
	if S.result != null: return
	if S.agenda.done: _toast("You've already tried to start a debate this month."); return
	if S.actionsLeft <= 0: _toast("No actions left this month."); return
	_raise_sheet(opt)

## The modes that colour each province by what it is like: known, issues, fed up, distress.
func _paint_profile_mode(info: Dictionary) -> void:
	var low_c := Look.mix(Look.LAND, Look.N500, 0.35)
	var high_c: Color
	match _map_mode:
		"known": high_c = Look.lit(Color(G.player_party(S).color))
		"fed": high_c = Look.MAP_FED
		_: high_c = Look.MAP_DISTRESS
	var used = {}
	for d in G.DISTRICTS:
		var x: Dictionary = _profiles.get(d.id, {})
		if x.is_empty(): continue
		if _map_mode == "issues":
			var ax: String = x.top[0]
			used[ax] = true
			_map.fills[d.id] = Look.mix(Look.LAND, Look.ISSUE.get(ax, Look.N500), 0.72)
		else:
			_map.fills[d.id] = Look.mix(low_c, high_c, _mode_level(x))
	# a line under each region's name, where it says something
	for r in G.REGIONS:
		var n = 0.0
		var v = 0.0
		for d in G.DISTRICTS:
			if d.region != r.id or not _profiles.has(d.id): continue
			n += _profiles[d.id].size; v += _profiles[d.id].size * _profiles[d.id].known
		if _map_mode == "known" and n > 0: _map.shares[r.id] = "%d%% know you" % Game.jround(v / n * 100)
	_map.legend_note = String(info.get("note", ""))
	if _map_mode == "issues":
		_map.legend = G.AXES.filter(func(ax): return used.has(ax.id)).map(func(ax): return [String(ax.issue), Look.ISSUE.get(ax.id, Look.N500)])
	else:
		_map.legend = []
		_map.legend_ramp = [low_c, high_c, String(info.get("low", "")), String(info.get("high", ""))]

## Where a province sits on the current mode's colour scale, 0..1. Fixed scales, so a
## province's colour changes when the country does.
func _mode_level(x: Dictionary) -> float:
	match _map_mode:
		"known": return sqrt(clampf(float(x.known), 0, 1))   # early gains show
		"fed": return clampf((float(x.fed) - 0.6) / 1.4, 0, 1)
		"distress": return clampf((float(x.distress) - 0.15) / 0.55, 0, 1)
	return 0.0

## The current mode's line in a province's tooltip.
func _mode_tip(id: String) -> Array:
	if _map_mode == "local":
		var out = []
		for o in G.raise_options(S):
			if o.kind == "issue" and o.get("district", "") == id: out.append("In the news: " + o.title)
		var h = S.get("localSpoke", {}).get(id)
		if h and S.week - int(h.week) <= G.LOCAL_STORY_MONTHS * G.WEEKS_PER_MONTH: out.append("You spoke up about %s: a trip here goes better" % h.title)
		return out
	var x: Dictionary = _profiles.get(id, {})
	if x.is_empty(): return []
	match _map_mode:
		"known": return ["%d%% here know your party" % Game.jround(float(x.known) * 100)]
		"issues":
			var names: Array = x.top.map(func(ax): return String(Game.by_id(G.AXES, ax).issue).to_lower())
			return ["Cares most about %s, then %s" % names]
		"fed": return ["Fed up with the system: %s" % G.level_word(_mode_level(x)).to_lower()]
		"distress": return ["Distress: %s (hard times %s, distrust %s)" % [G.level_word(_mode_level(x)).to_lower(), G.level_word(clampf(float(x.hardship) / 0.7, 0, 1)).to_lower(), G.level_word(clampf(float(x.distrust), 0, 1)).to_lower()]]
		"past":
			var r: Dictionary = S.get("pastElection", {}).get(id, {})
			if r.size(): return ["%s won it in 2026, with %d%%" % [G.party_of(S, r.winner).short if G.party_of(S, r.winner) else r.winner, Game.jround(float(r.share) * 100)]]
	return []

## Rivals whose leaders have toured this province recently (their push is still felt).
func _rivals_here(id: String) -> Array:
	var rt: Dictionary = S.districts.get(id, {}).get("rtrip", {})
	var out = []
	for pid in rt:
		if float(rt[pid]) >= 0.05 and G.party_of(S, pid): out.append(G.party_of(S, pid).short)
	return out

func _tip(id: String, kind: String) -> Array:
	if kind == "pin" and id.begins_with("ev:"):
		var eid: String = id.trim_prefix("ev:")
		for e in S.get("eventPins", []):
			if String(e.id) != eid: continue
			var waiting: bool = S.queue.any(func(q): return String(q.get("id", "")) == eid)
			var where: String = G.district_by_id(e.district).name if String(e.district) != "" else Game.by_id(G.REGIONS, e.region).name
			return [String(e.title), "Happened in %s, %s" % [where, G.date_label(int(e.week), false)], "On your desk: what you say counts for more here" if waiting else "Click for the debate it started"]
		return []
	if kind == "pin":
		var st: Dictionary = G.story(S, id)
		return [String(st.get("title", "")), String(st.get("text", "")), "Click to raise it as a national debate"]
	if kind == "district":
		var d = G.district_by_id(id)
		var w: int = G.winner_seats(int(d.seats))
		var lines = ["%s · %d seat%s" % [d.name, d.seats, "" if d.seats == 1 else "s"], Game.by_id(G.REGIONS, d.region).name + (" · the winner takes all" if w == int(d.seats) else " · the winner takes %d, %d shared by national vote" % [w, int(d.seats) - w])]
		lines.append_array(_mode_tip(id))
		var x: Dictionary = S.get("projection", {}).get(id, {})
		if x.size():
			var who: String = "You" if x.winner == "player" else G.party_of(S, x.winner).short
			var lead: float = float(x.margin) * 100
			lines.append("%s would win it today, %s" % [who, "safely" if lead >= 12 else ("comfortably" if lead >= 5 else "narrowly")])
			lines.append("Your vote here: %d%%" % Game.jround(float(x.you) * 100))
			if x.winner != "player":
				lines.append("You'd need about %d more percentage points" % maxi(1, Game.jround((float(x.share) - float(x.you)) * 100)))
		var here: Array = _rivals_here(id)
		if here.size(): lines.append("Campaigning here lately: " + ", ".join(here))
		lines.append("Click to tour, or to open an office")
		return lines
	if kind == "region":
		var r = Game.by_id(G.REGIONS, id)
		var lines = [r.name, r.blurb if r.has("blurb") else ""]
		if S.polls.size():
			var sh: Dictionary = S.polls[-1].regions[id]
			lines.append("Your support: %d%%" % Game.jround(sh.player * 100))
		lines.append("Click for its voters")
		return lines.filter(func(x): return x != "")
	var f = Game.by_id(G.FOREIGN, id)
	var st: Dictionary = S.countries.get(id, {})
	var lines = [" ".join(f.name), st.get("relation", f.get("relation", ""))]
	if st.get("notes", []).size(): lines.append(st.notes[-1].text)
	lines.append("Click for its profile")
	return lines.filter(func(x): return x != "")

func _ticker_items() -> Array:
	var out = []
	for i in range(S.log.size() - 1, maxi(-1, S.log.size() - 7), -1): out.append(S.log[i].text)
	return out if out.size() else ["Welcome to the campaign."]
