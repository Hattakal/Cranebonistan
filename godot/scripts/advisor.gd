## advisor.gd — Carlos Aster in the corner of headquarters, and Margaret
## Teyl's notes. Carlos talks (with a recording if one exists in
## assets/voice/carlos/<id>.ogg or .wav); Margaret only writes, and rarely.
class_name Advisor
extends Control

signal margaret_answered(agreed: bool)

const COOLDOWN := 6.0        # seconds between unprompted lines
var LINES: Dictionary = {}
var M_LINES: Dictionary = {}
var _order = {}               # situation -> shuffled ids still to use
var _queue: Array = []        # [{id, text, hold}]
var _busy := false
var _last_spoke := -100.0
var _tut_left: Array = []

var _portrait: Control
var _bubble: PanelContainer
var _text: Label
var _hint: Label
var _audio: AudioStreamPlayer
var _note: PanelContainer = null

func _ready() -> void:
	LINES = JSON.parse_string(FileAccess.get_file_as_string("res://data/carlos.json")).LINES
	M_LINES = JSON.parse_string(FileAccess.get_file_as_string("res://data/margaret.json"))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_audio = AudioStreamPlayer.new()
	add_child(_audio)
	_portrait = Portrait.new()
	_portrait.custom_minimum_size = Vector2(86, 86)
	_portrait.size = Vector2(86, 86)
	_portrait.tooltip_text = "Carlos Aster, your advisor. Click for a tip."
	_portrait.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_portrait.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			if _tut_left.size() or _busy: _next()
			else: say("tip", true))
	add_child(_portrait)
	_bubble = PanelContainer.new()
	var sb = Look.box(Color("fbf6e8"), 10, Color("3b2a12"), 2, 14, 12)
	sb.shadow_color = Color(0, 0, 0, 0.45); sb.shadow_size = 10
	_bubble.add_theme_stylebox_override("panel", sb)
	_bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	_bubble.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: _next())
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var who = Look.caps("Carlos Aster · advisor", 10, Color("8b6a2b"), 1)
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(who)
	_text = Look.label("", "body", 16, Look.INK, true)
	_text.custom_minimum_size.x = 340
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_text)
	_hint = Look.label("", "body_italic", 11, Look.MUTED)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_hint)
	_bubble.add_child(v)
	_bubble.visible = false
	add_child(_bubble)
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	_portrait.position = Vector2(18, size.y - 86 - 18)
	_bubble.reset_size()
	_bubble.position = Vector2(18 + 86 + 10, size.y - _bubble.get_combined_minimum_size().y - 62)

## Say a line from a situation. Unprompted lines respect a cooldown, so Carlos
## doesn't talk over himself; `force` is for things the player asked for.
func say(situation: String, force := false, chance := 1.0) -> void:
	if not LINES.has(situation): return
	if not force:
		if randf() > chance: return
		if Time.get_ticks_msec() / 1000.0 - _last_spoke < COOLDOWN and _busy: return
	var line = _pick(situation)
	_queue.append({"id": line.id, "text": line.text, "hold": false})
	if not _busy: _next()

func tutorial() -> void:
	_queue.clear()
	for line in LINES.tutorial: _queue.append({"id": line.id, "text": line.text, "hold": true})
	_tut_left = _queue.duplicate()
	_next()

func _pick(situation: String) -> Dictionary:
	var pool: Array = LINES[situation]
	if not _order.has(situation) or _order[situation].is_empty():
		var idx = range(pool.size())
		idx.shuffle()
		_order[situation] = idx
	return pool[_order[situation].pop_back()]

func _next() -> void:
	if _tut_left.size(): _tut_left.pop_front()
	if _queue.is_empty():
		_busy = false
		var tw = _bubble.create_tween()
		tw.tween_property(_bubble, "modulate:a", 0.0, 0.25)
		tw.tween_callback(func(): _bubble.visible = false)
		return
	_busy = true
	var item: Dictionary = _queue.pop_front()
	_last_spoke = Time.get_ticks_msec() / 1000.0
	_text.text = item.text
	_text.visible_ratio = 0.0
	_hint.text = ("Click to continue · %d more" % _queue.size()) if item.hold and _queue.size() else ("Click to continue" if item.hold else "")
	_bubble.visible = true
	_bubble.modulate.a = 1.0
	_layout()
	await get_tree().process_frame
	_layout()
	(_portrait as Portrait).talk(1.2 + item.text.length() / 30.0)
	var tw = _bubble.create_tween()
	tw.tween_property(_text, "visible_ratio", 1.0, item.text.length() / 55.0)
	_play(item.id)
	if not item.hold:
		var me = item.text
		get_tree().create_timer(3.5 + item.text.length() / 22.0).timeout.connect(func():
			if _text.text == me and _busy: _next())

