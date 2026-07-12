extends Node

const SAVE_PATH = "user://savegame.json"
const DEEPEST_LEVEL_PATH = "user://deepest_level.dat"

var pending_load = false
# Deepest dungeon level ever reached in a single run -- a high-score style
# stat, distinct from highest_unlocked_level below (which is the permanent
# progression gate: once a level is cleared it stays enterable forever,
# even if a later run doesn't reach as deep again).
var deepest_level_reached = 0
# Which dungeon levels are enterable -- starts at 1 (only Level 1 open on a
# fresh save). Clearing a level unlocks the next one permanently; this is
# part of the save file, not just a per-run counter (see DungeonManager).
var highest_unlocked_level = 1

# Dungeon entry is a REAL scene transition (main.tscn -> dungeon_interior.tscn
# and back), not an in-place arena spawn -- so a few things need to survive
# the round trip without touching the actual save file on disk:
#   active_dungeon_level: which level dungeon_interior.tscn should build on
#     _ready() (set right before the transition in).
#   pre_dungeon_position: where in the village to put the player back once
#     they return (set right before the transition in, consumed by main.gd).
#   pending_player_state: a snapshot of currency/inventory/weapons/health
#     captured right before EITHER transition, so the freshly-instanced
#     Player on the other side restores it instead of re-granting starting
#     resources (see player.gd's _ready()) or losing progress made mid-run.
var active_dungeon_level = 1
var pre_dungeon_position = Vector2.ZERO
# Vector2.ZERO is itself a plausible real position, so a separate flag marks
# whether pre_dungeon_position should actually be applied on this main.tscn
# boot (true only right after leaving dungeon_interior.tscn -- false on a
# normal New Game/Continue boot, where position comes from elsewhere).
var returning_from_dungeon = false
var pending_player_state: Dictionary = {}

# --- XP / skill tree ---
# Lives here (not on the player node) so it survives dungeon scene swaps
# without the carry-over dance. 1 skill point per level-up. chosen_class is
# "" until the player picks on their first skill-tree open; the reset potion
# clears it again (full refund + free class switch).
var player_xp = 0
var player_level = 1
var skill_points = 0
var chosen_class = ""
var unlocked_skills: Array = []
# Material types the Science Lab has identified -- until a material id is in
# here, the UI shows it as an unknown substance and skill nodes can't spend it.
var researched_materials: Array = []

func xp_to_next_level() -> int:
	return 50 + (player_level - 1) * 30

func add_xp(amount: int) -> void:
	var boosted = int(round(amount * (1.0 + get_skill_total("xp_gain"))))
	player_xp += boosted
	while player_xp >= xp_to_next_level():
		player_xp -= xp_to_next_level()
		player_level += 1
		skill_points += 1
		var player = get_tree().get_first_node_in_group("player")
		var notif = get_tree().get_first_node_in_group("notification_stack")
		if notif:
			notif.show_notification("Level up! You are now level %d (+1 skill point)" % player_level)

func get_skill_total(effect_key: String) -> float:
	var total = 0.0
	for node_id in unlocked_skills:
		var node = SkillTreeData.get_node_by_id(node_id)
		total += node.get("effect", {}).get(effect_key, 0.0)
	return total

func is_skill_unlocked(node_id: String) -> bool:
	return unlocked_skills.has(node_id)

# Points + prereq + (researched) materials, all checked and spent atomically.
func try_unlock_skill(node: Dictionary, player: Node) -> bool:
	if is_skill_unlocked(node.id):
		return false
	if skill_points < node.cost:
		return false
	if node.prereq != "" and not is_skill_unlocked(node.prereq):
		return false
	for mat_id in node.materials.keys():
		if not researched_materials.has(mat_id):
			return false
		if player.inventory.get_count(mat_id) < node.materials[mat_id]:
			return false
	for mat_id in node.materials.keys():
		player.inventory.remove_item(mat_id, node.materials[mat_id])
	skill_points -= node.cost
	unlocked_skills.append(node.id)
	return true

# The reset potion: refunds every spent point AND clears the class choice,
# putting the player back on the class-select screen. Spent materials are
# deliberately NOT refunded.
func reset_skills() -> void:
	skill_points = player_level - 1
	unlocked_skills = []
	chosen_class = ""
# True for the whole time dungeon_interior.tscn is the active scene -- lets
# save_game() below know to record pre_dungeon_position (a real village
# location) instead of the player's dungeon-local coordinates, which would
# be meaningless once loaded back into main.tscn (Continue always lands in
# the village, never back inside a dungeon run).
var in_dungeon = false

