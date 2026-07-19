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

# Story: the opening plea (Story.OPENING) plays once at the start of a new game.
# Persisted so Continue never replays it; reset by reset_for_new_game().
var seen_intro := false
# The Level-100 reveal (Story.L100_REVEAL) plays once per playthrough, at the
# gate. Per-save, reset by reset_for_new_game().
var seen_l100_reveal := false
# Beating Orin at Level 100 completes the game and PERMANENTLY unlocks the
# Shadow Monarch class for all future runs (persisted in its own file, like
# deepest_level -- survives new games). Loaded in _ready via load_game_completed.
const GAME_COMPLETED_PATH = "user://game_completed.dat"
var game_completed := false

func load_game_completed() -> void:
	game_completed = FileAccess.file_exists(GAME_COMPLETED_PATH)

func mark_game_completed() -> void:
	if game_completed:
		return
	game_completed = true
	var f = FileAccess.open(GAME_COMPLETED_PATH, FileAccess.WRITE)
	if f:
		f.store_8(1)
		f.close()

# === DEV / TEST MODE =========================================================
# The single switch that separates the developer's testing sandbox from the
# real, honest game. OFF (default) = a proper playthrough: weak starter kit, no
# gold, no admin wand/test gear, skills cost points + materials, only dungeon
# Lv1 open, real death penalties, an empty village you must rescue. ON = every
# testing convenience below is restored. Enable by launching with `--dev` (set
# in _ready), or flip this default to true. The four TEST_* flags all mirror it.
var dev_mode := false

# All driven by dev_mode in _ready() -- kept as named vars so the many existing
# GameState.TEST_* reads keep working unchanged.
var TEST_UNLOCK_ALL_LEVELS := false   # every dungeon level open from the start
var TEST_INSTANT_RESPAWN := false     # death skips the 7s countdown
var TEST_SKILL_SANDBOX := false       # skill nodes ignore point + material cost
var TEST_POPULATE_VILLAGE := false    # auto-fill the roster with sample villagers
const POPULATE_STAFF_FRACTION = 0.55

# Standing torches the player has placed with G (see player.try_place_torch):
# array of {x, y}. Respawned by main.gd on scene load; saved with the game.
var placed_torches: Array = []

const POPULATE_NAMES = ["Ash", "Bram", "Cora", "Dain", "Edda", "Finn", "Gwen",
	"Hale", "Iris", "Jory", "Kira", "Lorn", "Mira", "Nash", "Orla", "Pike",
	"Quinn", "Rook", "Sage", "Tess", "Ulf", "Vera", "Wren", "Yara", "Zed",
	"Bryn", "Cade", "Dara", "Eryn", "Flint"]

# Fill every building's non-enrollment roles to ~POPULATE_STAFF_FRACTION and
# add a handful of unemployed wanderers. Leaders (1-slot roles) are filled for
# every other building so roughly half have one.
func test_populate_village() -> void:
	if rescued_villagers.size() >= 10:
		return   # a real roster exists; don't pollute it
	var idx := 0
	var building_i := 0
	for bn in STARTING_BUILDINGS:
		building_i += 1
		for role_def in BuildingRoles.get_roles(bn):
			if role_def.get("is_enrollment", false):
				continue
			var slots = int(role_def.slots)
			var fill = int(floor(slots * POPULATE_STAFF_FRACTION))
			if slots == 1:
				fill = building_i % 2   # every other building gets its Leader
			for i in range(fill):
				var nm = POPULATE_NAMES[idx % POPULATE_NAMES.size()]
				if idx >= POPULATE_NAMES.size():
					nm += " %d" % (idx / POPULATE_NAMES.size() + 1)
				rescued_villagers.append({
					"id": "pop_%d" % idx, "name": nm,
					"sex": ["Male", "Female"][idx % 2], "is_kid": false,
					"stat_name": role_def.get("required_stat", ""),
					"role_key": bn, "role_title": role_def.title,
				})
				idx += 1
	for i in range(8):
		rescued_villagers.append({
			"id": "pop_u%d" % i, "name": POPULATE_NAMES[(idx + i) % POPULATE_NAMES.size()] + " the Idle",
			"sex": ["Male", "Female"][i % 2], "is_kid": false,
			"stat_name": "", "role_key": "", "role_title": "",
		})

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
# Proving Grounds: an admin test arena reusing dungeon_interior.tscn -- all items
# in labelled chests + an invincible DPS dummy, no combat. Set before entering.
var proving_grounds := false
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

# --- Equipment ---
# Worn gear, each holding an item_id ("" = empty). helmet/chest/pants/weapon
# are single slots; relics is a fixed 6-length array but only the first
# relic_slot_count() are usable (4 at first, 5 at Lv10, 6 at Lv20). armor &
# relic bonuses fold into get_bonus_total (alongside skill effects); the
# "weapon" slot holds an Excellent weapon, whose special power lives on the
# player (see player.gd) rather than as a stat total.
const RELIC_MAX_SLOTS = 6
# The ONE list of gear slots. Everything that walks slots reads these, so adding
# a slot can't leave a stale copy behind -- which is exactly how gloves/boots got
# dropped from reset_for_new_game and blew up every stat query on a new game.
const ARMOUR_SLOTS = ["helmet", "chest", "pants", "gloves", "boots"]
const GEAR_SLOTS = ["helmet", "chest", "pants", "gloves", "boots", "weapon"]

static func empty_equipment() -> Dictionary:
	var e := {}
	for s in GEAR_SLOTS:
		e[s] = ""
	e["relics"] = ["", "", "", "", "", ""]
	return e

var equipment = empty_equipment()

func relic_slot_count() -> int:
	if TEST_SKILL_SANDBOX:
		return RELIC_MAX_SLOTS   # testing: all 6 relic slots usable at any level
	if player_level >= 20:
		return 6
	if player_level >= 10:
		return 5
	return 4

func get_equipment_total(effect_key: String) -> float:
	var total = 0.0
	for slot in ARMOUR_SLOTS:
		total += item_equip_effect(equipment[slot], effect_key)
	for i in range(relic_slot_count()):
		total += item_equip_effect(equipment.relics[i], effect_key)
	return total

func item_equip_effect(item_id: String, effect_key: String) -> float:
	if item_id == "":
		return 0.0
	return Inventory.get_item_def(item_id).get("equip_effect", {}).get(effect_key, 0.0)

# Every weapon passively buffs a bit of everything while wielded, scaled by its
# grade (Inventory.get_weapon_passive) -- so a higher-grade weapon makes you
# universally stronger, not just via its attack.
func get_weapon_passive_total(effect_key: String) -> float:
	var wid = wielded_weapon_id()
	if wid == "":
		return 0.0
	return Inventory.get_weapon_passive(wid).get(effect_key, 0.0)

# Single source of truth for combat/economy bonuses: skill tree + worn gear
# + completed set bonuses + the wielded weapon's grade passive.
func get_bonus_total(effect_key: String) -> float:
	return get_skill_total(effect_key) + get_equipment_total(effect_key) + get_set_bonus_total(effect_key) + get_weapon_passive_total(effect_key) + monarch_bonus(effect_key)

func get_equipped_item_ids() -> Array:
	var ids = []
	for slot in GEAR_SLOTS:
		if equipment[slot] != "":
			ids.append(equipment[slot])
	for i in range(relic_slot_count()):
		if equipment.relics[i] != "":
			ids.append(equipment.relics[i])
	return ids

func set_pieces_equipped(set_id: String) -> int:
	var sd = Inventory.SET_DEFS.get(set_id, {})
	var equipped = get_equipped_item_ids()
	var count = 0
	for piece in sd.get("pieces", []):
		if piece in equipped:
			count += 1
	return count

func is_set_complete(set_id: String) -> bool:
	var sd = Inventory.SET_DEFS.get(set_id, {})
	var pieces = sd.get("pieces", [])
	return not pieces.is_empty() and set_pieces_equipped(set_id) >= pieces.size()

# The weapon currently wielded from the hotbar (player.gd) -- counts toward
# a set's full (armor + weapon) tier even though it isn't a gear slot.
func wielded_weapon_id() -> String:
	var p = get_tree().get_first_node_in_group("player")
	if p and "active_weapon_id" in p:
		return p.active_weapon_id
	return ""

# Two set tiers stack: completing the armor pieces pays "bonus"; ALSO wielding
# the set's weapon (if the set names one) pays "full_bonus" on top.
func get_set_bonus_total(effect_key: String) -> float:
	var total = 0.0
	var wielded = wielded_weapon_id()
	for set_id in Inventory.SET_DEFS.keys():
		var sd = Inventory.SET_DEFS[set_id]
		var worn = set_pieces_equipped(set_id)
		# partial 2-piece bonus first, then the full-armour bonus, then the
		# even-greater tier for also wielding the set weapon
		if worn >= 2:
			total += sd.get("bonus_2pc", {}).get(effect_key, 0.0)
		if worn >= sd.get("pieces", []).size():
			total += sd.get("bonus", {}).get(effect_key, 0.0)
			if sd.get("weapon", "") != "" and sd.get("weapon", "") == wielded:
				total += sd.get("full_bonus", {}).get(effect_key, 0.0)
	return total

# Equip an item from the player's inventory into its matching slot. Any item
# already in that slot goes back to the inventory (a swap). relic_index picks
# which of the usable relic slots to fill (-1 = first empty, else that slot).
func equip_item(item_id: String, player: Node, relic_index: int = -1) -> bool:
	if not Inventory.is_equippable(item_id):
		return false
	if player.inventory.get_count(item_id) <= 0:
		return false
	var category = Inventory.get_category(item_id)
	if category == "relic":
		var idx = relic_index
		if idx < 0:
			idx = first_empty_relic_slot()
		if idx < 0 or idx >= relic_slot_count():
			return false
		player.inventory.remove_item(item_id, 1)
		if equipment.relics[idx] != "":
			player.inventory.add_item(equipment.relics[idx], 1)
		equipment.relics[idx] = item_id
	else:
		var slot = Inventory.get_equip_slot(item_id)  # helmet/chest/pants/weapon
		if not equipment.has(slot):
			return false
		player.inventory.remove_item(item_id, 1)
		if equipment[slot] != "":
			player.inventory.add_item(equipment[slot], 1)
		equipment[slot] = item_id
	if player.has_method("on_equipment_changed"):
		player.on_equipment_changed()
	return true

func unequip_slot(slot: String, player: Node, relic_index: int = -1) -> void:
	var item_id = ""
	if slot == "relic":
		if relic_index < 0 or relic_index >= RELIC_MAX_SLOTS:
			return
		item_id = equipment.relics[relic_index]
		equipment.relics[relic_index] = ""
	else:
		if not equipment.has(slot):
			return
		item_id = equipment[slot]
		equipment[slot] = ""
	if item_id != "":
		player.inventory.add_item(item_id, 1)
	if player.has_method("on_equipment_changed"):
		player.on_equipment_changed()

func first_empty_relic_slot() -> int:
	for i in range(relic_slot_count()):
		if equipment.relics[i] == "":
			return i
	return -1

# Rebuild the equipment dict from saved (JSON-parsed) data, sanitizing shape
# so a malformed/old save can't leave slots missing or the relic array short.
func load_equipment(data: Dictionary) -> void:
	for slot in GEAR_SLOTS:
		equipment[slot] = str(data.get(slot, ""))
	var relics: Array = ["", "", "", "", "", ""]
	var saved_relics = data.get("relics", [])
	if saved_relics is Array:
		for i in range(min(saved_relics.size(), RELIC_MAX_SLOTS)):
			relics[i] = str(saved_relics[i])
	equipment.relics = relics

