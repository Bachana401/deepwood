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

# Regular floors no longer read from a fixed table -- they build a themed layout
# per floor (see generate_regular_layout, far below). The four old static sets and
# the flat two-ledge boss layout that lived here are gone: they were the whole of
# the "map is uncreative" report.

# Boss identity per level. The six standard bosses CYCLE through the regular
# boss levels (5..90); the apex bosses are the game's UNIQUE finale gauntlet --
# Seraphiel at 95, then three back-to-back boss levels 98 / 99 / 100 that
# escalate to The Fallen Wizard, the hardest fight in the game. Ids MUST match
# boss.gd's BOSSES and the BOSS_ARENAS keys below.
# THE LADDER -- one boss per boss floor, every one of them different.
#
# This used to be a 6-boss CYCLING_BOSSES list indexed with a modulo, so each of
# those six was fought THREE times across the 100 floors (Gravewarden on 5, again
# on 35, again on 65 -- same moveset, bigger numbers). 12 of the 22 boss fights
# were reruns. Dev's forever rule: "in this game all bosses must be different in
# many many ways." So the modulo is gone and every floor names its own boss.
#
# Ids MUST match boss.gd's BOSSES and the BOSS_ARENAS keys below. A floor whose
# boss has no entry yet falls back to the nearest defined one, so the ladder can
# be filled in a boss at a time without breaking the run.
const BOSS_LADDER = {
	# --- the teaching floors: one mechanic each, learn the vocabulary ---
	5:  "gravewarden",       # pure pattern, no tricks: learn to read a boss
	10: "frost_monarch",     # stagger_armour -- learn to commit to heavy hits
	15: "cinder_colossus",   # riposte      -- learn to read a tell
	20: "weaver",            # soulbind     -- learn to kill the adds first
	25: "stormcaller",       # skyfall      -- learn the ground is safer
	30: "void_sovereign",    # sidestep     -- learn to bait
	# --- the deep: mechanics stack and interact ---
	35: "hollow_choir",      # false_twin + soulbind
	40: "ashen_penitent",    # riposte + famine
	45: "gaoler",            # tether + stagger_armour
	50: "sablefang",         # sidestep + rhythm_punish
	55: "effigy",            # stagger_armour + afterimage_trap
	60: "mourncaller",       # soulbind + mirror
	65: "unseen",            # phase + afterimage_trap -- can't hit it, can't stand still
	70: "warden_of_nails",   # skyfall + dread_ward + riposte
	75: "twin_despair",      # covenant + sidestep + phase
	80: "cinderking",        # afterimage_trap + mirror + famine
	85: "glass_saint",       # mirror + dread_ward + rhythm_punish
	90: "last_man",          # rhythm_punish + phase + covenant -- fights like you do
	# --- the finale gauntlet ---
	95: "seraph", 98: "leviathan", 99: "eclipse", 100: "wizard",
}
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
		"width": 4800.0, "height": -780.0,
		"bg_top": Color(0.05, 0.08, 0.05, 1.0), "bg_bottom": Color(0.09, 0.15, 0.08, 1.0),
		"accent": Color(0.6, 1.0, 0.45, 1.0),
	},
	# Frozen Cathedral -- many scattered high platforms; you must keep moving
	# across them to dodge its icicle rain and frost novas. Cold blue.
	"frost_monarch": {
		"width": 6000.0, "height": -900.0,
		"bg_top": Color(0.03, 0.06, 0.12, 1.0), "bg_bottom": Color(0.06, 0.12, 0.2, 1.0),
		"accent": Color(0.6, 0.85, 1.0, 1.0),
	},
	# Molten Foundry -- narrow stepping stones over wide gaps; punishing for a
	# charging, pillar-erupting bruiser. Fiery red/orange.
	"cinder_colossus": {
		"width": 5000.0, "height": -820.0,
		"bg_top": Color(0.12, 0.02, 0.01, 1.0), "bg_bottom": Color(0.22, 0.05, 0.02, 1.0),
		"accent": Color(1.0, 0.5, 0.15, 1.0),
	},
	# Silken Hollow -- stacked ledges on each side + a high central perch the
	# summoner retreats to. Venomous purple.
	"weaver": {
		"width": 5600.0, "height": -940.0,
		"bg_top": Color(0.08, 0.03, 0.12, 1.0), "bg_bottom": Color(0.14, 0.06, 0.2, 1.0),
		"accent": Color(1.0, 0.4, 0.9, 1.0),
	},
	# Storm Spire -- a symmetric tiered arena; nowhere is safe from radial
	# novas for long. Electric yellow.
	"stormcaller": {
		"width": 5600.0, "height": -900.0,
		"bg_top": Color(0.1, 0.09, 0.02, 1.0), "bg_bottom": Color(0.18, 0.16, 0.05, 1.0),
		"accent": Color(1.0, 1.0, 0.6, 1.0),
	},
	# The Void Throne -- sparse floating islands over the abyss; the hardest
	# boss teleports between them. Near-black violet.
	"void_sovereign": {
		"width": 6600.0, "height": -1000.0,
		"bg_top": Color(0.04, 0.02, 0.08, 1.0), "bg_bottom": Color(0.1, 0.04, 0.16, 1.0),
		"accent": Color(0.8, 0.3, 1.0, 1.0),
	},
	# ----- THE DEEP (35-90) -- mechanics stack, and so do the arenas -----
	# The Choir Loft -- false_twin + soulbind. The tell is a SHADOW on the floor,
	# so this room is built to be LOOKED DOWN INTO: a wide bare floor with no low
	# clutter to hide feet, ringed by high galleries you climb to pick the real
	# one out. Lit bone-pale, because you cannot spot a shadow in the dark.
	"hollow_choir": {
		"width": 5400.0, "height": -880.0,
		"bg_top": Color(0.09, 0.1, 0.07, 1.0), "bg_bottom": Color(0.16, 0.17, 0.12, 1.0),
		"accent": Color(0.85, 0.95, 0.65, 1.0),
	},
	# The Prayer Well -- riposte + famine. It barely moves and it wants you to
	# come to it; famine bills you for standing close. So: a deep NARROW shaft,
	# the penitent on the floor, and ring-ledges climbing the walls that are the
	# only mana-safe ground in the room. Every trip down to swing is a decision.
	"ashen_penitent": {
		"width": 4200.0, "height": -1250.0,
		"bg_top": Color(0.1, 0.03, 0.02, 1.0), "bg_bottom": Color(0.2, 0.07, 0.03, 1.0),
		"accent": Color(1.0, 0.5, 0.12, 1.0),
	},
	# The Soul-Pits -- tether + stagger_armour. THE cover arena: a forest of
	# solid pillars, because the tether is a line of sight and these cut it. Low
	# and heavy: nowhere to fly away to, so you fight it at the pillars or you
	# bleed. See COVER_LAYER.
	"gaoler": {
		"width": 6800.0, "height": -640.0,
		"bg_top": Color(0.04, 0.06, 0.09, 1.0), "bg_bottom": Color(0.09, 0.13, 0.18, 1.0),
		"accent": Color(0.5, 0.8, 1.0, 1.0),
	},
	# The Hunting Warren -- sidestep + rhythm_punish. It dodges what you repeat,
	# so the ROOM refuses to let you find a rhythm: every gap is a different
	# length, no two ledges the same, nothing periodic anywhere in the layout.
	# It is the only arena in the game deliberately built without a loop.
	"sablefang": {
		"width": 6000.0, "height": -820.0,
		"bg_top": Color(0.06, 0.05, 0.09, 1.0), "bg_bottom": Color(0.12, 0.1, 0.16, 1.0),
		"accent": Color(0.8, 0.7, 1.0, 1.0),
	},
	# The Wicker Ring -- stagger_armour + afterimage_trap. It sows fire where you
	# STOOD, so the arena must always offer somewhere to go: an unbroken circuit
	# with no dead ends and no cul-de-sacs. Keep running the ring and the traps
	# fall behind you; stop to commit to a heavy hit and they catch up.
	"effigy": {
		"width": 5400.0, "height": -860.0,
		"bg_top": Color(0.11, 0.04, 0.01, 1.0), "bg_bottom": Color(0.2, 0.09, 0.03, 1.0),
		"accent": Color(1.0, 0.6, 0.15, 1.0),
	},
	# The Widow's Barrow -- soulbind + mirror. Your own arrows come back at you,
	# so the floor is a graveyard of solid headstones at chest height: cover you
	# duck behind to eat your own shot. Grief reflects; the barrow absorbs.
	"mourncaller": {
		"width": 5200.0, "height": -800.0,
		"bg_top": Color(0.05, 0.06, 0.1, 1.0), "bg_bottom": Color(0.11, 0.12, 0.19, 1.0),
		"accent": Color(0.55, 0.75, 1.0, 1.0),
	},
	# The Hall of Not-There -- phase + afterimage_trap. You cannot hit it and you
	# cannot stand still: thin catwalks over nothing, at many heights, so every
	# second you are committed to a direction. No wide platform exists here --
	# there is nowhere to plant your feet and wait it out.
	"unseen": {
		"width": 5600.0, "height": -1000.0,
		"bg_top": Color(0.02, 0.01, 0.04, 1.0), "bg_bottom": Color(0.06, 0.03, 0.1, 1.0),
		"accent": Color(0.75, 0.2, 0.95, 1.0),
	},
	# The Nail Cage -- skyfall + dread_ward + riposte. This is BOSSES.md's own
	# worked example: "skyfall is meaningless in an open room and lethal under a
	# low ceiling with pillars." So it gets the LOWEST ceiling in the game and a
	# grid of pillars -- the pillars double as the flanking geometry dread_ward
	# demands, since you get behind it by running the posts, not by out-DPSing.
	"warden_of_nails": {
		"width": 5000.0, "height": -520.0,
		"bg_top": Color(0.09, 0.07, 0.03, 1.0), "bg_bottom": Color(0.17, 0.13, 0.05, 1.0),
		"accent": Color(0.9, 0.8, 0.35, 1.0),
	},
	# The Mirrored Vigil -- covenant + sidestep + phase. Two bodies healing each
	# other: you must split damage and kill both inside one window. So the room
	# is exactly symmetric about its centre, with a fast high bridge spanning it
	# -- the arena hands you the shuttle run the mechanic demands.
	"twin_despair": {
		"width": 6400.0, "height": -900.0,
		"bg_top": Color(0.05, 0.03, 0.1, 1.0), "bg_bottom": Color(0.1, 0.07, 0.18, 1.0),
		"accent": Color(0.7, 0.3, 1.0, 1.0),
	},
	# The Ember Throne -- afterimage_trap + mirror + famine. All three want you
	# moving, covered, and far: long open fire-lanes to run, sparse solid
	# braziers to break your returning shots on, and nothing at all to camp.
	"cinderking": {
		"width": 7000.0, "height": -880.0,
		"bg_top": Color(0.12, 0.03, 0.0, 1.0), "bg_bottom": Color(0.24, 0.08, 0.01, 1.0),
		"accent": Color(1.0, 0.4, 0.05, 1.0),
	},
	# The Reliquary of Glass -- mirror + dread_ward + rhythm_punish. Tall solid
	# panes stand in staggered pairs: they stop your reflected volley AND they
	# are the only way behind it. Every pane is a door and a shield at once.
	"glass_saint": {
		"width": 6000.0, "height": -900.0,
		"bg_top": Color(0.06, 0.09, 0.11, 1.0), "bg_bottom": Color(0.12, 0.18, 0.22, 1.0),
		"accent": Color(0.8, 0.95, 1.0, 1.0),
	},
	# The Last Redoubt -- rhythm_punish + phase + covenant. He fights like you
	# do, so he is fought where you live: the silhouette of the village, in
	# ruins. Roof-lines and doorways for a layout, lit by dying hearth-light.
	"last_man": {
		"width": 6000.0, "height": -940.0,
		"bg_top": Color(0.08, 0.06, 0.06, 1.0), "bg_bottom": Color(0.16, 0.11, 0.09, 1.0),
		"accent": Color(1.0, 0.72, 0.4, 1.0),
	},
	# ----- APEX TIER (levels 35 / 40 / 45) -----
	# Endgame monsters designed for a player with flight / grapple relics.
	# The tallest, widest arenas in the game, and the bosses fly or fill them.
	# Shattered Sanctum -- a ruined sky-cathedral for the flying Seraph:
	# columned stacks to climb and high floating isles to fight around.
	"seraph": {
		"width": 6200.0, "height": -1200.0,
		"bg_top": Color(0.14, 0.12, 0.06, 1.0), "bg_bottom": Color(0.22, 0.18, 0.1, 1.0),
		"accent": Color(1.0, 0.95, 0.6, 1.0),
	},
	# Drowned Abyss -- a vast flooded cavern for the sky-serpent: three thin
	# altitude bands of perches over nothing; its vortex drags you off them.
	"leviathan": {
		"width": 6800.0, "height": -1100.0,
		"bg_top": Color(0.01, 0.06, 0.08, 1.0), "bg_bottom": Color(0.03, 0.12, 0.14, 1.0),
		"accent": Color(0.3, 0.95, 0.85, 1.0),
	},
	# Black Sun Crater -- a colossal impact bowl for the Eclipse Titan: platform
	# rows rise in tiers toward both rims; its arena-wide eclipse beam forces
	# constant altitude changes. Ash black and dying red.
	"eclipse": {
		"width": 6600.0, "height": -1300.0,
		"bg_top": Color(0.05, 0.01, 0.02, 1.0), "bg_bottom": Color(0.12, 0.03, 0.04, 1.0),
		"accent": Color(1.0, 0.25, 0.15, 1.0),
	},
	# Sanctum of the Fallen -- level 100, The Fallen Wizard's spell-hall: the
	# largest arena in the game. Ascending "spell circle" platforms spiral to
	# both sides of a grand central dais; sickly green witchlight.
	"wizard": {
		"width": 8400.0, "height": -1400.0,
		"bg_top": Color(0.03, 0.02, 0.07, 1.0), "bg_bottom": Color(0.08, 0.05, 0.14, 1.0),
		"accent": Color(0.55, 1.0, 0.5, 1.0),
	},
}

