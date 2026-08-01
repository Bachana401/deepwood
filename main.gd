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
# How far the earth is drawn below the surface. Must exceed half a viewport
# (324 at the 1152x648 base) or the player sees under the world.
const UNDERGROUND_DEPTH = 900.0
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
# The ridges are BACKDROP and must say so. They had no z at all, so they sat at
# z0 like the terrain and the player -- and swallowed anything drawn behind
# them, including the cave mound, which was simply invisible against the hills.
const MOUNTAIN_Z = -60

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

const TRAP_SCENE = preload("res://trap.tscn")
const TRAP_COUNT = 12   # dev call 2026-07-21: mines HALVED world-wide (was 25)
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
const SPECIAL_PLOT_SCRIPT = preload("res://special_plot.gd")
const VILLAGE_PRESENCE_SCRIPT = preload("res://village_presence.gd")
const SYNERGY_LANTERNS_SCRIPT = preload("res://synergy_lanterns.gd")
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
	# roster 14-15 (5.2, decided 2026-07-20 delegated): the Mine feeds the war
	# machine its metal; the Shrine gives corruption its only mercy
	{"name": "Mine", "role_key": "Mine", "width": 120.0, "height": 70.0, "scale": 2.4, "color": Color(0.36, 0.34, 0.38, 1)},
	{"name": "Shrine", "role_key": "Shrine", "width": 95.0, "height": 92.0, "scale": 2.2, "color": Color(0.72, 0.7, 0.6, 1)},
]
# The fallen city starts with only these few landmark ruins standing; every other
# building site is open ground until the player raises it from the B menu (dev
# 2026-07-23). All 15 are still fully buildable -- see build_menu (lists the whole
# roster) + create_building (raises one with no pre-placed ruin).
const ICONIC_STARTER_RUINS := ["Government", "Bank", "Barracks", "Marketplace"]

# Every roster building name, for the build menu (so a site with no ruin still lists).
func building_names() -> Array:
	var out := []
	for def in VILLAGE_BUILDINGS:
		out.append(str(def.name))
	return out

# Right edge of the last building, set by generate_village -- the houses start
# past it so the enlarged village never overruns the cottages.
var village_right_edge := VILLAGE_START_X

# Mating houses sit just past the 12 role buildings -- smaller cottages,
# deliberately distinct in shape/palette from the institutional buildings
# above. See house.gd for the pairing/child mechanic.
const HOUSE_MARGIN = 240.0   # gap from the last building to the first cottage
const HOUSE_SPACING = 160.0
const HOUSE_SCRIPT = preload("res://house.gd")
const SIEGE_ENEMY_FOR_ARRIVAL = preload("res://siege_enemy.tscn")
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
const UNDERDARK_SCRIPT = preload("res://underdark.gd")
const TREE_COUNT = 12
const ROCK_COUNT = 9
const HARVEST_SPAN_START = -350.0
const HARVEST_SPAN_END = 4300.0
const GROVE_START_X = 4420.0

const NPC_SCRIPT = preload("res://npc.gd")
# Fallback avatar spot for a villager with no role_key assigned yet -- near
# the village entrance rather than glued to any one building.
const VILLAGE_FALLBACK_POS = Vector2(4900.0, -100.0)

var music: AudioStreamOggVorbis = preload("res://audio/ground_theme.ogg")
# THE HEALTHY VILLAGE THEME (dev-supplied "Theme for a Triangle", 2026-07-27).
# The surface has TWO voices now: the plain ground theme while Deepwood is still
# a wound, and this one once the town is genuinely well. It is the ear's version
# of the same thing the flower boxes and lanterns say -- you fixed this place.
var healthy_music: AudioStreamMP3 = preload("res://audio/healthy_village_theme.mp3")
# 5/10 on the player-facing meter (village_morale is 0-100). OFF sits lower than
# ON so a village hovering exactly at the line doesn't flip tracks every second.
const HEALTHY_MORALE_ON := 50
const HEALTHY_MORALE_OFF := 44
const MUSIC_FADE := 1.2                # seconds of cross-fade either way
var _music_healthy := false
var _music_check_cd := 0.0
var _music_fade_tween: Tween = null
var _music_base_db := 0.0              # the scene-authored MusicPlayer volume

func _ready() -> void:
	# LOAD FIRST, BUILD SECOND. On a fresh process launch, Continue swaps to this
	# scene with pending_load hot and GameState still at its defaults -- every
	# generator below (village, houses, torches, walls, the Underdark's chests
	# and vaults) reads GameState, so applying the save AFTER them rebuilt the
	# world from empty state: player-built halls vanished, razed ruins returned,
	# emptied chests re-stocked. The save must be in memory before the first
	# generator runs.
	# ONE-SHOT: consume the flag immediately. It was only ever cleared on the New
	# Game path, so on a Continue/NG+ it stayed hot and EVERY return from a dungeon
	# (which reloads main.tscn) re-applied the STALE on-disk save over the live run
	# -- wiping dungeon loot/gold/XP since the last autosave and rewinding the clock.
	# Clearing it here loads the save exactly once; dungeon returns keep carry-over.
	if GameState.pending_load:
		GameState.pending_load = false
		apply_save_data()
		# children _ready before this ran, so the day/night cycle seeded itself
		# from the PRE-load clock -- re-seed it now that the real hours are in
		var dn = get_tree().get_first_node_in_group("day_night")
		if dn != null and dn.has_method("sync_from_master"):
			dn.sync_from_master()
	# the village diary rides along in every scene (5.9, press L)
	add_child(preload("res://village_log_ui.gd").new())
	# F8 field journal: bug notes with context attached (marathon playtest)
	add_child(preload("res://playtest_journal.gd").new())
	# the arrival storm: a new run opens at night, in the rain (start-scene fix)
	if not GameState.seen_arrival_battle and not GameState.dev_mode:
		add_child(preload("res://arrival_weather.gd").new())
	# the Wanderer's Post counter (5.6a) -- village only, where the stall is
	add_child(preload("res://wanderer_ui.gd").new())
	# the east road: streamed wild mobs, thicker and meaner the further you go
	add_child(preload("res://wilderness.gd").new())
	# the Builder's Ledger (B): every site, its state, and its purpose once known
	add_child(preload("res://build_menu.gd").new())
	generate_mountains()
	generate_grass()
	generate_traps()
	generate_platform_traps()
	generate_clouds()
	fit_sky_to_world()
	build_ground_skin()
	build_platform_skins()
	fence_the_camera()
	# THE UNDERDARK (§4): the cave is now the only way down -- it retires the
	# old surface door, carves the mouth, and builds the deep world. Mounted
	# AFTER build_ground_skin on purpose: it carves those very sprites, and
	# mounting it earlier once left the mouth sealed under an uncarved skin.
	add_child(UNDERDARK_SCRIPT.new())
	generate_village()
	generate_houses()
	# A newborn's avatar is normally spawned by the Hospital's child_produced hook, but the
	# Hospital is optional -- listen here too so a child born with no Hospital still gets a
	# walking avatar (the handler no-ops when a Hospital exists, so the two never double up).
	if not GameState.child_produced.is_connected(_on_village_child_born):
		GameState.child_produced.connect(_on_village_child_born)
	generate_harvestables()
	spawn_placed_torches()
	start_music()
	# a coronation interrupted by a quit finishes here, at home -- and it must
	# settle BEFORE the avatar pass below: settle_shadow_court() appends the
	# whole harvested roster back into rescued_villagers, so running it after
	# spawn_existing_villager_avatars left the raised Shadow Army bodiless (in
	# the roster, wages and all, but not one of them walking the streets) until
	# the next village reload.
	GameState.settle_shadow_court()
	spawn_existing_villager_avatars()
	spawn_adventurers()
	# THE ARRIVAL IS STAGED FROM THE FIRST FRAME (dev 2026-07-22): the trio and
	# their raiders are already trading blows at the road when the player walks up,
	# so nothing pops in out of nowhere. The approach only starts the banter and
	# turns the shadow-fight real. No-op once it's been seen / in dev / a dungeon.
	stage_arrival_battle()
	announce_orin_arrival()
	build_escape_ward()
	# (the standalone shop + its stall were removed on dev request 2026-07-22 --
	# the village starts bare; trade will come back through a built Marketplace.)
	# THE WAYSTONE (fast-travel hub, dev 2026-07-21). Once its blueprint wakes at
	# floor 20 it stands at the village threshold -- press E to leap to any Deep
	# Shrine you have woken in the dungeon, so re-descending never wastes time.
	if GameState.waystone_unlocked:
		var way = preload("res://shrine_node.gd").new()
		way.is_waystone = true
		add_child(way)
		way.global_position = Vector2(VILLAGE_START_X - 170.0, VILLAGE_Y)
		GameState.waystone_home_pos = way.global_position
	# a quiet objective ticker at the top of the screen -- a new player never has
	# to guess the next step (it reads GameState.next_objective live)
	add_child(preload("res://objective_banner.gd").new())
	# the interactive tutorial card -- walks the first three builds by DOING them
	add_child(preload("res://tutorial_overlay.gd").new())
	warn_wounded_corps()
	orin_midgame_taunt()
	# (settle_shadow_court moved up: it must run before the avatar spawn pass)
	stamp_rewound_arrival()
	# THE NEW FINALE: if the deep stood silent and everyone is home, the
	# false victory is waiting to be spoken -- and Orin is waiting for it
	call_deferred("_maybe_begin_feast")
	# coming home is the other milestone worth banking (autosave); deferred
	# AND queued AFTER the feast check on purpose (audit fix): deferred calls
	# run FIFO and _maybe_begin_feast is what restores pre_dungeon_position --
	# queued the other way round, every homecoming banked the pit-road spawn
	# instead of where the player actually stands
	call_deferred("_autosave_on_arrival")

