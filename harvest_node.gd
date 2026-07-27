extends Area2D

# A harvestable world node: a TREE (chop with the Woodsman's Axe) or a ROCK
# (mine with the Miner's Pickaxe). Built procedurally and spawned by main.gd's
# generate_harvestables(). An Area2D on purpose -- it never blocks the player
# walking past; the player's melee swing finds it via AttackArea overlap and
# calls take_tool_hit() when a matching tool is wielded (see player.gd).
#
# Wrong tool (or bare weapon with a tool wielded elsewhere) does nothing --
# the node only reacts to tool swings, and tells you which tool it wants.
# Depleting it pays out materials straight into the player's inventory, with
# a tiny chance of a gathering-exclusive relic (Sylvan Charm from trees,
# Heart of the Mountain from rocks -- never dungeon loot). It then withers
# away and regrows on the spot a couple of minutes later.

const HITS_TO_HARVEST = 4
const REGROW_SECONDS = 150.0
const RELIC_FIND_CHANCE = 0.02
const MATERIAL_PICKUP = preload("res://material_pickup.gd")

# Materials POP OUT onto the ground now (Terraria-style) instead of teleporting
# into the bag -- they toss out and magnet back to the player (material_pickup).
func _drop(id: String, n: int) -> void:
	if n <= 0:
		return
	var d = MATERIAL_PICKUP.new()
	get_parent().add_child(d)
	d.setup(id, n, global_position + Vector2(randf_range(-8.0, 8.0), -34.0))

# STONE IS A DEPOSIT, NOT A TREE (dev call 2026-07-21). A tree is four swings
# and it's gone. A rock holds TWENTY TIMES that reserve, pays out on every
# swing as you work it, and SHRINKS as it empties -- the shrinking IS the
# gauge, so you can read a seam's worth from across the clearing. When the
# reserve runs out it finally disappears (and a new seam surfaces later).
const ROCK_RESERVE_MULT = 5
const ROCK_RESERVE = HITS_TO_HARVEST * ROCK_RESERVE_MULT   # 20 swings (dev: stone was WAY too much)
const ROCK_MIN_SCALE = 0.34        # how small a nearly-spent seam looks
const ROCK_REGROW_SECONDS = 420.0  # a whole deposit takes far longer to return

var node_type := "tree"   # "tree" | "rock"
var state_id := ""        # stable id from main.spawn_harvest_node -- "" = untracked
var hits_left := HITS_TO_HARVEST
var reserve_left := ROCK_RESERVE
var size_mult := 1.0      # trees vary a LITTLE: a bigger one is a couple more swings
var depleted := false
var _regrow_at := 0.0     # game-hours deadline while depleted (0 = not depleted)
var visual_root: Node2D = null
var shake_tween: Tween = null

func _ready() -> void:
	add_to_group("harvestable")
	monitorable = true
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(56, 110) if node_type == "tree" else Vector2(70, 52)
	shape.shape = rect
	shape.position = Vector2(0, -rect.size.y / 2.0)
	add_child(shape)
	visual_root = Node2D.new()
	add_child(visual_root)
	if node_type == "tree":
		build_tree_visual()
		# a LITTLE variety (dev 2026-07-22): three sizes, a bigger tree is a few
		# more swings -- never wildly different, so the grove reads as a grove
		size_mult = [0.85, 1.0, 1.2][randi() % 3]
		visual_root.scale = Vector2(size_mult, size_mult)
		hits_left = int(round(HITS_TO_HARVEST * size_mult))
	else:
		build_rock_visual()
	_restore_state()

# --- persistence (audit fix) -------------------------------------------------
# Depletion used to be runtime-only: any rebuild of main.tscn (every dungeon
# round trip) regrew the whole world to full -- an unbounded materials farm
# that sidestepped the regrow clocks entirely. A TOUCHED node records itself in
# GameState.harvest_states under its stable id; regrow deadlines live on the
# GAME clock, so time away counts toward the regrow and a node whose hour has
# passed comes back full on the next build.

func _regrow_hours() -> float:
	var secs: float = ROCK_REGROW_SECONDS if node_type == "rock" else REGROW_SECONDS
	return secs * GameState.HOURS_PER_SECOND

func _save_state() -> void:
	if state_id == "":
		return
	GameState.harvest_states[state_id] = {
		"hits": hits_left, "reserve": reserve_left, "depleted": depleted,
		"size_mult": size_mult, "regrow_at": _regrow_at,
	}

func _restore_state() -> void:
	if state_id == "" or not GameState.harvest_states.has(state_id):
		return
	var st: Dictionary = GameState.harvest_states[state_id]
	size_mult = float(st.get("size_mult", size_mult))
	hits_left = int(st.get("hits", hits_left))
	reserve_left = int(st.get("reserve", reserve_left))
	_regrow_at = float(st.get("regrow_at", 0.0))
	if node_type == "tree":
		visual_root.scale = Vector2(size_mult, size_mult)
	if bool(st.get("depleted", false)):
		if GameState.game_hours >= _regrow_at:
			_regrow()   # its hour already passed while we were away
		else:
			depleted = true
			visual_root.modulate.a = 0.12 if node_type == "tree" else 0.0
			# resume the countdown for the REMAINDER, pause-respecting
			var secs: float = (_regrow_at - GameState.game_hours) / GameState.HOURS_PER_SECOND
			get_tree().create_timer(maxf(secs, 0.5), false).timeout.connect(_regrow)
	elif node_type == "rock":
		# a part-worked seam comes back part-shrunk, not full-size
		var frac: float = clampf(float(reserve_left) / float(ROCK_RESERVE), 0.0, 1.0)
		visual_root.scale = Vector2.ONE * lerpf(ROCK_MIN_SCALE, 1.0, frac)