const PLATFORM_HEIGHT = 20.0
const PLATFORM_COLOR = Color(0.3, 0.26, 0.24, 1.0)

# COVER -- a solid block, not a drop-through ledge: it stops you, stops the
# boss, stops arrows, and BREAKS LINE OF SIGHT (boss.gd tick_tether).
#
# Every platform in this game used to be one-way, which quietly made half of
# BOSSES.md undeliverable: "tether wants sight-blockers to break" and
# "dread_ward wants flankable geometry" are both impossible when the only
# building block is a ledge you fall through. Cover is the primitive those
# arenas are made of.
#
# Layers 1/2/4/8 are ground/player/enemy/building, so cover takes bit 5 (16) IN
# ADDITION to ground. It needs its own bit because a raycast ignores one_way:
# sighting against layer 1 would let any old ledge block vision, and the tether
# would snap on scenery. Sight is tested against COVER_LAYER alone.
const COVER_LAYER = 16
const COVER_COLOR = Color(0.24, 0.21, 0.2, 1.0)

# A solid pillar/wall. `h` is its full height, and y is its CENTRE (so a pillar
# standing on the floor sits at y = GROUND_Y - h/2).
static func cover(x: float, y: float, w: float, h: float) -> Dictionary:
	return {"x": x, "y": y, "w": w, "h": h, "solid": true}

# THE HARD CEILING ON COVER. The player's measured single-jump rise is ~92px
# (test_jump_node: JUMP_VELOCITY 400 / GRAVITY 900), and this is a side-scroller
# -- there is no going *around* a pillar, only over it. So a floor-rooted solid
# taller than a vault is not cover, it is a WALL between the player and the exit
# gate, and the floor cannot be finished. The first draft of these arenas had
# 300-tall pillars: five uncompletable rooms that looked perfectly fine.
#
# Chest height is the right answer anyway. Sight is traced centre-to-centre
# (boss origin ~120 above its feet, player origin 24 above the floor), so the
# ray runs LOW near the player: a barricade blocks it when you duck behind it,
# and doesn't when it's over on the boss's side. Cover you have to reach and use
# beats a wall that just stands there.
const VAULT_HEIGHT = 88.0

# A pillar rooted on the arena floor, given only how tall it is -- the form
# nearly every sight-blocker below wants. Height is clamped to a vault: an
# arena may not quietly build itself a wall.
static func pillar(x: float, w: float, h: float) -> Dictionary:
	return cover(x, GROUND_Y - minf(h, VAULT_HEIGHT) / 2.0, w, minf(h, VAULT_HEIGHT))

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
const CHEST_SCENE = preload("res://chest.tscn")
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

# How far past each side wall the cave fill runs. The camera can sit up to half
# a viewport (576 at the 1152-wide base) beyond the player, so anything less
# than that leaves bare viewport grey on screen at the ends of a floor.
const BACKFILL_X = 900.0
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
var _hint_timer := 0.0   # throttles the straggler direction refresh
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
	# the village diary is readable even down here -- what happened up top
	# while you delved is exactly what it exists to answer (5.9)
	add_child(preload("res://village_log_ui.gd").new())
	# the admin console rides along EVERYWHERE (dev request): dungeons and
	# test arenas included -- P opens it, same as the village. It is fully
	# group-based, so village-only actions simply no-op down here.
	add_child(preload("res://admin_panel.gd").new())
	add_child(preload("res://playtest_journal.gd").new())   # F8 field notes, everywhere
	GameState.in_dungeon = true
	if GameState.proving_grounds:
		build_proving_grounds()
		place_player_at_entry(false)
		setup_exit_button()
		start_music()
		return
	boss_counter_seq = build_counter_sequence()
	current_level = GameState.active_dungeon_level
	build_level_visuals(current_level)
	place_player_at_entry(false)
	update_level_label()
	setup_exit_button()
	start_music()
	# no countdown -- combat begins the moment the level loads
	spawn_level_combat()
	# a decade floor whose shrine already woke shows it again on re-entry (and is
	# where a fast-travel arrival lands -- it's at the entry, and the floor is clear)
	if GameState.shrine_revealed(current_level):
		_place_deep_shrine(false)

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
	$MusicPlayer.pitch_scale = music_pitch_for(current_level)
	$MusicPlayer.play()

# THE SOUND OF DEPTH (polish 2026-07-20): every one of the 100 floors --
# every boss, and the Harvest itself -- played the SAME loop at the SAME
# pitch, so floor 3 and the end of the world sounded identical. The art
# freeze forbids new assets, but the one track can still carry the
# descent: it sags a little lower the deeper you go, drops hard on a boss
# floor, and sits at its heaviest at the gate of 100.
const MUSIC_PITCH_SURFACE := 1.0
const MUSIC_PITCH_DEEPEST := 0.90     # by floor 99, from the depth slide alone
const MUSIC_PITCH_BOSS_DROP := 0.07   # a boss floor sits under its neighbours
const MUSIC_PITCH_FINALE := 0.74      # the gate of 100: heaviest in the game

func music_pitch_for(level: int) -> float:
	if level >= MAX_LEVEL:
		return MUSIC_PITCH_FINALE
	var t: float = clampf(float(level) / float(MAX_LEVEL), 0.0, 1.0)
	var pitch: float = lerpf(MUSIC_PITCH_SURFACE, MUSIC_PITCH_DEEPEST, t)
	if is_boss_level(level):
		pitch -= MUSIC_PITCH_BOSS_DROP
	return clampf(pitch, 0.6, 1.0)

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
	return generate_regular_layout(level)

# ============================ REGULAR FLOOR LAYOUTS ============================
# The dungeon used to hold FOUR hand-placed platform sets, cycled by (level-1)%5,
# so every non-boss floor was one of four identical rooms -- the "map is 2/10,
# uncreative" report. Each floor now GENERATES its own layout, seeded by its
# number (so it's identical on every visit), from a rotating catalogue of THEMES,
# each with its own silhouette and its own way to fight. The ground is always
# continuous (build_ground_and_walls), so a floor is winnable on foot no matter
# what; the platforms are reachable ADVANTAGE terrain, built from two primitives
# that are reachable BY CONSTRUCTION -- a tier-1 ledge within one 92px jump of the
# floor, and a climbable _stack whose rungs rise <=82px and overlap. The Underdark
# "closed places" lesson: test_dungeon_layout_node flood-fills all 100 floors so
# nothing is ever stranded again.
const REG_STEP := 82.0       # vertical gap between climbable rungs (< 92px jump)
const REG_FIRST := 74.0      # a tier-1 ledge's rise above the floor
const REG_MARGIN := 240.0    # keep platforms clear of both doorways
const REG_TOP := CEILING_Y + 90.0   # ledges stop here: clear of the ceiling AND its stalactites
const REG_L := REG_MARGIN
const REG_R := DUNGEON_WIDTH - REG_MARGIN
# A fixed shuffled order so consecutive floors never share a theme and no theme
# recurs for a dozen floors.
const REG_THEME_ORDER := [0, 7, 3, 10, 1, 5, 8, 2, 11, 4, 9, 6]

func get_regular_theme(level: int) -> int:
	return REG_THEME_ORDER[(level - 1) % REG_THEME_ORDER.size()]

