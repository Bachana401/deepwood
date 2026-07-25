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

# A FLOOR YOU CLEARED STAYS CLEARED (dev rule 2026-07-21): "mobs never respawn
# as long as player killed that level" -- leaving, coming back hours later, or
# quitting and reloading changes nothing. Floors used to repopulate on every
# entry, so re-crossing a cleared floor to reach a deeper one meant fighting it
# again from scratch. Per-run (a New Game starts with an unswept deep), keyed
# by floor number as a String because JSON keys are strings and a round-trip
# through the save would otherwise turn 7 into "7" and lose every entry.
var floors_cleared: Dictionary = {}

func floor_is_cleared(level: int) -> bool:
	return bool(floors_cleared.get(str(level), false))

func mark_floor_cleared(level: int) -> void:
	floors_cleared[str(level)] = true

# WAYSTONE SHRINES (fast-travel, Wukong-style, dev 2026-07-21). A Deep Shrine
# stands on every tenth floor, INVISIBLE until you clear that floor -- then it
# wakes (log + world-wide chime) and becomes a fast-travel anchor. The village
# WAYSTONE (its blueprint recovered the moment you clear floor 20) lets you leap
# to any woken shrine from home, so re-descending never wastes your time.
# "Revealed" is DERIVED from floors_cleared -- no separate save; only the
# Waystone's own unlock is a flag.
const SHRINE_INTERVAL := 10
var waystone_unlocked := false
# Where the village Waystone stands (set by main.gd when it spawns one). Transient
# -- a deep shrine reads it to know where "return home" drops you. Falls back to
# VILLAGE_SPAWN before a Waystone exists.
var waystone_home_pos := Vector2.ZERO

func is_shrine_floor(level: int) -> bool:
	return level >= SHRINE_INTERVAL and level % SHRINE_INTERVAL == 0

func shrine_revealed(level: int) -> bool:
	return is_shrine_floor(level) and floor_is_cleared(level)

func revealed_shrines() -> Array:
	var out := []
	var f: int = SHRINE_INTERVAL
	while f <= 100:
		if shrine_revealed(f):
			out.append(f)
		f += SHRINE_INTERVAL
	return out

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

# THE DEPTH PAYS (numbers pass 2026-07-20): every dungeon kill paid the
# same XP and GOLD as a floor-1 rat -- the "* damage_multiplier" in the
# death rewards reads the VILLAGE respawn-generation scaler, which is
# always 1.0 in the deep. So a floor-90 horror paid 8 XP and 5 gold,
# reaching a full skill tree (~level 55, ~45,000 XP) took ~560 floor
# clears, and the new upgrade ladder (~24,750g for a maxed town) had
# nothing to feed it. Depth now multiplies both: floor 1 pays ~9 XP a
# kill, floor 50 ~48, floor 99 ~87 -- clearing the whole ladder once
# lands a player in the mid-50s (a full class tree plus change), and the
# gold keeps pace with the buildings it is meant to buy.
func depth_reward_mult() -> float:
	if not in_dungeon:
		return 1.0
	return 1.0 + 0.10 * float(active_dungeon_level)

const PLAYER_LEVEL_CAP := 100   # the seventh gate: 7/7 IS the ceiling

func add_xp(amount: int) -> void:
	# the Monarch fiction has always said "cap 100" -- the code never did.
	# Level 100 is the full 2x god-form; there is nothing past the seventh
	# gate, so the counter must not tick past it either.
	if player_level >= PLAYER_LEVEL_CAP:
		player_xp = 0
		return
	var boosted = int(round(amount * (1.0 + get_bonus_total("xp_gain"))))
	player_xp += boosted
	var leveled := false
	while player_xp >= xp_to_next_level():
		if player_level >= PLAYER_LEVEL_CAP:
			player_xp = 0   # the counter must never tick past the cap, even on a huge grant
			break
		player_xp -= xp_to_next_level()
		player_level += 1
		skill_points += 1
		leveled = true
		var notif = get_tree().get_first_node_in_group("notification_stack")
		if notif:
			notif.show_notification("Level up! You are now level %d (+1 skill point)" % player_level)
	# the level-up MOMENT: levels are the reward engine now (the depth
	# pays), so the beat gets a bell and a word, not only a beige toast
	if leveled:
		play_sfx(SFX_CHIME, 1.9)
		var player = get_tree().get_first_node_in_group("player")
		if player != null:
			FloatingText.spawn_word(player.get_parent(), player.global_position + Vector2(0, -70),
				"LEVEL %d" % player_level, Color(1.0, 0.9, 0.4))
		if player != null and player.has_method("update_currency_display"):
			player.update_currency_display()
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
		# about YOU, not the town -- never gated by the village fog
		var stack = get_tree().get_first_node_in_group("notification_stack")
		if stack:
			stack.show_notification(line)

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
	# Toren Ashvale, the Forgefather (the Ten): crafting costs a quarter less
	var cost_mult := 0.75 if ten_freed("ten_toren") else 1.0
	for ing in recipe.keys():
		var need: int = maxi(1, int(ceil(recipe[ing] * cost_mult)))
		if player.inventory.get_count(ing) < need:
			return "Missing %dx %s." % [need, Inventory.get_display_name(ing)]
	var consumed := {}
	for ing in recipe.keys():
		var take: int = maxi(1, int(ceil(recipe[ing] * cost_mult)))
		player.inventory.remove_item(ing, take)
		consumed[ing] = take
	# add_item returns the leftover; a full bag would eat the crafted result and
	# the ingredients with it -- so roll the ingredients back and craft nothing
	if player.inventory.add_item(item_id, 1) > 0:
		for ing in consumed:
			player.inventory.add_item(ing, consumed[ing])
		return "Your bag is full — no room for the result."
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

# Which Underdark rune-vaults have been unbarred, by band index. The deep is
# rebuilt from a fixed seed on EVERY scene load (including every trip back up
# from a dungeon floor), so without this a vault you opened would silently
# re-bar itself the moment you returned -- runes reset, gate back down, an empty
# chest sealed behind it. Persisted so an opened vault stays open. (The loot
# itself never dupes regardless: the chest behind it lives in chest_contents.)
var underdark_vaults_open: Array = []

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

func set_adventurer_station(id: String, station: String) -> bool:
	ensure_adventurers()
	if not (adventurers.has(id) and station in Adventurers.STATIONS):
		return false
	# the wall only has so many fighting-steps -- a higher tier holds more. A full
	# wall turns the extra defenders back to the city patrol until you raise it.
	if station == "wall" and adventurers[id]["station"] != "wall":
		if wall_stationed_count() >= wall_station_capacity():
			var stack = get_tree().get_first_node_in_group("notification_stack")
			if stack:
				stack.show_notification("The wall is full (%d posts). Raise the rampart for more." % wall_station_capacity())
			return false
	adventurers[id]["station"] = station
	return true

# Living, rescued adventurers currently posted ON the wall (counts toward its cap).
func wall_stationed_count() -> int:
	ensure_adventurers()
	var n := 0
	for id in adventurers.keys():
		var a: Dictionary = adventurers[id]
		if a["rescued"] and not a["dead"] and a["station"] == "wall":
			n += 1
	return n

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
# --- THE GOLD FAUCETS (GAME_BIBLE 5.6, revised canon 2026-07-17) ---
# Only the GOVERNMENT (taxes) and the BANK (interest) make village gold --
# plus the Bar's small drink-sales trickle and the player's own dungeon
# haul. No other building prints money: they pay out in their own resource
# (food, arms, repairs, knowledge). Early game the dungeon subsidizes the
# village; as Government and Bank come online, it approaches self-funding.
# Numbers pass (2026-07-20, balance sim): income ticks fire ~30x per game
# day, so per-tick rates are set for PER-DAY sanity -- a worker's tax take
# (~1.8/day) barely clears their wage (1.5/day): the village approaches
# self-funding, it never becomes a mint. Fractions accrue (see _gold_accum)
# so a small town still earns its coins, just slowly.
const TAX_PER_EMPLOYED := 0.06         # ~1.8 gold per worker per day
const BARKEEP_TRICKLE := 0.08          # ~2.4 gold per staffed Barkeep per day
const WAGE_PER_WORKER_PER_DAY := 1.5   # 5.5: staff draw a daily wage from the purse
const BANK_PAYROLL_DISCOUNT := 0.85    # a staffed Bank runs payroll leaner
const PARTY_MEMBER_INCOME = 0.15       # per tick -- ~4.5/day per Party member
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
# A new run opens at NIGHT (start-scene fix 2026-07-21): 22:00, so the
# arrival's rain-lit fight plays in the dark as canon asks, and dawn breaks a
# few game-hours into the rebuilding. This is the clock OFFSET only --
# game_hours (elapsed play time) still starts at 0, so no elapsed-time gate
# (morale grace, wages, sieges) is disturbed.
const START_TIME_OF_DAY = 22.0
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
# A full day (24h) is 600s real, so 1 in-game hour ~= 25s. The FIRST wave is a
# generous grace day-and-a-bit so a new player finishes the tutorial and raises
# the wall before anything hits (dev 2026-07-23: "wave came too fast" -- it was 6h
# / ~2.5 real minutes, landing mid-tutorial). The clock also doesn't start until the
# opening is over (see tick_sieges).
const SIEGE_FIRST_HOURS = 24.0
const SIEGE_INTERVAL_HOURS = 12.0
# Abstract defense model used when a siege resolves OFF-SCREEN (player away):
# the wizard is a standing defense of SIEGE_DEF_WIZARD; each Barracks warrior
# adds SIEGE_DEF_PER_WARRIOR. A siege of "threat" = its day tier is repelled
# cleanly if defense >= threat, otherwise the overflow becomes villager deaths.
const SIEGE_DEF_WIZARD = 4.0
const SIEGE_DEF_PER_WARRIOR = 1.0
# THE BLACK TIDE (GAME_BIBLE 3c, dev vision: "a few waves, not often, which the
# village won't survive without adventurers"). Every Nth siege (once you've drawn
# real heat) is a Black Tide: a wave far past what the wall's passive defense
# (the wizard + warriors) can hold, so only STATIONED ADVENTURERS (worth 3 defense
# each) can turn it. Telegraphed early with a fog-piercing omen so you can rush
# home and post your defenders.
const BLACK_TIDE_EVERY := 6
const BLACK_TIDE_MIN_DEPTH := 15     # not until Orin is freed -- the start stays gentle
const BLACK_TIDE_TIER_MULT := 2.2
const BLACK_TIDE_LEAD := 8.0
var sieges_seen := 0
var _black_omen_armed := true
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
# building_health without depending on building.gd. Keep the two in sync: a
# runtime assert in building.gd._ready() fails loud if they ever drift.
const BUILDING_MAX_HEALTH = 400

# Construction progress per building, 0..TOTAL_BUILD_STAGES. 0 = ruins; each F
# repair advances it one stage (frame -> walls -> finished); only at the final
# stage is the building operational and its combat HP meaningful. Persisted so
# a half-built building stays half-built across reloads. See building.gd.
const TOTAL_BUILD_STAGES = 3
var building_stage: Dictionary = {}

# RUBBLE (dev request 2026-07-21): a ruin starts as a nameless heap. Before any
# plans or building can happen the player CLEARS it by hand -- E three times,
# 1/3, 2/3, 3/3 -- and only the clearing reveals what stood there. Until then
# no name floats over it; the old labels made the village read like a menu.
const CLEAR_STEPS = 3
var building_cleared: Dictionary = {}   # building name -> 0..CLEAR_STEPS

func building_clear_progress(name: String) -> int:
	return int(building_cleared.get(name, 0))

func building_is_cleared(name: String) -> bool:
	# anything already under construction or standing predates the rubble system
	# (or was cleared): never make the player re-shovel a half-built hall
	return building_clear_progress(name) >= CLEAR_STEPS or building_build_stage(name) > 0

# The Blacksmith (the Forge) is a MID-GAME building: it can't be raised until the
# player has braved this dungeon depth. It exists to reliably supply equippable
# gear of every slot up to a non-OP tier -- see assign_ui.add_smithy_section.
const BLACKSMITH_UNLOCK_DEPTH = 35

func blacksmith_unlocked() -> bool:
	# Gated on THIS run's progression, not the lifetime record -- a veteran
	# starting over earns the Forge again like everyone else.
	return highest_unlocked_level >= BLACKSMITH_UNLOCK_DEPTH

func building_build_stage(name: String) -> int:
	return int(building_stage.get(name, 0))

