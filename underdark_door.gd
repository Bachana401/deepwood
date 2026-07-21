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

func _ready() -> void:
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

func _unlocked() -> bool:
	return target_level <= GameState.highest_unlocked_level

func _process(_delta: float) -> void:
	rune.color = Color(0.95, 0.78, 0.3, 0.9) if _unlocked() else Color(0.3, 0.5, 0.85, 0.7)
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
	get_tree().change_scene_to_file.call_deferred("res://dungeon_interior.tscn")