func xp_to_next_level() -> int:
	return 50 + (player_level - 1) * 30

func add_xp(amount: int) -> void:
	var boosted = int(round(amount * (1.0 + get_bonus_total("xp_gain"))))
	player_xp += boosted
	while player_xp >= xp_to_next_level():
		player_xp -= xp_to_next_level()
		player_level += 1
		skill_points += 1
		var player = get_tree().get_first_node_in_group("player")
		var notif = get_tree().get_first_node_in_group("notification_stack")
		if notif:
			notif.show_notification("Level up! You are now level %d (+1 skill point)" % player_level)
	announce_monarch_awakening()

# --- The Shadow Monarch (hidden 7-stage passive, tied to character level) ---
# The player is secretly a Shadow Monarch; as they level (cap 100), their true
# nature emerges across 7 stages -- a growing shadow aura, ever-paler skin, and
# a stacking shadow power at each stage. It is never shown in the skill tree; it
# just happens. 7/7 (the level cap) is the full 2x god-form for the finale.
const MONARCH_STAGE_LEVELS := [5, 15, 30, 45, 60, 80, 100]
const MONARCH_STAGE_NAMES := ["Stirring", "Creeping Dark", "Shadowstep",
	"Dread Sovereign", "Veiled", "Ascendant", "Shadow Sovereign"]
const MONARCH_AWAKEN_LINES := [
	"A cold whisper stirs in your shadow...",
	"The dark creeps closer. Your shadow lengthens.",
	"You slip between shadows without thinking.",
	"A dread presence gathers around you. (Shadow Monarch 4/7)",
	"Your skin has gone deathly pale. The hood hides what you are becoming.",
	"The shadow is a living cloak now. You are almost sovereign.",
	"THE SHADOW MONARCH AWAKENS. Your true form, unshackled. (7/7)",
]
var monarch_stage_announced := 0

# 0 (dormant) .. 7 (full Shadow Monarch), from the player's character level.
func monarch_stage() -> int:
	var s := 0
	for lvl in MONARCH_STAGE_LEVELS:
		if player_level >= lvl:
			s += 1
	return s

# 0..1 progress from the current stage's level toward the next -- lets the aura
# and pallor grow smoothly between breakpoints, not just snap at each stage.
func monarch_progress() -> float:
	var s = monarch_stage()
	if s >= 7:
		return 1.0
	var lo = MONARCH_STAGE_LEVELS[s - 1] if s >= 1 else 1
	var hi = MONARCH_STAGE_LEVELS[s]
	return clampf(float(player_level - lo) / float(maxi(1, hi - lo)), 0.0, 1.0)

# 0..1 overall shadow intensity (stage + progress), for aura/pallor scaling.
func monarch_intensity() -> float:
	return clampf((float(monarch_stage()) + monarch_progress()) / 7.0, 0.0, 1.0)

# The shadow power folded into the existing bonus math (see get_bonus_total), so
# it flows through combat with no separate hooks. All fractions/percentages.
func monarch_bonus(key: String) -> float:
	var s = monarch_stage()
	if s <= 0:
		return 0.0
	match key:
		"damage_reduction":   # Shadow Armor, 5/7+
			if s < 5:
				return 0.0
			var dr = 0.08 * float(s - 4)
			if s >= 7:
				dr += 0.12
			return dr          # 5/7 .08, 6/7 .16, 7/7 .36
		"melee_damage", "bow_damage", "wand_damage":   # +shadow damage, 2/7+
			var d = 0.05 * float(maxi(0, s - 1))
			if s >= 7:
				d += 0.35
			return d           # 2/7 .05 ... 6/7 .25, 7/7 .65
		"move_speed":         # shadow swiftness, 3/7+
			return 0.03 * float(maxi(0, s - 2))
		_:
			return 0.0

# Fire the ominous toast ONCE for each newly-reached stage (call after leveling).
func announce_monarch_awakening() -> void:
	var s = monarch_stage()
	while monarch_stage_announced < s:
		var line = MONARCH_AWAKEN_LINES[monarch_stage_announced]
		monarch_stage_announced += 1
		notify(line)

# The 7/7 TRUE form (2x size, permanent shades, shadow novas, doubled
# lifesteal -- see player.gd monarch_tick). The numeric 7/7 spikes above always
# apply at level 100, but the visible god-form only manifests once no villager
# is left alive to witness it (the Harvest / finale, story.gd) -- or when
# forced from the admin P panel for testing.
var monarch_true_form_forced := false

func monarch_true_form() -> bool:
	# the Ascendant ultimate ("Sovereign of the Dead") grants the god-form as a
	# skill, so a post-game Monarch can reach it without emptying the village
	if get_skill_total("true_form_unlock") > 0.0:
		return true
	if monarch_stage() < 7:
		return false
	return monarch_true_form_forced or rescued_villagers.is_empty()

func get_skill_total(effect_key: String) -> float:
	var total = 0.0
	for node_id in unlocked_skills:
		var node = SkillTreeData.get_node_by_id(node_id)
		total += node.get("effect", {}).get(effect_key, 0.0)
	return total

func is_skill_unlocked(node_id: String) -> bool:
	if unlocked_skills.has(node_id):
		return true
	# some nodes (e.g. the innate Levitate) start already unlocked for free
	return SkillTreeData.get_node_by_id(node_id).get("default_unlocked", false)

# Points + prereq + (researched) materials, all checked and spent atomically.
func try_unlock_skill(node: Dictionary, player: Node) -> bool:
	if is_skill_unlocked(node.id):
		return false
	# graph-aware prereq: `prereq` may be an id, "" (none), or an Array meaning
	# "any of these" where a fork reconverges.
	if not SkillTreeData.prereq_met(node):
		return false
	# opportunity cost: a fork you didn't take is locked forever. Enforced even
	# in the sandbox -- you must CHOOSE, you can't buy both sides.
	if SkillTreeData.is_exclusive_blocked(node):
		return false
	# sandbox: prereq order still applies (so the tree reads sensibly) but the
	# node is free -- no points, no materials. Checked BEFORE the point cost.
	if TEST_SKILL_SANDBOX:
		unlocked_skills.append(node.id)
		return true
	if skill_points < node.cost:
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

# Crafting: if the player has every ingredient for `item_id`'s recipe, consume
# them and produce one. Returns "" on success, else a human error string.
func try_craft(item_id: String, player: Node) -> String:
	if not Inventory.CRAFT_RECIPES.has(item_id):
		return "That can't be crafted."
	var recipe = Inventory.CRAFT_RECIPES[item_id]
	for ing in recipe.keys():
		if player.inventory.get_count(ing) < recipe[ing]:
			return "Missing %dx %s." % [recipe[ing], Inventory.get_display_name(ing)]
	for ing in recipe.keys():
		player.inventory.remove_item(ing, recipe[ing])
	player.inventory.add_item(item_id, 1)
	return ""

# Testing (TEST_SKILL_SANDBOX): mark every skill-tree material as researched so
# names show real and no node is blocked on identification. Unlocking itself is
# already free in that mode (see try_unlock_skill) -- you still click each node.
func research_all_materials() -> void:
	for item_id in Inventory.ITEM_DEFS.keys():
		if Inventory.ITEM_DEFS[item_id].get("is_material", false) and not researched_materials.has(item_id):
			researched_materials.append(item_id)

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
		"active_weapon_id": player.active_weapon_id,
		"has_dash": player.has_dash,
		"has_double_jump": player.has_double_jump,
		"health": player.health,
		"mana": player.mana,
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

# --- Adventurers (GAME_BIBLE 2.4.1) ---
# Live state per adventurer id: {"rescued", "dead", "station", "hp"}. The
# registry (names/stats/rescue levels) is Adventurers.ROSTER; this dict is what
# saves. The opening trio starts rescued; the deep nine flip when freed.
# Stations: "wall" (front line), "city" (patrol), "house" (safe, no defense).
# Death is PERMANENT -- a dead adventurer never respawns and never returns.
var adventurers: Dictionary = {}

func ensure_adventurers() -> void:
	for id in Adventurers.ids():
		if not adventurers.has(id):
			var def = Adventurers.get_def(id)
			adventurers[id] = {
				"rescued": int(def.get("level", 0)) == 0,
				"dead": false,
				"station": "city",
				"hp": float(def.get("hp", 100.0)),
			}

func adventurer_state(id: String) -> Dictionary:
	ensure_adventurers()
	return adventurers.get(id, {})

func rescue_adventurer(id: String) -> void:
	ensure_adventurers()
	if not adventurers.has(id) or adventurers[id]["rescued"]:
		return
	adventurers[id]["rescued"] = true
	adventurers[id]["hp"] = float(Adventurers.get_def(id).get("hp", 100.0))
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack:
		stack.show_notification("%s is free -- another blade for Deepwood's wall!" % Adventurers.get_def(id).get("name", "An adventurer"))

func kill_adventurer(id: String) -> void:
	ensure_adventurers()
	if not adventurers.has(id) or adventurers[id]["dead"]:
		return
	adventurers[id]["dead"] = true
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack:
		stack.show_notification("%s has fallen. The dead do not re-enlist." % Adventurers.get_def(id).get("name", "An adventurer"))

func set_adventurer_station(id: String, station: String) -> void:
	ensure_adventurers()
	if adventurers.has(id) and station in Adventurers.STATIONS:
		adventurers[id]["station"] = station

# Living, rescued adventurers at fighting stations (wall/city). House-sheltered
# ones are alive but contribute nothing -- that is the trade the player makes.
func fighting_adventurers() -> Array:
	ensure_adventurers()
	var out := []
	for id in adventurers.keys():
		var a: Dictionary = adventurers[id]
		if a["rescued"] and not a["dead"] and a["station"] != "house":
			out.append(id)
	return out

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
# A villager whose personal bond (VillagerQuests) is complete works with unlocked
# potential -- their role income is multiplied by this. See turn_in_villager_quest.
const BOND_INCOME_MULT = 1.5

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
# --- Master in-game clock ---
# Owned here in the autoload (not in main.tscn's day_night node) so time keeps
# passing in EVERY scene -- village AND dungeon. The day/night visual simply
# mirrors game_hours; villager timers (mating/school/pregnancy) and the siege
# schedule all read it, so nothing freezes when the player teleports away.
const DAY_LENGTH_SECONDS = 600.0
const HOURS_PER_SECOND = 24.0 / DAY_LENGTH_SECONDS
const START_TIME_OF_DAY = 8.0
var game_hours = 0.0

# Self-contained day/night read (mirrors day_night_cycle.gd's dawn 5-7 / dusk
# 18-20 model) so anything -- e.g. building torches -- can ask "is it dark?"
# without depending on the day-night node. 0 = full day, 1 = full night.
func time_of_day() -> float:
	return fposmod(START_TIME_OF_DAY + game_hours, 24.0)

func village_darkness() -> float:
	var t = time_of_day()
	if t >= 7.0 and t <= 18.0:
		return 0.0
	if t >= 20.0 or t < 5.0:
		return 1.0
	if t >= 18.0:
		return (t - 18.0) / 2.0
	return 1.0 - (t - 5.0) / 2.0