func _maybe_begin_feast() -> void:
	if GameState.feast_ready():
		add_child(preload("res://harvest_director.gd").new())
	elif GameState.harvest_done and not GameState.despair_dead \
			and GameState.harvested_villagers.size() > 0 \
			and not GameState.harvest_at_home and not GameState.dev_mode:
		# a quit (or crash) mid-Harvest must never strand a half-turned world
		var d = preload("res://harvest_director.gd").new()
		d.resume = true
		add_child(d)
	# the book notices the moment all seven lines hold at once
	GameState.chronicle_check_complete()
	if GameState.returning_from_dungeon:
		GameState.returning_from_dungeon = false
		# only restore a real recorded spot -- the default (0,0) is below the
		# ground line and would spawn the player embedded in the floor. If it was
		# never set, keep the scene's own on-ground spawn instead. And NEVER a
		# below-surface point (same net as apply_save_data): a floor entered via a
		# tile-underground door records that door's deep coordinate, which in THIS
		# scene is empty sky / dead Underdark strip -- an unrecoverable fall. The
		# village surface never sits below y=-50.
		if GameState.pre_dungeon_position != Vector2.ZERO:
			$Player.global_position = GameState.pre_dungeon_position
			if $Player.global_position.y > -50.0:
				$Player.global_position = GameState.VILLAGE_SPAWN
	show_away_report()

# Summarises any sieges that resolved off-screen while the player was in a
# dungeon (see GameState.resolve_siege_offline) and clears the tally.
func show_away_report() -> void:
	# guard BEFORE consuming the report: this runs on the return-to-village flow, which can
	# fire as the scene is torn down (get_tree() null). Don't eat the report if we can't show
	# it -- leave it to be reported once we're properly in the tree.
	if not is_inside_tree():
		return
	var report = GameState.consume_away_report()
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if not stack:
		return
	# THE HOMECOMING (the fog's other half): the village lived without you
	# and you saw NONE of it. Say how much happened and point at the diary
	# -- otherwise a returning player never thinks to press L. (With
	# Telepathy nothing accumulates: you watched it all as it happened.)
	if GameState.log_unread > 0:
		# more than a bare count (dev ask 2026-07-22): name the freshest thing that
		# happened, so the homecoming actually tells you something before you press L
		var latest := ""
		if not GameState.village_log.is_empty():
			latest = str(GameState.village_log[0].get("text", ""))
		var msg := "📖 While you were away, %d thing%s happened in Deepwood." % [
			GameState.log_unread, "" if GameState.log_unread == 1 else "s"]
		if latest != "":
			msg += "  Latest: %s" % latest
		msg += "  (Press L for the full diary.)"
		stack.show_notification(msg)
		GameState.log_unread = 0
	if report.sieges <= 0:
		return
	stack.show_notification("While you were away: %d siege%s -- %d repelled." % [report.sieges, "" if report.sieges == 1 else "s", report.repelled])
	if report.villagers_lost > 0:
		stack.show_notification("The raids claimed %d villager%s!" % [report.villagers_lost, "" if report.villagers_lost == 1 else "s"])
	# Maera's mercy was tallied but never TOLD -- the one boon moment the player
	# would most want to hear about on homecoming (dev sweep 2026-07-23)
	if int(report.get("stabilized", 0)) > 0:
		stack.show_notification("✨ Maera pulled %d villager%s back from the brink — they live." % [
			int(report.get("stabilized", 0)), "" if int(report.get("stabilized", 0)) == 1 else "s"])
	if int(report.get("adventurers_lost", 0)) > 0:
		var names: Array = report.get("fallen_names", [])
		if names.is_empty():
			stack.show_notification("%d adventurer%s died holding the line. They will not return." % [report.adventurers_lost, "" if int(report.adventurers_lost) == 1 else "s"])
		else:
			stack.show_notification("%s died holding the line. %s will not return." % [
				", ".join(names), "They" if names.size() > 1 else str(names[0]).split(" ")[0]])

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
		# a building the player razed for good (build menu) leaves empty ground --
		# skip it but still advance the cursor so the others keep their spots
		if GameState.building_removed(def.name):
			cursor += reserve + VILLAGE_GAP
			continue
		# A FEW ICONIC RUINS ONLY (dev 2026-07-23): the fallen city shows a handful of
		# landmark ruins; every other site starts as OPEN GROUND you raise from the B
		# menu. A building the player has already placed always returns to its spot.
		# dev_mode keeps ALL 15 standing (the sandbox test-populates workers into every
		# building, so they must all exist).
		if not GameState.dev_mode and not (def.name in ICONIC_STARTER_RUINS) \
				and not GameState.building_positions.has(def.name):
			cursor += reserve + VILLAGE_GAP
			continue
		var building = BUILDING_SCRIPT.new()
		building.building_name = def.name
		building.role_key = def.role_key
		building.width = w
		building.height = h
		building.body_color = def.color
		building.position = Vector2(cursor + reserve / 2.0, VILLAGE_Y)
		# MOVABLE BUILDINGS (5.2): a player-chosen spot outlives the layout
		if GameState.building_positions.has(def.name):
			building.position.x = float(GameState.building_positions[def.name])
		$Village.add_child(building)
		# ATTACHMENTS FOLLOW THE BUILDING, not the layout cursor (audit fix): a
		# relocated Dock used to leave its ~1100px collision deck rebuilding on
		# the empty default slot every load, and a moved Farm's pasture (with
		# its animals) materialised hundreds of pixels from the farmhouse.
		# walkable stairs->bridge->stairs crossing over the dock's water
		if def.name == "Fishing Dock":
			var bridge = DOCK_BRIDGE_SCRIPT.new()
			bridge.span = reserve + 110.0   # stairs land on dry ground each side
			bridge.position = Vector2(building.position.x, VILLAGE_Y)
			$Village.add_child(bridge)
		cursor += reserve + VILLAGE_GAP
		# the Farm gets a fenced pasture with animals right beside it
		if def.name == "Farm":
			var pen = FARM_PEN_SCRIPT.new()
			pen.pen_width = FARM_PEN_WIDTH
			pen.position = Vector2(building.position.x + reserve / 2.0 + VILLAGE_GAP + FARM_PEN_WIDTH / 2.0, VILLAGE_Y)
			$Village.add_child(pen)
			cursor += FARM_PEN_WIDTH + VILLAGE_GAP
	village_right_edge = cursor
	spawn_special_plots()
	spawn_presence_layer()
	# the row is settled -- cache the layout (neighbours, quarters, plots). Deferred
	# so every body is really in the tree before we read the group.
	GameState.refresh_layout.call_deferred()

# THE GROUND ITSELF (roadmap Phase 3): seven patches that suit one building each.
# Drawn where they are so the player can SEE them and plan around them -- a plot
# you cannot see is a guessing game, not a decision.
# THE INVISIBLE MADE VISIBLE (dev 2026-07-30). Two read-only draw layers that
# show what the town is already doing: the stores yard and the aura pools on the
# ground, and the lantern ropes strung between working neighbour pairs overhead.
# Neither touches state -- deleting either changes nothing but the view.
func spawn_presence_layer() -> void:
	var ground = VILLAGE_PRESENCE_SCRIPT.new()
	ground.position = Vector2(0.0, VILLAGE_Y)
	$Village.add_child(ground)
	var overhead = SYNERGY_LANTERNS_SCRIPT.new()
	overhead.position = Vector2(0.0, VILLAGE_Y)
	$Village.add_child(overhead)

func spawn_special_plots() -> void:
	for plot in GameState.SPECIAL_PLOTS:
		var marker = SPECIAL_PLOT_SCRIPT.new()
		marker.plot_id = str(plot["id"])
		marker.plot_name = str(plot["name"])
		marker.plot_desc = str(plot["desc"])
		marker.for_building = str(plot["building"])
		marker.half_width = GameState.PLOT_RADIUS
		marker.position = Vector2(float(plot["x"]), VILLAGE_Y)
		$Village.add_child(marker)

# A village building's blueprint def by name (for the build menu + placer).
func building_def(bname: String) -> Dictionary:
	for def in VILLAGE_BUILDINGS:
		if str(def.name) == bname:
			return def
	return {}