func generate_regular_layout(level: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = (int(hash("dgn_layout")) ^ (level * 2654435)) & 0x7FFFFFFF
	var out: Array = []
	match get_regular_theme(level):
		0: _theme_terraces(out, rng)
		1: _theme_isles(out, rng)
		2: _theme_pillared_hall(out, rng)
		3: _theme_chasm_bridges(out, rng)
		4: _theme_overwatch(out, rng)
		5: _theme_gauntlet(out, rng)
		6: _theme_twin_towers(out, rng)
		7: _theme_amphitheatre(out, rng)
		8: _theme_roost(out, rng)
		9: _theme_warren(out, rng)
		10: _theme_sunken_court(out, rng)
		11: _theme_cascade(out, rng)
	return out

# ---- reachable primitives ----
# a one-way ledge whose STANDING SURFACE (top) is at `top`
func _ledge(out: Array, cx: float, top: float, w: float) -> void:
	out.append({"x": cx, "y": top + PLATFORM_HEIGHT * 0.5, "w": w})

# a climbable tower from the floor at cx: `count` rungs, each REG_STEP higher, x
# alternating +-54 (< the 150+ width) so consecutive rungs overlap -> reachable.
# Returns the height of the top rung.
func _stack(out: Array, cx: float, count: int, rng: RandomNumberGenerator) -> float:
	var side := 1.0
	var top := GROUND_Y - REG_FIRST
	for k in range(count):
		_ledge(out, cx + side * 54.0, top, rng.randf_range(150.0, 195.0))
		if k < count - 1:
			top -= REG_STEP
		side = -side
	return top

# a high horizontal SPAN with a climbable access stair at one end. The stair's top
# rung sits REG_STEP under the span and shares its x column, so the span is one hop
# up from ground the player earned rung by rung.
func _span_with_access(out: Array, tiers: int, x0: float, x1: float, access_left: bool, rng: RandomNumberGenerator) -> void:
	var ax: float = (x0 + 75.0) if access_left else (x1 - 75.0)
	var top := GROUND_Y - REG_FIRST
	var side := 1.0
	for k in range(tiers):
		_ledge(out, ax + side * 50.0, top, rng.randf_range(150.0, 180.0))
		top -= REG_STEP
		side = -side
	_ledge(out, (x0 + x1) * 0.5, top, x1 - x0)   # the span, REG_STEP over the last rung

# ---- the twelve themes ----
# 0 TERRACES -- a staircase climbing the whole hall one way, a perch on the far side
func _theme_terraces(out: Array, rng: RandomNumberGenerator) -> void:
	var dir: float = 1.0 if rng.randf() < 0.5 else -1.0
	var steps: int = rng.randi_range(5, 6)
	var x: float = (REG_L + 150.0) if dir > 0.0 else (REG_R - 150.0)
	var top: float = GROUND_Y - REG_FIRST
	for k in range(steps):
		top = maxf(top, REG_TOP)      # top out into a high landing, don't gore the ceiling
		_ledge(out, x, top, rng.randf_range(185.0, 230.0))
		top -= rng.randf_range(66.0, 80.0)
		x += dir * rng.randf_range(140.0, 172.0)
	_stack(out, (REG_R - 165.0) if dir > 0.0 else (REG_L + 165.0), rng.randi_range(1, 2), rng)

# 1 ISLES -- low floating stones the width of the room, two higher stacks
func _theme_isles(out: Array, rng: RandomNumberGenerator) -> void:
	var n: int = rng.randi_range(6, 8)
	for k in range(n):
		var x: float = lerpf(REG_L + 90.0, REG_R - 90.0, float(k) / float(n - 1)) + rng.randf_range(-35.0, 35.0)
		_ledge(out, x, GROUND_Y - rng.randf_range(56.0, 86.0), rng.randf_range(110.0, 150.0))
	var mid: float = (REG_L + REG_R) * 0.5
	_stack(out, rng.randf_range(REG_L + 300.0, mid - 100.0), 2, rng)
	_stack(out, rng.randf_range(mid + 100.0, REG_R - 300.0), 2, rng)

# 2 PILLARED HALL -- a colonnade of chest-high cover to weave and break sight on,
# with a few ledges to shoot from
func _theme_pillared_hall(out: Array, rng: RandomNumberGenerator) -> void:
	var n: int = rng.randi_range(5, 7)
	for k in range(n):
		var x: float = lerpf(REG_L + 130.0, REG_R - 130.0, float(k) / float(n - 1)) + rng.randf_range(-30.0, 30.0)
		out.append(pillar(x, rng.randf_range(48.0, 72.0), rng.randf_range(72.0, 88.0)))
	for k in range(rng.randi_range(2, 4)):
		_ledge(out, rng.randf_range(REG_L + 150.0, REG_R - 150.0), GROUND_Y - rng.randf_range(58.0, 84.0), rng.randf_range(130.0, 175.0))

# 3 CHASM BRIDGES -- two or three high spans over open floor, each with its own
# climb up; fight on the bridges or drop and fight below
func _theme_chasm_bridges(out: Array, rng: RandomNumberGenerator) -> void:
	var bridges: int = rng.randi_range(2, 3)
	for b in range(bridges):
		var x0: float = lerpf(REG_L + 60.0, REG_R - 640.0, float(b) / float(maxi(1, bridges - 1)))
		var x1: float = x0 + rng.randf_range(360.0, 560.0)
		_span_with_access(out, rng.randi_range(2, 3), x0, x1, rng.randf() < 0.5, rng)

# 4 OVERWATCH -- one long central spine over low stepping stones (the old slot 3,
# but the spine is now honestly reachable by its own stair)
func _theme_overwatch(out: Array, rng: RandomNumberGenerator) -> void:
	var cx: float = (REG_L + REG_R) * 0.5
	_span_with_access(out, rng.randi_range(2, 3), cx - rng.randf_range(300.0, 400.0), cx + rng.randf_range(300.0, 400.0), rng.randf() < 0.5, rng)
	for k in range(rng.randi_range(3, 4)):
		_ledge(out, rng.randf_range(REG_L + 120.0, REG_R - 120.0), GROUND_Y - rng.randf_range(56.0, 82.0), rng.randf_range(120.0, 160.0))

# 5 GAUNTLET -- cover and ledge alternating across the room, a serpentine run
func _theme_gauntlet(out: Array, rng: RandomNumberGenerator) -> void:
	var n: int = rng.randi_range(6, 8)
	for k in range(n):
		var x: float = lerpf(REG_L + 110.0, REG_R - 110.0, float(k) / float(n - 1))
		if k % 2 == 0:
			out.append(pillar(x, rng.randf_range(46.0, 64.0), 88.0))
		else:
			_ledge(out, x, GROUND_Y - rng.randf_range(60.0, 86.0), rng.randf_range(120.0, 160.0))

# 6 TWIN TOWERS -- two tall climbable towers flanking a low central island
func _theme_twin_towers(out: Array, rng: RandomNumberGenerator) -> void:
	_stack(out, REG_L + rng.randf_range(200.0, 320.0), rng.randi_range(3, 4), rng)
	_stack(out, REG_R - rng.randf_range(200.0, 320.0), rng.randi_range(3, 4), rng)
	_ledge(out, (REG_L + REG_R) * 0.5 + rng.randf_range(-60.0, 60.0), GROUND_Y - rng.randf_range(60.0, 84.0), rng.randf_range(160.0, 220.0))

# 7 AMPHITHEATRE -- symmetric tiers stepping up and IN toward the centre, a bowl
func _theme_amphitheatre(out: Array, rng: RandomNumberGenerator) -> void:
	var cx: float = (REG_L + REG_R) * 0.5
	var tiers: int = rng.randi_range(3, 4)
	var top: float = GROUND_Y - REG_FIRST
	var half: float = 700.0
	for t in range(tiers):
		_ledge(out, cx - half, top, rng.randf_range(180.0, 220.0))
		_ledge(out, cx + half, top, rng.randf_range(180.0, 220.0))
		top -= REG_STEP
		half -= 120.0

# 8 ROOST -- a corner tower climbing high, then a run of ledges under the ceiling
func _theme_roost(out: Array, rng: RandomNumberGenerator) -> void:
	var left: bool = rng.randf() < 0.5
	var cx: float = (REG_L + 180.0) if left else (REG_R - 180.0)
	var top: float = _stack(out, cx, 4, rng)
	var dir: float = 1.0 if left else -1.0
	var x: float = cx
	for k in range(rng.randi_range(3, 4)):
		x += dir * rng.randf_range(130.0, 165.0)
		_ledge(out, x, top + rng.randf_range(-6.0, 6.0), rng.randf_range(175.0, 205.0))

# 9 WARREN -- irregular, nothing periodic: a scatter of low ledges and stub cover,
# plus one high hidden perch. No two runs the same.
func _theme_warren(out: Array, rng: RandomNumberGenerator) -> void:
	var x: float = REG_L + 120.0
	while x < REG_R - 120.0:
		_ledge(out, x, GROUND_Y - rng.randf_range(56.0, 88.0), rng.randf_range(100.0, 165.0))
		if rng.randf() < 0.35:
			out.append(pillar(x + rng.randf_range(40.0, 90.0), rng.randf_range(44.0, 60.0), rng.randf_range(70.0, 88.0)))
		x += rng.randf_range(190.0, 300.0)
	_stack(out, rng.randf_range(REG_L + 300.0, REG_R - 300.0), rng.randi_range(2, 3), rng)

# 10 SUNKEN COURT -- a walled courtyard: two framing walls, rim stacks outside
# them, a low dais at the centre
func _theme_sunken_court(out: Array, rng: RandomNumberGenerator) -> void:
	var cx: float = (REG_L + REG_R) * 0.5
	out.append(pillar(cx - rng.randf_range(360.0, 440.0), 56.0, 88.0))
	out.append(pillar(cx + rng.randf_range(360.0, 440.0), 56.0, 88.0))
	_stack(out, REG_L + rng.randf_range(220.0, 320.0), rng.randi_range(2, 3), rng)
	_stack(out, REG_R - rng.randf_range(220.0, 320.0), rng.randi_range(2, 3), rng)
	_ledge(out, cx, GROUND_Y - rng.randf_range(58.0, 78.0), rng.randf_range(180.0, 240.0))

# 11 CASCADE -- a switchbacking climb: up one way, reverse halfway, back the other
func _theme_cascade(out: Array, rng: RandomNumberGenerator) -> void:
	var dir: float = 1.0 if rng.randf() < 0.5 else -1.0
	var x: float = (REG_L + 160.0) if dir > 0.0 else (REG_R - 160.0)
	var top: float = GROUND_Y - REG_FIRST
	var n: int = rng.randi_range(6, 7)
	for k in range(n):
		top = maxf(top, REG_TOP)      # a switchback tops out under the ceiling, not through it
		_ledge(out, x, top, rng.randf_range(165.0, 205.0))
		top -= rng.randf_range(64.0, 80.0)
		x += dir * rng.randf_range(110.0, 158.0)
		if k == int(n / 2):
			dir = -dir
	for k in range(2):
		_ledge(out, rng.randf_range(REG_L + 200.0, REG_R - 200.0), GROUND_Y - rng.randf_range(56.0, 78.0), rng.randf_range(140.0, 180.0))

func total_boss_levels() -> int:
	return int(MAX_LEVEL / 5)

# Finale levels (95/98/99/100) use their reserved unique boss; every other
# boss level cycles the six standard bosses.
const BOSS_DEFS_SCRIPT = preload("res://boss.gd")

func get_boss_id(level: int) -> String:
	var defs: Dictionary = BOSS_DEFS_SCRIPT.BOSSES
	var id: String = BOSS_LADDER.get(level, "")
	# A ladder entry whose boss isn't built in boss.gd YET must not brick the
	# floor -- the ladder is filled in one boss at a time, so fall back to the
	# deepest boss that actually exists at or above this floor.
	if id != "" and defs.has(id):
		return id
	var best := "gravewarden"
	var best_lv := -1
	for lv in BOSS_LADDER:
		if lv <= level and defs.has(BOSS_LADDER[lv]) and lv > best_lv:
			best_lv = lv
			best = BOSS_LADDER[lv]
	return best

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
		"hollow_choir": return gen_hollow_choir(w, h)
		"ashen_penitent": return gen_ashen_penitent(w, h)
		"gaoler": return gen_gaoler(w, h)
		"sablefang": return gen_sablefang(w, h)
		"effigy": return gen_effigy(w, h)
		"mourncaller": return gen_mourncaller(w, h)
		"unseen": return gen_unseen(w, h)
		"warden_of_nails": return gen_warden_of_nails(w, h)
		"twin_despair": return gen_twin_despair(w, h)
		"cinderking": return gen_cinderking(w, h)
		"glass_saint": return gen_glass_saint(w, h)
		"last_man": return gen_last_man(w, h)
		"seraph": return gen_seraph(w, h)
		"leviathan": return gen_leviathan(w, h)
		"eclipse": return gen_eclipse(w, h)
		"wizard": return gen_wizard(w, h)
	# A boss with no arena used to silently fall back to gen_gravewarden, which
	# meant 12 of the 22 fights were staged in the SAME tomb -- the modulo bug
	# wearing a different hat, and invisible because the room still looked fine.
	# Never fall back quietly again: name the gap.
	push_error("no arena for boss '%s' -- it is fighting in a borrowed room" % boss_id)
	return gen_gravewarden(w, h)

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

# ----- the deep (35-90) -----
# Every room below is built against its boss's mechanic stack using the real
# numbers those mechanics run on (boss.gd): TETHER_RANGE 420, FAMINE_RADIUS 120,
# SKYFALL_RADIUS 320, MIRROR_RADIUS 90, TRAP_PERIOD 2.2s. An arena that ignores
# them is decoration.

# Hollow Choir -- false_twin + soulbind. The fakes are untinted and identical;
# the ONLY tell is that the real one casts a shadow. That makes this room's job
# sightlines: keep the floor bare so shadows are legible, and put the player
# somewhere high enough to read the whole floor at once. The galleries are the
# mechanic. Its adds funnel across the open floor, so crossing it is the price.
func gen_hollow_choir(w: float, h: float) -> Array:
	var plats: Array = []
	var c := w / 2.0
	# the loft galleries: long balcony runs you climb to look DOWN and find the
	# one with a shadow under it
	var x := 900.0
	while x < w - 900.0:
		plats.append({"x": x, "y": -430.0, "w": 420.0})
		x += 1500.0
	x = 1650.0
	while x < w - 1650.0:
		plats.append({"x": x, "y": -620.0, "w": 300.0})
		x += 1500.0
	# access stacks, kept OUT of the central floor band on purpose: low ledges
	# there would hide the very feet you are trying to look at
	for sx in [560.0, w * 0.18, w * 0.82, w - 560.0]:
		if absf(sx - c) > w * 0.3:
			plats.append({"x": sx, "y": -155.0, "w": 210.0})
			plats.append({"x": sx, "y": -295.0, "w": 175.0})
	return add_sky_tier(plats, w, h)

# Ashen Penitent -- riposte + famine. It stands still at the bottom of a narrow
# shaft and waits. Famine (radius 120) means the floor costs you mana just to
# stand on, so the ring-ledges up the walls are the only free ground -- but the
# boss is DOWN there, so every swing is a paid trip. Riposte punishes hitting
# the wind-up, and the ledges give you somewhere to retreat and read it.
func gen_ashen_penitent(w: float, h: float) -> Array:
	var plats: Array = []
	var c := w / 2.0
	# the well's ring-ledges, alternating walls all the way up the shaft. Well
	# clear of FAMINE_RADIUS from the centre where it prays.
	var y := -190.0
	var i := 0
	while y > h + 170.0:
		var side := 1.0 if i % 2 == 0 else -1.0
		plats.append({"x": c + side * (w * 0.28), "y": y, "w": 260.0})
		# a stepping stone out over the middle every third ring, so you can
		# actually cross the shaft instead of only ever circling it
		if i % 3 == 2:
			plats.append({"x": c - side * (w * 0.08), "y": y - 80.0, "w": 150.0})
		y -= 165.0
		i += 1
	# the prayer dais: a low lip around it, the one bit of ground worth contesting
	plats.append({"x": c - 330.0, "y": -140.0, "w": 200.0})
	plats.append({"x": c + 330.0, "y": -140.0, "w": 200.0})
	return plats

# Gaoler -- tether + stagger_armour. THE cover arena. The tether is a line of
# sight (boss.gd _sight_to_player_blocked), so this is a forest of solid pillars
# spaced INSIDE the 420 leash: wherever it chains you, cover is a short dash
# away. Low ceiling -- you cannot climb out of a soul-pit, you break the chain
# at the posts or you bleed. Stagger armour means those pillar-breaks are also
# where you find room to wind up a heavy hit.
func gen_gaoler(w: float, h: float) -> Array:
	var plats: Array = []
	var i := 0
	var x := 520.0
	while x < w - 520.0:
		# alternating pillar heights so the cover reads as a warren, not a fence
		plats.append(pillar(x, 76.0, 88.0 if i % 2 == 0 else 72.0))
		# a ledge slung between every other pair: high ground that does NOT
		# break sight, so taking it is a real trade against the chain
		if i % 2 == 1:
			plats.append({"x": x - 190.0, "y": -380.0, "w": 240.0})
		x += 380.0        # < TETHER_RANGE: cover is always within the leash
		i += 1
	return plats

# Sablefang -- sidestep + rhythm_punish. It dodges what you repeat and it
# punishes your fourth identical beat, so the ROOM refuses to have a rhythm:
# every gap is a different length and no two ledges match. Nothing here is
# periodic, deliberately -- it is the only arena in the game with no loop in it.
# A player who finds a groove here built it themselves, and Sablefang eats it.
const SABLEFANG_GAPS := [410.0, 655.0, 380.0, 720.0, 495.0, 860.0, 340.0, 615.0,
	770.0, 445.0, 930.0, 520.0, 690.0, 365.0, 800.0, 585.0, 470.0, 745.0]
const SABLEFANG_YS := [-135.0, -290.0, -195.0, -365.0, -240.0, -160.0, -320.0,
	-215.0, -400.0, -175.0, -265.0, -345.0, -145.0, -305.0, -230.0]
const SABLEFANG_WS := [180.0, 115.0, 145.0, 95.0, 210.0, 130.0, 165.0, 105.0,
	190.0, 125.0, 150.0, 90.0, 175.0]
func gen_sablefang(w: float, h: float) -> Array:
	var plats: Array = []
	var x := 520.0
	var i := 0
	while x < w - 420.0:
		plats.append({"x": x, "y": SABLEFANG_YS[i % SABLEFANG_YS.size()],
			"w": SABLEFANG_WS[i % SABLEFANG_WS.size()]})
		x += SABLEFANG_GAPS[i % SABLEFANG_GAPS.size()]
		i += 1
	# the high branches: also irregular, offset from the run below so no column
	# of platforms ever lines up
	x = 980.0
	i = 0
	while x < w - 700.0:
		plats.append({"x": x, "y": -480.0 - float(i % 4) * 65.0,
			"w": SABLEFANG_WS[(i + 5) % SABLEFANG_WS.size()]})
		x += SABLEFANG_GAPS[(i + 7) % SABLEFANG_GAPS.size()] + 260.0
		i += 1
	return plats

# Effigy -- stagger_armour + afterimage_trap. It sows fire where you STOOD and
# detonates it every 2.2s, so the room's promise is: there is always somewhere
# to go. An unbroken circuit -- floor, end ramp, upper deck, far ramp, floor --
# with no dead ends anywhere. Run the ring and the traps fall behind you. But
# stagger armour only breaks to a committed heavy swing, and committing means
# standing still, which is exactly what the ring is built to punish.
func gen_effigy(w: float, h: float) -> Array:
	var plats: Array = []
	# the upper deck: long runs (a trap period at speed is ~700-900px, so these
	# are sized to be outrun, not hopped)
	var x := 700.0
	while x < w - 700.0:
		plats.append({"x": x, "y": -360.0, "w": 620.0})
		x += 780.0
	# ramps at BOTH ends and at the quarters -- the rungs that close the loop
	for rx in [620.0, w * 0.5, w - 620.0]:
		plats.append({"x": rx, "y": -140.0, "w": 230.0})
		plats.append({"x": rx, "y": -250.0, "w": 190.0})
	# the wicker crown: a second, shorter ring above the deck
	x = 1250.0
	while x < w - 1250.0:
		plats.append({"x": x, "y": -560.0, "w": 400.0})
		x += 1000.0
	return add_sky_tier(plats, w, h)

# Mourncaller -- soulbind + mirror. It flies, and it turns your own arrows
# around (MIRROR_RADIUS 90). So the floor is a barrow field of solid headstones
# at chest height: cover to duck behind when your shot comes home. Its rune adds
# walk the same field, which makes clearing them a fight through your own cover.
func gen_mourncaller(w: float, h: float) -> Array:
	var plats: Array = []
	var i := 0
	var x := 480.0
	while x < w - 480.0:
		# staggered headstones -- deliberately uneven so cover is real but never
		# a solid wall you can hide behind forever
		plats.append(pillar(x, 46.0, 60.0 + float(i % 3) * 14.0))
		if i % 4 == 1:
			plats.append(pillar(x + 150.0, 40.0, 62.0))
		x += 330.0
		i += 1
	# it FLIES: perches so the fight is not just you shooting at the ceiling
	x = 900.0
	i = 0
	while x < w - 900.0:
		plats.append({"x": x, "y": -270.0 - float(i % 3) * 110.0, "w": 200.0})
		x += 880.0
		i += 1
	return add_sky_tier(plats, w, h, 1050.0)

# The Unseen -- phase + afterimage_trap. You cannot hit it and you cannot stand
# still. Thin catwalks over nothing, at every height: each one is narrow enough
# that being on it is a commitment to a direction, and there is no wide platform
# anywhere in this room to plant your feet and wait the phase out. It flies and
# teleports; you get spans and gaps.
func gen_unseen(w: float, h: float) -> Array:
	var plats: Array = []
	var ys := [-165.0, -310.0, -455.0, -240.0, -600.0, -385.0, -520.0]
	var i := 0
	var x := 560.0
	while x < w - 560.0:
		# every catwalk is thin -- nowhere in this arena is safe standing room
		plats.append({"x": x, "y": ys[i % ys.size()], "w": 108.0})
		# an occasional longer span, still narrow, bridging two heights
		if i % 3 == 1:
			plats.append({"x": x + 230.0, "y": ys[(i + 3) % ys.size()], "w": 96.0})
		x += 430.0
		i += 1
	return plats

# Warden of Nails -- skyfall + dread_ward + riposte. BOSSES.md's own worked
# example, built to the letter: "skyfall is meaningless in an open room and
# lethal under a low ceiling with pillars." The LOWEST ceiling in the game, so
# leaving the floor puts you inside SKYFALL_RADIUS (320) with nowhere to climb
# to -- and a grid of pillars, which is also the flanking geometry dread_ward
# demands, since you only ever get behind this thing by running the posts.
func gen_warden_of_nails(w: float, h: float) -> Array:
	var plats: Array = []
	var i := 0
	var x := 460.0
	while x < w - 460.0:
		# the nails: a dense grid, close enough that a flank is always one post
		# away and no lane is ever a straight run
		plats.append(pillar(x, 62.0, 88.0 if i % 3 != 1 else 60.0))
		x += 400.0
		i += 1
	# a handful of low ledges ONLY -- under this ceiling they are a trap, not an
	# escape, which is the joke: the room offers you height and height is death
	x = 860.0
	while x < w - 860.0:
		plats.append({"x": x, "y": -330.0, "w": 200.0})
		x += 1400.0
	# NO sky tier: the ceiling is the mechanic. Do not give it back.
	return plats

# Twin Despair -- covenant + sidestep + phase. Two bodies, one soul, healing
# each other unless BOTH are pressured: the fight is a shuttle run, so the room
# is exactly symmetric about its centre and hands you a fast high bridge to
# cross it on. Anything built on one side exists on the other -- if the arena
# favoured a side, the covenant would resolve itself.
func gen_twin_despair(w: float, h: float) -> Array:
	var plats: Array = []
	var c := w / 2.0
	# the bridge: the shuttle the mechanic demands
	plats.append({"x": c, "y": -420.0, "w": 900.0})
	plats.append({"x": c, "y": -180.0, "w": 300.0})
	# mirrored pairs -- every entry is emitted on BOTH sides, by construction
	for pair in [[560.0, -150.0, 220.0], [560.0, -300.0, 170.0],
			[1180.0, -230.0, 200.0], [1180.0, -560.0, 180.0],
			[1820.0, -160.0, 210.0], [1820.0, -390.0, 170.0],
			[2480.0, -280.0, 190.0], [2480.0, -620.0, 160.0],
			[3150.0, -190.0, 200.0], [3150.0, -470.0, 170.0]]:
		if c - pair[0] < 320.0:
			continue
		plats.append({"x": c - pair[0], "y": pair[1], "w": pair[2]})
		plats.append({"x": c + pair[0], "y": pair[1], "w": pair[2]})
	return plats

# Cinderking -- afterimage_trap + mirror + famine. Three mechanics that all say
# the same thing: do not stand there. Long open fire-lanes to keep running,
# sparse solid braziers to break your own reflected shots on, and famine
# (radius 120) making the space around it cost mana. Nothing here is campable.
func gen_cinderking(w: float, h: float) -> Array:
	var plats: Array = []
	# the lanes: long uninterrupted running ground at two heights
	var x := 780.0
	var i := 0
	while x < w - 780.0:
		plats.append({"x": x, "y": -170.0 if i % 2 == 0 else -330.0, "w": 560.0})
		x += 700.0
		i += 1
	# braziers: sparse cover, far enough apart that reaching one is a real run
	x = 1300.0
	while x < w - 1300.0:
		plats.append(pillar(x, 90.0, 86.0))
		x += 1300.0
	# the throne's upper galleries
	x = 1600.0
	i = 0
	while x < w - 1600.0:
		plats.append({"x": x, "y": -520.0 - float(i % 2) * 130.0, "w": 300.0})
		x += 1500.0
		i += 1
	return add_sky_tier(plats, w, h)

# Glass Saint -- mirror + dread_ward + rhythm_punish. Tall panes in staggered
# pairs. Each pane is a shield and a door at once: it stops the volley the Saint
# just turned around on you, AND slipping between the pair is how you get behind
# something that only takes damage from behind. Offset so no pane is ever a
# straight-line answer -- reading them IS the fight.
func gen_glass_saint(w: float, h: float) -> Array:
	var plats: Array = []
	var i := 0
	var x := 560.0
	while x < w - 560.0:
		# a staggered PAIR: the gap between them is the flanking route
		plats.append(pillar(x, 34.0, 88.0))
		plats.append(pillar(x + 210.0, 34.0, 68.0))
		# reliquary shelves above the panes, offset from them
		if i % 2 == 0:
			plats.append({"x": x + 105.0, "y": -400.0, "w": 260.0})
		else:
			plats.append({"x": x + 105.0, "y": -540.0, "w": 220.0})
		x += 620.0
		i += 1
	return add_sky_tier(plats, w, h, 1100.0)

# The Last Man -- rhythm_punish + phase + covenant. He fights like you do, so he
# is fought where you live: the village, in ruins. The houses are solid (walls
# you flank around, doorways between them), the roof-lines are the high ground,
# and it is lit by dying hearth-light. The last floor before the finale should
# look like home and play like a duel.
# [width, standing-wall height]. The walls are RUINS -- vaultable, because a
# house you cannot get over is a wall across the only street (see VAULT_HEIGHT).
const REDOUBT_HOUSES := [[260.0, 88.0], [200.0, 72.0], [320.0, 84.0],
	[180.0, 64.0], [280.0, 88.0], [230.0, 76.0], [300.0, 80.0]]
func gen_last_man(w: float, h: float) -> Array:
	var plats: Array = []
	var i := 0
	var x := 620.0
	while x < w - 620.0:
		var house: Array = REDOUBT_HOUSES[i % REDOUBT_HOUSES.size()]
		var hw: float = house[0]
		var hh: float = house[1]
		plats.append(pillar(x, hw, hh))
		# The roof: the duel's high ground. Hung a jump above the wall top, not
		# an arbitrary offset -- roofs you cannot reach are scenery.
		plats.append({"x": x, "y": GROUND_Y - hh - 75.0, "w": hw + 40.0})
		x += hw + 560.0     # the street between them: the flanking route
		i += 1
	# the ruined upper storeys / broken rafters
	x = 1100.0
	i = 0
	while x < w - 1100.0:
		plats.append({"x": x, "y": -520.0 - float(i % 3) * 120.0, "w": 240.0})
		x += 1250.0
		i += 1
	return add_sky_tier(plats, w, h)

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
	# floor-surprise caches hang off the ROOT (so their ../ChestUI resolves), not
	# $LevelContainer, so clear them by group when a floor is (re)built
	for n in get_tree().get_nodes_in_group("floor_surprise"):
		n.queue_free()
	var boss = is_boss_level(level)
	var arena = get_boss_arena(level) if boss else {}
	current_width = get_level_width(level)
	current_ceiling = get_level_ceiling(level)
	build_background(boss, arena)
	build_ground_and_walls()
	var layout = get_layout(level)
	build_platforms(layout)
	build_floor_surprises(level, layout)
	build_stalactites(boss)
	build_torches(boss, arena)
	place_mines(boss, layout)
	place_hazards(level, boss)
	build_gates()

# FLOOR SURPRISES (dev 2026-07-21: "many places to go, many surprises, goods and
# bads"). Each non-boss floor rolls 1-2 extras, seeded by its level so a floor is
# the same each visit: a HIDDEN CACHE up on a ledge (good -- a chest, its loot
# stable by a floor id so a looted one stays looted), or a HAZARD trap on the
# ground (bad). Environmental, so the fight's difficulty is unchanged. (The
# ambush surprise -- a pack that springs -- lives in spawn_level_mobs, since it
# only makes sense on a floor still being fought.)
func build_floor_surprises(level: int, layout: Array) -> void:
	if is_boss_level(level):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hash("dgn_surprise")) ^ (level * 2654435)
	var ledges := []
	for plat in layout:
		if not plat.get("solid", false) and float(plat.y) < GROUND_Y - 70.0:
			ledges.append(plat)
	for i in range(rng.randi_range(1, 2)):
		# lean toward the CACHE -- it's the genuinely new GOOD surprise; the floor's
		# mines already provide hazards and the ambush is the new BAD one
		if rng.randf() < 0.6 and not ledges.is_empty():
			_dgn_cache(level, i, ledges[rng.randi() % ledges.size()], rng)
		else:
			_dgn_hazard(rng)

