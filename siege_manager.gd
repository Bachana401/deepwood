extends Node

# Presents LIVE sieges while the player is in the village. Scheduling and
# off-screen (player-away) resolution now live in GameState so the clock and
# assaults keep advancing in every scene -- this node just stages the physical
# battle when GameState says one is due here: it spawns the attacker wave,
# tracks it, and on a full repel repairs the wall + tells GameState the live
# battle is over.

const SIEGE_ENEMY_SCENE = preload("res://siege_enemy.tscn")

const BASE_COUNT = 3
const MAX_COUNT = 12
const BASE_HP = 50.0
const BASE_DMG = 10.0
const HP_PER_TIER = 0.30
const DMG_PER_TIER = 0.20

const SPAWN_Y = -70.0
const DEFAULT_WALL_X = 4700.0
const SPAWN_STANDOFF = 360.0

# Barracks soldiers: visible defenders that sally out to meet the raiders. Count
# = trained warriors, capped. They're a bit tankier/harder-hitting than raiders.
const MAX_SOLDIERS = 6
const SOLDIER_BASE_HP = 62.0
const SOLDIER_BASE_DMG = 12.0
const SOLDIER_SALLY_OFFSET = 130.0   # spawn just outside the wall (west), then charge on
const DUNGEON_APPROACH = 640.0       # west raiders start this far out -- an approach from the deep

var alive_count = 0
var siege_number = 0
var soldiers: Array = []
var label: Label = null

func _ready() -> void:
	add_to_group("siege_manager")
	build_label()
	# RESUME A WEEPING NIGHT (bug hunt 2026-07-28): a trip below (underground,
	# a dungeon floor) frees this manager with the scene -- without this, the
	# fresh manager never restarted the trickle, and the rest of the night
	# passed in silence while dawn still paid the survivor's bundle.
	if GameState.weeping_tonight:
		start_weeping_night(maxi(1, GameState.current_siege_tier()))

func _process(_delta: float) -> void:
	update_label()

# Both ramparts, by flank. Scenes without an east wall (old layouts, test
# rigs) degrade gracefully to a single-front siege.
func wall_for_flank(flank: String) -> Node:
	var fallback: Node = null
	for w in get_tree().get_nodes_in_group("village_wall"):
		if "flank" in w and w.flank == flank:
			return w
		fallback = w
	return fallback if flank == "west" else null

# Called by GameState.trigger_siege() when a scheduled siege lands while the
# player is here in the village. The wave pours out of the DUNGEON (the west/pit
# side) -- and only once Orin is freed (floor 15) does the east road open as a
# second, unannounced front (see two_fronts below).
func start_live_siege(tier: int, is_black := false) -> void:
	# idempotence guard (audit hardening): tick_sieges is the sole caller today
	# and gates on GameState.live_siege_active itself, but a second entry point
	# would have zeroed alive_count with raiders standing and ended it early
	if GameState.live_siege_active:
		return
	siege_number += 1
	# a Black Tide (3c) fields a visibly BIGGER horde -- past the usual cap
	var cap = MAX_COUNT + (6 if is_black else 0)
	var count = min(BASE_COUNT + tier, cap)
	var hp = int(round(BASE_HP * (1.0 + (tier - 1) * HP_PER_TIER)))
	var dmg = int(round(BASE_DMG * (1.0 + (tier - 1) * DMG_PER_TIER)))

	var west_wall = wall_for_flank("west")
	var east_wall = wall_for_flank("east")
	# THE EAST FRONT STAYS SHUT until Orin is freed (clearing floor 15, dev
	# 2026-07-22). Before that every wave pours out of the DUNGEON -- the west/pit
	# side ONLY. Afterward the east road opens too, same as the left -- and the
	# player is never told: they find out by seeing raiders where there were none.
	var two_fronts := GameState.orin_arrived() and east_wall != null
	var west_count: int = int(ceil(count / 2.0)) if two_fronts else count
	var east_count: int = (count - west_count) if two_fronts else 0

	alive_count = 0
	# the west wave marches in FROM THE DUNGEON side -- spawned further out so it
	# reads as a horde climbing the road out of the deep, not popping in at the gate
	for i in range(west_count):
		var face_x = west_wall.west_face_x() if west_wall else DEFAULT_WALL_X
		_spawn_raider(hp, dmg, tier, west_wall,
			Vector2(face_x - DUNGEON_APPROACH - i * randf_range(34.0, 70.0), SPAWN_Y))
	for i in range(east_count):
		_spawn_raider(hp, dmg, tier, east_wall,
			Vector2(east_wall.east_face_x() + SPAWN_STANDOFF + i * randf_range(34.0, 70.0), SPAWN_Y))

	# NEUTRAL announcement -- never names the flanks, so the east front is a
	# discovery, not a headline
	if is_black:
		notify("🌑 A BLACK TIDE rises out of the deep! Wave %d — %d attackers (tier %d). The wall cannot hold this alone — hold with your defenders!" % [siege_number, count, tier])
	else:
		notify("A siege! Wave %d — %d claw up out of the dark (tier %d)." % [siege_number, count, tier])
	_spawn_barracks_soldiers(tier, west_wall, east_wall)

