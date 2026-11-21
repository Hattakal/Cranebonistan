## mods.gd — loading the game's data and assets, with mods on top.
##
## A mod is a folder with a mod.json, and any of:
##   data/<file>.json   merged into the game's data/<file>.json (see merge() below)
##   assets/<path>      replaces res://assets/<path> (pictures, voice lines)
## Mods are looked for in three places, in this order:
##   user://mods/                     (the player's data folder)
##   <folder of the game executable>/mods/
##   <repository>/mods/               (when running from the Godot editor)
## Within those, mods load by "priority" in mod.json (lower first), then by folder
## name; a later mod wins. "enabled": false in mod.json switches a mod off.
## See MODDING.md for the full guide.
class_name Mods
extends RefCounted

static var _list = null      # the enabled mods: [{id, name, version, description, path}]
static var _cache = {}       # data file name -> merged data

## Every mod folder found, enabled or not (for showing the list).
static func all() -> Array:
	var found = []
	var seen = {}
	for root in _roots():
		var dir = DirAccess.open(root)
		if dir == null: continue
		for sub in dir.get_directories():
			var path: String = root.path_join(sub)
			if seen.has(sub) or not FileAccess.file_exists(path.path_join("mod.json")): continue
			var info = JSON.parse_string(FileAccess.get_file_as_string(path.path_join("mod.json")))
			if typeof(info) != TYPE_DICTIONARY:
				push_warning("Mod %s: mod.json is not valid JSON; skipped." % path)
				continue
			seen[sub] = true
			found.append({"id": sub, "name": str(info.get("name", sub)), "version": str(info.get("version", "")),
				"description": str(info.get("description", "")), "priority": float(info.get("priority", 0)),
				"enabled": bool(info.get("enabled", true)), "path": path})
	found.sort_custom(func(a, b): return a.priority < b.priority or (a.priority == b.priority and a.id < b.id))
	return found

## The mods that are switched on, in load order.
static func enabled() -> Array:
	if _list == null:
		_list = all().filter(func(m): return m.enabled)
		if _list.size(): print("Mods: ", ", ".join(_list.map(func(m): return "%s %s" % [m.name, m.version])))
	return _list

static func _roots() -> Array:
	var roots = ["user://mods"]
	if not OS.has_feature("editor"):
		roots.append(OS.get_executable_path().get_base_dir().path_join("mods"))
	else:
		roots.append(ProjectSettings.globalize_path("res://").path_join("../mods").simplify_path())
	return roots

## A data file, by name (without .json): the game's version, with every enabled mod's
## version merged on top. A mod may also add a data file the game doesn't have.
static func data(name: String) -> Variant:
	if _cache.has(name): return _cache[name].duplicate(true)
	var out = _names_in(_merged(name), _world_names())
	_cache[name] = out
	return out.duplicate(true) if out is Dictionary or out is Array else out

## The world's names, written into texts as {country}, {national} and {nationals}
## ("Who is a real {national}?"). Set in content.json COUNTRY, so a rename (or a mod)
## changes one place. Unknown {words} are left alone for the rules to fill in later.
static var _world = null
static func _world_names() -> Dictionary:
	if _world == null:
		var c = _merged("content")
		var w: Dictionary = c.get("COUNTRY", {}) if c is Dictionary else {}
		_world = {"country": str(w.get("name", "")), "national": str(w.get("national", "")), "nationals": str(w.get("nationals", ""))}
	return _world

static func _names_in(v, names: Dictionary):
	if v is String:
		return v.format(names) if v.contains("{") else v
	if v is Array:
		var a: Array = v
		for i in a.size(): a[i] = _names_in(a[i], names)
	elif v is Dictionary:
		var d: Dictionary = v
		for k in d.keys(): d[k] = _names_in(d[k], names)
	return v

static func _merged(name: String) -> Variant:
	var path = "res://data/%s.json" % name
	var out = null
	if FileAccess.file_exists(path):
		out = JSON.parse_string(FileAccess.get_file_as_string(path))
		if out == null: push_error("data/%s.json is not valid JSON." % name)
	for m in enabled():
		var mp: String = m.path.path_join("data").path_join(name + ".json")
		if not FileAccess.file_exists(mp): continue
		var add = JSON.parse_string(FileAccess.get_file_as_string(mp))
		if add == null:
			push_warning("Mod %s: data/%s.json is not valid JSON; ignored." % [m.name, name])
			continue
		out = add if out == null else merge(out, add)
	return out

## How a mod's data meets the game's:
## - Objects merge key by key. A key set to null is removed. {"_replace": true} in
##   an object replaces the whole object instead of merging into it.
## - Lists of objects with an "id" (events, parties, regions, outlets...) merge by
##   id: a known id is merged into, a new id is added, {"id": "x", "_remove": true}
##   removes one. Lists of objects with a "name" but no id (people) merge by name.
## - Any other list is replaced, unless the mod writes {"_append": [...]}, which adds
##   to it (handy for name lists and lines).
static func merge(base, add):
	if add is Dictionary and add.has("_append") and base is Array:
		var a: Array = base.duplicate(true)
		a.append_array(add._append)
		return a
	if add is Dictionary and base is Dictionary:
		if add.get("_replace", false):
			var r = add.duplicate(true)
			r.erase("_replace")
			return r
		var out: Dictionary = base.duplicate(true)
		for k in add:
			if add[k] == null: out.erase(k)
			elif out.has(k): out[k] = merge(out[k], add[k])
			else: out[k] = add[k]
		return out
	if add is Array and base is Array:
		var key = _list_key(base) if base.size() else _list_key(add)
		if key == "": return add
		var out: Array = base.duplicate(true)
		for item in add:
			if not (item is Dictionary) or not item.has(key):
				out.append(item); continue
			var at = -1
			for i in out.size():
				if out[i] is Dictionary and out[i].get(key) == item[key]: at = i; break
			if item.get("_remove", false):
				if at >= 0: out.remove_at(at)
			elif at >= 0: out[at] = merge(out[at], item)
			else: out.append(item)
		return out
	return add

static func _list_key(a: Array) -> String:
	for key in ["id", "name"]:
		if a.size() and a.all(func(x): return x is Dictionary and x.has(key)): return key
	return ""

# ---------- Assets ----------
## The file to use for res://assets/<path>: the last enabled mod that has it, or the game's.
static func asset_path(res_path: String) -> String:
	var rel: String = res_path.trim_prefix("res://")
	var best = res_path
	for m in enabled():
		var mp: String = m.path.path_join(rel)
		if FileAccess.file_exists(mp): best = mp
	return best

static func has_asset(res_path: String) -> bool:
	var p = asset_path(res_path)
	return ResourceLoader.exists(p) if p.begins_with("res://") else FileAccess.file_exists(p)

## A picture (png, jpg, webp, svg): a mod's file or the game's.
static func texture(res_path: String) -> Texture2D:
	var p = asset_path(res_path)
	if p.begins_with("res://"): return load(p) if ResourceLoader.exists(p) else null
	var img = Image.load_from_file(p)
	return ImageTexture.create_from_image(img) if img else null

## A sound (ogg, mp3, wav): a mod's file or the game's.
static func audio(res_path: String) -> AudioStream:
	var p = asset_path(res_path)
	if p.begins_with("res://"): return load(p) if ResourceLoader.exists(p) else null
	match p.get_extension().to_lower():
		"ogg": return AudioStreamOggVorbis.load_from_file(p)
		"mp3": return AudioStreamMP3.load_from_file(p)
		"wav": return AudioStreamWAV.load_from_file(p)
	return null