func _dgn_cache(level: int, idx: int, plat: Dictionary, rng: RandomNumberGenerator) -> void:
	var c = CHEST_SCENE.instantiate()
	c.chest_id = "dgn_%d_%d_%d" % [level, idx, int(plat.x)]   # unique per floor + slot
	c.add_to_group("floor_surprise")
	add_child(c)                       # ROOT child, so chest.gd's ../ChestUI resolves
	c.global_position = Vector2(float(plat.x), float(plat.y) - 22.0)
	if not GameState.chest_contents.has(c.chest_id):
		var table := ["potion_health", "potion_mana", "iron_shard", "ember_crystal", "coin_gold", "herb", "resin"]
		if level >= 40:
			table.append_array(["void_essence", "ancient_relic"])
		for k in range(rng.randi_range(2, 3)):
			c.inventory.add_item(table[rng.randi() % table.size()], rng.randi_range(1, 2))
		GameState.chest_contents[c.chest_id] = c.inventory.to_save_data()

func _dgn_hazard(rng: RandomNumberGenerator) -> void:
	var t = TRAP_SCENE.instantiate()
	$LevelContainer.add_child(t)
	t.global_position = Vector2(rng.randf_range(520.0, maxf(560.0, current_width - 420.0)), GROUND_Y)

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
	# The bands used to reach only 150px past each side wall, but the camera can
	# sit half a screen (576) beyond the player, so standing at either end of a
	# floor put bare viewport grey down one side of the screen. Overshoot wide.
	var sky_top = ColorRect.new()
	sky_top.color = top_color
	sky_top.z_index = -100
	sky_top.position = Vector2(-BACKFILL_X, sky_top_y)
	sky_top.size = Vector2(current_width + BACKFILL_X * 2.0, -400.0 - sky_top_y)
	$LevelContainer.add_child(sky_top)
	var sky_bottom = ColorRect.new()
	sky_bottom.color = bottom_color
	sky_bottom.z_index = -100
	sky_bottom.position = Vector2(-BACKFILL_X, -400)
	sky_bottom.size = Vector2(current_width + BACKFILL_X * 2.0, 400)
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
	# THE FLOOR WAS 80 PIXELS THICK AND THE VIEWPORT SEES ~360 BELOW THE PLAYER
	# (sweep 2026-07-21), so every dungeon floor was a band of rock sitting on a
	# slab of flat viewport grey -- the clear colour, not a colour anyone chose.
	# The collision shape stays 80 tall (grect above); only the fill runs deep.
	var ground_visual = ColorRect.new()
	ground_visual.size = Vector2(current_width + BACKFILL_X * 2.0, 900.0)
	ground_visual.position = Vector2(-(current_width + BACKFILL_X * 2.0) / 2.0, -40.0)
	ground_visual.color = Color(0.2, 0.17, 0.15, 1.0)
	ground_visual.z_index = -95
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
		var is_solid: bool = plat.get("solid", false)
		var ph: float = plat.get("h", PLATFORM_HEIGHT)
		var body = StaticBody2D.new()
		body.position = Vector2(plat.x, plat.y)
		if is_solid:
			body.collision_layer = 1 | COVER_LAYER
		var shape = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = Vector2(plat.w, ph)
		shape.shape = rect
		# cover is solid from every side -- that is the whole point of it
		shape.one_way_collision = not is_solid
		body.add_child(shape)
		var visual = ColorRect.new()
		visual.size = Vector2(plat.w, ph)
		visual.position = Vector2(-plat.w / 2.0, -ph / 2.0)
		visual.color = COVER_COLOR if is_solid else PLATFORM_COLOR
		body.add_child(visual)
		var edge = ColorRect.new()
		edge.size = Vector2(plat.w, 4.0)
		edge.position = Vector2(-plat.w / 2.0, -ph / 2.0)
		edge.color = (COVER_COLOR if is_solid else PLATFORM_COLOR).lightened(0.18)
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

