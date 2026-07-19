extends Node2D

const GRASS_COLORS = [
	Color(0.32, 0.78, 0.28),
	Color(0.3, 0.72, 0.32),
	Color(0.34, 0.76, 0.26),
	Color(0.28, 0.68, 0.24),
]

const GROUND_SPAN_START = -395.0
const GROUND_SPAN_END = 4470.0
const GROUND_Y = -39.0
const TUFT_COUNT = 32

# The world's real horizontal extent -- the ground skin, and everything the
# background has to cover. Anything that has to reach "the end of the map"
# derives from these two, so the world can be lengthened again without half the
# backdrop being left behind (which is exactly what happened: the ground was
# doubled and the scene-authored sky bands stayed at x=19000, leaving ~19,000px
# of bare viewport grey past the midpoint).
const WORLD_LEFT = -713.0
const WORLD_SPAN = 38713.0
const WORLD_RIGHT = WORLD_LEFT + WORLD_SPAN
const SKY_MARGIN = 400.0   # sky overhangs both ends so the edge is never on screen

const PLATFORM_TUFTS = [
	{"pos": Vector2(1470, -195), "count": 2},
	{"pos": Vector2(1900, -195), "count": 2},
	{"pos": Vector2(2370, -235), "count": 2},
	{"pos": Vector2(2930, -215), "count": 2},
]

# natural jagged mountain silhouettes -- deliberately sparse so they read as
# landmarks rather than a wall-to-wall backdrop. Two big ones sit near player
# spawn (x=-300) with different shapes, two more big ones are scattered
# further along the course, and two SMALL ones (sized like the very first
# version of this system) fill the remaining gaps. Mixed palette: some
# green-tinted, some the original purple-blue "distant range" tone.
const MOUNTAIN_Y = 40.0

# Deep-wood backdrop plate (art/environment/deepwood_backdrop.png, 400x160).
# INTEGER scale only -- 3 keeps every source pixel exactly 3x3 world px, so the
# plate is never stretched or resampled.
#
# Why 3 and not 4: the canopy top lands at MOUNTAIN_Y - 160*S. The sun/moon arc
# between day_night_cycle's SKY_HORIZON_Y (-540) and SKY_PEAK_Y (-760), and they
# draw at z=-50 -- BEHIND this backdrop. At scale 4 the canopy reaches -600,
# above the -540 horizon, so the sun and moon would be swallowed by the trees at
# every sunrise and sunset. Scale 3 tops the canopy out at -440: still well above
# the camera's view at ground level (~-390), so the woods fill the background,
# but always below the arc, so the sun and moon ride clear over the treetops.
const BACKDROP_SCALE = 3
const BACKDROP_MARGIN = 600.0   # tile past both world ends so an edge never shows

# Three plates of the SAME style, cycled so the treeline never visibly repeats.
# They are interchangeable by construction: identical 400x160 size, and
# tool_bg_align has ramped every plate's outer columns to one shared canonical
# trunk column -- so each plate's left edge is pixel-identical to every plate's
# right edge, and any join lands inside a tree trunk. Order and flipping are
# therefore free. Re-run tool_bg_align if a plate is ever re-arted.
const BACKDROP_PLATES = [
	"res://art/environment/deepwood_backdrop_1.png",
	"res://art/environment/deepwood_backdrop_2.png",
	"res://art/environment/deepwood_backdrop_3.png",
]

# Kept for the procedural fallback below (used only when the plate is missing).
const MOUNTAIN_ZONES = [
	{"x": -480.0, "width": 1240.0, "height": 855.0, "peaks": 3, "color": Color(0.36, 0.46, 0.38, 1)},
	{"x": -140.0, "width": 855.0, "height": 560.0, "peaks": 2, "color": Color(0.5, 0.47, 0.63, 1)},
	{"x": 1700.0, "width": 1395.0, "height": 900.0, "peaks": 4, "color": Color(0.44, 0.41, 0.58, 1)},
	{"x": 3250.0, "width": 1080.0, "height": 720.0, "peaks": 3, "color": Color(0.4, 0.5, 0.42, 1)},
	{"x": 800.0, "width": 480.0, "height": 310.0, "peaks": 2, "color": Color(0.48, 0.45, 0.61, 1)},
	{"x": 4000.0, "width": 420.0, "height": 280.0, "peaks": 3, "color": Color(0.38, 0.48, 0.4, 1)},
	{"x": 6200.0, "width": 1450.0, "height": 780.0, "peaks": 4, "color": Color(0.42, 0.44, 0.56, 1)},
]

const CLOUD_COUNT = 110
const CLOUD_SPAN_START = -900.0
const CLOUD_SPAN_END = WORLD_RIGHT + 500.0
const CLOUD_Y_MIN = -720.0
const CLOUD_Y_MAX = -470.0
const CLOUD_MIN_SCALE = 0.6
const CLOUD_MAX_SCALE = 2.4
const CLOUD_MIN_SPEED = 3.0
const CLOUD_MAX_SPEED = 10.0
const CLOUD_COLOR = Color(0.97, 0.97, 1.0, 1.0)
const CLOUD_Z_INDEX = -25

const MUSIC_LOOP_SAMPLES = 441000

