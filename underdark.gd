extends Node2D
# THE UNDERDARK (GAME_BIBLE §4 amendment, dev-decided 2026-07-21).
#
# The surface "DUNGEON door + level scroll" is retired. The only way down is
# THE CAVE: a mouth in the earth where the old sign stood, a long stair that
# slowly sinks east, and under the whole map an open underground world --
# Terraria-built, and Terraria-SIZED (dev: "at least small size of Terraria"):
#
#   ~37,000px wide x ~11,000px deep, EIGHT depth bands of winding tunnel
#   spines with chambers, connected by zigzag climbing shafts. Same map
#   proportions as a Terraria small world (depth:width ~0.28 vs their ~0.29).
#
# The 100 floors stay exactly as built. They are reached through HIDDEN STONE
# DOORS in the underdark's niches: deeper bands hold doors onto higher floors
# (band 1 -> floors 1-19 ... band 8 -> 85-100). A door only opens once its
# floor is unlocked -- the ladder is unchanged, doors are entry shortcuts.
# pre_dungeon_position is set at the door, so leaving a floor puts you back
# at the very door you entered.
#
# Three rules carried from the east road: cave mobs see you late (is_wild),
# they let go at the leash, and they STREAM -- only the sectors around the
# player are ever alive, so the size is free.

const ENEMY_SCENE = preload("res://enemy.tscn")
const HARVEST_NODE_SCRIPT = preload("res://harvest_node.gd")

# --- geometry ---------------------------------------------------------------
const UD_SEED = 0xD33B
# The spine starts EAST of where the entry stair LANDS -- derived, never
# guessed. A hardcoded number here silently drove the descent through band 1's
# slabs the moment the mouth moved, so ud_left is computed from the real stair
# geometry in _ready (see _stair_end_x).
var ud_left := 4600.0
const UD_RIGHT = 36800.0
const UD_TOP = 420.0               # below the surface strip
const BANDS = 8
const BAND_H = 1340.0              # solid rock + tunnel per band
const TUNNEL_H = 250.0             # breathing room of a normal tunnel
const CHAMBER_H = 620.0            # ...and of a chamber
const ARENA_H = 1050.0             # a hall you can fight a crowd in
const CRAWL_H = 130.0              # a squeeze -- no room to swing wide
const TRAP_SCENE = preload("res://trap.tscn")
const CHEST_SCENE = preload("res://chest.tscn")

# What a chest of the deep can hold, by band. Shallow caves pay in supplies and
# materials; the deepest pay in the things you cannot buy.
const LOOT_SHALLOW = ["potion_health", "wood", "stone", "iron_shard", "herb", "resin", "raw_meat"]
const LOOT_MID = ["potion_health", "potion_mana", "iron_shard", "ember_crystal", "food_stew", "coin_gold"]
const LOOT_DEEP = ["potion_mana", "ember_crystal", "void_essence", "ancient_relic", "coin_gold"]
const FLOOR_T = 60.0               # slab thickness
# FLOOR JITTER, AND WHY IT IS SMALL. The player jumps ~92px, so any rise taller
# than that is a wall you cannot climb. At 70 per segment with a +-140 band the
# floor could stack into ledges of 200-290px, and walking the deep meant hitting
# faces you simply could not get over (dev: "alignment of ground underground is
# too bad"). 40 keeps every step comfortably climbable, and _bridge_step lays a
# tread at each change so even those read as stairs rather than kerbs.
const MAX_STEP = 40.0
const FLOOR_BAND = 90.0            # how far a band's floor may wander from its base

# THE FIRES OF THE DEEP. Dev call: "real light like inside dungeons, somewhere
# orange, somewhere green, somewhere blue -- all colours to which fire can
# become". Each is a flame plus a big additive halo, so it genuinely lights the
# rock around it rather than being a coloured dot.
const FIRE_COLORS = [
	Color(1.0, 0.58, 0.18),    # common hearth-orange
	Color(1.0, 0.58, 0.18),
	Color(1.0, 0.74, 0.25),    # gold
	Color(0.35, 1.0, 0.5),     # witchfire green
	Color(0.3, 0.62, 1.0),     # cold blue
	Color(0.75, 0.4, 1.0),     # violet
	Color(0.3, 1.0, 0.92),     # pale teal
]
# The deep was legible only to a raycast: near-black rock behind near-black
# slabs, and you could not tell floor from void. Lifted until the stone reads
# as stone and the fires actually light it.
const ROCK_COLOR = Color(0.085, 0.075, 0.1, 1.0)
const SLAB_COLOR = Color(0.3, 0.26, 0.23, 1.0)
const SLAB_EDGE = Color(0.45, 0.39, 0.31, 1.0)

# --- the cave mouth ---------------------------------------------------------
# A HOLE IN THE GROUND IS A HAZARD TO EVERYTHING THAT STANDS ON IT, so the
# mouth's position is a real constraint, not decoration. It must clear:
#   x=-300  the player's boot position (a hole there drops them on frame 1)
#   x=520   the arrival battle's road
#   x=1500  the fixture ground half the boss suites pin their actors on
#   x=4700  the village's west wall
# 2400 sits in the open stretch between them: you walk past the cave on the
# way in, and can come back to it whenever. Anything that carves ground here
# reads this constant -- never a copy of the number.
const MOUTH_X = 2400.0
const STAIR_STEP_W = 36.0
const STAIR_STEP_DROP = 20.0

