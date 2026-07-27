extends Node2D

# THE HARVEST, AT HOME (new finale canon, 2026-07-20).
#
# The old finale fought Orin in the floor-100 arena. The dev's rework: floor
# 100 is EMPTY -- the false victory is carried home, the feast pumps the
# village to its peak, and Orin springs the trap at the height of the joy he
# engineered. So the fight happens HERE, in the streets the player built:
# the transformed town streams in waves wearing their own names, the Devourer
# eats the living to grow, the Ten (and Roland) hold lanes, and the Soul
# Split Wand opens the only window the deathless has ever shown.
#
# This node is added to the VILLAGE scene by main.gd when GameState.feast_ready()
# and runs the whole sequence: false victory -> feast -> reveal -> fight ->
# victory -> Shadow Army. The fight machinery mirrors dungeon_interior's proven
# loop (waves / devour / tiers), restaged on the village ground.

const ENEMY_SCENE = preload("res://enemy.tscn")
const BOSS_SCENE = preload("res://boss.tscn")
const WEAPON_TYPES = ["sword", "spear", "bow"]

const HARVEST_WAVE_GAP := 6.0
const HARVEST_WAVE_SIZE := 4
const HARVEST_LIVE_CAP := 12
const DEVOUR_INTERVAL := 5.0
const DEVOUR_TIERS := 20
const FEAST_SECONDS := 7.0          # lanterns and laughter before the lightning

var _harvest_pool: Array = []
var _harvest_total := 1
var _harvest_wave_timer := 0.0
var _devour_timer := 0.0
var _devoured := 0
var _monarch: Node = null
var _fight_on := false
var _revealed := false      # double-trigger guard: the reveal happens ONCE
# Quit (or crash) mid-Harvest and come back: the half-turned town cannot be
# left half-turned forever. main.gd mounts the director with resume=true and
# the fight re-stages directly -- Orin re-raises what fell; only killing HIM
# ends this. Without this path a mid-fight quit stranded the world: no Orin,
# no ending, ten souls in a dead town.
var resume := false
var _ground_y := -39.0
var _west_x := 4400.0
var _east_x := 5600.0

func _ready() -> void:
	var m = get_parent()
	if m != null and "VILLAGE_Y" in m:
		_ground_y = m.VILLAGE_Y
	if m != null and "village_right_edge" in m:
		_east_x = float(m.village_right_edge) + 300.0
	# claim the flag only once a PLAYER exists to run the beat (audit fix): the
	# bailouts below queue_free() this director, and a flag set before them
	# stayed stuck for the session -- sieges off, the deep sealed, and the
	# feast unable to ever fire again until a Quit -> Continue cleared it.
	if get_tree().get_first_node_in_group("player") == null:
		queue_free()
		return
	GameState.harvest_at_home = true
	if resume:
		_revealed = true
		var p = get_tree().get_first_node_in_group("player")
		if p == null:
			GameState.harvest_at_home = false
			queue_free()
			return
		# the wand guard holds on the resume road too
		if "inventory" in p and p.inventory != null and p.inventory.get_count("wpn_soulsplit") == 0:
			p.inventory.add_item("wpn_soulsplit", 1)
			_notify("Elenwe presses the Soul Split Wand back into your hand: \"An undivided soul cannot be destroyed. You will need this.\"")
		DialogueBox.play(p, Story.HARVEST_RESUME, func():
			resume_fight())
		return
	begin_false_victory()

# The resumed fight: the pool rebuilds from the SAVED harvested roster --
# Orin re-raises what fell while you were gone. Only killing him ends this.
func resume_fight() -> void:
	_harvest_pool = []
	for v in GameState.harvested_villagers:
		_harvest_pool.append(str(v.get("name", "a villager")))
	_harvest_pool.shuffle()
	_harvest_total = maxi(1, _harvest_pool.size())
	_clear_taken_avatars()
	_spawn_monarch()
	for t in TheTen.ids():
		_spawn_ally(t, "")
	var rst: Dictionary = GameState.adventurer_state("adv_roland")
	if rst.get("rescued", false) and not rst.get("dead", false):
		_spawn_ally("", "Roland")
	_harvest_wave_timer = 2.0
	_fight_on = true