const TRAP_SCENE = preload("res://trap.tscn")
const TRAP_COUNT = 25
const TRAP_SPAN_START = -670.0
const TRAP_SPAN_END = 4470.0
const TRAP_Y = -39.0
const TRAP_JITTER_FRACTION = 0.3
const TRAP_SAFE_ZONE_MIN = -365.0
const TRAP_SAFE_ZONE_MAX = -85.0
const TRAP_PLATFORM_EDGE_MARGIN = 28.0

const TRAP_PLATFORM_ZONES = [
	{"x_min": 48.0, "x_max": 248.0, "y": -128.0, "count": 1},
	{"x_min": 287.0, "x_max": 887.0, "y": -207.0, "count": 1},
	{"x_min": 1016.5, "x_max": 1305.0, "y": -160.5, "count": 1},
	{"x_min": 539.0, "x_max": 637.0, "y": -350.5, "count": 1},
	{"x_min": 1395.0, "x_max": 1545.0, "y": -195.0, "count": 1},
	{"x_min": 1610.0, "x_max": 1750.0, "y": -275.0, "count": 1},
	{"x_min": 1820.0, "x_max": 1980.0, "y": -195.0, "count": 1},
	{"x_min": 2055.0, "x_max": 2185.0, "y": -345.0, "count": 1},
	{"x_min": 2295.0, "x_max": 2445.0, "y": -235.0, "count": 1},
	{"x_min": 2580.0, "x_max": 2720.0, "y": -375.0, "count": 1},
	{"x_min": 2850.0, "x_max": 3010.0, "y": -215.0, "count": 1},
	{"x_min": 3145.0, "x_max": 3295.0, "y": -305.0, "count": 1},
]

# The village sits past the end of the combat course -- 12 buildings
# covering the roles named in the game's vision doc, spaced out along a
# widened stretch of ground. Most start unstaffed (see building.gd); Farm
# reflects Elin's rescue automatically since her role matches "Farm".
const VILLAGE_START_X = 4900.0   # LEFT edge of the first building
const VILLAGE_GAP = 360.0        # roomy gap: holds the extended work-yards even with buildings fully upgraded
# (retired 2026-07-16) Back when every building was a procedural box this
# stretched them 35% wide for a townier look. The painted facades have their own
# proportions, and stretching them to a made-up footprint is exactly what made
# the Fishing Dock read 72% too wide. Each building's `width` below is now
# derived FROM its art (content aspect x height), so the facade is drawn at the
# proportions it was painted at. Keep it that way: if you re-art a building, run
# tool_art_audit.gd and re-derive its width.
const VILLAGE_WIDTH_BOOST = 1.0
# Mirrors building.gd (1 + (MAX_LEVEL-1) * WIDTH_PER_LEVEL) = 1 + 5*0.08. Each
# building's slot reserves its FULLY-UPGRADED width so upgrades never overlap.
const MAX_UPGRADE_FACTOR = 1.4
const VILLAGE_Y = -39.0
const BUILDING_SCRIPT = preload("res://building.gd")
const FARM_PEN_SCRIPT = preload("res://farm_pen.gd")
const FARM_PEN_WIDTH = 420.0     # fenced pasture placed right after the Farm
const DOCK_BRIDGE_SCRIPT = preload("res://dock_bridge.gd")
const STANDING_TORCH_SCRIPT = preload("res://standing_torch.gd")
# Each building carries a "scale" -- its base size is multiplied by it so the
# village reads big on a full-screen display. Grandest civic buildings are
# largest; utility buildings x2. Buildings are then placed edge-to-edge (see
# generate_village) so no two overlap regardless of their scaled widths.
# `width` is DERIVED from each facade's art: (content width / content height
# above its ground-sink) x height. Height stays the dev-tuned dial; width just
# follows so the painting is never stretched. See tool_art_audit.gd.
const VILLAGE_BUILDINGS = [
	{"name": "Government", "role_key": "Government", "width": 135.0, "height": 100.0, "scale": 3.0, "color": Color(0.55, 0.48, 0.38, 1)},
	{"name": "School", "role_key": "School", "width": 91.0, "height": 80.0, "scale": 3.2, "color": Color(0.45, 0.55, 0.65, 1)},
	{"name": "Farm", "role_key": "Farm", "width": 133.0, "height": 75.0, "scale": 2.8, "color": Color(0.5, 0.6, 0.3, 1)},
	{"name": "Hospital", "role_key": "Hospital", "width": 97.0, "height": 85.0, "scale": 2.5, "color": Color(0.75, 0.72, 0.7, 1)},
	{"name": "Barracks", "role_key": "Barracks", "width": 96.0, "height": 80.0, "scale": 2.5, "color": Color(0.4, 0.35, 0.32, 1)},
	{"name": "Fishing Dock", "role_key": "Fishing Dock", "width": 94.0, "height": 70.0, "scale": 2.6, "color": Color(0.35, 0.5, 0.55, 1)},
	{"name": "Science Lab", "role_key": "Science Lab", "width": 106.0, "height": 85.0, "scale": 2.0, "color": Color(0.4, 0.45, 0.6, 1)},
	{"name": "Bank", "role_key": "Bank", "width": 114.0, "height": 90.0, "scale": 2.0, "color": Color(0.6, 0.55, 0.35, 1)},
	{"name": "Blacksmith", "role_key": "Blacksmith", "width": 104.0, "height": 75.0, "scale": 2.0, "color": Color(0.45, 0.4, 0.4, 1)},
	{"name": "Tavern", "role_key": "Tavern", "width": 90.0, "height": 80.0, "scale": 2.0, "color": Color(0.55, 0.35, 0.25, 1)},
	{"name": "Bar", "role_key": "Bar", "width": 130.0, "height": 78.0, "scale": 2.2, "color": Color(0.3, 0.24, 0.22, 1)},
	{"name": "Marketplace", "role_key": "Marketplace", "width": 145.0, "height": 65.0, "scale": 2.5, "color": Color(0.6, 0.5, 0.35, 1)},
	{"name": "Builderhouse", "role_key": "Builderhouse", "width": 142.0, "height": 90.0, "scale": 2.5, "color": Color(0.42, 0.38, 0.3, 1)},
]
# Right edge of the last building, set by generate_village -- the houses start
# past it so the enlarged village never overruns the cottages.
var village_right_edge := VILLAGE_START_X