# THE CAVE IS A HILLSIDE TUNNEL, NOT A HOLE (dev call 2026-07-21: "raise a
# rocky mound on the surface, with dark arch, you walk in horizontally and you
# go down slowly"). The first build was a gap in the flat ground -- and it
# sealed itself: the stair's top steps sat flush with the surface and 60px
# thick, so they bridged their own hole and the player walked straight over the
# entrance every time. Nothing to fall into now. You walk in at ground level
# through an arch in a rock mound, and the floor falls away beneath you.
const ARCH_RUN = 130.0             # flat corridor inside the arch before the drop
const ARCH_HEAD = 120.0            # headroom in the corridor
const MOUND_LEFT = MOUTH_X - 190.0
const MOUND_CREST = -250.0         # how high the rock rises above the road
const DESCENT_X = MOUTH_X + ARCH_RUN
const CRUST_CARVE = 430.0          # ground removed under the mound, and only there
const MOUND_RIGHT = DESCENT_X + CRUST_CARVE + 40.0
# The tunnel begins well under the 77px-thick crust, so nothing it does can
# open a hole in the road above it.
const TUNNEL_TOP_Y = 210.0

# --- doors ------------------------------------------------------------------
const DOORS_PER_BAND = 7

# --- streaming mobs ---------------------------------------------------------
const SECTOR_W = 1000.0
const ALIVE_RADIUS = 2300.0
const CULL_RADIUS = 3400.0
const RESPAWN_SECONDS = 150.0

var _plan := {}          # band -> Array of {x0, x1, floor_y, ceil_y, kind}
var _shafts := {}        # band -> Array of shaft x centers (to the band below)
var _player: Node2D = null
var _live := {}
var _cleared_at := {}
var _scan_timer := 0.0

func _ready() -> void:
	name = "Underdark"
	_retire_surface_door()
	# NOTE: the crust is NOT carved any more. The whole tunnel lives below it
	# (TUNNEL_TOP_Y), so the road over the cave is as solid as any other stretch
	# and the village stays reachable on foot. Entry is the arch prompt.
	_carve_ground_skin()
	var rng := RandomNumberGenerator.new()
	rng.seed = UD_SEED
	ud_left = _stair_end_x() + 260.0
	_plan_bands(rng)
	# shafts are PLANNED before anything is built: they mark holes on the
	# segments they cross, and _build_bands then builds those slabs as two
	# pieces. Building first and patching after would leave no hole at all.
	_plan_shafts(rng)
	_build_dark_backdrop()
	_build_mouth_and_stair()
	_build_bands(rng)
	_build_shaft_ladders()
	_place_doors(rng)
	_place_seams(rng)
	_place_chests(rng)
	_build_rune_vaults(rng)

func band_floor_y(band: int) -> float:
	return UD_TOP + (band + 1) * BAND_H - 180.0

# How many steps the descent takes, and therefore where it lets out. Both the
# stair builder and ud_left read this, so they can never disagree.
func _stair_steps() -> int:
	return int(ceil((band_floor_y(0) - TUNNEL_TOP_Y) / STAIR_STEP_DROP))

func _stair_end_x() -> float:
	return DESCENT_X + _stair_steps() * STAIR_STEP_W

# The old surface door: sign, prompt, zone -- gone. The cave IS the way in.
func _retire_surface_door() -> void:
	var main := get_parent()
	if main == null:
		return
	var zone := main.get_node_or_null("DungeonZone")
	if zone != null:
		zone.queue_free()

# (There is no _carve_mouth_collision any more. The first cave cut a real hole
# in the road's collision; the current one keeps the crust solid and drops the
# whole tunnel below it, so the road is never broken and the entrance is the
# arch prompt. Removed 2026-07-21 with that rework -- CRUST_CARVE survives only
# because the mound's drawn width still reads from it.)

# THE SKIN WOULD HAVE HIDDEN THE WHOLE WORLD. The surface's earth-tile fill
# draws at z0 from the crust down to y~925 -- everything underdark (rock
# backdrop, stair, braziers) sits below the player at negative z, so the upper
# underground would render as solid tiles with an invisible passage inside.
# Rather than a z-war (the player himself is z0), the skin is CARVED: the deep
# fill stops at y=165 (the crust keeps its texture where the surface camera
# sees it; darkness takes over below), and both skin sprites are split around
# the mouth so the opening is a real hole in the drawn earth too.
func _carve_ground_skin() -> void:
	var main := get_parent()
	var ground := main.get_node_or_null("Ground") if main != null else null
	if ground == null:
		return
	# THE SKIN IS NO LONGER SPLIT. It was cut open over the descent so the tunnel
	# showed through -- but the road there is SOLID (the tunnel runs below the
	# crust now), so the cut read as a hole in the earth you could obviously
	# fall into, and you cannot. The deep fill is still shortened, because the
	# tiles would otherwise be drawn over the top of the underworld.
	for child in ground.get_children():
		if not (child is Sprite2D) or not child.region_enabled:
			continue
		if child.region_rect.size.y > 300.0:
			child.region_rect.size.y = 165.0 - child.position.y