# ---- 1. THE FALSE VICTORY + THE FEAST ----
func begin_false_victory() -> void:
	var p = get_tree().get_first_node_in_group("player")
	if p == null:
		GameState.harvest_at_home = false   # never strand the flag with the director
		queue_free()
		return
	DialogueBox.play(p, Story.FALSE_VICTORY, func():
		GameState.feast_glow = true
		GameState.log_event("people", "The deep stood silent — Deepwood feasted, believing the war was won.")
		_notify("🏮 Deepwood feasts. Morale has never been higher.")
		GameState.play_sfx(GameState.SFX_CHIME, 1.4)
		# process_always=FALSE: create_timer defaults to ticking THROUGH a pause,
		# so the reveal used to fire over an open pause menu -- and closing that
		# menu then unpaused straight into the Monarch fight the player thought
		# was held. The feast clock now waits with the world.
		var t := get_tree().create_timer(FEAST_SECONDS, false)
		t.timeout.connect(begin_reveal))

# ---- 2. THE REVEAL AT THE FEAST ----
func begin_reveal() -> void:
	# a SceneTree timer callback (the feast timer outlives us): if the player quit to menu
	# during the ~7s unpaused feast, we're out of the tree and get_tree() is null.
	if not is_inside_tree():
		return
	if _revealed:
		return
	_revealed = true
	var p = get_tree().get_first_node_in_group("player")
	if p == null:
		GameState.harvest_at_home = false   # never strand the flag with the director
		queue_free()
		return
	GameState.play_sfx(GameState.SFX_THUD, 0.6)   # the lightning's answer
	# Elenwe's guard (the softlock rule): the wand returns to your hand at the
	# moment it is about to matter, with the line that explains the whole lock.
	if "inventory" in p and p.inventory != null and p.inventory.get_count("wpn_soulsplit") == 0:
		p.inventory.add_item("wpn_soulsplit", 1)
		_notify("Elenwe presses the Soul Split Wand back into your hand: \"An undivided soul cannot be destroyed. You will need this.\"")
	DialogueBox.play(p, Story.REVEAL_AT_FEAST, func():
		GameState.feast_glow = false
		begin_fight())

# ---- 3. THE HARVEST FIGHT, IN THE STREETS ----
func begin_fight() -> void:
	GameState.begin_harvest()
	_harvest_pool = []
	for v in GameState.harvested_villagers:
		_harvest_pool.append(str(v.get("name", "a villager")))
	# THE DEFENDERS' FATE (12.6): Wren and Castor, if they still stand, walk
	# in the horde as named turned -- their deaths are real. Roland holds.
	for aid in ["adv_wren", "adv_castor"]:
		var ast: Dictionary = GameState.adventurer_state(aid)
		if ast.get("rescued", false) and not ast.get("dead", false):
			GameState.adventurers[aid]["dead"] = true
			var aname := str(Adventurers.get_def(aid).get("name", aid))
			_harvest_pool.append(aname)
			GameState.log_event("combat", "%s was taken by the turning at the feast." % aname)
			_notify("%s walks in the horde — turned against the village they held." % aname)
	_harvest_pool.shuffle()
	_harvest_total = maxi(1, _harvest_pool.size())
	_clear_taken_avatars()
	_spawn_monarch()
	for t in TheTen.ids():
		_spawn_ally(t, "")
	var rst: Dictionary = GameState.adventurer_state("adv_roland")
	if rst.get("rescued", false) and not rst.get("dead", false):
		_spawn_ally("", "Roland")
		_notify("Roland plants his shield at your side: \"We hold. Same as always.\"")
	_harvest_wave_timer = 2.0
	_fight_on = true

# The turned cannot ALSO stroll the streets as civilians: when the roster
# wipes, every walking avatar whose villager is gone fades out (taken by the
# turning). The Ten's avatars survive -- their people are still in the roster.
func _clear_taken_avatars() -> void:
	for n in get_tree().get_nodes_in_group("npc"):
		if not n.has_method("find_villager_data"):
			continue
		if n.find_villager_data().is_empty():
			var tw = n.create_tween()
			tw.tween_property(n, "modulate:a", 0.0, 1.2)
			tw.tween_callback(n.queue_free)