# The 12 village buildings (names == building_name == role_key). At New Game the
# village lies in ruins -- every one of these starts DESTROYED (health 0) and
# non-operational until the player repairs it (building.gd.try_repair). This is
# the core "return from the dungeon and rebuild Deepwood" loop.
const STARTING_BUILDINGS = [
	"Government", "School", "Farm", "Hospital", "Barracks", "Fishing Dock",
	"Science Lab", "Bank", "Blacksmith", "Tavern", "Bar", "Marketplace", "Builderhouse",
	"Mine", "Shrine",
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

# --- DELETED BUILDINGS (dev 2026-07-22 building menu: "player can delete these
# ruins... game always double checks"). A building the player razes for good is
# recorded here; generate_village skips it on every rebuild, leaving its ground
# empty, until it is re-placed. Keyed by building_name.
var removed_buildings: Dictionary = {}

func building_removed(bname: String) -> bool:
	return removed_buildings.has(bname)

func remove_building(bname: String) -> void:
	removed_buildings[bname] = true
	# UNASSIGN its workers (dev 2026-07-23 hole): deleting a building left its
	# villagers with a role_key pointing at nothing -- still counted as "employed",
	# still drawing wages (tick_wages pays anyone with a role_key), producing
	# nothing, and awkward to reassign. Set them idle so the roster is honest.
	var freed := 0
	for v in rescued_villagers:
		if str(v.get("role_key", "")) == bname:
			v["role_key"] = ""
			v["role_title"] = ""
			freed += 1
	# School students AND Barracks recruits share school_enrollments (each tagged
	# with its enrollment's role_key). Clear only THIS building's trainees -- razing
	# the School must not wipe Barracks recruits, and razing the Barracks must not
	# leave recruits training a hall that no longer stands. (.keys() is a copy, so
	# erasing mid-iteration is safe.)
	for vid in school_enrollments.keys():
		if str(school_enrollments[vid].get("role_key", "School")) == bname:
			school_enrollments.erase(vid)
	log_event("village", "%s was cleared away — its ground stands empty now." % bname)
	if freed > 0:
		log_event("village", "%d worker%s laid off — the %s no longer stands." % [freed, "s" if freed != 1 else "", bname])

func restore_building(bname: String) -> void:
	removed_buildings.erase(bname)

# Delete a player-raised COTTAGE (dev 2026-07-23: cottages are deletable now). Drops
# its saved ground + the count, breaks any pairing sheltering there, AND frees any
# settled couple who called it home. villager_home_id() DERIVES a home by scanning
# cottage_homes -- so razing an occupied cottage without erasing its cottage_homes
# entry left the couple pointing at a home that no longer stood (they read as housed,
# their gone cottage never freed a housing slot). dev 2026-07-23 dangling-home hole.
func remove_cottage(house_id: String, x: float) -> void:
	var best_i := -1
	var best_d := 1.0e9
	for i in range(extra_cottage_positions.size()):
		var d: float = absf(float(extra_cottage_positions[i]) - x)
		if d < best_d:
			best_d = d
			best_i = i
	# Erase the home/pairing by the SURVIVING cottage's own stored id, not the id the
	# caller passed -- the two can differ once ids stopped tracking the index, and it is
	# the stored id that cottage_homes is really keyed by. Drop id + position together so
	# the two arrays stay in lockstep and the remaining ids never shift.
	var gone_id := house_id
	if best_i >= 0 and best_d < 48.0:
		if best_i < extra_cottage_ids.size():
			gone_id = str(extra_cottage_ids[best_i])
			extra_cottage_ids.remove_at(best_i)
		extra_cottage_positions.remove_at(best_i)
	extra_cottages = maxi(0, extra_cottages - 1)
	for hid in [gone_id, house_id]:        # the couple mid-cycle / settled here loses it
		if mating_houses.has(hid):
			mating_houses.erase(hid)
		if cottage_homes.has(hid):
			cottage_homes.erase(hid)
	log_event("village", "A cottage was cleared away — its ground stands empty now.")

# Register a freshly-built cottage on the ground the player chose and hand back its
# STABLE id. build_placer stamps the node with this; main.gd re-stamps the same id on
# reload via cottage_id_at(), so cottage_homes always resolves. The seq only ever
# climbs, so a deleted cottage's id is never handed out again.
func register_cottage(x: float) -> String:
	var id := "menu_house_%d" % cottage_id_seq
	cottage_id_seq += 1
	extra_cottage_ids.append(id)
	extra_cottage_positions.append(x)
	extra_cottages = extra_cottage_ids.size()
	return id

# The stable id of the j-th surviving extra cottage (what main.gd stamps on reload).
# Falls back to the legacy index id if an older save never stored one.
func cottage_id_at(index: int) -> String:
	if index >= 0 and index < extra_cottage_ids.size():
		return str(extra_cottage_ids[index])
	return "menu_house_%d" % index

# Delete a player-raised WALL: drop it from placed_walls by its ground.
func remove_placed_wall(x: float) -> void:
	var kept := []
	for w in placed_walls:
		if absf(float(w.get("x", 0.0)) - x) > 4.0:
			kept.append(w)
	placed_walls = kept
	log_event("village", "A rampart was pulled down.")

# True while the B-menu placer holds the cursor (building or deleting). The player
# checks this so a left-click that places/deletes doesn't ALSO swing a weapon.
var placing_building := false

# --- RAISING BUILDINGS FROM THE MENU (dev 2026-07-22: build from B with a holo) ---
# Pick a building, a green/red hologram shows where it can stand, click to raise
# it on clear village ground. can_place_building is the ONE truth the holo colour
# and the actual placement both read, so green ALWAYS means it will build.
const BUILD_BASE_COST := {"coin_gold": 60, "wood": 16, "stone": 8}

# The FIRST buildings you raise cost only what you can GATHER (wood/stone), never
# gold -- the honest start has no coin and no way to earn it before you've built
# anything (dev bug 2026-07-23: "it doesn't let me build wall"). Your shelter, farm
# and walls come from timber and stone; gold is for the grander halls that come
# later (BUILD_BASE_COST). A small founder's cache (player.gd) covers these three.
func build_cost(bname: String) -> Dictionary:
	# kept cheap (dev 2026-07-23: "too much wood") so the lean founder's cache
	# (20 wood + 12 stone, player.gd) covers all three tutorial builds exactly --
	# they total 19 wood + 12 stone. All three cost only what you can GATHER at the
	# start: timber from trees, stone from the deposits. No gold, no rare mats.
	if bname == "Cottage":
		return {"wood": 8, "stone": 4}            # a home: timber on a stone footing
	if bname == "Wall":
		return {"stone": 6, "wood": 5}            # a rampart is stone + timber
	if bname == "Farm":
		return {"wood": 6, "stone": 2}            # tilled ground + a fence
	return BUILD_BASE_COST

func can_afford_build(bname: String, player: Node) -> bool:
	if player == null or not ("inventory" in player) or player.inventory == null:
		return false
	for k in build_cost(bname):
		if player.inventory.get_count(k) < int(build_cost(bname)[k]):
			return false
	return true

func pay_build(bname: String, player: Node) -> void:
	for k in build_cost(bname):
		player.inventory.remove_item(k, int(build_cost(bname)[k]))

# THE SURFACE BAND (de-magic'd 2026-07-24). Before the ramparts exist there is no
# perimeter to bound a build against, so these name the fallback band a building
# may stand in. Once a wall of a given flank stands, its REAL position overrides
# the matching fallback (see can_place_building / player.try_plant_building, which
# both read them). The east edge is deliberately modest (not 1e9): a huge value
# let a stray click strand a hall a mile out in the eastern void.
const SURFACE_WEST_FALLBACK_X := 4700.0
const SURFACE_EAST_FALLBACK_X := 30000.0
const BUILD_INSIDE_MARGIN := 160.0          # breathing room just inside a rampart
# The PLANT/relocate path keeps a far looser east fallback than the build menu:
# with no east rampart standing (it's shut until Orin is freed) you may walk a
# packed building well out east and set it down on open ground. This sentinel is
# the "no east wall = no east cap yet" marker, and test_construction mirrors it
# exactly -- so the two must stay equal. (The build menu deliberately caps tighter
# at SURFACE_EAST_FALLBACK_X so a stray CLICK can't fling a hall into the void.)
const PLANT_EAST_NO_WALL_X := 999999.0
# A WALL *defines* the perimeter, so it isn't bound by "inside the ramparts" --
# it may stand anywhere on the real surface band (west road through a built-out
# eastern town), only clear of the buildings.
const WALL_BAND_WEST_X := 2000.0
const WALL_BAND_EAST_X := 30000.0

# Can a building `bwidth` wide stand centred at x? INSIDE the ramparts and clear
# of every other structure -- the same rule the old relocate plant used, so a
# built building can never overlap another. (The village IS the surface, so a
# spot here is always "on the ground, not underground".)
func can_place_building(tree: SceneTree, bwidth: float, x: float, exclude: Node = null, is_wall: bool = false) -> bool:
	# A WALL *defines* the perimeter, so it is not bound by "inside the ramparts"
	# (with the walls gone at the start, that boundary doesn't even exist yet -- the
	# first rampart could never be placed, dev bug 2026-07-23). A wall may stand
	# anywhere along the village surface, only clear of the buildings. Everything
	# else must sit INSIDE the ramparts.
	if not is_wall:
		var west_x := SURFACE_WEST_FALLBACK_X
		# with no east rampart standing, halls are still bound to the same sane
		# surface band walls use (SURFACE_EAST_FALLBACK_X, not 1e9, or a stray click
		# could strand a hall a mile out in the eastern void -- dev sweep 2026-07-23)
		var east_x := SURFACE_EAST_FALLBACK_X
		for w in tree.get_nodes_in_group("village_wall"):
			if "flank" in w and w.flank == "east":
				east_x = w.global_position.x
			else:
				west_x = w.global_position.x
		if x < west_x + BUILD_INSIDE_MARGIN or x > east_x - BUILD_INSIDE_MARGIN:
			return false
	else:
		# a sane surface band (west road through the full eastern village + its
		# cottages, which a built-out town can stretch well past x=14000) so a wall
		# can't be dropped a mile out in the void, but any real gate is reachable
		if x < WALL_BAND_WEST_X or x > WALL_BAND_EAST_X:
			return false
	var my_half: float = bwidth / 2.0
	for other in tree.get_nodes_in_group("building"):
		if other == exclude or not ("width" in other):
			continue
		if absf(x - other.global_position.x) < my_half + float(other.width) / 2.0 + RELOCATE_CLEARANCE:
			return false
	return true

# --- THE OPENING TUTORIAL (step-gated, dev polish 2026-07-22) ---
# After the oath, the trio's words become a CHECKLIST: raise a wall, then a farm,
# then a home -- each build ticks the current step and points at the next. Starts
# when the opening ends (tutorial_begin), per-lifetime, skipped in dev_mode.
# The interactive tutorial (dev 2026-07-22: "show, don't tell"). tutorial_overlay.gd
# turns each of these into a live, do-it-now card -- name the building + why, then
# prompt the exact action (open the ledger, then pick + place). `done` is the brief
# confirm shouted when it goes up; the closing (below) tells the rest, after doing.
const TUTORIAL_STEPS := [
	{"want": "Wall", "done": "✓ A rampart rises — that's the whole of building: [B] · pick · place on GREEN."},
	{"want": "Farm", "done": "✓ A farm — the village will eat now."},
	{"want": "Cottage", "done": "✓ A home stands, ready for someone you save."},
]
var tutorial_step: int = -1     # -1 = inactive/done; 0..N = the step you're on

func tutorial_begin() -> void:
	if tutorial_step != -1 or dev_mode:
		return
	# the cinematic opening is over the moment building becomes the task: the HUD
	# and the "what now" ticker come up now, not on the game's first frame.
	opening_done = true
	tutorial_step = 0
	# the on-screen card (tutorial_overlay.gd) carries the live instructions now --
	# no toast needed to start, it appears the moment the step goes non-negative

# Called when a building is raised. If it's what the current step wants, tick it
# and point at the next -- or close the tutorial on the last.
func tutorial_note(building_name: String) -> void:
	if tutorial_step < 0 or tutorial_step >= TUTORIAL_STEPS.size():
		return
	if building_name != str(TUTORIAL_STEPS[tutorial_step]["want"]):
		return
	# shout the brief confirm for the building that just went up (the card already
	# shows the NEXT one, so the toast is a reward, not another instruction)
	notify(str(TUTORIAL_STEPS[tutorial_step].get("done", "✓ Raised.")))
	tutorial_step += 1
	if tutorial_step >= TUTORIAL_STEPS.size():
		tutorial_step = -1
		# NOW the tells, after the doing: what gates building, and the whole point.
		notify("You only raise what you hold the PLANS for — the rest lie scattered in the deep, one to a floor. Press [E] at any building to run it, [L] for the village log.")
		notify("That's the way of it. Now — find a door in the deep and go DOWN, and bring our frozen people home. That is how Deepwood lives again.")

# --- THE RAMPART (dev ask 2026-07-22: "make WALLS bigger... with gate,
# upgradable... in the beginning it's gotta be weak of course"). One shared tier
# drives BOTH ramparts (the west gatehouse the wild road breaks against and the
# east wall over the cottages). A tier is a wall you can SEE grow, that soaks a
# heavier wave (more HP), that fights back on its own (spiked/oil TRAPS damage
# besiegers pressed against its face), and that HOLDS more defenders (station
# slots). Tier 1 is a weak palisade; tier 4 is a fortress.
var wall_level: int = 1
const WALL_MAX_LEVEL := 4
# 1-indexed by tier; index 0 is unused padding so wall_level maps straight in.
const WALL_HP_BY_LEVEL       := [0, 350, 650, 1050, 1600]  # weak start -> fortress
const WALL_DEFENSE_BY_LEVEL  := [0, 0.0, 1.5, 3.0, 5.0]    # the wall's own worth vs a wave
const WALL_TRAP_DPS_BY_LEVEL := [0, 0.0, 8.0, 16.0, 28.0]  # traps bleed besiegers at the face
const WALL_SLOTS_BY_LEVEL    := [0, 2, 4, 6, 9]            # adventurers postable ON the wall
# Cost to reach the NEXT tier (index = the tier you're LEAVING). All inventory ids.
const WALL_UPGRADE_COST := [
	{},                                                    # 0 unused
	{"coin_gold": 120, "stone": 20, "iron_shard": 4},      # 1 -> 2
	{"coin_gold": 320, "stone": 45, "iron_shard": 10},     # 2 -> 3
	{"coin_gold": 700, "stone": 80, "iron_shard": 20},     # 3 -> 4
]

func wall_max_health() -> int:
	var base: int = WALL_HP_BY_LEVEL[clampi(wall_level, 1, WALL_MAX_LEVEL)]
	# Brannoc, the Wall That Stood (the Ten), still stacks half again on top
	if ten_freed("ten_brannoc"):
		base = int(base * 1.5)
	return base

func wall_defense_bonus() -> float:
	return WALL_DEFENSE_BY_LEVEL[clampi(wall_level, 1, WALL_MAX_LEVEL)]

func wall_trap_dps() -> float:
	return WALL_TRAP_DPS_BY_LEVEL[clampi(wall_level, 1, WALL_MAX_LEVEL)]

func wall_station_capacity() -> int:
	return WALL_SLOTS_BY_LEVEL[clampi(wall_level, 1, WALL_MAX_LEVEL)]

# The gold+materials to raise the wall one tier, or {} when already maxed.
func wall_upgrade_cost() -> Dictionary:
	if wall_level >= WALL_MAX_LEVEL:
		return {}
	return WALL_UPGRADE_COST[wall_level]

func can_afford_wall_upgrade(player: Node) -> bool:
	var cost := wall_upgrade_cost()
	if cost.is_empty() or player == null or not ("inventory" in player) or player.inventory == null:
		return false
	for k in cost.keys():
		if player.inventory.get_count(k) < int(cost[k]):
			return false
	return true

# Pay + raise the tier one step, then refresh any live wall node so the change is
# immediate (taller, tougher, better-manned). Returns true on success.
func try_upgrade_wall(player: Node) -> bool:
	if wall_level >= WALL_MAX_LEVEL:
		return false
	# no reinforcing mid-battle: refresh_from_level() full-heals and un-breaches
	# EVERY rampart, so a mid-siege upgrade was a free full repair of the breached
	# wall you weren't even paying toward. Repairs come from repelling the wave.
	if live_siege_active:
		return false
	if not can_afford_wall_upgrade(player):
		return false
	var cost := wall_upgrade_cost()
	for k in cost.keys():
		player.inventory.remove_item(k, int(cost[k]))
	wall_level += 1
	log_event("village", "The rampart was raised to tier %d — taller, tougher, and better manned." % wall_level)
	for w in get_tree().get_nodes_in_group("village_wall"):
		if w.has_method("refresh_from_level"):
			w.refresh_from_level()
	return true

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

# A session-monotonic sequence behind every generated pregnancy/child id. Births
# that resolve in the SAME frame -- a dev time-skip completing several
# pregnancies at once, or multiple cottages departing together -- share
# Time.get_ticks_msec() to the millisecond, so a bare timestamp+random id could
# collide and silently overwrite one soul in the roster dict. The sequence makes
# ids unique WITHIN a run no matter the frame; the timestamp keeps them unique
# across runs. Not saved: it only has to be monotonic while the session lives.
var _birth_seq: int = 0
func _mint_birth_id(prefix: String) -> String:
	_birth_seq += 1
	return "%s_%d_%d_%d" % [prefix, Time.get_ticks_msec(), _birth_seq, randi() % 100000]

# --- THE VILLAGE LOG (GAME_BIBLE 5.9) ---
# The village's diary, opened with L: a timestamped journal of everything
# that mattered -- much of it while the player was down in the dark. Plain
# language ("Milo and Elin had a child", never a system code), newest
# first, only things worth surfacing. It reads like the town wrote it.
const LOG_MAX_ENTRIES := 120
var village_log: Array = []   # {"day", "hour", "cat", "text"}, newest first
# Entries written while the player could NOT see the village (the fog).
# The homecoming reports the count -- otherwise a player returns from a
# delve with no idea anything happened and never thinks to press L.
# With Telepathy nothing accumulates: you watched it all live.
var log_unread := 0

func log_event(cat: String, text: String) -> void:
	village_log.push_front({
		"day": int(game_hours / 24.0) + 1,
		"hour": int(game_hours) % 24,
		"cat": cat, "text": text,
	})
	if not village_info_available():
		log_unread += 1
	if village_log.size() > LOG_MAX_ENTRIES:
		village_log.resize(LOG_MAX_ENTRIES)

# --- HOUSING (GAME_BIBLE 5.8) ---
# The cradle IS the home: the cottage a pair unites in becomes THEIRS for
# life -- only death parts a pair or frees their cottage. Housing is the
# hard brake on the population flywheel: you cannot out-rescue or out-breed
# the cottages you raise. The Tavern lodges the unhoused, warm but not home.
const WIDOW_MOURN_HOURS := 48.0     # canon: re-pairable only after the mourning
const SINGLE_MORALE_PENALTY := 2.0  # canon: a lonely adult carries -2, standing
# MATING-DEPRESSION (GAME_BIBLE 7): loneliness is not flat -- an adult who stays
# single SADDENS the longer they go unpaired. The -2 standing penalty deepens
# toward MAX over DEEPEN_HOURS of solitude, then pairing lifts it entirely. The
# clock (single_since_hours) is stamped/cleared in tick_personal_morale and
# rides along in each villager's dict, so it saves with the game for free.
const SINGLE_MORALE_PENALTY_MAX := 3.5   # the depth of long, unbroken solitude
const SINGLE_DEEPEN_HOURS := 120.0       # ~5 in-game days single to reach the floor
# The floor a FED soul never falls below (3b): well clear of the morale-0 rot
# trigger, so a poor-but-fed village is miserable, not dying. Starvation lifts it.
const ROT_SAFE_FLOOR := 1.5
const WIDOW_MORALE_HIT := 3.0       # canon: -3, decaying back over the mourning
var cottage_homes: Dictionary = {}  # house_id -> {"a": id, "b": id}, permanent
var extra_cottages: int = 0         # cottages RAISED beyond the starting row (5.8: built, not free)
# Freeform ground the player chose for menu-built cottages (build menu 2026-07-22).
# Index j lines up with the j-th extra cottage; a cottage without a stored spot
# falls back to the old end-of-row slot. Persisted so a placed home stays put.
var extra_cottage_positions: Array = []
# STABLE per-cottage ids, in lockstep with extra_cottage_positions (index j -> the
# j-th cottage's id). cottage_homes/mating_houses are keyed by these, so the id must
# NOT be the array index: deleting a middle cottage used to shift the index-derived
# ids ("menu_house_%d" % j) and orphan a settled couple's home on reload (and collide
# the next build with a surviving cottage). A monotonic seq gives each cottage an id
# that never moves or repeats, so a home always resolves to its real cottage. (dev
# 2026-07-23 cottage-reindex desync — see [[deepwood_build_menu]].)
var extra_cottage_ids: Array = []
var cottage_id_seq: int = 0
# Ramparts the player has BUILT from the menu (walls start removed now — dev
# 2026-07-22 "build them in the tutorial"). Each is {"x": float, "flank": String};
# main.gd re-raises them on every scene build, so a built wall stays where it was.
var placed_walls: Array = []

func villager_name(vid: String) -> String:
	for v in rescued_villagers:
		if str(v.get("id", "")) == vid:
			return str(v.get("name", "someone"))
	return "someone"

func villager_home_id(vid: String) -> String:
	for hid in cottage_homes:
		var h: Dictionary = cottage_homes[hid]
		if str(h.get("a", "")) == vid or str(h.get("b", "")) == vid:
			return str(hid)
	return ""

# A child sleeps under its parents' roof (5.8) -- housed if either parent is.
# Legacy children from before parent-tracking count as housed (kind default).
func kid_is_housed(v: Dictionary) -> bool:
	if not v.has("parents"):
		return true
	for pid in v.get("parents", []):
		if villager_home_id(str(pid)) != "":
			return true
	return false

# Housed couples keep the cradle full on their own -- the flywheel (5.7 B)
# whose brake is the cottage count itself. A starving or despairing village
# does not conceive.
const FAMILY_CYCLE_HOURS := 60.0
var _family_cycle_accum := 0.0

func _couple_expecting(a: String, b: String) -> bool:
	for p in pregnancies.values():
		if p.get("male_id", "") in [a, b] or p.get("female_id", "") in [a, b]:
			return true
	return false

func update_cottage_families(hours_passed: float) -> void:
	_family_cycle_accum += hours_passed
	if _family_cycle_accum < FAMILY_CYCLE_HOURS:
		return
	_family_cycle_accum = 0.0
	if not has_food() or village_in_despair():
		return
	var candidates := []
	for hid in cottage_homes:
		var h: Dictionary = cottage_homes[hid]
		var a := str(h.get("a", ""))
		var b := str(h.get("b", ""))
		if villager_name(a) == "someone" or villager_name(b) == "someone":
			continue
		if _couple_expecting(a, b):
			continue
		candidates.append(h)
	if candidates.is_empty():
		return
	var pick: Dictionary = candidates[randi() % candidates.size()]
	var pregnancy_id = _mint_birth_id("preg")
	pregnancies[pregnancy_id] = {"male_id": pick.get("a", ""), "female_id": pick.get("b", ""), "remaining_hours": GESTATION_DURATION_HOURS}

# Active School/Barracks enrollments, keyed by villager_id:
# {"remaining_hours", "grants_stat"}. grants_stat is either "random" (School
# picks one of REGULAR_STATS) or a specific stat name (Barracks always
# grants "Warrior"). 24 in-game HOURS, same clock as mating pairings.
const EDUCATION_DURATION_HOURS = 24.0
# The 8 "regular" professions a School graduate can come out with.
# Leadership titles (Leader/Principal/Warchief) are deliberately never
# taught here -- see building_roles.gd for why.
const REGULAR_STATS = ["Farm", "Hospital", "Fishing", "Scientist", "Financist", "Blacksmith", "Tavern", "Marketplace", "Mine"]
# THE ROLE ROLL (GAME_BIBLE 5.4, revised canon): a graduate does not pick --
# they ROLL from a table weighted INVERSE to the role's value. Anyone can
# tend a field or pour a drink; a banker, a scholar, a surgeon is a rare
# mind. Scarcity is what makes the rare roles feel rare and keeps rescued
# VIPs precious -- to staff the Bank you breed, school, and pray.
# (School weight-tuning -- hand-adjusting this table as a mid-game payoff --
# is 12.9-open and NOT built; the default table below is the whole game.)
const ROLE_ROLL_WEIGHTS = {
	"Farm": 25, "Fishing": 20, "Tavern": 20,        # food & fun: common hands
	"Blacksmith": 8, "Marketplace": 8, "Mine": 8,    # skilled trades: uncommon
	"Hospital": 7, "Scientist": 6, "Financist": 6,   # rare minds
}

# FAVOUR-A-CALLING (5.4 weight-tuning, decided delegated): from School
# level 2, the player may favour ONE calling; its weight runs at
# x(1 + 0.5 per level above 1), hard-capped at 40% of the whole table.
# Never 100% -- the dice never fully leave, the player only leans on them.
const FAVOUR_SHARE_CAP := 0.4
var school_favoured_stat := ""

func effective_roll_weights() -> Dictionary:
	var weights := {}
	var total := 0.0
	for stat_name in ROLE_ROLL_WEIGHTS:
		weights[stat_name] = float(ROLE_ROLL_WEIGHTS[stat_name])
		total += weights[stat_name]
	var lvl := building_level("School")
	if school_favoured_stat != "" and weights.has(school_favoured_stat) and lvl >= 2:
		var base: float = weights[school_favoured_stat]
		var boosted: float = base * (1.0 + 0.5 * float(lvl - 1))
		# cap: the favoured share may never exceed 40% of the (new) table
		var cap_value: float = FAVOUR_SHARE_CAP * (total - base) / (1.0 - FAVOUR_SHARE_CAP)
		weights[school_favoured_stat] = minf(boosted, cap_value)
	return weights

func roll_regular_stat() -> String:
	var weights := effective_roll_weights()
	var total := 0.0
	for w in weights.values():
		total += float(w)
	var pick := randf() * total
	for stat_name in weights:
		pick -= float(weights[stat_name])
		if pick < 0.0:
			return stat_name
	return "Farm"
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
	# the quiet insurance: a crash should cost minutes, never a session
	_autosave_accum += delta
	if _autosave_accum >= AUTOSAVE_INTERVAL_SECONDS:
		autosave()
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
	update_cottage_families(hours_passed)
	update_school_enrollments(hours_passed)
	decay_doctor_price(hours_passed)
	tick_deep_catches(hours_passed)
	tick_wages(hours_passed)
	tick_wanderers(hours_passed)
	tick_watchtower_warning()
	tick_mine_yield(hours_passed)
	tick_self_sufficiency()   # celebrate each chore the moment it starts running itself
	tick_village_peril()      # escalating dread as the hearth empties (pierces the fog)
	tick_black_tide_omen()    # the fog-piercing warning of a coming Black Tide
	if hours_passed > 0.0:
		# grief heals with time -- the forgiving half of the death-shock system
		morale_death_shock = maxf(0.0, morale_death_shock - hours_passed * DEATH_SHOCK_DECAY_PER_HOUR * (2.0 if ten_freed("ten_seraphel") else 1.0))
		tick_food(hours_passed)          # eat/produce first, so hunger drain sees fresh state
		tick_morale_effects(hours_passed)
		tick_village_tribute(hours_passed)
		tick_sieges(hours_passed)

# --- Siege scheduling + resolution (runs in every scene) ---

func current_siege_tier() -> int:
	# 7.6, numbers pass (2026-07-20, balance sim): PROSPERITY x DEPTH, never
	# the calendar. The old clock-only tier (+1 per day, unbounded) was a
	# guaranteed roster wipe by day 40 -- a player who took their time was
	# executed for it. Depth is the main screw (you brought this on the
	# village by digging); a living town adds the prosperity surcharge.
	var depth_part: float = float(highest_unlocked_level) * 0.30
	var prosperity: float = float(rescued_villagers.size()) * 0.08 + float(village_morale()) * 0.02
	return maxi(1, int(round(1.0 + depth_part + prosperity)))

# Standing defense strength of the village right now (wizard + warriors).
# GAME_BIBLE 2.5.1: Orin enters the story only once the player has carved to
# ~floor 15. Before that he is the Doctor's rumour -- a wizard who went down
# and never came back. (--dev keeps him for the sandbox.)
const ORIN_ARRIVAL_DEPTH := 15
var seen_orin_arrival := false
var seen_doctor_account := false
var seen_failed_escape := false
var seen_orin_glimpse := false
var seen_kneel_echo := false
var seen_orin_taunt := false
var seen_arrival_battle := false
var seen_arrival_talk := false   # the wall-crossing reveal was DELIVERED (split from the battle flag 2026-07-21)
# THE OPENING IS CINEMATIC (dev 2026-07-22): from a new game's first frame the
# player should see only the chat, no HUD chrome and no "raise the Farm" ticker,
# until the interactive building tutorial begins (tutorial_begin flips this true).
# Old saves + dev_mode are already past the opening, so they read true.
var opening_done := false
var seen_gather_hint := false    # taught the axe/pickaxe once (transient; a swing at a tree/rock with a plain weapon triggers it)
# THE NEW FINALE (canon rework 2026-07-20): floor 100 is EMPTY. The false
# victory is carried home, the feast pumps the village to its peak, and Orin
# reveals himself AT THE FEAST -- the Harvest is fought in the village.
var seen_empty_throne := false     # the player has stood in the silent hall (saved)
var harvest_at_home := false       # the feast->reveal->fight sequence is LIVE (transient)
var feast_glow := false            # the false victory's joy (transient, morale reads 100)

# The feast (and Orin) fire only when the deep is TRULY empty: floors cleared
# AND every one of the Ten home. Nobody celebrates "the evil is defeated"
# while their brother still hangs frozen below -- and this guarantees the
# Soul Split Wand (gifted on the tenth rescue) is in hand for the only fight
# that needs it.
func deep_truly_empty() -> bool:
	return highest_unlocked_level >= 100 and all_ten_freed()

func feast_ready() -> bool:
	# NB gated on per-run despair_dead, NEVER on lifetime game_completed --
	# game_completed survives into NG+ forever, and the Rewound Hour's whole
	# promise is that the world (and its finale) happens AGAIN.
	return seen_empty_throne and deep_truly_empty() \
		and not harvest_done and not despair_dead \
		and not harvest_at_home and not dev_mode and not in_dungeon
# The opening wave is a TEACHING fight, not a trial: the three defenders
# are scripted to survive it (Roland in particular is canon at the gate of
# 100, §12.6). Transient -- never saved; a real siege can still take them.
var arrival_battle_active := false
var _arrival_shield_until := 0.0     # hard deadline, so it can never stick

# The shield must be impossible to leave ON: if the player walks into the
# dungeon mid-arrival, or a raider gets stuck and the wave never finishes,
# an un-expiring flag would make the corps IMMORTAL for the rest of the
# run. It dies on a timer, on entering the deep, and when the wave breaks.
func arrival_shield_on() -> bool:
	if not arrival_battle_active:
		return false
	if in_dungeon or Time.get_ticks_msec() / 1000.0 > _arrival_shield_until:
		arrival_battle_active = false
		return false
	return true

func begin_arrival_shield(seconds := 150.0) -> void:
	arrival_battle_active = true
	_arrival_shield_until = Time.get_ticks_msec() / 1000.0 + seconds
var escape_attempts := 0    # 12.7: the road out, tested -- each retry doubles the answer

func orin_arrived() -> bool:
	# Per-run: in a fresh world Orin has not "walked back out" yet, no matter
	# how deep some earlier life of this install once went.
	return dev_mode or highest_unlocked_level >= ORIN_ARRIVAL_DEPTH

func village_defense_power() -> float:
	# no Orin, no meteors: until he walks out of the dungeon the village's
	# nightly defense is the adventurers and whatever warriors it has raised
	var power = SIEGE_DEF_WIZARD if orin_arrived() else 0.0
	for v in rescued_villagers:
		if v.get("role_title", "") == "Recruit":
			continue   # still in training -- doesn't fight yet (matches warrior_count)
		if v.get("stat_name", "") == "Warrior" or v.get("role_key", "") == "Barracks":
			# 7.3: the on-shift holds the wall at full worth; the off-shift
			# scrambles from their bunks at half
			power += SIEGE_DEF_PER_WARRIOR * (1.0 if warrior_on_duty(v) else 0.5)
		# a barracks-forged HERO is a one-person garrison (and never sleeps
		# through a horn)
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
	# the RAMPART itself blunts the wave: a higher tier is taller stone with
	# traps set into it, worth real defense even before a body mans it
	power += wall_defense_bonus()
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

# --- DAY/NIGHT SHIFTS (GAME_BIBLE 7.3) ---
# The corps splits into two 12h shifts by a coin flip that never changes
# (the id's hash): DAWN mans the wall 6:00-18:00, DUSK holds the night.
# The off-shift sleeps -- and only a rested body heals (see the regen
# branch in tick_morale_effects). A siege landing within an hour of the
# changeover catches the wall HALF-manned: the deliberate weak window.
const SHIFT_CHANGE_HOURS = [6.0, 18.0]
const SHIFT_CHANGE_WINDOW := 1.0

func hour_of_day() -> float:
	# THE SHIFT CLOCK RIDES THE VISIBLE DAY: watches must change at the dawn/dusk
	# the player actually sees. time_of_day() folds in START_TIME_OF_DAY (=22);
	# the raw fmod(game_hours) used before ran the changeover ~2h early (displayed
	# 4:00 / 16:00), so the half-manned "weak window" and the off-shift heal gate
	# were out of step with visible night. (Used only by the shift helpers below.)
	return time_of_day()

func warrior_shift(vid: String) -> String:
	return "dawn" if hash(vid) % 2 == 0 else "dusk"

func on_duty_shift() -> String:
	var h := hour_of_day()
	return "dawn" if h >= 6.0 and h < 18.0 else "dusk"

func warrior_on_duty(v: Dictionary) -> bool:
	return warrior_shift(str(v.get("id", ""))) == on_duty_shift()

func on_duty_warrior_count() -> int:
	var n := 0
	for v in rescued_villagers:
		if v.get("role_title", "") == "Recruit":
			continue
		if (v.get("stat_name", "") == "Warrior" or v.get("role_key", "") == "Barracks") and warrior_on_duty(v):
			n += 1
	return n

func in_shift_change_window() -> bool:
	var h := hour_of_day()
	for c in SHIFT_CHANGE_HOURS:
		if absf(h - float(c)) <= SHIFT_CHANGE_WINDOW:
			return true
	return false

func tick_sieges(hours_passed: float) -> void:
	# The Shadow Court (GAME_BIBLE 11): the raids die with their master.
	if despair_dead:
		return
	# The Harvest is the finale's OWN battle, fought at home -- no ordinary raid
	# (and never a Black Tide) may spawn on top of the Monarch fight.
	if harvest_at_home:
		return
	# The siege clock does not even START until the opening is over (the prologue,
	# the arrival fight, the oath, and the build tutorial). A brand-new player is
	# never hit while still learning to raise the wall (dev 2026-07-23).
	# DEV MODE counts as open: the dev sandbox skips the tutorial entirely, so
	# tutorial_begin() never runs there and opening_done stays false -- without this
	# the gate silently disabled ALL sieges in --dev and the marathon sim ("0 lost
	# to siege" was an artifact, caught by the sim re-run 2026-07-23).
	if not opening_done and not dev_mode:
		return
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

# Is siege number n a Black Tide? Periodic + gated behind real depth, so a fresh
# town isn't hit by one before it can field defenders.
func is_black_tide_number(n: int) -> bool:
	return n > 0 and n % BLACK_TIDE_EVERY == 0 and highest_unlocked_level >= BLACK_TIDE_MIN_DEPTH

func next_siege_is_black_tide() -> bool:
	return is_black_tide_number(sieges_seen + 1)

# The dread of a coming Black Tide reaches you ANYWHERE (pierces the away-fog),
# far enough ahead to run home and post your defenders. One-shot per tide.
func tick_black_tide_omen() -> void:
	if despair_dead or live_siege_active or not next_siege_is_black_tide():
		_black_omen_armed = true
		return
	if hours_until_next_siege <= BLACK_TIDE_LEAD and _black_omen_armed:
		_black_omen_armed = false
		notify_urgent("🌑 A BLACK TIDE is rising — a wave the wall cannot hold alone. Station your adventurers and come home. ~%dh." % int(ceil(maxf(hours_until_next_siege, 0.0))))
		log_event("combat", "The horizon darkened — a Black Tide gathers against Deepwood.")
		play_sfx(SFX_THUD, 0.6)

func trigger_siege() -> void:
	if despair_dead:
		return
	sieges_seen += 1
	var black := is_black_tide_number(sieges_seen)
	var tier = current_siege_tier()
	# gentler until Orin is freed (dev 2026-07-22): the early game is not meant to
	# be hard, and every pre-Orin wave comes from ONE side (the dungeon/west) only
	if not orin_arrived():
		tier = maxi(1, int(round(float(tier) * 0.6)))
	if black:
		# far past the wall's own strength -- the defenders are the only answer
		tier = int(round(float(tier) * BLACK_TIDE_TIER_MULT)) + 2
		notify_urgent("🌑 THE BLACK TIDE BREAKS on Deepwood — tier %d! Only your stationed defenders can turn it." % tier)
		log_event("combat", "A Black Tide crashed against the wall — a wave the town could never hold alone.")
	if not in_dungeon:
		var mgr = get_tree().get_first_node_in_group("siege_manager")
		if mgr and mgr.has_method("start_live_siege"):
			mgr.start_live_siege(tier, black)
			live_siege_active = true
			return
	resolve_siege_offline(tier)

# Kaldos, the Tidecaller (the Ten): the Dock's deep-catches haul MATERIALS as
# well as food -- one basic material per in-game day per staffed dock, dropped
# into the player's bag. (The dock has no food loop of its own yet, so this is
# the boon's material half wired to the real hook that exists.)
var _deep_catch_accum := 0.0
const DEEP_CATCH_MATERIALS = ["iron_shard", "slime", "resin"]

func tick_deep_catches(hours_passed: float) -> void:
	if not ten_freed("ten_kaldos"):
		return
	var dock_hands := 0
	for v in rescued_villagers:
		if str(v.get("role_key", "")) == "Fishing Dock":
			dock_hands += 1
	if dock_hands == 0:
		return
	_deep_catch_accum += hours_passed
	while _deep_catch_accum >= 24.0:
		_deep_catch_accum -= 24.0
		var player = get_tree().get_first_node_in_group("player")
		if player and "inventory" in player and player.inventory:
			player.inventory.add_item(DEEP_CATCH_MATERIALS[randi() % DEEP_CATCH_MATERIALS.size()], 1)

# Abstract off-screen resolution used while the player is away.
var maera_stabilized_this_siege := false

func resolve_siege_offline(tier: int) -> void:
	away_report.sieges += 1
	maera_stabilized_this_siege = false
	if village_defense_power() >= float(tier):
		away_report.repelled += 1
		log_event("combat", "A tier-%d siege struck while you were away — the defense held. Nobody was lost." % tier)
		return
	log_event("combat", "A tier-%d siege struck while you were away — the wall could not hold it all." % tier)
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
			# a permadeath deserves a NAME in the report, not a tally mark
			if not away_report.has("fallen_names"):
				away_report["fallen_names"] = []
			var fallen_name := str(Adventurers.get_def(shield_id).get("name", "an adventurer"))
			away_report["fallen_names"].append(fallen_name)
			log_event("combat", "%s fell holding the line. They will not re-enlist." % fallen_name)
			continue
		# Maera, the Last Lightmender (the Ten): once per siege she pulls someone
		# back from the brink -- one villager who would have died, does not
		if ten_freed("ten_maera") and not maera_stabilized_this_siege:
			maera_stabilized_this_siege = true
			away_report["stabilized"] = int(away_report.get("stabilized", 0)) + 1
			log_event("combat", "Maera pulled someone back from the brink — one villager who should have died, did not.")
			continue
		if rescued_villagers.is_empty():
			break
		# HONEST bookkeeping (dev sweep 2026-07-23): with only unbreakables (the Ten)
		# left, remove_random_villager() takes nobody -- so count a loss ONLY when
		# someone was actually taken, and stop rolling casualties that can't land.
		if not remove_random_villager():
			break
		away_report.villagers_lost += 1

# Called by the live SiegeManager when a village battle is fully repelled.
func on_live_siege_ended() -> void:
	live_siege_active = false
	hours_until_next_siege = SIEGE_INTERVAL_HOURS
	log_event("combat", "The wave broke against the wall — Deepwood held.")
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
const FOOD_PER_FISHER_PER_DAY := 4.0        # the sea never has a bad harvest, but feeds fewer per hand
const FOOD_DAYS_CAP := 5.0                   # the larder holds at most this many days of food
# ^ 5, not 4: the opening larder IS this cap (village_food starts at food_capacity),
# so a fresh 3-soul town with nobody working must survive PAST 5 untouched days
# before hunger takes anyone (a new player's learning runway, per the balance sim's
# S1). A 4-day larder + the ~1-day morale-crash cascade landed the first loss at
# exactly day 5 -- a hair short. One more day of pantry gives the intended grace.
const FOOD_MANUAL_HARVEST_YIELD := 4.0       # food produced by one hand-harvest action
const FOOD_STARVE_GRACE_HOURS := 30.0        # empty larder must persist this long before HP drains
const FOOD_STARVE_HP_DRAIN_PER_HOUR := 5.0   # then hunger eats HP (x _despair_rate, staggered)

var village_food := 0.0                      # current stockpile (villager-days)
var food_empty_hours := 0.0                  # how long the stockpile has sat empty

# Edge-latches so danger toasts fire ONCE on crossing into trouble, not every
# tick. Each re-arms when the situation clears (with hysteresis for morale).
var _warned_no_food := false
var _warned_low_morale := false

# How much food the town can hold -- scales with the REAL population so a bigger
# village needs a bigger buffer (and more farmers to keep it full). The floor was
# 6 phantom mouths, which gave an EMPTY honest village a static 24-food larder that
# never moved (dev 2026-07-23: "food is too high and never ends"). A small min of 3
# just avoids a literal-empty larder the instant your first villager arrives.
func food_capacity() -> float:
	return FOOD_DAYS_CAP * maxf(float(rescued_villagers.size()), 3.0)

# The town is "fed" as long as there is any food in store.
func has_food() -> bool:
	return village_food > 0.0

# The living eat: total food burned per in-game hour. Shadow-court villagers
# (11) hunger for nothing, so they never draw on the larder.
func food_consumption_per_hour() -> float:
	var eaters := 0
	for v in rescued_villagers:
		if not v.get("shadow", false):
			eaters += 1
	return float(eaters) * FOOD_PER_VILLAGER_PER_DAY / 24.0

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
	var farm := float(farm_worker_count()) * FOOD_PER_FARMER_PER_DAY / 24.0 * (1.0 + HARVESTMASTER_FOOD_BONUS * seated_leaders("Farm")) * (2.0 if ten_freed("ten_sylvara") else 1.0)
	# The Fishing Dock is the economy's PREMIUM food source (its fish feed
	# fewer mouths per worker than the Farm's grain, but the sea never has a
	# bad harvest). This also makes Kaldos' boon honest end to end: the Dock
	# genuinely yields food, and with the Tidecaller freed, materials as well.
	var dock := float(dock_worker_count()) * FOOD_PER_FISHER_PER_DAY / 24.0 * (1.0 + HARVESTMASTER_FOOD_BONUS * seated_leaders("Fishing Dock"))
	return farm + dock

func dock_worker_count() -> int:
	if not is_building_operational("Fishing Dock"):
		return 0
	var n := 0
	for v in rescued_villagers:
		if str(v.get("role_key", "")) == "Fishing Dock" and str(v.get("role_title", "")) == "Fisherman":
			n += 1
	return n

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
# --- THE VILLAGE FOG (dev decision 2026-07-20): distance is ignorance ---
# Away from home the player learns NOTHING of the village -- no meter, no
# toasts, no diary. Its life still writes itself to the Log; coming home
# and reading it is how you find out what your absence cost. TELEPATHY
# (Mage, mg_t1, mid-game) is the answer: the whole village channel --
# meter, diary, every cry, even the Watchtower's bell -- reaches you
# anywhere, including the deep.
const VILLAGE_PRESENCE_X := 4300.0    # just west of the gatehouse road

func has_telepathy() -> bool:
	return get_bonus_total("telepathy") > 0.0

# THE WHISPERSTONE (dev ask 2026-07-22): the non-mage's answer to the fog. A
# scrying/comm device built ONCE at a working Science Lab -- after that the
# village's whole channel (toasts + the Log's live feed) reaches you anywhere,
# exactly like Telepathy. Without it, and without the rune, you learn nothing
# away from home but what the villagers tell you when you get back.
const WHISPERSTONE_COST := {"iron_shard": 8, "ember_crystal": 2}
var has_whisperstone := false

func has_communicator() -> bool:
	return has_whisperstone

# Craft the Whisperstone at the Lab. Returns "" on success, else the reason.
func try_build_whisperstone(player: Node) -> String:
	if has_whisperstone:
		return "The Whisperstone already hums on the Lab bench."
	if not is_building_operational("Science Lab"):
		return "The Whisperstone can only be made at a working Science Lab."
	if count_workers("Science Lab") == 0 and seated_leaders("Science Lab") == 0:
		return "The bench sits cold — staff a Scientist first."
	if player == null or not ("inventory" in player) or player.inventory == null:
		return "No hands to build it."
	for mid in WHISPERSTONE_COST:
		if player.inventory.get_count(mid) < int(WHISPERSTONE_COST[mid]):
			return "The Whisperstone needs %s." % _cost_text(WHISPERSTONE_COST)
	for mid in WHISPERSTONE_COST:
		player.inventory.remove_item(mid, int(WHISPERSTONE_COST[mid]))
	has_whisperstone = true
	log_event("village", "The Lab's Whisperstone woke with a low hum — Deepwood can reach you now, wherever you roam.")
	play_sfx(SFX_CHIME, 1.2)
	return ""

func _cost_text(cost: Dictionary) -> String:
	var parts := []
	for mid in cost:
		parts.append("%dx %s" % [int(cost[mid]), Inventory.get_display_name(mid)])
	return ", ".join(parts)

func village_presence() -> bool:
	if dev_mode:
		return true
	if in_dungeon:
		return false
	var pl = get_tree().get_first_node_in_group("player")
	return pl != null and pl.global_position.x > VILLAGE_PRESENCE_X

func village_info_available() -> bool:
	return village_presence() or has_telepathy() or has_communicator()

# The VILLAGE channel: every toast about the town's life flows through
# here, and the fog gates it. (Player-personal messages use the stack
# directly and are never gated.)
func notify(text: String) -> void:
	if not village_info_available():
		return
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
	# 5.8: pairing is durable -- the partner link outlives the mating session
	# and every birth; only death clears it (see remove_villager_by_id).
	for v in rescued_villagers:
		if str(v.get("id", "")) == vid:
			if str(v.get("partner_id", "")) != "":
				return true
			break
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

# --- PERSONAL MORALE (GAME_BIBLE 5.5b) ---
# Two layers, the same numbers seen at two scales: every villager carries
# their OWN morale 0-10 -- their needs move their number, and personal 0 is
# what corrupts or kills THAT villager (10) -- while the village meter is
# nothing but the plain average of everyone's personal value. A serene
# average can hide two people in the red: the meter is for the shop and the
# finale gate; the danger is always local.
#
# Weights are tuned so a perfect ADULT (fed, employed, paired, armed town,
# open bar, full streets) sits at exactly 10.0 with no boons -- so the
# gate's "average of 10" still demands EVERY villager perfect. Boons (Ilo,
# seated hosts) are slack on top, clamped like everything else.
const MORALE_DRIFT_PER_HOUR := 0.6   # spirits move toward their target on hour-scale

func personal_morale_target(v: Dictionary) -> float:
	# THE SHADOW COURT (11): a raised villager is fully pledged to the Monarch,
	# and needless with it -- no hunger, no rot, no want of work, home, love or
	# fun. Their spirit is simply fixed at the top, forever.
	if v.get("shadow", false):
		return 10.0
	var vid := str(v.get("id", ""))
	var t := 1.4                                                 # being alive, and free
	t += 2.0 if has_food() else 0.0                              # a full larder
	if v.get("is_kid", false):
		t += 3.8                                                 # a child's world: home, play, school
		# a child sleeps where its parents do (5.8)
		if not kid_is_housed(v):
			t -= 0.5 if is_building_operational("Tavern") else 1.5
	else:
		t += 2.2 if str(v.get("role_key", "")) != "" else 0.0    # purpose
		# 5.8 housing: a cottage of your own 1.6; the Tavern's spare bed 0.8;
		# the street costs you
		if villager_home_id(vid) != "":
			t += 1.6
		elif is_building_operational("Tavern"):
			t += 0.8
		else:
			t -= 1.0
		# 5.8: loneliness is a STANDING penalty, not a missing bonus -- and a
		# fresh widow carries the -3 on top, easing off across the mourning.
		# MATING-DEPRESSION (7): the standing -2 DEEPENS toward MAX the longer
		# they stay single (single_since_hours, stamped in tick). Pure read here:
		# unstamped -> depth 0 -> the plain -2, so this is safe before any tick.
		if not is_villager_paired(vid):
			var single_since := float(v.get("single_since_hours", game_hours))
			var depth := clampf((game_hours - single_since) / SINGLE_DEEPEN_HOURS, 0.0, 1.0)
			t -= lerpf(SINGLE_MORALE_PENALTY, SINGLE_MORALE_PENALTY_MAX, depth)
		if v.has("widowed_at_hours"):
			var mourn_left: float = float(v["widowed_at_hours"]) + WIDOW_MOURN_HOURS - game_hours
			if mourn_left > 0.0:
				t -= WIDOW_MORALE_HIT * (mourn_left / WIDOW_MOURN_HOURS)
	t += 1.4 if is_building_operational("Blacksmith") else 0.0   # an armed town sleeps better
	t += 1.0 if is_building_operational("Bar") else 0.0          # somewhere to laugh
	# the Dock's PREMIUM food (5.7): fish on the table lifts every spirit --
	# the quality-food edge, slack on top like the boons (never gate-required)
	if has_food() and is_building_operational("Fishing Dock") and count_workers("Fishing Dock") > 0:
		t += 0.3
	t += 0.4 * clampf(float(rescued_villagers.size()) / MORALE_POP_TARGET, 0.0, 1.0)
	t += (LEADER_MORALE_EACH / 10.0) * (seated_leaders("Tavern") + seated_leaders("Bar"))
	# Ilo, the Nameless Bard (the Ten): his songs lift the whole village
	if ten_freed("ten_ilo"):
		t += 1.0
	t -= morale_death_shock / 10.0                               # the town's grief weighs on everyone
	# 3b tuning (2026-07-22): a FED, free soul holds a dim ember -- miserable, yes
	# (low income, no births, complaints, maybe below the despair line), but
	# poverty ALONE never rots them to death. Only an EMPTY larder lifts this
	# floor, so corruption is the price of real crisis (starvation), not the
	# default state of a fresh, unbuilt village. Before this, a new town of
	# homeless jobless souls sat at ~0.5 and collapsed to demons in ~5 real min.
	if has_food():
		t = maxf(t, ROT_SAFE_FLOOR)
	return clampf(t, 0.0, 10.0)

# Seeded at target on first touch (a new villager, or a villager from an
# old save that predates the personal layer) -- additive, never a migration.
func get_personal_morale(v: Dictionary) -> float:
	if not v.has("morale"):
		v["morale"] = personal_morale_target(v)
	return float(v["morale"])

func tick_personal_morale(hours_passed: float) -> void:
	for v in rescued_villagers:
		_tick_solitude_clock(v)
		var cur := get_personal_morale(v)
		var target := personal_morale_target(v)
		var step: float = MORALE_DRIFT_PER_HOUR * hours_passed
		v["morale"] = clampf(cur + clampf(target - cur, -step, step), 0.0, 10.0)

# MATING-DEPRESSION bookkeeping: an adult who is unpaired starts a solitude
# clock the first hour they're seen single; pairing (or childhood) clears it,
# so their loneliness resets and a later break-up starts the sadness fresh.
# A widow's clock only starts once mourning ends -- they're barred from re-
# pairing until then, so it would be unfair to deepen their loneliness meanwhile.
func _tick_solitude_clock(v: Dictionary) -> void:
	if v.get("is_kid", false) or is_villager_paired(str(v.get("id", ""))):
		v.erase("single_since_hours")
		return
	if v.has("single_since_hours"):
		return
	var start: float = game_hours
	if v.has("widowed_at_hours"):
		var mourn_end: float = float(v["widowed_at_hours"]) + WIDOW_MOURN_HOURS
		if mourn_end > start:
			start = mourn_end
	v["single_since_hours"] = start

# The meter: the plain average of every personal value, on the 0-100 scale
# the HUD/shop/gate already speak. Nothing separate -- just the mean.
func village_morale() -> int:
	# the false victory (new finale): for one evening, hope is COMPLETE
	if feast_glow:
		return 100
	if rescued_villagers.is_empty():
		return 0
	var total := 0.0
	for v in rescued_villagers:
		total += get_personal_morale(v)
	var avg100 := total / float(rescued_villagers.size()) * 10.0
	# morale_admin_offset is a dev-panel nudge (0 in normal play)
	return clampi(int(round(avg100)) + morale_admin_offset, 0, 100)

# Dev/admin panel nudge to morale, in tenths (+1 == +1.0 on the 0-10 meter).
func admin_nudge_morale(tenths: int) -> void:
	morale_admin_offset = clampi(morale_admin_offset + tenths * 10, -100, 100)

# The player-facing 0-10 reading.
func village_morale_10() -> float:
	return float(village_morale()) / 10.0

# Villagers killed (siege waves, the death penalty) pile onto the death shock;
# new villagers (births, spawned troops) repay it. Both are clamped so a wipe
# can't bottom morale out instantly and over-healing can't push shock negative.
# 10, decided: death-shock is a hard hit that spreads OUTWARD from the body
# as a diminishing wave, lands regardless of the witness's current morale,
# and stacks -- ~5-6 close deaths take a 10/10 witness to 1-2. Children feel
# it half again as hard. With no epicenter (an away resolution, an abstract
# loss) the news lands as a flat, smaller weight instead.
const DEATH_SHOCK_CLOSE := 1.5         # within the near ring, per death
const DEATH_SHOCK_NEAR_RADIUS := 260.0
const DEATH_SHOCK_FAR_RADIUS := 520.0
const DEATH_SHOCK_ABSTRACT := 0.4      # unwitnessed news, per death

func register_villager_deaths(n: int, epicenter: Vector2 = Vector2(INF, INF)) -> void:
	if n <= 0:
		return
	morale_death_shock = minf(morale_death_shock + float(n) * DEATH_SHOCK_PER_KILL, DEATH_SHOCK_MAX)
	var witnessed: bool = epicenter.x != INF and not in_dungeon
	var npc_pos := {}
	if witnessed:
		for npc in get_tree().get_nodes_in_group("npc"):
			if "villager_id" in npc:
				npc_pos[str(npc.villager_id)] = npc.global_position
	for v in rescued_villagers:
		var hit := DEATH_SHOCK_ABSTRACT
		if witnessed:
			var vid := str(v.get("id", ""))
			if npc_pos.has(vid):
				var d: float = npc_pos[vid].distance_to(epicenter)
				if d <= DEATH_SHOCK_NEAR_RADIUS:
					hit = DEATH_SHOCK_CLOSE
				elif d <= DEATH_SHOCK_FAR_RADIUS:
					hit = DEATH_SHOCK_CLOSE * 0.5
				else:
					hit = 0.2
		if v.get("is_kid", false):
			hit *= 1.5   # the fragile hearts a careless siege breaks first (10)
		v["morale"] = clampf(get_personal_morale(v) - float(n) * hit, 0.0, 10.0)

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
const DESPAIR_HP_REGEN_PER_HOUR := 3.0   # a LOW everywhere-trickle (base cut 12 -> 3) so nobody stays broken forever -- REAL, fast recovery is the Hospital (the Sick Road)
const VILLAGER_MAX_HP := 100.0
# THE SICK ROAD (expansion 2026-07-24): how fast the Hospital mends a patient who
# walked in wounded. A built ward heals at the base rate even bare-staffed; each
# villager on the Hospital's roster speeds it, and a seated Chief Physician
# sharpens the whole ward. So PLACEMENT gets them there fast; STAFFING is how
# quickly they mend once inside.
const HOSPITAL_TREAT_BASE_PER_HOUR := 20.0
const HOSPITAL_TREAT_PER_STAFF := 15.0
const HOSPITAL_CHIEF_TREAT_MULT := 1.5

# --- THE FADING OF DEEPWOOD (dev ask 2026-07-22): the village dying is a felt,
# escalating dread that PIERCES the away-fog -- you must be warned even in the
# deep, because losing everyone is nearly the end. Not the end itself: an empty
# hearth can still be rebuilt by rescuing the taken from the dark. The true end
# comes only when the town is empty AND no soul is left to bring home (below).
const VILLAGE_PERIL_LOW := 3             # "few souls remain" dread fires at/under this
# band: -1 safe, 0 dwindling (<=LOW), 1 the last soul (<=1), 2 empty (0). Warnings
# fire only on WORSENING (band rising); recovery lowers it and re-arms the dread.
var _peril_band := -1
# Named souls lost FOREVER (a rescued figure who then died -- they don't wait in
# the dark to be freed again). Empties the finite rescue pool over a doomed run;
# see rescue_pool_open. (Populated by the permadeath wiring; see commit note.)
var lost_souls: Array = []
var village_lost := false                # the true end has fired (village empty, none to save)

# --- CORRUPTION (GAME_BIBLE 10): despair made mechanical, v2 ---
# The Law of Despair executed locally on the personal-morale layer (5.5b):
# a villager whose OWN morale sits at zero begins to ROT -- a grey telegraph
# with a real window in which mending their life (food, a home, a job,
# company) REDEEMS them; nobody turns whose needs are fixed in time. If the
# window closes, they become an evil thing loose INSIDE the walls. Two
# separate fates, per canon: an empty larder KILLS (starvation is a death);
# a broken hope CORRUPTS (morale 0 is a turning). Warriors are exempt --
# they don't break, they die in battle. Children rot in half the time.
# ENABLED 2026-07-19: every support system canon wanted first (needs,
# personal morale, nurses, the Log) is now built.
const CORRUPTION_ENABLED := true
const ROT_HOURS := 6.0                 # the redeem window at morale 0
const ROT_CHILD_MULT := 0.5            # children corrupt far more easily (10)
const INFECT_RADIUS := 240.0           # a turning drags NEIGHBOURS this close
const INFECT_LOW_MORALE := 3.0         # "already low" -> dragged under, rot begins
const INFECT_STRAINED_TARGET := 5.5    # healthy-but-strained -> pushed, not turned
const INFECT_PUSH := 2.0
const FALLEN_PRESENCE_DRAIN := 0.05    # per loose demon per hour -- a trickle by design
const WALL_BREAK_MORALE_HIT := 0.5     # a bad omen, not a catastrophe
const SIEGE_ENEMY_SCENE := preload("res://siege_enemy.tscn")
const DEMON_BASE_HP := 40.0
const DEMON_BASE_DMG := 9.0
const DEMON_HP_PER_TIER := 0.30
const DEMON_DMG_PER_TIER := 0.20
const CORRUPTION_MORALE_SHOCK := 4.0     # extra town-wide dread per turning (domino)

var low_morale_hours := 0.0
var villager_hp: Dictionary = {}         # id -> current hp (0..100); absent == full health
var villager_rot: Dictionary = {}        # id -> game_hours the rot began (10)
var morale_admin_offset := 0             # dev-panel morale nudge (0 in normal play)

func is_warrior_villager(v: Dictionary) -> bool:
	return v.get("stat_name", "") == "Warrior" or v.get("role_key", "") == "Barracks"

# The rot clock (10): morale 0 opens the window, mending closes it, and
# only the window running out turns a person. The Log narrates both edges.
func tick_rot(_hours_passed: float) -> void:
	if not CORRUPTION_ENABLED:
		return
	var turned := []
	for v in rescued_villagers:
		var id := str(v.get("id", ""))
		# warriors die in battle, never to despair; shadows are past despair's
		# reach entirely (pledged, needless) -- neither ever enters the rot
		if is_warrior_villager(v) or v.get("shadow", false):
			villager_rot.erase(id)
			continue
		var m := get_personal_morale(v)
		if m <= 0.05:
			if not villager_rot.has(id):
				villager_rot[id] = game_hours
				log_event("people", "%s is slipping — despair has them by the throat." % str(v.get("name", "?")))
				notify("⚠ %s is at the edge — mend their life before the dark takes them!" % str(v.get("name", "?")))
			var window := ROT_HOURS * (ROT_CHILD_MULT if v.get("is_kid", false) else 1.0)
			if game_hours - float(villager_rot[id]) >= window:
				turned.append(id)
		elif villager_rot.has(id) and m > 0.5:
			villager_rot.erase(id)
			log_event("people", "%s was pulled back from the edge — hope held." % str(v.get("name", "?")))
	for id in turned:
		villager_rot.erase(id)
		transform_villager_to_demon(id)

# The chain reaction (10): a turning infects by each neighbour's OWN state.
# Already-low neighbours are dragged under (their rot window opens -- the
# spreading powder keg); healthy-but-strained ones take a hard push; a
# well-kept neighbour RESISTS outright. Healthy villagers are the firewall,
# which is exactly why the whole village must be cared for. Away from the
# live scene the dread finds two at random instead of by distance.
func _spread_infection(epicenter: Vector2) -> void:
	var near_ids := []
	if epicenter.x != INF and not in_dungeon:
		for npc in get_tree().get_nodes_in_group("npc"):
			if "villager_id" in npc and npc.global_position.distance_to(epicenter) <= INFECT_RADIUS:
				near_ids.append(str(npc.villager_id))
	if near_ids.is_empty():
		var pool := []
		for v in rescued_villagers:
			if not is_warrior_villager(v):
				pool.append(str(v.get("id", "")))
		pool.shuffle()
		near_ids = pool.slice(0, 2)
	for v in rescued_villagers:
		var vid := str(v.get("id", ""))
		if not near_ids.has(vid) or is_warrior_villager(v) or v.get("shadow", false):
			continue
		var m := get_personal_morale(v)
		if m < INFECT_LOW_MORALE:
			v["morale"] = 0.0
		elif personal_morale_target(v) < INFECT_STRAINED_TARGET:
			v["morale"] = clampf(m - INFECT_PUSH, 0.0, 10.0)

# 7.5/10: a rampart falling is a bad omen for everyone -- but only an omen;
# the real morale damage is the deaths a breach then lets happen.
func on_wall_broken(flank: String) -> void:
	for v in rescued_villagers:
		v["morale"] = clampf(get_personal_morale(v) - WALL_BREAK_MORALE_HIT, 0.0, 10.0)
	log_event("combat", "The %s rampart has fallen — the horde is in the streets!" % flank)

func get_villager_hp(id: String) -> float:
	return float(villager_hp.get(id, VILLAGER_MAX_HP))

# HP restored per in-game hour to a patient being treated at the Hospital (Sick
# Road). Placement gets them there; STAFFING is how fast they mend once inside.
func hospital_treat_rate() -> float:
	var rate := HOSPITAL_TREAT_BASE_PER_HOUR + HOSPITAL_TREAT_PER_STAFF * float(count_workers("Hospital"))
	if seated_leaders("Hospital") > 0:
		rate *= HOSPITAL_CHIEF_TREAT_MULT
	return rate

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
	# the simulation's real layer: every villager's own spirit drifts toward
	# what their life currently deserves (5.5b)
	tick_personal_morale(hours_passed)
	# the rot clock (10): personal zeros open windows, mending closes them
	tick_rot(hours_passed)
	# the presence of the fallen (10): every demon loose among the living saps
	# nearby hope -- deliberately a trickle, never an accelerant
	if not in_dungeon:
		var demons: int = get_tree().get_nodes_in_group("village_demon").size()
		if demons > 0:
			var sap: float = minf(FALLEN_PRESENCE_DRAIN * float(demons), 0.15) * hours_passed
			for v in rescued_villagers:
				v["morale"] = clampf(get_personal_morale(v) - sap, 0.0, 10.0)
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
		# day one is understood to be ashes -- a fresh village of three
		# unhoused, jobless souls IS miserable, and saying so in the player's
		# first minute is noise, not news. The warning waits out the first day.
		if not _warned_low_morale and game_hours > 24.0:
			_warned_low_morale = true
			notify("Your villagers are miserable — morale is critically low!")
			log_event("village", "The village's spirit is failing — despair gathers in the streets.")
	elif m >= 30:
		if _warned_low_morale:
			log_event("village", "Hope returns to Deepwood — the worst has passed.")
		_warned_low_morale = false
	# Villagers lose HP from TWO causes that share this one drain path (so there
	# is never a second, parallel death system): rock-bottom morale that has
	# persisted past its grace, and an empty larder that has persisted past its
	# grace (hunger, tracked in tick_food). Whichever cause is worse sets the
	# drain rate; the moment the player fixes EITHER, the dying stops and -- while
	# the no-regen rule isn't in yet (Step 3) -- HP heals back.
	# 10, two fates kept separate: only an EMPTY LARDER withers bodies now --
	# broken hope ROTS instead (tick_rot above turns it, per-villager). The
	# crisis meter still warns, halts births and saps defense; it just no
	# longer runs a second, parallel death machine.
	var drain_rate := 0.0
	if village_is_starving():
		# Seraphel, the Lightkeeper (the Ten): her aura slows the withering
		drain_rate = FOOD_STARVE_HP_DRAIN_PER_HOUR * (0.5 if ten_freed("ten_seraphel") else 1.0)
	# HEALTH (5.5): a staffed Hospital's doctors fight the withering and, in
	# the regen branch below, speed every recovery -- wounds linger without it
	var doctors := count_workers("Hospital") if is_building_operational("Hospital") else 0
	if drain_rate > 0.0 and doctors > 0:
		drain_rate /= 1.0 + 0.3 * float(doctors)
	var starving = drain_rate > 0.0
	var dead: Array = []
	for v in rescued_villagers:
		var id = v.get("id", "")
		# a shadow neither hungers nor withers -- skip the whole drain/regen path
		if v.get("shadow", false):
			continue
		var hp = get_villager_hp(id)
		if starving:
			hp -= hours_passed * drain_rate * _despair_rate(id)
			if hp <= 0.0:
				if CORRUPTION_ENABLED:
					dead.append(id)
				else:
					# kill-switch: misery sickens but can't finish them
					villager_hp[id] = 1.0
			else:
				villager_hp[id] = hp
		elif hp < VILLAGER_MAX_HP:
			# 7.3: only a rested body heals -- a warrior ON SHIFT stands the
			# wall and recovers nothing until their relief comes
			var is_warrior: bool = v.get("stat_name", "") == "Warrior" or v.get("role_key", "") == "Barracks"
			if is_warrior and warrior_on_duty(v):
				continue
			# passive regen is a low trickle now (base 3); doctors still nudge it up, but
			# the REAL, fast recovery is the Hospital (the Sick Road)
			villager_hp[id] = minf(VILLAGER_MAX_HP, hp + hours_passed * DESPAIR_HP_REGEN_PER_HOUR * (1.0 + 0.5 * float(doctors)))
	# 10: two SEPARATE fates. An empty larder / withered body KILLS -- a death,
	# with death-shock and a grave. A broken hope CORRUPTS -- that is tick_rot's
	# morale-zero window above, never this HP path.
	for id in dead:
		villager_hp.erase(id)
		var starved_name := villager_name(id)
		remove_villager_by_id(id)
		log_event("people", "%s starved to death. The town buried them at dawn." % starved_name)
	if dead.size() > 0:
		if dead.size() == 1:
			notify("A villager has starved to death.")
		else:
			notify("%d villagers have starved to death." % dead.size())

# A mortal-peril cry that PIERCES the village fog: unlike notify(), this reaches
# the player anywhere -- the deep included -- because "your whole town is about
# to die" is the one thing distance must not hide.
func notify_urgent(text: String) -> void:
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack and stack.has_method("show_notification"):
		stack.show_notification(text)

# THE FADING OF DEEPWOOD: watch the hearth's headcount and raise escalating dread
# as it empties. Fires only when things get WORSE (band rising) so it never spams;
# recovery re-arms it. Called every clock tick.
func tick_village_peril() -> void:
	if dev_mode:
		return
	var n := rescued_villagers.size()
	var band := -1
	if n == 0:
		band = 2
	elif n <= 1:
		band = 1
	elif n <= VILLAGE_PERIL_LOW:
		band = 0
	if band > _peril_band:
		match band:
			0:
				notify_urgent("❄ A cold dread reaches you even here — Deepwood is dying. Only %d souls remain at the hearth." % n)
				log_event("people", "Deepwood is dwindling — only %d souls remain." % n)
				play_sfx(SFX_THUD, 0.7)
			1:
				notify_urgent("❄ The LAST soul of Deepwood clings to life. If they fall with no one left to bring home, Deepwood is lost. GO HOME.")
				log_event("people", "One soul, alone, keeps Deepwood's fire lit. The town holds its breath.")
				play_sfx(SFX_THUD, 0.55)
			2:
				_on_village_emptied()
	_peril_band = band

# The hearth has gone cold. If souls still wait in the dark, this is a wound, not
# the end -- go free them and Deepwood breathes again. Only when NOBODY is left
# to rescue does the story truly close (village_truly_lost / _trigger below).
func _on_village_emptied() -> void:
	log_event("people", "Deepwood has fallen silent — not one soul remains at the hearth.")
	if rescue_pool_open():
		notify_urgent("Deepwood stands empty and cold. But the dark still holds captives — descend, break their chains, and carry the village home again.")
		play_sfx(SFX_THUD, 0.5)
	else:
		_trigger_village_lost()

# Is there anyone still out there to bring home? A named soul who has neither been
# rescued yet nor been lost forever -- a chained figure, a captive of the deep
# nine, one of the Ten still in a vault. While ANY remains, an empty village is a
# wound, not the end: you can always descend and rebuild.
func rescue_pool_open() -> bool:
	for lvl in VillagerQuests.IMPORTANT_FIGURES:
		var fid := str(VillagerQuests.IMPORTANT_FIGURES[lvl].get("villager_id", ""))
		if fid != "" and not is_villager_rescued(fid) and not lost_souls.has(fid):
			return true
	for id in Adventurers.ids():
		var st := adventurer_state(id)
		if not bool(st.get("rescued", false)) and not bool(st.get("dead", false)):
			return true
	if not all_ten_freed():
		return true
	return false

# Is this id one of the named leadership figures (the finite, now-permadeath
# rescue pool)? A rescued figure who dies is added to lost_souls and never waits
# in the dark to be freed again -- which is what lets the pool finally empty.
func is_important_figure(villager_id: String) -> bool:
	# EVERY named, quest-bearing soul is a one-off: the road hostages hand-placed
	# in main.tscn (Elin/Milo/Sena...) as much as the deep's chained figures. They
	# were excluded here, so a freed road hostage who later DIED never entered
	# lost_souls -- and their Sorrow-Crystal respawned on the road on the next
	# Continue (dev 2026-07-23, seen with EYES: "[E] free Elin" back on the road).
	if VillagerQuests.QUEST_DEFS.has(villager_id):
		return true
	for lvl in VillagerQuests.IMPORTANT_FIGURES:
		if str(VillagerQuests.IMPORTANT_FIGURES[lvl].get("villager_id", "")) == villager_id:
			return true
	return false

# The true end: the hearth is cold AND no soul is left to bring home. The story
# closes here -- a somber screen, then back to the world's edge (the main menu).
func _trigger_village_lost() -> void:
	if village_lost:
		return
	village_lost = true
	log_event("people", "Deepwood is gone. There was no one left to save, and now no one at all.")
	_show_village_lost_screen()

func _show_village_lost_screen() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 250
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.03, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 26)
	center.add_child(box)
	var title := Label.new()
	title.text = "DEEPWOOD IS GONE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.72, 0.2, 0.24))
	box.add_child(title)
	var body := Label.new()
	body.text = "Not one soul remains at the hearth,\nand no one waits in the dark to be brought home.\nThere was no one left to save.\n\nThe forest keeps its silence."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", Color(0.78, 0.78, 0.82))
	box.add_child(body)
	var btn := Button.new()
	btn.text = "Let the story rest"
	btn.custom_minimum_size = Vector2(240, 40)
	btn.pressed.connect(func():
		tree.paused = false
		tree.change_scene_to_file("res://main_menu.tscn"))
	box.add_child(btn)
	tree.paused = true

