## How long the rules take: a new game, a summary of every voter, a poll, a month, a week.
## To check that the game stays quick. Usage: godot --headless --path godot -s tests/perf.gd
extends SceneTree
func _t(label: String, f: Callable, n := 5) -> void:
	var t0 = Time.get_ticks_usec()
	for i in n: f.call()
	print("%-28s %8.1f ms" % [label, (Time.get_ticks_usec() - t0) / 1000.0 / n])
func _init() -> void:
	var G = load("res://scripts/sim.gd").new()
	var t0 = Time.get_ticks_usec()
	var s: Dictionary = G.new_game({"seed": 3})
	print("new_game %.0f ms, pops %d" % [(Time.get_ticks_usec() - t0) / 1000.0, s.pops.size()])
	for i in 40:
		s.queue.clear(); G.advance_week(s)
	_t("score_context", func(): G.score_context(s), 20)
	_t("summarize(all pops)", func(): G.summarize(s, s.pops), 5)
	_t("district_results", func(): G.district_results(s), 3)
	_t("take_poll", func(): G.take_poll(s, "x", true), 3)
	_t("district_profiles", func(): G.district_profiles(s), 5)
	_t("raise_options", func(): G.raise_options(s), 20)
	_t("national_awareness", func(): G.national_awareness(s), 20)
	_t("monthly_update", func(): G.monthly_update(s), 2)
	_t("world_monthly", func(): G.world_monthly(s), 3)
	var wk = func():
		s.queue.clear(); G.advance_week(s)
	_t("advance_week (avg of 16)", wk, 16)
	quit()