func _spawn_raider(hp: int, dmg: int, tier: int, wall, pos: Vector2) -> void:
	var e = SIEGE_ENEMY_SCENE.instantiate()
	e.skin = "raider"          # PixelLab goblin marauder art
	e.max_health = hp
	e.attack_damage = dmg
	e.reward = 5 + tier
	e.wall = wall
	e.global_position = pos
	e.died.connect(_on_enemy_died)
	get_parent().add_child(e)
	alive_count += 1

# The Barracks answers the horn: trained warriors sally out (just west of the
# wall) as visible Soldier units and charge the raiders. Reuses the siege_enemy
# body with faction "village" + the soldier sprite skin.
# One soldier/hero body, posted to a flank: west defenders sally just east
# of the west rampart facing the wild; east defenders mirror it.
func _post_for_flank(west_wall, east_wall, index: int) -> Dictionary:
	# match where the RAIDERS actually are: pre-Orin the east front is shut (all raiders
	# spawn west), so posting half the garrison to the east wall left it defending an empty
	# flank while the west took the whole wave. Gate on two_fronts, not merely east_wall.
	var to_east: bool = GameState.orin_arrived() and east_wall != null and index % 2 == 1
	if to_east:
		return {"wall": east_wall, "facing": 1,
			"x": east_wall.west_face_x() + SOLDIER_SALLY_OFFSET + (index / 2) * randf_range(30.0, 55.0)}
	var face_x = west_wall.west_face_x() if west_wall else DEFAULT_WALL_X
	return {"wall": west_wall, "facing": -1,
		"x": face_x - SOLDIER_SALLY_OFFSET - (index / 2) * randf_range(30.0, 55.0)}