# Shared soft radial glow for every dungeon torch (built once).
static var _torch_glow: GradientTexture2D = null

static func _torch_glow_tex() -> GradientTexture2D:
	if _torch_glow == null:
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
		grad.colors = PackedColorArray([
			Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.45),
			Color(1, 1, 1, 0.14), Color(1, 1, 1, 0.0),
		])
		_torch_glow = GradientTexture2D.new()
		_torch_glow.gradient = grad
		_torch_glow.width = 128
		_torch_glow.height = 128
		_torch_glow.fill = GradientTexture2D.FILL_RADIAL
		_torch_glow.fill_from = Vector2(0.5, 0.5)
		_torch_glow.fill_to = Vector2(1.0, 0.5)
	return _torch_glow

func build_torch(pos: Vector2, color: Color = TORCH_COLOR) -> void:
	var torch = Node2D.new()
	torch.position = pos
	$LevelContainer.add_child(torch)

	# A WALL SCONCE, NOT A BONFIRE. The old torch stood 30px with its flame at
	# -38 -- chest height on a 56px player -- so the glow octagon sat ON whoever
	# walked past and read as an orange blob stuck to them (visual sweep). It
	# burns above head height now.
	var pole = ColorRect.new()
	pole.color = Color(0.22, 0.16, 0.11, 1.0)
	pole.size = Vector2(6.0, 74.0)
	pole.position = Vector2(-3.0, -74.0)
	torch.add_child(pole)

	# A FLAT POLYGON CANNOT LOOK LIKE LIGHT. The old glow was a hard-edged
	# octagon that read as an orange SIGN hanging by the flame; softening its
	# alpha only made a fainter octagon. It is a real radial falloff now --
	# the same soft-light trick the village torches use.
	var glow = Sprite2D.new()
	glow.texture = _torch_glow_tex()
	glow.modulate = Color(color.r, color.g, color.b, 0.5)
	glow.position = Vector2(0, -82.0)
	glow.material = make_additive_material()
	torch.add_child(glow)

	var flame = Polygon2D.new()
	flame.polygon = PackedVector2Array([Vector2(-5, 0), Vector2(5, 0), Vector2(0, -16)])
	flame.color = color
	flame.position = Vector2(0, -82.0)
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
		# never on cover: a pillar's y is its CENTRE, so a mine would hang in
		# mid-air halfway up it
		if plat.get("solid", false):
			continue
		# dev call 2026-07-21: mines halved world-wide (was 0.5 per platform)
		if randf() < 0.25:
			var x = plat.x + randf_range(-plat.w * 0.3, plat.w * 0.3)
			place_mine(Vector2(x, plat.y))