# Raise a role building FROM SCRATCH on chosen ground (build menu). Used when its
# ruin was deleted -- there's no node to move, so make a fresh standing one. The
# caller sets building_stage/positions; this just puts the body in the world.
func create_building(bname: String, x: float) -> Node:
	var def := building_def(bname)
	if def.is_empty():
		return null
	var sc := float(def.get("scale", 2.0))
	var b = BUILDING_SCRIPT.new()
	b.building_name = str(def.name)
	b.role_key = str(def.role_key)
	b.width = def.width * sc * VILLAGE_WIDTH_BOOST * 1.3
	b.height = def.height * sc * 1.3
	b.body_color = def.color
	b.position = Vector2(x, VILLAGE_Y)
	$Village.add_child(b)
	# LIVE ATTACHMENTS on this path too (audit fix): only generate_village used
	# to build them, so a Farm raised fresh from the B menu had NO pasture (and
	# no animals) until the next scene load, and a fresh Dock had no bridge --
	# a walkable deck the village literally routes over.
	if b.building_name == "Fishing Dock":
		var water_max = 1.0 + (BUILDING_SCRIPT.MAX_LEVEL - 1) * BUILDING_SCRIPT.DOCK_WATER_PER_LEVEL
		var reserve = maxf(b.width * MAX_UPGRADE_FACTOR, b.width * 2.0 * BUILDING_SCRIPT.DOCK_WATER_HALF * water_max)
		var bridge = DOCK_BRIDGE_SCRIPT.new()
		bridge.span = reserve + 110.0
		bridge.position = Vector2(x, VILLAGE_Y)
		$Village.add_child(bridge)
	elif b.building_name == "Farm":
		var pen = FARM_PEN_SCRIPT.new()
		pen.pen_width = FARM_PEN_WIDTH
		pen.position = Vector2(x + b.width * MAX_UPGRADE_FACTOR / 2.0 + VILLAGE_GAP + FARM_PEN_WIDTH / 2.0, VILLAGE_Y)
		$Village.add_child(pen)
	return b

# Re-plant every standing torch the player has placed (G key) -- they persist
# in GameState.placed_torches across dungeon trips and save/load.
func spawn_placed_torches() -> void:
	for e in GameState.placed_torches:
		var t = STANDING_TORCH_SCRIPT.new()
		t.position = Vector2(float(e.get("x", 0.0)), float(e.get("y", 0.0)))
		add_child(t)

# A cottage raised by the BUILDERS, not the player (automation ladder): same
# node, palette and ground rules as the B-menu path, but the id is already
# registered by GameState.auto_build_cottage -- we only put the body on screen.
func spawn_cottage_node(house_id: String, x: float) -> Node:
	var pal = HOUSE_COLORS[GameState.extra_cottages % HOUSE_COLORS.size()]
	var home = HOUSE_SCRIPT.new()
	home.house_id = house_id
	home.house_name = "Cottage %d" % (HOUSE_COUNT + GameState.extra_cottages)
	home.body_color = pal.body
	home.roof_color = pal.roof
	home.position = Vector2(x, VILLAGE_Y)
	var village = get_node_or_null("Village")
	(village if village != null else self).add_child(home)
	return home

func generate_houses() -> void:
	# Cottages sit just past the (now larger) village, computed from where the
	# buildings actually ended so they never overlap.
	var start_x = village_right_edge + HOUSE_MARGIN
	# NO PRE-BUILT COTTAGES (dev 2026-07-23): the fallen village starts with none --
	# you raise every home yourself from the B menu. Only the ones the PLAYER built
	# come back below.
	# cottages RAISED in past sessions (5.8) come back with the world...
	for j in range(GameState.extra_cottages):
		var idx = j + 1
		var palette2 = HOUSE_COLORS[idx % HOUSE_COLORS.size()]
		var extra = HOUSE_SCRIPT.new()
		# CRITICAL: the id MUST match the one this cottage was built with -- cottage_homes
		# is keyed by it and house.gd reads occupancy by it, so a mismatched id on reload
		# made a settled cottage read EMPTY and get double-booked. The id is STABLE now
		# (stored per-cottage, not derived from the index j), so deleting a middle cottage
		# no longer shifts the survivors' ids out from under their couples (dev 2026-07-23).
		extra.house_id = GameState.cottage_id_at(j)
		extra.house_name = "Cottage %d" % (HOUSE_COUNT + idx)
		extra.body_color = palette2.body
		extra.roof_color = palette2.roof
		# menu-built cottages come back on the ground the player chose; the old
		# end-of-row slot is only the fallback for any without a saved spot
		var ecx: float = start_x + (HOUSE_COUNT + j) * HOUSE_SPACING
		if j < GameState.extra_cottage_positions.size():
			ecx = float(GameState.extra_cottage_positions[j])
		extra.position = Vector2(ecx, VILLAGE_Y)
		$Village.add_child(extra)
	# (The old end-of-row "cottage_plot" E-to-build marker was REMOVED 2026-07-23:
	# cottages are raised ONE way now -- from the B menu, placed on any clear ground.
	# A second build path with its own id scheme was the double-book bug's root.)
	# 7.1: the Watchtower's plot stands just inside the west gate -- the first
	# thing a returning delver passes, asking to be raised
	var tower = preload("res://watchtower.gd").new()
	tower.position = Vector2(4800.0, VILLAGE_Y)
	$Village.add_child(tower)
	# THE ROAD MARKERS: village gate <-> the pit, ~5,200px apart. Two
	# signposts and an E, because the walk was never the game.
	const ROAD_MARKER = preload("res://road_marker.gd")
	var village_road = ROAD_MARKER.new()
	village_road.partner_x = -180.0
	village_road.marker_label = "the pit"
	village_road.position = Vector2(4600.0, VILLAGE_Y)
	$Village.add_child(village_road)
	var pit_road = ROAD_MARKER.new()
	pit_road.partner_x = 4600.0
	pit_road.marker_label = "the village"
	pit_road.position = Vector2(-180.0, VILLAGE_Y)
	add_child(pit_road)
	# 7.2: the village is besieged from BOTH ends -- the west gate the pit-road
	# breaks against, and the cottage row's far (east) end, which opens as a second
	# front once Orin is freed (clear floor 15, see siege_manager two_fronts).
	# BOTH ramparts are the PLAYER'S to raise now (dev 2026-07-23): the east wall is
	# NO LONGER auto-spawned at floor 15. When the east front wakes you raise the east
	# rampart yourself from the B menu, exactly like the west -- it returns below with
	# the rest of placed_walls. (This ended the "two walls at level 15" overlap, where
	# the auto wall stacked on top of any east wall the player had already built.)
	# player-built ramparts (build menu) come back on the ground they were raised
	for wdata in GameState.placed_walls:
		var pwall = preload("res://wall.tscn").instantiate()
		pwall.flank = str(wdata.get("flank", "west"))
		pwall.position = Vector2(float(wdata.get("x", GameState.SURFACE_WEST_FALLBACK_X)), VILLAGE_Y)
		add_child(pwall)

# NPC world avatars are runtime-only nodes -- nothing about them is written
# to the save file, so a fresh scene boot (New Game OR Continue) starts with
# zero of them in the tree. This reconstructs one for every entry already in
# GameState.rescued_villagers (a no-op on New Game, where that list is empty)
# so nobody who was previously rescued/born silently vanishes from the
# village after a save/reload. Anyone currently mid-mating-cycle (still in
# a cottage, or gestating) is skipped -- they don't have a wandering avatar
# during that time even in a live, non-reloaded session (see house.gd).
func spawn_existing_villager_avatars() -> void:
	# THE EMPTY RUINS (2026-07-25): a fresh arrival opens on a dead village. The
	# starting souls (Doctor Maren + the two farmhands) exist in the roster from
	# frame one so every system that counts them works, but their AVATARS stay
	# hidden until the first wave is broken -- then they creep from the wreckage
	# in the arrival cutscene (_on_arrival_raider_died -> _emerge_arrival_survivors,
	# which calls this again with the flag now set). dev_mode skips the whole
	# opening, so it peoples the village at once.
	var hide_starters := not GameState.seen_arrival_battle and not GameState.dev_mode
	# NO DOUBLES: this spawner runs more than once per scene life (arrival
	# emerge, post-victory), and a crystal freed on the road already spawned its
	# own body via villager.spawn_world_avatar -- without this check each such
	# villager got a twin (two hover cards, two E-prompts, double defence hits),
	# and the endgame pass duplicated all Ten.
	var has_body := {}
	for n in get_tree().get_nodes_in_group("npc"):
		if is_instance_valid(n) and "villager_id" in n:
			has_body[str(n.villager_id)] = true
	for villager in GameState.rescued_villagers:
		var villager_id = villager.get("id", "")
		# THE THAW (4.2a): a crystal-freed hostage's stats stay wrapped until
		# they stand at home -- this is home. Unwrap the gift, and say what
		# the gamble paid. This ALWAYS runs (independent of whether the opening's
		# starter avatars are shown yet) -- the reveal is roster state, not visuals.
		if villager.get("stats_hidden", false):
			villager.erase("stats_hidden")
			var stat := str(villager.get("stat_name", ""))
			if stat != "":
				GameState.notify("❄→☀ %s thaws fully — a %s of %d!" % [
					villager.get("name", "?"), stat, int(villager.get("stat_value", 0))])
				GameState.log_event("people", "%s thawed at home — a %s of %d." % [
					villager.get("name", "?"), stat, int(villager.get("stat_value", 0))])
		# THE EMPTY RUINS: keep the starter avatars hidden until the first wave --
		# suppress only the avatar spawn, never the thaw above.
		if hide_starters:
			continue
		if has_body.has(str(villager_id)):
			continue
		if is_villager_busy_mating(villager_id):
			continue
		var npc = NPC_SCRIPT.new()
		npc.villager_id = villager_id
		npc.global_position = offscreen_spawn(find_avatar_spawn_position(villager.get("role_key", "")))
		$Village.add_child(npc)
		# plant the feet AFTER _ready has sized the body (kid vs adult): the spawn
		# helpers aim a rough y, and anything above the floor hangs in mid-air for
		# as long as the tree is paused (a cutscene) instead of falling
		npc.global_position.y = _npc_ground_y(npc)