# Torches light at dusk and go out after dawn.
func torches_lit() -> bool:
	return village_darkness() > 0.4

# --- Village siege state (autoload-owned so assaults resolve while the player
# is off in a dungeon) ---
const SIEGE_FIRST_HOURS = 6.0
const SIEGE_INTERVAL_HOURS = 12.0
# Abstract defense model used when a siege resolves OFF-SCREEN (player away):
# the wizard is a standing defense of SIEGE_DEF_WIZARD; each Barracks warrior
# adds SIEGE_DEF_PER_WARRIOR. A siege of "threat" = its day tier is repelled
# cleanly if defense >= threat, otherwise the overflow becomes villager deaths.
const SIEGE_DEF_WIZARD = 4.0
const SIEGE_DEF_PER_WARRIOR = 1.0
var hours_until_next_siege = SIEGE_FIRST_HOURS
var live_siege_active = false
# Tally of what happened while the player was away, shown on their return.
var away_report = {"sieges": 0, "repelled": 0, "villagers_lost": 0, "adventurers_lost": 0}

# --- Village mage (Orin) downed/respawn state ---
# When Orin falls he doesn't die for good -- he collapses into a small fireball
# on the spot and reforms WIZARD_RESPAWN_HOURS in-game hours later, then keeps
# fighting from the same place. The timer lives here (not on the wizard node)
# so it keeps counting while the player is off in a dungeon and survives the
# village scene reloading. -1 = he's up and fighting. See wizard.gd.
const WIZARD_RESPAWN_HOURS = 12.0
var wizard_respawn_at_hours := -1.0

# Orin is undying and grows stronger every single time he falls (1.3x HP/damage,
# faster casts, a new unlocked skill), forever. This counter -- how many times
# he has died -- drives all of that (see wizard.gd apply_power_tier). It is the
# seed of the endgame: he is secretly the final boss. Persisted across saves.
var wizard_power_tier := 0

# --- Construction-material drops (the repair economy) ---
# Rolled on any enemy death, anywhere. Generous on purpose so the repair economy
# actually flows (buildings now take 3 builds x a material bundle). At most one
# material per kill; tougher fights pass a higher chance_mult. Returns the
# dropped material id, or "" for nothing. Bosses use grant_construction_bundle.
const CONSTRUCTION_DROP_TABLE = [["wood", 0.35], ["stone", 0.25], ["resin", 0.15]]

func _has_inventory(player) -> bool:
	return is_instance_valid(player) and player.get("inventory") != null

func roll_construction_drop(player, chance_mult: float = 1.0) -> String:
	if not _has_inventory(player):
		return ""
	var r = randf()
	var acc = 0.0
	for entry in CONSTRUCTION_DROP_TABLE:
		acc += float(entry[1]) * chance_mult
		if r < acc:
			player.inventory.add_item(entry[0], 1)
			return entry[0]
	return ""

func grant_construction_bundle(player, wood: int, stone: int, resin: int) -> void:
	if not _has_inventory(player):
		return
	if wood > 0:
		player.inventory.add_item("wood", wood)
	if stone > 0:
		player.inventory.add_item("stone", stone)
	if resin > 0:
		player.inventory.add_item("resin", resin)

func wizard_is_down() -> bool:
	return wizard_respawn_at_hours >= 0.0 and game_hours < wizard_respawn_at_hours

# 0.0 right after he falls -> 1.0 at the instant he reforms. Drives the ember
# that starts tiny and swells brighter/hotter as revival nears (see wizard.gd).
func wizard_down_progress() -> float:
	if wizard_respawn_at_hours < 0.0:
		return 0.0
	var start = wizard_respawn_at_hours - WIZARD_RESPAWN_HOURS
	return clamp((game_hours - start) / WIZARD_RESPAWN_HOURS, 0.0, 1.0)

func mark_wizard_down() -> void:
	wizard_respawn_at_hours = game_hours + WIZARD_RESPAWN_HOURS

func clear_wizard_down() -> void:
	wizard_respawn_at_hours = -1.0

# Per-building battle damage, keyed by building_name (== role_key). Persisted
# so a smashed building stays smashed across dungeon trips and reloads. Absent
# key = undamaged. 0 = destroyed (non-operative). See building.gd.
var building_health: Dictionary = {}

# Mirrors building.gd's MAX_HEALTH -- kept here so GameState can seed/restore
# building_health without depending on building.gd. Keep the two in sync.
const BUILDING_MAX_HEALTH = 400

# Construction progress per building, 0..TOTAL_BUILD_STAGES. 0 = ruins; each F
# repair advances it one stage (frame -> walls -> finished); only at the final
# stage is the building operational and its combat HP meaningful. Persisted so
# a half-built building stays half-built across reloads. See building.gd.
const TOTAL_BUILD_STAGES = 3
var building_stage: Dictionary = {}

# The Blacksmith (the Forge) is a MID-GAME building: it can't be raised until the
# player has braved this dungeon depth. It exists to reliably supply equippable
# gear of every slot up to a non-OP tier -- see assign_ui.add_smithy_section.
const BLACKSMITH_UNLOCK_DEPTH = 35

func blacksmith_unlocked() -> bool:
	return deepest_level_reached >= BLACKSMITH_UNLOCK_DEPTH

func building_build_stage(name: String) -> int:
	return int(building_stage.get(name, 0))

# The 12 village buildings (names == building_name == role_key). At New Game the
# village lies in ruins -- every one of these starts DESTROYED (health 0) and
# non-operational until the player repairs it (building.gd.try_repair). This is
# the core "return from the dungeon and rebuild Deepwood" loop.
const STARTING_BUILDINGS = [
	"Government", "School", "Farm", "Hospital", "Barracks", "Fishing Dock",
	"Science Lab", "Bank", "Blacksmith", "Tavern", "Bar", "Marketplace", "Builderhouse",
]

# Admin/debug helper (M key): flag every known building as fully repaired.
# Live building nodes still refresh their own visuals from this (see player.gd).
func restore_all_buildings() -> void:
	for bn in STARTING_BUILDINGS:
		building_health[bn] = BUILDING_MAX_HEALTH
		building_stage[bn] = TOTAL_BUILD_STAGES

# Per-building upgrade level (1..building.MAX_LEVEL), keyed by building_name.
# Higher level = bigger building, more worker slots, and more output. Absent
# key = level 1. See building.gd for size/slots and the multiplier below.
var building_levels: Dictionary = {}
const BUILDING_OUTPUT_PER_LEVEL = 0.25   # +25% output per level over level 1

func building_level(name: String) -> int:
	return int(building_levels.get(name, 1))

func building_output_multiplier(name: String) -> float:
	return 1.0 + (building_level(name) - 1) * BUILDING_OUTPUT_PER_LEVEL

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
	# Launch with `--dev` to restore the whole testing sandbox; otherwise this is
	# the real game. All four TEST_* conveniences follow dev_mode.
	if OS.get_cmdline_args().has("--dev"):
		dev_mode = true
	TEST_UNLOCK_ALL_LEVELS = dev_mode
	TEST_INSTANT_RESPAWN = dev_mode
	TEST_SKILL_SANDBOX = dev_mode
	TEST_POPULATE_VILLAGE = dev_mode
	load_deepest_level()
	load_game_completed()
	setup_audio()

# --- Audio: a "Master" (Volume) bus and a dedicated "Music" bus routed into it,
# so music can be turned down independently of everything else. Levels persist
# across launches. ---
const AUDIO_CFG_PATH = "user://audio_settings.cfg"
var master_volume := 1.0
var music_volume := 1.0

func setup_audio() -> void:
	# create the Music bus (sending into Master) if it isn't there yet
	if AudioServer.get_bus_index("Music") == -1:
		var idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, "Music")
		AudioServer.set_bus_send(idx, "Master")
	var cfg = ConfigFile.new()
	if cfg.load(AUDIO_CFG_PATH) == OK:
		master_volume = float(cfg.get_value("audio", "master", 1.0))
		music_volume = float(cfg.get_value("audio", "music", 1.0))
	apply_master_volume()
	apply_music_volume()

func apply_master_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(max(master_volume, 0.0001)))
	AudioServer.set_bus_mute(0, master_volume <= 0.0)

func apply_music_volume() -> void:
	var mi = AudioServer.get_bus_index("Music")
	if mi < 0:
		return
	AudioServer.set_bus_volume_db(mi, linear_to_db(max(music_volume, 0.0001)))
	AudioServer.set_bus_mute(mi, music_volume <= 0.0)

func set_master_volume(v: float) -> void:
	master_volume = clamp(v, 0.0, 1.0)
	apply_master_volume()
	save_audio_settings()

func set_music_volume(v: float) -> void:
	music_volume = clamp(v, 0.0, 1.0)
	apply_music_volume()
	save_audio_settings()

func save_audio_settings() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.save(AUDIO_CFG_PATH)

func _process(delta: float) -> void:
	# Only simulate while an actual game scene is loaded (a player exists in it).
	# This skips the main menu, where GameState is already alive but no run is
	# in progress -- otherwise the clock and sieges would tick behind the menu.
	if get_tree().get_first_node_in_group("player") == null:
		return
	game_hours += delta * HOURS_PER_SECOND
	income_timer += delta
	if income_timer >= INCOME_INTERVAL_SECONDS:
		income_timer -= INCOME_INTERVAL_SECONDS
		generate_passive_income()
		apply_leadership_automation()
	tick_village_clock()
	update_morale_meter_unlock()

# Debug time-skip keys (and anything else) nudge the master clock through here.
func skip_hours(h: float) -> void:
	game_hours = max(0.0, game_hours + h)

func tick_village_clock() -> void:
	var hours_passed = game_hours - village_last_hours_elapsed
	village_last_hours_elapsed = game_hours
	# pregnancies first: a cottage stay completing this same tick (below)
	# creates a fresh pregnancy that must start at the full duration, not get
	# immediately clipped by this tick's hours_passed too.
	update_pregnancies(hours_passed)
	update_mating_houses(hours_passed)
	update_school_enrollments(hours_passed)
	decay_doctor_price(hours_passed)
	if hours_passed > 0.0:
		# grief heals with time -- the forgiving half of the death-shock system
		morale_death_shock = maxf(0.0, morale_death_shock - hours_passed * DEATH_SHOCK_DECAY_PER_HOUR)
		tick_food(hours_passed)          # eat/produce first, so hunger drain sees fresh state
		tick_morale_effects(hours_passed)
		tick_village_tribute(hours_passed)
		tick_sieges(hours_passed)

# --- Siege scheduling + resolution (runs in every scene) ---

func current_siege_tier() -> int:
	return 1 + int(game_hours / 24.0)

# Standing defense strength of the village right now (wizard + warriors).
# GAME_BIBLE 2.5.1: Orin enters the story only once the player has carved to
# ~floor 15. Before that he is the Doctor's rumour -- a wizard who went down
# and never came back. (--dev keeps him for the sandbox.)
const ORIN_ARRIVAL_DEPTH := 15
var seen_orin_arrival := false
var seen_doctor_account := false
var seen_failed_escape := false

func orin_arrived() -> bool:
	return dev_mode or deepest_level_reached >= ORIN_ARRIVAL_DEPTH