func capture_player_state(player: Node) -> Dictionary:
	return {
		"inventory": player.inventory.to_save_data(),
		"owned_weapons": player.owned_weapons.duplicate(true),
		"equipped_weapon": player.equipped_weapon,
		"has_dash": player.has_dash,
		"has_double_jump": player.has_double_jump,
		"health": player.health,
	}

# Set once on the New Game / difficulty-picker screen, saved with the game,
# and never changed mid-playthrough. Controls death-penalty severity only
# (see player.gd's die()) -- no other gameplay scaling reads this.
var difficulty = "Medium"

# Roster of every villager (rescued hostages AND their children), each:
# {"id", "name", "sex", "is_kid", "stat_name", "stat_value", "role_key",
#  "role_title", "paired"}.
# role_key = which building they work at (e.g. "Farm", "Government"), or ""
# if unassigned. role_title = their specific role within that building (e.g.
# "Farmer", "Leader"), or "" if unassigned. Two fields instead of one because
# some role titles (like "Leader") are reused across several buildings, so
# the title alone doesn't say which building someone works at.
# "id" is either the rescuing villager.tscn instance's unique villager_id
# (stops an already-rescued villager from reappearing after a save is
# continued) or a generated "child_..." id for someone born in a mating house.
var rescued_villagers: Array = []

# Per-chest saved contents, keyed by each chest's unique chest_id -- see
# chest.gd. Written whenever a chest's UI is closed.
var chest_contents: Dictionary = {}

# Rescued villagers assigned to a functioning role passively generate
# currency over time (see the vision doc: "roles generate resources over
# time, which the player spends on gear and skill tree upgrades"). Each of
# the 8 REGULAR_STATS buildings pays its worker-tier role_title holders
# their stat_value in gold; Government's Party pays a small flat amount
# each (tax revenue). Farm's Leader and Government's Leader additionally
# boost income -- see the leader-bonus section below.
const INCOME_INTERVAL_SECONDS = 20.0
var income_timer = 0.0
const INCOME_ROLES = {
	"Farm": "Farmer", "Hospital": "Doctors", "Fishing Dock": "Fisherman",
	"Science Lab": "Scientist", "Bank": "Financist", "Blacksmith": "Blacksmith",
	"Tavern": "Barman", "Marketplace": "Trader",
}
const PARTY_MEMBER_INCOME = 1.0

# --- Leader bonuses ---
# Filling a building's Leader/Principal/Warchief slot grants a bonus themed
# to that building, stacking per holder (e.g. School allows 2 Principals =
# up to +30%). These are deliberately separate multipliers, not a single
# generic "leader stat" bonus, so different buildings reward leadership
# differently:
#   Government/Leader -> +village-wide passive income
#   Farm/Leader        -> +Farm's own income, on top of the village-wide one
#   Hospital/Leader     -> +childbirth (gestation) speed
#   School/Principal    -> +School graduation speed
#   Barracks/Warchief   -> +Barracks graduation speed
# "Couple mating speed" and "material generation speed" (mentioned as example
# bonus types) aren't mapped to a building yet -- no current building fits
# the former thematically, and materials don't exist yet for the latter.
const LEADER_BONUS_PER_HOLDER = 0.15

# The day/night clock reading as of the last tick -- used to measure how
# much IN-GAME time passed since then (which can be negative if the player
# just rewound time), rather than how much real time passed. Shared by both
# mating pairings and school/barracks enrollments so the debug time-skip
# keys ([ / ] / \) speed up or rewind both exactly like they do day/night.
var village_last_hours_elapsed = 0.0

# Two-phase mating timeline. Phase 1: the pair occupies the cottage (keyed
# by house_id in mating_houses) for COTTAGE_OCCUPANCY_HOURS, then leaves --
# freeing the house for a new pairing -- and starts phase 2, a pregnancy
# (keyed by a generated id in `pregnancies`, no longer tied to any house)
# lasting GESTATION_DURATION_HOURS, at the end of which the child is born at
# the Hospital. Both phases tick off GameState's shared in-game clock, so the
# debug time-skip keys speed up/rewind either phase exactly like day/night.
const COTTAGE_OCCUPANCY_HOURS = 1.0
const GESTATION_DURATION_HOURS = 24.0
const CHILD_NAMES = ["Tomi", "Sasha", "Luca", "Mira", "Finn", "Ari", "Noa", "Ren"]
var mating_houses: Dictionary = {}
var pregnancies: Dictionary = {}