# CREATIVE HAZARDS beyond the mine (dev 2026-07-21: "no creative traps"). A themed
# couple per non-boss floor, seeded so a floor is the same each visit. Spikes and
# flame-vents from the start; the crusher and poison geyser join a little deeper so
# the early floors stay gentle. All are telegraphed and dodgeable -- danger you
# read and route around, not damage you eat blind.
const HAZARD_SCRIPT = preload("res://hazard.gd")

func place_hazards(level: int, boss: bool) -> void:
	if boss:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hash("dgn_hazard_v2")) ^ (level * 40503)
	var pool := ["spike", "flamevent"]
	if level >= 12:
		pool.append("crusher")
	if level >= 18:
		pool.append("gas")
	var n := clampi(1 + int(level / 22), 1, 3)
	var placed := 0
	var tries := 0
	while placed < n and tries < 40:
		tries += 1
		var x := rng.randf_range(360.0, current_width - 320.0)
		if absf(x - ENTRY_X) < MINE_SAFE_ZONE or absf(x - (current_width - 46.0)) < 200.0:
			continue
		var hz = HAZARD_SCRIPT.new()
		hz.kind = pool[rng.randi() % pool.size()]
		hz.damage = mini(int(round(16 + level * 0.6)), 70)   # scales with depth, capped, never a one-shot
		hz.span = rng.randf_range(84.0, 120.0)
		hz.position = Vector2(x, GROUND_Y)
		$LevelContainer.add_child(hz)
		placed += 1

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

# DEEP SHRINES (Wukong-style fast-travel, dev 2026-07-21). One stands at the entry
# of every tenth floor -- INVISIBLE until you clear that floor, then it wakes (log
# + world-wide chime) and becomes a travel anchor you can leap to from the village
# Waystone. Placed silently when you re-enter a floor whose shrine already woke.
const SHRINE_NODE = preload("res://shrine_node.gd")

func _place_deep_shrine(waking: bool) -> void:
	for c in get_children():
		if c.get_script() == SHRINE_NODE:
			return                                  # one per floor, never doubled
	var sh = SHRINE_NODE.new()
	sh.is_waystone = false
	add_child(sh)
	sh.global_position = Vector2(ENTRY_X + 130.0, GROUND_Y)
	if not waking:
		return
	sh.play_wake()          # the dramatic rise-from-nothing when a floor first falls
	GameState.log_event("combat", "A Deep Shrine woke on floor %d — you can leap here from the Waystone." % current_level)
	GameState.play_sfx(GameState.SFX_CHIME, 1.9)
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack:
		stack.show_notification("🔔 A DEEP SHRINE awakens on floor %d — a new anchor to travel to." % current_level)
	# THE WAYSTONE is earned at floor 20: its blueprint wakes with the shrine there
	if current_level >= 20 and not GameState.waystone_unlocked:
		GameState.waystone_unlocked = true
		GameState.log_event("village", "The WAYSTONE blueprint woke — raise it at home to leap to any shrine.")
		if stack:
			stack.show_notification("▲ The WAYSTONE will rise at home — from it, travel to any woken shrine.")

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
	# THE EMPTY THRONE (new finale, 2026-07-20): floor 100 holds NOTHING.
	# The silence is the trap's final move -- the false victory is carried
	# home, and Orin springs the Harvest at the feast, in the village.
	# (dev_mode keeps a plain Orin here for arena testing.)
	if current_level >= MAX_LEVEL and not GameState.dev_mode:
		level_in_progress = false
		level_cleared = true
		GameState.seen_empty_throne = true
		update_level_label()
		var label = get_node_or_null("CanvasLayer/LevelLabel")
		if label:
			label.text = "Level: 100 / 100   —   the deep is SILENT"
		if not GameState.seen_l100_reveal:
			GameState.seen_l100_reveal = true
			call_deferred("play_empty_throne")
		return
	# A FLOOR YOU ALREADY SWEPT IS STILL SWEPT. Nothing respawns here -- not
	# after a walk home, not after a night's sleep, not after a reload. It
	# stands as an open corridor you can cross on the way somewhere deeper.
	# (The Ten's vaults and any un-freed hostage still stand: those are yours
	# to collect, not enemies to refight -- see spawn_deep_rescue below.)
	if GameState.floor_is_cleared(current_level):
		level_in_progress = false
		level_cleared = true
		spawn_deep_rescue()
		update_level_label()
		show_notification("Floor %d is as you left it — nothing living stirs." % current_level)
		return
	if is_boss_level(current_level):
		var b = spawn_boss()
		var intro = "Level %d - %s awakens!" % [current_level, b.get_display_name()]
		var counter = get_boss_counter(current_level)
		if counter != "":
			intro += "  (weak to %s)" % counter
		show_notification(intro)
		# (The Harvest moved HOME -- see harvest_director.gd. Floor 100 in a
		# real run is the empty throne above; in dev_mode the wizard spawns
		# here plain, for arena testing.)
	else:
		spawn_level_mobs()
		# the permanent HUD label already reads "Level 3 / 100" -- a toast
		# repeating the number was pure noise. Name who holds the floor
		# instead (same roster the spawns use: one archetype per 5 levels).
		var rosters: Array = load("res://enemy.gd").ENEMY_ROSTERS
		var roster: Dictionary = rosters[int((current_level - 1) / 5) % rosters.size()]
		show_notification("Floor %d — %ss hold this deep." % [current_level, str(roster.get("name", "creature"))])
	spawn_deep_rescue()
	update_level_label()

