extends Node2D

# Dungeons are a real separate scene the player is teleported into (see
# level_select_ui.gd), roughly half the width of the overworld combat
# course. Layouts cycle every 5 levels: (level-1)%5 gives 0-3 for one of 4
# regular platform arrangements, or exactly 4 on every 5th level (5, 10,
# 15...), which uses ONE unique boss arena layout instead.
const DUNGEON_WIDTH = 2600.0
const GROUND_Y = -39.0
const CEILING_Y = -480.0
const ENTRY_X = 140.0

const REGULAR_LAYOUTS = [
	# 0 -- "Ascending Steps": a rough staircase climbing left to right.
	[
		{"x": 320.0, "y": -120.0, "w": 180.0},
		{"x": 640.0, "y": -200.0, "w": 160.0},
		{"x": 980.0, "y": -280.0, "w": 160.0},
		{"x": 1380.0, "y": -220.0, "w": 200.0},
		{"x": 1780.0, "y": -140.0, "w": 180.0},
		{"x": 2160.0, "y": -260.0, "w": 160.0},
	],
	# 1 -- "Scattered Isles": small floating platforms, wider gaps.
	[
		{"x": 260.0, "y": -160.0, "w": 120.0},
		{"x": 530.0, "y": -260.0, "w": 100.0},
		{"x": 830.0, "y": -180.0, "w": 140.0},
		{"x": 1160.0, "y": -320.0, "w": 110.0},
		{"x": 1490.0, "y": -200.0, "w": 130.0},
		{"x": 1860.0, "y": -300.0, "w": 120.0},
		{"x": 2210.0, "y": -180.0, "w": 140.0},
	],
	# 2 -- "Twin Ledges over a Pit": symmetric flanking ledges, high spine.
	[
		{"x": 230.0, "y": -140.0, "w": 220.0},
		{"x": 570.0, "y": -240.0, "w": 160.0},
		{"x": 1300.0, "y": -340.0, "w": 200.0},
		{"x": 2030.0, "y": -240.0, "w": 160.0},
		{"x": 2370.0, "y": -140.0, "w": 220.0},
	],
	# 3 -- "Long Overwatch": one long high spine over lower stepping stones.
	[
		{"x": 1300.0, "y": -300.0, "w": 700.0},
		{"x": 360.0, "y": -150.0, "w": 150.0},
		{"x": 760.0, "y": -190.0, "w": 130.0},
		{"x": 1900.0, "y": -190.0, "w": 130.0},
		{"x": 2300.0, "y": -150.0, "w": 150.0},
	],
]
const BOSS_LAYOUT = [
	{"x": 500.0, "y": -220.0, "w": 320.0},
	{"x": 2100.0, "y": -220.0, "w": 320.0},
]

# Boss identity per level. The six standard bosses CYCLE through the regular
# boss levels (5..90); the apex bosses are the game's UNIQUE finale gauntlet --
# Seraphiel at 95, then three back-to-back boss levels 98 / 99 / 100 that
# escalate to The Fallen Wizard, the hardest fight in the game. Ids MUST match
# boss.gd's BOSSES and the BOSS_ARENAS keys below.
const CYCLING_BOSSES = ["gravewarden", "frost_monarch", "cinder_colossus", "weaver", "stormcaller", "void_sovereign"]
const FINALE_BOSSES = {95: "seraph", 98: "leviathan", 99: "eclipse", 100: "wizard"}

# The deepest N boss levels have NO weapon counter (mastery of every weapon is
# required); only the shallower boss levels get a countering weapon assigned.
const COUNTER_IMMUNE_TAIL = 12
# Fixed-order counter assignment for the counterable boss levels, built once in
# _ready(). Deterministic (seeded) so a given level always has the same
# matchup, and constrained so the same weapon never counters 4 bosses in a row.
var boss_counter_seq: Array = []

# One bespoke arena per boss: its own platform layout, background gradient, and
# torch/accent color, so each boss fight looks and plays differently.
const BOSS_ARENAS = {
	# Tomb of the Warden -- two big flanking ledges + a low central island;
	# earthy green. Room to bait its slam/charge and dodge summoned adds.
	"gravewarden": {
		"width": 7800.0, "height": -780.0,
		"bg_top": Color(0.05, 0.08, 0.05, 1.0), "bg_bottom": Color(0.09, 0.15, 0.08, 1.0),
		"accent": Color(0.6, 1.0, 0.45, 1.0),
	},
	# Frozen Cathedral -- many scattered high platforms; you must keep moving
	# across them to dodge its icicle rain and frost novas. Cold blue.
	"frost_monarch": {
		"width": 10400.0, "height": -900.0,
		"bg_top": Color(0.03, 0.06, 0.12, 1.0), "bg_bottom": Color(0.06, 0.12, 0.2, 1.0),
		"accent": Color(0.6, 0.85, 1.0, 1.0),
	},
	# Molten Foundry -- narrow stepping stones over wide gaps; punishing for a
	# charging, pillar-erupting bruiser. Fiery red/orange.
	"cinder_colossus": {
		"width": 7800.0, "height": -820.0,
		"bg_top": Color(0.12, 0.02, 0.01, 1.0), "bg_bottom": Color(0.22, 0.05, 0.02, 1.0),
		"accent": Color(1.0, 0.5, 0.15, 1.0),
	},
	# Silken Hollow -- stacked ledges on each side + a high central perch the
	# summoner retreats to. Venomous purple.
	"weaver": {
		"width": 10400.0, "height": -940.0,
		"bg_top": Color(0.08, 0.03, 0.12, 1.0), "bg_bottom": Color(0.14, 0.06, 0.2, 1.0),
		"accent": Color(1.0, 0.4, 0.9, 1.0),
	},
	# Storm Spire -- a symmetric tiered arena; nowhere is safe from radial
	# novas for long. Electric yellow.
	"stormcaller": {
		"width": 10400.0, "height": -900.0,
		"bg_top": Color(0.1, 0.09, 0.02, 1.0), "bg_bottom": Color(0.18, 0.16, 0.05, 1.0),
		"accent": Color(1.0, 1.0, 0.6, 1.0),
	},
	# The Void Throne -- sparse floating islands over the abyss; the hardest
	# boss teleports between them. Near-black violet.
	"void_sovereign": {
		"width": 13000.0, "height": -1000.0,
		"bg_top": Color(0.04, 0.02, 0.08, 1.0), "bg_bottom": Color(0.1, 0.04, 0.16, 1.0),
		"accent": Color(0.8, 0.3, 1.0, 1.0),
	},
	# ----- APEX TIER (levels 35 / 40 / 45) -----
	# Endgame monsters designed for a player with flight / grapple relics.
	# The tallest, widest arenas in the game, and the bosses fly or fill them.
	# Shattered Sanctum -- a ruined sky-cathedral for the flying Seraph:
	# columned stacks to climb and high floating isles to fight around.
	"seraph": {
		"width": 10400.0, "height": -1200.0,
		"bg_top": Color(0.14, 0.12, 0.06, 1.0), "bg_bottom": Color(0.22, 0.18, 0.1, 1.0),
		"accent": Color(1.0, 0.95, 0.6, 1.0),
	},
	# Drowned Abyss -- a vast flooded cavern for the sky-serpent: three thin
	# altitude bands of perches over nothing; its vortex drags you off them.
	"leviathan": {
		"width": 13000.0, "height": -1100.0,
		"bg_top": Color(0.01, 0.06, 0.08, 1.0), "bg_bottom": Color(0.03, 0.12, 0.14, 1.0),
		"accent": Color(0.3, 0.95, 0.85, 1.0),
	},
	# Black Sun Crater -- a colossal impact bowl for the Eclipse Titan: platform
	# rows rise in tiers toward both rims; its arena-wide eclipse beam forces
	# constant altitude changes. Ash black and dying red.
	"eclipse": {
		"width": 13000.0, "height": -1300.0,
		"bg_top": Color(0.05, 0.01, 0.02, 1.0), "bg_bottom": Color(0.12, 0.03, 0.04, 1.0),
		"accent": Color(1.0, 0.25, 0.15, 1.0),
	},
	# Sanctum of the Fallen -- level 100, The Fallen Wizard's spell-hall: the
	# largest arena in the game. Ascending "spell circle" platforms spiral to
	# both sides of a grand central dais; sickly green witchlight.
	"wizard": {
		"width": 13000.0, "height": -1400.0,
		"bg_top": Color(0.03, 0.02, 0.07, 1.0), "bg_bottom": Color(0.08, 0.05, 0.14, 1.0),
		"accent": Color(0.55, 1.0, 0.5, 1.0),
	},
}

