extends SceneTree
func _init() -> void:
	var G = load("res://scripts/sim.gd").new()
	var s: Dictionary = G.new_game({"seed": 11, "partyName": "Test", "manifesto": {"nation": 1, "economy": 1, "society": 2, "foreign": 2, "welfare": 1, "system": 0, "order": 2}})
	while s.week < G.ELECTION_WEEK - 2:
		if s.queue.is_empty(): G.advance_week(s); continue
		var f: Dictionary = s.queue[0]
		if f.type == "event": G.resolve_event(s, 0, -1)
		elif f.type == "budget": G.resolve_budget(s, {"road": 1.0, "social": 1.0, "tv": 0.0, "tour": 0.0}, [])
		elif f.type == "debate": G.answer_debate(s, 0)
		else: G.dismiss_front(s)
	var kinds = {}
	for m in s.rivalMoves:
		var k = m.text.split(" ")[1] if m.text.split(" ").size() > 1 else m.text
		var key = m.party + ":" + ("toured" if "toured" in m.text else ("ads" if "adverts" in m.text else ("deal" if "deal" in m.text else ("dig" if ("investig" in m.text or "leaks" in m.text) else "other"))))
		kinds[key] = kinds.get(key, 0) + 1
	print(kinds)
	for p in G.rivals(s): print(p.short, " money ", snappedf(p.money, 0.1), " support ", snappedf(s.lastSupport[p.id], 0.001))
	for o in G.OUTLETS:
		if s.media[o.id].sponsor != "" or s.media[o.id].owner != "": print(o.name, " sponsor=", s.media[o.id].sponsor, " owner=", s.media[o.id].owner, " subs=", snappedf(s.media[o.id].subs, 0.01))
	for m in s.rivalMoves.slice(-8): print("  ", G.date_label(m.week), " ", m.text)
	quit()