func _plan_bands(rng: RandomNumberGenerator) -> void:
	for b in range(BANDS):
		var segs := []
		var base := band_floor_y(b)
		var floor_y := base
		var x := ud_left
		while x < UD_RIGHT:
			# THE SHAPE OF THE DEEP: mostly tunnel, with chambers to breathe in,
			# rare ARENAS wide and tall enough to fight a crowd, and CRAWLS that
			# squeeze you down to a corridor you cannot swing wide in. Variety
			# is what makes it a place rather than a very long hallway.
			var roll := rng.randf()
			var kind := "tunnel"
			var w := rng.randf_range(700.0, 1400.0)
			if roll < 0.09:
				kind = "arena"
				w = rng.randf_range(1500.0, 2300.0)
			elif roll < 0.28:
				kind = "chamber"
			elif roll < 0.40:
				kind = "crawl"
				w = rng.randf_range(420.0, 780.0)
			floor_y = clampf(floor_y + rng.randf_range(-MAX_STEP, MAX_STEP),
				base - FLOOR_BAND, base + FLOOR_BAND)
			var head: float = TUNNEL_H
			match kind:
				"arena": head = ARENA_H
				"chamber": head = CHAMBER_H
				"crawl": head = CRAWL_H
			segs.append({
				"x0": x, "x1": minf(x + w, UD_RIGHT), "floor_y": floor_y,
				"ceil_y": floor_y - head, "kind": kind,
			})
			x += w
		_plan[b] = segs

func _build_dark_backdrop() -> void:
	var rock := ColorRect.new()
	rock.color = ROCK_COLOR
	rock.z_index = -90
	rock.position = Vector2(MOUTH_X - 600.0, 60.0)
	rock.size = Vector2(UD_RIGHT - rock.position.x + 900.0, UD_TOP + BANDS * BAND_H + 600.0)
	add_child(rock)

func _slab(x: float, y: float, w: float, h: float) -> void:
	var body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	cs.shape = rect
	body.add_child(cs)
	add_child(body)
	body.global_position = Vector2(x + w / 2.0, y + h / 2.0)
	var vis := ColorRect.new()
	vis.color = SLAB_COLOR
	vis.size = Vector2(w, h)
	vis.position = Vector2(-w / 2.0, -h / 2.0)
	vis.z_index = -1        # above the rock dark (-90), below the player (0)
	body.add_child(vis)
	var edge := ColorRect.new()
	edge.color = SLAB_EDGE
	edge.size = Vector2(w, 5.0)
	edge.position = Vector2(-w / 2.0, -h / 2.0)
	edge.z_index = -1
	body.add_child(edge)

# The mouth: a dark opening in the surface, then a stair that SLOWLY goes
# down (dev's words), sinking east ~16px a step until it reaches band 1.
func _build_mouth_and_stair() -> void:
	var floor_y := -39.0        # the road's own surface: you walk IN, not down
	# --- the rock mound, drawn ---------------------------------------------
	var rock := Polygon2D.new()
	rock.color = Color(0.2, 0.185, 0.17)
	rock.polygon = PackedVector2Array([
		Vector2(MOUND_LEFT, floor_y + 6.0),
		Vector2(MOUND_LEFT + 70.0, MOUND_CREST * 0.45),
		Vector2(MOUTH_X - 30.0, MOUND_CREST),
		Vector2(MOUND_RIGHT - 150.0, MOUND_CREST * 0.85),
		Vector2(MOUND_RIGHT, floor_y + 6.0)])
	rock.z_index = -2
	add_child(rock)
	# the arch: a dark bite out of the mound's west face, at walking height
	var arch := Polygon2D.new()
	arch.color = ROCK_COLOR
	var pts := PackedVector2Array()
	pts.append(Vector2(MOUTH_X - 4.0, floor_y + 6.0))
	for i in range(13):        # a rounded head, so it reads as a mouth not a door
		var t := float(i) / 12.0
		pts.append(Vector2(MOUTH_X - 4.0 + t * 96.0,
			floor_y - ARCH_HEAD + 26.0 - sin(t * PI) * 26.0))
	pts.append(Vector2(MOUTH_X + 92.0, floor_y + 6.0))
	arch.polygon = pts
	arch.z_index = -1
	add_child(arch)
	_brazier(Vector2(MOUTH_X - 46.0, floor_y - 4.0))

	# --- the mound is SCENERY, and that is deliberate -----------------------
	# A side-scroller road is one-dimensional: anything solid standing on it is
	# a wall. The first cut of this mound had a rock shoulder either side of the
	# arch, and it walled the road east -- you could not reach the village any
	# more. So the mound never collides. You walk THROUGH the arch (an E prompt,
	# built below), and the road past it stays exactly as open as it always was.
	var lip := Polygon2D.new()
	lip.color = Color(0.145, 0.135, 0.125)
	lip.polygon = PackedVector2Array([
		Vector2(MOUTH_X - 26.0, floor_y + 8.0), Vector2(MOUTH_X - 26.0, floor_y - 14.0),
		Vector2(MOUTH_X + 108.0, floor_y - 14.0), Vector2(MOUTH_X + 108.0, floor_y + 8.0)])
	lip.z_index = 1
	add_child(lip)
	_build_cave_prompt(floor_y)

	# --- the descent, entirely BENEATH the untouched crust ------------------
	var target_y := band_floor_y(0)
	var steps := _stair_steps()
	var x := DESCENT_X
	var y := TUNNEL_TOP_Y
	for i in range(steps):
		_slab(x, y, STAIR_STEP_W + 26.0, FLOOR_T)
		x += STAIR_STEP_W
		y += STAIR_STEP_DROP
		if i % 26 == 0:
			_brazier(Vector2(x, y - 60.0))
	# landing that joins the stair to band 1's spine
	var first_seg: Dictionary = _plan[0][0]
	_slab(x, target_y, maxf(80.0, first_seg.x0 - x + 120.0), FLOOR_T)
	# the tunnel ceiling, all the way from the top -- the descent never touches
	# the crust now, so there is no stretch that must stay open
	x = DESCENT_X
	y = TUNNEL_TOP_Y - TUNNEL_H
	for i in range(steps):
		_slab(x, y, STAIR_STEP_W + 26.0, FLOOR_T)
		x += STAIR_STEP_W
		y += STAIR_STEP_DROP

