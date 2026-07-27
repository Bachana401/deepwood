extends Area2D
# A hidden stone door of the Underdark (GAME_BIBLE §4 amendment). Each one is
# sealed onto ONE dungeon floor; finding it deep in the caves is the reward.
# It opens only if that floor is unlocked -- the ladder is untouched, a door
# is an entry SHORTCUT, not a skip. Entering records pre_dungeon_position, so
# leaving the floor puts you back at this very door.

var target_level := 1
var player_inside := false
var prompt: Label = null
var rune: ColorRect = null
# THE WAY FORWARD (dev ask 2026-07-22: "1 main way clearly indicating to go for
# floors"). Exactly one door -- the deepest floor you can currently enter -- wears
# a tall beacon of light so, in a cave of many doors, the next step is never a
# guess. It updates live as you clear floors and the frontier moves on.
var beacon: Node2D = null

func _ready() -> void:
	add_to_group("underdark_floor_door")   # so the strip can sleep them topside
	collision_mask = 2
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(150.0, 150.0)
	cs.shape = rect
	cs.position = Vector2(0, -70.0)
	add_child(cs)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	_build_visual()

func _build_visual() -> void:
	# a weathered arch and slab, dressed dim -- it should be FOUND, not seen
	var arch := Polygon2D.new()
	arch.color = Color(0.19, 0.17, 0.155)
	arch.polygon = PackedVector2Array([
		Vector2(-44, 0), Vector2(-44, -96), Vector2(-26, -118), Vector2(26, -118),
		Vector2(44, -96), Vector2(44, 0), Vector2(30, 0), Vector2(30, -90),
		Vector2(18, -104), Vector2(-18, -104), Vector2(-30, -90), Vector2(-30, 0)])
	arch.z_index = -5
	add_child(arch)
	var slab := ColorRect.new()
	slab.color = Color(0.115, 0.105, 0.1)
	slab.size = Vector2(60, 104)
	slab.position = Vector2(-30, -104)
	slab.z_index = -5
	add_child(slab)
	# the rune: the one glint of colour in the dark. Cold blue while sealed,
	# warm gold once the floor behind it is unlocked.
	rune = ColorRect.new()
	rune.size = Vector2(10, 26)
	rune.position = Vector2(-5, -78)
	rune.z_index = -4
	add_child(rune)
	prompt = Label.new()
	prompt.add_theme_font_size_override("font_size", 12)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.position = Vector2(-130.0, -166.0)
	prompt.size = Vector2(260.0, 20.0)
	prompt.visible = false
	prompt.z_index = 5
	add_child(prompt)
	_build_beacon()

# A tall, soft column of gold light rising from the arch, capped by a slowly
# bobbing chevron pointing down at the door -- the "go here next" marker. Built
# hidden; only the frontier door shows it (see _process). Additive, so it reads
# as light against the dark; a single cheap tween drives the bob + pulse.
func _build_beacon() -> void:
	beacon = Node2D.new()
	beacon.visible = false
	beacon.z_index = -3
	add_child(beacon)
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# the column: a few stacked bars, brightest at the base, fading up
	for i in range(6):
		var bar := ColorRect.new()
		var wdt := 26.0 - i * 3.0
		bar.size = Vector2(wdt, 66.0)
		bar.position = Vector2(-wdt / 2.0, -150.0 - i * 62.0)
		bar.color = Color(1.0, 0.82, 0.4, 0.16 - i * 0.02)
		bar.material = add_mat
		beacon.add_child(bar)
	# the bobbing chevron above the arch
	var chevron := Polygon2D.new()
	chevron.polygon = PackedVector2Array([Vector2(-16, -18), Vector2(16, -18), Vector2(0, 0)])
	chevron.color = Color(1.0, 0.85, 0.45, 0.95)
	chevron.material = add_mat
	chevron.position = Vector2(0, -132.0)
	beacon.add_child(chevron)
	var t := create_tween().set_loops()
	t.tween_property(chevron, "position:y", -120.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(chevron, "position:y", -132.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _unlocked() -> bool:
	return target_level <= GameState.highest_unlocked_level

# The single door worth beaconing: the deepest floor you can currently enter.
func _is_frontier() -> bool:
	return target_level == GameState.highest_unlocked_level

func _process(_delta: float) -> void:
	rune.color = Color(0.95, 0.78, 0.3, 0.9) if _unlocked() else Color(0.3, 0.5, 0.85, 0.7)
	if beacon != null:
		beacon.visible = _is_frontier()
	if not player_inside:
		return
	if Input.is_action_just_pressed("interact"):
		_try_enter()

func _on_enter(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	player_inside = true
	if _unlocked():
		prompt.text = "[E]  A door in the stone — Floor %d" % target_level
	else:
		prompt.text = "Sealed. The stone hums: floor %d must fall first." % (target_level - 1)
	prompt.visible = true

func _on_exit(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = false
		prompt.visible = false

func _try_enter() -> void:
	var pl = get_tree().get_first_node_in_group("player")
	if pl == null:
		return
	# the arrival talk can never be skipped by diving early: if it is still
	# owed, the reveal happens here at the door instead of at the wall
	var main := get_tree().current_scene
	if main != null and "_arrival_talk_pending" in main and main._arrival_talk_pending:
		main._arrival_talk_pending = false
		main.play_arrival_talk(pl)
		return
	if not _unlocked():
		GameState.notify("The seal holds — clear floor %d first." % (target_level - 1))
		return
	# one door stays shut mid-Harvest, same as the old scroll: you cannot run
	if GameState.harvest_at_home:
		GameState.notify("⛔ The village is TURNING behind you. There is nothing below anymore — the fight is HERE.")
		return
	# the exact launch sequence level_select_ui used, verbatim semantics:
	# capture what must survive the swap, remember where to put the player
	# back (RIGHT HERE, at this door), then hand off to the floor
	GameState.pending_player_state = GameState.capture_player_state(pl)
	GameState.pre_dungeon_position = global_position
	GameState.active_dungeon_level = target_level
	# if this door stands in the tile UNDERGROUND, remember to return there (not the
	# village) when the floor is left.
	GameState.came_from_underground = get_tree().get_first_node_in_group("tile_world") != null
	get_tree().change_scene_to_file.call_deferred("res://dungeon_interior.tscn")