# A neglected villager's descent completes: spawn a demon where their avatar
# stands (so it attacks the town from within), then purge the villager and heap
# extra dread on the town (the domino). If the player is away in the dungeon
# there's no village to spawn into -- the villager is simply lost to corruption.
func transform_villager_to_demon(villager_id: String) -> void:
	log_event("people", "%s's hope broke — they turned, and the thing they became walks the streets." % villager_name(villager_id))
	# remember who they WERE -- the Shrine's mercy needs the person, not the
	# monster (10)
	var snapshot := {}
	for v in rescued_villagers:
		if str(v.get("id", "")) == villager_id:
			snapshot = v.duplicate(true)
			break
	var pos = Vector2.ZERO
	var parent: Node = null
	for npc in get_tree().get_nodes_in_group("npc"):
		if npc.villager_id == villager_id:
			pos = npc.global_position
			parent = npc.get_parent()
			break
	if parent != null and not in_dungeon:
		_spawn_demon_at(pos, parent, snapshot)
	remove_villager_by_id(villager_id)   # roster + mating/school cleanup + avatar + grief
	# each turning deepens the whole town's dread -> a miserable village chains
	morale_death_shock = minf(morale_death_shock + CORRUPTION_MORALE_SHOCK, DEATH_SHOCK_MAX)
	# ...and infects by proximity (10): the already-low are dragged under, the
	# strained are pushed, the well-kept RESIST
	_spread_infection(pos if parent != null else Vector2(INF, INF))