# Mating houses sit just past the 12 role buildings -- smaller cottages,
# deliberately distinct in shape/palette from the institutional buildings
# above. See house.gd for the pairing/child mechanic.
const HOUSE_MARGIN = 240.0   # gap from the last building to the first cottage
const HOUSE_SPACING = 160.0
const HOUSE_SCRIPT = preload("res://house.gd")
const HOUSE_COLORS = [
	{"body": Color(0.62, 0.48, 0.32, 1), "roof": Color(0.48, 0.24, 0.18, 1)},
	{"body": Color(0.55, 0.42, 0.5, 1), "roof": Color(0.4, 0.22, 0.32, 1)},
	{"body": Color(0.42, 0.5, 0.42, 1), "roof": Color(0.28, 0.36, 0.24, 1)},
	{"body": Color(0.58, 0.5, 0.35, 1), "roof": Color(0.42, 0.3, 0.16, 1)},
	{"body": Color(0.48, 0.45, 0.55, 1), "roof": Color(0.32, 0.28, 0.4, 1)},
]
const HOUSE_COUNT = 5

# Harvestable trees (axe) and mineral rocks (pickaxe) -- see harvest_node.gd.
# Spread along the combat course, plus a grove/outcrop in the gap between the
# course's end and the village gate (ground is guaranteed there).
const HARVEST_NODE_SCRIPT = preload("res://harvest_node.gd")
const TREE_COUNT = 12
const ROCK_COUNT = 9
const HARVEST_SPAN_START = -350.0
const HARVEST_SPAN_END = 4300.0
const GROVE_START_X = 4420.0

const NPC_SCRIPT = preload("res://npc.gd")
# Fallback avatar spot for a villager with no role_key assigned yet -- near
# the village entrance rather than glued to any one building.
const VILLAGE_FALLBACK_POS = Vector2(4900.0, -100.0)

var music: AudioStreamWAV = preload("res://audio/ambient_music.wav")

func _ready() -> void:
	generate_mountains()
	generate_grass()
	generate_traps()
	generate_platform_traps()
	generate_clouds()
	fit_sky_to_world()
	build_ground_skin()
	generate_village()
	generate_houses()
	generate_harvestables()
	spawn_placed_torches()
	start_music()
	if GameState.pending_load:
		apply_save_data()
	spawn_existing_villager_avatars()
	spawn_adventurers()
	announce_orin_arrival()
	build_escape_ward()
	warn_wounded_corps()
	if GameState.returning_from_dungeon:
		GameState.returning_from_dungeon = false
		# only restore a real recorded spot -- the default (0,0) is below the
		# ground line and would spawn the player embedded in the floor. If it was
		# never set, keep the scene's own on-ground spawn instead.
		if GameState.pre_dungeon_position != Vector2.ZERO:
			$Player.global_position = GameState.pre_dungeon_position
	show_away_report()

# Summarises any sieges that resolved off-screen while the player was in a
# dungeon (see GameState.resolve_siege_offline) and clears the tally.
func show_away_report() -> void:
	var report = GameState.consume_away_report()
	if report.sieges <= 0:
		return
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if not stack:
		return
	stack.show_notification("While you were away: %d siege%s -- %d repelled." % [report.sieges, "" if report.sieges == 1 else "s", report.repelled])
	if report.villagers_lost > 0:
		stack.show_notification("The raids claimed %d villager%s!" % [report.villagers_lost, "" if report.villagers_lost == 1 else "s"])
	if int(report.get("adventurers_lost", 0)) > 0:
		stack.show_notification("%d adventurer%s died holding the line. They will not return." % [report.adventurers_lost, "" if int(report.adventurers_lost) == 1 else "s"])