func _build_bands(rng: RandomNumberGenerator) -> void:
	for b in range(BANDS):
		var segs: Array = _plan[b]
		for i in range(segs.size()):
			var s: Dictionary = segs[i]
			var w: float = s.x1 - s.x0
			# one fire colour per segment, so a stretch of tunnel reads as ITS OWN
			# place rather than a rainbow -- and the deeper bands lean cold
			var fire: Color = FIRE_COLORS[rng.randi_range(0, FIRE_COLORS.size() - 1)]
			_slab_with_hole(s.x0, s.x1, s.floor_y, s.get("floor_hole"))
			_slab_with_hole(s.x0, s.x1, s.ceil_y - FLOOR_T, s.get("ceil_hole"))
			# A TREAD AT EVERY CHANGE OF LEVEL. Two segments at different heights
			# meet as a bare vertical face; halve it with a step and the join
			# reads as stairs and walks like stairs, in both directions.
			if i > 0:
				var prev: Dictionary = segs[i - 1]
				var drop: float = s.floor_y - prev.floor_y
				if absf(drop) > 12.0:
					_slab(s.x0 - 55.0, prev.floor_y + drop * 0.5, 110.0, FLOOR_T)
			# PLATFORMS HERE AND THERE (dev request): something to climb to, and
			# something to fight from, in the plain stretches too -- not only in
			# the chambers and arenas.
			if s.kind == "tunnel" and rng.randf() < 0.45:
				for k in range(rng.randi_range(1, 2)):
					_slab(s.x0 + rng.randf_range(0.2, 0.75) * w,
						s.floor_y - rng.randf_range(80.0, 150.0),
						rng.randf_range(110.0, 190.0), 14.0)
			# a chamber gets furniture: a platform or two, and light
			if s.kind == "chamber":
				for p in range(rng.randi_range(1, 2)):
					_slab(s.x0 + rng.randf_range(0.15, 0.6) * w,
						s.floor_y - rng.randf_range(90.0, 170.0),
						rng.randf_range(120.0, 220.0), 16.0)
				_brazier(Vector2(s.x0 + w * 0.5, s.floor_y - 40.0), fire)
			elif s.kind == "arena":
				# a fighting hall: tiered ledges around the rim so a crowd can
				# come at you from above, and lit at both ends
				for p in range(rng.randi_range(3, 5)):
					_slab(s.x0 + rng.randf_range(0.1, 0.85) * w,
						s.floor_y - rng.randf_range(150.0, 620.0),
						rng.randf_range(160.0, 300.0), 16.0)
				_brazier(Vector2(s.x0 + 90.0, s.floor_y - 40.0), fire)
				_brazier(Vector2(s.x1 - 90.0, s.floor_y - 40.0), fire)
			elif s.kind == "crawl":
				# a squeeze is where a trap actually bites -- nowhere to dodge
				if rng.randf() < 0.75:
					_trap(Vector2(s.x0 + w * rng.randf_range(0.3, 0.7), s.floor_y - 14.0))
			else:
				# EVERY stretch gets a fire. A tunnel with no light was simply a
				# black gap you crossed blind between two lit rooms.
				_brazier(Vector2(s.x0 + w * 0.34, s.floor_y - 34.0), fire)
				if w > 900.0:
					_brazier(Vector2(s.x0 + w * 0.75, s.floor_y - 34.0), fire)
		# Hard walls at the ends of the band, so nothing walks out of the world.
		# EXCEPT band 0's western end -- that is where the entry stair arrives,
		# and walling it meant you walked down from the cave, along the landing,
		# and straight into a dead end a few strides in (dev report: "there's
		# like a wall which does not let me go further").
		var first: Dictionary = segs[0]
		var last: Dictionary = segs[segs.size() - 1]
		if b > 0:
			_slab(first.x0 - 60.0, first.ceil_y - 80.0, 60.0, first.floor_y - first.ceil_y + 160.0)
		_slab(last.x1, last.ceil_y - 80.0, 60.0, last.floor_y - last.ceil_y + 160.0)