const PLATFORM_HEIGHT = 20.0
const PLATFORM_COLOR = Color(0.3, 0.26, 0.24, 1.0)

const MIN_MINES = 8
const MAX_MINES = 14
const BOSS_MIN_MINES = 10
const BOSS_MAX_MINES = 16
const MINE_SAFE_ZONE = 220.0
const TRAP_SCENE = preload("res://trap.tscn")

const ENEMY_SCENE = preload("res://enemy.tscn")
const BOSS_SCENE = preload("res://boss.tscn")
const VILLAGER_SCENE = preload("res://villager.tscn")
const SPECIAL_MOB_SCRIPT = preload("res://special_mob.gd")
const WEAPON_TYPES = ["sword", "spear", "bow"]
const HP_SCALE_PER_LEVEL = 0.15
const DMG_SCALE_PER_LEVEL = 0.10
const SPEED_SCALE_PER_LEVEL = 0.075
const SPEED_SCALE_CAP_LEVEL = 25
# Past a soft-cap level the HP and DAMAGE curves flatten to a gentler slope.
# The old straight lines meant L100 dealt ~11x damage (a beam one-shot any
# player) and bosses had ~16x HP (60k+ sponges); these keep the deepest
# levels tense and winnable instead. At L100: HP ~5.5x, DMG ~5.3x.
const HP_SOFTCAP_LEVEL = 20
const HP_SCALE_AFTER = 0.02
const DMG_SOFTCAP_LEVEL = 30
const DMG_SCALE_AFTER = 0.02
const LEVEL_CLEAR_DELAY = 2.5
const MAX_LEVEL = 100

const BG_TOP_COLOR = Color(0.03, 0.025, 0.05, 1.0)
const BG_BOTTOM_COLOR = Color(0.09, 0.06, 0.11, 1.0)
const BOSS_BG_TOP_COLOR = Color(0.09, 0.015, 0.015, 1.0)
const BOSS_BG_BOTTOM_COLOR = Color(0.17, 0.035, 0.03, 1.0)
const WALL_COLOR_FAR = Color(0.09, 0.07, 0.11, 1.0)
const WALL_COLOR_NEAR = Color(0.14, 0.11, 0.16, 1.0)
const TORCH_SPACING = 380.0
const TORCH_COLOR = Color(1.0, 0.55, 0.15, 1.0)
const STALACTITE_COLOR = Color(0.11, 0.09, 0.13, 1.0)

var music: AudioStreamWAV = preload("res://audio/dungeon_music.wav")

# pause_menu.gd (shared with the overworld) reads these off whichever node
# is named "DungeonManager" -- this scene's root plays that role here, and
# unlike the overworld's stub, a dungeon run really IS always active while
# this scene is loaded.
var started = true
var starting = false
var current_level = 1
var alive_count = 0
var level_in_progress = false
# set once the current level's combat is fully cleared -- this is what arms
# the forward gate (advancing is a manual walk through it now, never automatic)
var level_cleared = false
# The playfield width/ceiling of the CURRENT level. Regular levels use
# DUNGEON_WIDTH / CEILING_Y; boss levels are much wider AND taller (see each
# arena's "width"/"height"), so the whole build pipeline (ground, walls,
# torches, mines, gates, spawns) reads these instead of the constants. Both
# are set at the top of build_level_visuals().
var current_width := DUNGEON_WIDTH
var current_ceiling := CEILING_Y

const GATE_SCRIPT = preload("res://dungeon_gate.gd")

func _ready() -> void:
	GameState.in_dungeon = true
	boss_counter_seq = build_counter_sequence()
	current_level = GameState.active_dungeon_level
	build_level_visuals(current_level)
	place_player_at_entry(false)
	update_level_label()
	setup_exit_button()
	start_music()
	# no countdown -- combat begins the moment the level loads
	spawn_level_combat()

func setup_exit_button() -> void:
	var exit_button = get_node_or_null("CanvasLayer/ExitDungeonButton")
	if exit_button:
		exit_button.visible = true
		exit_button.pressed.connect(exit_dungeon)

# 10 seconds of 16-bit mono at 44.1kHz -- must match the synthesized file.
const DUNGEON_MUSIC_LOOP_SAMPLES = 441000

func start_music() -> void:
	music.loop_mode = AudioStreamWAV.LOOP_FORWARD
	# loop_end defaults to 0, and a [0,0] loop region plays as pure silence --
	# the loop bounds have to be set explicitly (same as main.gd's music).
	music.loop_begin = 0
	music.loop_end = DUNGEON_MUSIC_LOOP_SAMPLES
	$MusicPlayer.stream = music
	$MusicPlayer.bus = "Music"   # controlled by the Music volume slider
	$MusicPlayer.play()

# --- layout selection ---

func get_layout_slot(level: int) -> int:
	return (level - 1) % 5

func is_boss_level(level: int) -> bool:
	# every 5th level, plus the back-to-back finale gauntlet at 98 and 99
	return get_layout_slot(level) == 4 or level >= MAX_LEVEL - 2

func get_layout(level: int) -> Array:
	if is_boss_level(level):
		var arena = get_boss_arena(level)
		return generate_boss_platforms(get_boss_id(level), arena.get("width", DUNGEON_WIDTH), arena.get("height", CEILING_Y))
	return REGULAR_LAYOUTS[get_layout_slot(level)]

func total_boss_levels() -> int:
	return int(MAX_LEVEL / 5)

# Finale levels (95/98/99/100) use their reserved unique boss; every other
# boss level cycles the six standard bosses.
func get_boss_id(level: int) -> String:
	if FINALE_BOSSES.has(level):
		return FINALE_BOSSES[level]
	var n = int(level / 5)
	return CYCLING_BOSSES[max(0, n - 1) % CYCLING_BOSSES.size()]

# Which weapon (if any) counters the boss on this level. "" for the deep,
# counter-immune levels. Sequence is precomputed in build_counter_sequence().
func get_boss_counter(level: int) -> String:
	var n = int(level / 5)
	if n >= 1 and n <= boss_counter_seq.size():
		return boss_counter_seq[n - 1]
	return ""