# Active School/Barracks enrollments, keyed by villager_id:
# {"remaining_hours", "grants_stat"}. grants_stat is either "random" (School
# picks one of REGULAR_STATS) or a specific stat name (Barracks always
# grants "Warrior"). 24 in-game HOURS, same clock as mating pairings.
const EDUCATION_DURATION_HOURS = 24.0
# The 8 "regular" professions a School graduate can randomly come out with.
# Leadership titles (Leader/Principal/Warchief) are deliberately never
# taught here -- see building_roles.gd for why.
const REGULAR_STATS = ["Farm", "Hospital", "Fishing", "Scientist", "Financist", "Blacksmith", "Tavern", "Marketplace"]
var school_enrollments: Dictionary = {}

signal couple_departed(house_id, male_id, female_id)
signal child_produced(child_id)

func _ready() -> void:
	load_deepest_level()

func _process(delta: float) -> void:
	income_timer += delta
	if income_timer >= INCOME_INTERVAL_SECONDS:
		income_timer -= INCOME_INTERVAL_SECONDS
		generate_passive_income()
	tick_village_clock()

func tick_village_clock() -> void:
	var dnc = get_tree().get_first_node_in_group("day_night_cycle")
	if not dnc:
		return
	var current_hours = dnc.total_hours_elapsed
	var hours_passed = current_hours - village_last_hours_elapsed
	village_last_hours_elapsed = current_hours
	# pregnancies first: a cottage stay completing this same tick (below)
	# creates a fresh pregnancy that must start at the full duration, not get
	# immediately clipped by this tick's hours_passed too.
	update_pregnancies(hours_passed)
	update_mating_houses(hours_passed)
	update_school_enrollments(hours_passed)

func generate_passive_income() -> void:
	var total = 0.0
	var village_mult = get_village_income_multiplier()
	for villager in rescued_villagers:
		var role_key = villager.get("role_key", "")
		var role_title = villager.get("role_title", "")
		var value = 0.0
		if INCOME_ROLES.get(role_key, "") == role_title:
			value = float(villager.get("stat_value", 0))
			if role_key == "Farm":
				value *= get_farm_income_multiplier()
		elif role_key == "Government" and role_title == "Party":
			value = PARTY_MEMBER_INCOME
		total += value * village_mult
	if total <= 0:
		return
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("add_currency"):
		player.add_currency(int(round(total)))

func count_leader_holders(role_key: String, title: String) -> int:
	var count = 0
	for villager in rescued_villagers:
		if villager.get("role_key") == role_key and villager.get("role_title") == title:
			count += 1
	return count

func get_village_income_multiplier() -> float:
	return 1.0 + count_leader_holders("Government", "Leader") * LEADER_BONUS_PER_HOLDER

func get_farm_income_multiplier() -> float:
	return 1.0 + count_leader_holders("Farm", "Leader") * LEADER_BONUS_PER_HOLDER

func get_gestation_speed_multiplier() -> float:
	return 1.0 + count_leader_holders("Hospital", "Leader") * LEADER_BONUS_PER_HOLDER

func get_school_graduation_speed_multiplier() -> float:
	return 1.0 + count_leader_holders("School", "Principal") * LEADER_BONUS_PER_HOLDER

func get_barracks_graduation_speed_multiplier() -> float:
	return 1.0 + count_leader_holders("Barracks", "Warchief") * LEADER_BONUS_PER_HOLDER

func find_available_parents() -> Dictionary:
	var male_id = ""
	var female_id = ""
	for villager in rescued_villagers:
		if villager.get("paired", false):
			continue
		if villager.get("sex") == "Male" and male_id == "":
			male_id = villager.get("id", "")
		elif villager.get("sex") == "Female" and female_id == "":
			female_id = villager.get("id", "")
	return {"male_id": male_id, "female_id": female_id}

func start_pairing(house_id: String, male_id: String, female_id: String) -> void:
	mating_houses[house_id] = {"male_id": male_id, "female_id": female_id, "remaining_hours": COTTAGE_OCCUPANCY_HOURS}
	for villager in rescued_villagers:
		if villager.get("id") == male_id or villager.get("id") == female_id:
			villager["paired"] = true
	# in case either partner is already out wandering from a previous cycle,
	# they're stepping back into the cottage now -- clear their old avatar.
	remove_npc_avatar(male_id)
	remove_npc_avatar(female_id)

