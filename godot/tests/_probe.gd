extends SceneTree

func _init() -> void:
	var G = load("res://scripts/sim.gd").new()
	var M = {"nation": 2, "economy": 1, "society": 2, "foreign": 2, "welfare": 1, "system": 1, "order": 2}
	var s: Dictionary = G.new_game({"seed": 5, "partyName": "Test", "manifesto": M})
	var guard = 0
	while s.week < 30 and guard < 5000:
		guard += 1
		if s.queue.is_empty():
			G.advance_week(s)
			continue
		var f: Dictionary = s.queue[0]
		if f.type == "event": G.resolve_event(s, 0, -1)
		elif f.type == "budget": G.resolve_budget(s, {"road": 0.0, "social": 0.0, "tv": 0.0, "tour": 0.0}, [])
		elif f.type == "debate": G.answer_debate(s, 0)
		else: G.dismiss_front(s)
	s.projection = G.district_results(s)
	print("support ", s.lastSupport.player, " roadFund ", s.get("roadFund"))
	for id in ["cranbia_3", "erland_3", "alinni_2"]:
		var c = s.duplicate(true)
		var before = c.projection.duplicate(true)
		var pw = G.visit_power(c, id)
		G.act_visit(c, id)
		var line = "%s k=%.2f why=%s :: " % [id, pw.k, str(pw.why)]
		var d0 = G.district_by_id(id)
		for d in G.DISTRICTS:
			if d.region != d0.region: continue
			line += "%s %d->%d (%s,%d%%) " % [d.name, round(before[d.id].you * 100), round(c.projection[d.id].you * 100), c.projection[d.id].winner, round(c.projection[d.id].share * 100)]
		print(line)
	quit()