# A newborn with no Hospital to host the birth still needs a world avatar -- else it is an
# invisible roster entry (counting for population/wages/morale) until the next village
# reload. building.gd's Hospital hook covers the Hospital case; this covers its absence,
# guarded so the two never both spawn.
func _on_village_child_born(child_id: String) -> void:
	# child_produced is a persistent AUTOLOAD signal; a birth resolving as this village
	# scene is torn down would run us out-of-tree (null get_tree() / $Village).
	if not is_inside_tree():
		return
	if get_tree().get_first_node_in_group("building_role_Hospital") != null:
		return
	var npc = NPC_SCRIPT.new()
	npc.villager_id = child_id
	npc.global_position = offscreen_spawn(find_avatar_spawn_position(""))
	$Village.add_child(npc)
	npc.global_position.y = _npc_ground_y(npc)   # feet on the floor, never mid-air

# FORESHADOWING (GAME_BIBLE 9.8): the mid-game taunt -- Orin WANTS you to grow,
# and once, around the halfway mark, he says so almost plainly. Reads as a
# mentor's pride the first time; reads as the farmer admiring the crop forever
# THE ARRIVAL BATTLE (GAME_BIBLE 2.4.1, beats 1-2): the player's first fight
# is IN COMPANY. When the opening plea ends, a small Despair wave is already
# breaking against the three defenders at the west gate -- the player joins,
# the wave dies, and the trio explains the trap that makes the whole game
# happen HERE (Story.ARRIVAL_TRAP). Once per world, saved.
var _arrival_left := 0
# has the approach cutscene already been handed to the player IN THIS SCENE?
# Transient on purpose: a reload re-arms the approach, a lapsed shield does not.
var _arrival_scene_played := false

# THE ROAD IS WALKED ALONE (dev 2026-07-21). The teaching fight used to be
# staged 800px from where the player wakes, so he was never by himself for a
# second. Now the prologue ends and he has the whole road to himself; the
# defenders and their raiders exist only once he can see the west wall.
var _arrival_armed := false

func arm_arrival_battle() -> void:
	if GameState.seen_arrival_battle or GameState.dev_mode:
		return
	_arrival_armed = true

const ARRIVAL_TRIGGER_DIST = 900.0   # first sight of the rampart

func _check_arrival_trigger() -> void:
	# RELOAD GUARD (sweep 2026-07-21). _arrival_armed is transient -- it is set
	# only by the prologue's callback, and the prologue never replays. So a
	# player who saved after the prologue but before reaching the wall came back
	# to NO fight and NO reveal, forever: the whole opening silently skipped.
	# Re-arm whenever the prologue is done and the battle has neither happened
	# (seen_arrival_battle) nor is currently running (arrival_battle_active) --
	# the two guards that keep this from re-spawning the wave mid-fight or after.
	# ...but ONCE PER SCENE. The shield behind arrival_battle_active expires after
	# 150s, and once it lapsed this re-armed mid-fight: a new player still
	# swinging at the four raiders got the whole HEROES_BANTER cutscene shoved
	# back in their face (pausing the world), and again every ~150s until the
	# wave died. _arrival_scene_played is transient, so the reload path (a save
	# taken between the prologue and the wall) still re-arms exactly as before.
	if not _arrival_armed and not _arrival_scene_played and GameState.seen_intro \
			and not GameState.seen_arrival_battle \
			and not GameState.arrival_battle_active and not GameState.dev_mode:
		_arrival_armed = true
	if not _arrival_armed:
		return
	var pl = get_tree().get_first_node_in_group("player")
	if pl == null:
		return
	# THE ARRIVAL IS A SURFACE SCENE AT THE GATE. The cave is sealed until it is
	# done (underdark._tick_cave_mouth), but guard here too: never fire it from a
	# dungeon floor or from down in the deep, so the trio + reveal can only ever
	# happen where they belong -- on the road at the village wall.
	if GameState.in_dungeon or pl.global_position.y > 250.0:
		return
	var wall_x := _west_wall_x()
	if pl.global_position.x < wall_x - ARRIVAL_TRIGGER_DIST:
		return
	_arrival_armed = false
	trigger_arrival_scene(wall_x)

func _west_wall_x() -> float:
	# the west rampart's real face if one stands, else the shared surface-band
	# fallback (de-magic'd 2026-07-24; was a bare 4700.0 duplicated in three spots)
	var wall_x := GameState.SURFACE_WEST_FALLBACK_X
	for w in get_tree().get_nodes_in_group("village_wall"):
		if "flank" in w and w.flank == "west":
			wall_x = w.global_position.x
			break
	return wall_x

var _arrival_staged := false

# STAGE the teaching fight at new-game start (dev 2026-07-22): the trio + their
# raiders stand at the road ALREADY fighting -- theatrically, so no one falls --
# so when the player walks up there is no pop-in, just a battle in progress. The
# fight happens AT THE WALL (2.4.1): you FIND the three defenders mid-battle and
# learn combat in company. Transient (raiders aren't saved) -- re-staged on a
# reload where the arrival is still owed.
func stage_arrival_battle(wall_x: float = -1.0) -> void:
	if GameState.seen_arrival_battle or GameState.dev_mode or _arrival_staged:
		return
	if GameState.in_dungeon:
		return
	if wall_x < 0.0:
		wall_x = _west_wall_x()
	var road_x: float = wall_x - 620.0
	_arrival_staged = true
	# ARM THE APPROACH TRIGGER HERE (softlock fix 2026-07-25). On a fresh game the
	# prologue calls arm_arrival_battle(); on a CONTINUE the prologue never replays,
	# and staging turns on the shield (arrival_battle_active), which then blocked
	# _check_arrival_trigger from ever re-arming -- so activate_arrival_combat never
	# fired and the raiders stayed theatrical=true (invincible) forever. Arming the
	# moment we stage makes the reload path trigger the fight exactly like a new game.
	_arrival_armed = true
	_arrival_left = 4
	GameState.begin_arrival_shield()   # nobody dies in the teaching wave
	for i in range(4):
		var e = SIEGE_ENEMY_FOR_ARRIVAL.instantiate()
		e.skin = "raider"
		e.max_health = 60          # a LEARNING fight: lasts long enough for the
		                           # player to WALK OVER and land real hits once live
		e.attack_damage = 4
		e.reward = 3
		e.wall = null              # they fight the defenders, not the stone
		e.arrival_mode = true      # ...and ONLY the defenders -- never a building 4km east
		e.theatrical = true        # a shadow-fight until the player triggers the scene
		e.global_position = Vector2(road_x + 170.0 + i * 55.0, -70.0)
		e.died.connect(_on_arrival_raider_died)
		add_child(e)
	# the trio HOLDS the road: their POST is moved here (home_x), not just their
	# bodies, or they would seek raiders only near their old village station and
	# never engage. Spaced DETERMINISTICALLY (random offsets once glued two into
	# one blob, dev's report).
	var line_i := 0
	for a in get_tree().get_nodes_in_group("adventurer"):
		var ax: float = road_x - 40.0 + line_i * 62.0
		a.global_position = Vector2(ax, -70.0)
		if "home_x" in a:
			a.home_x = ax
		line_i += 1

# The APPROACH (within sight of the rampart) starts the banter, then turns the
# staged shadow-fight into a real one. The fight is already on screen; this only
# hands the player their cue.
func trigger_arrival_scene(wall_x: float = -1.0) -> void:
	if GameState.seen_arrival_battle or GameState.dev_mode:
		return
	_arrival_scene_played = true   # the cue is spent: never replay it mid-fight
	if not _arrival_staged:
		stage_arrival_battle(wall_x)   # belt-and-suspenders (e.g. an odd reload)
	# BEAT 2-3 (dev's opening): the player crested the road and SEES the trio
	# fighting -- their banter plays, ending on "let's help them", then control
	# returns and the shadow-fight becomes the teaching wave.
	var pl_b = get_tree().get_first_node_in_group("player")
	if pl_b != null:
		DialogueBox.play(pl_b, Story.HEROES_BANTER, func(): activate_arrival_combat())
	else:
		activate_arrival_combat()