# --- visuals (origin sits on the ground line; everything drawn upward) ---

func build_tree_visual() -> void:
	var trunk = Polygon2D.new()
	var trunk_col = Color(0.42, 0.28, 0.15).lerp(Color(0.5, 0.34, 0.18), randf())
	trunk.polygon = PackedVector2Array([
		Vector2(-7, 0), Vector2(-5, -58), Vector2(5, -58), Vector2(7, 0)])
	trunk.color = trunk_col
	visual_root.add_child(trunk)
	var canopy_col = Color(0.2, 0.5, 0.22).lerp(Color(0.3, 0.62, 0.26), randf())
	for blob in [
		{"c": Vector2(0, -86), "r": 30.0},
		{"c": Vector2(-20, -70), "r": 22.0},
		{"c": Vector2(20, -70), "r": 22.0},
		{"c": Vector2(0, -64), "r": 20.0},
	]:
		var leaf = Polygon2D.new()
		leaf.polygon = _circle(blob.r * randf_range(0.9, 1.1), 12)
		leaf.position = blob.c
		leaf.color = canopy_col.lightened(randf_range(0.0, 0.12))
		visual_root.add_child(leaf)

func build_rock_visual() -> void:
	var body = Polygon2D.new()
	var grey = Color(0.5, 0.5, 0.54).lerp(Color(0.62, 0.62, 0.66), randf())
	body.polygon = PackedVector2Array([
		Vector2(-32, 0), Vector2(-26, -26), Vector2(-8, -40), Vector2(14, -36),
		Vector2(30, -18), Vector2(33, 0)])
	body.color = grey
	visual_root.add_child(body)
	var facet = Polygon2D.new()
	facet.polygon = PackedVector2Array([
		Vector2(-26, -26), Vector2(-8, -40), Vector2(0, -26), Vector2(-14, -18)])
	facet.color = grey.lightened(0.15)
	visual_root.add_child(facet)
	# mineral glints hint that this is an ore rock, not scenery
	for i in range(3):
		var glint = Polygon2D.new()
		glint.polygon = _circle(2.5, 6)
		glint.position = Vector2(randf_range(-18, 18), randf_range(-28, -8))
		glint.color = [Color(0.6, 0.62, 0.68), Color(0.95, 0.45, 0.15), Color(0.85, 0.75, 0.4)][i]
		visual_root.add_child(glint)

func _circle(radius: float, sides: int) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in range(sides):
		var ang = TAU * float(i) / sides
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	return pts

# --- harvesting ---

# Called by the player's melee swing when a gathering tool is wielded.
func take_tool_hit(tool_type: String, player: Node) -> void:
	if depleted:
		return
	var wanted = "axe" if node_type == "tree" else "pickaxe"
	if tool_type != wanted:
		_notify("This %s needs a %s." % [node_type, "Woodsman's Axe" if wanted == "axe" else "Miner's Pickaxe"])
		return
	_shake()
	_spawn_chips()
	# a real HIT sound at last (dev: "no sound effect? for real?"): a dull thock
	# for the axe on wood, a metallic chink for the pick on stone
	GameState.play_sfx(
		GameState.SFX_THUD if node_type == "tree" else GameState.SFX_CHIME,
		1.25 if node_type == "tree" else 0.8, global_position)
	if node_type == "rock":
		_mine_swing(player)
		return
	hits_left -= 1
	if hits_left <= 0:
		_harvest(player)
	else:
		_save_state()

# One pickaxe swing into a seam: it pays immediately, shrinks a little, and
# only vanishes once the whole reserve is worked out.
func _mine_swing(player: Node) -> void:
	reserve_left -= 1
	_drop("stone", 1)                # was 1-2/swing over 80 swings (~110 a rock) -- far too much
	# the deeper minerals the skill tree spends, surfacing as you work
	if randf() < 0.05:
		_drop("iron_shard", 1)
		_notify("A vein of " + Inventory.get_display_name("iron_shard") + "!")
	elif randf() < 0.025:
		_drop("ember_crystal", 1)
		_notify("A vein of " + Inventory.get_display_name("ember_crystal") + "!")
	# a relic is too rare to risk to a despawn timer -- straight to the bag
	if randf() < RELIC_FIND_CHANCE * 0.25 and player.inventory.get_count("relic_mountain") == 0:
		if player.inventory.add_item("relic_mountain", 1) > 0:
			_drop("relic_mountain", 1)   # bag full -- drop it rather than lose it
		_notify("Deep in the stone... the Heart of the Mountain!")
	_apply_reserve_scale()
	if reserve_left <= 0:
		_exhaust_seam()
	else:
		_save_state()

