## Plays a game where the player fans one debate a month, and prints how
## the national debate develops. godot --headless --path . -s tests/debates.gd -- 7
extends SceneTree

func _init() -> void:
	var G = load("res://scripts/sim.gd").new()
	var seed = int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() else 7
	var s = G.new_game({"seed": seed, "partyName": "People's Awakening", "manifesto": {"nat": 1, "econ": 2, "prog": 3, "war": 1, "gov": 3, "labor": 1, "immig": 4, "rev": 0}})
	var events = 0
	var months = 0
	while not s.result:
		if s.queue.size():
			var f = s.queue[0]
			match f.type:
				"event": G.resolve_event(s, 0, -1); events += 1
				"budget": G.resolve_budget(s, {"tour": s.money * 0.6}, [])
				"debate": G.answer_debate(s, 0)
				_: G.dismiss_front(s)
			continue
		var c = G.calendar(s.week)
		if c.isMonthStart:
			months += 1
			# the player fans the hottest debate on their own side
			if s.debates.size() and s.actionsLeft > 0:
				var d = s.debates[0]
				for x in s.debates: if x.heat > d.heat: d = x
				G.act_fan(s, d.id, "R" if G.player_party(s).manifesto[d.axis] > 0 else "L")
			if months % 6 == 0:
				var line = "m%d sup=%.3f ev=%d |" % [months, s.lastSupport.player, events]
				for d in s.debates: line += " %s h%d l%d [%s];" % [d.title.substr(0, 22), d.heat, d.lean, d.source]
				print(line)
		G.advance_week(s)
	print("RESULT you=%.3f events=%d months=%d debates over=%d" % [s.lastSupport.player, events, months, s.debatesPast.size()])
	quit()