# The scene is over: the raiders can now be killed, they turn on the player, and
# the trio's shield is refreshed for the whole of the real fight.
func activate_arrival_combat() -> void:
	GameState.begin_arrival_shield()   # a fresh window covering the live fight
	for e in get_tree().get_nodes_in_group("siege_enemy"):
		if "theatrical" in e:
			e.theatrical = false
	GameState.notify("⚔ Three of them, holding the gate — GO!")

func _on_arrival_raider_died() -> void:
	_arrival_left -= 1
	if _arrival_left > 0 or GameState.seen_arrival_battle:
		return
	GameState.seen_arrival_battle = true
	GameState.arrival_battle_active = false   # from here on, they are mortal
	# bank the win at once (softlock fix 2026-07-25): even if the player quits during
	# the reveal talk that follows, Continue must not replay the (now-won) wave.
	GameState.autosave("the first wave broke")
	# release the trio from the road post we pinned them to for the staged fight,
	# so they drift back to their proper stations (home_x = 0 -> re-resolves)
	for a in get_tree().get_nodes_in_group("adventurer"):
		if "home_x" in a:
			a.home_x = 0.0
	GameState.log_event("combat", "Your first wave broke at the gate — you fought it beside Roland, Wren and Castor.")
	# THE SURVIVORS EMERGE (2026-07-25): the ruin stood empty through the fight;
	# now that the gate holds, the people who hid from the raiders creep out --
	# the Doctor and the two farmhands. Spawn their avatars beside the gate so the
	# reveal that follows is spoken by real bodies, and the village is peopled from
	# here on. Their walk-in reads as the moment life returns to Deepwood.
	var pl0 = get_tree().get_first_node_in_group("player")
	_emerge_arrival_survivors(pl0)
	# THE TALK FOLLOWS THE FIGHT, because the fight is now AT the wall (dev
	# 2026-07-21: "only after defeating them dialogue starts"). An earlier pass
	# made the player walk to the rampart first -- correct when the battle was
	# staged out on the open road, pointless now that it is fought at the gate.
	_arrival_talk_pending = true
	if pl0 != null:
		play_arrival_talk(pl0)

# The pending arrival talk: armed when the teaching wave breaks, fired when the
# player crosses the west rampart. Transient on purpose -- if the player quits
# between the fight and the wall, the reload replays from seen_arrival_battle
# and the talk is delivered by the fallback below.
var _arrival_talk_pending := false
# The chain is in flight right now (transient, never saved). This is the replay
# guard while the boxes play -- seen_arrival_talk is only persisted once the LAST
# box lands, so a quit mid-chain replays the whole talk on Continue instead of
# stranding opening_done=false forever (which silently disabled every siege).
var _arrival_talk_running := false
const ARRIVAL_TALK_FALLBACK_X = 5400.0   # past the wall, however a save moved it

func _check_arrival_talk() -> void:
	# reload guard: a save made between the fight and the wall re-arms the walk
	if not _arrival_talk_pending and not _arrival_talk_running \
			and GameState.seen_arrival_battle \
			and not GameState.seen_arrival_talk and not GameState.dev_mode:
		_arrival_talk_pending = true
	if not _arrival_talk_pending:
		return
	var pl = get_tree().get_first_node_in_group("player")
	if pl == null:
		return
	# the west rampart's real face if one stands, else the classic line
	var wall_x := _west_wall_x()
	# Only the RELOAD path reaches here (a save taken between the fight and the
	# words). The fight itself plays the talk on the spot. Near the wall is the
	# condition, not past it -- the battle is fought on its western approach.
	if pl.global_position.x < wall_x - ARRIVAL_TRIGGER_DIST:
		return
	_arrival_talk_pending = false
	play_arrival_talk(pl)

# THE SURVIVORS EMERGE. Fired once, the instant the arrival wave breaks. Now that
# seen_arrival_battle is true, re-running the spawn peoples the village for the
# first time (spawn_existing_villager_avatars' hide_starters guard is now false),
# so the Doctor and the two farmhands appear. Gather them just inside the gate,
# on-screen beside the player, so the reveal cutscene that follows is spoken by
# real bodies stepping out of the ruin rather than thin air.
func _emerge_arrival_survivors(pl: Node) -> void:
	spawn_existing_villager_avatars()
	_stage_arrival_tableau(pl)

# Arrange the arrival cutscene as a tableau: the three defenders gathered at the
# player's WEST shoulder (toward the gate they just held), turned east to face
# him; the survivors at his EAST shoulder (stepping out of the ruined town),
# turned west, the Doctor nearest since she speaks the reveal. Positions and
# facings are set DIRECTLY, not left to each body's own _process -- the dialogue
# box pauses the whole tree the same frame this runs, so nothing would tick to
# apply them. Shared by the live path (_emerge_arrival_survivors) and the reload
# path (play_arrival_talk), so the scene composes the same either way.
func _stage_arrival_tableau(pl: Node) -> void:
	if pl == null:
		return
	var px: float = pl.global_position.x
	var ai := 0
	for a in get_tree().get_nodes_in_group("adventurer"):
		if "is_dead" in a and a.is_dead:
			continue
		a.global_position = Vector2(px - 96.0 - 74.0 * float(ai), a.global_position.y)
		_face_entity(a, 1.0)                       # look east, toward the player
		ai += 1
	var survivors: Array = []
	var doc: Node = null
	for n in get_tree().get_nodes_in_group("npc"):
		if not is_instance_valid(n):
			continue
		if str(n.get("villager_id")) == "doctor_maren":
			doc = n
		else:
			survivors.append(n)
	if doc != null:
		survivors.push_front(doc)                  # the Doctor stands closest
	# THEY COME OUT OF THE RUINS, ON THE GROUND (dev call 2026-07-27: "villagers
	# spawn mid air, i want them to come out from ruins"). Two faults stacked
	# here. (1) Their spawn y sat 40-60px ABOVE the village floor: an npc's
	# collision box is CENTRED on its origin (npc.apply_size), so its feet are
	# 18*scale BELOW it -- standing y is VILLAGE_Y - 18*scale, not VILLAGE_Y - 60.
	# (2) The dialogue box pauses the whole tree the same frame this runs, so
	# gravity never pulled them down and they hung in the air for the whole beat.
	# Now each survivor is planted ON the floor AT a ruin -- nearest ruins first,
	# fanned along the facade -- so the reveal reads as people stepping out of the
	# wreckage of their own town rather than materialising beside the player.
	# ...but ONLY a ruin the player can actually SEE. The first version of this
	# sorted every building by distance and used the nearest -- and on a fresh
	# arrival the four standing ruins are 5.2k/8.9k/11.7k/14.9k while the fight
	# ends at x~4100, so the survivors were flung 1,000-7,400px away and the
	# reveal was spoken by bodies off the edge of the screen (the function's own
	# contract is that the speaker must have a visible body). A ruin only counts
	# if it is inside the view; otherwise they step out beside the player, which
	# is what the shot needs above all.
	var half_view: float = get_viewport_rect().size.x * 0.5
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		half_view = half_view / maxf(cam.zoom.x, 0.05)
	var ruins: Array = []
	for b in get_tree().get_nodes_in_group("building"):
		if is_instance_valid(b) and absf(b.global_position.x - px) <= half_view - 120.0:
			ruins.append(b)
	ruins.sort_custom(func(r1, r2):
		return absf(r1.global_position.x - px) < absf(r2.global_position.x - px))
	var ni := 0
	for n in survivors:
		var gy := _npc_ground_y(n)
		if ruins.is_empty():
			# no ruin on screen: the old staging, at the player's east shoulder
			n.global_position = Vector2(px + 108.0 + 72.0 * float(ni), gy)
		else:
			var ruin = ruins[ni % ruins.size()]
			var lane := int(ni / ruins.size())      # a second lap stands further out
			var half: float = (ruin.eff_w() * 0.5) if ruin.has_method("eff_w") else 60.0
			# step out of the side of the ruin that FACES the player
			var side: float = -1.0 if ruin.global_position.x >= px else 1.0
			var sx: float = ruin.global_position.x + side * (half * 0.6 + 30.0 * float(lane))
			# and never past the edge of the shot
			n.global_position = Vector2(
				clampf(sx, px - half_view + 90.0, px + half_view - 90.0), gy)
		var toward: float = signf(px - n.global_position.x)
		_face_entity(n, toward if toward != 0.0 else -1.0)   # turn to the player
		ni += 1

# An npc's collision box is CENTRED on its origin (npc.apply_size sizes it
# 36*scale tall), so its feet sit 18*scale below -- that is the offset the
# village floor has to meet. Kids are scaled 0.65, so they need their own value.
func _npc_ground_y(n: Node) -> float:
	var s: float = float(n.body_scale_factor) if "body_scale_factor" in n else 1.0
	return VILLAGE_Y - 18.0 * s

# Turn a character to face left (dir<0) or right (dir>0). Covers both body kinds:
# villager npcs (Node2D body_gfx scaled by direction) and adventurers (an
# AnimatedSprite2D _skin_sprite, or a body_rect fallback).
func _face_entity(node: Node, dir: float) -> void:
	var s := signf(dir)
	if "direction" in node:
		node.direction = int(s)
	if "body_gfx" in node and node.body_gfx != null:
		var f := 1.0
		if "body_scale_factor" in node:
			f = absf(float(node.body_scale_factor))
		node.body_gfx.scale.x = s * f
	if "_skin_sprite" in node and node._skin_sprite != null:
		node._skin_sprite.scale.x = absf(node._skin_sprite.scale.x) * s
	if "body_rect" in node and node.body_rect != null:
		node.body_rect.scale.x = s