func build_counter_sequence() -> Array:
	var count = max(0, total_boss_levels() - COUNTER_IMMUNE_TAIL)
	var rng = RandomNumberGenerator.new()
	rng.seed = 0x5EED           # fixed: matchup order is stable across runs
	var roles = ["sword", "archer", "mage"]
	var seq: Array = []
	for i in range(count):
		var choices = roles.duplicate()
		# never let the same weapon counter a 4th boss in a row
		if seq.size() >= 3 and seq[-1] == seq[-2] and seq[-2] == seq[-3]:
			choices.erase(seq[-1])
		seq.append(choices[rng.randi() % choices.size()])
	return seq

func get_boss_arena(level: int) -> Dictionary:
	return BOSS_ARENAS.get(get_boss_id(level), {})

func get_level_width(level: int) -> float:
	if is_boss_level(level):
		return get_boss_arena(level).get("width", DUNGEON_WIDTH)
	return DUNGEON_WIDTH

func get_level_ceiling(level: int) -> float:
	if is_boss_level(level):
		return get_boss_arena(level).get("height", CEILING_Y)
	return CEILING_Y

# --- boss arena platform generators ---
#
# Each boss gets a hand-designed platform pattern that plays into its kit,
# scaled across its (much larger) arena width AND height. The ground is always
# continuous so the fight is winnable on foot; the platforms are an advantage
# the player earns with mobility (and mobility gear), never a requirement.
# Low rows are tiered in ~80px steps so they're reachable without a double
# jump; the upper tiers (add_sky_tier and the apex arenas) assume late-game
# flight/grapple relics and give airborne players terrain to fight around.

func generate_boss_platforms(boss_id: String, w: float, h: float) -> Array:
	match boss_id:
		"gravewarden": return gen_gravewarden(w, h)
		"frost_monarch": return gen_frost(w, h)
		"cinder_colossus": return gen_cinder(w, h)
		"weaver": return gen_weaver(w, h)
		"stormcaller": return gen_stormcaller(w, h)
		"void_sovereign": return gen_void(w, h)
		"seraph": return gen_seraph(w, h)
		"leviathan": return gen_leviathan(w, h)
		"eclipse": return gen_eclipse(w, h)
		"wizard": return gen_wizard(w, h)
		_: return gen_gravewarden(w, h)

# A sparse band of high platforms between mid-air and the arena ceiling --
# stitched onto every boss arena so the vertical space is usable terrain, not
# empty air. Staggered heights, wide gaps: flight/grapple territory.
func add_sky_tier(plats: Array, w: float, h: float, spacing: float = 900.0) -> Array:
	var top = h + 160.0            # just under the ceiling
	var mid = h * 0.55             # roughly halfway up the arena
	var i := 0
	var x := 700.0
	while x < w - 700.0:
		var y = mid if i % 2 == 0 else top
		plats.append({"x": x, "y": y, "w": 170.0})
		x += spacing
		i += 1
	return plats

# Gravewarden -- a melee bruiser (slam/charge/summon). Long open ground for its
# charge lanes, broken by a steady run of low ledges you hop onto to escape the
# slam radius and shoot down at it, plus one big central island to make a stand.
func gen_gravewarden(w: float, h: float) -> Array:
	var plats: Array = []
	var i := 0
	var x := 560.0
	while x < w - 560.0:
		if i % 2 == 0:
			plats.append({"x": x, "y": -120.0, "w": 210.0})
		else:
			plats.append({"x": x, "y": -205.0, "w": 150.0})
		x += 470.0
		i += 1
	plats.append({"x": w / 2.0, "y": -175.0, "w": 380.0})
	# a third climbing row so the taller tomb isn't empty above the ledges
	x = 800.0
	while x < w - 800.0:
		plats.append({"x": x, "y": -330.0, "w": 140.0})
		x += 940.0
	return add_sky_tier(plats, w, h)

# Frost Monarch -- a ranged caster (icicle rain/nova/teleport). A dense field of
# scattered platforms at many heights: you must keep hopping to stay out of nova
# range and off the marked rain columns, with height to close on the caster.
func gen_frost(w: float, h: float) -> Array:
	var plats: Array = []
	var ys := [-140.0, -230.0, -320.0, -235.0, -300.0, -175.0]
	var i := 0
	var x := 480.0
	while x < w - 480.0:
		plats.append({"x": x, "y": ys[i % ys.size()], "w": 130.0})
		x += 430.0
		i += 1
	# a second scattered field higher up -- the cathedral's broken galleries
	var ys_hi := [-430.0, -520.0, -470.0, -560.0]
	i = 0
	x = 650.0
	while x < w - 650.0:
		plats.append({"x": x, "y": ys_hi[i % ys_hi.size()], "w": 120.0})
		x += 640.0
		i += 1
	return add_sky_tier(plats, w, h, 1050.0)

# Cinder Colossus -- charge/fan/pillars. Narrow stepping stones over wide gaps:
# great for the player to break its charges on, but every few steps a bigger
# island tempts you to stand still right where its pillars erupt.
func gen_cinder(w: float, h: float) -> Array:
	var plats: Array = []
	var i := 0
	var x := 600.0
	while x < w - 600.0:
		if i % 5 == 2:
			plats.append({"x": x, "y": -255.0, "w": 190.0})
		elif i % 2 == 0:
			plats.append({"x": x, "y": -140.0, "w": 115.0})
		else:
			plats.append({"x": x, "y": -230.0, "w": 115.0})
		x += 545.0
		i += 1
	# foundry gantries: a high sparse walkway row above the stepping stones
	x = 950.0
	while x < w - 950.0:
		plats.append({"x": x, "y": -400.0, "w": 210.0})
		x += 1150.0
	return add_sky_tier(plats, w, h)

# Weaver -- a summoner (summon/nova/teleport) that wants a high perch. A tall
# central platform it retreats to, symmetric climbing ledges so you CAN chase it
# up, side stacks by both doors, and low stepping stones so the wide floor where
# its adds funnel is still crossable.
func gen_weaver(w: float, h: float) -> Array:
	var plats: Array = []
	var c := w / 2.0
	plats.append({"x": c, "y": -375.0, "w": 240.0})
	for pair in [[520.0, -290.0, 150.0], [1040.0, -210.0, 160.0], [1560.0, -125.0, 180.0]]:
		plats.append({"x": c - pair[0], "y": pair[1], "w": pair[2]})
		plats.append({"x": c + pair[0], "y": pair[1], "w": pair[2]})
	for sx in [660.0, w - 660.0]:
		plats.append({"x": sx, "y": -160.0, "w": 200.0})
		plats.append({"x": sx, "y": -300.0, "w": 150.0})
	var x := 900.0
	while x < w - 900.0:
		if absf(x - c) > 320.0:
			plats.append({"x": x, "y": -120.0, "w": 150.0})
		x += 720.0
	# the web above: a second perch layer strung over the central one
	plats.append({"x": c, "y": -560.0, "w": 190.0})
	plats.append({"x": c - 800.0, "y": -480.0, "w": 150.0})
	plats.append({"x": c + 800.0, "y": -480.0, "w": 150.0})
	return add_sky_tier(plats, w, h, 1000.0)