# Spawn one demon at a world position, hunting the town. Wears the downloaded
# demon sprite (art/enemies/demon) so a corrupted villager visibly becomes a
# DEMON -- not a lookalike of the hooded siege raiders.
func _spawn_demon_at(pos: Vector2, parent: Node, was: Dictionary = {}) -> void:
	var tier = current_siege_tier()
	var demon = SIEGE_ENEMY_SCENE.instantiate()
	demon.skin = "demon"
	demon.was_villager = was
	demon.max_health = int(round(DEMON_BASE_HP * (1.0 + (tier - 1) * DEMON_HP_PER_TIER)))
	demon.attack_damage = int(round(DEMON_BASE_DMG * (1.0 + (tier - 1) * DEMON_DMG_PER_TIER)))
	demon.reward = 4 + tier
	demon.global_position = pos
	parent.add_child(demon)
	demon.add_to_group("village_demon")   # its lingering presence saps hope (10)
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

# Everyone with a role at a working building, any title.
func count_workers(role_key: String) -> int:
	var n := 0
	for villager in rescued_villagers:
		if str(villager.get("role_key", "")) == role_key:
			n += 1
	return n

# 5.6: the village's own gold engine. Taxes need a WORKING, STAFFED
# Government -- before that, the dungeon is the only faucet and every coin
# hurts, exactly as Act I intends. A bonded villager works at unlocked
# potential and is taxed at BOND_INCOME_MULT; Party members organize the
# take; the Bar trickles drink money on the side.
func generate_passive_income() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("add_currency"):
		return
	var total := 0.0
	if is_building_operational("Government") and count_workers("Government") > 0:
		var taxable := 0.0
		for villager in rescued_villagers:
			var rk := str(villager.get("role_key", ""))
			if rk == "" or rk == "Government" or not is_building_operational(rk):
				continue
			if school_enrollments.has(str(villager.get("id", ""))):
				continue   # trainees aren't taxable working employees yet
			var share := TAX_PER_EMPLOYED * building_output_multiplier(rk)
			if villager.get("bond", false):
				share *= BOND_INCOME_MULT
			taxable += share
		taxable += PARTY_MEMBER_INCOME * float(count_leader_holders("Government", "Party"))
		total += taxable * get_village_income_multiplier()
	if is_building_operational("Bar"):
		total += BARKEEP_TRICKLE * float(count_workers("Bar"))
	if total <= 0.0:
		return
	# a happy village is a taxable village (0.75x .. 1.25x)
	total *= village_morale_multiplier()
	# fractions accrue: a six-soul town earns a coin every few ticks instead
	# of rounding forever to zero
	_gold_accum += total
	if _gold_accum >= 1.0:
		var pay := int(_gold_accum)
		_gold_accum -= float(pay)
		player.add_currency(pay)