func play_empty_throne() -> void:
	# the silent hall: the search, the false conclusion, the walk home. Ilo's
	# unease leads it when he's free -- he alone hears that the song isn't over.
	var lines: Array = Story.EMPTY_THRONE
	if GameState.ten_freed("ten_ilo"):
		lines = lines + [{"speaker": "Ilo, the Nameless Bard",
			"text": "(His voice reaches you from the world above, the way only a song can.) Hunter... the deep has gone quiet, and I cannot finish the song. Silence is not the same as an ending. Come home — but come home CAREFUL."}]
	DialogueBox.play(self, lines)

# Orin is down -- the deathless made mortal for one instant, and the blow landed.
# Play the ending, permanently unlock the Shadow Monarch, and salute the win.
func play_final_victory() -> void:
	# the fight is over: the Ten lower their weapons and gather (their walking
	# village avatars take it from here -- these battle stand-ins bow out)
	for a in get_tree().get_nodes_in_group("ten_ally"):
		if is_instance_valid(a):
			var t = a.create_tween()
			t.tween_property(a, "modulate:a", 0.0, 2.0)
			t.tween_callback(a.queue_free)
	GameState.mark_game_completed()
	# The Shadow Court (11): the raiders were the farmer's apparatus, and the
	# apparatus dies with the farmer. Per-run and saved -- if the player quits
	# during the dialogue below, settle_shadow_court() finishes the coronation
	# the next time they stand in their village.
	GameState.despair_dead = true
	DialogueBox.play(self, Story.ENDING, func():
		# the first royal act (9.6): every fallen villager rises as a shadow of
		# themselves -- names, homes, jobs and bonds kept. The village Orin
		# murdered gets back up, as the Shadow Monarch's people.
		GameState.raise_shadow_army()
		# NG+ (11): the time-reversal spoil. Re-granted on a later victory only
		# if the last one was spent -- one hourglass per world.
		var p = get_tree().get_first_node_in_group("player")
		if p and "inventory" in p and p.inventory and p.inventory.get_count("relic_rewound_hour") == 0:
			p.inventory.add_item("relic_rewound_hour", 1)
			show_notification("Among the spoils: ⌛ THE REWOUND HOUR. The world can be made to start again — and you would be immune.")
		show_notification("Deepwood stands. The Shadow Monarch has returned — a new class awaits your next journey."))

# Deep-level rescues: a reserved important figure (VillagerQuests.IMPORTANT_FIGURES,
# levels 85/90/95) is chained up in this level to be freed with E. Skipped once
# they've been rescued (the roster dedupes, same as village hostages). They add
# to the roster on rescue and their walking avatar appears back in the village.
const ADVENTURER_RESCUE = preload("res://adventurer_rescue.gd")
const TROPHY_VAULT = preload("res://trophy_vault.gd")

func spawn_deep_rescue() -> void:
	# a BLUEPRINT satchel (5.2) may lie at this floor -- the plans for one
	# village building, lost when Deepwood fell, paced by the dependency
	# ladder so everything is in hand by floor 30
	if GameState.BLUEPRINT_FLOORS.has(current_level):
		var bp_name: String = GameState.BLUEPRINT_FLOORS[current_level]
		if not GameState.has_blueprint(bp_name):
			var bp = preload("res://blueprint_pickup.gd").new()
			bp.building_name = bp_name
			bp.position = Vector2(current_width * 0.62, GROUND_Y)
			$LevelContainer.add_child(bp)
			show_notification("Something papery glints in the gloom — plans, maybe...")
	# a Trophy Vault of the Ten (GAME_BIBLE §8) may hang hidden in this floor --
	# deep past the fighting, at the far reaches, a discovery rather than loot
	var ten = TheTen.for_level(current_level)
	if not ten.is_empty() and not GameState.ten_freed(str(ten.get("id", ""))):
		var tv = TROPHY_VAULT.new()
		tv.ten_id = str(ten.get("id", ""))
		tv.position = Vector2(current_width * 0.82, GROUND_Y)
		$LevelContainer.add_child(tv)
		show_notification("Something gilded glints deep in this level — one of Orin's trophies...")
	# a chained adventurer of the deep nine (GAME_BIBLE 2.4.1) may be held here
	var adv = Adventurers.for_level(current_level)
	if not adv.is_empty():
		var a_state = GameState.adventurer_state(str(adv.get("id", "")))
		if not a_state.get("rescued", true):
			var ar = ADVENTURER_RESCUE.new()
			ar.adventurer_id = str(adv.get("id", ""))
			ar.position = Vector2(current_width * 0.35, GROUND_Y - 40.0)
			$LevelContainer.add_child(ar)
			show_notification("An adventurer is chained in this level — free them!")
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
	# AMBUSH (a bad surprise, dev 2026-07-21): now and then a couple of the floor's
	# own drop in from high up as you fight -- extra bodies to clear, this floor's
	# own monster types, so it stings without a fresh difficulty tier.
	if randf() < 0.32:
		for k in range(2):
			spawn_enemy(Vector2(randf_range(600.0, current_width - 300.0), GROUND_Y - randf_range(220.0, 340.0)))

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

# ===================== THE HARVEST (GAME_BIBLE 9.3 / 9.4) =====================
# The turned village, streamed as waves; the Devourer eating the living; the
# Ten holding lanes. Population is 150+ at full staffing -- NEVER all at once.
const HARVEST_WAVE_GAP := 6.0     # seconds between waves
const HARVEST_WAVE_SIZE := 4
const HARVEST_LIVE_CAP := 12      # living transformed on screen at most
const DEVOUR_INTERVAL := 5.0      # the Monarch eats one living transformed
const DEVOUR_TIERS := 20          # +1 tier per 5% of the population consumed
var _harvest_pool: Array = []
var _harvest_total := 1
var _harvest_wave_timer := 0.0
var _devour_timer := 0.0
var _devoured := 0
var _monarch: Node = null

func _physics_process(delta: float) -> void:
	# the straggler hint tracks the player, so refresh it a few times a
	# second while the hunt is down to the last few
	if level_in_progress and alive_count > 0 and alive_count <= 3:
		_hint_timer -= delta
		if _hint_timer <= 0.0:
			_hint_timer = 0.35
			update_level_label()
	if _monarch == null or not is_instance_valid(_monarch) or _monarch.is_dead:
		return
	# stream the town in, wave by named wave
	_harvest_wave_timer -= delta
	if _harvest_wave_timer <= 0.0 and not _harvest_pool.is_empty():
		_harvest_wave_timer = HARVEST_WAVE_GAP
		var living := get_tree().get_nodes_in_group("transformed").filter(func(t): return is_instance_valid(t) and not t.is_dead).size()
		for i in range(mini(HARVEST_WAVE_SIZE, HARVEST_LIVE_CAP - living)):
			if _harvest_pool.is_empty():
				break
			_spawn_transformed(str(_harvest_pool.pop_back()))
	# the Devourer race: he eats the LIVING transformed; your kills deny him
	_devour_timer -= delta
	if _devour_timer <= 0.0:
		_devour_timer = DEVOUR_INTERVAL
		var prey: Node = null
		var best := 999999.0
		for t in get_tree().get_nodes_in_group("transformed"):
			if not is_instance_valid(t) or t.is_dead:
				continue
			var d: float = _monarch.global_position.distance_to(t.global_position)
			if d < best:
				best = d
				prey = t
		if prey != null:
			_devoured += 1
			FloatingText.spawn_word(self, prey.global_position + Vector2(0, -40), "DEVOURED", Color(0.7, 0.3, 0.9))
			prey.queue_free()
			_apply_devour_tier()

# Every 5% of the population consumed = +1 power tier: bigger, tougher, harder.
# Rush the horde and you starve him; turtle and face a titan. Winnable either way.
func _apply_devour_tier() -> void:
	var tier := int(floor(float(_devoured) / float(_harvest_total) * float(DEVOUR_TIERS)))
	if _monarch == null or not is_instance_valid(_monarch):
		return
	_monarch.max_health += int(_monarch.max_health * 0.04)
	_monarch.health = mini(_monarch.health + int(_monarch.max_health * 0.06), _monarch.max_health)
	_monarch.damage_multiplier *= 1.1025   # +5% output (damage scales by sqrt)
	_monarch.scale = Vector2.ONE * minf(1.0 + float(tier) * 0.05, 2.0)
	if _monarch.has_method("update_health_bar"):
		_monarch.update_health_bar()
	show_notification("The Devourer swells — tier %d (%d souls eaten). Every kill of yours is one he can't." % [tier, _devoured])

# One turned villager, wearing their NAME -- you know exactly who you're
# cutting down, and exactly who the Shadow Army will give back.
func _spawn_transformed(v_name: String) -> void:
	var enemy = ENEMY_SCENE.instantiate()
	enemy.weapon_type = WEAPON_TYPES[randi() % WEAPON_TYPES.size()]
	enemy.respawns = false
	enemy.instant_aggro = true
	var scaling = get_level_scaling()
	enemy.wave_hp_multiplier = scaling.hp
	enemy.wave_damage_multiplier = scaling.dmg
	enemy.wave_speed_multiplier = scaling.speed
	enemy.apply_block_archetype(19)
	assign_enemy_behavior(enemy)
	enemy.position = Vector2(randf_range(400.0, current_width - 400.0), GROUND_Y - 60.0)
	enemy.add_to_group("dungeon_combatant")
	enemy.add_to_group("transformed")
	$LevelContainer.add_child(enemy)
	enemy.died.connect(_on_combatant_died)
	alive_count += 1
	var nl := Label.new()
	nl.text = v_name
	nl.position = Vector2(-50, -74)
	nl.size = Vector2(100, 14)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.add_theme_font_size_override("font_size", 9)
	nl.add_theme_color_override("font_color", Color(0.85, 0.55, 0.95))
	nl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	nl.add_theme_constant_override("outline_size", 3)
	enemy.add_child(nl)

# (The Ten's lane-holding spawn moved to harvest_director._spawn_ally when the
# Harvest moved from this arena into the village. The dungeon copy was left
# behind with no callers -- removed rather than kept as a decoy.)

