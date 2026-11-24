## The coalition talks on made-up results, and with extra parties, to check the rules
## work for any number of parties. Prints each step and the outcome.
##   godot --headless --path godot -s tests/coalition.gd
extends SceneTree

var G

func _init() -> void:
	G = load("res://scripts/sim.gd").new()
	var s: Dictionary = G.new_game({"seed": 3, "partyName": "Test", "manifesto": {"nation": 2, "economy": 2, "society": 2, "foreign": 2, "welfare": 2, "system": 2, "order": 2}})
	_show(s, "Majority alone", {"player": 20, "nup": 160, "clf": 70, "oc": 30, "apv": 20})
	_show(s, "Usual hung parliament", {"player": 45, "nup": 110, "clf": 90, "oc": 35, "apv": 20})
	_show(s, "Player largest", {"player": 95, "nup": 80, "clf": 70, "oc": 35, "apv": 20})
	_show(s, "Even split: talks break down, then a compromise", {"player": 62, "nup": 67, "clf": 57, "oc": 58, "apv": 56})
	_show(s, "Player out of parliament", {"player": 0, "nup": 120, "clf": 110, "oc": 50, "apv": 20})
	# two more parties, to check nothing assumes four rivals
	for extra in [["grn", "Greens", -30], ["far", "Hearth Front", 80]]:
		var p: Dictionary = G.party_of(s, "clf").duplicate(true)
		p.id = extra[0]; p.name = extra[1]; p.short = extra[0].to_upper()
		for ax in G.AXES: p.perceived[ax.id] = clampf(float(p.perceived[ax.id]) + extra[2], -100, 100)
		s.parties.append(p)
	_show(s, "Seven parties", {"player": 40, "nup": 75, "clf": 60, "oc": 35, "apv": 20, "grn": 40, "far": 30})
	_bargain(s, {"player": 95, "nup": 80, "clf": 70, "oc": 35, "apv": 20})
	_asked(s, {"player": 45, "nup": 110, "clf": 90, "oc": 35, "apv": 20}, [])
	_asked(s, {"player": 45, "nup": 110, "clf": 90, "oc": 35, "apv": 20}, ["interior", "finance", "foreign"])
	print("RESULT coalition ok")
	quit()

func _show(s: Dictionary, title: String, seats: Dictionary) -> void:
	print("\n== %s ==" % title)
	var co: Dictionary = G.form_government(s, seats)
	for st in co.log:
		match st.t:
			"combos": print("  combos (round %d): %s" % [st.round, ", ".join(st.list.map(func(c): return "+".join(c)))])
			"cross": print("  X %s: %s" % ["+".join(st.pair), st.why])
			"formateur": print("  %s tries" % st.party)
			"approach": print("    -> %s (%s): %s %s" % [st.p, st.stance, st.verdict, st.why])
			"fail": print("  fails: %s" % st.why)
			"shutout": print("  SHUTOUT %s" % st.party)
			"government": print("  GOVERNMENT %s, PM %s: %s" % ["+".join(st.members), st.pm, ", ".join(st.cabinet.map(func(c): return "%s=%s" % [c.ministry, c.party]))])
			"majority": print("  majority: %s" % st.party)
			"compromise": print("  COMPROMISE %s: %s" % ["+".join(st.members), st.why])
			"deadlock": print("  DEADLOCK")
	print("  outcome for the player: %s" % co.outcome)


## You are the largest party: offers, counteroffers, a final offer, then forming or forcing.
func _bargain(s: Dictionary, seats: Dictionary) -> void:
	print("\n== You bargain ==")
	s.result = {"seats": {"national": seats}}
	s.result.coalition = G.coalition_open(s, seats)
	var opts: Array = G.coalition_options(s)
	print("  options: ", opts.map(func(c): return "+".join(c)))
	for combo in opts:
		var offer: Dictionary = G.coalition_default_offer(s, combo)
		var needs: Dictionary = G.coalition_needs(s, combo)
		var counter: Dictionary = G.coalition_counter(s, combo, offer)
		for p in needs: print("    %s with %s: needs %.1f asks %.1f; first offer %.1f, counter %.1f" % ["+".join(combo), p, needs[p].need, needs[p].ask, G.offer_value(s, offer, p), G.offer_value(s, counter, p)])
		print("    verdict on first offer: ", G.coalition_verdict(s, combo, offer), "  on counter: ", G.coalition_verdict(s, combo, counter))
	print("  least liked: ", G.coalition_least_liked(s))
	G.coalition_force(s)
	var co = s.result.coalition
	print("  after forcing: round %d pending %s options %s" % [co.round, co.pending, G.coalition_options(s).map(func(c): return "+".join(c)) if co.pending else []])
	if co.pending and G.coalition_options(s).size():
		var c2: Array = G.coalition_options(s)[0]
		G.coalition_form(s, c2, G.coalition_counter(s, c2, G.coalition_default_offer(s, c2)))
	print("  outcome: %s, government %s" % [co.get("outcome", "?"), "+".join(co.government.members) if co.government else "none"])


## A party asks you to join: you answer with demands, and the talks run on.
func _asked(s: Dictionary, seats: Dictionary, extra: Array) -> void:
	print("\n== Asked to join (demands: %s) ==" % ("their offer" if extra.is_empty() else "+".join(extra)))
	s.result = {"seats": {"national": seats}}
	s.result.coalition = G.form_government(s, seats, {})
	var co = s.result.coalition
	if not co.get("pending", false):
		print("  nobody asked; outcome ", co.get("outcome", "?")); return
	print("  %s asks; aims at %s; offers you %s; desperate %s" % [co.ask.f, "+".join(co.ask.combo), co.ask.offer, co.ask.desperate])
	var demands: Array = co.ask.offer if extra.is_empty() else extra
	print("  verdict: ", G.coalition_ask_verdict(s, co.ask, demands))
	G.coalition_answer(s, demands)
	co = s.result.coalition
	print("  pending %s; outcome %s; government %s" % [co.get("pending", false), co.get("outcome", "?"), "+".join(co.government.members) if co.get("government") else "none"])
	if co.get("government"): print("  your ministries: ", co.government.cabinet.filter(func(c): return c.party == "player").map(func(c): return c.ministry))