var _gold_accum := 0.0

# --- AUTOSAVE (polish 2026-07-20) ---
# The game only ever saved on a deliberate pause-menu quit -- so a crash,
# an alt-F4, or a power cut threw away the entire session. (It happened.)
# Now the world writes itself down at the moments that matter and every
# few minutes besides. Never while the player is dead (that would bank a
# corpse mid-respawn), and never from the menu (no player, no run).
const AUTOSAVE_INTERVAL_SECONDS := 180.0
var _autosave_accum := 0.0

func autosave(reason := "", loud := false) -> void:
	# NEVER from a test harness: the suites paint fake villagers and fake
	# economies into this very state, and an autosave would bank that
	# fiction over the dev's real save.
	if OS.has_environment("MONARCH_TEST"):
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if "is_dead" in player and player.is_dead:
		return
	save_game(player)
	_autosave_accum = 0.0
	if loud:
		var stack = get_tree().get_first_node_in_group("notification_stack")
		if stack:
			stack.show_notification("💾 Progress saved%s." % ("" if reason == "" else " — " + reason))

# --- "WHAT NOW?" (polish 2026-07-20) ---
# The game is deep and its opening is quiet: a new player lands in ruins
# with no idea which of a dozen systems to touch first. This reads the
# village's actual state and names the single most useful next act --
# survival first, then the people, then the depth. Shown in the TAB
# glance; never a quest system, just a sentence that is always true.
func next_objective() -> String:
	if not is_building_operational("Farm"):
		if not has_blueprint("Farm"):
			return "Find the Farm's blueprint below"
		return "Raise the Farm — open the Build menu (B) and place it"
	if farm_worker_count() == 0 and dock_worker_count() == 0:
		return "Put someone to work at the Farm (E → assign) so food grows itself"
	if village_food <= 0.0:
		return "The larder is EMPTY — tend the Farm by hand (hold H) now"
	var homeless := 0
	for v in rescued_villagers:
		if not v.get("is_kid", false) and villager_home_id(str(v.get("id", ""))) == "":
			homeless += 1
	if not is_building_operational("Hospital") and has_blueprint("Hospital"):
		return "Raise the Hospital (Build menu: B) — wounds do not heal on their own here"
	if homeless >= 4:
		return "Raise a cottage at the staked plot — %d sleep rough" % homeless
	if rescued_villagers.size() < 8:
		return "Descend and free the taken — every soul is a pair of hands"
	if not is_building_operational("Barracks") and has_blueprint("Barracks"):
		return "Raise the Barracks (Build menu: B) — the nights are getting worse"
	if watchtower_tier < 1:
		return "Raise the Watchtower — you cannot plan around a siege you can't see"
	if not is_building_operational("Government"):
		return "The Government makes the village's own gold — raise it (Build menu: B) when you can"
	var ruined := count_ruined_buildings()
	if ruined > 0:
		return "%d building%s still in ruins — Deepwood deserves to stand whole" % [ruined, "" if ruined == 1 else "s"]
	if count_empty_role_slots() > 0:
		return "Staff every post — %d stand empty" % count_empty_role_slots()
	if not all_ten_freed():
		return "Free the Ten from the vaults below — %d still hang in the dark" % (10 - count_ten_freed())
	if seen_empty_throne and deep_truly_empty():
		return "Carry the news home — Deepwood deserves to hear it"
	if highest_unlocked_level >= 100:
		return "Descend to 100 — the deep has gone strangely QUIET"
	return "Clear the way to the root — floor %d waits" % highest_unlocked_level

# --- ONE-SHOT SFX (polish pass 2026-07-20) ---
# Every system built this week spoke only in toasts -- silent portals,
# silent blueprints, a silent Watchtower bell. One helper, so a moment
# that matters is HEARD as well as read. Positional when a place is
# given, flat UI otherwise; pitch shifts let one sample wear many hats.
const SFX_YES = preload("res://audio/purchase.wav")
const SFX_NO = preload("res://audio/purchase_denied.wav")
const SFX_THUD = preload("res://audio/explosion.wav")
const SFX_CHIME = preload("res://audio/arrow_deflect.wav")

func play_sfx(stream: AudioStream, pitch := 1.0, at = null) -> void:
	var tree := get_tree()
	if tree == null or stream == null:
		return
	var host: Node = tree.current_scene
	if host == null:
		return
	if at != null:
		var sp := AudioStreamPlayer2D.new()
		sp.stream = stream
		sp.pitch_scale = pitch
		host.add_child(sp)
		sp.global_position = at
		sp.play()
		sp.finished.connect(sp.queue_free)
		return
	var up := AudioStreamPlayer.new()
	up.stream = stream
	up.pitch_scale = pitch
	host.add_child(up)
	up.play()
	up.finished.connect(up.queue_free)

# --- BLUEPRINTS (GAME_BIBLE 5.2, dev decision 2026-07-20) ---
# A ruin cannot be RAISED until its blueprint is found in the deep. The
# survival basics are known from the start; the other twelve lie at fixed
# floors paced by the dependency ladder (5.7.1), everything in hand by
# floor 30 -- deliberately early, so no building arrives too late to
# matter. Old saves know everything (additive default).
const BLUEPRINT_STARTERS = ["Farm", "Tavern", "Builderhouse", "Cottage", "Wall"]
const BLUEPRINT_FLOORS = {
	2: "Hospital", 4: "School", 6: "Fishing Dock", 8: "Barracks",
	10: "Science Lab", 11: "Bar", 13: "Mine", 16: "Blacksmith",
	19: "Marketplace", 22: "Bank", 26: "Government", 30: "Shrine",
}
var blueprints: Array = []

func has_blueprint(building_name: String) -> bool:
	# DEV/TEST: in dev_mode you hold EVERY blueprint, so the whole build menu is
	# open to test (dev ask 2026-07-22). The real game still SCATTERS them through
	# the levels (BLUEPRINT_FLOORS + blueprint_pickup) -- this only bypasses that
	# in the sandbox. Launch with --dev to get them all.
	return dev_mode or (building_name in blueprints)

func grant_blueprint(building_name: String) -> void:
	if building_name in blueprints:
		return
	blueprints.append(building_name)
	log_event("village", "The %s blueprint was recovered from the deep." % building_name)
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack:
		stack.show_notification("📜 BLUEPRINT: the %s can be raised now." % building_name)

# --- MOVABLE BUILDINGS (GAME_BIBLE 5.2, dev decision 2026-07-20) ---
# Every roster building can be RELOCATED: the assign panel packs it up
# (25g + 4 wood), you walk to the new ground and press H to plant it.
# Positions persist and rebuild with the scene. Cottages, the walls and
# the Watchtower keep their ground -- the row, the flanks and the plot
# ARE their identity.
const RELOCATE_GOLD := 25
const RELOCATE_WOOD := 4
const RELOCATE_CLEARANCE := 40.0
var building_positions: Dictionary = {}   # building_name -> x, player-chosen
var moving_building := ""                 # transient: the building packed up

# --- THE MINE (GAME_BIBLE 5.7, decided 2026-07-20 delegated) ---
# The delegated form of hand-mining: staffed Miners haul the SAME materials
# the pickaxe does -- stone and iron shards -- into the player's bag, one
# haul per Miner per in-game day. No new resource ids: the Blacksmith and
# Builderhouse chains simply connect.
var _mine_accum := 0.0
var _mine_cycles := 0

func tick_mine_yield(hours_passed: float) -> void:
	if not is_building_operational("Mine"):
		return
	var miners := count_workers("Mine")
	if miners == 0:
		return
	_mine_accum += hours_passed
	while _mine_accum >= 24.0:
		_mine_accum -= 24.0
		_mine_cycles += 1
		var player = get_tree().get_first_node_in_group("player")
		if player and "inventory" in player and player.inventory:
			player.inventory.add_item("stone", 2 * miners)
			player.inventory.add_item("iron_shard", 1 * miners)
			# EMBER too, at half the iron cadence. ember_crystal gates 28 skill nodes
			# -- the most of any material -- yet was cache-ONLY (scarce), while iron
			# (10 nodes) flowed from here. That left every ember-gated spec, and ALL
			# THREE Mage specs (their tier-4 forks are all ember), materially stalled
			# vs iron specs (marathon sim 2026-07-22: Mage 29% tree vs Sword 52%). The
			# mine now digs crystals too, so ember has a village source like iron does.
			if _mine_cycles % 2 == 0:
				player.inventory.add_item("ember_crystal", 1 * miners)
				log_event("economy", "The Mine's deep seam gave up %d ember crystal." % miners)
			log_event("economy", "The Mine's haul came up: %d stone, %d iron." % [2 * miners, miners])

# --- THE SHRINE (GAME_BIBLE 10, decided 2026-07-20 delegated) ---
# Corruption's only mercy, unlocked at depth 30: a put-down demon that was
# once a villager can be CLEANSED back to life -- if the Shrine stands, its
# Lightkeepers are at their posts, and the player carries 3 SORROWSHARDS
# (despair, captured and inverted, is the reagent that undoes despair).
# Away-losses stay losses: the Shrine only cleanses what you catch.
const SHRINE_UNLOCK_DEPTH := 30
const SHRINE_CLEANSE_SHARDS := 3

func shrine_unlocked() -> bool:
	return highest_unlocked_level >= SHRINE_UNLOCK_DEPTH

func shrine_ready() -> bool:
	return shrine_unlocked() and is_building_operational("Shrine") and count_workers("Shrine") > 0