# Phase 1: the pair leaves the cottage (freeing it for a new pairing) once
# COTTAGE_OCCUPANCY_HOURS elapses, then immediately starts phase 2.
func update_mating_houses(hours_passed: float) -> void:
	if mating_houses.is_empty():
		return
	var departed_ids = []
	for house_id in mating_houses.keys():
		mating_houses[house_id]["remaining_hours"] -= hours_passed
		if mating_houses[house_id]["remaining_hours"] <= 0:
			departed_ids.append(house_id)
	for house_id in departed_ids:
		var pairing = mating_houses[house_id]
		mating_houses.erase(house_id)
		var pregnancy_id = "preg_%d_%d" % [Time.get_ticks_msec(), randi() % 100000]
		pregnancies[pregnancy_id] = {"male_id": pairing.male_id, "female_id": pairing.female_id, "remaining_hours": GESTATION_DURATION_HOURS}
		couple_departed.emit(house_id, pairing.male_id, pairing.female_id)

# Phase 2: GESTATION_DURATION_HOURS after leaving the cottage, the child is
# born at the Hospital (see building.gd's Hospital-only child_produced hook).
func update_pregnancies(hours_passed: float) -> void:
	if pregnancies.is_empty():
		return
	var sped_up_hours = hours_passed * get_gestation_speed_multiplier()
	var completed_ids = []
	for pregnancy_id in pregnancies.keys():
		pregnancies[pregnancy_id]["remaining_hours"] -= sped_up_hours
		if pregnancies[pregnancy_id]["remaining_hours"] <= 0:
			completed_ids.append(pregnancy_id)
	for pregnancy_id in completed_ids:
		produce_child(pregnancy_id)

func produce_child(pregnancy_id: String) -> void:
	var pairing = pregnancies[pregnancy_id]
	pregnancies.erase(pregnancy_id)
	for villager in rescued_villagers:
		if villager.get("id") == pairing.male_id or villager.get("id") == pairing.female_id:
			villager["paired"] = false
	var child_sex = "Male" if randi() % 2 == 0 else "Female"
	var child_name = CHILD_NAMES[randi() % CHILD_NAMES.size()]
	var child_id = "child_%d_%d" % [Time.get_ticks_msec(), randi() % 100000]
	rescued_villagers.append({
		"id": child_id, "name": child_name, "sex": child_sex, "is_kid": true,
		"stat_name": "", "stat_value": 0, "role_key": "", "role_title": "", "paired": false,
	})
	child_produced.emit(child_id)

# Finds a villager's current wander-AI world avatar (if any) via the shared
# "npc" group -- see npc.gd -- and removes it. Used when a pair steps back
# into a cottage for another pregnancy after already having one before.
func remove_npc_avatar(villager_id: String) -> void:
	for npc in get_tree().get_nodes_in_group("npc"):
		if npc.villager_id == villager_id:
			npc.queue_free()

# --- School / Barracks enrollment ---

func enroll_villager(villager_id: String, role_key: String, role_title: String, grants_stat: String) -> void:
	for villager in rescued_villagers:
		if villager.get("id") == villager_id:
			villager["role_key"] = role_key
			villager["role_title"] = role_title
	school_enrollments[villager_id] = {"remaining_hours": EDUCATION_DURATION_HOURS, "grants_stat": grants_stat, "role_key": role_key}

func update_school_enrollments(hours_passed: float) -> void:
	if school_enrollments.is_empty():
		return
	var school_hours = hours_passed * get_school_graduation_speed_multiplier()
	var barracks_hours = hours_passed * get_barracks_graduation_speed_multiplier()
	var graduated_ids = []
	for villager_id in school_enrollments.keys():
		var enrollment = school_enrollments[villager_id]
		var sped_up_hours = school_hours if enrollment.get("role_key", "School") == "School" else barracks_hours
		enrollment["remaining_hours"] -= sped_up_hours
		if enrollment["remaining_hours"] <= 0:
			graduated_ids.append(villager_id)
	for villager_id in graduated_ids:
		graduate_villager(villager_id)

func graduate_villager(villager_id: String) -> void:
	var enrollment = school_enrollments[villager_id]
	school_enrollments.erase(villager_id)
	var granted_stat = enrollment.grants_stat
	if granted_stat == "random":
		granted_stat = REGULAR_STATS[randi() % REGULAR_STATS.size()]
	for villager in rescued_villagers:
		if villager.get("id") == villager_id:
			villager["is_kid"] = false
			villager["stat_name"] = granted_stat
			villager["stat_value"] = 3
			villager["role_key"] = ""
			villager["role_title"] = ""

func load_deepest_level() -> void:
	if FileAccess.file_exists(DEEPEST_LEVEL_PATH):
		var file = FileAccess.open(DEEPEST_LEVEL_PATH, FileAccess.READ)
		deepest_level_reached = file.get_32()
		file.close()