func generate_village() -> void:
	# Place buildings left-to-right. Each reserves its FULLY-UPGRADED width plus a
	# gap so even maxed-out buildings never overlap. The building is centred in
	# its reserved slot (it starts at level-1 width and grows toward the edges).
	var cursor = VILLAGE_START_X
	for i in range(VILLAGE_BUILDINGS.size()):
		var def = VILLAGE_BUILDINGS[i]
		var sc = float(def.get("scale", 2.0))
		# dev call: the whole village reads better 30% bigger
		var w = def.width * sc * VILLAGE_WIDTH_BOOST * 1.3
		var h = def.height * sc * 1.3
		# Every building (Marketplace included) reserves its FULLY-UPGRADED width;
		# the Fishing Dock reserves its full water span (wider than any upgrade).
		var reserve = w * MAX_UPGRADE_FACTOR
		if def.name == "Fishing Dock":
			# reserve the water at its MAX-upgraded sideways spread
			var water_max = 1.0 + (BUILDING_SCRIPT.MAX_LEVEL - 1) * BUILDING_SCRIPT.DOCK_WATER_PER_LEVEL
			reserve = max(reserve, w * 2.0 * BUILDING_SCRIPT.DOCK_WATER_HALF * water_max)
		var building = BUILDING_SCRIPT.new()
		building.building_name = def.name
		building.role_key = def.role_key
		building.width = w
		building.height = h
		building.body_color = def.color
		building.position = Vector2(cursor + reserve / 2.0, VILLAGE_Y)
		$Village.add_child(building)
		# walkable stairs->bridge->stairs crossing over the dock's water
		if def.name == "Fishing Dock":
			var bridge = DOCK_BRIDGE_SCRIPT.new()
			bridge.span = reserve + 110.0   # stairs land on dry ground each side
			bridge.position = Vector2(cursor + reserve / 2.0, VILLAGE_Y)
			$Village.add_child(bridge)
		cursor += reserve + VILLAGE_GAP
		# the Farm gets a fenced pasture with animals right beside it
		if def.name == "Farm":
			var pen = FARM_PEN_SCRIPT.new()
			pen.pen_width = FARM_PEN_WIDTH
			pen.position = Vector2(cursor + FARM_PEN_WIDTH / 2.0, VILLAGE_Y)
			$Village.add_child(pen)
			cursor += FARM_PEN_WIDTH + VILLAGE_GAP
	village_right_edge = cursor

# Re-plant every standing torch the player has placed (G key) -- they persist
# in GameState.placed_torches across dungeon trips and save/load.
func spawn_placed_torches() -> void:
	for e in GameState.placed_torches:
		var t = STANDING_TORCH_SCRIPT.new()
		t.position = Vector2(float(e.get("x", 0.0)), float(e.get("y", 0.0)))
		add_child(t)

func generate_houses() -> void:
	# Cottages sit just past the (now larger) village, computed from where the
	# buildings actually ended so they never overlap.
	var start_x = village_right_edge + HOUSE_MARGIN
	for i in range(HOUSE_COUNT):
		var palette = HOUSE_COLORS[i % HOUSE_COLORS.size()]
		var house = HOUSE_SCRIPT.new()
		house.house_id = "house_%d" % i
		house.house_name = "Cottage %d" % (i + 1)
		house.body_color = palette.body
		house.roof_color = palette.roof
		house.position = Vector2(start_x + i * HOUSE_SPACING, VILLAGE_Y)
		$Village.add_child(house)

# NPC world avatars are runtime-only nodes -- nothing about them is written
# to the save file, so a fresh scene boot (New Game OR Continue) starts with
# zero of them in the tree. This reconstructs one for every entry already in
# GameState.rescued_villagers (a no-op on New Game, where that list is empty)
# so nobody who was previously rescued/born silently vanishes from the
# village after a save/reload. Anyone currently mid-mating-cycle (still in
# a cottage, or gestating) is skipped -- they don't have a wandering avatar
# during that time even in a live, non-reloaded session (see house.gd).
func spawn_existing_villager_avatars() -> void:
	for villager in GameState.rescued_villagers:
		var villager_id = villager.get("id", "")
		if is_villager_busy_mating(villager_id):
			continue
		var npc = NPC_SCRIPT.new()
		npc.villager_id = villager_id
		npc.global_position = find_avatar_spawn_position(villager.get("role_key", ""))
		$Village.add_child(npc)

# Triage warning: adventurer wounds persist between sieges and their deaths are
# permanent, so a player coming home should hear at once if the corps is in
# danger -- housing a wounded defender is the whole point of the house station.
func warn_wounded_corps() -> void:
	GameState.ensure_adventurers()
	var wounded := 0
	for id in GameState.adventurers.keys():
		var a: Dictionary = GameState.adventurers[id]
		if not a["rescued"] or a["dead"] or a["station"] == "house":
			continue
		var max_hp := maxf(1.0, float(Adventurers.get_def(id).get("hp", 100.0)))
		if float(a.get("hp", max_hp)) < max_hp * 0.5:
			wounded += 1
	if wounded > 0:
		var stack = get_tree().get_first_node_in_group("notification_stack")
		if stack:
			stack.show_notification("⚠ %d adventurer%s badly wounded and still on duty — house them before the next siege, or lose them for good." % [wounded, " is" if wounded == 1 else "s are"])