# Stormcaller -- radial novas/pillars/fan. A symmetric tiered arena mirrored
# about the center: pockets of safety exist between the rings, but there is no
# lasting cover from a 360 burst, so you are always rotating outward.
func gen_stormcaller(w: float, h: float) -> Array:
	var plats: Array = []
	var c := w / 2.0
	plats.append({"x": c, "y": -200.0, "w": 260.0})
	for r in [[720.0, -285.0, 160.0], [1440.0, -175.0, 200.0], [2160.0, -300.0, 160.0], [2880.0, -190.0, 200.0], [3600.0, -140.0, 180.0]]:
		if c - r[0] > 320.0:
			plats.append({"x": c - r[0], "y": r[1], "w": r[2]})
			plats.append({"x": c + r[0], "y": r[1], "w": r[2]})
	var x := 700.0
	while x < w - 700.0:
		if absf(x - c) > 400.0:
			plats.append({"x": x, "y": -120.0, "w": 140.0})
		x += 760.0
	# high mirrored storm-rings continuing the pattern upward
	for r in [[1080.0, -430.0, 150.0], [2520.0, -470.0, 150.0]]:
		if c - r[0] > 320.0:
			plats.append({"x": c - r[0], "y": r[1], "w": r[2]})
			plats.append({"x": c + r[0], "y": r[1], "w": r[2]})
	return add_sky_tier(plats, w, h)

# Void Sovereign -- the hardest, a teleporter (teleport/rain/nova/summon). Sparse
# islands strung far apart over the abyss at wildly varying heights; it blinks
# between them freely while you make long, committed jumps to follow.
func gen_void(w: float, h: float) -> Array:
	var plats: Array = []
	var ys := [-170.0, -320.0, -250.0, -365.0, -220.0, -300.0]
	var i := 0
	var x := 620.0
	while x < w - 620.0:
		plats.append({"x": x, "y": ys[i % ys.size()], "w": 150.0})
		x += 760.0
		i += 1
	plats.append({"x": w / 2.0, "y": -360.0, "w": 200.0})
	# drifting shards higher in the void, offset from the lower islands
	var ys_hi := [-520.0, -610.0, -560.0]
	i = 0
	x = 1000.0
	while x < w - 1000.0:
		plats.append({"x": x, "y": ys_hi[i % ys_hi.size()], "w": 130.0})
		x += 980.0
		i += 1
	return add_sky_tier(plats, w, h, 1100.0)

# ----- apex arena generators -----

# Seraph -- Shattered Sanctum. A flying boss that dives and rains light: the
# arena is a ruined cathedral of columned stacks (three-step towers you can
# climb even without relics) with floating isles between their tops, giving an
# airborne player cover rings at every altitude.
func gen_seraph(w: float, h: float) -> Array:
	var plats: Array = []
	var x := 700.0
	var i := 0
	while x < w - 700.0:
		# column: a climbable three-step tower
		plats.append({"x": x, "y": -150.0, "w": 190.0})
		plats.append({"x": x + 60.0, "y": -300.0, "w": 150.0})
		plats.append({"x": x - 60.0, "y": -450.0, "w": 150.0})
		# isles drifting between the column tops, alternating heights
		if i % 2 == 0:
			plats.append({"x": x + 560.0, "y": -620.0, "w": 130.0})
		else:
			plats.append({"x": x + 560.0, "y": -760.0, "w": 130.0})
		x += 1120.0
		i += 1
	# the broken nave roof: a thin ridge just under the ceiling
	plats.append({"x": w / 2.0, "y": h + 200.0, "w": 300.0})
	plats.append({"x": w / 2.0 - 1400.0, "y": h + 260.0, "w": 170.0})
	plats.append({"x": w / 2.0 + 1400.0, "y": h + 260.0, "w": 170.0})
	return plats

# Leviathan -- Drowned Abyss. A sky-serpent that sweeps and pulls: three thin
# altitude bands of small perches with big empty water between them. Its
# vortex drags you off a perch; the bands mean there's always another one
# below to catch yourself on -- if you're quick.
func gen_leviathan(w: float, h: float) -> Array:
	var plats: Array = []
	var bands := [-170.0, -480.0, -790.0]
	for b in range(bands.size()):
		var x := 600.0 + b * 380.0   # stagger each band so falls are diagonal
		while x < w - 600.0:
			plats.append({"x": x, "y": bands[b], "w": 140.0})
			x += 1150.0
	# a lone high refuge at the center, just under the serpent's cruising line
	plats.append({"x": w / 2.0, "y": h + 220.0, "w": 220.0})
	return plats

# Eclipse Titan -- Black Sun Crater. A colossus whose arena-wide beam forces
# altitude changes: platform rows rise in tiers from the low center toward
# both rims, so wherever the beam locks on there is a row above and below to
# move to. The rims themselves are high ledges for ranged play.
func gen_eclipse(w: float, h: float) -> Array:
	var plats: Array = []
	var c := w / 2.0
	# tiered crater rows, mirrored: farther from center = higher
	var tiers := [[600.0, -150.0], [1400.0, -270.0], [2200.0, -390.0], [3000.0, -510.0], [3800.0, -630.0], [4600.0, -750.0]]
	for t in tiers:
		if c - t[0] > 400.0:
			plats.append({"x": c - t[0], "y": t[1], "w": 200.0})
			plats.append({"x": c + t[0], "y": t[1], "w": 200.0})
	# the crater floor's central slab -- bait for its pillars
	plats.append({"x": c, "y": -140.0, "w": 300.0})
	# rim overlooks near both walls, high above the fight
	plats.append({"x": 800.0, "y": h + 280.0, "w": 240.0})
	plats.append({"x": w - 800.0, "y": h + 280.0, "w": 240.0})
	# scattered ash shards floating over the bowl for airborne cover
	var x := 1600.0
	var i := 0
	while x < w - 1600.0:
		if absf(x - c) > 500.0:
			plats.append({"x": x, "y": (-880.0 if i % 2 == 0 else -1000.0), "w": 140.0})
		x += 1250.0
		i += 1
	return plats

# The Fallen Wizard -- Sanctum of the Fallen (level 100). A teleporting,
# orb-slinging archmage: ascending spell-circle platforms stair-step outward
# and UP from a grand central dais, so chasing him means climbing while his
# curses chase you. Low stepping stones keep the floor route alive, and one
# refuge hangs just under the ceiling for the endgame's flying players.
func gen_wizard(w: float, h: float) -> Array:
	var plats: Array = []
	var c := w / 2.0
	plats.append({"x": c, "y": -180.0, "w": 420.0})   # the grand dais
	# mirrored spell-circles spiraling upward toward both walls
	for ring in [[900.0, -320.0, 170.0], [1800.0, -480.0, 150.0], [2700.0, -640.0, 150.0], [3600.0, -800.0, 150.0], [4500.0, -960.0, 150.0]]:
		if c - ring[0] > 400.0:
			plats.append({"x": c - ring[0], "y": ring[1], "w": ring[2]})
			plats.append({"x": c + ring[0], "y": ring[1], "w": ring[2]})
	# low stepping stones so the ground fight can cross the huge hall
	var x := 800.0
	while x < w - 800.0:
		if absf(x - c) > 500.0:
			plats.append({"x": x, "y": -140.0, "w": 150.0})
		x += 900.0
	plats.append({"x": c, "y": h + 220.0, "w": 260.0})   # ceiling refuge
	return plats

# --- level (re)building ---

func build_level_visuals(level: int) -> void:
	for child in $LevelContainer.get_children():
		child.queue_free()
	var boss = is_boss_level(level)
	var arena = get_boss_arena(level) if boss else {}
	current_width = get_level_width(level)
	current_ceiling = get_level_ceiling(level)
	build_background(boss, arena)
	build_ground_and_walls()
	var layout = get_layout(level)
	build_platforms(layout)
	build_stalactites(boss)
	build_torches(boss, arena)
	place_mines(boss, layout)
	build_gates()

