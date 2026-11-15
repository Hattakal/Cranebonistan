extends SceneTree
## Checks the mod loader: the merge rules, and a real mod folder loaded on top of the
## game's data (a temporary mod in user://mods, removed afterwards).
var fails = 0

func check(what: String, ok: bool) -> void:
	print(("ok    " if ok else "FAIL  ") + what)
	if not ok: fails += 1

func _init() -> void:
	# 1. merge rules
	var m = Mods.merge({"a": 1, "b": {"c": 2, "d": 3}}, {"b": {"c": 5}, "e": 6})
	check("objects merge key by key", m.a == 1 and m.b.c == 5 and m.b.d == 3 and m.e == 6)
	check("null removes a key", not Mods.merge({"a": 1, "b": 2}, {"b": null}).has("b"))
	check("_replace replaces an object", Mods.merge({"a": {"x": 1, "y": 2}}, {"a": {"_replace": true, "x": 9}}).a == {"x": 9})
	var l = Mods.merge([{"id": "p", "v": 1, "w": 1}, {"id": "q", "v": 2}], [{"id": "p", "v": 7}, {"id": "r", "v": 3}, {"id": "q", "_remove": true}])
	check("id lists merge, add and remove", l.size() == 2 and l[0].v == 7 and l[0].w == 1 and l[1].id == "r")
	check("name lists merge by name", Mods.merge([{"name": "A", "age": 1}], [{"name": "A", "age": 2}])[0].age == 2)
	check("plain lists are replaced", Mods.merge([1, 2], [3]) == [3])
	check("_append adds to a list", Mods.merge(["a"], {"_append": ["b"]}) == ["a", "b"])
	# 2. a real mod folder on top of the game's data
	var root = "user://mods/_check_mod"
	DirAccess.make_dir_recursive_absolute(root + "/data")
	var f = FileAccess.open(root + "/mod.json", FileAccess.WRITE); f.store_string('{"name": "Check", "version": "1"}'); f.close()
	f = FileAccess.open(root + "/data/content.json", FileAccess.WRITE)
	f.store_string('{"CONFIG": {"actionsPerMonth": 9}, "PARTIES": [{"id": "oc", "leader": "Modded Leader"}], "EVENTS": [{"id": "mod_event", "title": "A modded event", "text": "", "choices": [{"label": "Fine", "effects": {}}]}]}')
	f.close()
	f = FileAccess.open(root + "/data/names.json", FileAccess.WRITE); f.store_string('{"POOLS": {"erland": {"m": {"_append": ["Modbert"]}}}}'); f.close()
	Mods._list = null
	Mods._cache = {}
	var G = load("res://scripts/sim.gd").new()
	check("mod found and enabled", Mods.enabled().any(func(x): return x.id == "_check_mod"))
	check("a setting changed", int(G.C.actionsPerMonth) == 9)
	check("a rival leader renamed, rest of the party kept", G.by_id(G.PARTIES, "oc").leader == "Modded Leader" and G.by_id(G.PARTIES, "oc").has("manifesto"))
	check("an event added, the others kept", G.event_by_id("mod_event") != null and G.EVENTS.size() > 50)
	check("a name appended to a pool", G.NAMES.POOLS.erland.m.has("Modbert") and G.NAMES.POOLS.erland.m.size() > 20)
	var s: Dictionary = G.new_game({"seed": 3, "partyName": "T"})
	check("a game starts with the mod", s.parties.size() > 1 and G.party_of(s, "oc").leader == "Modded Leader")
	# clean up
	for p in [root + "/data/content.json", root + "/data/names.json", root + "/mod.json"]: DirAccess.remove_absolute(p)
	DirAccess.remove_absolute(root + "/data"); DirAccess.remove_absolute(root)
	print("RESULT mods ", "ok" if fails == 0 else "%d failed" % fails)
	quit()
