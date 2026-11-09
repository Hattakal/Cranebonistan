## Plays one seeded game with a fixed script of decisions and prints a trace (a smoke test).
## It once matched the browser version exactly; the browser version is retired.
##   godot --headless --path godot -s tests/parity.gd -- 42
extends SceneTree

func _init() -> void:
	var G = load("res://scripts/sim.gd").new()
	var args = OS.get_cmdline_user_args()
	var seed = int(args[0]) if args.size() else 42
	var M = {"nation": 2, "economy": 1, "society": 2, "foreign": 2, "welfare": 1, "system": 1, "order": 2}
	var s: Dictionary = G.new_game({"seed": seed, "partyName": "Test", "manifesto": M})
	var last = -1
	var guard = 0
	while not s.result and guard < 20000:
		guard += 1
		if s.queue.is_empty():
			var m: int = s.week / 4
			if m != last:
				last = m
				if s.agenda.offered.size() and not s.agenda.done and m % 2 == 0: G.take_initiative(s, s.agenda.offered[0])
				if s.actionsLeft > 0 and m % 3 == 0: G.act_outrage(s)
				if s.actionsLeft > 0 and m % 5 == 1 and s.money > 2: G.act_grassroots(s, G.REGIONS[m % 5].id)
			G.advance_week(s)
			continue
		var f: Dictionary = s.queue[0]
		if f.type == "event":
			var ev: Dictionary = G.event_of(f)
			var i: int = s.week % ev.choices.size()
			var lines: Array = ev.choices[i].get("lines", [])
			G.resolve_event(s, i, (m_of(s) % lines.size()) if lines.size() else -1)
		elif f.type == "budget":
			var money: float = s.money
			var tot = 0.0
			for r in G.REGIONS: tot += r.adults
			var alloc = {}
			for r in G.REGIONS: alloc[r.id] = money * 0.55 * r.adults / tot
			alloc.social = money * 0.15; alloc.tv = money * 0.15; alloc.tour = money * 0.15
			G.resolve_budget(s, alloc, [])
		elif f.type == "debate":
			G.answer_debate(s, s.debate.step % 4)
		else:
			if f.type == "poll":
				var p: Dictionary = s.polls[f.index]
				print("%s w%d you=%.6f nup=%.6f trust=%.4f rng=%d" % [p.label, p.week, p.national.player, p.national.nup, s.trust, s.rng])
			G.dismiss_front(s)
	var r: Dictionary = s.result
	print("RESULT you=%.6f seats=%d won=%s crisis=%s" % [r.votes.player, r.seats.national.player, str(r.playerWon), s.crisis.id if s.crisis else "none"])
	var pr: Dictionary = G.build_profile(s)
	print("PROFILE %s | contra %d | betrayed %d | style %s" % [pr.archetype.title, pr.contradictions.size(), pr.betrayed.size(), pr.style])
	quit()

func m_of(s: Dictionary) -> int:
	return s.week / 4
