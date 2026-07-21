extends Node
# THE EAST ROAD (2026-07-21, dev request).
#
# Nothing lived in the overworld: enemy.tscn was only ever used by the dungeon,
# by boss summons, by sieges and by the Harvest. Walk east out of the village
# and the map was 30,000px of empty scenery.
#
# Now the road is populated, and it gets worse the further you go: more of them
# per stretch, and each one tougher. Three rules keep it fair rather than a
# wall, and they are the whole design:
#
#   1. WILD MOBS SEE YOU LATE. 40% of normal sight (dev: "60% lower"). You spot
#      them before they spot you, so a fight out here is usually your choice.
#   2. THEY DON'T FOLLOW FAR. Each one belongs to the ground it spawned on and
#      breaks off at WILD_LEASH, so running away actually works and you never
#      drag a tail of thirty mobs home. (enemy.gd, is_wild.)
#   3. THEY STREAM. The world is far too long to populate at once -- 33,000px
#      at full density would be thousands of CharacterBody2Ds and a dead frame
#      rate. Only the sectors near the player are ever alive; the rest is
#      bookkeeping. Nothing is spawned inside the player's view either, so mobs
#      are never seen popping into existence.

const ENEMY_SCENE = preload("res://enemy.tscn")

# WHERE THE WILDS BEGIN -- measured from the village's EAST rampart, never
# guessed. This was a hardcoded 5200, and the village actually runs from its
# west wall at 4700 to its east wall at 22693 (buildings 5269..18483), so the
# whole town sat inside the wilderness and mobs streamed in among the houses
# (dev report 2026-07-21: "too many mobs inside the village... it should start
# after end of the village, right side wall"). Beyond the east gate the road
# belongs to whatever lives out there, and it worsens from that line onward.
const WILD_FALLBACK_START = 23200.0
const WILD_MARGIN = 500.0          # a breath of clear road outside the gate
var wild_start := WILD_FALLBACK_START

func _resolve_wild_start() -> void:
	var east_x := -1.0
	for w in get_tree().get_nodes_in_group("village_wall"):
		if "flank" in w and w.flank == "east":
			east_x = w.global_position.x
			break
	if east_x < 0.0:
		# no east rampart in this layout: fall back to the far side of the
		# furthest building rather than a magic number
		for b in get_tree().get_nodes_in_group("building"):
			east_x = maxf(east_x, b.global_position.x)
	wild_start = (east_x + WILD_MARGIN) if east_x > 0.0 else WILD_FALLBACK_START

# Sector bookkeeping. One sector is a stretch of road with its own population.
const SECTOR_W = 900.0
const ALIVE_RADIUS = 2400.0        # sectors this close to the player are populated
const CULL_RADIUS = 3600.0         # ...and are put away again past this
const RESPAWN_SECONDS = 120.0      # a cleared stretch stays clear for a while

# Difficulty curve, measured from wild_start out to the world's end.
const MIN_PER_SECTOR = 1
const MAX_PER_SECTOR = 7
const MAX_HP_MULT = 4.2
const MAX_DMG_MULT = 3.0
const MAX_SPEED_MULT = 1.35
# Which of enemy.gd's authored rosters the road draws from. Walking east walks
# you up the same creature ladder the dungeon uses, so the land visibly turns
# on you: orcs near the fields, worse things at the edge of the map.
const MAX_ROSTER_BLOCK = 8

var world_right := 38000.0
var _player: Node2D = null
var _live := {}            # sector index -> Array[Node]
var _cleared_at := {}      # sector index -> time it was emptied
var _scan_timer := 0.0

func _ready() -> void:
	name = "Wilderness"
	var main := get_parent()
	if main != null and "WORLD_RIGHT" in main:
		world_right = float(main.WORLD_RIGHT)
	_resolve_wild_start()

func _process(delta: float) -> void:
	_scan_timer -= delta
	if _scan_timer > 0.0:
		return
	_scan_timer = 0.5          # streaming is cheap, but it doesn't need 60Hz
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return
	if GameState.in_dungeon:
		return
	_stream(_player.global_position.x)