func village_defense_power() -> float:
	# no Orin, no meteors: until he walks out of the dungeon the village's
	# nightly defense is the adventurers and whatever warriors it has raised
	var power = SIEGE_DEF_WIZARD if orin_arrived() else 0.0
	for v in rescued_villagers:
		if v.get("stat_name", "") == "Warrior" or v.get("role_key", "") == "Barracks":
			power += SIEGE_DEF_PER_WARRIOR
		# a barracks-forged HERO is a one-person garrison
		if v.get("hero_trained", false):
			power += SIEGE_DEF_PER_WARRIOR * 3.0
	# adventurers hold the line by station: the wall is worth more than a
	# patrol, and a sheltered adventurer is worth nothing (but cannot die)
	ensure_adventurers()
	for id in adventurers.keys():
		var a: Dictionary = adventurers[id]
		if not a["rescued"] or a["dead"]:
			continue
		if a["station"] == "wall":
			power += 1.5
		elif a["station"] == "city":
			power += 1.0
	# warriors ARMED from the Barracks armory hit far above their weight
	power += ARMED_WARRIOR_BONUS * float(armed_warriors())
	# a seated Warchief is a standing army in themselves -- auto-repels far more
	power += WARCHIEF_DEFENSE * seated_leaders("Barracks")
	# morale rides the whole village's fighting spirit up or down
	return power * morale_defense_multiplier()

# How many TRAINED warriors the Barracks has -- drives how many VISIBLE soldier
# units sally out to fight during a live siege (see siege_manager.gd). Recruits
# still in training (role_title "Recruit") don't fight yet.
func warrior_count() -> int:
	var n = 0
	for v in rescued_villagers:
		if v.get("role_title", "") == "Recruit":
			continue
		if v.get("stat_name", "") == "Warrior" or v.get("role_key", "") == "Barracks":
			n += 1
	return n

func tick_sieges(hours_passed: float) -> void:
	# Leaving for a dungeon abandons any in-progress live battle -- from here on
	# sieges resolve abstractly until the player is back in the village.
	if in_dungeon:
		live_siege_active = false
	if live_siege_active:
		return
	hours_until_next_siege -= hours_passed
	var guard = 0
	while hours_until_next_siege <= 0.0 and guard < 100:
		guard += 1
		hours_until_next_siege += SIEGE_INTERVAL_HOURS
		trigger_siege()
		if live_siege_active:
			break  # a live battle just started; stop scheduling until it ends

func trigger_siege() -> void:
	var tier = current_siege_tier()
	if not in_dungeon:
		var mgr = get_tree().get_first_node_in_group("siege_manager")
		if mgr and mgr.has_method("start_live_siege"):
			mgr.start_live_siege(tier)
			live_siege_active = true
			return
	resolve_siege_offline(tier)

# Abstract off-screen resolution used while the player is away.
func resolve_siege_offline(tier: int) -> void:
	away_report.sieges += 1
	if village_defense_power() >= float(tier):
		away_report.repelled += 1
		return
	var casualties = int(ceil(float(tier) - village_defense_power()))
	for i in range(casualties):
		# the adventurers are the shield: a fighting one (wall first, then city)
		# falls IN PLACE of a villager. That is their job, and their risk -- one
		# sheltered in a house is never touched. The dead never re-enlist.
		var shield_id := ""
		for station in ["wall", "city"]:
			for id in fighting_adventurers():
				if adventurers[id]["station"] == station:
					shield_id = id
					break
			if shield_id != "":
				break
		if shield_id != "":
			adventurers[shield_id]["dead"] = true
			away_report.adventurers_lost = int(away_report.get("adventurers_lost", 0)) + 1
			continue
		if rescued_villagers.is_empty():
			break
		remove_random_villager()
		away_report.villagers_lost += 1

# Called by the live SiegeManager when a village battle is fully repelled.
func on_live_siege_ended() -> void:
	live_siege_active = false
	hours_until_next_siege = SIEGE_INTERVAL_HOURS
	# the survivors bind their wounds: every adventurer still standing recovers
	# to full between sieges, so attrition never quietly executes them across a
	# dozen fights -- only a battle that actually kills one removes them
	ensure_adventurers()
	for id in adventurers.keys():
		if adventurers[id]["rescued"] and not adventurers[id]["dead"]:
			adventurers[id]["hp"] = float(Adventurers.get_def(id).get("hp", 100.0))
	for a in get_tree().get_nodes_in_group("adventurer"):
		if is_instance_valid(a) and not a.is_dead:
			if a.body_rect:
				a.body_rect.color = Color(0.32, 0.36, 0.46)   # wounds bound, colour restored
			if a.has_method("on_siege_ended"):
				a.on_siege_ended()   # once-per-siege pacts (Daybreak) renew

# Read + clear the away tally (main.gd shows it when the player returns).
func consume_away_report() -> Dictionary:
	var report = away_report.duplicate()
	away_report = {"sieges": 0, "repelled": 0, "villagers_lost": 0, "adventurers_lost": 0}
	return report

# A building generates income / functions only once it is FULLY built (all 3
# construction stages done). A ruined or half-built building does nothing.
func is_building_operational(building_key: String) -> bool:
	return int(building_stage.get(building_key, 0)) >= TOTAL_BUILD_STAGES

# --- Food & hunger (Step 1: the hunger loop) ---
# Food is a real, depleting village stockpile measured in "villager-days" --
# roughly, how many villager-days of meals are in store. Everyone (adults AND
# kids) eats FOOD_PER_VILLAGER_PER_DAY each day. A STAFFED Farm produces food
# passively (building-level automation); an unstaffed-but-built Farm produces
# nothing, so early game the player must HAND-HARVEST at the farm to keep the
# larder full -- the manual chore you later automate by hiring farmers. If the
# stockpile sits EMPTY past a grace period, villagers begin to starve, draining
# the SAME villager_hp the despair system uses (no second death path); death
# lands ~2-3 in-game days after the food runs out. The stockpile also feeds the
# morale "food" input via has_food(), replacing the old binary "is the Farm
# built?" check.
const FOOD_PER_VILLAGER_PER_DAY := 1.0       # everyone eats this much per in-game day
const FOOD_PER_FARMER_PER_DAY := 6.0         # each farm worker feeds this many villagers
const FOOD_DAYS_CAP := 4.0                   # the larder holds at most this many days of food
const FOOD_MANUAL_HARVEST_YIELD := 4.0       # food produced by one hand-harvest action
const FOOD_STARVE_GRACE_HOURS := 30.0        # empty larder must persist this long before HP drains
const FOOD_STARVE_HP_DRAIN_PER_HOUR := 5.0   # then hunger eats HP (x _despair_rate, staggered)

var village_food := 0.0                      # current stockpile (villager-days)
var food_empty_hours := 0.0                  # how long the stockpile has sat empty

# Edge-latches so danger toasts fire ONCE on crossing into trouble, not every
# tick. Each re-arms when the situation clears (with hysteresis for morale).
var _warned_no_food := false
var _warned_low_morale := false

# How much food the town can hold -- scales with population so a bigger village
# needs a bigger buffer (and more farmers to keep it full).
func food_capacity() -> float:
	return FOOD_DAYS_CAP * maxf(float(rescued_villagers.size()), 6.0)

# The town is "fed" as long as there is any food in store.
func has_food() -> bool:
	return village_food > 0.0

# Everyone eats: total food burned per in-game hour by the whole population.
func food_consumption_per_hour() -> float:
	return float(rescued_villagers.size()) * FOOD_PER_VILLAGER_PER_DAY / 24.0

# Villagers employed at the Farm (Leader + Farmers) work the fields.
func farm_worker_count() -> int:
	if not is_building_operational("Farm"):
		return 0
	var n := 0
	for v in rescued_villagers:
		if v.get("role_key", "") == "Farm":
			n += 1
	return n

# Passive food produced per in-game hour by a staffed farm (0 if unstaffed).
# A seated Harvestmaster drives the fields far harder (auto-feeds the town).
func food_production_per_hour() -> float:
	return float(farm_worker_count()) * FOOD_PER_FARMER_PER_DAY / 24.0 * (1.0 + HARVESTMASTER_FOOD_BONUS * seated_leaders("Farm"))

# Days of food left at the current population's burn rate (for the HUD readout).
func food_days_remaining() -> float:
	var burn = food_consumption_per_hour()
	if burn <= 0.0:
		return FOOD_DAYS_CAP
	return (village_food / burn) / 24.0

# True once the empty larder has persisted long enough that hunger kills.
func village_is_starving() -> bool:
	return food_empty_hours >= FOOD_STARVE_GRACE_HOURS

# Player hand-harvest at the farm (manual production for the early game).
# Returns the amount actually added (0 if the larder is already full).
func manual_harvest_food() -> float:
	var before = village_food
	village_food = minf(food_capacity(), village_food + FOOD_MANUAL_HARVEST_YIELD)
	return village_food - before

# Push a toast to whichever scene's notification stack is live (village or
# dungeon). No-ops if none is present.
func notify(text: String) -> void:
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack and stack.has_method("show_notification"):
		stack.show_notification(text)

# Advance the food stockpile: staffed farms add, the population eats, and the
# empty-larder timer tracks how long the town has gone without. Called from
# tick_village_clock BEFORE tick_morale_effects so the hunger HP-drain sees
# fresh state on the same tick.
func tick_food(hours_passed: float) -> void:
	if hours_passed <= 0.0:
		return
	var net = (food_production_per_hour() - food_consumption_per_hour()) * hours_passed
	village_food = clampf(village_food + net, 0.0, food_capacity())
	if village_food <= 0.0:
		food_empty_hours += hours_passed
	else:
		# recovers twice as fast as it built -- a brief gap won't snowball into death
		food_empty_hours = maxf(0.0, food_empty_hours - hours_passed * 2.0)
	# warn ONCE when a populated village first runs dry (re-arms when refilled)
	if village_food <= 0.0 and not rescued_villagers.is_empty():
		if not _warned_no_food:
			_warned_no_food = true
			notify("The village has run out of food! Villagers will start to starve.")
	else:
		_warned_no_food = false

# --- Villager needs & morale ---
# Each villager's mood is computed LIVE from what the village gives them: a
# job (and the RIGHT job for their training), food (a working Farm), a social
# life (a working Bar), and companionship (a mating pairing). Morale is 0-100.
# The village average feeds back into passive income (happy workers produce
# more) and drives the mood lines villagers say near the player (npc.gd).
func is_villager_paired(vid: String) -> bool:
	for h in mating_houses.values():
		if h.get("male_id", "") == vid or h.get("female_id", "") == vid:
			return true
	for p in pregnancies.values():
		if p.get("male_id", "") == vid or p.get("female_id", "") == vid:
			return true
	return false

func villager_needs(v: Dictionary) -> Dictionary:
	var role = v.get("role_key", "")
	var stat = v.get("stat_name", "")
	var right_job = true
	if role != "" and stat != "":
		var req = ""
		for rd in BuildingRoles.get_roles(role):
			if rd.get("title", "") == v.get("role_title", ""):
				req = rd.get("required_stat", "")
		# a trained specialist stuck in a slot that doesn't use their training
		# (generic slot, or a different requirement) = wrong employment
		right_job = (req == stat)
	return {
		"work": role != "",
		"right_job": right_job,
		"food": has_food(),
		"social": is_building_operational("Bar"),
		"love": v.get("is_kid", false) or is_villager_paired(v.get("id", "")),
	}