# Zigzag climbing shafts between bands: a hole in the upper band's floor, a
# hole in the lower band's ceiling, and platforms every <=75px so the way BACK
# UP respects the 92px jump rule. Planning only marks the holes on the
# segments; _build_bands honours them, _build_shaft_ladders adds the climb.
func _plan_shafts(rng: RandomNumberGenerator) -> void:
	for b in range(BANDS - 1):
		var xs := []
		for k in range(4):
			var sx := lerpf(ud_left + 1200.0, UD_RIGHT - 1200.0, (k + rng.randf_range(0.2, 0.8)) / 4.0)
			var top_seg := _seg_at(b, sx)
			var bot_seg := _seg_at(b + 1, sx)
			if top_seg.is_empty() or bot_seg.is_empty():
				continue
			# never punch a hole nearer than 120px to a segment edge; if the
			# two bands' segments barely overlap here, the clamps can fight --
			# skip rather than mark a hole outside its own slab
			sx = clampf(sx, top_seg.x0 + 210.0, top_seg.x1 - 210.0)
			sx = clampf(sx, bot_seg.x0 + 210.0, bot_seg.x1 - 210.0)
			if sx - 90.0 < maxf(top_seg.x0, bot_seg.x0) + 60.0 \
					or sx + 90.0 > minf(top_seg.x1, bot_seg.x1) - 60.0:
				continue
			top_seg["floor_hole"] = Vector2(sx - 90.0, sx + 90.0)
			bot_seg["ceil_hole"] = Vector2(sx - 90.0, sx + 90.0)
			xs.append(sx)
		_shafts[b] = xs

func _build_shaft_ladders() -> void:
	for b in _shafts.keys():
		for sx in _shafts[b]:
			var top_seg := _seg_at(b, sx)
			var bot_seg := _seg_at(b + 1, sx)
			if top_seg.is_empty() or bot_seg.is_empty():
				continue
			# THE LADDER MUST REACH THE LOWER FLOOR, NOT THE LOWER CEILING. It used
			# to stop at bot_seg.ceil_y+50 -- but the player who drops down a shaft
			# falls all the way to bot_seg.floor_y, and the room below the ceiling
			# (head: 250px in a tunnel, up to ~1050 in an arena) had NO rungs. So the
			# lowest handhold sat 200-1000px overhead -- far past the ~92px jump --
			# and once you went below band 0 you could descend forever but never
			# climb back: a hard softlock in the deep. Rungs now divide the WHOLE
			# floor-to-floor span into even gaps (<=82px, both ends included), so the
			# shaft climbs in both directions no matter the room heights it joins.
			var span: float = bot_seg.floor_y - top_seg.floor_y
			var n: int = maxi(1, int(ceil(span / 82.0)))
			var step: float = span / float(n)
			var side := 1.0
			for i in range(1, n):
				_slab(sx + side * 55.0 - 45.0, bot_seg.floor_y - step * float(i), 90.0, 14.0)
				side = -side
			_brazier(Vector2(sx, top_seg.floor_y + 34.0))

# a slab that may carry one hole: built as two pieces around it
func _slab_with_hole(x0: float, x1: float, y: float, hole) -> void:
	if hole == null:
		_slab(x0, y, x1 - x0, FLOOR_T)
		return
	if hole.x > x0:
		_slab(x0, y, hole.x - x0, FLOOR_T)
	if x1 > hole.y:
		_slab(hole.y, y, x1 - hole.y, FLOOR_T)

func _seg_at(band: int, x: float) -> Dictionary:
	for s in _plan[band]:
		if x >= s.x0 and x <= s.x1:
			return s
	return {}

func _brazier(pos: Vector2, tint: Color = Color(1.0, 0.58, 0.18)) -> void:
	var glow := Sprite2D.new()
	glow.texture = _glow_tex()
	glow.material = _add_mat()
	glow.modulate = Color(tint.r, tint.g, tint.b, 0.9)
	glow.scale = Vector2(5.2, 5.2)
	glow.position = pos + Vector2(0, -14)
	glow.z_index = -1
	add_child(glow)
	var bowl := ColorRect.new()
	bowl.color = Color(0.25, 0.2, 0.16)
	bowl.size = Vector2(18, 8)
	bowl.position = pos + Vector2(-9, -6)
	bowl.z_index = -1
	add_child(bowl)
	var flame := ColorRect.new()
	flame.color = Color(tint.r, tint.g, tint.b, 0.95)
	flame.size = Vector2(8, 14)
	flame.position = pos + Vector2(-4, -18)
	flame.z_index = -1
	add_child(flame)

static var _glow: ImageTexture = null
static func _glow_tex() -> ImageTexture:
	if _glow != null:
		return _glow
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for py in range(64):
		for px in range(64):
			var d := Vector2(px - 32, py - 32).length() / 32.0
			# squared falloff: a bright core that fades wide, so it lights the rock
			# instead of drawing a flat disc
			var f := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(px, py, Color(1, 1, 1, f * f * 0.85))
	_glow = ImageTexture.create_from_image(img)
	return _glow

static func _add_mat() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m

