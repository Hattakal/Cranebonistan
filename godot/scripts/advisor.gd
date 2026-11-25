## advisor.gd — Carlos Aster in the corner of headquarters, and Margaret
## Perkins's notes. Carlos talks (with a recording if one exists in
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
var _hold := false

func _process(d: float) -> void:
	if _bubble == null or not _bubble.visible or _hold or not _busy: return
	var over: bool = _bubble.get_global_rect().has_point(get_global_mouse_position())
	var want: float = 0.12 if over else 1.0
	if absf(_bubble.modulate.a - want) > 0.01:
		_bubble.modulate.a = move_toward(_bubble.modulate.a, want, d * 6.0)

func _ready() -> void:
	LINES = Mods.data("carlos").LINES
	M_LINES = Mods.data("margaret")
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
	var sb = Look.box(Look.N700, 3, Look.N500, 1, 0, 14)
	sb.border_width_left = 3; sb.border_color = Look.LAMP
	sb.shadow_color = Color(0, 0, 0, 0.55); sb.shadow_size = 16
	_bubble.add_theme_stylebox_override("panel", sb)
	_bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	_bubble.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: _next())
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var who = Look.caps("Carlos Aster · advisor", 11, Look.LAMP, 2)
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(who)
	_text = Look.label("", "body", 16, Look.TXT, true)
	_text.custom_minimum_size.x = 340
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_text)
	_hint = Look.label("", "body_italic", 11, Look.FAINT)
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
	# an ordinary remark never blocks the buttons under it: clicks pass through, and it
	# fades while the mouse is over it (see _process). Tutorial lines wait for a click.
	_bubble.mouse_filter = Control.MOUSE_FILTER_STOP if item.hold else Control.MOUSE_FILTER_IGNORE
	_hold = item.hold
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
		if Mods.has_asset(p):
			_audio.stream = Mods.audio(p)
			_audio.play()
			return

## Margaret steps in: a typed note with two answers.
func margaret(trigger: String) -> void:
	if _note or not M_LINES.LINES.has(trigger): return
	var text: String = M_LINES.LINES[trigger][randi() % M_LINES.LINES[trigger].size()]
	_note = PanelContainer.new()
	var sb = Look.box(Look.PAPER, 1, Look.RED, 0, 0, 16)
	sb.border_width_left = 4
	sb.shadow_color = Color(0, 0, 0, 0.6); sb.shadow_size = 18
	_note.add_theme_stylebox_override("panel", sb)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(Look.caps("Margaret Perkins · party secretary", 11, Look.RED, 2))
	var t = Look.label(text, "type", 14, Look.INK, true)
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
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_stylebox_override("normal", Look.box(Color(1, 1, 1, 0.35), 2, Look.INK if pr[1] else Look.MUTED, 1, 0, 8))
		b.add_theme_stylebox_override("hover", Look.box(Look.INK, 2, Look.INK, 1, 0, 8))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
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

## Carlos: his picture (godot/assets/portraits/carlos.jpg) or, until there is one, a man
## in a dark office with the lamp behind him: a silhouette with a warm edge, which nods
## while he talks.
class Portrait extends Control:
	var _talk := 0.0
	var _has_photo := false
	func _ready() -> void:
		clip_contents = true
		var tex = Photo.find(["portraits/carlos"])
		if tex:
			_has_photo = true
			var ph = Photo.new(tex, true, true)
			ph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			ph.show_behind_parent = true
			add_child(ph)
	func talk(seconds: float) -> void:
		_talk = seconds
	func _process(d: float) -> void:
		if _talk > 0:
			_talk -= d
			queue_redraw()
	func _draw() -> void:
		var c = size / 2
		var r = size.x / 2
		var bob = sin(Time.get_ticks_msec() / 90.0) * 1.5 if _talk > 0 else 0.0
		if _has_photo:
			draw_arc(c, r - 1, 0, TAU, 48, Look.LAMP if _talk > 0 else Look.N500, 1.5, true)
			return
		draw_circle(c, r - 1, Look.N700)
		# the lamp somewhere behind his right shoulder
		var lamp = c + Vector2(r * 0.3, -r * 0.18)
		draw_circle(lamp, r * 0.64, Color(Look.LAMP, 0.08))
		draw_circle(lamp, r * 0.46, Color(Look.LAMP, 0.1))
		draw_circle(lamp, r * 0.28, Color(Look.LAMP, 0.16))
		var sh = c + Vector2(0, size.y * 0.56)
		var sr = size.x * 0.4
		var h = c + Vector2(0, -6 + bob)
		var hr = size.x * 0.19
		var rim = Vector2(2.0, -1.0)
		# the edge the light catches, then the man himself
		draw_circle(sh + rim, sr, Color(Look.LAMP, 0.85))
		draw_circle(h + rim, hr, Color(Look.LAMP, 0.85))
		draw_rect(Rect2(h.x - hr * 0.42 + rim.x, h.y, hr * 0.84, hr * 1.6), Color(Look.LAMP, 0.85))
		draw_circle(sh, sr, Look.N950)
		draw_rect(Rect2(h.x - hr * 0.42, h.y, hr * 0.84, hr * 1.6), Look.N950)
		draw_circle(h, hr, Look.N950)
		draw_arc(c, r - 1, 0, TAU, 48, Look.LAMP if _talk > 0 else Look.N500, 1.5, true)