func build_gates() -> void:
	var back_gate = GATE_SCRIPT.new()
	back_gate.direction = "back"
	back_gate.manager = self
	back_gate.position = Vector2(46.0, GROUND_Y)
	$LevelContainer.add_child(back_gate)
	var forward_gate = GATE_SCRIPT.new()
	forward_gate.direction = "forward"
	forward_gate.manager = self
	forward_gate.position = Vector2(current_width - 46.0, GROUND_Y)
	$LevelContainer.add_child(forward_gate)

# Both gates funnel through here. Back: level 1 leaves the dungeon, deeper
# levels retreat one (usable any time, even mid-fight, as an escape hatch).
# Forward: locked until the level is cleared; on the final level it exits.
func on_gate_used(direction: String) -> void:
	if direction == "back":
		if current_level <= 1:
			exit_dungeon()
		else:
			go_to_level(current_level - 1, true)
		return
	if not level_cleared:
		show_notification("The way down is sealed -- clear this level first!")
		return
	if current_level >= MAX_LEVEL:
		show_notification("All " + str(MAX_LEVEL) + " dungeon levels cleared!")
		exit_dungeon()
	else:
		go_to_level(current_level + 1, false)

func go_to_level(level: int, enter_from_right: bool) -> void:
	current_level = level
	build_level_visuals(current_level)
	place_player_at_entry(enter_from_right)
	spawn_level_combat()

func build_background(boss: bool, arena: Dictionary = {}) -> void:
	var top_color = arena.get("bg_top", BOSS_BG_TOP_COLOR) if boss else BG_TOP_COLOR
	var bottom_color = arena.get("bg_bottom", BOSS_BG_BOTTOM_COLOR) if boss else BG_BOTTOM_COLOR
	# the upper gradient band stretches from well above the ceiling down to
	# -400 where the lower band takes over, whatever the arena's height
	var sky_top_y = current_ceiling - 500.0
	var sky_top = ColorRect.new()
	sky_top.color = top_color
	sky_top.z_index = -100
	sky_top.position = Vector2(-150, sky_top_y)
	sky_top.size = Vector2(current_width + 300, -400.0 - sky_top_y)
	$LevelContainer.add_child(sky_top)
	var sky_bottom = ColorRect.new()
	sky_bottom.color = bottom_color
	sky_bottom.z_index = -100
	sky_bottom.position = Vector2(-150, -400)
	sky_bottom.size = Vector2(current_width + 300, 400)
	$LevelContainer.add_child(sky_bottom)
	build_wall_layer(-90.0, 240.0, 5, WALL_COLOR_FAR, -95)
	build_wall_layer(-55.0, 170.0, 6, WALL_COLOR_NEAR, -90)

# A jagged ridge silhouette, reusing the same "a few random peaks blended
# with falloff, plus fine jitter" technique that made the overworld
# mountains read as natural rather than random zigzag -- here inverted to
# hang from the ceiling as cave-wall texture.
func build_wall_layer(y_offset: float, height: float, peak_count: int, color: Color, z: int) -> void:
	var points = PackedVector2Array()
	var segments = max(peak_count * 6, 18)
	var peak_positions = []
	var peak_heights = []
	for p in range(peak_count):
		peak_positions.append(randf_range(0.05, 0.95))
		peak_heights.append(randf_range(0.6, 1.0))
	points.append(Vector2(0, y_offset))
	for i in range(1, segments):
		var t = float(i) / float(segments)
		var x = t * current_width
		var influence = 0.0
		for p in range(peak_count):
			var dist = absf(t - peak_positions[p])
			influence = max(influence, max(0.0, 1.0 - dist * 3.2) * peak_heights[p])
		var jitter = 1.0 + randf_range(-0.08, 0.08)
		points.append(Vector2(x, y_offset + height * (0.3 + 0.7 * influence) * jitter))
	points.append(Vector2(current_width, y_offset))
	points.append(Vector2(current_width, current_ceiling - 40.0))
	points.append(Vector2(0, current_ceiling - 40.0))
	var wall = Polygon2D.new()
	wall.polygon = points
	wall.color = color
	wall.z_index = z
	$LevelContainer.add_child(wall)

func build_ground_and_walls() -> void:
	var ground = StaticBody2D.new()
	ground.position = Vector2(current_width / 2.0, GROUND_Y + 40.0)
	var gshape = CollisionShape2D.new()
	var grect = RectangleShape2D.new()
	grect.size = Vector2(current_width + 200.0, 80.0)
	gshape.shape = grect
	ground.add_child(gshape)
	var ground_visual = ColorRect.new()
	ground_visual.size = Vector2(current_width + 200.0, 80.0)
	ground_visual.position = Vector2(-(current_width + 200.0) / 2.0, -40.0)
	ground_visual.color = Color(0.2, 0.17, 0.15, 1.0)
	ground.add_child(ground_visual)
	var ground_top_edge = ColorRect.new()
	ground_top_edge.size = Vector2(current_width + 200.0, 6.0)
	ground_top_edge.position = Vector2(-(current_width + 200.0) / 2.0, -40.0)
	ground_top_edge.color = Color(0.26, 0.22, 0.19, 1.0)
	ground.add_child(ground_top_edge)
	$LevelContainer.add_child(ground)

	build_wall(-40.0)
	build_wall(current_width + 40.0)

func build_wall(x: float) -> void:
	# side walls always run from below the floor up past the arena's ceiling,
	# so a flying player can never slip around the edge of a tall boss arena
	var wall_h = (GROUND_Y + 60.0) - (current_ceiling - 120.0)
	var center_y = (GROUND_Y + 60.0 + current_ceiling - 120.0) / 2.0
	var wall = StaticBody2D.new()
	wall.position = Vector2(x, center_y)
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(20.0, wall_h)
	shape.shape = rect
	wall.add_child(shape)
	var visual = ColorRect.new()
	visual.size = Vector2(20.0, wall_h)
	visual.position = Vector2(-10.0, -wall_h / 2.0)
	visual.color = Color(0.13, 0.1, 0.12, 1.0)
	wall.add_child(visual)
	$LevelContainer.add_child(wall)

func build_platforms(layout: Array) -> void:
	for plat in layout:
		var body = StaticBody2D.new()
		body.position = Vector2(plat.x, plat.y)
		var shape = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = Vector2(plat.w, PLATFORM_HEIGHT)
		shape.shape = rect
		shape.one_way_collision = true
		body.add_child(shape)
		var visual = ColorRect.new()
		visual.size = Vector2(plat.w, PLATFORM_HEIGHT)
		visual.position = Vector2(-plat.w / 2.0, -PLATFORM_HEIGHT / 2.0)
		visual.color = PLATFORM_COLOR
		body.add_child(visual)
		var edge = ColorRect.new()
		edge.size = Vector2(plat.w, 4.0)
		edge.position = Vector2(-plat.w / 2.0, -PLATFORM_HEIGHT / 2.0)
		edge.color = PLATFORM_COLOR.lightened(0.18)
		body.add_child(edge)
		$LevelContainer.add_child(body)