func play_arrival_talk(pl: Node) -> void:
	# clear the pending flag up front: the live path (the fight) arms it then
	# calls straight in, and _check_arrival_talk runs again the instant the
	# dialogue unpauses -- without this the whole trap/reveal/oath/tutorial chain
	# (and _spawn_reveal_survivors + tutorial_begin) replayed a second time.
	_arrival_talk_pending = false
	_arrival_talk_running = true   # replay guard while the boxes play (transient)
	# Compose the scene: defenders and survivors gathered around the player, each
	# turned to face the exchange (the RELOAD path reaches here without _emerge
	# having run, so the tableau is staged here too -- idempotent, safe to repeat).
	# The SPEAKER MUST HAVE A BODY (live-playtest lesson): the reveal is spoken by
	# a real villager avatar, the Doctor, standing at the player's side.
	_stage_arrival_tableau(pl)
	# the full arrival chain (new canon): the trap named -> the ruin
	# REVEALED as Deepwood itself (the 180-degree reality check) -> the
	# oath the whole game executes, sworn aloud once
	DialogueBox.play(pl, Story.ARRIVAL_TRAP, func():
		DialogueBox.play(pl, Story.DEEPWOOD_REVEAL, func():
			DialogueBox.play(pl, Story.THE_OATH, func():
				# beat 8: the oath sworn, the trio teach the player the ropes -- then
				# the tutorial becomes a step-gated checklist (wall -> farm -> home)
				DialogueBox.play(pl, Story.TUTORIAL_INTRO, func():
					# only NOW is the talk banked: a quit anywhere above replays the
					# chain on Continue rather than losing tutorial_begin (and with
					# it opening_done -- i.e. the entire siege half of the game)
					GameState.seen_arrival_talk = true
					_arrival_talk_running = false
					GameState.tutorial_begin()))))

# (The BEAT-6 "reveal survivors" cutscene figures were REMOVED 2026-07-25 on dev's
# call. They were bare ColorRect placeholder boxes whose fade tweens were pausable,
# so they stayed frozen-invisible through the paused reveal/oath dialogue and then
# leaked into free play as loitering boxes that faded out ~26s later. The real
# survivor who speaks the reveal is the actual npc avatar handled above.)

# NG+ arrival: one line the moment the rewound player wakes, then the world
# treats them like any first arrival. Transient flag -- never saved, so a
# reload mid-run stays silent.
func _autosave_on_arrival() -> void:
	GameState.autosave("home safe", true)

func stamp_rewound_arrival() -> void:
	if not GameState.just_rewound:
		return
	GameState.just_rewound = false
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack:
		stack.show_notification("⌛ The world has rewound (cycle %d). You remember everything. It remembers nothing." % GameState.ng_plus_cycles)

# after. One-shot, saved.
func orin_midgame_taunt() -> void:
	if GameState.seen_orin_taunt or not GameState.orin_arrived() or GameState.dev_mode:
		return
	if GameState.highest_unlocked_level < 40:
		return
	GameState.seen_orin_taunt = true
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack:
		stack.show_notification("Orin, watching you return from the deep: \"Stronger again. Good. GOOD. Bring every scrap of it home, hunter — build this place to its peak. I find I very much want to see that.\"")

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
	if GameState.game_completed or GameState.despair_dead:
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
	ward.body_entered.connect(_on_escape_attempt)

# "LEAVING DEEPWOOD" (12.7, decided delegated): the exit is TESTABLE -- and
# testing it is the lesson. The first attempt is the scripted near-death
# (2.4.1 beat 3). Every retry spawns a REAL, doubling wave: clearable, and
# clearing it only proves the road ahead has already doubled again. The
# cage is not a wall; it is arithmetic.
var _gauntlet_left := 0

func _on_escape_attempt(b: Node) -> void:
	if not b.is_in_group("player") or b.god_mode:
		return
	GameState.escape_attempts += 1
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if GameState.escape_attempts <= 1:
		# beat 3: mauled to the brink, hurled back east
		b.health = maxi(1, int(b.get_max_health() * 0.2))
		if b.has_method("update_health_display"):
			b.update_health_display()
		b.global_position.x = GROUND_SPAN_START + 260.0
		b.velocity = Vector2(420.0, -160.0)
		if b.has_method("apply_knockback"):
			b.apply_knockback(1, 120.0)
		if stack:
			stack.show_notification("The road out DROWNS in the horde — it swells to meet you. You barely crawl back.")
		if not GameState.seen_failed_escape:
			GameState.seen_failed_escape = true
			DialogueBox.play(self, Story.FAILED_ESCAPE)
		return
	if _gauntlet_left > 0:
		return                       # one gauntlet at a time
	# retries: shoved back on your feet -- and the road answers in numbers.
	# The spawn is DEFERRED: this handler runs inside the physics flush
	# (body_entered), and adding CharacterBody2Ds mid-flush is exactly the
	# kind of engine-state violation that hard-crashes a release build.
	b.global_position.x = GROUND_SPAN_START + 300.0
	b.velocity = Vector2(380.0, -120.0)
	var n: int = mini(4 * int(pow(2.0, GameState.escape_attempts - 2)), 24)
	_gauntlet_left = n
	call_deferred("_spawn_gauntlet_wave", n)
	if stack:
		stack.show_notification("⚠ The road answers: %d of the horde turn to meet you." % n)
	GameState.log_event("combat", "You tested the road out — %d of the dark came to argue." % n)

func _spawn_gauntlet_wave(n: int) -> void:
	var tier: int = GameState.current_siege_tier()
	for i in range(n):
		var e = SIEGE_ENEMY_FOR_ARRIVAL.instantiate()
		e.skin = "raider"
		e.max_health = int(round(50.0 * (1.0 + (tier - 1) * 0.3)))
		e.attack_damage = int(round(10.0 * (1.0 + (tier - 1) * 0.2)))
		e.reward = 2                 # the road pays poorly on purpose
		e.wall = null
		e.global_position = Vector2(GROUND_SPAN_START + 60.0 + (i % 6) * 44.0, GROUND_Y - 70.0 - float(i / 6) * 40.0)
		e.died.connect(_on_gauntlet_raider_died)
		add_child(e)

func _on_gauntlet_raider_died() -> void:
	_gauntlet_left -= 1
	if _gauntlet_left > 0:
		return
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack:
		stack.show_notification("The wave breaks... and the road runs on — the dark ahead of it has already DOUBLED. There is no end in this direction.")
	GameState.log_event("combat", "You broke the road's wave. The road did not care.")

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
		# spawn them IN the village, not on the old map's coordinates (they
		# used to appear at x~1900, thousands of pixels west of the town)
		adv.global_position = Vector2(VILLAGE_START_X + 60.0 + i * 90.0, VILLAGE_Y - 30.0)
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

# NOBODY POPS INTO EXISTENCE IN FRONT OF YOU (dev call 2026-07-21). People
# appearing out of thin air a few steps away breaks the world harder than any
# missing feature. Any spawn inside the player's view is pushed just past the
# nearest screen edge, so a villager always WALKS into frame instead of
# materialising in it. (Their own wander logic carries them the rest of the way.)
const OFFSCREEN_MARGIN := 140.0

func offscreen_spawn(pos: Vector2) -> Vector2:
	var pl = get_tree().get_first_node_in_group("player")
	if pl == null:
		return pos
	var half_view: float = get_viewport_rect().size.x * 0.5 + OFFSCREEN_MARGIN
	var dx: float = pos.x - pl.global_position.x
	if absf(dx) >= half_view:
		return pos                      # already out of sight -- leave it be
	# push to whichever edge it is already closer to, so the walk-in is short
	var side: float = 1.0 if dx >= 0.0 else -1.0
	return Vector2(pl.global_position.x + side * half_view, pos.y)

func find_avatar_spawn_position(role_key: String) -> Vector2:
	if role_key != "":
		for child in $Village.get_children():
			if child.has_method("get_roles") and child.role_key == role_key:
				return child.global_position + Vector2(randf_range(-18.0, 18.0), -60.0)
	# the unemployed (the Doctor among them) belong IN the village, not on its
	# western doorstep -- the old fixed fallback sat ~300px west of the first
	# building, so they read as standing outside town (dev's report).
	# SPREAD, don't bunch (dev 2026-07-24): landing every unhoused villager just
	# past the LEFTMOST building parked them all at the west gate -- right where
	# the arrival battle is fought -- so after the first wave they read as a row
	# of "random dark figures" on the doorstep. Fan them across the whole village
	# span instead, so they stand about town like people, not a huddle at the gate.
	var first_x := 0.0
	var last_x := 0.0
	for child2 in $Village.get_children():
		if child2.has_method("get_roles"):
			var cx: float = child2.global_position.x
			first_x = cx if first_x == 0.0 else minf(first_x, cx)
			last_x = maxf(last_x, cx)
	if first_x > 0.0:
		var span: float = maxf(last_x - first_x, 200.0)
		return Vector2(first_x + 120.0 + randf() * span, VILLAGE_FALLBACK_POS.y + randf_range(-24.0, 24.0))
	return VILLAGE_FALLBACK_POS