func villager_morale(v: Dictionary) -> int:
	var n = villager_needs(v)
	var m = 50
	m += 18 if n.work else -18
	m += 8 if n.right_job else -12
	m += 12 if n.food else -16
	m += 8 if n.social else -6
	m += 8 if n.love else -8
	return clampi(m, 0, 100)

# --- Village-wide morale (0-100 internally, shown to the player as X/10) ---
# Morale exists for the WHOLE game, but the on-screen METER only unlocks once
# every building has been rebuilt (morale_meter_unlocked), after which it stays
# on screen forever. Morale is driven by how well the village lives:
#   employment, food (Farm), armor (Blacksmith), companionship (mating), a
#   social life (Bar) and sheer numbers alive -- minus a decaying "death shock"
#   from villagers lost to siege waves. 10/10 is a hard, late-game-only state:
#   it needs the town employed, armed, paired, well-fed and populous with no
#   recent losses. A brutal wave that kills 20 knocks morale down (a maxed 10/10
#   town falls to ~6/10) but it is FORGIVING -- the shock fades over time and is
#   repaid as you spawn/mate replacements back into the population.
const MORALE_POP_TARGET := 30.0          # headcount at which "numbers alive" maxes out
const DEATH_SHOCK_PER_KILL := 2.0        # morale points lost per villager killed (0-100)
const DEATH_SHOCK_MAX := 60.0            # one catastrophe can't zero morale outright
const DEATH_SHOCK_DECAY_PER_HOUR := 1.0  # the town grieves, then heals over time
const REPLACE_RELIEF := 2.5              # each new villager (birth/troop) repays some shock

var morale_death_shock := 0.0
var morale_meter_unlocked := false

func count_adults() -> int:
	var n = 0
	for v in rescued_villagers:
		if not v.get("is_kid", false):
			n += 1
	return n

func village_morale() -> int:
	var pop = rescued_villagers.size()
	if pop == 0:
		return 0
	var adults = maxi(1, count_adults())
	var employed = 0
	var paired = 0
	for v in rescued_villagers:
		if v.get("is_kid", false):
			continue
		if v.get("role_key", "") != "":
			employed += 1
		if is_villager_paired(v.get("id", "")):
			paired += 1
	var score := 0.0
	score += 26.0 * float(employed) / float(adults)                  # employment
	score += 20.0 if has_food() else 0.0                             # food (see tick_food)
	score += 16.0 if is_building_operational("Blacksmith") else 0.0  # armor
	score += 18.0 * float(paired) / float(adults)                    # mating / good sex
	score += 10.0 if is_building_operational("Bar") else 0.0         # social life
	score += 10.0 * clampf(float(pop) / MORALE_POP_TARGET, 0.0, 1.0) # numbers alive
	score += LEADER_MORALE_EACH * (seated_leaders("Tavern") + seated_leaders("Bar"))  # a good host keeps spirits up
	score -= morale_death_shock                                      # grief from losses
	# morale_admin_offset is a dev-panel nudge (0 in normal play)
	return clampi(int(round(score)) + morale_admin_offset, 0, 100)

# Dev/admin panel nudge to morale, in tenths (+1 == +1.0 on the 0-10 meter).
func admin_nudge_morale(tenths: int) -> void:
	morale_admin_offset = clampi(morale_admin_offset + tenths * 10, -100, 100)

# The player-facing 0-10 reading.
func village_morale_10() -> float:
	return float(village_morale()) / 10.0

# Villagers killed (siege waves, the death penalty) pile onto the death shock;
# new villagers (births, spawned troops) repay it. Both are clamped so a wipe
# can't bottom morale out instantly and over-healing can't push shock negative.
func register_villager_deaths(n: int) -> void:
	if n <= 0:
		return
	morale_death_shock = minf(morale_death_shock + float(n) * DEATH_SHOCK_PER_KILL, DEATH_SHOCK_MAX)

func register_villagers_added(n: int) -> void:
	if n <= 0:
		return
	morale_death_shock = maxf(0.0, morale_death_shock - float(n) * REPLACE_RELIEF)

# The meter appears the moment the last building is finished, and never leaves.
func all_buildings_operational() -> bool:
	for bn in STARTING_BUILDINGS:
		if not is_building_operational(bn):
			return false
	return true

func update_morale_meter_unlock() -> void:
	if not morale_meter_unlocked and all_buildings_operational():
		morale_meter_unlocked = true

# Happy village, richer village: 0.75x income at 0 morale, 1.0x at 50, 1.25x at 100.
func village_morale_multiplier() -> float:
	return 0.75 + 0.5 * float(village_morale()) / 100.0

# --- Morale consequences (rewards & punishments) ---
# A miserable village literally withers: once morale sits below 2/10 for a long
# grace period, villagers begin STARVING -- losing HP every hour and, staggered
# so they fall one by one, dying -- until the player turns things around. Misery
# also SAPS the town's defense (demoralized fighters die more easily to sieges)
# and HALTS new births. A THRIVING village is rewarded in kind: stronger defense,
# faster births, and (see generate_passive_income) up to 1.25x gold.
const DESPAIR_MORALE := 20               # below 2/10 == the village is in crisis
const DESPAIR_GRACE_HOURS := 18.0        # crisis must persist this long before it bites
const DESPAIR_HP_DRAIN_PER_HOUR := 6.0   # then despair grinds the villager down...
const DESPAIR_HP_REGEN_PER_HOUR := 12.0  # ...but a recovered village pulls them back
const VILLAGER_MAX_HP := 100.0

# --- Corruption (Step 2): neglect doesn't just kill, it turns villagers evil ---
# A villager ground all the way down by untended despair (empty larder or
# rock-bottom morale) doesn't quietly die -- their hope hits zero and they turn
# DEMONIC, spawning as a siege_enemy that attacks the town from the inside. Each
# turning heaps extra dread on the whole village (the domino), so a broadly
# miserable town chains into a powder keg. The player can still save a rotting
# villager by fixing food/morale before the drain finishes (redemption).
# TEMP KILL-SWITCH (2026-07-13, developer request): while false, misery can't
# finish a villager off -- their HP floors at 1 (sick, grey, but alive) and
# NOBODY dies or turns demonic from despair/hunger. Flip back to true to
# reactivate the corruption transformation.
const CORRUPTION_ENABLED := false
const SIEGE_ENEMY_SCENE := preload("res://siege_enemy.tscn")
const DEMON_BASE_HP := 40.0
const DEMON_BASE_DMG := 9.0
const DEMON_HP_PER_TIER := 0.30
const DEMON_DMG_PER_TIER := 0.20
const CORRUPTION_MORALE_SHOCK := 4.0     # extra town-wide dread per turning (domino)

var low_morale_hours := 0.0
var villager_hp: Dictionary = {}         # id -> current hp (0..100); absent == full health
var morale_admin_offset := 0             # dev-panel morale nudge (0 in normal play)

func get_villager_hp(id: String) -> float:
	return float(villager_hp.get(id, VILLAGER_MAX_HP))

func village_in_despair() -> bool:
	return low_morale_hours >= DESPAIR_GRACE_HOURS

# 0..1 -- how deep into the crisis we are, for the starving visuals on avatars.
func village_despair_depth() -> float:
	if not village_in_despair():
		return 0.0
	return clampf((low_morale_hours - DESPAIR_GRACE_HOURS) / 24.0, 0.0, 1.0)

# Deterministic per-villager drain multiplier (0.5..1.5) so the starving deaths
# stagger out over time instead of the whole town dropping dead the same hour.
func _despair_rate(id: String) -> float:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(id)
	return 0.5 + rng.randf()

func tick_morale_effects(hours_passed: float) -> void:
	if hours_passed <= 0.0:
		return
	var m = village_morale()
	var in_crisis = m < DESPAIR_MORALE
	if in_crisis:
		low_morale_hours += hours_passed
	else:
		# recovers roughly twice as fast as it built -- forgiving once fixed
		low_morale_hours = maxf(0.0, low_morale_hours - hours_passed * 2.0)
	# warn ONCE when morale hits rock bottom (re-arms only after it recovers past
	# 3/10, so a village hovering at the threshold doesn't spam the toast)
	if m < DESPAIR_MORALE:
		if not _warned_low_morale:
			_warned_low_morale = true
			notify("Your villagers are miserable — morale is critically low!")
	elif m >= 30:
		_warned_low_morale = false
	# Villagers lose HP from TWO causes that share this one drain path (so there
	# is never a second, parallel death system): rock-bottom morale that has
	# persisted past its grace, and an empty larder that has persisted past its
	# grace (hunger, tracked in tick_food). Whichever cause is worse sets the
	# drain rate; the moment the player fixes EITHER, the dying stops and -- while
	# the no-regen rule isn't in yet (Step 3) -- HP heals back.
	var morale_starving = in_crisis and low_morale_hours >= DESPAIR_GRACE_HOURS
	var drain_rate := 0.0
	if morale_starving:
		drain_rate = DESPAIR_HP_DRAIN_PER_HOUR
	if village_is_starving():
		drain_rate = maxf(drain_rate, FOOD_STARVE_HP_DRAIN_PER_HOUR)
	var starving = drain_rate > 0.0
	var dead: Array = []
	for v in rescued_villagers:
		var id = v.get("id", "")
		var hp = get_villager_hp(id)
		if starving:
			hp -= hours_passed * drain_rate * _despair_rate(id)
			if hp <= 0.0:
				if CORRUPTION_ENABLED:
					dead.append(id)
				else:
					# corruption disabled: misery sickens but can't finish them
					villager_hp[id] = 1.0
			else:
				villager_hp[id] = hp
		elif hp < VILLAGER_MAX_HP:
			villager_hp[id] = minf(VILLAGER_MAX_HP, hp + hours_passed * DESPAIR_HP_REGEN_PER_HOUR)
	for id in dead:
		villager_hp.erase(id)
		transform_villager_to_demon(id)   # despair consumes them -> they turn demonic
	# toast the turning, flavouring by what finally broke them
	if dead.size() > 0:
		var cause = "A starving villager" if village_is_starving() else "A despairing villager"
		if dead.size() == 1:
			notify(cause + " has turned into a demon and attacks the village!")
		else:
			notify("%d villagers have been consumed by despair and turned demonic!" % dead.size())

# A neglected villager's descent completes: spawn a demon where their avatar
# stands (so it attacks the town from within), then purge the villager and heap
# extra dread on the town (the domino). If the player is away in the dungeon
# there's no village to spawn into -- the villager is simply lost to corruption.
func transform_villager_to_demon(villager_id: String) -> void:
	var pos = Vector2.ZERO
	var parent: Node = null
	for npc in get_tree().get_nodes_in_group("npc"):
		if npc.villager_id == villager_id:
			pos = npc.global_position
			parent = npc.get_parent()
			break
	if parent != null and not in_dungeon:
		_spawn_demon_at(pos, parent)
	remove_villager_by_id(villager_id)   # roster + mating/school cleanup + avatar + grief
	# each turning deepens the whole town's dread -> a miserable village chains
	morale_death_shock = minf(morale_death_shock + CORRUPTION_MORALE_SHOCK, DEATH_SHOCK_MAX)

