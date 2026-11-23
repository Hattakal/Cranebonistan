extends SceneTree
func _init() -> void:
	var G = load("res://scripts/sim.gd").new()
	var s: Dictionary = G.new_game({"seed": 3})
	while s.week < G.ELECTION_WEEK - 13:
		s.queue.clear(); G.advance_week(s)
	for k in 14:
		var types = s.queue.map(func(q): return q.type)
		s.queue.clear()
		if not G.advance_week(s): break
		print("week %d campaign=%s actions=%d queue=%s" % [s.week, G.in_campaign(s), s.actionsLeft, s.queue.map(func(q): return q.type)])
	print("route: ", s.convoy.route.map(func(id): return G.district_by_id(id).name))
	for pid in s.rivalConvoys: print(pid, ": ", s.rivalConvoys[pid].map(func(id): return G.district_by_id(id).name))
	quit()