# GAME_BIBLE 2.4.1 beat 3 -- THE FAILED ESCAPE. The way out of Deepwood is not
# blocked; it is BAITED: the Despair Army swells to meet anyone who tries.
# Walking off the west edge triggers the lesson as gameplay: the horde rises,
# you are mauled to the brink and thrown back. The first attempt is the story
# beat (near-death + the line); every later attempt costs the same -- the edge
# stays a soft wall the fiction owns, until the game is won.
func build_escape_ward() -> void:
	if GameState.game_completed:
		return              # the root is dead; the roads are roads again
	var ward := Area2D.new()
	ward.collision_layer = 0
	ward.collision_mask = 2
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(60, 600)
	cs.shape = rect
	ward.add_child(cs)
	ward.position = Vector2(GROUND_SPAN_START + 20.0, GROUND_Y - 200.0)
	add_child(ward)
	ward.body_entered.connect(func(b):
		if not b.is_in_group("player") or b.god_mode:
			return
		# the horde swells: mauled to the brink, hurled back east
		b.health = maxi(1, int(b.get_max_health() * 0.2))
		if b.has_method("update_health_display"):
			b.update_health_display()
		b.global_position.x = GROUND_SPAN_START + 260.0
		b.velocity = Vector2(420.0, -160.0)
		if b.has_method("apply_knockback"):
			b.apply_knockback(1, 120.0)
		var stack = get_tree().get_first_node_in_group("notification_stack")
		if stack:
			stack.show_notification("The road out DROWNS in the horde — it swells to meet you. You barely crawl back.")
		if not GameState.seen_failed_escape:
			GameState.seen_failed_escape = true
			DialogueBox.play(self, Story.FAILED_ESCAPE))

# GAME_BIBLE 2.5.1 beat 2: the first village visit after carving to floor 15,
# Orin stands at the wall as though returning from a long walk -- the wandering
# mage of the Doctor's rumour, back from the dungeon that "kept him stuck".
# (Every word a lie shaped to mirror the player's own arrival.)
func announce_orin_arrival() -> void:
	if not GameState.orin_arrived() or GameState.seen_orin_arrival or GameState.dev_mode:
		return
	GameState.seen_orin_arrival = true
	# the full introductions-and-pact scene (2.5.1 beat 3): the Doctor presents
	# him, the three defenders size him up, everyone commits to the same plan --
	# and Orin plants the game's central lie in plain sight.
	DialogueBox.play(self, Story.ORIN_PACT, func():
		var stack = get_tree().get_first_node_in_group("notification_stack")
		if stack:
			stack.show_notification("★ Orin holds the nightly watch from now on."))

# The living adventurers (GAME_BIBLE 2.4.1): every rescued one that hasn't
# fallen walks the village at its chosen station. The dead are simply absent --
# permadeath means no node to spawn.
const ADVENTURER_SCRIPT = preload("res://adventurer.gd")
func spawn_adventurers() -> void:
	GameState.ensure_adventurers()
	var i := 0
	for id in GameState.adventurers.keys():
		var a: Dictionary = GameState.adventurers[id]
		if not a["rescued"] or a["dead"]:
			continue
		var adv = ADVENTURER_SCRIPT.new()
		adv.adventurer_id = id
		adv.global_position = Vector2(1900.0 + i * 90.0, GROUND_Y - 30.0)
		$Village.add_child(adv)
		i += 1

func is_villager_busy_mating(villager_id: String) -> bool:
	for pairing in GameState.mating_houses.values():
		if pairing.male_id == villager_id or pairing.female_id == villager_id:
			return true
	for pairing in GameState.pregnancies.values():
		if pairing.male_id == villager_id or pairing.female_id == villager_id:
			return true
	return false

func find_avatar_spawn_position(role_key: String) -> Vector2:
	if role_key != "":
		for child in $Village.get_children():
			if child.has_method("get_roles") and child.role_key == role_key:
				return child.global_position + Vector2(randf_range(-18.0, 18.0), -60.0)
	return VILLAGE_FALLBACK_POS

func _process(delta: float) -> void:
	for cloud in $Clouds.get_children():
		cloud.position.x += cloud.get_meta("speed") * delta
		if cloud.position.x > CLOUD_SPAN_END:
			cloud.position.x = CLOUD_SPAN_START

func start_music() -> void:
	music.loop_mode = AudioStreamWAV.LOOP_FORWARD
	music.loop_begin = 0
	music.loop_end = MUSIC_LOOP_SAMPLES
	$MusicPlayer.stream = music
	$MusicPlayer.bus = "Music"   # so the Music volume slider controls it
	$MusicPlayer.play()

func apply_save_data() -> void:
	var data = GameState.load_game()
	if data.is_empty():
		return
	var player = $Player
	var saved_inventory = data.get("inventory", null)
	if saved_inventory is Array:
		player.inventory.from_save_data(saved_inventory)
	else:
		# older save from before the inventory system existed -- fall back
		# to the flat currency int it stored.
		player.currency = data.get("currency", player.currency)
	player.global_position = Vector2(data.get("position_x", player.global_position.x), data.get("position_y", player.global_position.y))
	player.has_dash = data.get("has_dash", player.has_dash)
	player.has_double_jump = data.get("has_double_jump", player.has_double_jump)
	player.health = data.get("health", player.health)
	player.mana = float(data.get("mana", player.mana))
	# weapons live in the inventory now (restored above); re-wield the one that
	# was in hand.
	var eq = str(data.get("active_weapon_id", "wpn_sword"))
	if not player.wield_weapon(eq):
		player.wield_weapon("wpn_sword")
	# the load above replaced the whole inventory, wiping anything player._ready
	# granted -- re-apply the guaranteed test items now that the save is in.
	if player.has_method("ensure_test_items"):
		player.ensure_test_items()
	player.update_currency_display()
	player.update_health_display()