func try_cleanse(was_villager: Dictionary) -> bool:
	if was_villager.is_empty() or not shrine_ready():
		return false
	var player = get_tree().get_first_node_in_group("player")
	if player == null or not "inventory" in player or player.inventory == null:
		return false
	if not player.inventory.remove_item("sorrowshard", SHRINE_CLEANSE_SHARDS):
		notify("The Shrine could cleanse them — but it needs %d Sorrowshards." % SHRINE_CLEANSE_SHARDS)
		return false
	var v: Dictionary = was_villager.duplicate(true)
	# they come back THEMSELVES -- shaken, but alive. Seraphel, the
	# Lightkeeper (the Ten): under her light they return steadier.
	v["morale"] = 5.0 if ten_freed("ten_seraphel") else 3.0
	v.erase("shadow")
	lost_souls.erase(str(v.get("id", "")))   # cleansed back to life -> no longer lost
	rescued_villagers.append(v)
	villager_hp[str(v.get("id", ""))] = 60.0
	play_sfx(SFX_YES, 1.15)
	log_event("people", "★ %s was cleansed at the Shrine — despair could not keep them." % str(v.get("name", "?")))
	notify("★ The Shrine burns three Sorrowshards — %s returns to the living." % str(v.get("name", "?")))
	return true

# --- THE WATCHTOWER (GAME_BIBLE 7.1, decided 2026-07-20 delegated) ---
# Foresight is EARNED. Act I is true chaos: no wave indicator exists at all.
# A standalone structure (not roster -- it has no staff and no need) rises
# in three paid tiers beside the west rampart; each tier buys a longer
# warning, and tier 1 is what makes the siege clock VISIBLE at all.
const WATCHTOWER_WARNING_HOURS = [0.0, 1.0, 2.0, 24.0]   # by tier
const WATCHTOWER_COSTS = [
	{"wood": 10, "stone": 8},          # tier 1: eyes on the road
	{"iron_shard": 6, "wood": 8},      # tier 2: a bell and a brazier
	{"ember_crystal": 2, "stone": 12}, # tier 3: the far-seeing flame
]
var watchtower_tier := 0
var _tower_bell_armed := true          # transient: one toll per incoming siege

func watchtower_warning_hours() -> float:
	return WATCHTOWER_WARNING_HOURS[clampi(watchtower_tier, 0, 3)]

# tier 0 = the night keeps its own counsel (dev sandbox sees everything)
func siege_clock_visible() -> bool:
	return dev_mode or watchtower_tier >= 1

# The tower's bell: tolls ONCE per incoming siege, as early as the tier
# allows. Called from the hourly tick.
func tick_watchtower_warning() -> void:
	if watchtower_tier < 1 or despair_dead or live_siege_active:
		return
	var lead := watchtower_warning_hours()
	if hours_until_next_siege > lead:
		_tower_bell_armed = true       # quiet road: re-arm for the next wave
	elif _tower_bell_armed:
		_tower_bell_armed = false
		play_sfx(SFX_CHIME, 0.7)
		notify("🔔 The Watchtower bell — a tier-%d wave lands in ~%dh!" % [current_siege_tier(), int(ceil(hours_until_next_siege))])
		log_event("combat", "The Watchtower rang: a wave is coming.")

# --- THE WANDERER'S POST (GAME_BIBLE 5.6a) ---
# The Marketplace makes no gold. It is the town's guest-stall: wandering
# treasure-sellers drift in with random stock, and how well they treat you
# is a DIRECT function of how nice your village is to be in. High morale
# (5/10+): they stay the full day and slowly mark prices DOWN the longer
# they linger. A gloomy town gets a short, full-price visit. Sellers
# escalate -- the road talks, and a well-run village attracts better
# merchants with rarer stock at steeper opening prices, which your
# hospitality then eats into. Purely a gold SINK (5.6). A staffed Merchant
# sweetens stock and haggling -- the book's own lean for the profession.
const WANDERER_NAMES = ["Salla of the Long Road", "Bramble-cart Icky", "Vex the Peddler",
	"Odo Twicesold", "Mirena Farshore", "The Quiet Tinker"]
const WANDERER_GAP_MIN := 12.0
const WANDERER_GAP_MAX := 30.0
const WANDERER_DISCOUNT_MAX := 0.25    # a happy town's slow markdown across the stay
const WANDERER_NEVER_SOLD = ["wpn_soulsplit", "relic_rewound_hour", "wpn_wand"]
var wanderer: Dictionary = {}          # active seller: name/arrived/dwell/stock/tier
var wanderer_next_at_hours := 8.0      # the first drifts in early on day one
var wanderers_seen := 0                # the road talks: stock escalates

func grade_rank(item_id: String) -> int:
	var grade = Inventory.get_grade(item_id)
	if Inventory.GRADE_DEFS.has(grade):
		return int(Inventory.GRADE_DEFS[grade].rank)
	return 1

func marketplace_merchant_staffed() -> bool:
	return is_building_operational("Marketplace") and count_workers("Marketplace") > 0

func tick_wanderers(_hours_passed: float) -> void:
	if not is_building_operational("Marketplace"):
		return                          # the road walks past a ruin
	if wanderer.is_empty():
		if game_hours >= wanderer_next_at_hours:
			_wanderer_arrive()
	elif game_hours >= float(wanderer["arrived"]) + float(wanderer["dwell"]):
		log_event("economy", "%s packed the cart and moved on." % str(wanderer.get("name", "The wanderer")))
		wanderer = {}
		wanderer_next_at_hours = game_hours + randf_range(WANDERER_GAP_MIN, WANDERER_GAP_MAX)

# canon curve: 5/10+ hospitality earns the full ~24h stay; below it the
# visit shortens with the gloom, down to a 6-hour stop-and-go
func _wanderer_dwell_hours() -> float:
	var m := float(village_morale())
	if m >= 50.0:
		return 24.0
	return maxf(6.0, 12.0 * m / 50.0)

func _wanderer_pool(tier: int) -> Array:
	var pool := []
	for id in Inventory.ITEM_GRADES:
		if id in WANDERER_NEVER_SOLD:
			continue
		var rank := grade_rank(id)
		# tier 0 carries common/uncommon; each visit-tier admits one rank more,
		# so the road's best only ever reaches epic (loot stays king above)
		if rank <= 2 + tier and rank <= 4:
			pool.append(id)
	return pool

func _wanderer_price(item_id: String) -> int:
	var rank := grade_rank(item_id)
	var def: Dictionary = Inventory.get_item_def(item_id)
	var cat := str(def.get("category", ""))
	var base: float
	if cat == "consumable" or cat == "material":
		base = 8.0 + float(rank * rank) * 4.0
	else:
		base = 20.0 + float(rank * rank) * 22.0
	# the road talks: later sellers open steeper (their stock is worth it)
	base *= 1.0 + 0.15 * float(mini(wanderers_seen, 8))
	return maxi(2, int(round(base)))

func _wanderer_arrive() -> void:
	wanderers_seen += 1
	var tier: int = mini(wanderers_seen / 2, 2)
	var pool := _wanderer_pool(tier)
	if pool.is_empty():
		return
	pool.shuffle()
	var slots: int = 4 + (1 if marketplace_merchant_staffed() else 0)
	var stock := []
	for i in range(mini(slots, pool.size())):
		var id: String = pool[i]
		var cat := str(Inventory.get_item_def(id).get("category", ""))
		stock.append({"id": id, "price": _wanderer_price(id),
			"count": 3 if (cat == "consumable" or cat == "material") else 1})
	wanderer = {
		"name": WANDERER_NAMES[randi() % WANDERER_NAMES.size()],
		"arrived": game_hours, "dwell": _wanderer_dwell_hours(),
		"stock": stock, "tier": tier,
	}
	log_event("economy", "%s set up at the Wanderer's Post — %d wares on the cart." % [wanderer["name"], stock.size()])
	notify("🛒 %s has set up at the Wanderer's Post." % wanderer["name"])

# The live price: a happy town's markdown deepens across the stay, and a
# staffed Merchant haggles a tenth off everything.
func wanderer_price_now(entry: Dictionary) -> int:
	var p := float(entry.get("price", 10))
	if not wanderer.is_empty() and float(village_morale()) >= 50.0:
		var stay: float = clampf((game_hours - float(wanderer["arrived"])) / maxf(float(wanderer["dwell"]), 0.1), 0.0, 1.0)
		p *= 1.0 - WANDERER_DISCOUNT_MAX * stay
	if marketplace_merchant_staffed():
		p *= 0.9
	return maxi(1, int(round(p)))

func buy_from_wanderer(index: int, player: Node) -> bool:
	if wanderer.is_empty() or player == null or not "inventory" in player or player.inventory == null:
		return false
	var stock: Array = wanderer.get("stock", [])
	if index < 0 or index >= stock.size():
		return false
	var entry: Dictionary = stock[index]
	var price := wanderer_price_now(entry)
	if player.currency < price:
		notify("You cannot afford that — %dg." % price)
		return false
	# the ware goes in the bag BEFORE gold changes hands -- a full bag must
	# never eat the coin (add_item returns what did NOT fit)
	if player.inventory.add_item(str(entry.get("id", "")), 1) > 0:
		notify("Your bag is full — make room first.")
		return false
	player.add_currency(-price)
	entry["count"] = int(entry.get("count", 1)) - 1
	if int(entry["count"]) <= 0:
		stock.remove_at(index)
	return true

# 5.5 WAGES: staff work for PAY, drawn daily from the player's purse (the
# treasury, 5.6 -- the Bank runs it leaner when staffed). Workers the purse
# cannot cover QUIT on the spot: their service stops until re-staffed, and
# the Log names them. This is the cost side of every chain in 5.7.
var wage_accum_hours := 0.0

func tick_wages(hours_passed: float) -> void:
	wage_accum_hours += hours_passed
	if wage_accum_hours < 24.0:
		return
	wage_accum_hours -= 24.0
	var staff := []
	for v in rescued_villagers:
		# a School student / Barracks recruit isn't a working, waged employee yet
		# -- they're IN school_enrollments, training toward their role
		if str(v.get("role_key", "")) != "" and not school_enrollments.has(str(v.get("id", ""))):
			staff.append(v)
	if staff.is_empty():
		return
	var per := WAGE_PER_WORKER_PER_DAY
	if is_building_operational("Bank") and count_workers("Bank") > 0:
		per *= BANK_PAYROLL_DISCOUNT
	var player = get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("add_currency"):
		return
	var affordable: int = mini(staff.size(), int(floor(float(player.currency) / per)))
	if affordable > 0:
		player.add_currency(-int(round(per * float(affordable))))
	var unpaid: int = staff.size() - affordable
	if unpaid > 0:
		staff.shuffle()
		for i in range(unpaid):
			var v: Dictionary = staff[i]
			log_event("economy", "%s quit their post — the purse could not pay them." % str(v.get("name", "?")))
			v["role_key"] = ""
			v["role_title"] = ""
			v["morale"] = clampf(get_personal_morale(v) - 1.5, 0.0, 10.0)
		play_sfx(SFX_NO, 0.8)
		notify("%d worker%s quit unpaid — the treasury ran dry." % [unpaid, "" if unpaid == 1 else "s"])

func count_leader_holders(role_key: String, title: String) -> int:
	var count = 0
	for villager in rescued_villagers:
		if villager.get("role_key") == role_key and villager.get("role_title") == title:
			count += 1
	return count

func get_village_income_multiplier() -> float:
	return 1.0 + count_leader_holders("Government", "Chancellor") * LEADER_BONUS_PER_HOLDER * (2.0 if ten_freed("ten_mirielle") else 1.0)

func get_gestation_speed_multiplier() -> float:
	# a happy town makes babies faster; a despairing one makes none at all
	return (1.0 + count_leader_holders("Hospital", "Chief Physician") * LEADER_BONUS_PER_HOLDER) * morale_birth_multiplier()

func get_school_graduation_speed_multiplier() -> float:
	return 1.0 + count_leader_holders("School", "Principal") * LEADER_BONUS_PER_HOLDER

func get_barracks_graduation_speed_multiplier() -> float:
	# Brannoc, the Wall That Stood (the Ten): warriors train twice as fast
	var ten_mult := 2.0 if ten_freed("ten_brannoc") else 1.0
	return (1.0 + count_leader_holders("Barracks", "Warchief") * LEADER_BONUS_PER_HOLDER) * ten_mult

# ============================ LEADERSHIP AUTOMATION ============================
# The rescued VIP leaders don't just buff numbers -- they RUN the village so it
# needs far less hand-management (the colony-sim payoff). Driven once per income
# tick (right after generate_passive_income) plus a few read-time multipliers
# (defense/food/morale, folded into those functions). Every effect is gated on
# that building's leadership seat(s) being FILLED and scales with how many are
# seated (Science Lab 4, Barracks/School/Builderhouse 2). Leaders keep working
# even while the player is off in the dungeon -- the town runs itself.
const BANK_INTEREST_RATE := 0.0008      # ~2.4%/day at full rate (numbers pass 2026-07-20)
const BANK_INTEREST_CAP := 5            # ...capped per tick so wealth can never run away
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
	return grade_rank(item_id)

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
	if player and player.has_method("add_currency") and (seated_leaders("Bank") > 0 or (is_building_operational("Bank") and count_workers("Bank") > 0)):
		# 5.6: interest is the Bank's FUNCTION -- any staffed Financist grows
		# the treasury (half rate); the Treasurer leader runs it at full, and
		# Dorian Vail, the Coinbinder (the Ten), doubles whatever runs
		var rate: float = BANK_INTEREST_RATE * (1.0 if seated_leaders("Bank") > 0 else 0.5)
		var interest = clampi(int(player.currency * rate * (2.0 if ten_freed("ten_dorian") else 1.0)), 0, BANK_INTEREST_CAP)
		if interest > 0:
			player.add_currency(interest)               # the treasury grows
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
	# Grammar (5.1): a staffed Worker crew rebuilds on its own -- delegated,
	# at half the leaders' pace; Master Builder/Foreman run it every tick
	if seated_leaders("Builderhouse") > 0:
		auto_repair_one()                           # leaders: rebuild the ruins
	elif count_workers("Builderhouse") > 0:
		_builder_half_tick = not _builder_half_tick
		if _builder_half_tick:
			auto_repair_one()                       # the crew alone: slower, but real
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
			if count_leader_holders(bkey, str(rd.get("title", ""))) >= role_capacity(bkey, rd):
				continue
			v["role_key"] = bkey
			v["role_title"] = str(rd.get("title", ""))
			return true
	return false

# A worker role's LIVE capacity = the building instance's effective_slots (base +
# SLOTS_PER_LEVEL per upgrade), exactly what the assign UI + is_role_full enforce.
# auto-staff used the STATIC base instead (dev 2026-07-23), so the Chancellor could
# never fill an upgraded worker building past its level-1 count -- the assign panel
# offered slots the automation refused, and a big auto-run town under-produced (food
# most of all). Match the manual cap; fall back to base when no node exists (a headless
# balance sim has no building nodes, so its numbers are unchanged).
func role_capacity(building_key: String, role_def: Dictionary) -> int:
	var node = get_tree().get_first_node_in_group("building_role_" + building_key)
	if node != null and node.has_method("effective_slots"):
		return int(node.effective_slots(role_def))
	return int(role_def.get("slots", 0))

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
var _builder_half_tick := false

func auto_repair_one() -> void:
	var worst := ""
	var worst_stage := TOTAL_BUILD_STAGES
	for bn in STARTING_BUILDINGS:
		# Only a building that actually STANDS can be repaired. Buildings are placed
		# from the B menu now (build-menu rework), and an unplaced one has no node while
		# building_build_stage defaults it to 0 -- so the old loop treated every un-built
		# hall as "most ruined" and the crew silently raised it to OPERATIONAL with no
		# node, running its service (food, tax, healing...) for free and handing the
		# finale gate every building. Repair only what was actually built (dev 2026-07-23).
		if get_tree().get_first_node_in_group("building_role_" + bn) == null:
			continue
		var st = building_build_stage(bn)
		if st < worst_stage:
			worst_stage = st
			worst = bn
	if worst == "" or worst_stage >= TOTAL_BUILD_STAGES:
		return
	building_stage[worst] = worst_stage + 1
	if int(building_stage[worst]) >= TOTAL_BUILD_STAGES:
		building_health[worst] = BUILDING_MAX_HEALTH
		log_event("village", "The builders finished the %s — it stands again." % worst)
	for node in get_tree().get_nodes_in_group("building"):
		if "role_key" in node and str(node.role_key) == worst and node.has_method("refresh_visual"):
			node.refresh_visual()

# --- VILLAGE SELF-SUFFICIENCY (the time economy, dev vision 2026-07-22) ---
# The dev's core loop: early Deepwood needs the player's HANDS for everything --
# hand-harvesting food, hauling repairs, assigning every rescue -- so the day is
# eaten by chores and only a thin window is left to dive. Every automation earned
# above (a staffed Farm, a builder crew, a seated Chancellor) hands one of those
# chores to the village and gives that time BACK. This makes the trade legible:
# a self-reliance % for the glance panel, and a one-time celebration the first
# time each chore starts running itself ("your mornings are your own").
#
# Each domain: key, a short label, whether it currently runs WITHOUT the player,
# and the line said the first time it does. Purely derived from live state --
# the same staffing checks the auto_* helpers above act on, read as progress.
func chore_domains() -> Array:
	return [
		{
			"key": "food", "label": "Food",
			"handled": not rescued_villagers.is_empty() and food_production_per_hour() >= food_consumption_per_hour(),
			"freed": "🌾 The fields feed the town on their own now — that's your mornings back. Spend them below.",
		},
		{
			"key": "staffing", "label": "Labour",
			"handled": seated_leaders("Government") > 0,
			"freed": "🏛 The Chancellor seats every new soul for you now — no more hand-assigning the rescued.",
		},
		{
			"key": "repair", "label": "Repairs",
			"handled": seated_leaders("Builderhouse") > 0 or count_workers("Builderhouse") > 0,
			"freed": "🔨 The builders keep Deepwood standing without you — leave the hauling to them.",
		},
		{
			"key": "health", "label": "Healing",
			"handled": is_building_operational("Hospital") and count_workers("Hospital") > 0,
			"freed": "⚕ The infirmary tends the hurt on its own now — one less thing to come home for.",
		},
		{
			"key": "commerce", "label": "Coin & lore",
			"handled": seated_leaders("Science Lab") > 0 or seated_leaders("Marketplace") > 0,
			"freed": "⚖ The market and lab turn your haul to coin and knowledge without you lifting a finger.",
		},
	]

# How much of the village's daily upkeep now runs itself, 0..1 (plus the raw
# counts for the readout). At 0 the town needs the player for everything (the
# early block); at 1 it runs itself and the whole day is the player's to dive.
func village_self_sufficiency() -> Dictionary:
	var doms := chore_domains()
	var handled := 0
	for d in doms:
		if d["handled"]:
			handled += 1
	return {
		"handled": handled, "total": doms.size(),
		"fraction": float(handled) / float(maxi(1, doms.size())),
	}

# Persistent: which domains have already had their one-time "you're free of this
# chore" celebration. Never fires twice, and waits until the player is HOME to
# see it (village_info_available) so a chore that automates while you're deep is
# still celebrated when you walk back in and it still holds.
var selfsuf_celebrated: Array = []

func tick_self_sufficiency() -> void:
	# once every chore has been celebrated there is nothing left to watch
	if dev_mode or selfsuf_celebrated.size() >= 5 or not village_info_available():
		return
	for d in chore_domains():
		var key := str(d["key"])
		if bool(d["handled"]) and not selfsuf_celebrated.has(key):
			selfsuf_celebrated.append(key)
			notify(str(d["freed"]))
			log_event("village", str(d["freed"]))
			play_sfx(SFX_CHIME, 1.15)