func build_stalactites(boss: bool) -> void:
	var count = int((14 if boss else 10) * (current_width / DUNGEON_WIDTH))
	for i in range(count):
		var x = randf_range(40.0, current_width - 40.0)
		var h = randf_range(30.0, 75.0)
		var w = randf_range(10.0, 22.0)
		var stalactite = Polygon2D.new()
		stalactite.polygon = PackedVector2Array([Vector2(-w / 2.0, 0), Vector2(w / 2.0, 0), Vector2(0, h)])
		stalactite.color = STALACTITE_COLOR.darkened(randf_range(0.0, 0.15))
		stalactite.position = Vector2(x, current_ceiling)
		$LevelContainer.add_child(stalactite)

func make_additive_material() -> CanvasItemMaterial:
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat

func build_torches(boss: bool, arena: Dictionary = {}) -> void:
	var accent = arena.get("accent", TORCH_COLOR) if boss else TORCH_COLOR
	var count = int(current_width / TORCH_SPACING)
	for i in range(count):
		var x = 180.0 + i * TORCH_SPACING + randf_range(-40.0, 40.0)
		build_torch(Vector2(clamp(x, 60.0, current_width - 60.0), GROUND_Y), accent)

func build_torch(pos: Vector2, color: Color = TORCH_COLOR) -> void:
	var torch = Node2D.new()
	torch.position = pos
	$LevelContainer.add_child(torch)

	var pole = ColorRect.new()
	pole.color = Color(0.22, 0.16, 0.11, 1.0)
	pole.size = Vector2(6.0, 30.0)
	pole.position = Vector2(-3.0, -30.0)
	torch.add_child(pole)

	var glow = Polygon2D.new()
	# chunky octagon glow -- squarish pixel-art theme
	var glow_points = PackedVector2Array()
	for i in range(8):
		var angle = (i + 0.5) * TAU / 8.0
		glow_points.append(Vector2(cos(angle), sin(angle)) * 28.0)
	glow.polygon = glow_points
	glow.color = Color(color.r, color.g, color.b, 0.32)
	glow.position = Vector2(0, -38.0)
	glow.material = make_additive_material()
	torch.add_child(glow)

	var flame = Polygon2D.new()
	flame.polygon = PackedVector2Array([Vector2(-5, 0), Vector2(5, 0), Vector2(0, -16)])
	flame.color = color
	flame.position = Vector2(0, -38.0)
	torch.add_child(flame)

	var flicker = flame.create_tween()
	flicker.set_loops()
	flicker.tween_property(flame, "scale", Vector2(1.15, 0.85), randf_range(0.15, 0.25))
	flicker.tween_property(flame, "scale", Vector2(0.88, 1.12), randf_range(0.15, 0.25))
	flicker.tween_property(flame, "scale", Vector2.ONE, randf_range(0.15, 0.25))

func place_mines(boss: bool, layout: Array) -> void:
	var base_count = randi_range(BOSS_MIN_MINES, BOSS_MAX_MINES) if boss else randi_range(MIN_MINES, MAX_MINES)
	var ground_count = int(base_count * (current_width / DUNGEON_WIDTH))
	for i in range(ground_count):
		var x = randf_range(60.0, current_width - 60.0)
		# keep both doorway areas mine-free so entering/leaving is never a trap
		if absf(x - ENTRY_X) < MINE_SAFE_ZONE or absf(x - (current_width - 46.0)) < 150.0:
			continue
		place_mine(Vector2(x, GROUND_Y))
	for plat in layout:
		if randf() < 0.5:
			var x = plat.x + randf_range(-plat.w * 0.3, plat.w * 0.3)
			place_mine(Vector2(x, plat.y))

func place_mine(pos: Vector2) -> void:
	var mine = TRAP_SCENE.instantiate()
	mine.position = pos
	$LevelContainer.add_child(mine)

func place_player_at_entry(enter_from_right: bool) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var x = (current_width - ENTRY_X) if enter_from_right else ENTRY_X
		player.global_position = Vector2(x, GROUND_Y - 100.0)
		player.velocity = Vector2.ZERO

# --- combat flow (mirrors the old overworld dungeon_manager.gd) ---

# A per-level multiplier that grows at `per`/level until `softcap`, then at the
# gentler `after`/level beyond it.
func _softcapped_mult(level: int, per: float, softcap: int, after: float) -> float:
	if level <= softcap:
		return 1.0 + (level - 1) * per
	return 1.0 + (softcap - 1) * per + (level - softcap) * after

func get_level_scaling() -> Dictionary:
	var hp_mult = _softcapped_mult(current_level, HP_SCALE_PER_LEVEL, HP_SOFTCAP_LEVEL, HP_SCALE_AFTER)
	var dmg_mult = _softcapped_mult(current_level, DMG_SCALE_PER_LEVEL, DMG_SOFTCAP_LEVEL, DMG_SCALE_AFTER)
	var speed_level = min(current_level, SPEED_SCALE_CAP_LEVEL)
	var speed_mult = 1.0 + (speed_level - 1) * SPEED_SCALE_PER_LEVEL
	return {"hp": hp_mult, "dmg": dmg_mult, "speed": speed_mult}

func spawn_level_combat() -> void:
	level_in_progress = true
	level_cleared = false
	alive_count = 0
	GameState.record_level_reached(current_level)
	if is_boss_level(current_level):
		var b = spawn_boss()
		var intro = "Level %d - %s awakens!" % [current_level, b.get_display_name()]
		var counter = get_boss_counter(current_level)
		if counter != "":
			intro += "  (weak to %s)" % counter
		show_notification(intro)
	else:
		spawn_level_mobs()
		show_notification("Level " + str(current_level))
	spawn_deep_rescue()
	update_level_label()
	# Level 100: the mask falls. Play the reveal once, at the gate, before the
	# fight (the DialogueBox pauses the tree, so Orin waits until it's done).
	if current_level >= MAX_LEVEL and not GameState.seen_l100_reveal:
		GameState.seen_l100_reveal = true
		call_deferred("play_l100_reveal")

func play_l100_reveal() -> void:
	DialogueBox.play(self, Story.L100_REVEAL)

# Orin is down -- the deathless made mortal for one instant, and the blow landed.
# Play the ending, permanently unlock the Shadow Monarch, and salute the win.
func play_final_victory() -> void:
	GameState.mark_game_completed()
	DialogueBox.play(self, Story.ENDING, func():
		show_notification("Deepwood stands. The Shadow Monarch has returned — a new class awaits your next journey."))

# Deep-level rescues: a reserved important figure (VillagerQuests.IMPORTANT_FIGURES,
# levels 85/90/95) is chained up in this level to be freed with E. Skipped once
# they've been rescued (the roster dedupes, same as village hostages). They add
# to the roster on rescue and their walking avatar appears back in the village.
func spawn_deep_rescue() -> void:
	var figure = VillagerQuests.figure_for_level(current_level)
	if figure.is_empty() or GameState.is_villager_rescued(str(figure.get("villager_id", ""))):
		return
	var v = VILLAGER_SCENE.instantiate()
	v.villager_id = str(figure.get("villager_id", ""))
	v.villager_name = str(figure.get("villager_name", "?"))
	v.stat_name = str(figure.get("stat_name", ""))
	v.stat_value = int(figure.get("stat_value", 0))
	v.role_key = str(figure.get("role_key", ""))
	v.role_title = str(figure.get("role_title", ""))
	v.sex = str(figure.get("sex", "Female"))
	v.backstory = str(figure.get("backstory", ""))
	v.position = Vector2(current_width * 0.5, GROUND_Y - 40.0)
	$LevelContainer.add_child(v)
	show_notification("A captive of note is held here — free them!")