func record_level_reached(level: int) -> void:
	if level > deepest_level_reached:
		deepest_level_reached = level
		var file = FileAccess.open(DEEPEST_LEVEL_PATH, FileAccess.WRITE)
		file.store_32(deepest_level_reached)
		file.close()

# Called on genuine New Game (not Continue) -- GameState is an autoload that
# survives scene changes, so without this, starting a New Game after an
# active session would silently carry over the previous session's villagers,
# mating state, and unlocked dungeon levels instead of starting clean.
func reset_for_new_game() -> void:
	rescued_villagers = []
	chest_contents = {}
	mating_houses = {}
	pregnancies = {}
	school_enrollments = {}
	highest_unlocked_level = 1
	village_last_hours_elapsed = 0.0
	player_xp = 0
	player_level = 1
	skill_points = 0
	chosen_class = ""
	unlocked_skills = []
	researched_materials = []

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game(player: Node) -> void:
	var save_pos = pre_dungeon_position if in_dungeon else player.global_position
	var data = {
		"currency": player.currency,
		"inventory": player.inventory.to_save_data(),
		"position_x": save_pos.x,
		"position_y": save_pos.y,
		"owned_weapons": player.owned_weapons,
		"equipped_weapon": player.equipped_weapon,
		"has_dash": player.has_dash,
		"has_double_jump": player.has_double_jump,
		"health": player.health,
		"difficulty": difficulty,
		"rescued_villagers": rescued_villagers,
		"chest_contents": chest_contents,
		"mating_houses": mating_houses,
		"pregnancies": pregnancies,
		"school_enrollments": school_enrollments,
		"highest_unlocked_level": highest_unlocked_level,
		"player_xp": player_xp,
		"player_level": player_level,
		"skill_points": skill_points,
		"chosen_class": chosen_class,
		"unlocked_skills": unlocked_skills,
		"researched_materials": researched_materials,
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func load_game() -> Dictionary:
	if not has_save():
		return {}
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		if parsed.has("difficulty"):
			difficulty = parsed["difficulty"]
		if parsed.has("rescued_villagers"):
			rescued_villagers = parsed["rescued_villagers"]
		if parsed.has("chest_contents"):
			chest_contents = parsed["chest_contents"]
		if parsed.has("mating_houses"):
			mating_houses = parsed["mating_houses"]
		if parsed.has("pregnancies"):
			pregnancies = parsed["pregnancies"]
		if parsed.has("school_enrollments"):
			school_enrollments = parsed["school_enrollments"]
		if parsed.has("highest_unlocked_level"):
			highest_unlocked_level = parsed["highest_unlocked_level"]
		player_xp = parsed.get("player_xp", player_xp)
		player_level = parsed.get("player_level", player_level)
		skill_points = parsed.get("skill_points", skill_points)
		chosen_class = parsed.get("chosen_class", chosen_class)
		unlocked_skills = parsed.get("unlocked_skills", unlocked_skills)
		researched_materials = parsed.get("researched_materials", researched_materials)
		return parsed
	return {}

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)

func rescue_villager(data: Dictionary) -> void:
	rescued_villagers.append(data)

func is_villager_rescued(villager_id: String) -> bool:
	for entry in rescued_villagers:
		if entry.get("id") == villager_id:
			return true
	return false

func assign_villager_to_role(villager_id: String, role_key: String, role_title: String) -> void:
	for villager in rescued_villagers:
		if villager.get("id") == villager_id:
			villager["role_key"] = role_key
			villager["role_title"] = role_title
			return

# Called by the death sequence (player.gd's die()) on Medium/Hard.
func remove_random_villager() -> void:
	if rescued_villagers.is_empty():
		return
	var removed = rescued_villagers[randi() % rescued_villagers.size()]
	rescued_villagers.erase(removed)
	var removed_id = removed.get("id")
	for house_id in mating_houses.keys():
		var pairing = mating_houses[house_id]
		if pairing.male_id == removed_id or pairing.female_id == removed_id:
			mating_houses.erase(house_id)
	for pregnancy_id in pregnancies.keys():
		var pairing = pregnancies[pregnancy_id]
		if pairing.male_id == removed_id or pairing.female_id == removed_id:
			pregnancies.erase(pregnancy_id)
	if school_enrollments.has(removed_id):
		school_enrollments.erase(removed_id)
	remove_npc_avatar(removed_id)

# TODO: wire up once the skill material system exists
func remove_one_skill_material() -> void:
	pass