# The visible gauge: a full seam stands tall, a spent one is a stub.
func _apply_reserve_scale() -> void:
	var frac: float = clampf(float(reserve_left) / float(ROCK_RESERVE), 0.0, 1.0)
	var s: float = lerpf(ROCK_MIN_SCALE, 1.0, frac)
	var t := create_tween()
	t.tween_property(visual_root, "scale", Vector2(s, s), 0.12)

func _exhaust_seam() -> void:
	depleted = true
	_regrow_at = GameState.game_hours + _regrow_hours()
	_save_state()
	_notify("The seam is worked out.")
	var fade = create_tween()
	fade.tween_property(visual_root, "modulate:a", 0.0, 0.5)
	# process_always=false: the regrow clock waits with the world when paused
	get_tree().create_timer(ROCK_REGROW_SECONDS, false).timeout.connect(_regrow)

func _shake() -> void:
	if shake_tween:
		shake_tween.kill()
	visual_root.position = Vector2.ZERO
	shake_tween = create_tween()
	shake_tween.tween_property(visual_root, "position:x", 4.0, 0.04)
	shake_tween.tween_property(visual_root, "position:x", -3.0, 0.05)
	shake_tween.tween_property(visual_root, "position:x", 0.0, 0.05)

# Little debris flecks fly off each hit -- green leaves for trees, grey chips
# for rocks.
func _spawn_chips() -> void:
	var col = Color(0.3, 0.55, 0.25) if node_type == "tree" else Color(0.55, 0.55, 0.6)
	for i in range(4):
		var chip = Polygon2D.new()
		chip.polygon = _circle(randf_range(1.6, 3.0), 6)
		chip.color = col
		chip.z_index = 30
		get_parent().add_child(chip)
		chip.global_position = global_position + Vector2(randf_range(-14, 14), randf_range(-70, -20))
		var t = chip.create_tween()
		t.tween_property(chip, "global_position", chip.global_position + Vector2(randf_range(-22, 22), randf_range(14, 34)), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(chip, "modulate:a", 0.0, 0.4)
		t.tween_callback(chip.queue_free)

func _harvest(player: Node) -> void:
	depleted = true
	var got := []
	if node_type == "tree":
		# dev 2026-07-23 "too much wood/herbs": a tree gives a modest 2-3 wood, and
		# resin/herbs are an OCCASIONAL find, not nearly every tree.
		var wood = randi_range(2, 3)
		_drop("wood", wood)
		got.append("%d Wood" % wood)
		if randf() < 0.22:
			_drop("resin", 1)
			got.append("1 Resin")
		if randf() < 0.15:   # wild herbs for cooking (crafting ingredient) -- occasional
			_drop("herb", 1)
			got.append("1 " + Inventory.get_display_name("herb"))
		if randf() < RELIC_FIND_CHANCE and player.inventory.get_count("relic_sylvan") == 0:
			if player.inventory.add_item("relic_sylvan", 1) > 0:
				_drop("relic_sylvan", 1)   # bag full -- drop it rather than lose it
			_notify("Hidden in the roots... the Sylvan Charm!")
	else:
		var stone = randi_range(2, 4)
		_drop("stone", stone)
		got.append("%d Stone" % stone)
		# deeper minerals surface rarely -- the same substances the skill tree
		# spends, so mining feeds progression alongside dungeon drops
		if randf() < 0.20:
			_drop("iron_shard", 1)
			got.append("1 " + Inventory.get_display_name("iron_shard"))
		elif randf() < 0.10:
			_drop("ember_crystal", 1)
			got.append("1 " + Inventory.get_display_name("ember_crystal"))
		if randf() < RELIC_FIND_CHANCE and player.inventory.get_count("relic_mountain") == 0:
			if player.inventory.add_item("relic_mountain", 1) > 0:
				_drop("relic_mountain", 1)   # bag full -- drop it rather than lose it
			_notify("Deep in the stone... the Heart of the Mountain!")
	_notify(("Chopped: " if node_type == "tree" else "Mined: ") + ", ".join(got))
	_regrow_at = GameState.game_hours + _regrow_hours()
	_save_state()
	# wither, wait, regrow in place (pause-respecting, like the seam clock)
	var fade = create_tween()
	fade.tween_property(visual_root, "modulate:a", 0.12, 0.4)
	get_tree().create_timer(REGROW_SECONDS, false).timeout.connect(_regrow)

func _regrow() -> void:
	if not is_instance_valid(self):
		return
	depleted = false
	_regrow_at = 0.0
	hits_left = int(round(HITS_TO_HARVEST * size_mult))
	reserve_left = ROCK_RESERVE
	# a full node needs no record -- drop the entry rather than carry it forever
	if state_id != "":
		GameState.harvest_states.erase(state_id)
	visual_root.scale = Vector2(size_mult, size_mult)   # back to its own size
	var grow = create_tween()
	grow.tween_property(visual_root, "modulate:a", 1.0, 0.6)

func _notify(text: String) -> void:
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack:
		stack.show_notification(text)