# --- the streaming window ---------------------------------------------------
func _stream(px: float) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	# put away anything far behind us, and forget sectors we emptied long ago
	for idx in _live.keys():
		if absf(_sector_center(idx) - px) > CULL_RADIUS:
			for e in _live[idx]:
				if is_instance_valid(e):
					e.queue_free()
			_live.erase(idx)
	for idx in _cleared_at.keys():
		if now - float(_cleared_at[idx]) > RESPAWN_SECONDS:
			_cleared_at.erase(idx)

	var first := int(floor((px - ALIVE_RADIUS) / SECTOR_W))
	var last := int(floor((px + ALIVE_RADIUS) / SECTOR_W))
	for idx in range(first, last + 1):
		var center := _sector_center(idx)
		if center < wild_start or center > world_right - 400.0:
			continue
		if _live.has(idx):
			_prune(idx, now)
			continue
		if _cleared_at.has(idx):
			continue
		_populate(idx, center, px)

func _sector_center(idx: int) -> float:
	return idx * SECTOR_W + SECTOR_W * 0.5

# 0 at the edge of the wilds, 1 at the world's end.
func depth_at(x: float) -> float:
	var span: float = maxf(1.0, world_right - wild_start)
	return clampf((x - wild_start) / span, 0.0, 1.0)

func _prune(idx: int, now: float) -> void:
	var alive := []
	for e in _live[idx]:
		if is_instance_valid(e) and not e.is_dead:
			alive.append(e)
	_live[idx] = alive
	if alive.is_empty():
		_live.erase(idx)
		_cleared_at[idx] = now     # you cleared this stretch; it stays clear a while

func _populate(idx: int, center: float, px: float) -> void:
	var depth := depth_at(center)
	var count: int = int(round(lerpf(float(MIN_PER_SECTOR), float(MAX_PER_SECTOR), depth)))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(idx) ^ 0x5EED       # a sector's make-up is stable per index
	var made := []
	for i in range(count):
		var x := center + rng.randf_range(-SECTOR_W * 0.45, SECTOR_W * 0.45)
		# never let one appear inside the player's own screen
		if absf(x - px) < 760.0:
			continue
		var e := _make_mob(x, depth, rng)
		if e != null:
			made.append(e)
	if not made.is_empty():
		_live[idx] = made

func _make_mob(x: float, depth: float, rng: RandomNumberGenerator) -> Node:
	var main := get_parent()
	if main == null:
		return null
	var e = ENEMY_SCENE.instantiate()
	e.respawns = false                  # the SECTOR respawns, not the individual
	e.is_wild = true
	e.wild_home_x = x
	e.wave_hp_multiplier = lerpf(1.0, MAX_HP_MULT, depth) * rng.randf_range(0.9, 1.15)
	e.wave_damage_multiplier = lerpf(1.0, MAX_DMG_MULT, depth) * rng.randf_range(0.9, 1.1)
	e.wave_speed_multiplier = lerpf(1.0, MAX_SPEED_MULT, depth)
	# Give it a real creature, the way the dungeon does -- without this a wild
	# mob is an untextured red block while every dungeon mob is a painted
	# monster. Must run BEFORE add_child (it feeds _ready's build_character),
	# and it MULTIPLIES the scaling above rather than replacing it.
	e.apply_block_archetype(mini(int(depth * (MAX_ROSTER_BLOCK + 1)), MAX_ROSTER_BLOCK))
	# course_enemy is THE overworld hostile group: it is what the player's sword
	# arc and arrows scan (player.HOSTILE_GROUPS) and what defenders look for.
	# Without it a wild mob could hurt you and you could not hurt it back --
	# invisible to every weapon in the game.
	e.add_to_group("course_enemy")
	main.add_child(e)
	e.global_position = Vector2(x, -140.0)
	# short sight is the point of the whole system -- see the header. Set AFTER
	# _ready(), which is where the enemy seeds detection_range_current itself.
	e.detection_range_current = e.DETECTION_RANGE * e.WILD_SIGHT_MULT
	return e

# --- for tests and the audit kit --------------------------------------------
# Deliberately NOT an add_to_group("wild_mob"): the only consumer would have
# been this file and a test, and tool_wiring_audit rightly calls that dead
# bookkeeping. A mob's wildness already lives on the mob (enemy.is_wild).
func live_count() -> int:
	var n := 0
	for idx in _live.keys():
		for e in _live[idx]:
			if is_instance_valid(e) and not e.is_dead:
				n += 1
	return n

func any_live_mob() -> Node:
	for idx in _live.keys():
		for e in _live[idx]:
			if is_instance_valid(e) and not e.is_dead:
				return e
	return null
