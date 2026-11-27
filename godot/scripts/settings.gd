## settings.gd — the player's options, kept in user://settings.cfg between runs.
## Read once at start (Settings.load_all() in main.gd); the Options sheet changes them.
## Only how the game looks and sounds; nothing here changes the rules.
class_name Settings
extends RefCounted

const PATH := "user://settings.cfg"
const DEFAULTS := {
	"look": "study",       # the colour scheme: Look.PALETTES
	"grain": false,        # film grain and darker corners over the screen (off: it shimmered)
	"mapedge": "clear",    # the map's edges: clear, or fading into the dark
	"text": "normal",      # normal | large
	"fullscreen": false,
	"volume": 0.8,         # 0..1, everything (Carlos's voice for now)
}
static var values := DEFAULTS.duplicate()
static var reopen := false   # open the Options sheet again after the screen rebuilds

static func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))

static func load_all() -> void:
	var cf = ConfigFile.new()
	if cf.load(PATH) == OK:
		for k in DEFAULTS: values[k] = cf.get_value("options", k, DEFAULTS[k])
	apply()

static func set_value(key: String, v: Variant) -> void:
	values[key] = v
	var cf = ConfigFile.new()
	for k in values: cf.set_value("options", k, values[k])
	cf.save(PATH)
	apply()

## What can change without rebuilding the screen; the look and the text size need a
## rebuild (main.gd reloads the scene).
static func apply() -> void:
	Look.use(str(get_value("look")))
	Look.text_boost = 2 if get_value("text") == "large" else 0
	var full: bool = get_value("fullscreen")
	if DisplayServer.get_name() != "headless":
		var mode = DisplayServer.window_get_mode()
		if full and mode != DisplayServer.WINDOW_MODE_FULLSCREEN: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif not full and mode == DisplayServer.WINDOW_MODE_FULLSCREEN: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(get_value("volume")), 0.0001)))