func _process(delta: float) -> void:
	for cloud in $Clouds.get_children():
		cloud.position.x += cloud.get_meta("speed") * delta
		if cloud.position.x > CLOUD_SPAN_END:
			cloud.position.x = CLOUD_SPAN_START
	_check_arrival_trigger()
	_check_arrival_talk()
	_tick_music(delta)

# ── THE FULL MAP (M), village edition ─────────────────────────────────────────
# The underground grew Terraria's fullscreen map and the dev asked for it
# everywhere. Here the chart is a SNAPSHOT of the living village: every building
# by name, the walls, the ways out -- and the people walk on it live.
const WORLD_MAP := preload("res://world_map.gd")
var _world_map: CanvasLayer = null

func _unhandled_input(e: InputEvent) -> void:
	if _world_map != null and _world_map.handle_input(e):
		return
	# the full map is ADMIN kit (dev call, 2026-07-30): launch --dev to use it
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_M and GameState.dev_mode:
		_open_village_map()
	# THE PROVING GROUND on P: three dummies at staged distances and a readout
	# of what the wielded weapon actually does. Admin kit, same as the map --
	# it exists so a weapon can be APPROVED by being watched, which is the one
	# thing none of the headless probes can do.
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_P and GameState.dev_mode:
		_toggle_proving_ground()

const TRAINING_ARENA = preload("res://training_arena.gd")
var _arena: Node2D = null

func _toggle_proving_ground() -> void:
	if _arena != null and is_instance_valid(_arena):
		_arena.queue_free()
		_arena = null
		return
	_arena = TRAINING_ARENA.new()
	add_child(_arena)

func _open_village_map() -> void:
	if _world_map == null:
		_world_map = WORLD_MAP.new()
		add_child(_world_map)
	if _world_map.is_open():
		_world_map.close_map()
		return
	var rects: Array = []
	var markers: Array = []
	# the ground: one long strip so the chart has a floor line
	rects.append({"rect": Rect2(-2600, 300, 42000, 90), "color": Color(0.24, 0.30, 0.18)})
	for b in get_tree().get_nodes_in_group("building"):
		if not is_instance_valid(b) or not (b is Node2D):
			continue
		var w: float = b.width if "width" in b else 100.0
		var h: float = b.height if "height" in b else 80.0
		rects.append({"rect": Rect2(b.global_position.x - w / 2.0, b.global_position.y - h, w, h),
			"color": Color(0.52, 0.42, 0.28)})
		var bname: String = b.building_name if "building_name" in b else "Building"
		markers.append({"at": Vector2(b.global_position.x, b.global_position.y - h - 14.0),
			"color": Color(1.0, 0.85, 0.3, 0.0), "label": bname})   # invisible dot: hover names the building
	for w2 in get_tree().get_nodes_in_group("village_wall"):
		if is_instance_valid(w2) and w2 is Node2D:
			rects.append({"rect": Rect2(w2.global_position.x - 14, w2.global_position.y - 110, 28, 110),
				"color": Color(0.45, 0.44, 0.48)})
			markers.append({"at": w2.global_position + Vector2(0, -120),
				"color": Color(0.8, 0.8, 0.9, 0.0), "label": "The rampart — the village wall"})
	# the ways out of town
	markers.append({"at": Vector2((UNDERDARK_SCRIPT.MOUND_LEFT + UNDERDARK_SCRIPT.MOUND_RIGHT) / 2.0, 260.0),
		"color": Color(0.4, 0.9, 1.0), "label": "The cave mouth — down to the underground"})
	var live := {
		"npc": {"color": Color(0.55, 0.85, 0.5), "label": "A villager"},
		"adventurer": {"color": Color(0.4, 0.7, 1.0), "label": "A defender"},
		"siege_enemy": {"color": Color(1.0, 0.3, 0.25), "label": "An enemy at the walls"},
	}
	_world_map.open_map(rects, markers, live, get_tree().get_first_node_in_group("player"))

func start_music() -> void:
	# THE SURFACE THEME (dev-supplied, 2026-07-27). Ogg/MP3 streams, so looping
	# is a property on the resource rather than WAV loop-point samples.
	music.loop = true
	healthy_music.loop = true
	# pick the right voice on the FIRST frame: walking home to a thriving town
	# should already sound thriving, not switch a second later
	_music_healthy = _village_is_healthy()
	$MusicPlayer.stream = healthy_music if _music_healthy else music
	$MusicPlayer.bus = "Music"   # so the Music volume slider controls it
	# the scene's authored volume is the baseline (audit fix: this used to
	# hard-code 0.0 over a stale -10 in the .tscn -- the two now agree, and a
	# designer tuning the scene changes what actually plays)
	_music_base_db = $MusicPlayer.volume_db
	$MusicPlayer.play()

# Is the town well enough to have earned the better theme? Hysteresis: once the
# healthy theme is on it takes a real slide (not a wobble at the line) to lose it.
func _village_is_healthy() -> bool:
	# the finale owns its own dramaturgy -- the false-victory feast pins morale
	# at 100, and the Harvest that follows must NOT sound like a healthy village
	if GameState.harvest_at_home or GameState.feast_glow:
		return _music_healthy and not GameState.harvest_at_home
	var m: int = GameState.village_morale()
	return m >= (HEALTHY_MORALE_OFF if _music_healthy else HEALTHY_MORALE_ON)

# Swap the surface theme when the town's health crosses the line, cross-faded so
# it reads as the place lifting rather than a track being changed.
func _tick_music(delta: float) -> void:
	_music_check_cd -= delta
	if _music_check_cd > 0.0:
		return
	_music_check_cd = 1.0
	var want := _village_is_healthy()
	if want == _music_healthy:
		return
	_music_healthy = want
	var mp: AudioStreamPlayer = $MusicPlayer
	var next: AudioStream = healthy_music if want else music
	if _music_fade_tween != null and _music_fade_tween.is_valid():
		_music_fade_tween.kill()
	_music_fade_tween = create_tween()
	_music_fade_tween.tween_property(mp, "volume_db", -40.0, MUSIC_FADE * 0.5)
	_music_fade_tween.tween_callback(func():
		mp.stream = next
		mp.play())
	_music_fade_tween.tween_property(mp, "volume_db", _music_base_db, MUSIC_FADE * 0.5)
	# the MILESTONE is said once per run (audit fix: the theme itself may swap
	# on every crossing of the hysteresis band -- that's the music doing its
	# job -- but a diary that logs "the town found its song" on every wobble
	# around the line turns a milestone into noise)
	if want and not GameState.healthy_theme_celebrated:
		GameState.healthy_theme_celebrated = true
		GameState.notify("🎵 Deepwood sounds like a village again.")
		GameState.log_event("village", "The town found its song again — Deepwood is healthy.")

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
	# NEVER load underground. The Underdark lives inside THIS scene, so a save made
	# down in the caves -- or the auto-save on clearing a floor, which records the
	# deep Underdark DOOR you entered by -- would drop you into the deep. And the
	# deep's collision is generated over the first frames, so a player placed there
	# before it exists FALLS FOREVER (dev report 2026-07-22: "pressed Continue,
	# spawned underground, fell forever"). Continue always lands you safe on the
	# surface, at the village threshold. In-session floor exit is unaffected -- it
	# uses the live pre_dungeon_position, not this saved point.
	# The same net also catches a below-ground / (0,0) origin save: a stale or
	# interrupted write (e.g. one made before the player was placed) leaves the
	# origin, which sits UNDER the village floor (surface y=-39, standing centre
	# y=-63) and falls just the same. The surface never sits below y=-50, so any
	# saved y greater than that is not on it. (dev report 2026-07-25: "pressed
	# Continue, spawned below ground, fell endlessly".)
	if player.global_position.y > -50.0:
		player.global_position = GameState.VILLAGE_SPAWN
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

# running id for harvest nodes: incremented on every spawn CALL (even skipped
# ones), so a node's id depends only on its position in the fixed spawn order
var _harvest_id_seq := 0