func _spawn_barracks_soldiers(tier: int, west_wall, east_wall) -> void:
	soldiers.clear()
	# Barracks-forged HEROES sally first: one unit each, on top of the soldier
	# cap, at triple a soldier's strength -- the 0.5% birth paying off in force.
	# Each hero marches under their OWN name and power (rolled at graduation) --
	# a 0.5% miracle never fights like a big generic soldier. Heroes alternate
	# flanks: legends stand where the line is thinnest.
	var hero_villagers := []
	for v in GameState.rescued_villagers:
		if v.get("hero_trained", false):
			hero_villagers.append(v)
	var hero_hp = int(round(SOLDIER_BASE_HP * 3.0 * (1.0 + (tier - 1) * HP_PER_TIER)))
	var hero_dmg = int(round(SOLDIER_BASE_DMG * 3.0 * (1.0 + (tier - 1) * DMG_PER_TIER)))
	var rally_present := false
	for i in range(hero_villagers.size()):
		var hv: Dictionary = hero_villagers[i]
		var post := _post_for_flank(west_wall, east_wall, i)
		var h = SIEGE_ENEMY_SCENE.instantiate()
		h.faction = "village"
		h.skin = "soldier"
		h.max_health = hero_hp
		h.attack_damage = hero_dmg
		h.hero_power = str(hv.get("hero_power", "warcry"))
		h.hero_name = str(hv.get("name", "Hero"))
		if h.hero_power == "rally":
			rally_present = true
		h.wall = post.wall
		h.facing = post.facing
		h.global_position = Vector2(post.x - 40.0 * post.facing, SPAWN_Y)
		h.died.connect(_on_soldier_died.bind(h))
		get_parent().add_child(h)
		h.scale = Vector2(1.25, 1.25)   # a hero reads bigger on the field
		soldiers.append(h)
	if not hero_villagers.is_empty():
		notify("★ %d HERO%s take%s the field!" % [hero_villagers.size(), "" if hero_villagers.size() == 1 else "ES", "s" if hero_villagers.size() == 1 else ""])
	# 7.3: only the ON-SHIFT half answers the horn -- and a siege landing at
	# the changeover catches the wall between watches, half of THOSE still
	# pulling their boots on. The weak window is deliberate, and announced.
	var n = min(GameState.on_duty_warrior_count(), MAX_SOLDIERS)
	if GameState.in_shift_change_window() and n > 1:
		n = int(ceil(n / 2.0))
		notify("⚠ The horn caught the shift change — only half the watch stands ready!")
	if n <= 0:
		return
	var hp = int(round(SOLDIER_BASE_HP * (1.0 + (tier - 1) * HP_PER_TIER)))
	# Rally: a hero of the banner on the field hardens every soldier who
	# marches beside them
	if rally_present:
		hp = int(round(hp * 1.5))
	var dmg = int(round(SOLDIER_BASE_DMG * (1.0 + (tier - 1) * DMG_PER_TIER)))
	for i in range(n):
		var post := _post_for_flank(west_wall, east_wall, i)
		var s = SIEGE_ENEMY_SCENE.instantiate()
		s.faction = "village"
		s.skin = "soldier"
		s.max_health = hp
		s.attack_damage = dmg
		s.wall = post.wall
		s.facing = post.facing
		s.global_position = Vector2(post.x, SPAWN_Y)
		s.died.connect(_on_soldier_died.bind(s))
		get_parent().add_child(s)
		soldiers.append(s)
	notify("%d soldier%s march out — the %s watch holds the line!" % [n, "" if n == 1 else "s", GameState.on_duty_shift().to_upper()])

func _on_soldier_died(s) -> void:
	soldiers.erase(s)

# === THE REAVER CARAVAN (renewability pillar 2, 2026-07-28) ===
# Not a siege: a MARCHING PARTY. Three structured waves up the EAST road --
# each held wave summons the next, the third walks in with a named captain --
# and a full repel pays the Reaver Cache. Reuses the raider body, the
# soldier sally and the wall logic wholesale.
var caravan_wave := 0     # 0 = idle; 1..3 while the caravan runs
var caravan_tier := 0

func start_caravan(tier: int) -> void:
	# never on top of a live siege -- the road defers to the war
	if GameState.live_siege_active or caravan_wave > 0:
		GameState.live_caravan_active = false
		GameState.resolve_caravan_offline(tier)
		return
	caravan_tier = tier
	caravan_wave = 0
	notify("⚔ THE REAVER CARAVAN rolls up the east road — three waves! Hold the gate!")
	GameState.log_event("combat", "A reaver caravan reached the east road (tier %d)." % tier)
	_next_caravan_wave()

func _next_caravan_wave() -> void:
	caravan_wave += 1
	var east_wall = wall_for_flank("east")
	var west_wall = wall_for_flank("west")
	var wall = east_wall if east_wall != null else west_wall
	var count: int = 2 + caravan_wave + caravan_tier / 3
	var hp = int(round(BASE_HP * (1.0 + (caravan_tier - 1) * HP_PER_TIER)))
	var dmg = int(round(BASE_DMG * (1.0 + (caravan_tier - 1) * DMG_PER_TIER)))
	var base_x: float = (east_wall.east_face_x() if east_wall != null else DEFAULT_WALL_X + 900.0)
	for i in range(count):
		_spawn_raider(hp, dmg, caravan_tier, wall,
			Vector2(base_x + SPAWN_STANDOFF + i * randf_range(34.0, 70.0), SPAWN_Y))
	if caravan_wave == 3:
		_spawn_captain(wall, hp, dmg, base_x)
	else:
		notify("⚔ Caravan wave %d of 3 — they keep coming!" % caravan_wave)
	if caravan_wave == 1:
		_spawn_barracks_soldiers(caravan_tier, west_wall, east_wall)