# --- the hidden doors -------------------------------------------------------
func _place_doors(rng: RandomNumberGenerator) -> void:
	for b in range(BANDS):
		var lo := 1 + b * 12
		var hi := mini(100, lo + 18)
		var segs: Array = _plan[b]
		# NEVER on the vault segment. _build_rune_vaults (which runs after this)
		# claims segs[size-2] and bars it behind three runes -- so a door landing
		# there is unreachable until the puzzle is solved, and if that door were
		# the band's guaranteed floor rung, a whole band's dungeon access would
		# sit behind a gate. Worst case: the FRESH-RUN floor-1 door, which would
		# soft-lock the game exactly as the "every band's first door is its
		# floor" rule was written to prevent. Currently the fixed seed dodges it;
		# reserving the segment makes that guarantee independent of the seed.
		var vault_idx: int = segs.size() - 2
		var placed := 0
		var guard := 0
		while placed < DOORS_PER_BAND and guard < 200:
			guard += 1
			var idx := rng.randi_range(0, segs.size() - 1)
			if idx == vault_idx:
				continue
			var s: Dictionary = segs[idx]
			if s.has("door_here"):
				continue
			s["door_here"] = true
			var door := preload("res://underdark_door.gd").new()
			# EVERY BAND'S FIRST DOOR IS ITS FLOOR. Rolling all seven at random
			# once left band 1 with nothing below floor 8 -- and a fresh save
			# has only floor 1 unlocked, so the whole dungeon was UNREACHABLE:
			# no door would open and there is no other way down any more.
			# The band's bottom rung is guaranteed; the rest stay a lottery.
			door.target_level = lo if placed == 0 else rng.randi_range(lo, hi)
			door.position = Vector2(lerpf(s.x0 + 90.0, s.x1 - 90.0, rng.randf()), s.floor_y)
			add_child(door)
			placed += 1

# --- ore seams --------------------------------------------------------------
func _place_seams(rng: RandomNumberGenerator) -> void:
	for b in range(BANDS):
		for s in _plan[b]:
			if rng.randf() > 0.26:
				continue
			var node = HARVEST_NODE_SCRIPT.new()
			node.node_type = "rock"
			node.position = Vector2(lerpf(s.x0 + 60.0, s.x1 - 60.0, rng.randf()), s.floor_y)
			node.z_index = -4
			add_child(node)

# --- streamed cave mobs (the east road's three rules, underground) ----------
func _process(delta: float) -> void:
	_hold_the_dark_lit()
	_tick_cave_mouth()
	_stream_tick(delta)

# THE SUN HAS NO BUSINESS DOWN HERE. A CanvasModulate darkens the whole canvas
# for nightfall, and it was dimming the underworld along with the surface --
# so at 22:00 the caves were near-black no matter how many fires burned in
# them, which is exactly backwards: the deep is lit by ITS OWN light and does
# not care what time it is. Same counter-multiply the moon already uses to
# escape the tint (day_night_cycle.counter_color).
func _hold_the_dark_lit() -> void:
	var cm := get_parent().get_node_or_null("CanvasModulate") if get_parent() != null else null
	if cm == null:
		return
	var c: Color = cm.color
	modulate = Color(1.0 / maxf(c.r, 0.05), 1.0 / maxf(c.g, 0.05), 1.0 / maxf(c.b, 0.05), 1.0)

func _stream_tick(delta: float) -> void:
	_scan_timer -= delta
	if _scan_timer > 0.0:
		return
	_scan_timer = 0.5
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return
	if GameState.in_dungeon or _player.global_position.y < UD_TOP - 120.0:
		return
	_stream(_player.global_position)

func _band_of(y: float) -> int:
	return clampi(int((y - UD_TOP) / BAND_H), 0, BANDS - 1)

func _stream(ppos: Vector2) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	for key in _live.keys():
		var center: Vector2 = _sector_center(key)
		if center.distance_to(ppos) > CULL_RADIUS:
			for e in _live[key]:
				if is_instance_valid(e):
					e.queue_free()
			_live.erase(key)
	for key in _cleared_at.keys():
		if now - float(_cleared_at[key]) > RESPAWN_SECONDS:
			_cleared_at.erase(key)
	var band := _band_of(ppos.y)
	for bb in range(maxi(0, band - 1), mini(BANDS, band + 2)):
		var first := int(floor((ppos.x - ALIVE_RADIUS) / SECTOR_W))
		var last := int(floor((ppos.x + ALIVE_RADIUS) / SECTOR_W))
		for idx in range(first, last + 1):
			var key := "%d:%d" % [bb, idx]
			var cx := idx * SECTOR_W + SECTOR_W * 0.5
			if cx < ud_left + 200.0 or cx > UD_RIGHT - 200.0:
				continue
			if _live.has(key):
				_prune(key, now)
				continue
			if _cleared_at.has(key):
				continue
			_populate(key, bb, cx, ppos)

func _sector_center(key: String) -> Vector2:
	var parts := key.split(":")
	var bb := int(parts[0])
	var idx := int(parts[1])
	return Vector2(idx * SECTOR_W + SECTOR_W * 0.5, band_floor_y(bb) - 60.0)

func _prune(key: String, now: float) -> void:
	var alive := []
	for e in _live[key]:
		if is_instance_valid(e) and not e.is_dead:
			alive.append(e)
	_live[key] = alive
	if alive.is_empty():
		_live.erase(key)
		_cleared_at[key] = now