# Spawn one demon at a world position, hunting the town. Wears the downloaded
# demon sprite (art/enemies/demon) so a corrupted villager visibly becomes a
# DEMON -- not a lookalike of the hooded siege raiders.
func _spawn_demon_at(pos: Vector2, parent: Node) -> void:
	var tier = current_siege_tier()
	var demon = SIEGE_ENEMY_SCENE.instantiate()
	demon.skin = "demon"
	demon.max_health = int(round(DEMON_BASE_HP * (1.0 + (tier - 1) * DEMON_HP_PER_TIER)))
	demon.attack_damage = int(round(DEMON_BASE_DMG * (1.0 + (tier - 1) * DEMON_DMG_PER_TIER)))
	demon.reward = 4 + tier
	demon.global_position = pos
	parent.add_child(demon)
	# _ready() defaulted wall to the village wall; clear it so the demon skips the
	# wall and immediately hunts the nearest villager/player/building (from within)
	demon.wall = null

# Morale swings the village's fighting strength: 0.5x at rock bottom, 1.0x at
# 5/10, 1.5x when thriving. Demoralized towns bleed in sieges; happy ones hold.
func morale_defense_multiplier() -> float:
	return 0.5 + float(village_morale()) / 100.0

# New births stop entirely in despair, run slow when unhappy, and speed up when
# the town is thriving (0.6x .. 1.2x). Folded into the gestation clock.
func morale_birth_multiplier() -> float:
	if village_in_despair():
		return 0.0
	return 0.6 + 0.6 * float(village_morale()) / 100.0

# --- High-morale rewards (the carrot) ---
# Above 8/10 the thriving town starts actively blessing its hero. This factor
# ramps 0 -> 1 across 8/10..10/10, so only a genuinely happy village pays out,
# and it pays MOST at a perfect 10.
func morale_high_factor() -> float:
	return clampf((float(village_morale()) - 80.0) / 20.0, 0.0, 1.0)

# A hero walking through a joyful town moves quicker and slowly heals -- the
# village's good cheer literally buoys you (village only, not in the dungeon).
func morale_speed_bonus() -> float:
	if in_dungeon:
		return 0.0
	return 0.12 * morale_high_factor()

func morale_regen_per_sec() -> float:
	if in_dungeon:
		return 0.0
	return 2.0 * morale_high_factor()

# At a perfect 10/10 (the meter reads a full 10.0) the whole village erupts in
# celebration -- fireworks, confetti, cheering. See village_life.gd.
func village_is_celebrating() -> bool:
	return not in_dungeon and village_morale() >= 100

# A grateful town periodically brings its hero a gift of gold. The richer the
# mood and the bigger the town, the fatter the purse.
const TRIBUTE_INTERVAL_HOURS := 24.0
const TRIBUTE_MORALE_MIN := 90
var tribute_timer := 0.0

func tick_village_tribute(hours_passed: float) -> void:
	if in_dungeon or village_morale() < TRIBUTE_MORALE_MIN:
		tribute_timer = 0.0
		return
	tribute_timer += hours_passed
	if tribute_timer >= TRIBUTE_INTERVAL_HOURS:
		tribute_timer -= TRIBUTE_INTERVAL_HOURS
		grant_village_tribute()

func grant_village_tribute() -> void:
	var gift = 15 + rescued_villagers.size() * 2
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("add_currency"):
		player.add_currency(gift)
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack and stack.has_method("show_notification"):
		stack.show_notification("The grateful village brings you a gift of %d gold!" % gift)

func generate_passive_income() -> void:
	var total = 0.0
	var village_mult = get_village_income_multiplier()
	for villager in rescued_villagers:
		var role_key = villager.get("role_key", "")
		var role_title = villager.get("role_title", "")
		# a destroyed building produces nothing until it's rebuilt
		if role_key != "" and not is_building_operational(role_key):
			continue
		var value = 0.0
		if INCOME_ROLES.get(role_key, "") == role_title:
			value = float(villager.get("stat_value", 0))
			if role_key == "Farm":
				value *= get_farm_income_multiplier()
		elif role_key == "Government" and role_title == "Party":
			value = PARTY_MEMBER_INCOME
		# a higher-level building produces more from the same worker
		value *= building_output_multiplier(role_key)
		# a villager whose personal bond is complete works at unlocked potential
		if villager.get("bond", false):
			value *= BOND_INCOME_MULT
		total += value * village_mult
	if total <= 0:
		return
	# happy workers produce more, miserable ones less (0.75x .. 1.25x)
	total *= village_morale_multiplier()
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
	return 1.0 + count_leader_holders("Government", "Chancellor") * LEADER_BONUS_PER_HOLDER

func get_farm_income_multiplier() -> float:
	return 1.0 + count_leader_holders("Farm", "Harvestmaster") * LEADER_BONUS_PER_HOLDER

func get_gestation_speed_multiplier() -> float:
	# a happy town makes babies faster; a despairing one makes none at all
	return (1.0 + count_leader_holders("Hospital", "Chief Physician") * LEADER_BONUS_PER_HOLDER) * morale_birth_multiplier()

func get_school_graduation_speed_multiplier() -> float:
	return 1.0 + count_leader_holders("School", "Principal") * LEADER_BONUS_PER_HOLDER

func get_barracks_graduation_speed_multiplier() -> float:
	return 1.0 + count_leader_holders("Barracks", "Warchief") * LEADER_BONUS_PER_HOLDER

# ============================ LEADERSHIP AUTOMATION ============================
# The rescued VIP leaders don't just buff numbers -- they RUN the village so it
# needs far less hand-management (the colony-sim payoff). Driven once per income
# tick (right after generate_passive_income) plus a few read-time multipliers
# (defense/food/morale, folded into those functions). Every effect is gated on
# that building's leadership seat(s) being FILLED and scales with how many are
# seated (Science Lab 4, Barracks/School/Builderhouse 2). Leaders keep working
# even while the player is off in the dungeon -- the town runs itself.
const BANK_INTEREST_RATE := 0.03        # Treasurer: treasury grows this fraction per tick
const BANK_INTEREST_CAP := 60           # ...capped per tick so wealth can't run away
const AUTO_HEAL_PER_PHYSICIAN := 18.0   # Chief Physician: injured-villager HP restored per tick
const AUTO_SELL_KEEP := 12              # Merchant Prince: keep this many of each material
const AUTO_SELL_PRICE := 4              # ...and sell the surplus at this gold each
const AUTO_ENROLL_PER_PRINCIPAL := 2    # Principal: idle children auto-enrolled per tick
const WARCHIEF_DEFENSE := 4.0           # Warchief: standing siege defense added per seat
const HARVESTMASTER_FOOD_BONUS := 0.6   # Harvestmaster: +this fraction of farm food output
const LEADER_MORALE_EACH := 6           # Tavernkeeper/Publican: morale points added per seat

# --- Barracks armory ---
# Warriors fight far harder when ARMED. Early game the player hand-carries spare
# weapons/armor to the Barracks (deposit_one_arm) to stock its armory; once a
# Forgemaster (Blacksmith leader) is seated, his smiths auto-deliver arms every
# tick (see apply_leadership_automation). arm_value scales with the gear's grade.
var barracks_arms := 0
const ARMED_WARRIOR_BONUS := 1.5        # extra siege defense per armed warrior
const BARRACKS_ARMS_CAP := 99           # armory stockpile ceiling
const FORGE_ARMS_PER_TICK := 3          # arms the Forgemaster's smiths deliver per tick

# How much one piece of gear arms the barracks (better grade == better kit).
func arm_value_of(item_id: String) -> int:
	var grade = Inventory.get_grade(item_id)
	if Inventory.GRADE_DEFS.has(grade):
		return int(Inventory.GRADE_DEFS[grade].rank)
	return 1

# Warriors actually equipped from the armory (can't arm more than you have).
func armed_warriors() -> int:
	return min(warrior_count(), barracks_arms)

# Is a Forgemaster keeping the armory supplied automatically?
func forgemaster_supplying() -> bool:
	return seated_leaders("Blacksmith") > 0 and is_building_operational("Barracks")

# Manual deposit: hand one piece of spare gear to the Barracks. Returns arms added.
func deposit_one_arm(player: Node, item_id: String) -> int:
	if player == null or not ("inventory" in player) or player.inventory == null:
		return 0
	if player.inventory.get_count(item_id) <= 0:
		return 0
	var cat = str(Inventory.get_item_def(item_id).get("category", ""))
	if cat != "weapon" and cat != "armor":
		return 0
	if barracks_arms >= BARRACKS_ARMS_CAP:
		return 0
	player.inventory.remove_item(item_id, 1)
	var v = min(arm_value_of(item_id), BARRACKS_ARMS_CAP - barracks_arms)
	barracks_arms += v
	return v

# How many VIP leaders are currently seated at a building's top post(s).
func seated_leaders(role_key: String) -> int:
	var n := 0
	for rd in BuildingRoles.get_roles(role_key):
		if rd.get("leadership", false):
			n += count_leader_holders(role_key, str(rd.get("title", "")))
	return n

func apply_leadership_automation() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if seated_leaders("Government") > 0:            # Chancellor: staff the town
		auto_staff_villagers()
	if player and player.has_method("add_currency") and seated_leaders("Bank") > 0:
		var interest = clampi(int(player.currency * BANK_INTEREST_RATE), 0, BANK_INTEREST_CAP)
		if interest > 0:
			player.add_currency(interest)               # Treasurer: interest
	var researchers = seated_leaders("Science Lab")
	if researchers > 0:
		auto_research(researchers)                  # Lead Researchers: identify mats
	if player and seated_leaders("Marketplace") > 0:
		auto_sell_surplus(player)                   # Merchant Prince: sell surplus
	var physicians = seated_leaders("Hospital")
	if physicians > 0:
		auto_heal_villagers(physicians)             # Chief Physician: heal the hurt
	if seated_leaders("School") > 0:
		auto_enroll_children(seated_leaders("School"))  # Principal: school the kids
	if seated_leaders("Builderhouse") > 0:
		auto_repair_one()                           # Builders: rebuild the ruins
	if forgemaster_supplying() and barracks_arms < BARRACKS_ARMS_CAP:
		barracks_arms = min(BARRACKS_ARMS_CAP, barracks_arms + FORGE_ARMS_PER_TICK)  # Forgemaster: arm the barracks

# Chancellor: seat every idle adult in an understaffed, operational worker role
# they qualify for (matching-stat first, then any open role). Leadership seats
# are never touched -- those stay unique to their rescued figure.
func auto_staff_villagers() -> void:
	for v in rescued_villagers:
		if v.get("is_kid", false) or str(v.get("role_key", "")) != "" or school_enrollments.has(v.get("id")):
			continue
		if not try_auto_place(v, true):
			try_auto_place(v, false)

func try_auto_place(v: Dictionary, require_stat_match: bool) -> bool:
	for bkey in BuildingRoles.ROLE_DEFS.keys():
		if not is_building_operational(bkey):
			continue
		for rd in BuildingRoles.get_roles(bkey):
			if rd.get("leadership", false) or rd.get("is_enrollment", false):
				continue
			var need = str(rd.get("required_stat", ""))
			if require_stat_match and need != str(v.get("stat_name", "")):
				continue
			if not require_stat_match and need != "":
				continue
			if count_leader_holders(bkey, str(rd.get("title", ""))) >= int(rd.get("slots", 0)):
				continue
			v["role_key"] = bkey
			v["role_title"] = str(rd.get("title", ""))
			return true
	return false