# --- normal-level mob composition ---
#
# Each 5-level block is a crescendo. The variety of mob TYPES ramps with the
# position inside the block (pos 1 -> 2-3 distinct types ... pos 4 -> 5-6),
# and the share of "OP" mobs (teleporters, mages, chargers, bombers) rises
# from ~45% just after a boss to ~75% right before the next one -- averaging
# the intended 60/40 OP-to-annoying split. The very first block is capped
# gentler (~35% OP) while the player learns. Grunts, flyers and spitters make
# up the annoying-but-not-weak 40%.
const OP_KINDS_BASE = ["bomber", "charger"]
const OP_KINDS_MID = ["stalker", "hexer"]                        # from level 5
const OP_KINDS_LATE = ["blink_archer", "runecaster", "warlock"]  # from level 8
const ANNOYING_KINDS = ["grunt", "flyer", "spitter"]
# Levels whose grunt is a downloaded sprite-skin (Orc/Blood Fiend/Demon blocks);
# on these, about half of spawns are grunts so the skinned mob is prominent.
const GRUNT_SKIN_MAX_LEVEL = 15
const GRUNT_SPAWN_BIAS = 0.5
const ELITE_CHANCE = 0.125
const FIRST_BLOCK_OP_CAP = 0.35

func block_position(level: int) -> int:
	return (level - 1) % 5 + 1     # 1..4 = normal levels, 5 = boss

func op_pool_for_level(level: int) -> Array:
	var pool = OP_KINDS_BASE.duplicate()
	if level >= 5:
		pool.append_array(OP_KINDS_MID)
	if level >= 8:
		pool.append_array(OP_KINDS_LATE)
	return pool

func op_fraction(level: int) -> float:
	var p = block_position(level)
	var frac = lerpf(0.45, 0.75, float(p - 1) / 3.0)
	if level <= 4:
		frac = minf(frac, FIRST_BLOCK_OP_CAP)
	return frac

func spawn_level_mobs() -> void:
	var p = block_position(current_level)
	var type_target = randi_range(p + 1, p + 2)   # pos 1 -> 2-3 ... pos 4 -> 5-6
	var op_frac = op_fraction(current_level)
	var op_pool = op_pool_for_level(current_level)
	# split the type menu between the classes, always at least one of each
	var op_types_n = clampi(int(round(type_target * op_frac)), 1, op_pool.size())
	var annoy_types_n = clampi(type_target - op_types_n, 1, ANNOYING_KINDS.size())
	var op_types = pick_random_subset(op_pool, op_types_n)
	var annoy_types = pick_random_subset(ANNOYING_KINDS, annoy_types_n)
	# total headcount also swells toward the block's end and with depth
	var total = clampi(4 + p + int(current_level / 12), 5, 13)
	# On the sprite-skinned blocks (levels 1-15: Orc/Blood Fiend/Demon) the grunt
	# IS the skinned character, so bias spawns toward it -- your downloaded mob is
	# the backbone you fight, with the distinct special mobs mixed in as variety.
	for i in range(total):
		if current_level <= GRUNT_SKIN_MAX_LEVEL and randf() < GRUNT_SPAWN_BIAS:
			spawn_kind("grunt")
		elif randf() < op_frac:
			spawn_kind(op_types[randi() % op_types.size()])
		else:
			spawn_kind(annoy_types[randi() % annoy_types.size()])

func pick_random_subset(pool: Array, n: int) -> Array:
	var copy = pool.duplicate()
	copy.shuffle()
	return copy.slice(0, n)

func spawn_kind(kind: String) -> void:
	if kind == "grunt":
		spawn_enemy()
		return
	var pos: Vector2
	if kind == "flyer":
		pos = Vector2(randf_range(300.0, current_width - 300.0), GROUND_Y - randf_range(180.0, 320.0))
	else:
		pos = Vector2(randf_range(700.0, current_width - 300.0), GROUND_Y - 60.0)
	spawn_special_mob(kind, pos)

func spawn_special_mob(kind: String, pos: Vector2) -> void:
	var mob = SPECIAL_MOB_SCRIPT.new()
	mob.kind = kind
	# roughly 1-in-8 OP mobs spawns as an ELITE: bigger, tougher, double reward
	if not (kind in ANNOYING_KINDS) and randf() < ELITE_CHANCE:
		mob.elite = true
	var scaling = get_level_scaling()
	mob.wave_hp_multiplier = scaling.hp
	mob.wave_damage_multiplier = scaling.dmg
	mob.wave_speed_multiplier = scaling.speed
	mob.position = pos
	$LevelContainer.add_child(mob)
	mob.died.connect(_on_combatant_died)
	alive_count += 1

func spawn_enemy() -> void:
	var enemy = ENEMY_SCENE.instantiate()
	enemy.weapon_type = WEAPON_TYPES[randi() % WEAPON_TYPES.size()]
	enemy.respawns = false
	enemy.instant_aggro = true
	var scaling = get_level_scaling()
	enemy.wave_hp_multiplier = scaling.hp
	enemy.wave_damage_multiplier = scaling.dmg
	enemy.wave_speed_multiplier = scaling.speed
	# re-skin into this 5-level block's roster (levels 1-5 -> block 0, etc.)
	enemy.apply_block_archetype(int((current_level - 1) / 5))
	assign_enemy_behavior(enemy)
	enemy.position = Vector2(randf_range(600.0, current_width - 200.0), GROUND_Y - 60.0)
	enemy.add_to_group("dungeon_combatant")
	$LevelContainer.add_child(enemy)
	enemy.died.connect(_on_combatant_died)
	alive_count += 1

# Roughly a third of dungeon enemies become a special archetype (shield/caster/
# healer/summoner/dasher), and a few of THOSE (or plain ones) become elites.
# The variety ramps a bit with depth so early levels stay gentle.
const ENEMY_BEHAVIORS = ["shield", "caster", "healer", "summoner", "dasher"]

func assign_enemy_behavior(enemy: Node) -> void:
	if not enemy.has_method("set_behavior"):
		return
	var special_chance = clamp(0.18 + current_level * 0.006, 0.18, 0.45)
	var elite_chance = clamp(0.03 + current_level * 0.004, 0.03, 0.16)
	var kind := ""
	if randf() < special_chance:
		kind = ENEMY_BEHAVIORS[randi() % ENEMY_BEHAVIORS.size()]
	var elite = randf() < elite_chance
	if kind != "" or elite:
		enemy.set_behavior(kind, elite)

func spawn_boss() -> Node:
	var boss = BOSS_SCENE.instantiate()
	var scaling = get_level_scaling()
	boss.boss_id = get_boss_id(current_level)
	boss.counter_role = get_boss_counter(current_level)
	boss.level_hp_mult = scaling.hp
	boss.damage_multiplier = scaling.dmg
	boss.speed_multiplier = scaling.speed
	# Spawn a fixed distance from wherever the player entered, biased toward the
	# arena interior. In these very wide arenas spawning at the far edge would
	# leave a melee boss trudging across for a minute; this starts the fight
	# quickly and lets it roam across the big space from there. Spawn well above
	# the floor so the larger boss bodies settle onto the ground.
	var px := ENTRY_X
	var p := get_tree().get_first_node_in_group("player")
	if p:
		px = p.global_position.x
	var toward_center := 1.0 if px < current_width / 2.0 else -1.0
	var boss_x: float = clamp(px + toward_center * 1500.0, 400.0, current_width - 400.0)
	boss.position = Vector2(boss_x, GROUND_Y - 140.0)
	boss.add_to_group("dungeon_combatant")
	$LevelContainer.add_child(boss)
	boss.died.connect(_on_combatant_died)
	alive_count += 1
	return boss