func _populate(key: String, band: int, cx: float, ppos: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) ^ UD_SEED
	var count := 1 + int(band / 2.0) + (1 if rng.randf() < 0.5 else 0)
	var made := []
	for i in range(count):
		var x := cx + rng.randf_range(-SECTOR_W * 0.4, SECTOR_W * 0.4)
		var seg := _seg_at(band, x)
		if seg.is_empty():
			continue
		var pos := Vector2(x, seg.floor_y - 50.0)
		if pos.distance_to(ppos) < 720.0:
			continue
		var e = ENEMY_SCENE.instantiate()
		e.respawns = false
		e.is_wild = true
		e.wild_home_x = x
		var depth := float(band) / float(BANDS - 1)
		e.wave_hp_multiplier = lerpf(1.2, 5.0, depth) * rng.randf_range(0.9, 1.15)
		e.wave_damage_multiplier = lerpf(1.1, 3.4, depth) * rng.randf_range(0.9, 1.1)
		e.wave_speed_multiplier = lerpf(1.0, 1.35, depth)
		e.apply_block_archetype(mini(int(depth * 9.0), 8))
		e.add_to_group("course_enemy")
		add_child(e)
		e.global_position = pos
		e.detection_range_current = e.DETECTION_RANGE * e.WILD_SIGHT_MULT
		made.append(e)
	if not made.is_empty():
		_live[key] = made

func live_count() -> int:
	var n := 0
	for key in _live.keys():
		for e in _live[key]:
			if is_instance_valid(e) and not e.is_dead:
				n += 1
	return n

# --- traps, chests, and the rune vaults -------------------------------------
func _trap(pos: Vector2) -> void:
	var t = TRAP_SCENE.instantiate()
	add_child(t)
	t.global_position = pos

# Chests of the deep. Contents are rolled ONCE from the band's table and then
# live in GameState.chest_contents under a position-stable id, so a chest you
# emptied stays empty and one you left full is still full when you come back --
# the same promise the cleared floors make.
func _stock_chest(chest: Node, band: int, rng: RandomNumberGenerator) -> void:
	if GameState.chest_contents.has(chest.chest_id):
		return                      # already rolled in an earlier session
	var table: Array = LOOT_SHALLOW
	if band >= 5:
		table = LOOT_DEEP
	elif band >= 2:
		table = LOOT_MID
	for i in range(rng.randi_range(2, 4)):
		var id: String = table[rng.randi_range(0, table.size() - 1)]
		chest.inventory.add_item(id, rng.randi_range(1, 3 if band < 5 else 2))
	GameState.chest_contents[chest.chest_id] = chest.inventory.to_save_data()

func _add_chest(pos: Vector2, band: int, tag: String, rng: RandomNumberGenerator) -> void:
	var c = CHEST_SCENE.instantiate()
	c.chest_id = "ud_%s_%d_%d" % [tag, band, int(pos.x)]
	# parented to MAIN, not to the Underdark: chest.gd opens the shared window
	# through the relative path "../ChestUI", which only resolves for a direct
	# child of the village scene (tool_wiring_audit polices exactly this).
	get_parent().add_child(c)
	c.global_position = pos
	_stock_chest(c, band, rng)

func _place_chests(rng: RandomNumberGenerator) -> void:
	for b in range(BANDS):
		for s in _plan[b]:
			if s.kind != "chamber" and s.kind != "arena":
				continue
			if rng.randf() > 0.55:
				continue
			_add_chest(Vector2(lerpf(s.x0 + 120.0, s.x1 - 120.0, rng.randf()), s.floor_y - 16.0),
				b, "cache", rng)

# THE RUNE VAULTS -- one per band. A barred gate with a real prize behind it,
# and three rune stones scattered along that band's tunnels. Press E on all
# three and the bars fall. It is a reason to sweep a whole band rather than
# beeline for the next shaft.
var _vault_runes := {}      # band -> total lit
var _vault_gates := {}      # band -> Array[StaticBody2D]

func _build_rune_vaults(rng: RandomNumberGenerator) -> void:
	for b in range(BANDS):
		var segs: Array = _plan[b]
		if segs.size() < 8:
			continue
		var vault: Dictionary = segs[segs.size() - 2]
		var gx: float = vault.x1 - 200.0
		# A vault you already unbarred STAYS unbarred (persisted): no gate, and its
		# runes come up already lit. Every RNG draw below still fires either way, so
		# the seed-driven layout of the rest of the deep never shifts.
		var is_open: bool = GameState.underdark_vaults_open.has(b)
		if not is_open:
			# the bars: two slabs the player cannot pass until the runes are lit
			var gate := StaticBody2D.new()
			var gcs := CollisionShape2D.new()
			var grect := RectangleShape2D.new()
			grect.size = Vector2(24.0, 200.0)
			gcs.shape = grect
			gate.add_child(gcs)
			var gvis := ColorRect.new()
			gvis.color = Color(0.36, 0.33, 0.2)
			gvis.size = Vector2(24.0, 200.0)
			gvis.position = Vector2(-12.0, -100.0)
			gvis.z_index = -1
			gate.add_child(gvis)
			add_child(gate)
			gate.global_position = Vector2(gx, vault.floor_y - 100.0)
			_vault_gates[b] = gate
		_vault_runes[b] = 3 if is_open else 0
		# the prize (the chest's own looted-state persists via chest_contents)
		_add_chest(Vector2(gx + 110.0, vault.floor_y - 16.0), b, "vault", rng)
		# three runes, spread across the band's earlier tunnels
		for i in range(3):
			var s: Dictionary = segs[rng.randi_range(1, maxi(1, segs.size() - 4))]
			var rune := preload("res://underdark_rune.gd").new()
			rune.band = b
			rune.host = self
			rune.start_lit = is_open
			add_child(rune)
			rune.global_position = Vector2(lerpf(s.x0 + 90.0, s.x1 - 90.0, rng.randf()),
				s.floor_y - 24.0)