func auto_research(n: int) -> void:
	var done := 0
	for item_id in Inventory.ITEM_DEFS.keys():
		if done >= n:
			return
		if Inventory.ITEM_DEFS[item_id].get("is_material", false) and not researched_materials.has(item_id):
			researched_materials.append(item_id)
			done += 1

func auto_sell_surplus(player) -> void:
	if not ("inventory" in player) or player.inventory == null:
		return
	var earned := 0
	for item_id in Inventory.ITEM_DEFS.keys():
		if not Inventory.ITEM_DEFS[item_id].get("is_material", false):
			continue
		var have = player.inventory.get_count(item_id)
		if have > AUTO_SELL_KEEP:
			var sell = have - AUTO_SELL_KEEP
			player.inventory.remove_item(item_id, sell)
			earned += sell * AUTO_SELL_PRICE
	if earned > 0 and player.has_method("add_currency"):
		player.add_currency(earned)

func auto_heal_villagers(physicians: int) -> void:
	var amount = AUTO_HEAL_PER_PHYSICIAN * float(physicians)
	for id in villager_hp.keys():
		var hp = float(villager_hp[id])
		if hp < VILLAGER_MAX_HP:
			villager_hp[id] = minf(VILLAGER_MAX_HP, hp + amount)

func auto_enroll_children(principals: int) -> void:
	if not is_building_operational("School"):
		return
	var budget = AUTO_ENROLL_PER_PRINCIPAL * principals
	for v in rescued_villagers:
		if budget <= 0:
			return
		if v.get("is_kid", false) and str(v.get("role_key", "")) == "" and not school_enrollments.has(v.get("id")):
			enroll_villager(str(v.get("id")), "School", "Student", "random")
			budget -= 1

# Builderhouse: advance the single most-ruined building one construction stage
# each tick, for free -- the crew slowly rebuilds Deepwood on its own.
func auto_repair_one() -> void:
	var worst := ""
	var worst_stage := TOTAL_BUILD_STAGES
	for bn in STARTING_BUILDINGS:
		var st = building_build_stage(bn)
		if st < worst_stage:
			worst_stage = st
			worst = bn
	if worst == "" or worst_stage >= TOTAL_BUILD_STAGES:
		return
	building_stage[worst] = worst_stage + 1
	if int(building_stage[worst]) >= TOTAL_BUILD_STAGES:
		building_health[worst] = BUILDING_MAX_HEALTH
	for node in get_tree().get_nodes_in_group("building"):
		if "role_key" in node and str(node.role_key) == worst and node.has_method("refresh_visual"):
			node.refresh_visual()

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
	var child := {
		"id": child_id, "name": child_name, "sex": child_sex, "is_kid": true,
		"stat_name": "", "stat_value": 0, "role_key": "", "role_title": "", "paired": false,
	}
	# One in two hundred is born a HERO: a once-a-playthrough (if that) event.
	# A hero child cannot be schooled -- only the Barracks can shape what they
	# are -- and they emerge from training a full ADULT and terrifyingly strong.
	if randf() < HERO_BIRTH_CHANCE:
		child["hero"] = true
		var stack = get_tree().get_first_node_in_group("notification_stack")
		if stack:
			stack.show_notification("★ %s is born a HERO — the Barracks awaits them." % child_name)
	rescued_villagers.append(child)
	register_villagers_added(1)   # a new life eases the town's grief
	child_produced.emit(child_id)

# Finds a villager's current wander-AI world avatar (if any) via the shared
# "npc" group -- see npc.gd -- and removes it. Used when a pair steps back
# into a cottage for another pregnancy after already having one before.
func remove_npc_avatar(villager_id: String) -> void:
	for npc in get_tree().get_nodes_in_group("npc"):
		if npc.villager_id == villager_id:
			npc.queue_free()

# --- School / Barracks enrollment ---

const HERO_BIRTH_CHANCE := 0.005   # 0.5% of newborns
# The powers a hero may graduate with (rolled once, kept for life). Each is a
# different mechanic on their siege unit -- see siege_enemy.gd's hero hooks.
const HERO_POWERS = {
	"warcry": "Warcry",         # arrival staggers every raider near them slow
	"stormhand": "Stormhand",   # every blow chains a shock into a second raider
	"unbroken": "Unbroken",     # the first death each siege doesn't take
	"rally": "Rally",           # every soldier beside them marches with +50% HP
}

# --- The Doctor's escalating heal (GAME_BIBLE 5.5a) ---
# The early game's lifeline: full heal on demand, but every purchase raises the
# next price by half again, and only rest (in-game days) walks it back down.
# "Every avoidable wound bleeds your economy" -- and if she dies in a siege,
# the service dies with her.
const DOCTOR_BASE_PRICE := 8
const DOCTOR_PRICE_GROWTH := 1.5
const DOCTOR_DECAY_HOURS := 24.0   # one price step forgiven per in-game day
var doctor_heals_bought := 0
var _doctor_decay_accum := 0.0

func doctor_heal_price() -> int:
	return int(round(DOCTOR_BASE_PRICE * pow(DOCTOR_PRICE_GROWTH, doctor_heals_bought)))

func doctor_alive() -> bool:
	for v in rescued_villagers:
		if v.get("healer", false):
			return true
	return false

func decay_doctor_price(hours_passed: float) -> void:
	if doctor_heals_bought <= 0:
		return
	_doctor_decay_accum += hours_passed
	while _doctor_decay_accum >= DOCTOR_DECAY_HOURS and doctor_heals_bought > 0:
		_doctor_decay_accum -= DOCTOR_DECAY_HOURS
		doctor_heals_bought -= 1

func enroll_villager(villager_id: String, role_key: String, role_title: String, grants_stat: String) -> void:
	# A hero child refuses the School outright -- books cannot hold what they
	# are. Only the Barracks can. (The UI filters them out too; this guard is
	# for any other path that reaches enrollment.)
	var v = find_villager_by_id(villager_id)
	if v.get("hero", false) and role_key == "School":
		var stack = get_tree().get_first_node_in_group("notification_stack")
		if stack:
			stack.show_notification("%s was born a HERO — the School cannot teach them. Send them to the Barracks." % v.get("name", "The child"))
		return
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
			# A HERO leaves the Barracks a finished weapon: a full adult with a
			# Warrior stat no school could grant, counted at triple weight in
			# the defense maths and fielded as a hero soldier in live sieges.
			if villager.get("hero", false):
				villager["stat_name"] = "Warrior"
				villager["stat_value"] = 10
				villager["hero_trained"] = true
				# each hero graduates with a PERSONAL power, rolled once and
				# carried for life -- no two playthroughs' heroes fight alike
				var power: String = HERO_POWERS.keys()[randi() % HERO_POWERS.size()]
				villager["hero_power"] = power
				var stack = get_tree().get_first_node_in_group("notification_stack")
				if stack:
					stack.show_notification("★ %s completes their training — a HERO of the %s stands among you." % [
						villager.get("name", "?"), HERO_POWERS[power]])

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
	adventurers = {}
	ensure_adventurers()                       # the opening trio stands ready
	doctor_heals_bought = 0
	# The Doctor (GAME_BIBLE 2.4.1 / 5.5a): the woman found tending the three
	# wounded defenders, Deepwood's physician before it fell. She is WITH you
	# from the first breath -- the early game's only reliable healing -- and she
	# is an ordinary mortal villager: a siege can take her like anyone else,
	# and with her dies the service.
	rescued_villagers.append({
		"id": "doctor_maren", "name": "Doctor Maren Hollis", "sex": "Female", "is_kid": false,
		"stat_name": "Hospital", "stat_value": 4, "role_key": "", "role_title": "", "paired": false,
		"healer": true,
	})
	# ...and the two farmhands of the starting six (2.5.1's roster: 3 heroes,
	# 1 Doctor, 2 Farmers). First food, first hands.
	rescued_villagers.append({
		"id": "farmer_tam", "name": "Tam Beckett", "sex": "Male", "is_kid": false,
		"stat_name": "Farm", "stat_value": 2, "role_key": "", "role_title": "", "paired": false,
	})
	rescued_villagers.append({
		"id": "farmer_ada", "name": "Ada Brook", "sex": "Female", "is_kid": false,
		"stat_name": "Farm", "stat_value": 2, "role_key": "", "role_title": "", "paired": false,
	})
	chest_contents = {}
	mating_houses = {}
	pregnancies = {}
	school_enrollments = {}
	highest_unlocked_level = 999 if TEST_UNLOCK_ALL_LEVELS else 1
	village_last_hours_elapsed = 0.0
	game_hours = 0.0
	hours_until_next_siege = SIEGE_FIRST_HOURS
	live_siege_active = false
	away_report = {"sieges": 0, "repelled": 0, "villagers_lost": 0, "adventurers_lost": 0}
	# The village starts in ruins -- every building begins destroyed (health 0)
	# and must be repaired before its roles work.
	building_health = {}
	building_stage = {}
	for bn in STARTING_BUILDINGS:
		building_health[bn] = 0
		building_stage[bn] = 0
	building_levels = {}
	wizard_respawn_at_hours = -1.0
	placed_torches = []
	morale_death_shock = 0.0
	morale_meter_unlocked = false
	low_morale_hours = 0.0
	villager_hp = {}
	barracks_arms = 0
	seen_intro = false
	seen_l100_reveal = false
	morale_admin_offset = 0
	if TEST_POPULATE_VILLAGE:
		test_populate_village()
	wizard_power_tier = 0
	player_xp = 0
	player_level = 1
	monarch_stage_announced = 0
	skill_points = 0
	chosen_class = ""
	unlocked_skills = []
	researched_materials = []
	equipment = empty_equipment()
	# Per-run flags that were quietly surviving into fresh games. The admin's
	# forced god-form stayed forced; the starvation/morale warnings stayed
	# "already warned" and so could never fire again for the rest of the install;
	# and a New Game started from inside a dungeon kept the dungeon transition
	# half-armed. (deepest_level_reached and game_completed are NOT reset here --
	# those are deliberate lifetime records with their own save files.)
	monarch_true_form_forced = false
	_warned_no_food = false
	_warned_low_morale = false
	in_dungeon = false
	returning_from_dungeon = false
	active_dungeon_level = 1
	pre_dungeon_position = Vector2.ZERO
	income_timer = 0.0
	tribute_timer = 0.0
	# A fresh village opens with a full larder (computed after any test-populate,
	# so the starting food matches the starting headcount) -- the player has a
	# comfortable runway to rebuild the Farm before hunger bites.
	food_empty_hours = 0.0
	village_food = food_capacity()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game(player: Node) -> void:
	var save_pos = pre_dungeon_position if in_dungeon else player.global_position
	var data = {
		"currency": player.currency,
		"inventory": player.inventory.to_save_data(),
		"position_x": save_pos.x,
		"position_y": save_pos.y,
		"active_weapon_id": player.active_weapon_id,
		"has_dash": player.has_dash,
		"has_double_jump": player.has_double_jump,
		"health": player.health,
		"mana": player.mana,
		"difficulty": difficulty,
		"rescued_villagers": rescued_villagers,
		"adventurers": adventurers,
		"doctor_heals_bought": doctor_heals_bought,
		"seen_orin_arrival": seen_orin_arrival,
		"seen_doctor_account": seen_doctor_account,
		"seen_failed_escape": seen_failed_escape,
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
		"equipment": equipment,
		"game_hours": game_hours,
		"hours_until_next_siege": hours_until_next_siege,
		"away_report": away_report,
		"building_health": building_health,
		"building_stage": building_stage,
		"building_levels": building_levels,
		"placed_torches": placed_torches,
		"wizard_respawn_at_hours": wizard_respawn_at_hours,
		"wizard_power_tier": wizard_power_tier,
		"morale_death_shock": morale_death_shock,
		"morale_meter_unlocked": morale_meter_unlocked,
		"low_morale_hours": low_morale_hours,
		"villager_hp": villager_hp,
		"morale_admin_offset": morale_admin_offset,
		"barracks_arms": barracks_arms,
		"seen_intro": seen_intro,
		"seen_l100_reveal": seen_l100_reveal,
		"village_food": village_food,
		"food_empty_hours": food_empty_hours,
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
		if parsed.has("adventurers"):
			adventurers = parsed["adventurers"]
			ensure_adventurers()   # a newer build may know MORE adventurers than the save
		doctor_heals_bought = int(parsed.get("doctor_heals_bought", 0))
		seen_orin_arrival = bool(parsed.get("seen_orin_arrival", false))
		seen_doctor_account = bool(parsed.get("seen_doctor_account", false))
		seen_failed_escape = bool(parsed.get("seen_failed_escape", false))
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
		if TEST_UNLOCK_ALL_LEVELS:
			highest_unlocked_level = max(highest_unlocked_level, 999)
		player_xp = parsed.get("player_xp", player_xp)
		player_level = parsed.get("player_level", player_level)
		monarch_stage_announced = monarch_stage()   # already-reached stages don't re-toast
		skill_points = parsed.get("skill_points", skill_points)
		chosen_class = parsed.get("chosen_class", chosen_class)
		unlocked_skills = parsed.get("unlocked_skills", unlocked_skills)
		researched_materials = parsed.get("researched_materials", researched_materials)
		if parsed.has("equipment"):
			load_equipment(parsed["equipment"])
		game_hours = float(parsed.get("game_hours", 0.0))
		hours_until_next_siege = float(parsed.get("hours_until_next_siege", SIEGE_FIRST_HOURS))
		live_siege_active = false
		# start the village-clock baseline at the loaded time so the first
		# tick after loading doesn't see a giant false "hours passed".
		village_last_hours_elapsed = game_hours
		if parsed.has("away_report") and parsed["away_report"] is Dictionary:
			var ar = parsed["away_report"]
			away_report = {
				"sieges": int(ar.get("sieges", 0)),
				"repelled": int(ar.get("repelled", 0)),
				"villagers_lost": int(ar.get("villagers_lost", 0)),
			}
		if parsed.has("building_health") and parsed["building_health"] is Dictionary:
			building_health = {}
			for k in parsed["building_health"].keys():
				building_health[k] = int(parsed["building_health"][k])
		if parsed.has("building_levels") and parsed["building_levels"] is Dictionary:
			building_levels = {}
			for k in parsed["building_levels"].keys():
				building_levels[k] = int(parsed["building_levels"][k])
		if parsed.has("building_stage") and parsed["building_stage"] is Dictionary:
			building_stage = {}
			for k in parsed["building_stage"].keys():
				building_stage[k] = int(parsed["building_stage"][k])
		placed_torches = []
		for e in parsed.get("placed_torches", []):
			if e is Dictionary:
				placed_torches.append({"x": float(e.get("x", 0.0)), "y": float(e.get("y", 0.0))})
		wizard_respawn_at_hours = float(parsed.get("wizard_respawn_at_hours", -1.0))
		wizard_power_tier = int(parsed.get("wizard_power_tier", 0))
		morale_death_shock = float(parsed.get("morale_death_shock", 0.0))
		morale_meter_unlocked = bool(parsed.get("morale_meter_unlocked", false))
		low_morale_hours = float(parsed.get("low_morale_hours", 0.0))
		morale_admin_offset = int(parsed.get("morale_admin_offset", 0))
		# Older saves have no larder key -> default to a full one for the loaded pop.
		food_empty_hours = float(parsed.get("food_empty_hours", 0.0))
		barracks_arms = int(parsed.get("barracks_arms", 0))
		seen_intro = bool(parsed.get("seen_intro", true))   # old saves: don't replay
		seen_l100_reveal = bool(parsed.get("seen_l100_reveal", false))
		village_food = float(parsed.get("village_food", food_capacity()))
		villager_hp = {}
		if parsed.has("villager_hp") and parsed["villager_hp"] is Dictionary:
			for k in parsed["villager_hp"].keys():
				villager_hp[k] = float(parsed["villager_hp"][k])
		if TEST_POPULATE_VILLAGE:
			test_populate_village()
		return parsed
	return {}

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)