func generate_harvestables() -> void:
	# trees spread along the whole combat course...
	var spacing = (HARVEST_SPAN_END - HARVEST_SPAN_START) / float(TREE_COUNT)
	for i in range(TREE_COUNT):
		var x = HARVEST_SPAN_START + (i + 0.5) * spacing + randf_range(-spacing * 0.3, spacing * 0.3)
		spawn_harvest_node("tree", x)
	# ...with rocks interleaved between them on their own rhythm
	var rock_spacing = (HARVEST_SPAN_END - HARVEST_SPAN_START) / float(ROCK_COUNT)
	for i in range(ROCK_COUNT):
		var x = HARVEST_SPAN_START + (i + 0.15) * rock_spacing + randf_range(-rock_spacing * 0.25, rock_spacing * 0.25)
		spawn_harvest_node("rock", x)
	# a small grove and outcrop just before the village gate
	for i in range(3):
		spawn_harvest_node("tree", GROVE_START_X + i * 120.0 + randf_range(-25.0, 25.0))
	for i in range(2):
		spawn_harvest_node("rock", GROVE_START_X + 60.0 + i * 200.0 + randf_range(-25.0, 25.0))

func spawn_harvest_node(kind: String, x: float) -> void:
	var node = HARVEST_NODE_SCRIPT.new()
	node.node_type = kind
	node.position = Vector2(x, GROUND_Y)
	node.z_index = -4   # behind the player and combat, in front of the mountains
	$Decorations.add_child(node)

func generate_grass() -> void:
	var spacing = (GROUND_SPAN_END - GROUND_SPAN_START) / float(TUFT_COUNT)
	for i in range(TUFT_COUNT):
		var x = GROUND_SPAN_START + i * spacing + randf_range(-spacing * 0.35, spacing * 0.35)
		spawn_tuft(Vector2(x, GROUND_Y))

	for group in PLATFORM_TUFTS:
		for i in range(group.count):
			var offset_x = randf_range(-35.0, 35.0)
			spawn_tuft(group.pos + Vector2(offset_x, 0))

func generate_traps() -> void:
	var spacing = (TRAP_SPAN_END - TRAP_SPAN_START) / float(TRAP_COUNT)
	for i in range(TRAP_COUNT):
		var x = TRAP_SPAN_START + i * spacing + randf_range(-spacing * TRAP_JITTER_FRACTION, spacing * TRAP_JITTER_FRACTION)
		if x > TRAP_SAFE_ZONE_MIN and x < TRAP_SAFE_ZONE_MAX:
			x = TRAP_SAFE_ZONE_MIN if (x - TRAP_SAFE_ZONE_MIN) < (TRAP_SAFE_ZONE_MAX - x) else TRAP_SAFE_ZONE_MAX
		place_trap(x, TRAP_Y)

func generate_platform_traps() -> void:
	for zone in TRAP_PLATFORM_ZONES:
		var usable_min = zone.x_min + TRAP_PLATFORM_EDGE_MARGIN
		var usable_max = zone.x_max - TRAP_PLATFORM_EDGE_MARGIN
		if usable_max <= usable_min:
			usable_min = zone.x_min
			usable_max = zone.x_max
		var count = zone.count
		if count == 1:
			var x = (usable_min + usable_max) / 2.0 + randf_range(-10.0, 10.0)
			place_trap(x, zone.y)
		else:
			var segment = (usable_max - usable_min) / float(count)
			for i in range(count):
				var seg_start = usable_min + i * segment
				var x = seg_start + segment * 0.5 + randf_range(-segment * 0.2, segment * 0.2)
				place_trap(x, zone.y)

func place_trap(x: float, y: float) -> void:
	var trap = TRAP_SCENE.instantiate()
	trap.position = Vector2(x, y)
	$Traps.add_child(trap)