# called by a rune when the player lights it
func rune_lit(band: int) -> void:
	_vault_runes[band] = int(_vault_runes.get(band, 0)) + 1
	var lit: int = _vault_runes[band]
	if lit < 3:
		GameState.notify("A rune warms under your hand — %d of 3." % lit)
		return
	GameState.notify("The bars grind back. Something was kept here.")
	# remember it: the deep rebuilds every reload, and this vault must stay open
	if not GameState.underdark_vaults_open.has(band):
		GameState.underdark_vaults_open.append(band)
	var gate = _vault_gates.get(band)
	if gate != null and is_instance_valid(gate):
		gate.queue_free()

# --- the arch you walk into -------------------------------------------------
# Standing in the mouth and pressing E puts you at the head of the tunnel, and
# the same prompt at the tunnel head brings you back out. A physical opening in
# the road would either block the way east or drop you in every time you walked
# past -- see the note in _build_mouth_and_stair.
var _cave_prompt: Label = null
var _exit_prompt: Label = null
var _at_mouth := false
var _at_head := false

func _build_cave_prompt(floor_y: float) -> void:
	var mouth := Area2D.new()
	mouth.collision_mask = 2
	var mcs := CollisionShape2D.new()
	var mr := RectangleShape2D.new()
	mr.size = Vector2(150.0, 130.0)
	mcs.shape = mr
	mcs.position = Vector2(MOUTH_X + 40.0, floor_y - 55.0)
	mouth.add_child(mcs)
	add_child(mouth)
	mouth.body_entered.connect(func(b):
		if b.is_in_group("player"):
			_at_mouth = true
			_cave_prompt.visible = true)
	mouth.body_exited.connect(func(b):
		if b.is_in_group("player"):
			_at_mouth = false
			_cave_prompt.visible = false)
	_cave_prompt = Label.new()
	_cave_prompt.text = "[E]  Into the cave"
	_cave_prompt.add_theme_font_size_override("font_size", 13)
	_cave_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cave_prompt.position = Vector2(MOUTH_X - 110.0, floor_y - 190.0)
	_cave_prompt.size = Vector2(300.0, 20.0)
	_cave_prompt.visible = false
	_cave_prompt.z_index = 5
	add_child(_cave_prompt)

	var head := Area2D.new()
	head.collision_mask = 2
	var hcs := CollisionShape2D.new()
	var hr := RectangleShape2D.new()
	hr.size = Vector2(150.0, 150.0)
	hcs.shape = hr
	hcs.position = Vector2(DESCENT_X + 40.0, TUNNEL_TOP_Y - 70.0)
	head.add_child(hcs)
	add_child(head)
	head.body_entered.connect(func(b):
		if b.is_in_group("player"):
			_at_head = true
			_exit_prompt.visible = true)
	head.body_exited.connect(func(b):
		if b.is_in_group("player"):
			_at_head = false
			_exit_prompt.visible = false)
	_exit_prompt = Label.new()
	_exit_prompt.text = "[E]  Back out into the daylight"
	_exit_prompt.add_theme_font_size_override("font_size", 13)
	_exit_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_exit_prompt.position = Vector2(DESCENT_X - 110.0, TUNNEL_TOP_Y - 200.0)
	_exit_prompt.size = Vector2(300.0, 20.0)
	_exit_prompt.visible = false
	_exit_prompt.z_index = 5
	add_child(_exit_prompt)

func _tick_cave_mouth() -> void:
	if not (_at_mouth or _at_head):
		return
	if not Input.is_action_just_pressed("interact"):
		return
	var pl = get_tree().get_first_node_in_group("player")
	if pl == null:
		return
	if _at_mouth:
		# NO RUNNING FROM THE HARVEST. The level-select and the stone doors
		# already refuse to descend once the village is turning; the cave mouth
		# is a third way down and must refuse too, or the finale's "there is
		# nothing below anymore -- the fight is HERE" has a back door west of the
		# wall. (Climbing OUT is always allowed -- that is toward the fight.)
		if GameState.harvest_at_home:
			GameState.notify("⛔ The village is TURNING behind you. There is nothing below anymore — the fight is HERE.")
			return
		pl.global_position = Vector2(DESCENT_X + 40.0, TUNNEL_TOP_Y - 60.0)
		_at_mouth = false
		_cave_prompt.visible = false
		GameState.notify("The air turns cold. The floor slopes away east.")
	else:
		pl.global_position = Vector2(MOUTH_X + 30.0, -70.0)
		_at_head = false
		_exit_prompt.visible = false
	pl.velocity = Vector2.ZERO