func rescue_villager(data: Dictionary) -> void:
	# personal bond (VillagerQuests): if this named villager has a quest, it
	# starts active the moment they're freed.
	if VillagerQuests.has_quest(str(data.get("id", ""))):
		data["quest_state"] = "active"
		data["quest_progress"] = 0
	rescued_villagers.append(data)
	# rescuing someone can be the objective of a "reunite" bond on ANOTHER villager
	quest_event("reunite", str(data.get("id", "")), 1)

# --- Villager bonds (personal quests) ---
# Advance every active bond of a matching kind. gather bonds aren't event-driven
# (readiness is read live from the bag at turn-in); slay/reach_level/reunite
# accumulate here. Called from player.on_enemy_killed (slay), the dungeon on a
# level clear (reach_level), and rescue_villager (reunite).
func quest_event(kind: String, key: String, amount: int) -> void:
	for v in rescued_villagers:
		if v.get("quest_state", "") != "active":
			continue
		var def = VillagerQuests.get_def(str(v.get("id", "")))
		if def.is_empty() or str(def.get("kind", "")) != kind:
			continue
		match kind:
			"slay":
				v["quest_progress"] = int(v.get("quest_progress", 0)) + amount
			"reach_level":
				v["quest_progress"] = max(int(v.get("quest_progress", 0)), amount)
			"reunite":
				if key == str(def.get("key", "")):
					v["quest_progress"] = int(def.get("count", 1))

func find_villager_by_id(villager_id: String) -> Dictionary:
	for v in rescued_villagers:
		if str(v.get("id", "")) == villager_id:
			return v
	return {}

# Is this villager's bond finished-but-not-yet-claimed? gather reads the live
# bag; the rest compare accumulated quest_progress to the target count.
func villager_quest_ready(v: Dictionary, player: Node) -> bool:
	if v.get("quest_state", "") != "active":
		return false
	var def = VillagerQuests.get_def(str(v.get("id", "")))
	if def.is_empty():
		return false
	var count = int(def.get("count", 1))
	if str(def.get("kind", "")) == "gather":
		if player == null or not ("inventory" in player) or player.inventory == null:
			return false
		return player.inventory.get_count(str(def.get("key", ""))) >= count
	return int(v.get("quest_progress", 0)) >= count

# Claim a ready bond: consume gather items, reveal the hidden stat, pay the
# reward, and mark the villager bonded (permanent income boost). Returns the
# villager's completion line for the caller to voice, or "" if not claimable.
func turn_in_villager_quest(villager_id: String, player: Node) -> String:
	var v = find_villager_by_id(villager_id)
	if v.is_empty() or not villager_quest_ready(v, player):
		return ""
	var def = VillagerQuests.get_def(villager_id)
	if str(def.get("kind", "")) == "gather" and player and "inventory" in player and player.inventory:
		player.inventory.remove_item(str(def.get("key", "")), int(def.get("count", 1)))
	v["quest_state"] = "done"
	v["bond"] = true
	if str(def.get("reveal_stat", "")) != "":
		v["stat2_name"] = str(def.get("reveal_stat"))
		v["stat2_value"] = int(def.get("reveal_value", 0))
	if int(def.get("reward_gold", 0)) > 0 and player and player.has_method("add_currency"):
		player.add_currency(int(def.get("reward_gold")))
	if str(def.get("reward_item", "")) != "" and player and "inventory" in player and player.inventory:
		player.inventory.add_item(str(def.get("reward_item")), int(def.get("reward_count", 1)))
	return str(def.get("reward_line", ""))

func is_villager_rescued(villager_id: String) -> bool:
	for entry in rescued_villagers:
		if entry.get("id") == villager_id:
			return true
	return false

func assign_villager_to_role(villager_id: String, role_key: String, role_title: String) -> bool:
	# Leadership seats are RESERVED and unique: only the rescued VIP who carries
	# that post's own stat may ever hold it. This is a hard invariant enforced
	# here (not just filtered by the assign UI), so no code path can seat a
	# regular villager, a School graduate, or a child as a leader.
	for rd in BuildingRoles.get_roles(role_key):
		if str(rd.get("title", "")) == role_title and rd.get("leadership", false):
			var who := {}
			for v in rescued_villagers:
				if v.get("id") == villager_id:
					who = v
					break
			if who.is_empty() or str(who.get("stat_name", "")) != str(rd.get("required_stat", "")):
				return false
			break
	for villager in rescued_villagers:
		if villager.get("id") == villager_id:
			villager["role_key"] = role_key
			villager["role_title"] = role_title
			return true
	return false

# Fully removes one villager: from the roster, plus any mating/pregnancy/
# school state they were tied to, plus their walking world avatar. Shared by
# the death-penalty path (remove_random_villager) and villager death (an NPC
# whose HP hit 0 -- see npc.gd's die()).
func remove_villager_by_id(villager_id: String) -> void:
	for entry in rescued_villagers:
		if entry.get("id") == villager_id:
			rescued_villagers.erase(entry)
			register_villager_deaths(1)   # every villager lost grieves the town
			break
	for house_id in mating_houses.keys():
		var pairing = mating_houses[house_id]
		if pairing.male_id == villager_id or pairing.female_id == villager_id:
			mating_houses.erase(house_id)
	for pregnancy_id in pregnancies.keys():
		var pairing = pregnancies[pregnancy_id]
		if pairing.male_id == villager_id or pairing.female_id == villager_id:
			pregnancies.erase(pregnancy_id)
	if school_enrollments.has(villager_id):
		school_enrollments.erase(villager_id)
	remove_npc_avatar(villager_id)

# Called by the death sequence (player.gd's die()) on Medium/Hard.
func remove_random_villager() -> void:
	if rescued_villagers.is_empty():
		return
	var removed = rescued_villagers[randi() % rescued_villagers.size()]
	remove_villager_by_id(removed.get("id"))

# Hard's extra sting on death: you lose a unit of a skill-crafting material.
# Skill nodes are paid for in these (see unlock_skill), so dying on Hard sets
# back your TREE as well as your village -- which is the whole point of the
# difficulty. This sat as an empty `pass` with a stale "wire it up once the
# material system exists" note long after that system shipped, so Hard and
# Medium were punishing death identically.
func remove_one_skill_material() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null or not ("inventory" in player) or player.inventory == null:
		return
	# only take something the player actually has, preferring the cheapest so a
	# death doesn't wipe a rare drop they were saving for an ultimate
	var order := ["slime", "iron_shard", "ember_crystal", "void_essence", "ancient_relic"]
	for mat_id in order:
		if player.inventory.get_count(mat_id) > 0:
			player.inventory.remove_item(mat_id, 1)
			var stack = get_tree().get_first_node_in_group("notification_stack")
			if stack and stack.has_method("show_notification"):
				stack.show_notification("Hard: you lost 1 %s." % Inventory.get_display_name(mat_id))
			return