func _spawn_captain(wall, hp: int, dmg: int, base_x: float) -> void:
	var c = SIEGE_ENEMY_SCENE.instantiate()
	c.skin = "raider"
	c.max_health = hp * 5
	c.attack_damage = int(round(dmg * 1.6))
	c.reward = 40 + caravan_tier * 5
	c.wall = wall
	c.global_position = Vector2(base_x + SPAWN_STANDOFF + 260.0, SPAWN_Y)
	c.died.connect(_on_enemy_died)
	get_parent().add_child(c)
	c.scale = Vector2(1.4, 1.4)
	c.modulate = Color(1.2, 0.82, 0.66)   # the captain reads bigger and meaner
	alive_count += 1
	var cname: String = GameState.CARAVAN_CAPTAIN_NAMES[randi() % GameState.CARAVAN_CAPTAIN_NAMES.size()]
	notify("☠ The third wave — and %s walks with it!" % cname)

func end_caravan() -> void:
	caravan_wave = 0
	alive_count = 0
	for wall in get_tree().get_nodes_in_group("village_wall"):
		if wall.has_method("repair_fully"):
			wall.repair_fully()
	for s in soldiers:
		if is_instance_valid(s):
			s.queue_free()
	soldiers.clear()
	GameState.live_caravan_active = false
	GameState.grant_reaver_cache(caravan_tier, false)
	notify("The caravan breaks and runs — the road is yours!")
	GameState.log_event("combat", "The reaver caravan was repelled at the gate.")

func _on_enemy_died() -> void:
	alive_count -= 1
	if alive_count <= 0:
		if GameState.live_caravan_active and caravan_wave > 0:
			if caravan_wave < 3:
				_next_caravan_wave()
			else:
				end_caravan()
		elif GameState.live_siege_active:
			end_siege()

# === THE WEEPING HOUR (night event, 2026-07-28) ============================
# All night, a TRICKLE: one to three pale weepers every few seconds from
# either road, many and quick but light-handed -- pressure, never one-shots
# (the boss rule holds at the walls too). They stand OUTSIDE the wave
# machinery on purpose: alive_count belongs to sieges and caravans, and a
# weeper's death must never end someone else's battle.
const WEEP_TRICKLE_SEC := 7.0
const WEEP_MAX_LIVE := 9
var weeping_timer: Timer = null
var weeping_tier := 1
var weepers: Array = []

func start_weeping_night(tier: int) -> void:
	weeping_tier = tier
	if weeping_timer == null:
		weeping_timer = Timer.new()
		weeping_timer.wait_time = WEEP_TRICKLE_SEC
		weeping_timer.timeout.connect(_weeping_trickle)
		add_child(weeping_timer)
	weeping_timer.start()
	_weeping_trickle()   # the first sob arrives with the word