func generate_harvestables() -> void:
	_harvest_id_seq = 0
	# PER-RUN seeded jitter (audit fix): these offsets were unseeded, so every
	# scene rebuild grew a different forest and no per-node depletion state
	# could ever persist -- one dungeon round trip regrew the whole world to
	# full. One roll per run (saved), and the grove holds still.
	var jrng := RandomNumberGenerator.new()
	jrng.seed = GameState.ensure_harvest_seed()
	# trees spread along the whole combat course...
	var spacing = (HARVEST_SPAN_END - HARVEST_SPAN_START) / float(TREE_COUNT)
	for i in range(TREE_COUNT):
		var x = HARVEST_SPAN_START + (i + 0.5) * spacing + jrng.randf_range(-spacing * 0.3, spacing * 0.3)
		spawn_harvest_node("tree", x)
	# ...with rocks interleaved between them on their own rhythm
	var rock_spacing = (HARVEST_SPAN_END - HARVEST_SPAN_START) / float(ROCK_COUNT)
	for i in range(ROCK_COUNT):
		var x = HARVEST_SPAN_START + (i + 0.15) * rock_spacing + jrng.randf_range(-rock_spacing * 0.25, rock_spacing * 0.25)
		spawn_harvest_node("rock", x)
	# a small grove and outcrop just before the village gate
	for i in range(3):
		spawn_harvest_node("tree", GROVE_START_X + i * 120.0 + jrng.randf_range(-25.0, 25.0))
	for i in range(2):
		spawn_harvest_node("rock", GROVE_START_X + 60.0 + i * 200.0 + jrng.randf_range(-25.0, 25.0))
	# THE WILDS WERE BARREN (dev report 2026-07-21: "I don't see random trees
	# or stone mining places"). Harvestables stopped at x=4300 -- the east's
	# 33,000px had not one tree or seam. Now the whole world is forageable:
	# scattered singles with occasional DENSE groves and outcrop clusters, so
	# gathering out east is a reason to travel, not a lap around the village.
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x7EEE5
	var x := 6200.0
	while x < WORLD_RIGHT - 500.0:
		var roll := rng.randf()
		if roll < 0.14:
			# a grove: 4-6 trees close together
			for i in range(rng.randi_range(4, 6)):
				spawn_harvest_node("tree", x + i * rng.randf_range(70.0, 110.0))
			x += 700.0
		elif roll < 0.24:
			# a stone outcrop: 2-4 seams
			for i in range(rng.randi_range(2, 4)):
				spawn_harvest_node("rock", x + i * rng.randf_range(90.0, 140.0))
			x += 600.0
		elif roll < 0.62:
			spawn_harvest_node("tree", x)
		elif roll < 0.86:
			spawn_harvest_node("rock", x)
		x += rng.randf_range(320.0, 620.0)

func spawn_harvest_node(kind: String, x: float) -> void:
	# the id ticks on every CALL (skipped spawns included), so it depends only
	# on the fixed spawn order -- stable across builds, per-node state hangs off it
	_harvest_id_seq += 1
	# nothing roots over the cave: the rock mound is scenery the tree would
	# clip through, and the arch is the way in. Skip the whole mound footprint,
	# not just the mouth -- the original grove/rock span (-350..4300) overlaps
	# it, so a tree could otherwise sprout out of the cave's shoulder.
	if x >= UNDERDARK_SCRIPT.MOUND_LEFT - 40.0 and x <= UNDERDARK_SCRIPT.MOUND_RIGHT + 40.0:
		return
	var node = HARVEST_NODE_SCRIPT.new()
	node.node_type = kind
	node.state_id = "hv_%s_%d" % [kind, _harvest_id_seq]
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
	# dev call 2026-07-21: mines halved everywhere -- every OTHER platform
	# zone gets one now, so the climb still bites without being a minefield
	var zone_i := -1
	for zone in TRAP_PLATFORM_ZONES:
		zone_i += 1
		if zone_i % 2 == 1:
			continue
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
	#
	# DEV CALL (2026-07-20): the painted PixelLab backdrop is RETIRED for now --
	# its busy plates swallowed the small NPC sprites ("i don't see any npc at
	# all") and the dev wants something better made later. Files stay on disk
	# (no-deletion rule); flip this to bring it back for comparison.
	const USE_PAINTED_BACKDROP := false
	if USE_PAINTED_BACKDROP and ResourceLoader.exists(BACKDROP_PLATES[0]):
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
	# Filler ridges FIRST, so the seven authored village zones still draw in front
	# of them and the approved village skyline is unchanged.
	_extend_ridges_across_world()
	for zone in MOUNTAIN_ZONES:
		var mountain = Polygon2D.new()
		mountain.position = Vector2(zone.x, MOUNTAIN_Y)
		mountain.color = zone.color
		mountain.polygon = generate_mountain_shape(zone.width, zone.height, zone.peaks)
		mountain.z_index = MOUNTAIN_Z
		$Background/Mountains.add_child(mountain)

# THE MAP HAD NO BACKDROP PAST THE VILLAGE (sweep 2026-07-21). MOUNTAIN_ZONES is
# seven hand-placed ridges that end at x~7650 -- but the world runs to 38000, so
# roughly four fifths of Deepwood was flat sky bands with nothing behind them.
# It only ever looked right because the painted-plate path (now retired by dev
# call) used to tile the whole span; when that was switched off, the fallback
# never covered the same ground.
#
# Continue the authored style out to the right edge: same palette, same shape
# generator, ridges overlapping so they interlock instead of standing as islands.
# Seeded, so the skyline is identical every run and in every save.
const RIDGE_SEED = 0xDEE9

func _extend_ridges_across_world() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = RIDGE_SEED
	var palette: Array = []
	for zone in MOUNTAIN_ZONES:
		palette.append(zone.color)
	var x := WORLD_LEFT - 600.0
	var i := 0
	while x < WORLD_RIGHT + 600.0:
		var w: float = rng.randf_range(760.0, 1520.0)
		var ridge := Polygon2D.new()
		ridge.position = Vector2(x, MOUNTAIN_Y)
		# alternate near/far bands so the skyline reads as layered, not a fence
		var far: bool = i % 2 == 1
		ridge.color = palette[rng.randi_range(0, palette.size() - 1)]
		if far:
			ridge.color = ridge.color.lightened(0.12)
		ridge.polygon = generate_mountain_shape(w,
			rng.randf_range(300.0, 620.0) if far else rng.randf_range(520.0, 900.0),
			rng.randi_range(2, 4))
		ridge.z_index = MOUNTAIN_Z
		$Background/Mountains.add_child(ridge)
		x += w * rng.randf_range(0.42, 0.66)   # overlap, so no gaps open up
		i += 1

# The sky bands are authored in main.tscn, and were authored back when the world
# ended at x=19000. When the map was extended they stayed put, so the entire
# right half of Deepwood had no sky behind it at all -- just the viewport's grey
# clear colour. Stretch them across the real world span at load, so lengthening
# the map can never strand the sky again.
# NOTHING EVER FENCED THE CAMERA (sweep 2026-07-21). There is not a single
# limit_left/right anywhere in the project, so the camera simply centres on the
# player -- and at either end of the map that put half a screen of out-of-world
# on display: no sky, no ground, just the viewport's grey clear colour down one
# side. Walk to the west edge of the village and you could see the world end.
func fence_the_camera() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p == null or not p.has_node("Camera2D"):
		return
	var cam: Camera2D = p.get_node("Camera2D")
	cam.limit_left = int(WORLD_LEFT)
	cam.limit_right = int(WORLD_RIGHT)

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
	# THE EARTH WAS 46 PIXELS THICK (sweep 2026-07-21). The camera sees ~324px
	# below the player, so under the village's thin crust sat a strip of stray
	# sky band and then flat viewport grey -- the clear colour, for the bottom
	# fifth of the screen, everywhere in the overworld. The tile repeats, so
	# depth is free.
	s2.region_rect = Rect2(0, 0, span, UNDERGROUND_DEPTH)
	s2.position = Vector2(WORLD_LEFT, fill_top)
	$Ground.add_child(s2)

# Dress the floating one-way JUMP platforms (Ground2..6) in the SAME grass+earth
# tiles as the main ground (dev 2026-07-23, seen with EYES: they read as flat dark
# slabs floating at night). Reuses the ground tileset -- no new art, honors the
# freeze -- so a platform reads as a chunk of the same terrain, grass on top.
const SURFACE_PLATFORMS := ["Ground2", "Ground3", "Ground4", "Ground5", "Ground6"]

func build_platform_skins() -> void:
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
	var surf: ImageTexture = mk_tile.call(96, 0)     # grass-capped surface tile
	var fill: ImageTexture = mk_tile.call(64, 32)    # solid earth fill tile
	var pad := _tile_top_padding(img, 96, 0)
	for pname in SURFACE_PLATFORMS:
		var body = get_node_or_null(pname)
		if body == null:
			continue
		var rect: ColorRect = body.get_node_or_null("ColorRect")
		if rect == null:
			continue
		var w: float = rect.size.x
		var h: float = rect.size.y
		var tl: Vector2 = rect.position
		# earth body first (behind), full platform height...
		var earth := Sprite2D.new()
		earth.texture = fill
		earth.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		earth.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		earth.centered = false
		earth.region_enabled = true
		earth.region_rect = Rect2(0, 0, w, h)
		earth.position = tl
		earth.z_index = 0
		body.add_child(earth)
		# ...then the grass cap on top, hoisted by the tile's padding so the GRASS
		# lands right on the platform's walk surface (same trick as the ground)
		var cap := Sprite2D.new()
		cap.texture = surf
		cap.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		cap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		cap.centered = false
		cap.region_enabled = true
		cap.region_rect = Rect2(0, 0, w, 32)
		cap.position = Vector2(tl.x, tl.y - float(pad))
		cap.z_index = 1
		body.add_child(cap)
		rect.visible = false

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
