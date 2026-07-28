extends Node2D

# HIDDEN EVENT-BOSS DIRECTOR (2026-07-28). Mounted into whatever scene the
# player is standing in (village or dungeon) by GameState.tick_hidden_events
# the instant a secret condition is met. It stages ONE event boss, shows the
# cinematic banner, and pays out the exclusive loot table when the boss falls.
# Modelled on harvest_director._spawn_monarch -- the same proven recipe, minus
# the wave/devour machinery (an event boss is a duel, not the finale).
#
# Set `event_id` BEFORE add_child. The director self-registers in the
# "event_boss_director" group so GameState knows an event is live and won't
# stack a second one; leaving the scene frees it, which re-clears the slot.

const BOSS_SCENE = preload("res://boss.tscn")

var event_id := ""
var _boss: Node = null
var _ev: Dictionary = {}
var _done := false

func _ready() -> void:
	add_to_group("event_boss_director")
	_ev = EventBoss.get_event(event_id)
	var p = get_tree().get_first_node_in_group("player")
	if _ev.is_empty() or p == null or not is_instance_valid(p):
		queue_free()
		return
	_spawn(p)

func _spawn(p: Node) -> void:
	# The player stands on the ground, so their feet Y is the ground line in any
	# scene -- no need to know whether this is the village or the deep.
	var ground_y: float = p.global_position.y
	var boss = BOSS_SCENE.instantiate()
	boss.boss_id = str(_ev.get("boss_id", "gravewarden"))
	var sc: Dictionary = EventBoss.scaling_for(event_id)
	boss.level_hp_mult = float(sc.get("hp", 1.0))
	boss.damage_multiplier = float(sc.get("dmg", 1.0))
	boss.speed_multiplier = 1.0
	boss.boss_floor = int(sc.get("floor", 22))
	# spawn a room's width to one side and above the ground so it settles down;
	# boss.gd clamps its own x to the arena each frame, so an out-of-bounds guess
	# self-corrects rather than stranding it in a wall.
	var side: float = 1.0 if randf() < 0.5 else -1.0
	add_child(boss)
	# set GLOBAL position after entering the tree -- the village root and the
	# dungeon's LevelContainer sit at different transforms, so a local position
	# would drop the boss in the wrong place in one of them.
	boss.global_position = Vector2(p.global_position.x + side * 620.0, ground_y - 150.0)
	# MUST be a target: boss.gd never self-registers, and every ally / aura /
	# weapon splash scans the hostile groups (see harvest_director's note).
	boss.add_to_group("dungeon_combatant")
	boss.died.connect(_on_boss_died)
	_boss = boss

	# the cinematic name-card + top-screen banner (every boss is an EVENT)
	var hud = get_tree().get_first_node_in_group("boss_hud")
	if hud == null:
		hud = preload("res://boss_hud.gd").new()
		hud.name = "BossHUD"
		add_child(hud)
	if hud.has_method("present"):
		hud.present(str(_ev.get("name", "?")),
			str(_ev.get("banner", "")) + "  —  " + str(sc.get("label", "")) + " event",
			sc.get("accent", Color(1, 1, 1)))
	GameState.notify("Something you did has woken " + str(_ev.get("name", "a hidden foe")) + "…")
	GameState.play_sfx(GameState.SFX_CHIME, 0.6)

func _on_boss_died() -> void:
	if _done:
		return
	_done = true
	var p = get_tree().get_first_node_in_group("player")
	var granted: Array = EventBoss.award(p, event_id)
	GameState.on_event_boss_killed(event_id)
	if granted.is_empty():
		GameState.notify(str(_ev.get("name", "The foe")) + " falls — but your bag was full. Make room and it drops nothing twice!")
	else:
		GameState.notify(str(_ev.get("name", "The foe")) + " falls! You claim: " + ", ".join(granted))
	# linger a beat so the banner/loot toasts read, then clear the slot
	await get_tree().create_timer(2.5).timeout
	queue_free()

# Fleeing the fight (a scene change frees the boss WITHOUT its died signal, so
# _on_boss_died never runs) must not strand the event as "triggered" for the
# rest of the run -- re-arm it here so it can fire again, mirroring the load
# path. `_done` is set on a real kill, so a genuine victory never re-arms.
func _exit_tree() -> void:
	if not _done and GameState.event_state.get(event_id, "") == "triggered":
		GameState.event_state[event_id] = "armed"