func generate_mountains() -> void:
	# The deep-wood backdrop: one painted plate tiled edge-to-edge behind the
	# whole village, with the dead-forest treeline in front of it. The procedural
	# polygon ridges stay as the fallback.
	#
	# Two rules this obeys that the old ridge code did not:
	#  1. UNIFORM INTEGER scale. The ridges were scaled per zone by
	#     (zone.width/art.x, zone.height/art.y) -- a non-uniform stretch that
	#     squashed the same art differently in every zone. The plate is drawn at
	#     BACKDROP_SCALE on both axes, so its pixels stay square everywhere.
	#  2. MIRROR tiling. Every other tile is flipped, so a tile's right edge is
	#     always its neighbour's mirrored right edge -- the columns match and the
	#     seam disappears, without needing a seamless plate.
	#
	# Height is deliberate -- see BACKDROP_SCALE: the canopy tops out at -440, low
	# enough that the sun/moon arc (-540 to -760) always rides clear above it.
	if ResourceLoader.exists(BACKDROP_PLATES[0]):
		var texs: Array[Texture2D] = []
		for path in BACKDROP_PLATES:
			if ResourceLoader.exists(path):
				texs.append(load(path))
		# Every plate must be identical in size or the tops/bases would step and
		# the tile widths would drift. Cut by tool_bg_cut, proven by tool_bg_align.
		var ps: Vector2 = texs[0].get_size()
		for t2 in texs:
			assert(t2.get_size() == ps, "backdrop plates must all be the same size")
		var tw: float = ps.x * BACKDROP_SCALE
		var th: float = ps.y * BACKDROP_SCALE
		var bx := WORLD_LEFT - BACKDROP_MARGIN
		var i := 0
		while bx < WORLD_RIGHT + BACKDROP_MARGIN:
			var bs := Sprite2D.new()
			# Cycle plate, and flip the whole cycle every second pass: the run is
			# 1,2,3,1',2',3' -- a 6-tile period, and never the same plate twice in
			# a row, so no mirrored butterfly ever forms.
			bs.texture = texs[i % texs.size()]
			bs.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			bs.centered = false
			# Full rect, deliberately NOT get_used_rect(): trimming is per-image and
			# would give the plates different widths, drifting the tiling apart.
			bs.region_enabled = true
			bs.region_rect = Rect2(Vector2.ZERO, ps)
			bs.scale = Vector2(BACKDROP_SCALE, BACKDROP_SCALE)
			bs.flip_h = (i / texs.size()) % 2 == 1
			bs.position = Vector2(bx, MOUNTAIN_Y - th)
			$Background/Mountains.add_child(bs)
			bx += tw
			i += 1
		# the dead forest line in front of the ridges: overlapping, randomly
		# flipped copies so no repeating seam ever shows
		if ResourceLoader.exists("res://art/environment/treeline.png"):
			var ttex: Texture2D = load("res://art/environment/treeline.png")
			var timg: Image = ttex.get_image()
			if timg.is_compressed():
				timg.decompress()
			var tused := Rect2(timg.get_used_rect())
			var x := -900.0
			var k := 0
			while x < WORLD_RIGHT + 500.0:
				var t := Sprite2D.new()
				t.texture = ttex
				t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				t.centered = false
				t.region_enabled = true
				t.region_rect = tused
				var tsc := randf_range(0.95, 1.3)
				t.scale = Vector2(tsc, tsc)
				t.flip_h = k % 2 == 1
				t.position = Vector2(x, MOUNTAIN_Y - tused.size.y * tsc + 4.0)
				$Background/Mountains.add_child(t)
				x += tused.size.x * tsc * randf_range(0.72, 0.88)
				k += 1
		return
	for zone in MOUNTAIN_ZONES:
		var mountain = Polygon2D.new()
		mountain.position = Vector2(zone.x, MOUNTAIN_Y)
		mountain.color = zone.color
		mountain.polygon = generate_mountain_shape(zone.width, zone.height, zone.peaks)
		$Background/Mountains.add_child(mountain)

# The sky bands are authored in main.tscn, and were authored back when the world
# ended at x=19000. When the map was extended they stayed put, so the entire
# right half of Deepwood had no sky behind it at all -- just the viewport's grey
# clear colour. Stretch them across the real world span at load, so lengthening
# the map can never strand the sky again.
func fit_sky_to_world() -> void:
	var bg := get_node_or_null("Background")
	if bg == null:
		return
	for band in bg.get_children():
		if band is ColorRect and band.name.begins_with("SkyBand"):
			band.offset_left = WORLD_LEFT - SKY_MARGIN
			band.offset_right = WORLD_RIGHT + SKY_MARGIN

# Re-dresses the flat green ground strip in the PixelLab tiles: a mossy-grass
# surface row across the whole span with the stony-earth fill beneath it.
func build_ground_skin() -> void:
	if not ResourceLoader.exists("res://art/environment/ground_tiles.png"):
		return
	var sheet: Texture2D = load("res://art/environment/ground_tiles.png")
	var img: Image = sheet.get_image()
	if img.is_compressed():
		img.decompress()
	var mk_tile = func(x: int, y: int) -> ImageTexture:
		var t := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		t.blit_rect(img, Rect2i(x, y, 32, 32), Vector2i.ZERO)
		return ImageTexture.create_from_image(t)
	var surf: ImageTexture = mk_tile.call(96, 0)    # grass-capped surface tile
	var fill: ImageTexture = mk_tile.call(64, 32)   # solid earth fill tile
	var span := WORLD_SPAN
	var rect: ColorRect = $Ground.get_node_or_null("ColorRect")
	if rect:
		rect.visible = false
	# The surface tile is a WANG tile: its grass sits partway down the cell with
	# transparent padding above it. Laying the cell's top edge on GROUND_Y put
	# the visible green that far BELOW the line every building stands on -- so
	# the entire village hung in the air by exactly that padding. Hoist the strip
	# by the measured padding so the GRASS lands on GROUND_Y, and start the earth
	# where the surface strip actually ends.
	var pad := _tile_top_padding(img, 96, 0)
	var surf_top := GROUND_Y - float(pad)
	var s1 := Sprite2D.new()
	s1.texture = surf
	s1.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s1.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s1.centered = false
	s1.region_enabled = true
	s1.region_rect = Rect2(0, 0, span, 32)
	s1.position = Vector2(WORLD_LEFT, surf_top)
	$Ground.add_child(s1)
	var fill_top := surf_top + 32.0
	var s2 := Sprite2D.new()
	s2.texture = fill
	s2.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s2.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s2.centered = false
	s2.region_enabled = true
	s2.region_rect = Rect2(0, 0, span, maxf(46.0, 39.0 - fill_top))
	s2.position = Vector2(WORLD_LEFT, fill_top)
	$Ground.add_child(s2)

