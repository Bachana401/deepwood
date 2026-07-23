extends CanvasLayer
# A quiet, always-current objective ticker at the top of the VILLAGE screen, so a
# new player (and a returning one) never has to guess what to do next -- it reads
# GameState.next_objective() live. Spawned by main.gd; the dungeon keeps its own
# level label. Hidden during the prologue (before you've arrived) and once the
# Harvest is turning the town (there's only one thing to do then).

var _label: Label = null
var _timer := 0.0

func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	var wrap := PanelContainer.new()
	wrap.add_theme_stylebox_override("panel", _bg())
	wrap.anchor_left = 0.5
	wrap.anchor_right = 0.5
	wrap.anchor_top = 0.0
	wrap.offset_top = 10.0
	wrap.grow_horizontal = Control.GROW_DIRECTION_BOTH
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wrap)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 16)
	m.add_theme_constant_override("margin_right", 16)
	m.add_theme_constant_override("margin_top", 5)
	m.add_theme_constant_override("margin_bottom", 5)
	wrap.add_child(m)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.72))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("outline_size", 4)
	m.add_child(_label)
	_wrap = wrap
	_refresh()

var _wrap: Control = null

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = 1.0
		_refresh()

func _refresh() -> void:
	if _wrap == null:
		return
	# This lives in main.tscn, so it is village-only already. Silent (1) through the
	# whole cinematic OPENING -- no "raise the Farm" nag on a new game's first frame,
	# only once building becomes the task (opening_done / dev_mode); (2) while the
	# interactive tutorial card is up (it carries the instructions then, tutorial_step
	# >= 0); and (3) while the town is TURNING (the Harvest, one thing left to do).
	var show: bool = (GameState.opening_done or GameState.dev_mode) \
		and GameState.tutorial_step < 0 and not GameState.harvest_at_home
	_wrap.visible = show
	if show:
		_label.text = "▶  " + GameState.next_objective()

func _bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.11, 0.82)
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.9, 0.82, 0.5, 0.45)
	sb.content_margin_left = 2.0
	sb.content_margin_right = 2.0
	return sb