func _play(id: String) -> void:
	for ext in ["ogg", "wav", "mp3"]:
		var p = "res://assets/voice/carlos/%s.%s" % [id, ext]
		if ResourceLoader.exists(p):
			_audio.stream = load(p)
			_audio.play()
			return

## Margaret steps in: a typed note with two answers.
func margaret(trigger: String) -> void:
	if _note or not M_LINES.LINES.has(trigger): return
	var text: String = M_LINES.LINES[trigger][randi() % M_LINES.LINES[trigger].size()]
	_note = PanelContainer.new()
	var sb = Look.box(Color("f3ead6"), 2, Color("8b1e1e"), 0, 16, 14)
	sb.border_width_left = 5
	sb.shadow_color = Color(0, 0, 0, 0.5); sb.shadow_size = 12
	_note.add_theme_stylebox_override("panel", sb)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(Look.caps("Margaret Teyl · party secretary", 10, Color("8b1e1e"), 1))
	var t = Look.label("“%s”" % text, "type", 16, Look.INK, true)
	t.custom_minimum_size.x = 380
	v.add_child(t)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var agree: String = M_LINES.AGREE[randi() % M_LINES.AGREE.size()]
	var dismiss: String = M_LINES.DISMISS[randi() % M_LINES.DISMISS.size()]
	for pr in [[agree, true], [dismiss, false]]:
		var b = Button.new()
		b.text = pr[0]
		b.add_theme_font_override("font", Look.font("body_bold"))
		b.add_theme_font_size_override("font_size", Look.fs(13))
		b.add_theme_color_override("font_color", Look.INK)
		b.add_theme_stylebox_override("normal", Look.box(Color(0, 0, 0, 0.06), 3, Color("8b1e1e") if pr[1] else Look.MUTED, 1, 8, 4))
		b.add_theme_stylebox_override("hover", Look.box(Color(0, 0, 0, 0.12), 3, Color("8b1e1e") if pr[1] else Look.MUTED, 1, 8, 4))
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var agreed: bool = pr[1]
		b.pressed.connect(func():
			margaret_answered.emit(agreed)
			var n = _note
			_note = null
			var tw = n.create_tween()
			tw.tween_property(n, "modulate:a", 0.0, 0.25)
			tw.tween_callback(n.queue_free))
		row.add_child(b)
	v.add_child(row)
	_note.add_child(v)
	add_child(_note)
	_note.reset_size()
	_note.position = Vector2(size.x - _note.size.x - 30, size.y + 10)
	_note.rotation_degrees = -1.2
	var tw = _note.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_note, "position:y", size.y - _note.size.y - 70, 0.5)

## A placeholder portrait until the real art arrives: a drawn bust that
## bobs while he talks.
class Portrait extends Control:
	var _talk := 0.0
	func talk(seconds: float) -> void:
		_talk = seconds
	func _process(d: float) -> void:
		if _talk > 0:
			_talk -= d
			queue_redraw()
	func _draw() -> void:
		var c = size / 2
		var bob = sin(Time.get_ticks_msec() / 90.0) * 1.5 if _talk > 0 else 0.0
		draw_circle(c, size.x / 2, Color("3b2a12"))
		draw_circle(c, size.x / 2 - 3, Color("c9a35a"))
		# shoulders and suit
		draw_circle(c + Vector2(0, size.y * 0.52), size.x * 0.36, Color("2a3550"))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 14), c + Vector2(6, 14), c + Vector2(0, 30)]), Color("f3ead6"))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-2, 16), c + Vector2(2, 16), c + Vector2(0, 28)]), Look.RED)
		# head
		var h = c + Vector2(0, -8 + bob)
		draw_circle(h, size.x * 0.2, Color("e8c39e"))
		draw_arc(h + Vector2(0, -3), size.x * 0.21, PI * 1.05, PI * 1.95, 16, Color("2b1d12"), 6)
		draw_circle(h + Vector2(-5, -1), 1.6, Look.INK)
		draw_circle(h + Vector2(5, -1), 1.6, Look.INK)
		var mouth = 3.0 + (absf(sin(Time.get_ticks_msec() / 70.0)) * 3.0 if _talk > 0 else 0.0)
		draw_arc(h + Vector2(0, 6), 4, 0.2, PI - 0.2, 8, Color("7a3020"), mouth * 0.6)