func find_available_parents() -> Dictionary:
	var male_id = ""
	var female_id = ""
	for villager in rescued_villagers:
		if villager.get("paired", false) or villager.get("is_kid", false):
			continue
		# The Ten are LEGENDS, not settlers (dev sweep 2026-07-23): without this,
		# pressing E on a cottage could draft Maera or Brannoc as a parent -- paired
		# for life, avatar removed, pulled into the cradle cycle. The Unbreakables
		# walk the village; they don't disappear into a cottage to start a family.
		if villager.get("unbreakable", false):
			continue
		# 5.8: a widow(er) cannot be re-paired until the mourning has passed
		if villager.has("widowed_at_hours") and game_hours < float(villager["widowed_at_hours"]) + WIDOW_MOURN_HOURS:
			continue
		if villager.get("sex") == "Male" and male_id == "":
			male_id = villager.get("id", "")
		elif villager.get("sex") == "Female" and female_id == "":
			female_id = villager.get("id", "")
	return {"male_id": male_id, "female_id": female_id}

func start_pairing(house_id: String, male_id: String, female_id: String) -> void:
	mating_houses[house_id] = {"male_id": male_id, "female_id": female_id, "remaining_hours": COTTAGE_OCCUPANCY_HOURS}
	for villager in rescued_villagers:
		if villager.get("id") == male_id:
			villager["paired"] = true
			villager["partner_id"] = female_id   # 5.8: pairs are for life
		elif villager.get("id") == female_id:
			villager["paired"] = true
			villager["partner_id"] = male_id
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
		# 5.8: the cradle IS the home. The cottage they united in is theirs
		# for life -- it never returns to the free pool while both live.
		cottage_homes[house_id] = {"a": pairing.male_id, "b": pairing.female_id}
		log_event("people", "%s and %s made a cottage their home." % [villager_name(pairing.male_id), villager_name(pairing.female_id)])
		var pregnancy_id = _mint_birth_id("preg")
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
	# (5.8: pairs are permanent -- birth no longer dissolves the marriage; the
	# couple keeps their cottage and update_cottage_families keeps the cradle)
	var child_sex = "Male" if randi() % 2 == 0 else "Female"
	var child_name = CHILD_NAMES[randi() % CHILD_NAMES.size()]
	var child_id = _mint_birth_id("child")
	var child := {
		"id": child_id, "name": child_name, "sex": child_sex, "is_kid": true,
		"stat_name": "", "stat_value": 0, "role_key": "", "role_title": "", "paired": false,
		"parents": [pairing.male_id, pairing.female_id],   # sleeps under their roof (5.8)
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
	if child.get("hero", false):
		log_event("people", "★ %s was born a HERO — the Barracks awaits them." % child_name)
	else:
		log_event("people", "%s and %s had a child — welcome, %s." % [villager_name(str(pairing.male_id)), villager_name(str(pairing.female_id)), child_name])
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

# --- THE TEN (GAME_BIBLE §8) ---
# Live state per capstone hostage: {"freed": bool}. Freeing one grants its
# permanent village boon (checked via ten_freed at each system's hook) and the
# legend joins the roster as a walking villager. All ten freed is part of the
# finale gate (§9.1): floor 100 will not open while any still hangs.
var the_ten: Dictionary = {}

# --- THE HARVEST (GAME_BIBLE 9.3) ---
# At the gate of 100 the truth is the weapon: the whole village turns at once --
# every farmer, child and soldier becomes level-100 despair. No survivors, no
# loyal holdouts... except the Ten. The roster empties into harvested_villagers
# (a snapshot the Shadow Army will raise, 9.6) and only the unbreakable remain.
var harvest_done := false
var harvested_villagers: Array = []

# --- THE SHADOW COURT (GAME_BIBLE 11) ---
# "Sieges are over -- Despair is dead." Set at the final victory, per-run,
# saved: the raiders were never random monsters, they were Orin's farming
# apparatus, and the apparatus dies with the farmer.
var despair_dead := false

func begin_harvest() -> void:
	if harvest_done:
		return
	harvest_done = true
	var keep := []
	for v in rescued_villagers:
		if v.get("unbreakable", false):
			keep.append(v)
		else:
			harvested_villagers.append(v)
	rescued_villagers = keep
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack:
		stack.show_notification("THE HARVEST: %d souls turn at once. Only the Ten still stand." % harvested_villagers.size())

# The return (9.6): victory breaks the seal, and the first royal act is SHADOW
# ARMY -- every fallen villager rises as a shadow of themselves: names, homes,
# jobs and bonds kept, re-made in shadow-form. The stronger they were in life,
# the stronger the shade. The Ten remain flesh among the shadows.
func raise_shadow_army() -> void:
	var raised := harvested_villagers.size()
	for v in harvested_villagers:
		v["shadow"] = true
		# pledged and needless: raise them whole and content, whatever their
		# fallen state was -- spirit at the top, body mended, no rot clock
		v["morale"] = 10.0
		villager_rot.erase(str(v.get("id", "")))
		villager_hp[str(v.get("id", ""))] = VILLAGER_MAX_HP
		rescued_villagers.append(v)
	harvested_villagers = []
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack and raised > 0:
		stack.show_notification("★ SHADOW ARMY: %d souls rise — themselves, continued. Deepwood stands, and it is yours." % raised)

# If the player quit during the ending dialogue, the army never rose -- the
# debt is settled the moment they next stand in their village. Never fires
# mid-Harvest: despair_dead only becomes true at the final victory.
func settle_shadow_court() -> void:
	if despair_dead and harvested_villagers.size() > 0:
		raise_shadow_army()

# --- NG+ (GAME_BIBLE 11): THE REWOUND HOUR ---
# Among the victory spoils is time-reversal loot: the world rewinds for a new
# run but the player and their gear are immune -- you keep yourself and
# everything you carry. Clean prestige loop.
var ng_plus_cycles := 0
var just_rewound := false      # transient: stamps one arrival line, never saved
# THE TRUE ENDING (11/12): once the player SHATTERS the Rewound Hour instead of
# turning it, the cycle is over for good on this save -- no rewind, and no new
# hourglass is ever granted again. Persisted; a fresh New Game clears it.
var cycle_broken := false

# the Player node's position in main.tscn -- the rewound player wakes where
# every first arrival begins
const VILLAGE_SPAWN = Vector2(-300, -150)

# The pure state turn, separated from the ceremony below so a test can run it
# without touching the save file or the scene tree. "Yourself" is the
# character: level, class, skills, craft-knowledge, worn gear -- and the count
# of worlds walked. Carried gear lives on the player node, which the ceremony
# writes into the save untouched.
func rewind_world_keep_player() -> void:
	var keep_xp = player_xp
	var keep_level = player_level
	var keep_points = skill_points
	var keep_class = chosen_class
	var keep_skills = unlocked_skills.duplicate(true)
	var keep_research = researched_materials.duplicate(true)
	var keep_equipment = equipment.duplicate(true)
	var keep_stage = monarch_stage_announced
	var keep_cycles = ng_plus_cycles + 1
	reset_for_new_game()
	player_xp = keep_xp
	player_level = keep_level
	skill_points = keep_points
	chosen_class = keep_class
	unlocked_skills = keep_skills
	researched_materials = keep_research
	equipment = keep_equipment
	monarch_stage_announced = keep_stage
	ng_plus_cycles = keep_cycles
	just_rewound = true

# --- THE CHRONICLE (GAME_BIBLE 11): the 100% ledger ---
# "100% completion = every villager rescued, every bond quest done, all Ten
# freed, full skill graph explored, village fully restored, Despair destroyed,
# Shadow Army raised." Seven lines, one book, per-run -- NG+ opens a blank one.
var seen_chronicle_100 := false

func chronicle() -> Array:
	var out := []
	# 1. every named soul: the chained figures of the deep + the 12 adventurers
	var fig_total: int = VillagerQuests.IMPORTANT_FIGURES.size()
	var fig_home := 0
	for fd in VillagerQuests.IMPORTANT_FIGURES.values():
		var fid := str(fd.get("villager_id", ""))
		for v in rescued_villagers:
			if str(v.get("id", "")) == fid:
				fig_home += 1
				break
	var adv_total: int = Adventurers.ids().size()
	var adv_found := 0
	for id in Adventurers.ids():
		if bool(adventurer_state(id).get("rescued", false)):
			adv_found += 1
	out.append({"line": "Every taken soul brought home",
		"done": fig_home == fig_total and adv_found == adv_total,
		"detail": "%d/%d figures of the deep, %d/%d adventurers" % [fig_home, fig_total, adv_found, adv_total]})
	# 2. every bond honored
	var bond_total: int = VillagerQuests.QUEST_DEFS.size()
	var bond_done := 0
	for v in rescued_villagers:
		if str(v.get("quest_state", "")) == "done":
			bond_done += 1
	out.append({"line": "Every bond honored",
		"done": bond_done >= bond_total,
		"detail": "%d/%d bonds fulfilled" % [bond_done, bond_total]})
	# 3. the Ten
	out.append({"line": "The Ten walk free",
		"done": all_ten_freed(),
		"detail": "%d/10 freed from Orin's vaults" % count_ten_freed()})
	# 4. the skill graph -- exclusive forks mean one path per crossroads, so
	# "fully explored" is every node a single build can lawfully hold
	var sk_done := false
	var sk_detail := "no calling chosen yet"
	if chosen_class != "":
		var tree: Array = SkillTreeData.TREES.get(chosen_class, [])
		var groups := {}
		var achievable := 0
		var have := 0
		for n in tree:
			var grp := str(n.get("exclusive", ""))
			if grp == "":
				achievable += 1
			else:
				groups[grp] = true
			if is_skill_unlocked(str(n.id)):
				have += 1
		achievable += groups.size()
		sk_done = have >= achievable
		sk_detail = "%d/%d nodes (one path per crossroads)" % [have, achievable]
	out.append({"line": "The skill graph fully explored", "done": sk_done, "detail": sk_detail})
	# 5. the village at its peak (the same three stones the finale gate weighs)
	var ruined := count_ruined_buildings()
	var empty := count_empty_role_slots()
	var peak: bool = village_morale() >= 100
	out.append({"line": "Deepwood restored to its peak",
		"done": ruined == 0 and empty == 0 and peak,
		"detail": "whole, staffed, spirits high" if (ruined == 0 and empty == 0 and peak)
			else "%d ruins, %d empty posts, morale %.1f/10" % [ruined, empty, village_morale_10()]})
	# 6. Despair destroyed
	out.append({"line": "Despair destroyed",
		"done": despair_dead,
		"detail": "the apparatus is dust" if despair_dead else "the Monarch still reigns below"})
	# 7. the Shadow Army
	var army_up: bool = despair_dead and harvested_villagers.is_empty()
	out.append({"line": "The Shadow Army raised",
		"done": army_up,
		"detail": "themselves, continued" if army_up else "the fallen still wait"})
	return out

# One-shot per run: the moment all seven lines hold at once, the book closes.
func chronicle_check_complete() -> void:
	if seen_chronicle_100:
		return
	for row in chronicle():
		if not bool(row.get("done", false)):
			return
	seen_chronicle_100 = true
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack:
		stack.show_notification("⭐ THE CHRONICLE CLOSES COMPLETE — 100%. Every soul home, every bond kept, every stone raised. Deepwood will remember.")

func new_game_plus(player: Node) -> void:
	rewind_world_keep_player()
	# the turn knits you whole, and you wake at the village gate of a world
	# that has never met you
	player.health = player.get_max_health()
	player.mana = player.get_max_mana()
	player.global_position = VILLAGE_SPAWN
	save_game(player)
	pending_load = true
	get_tree().change_scene_to_file.call_deferred("res://main.tscn")

# THE OTHER ROAD (11/12): shatter the Rewound Hour instead of turning it. The
# cycle ends for good -- the flag persists, no further hourglass is ever granted
# (see the guarded victory grants), and the player stays in the won world, which
# will now simply stand. The true-ending dialogue is played by the caller; this
# just makes the world's end permanent. Idempotent.
func break_the_cycle(player: Node = null) -> void:
	if cycle_broken:
		return
	cycle_broken = true
	log_event("people", "The Rewound Hour was shattered. Deepwood will stand, un-rewound, forever — the last cage broken.")
	if player != null:
		save_game(player)

# --- THE FINALE GATE (GAME_BIBLE 9.1) ---
# Level 100 opens only to a PERFECT village -- because a perfect village is
# what Orin has been patiently farming all game. He needs the peak to reap it.
# Four conditions; unmet ones are listed at the door so the player always knows
# what the gate still wants.
func count_ruined_buildings() -> int:
	var ruined := 0
	for b in STARTING_BUILDINGS:
		if not is_building_operational(b):
			ruined += 1
	return ruined

# full employment: every base role slot of every working building staffed
func count_empty_role_slots() -> int:
	var empty_slots := 0
	for b in STARTING_BUILDINGS:
		if not is_building_operational(b):
			continue
		for rd in BuildingRoles.get_roles(b):
			if rd.get("is_enrollment", false):
				continue
			var holders := 0
			for v in rescued_villagers:
				if str(v.get("role_key", "")) == b and str(v.get("role_title", "")) == str(rd.get("title", "")):
					holders += 1
			empty_slots += maxi(0, int(rd.get("slots", 0)) - holders)
	return empty_slots

func finale_gate_missing() -> Array:
	var missing := []
	var ruined := count_ruined_buildings()
	if ruined > 0:
		missing.append("%d building%s still in ruins" % [ruined, "" if ruined == 1 else "s"])
	var empty_slots := count_empty_role_slots()
	if empty_slots > 0:
		missing.append("%d role slot%s stand empty" % [empty_slots, "" if empty_slots == 1 else "s"])
	if village_morale() < 100:
		missing.append("the village is not at perfect morale (%.1f / 10)" % village_morale_10())
	if not all_ten_freed():
		missing.append("%d of the Ten still hang in Orin's vaults" % (10 - count_ten_freed()))
	return missing

func finale_gate_open() -> bool:
	return finale_gate_missing().is_empty()

func ensure_the_ten() -> void:
	for id in TheTen.ids():
		if not the_ten.has(id):
			the_ten[id] = {"freed": false}

func ten_freed(id: String) -> bool:
	ensure_the_ten()
	return bool(the_ten.get(id, {}).get("freed", false))

func count_ten_freed() -> int:
	ensure_the_ten()
	var n := 0
	for id in the_ten.keys():
		if the_ten[id]["freed"]:
			n += 1
	return n

func all_ten_freed() -> bool:
	return count_ten_freed() >= TheTen.ids().size()

func free_one_of_the_ten(id: String) -> void:
	ensure_the_ten()
	if not the_ten.has(id) or the_ten[id]["freed"]:
		return
	the_ten[id]["freed"] = true
	var def = TheTen.get_def(id)
	log_event("people", "★ %s, %s, walks free of Orin's vaults." % [def.get("name", "?"), def.get("title", "")])
	# the legend walks the village from now on -- unbreakable, and visibly so
	rescued_villagers.append({
		"id": id, "name": "%s, %s" % [def.get("name", "?"), def.get("title", "")],
		"sex": "Female" if id in ["ten_maera", "ten_sylvara", "ten_elenwe", "ten_mirielle", "ten_seraphel"] else "Male",
		"is_kid": false, "stat_name": "Legend", "stat_value": 10,
		"role_key": "", "role_title": "", "paired": false, "unbreakable": true,
	})
	# Elenwe's boon lands the moment she is freed: everything unknown, understood
	if id == "ten_elenwe":
		research_all_materials()
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack:
		stack.show_notification("★ %s, %s is FREE. %s (%d of the Ten stand with Deepwood.)" % [
			def.get("name", "?"), def.get("title", ""), def.get("boon", ""), count_ten_freed()])
	# THE GIFT (9.7): when the last of the Ten stands free, together they hand
	# over the one weapon that matters -- Elenwe knew WHAT it was, Toren reforged
	# it, Ilo remembered WHY. (Quest placement is 12's open question; until the
	# dev sites it elsewhere, the Ten themselves are the quest.)
	if all_ten_freed():
		var player = get_tree().get_first_node_in_group("player")
		if player and "inventory" in player and player.inventory and player.inventory.get_count("wpn_soulsplit") == 0:
			player.inventory.add_item("wpn_soulsplit", 1)
			if stack:
				stack.show_notification("★★ The Ten gather. Elenwe: \"An undivided soul cannot be destroyed. So...\" — Toren presses the SOUL SPLIT WAND into your hands — \"...divide it.\"")

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

# Saves made before the starting-six existed have no Doctor and no farmhands --
# and nothing else can ever create them, so an old playthrough would simply
# lack the 5.5a healing lifeline forever. Called ONLY for saves fingerprinted
# as pre-Doctor (no doctor_heals_bought key), so a newer save that lost her to
# a siege keeps its dead -- migration never resurrects anyone.
func _migrate_starting_civilians() -> void:
	var has_healer := false
	var have_ids := {}
	for v in rescued_villagers:
		if v.get("healer", false):
			has_healer = true
		have_ids[str(v.get("id", ""))] = true
	if not has_healer and not have_ids.has("doctor_maren"):
		rescued_villagers.append({
			"id": "doctor_maren", "name": "Doctor Maren Hollis", "sex": "Female", "is_kid": false,
			"stat_name": "Hospital", "stat_value": 4, "role_key": "", "role_title": "", "paired": false,
			"healer": true,
		})
	for farmer in [["farmer_tam", "Tam Beckett", "Male"], ["farmer_ada", "Ada Brook", "Female"]]:
		if not have_ids.has(farmer[0]):
			rescued_villagers.append({
				"id": farmer[0], "name": farmer[1], "sex": farmer[2], "is_kid": false,
				"stat_name": "Farm", "stat_value": 2, "role_key": "", "role_title": "", "paired": false,
			})

func decay_doctor_price(hours_passed: float) -> void:
	if doctor_heals_bought <= 0:
		return
	_doctor_decay_accum += hours_passed
	# Maera, the Last Lightmender (the Ten): the price mends twice as fast
	var step: float = DOCTOR_DECAY_HOURS * (0.5 if ten_freed("ten_maera") else 1.0)
	while _doctor_decay_accum >= step and doctor_heals_bought > 0:
		_doctor_decay_accum -= step
		doctor_heals_bought -= 1

func enroll_villager(villager_id: String, role_key: String, role_title: String, grants_stat: String) -> void:
	# A hero child refuses the School outright -- books cannot hold what they
	# are. Only the Barracks can. (The UI filters them out too; this guard is
	# for any other path that reaches enrollment.)
	var v = find_villager_by_id(villager_id)
	# Nobody home, nobody enrolled (dev sweep 2026-07-23): a stale UI click --
	# assign fired the instant that villager died -- otherwise planted a GHOST
	# enrollment that ticked the full term and graduated no one.
	if v.is_empty():
		return
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
		granted_stat = roll_regular_stat()   # the weighted role roll (5.4)
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
				log_event("people", "★ %s finished barracks training — a HERO of the %s stands among you." % [
					villager.get("name", "?"), HERO_POWERS[power]])
			else:
				log_event("people", "%s finished school — a %s now." % [villager.get("name", "?"), granted_stat])

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
	underdark_vaults_open = []
	mating_houses = {}
	cottage_homes = {}
	extra_cottages = 0
	extra_cottage_positions = []
	extra_cottage_ids = []
	cottage_id_seq = 0
	placed_walls = []
	tutorial_step = -1
	_family_cycle_accum = 0.0
	village_log = []
	log_unread = 0
	wage_accum_hours = 0.0
	villager_rot = {}
	wanderer = {}
	wanderer_next_at_hours = 8.0
	wanderers_seen = 0
	watchtower_tier = 0
	_tower_bell_armed = true
	_mine_accum = 0.0
	_mine_cycles = 0
	blueprints = BLUEPRINT_STARTERS.duplicate()
	building_positions = {}
	moving_building = ""
	pregnancies = {}
	school_enrollments = {}
	highest_unlocked_level = 999 if TEST_UNLOCK_ALL_LEVELS else 1
	floors_cleared = {}                        # a new run's deep is unswept
	waystone_unlocked = false                  # the Waystone is re-earned at floor 20
	village_last_hours_elapsed = 0.0
	game_hours = 0.0
	hours_until_next_siege = SIEGE_FIRST_HOURS
	live_siege_active = false
	away_report = {"sieges": 0, "repelled": 0, "villagers_lost": 0, "adventurers_lost": 0}
	# The village starts in ruins -- every building begins destroyed (health 0)
	# and must be repaired before its roles work.
	building_health = {}
	building_stage = {}
	building_cleared = {}
	for bn in STARTING_BUILDINGS:
		building_health[bn] = 0
		building_stage[bn] = 0
		building_cleared[bn] = 0
	building_levels = {}
	wall_level = 1
	removed_buildings = {}
	wizard_respawn_at_hours = -1.0
	placed_torches = []
	morale_death_shock = 0.0
	morale_meter_unlocked = false
	low_morale_hours = 0.0
	villager_hp = {}
	barracks_arms = 0
	seen_intro = false
	seen_l100_reveal = false
	# Every per-run story one-shot must rewind with the world, or a second
	# playthrough plays mute: Orin never introduces himself, the Doctor never
	# tells her account, the plants never plant.
	seen_orin_arrival = false
	seen_doctor_account = false
	seen_failed_escape = false
	seen_orin_glimpse = false
	seen_kneel_echo = false
	seen_orin_taunt = false
	seen_gather_hint = false
	seen_arrival_battle = false
	seen_arrival_talk = false
	opening_done = false
	seen_empty_throne = false
	harvest_at_home = false
	feast_glow = false
	escape_attempts = 0
	school_favoured_stat = ""
	# The Ten wait in their cages again, and the Harvest has not happened --
	# without these a second run starts with every boon active, no vaults to
	# find, and a finale that begin_harvest() refuses to start.
	the_ten = {}
	ensure_the_ten()
	harvest_done = false
	harvested_villagers = []
	despair_dead = false
	_gold_accum = 0.0
	ng_plus_cycles = 0
	cycle_broken = false
	seen_chronicle_100 = false
	maera_stabilized_this_siege = false
	_deep_catch_accum = 0.0
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
	selfsuf_celebrated = []   # a fresh run earns every "your day is your own" beat again
	_peril_band = -1          # the fading-of-Deepwood dread starts quiet
	village_lost = false
	lost_souls = []
	has_whisperstone = false  # the Lab's far-speaker must be built anew each run
	sieges_seen = 0           # the Black Tide count restarts with the run
	_black_omen_armed = true

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game(player: Node) -> void:
	var save_pos = pre_dungeon_position if in_dungeon else player.global_position
	# Continue must land on the SURFACE, never in the Underdark (which lives in the
	# village scene). in_dungeon saves pre_dungeon_position -- but with doors-only
	# access that IS a deep Underdark door, and a plain walk in the caves saves the
	# live deep position. Either would drop the player underground on load (and into
	# the void before the deep is built). Persist a safe village spawn instead; the
	# in-session floor exit still uses the live pre_dungeon_position, unaffected.
	if save_pos.y > 250.0:
		save_pos = VILLAGE_SPAWN
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
		"the_ten": the_ten,
		"harvest_done": harvest_done,
		"despair_dead": despair_dead,
		"ng_plus_cycles": ng_plus_cycles,
		"cycle_broken": cycle_broken,
		"seen_chronicle_100": seen_chronicle_100,
		"harvested_villagers": harvested_villagers,
		"seen_orin_arrival": seen_orin_arrival,
		"seen_doctor_account": seen_doctor_account,
		"seen_failed_escape": seen_failed_escape,
		"seen_orin_glimpse": seen_orin_glimpse,
		"seen_kneel_echo": seen_kneel_echo,
		"seen_orin_taunt": seen_orin_taunt,
		"seen_arrival_battle": seen_arrival_battle,
		"seen_arrival_talk": seen_arrival_talk,
		"opening_done": opening_done,
		"seen_empty_throne": seen_empty_throne,
		"escape_attempts": escape_attempts,
		"school_favoured_stat": school_favoured_stat,
		"chest_contents": chest_contents,
		"underdark_vaults_open": underdark_vaults_open,
		"mating_houses": mating_houses,
		"cottage_homes": cottage_homes,
		"extra_cottages": extra_cottages,
		"extra_cottage_positions": extra_cottage_positions,
		"extra_cottage_ids": extra_cottage_ids,
		"cottage_id_seq": cottage_id_seq,
		"placed_walls": placed_walls,
		"tutorial_step": tutorial_step,
		"village_log": village_log,
		"log_unread": log_unread,
		"wage_accum_hours": wage_accum_hours,
		"villager_rot": villager_rot,
		"wanderer": wanderer,
		"wanderer_next_at_hours": wanderer_next_at_hours,
		"wanderers_seen": wanderers_seen,
		"watchtower_tier": watchtower_tier,
		"blueprints": blueprints,
		"building_positions": building_positions,
		"pregnancies": pregnancies,
		"school_enrollments": school_enrollments,
		"highest_unlocked_level": highest_unlocked_level,
		"floors_cleared": floors_cleared,
		"waystone_unlocked": waystone_unlocked,
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
		"building_cleared": building_cleared,
		"building_levels": building_levels,
		"wall_level": wall_level,
		"removed_buildings": removed_buildings,
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
		"selfsuf_celebrated": selfsuf_celebrated,
		"lost_souls": lost_souls,
		"village_lost": village_lost,
		"has_whisperstone": has_whisperstone,
		"sieges_seen": sieges_seen,
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
			# only saves from BEFORE the Doctor existed get her seeded -- a
			# newer save that lost her to a siege keeps its dead. The
			# doctor_heals_bought key shipped in the same commit she did, so
			# its absence is the exact fingerprint of a pre-Doctor save.
			if not parsed.has("doctor_heals_bought"):
				_migrate_starting_civilians()
		if parsed.has("adventurers"):
			adventurers = parsed["adventurers"]
			ensure_adventurers()   # a newer build may know MORE adventurers than the save
		doctor_heals_bought = int(parsed.get("doctor_heals_bought", 0))
		if parsed.has("the_ten"):
			the_ten = parsed["the_ten"]
			ensure_the_ten()
		harvest_done = bool(parsed.get("harvest_done", false))
		despair_dead = bool(parsed.get("despair_dead", false))
		ng_plus_cycles = int(parsed.get("ng_plus_cycles", 0))
		cycle_broken = bool(parsed.get("cycle_broken", false))
		seen_chronicle_100 = bool(parsed.get("seen_chronicle_100", false))
		harvested_villagers = parsed.get("harvested_villagers", [])
		seen_orin_arrival = bool(parsed.get("seen_orin_arrival", false))
		seen_doctor_account = bool(parsed.get("seen_doctor_account", false))
		seen_failed_escape = bool(parsed.get("seen_failed_escape", false))
		seen_orin_glimpse = bool(parsed.get("seen_orin_glimpse", false))
		seen_kneel_echo = bool(parsed.get("seen_kneel_echo", false))
		seen_orin_taunt = bool(parsed.get("seen_orin_taunt", false))
		seen_arrival_battle = bool(parsed.get("seen_arrival_battle", true))   # old saves: don't replay
		seen_arrival_talk = bool(parsed.get("seen_arrival_talk", seen_arrival_battle))   # old saves heard it with the battle
		opening_done = bool(parsed.get("opening_done", true))   # old saves are long past the opening
		seen_empty_throne = bool(parsed.get("seen_empty_throne", false))
		escape_attempts = int(parsed.get("escape_attempts", 0))
		school_favoured_stat = str(parsed.get("school_favoured_stat", ""))
		if parsed.has("chest_contents"):
			chest_contents = parsed["chest_contents"]
		if parsed.has("underdark_vaults_open"):
			# JSON numbers load as floats -- normalise to int band indices so
			# underdark_vaults_open.has(band) matches an int band cleanly
			underdark_vaults_open = []
			for v in parsed["underdark_vaults_open"]:
				underdark_vaults_open.append(int(v))
		if parsed.has("mating_houses"):
			mating_houses = parsed["mating_houses"]
		if parsed.has("cottage_homes"):
			cottage_homes = parsed["cottage_homes"]
		extra_cottages = int(parsed.get("extra_cottages", 0))
		extra_cottage_positions = []
		if parsed.has("extra_cottage_positions") and parsed["extra_cottage_positions"] is Array:
			for cx in parsed["extra_cottage_positions"]:
				extra_cottage_positions.append(float(cx))
		# STABLE cottage ids (dev 2026-07-23). Older saves have none -- synth them as the
		# legacy "menu_house_%d" % j so their existing cottage_homes keys still resolve,
		# and start the seq past them so a NEW build can never collide a migrated id.
		extra_cottage_ids = []
		if parsed.has("extra_cottage_ids") and parsed["extra_cottage_ids"] is Array:
			for cid in parsed["extra_cottage_ids"]:
				extra_cottage_ids.append(str(cid))
		# give every reload slot a stable id: cover both the stored positions and the
		# saved count (a very old save could carry end-of-row cottages with no position).
		var want_ids: int = maxi(extra_cottages, extra_cottage_positions.size())
		while extra_cottage_ids.size() < want_ids:
			extra_cottage_ids.append("menu_house_%d" % extra_cottage_ids.size())
		extra_cottages = extra_cottage_ids.size()          # count, ids and (>=) positions agree
		cottage_id_seq = int(parsed.get("cottage_id_seq", extra_cottage_ids.size()))
		cottage_id_seq = maxi(cottage_id_seq, extra_cottage_ids.size())
		placed_walls = []
		if parsed.has("placed_walls") and parsed["placed_walls"] is Array:
			for w in parsed["placed_walls"]:
				if w is Dictionary and w.has("x"):
					placed_walls.append({"x": float(w["x"]), "flank": str(w.get("flank", "west"))})
		tutorial_step = int(parsed.get("tutorial_step", -1))
		if parsed.has("village_log") and parsed["village_log"] is Array:
			village_log = parsed["village_log"]
		log_unread = int(parsed.get("log_unread", 0))
		wage_accum_hours = float(parsed.get("wage_accum_hours", 0.0))
		villager_rot = {}
		if parsed.has("villager_rot") and parsed["villager_rot"] is Dictionary:
			for k in parsed["villager_rot"].keys():
				villager_rot[k] = float(parsed["villager_rot"][k])
		wanderer = parsed.get("wanderer", {}) if parsed.get("wanderer", {}) is Dictionary else {}
		wanderer_next_at_hours = float(parsed.get("wanderer_next_at_hours", 8.0))
		wanderers_seen = int(parsed.get("wanderers_seen", 0))
		watchtower_tier = int(parsed.get("watchtower_tier", 0))
		# old saves know every blueprint -- never brick a mid-run town
		if parsed.has("blueprints") and parsed["blueprints"] is Array:
			blueprints = parsed["blueprints"]
		else:
			blueprints = STARTING_BUILDINGS.duplicate()
		# the Cottage blueprint is a given (dev 2026-07-22) -- grant it to any save
		# from before it existed, so building homes from the menu always works
		if not ("Cottage" in blueprints):
			blueprints.append("Cottage")
		building_positions = {}
		if parsed.has("building_positions") and parsed["building_positions"] is Dictionary:
			for k in parsed["building_positions"].keys():
				building_positions[k] = float(parsed["building_positions"][k])
		if parsed.has("pregnancies"):
			pregnancies = parsed["pregnancies"]
		if parsed.has("school_enrollments"):
			school_enrollments = parsed["school_enrollments"]
		if parsed.has("highest_unlocked_level"):
			highest_unlocked_level = int(parsed["highest_unlocked_level"])
		if parsed.has("floors_cleared") and parsed["floors_cleared"] is Dictionary:
			floors_cleared = parsed["floors_cleared"]
		waystone_unlocked = bool(parsed.get("waystone_unlocked", false))
		if TEST_UNLOCK_ALL_LEVELS:
			highest_unlocked_level = max(highest_unlocked_level, 999)
		player_xp = int(parsed.get("player_xp", player_xp))
		player_level = int(parsed.get("player_level", player_level))
		monarch_stage_announced = monarch_stage()   # already-reached stages don't re-toast
		skill_points = int(parsed.get("skill_points", skill_points))
		chosen_class = parsed.get("chosen_class", chosen_class)
		unlocked_skills = parsed.get("unlocked_skills", unlocked_skills)
		researched_materials = parsed.get("researched_materials", researched_materials)
		if parsed.has("equipment"):
			load_equipment(parsed["equipment"])
		game_hours = float(parsed.get("game_hours", 0.0))
		hours_until_next_siege = float(parsed.get("hours_until_next_siege", SIEGE_FIRST_HOURS))
		live_siege_active = false
		# Continue loads you standing in the VILLAGE -- but GameState is an autoload
		# that survives Quit-to-Menu, so transient run-flags from the pre-menu
		# session leak in (reset_for_new_game clears these; load_game must too).
		# Without this, quitting inside a dungeon left in_dungeon=true (live sieges
		# silently resolved off-screen, arrival suppressed); quitting mid-Harvest
		# left harvest_at_home/feast_glow set (finale soft-lock / morale pinned 100).
		in_dungeon = false
		harvest_at_home = false
		feast_glow = false
		_warned_no_food = false
		_warned_low_morale = false
		# start the village-clock baseline at the loaded time so the first
		# tick after loading doesn't see a giant false "hours passed".
		village_last_hours_elapsed = game_hours
		if parsed.has("away_report") and parsed["away_report"] is Dictionary:
			var ar = parsed["away_report"]
			away_report = {
				"sieges": int(ar.get("sieges", 0)),
				"repelled": int(ar.get("repelled", 0)),
				"villagers_lost": int(ar.get("villagers_lost", 0)),
				"adventurers_lost": int(ar.get("adventurers_lost", 0)),
			}
			# the homecoming lines need these too -- kept optional, exactly as the
			# runtime writes them (only when someone actually fell / was saved)
			if ar.has("fallen_names") and ar["fallen_names"] is Array:
				away_report["fallen_names"] = ar["fallen_names"].duplicate()
			if ar.has("stabilized"):
				away_report["stabilized"] = int(ar.get("stabilized", 0))
		if parsed.has("building_health") and parsed["building_health"] is Dictionary:
			building_health = {}
			for k in parsed["building_health"].keys():
				building_health[k] = int(parsed["building_health"][k])
		if parsed.has("building_levels") and parsed["building_levels"] is Dictionary:
			building_levels = {}
			for k in parsed["building_levels"].keys():
				building_levels[k] = int(parsed["building_levels"][k])
		if parsed.has("wall_level"):
			wall_level = clampi(int(parsed["wall_level"]), 1, WALL_MAX_LEVEL)
		if parsed.has("removed_buildings") and parsed["removed_buildings"] is Dictionary:
			removed_buildings = {}
			for k in parsed["removed_buildings"].keys():
				removed_buildings[k] = true
		if parsed.has("building_stage") and parsed["building_stage"] is Dictionary:
			building_stage = {}
			for k in parsed["building_stage"].keys():
				building_stage[k] = int(parsed["building_stage"][k])
		if parsed.has("building_cleared") and parsed["building_cleared"] is Dictionary:
			building_cleared = {}
			for k in parsed["building_cleared"].keys():
				building_cleared[k] = int(parsed["building_cleared"][k])
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
		selfsuf_celebrated = parsed.get("selfsuf_celebrated", [])
		lost_souls = parsed.get("lost_souls", [])
		village_lost = bool(parsed.get("village_lost", false))
		has_whisperstone = bool(parsed.get("has_whisperstone", false))
		sieges_seen = int(parsed.get("sieges_seen", 0))
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
	lost_souls.erase(str(data.get("id", "")))   # a soul brought home is no longer lost
	# personal bond (VillagerQuests): if this named villager has a quest, it
	# starts active the moment they're freed.
	if VillagerQuests.has_quest(str(data.get("id", ""))):
		data["quest_state"] = "active"
		data["quest_progress"] = 0
	rescued_villagers.append(data)
	log_event("people", "%s, freed from the dark, reached the village." % str(data.get("name", "A stranger")))
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
					# the reunion itself gets a voice at the moment it happens --
					# the freed sister knows who waited for her
					var stack = get_tree().get_first_node_in_group("notification_stack")
					if stack:
						var giver_name := str(v.get("name", "someone"))
						stack.show_notification("\"%s — she's alive? Take me home.\" (Return to %s.)" % [giver_name, giver_name])

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
	# where the body fell decides who WITNESSED it (10's outward shock wave)
	var death_pos := Vector2(INF, INF)
	for npc in get_tree().get_nodes_in_group("npc"):
		if "villager_id" in npc and str(npc.villager_id) == villager_id:
			death_pos = npc.global_position
			break
	villager_rot.erase(villager_id)
	villager_hp.erase(villager_id)   # clear HP too, or dead ids pile up in the save
	for entry in rescued_villagers:
		if entry.get("id") == villager_id:
			rescued_villagers.erase(entry)
			register_villager_deaths(1, death_pos)   # every villager lost grieves the town
			log_event("people", "%s is gone. Deepwood grieves." % str(entry.get("name", "Someone")))
			# a fallen leadership figure is lost FOREVER -- they never wait in the
			# dark to be freed again, so the finite rescue pool can truly empty
			if is_important_figure(villager_id) and not lost_souls.has(villager_id):
				lost_souls.append(villager_id)
				log_event("people", "%s will not be found in the dark again — that post is lost for good." % str(entry.get("name", "A leader")))
			break
	# 5.8: widowhood. The survivor's partner-link breaks, the -3 grief lands
	# now and decays across the mourning window, and only after ~48h can they
	# be paired again. Their cottage is freed below -- a home needs its pair.
	for v in rescued_villagers:
		if str(v.get("partner_id", "")) == villager_id:
			v["partner_id"] = ""
			v["paired"] = false
			v["widowed_at_hours"] = game_hours
			v["morale"] = clampf(get_personal_morale(v) - WIDOW_MORALE_HIT, 0.0, 10.0)
	for hid in cottage_homes.keys():
		var home: Dictionary = cottage_homes[hid]
		if str(home.get("a", "")) == villager_id or str(home.get("b", "")) == villager_id:
			cottage_homes.erase(hid)
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
# Returns true if someone was actually taken -- with only unbreakables (the Ten)
# left it takes nobody, and callers who COUNT losses must know (honest away report).
func remove_random_villager() -> bool:
	if rescued_villagers.is_empty():
		return false
	# 5.8: the Ten cannot be taken by anything -- not despair, not your death
	var takeable := []
	for v in rescued_villagers:
		if not v.get("unbreakable", false):
			takeable.append(v)
	if takeable.is_empty():
		return false
	var removed = takeable[randi() % takeable.size()]
	remove_villager_by_id(removed.get("id"))
	return true

# THE DEATH TOLL (polish 2026-07-20): on Medium a death costs a villager
# and on Hard a skill material too -- the harshest mechanic in the game,
# and it happened in complete SILENCE. The player respawned, and hours
# later noticed someone missing with no idea their own death had done it.
# Name the cost, out loud, at the moment it is paid.
# What the latest death cost, for the death screen itself -- the toast
# alone played BEHIND the death overlay, so the harshest news went unseen.
var last_death_toll := ""

func report_death_toll(difficulty_name: String) -> void:
	if rescued_villagers.is_empty():
		return
	var takeable := []
	for v in rescued_villagers:
		if not v.get("unbreakable", false):
			takeable.append(v)
	if takeable.is_empty():
		return
	var doomed: Dictionary = takeable[randi() % takeable.size()]
	var who := str(doomed.get("name", "Someone"))
	remove_villager_by_id(str(doomed.get("id", "")))
	last_death_toll = "%s is gone — the price of your death. (%s)" % [who, difficulty_name]
	log_event("people", "%s was lost while you lay dying in the deep." % who)
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack:
		stack.show_notification("💀 Your death cost Deepwood a life: %s is gone. (%s difficulty)" % [who, difficulty_name])

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