# Which skill-tree material this dungeon depth drops -- deeper brackets
# drop rarer materials (matching the escalating tier costs in skill_tree.gd).
func get_material_for_level(level: int) -> String:
	if level <= 5:
		return "slime"
	if level <= 10:
		return "iron_shard"
	if level <= 20:
		return "ember_crystal"
	if level <= 40:
		return "void_essence"
	return "ancient_relic"

const MATERIAL_DROP_CHANCE = 0.25

func roll_material_drop(guaranteed: bool = false) -> void:
	if not guaranteed and randf() > MATERIAL_DROP_CHANCE:
		return
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var mat_id = get_material_for_level(current_level)
	player.inventory.add_item(mat_id, 1)
	show_notification("Found: " + Inventory.get_display_name(mat_id))

# --- Gear loot ---
# Every boss also drops one piece of real gear, drawn from level-gated pools
# and always something the player doesn't own yet -- so working deeper into
# the dungeon steadily assembles the class sets (armor first, the set weapon
# that completes a set's full tier only past L15). The three newest Excellent
# weapons are a separate rare roll so they stay a jackpot moment. Once the
# player owns everything a bracket offers, bosses pay an extra material
# instead. (Sylvan Charm / Heart of the Mountain never drop here -- those are
# gathering-exclusive, see harvest_node.gd.)
const GEAR_RELIC_IDS = ["relic_vigor", "relic_swiftness", "relic_greed", "relic_wisdom",
	"relic_berserker", "relic_hawk", "relic_archon", "relic_wellspring",
	"relic_wings", "relic_feather",
	"relic_godheart", "relic_warlord", "relic_fortune", "relic_celerity",
	"relic_phoenix", "relic_thorns", "relic_aegis", "relic_vampire", "relic_juggernaut",
	"relic_blink", "relic_reaper", "relic_ward", "relic_steward"]
const GEAR_ARMOR_IDS = ["helm_bulwark", "armor_bulwark", "pants_bulwark",
	"helm_windstalker", "armor_windstalker", "pants_windstalker",
	"helm_runeweave", "armor_runeweave", "pants_runeweave",
	# batch: mid-tier Ranger set + gloves/boots + Dragonscale endgame set
	"helm_ranger", "armor_ranger", "pants_ranger",
	"gloves_leather", "gloves_iron", "gloves_assassin", "gloves_titan",
	"boots_leather", "boots_swift", "boots_storm", "boots_titan",
	"helm_dragon", "armor_dragon", "pants_dragon", "gloves_dragon", "boots_dragon"]
const GEAR_SET_WEAPON_IDS = ["wpn_claymore", "wpn_recurve", "wpn_scepter"]
# special-attack class weapons (flying slash, javelin volley, multi-shot,
# homing arrows, fireball, frost shard, cleave) -- see inventory.gd "special"
const GEAR_CLASS_WEAPON_IDS = ["wpn_windcutter", "wpn_sunderer", "wpn_stormlance",
	"wpn_stormvolley", "wpn_seeker", "wpn_emberstaff", "wpn_iciclewand",
	"wpn_mace", "wpn_greatsword", "wpn_katana", "wpn_warhammer", "wpn_javelin", "wpn_harpoon"]
const GEAR_EXCELLENT_IDS = ["exc_midas", "exc_echo", "exc_soul", "exc_hook", "exc_boomerang", "exc_chrono", "exc_wizardsbane", "exc_ragnarok", "wpn_tempest", "exc_doom", "exc_singularity", "exc_worldsplitter", "exc_dawnbreaker", "exc_shadowblade", "exc_earthshaker", "exc_gungnir", "exc_frostmourne", "exc_voidcaller", "exc_stormfury"]
const EXCELLENT_MIN_LEVEL = 25
const EXCELLENT_DROP_CHANCE = 0.15

func roll_gear_drop() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	if current_level >= EXCELLENT_MIN_LEVEL and randf() < EXCELLENT_DROP_CHANCE:
		var excellents = _gear_unowned(GEAR_EXCELLENT_IDS, player)
		if not excellents.is_empty():
			_give_gear(player, excellents.pick_random(), true)
			return
	var pool = []
	if current_level >= 3:
		pool += _gear_unowned(GEAR_RELIC_IDS, player)
	if current_level >= 6:
		pool += _gear_unowned(GEAR_ARMOR_IDS, player)
	if current_level >= 10:
		pool += _gear_unowned(GEAR_CLASS_WEAPON_IDS, player)
	if current_level >= 15:
		pool += _gear_unowned(GEAR_SET_WEAPON_IDS, player)
	if pool.is_empty():
		roll_material_drop(true)   # owns it all -- pay an extra material instead
		return
	_give_gear(player, pool.pick_random(), false)

# Owned = in the bag, worn, or currently wielded.
func _gear_unowned(ids: Array, player: Node) -> Array:
	var out = []
	var equipped = GameState.get_equipped_item_ids()
	for id in ids:
		if player.inventory.get_count(id) > 0 or id in equipped or id == player.active_weapon_id:
			continue
		out.append(id)
	return out

func _give_gear(player: Node, item_id: String, excellent: bool) -> void:
	if player.inventory.add_item(item_id, 1) > 0:
		show_notification("Your bag is full -- the %s was left behind!" % Inventory.get_display_name(item_id))
		return
	if excellent:
		show_notification("EXCELLENT find: %s!" % Inventory.get_display_name(item_id))
	else:
		show_notification("Gear drop: %s!" % Inventory.get_display_name(item_id))

func _on_combatant_died() -> void:
	# bosses always drop a material; regular enemies drop rarely
	roll_material_drop(is_boss_level(current_level))
	if is_boss_level(current_level):
		roll_gear_drop()
	alive_count -= 1
	if alive_count <= 0 and level_in_progress:
		level_in_progress = false
		level_cleared = true
		GameState.highest_unlocked_level = max(GameState.highest_unlocked_level, current_level + 1)
		# advance any "reach dungeon level N" villager bonds
		GameState.quest_event("reach_level", "", current_level)
		# beating Level 100 = beating Orin = the ending
		if current_level >= MAX_LEVEL:
			call_deferred("play_final_victory")
		show_notification("Level " + str(current_level) + " cleared! The far gate is open.")

func exit_dungeon() -> void:
	starting = false
	var player = get_tree().get_first_node_in_group("player")
	if player:
		GameState.pending_player_state = GameState.capture_player_state(player)
	GameState.in_dungeon = false
	GameState.returning_from_dungeon = true
	get_tree().change_scene_to_file.call_deferred("res://main.tscn")

func update_level_label() -> void:
	var label = get_node_or_null("CanvasLayer/LevelLabel")
	if label:
		label.text = "Level: " + str(current_level) + " / " + str(MAX_LEVEL) + "  (Unlocked: " + str(GameState.highest_unlocked_level) + ")"
		label.visible = true

func show_notification(text: String) -> void:
	var stack = get_node_or_null("CanvasLayer/NotificationStack")
	if stack:
		stack.show_notification(text)