func spawn_enemy(at = null) -> void:
	var enemy = ENEMY_SCENE.instantiate()
	enemy.weapon_type = WEAPON_TYPES[randi() % WEAPON_TYPES.size()]
	enemy.respawns = false
	enemy.instant_aggro = true
	var scaling = get_level_scaling()
	enemy.wave_hp_multiplier = scaling.hp
	enemy.wave_damage_multiplier = scaling.dmg
	enemy.wave_speed_multiplier = scaling.speed
	# re-skin into this floor's 5-level block, but MIX a neighbour's LOOK onto ~45%
	# of grunts so the floor fields a varied horde, not one repeated monster. Stats
	# always come from THIS floor's block, so difficulty is unchanged, and a grunt
	# never wears the face of a monster from deeper than you have reached.
	var stat_block := int((current_level - 1) / 5)
	var vis_block := stat_block
	if randf() < 0.45:
		var choices := []
		if stat_block - 1 >= 0:
			choices.append(stat_block - 1)
		var max_seen := int((GameState.highest_unlocked_level - 1) / 5)
		if stat_block + 1 <= max_seen and stat_block + 1 < enemy.ENEMY_ROSTERS.size():
			choices.append(stat_block + 1)
		if not choices.is_empty():
			vis_block = choices[randi() % choices.size()]
	enemy.apply_mixed_archetype(stat_block, vis_block)
	assign_enemy_behavior(enemy)
	enemy.position = at if at != null else Vector2(randf_range(600.0, current_width - 200.0), GROUND_Y - 60.0)
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
	# How deep this fight is decides how LONG its combos run (see
	# boss.gd active_combos). Depth buys longer, nastier sentences -- not
	# bigger numbers.
	boss.boss_floor = current_level
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
	"relic_blink", "relic_reaper", "relic_ward", "relic_steward", "relic_gorgon"]
# The common/uncommon weapon rack. Without this tier every one of these existed,
# was balanced, appeared in the catalogue -- and could never be found by anyone,
# because the class-weapon pool below starts at rare. These are what the first
# ten floors are meant to hand you.
const GEAR_EARLY_WEAPON_IDS = ["wpn_club", "wpn_shortbow", "wpn_apprentice_wand",
	"wpn_dagger", "wpn_shortsword", "wpn_rapier", "wpn_cleaver", "wpn_hatchet", "wpn_woodspear",
	"wpn_slingshot", "wpn_huntingbow", "wpn_sparkwand",
	"wpn_falchion", "wpn_warpick", "wpn_twinblades", "wpn_saber", "wpn_trident",
	"wpn_warglaive", "wpn_crossbow", "wpn_flatbow", "wpn_frostwand", "wpn_channelwand"]
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
	# THE POTIONS RULE (5.5): a felled boss always restocks the belt -- you
	# leave every boss fight provisioned for the next block's climb
	player.inventory.add_item("potion_health", 2)
	player.inventory.add_item("potion_mana", 1)
	show_notification("The boss's cache: 2 health potions, 1 mana potion.")
	if current_level >= EXCELLENT_MIN_LEVEL and randf() < EXCELLENT_DROP_CHANCE:
		var excellents = _gear_unowned(GEAR_EXCELLENT_IDS, player)
		if not excellents.is_empty():
			_give_gear(player, excellents.pick_random(), true)
			return
	var pool = []
	# the early rack is available from the very first floor, and stops appearing
	# once the mid-tier weapons open up so it never dilutes later drops
	if current_level < 12:
		pool += _gear_unowned(GEAR_EARLY_WEAPON_IDS, player)
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
	update_level_label()   # the tally is live, every kill
	if alive_count <= 0 and level_in_progress:
		level_in_progress = false
		level_cleared = true
		# ...and refresh the label AFTER the flags flip: the per-kill refresh
		# above ran while level_cleared was still false and alive_count had
		# just hit zero, so it printed neither the tally nor the clear line.
		# (Caught by the first-session smoke test -- every slice test passed.)
		update_level_label()
		# a cleared floor deserves a SOUND, not only a line of text -- and a
		# felled boss rings brighter than a cleared corridor
		GameState.play_sfx(GameState.SFX_CHIME, 1.6 if is_boss_level(current_level) else 1.15)
		# what you killed STAYS killed -- this floor never repopulates again,
		# in this run, however long you are away (dev rule 2026-07-21)
		GameState.mark_floor_cleared(current_level)
		# a Deep Shrine wakes on every tenth floor -- see _place_deep_shrine
		if GameState.is_shrine_floor(current_level):
			_place_deep_shrine(true)
		GameState.highest_unlocked_level = max(GameState.highest_unlocked_level, current_level + 1)
		# a cleared floor is a milestone worth banking (autosave)
		GameState.autosave("floor %d cleared" % current_level, true)
		# advance any "reach dungeon level N" villager bonds
		GameState.quest_event("reach_level", "", current_level)
		# beating Level 100 = beating Orin = the ending
		if current_level >= MAX_LEVEL:
			call_deferred("play_final_victory")
		# 2.5.1 beat 2: his return lands "right after a boss" -- the floor-15
		# boss falls and for one breath he is simply THERE. The full pact scene
		# then plays on the next village visit.
		if current_level == GameState.ORIN_ARRIVAL_DEPTH and not GameState.seen_orin_glimpse and not GameState.seen_orin_arrival and not GameState.dev_mode:
			GameState.seen_orin_glimpse = true
			call_deferred("play_orin_glimpse")
		show_notification("Level " + str(current_level) + " cleared! The far gate is open.")


func play_orin_glimpse() -> void:
	DialogueBox.play(self, Story.ORIN_GLIMPSE)

# ===================== PROVING GROUNDS (admin test arena) =====================
const DPS_DUMMY = preload("res://dps_dummy.gd")
const VAULT_CHEST = preload("res://vault_chest.gd")
const PROVING_WIDTH = 2600.0   # a medium, regular-dungeon-sized flat room

func build_proving_grounds() -> void:
	current_level = 0
	current_width = PROVING_WIDTH
	current_ceiling = CEILING_Y
	build_background(false)
	build_ground_and_walls()
	# a title banner
	_proving_label(Vector2(PROVING_WIDTH / 2.0, GROUND_Y - 330.0), "THE PROVING GROUNDS",
		Color(1, 0.9, 0.6), 0)
	_proving_label(Vector2(PROVING_WIDTH / 2.0, GROUND_Y - 300.0),
		"open a chest (E) — your bag opens too · drag an item out to take it, drag it back to return · beat the dummy for DPS",
		Color(0.8, 0.78, 0.7), 0)

	# ---- the item vault: one chest per rarity + a materials/consumables chest ----
	var by_grade := {}
	for id in Inventory.ITEM_GRADES.keys():
		var g: String = Inventory.ITEM_GRADES[id]
		if not by_grade.has(g):
			by_grade[g] = []
		by_grade[g].append(id)
	var ungraded := []
	for id in Inventory.ITEM_DEFS.keys():
		var cat: String = Inventory.ITEM_DEFS[id].get("category", "")
		if not Inventory.ITEM_GRADES.has(id) and cat in ["material", "consumable", "currency"]:
			ungraded.append(id)

	var order := ["common", "uncommon", "rare", "epic", "legendary", "mythic"]
	var chests := []
	for g in order:
		var ids: Array = by_grade.get(g, [])
		var gd: Dictionary = Inventory.GRADE_DEFS.get(g, {})
		chests.append({"ids": ids, "title": g.to_upper(),
			"sub": "%d items · drag to take" % ids.size(), "accent": gd.get("color", Color.WHITE)})
	chests.append({"ids": ungraded, "title": "MATERIALS & USE",
		"sub": "%d items · drag to take" % ungraded.size(), "accent": Color(0.7, 0.85, 0.55)})

	var margin := 260.0
	var span := PROVING_WIDTH - margin * 2.0
	for i in range(chests.size()):
		var c: Dictionary = chests[i]
		var x: float = margin + span * float(i) / float(chests.size() - 1)
		var chest = VAULT_CHEST.new()
		chest.item_ids = c["ids"]
		chest.title = c["title"]
		chest.subtitle = c["sub"]
		chest.accent = c["accent"]
		$LevelContainer.add_child(chest)
		chest.global_position = Vector2(x, GROUND_Y)

	# ---- the DPS dummy, centre stage ----
	var dummy = DPS_DUMMY.new()
	$LevelContainer.add_child(dummy)
	dummy.global_position = Vector2(PROVING_WIDTH / 2.0, GROUND_Y)

func _proving_label(pos: Vector2, text: String, col: Color, _z: int) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos - Vector2(300, 0)
	l.size = Vector2(600, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.z_index = 40
	$LevelContainer.add_child(l)

func exit_dungeon() -> void:
	GameState.proving_grounds = false   # never carry the test arena back out
	starting = false
	var player = get_tree().get_first_node_in_group("player")
	if player:
		GameState.pending_player_state = GameState.capture_player_state(player)
	GameState.in_dungeon = false
	GameState.returning_from_dungeon = true
	get_tree().change_scene_to_file.call_deferred("res://main.tscn")

func update_level_label() -> void:
	var label = get_node_or_null("CanvasLayer/LevelLabel")
	if label == null:
		return
	# COMPACT ON PURPOSE (visual sweep): the old label read "Level: 5 / 100
	# (Unlocked: 1)" and my straggler hint pushed it long enough to collide
	# with the notification text in the opposite corner -- the two ran
	# together into one unreadable line. "Unlocked" belongs on the level
	# select, not on the wall of the floor you are standing in.
	var text := "Floor %d / %d" % [current_level, MAX_LEVEL]
	# THE STRAGGLER PROBLEM (polish 2026-07-20): the exit only opens on a
	# CLEARED floor, and alive_count was tracked but never shown -- so one
	# mob stuck behind a pillar at the far edge meant blind searching a
	# level wider than a screen. Show the tally, and when the hunt is down
	# to a handful, say which way they are.
	if level_in_progress and alive_count > 0:
		text += "   ⚔ %d left" % alive_count
		if alive_count <= 3:
			var hint := _straggler_hint()
			if hint != "":
				text += "  " + hint
	elif level_cleared:
		text += "   ✔ cleared"
	label.text = text
	label.visible = true

# Which way the nearest living foe lies, for the last few of a floor.
func _straggler_hint() -> String:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return ""
	var best: Node2D = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group("dungeon_combatant"):
		if not is_instance_valid(e) or e.is_in_group("player"):
			continue
		if "is_dead" in e and e.is_dead:
			continue
		var d: float = absf(e.global_position.x - player.global_position.x)
		if d < best_d:
			best_d = d
			best = e
	if best == null:
		return ""
	if best_d < 260.0:
		return "(close)"
	return "◀ west" if best.global_position.x < player.global_position.x else "east ▶"

func show_notification(text: String) -> void:
	var stack = get_node_or_null("CanvasLayer/NotificationStack")
	if stack:
		stack.show_notification(text)