func _spawn_monarch() -> void:
	var boss = BOSS_SCENE.instantiate()
	boss.boss_id = "wizard"
	# floor-100 scaling, computed from the dungeon's own curve
	var DI = load("res://dungeon_interior.gd")
	var di = DI.new()
	di.current_level = 100
	var scaling: Dictionary = di.get_level_scaling()
	di.free()
	boss.level_hp_mult = scaling.hp
	boss.damage_multiplier = scaling.dmg
	boss.speed_multiplier = scaling.speed
	boss.boss_floor = 100
	var p = get_tree().get_first_node_in_group("player")
	var px: float = p.global_position.x if p != null else (_west_x + _east_x) / 2.0
	boss.position = Vector2(clampf(px + 420.0, _west_x, _east_x), _ground_y - 220.0)
	add_child(boss)
	# HE MUST BE A TARGET. boss.gd never self-registers, and every group-scanning
	# ally and weapon in the game (shades, the 12 adventurers, auras, novas,
	# excellent-weapon splash, villager flee) looks for course_enemy /
	# dungeon_combatant / siege_enemy -- without this the whole Shadow Army stood
	# inert through the finale while the Monarch's own summons DID join the group.
	boss.add_to_group("dungeon_combatant")
	_monarch = boss
	# the Devourer starts WEAK (9.4): his power must be EATEN, not given.
	# boss damage scales by sqrt(damage_multiplier), so x0.25 halves his
	# output. (The old finale wrote to a nonexistent 'attack_damage' and
	# silently never weakened him at all -- caught by the error log.)
	boss.damage_multiplier *= 0.25
	# THE CLIMAX IS AN EVENT TOO (dev 2026-07-23, seen with EYES). Every dungeon boss
	# gets the spectacle overlay -- cinematic name-card + the big top-screen health
	# banner -- but the BossHUD is only ever seated in the dungeon, so the FINAL boss,
	# fought here in the streets, arrived with none (update_health_bar's set_health
	# found no boss_hud and no-op'd; only the tiny overhead bar showed). Seat one for
	# the finale and present him, so the Monarch of Despair enters with more ceremony
	# than a floor-5 miniboss -- exactly the "every boss an EVENT" rule (boss_hud.gd).
	var hud = get_tree().get_first_node_in_group("boss_hud")
	if hud == null:
		hud = preload("res://boss_hud.gd").new()
		hud.name = "BossHUD"
		add_child(hud)                      # CanvasLayer(60): renders over the village
	if hud.has_method("present"):
		hud.present("The Monarch of Despair", "Orin — the end of the living",
			Color(0.58, 0.28, 0.82))         # a royal despair-violet

func _spawn_ally(ten_id: String, override_name: String) -> void:
	var ally = load("res://ten_ally.gd").new()
	ally.ten_id = ten_id
	if override_name != "":
		ally.override_name = override_name
		ally.power_scale = 0.7
	var p = get_tree().get_first_node_in_group("player")
	var px: float = p.global_position.x if p != null else _west_x + 400.0
	ally.position = Vector2(px + randf_range(-320.0, 320.0), _ground_y - 40.0)
	add_child(ally)
	if ten_id != "":
		var def = TheTen.get_def(ten_id)
		FloatingText.spawn_word(self, ally.position + Vector2(0, -80), def.get("name", "?"), Color(1.0, 0.85, 0.4))

func _spawn_transformed(v_name: String) -> void:
	var enemy = ENEMY_SCENE.instantiate()
	enemy.weapon_type = WEAPON_TYPES[randi() % WEAPON_TYPES.size()]
	enemy.respawns = false
	enemy.instant_aggro = true
	var DI = load("res://dungeon_interior.gd")
	var di = DI.new()
	di.current_level = 100
	var scaling: Dictionary = di.get_level_scaling()
	di.free()
	enemy.wave_hp_multiplier = scaling.hp
	enemy.wave_damage_multiplier = scaling.dmg
	enemy.wave_speed_multiplier = scaling.speed
	enemy.apply_block_archetype(19)
	# they come from BOTH edges of the town they lived in
	var from_west := randf() < 0.5
	enemy.position = Vector2(_west_x if from_west else _east_x, _ground_y - 60.0)
	enemy.add_to_group("transformed")
	# same as the dungeon-side _spawn_transformed: without a hostile group the
	# horde is invisible to shades, defenders and every group-scanning weapon
	enemy.add_to_group("dungeon_combatant")
	add_child(enemy)
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