func _weeping_trickle() -> void:
	if not GameState.weeping_tonight:
		return
	# the night pauses while the player is away below -- villagers hide, and
	# an empty stage must not silently pile up a horde for their return
	if GameState.in_dungeon:
		return
	weepers = weepers.filter(func(w): return is_instance_valid(w))
	if weepers.size() >= WEEP_MAX_LIVE:
		return
	var east_wall = wall_for_flank("east")
	var west_wall = wall_for_flank("west")
	# light-handed on purpose: weepers press as a crowd, not as executioners
	var hp = int(round(BASE_HP * (0.8 + (weeping_tier - 1) * HP_PER_TIER * 0.8)))
	var dmg = maxi(1, int(round(BASE_DMG * (0.65 + (weeping_tier - 1) * DMG_PER_TIER * 0.7))))
	var n: int = 1 + (randi() % 2) + weeping_tier / 5
	for i in range(mini(n, WEEP_MAX_LIVE - weepers.size())):
		var from_east: bool = randf() < 0.5
		var wall = (east_wall if from_east else west_wall)
		if wall == null:
			wall = east_wall if east_wall != null else west_wall
		var pos: Vector2
		if from_east:
			var bx: float = (east_wall.east_face_x() if east_wall != null else DEFAULT_WALL_X + 900.0)
			pos = Vector2(bx + SPAWN_STANDOFF + i * randf_range(30.0, 64.0), SPAWN_Y)
		else:
			var fx: float = (west_wall.west_face_x() if west_wall != null else DEFAULT_WALL_X)
			pos = Vector2(fx - SPAWN_STANDOFF - i * randf_range(30.0, 64.0), SPAWN_Y)
		var e = SIEGE_ENEMY_SCENE.instantiate()
		e.skin = "raider"
		e.max_health = hp
		e.attack_damage = dmg
		e.reward = 3 + weeping_tier / 2
		e.wall = wall
		e.global_position = pos
		e.died.connect(_on_weeper_died)
		get_parent().add_child(e)
		# the pale ones: moon-washed and a little translucent, unmistakably
		# NOT raiders even in the dark
		e.modulate = Color(0.72, 0.84, 1.1, 0.88)
		weepers.append(e)

func _on_weeper_died() -> void:
	GameState.weeping_kills += 1
	# sorrow condenses: better than half the fallen leave a Pale Tear
	if randf() < 0.55:
		var pl = get_tree().get_first_node_in_group("player")
		if pl and "inventory" in pl and pl.inventory:
			pl.inventory.add_item("tear_pale", 1)

func end_weeping_night() -> void:
	if weeping_timer != null:
		weeping_timer.stop()
	# whatever still walks melts with the light
	for w in weepers:
		if is_instance_valid(w):
			w.queue_free()
	weepers.clear()

func end_siege() -> void:
	alive_count = 0
	# both ramparts get patched between assaults (7.2)
	for wall in get_tree().get_nodes_in_group("village_wall"):
		if wall.has_method("repair_fully"):
			wall.repair_fully()
	# surviving soldiers march back to the Barracks
	for s in soldiers:
		if is_instance_valid(s):
			s.queue_free()
	soldiers.clear()
	GameState.on_live_siege_ended()
	notify("Siege repelled! The walls are patched up.")

func notify(text: String) -> void:
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack:
		stack.show_notification(text)

func build_label() -> void:
	var ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	label = Label.new()
	label.anchor_left = 0.5
	label.anchor_right = 0.5
	label.offset_left = -170.0
	label.offset_right = 170.0
	label.offset_top = 44.0
	label.offset_bottom = 66.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.6, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 4)
	ui_layer.add_child(label)

func update_label() -> void:
	if not label:
		return
	if GameState.despair_dead:
		label.text = "☾ The nights are quiet — Despair is dead. Deepwood is yours."
	elif GameState.harvest_at_home:
		# THE FINALE OWNS THE TOP OF THE SCREEN (dev 2026-07-23): the Monarch's boss
		# banner sits top-centre here, and there is no "next siege" to foresee -- the
		# siege apparatus IS the Harvest now -- so the foresight label stands aside.
		label.text = ""
	elif GameState.live_siege_active:
		label.text = "⚔ SIEGE  -  %d attacker%s left" % [alive_count, "" if alive_count == 1 else "s"]
	elif not GameState.seen_arrival_battle:
		# the PROLOGUE is playing -- no HUD chatter over the opening
		label.text = ""
	elif not GameState.siege_clock_visible():
		# 7.1: Act I is TRUE CHAOS -- until the Watchtower stands there is no
		# indicator at all. You cannot plan; you can only stay ready.
		label.text = "The night keeps its own counsel. (Raise the Watchtower to read it.)"
	else:
		label.text = "🗼 Next siege in %.0fh  (tier %d)" % [max(GameState.hours_until_next_siege, 0.0), GameState.current_siege_tier()]
