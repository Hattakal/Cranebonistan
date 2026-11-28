## main.gd — headquarters, the last of the chain (main_base.gd explains it): screenshots for
## checking the look.
extends "res://scripts/main_story.gd"
# ---------- Screenshots for checking the look (godot ... -- --shot=path --weeks=N) ----------
func _shot(args: Dictionary) -> void:
	S = G.new_game({"seed": 42, "partyName": "People's Awakening", "leaderName": "Dorin Vask", "manifesto": {"nation": 2, "economy": 1, "society": 2, "foreign": 3, "welfare": 1, "system": 1, "order": 2}})
	var weeks = int(args.get("weeks", "20"))
	var guard = 0
	while S.week < weeks and guard < 500:
		guard += 1
		if S.queue.is_empty():
			pass
			G.advance_week(S); continue
		var f: Dictionary = S.queue[0]
		match f.type:
			"event": G.resolve_event(S, 0, 0 if G.event_of(f).choices[0].get("lines", []).size() else -1)
			"budget": G.resolve_budget(S, {"tv": S.money * 0.25, "social": S.money * 0.25, "road": S.money * 0.3}, [])
			"debate": G.answer_debate(S, 0)
			"interview": G.answer_interview(S, 0)
			_: G.dismiss_front(S)
	# stop on the next decision so the board shows one (or on a given kind)
	G.advance_to_decision(S)
	var until: String = args.get("until", "")
	var g2 = 0
	while until != "" and g2 < 400 and not (S.queue.size() and S.queue[0].type == until):
		g2 += 1
		if S.queue.is_empty():
			G.advance_week(S); continue
		var f2: Dictionary = S.queue[0]
		match f2.type:
			"event": G.resolve_event(S, 0, -1)
			"budget": G.resolve_budget(S, {"tv": S.money * 0.25, "social": S.money * 0.25}, [])
			"debate": G.answer_debate(S, 0)
			"interview": G.answer_interview(S, 0)
			_: G.dismiss_front(S)
	render()
	for i in 20: await get_tree().process_frame
	if args.has("hover"): _map.hover_kind = String(args.get("hoverkind", "")); _map.hover = args.hover; _map._mouse = _map.to_screen(Vector2(1300, 980)); _map.queue_redraw()
	if args.has("flagship"):
		S.queue.push_front({"type": "event", "event": G.flagship_event(S)})
	if args.has("violence"):
		S.queue.clear()
		_cheats._violence()
	if args.has("leak"):
		S.queue.clear()
		var live: Array = G.live_secrets(S)
		if live.size(): G.leak_secret(S, live[0], "")
	if args.has("ivdone") and S.queue.size() and S.queue[0].type == "interview":
		while S.queue.size() and S.queue[0].type == "interview": G.answer_interview(S, int(args.ivdone))
		_interview_piece(_paper(860))
	if args.has("open"): _open_front()
	if args.has("found"):
		_founding_sheet()
		if args.has("home"): _found.home = args.home; _founding_build(_sheet_layer.get_child(-1))
		if args.has("scroll"):
			for i in 3: await get_tree().process_frame
			(_sheet_layer.get_child(-1) as Paper)._scroll.scroll_vertical = int(args.scroll)
	await get_tree().process_frame
	if args.has("queue"):   # fire these events now: --queue=norbanian_boats,smog_cranbia (with --open=1, the first one opens)
		if args.has("open"): S.queue.clear()
		for id in String(args.queue).split(",", false): G.queue_event(S, id)
		render()
		if args.has("open") and S.queue.size(): _event_sheet(S.queue[0])
	_shot_words = args.has("words")
	if args.has("step2"):
		var ev: Dictionary = G.event_of(S.queue[0])
		var ci = -1
		for i in ev.choices.size():
			if ev.choices[i].get("lines", []).size(): ci = i
		if ci >= 0: _event_step2(_sheet_layer.get_child(-1), ev, ci)
	if args.has("result"):
		var ev2: Dictionary = G.event_of(S.queue[0])
		_event_result(_sheet_layer.get_child(-1), G.resolve_event(S, 0, 0 if ev2.choices[0].get("lines", []).size() else -1), ev2)
	if args.has("mapmode"): _set_map_mode(String(args.mapmode))
	if args.has("routeedit") and S.has("convoy"):   # choosing the convoy's stops, three picked
		_route_edit = true; _route_from = 0; _route_draft = S.convoy.route.slice(0, int(args.routeedit)); _render_map()
	if args.has("file"):
		if args.has("clear"): S.queue.clear()
		_show_file(args.file)
		if args.has("scroll"):
			await get_tree().process_frame
			await get_tree().process_frame
			_files._scroll.scroll_vertical = int(args.scroll)
	if args.has("region"): _files.S = S; _files.open_region(args.region)
	if args.has("district"): _district_sheet(args.district)
	if args.has("tour"):
		S.queue.clear()
		S.lastVisit = -99
		_district_sheet(args.tour)
		_tour_result(_sheet_layer.get_child(-1), G.act_visit(S, args.tour))
	if args.has("seats") and S.result:
		# made-up seats for checking the talks: --seats=player:95,nup:80,clf:70
		var seats = {}
		for kv in String(args.seats).split(","):
			var pr = kv.split(":")
			seats[pr[0]] = int(pr[1])
		S.result.seats.national = seats
		S.result.ranking = Game.ssort(seats.keys(), func(a, b): return seats[b] - seats[a])
		var top: Array = S.result.ranking.filter(func(id): return int(seats.get(id, 0)) > 0)
		S.result.coalition = G.coalition_open(S, seats) if top.size() and top[0] == "player" and int(seats.get("player", 0)) <= int(G.C.seats / 2) else G.form_government(S, seats, {})
	if args.has("coalition") and S.result:
		var cv = _coalition_view()
		if args.coalition == "end":
			cv._skip()
			for k in int(args.get("negstep", "0")): cv.step_negotiation()   # --negstep=1|2: counteroffers, verdicts
		else: await get_tree().create_timer(float(args.coalition)).timeout
	if args.has("profile"): _profile_sheet()
	if args.has("country"): _country_sheet(args.country)
	if args.has("margaret"):
		_advisor.margaret(args.margaret)
	if args.has("cheats"):
		_cheats.visible = true
		_cheats._build()
		if args.cheats != "1": _cheats._play_months(int(args.cheats))
		_cheats._show_status("test")
		render()
	if args.has("carlos"):
		_advisor.say(args.carlos, true)
	if args.has("title"): _title_card()
	if args.has("options"): _options_sheet()
	if args.has("build"):
		for name in ["Cranebo", "Tarroport", "Bayernal"]:
			S.actionsLeft = 3; S.money = 9.0
			G.act_community(S, name)
			if name == "Cranebo": G.act_community(S, name)
		render()
	if args.has("speak"):
		S.queue.clear()
		var ds: Array = Game.ssort(S.debates.duplicate(), func(a, b): return b.heat - a.heat)
		_speak_sheet(ds[int(args.speak)].id, "L")
	if args.has("spoke"):   # --spoke=1: speak in a debate that has promises on offer, and show how it played
		S.queue.clear()
		S.actionsLeft = 3
		var with_p: Array = S.debates.filter(func(x): return G.pledges_for(S, x, "L").size() > 0)
		if with_p.size():
			var dd: Dictionary = with_p[0]
			var res: Dictionary = G.act_speak(S, dd.id, "L", 0)
			if args.has("pledge"): G.act_pledge(S, G.pledges_for(S, dd, "L")[0].id)
			if args.has("file"):   # with --file: show that file with the promise made, not the speech
				_files.render()
			else: _speech_result(_paper(760, false), res, dd, "L")
	if args.has("raise"):
		S.queue.clear()
		_raise_sheet(G.raise_options(S)[int(args.raise)])
	if args.has("then"):
		# move on to the next poll and catch the motion part-way
		var target = S.polls.size() + 1
		var g3 = 0
		while S.polls.size() < target and g3 < 200:
			g3 += 1
			if S.queue.is_empty(): G.advance_week(S); continue
			match S.queue[0].type:
				"event": G.resolve_event(S, 0, -1)
				"budget": G.resolve_budget(S, {"tv": S.money * 0.25, "social": S.money * 0.25}, [])
				"debate": G.answer_debate(S, 0)
				"interview": G.answer_interview(S, 0)
				_: G.dismiss_front(S)
		render()
		await get_tree().create_timer(float(args.then)).timeout
	for i in 10: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(args.shot)
	print("shot saved ", args.shot)
	get_tree().quit()