func _physics_process(delta: float) -> void:
	if not _fight_on:
		return
	if _monarch == null or not is_instance_valid(_monarch) or _monarch.is_dead:
		if _fight_on:
			_fight_on = false
			call_deferred("_victory")
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

# power tiers already granted -- the growth curve is PER TIER and hard-capped
var _devour_tier_applied := 0

func _apply_devour_tier() -> void:
	var tier := mini(DEVOUR_TIERS,
		int(floor(float(_devoured) / float(maxi(1, _harvest_total)) * float(DEVOUR_TIERS))))
	if _monarch == null or not is_instance_valid(_monarch):
		return
	# every soul still FEEDS him (the sustain race the fight is about)...
	_monarch.health = mini(_monarch.health + int(_monarch.max_health * 0.06), _monarch.max_health)
	# ...but POWER rises once per TIER and stops at the cap. The old code
	# multiplied damage per SOUL eaten with no cap at all (DEVOUR_TIERS only
	# capped the notification text and his sprite scale), so a 40-soul village
	# compounded x66 damage and his ordinary beam crossed the one-shot line
	# (player 160 HP) about two minutes in. At the cap the curve tops out at
	# 1.1025^20 = x7.04 -- sqrt discipline makes that x2.65 output: nasty,
	# never lethal in one hit.
	while _devour_tier_applied < tier:
		_devour_tier_applied += 1
		_monarch.max_health += int(_monarch.max_health * 0.04)
		# +5% damage OUTPUT per tier: sqrt(x1.1025) = x1.05
		_monarch.damage_multiplier *= 1.1025
	_monarch.scale = Vector2.ONE * minf(1.0 + float(tier) * 0.05, 2.0)
	if _monarch.has_method("update_health_bar"):
		_monarch.update_health_bar()
	_notify("The Devourer swells — tier %d (%d souls eaten). Every kill of yours is one he can't." % [tier, _devoured])

# ---- 4. VICTORY: the return, and the Shadow Army ----
func _victory() -> void:
	# called via call_deferred from _physics_process the frame the Monarch dies; a
	# quit-to-menu that same frame detaches us before the deferred flush -> get_tree() null.
	if not is_inside_tree():
		return
	GameState.harvest_at_home = false
	for a in get_tree().get_nodes_in_group("ten_ally"):
		if is_instance_valid(a):
			var t = a.create_tween()
			t.tween_property(a, "modulate:a", 0.0, 2.0)
			t.tween_callback(a.queue_free)
	for t2 in get_tree().get_nodes_in_group("transformed"):
		if is_instance_valid(t2):
			t2.queue_free()
	GameState.mark_game_completed()
	GameState.despair_dead = true
	var p = get_tree().get_first_node_in_group("player")
	if p == null:
		queue_free()
		return
	# Grant the hourglass BEFORE the ending dialogue: a quit (or crash) while the
	# six lines play used to skip the callback and lock NG+ / the true ending out
	# of that save forever (settle_shadow_court never granted it). The autosave on
	# the next arrival banks it.
	if p and "inventory" in p and p.inventory and p.inventory.get_count("relic_rewound_hour") == 0 and not GameState.cycle_broken:
		p.inventory.add_item("relic_rewound_hour", 1)
		_notify("Among the spoils: ⌛ THE REWOUND HOUR. The world can be made to start again — and you would be immune.")
	DialogueBox.play(p, Story.ENDING, func():
		GameState.raise_shadow_army()
		_notify("Deepwood stands. The Shadow Monarch has returned — a new class awaits your next journey.")
		var m = get_parent()
		if m != null and m.has_method("spawn_existing_villager_avatars"):
			m.spawn_existing_villager_avatars()
		queue_free())

func _notify(text: String) -> void:
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack:
		stack.show_notification(text)
