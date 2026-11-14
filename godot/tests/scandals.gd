extends SceneTree
## Plays games that take dirty money and attack the elites, answering every
## scandal one way, and prints what leaked and what it cost. Usage: -- <answer> <seed>
func _init() -> void:
	var args = OS.get_cmdline_user_args()
	var how: String = args[0] if args.size() else "deny"
	var seed_n: int = int(args[1]) if args.size() > 1 else 4
	var clean: bool = args.size() > 2 and args[2] == "clean"   # refuse business and foreign money
	var G = load("res://scripts/sim.gd").new()
	var s: Dictionary = G.new_game({"seed": seed_n, "partyName": "Test", "home": "Tarropolis", "manifesto": {"nation": 1, "economy": 1, "society": 2, "foreign": 2, "welfare": 1, "system": 0, "order": 2}})
	print("start secrets: ", s.secrets.map(func(x): return "%s (%.1f)" % [x.title, x.size]))
	var leaks = 0
	while s.week < G.ELECTION_WEEK - 2:
		if s.queue.is_empty():
			G.advance_week(s)
			# speak against the elites now and then
			if s.week % 8 == 0 and s.actionsLeft > 0:
				for d in s.debates:
					if d.axis == "system" and not d.has("you"): G.act_speak(s, d.id, "L", 0); break
			continue
		var f: Dictionary = s.queue[0]
		if f.type == "event":
			var ev = G.event_of(f)
			if ev.get("kind", "") == "scandal":
				leaks += 1
				var ci = 0
				for i in ev.choices.size():
					if ev.choices[i].effects.get("secretAnswer", {}).get("how", "") == how: ci = i
				var before = G.summarize(s, s.pops).support.player
				var r = G.resolve_event(s, ci, 0)
				var after = G.summarize(s, s.pops).support.player
				print("%s  %s -> %s: %.1f%% -> %.1f%% %s" % [G.date_label(s.week), ev.title, ev.choices[ci].label, before * 100, after * 100, r.extra])
			else: G.resolve_event(s, 0, -1)
		elif f.type == "budget":
			var take = [] if clean else f.offers.filter(func(id): return id in ["chamber", "tycoon", "dillihan", "golba"])
			G.resolve_budget(s, {"road": 1.0, "social": 1.0, "tv": 0.0, "tour": 0.0}, take)
		elif f.type == "debate": G.answer_debate(s, 0)
		elif f.type == "interview": G.answer_interview(s, 0)
		else: G.dismiss_front(s)
	print("leaks %d, secrets left %s, money taken %d, Margaret %s, figures %d, lost %s" % [leaks, G.live_secrets(s).map(func(x): return "%s %.1f" % [x.kind, x.size]), s.record.money.filter(func(m): return m.dirty).size(),
		str(G.teyl(s).loyalty if G.teyl(s) else "gone"), s.figures.size(), s.figuresLost.map(func(l): return l.get("why", "quit"))])
	print("final support %.1f%%" % (s.lastSupport.player * 100))
	quit()
