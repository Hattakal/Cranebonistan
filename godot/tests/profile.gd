extends SceneTree

func t(label: String, f: Callable, n := 1) -> void:
	var a = Time.get_ticks_usec()
	for i in n: f.call()
	print("%-22s %7.1f ms" % [label, (Time.get_ticks_usec() - a) / 1000.0 / n])

func _init() -> void:
	var G = load("res://scripts/sim.gd").new()
	var s: Dictionary = G.new_game({"seed": 5, "partyName": "Test", "manifesto": {"nation": 2, "economy": 1, "society": 2, "foreign": 2, "welfare": 1, "system": 1, "order": 2}})
	print("pops ", s.pops.size())
	t("score_context", func(): G.score_context(s), 20)
	var ctx = G.score_context(s)
	t("pop_support x all", func():
		for pop in s.pops: G.pop_support(s, pop, null, ctx), 3)
	t("summarize", func(): G.summarize(s, s.pops), 3)
	t("district_results", func(): G.district_results(s), 3)
	t("media_monthly", func(): G.media_monthly(s), 3)
	t("take_poll", func(): G.take_poll(s, "x", true), 2)
	t("business_mood", func(): G.business_mood(s), 3)
	t("monthly_update", func(): G.monthly_update(s), 2)
	t("world_monthly", func(): G.world_monthly(s), 2)
	quit()
