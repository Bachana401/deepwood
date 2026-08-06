extends CanvasLayer

const LEVEL_COUNT = 100

func _ready() -> void:
	visible = false
	# the one window that never joined esc_window: ESC used to stack the pause
	# menu ON TOP of the 100-button grid instead of closing it -- and the new
	# world-input gate (player.ui_blocks_world_input) keys off this group too,
	# so clicking a floor button no longer also swings the wielded weapon
	add_to_group("esc_window")
	build_level_grid()
	$Panel/CloseButton.pressed.connect(close)

func esc_is_open() -> bool:
	return visible

func esc_close() -> void:
	close()

func build_level_grid() -> void:
	var grid = $Panel/ScrollContainer/GridContainer
	for level in range(1, LEVEL_COUNT + 1):
		var button = Button.new()
		button.text = str(level)
		button.custom_minimum_size = Vector2(36, 36)
		button.pressed.connect(_on_level_selected.bind(level))
		grid.add_child(button)

func open() -> void:
	refresh_lock_states()
	visible = true
	warn_if_village_exposed()

# The Watchtower's SPIRIT until the Watchtower exists (GAME_BIBLE 7.1 -- the
# warning is the designed mitigation for siege chaos, and the building itself
# waits on art). At the moment the player chooses to leave, tell them what
# their absence will cost: when is the next siege due, and will the village
# hold it without them. Deaths while away are permanent -- nobody should learn
# that from the away report.
func warn_if_village_exposed() -> void:
	# post-game there is nothing left to warn about -- the sieges died with Orin
	if GameState.despair_dead:
		return
	# THE VILLAGE FOG: the dungeon door stands far from home -- without
	# Telepathy you descend on faith, exactly as the fog rule intends
	if not GameState.village_info_available():
		return
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack == null:
		return
	var tier: int = GameState.current_siege_tier()
	var defense: float = GameState.village_defense_power()
	# 7.1: without the Watchtower the WHEN is unknowable -- the warning can
	# only speak to whether the village would hold, not to any clock
	if not GameState.siege_clock_visible():
		if defense < float(tier):
			stack.show_notification("⚠ The village stands exposed — and without a Watchtower, you cannot know when the next wave comes. Every loss while you're away is forever.")
		return
	var hours: float = GameState.hours_until_next_siege
	if defense < float(tier):
		stack.show_notification("⚠ A tier-%d siege lands in ~%dh — defense %.1f will NOT hold. Every loss while you're away is forever." % [tier, int(ceil(hours)), defense])
	elif hours < 6.0:
		stack.show_notification("A siege is due in ~%dh. Defense %.1f should hold — but the deep keeps its own time." % [int(ceil(hours)), defense])

# Only levels up to GameState.highest_unlocked_level are pressable -- clearing
# a level unlocks the next one (see DungeonManager._on_combatant_died).
func refresh_lock_states() -> void:
	var grid = $Panel/ScrollContainer/GridContainer
	for i in range(grid.get_child_count()):
		var level = i + 1
		var button = grid.get_child(i)
		button.disabled = level > GameState.highest_unlocked_level
		# BLUEPRINT MARKERS (polish 2026-07-20): a floor still holding lost
		# plans wears a scroll. Blueprints gate every rebuild, so hunting
		# them blind would be a scavenger hunt with no map -- the village
		# remembers roughly where its things were dragged.
		if GameState.BLUEPRINT_FLOORS.has(level) and not GameState.has_blueprint(str(GameState.BLUEPRINT_FLOORS[level])):
			# DEV CALL (2026-07-21): no blueprint spoilers -- the scroll says
			# SOMETHING waits here, never WHAT. Discovery stays discovery.
			button.text = "%d\n📜" % level
			button.tooltip_text = "Something of Deepwood's lies lost on this floor"
			button.add_theme_color_override("font_color", Color(0.95, 0.88, 0.55))
		else:
			button.text = str(level)
			button.tooltip_text = ""
			button.remove_theme_color_override("font_color")

func close() -> void:
	visible = false

func _on_level_selected(level: int) -> void:
	if level > GameState.highest_unlocked_level:
		return
	# THE NEW FINALE (canon rework 2026-07-20): floor 100 opens like any other
	# floor once 99 is cleared -- and stands EMPTY. The old perfect-village
	# gate is gone; the peak is now created dramatically (the false victory ->
	# the feast), and the wand guard lives at the feast (harvest_director),
	# the moment it is about to matter.
	# One door stays shut: nobody descends mid-Harvest. You cannot run from this.
	if GameState.harvest_at_home:
		var stack = get_tree().get_first_node_in_group("notification_stack")
		if stack:
			stack.show_notification("⛔ The village is TURNING behind you. There is nothing below anymore — the fight is HERE.")
		return
	# A FALLEN BLOCK CUTS THE ROAD. This was promised in two places -- the patrol
	# panel tells the player a lost block cuts the way down, and game_state has
	# carried floor_is_road_blocked() to answer it -- but NOTHING anywhere read that
	# function except its own test. The way down stayed wide open, so losing a block
	# cost the player nothing and the warning was a lie. (A woken Waystone shrine
	# still reaches past it; that is what makes the network worth building.)
	if GameState.floor_is_road_blocked(level):
		var blocked_stack = get_tree().get_first_node_in_group("notification_stack")
		if blocked_stack:
			var fallen: int = GameState.first_fallen_block()
			var r: Array = GameState.block_floor_range(fallen)
			blocked_stack.show_notification(
				"⛔ The road is cut at floors %d-%d. Take them back, or reach past by Waystone."
				% [int(r[0]), int(r[1])])
		return
	close()
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	# real teleport: capture everything that needs to survive the scene
	# swap, remember where to put the player back, then hand off to
	# dungeon_interior.tscn -- see game_state.gd's carry-over fields and
	# player.gd's apply_pending_player_state().
	GameState.pending_player_state = GameState.capture_player_state(player)
	GameState.pre_dungeon_position = player.global_position
	GameState.active_dungeon_level = level
	# a floor launched from the village Waystone returns to the VILLAGE. Declare that
	# explicitly (as underdark_door.gd does for the underground) so a stale true left by
	# a prior underground trip can't misroute this floor's exit into the underground.
	GameState.came_from_underground = false
	get_tree().change_scene_to_file.call_deferred("res://dungeon_interior.tscn")