# Rows of transparent padding above a tile's first opaque pixel. Measured rather
# than hardcoded so re-arting the tileset can't silently float the village again.
func _tile_top_padding(img: Image, ox: int, oy: int) -> int:
	for y in range(32):
		for x in range(32):
			if img.get_pixel(ox + x, oy + y).a > 0.5:
				return y
	return 0

# a jagged ridge instead of a flat triangle or pure per-point noise: a few
# distinct "peaks" at random positions/heights shape the overall silhouette
# (so it reads as real summits, not random zigzag), a sine envelope tapers
# the whole thing to ground level at both edges, and fine jitter on top adds
# rocky texture without breaking the coherent shape.
func generate_mountain_shape(width: float, height: float, peak_count: int) -> PackedVector2Array:
	var points = PackedVector2Array()
	points.append(Vector2(-width / 2.0, 0.0))
	var segments = max(peak_count * 6, 18)
	var peak_positions = []
	var peak_heights = []
	for p in range(peak_count):
		peak_positions.append(randf_range(0.15, 0.85))
		peak_heights.append(randf_range(0.65, 1.0))
	for i in range(1, segments):
		var t = float(i) / float(segments)
		var x = -width / 2.0 + t * width
		var peak_influence = 0.0
		for p in range(peak_count):
			var dist = absf(t - peak_positions[p])
			var influence = max(0.0, 1.0 - dist * 2.2)
			peak_influence = max(peak_influence, influence * peak_heights[p])
		var envelope = sin(t * PI)
		var fine_jitter = 1.0 + randf_range(-0.08, 0.08)
		var y = -height * envelope * (0.5 + 0.5 * peak_influence) * fine_jitter
		points.append(Vector2(x, y))
	points.append(Vector2(width / 2.0, 0.0))
	return points

func generate_clouds() -> void:
	var painted := ResourceLoader.exists("res://art/environment/cloud.png")
	var ctex: Texture2D = load("res://art/environment/cloud.png") if painted else null
	for i in range(CLOUD_COUNT):
		var x = randf_range(CLOUD_SPAN_START, CLOUD_SPAN_END)
		var y = randf_range(CLOUD_Y_MIN, CLOUD_Y_MAX)
		if painted:
			var spr := Sprite2D.new()
			spr.texture = ctex
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			spr.position = Vector2(x, y)
			spr.z_index = CLOUD_Z_INDEX
			var s = randf_range(CLOUD_MIN_SCALE, CLOUD_MAX_SCALE)
			spr.scale = Vector2(s, s)
			spr.flip_h = randf() < 0.5
			spr.modulate = Color(1, 1, 1, randf_range(0.5, 0.85))
			spr.set_meta("speed", randf_range(CLOUD_MIN_SPEED, CLOUD_MAX_SPEED))
			$Clouds.add_child(spr)
			continue
		var cloud = Polygon2D.new()
		cloud.position = Vector2(x, y)
		cloud.z_index = CLOUD_Z_INDEX
		var scale_factor = randf_range(CLOUD_MIN_SCALE, CLOUD_MAX_SCALE)
		cloud.polygon = generate_cloud_shape(scale_factor)
		var alpha = randf_range(0.65, 0.95)
		cloud.color = Color(CLOUD_COLOR.r, CLOUD_COLOR.g, CLOUD_COLOR.b, alpha)
		cloud.set_meta("speed", randf_range(CLOUD_MIN_SPEED, CLOUD_MAX_SPEED))
		$Clouds.add_child(cloud)

func generate_cloud_shape(scale_factor: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	var segments = randi_range(8, 14)
	var width = randf_range(30.0, 70.0) * scale_factor
	var height = width * randf_range(0.35, 0.6)
	var bumpiness = randf_range(0.15, 0.35)
	for i in range(segments):
		var angle = i * TAU / float(segments)
		var variance = 1.0 + randf_range(-bumpiness, bumpiness)
		var x = cos(angle) * width * variance
		var y = sin(angle) * height * variance
		points.append(Vector2(x, y))
	return points

func spawn_tuft(pos: Vector2) -> void:
	var tuft = Polygon2D.new()
	tuft.position = pos
	tuft.color = GRASS_COLORS[randi() % GRASS_COLORS.size()]
	var h = randf_range(9.0, 15.0)
	var w = randf_range(5.0, 8.0)
	tuft.polygon = PackedVector2Array([
		Vector2(-w, 0), Vector2(-w * 0.65, -h * 0.65), Vector2(-w * 0.3, -h * 0.3),
		Vector2(0, -h), Vector2(w * 0.3, -h * 0.3), Vector2(w * 0.65, -h * 0.65), Vector2(w, 0)
	])
	$Decorations.add_child(tuft)
