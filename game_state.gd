extends Node

const SAVE_PATH = "user://savegame.json"

# THE DEV'S REAL SAVE IS NOT A TEST FIXTURE (global hunt 2026-07-28).
# autosave() was already MONARCH_TEST-gated, but three suites call
# save_game() DIRECTLY (save / cleared / savespawn) -- so every suite run,
# from any parallel session, banked test fiction over the real playthrough.
# Under a test harness every save byte now goes to a sidecar instead; the
# suites still exercise the real save/load code end to end.
func active_save_path() -> String:
	if OS.has_environment("MONARCH_TEST"):
		return "user://savegame_test.json"
	return SAVE_PATH
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
	var was_cleared := floors_cleared.has(str(level))
	floors_cleared[str(level)] = true
	# a FRESH clear extends the no-death streak (the Sleepless Warden's trigger).
	# Guarded on first-clear so a re-mark can't inflate it, and hooked HERE rather
	# than on quest_event("reach_level") -- that one also fires on floor ARRIVAL,
	# which would have counted entering a floor as clearing it.
	if not was_cleared:
		note_floor_cleared_event()

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
# The admin GOD MODE toggle, held at session level because the Player node is
# re-instanced on every scene change and a field on it dies at every door.
# Deliberately NOT saved to disk: a testing switch should never ride along into
# a real save file. (2026-07-30)
var god_mode := false

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

# --- Harvest-node persistence (audit fix) ------------------------------------
# Trees and ore seams used to be runtime-only: every rebuild of main.tscn (any
# dungeon round trip) regrew the whole world to full, an unbounded materials
# farm that sidestepped the 150s/420s regrow clocks. The village-area jitter is
# now seeded per run so each node has a stable identity, and any TOUCHED node
# records itself here (see harvest_node.gd): id -> {hits, reserve, depleted,
# size_mult, regrow_at}. regrow_at is a game-hours deadline, so time away
# counts toward the regrow. Untouched (full) nodes carry no entry.
var harvest_seed := 0
var harvest_states: Dictionary = {}

# Rampart wounds by flank ("west"/"east" -> hp; absent = whole). Audit fix:
# wall HP was runtime-only, so any scene rebuild repaired a breached wall free.
var wall_hp: Dictionary = {}

func ensure_harvest_seed() -> int:
	if harvest_seed == 0:
		harvest_seed = randi() | 1   # never 0, so "unset" stays distinguishable
	return harvest_seed

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
# TERRARIA UNDERGROUND (2026-07-25): true when a floor was entered from the tile
# underground (vs the village), so exiting that floor returns you to the
# underground at the door instead of the village. Transient.
var came_from_underground := false
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
# THE SUMMON LEDGER (Summoner batch 1, 2026-07-30). Which minions are standing
# right now, as [{scepter_id, kind}]. The pack persists across weapon swaps
# and floors -- the scepter only has to stay in the bag -- so it cannot live on
# the Player node, which is re-instanced on every dungeon entry/exit.
# Saved with a [] default so old saves load clean (the house pattern).
var active_summons: Array = []
# THE WATCH ETERNAL (Wallwarden keystone) lets posts REDEPLOY themselves when
# you change floors. Posts are scene nodes and die with the scene, so the ones
# worth keeping are remembered here as [{s_kind, damage, gap, source_id}].
var active_posts: Array = []
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
# TWELVE relic slots (dev 2026-07-28: "about 12 relic space max, starting
# with 6 and unlocking slowly"): 6 from the first breath, then one more every
# ten levels until all 12 stand open at level 60.
const RELIC_MAX_SLOTS = 12
# The ONE list of gear slots. Everything that walks slots reads these, so adding
# a slot can't leave a stale copy behind -- which is exactly how gloves/boots got
# dropped from reset_for_new_game and blew up every stat query on a new game.
# THREE SLOTS, TERRARIA-EXACT (dev 2026-07-28: "player has only helmet,
# breastplate and leggins, change it like that for our game too"). Gloves and
# boots slots are RETIRED; their stat identity folds into the 3-piece armor
# sets in the overhaul. Legacy gloves/boots ITEMS survive as bag curios
# (equip_item refuses unknown slots gracefully), and a save that had them
# EQUIPPED gets them handed back to the bag on load (see load_game).
const ARMOUR_SLOTS = ["helmet", "chest", "pants"]
# "weapon" removed by the audit: the hotbar migration left it as a vestige --
# allocated, saved, walked by every gear loop -- yet UNFILLABLE (is_equippable
# only ever admits armor/relic, so equip_item rejected weapons at line one).
# A live trap for anyone re-adding weapon gear: wire is_equippable + the
# equipment_ui slot together with it if that day comes.
const GEAR_SLOTS = ["helmet", "chest", "pants"]
const RETIRED_SLOTS = ["gloves", "boots"]   # read ONLY by the load migration

static func empty_equipment() -> Dictionary:
	var e := {}
	for s in GEAR_SLOTS:
		e[s] = ""
	var r: Array = []
	r.resize(RELIC_MAX_SLOTS)
	r.fill("")
	e["relics"] = r
	return e

var equipment = empty_equipment()

func relic_slot_count() -> int:
	if TEST_SKILL_SANDBOX:
		return RELIC_MAX_SLOTS   # testing: every relic slot usable at any level
	# 6 to start, +1 per ten levels: 7 at 10 ... 12 at 60
	return clampi(6 + int(player_level / 10.0), 6, RELIC_MAX_SLOTS)

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
	return get_skill_total(effect_key) + get_equipment_total(effect_key) + get_set_bonus_total(effect_key) + get_weapon_passive_total(effect_key) + monarch_bonus(effect_key) + found_bonus(effect_key)

# ── LIFE CRYSTALS ─────────────────────────────────────────────────────────────
# Every other term above is DERIVED -- unequip the gear, respec the tree, and it
# is gone. This one is earned and kept: Terraria's Life Crystals, dug out of the
# deep and permanently yours (underground.gd places them, GameState counts them).
#
# BALANCE: the endgame curves are tuned around a 160 HP player, so this is
# deliberately far short of Terraria's ratio (100 -> 400, four-fold). Twelve
# crystals at +12 takes 160 -> 304, under double, and every one of them has to be
# found in a biome deep enough to be dangerous.
const LIFE_CRYSTAL_HP := 12
const LIFE_CRYSTALS_MAX := 12
var life_crystals: int = 0

func found_bonus(effect_key: String) -> float:
	if effect_key == "max_health":
		return float(mini(life_crystals, LIFE_CRYSTALS_MAX) * LIFE_CRYSTAL_HP)
	return 0.0

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
	else:
		if not equipment.has(slot):
			return
		item_id = equipment[slot]
	# put the piece back in the bag FIRST -- if it's full, refuse rather than DESTROY a
	# (possibly mythic) relic/armor piece. Every other caller checks add_item's leftover.
	if item_id != "":
		var left: int = player.inventory.add_item(item_id, 1)
		if left > 0:
			notify("Your bag is full — make room before unequipping.")
			return
	# only now vacate the slot (the piece is safely in the bag)
	if slot == "relic":
		equipment.relics[relic_index] = ""
	else:
		equipment[slot] = ""
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
	# RETIRED SLOTS (Terraria-exact armor, 2026-07-28): a save from the
	# five-slot era may have gloves/boots EQUIPPED -- those items left the bag
	# when they were worn, so dropping the slot would silently delete them.
	# Hand them back to the bag instead.
	for slot in RETIRED_SLOTS:
		var legacy := str(data.get(slot, ""))
		if legacy != "":
			var pl = get_tree().get_first_node_in_group("player")
			if pl != null and "inventory" in pl and pl.inventory != null:
				pl.inventory.add_item(legacy, 1)
	var relics: Array = []
	relics.resize(RELIC_MAX_SLOTS)
	relics.fill("")
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
	var st := {
		"inventory": player.inventory.to_save_data(),
		"active_weapon_id": player.active_weapon_id,
		"has_dash": player.has_dash,
		"has_double_jump": player.has_double_jump,
		"health": player.health,
		"mana": player.mana,
	}
	# TRANSIENTS THAT MUST SURVIVE THE SWAP (audit fix): a dungeon entry/exit
	# re-instances the Player node, so every relic/skill cooldown re-armed
	# (Phoenix Heart and the once-per-life Living Fortress became once-per-
	# FLOOR exploits) and every food buff was silently destroyed with the
	# potion already spent. The deadlines ride the process clock
	# (ticks_msec), which keeps running across an in-session scene change.
	for f in ["phoenix_ready_at", "aegis_ready_at", "gorgon_ready_at",
			"monarch_long_dark_ready_at", "undying_used", "rampage_stacks",
			"rampage_until"]:
		# rampage_until rides with rampage_stacks or the carry is a no-op: the
		# fresh player's deadline is 0.0, so the first read zeroed the restored
		# stacks before they ever added anything
		if f in player:
			st[f] = player.get(f)
	if "active_buffs" in player:
		st["active_buffs"] = player.active_buffs.duplicate(true)
	return st

# Set once on the New Game / difficulty-picker screen, saved with the game,
# and never changed mid-playthrough. Controls death-penalty severity only
# (see player.gd's die()) -- no other gameplay scaling reads this.
var difficulty = "Medium"

# THE WORLD SEED (2026-07-30). Every noise field and every placement roll in the
# tile underground used to be a hardcoded constant, so every playthrough on every
# machine got a byte-identical map -- the opposite of what a seeded world means.
# Rolled fresh per New Game, saved with the run, and mixed into everything
# underground.gd generates, so a new game is a new world and a loaded game is the
# one you left. 0 means "not rolled yet" (old saves), which reads as the original
# fixed map so an existing run's dug tunnels still line up with its terrain.
var world_seed: int = 0

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
const WAGE_MAX_QUITS_PER_DAY := 2      # a dry purse bleeds staff, never wipes them in one tick
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
# THE WORKERS WORK (dev call 2026-07-29). An audit of the automation ladder found
# three buildings whose WORKER posts were declared, staffable, and never read by
# any game logic -- 30 slots (School "Teachers" 10, Tavern "Barman" 10, Blacksmith
# "Blacksmith" 10) where a player could assign villagers, see them employed, and
# get literally nothing. Staffing a building is supposed to be HOW it runs itself,
# so each now pays its own kind of work, at a lesser rate than the leader who runs
# the place.
const TEACHER_SPEED_PER_HEAD := 0.08    # School: each Teacher speeds graduation
const BARMAN_MORALE_EACH := 0.12        # Tavern: each Barman lifts the room (0-10 scale)
const BARMAN_TRICKLE := 0.06            # Tavern: drink money per Barman (cf BARKEEP_TRICKLE)
const SMITH_ARMS_PER_HEAD := 0.5        # Blacksmith: each smith adds forge throughput

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
# How much unmet threat it takes to cost ONE life when a wave breaks through, and
# the most an ORDINARY wave may ever take (a Black Tide is exempt). See
# resolve_siege_offline for why these exist -- the old 1-life-per-point, uncapped
# rule made town collapse a mathematical certainty.
const SIEGE_SHORTFALL_PER_CASUALTY := 3.0
const SIEGE_MAX_CASUALTIES := 2
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
	# honest on a full bag (the add_item-leftover family, bug hunt 2026-07-28)
	var lost := 0
	if wood > 0:
		lost += player.inventory.add_item("wood", wood)
	if stone > 0:
		lost += player.inventory.add_item("stone", stone)
	if resin > 0:
		lost += player.inventory.add_item("resin", resin)
	if lost > 0:
		notify("Your bag was full — %d pieces of the victory bundle were left behind." % lost)

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
# THE SHRINK (dev law 2026-07-29: "stats not important at all"). This was 0.25 --
# a level-6 building's whole identity was +125% output, and the upgrade UI sold
# that percentage as the reason to spend ~1650 gold. Numbers are now connective
# tissue only: the REASON to raise a building is the named power it wakes at
# BUILDING_POWER_LEVEL (see BUILDING_POWERS), not the trickle of extra output.
const BUILDING_OUTPUT_PER_LEVEL = 0.05   # +5% output per level over level 1
const LONG_NIGHT_MORALE_FLOOR := 25.0    # Tavern power: the town's spirit cannot fall below this

func building_level(name: String) -> int:
	return int(building_levels.get(name, 1))

# ===================== BUILDING POWERS (dev law 2026-07-29) =====================
# "i want stats to be not important at all, transfer their importance to their
# unique behavior." A building's levels used to buy nothing but a percentage --
# the WRONG shape for progression. At BUILDING_POWER_LEVEL every building instead
# wakes a NAMED power that changes what it DOES, and the numeric ladder shrinks to
# connective tissue. The through-line is the automated-city vision: a grown
# building stops needing to be managed.
const BUILDING_POWER_LEVEL := 4
const BUILDING_POWERS := {
	# THE FOUR RE-SCOPED (dev call 2026-07-30: "leader loses its value"). These four
	# used to read "...with no Forgemaster / no Principal / no Chancellor / no Master
	# Builder" -- they replaced the very person they belonged to. Now a power needs
	# its leader IN the chair (has_building_power), so each had to become something
	# that leader could never do alone, or level 4 would have bought nothing at all.
	"Blacksmith":   {"name": "The Night Forge", "desc": "The fires never bank — the forge turns out twice the arms a day-shift could."},
	"School":       {"name": "The Open Doors", "desc": "No child waits for a seat — the hall takes them all in, past every desk it has."},
	"Government":   {"name": "The Standing Order", "desc": "Nobody works a trade they weren't trained for — the wrongly-placed are moved to work that fits."},
	"Builderhouse": {"name": "The Standing Crew", "desc": "The crew scavenges what it needs — repairs cost the village stores nothing."},
	"Barracks":     {"name": "The Standing Watch", "desc": "The watch overlaps — every warrior holds the wall at full worth, on shift or not."},
	"Farm":         {"name": "The Standing Harvest", "desc": "The Farm holds a reserve back, and opens it rather than let Deepwood starve."},
	"Fishing Dock": {"name": "The Long Haul", "desc": "The boats work past the shallows — a deep catch comes in daily, unbidden."},
	"Mine":         {"name": "The Deep Seam", "desc": "The crew breaks into ore the shallow workings never reach."},
	"Hospital":     {"name": "The Ward That Never Sleeps", "desc": "Whoever is carried in leaves it whole — no trickle, no waiting."},
	"Bar":          {"name": "The Matchmaker's Round", "desc": "Matches are made unbidden, and a home is raised for the couple that waits."},
	"Tavern":       {"name": "The Long Night", "desc": "The fire never goes out — grief burns off twice as fast, and no heart falls all the way to nothing."},
	"Shrine":       {"name": "The Unbroken Light", "desc": "The light holds — despair can no longer take root in anyone."},
	"Bank":         {"name": "The Ledger That Pays", "desc": "The Bank covers any shortfall — payday never touches your purse again."},
	"Marketplace":  {"name": "The Caravan Road", "desc": "The road knows Deepwood — traders come far more often, and never stop coming."},
	"Science Lab":  {"name": "The Whisper Network", "desc": "Every material is known on sight — nothing waits to be identified."},
}
# The Deep Seam's yield: skill materials the Mine has no other way to produce.
const DEEP_SEAM_MATERIALS := ["ember_crystal", "iron_shard", "resin"]

# ===================== LEADER POWERS (dev law 2026-07-29) =====================
# Four leaders were pure STAT -- Harvestmaster +60% food, Harbormaster +60%,
# Pitmaster +50% ore, Warchief +15% training -- while every other leader already
# DID something (the Chancellor staffs, the Publican pairs, the Master Builder
# builds). Under the same law their flat percentages shrink to connective tissue
# and each gains a named behaviour instead. Deliberately chosen NOT to overlap the
# building power sitting alongside them (a Farm's Standing Harvest opens a
# reserve; its Harvestmaster works the fields with no hands at all).
const LEADER_POWERS := {
	"Farm":         {"title": "Harvestmaster", "name": "The Full Table", "desc": "The master works the fields alone — the Farm feeds Deepwood with no farmhands seated."},
	"Fishing Dock": {"title": "Harbormaster", "name": "The Tide Table", "desc": "They read the water — the boats land a sealed crate from the deep water now and then."},
	"Mine":         {"title": "Pitmaster", "name": "The Sounding", "desc": "They sound the rock — the crew cuts ore matched to the deepest floor you have reached."},
	"Barracks":     {"title": "Warchief", "name": "The Muster", "desc": "The horn calls everyone — every able adult stands to the wall, not only the trained."},
}

# Is this building's named LEADER seated (and the building working)?
func has_leader_power(building: String) -> bool:
	return LEADER_POWERS.has(building) and is_building_operational(building) \
		and count_leader_holders(building, str(LEADER_POWERS[building]["title"])) > 0

# A crew the master can work alone: THE FULL TABLE / THE SOUNDING let a building
# produce with nobody at the benches, because the master is worth a crew.
const MASTER_ALONE_CREW := 2

# THE SOUNDING's ore: the Mine follows the player DOWN. Shallow rock gives iron;
# only a town whose delver has carved deep sees the rarer seams surface at home.
func _sounding_material() -> String:
	if deepest_level_reached >= 60:
		return "void_essence"
	if deepest_level_reached >= 35:
		return "ember_crystal"
	if deepest_level_reached >= 15:
		return "resin"
	return "iron_shard"

# THE TIDE TABLE's catch: what the Harbormaster's boats bring up from deep water.
const TIDE_TABLE_CRATES := ["crate_driftwood", "crate_pearlbound"]
const TIDE_TABLE_DAYS := 3.0        # a sealed crate about this often
var _tide_table_accum := 0.0

# A power is its LEADER'S MASTERWORK, not a replacement for them (dev call
# 2026-07-30: "leader loses its value"). As first built, ten of the fifteen powers
# did the seated leader's own job -- the Standing Order staffed the town "without a
# Chancellor", the Open Doors schooled children "no Principal needed" -- so gold
# spent on a level bought past the rarest content in the game (one named VIP per
# post, each pulled from a specific depth) AND past the automation ladder's whole
# pacing, which is measured in rescue depths: Publican 20, Principal 45, Master
# Builder 55, Chancellor 95.
# Now the building must be GRAND ENOUGH (level 4) *and* have the right person in
# the chair. The power is what that person can finally do with a hall this size.
func has_building_power(name: String) -> bool:
	return BUILDING_POWERS.has(name) and is_building_operational(name) \
		and building_level(name) >= BUILDING_POWER_LEVEL \
		and building_power_staffed(name)

# Who has to be in the chair for the power to wake. Every building crowns itself
# with a named leadership post -- except the SHRINE, whose Lightkeepers are
# Hospital-trained keepers rather than a rescued VIP. There, the keepers at their
# posts are the ones holding the light, so they answer for it.
func building_power_staffed(name: String) -> bool:
	for rd in BuildingRoles.get_roles(name):
		if rd.get("leadership", false):
			return seated_leaders(name) > 0
	return count_workers(name) > 0

# The power's display name, or "" if this building has none / hasn't grown into it.
func building_power_name(name: String) -> String:
	if not has_building_power(name):
		return ""
	return str(BUILDING_POWERS[name].get("name", ""))

# ============================ ADJACENCY SYNERGY ============================
# WHERE you build matters, not just what (settlement-depth roadmap Phase 1). The
# village is a 1-D strip, so "adjacent" means the IMMEDIATE left/right neighbour
# along the road -- readable at a glance, with no grid to puzzle over.
#
# Every pair below is a link in the City Machine's supply chain made PHYSICAL:
# stand the Mine beside the forge and the ore has no distance to travel. POSITIVE
# ONLY (dev call on this layer): a good layout is rewarded, a plain one is never
# punished, so no existing save is retroactively fined for a row it laid down
# before this existed. Medium strength, and capped, so a lucky cluster of six
# can't run away with the economy.
const ADJACENCY_BONUS_CAP := 0.30
const ADJACENCY_PAIRS := [
	{"a": "Mine",        "b": "Blacksmith",   "bonus": 0.20, "why": "ore goes straight from the seam to the forge"},
	{"a": "Mine",        "b": "Builderhouse", "bonus": 0.15, "why": "stone lands at the masons' door"},
	{"a": "Blacksmith",  "b": "Barracks",     "bonus": 0.15, "why": "arms are carried straight to the drill yard"},
	{"a": "Farm",        "b": "Fishing Dock", "bonus": 0.15, "why": "one larder, filled from field and water both"},
	{"a": "Bank",        "b": "Marketplace",  "bonus": 0.20, "why": "the counting house sits beside the carts"},
	{"a": "Science Lab", "b": "School",       "bonus": 0.15, "why": "the lab's findings are taught the same day"},
	{"a": "Bar",         "b": "Tavern",       "bonus": 0.15, "why": "a bed waits directly above the music"},
	{"a": "Hospital",    "b": "Shrine",       "bonus": 0.15, "why": "healing and mercy keep one threshold"},
]

# ============================ AURAS (roadmap Phase 4) ============================
# The last spatial rule, and the only one that points OUTWARD. Phases 1-3 all
# change what a building produces for itself (adjacency, quarter, plot all fold
# into building_output_multiplier). An aura changes life for everything AROUND
# it -- so for the first time, where you put a building decides who benefits.
#
# MEASURED AGAINST HOMES AND WORKPLACES, not wandering bodies. A villager's NPC
# avatar only exists while the surface scene is loaded, and it walks about all
# day; their COTTAGE and their JOB stand still and survive into the deep. So an
# aura asks "is this person's home or work inside the circle?" -- which is
# stable, saves correctly, keeps working while the player is away, and (the real
# prize) finally makes COTTAGE PLACEMENT part of the puzzle: a home built in the
# Bar's light is a happier home for as long as it stands.
#
# Only three buildings carry one, and each rides a system that is ALREADY
# spatial -- no aura was invented to give a building something to do.
const AURAS := {
	"Bar": {"radius": 1600.0, "name": "The Sound of It",
		"desc": "music carries down the row — anyone living or working in earshot is gladder for it"},
	"Shrine": {"radius": 1400.0, "name": "Hallowed Ground",
		"desc": "despair cannot take root within sight of the stones"},
	"Hospital": {"radius": 1500.0, "name": "The Ward's Shadow",
		"desc": "the hurt mend faster near the ward, without ever being carried in"},
}
const AURA_BAR_MORALE := 0.8       # added to personal morale target, in range
const AURA_WARD_REGEN := 2.5       # extra HP/hour for the wounded, in range

# Where each building stands, cached with the rest of the layout (the surface
# scene is unloaded in the deep, and auras must still resolve).
var building_x: Dictionary = {}

# The fixed places a villager's life is anchored to: their cottage, and the
# building they work at. Empty for a homeless, jobless soul -- no aura reaches
# someone with nowhere to be, which is its own quiet argument for housing them.
func villager_places(v: Dictionary) -> Array:
	var out := []
	var vid := str(v.get("id", ""))
	var hid := villager_home_id(vid)
	if hid == "":
		# a child sleeps under its parents' roof
		for pid in v.get("parents", []):
			hid = villager_home_id(str(pid))
			if hid != "":
				break
	if hid != "":
		var idx := extra_cottage_ids.find(hid)
		if idx >= 0 and idx < extra_cottage_positions.size():
			out.append(float(extra_cottage_positions[idx]))
	var rk := str(v.get("role_key", ""))
	if rk != "" and building_x.has(rk):
		out.append(float(building_x[rk]))
	return out

# Is this villager's life lived inside the named building's aura?
func in_aura(building: String, v: Dictionary) -> bool:
	if not AURAS.has(building) or not is_building_operational(building):
		return false
	if not building_x.has(building):
		return false
	var bx := float(building_x[building])
	var r := float(AURAS[building]["radius"])
	for px in villager_places(v):
		if absf(float(px) - bx) <= r:
			return true
	return false

# How many souls a building's aura actually reaches (for the E-panel readout).
func aura_reach(building: String) -> int:
	if not AURAS.has(building):
		return 0
	var n := 0
	for v in rescued_villagers:
		if in_aura(building, v):
			n += 1
	return n

# ========================= SPECIAL PLOTS (roadmap Phase 3) =========================
# The third spatial rule, and the first where the MAP ITSELF has an opinion.
# Adjacency is relative (who is beside you) and districts are zones (a broad
# region). A plot is one EXACT patch of ground that suits exactly one building:
# the seam the Mine wants, the soil the Farm wants, the spring the boats want.
#
# The seed already existed, inverted: the Fishing Dock carried its own water
# (dock_water_half() is derived from the dock's own width, so it painted a pond
# wherever you dropped it). Here the ground comes first and the building comes
# to it.
#
# THREE RULES THIS OBEYS:
#  1. PURELY ADDITIVE. The Dock still works anywhere; on a real spring it works
#     BETTER. Nothing that worked before is worth less now -- the same rule that
#     kept adjacency penalty-free and district boundaries absolute.
#  2. PLOT AGREES WITH DISTRICT. Every plot sits inside the quarter its building
#     already belongs to, so the two rules never fight. Three spatial demands
#     pulling against each other would stop being a puzzle and start being
#     unsolvable; ADJACENCY stays the one thing you trade away.
#  3. THE ROW REWARDS PLANNING. The Black Soil and the Spring are set ~850 apart,
#     as are the Quarry Shelf and the Ore Vein -- close enough that a careful
#     player can stand BOTH buildings on their own ground AND keep them
#     neighbours. Those two "perfect corners" are earned, not given. The Mine's
#     forge pairing and the Shrine's ward pairing stay genuinely impossible to
#     combine with their plots, and that is the point.
const PLOT_BONUS := 0.15        # richer than a quarter: a plot is one spot, and far away
const PLOT_RADIUS := 260.0      # how near the centre a building must stand to work it
const SPECIAL_PLOTS := [
	{"id": "muster", "x": 7000.0, "building": "Barracks", "name": "The Muster Yard",
		"desc": "the old parade ground — boots have packed this earth flat for a century"},
	{"id": "square", "x": 13200.0, "building": "Marketplace", "name": "The Old Market Square",
		"desc": "the fallen city traded here; the cobbles remember every cart"},
	{"id": "soil", "x": 15800.0, "building": "Farm", "name": "The Black Soil",
		"desc": "river silt, dark and deep — anything sown here comes up thick"},
	{"id": "spring", "x": 16650.0, "building": "Fishing Dock", "name": "The Spring",
		"desc": "cold water rising from the rock, and it never freezes over"},
	# ...and these two clear the surface chest that sits at x=18700 (it is a
	# village_structure and really does reserve its ground -- found by probing the
	# live placer, not by reading the numbers)
	{"id": "quarry", "x": 17300.0, "building": "Builderhouse", "name": "The Quarry Shelf",
		"desc": "cut stone lies here already, half-dressed and waiting"},
	{"id": "vein", "x": 18200.0, "building": "Mine", "name": "The Ore Vein",
		"desc": "a black seam breaks the surface — the rock is generous this deep"},
	{"id": "stones", "x": 20200.0, "building": "Shrine", "name": "The Sorrow-Touched Stones",
		"desc": "standing stones the dark never managed to foul"},
]

# The plot that suits this building, if any ({} when it has none).
func plot_for_building(name: String) -> Dictionary:
	for plot in SPECIAL_PLOTS:
		if str(plot["building"]) == name:
			return plot
	return {}

# The plot whose ground this x sits on, if any.
func plot_at(x: float) -> Dictionary:
	for plot in SPECIAL_PLOTS:
		if absf(x - float(plot["x"])) <= PLOT_RADIUS:
			return plot
	return {}

# name -> plot id it is standing on (""), cached with the rest of the layout so
# the away ticks still know the town while the surface scene is unloaded.
var building_plots: Dictionary = {}

func building_plot(name: String) -> String:
	return str(building_plots.get(name, ""))

# Standing on the ground that suits it?
func on_home_plot(name: String) -> bool:
	var plot := plot_for_building(name)
	return not plot.is_empty() and building_plot(name) == str(plot["id"])

func plot_bonus(name: String) -> float:
	if not is_building_operational(name):
		return 0.0
	return PLOT_BONUS if on_home_plot(name) else 0.0

# ============================ DISTRICTS (roadmap Phase 2) ============================
# The second spatial axis. Adjacency asks WHO you stand next to; a district asks
# WHERE ON THE MAP you stand. The road runs west (the gate the sieges come from)
# to east (open working land), so the strip has three natural quarters:
#
#   GATEFRONT  the war quarter -- the exposed ground the waves reach first.
#              Soldiers, arms and the ward that receives the wounded belong here
#              (and the Sick Road already walks the hurt toward the nearest ward).
#   HEART      the civic quarter -- the town square. Rule, coin, trade, learning
#              and the places people gather.
#   OUTSKIRTS  the working land -- fields, water, seams, timber, and a shrine set
#              apart from the crowd.
#
# Measured off the REAL row (probe 2026-07-29: gate 4700, buildings from ~5269 to
# ~17600, ~880px slots), and anchored in ABSOLUTE distance from the gate on
# purpose. Fractional thirds would have re-drawn every boundary each time the town
# grew east, silently moving a building out of its district and taking a bonus
# away that the player never spent -- a hidden retro-penalty. Only MOVING a
# building changes its district now.
const DISTRICT_GATEFRONT_DEPTH := 4500.0     # gate .. +4500
const DISTRICT_HEART_DEPTH := 9500.0         # +4500 .. +9500, then outskirts
const DISTRICT_BONUS := 0.10                 # standing in your own quarter
# Positive only, like adjacency: the right quarter PAYS, the wrong one simply
# doesn't. Nobody's existing row is fined for predating this.
const DISTRICT_HOME := {
	"Barracks": "gatefront", "Blacksmith": "gatefront", "Hospital": "gatefront",
	"Government": "heart", "Bank": "heart", "Marketplace": "heart",
	"School": "heart", "Science Lab": "heart", "Bar": "heart", "Tavern": "heart",
	"Farm": "outskirts", "Fishing Dock": "outskirts", "Mine": "outskirts",
	"Builderhouse": "outskirts", "Shrine": "outskirts",
}
const DISTRICT_LABEL := {
	"gatefront": "Gatefront — the war quarter",
	"heart": "The Heart — the civic quarter",
	"outskirts": "Outskirts — the working land",
}

# Which quarter a piece of ground belongs to. Anything at or west of the gate
# counts as gatefront: that IS the exposed edge, by definition.
func district_at(x: float) -> String:
	var gate := SURFACE_WEST_FALLBACK_X
	var t := get_tree()
	if t != null:
		for w in t.get_nodes_in_group("village_wall"):
			if "flank" in w and str(w.flank) == "west":
				gate = w.global_position.x
				break
	var east := x - gate
	if east <= DISTRICT_GATEFRONT_DEPTH:
		return "gatefront"
	if east <= DISTRICT_HEART_DEPTH:
		return "heart"
	return "outskirts"

# name -> district, cached beside the neighbour row for the same reason (the
# surface scene is unloaded while the player is in the deep).
var building_districts: Dictionary = {}

func building_district(name: String) -> String:
	return str(building_districts.get(name, ""))

# Is this building standing in the quarter that suits it?
func in_home_district(name: String) -> bool:
	var home := str(DISTRICT_HOME.get(name, ""))
	return home != "" and building_district(name) == home

func district_bonus(name: String) -> float:
	if not is_building_operational(name):
		return 0.0
	return DISTRICT_BONUS if in_home_district(name) else 0.0

# name -> [left_neighbour, right_neighbour]. Rebuilt from the live village and
# CACHED, because the surface scene is UNLOADED while the player is in the deep
# and the away ticks (food, income, the stores) still need to know the row.
# Buildings cannot move while you are away, so the last known row stays true.
var building_neighbors: Dictionary = {}

# Read the village's LAYOUT off the standing bodies: who neighbours whom, and
# which quarter each building stands in. Physical adjacency counts every building
# BODY -- a ruin between two halls really does separate them, and raising or
# moving it is how you fix that. Whether a synergy FIRES is gated on both halves
# being operational (see adjacency_links).
func refresh_layout() -> void:
	var t := get_tree()
	if t == null:
		return
	var row := []
	for b in t.get_nodes_in_group("building"):
		if not is_instance_valid(b) or not ("building_name" in b):
			continue
		row.append({"name": str(b.building_name), "x": b.global_position.x})
	if row.is_empty():
		return                      # away from the village: keep the cached layout
	row.sort_custom(func(p, q): return float(p["x"]) < float(q["x"]))
	var nb := {}
	var dist := {}
	var plots := {}
	var xs := {}
	for i in range(row.size()):
		var bn := str(row[i]["name"])
		var bx := float(row[i]["x"])
		xs[bn] = bx
		nb[bn] = [
			str(row[i - 1]["name"]) if i > 0 else "",
			str(row[i + 1]["name"]) if i < row.size() - 1 else "",
		]
		dist[bn] = district_at(bx)
		var plot := plot_at(bx)
		plots[bn] = str(plot["id"]) if not plot.is_empty() else ""
	building_neighbors = nb
	building_districts = dist
	building_plots = plots
	building_x = xs

# The synergies LIVE for one building right now: [{partner, bonus, why}, ...].
# Both halves must stand and work -- a rubble Blacksmith forges nothing for the
# Mine beside it.
func adjacency_links(name: String) -> Array:
	var out := []
	if not is_building_operational(name):
		return out
	var sides: Array = building_neighbors.get(name, [])
	for side in sides:
		var partner := str(side)
		if partner == "" or not is_building_operational(partner):
			continue
		for pair in ADJACENCY_PAIRS:
			var a := str(pair["a"])
			var b := str(pair["b"])
			if (a == name and b == partner) or (b == name and a == partner):
				out.append({"partner": partner, "bonus": float(pair["bonus"]), "why": str(pair["why"])})
	return out

# How much a building's output is lifted by its neighbours (0.0 .. CAP).
func adjacency_bonus(name: String) -> float:
	var total := 0.0
	for link in adjacency_links(name):
		total += float(link["bonus"])
	return minf(total, ADJACENCY_BONUS_CAP)

# ONE output term per building: its upgrade level, its NEIGHBOURS, and the QUARTER
# it stands in. Every producer in the chain reads this, so a well-laid town
# genuinely runs richer than a scattered one.
func building_output_multiplier(name: String) -> float:
	return 1.0 + (building_level(name) - 1) * BUILDING_OUTPUT_PER_LEVEL \
		+ adjacency_bonus(name) + district_bonus(name) + plot_bonus(name)

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
	else:
		# no positional match (a drifted save, a moved home): fall back to the
		# id itself. Decrementing the count WITHOUT trimming the arrays used to
		# silently delete the LAST cottage on the next village rebuild instead
		# of the one the player actually chose (audit fix).
		var idx := extra_cottage_ids.find(house_id)
		if idx >= 0:
			extra_cottage_ids.remove_at(idx)
			if idx < extra_cottage_positions.size():
				extra_cottage_positions.remove_at(idx)
	# ONE source of truth for the count -- exactly how load_game normalises it
	extra_cottages = extra_cottage_ids.size()
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
		# clearance uses the MAX-UPGRADE width, not the current level's: eff_w()
		# at level 1 is just the base again, so two halls green-lit at the
		# minimum gap still ended up drawn inside each other at level 6 (each
		# grows x1.4 and try_upgrade performs no clearance check of its own).
		# max_upgrade_width() is what the auto-layout reserves for the same
		# reason -- promise the room a building will EVER need, up front.
		var other_half: float = (other.max_upgrade_width() if other.has_method("max_upgrade_width") \
			else (other.eff_w() if other.has_method("eff_w") else float(other.width))) / 2.0
		if absf(x - other.global_position.x) < my_half + other_half + RELOCATE_CLEARANCE:
			return false
	# ...and (for HALLS/COTTAGES, not walls) don't bury a cottage / watchtower /
	# road marker either -- those are "village_structure", not "building", so
	# the loop above missed them and a menu-placed cottage could be dropped
	# straight on top of another (dev sweep 2025-07-25). Walls stay EXEMPT by
	# design ("a rampart defines the edge and stands among the road markers at
	# the gate", and test_buildplace pins it); the E-press conflict a stacked
	# wall used to cause is arbitrated in wall.gd instead. Only SAME-SURFACE
	# structures count -- the Underdark's chests are village_structures a
	# kilometre down and mustn't reserve the ground above them; with NO
	# building standing the surface falls back to the village ground line
	# instead of matching everything (an empty village once let deep caches
	# paint the whole surface red).
	if not is_wall:
		var surface_y := -39.0   # the village ground line (main.VILLAGE_Y)
		for b in tree.get_nodes_in_group("building"):
			if is_instance_valid(b):
				surface_y = b.global_position.y
				break
		for node in tree.get_nodes_in_group("village_structure"):
			if node == exclude or not is_instance_valid(node):
				continue
			if absf(node.global_position.y - surface_y) > 300.0:
				continue
			var ohalf: float = (float(node.width) / 2.0) if ("width" in node) else 60.0
			if absf(x - node.global_position.x) < my_half + ohalf + RELOCATE_CLEARANCE:
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
	# BANK THE OPENING (softlock fix 2026-07-25). Until now nothing saved when the
	# opening finished, so a player who beat the first wave and quit before the next
	# 180s autosave came back to a PRE-arrival save -- Continue replayed the arrival
	# (and its raiders were invincible). Writing the save here means Continue resumes
	# in the village with the opening done: no re-fight, no repeated dialogue.
	autosave("the oath sworn")

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
# Per HOUSED COUPLE, per cycle. THE FLYWHEEL FIX (2026-07-29): this used to pick
# exactly ONE couple per cycle no matter how many cottages stood -- so a town of
# 20 cottages bred at precisely the same rate as a town of 1, the "brake is the
# cottage count" promised above was never implemented, and the population could
# never approach the intended city scale (dev: ~70-80 villagers by floor 60; the
# marathon sim topped out around 11). Now every couple rolls its own cradle, so
# cottages are what actually grow the town -- and the natural brakes still hold:
# a couple already expecting is skipped, and no one conceives while the larder is
# empty or the village is in despair.
const FAMILY_CONCEPTION_CHANCE := 0.4
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
	# EVERY housed couple rolls for the cradle -- more cottages, more children.
	# (_mint_birth_id is sequence-backed, so several conceptions in ONE frame
	# still get unique ids -- see the _birth_seq note.)
	for h in candidates:
		if randf() >= FAMILY_CONCEPTION_CHANCE:
			continue
		var pregnancy_id = _mint_birth_id("preg")
		pregnancies[pregnancy_id] = {"male_id": h.get("a", ""), "female_id": h.get("b", ""), "remaining_hours": GESTATION_DURATION_HOURS}

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

# The music sat too quiet against the sfx (dev call 2026-07-27): +20% on the bus
# rather than on the setting, so the 0..1 slider keeps meaning "none .. full" and
# a saved preference is not silently rescaled. Slight headroom clamp so a full
# slider plus the gain can't clip the Master bus.
const MUSIC_GAIN := 1.2

func apply_music_volume() -> void:
	var mi = AudioServer.get_bus_index("Music")
	if mi < 0:
		return
	var lin: float = min(max(music_volume, 0.0001) * MUSIC_GAIN, 1.6)
	AudioServer.set_bus_volume_db(mi, linear_to_db(lin))
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
	tick_tide_table(hours_passed)     # Harbormaster: the sealed crates
	tick_wages(hours_passed)
	tick_wanderers(hours_passed)
	tick_watchtower_warning()
	tick_mine_yield(hours_passed)
	tick_wood_gathering(hours_passed)
	tick_patrols(hours_passed)
	tick_sickness(hours_passed)
	tick_fire(hours_passed)
	tick_eclipse(hours_passed)
	tick_self_sufficiency()   # celebrate each chore the moment it starts running itself
	tick_village_peril()      # escalating dread as the hearth empties (pierces the fog)
	tick_black_tide_omen()    # the fog-piercing warning of a coming Black Tide
	tick_hidden_events()      # secret event bosses, woken by what the player does
	if hours_passed > 0.0:
		# grief heals with time -- the forgiving half of the death-shock system
		# THE LONG NIGHT (Tavern power): the fire never goes out, and grief burns
		# off twice as fast in a room that stays warm
		morale_death_shock = maxf(0.0, morale_death_shock - hours_passed * DEATH_SHOCK_DECAY_PER_HOUR \
			* (2.0 if ten_freed("ten_seraphel") else 1.0) * (2.0 if has_building_power("Tavern") else 1.0))
		tick_food(hours_passed)          # eat/produce first, so hunger drain sees fresh state
		tick_morale_effects(hours_passed)
		tick_village_tribute(hours_passed)
		tick_sieges(hours_passed)
		tick_caravans(hours_passed)
		tick_fishing()            # starter rod + the Harbormaster's daily (pillar 3)
		tick_weeping(hours_passed)   # the forest's rare grieving night
		tick_lantern(hours_passed)   # ...and the town's rare festival one (after weeping: grief wins a shared dusk)

# === HIDDEN EVENT BOSSES (2026-07-28) ==================================
# Ten secret bosses (event_boss.gd), each armed once per run. Their trigger
# CONDITIONS live here because they read live world state; the loot + boss
# defs live in event_boss.gd / boss.gd. event_state[id] walks
# "armed" -> "triggered" (the fight is on/was on) -> "killed" (looted). The
# per-run counters below are the raw material of the milestone triggers; they
# reset with every run and persist across a save (so a hoard survives a quit).
var event_state: Dictionary = {}
var run_kills := 0
var run_trees := 0
var run_rocks := 0
var run_gold_spent := 0
var run_villager_deaths := 0
var floors_since_death := 0

func arm_hidden_events() -> void:
	event_state = {}
	for id in EventBoss.ids():
		event_state[id] = "armed"
	_event_omen_fired = {}

func note_kill(n: int) -> void:
	run_kills += maxi(0, n)

func note_harvest_swing(kind: String) -> void:
	if kind == "tree":
		run_trees += 1
	elif kind == "rock":
		run_rocks += 1

func note_gold_spent(amount: int) -> void:
	if amount > 0:
		run_gold_spent += amount

func note_floor_cleared_event() -> void:
	floors_since_death += 1

func on_player_died_event() -> void:
	floors_since_death = 0   # the no-death streak is broken

# REMATCHES (renewability pillar 2, 2026-07-28): a felled hunt rests a day,
# then RE-ARMS one rung harder -- the same playstyle that woke it wakes it
# again (the Tallyman returns because you are still rich). First kill pays
# the exclusive table; every rematch pays materials and gold, never the twin.
const REMATCH_REST_HOURS := 24.0
var event_rematch_level: Dictionary = {}   # id -> kills so far (0 = never felled)
var event_rearm_at: Dictionary = {}        # id -> game_hours when the hunt re-arms

func on_event_boss_killed(id: String) -> void:
	if event_state.has(id):
		event_state[id] = "killed"
	event_rematch_level[id] = int(event_rematch_level.get(id, 0)) + 1
	event_rearm_at[id] = game_hours + REMATCH_REST_HOURS
	_note_capstone_kill(id)   # lifetime record + the Horn reveal when all ten fall
	log_event("combat", "A hidden foe fell: " + str(EventBoss.get_event(id).get("name", id)) + ".")

# One event may hold the stage at a time, and never during the scripted
# prologue or the Harvest finale (they own the world exclusively).
# True while an item-summon's delay timer is counting down but no director node
# exists yet -- claims the stage synchronously so nothing spawns in that window.
var _summon_pending := false

func _event_stage_free() -> bool:
	if not opening_done:
		return false
	if harvest_at_home or despair_dead:
		return false
	if _summon_pending:
		return false   # a delayed summon has already claimed the stage
	var tree := get_tree()
	if tree == null:
		return false
	return tree.get_nodes_in_group("event_boss_director").is_empty()

func tick_hidden_events() -> void:
	if event_state.is_empty():
		arm_hidden_events()
	# rested kills RE-ARM one rung harder (the rematch ladder)
	for rid in event_rearm_at.keys():
		if event_state.get(rid, "") == "killed" and game_hours >= float(event_rearm_at[rid]):
			event_state[rid] = "armed"
			event_rearm_at.erase(rid)
	if not _event_stage_free():
		return
	var tree := get_tree()
	var p = tree.get_first_node_in_group("player")
	if p == null or not is_instance_valid(p):
		return
	for id in EventBoss.ids():
		if EventBoss.is_item_only(str(id)):
			continue   # Nihil / the Master are woken by an item, never ambiently
		if event_state.get(id, "armed") != "armed":
			continue
		_tick_event_omen(str(id), p)   # a subtle tell as the player nears the condition
		if _event_condition_met(str(id), p):
			_fire_event(str(id), p)
			return   # at most one wakes per tick

func _event_condition_met(id: String, p: Node) -> bool:
	match id:
		"tallyman":
			return not in_dungeon and int(p.currency) >= 8000
		"first_frost":
			var h := hour_of_day()
			return not in_dungeon and h >= 0.0 and h <= 2.5
		"glutton_root":
			return run_trees >= 50
		"drowned_chorus":
			return run_rocks >= 90
		"effigy_king":
			return run_gold_spent >= 15000
		"sleepless_warden":
			return in_dungeon and floors_since_death >= 6
		"grief_eater":
			return run_villager_deaths >= 3
		"hollow_crown":
			return in_dungeon and monarch_stage() >= 4
		"sable_hound":
			return run_kills >= 300
		"nihil":
			var mh: int = p.get_max_health() if p.has_method("get_max_health") else 100
			var near_death := float(p.health) <= float(mh) * 0.08
			return in_dungeon and active_dungeon_level >= 60 and near_death and hour_of_day() <= 2.5
	return false

func _fire_event(id: String, _p: Node) -> void:
	var scene = get_tree().current_scene
	if scene == null:
		return   # no stage yet -- stays armed, retries next tick
	event_state[id] = "triggered"
	var dir = preload("res://event_boss_director.gd").new()
	dir.event_id = id
	scene.add_child(dir)

# ====================== THE ECLIPSE (dev design 2026-08-06) ======================
# The moon takes the sun whole and the world goes to silhouette under a red ring.
# The only hour the Hollow Signet answers, and the way the hardest fight in
# Deepwood is called.
#
# NOT the dawn/dusk crossing -- that happens twice a day, every day, and is what
# Nihil's older Duskmoon rite reads (_sun_moon_both_up). This is a rarer thing
# entirely, and the two must never be confused.
#
# RARE, RECURRING, AND NEVER MISSABLE (dev call): each day carries a flat 3%
# chance, but never within ECLIPSE_COOLDOWN_DAYS of the last one -- so it cannot
# fall twice in a row, and it cannot be farmed by idling. Expect roughly one
# every forty-odd days (~7 real hours), at no predictable moment. If you are
# caught in the deep without the Signet, you have lost THIS one and nothing more:
# another will come. That is what keeps a once-a-campaign spectacle from being a
# once-a-campaign punishment.
#
# It is ANNOUNCED the moment it begins, through the away-fog, and holds for
# ECLIPSE_DURATION_HOURS -- about five real minutes, long enough to waystone home,
# not long enough to go and fetch what you should already be carrying.
const ECLIPSE_CHANCE_PER_DAY := 0.03
const ECLIPSE_COOLDOWN_DAYS := 7.0       # never twice in a row
const ECLIPSE_DURATION_HOURS := 12.0     # ~5 real minutes of wrong sky
const ECLIPSE_START_HOUR := 6.0          # sunrise: the span is exactly the day
var eclipse_at_hours := -1.0             # when the CURRENT/most recent one began
var eclipses_seen := 0
var _eclipse_roll_accum := 0.0
var _eclipse_announced := false

func eclipse_is_active() -> bool:
	if eclipse_at_hours < 0.0:
		return false
	return game_hours >= eclipse_at_hours \
		and game_hours < eclipse_at_hours + ECLIPSE_DURATION_HOURS

# Hours since the last one let go (a huge number when there has never been one).
func hours_since_eclipse() -> float:
	if eclipse_at_hours < 0.0:
		return 1e9
	return game_hours - (eclipse_at_hours + ECLIPSE_DURATION_HOURS)

# 0 at first contact, 1 at totality, 0 again as it lets go -- what the sky draws.
func eclipse_progress() -> float:
	if not eclipse_is_active():
		return 0.0
	var t: float = (game_hours - eclipse_at_hours) / ECLIPSE_DURATION_HOURS
	return sin(clampf(t, 0.0, 1.0) * PI)

func tick_eclipse(hours_passed: float) -> void:
	if hours_passed <= 0.0:
		return
	if eclipse_is_active():
		if not _eclipse_announced:
			_eclipse_announced = true
			eclipses_seen += 1
			# PIERCES THE FOG on purpose: nobody can be asked to be ready for a
			# thing they were never told about.
			notify_urgent("🌑 THE SUN IS GOING OUT — the sky turns red over Deepwood.")
			log_event("village", "The moon took the sun whole. The world stood in red dark.")
			SfxSynth.play_village(self, SfxSynth.SFX_ECLIPSE)
		return
	# between eclipses: one roll a day, and never inside the cooldown
	if hours_since_eclipse() < ECLIPSE_COOLDOWN_DAYS * 24.0:
		return
	_eclipse_roll_accum += hours_passed
	while _eclipse_roll_accum >= 24.0:
		_eclipse_roll_accum -= 24.0
		if randf() < ECLIPSE_CHANCE_PER_DAY:
			# IT ALWAYS BEGINS AT DAWN. The roll picks the DAY; the sky picks the
			# hour. An eclipse rolled at midnight and started on the spot would be
			# a red night -- no sun to take, no ring, nothing to look at. Snapped
			# to sunrise, the twelve hours land exactly on the daylight span:
			# first contact at dawn, totality at noon, the sun let go at dusk.
			eclipse_at_hours = game_hours + hours_until_time_of_day(ECLIPSE_START_HOUR)
			_eclipse_announced = false
			return

# Hours from now until the clock next reads `target` (0 if it reads it already).
func hours_until_time_of_day(target: float) -> float:
	return fposmod(target - time_of_day(), 24.0)

# Rolled, but the sun has not been touched yet -- we are waiting on dawn.
func eclipse_is_pending() -> bool:
	return eclipse_at_hours > game_hours

# The gate the Hollow Signet reads: a TRUE eclipse, not the daily crossing.
func is_true_eclipse() -> bool:
	return eclipse_is_active()

# --- Item-summoned events (Nihil's Duskmoon rite, the Master's Horn, and every
# re-summon token). Called from player.use_item. Returns "" on success, else a
# short reason to show WITHOUT spending the item. Bypasses the once-per-run lock
# (that's the whole point of a token), but still only one event on stage. ---
func summon_event_boss(id: String, delay: float, require_eclipse: bool, require_true_eclipse := false) -> String:
	if EventBoss.get_event(id).is_empty():
		return "Nothing answers."
	if not opening_done or harvest_at_home or despair_dead:
		return "Not here. Not now."
	if _summon_pending or not get_tree().get_nodes_in_group("event_boss_director").is_empty():
		return "The air is already thick — finish what you started."
	if require_eclipse and not _sun_moon_both_up():
		return "Nothing happens. The sky is not yet wrong."   # no explicit how-to on purpose
	# THE TRUE ECLIPSE is a different, far rarer gate than the daily crossing
	# above: the Signet will not answer at dusk, only when the moon has the sun
	# whole. Kept as its own flag so the two can never be confused.
	if require_true_eclipse and not is_true_eclipse():
		return "The ring is cold. The moon has not taken the sun."
	var p = get_tree().get_first_node_in_group("player")
	if p == null or not is_instance_valid(p):
		return "Nothing answers."
	event_state[id] = "triggered"   # claim the stage immediately (no double-cast)
	notify("The air curdles — something is coming…")
	play_sfx(SFX_CHIME, 0.4)
	if delay > 0.0:
		_summon_pending = true   # hold the stage through the whole countdown
		var t := get_tree().create_timer(delay)
		t.timeout.connect(_spawn_summoned.bind(id))
	else:
		_spawn_summoned(id)
	return ""

func _spawn_summoned(id: String) -> void:
	_summon_pending = false   # the countdown is over -- release the pending claim
	var scene = get_tree().current_scene
	if scene == null or not get_tree().get_nodes_in_group("event_boss_director").is_empty():
		return
	var dir = preload("res://event_boss_director.gd").new()
	dir.event_id = id
	scene.add_child(dir)

# True only in the village, where the sky exists, during the dawn/dusk window
# when the sun and the moon both ride it at once (day_night_cycle overlap).
func _sun_moon_both_up() -> bool:
	var dn = get_tree().get_first_node_in_group("day_night_cycle")
	if dn == null:
		dn = get_tree().get_first_node_in_group("day_night")
	return dn != null and dn.has_method("is_sun_moon_overlap") and dn.is_sun_moon_overlap()

# === the capstone: a lifetime record of which hidden bosses have ever fallen ===
var event_bosses_ever_killed: Array = []
var hunters_horn_announced := false

# The player-facing Chronicle of the hidden hunt: one entry per event boss, in
# display order. A boss you've felled reveals its NAME and its trigger; one you
# haven't is a blank "???" -- so the page is a record of what you've proven, not
# a spoiler list. (Rendered in the pause menu's Chronicle panel.)
func hidden_hunt_entries() -> Array:
	var out: Array = []
	for id in EventBoss.ids():
		var ev: Dictionary = EventBoss.get_event(str(id))
		var killed: bool = event_bosses_ever_killed.has(id)
		out.append({
			"id": id,
			"name": str(ev.get("name", id)) if killed else "???",
			"killed": killed,
			"hint": str(ev.get("hint", "")) if killed else "a secret yet unproven",
			"difficulty": str(ev.get("difficulty", "")),
			"capstone": bool(ev.get("capstone", false)),
		})
	return out

func hidden_hunt_slain_count() -> int:
	var n := 0
	for id in EventBoss.ids():
		if event_bosses_ever_killed.has(id):
			n += 1
	return n

func _note_capstone_kill(id: String) -> void:
	if not event_bosses_ever_killed.has(id):
		event_bosses_ever_killed.append(id)
	# once all ten of the hunt have fallen (ever), point the way to the Horn ONCE
	if hunters_horn_announced:
		return
	var all_ten := true
	for hid in EventBoss.hunt_ids():
		if not event_bosses_ever_killed.has(hid):
			all_ten = false
			break
	if all_ten:
		hunters_horn_announced = true
		notify("The hunt is whole. Ten trophies… something can be forged from them.")
		log_event("combat", "All ten hidden bosses have fallen. The Hunter's Horn can be forged.")

# === subtle ambient omens (no text): a faint tell as the player nears a trigger ===
var _event_omen_fired: Dictionary = {}

func _tick_event_omen(id: String, p: Node) -> void:
	if _event_omen_fired.get(id, false):
		return
	var progress := _event_omen_progress(id, p)
	if progress >= 0.8 and progress < 1.0:
		_event_omen_fired[id] = true
		# felt, not told: a low toll + a brief darkening at the screen's edge
		play_sfx(SFX_CHIME, 0.32)
		var pl = get_tree().get_first_node_in_group("player")
		if pl != null and pl.has_method("play_event_omen"):
			pl.play_event_omen()

# 0..1 fraction toward a countable milestone (‑1 = not omenable, e.g. pure time).
func _event_omen_progress(id: String, p: Node) -> float:
	match id:
		"tallyman": return clampf(float(p.currency) / 8000.0, 0.0, 1.0) if not in_dungeon else 0.0
		"glutton_root": return clampf(float(run_trees) / 50.0, 0.0, 1.0)
		"drowned_chorus": return clampf(float(run_rocks) / 90.0, 0.0, 1.0)
		"effigy_king": return clampf(float(run_gold_spent) / 15000.0, 0.0, 1.0)
		"sleepless_warden": return clampf(float(floors_since_death) / 6.0, 0.0, 1.0) if in_dungeon else 0.0
		"grief_eater": return clampf(float(run_villager_deaths) / 3.0, 0.0, 1.0)
		"sable_hound": return clampf(float(run_kills) / 300.0, 0.0, 1.0)
	return -1.0

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

# ======================= THE PATROLS (dev design 2026-07-30) =======================
# The town's first reach OUTWARD. Warriors are posted into the deep to hold
# stretches you have already swept, instead of standing on the wall waiting for a
# siege -- which is the only thing they have ever done.
#
# BY BLOCK OF TEN FLOORS, not one by one: ten posts to think about instead of a
# hundred, matching the Deep Shrine cadence that already exists. A block only
# opens for posting once you have personally cleared every floor in it.
#
# THE COST IS THE POINT: a posted warrior is NOT on the wall (see
# village_defense_power). You cannot hold the deep and the gate with the same
# soldier, so warrior count finally means something beyond the siege clock.
#
# WHAT THEY BRING BACK: coins and materials, and nothing else, ever. No gear, no
# relics, no blueprints, no people. The player stays the only source of anything
# that matters -- warriors produce BULK, the player produces MEANING. (A mid-game
# upgrade may later add a fraction-of-a-percent gear chance; deliberately a
# delight, never a strategy.)
#
# AND IF YOU DON'T PATROL: evil seeps back. A block's creep climbs, and when it
# tops out those ten floors REVERT to uncleared -- the monsters are genuinely
# back for you too -- and the road down through them is cut. Waystones still
# reach past a fallen block, so it isolates rather than strands.
const PATROL_BLOCK_SIZE := 10
const PATROL_BLOCKS := 10                      # floors 1..100
const CREEP_BASE_PER_HOUR := 0.0030            # a swept block sours this fast...
const CREEP_DEPTH_PER_HOUR := 0.0011           # ...plus this much per block deep
const PATROL_SUPPRESS_PER_WARRIOR := 0.011     # each posted warrior pushes back
const PATROL_COIN_PER_WARRIOR_DAY := 3.0
const PATROL_MATS_PER_WARRIOR_DAY := 0.9
const PATROL_MATS := ["stone", "iron_shard", "wood"]

var patrol_posts: Dictionary = {}     # block (1..10) -> warriors posted
var block_creep: Dictionary = {}      # block (1..10) -> 0.0..1.0
var _patrol_accum := 0.0

func block_of_floor(level: int) -> int:
	return clampi(int((level - 1) / PATROL_BLOCK_SIZE) + 1, 1, PATROL_BLOCKS)

func block_floor_range(b: int) -> Array:
	var lo := (b - 1) * PATROL_BLOCK_SIZE + 1
	return [lo, lo + PATROL_BLOCK_SIZE - 1]

# A block may only be patrolled once YOU have swept every floor in it.
func block_is_cleared(b: int) -> bool:
	var r := block_floor_range(b)
	for lv in range(int(r[0]), int(r[1]) + 1):
		if not floor_is_cleared(lv):
			return false
	return true

func block_creep_of(b: int) -> float:
	return clampf(float(block_creep.get(b, 0.0)), 0.0, 1.0)

func patrol_at(b: int) -> int:
	return int(patrol_posts.get(b, 0))

func posted_warriors() -> int:
	var n := 0
	for b in patrol_posts.keys():
		n += int(patrol_posts[b])
	return n

# Warriors not already in the deep -- the pool you may post from.
func warriors_available_to_post() -> int:
	return maxi(0, warrior_count() - posted_warriors())

func post_patrol(b: int, n: int) -> bool:
	if b < 1 or b > PATROL_BLOCKS or not block_is_cleared(b):
		return false
	var want := maxi(0, n)
	var was: int = patrol_at(b)
	var others := posted_warriors() - was
	if want + others > warrior_count():
		want = maxi(0, warrior_count() - others)
	patrol_posts[b] = want
	if want <= 0:
		patrol_posts.erase(b)
	# only when the watch GROWS: assign_ui binds +1 and -1 to this same call, so an
	# unguarded march would also play while you were pulling the watch back home
	if want > was:
		SfxSynth.play_village(self, SfxSynth.SFX_PATROL_OUT)
	return true

# A block in enemy hands cuts the road: you cannot WALK past it. (Waystones still
# reach a woken shrine beyond it -- the network is what a fallen block makes
# valuable.) Returns 0 when the way down is clear.
func first_fallen_block() -> int:
	for b in range(1, PATROL_BLOCKS + 1):
		if block_creep_of(b) >= 1.0:
			return b
	return 0

func floor_is_road_blocked(level: int) -> bool:
	var fallen := first_fallen_block()
	return fallen > 0 and block_of_floor(level) > fallen

func tick_patrols(hours_passed: float) -> void:
	if hours_passed <= 0.0:
		return
	for b in range(1, PATROL_BLOCKS + 1):
		if not block_is_cleared(b):
			block_creep.erase(b)          # nothing to hold: it was never swept
			continue
		var posted := patrol_at(b)
		var rise := (CREEP_BASE_PER_HOUR + CREEP_DEPTH_PER_HOUR * float(b - 1)) * hours_passed
		var held := PATROL_SUPPRESS_PER_WARRIOR * float(posted) * hours_passed
		var creep := clampf(block_creep_of(b) + rise - held, 0.0, 1.0)
		block_creep[b] = creep
		if creep >= 1.0:
			_block_falls(b)
	_patrol_earnings(hours_passed)

# The deep takes a stretch back: those ten floors are wild again, and anyone
# posted there is driven home.
func _block_falls(b: int) -> void:
	var r := block_floor_range(b)
	var lost := 0
	for lv in range(int(r[0]), int(r[1]) + 1):
		if floors_cleared.has(str(lv)):
			floors_cleared.erase(str(lv))
			lost += 1
	block_creep[b] = 0.0
	var watch: int = patrol_at(b)
	patrol_posts.erase(b)
	# read BEFORE the erase, and only if a watch was actually standing there: a
	# block can fall with nobody posted, and that is a setback, not a bereavement
	if watch > 0:
		SfxSynth.play_village(self, SfxSynth.SFX_PATROL_LOST)
	if lost > 0:
		log_event("combat", "Floors %d-%d have fallen back to the dark — the road down is cut there." % [int(r[0]), int(r[1])])
		notify("⚠ The deep took floors %d-%d back. Sweep them again to open the road." % [int(r[0]), int(r[1])])

# What the patrols send home. DEPTH IS THE WHOLE POINT (dev call 2026-07-30:
# "you believe materials and gold are that important... when their village might
# get crushed?"). He was right -- coins and timber never justified taking
# warriors off a wall that losing means losing the run. So the deep pays:
# earnings scale hard with how far down the watch is set, and a patrol
# occasionally finds something on the bodies.
const PATROL_DEPTH_BONUS := 0.35                    # per block deeper
const PATROL_FIND_CHANCE_PER_WARRIOR_DAY := 0.012   # a find is a delight, not a supply

func _patrol_earnings(hours_passed: float) -> void:
	if posted_warriors() <= 0:
		return
	_patrol_accum += hours_passed
	while _patrol_accum >= 24.0:
		_patrol_accum -= 24.0
		var player = get_tree().get_first_node_in_group("player")
		var coin_total := 0
		var mat_total := 0
		var kind: String = PATROL_MATS[randi() % PATROL_MATS.size()]
		for b in patrol_posts.keys():
			var n := int(patrol_posts[b])
			if n <= 0:
				continue
			var deep := 1.0 + PATROL_DEPTH_BONUS * float(int(b) - 1)
			coin_total += int(round(PATROL_COIN_PER_WARRIOR_DAY * float(n) * deep))
			mat_total += _add_to_store(kind, PATROL_MATS_PER_WARRIOR_DAY * float(n) * deep)
			for _i in range(n):
				if randf() < PATROL_FIND_CHANCE_PER_WARRIOR_DAY:
					_patrol_find_gear(int(b), player)
		if player != null and player.has_method("add_currency") and coin_total > 0:
			player.add_currency(coin_total)
		if coin_total > 0 or mat_total > 0:
			log_event("economy", "The patrols sent up %d gold and %d %s from the deep." % [
				coin_total, mat_total, kind.replace("_", " ")])
			# a find is rolled in the loop just above and lands the same frame; it is
			# the bigger sound, so the plain coin lift stands aside for it
			if not SfxSynth.played_recently(SfxSynth.SFX_PATROL_FIND):
				SfxSynth.play_village(self, SfxSynth.SFX_PATROL_HOME)

# THE FIND. Rare, and SELF-BALANCING: a watch can only turn up gear the floors it
# holds would have yielded, using the game's own TIER_FLOORS brackets. Since a
# stretch can only be patrolled once YOU have swept it, a find is always behind
# your own progress -- floors 1-10 send up things you would sell, and only a deep
# watch (which costs many warriors off the wall) turns up anything you would wear.
# No percentage to tune: the depth gate does the balancing.
func _patrol_find_gear(b: int, player) -> void:
	if player == null or not ("inventory" in player) or player.inventory == null:
		return
	var deepest := b * PATROL_BLOCK_SIZE
	var pool := []
	for id in Inventory.ITEM_DEFS.keys():
		var cat := str(Inventory.ITEM_DEFS[id].get("category", ""))
		if not (cat in ["weapon", "armor", "relic"]):
			continue
		if str(id) in WANDERER_NEVER_SOLD:
			continue                       # some things are never loot
		var g := Inventory.get_grade(str(id))
		var rank := int(Inventory.GRADE_DEFS.get(g, {}).get("rank", 1))
		var br: Array = WeaponRoster.TIER_FLOORS[clampi(rank, 1, 8)]
		if deepest >= int(br[0]):
			pool.append(str(id))
	if pool.is_empty():
		return
	var pick: String = pool[randi() % pool.size()]
	if player.inventory.add_item(pick, 1) == 0:
		var r: Array = block_floor_range(b)
		log_event("economy", "The patrol on floors %d-%d found something on the bodies: %s." % [
			int(r[0]), int(r[1]), Inventory.get_display_name(pick)])
		notify("⚔ Your patrol sends up a find: %s" % Inventory.get_display_name(pick))
		SfxSynth.play_village(self, SfxSynth.SFX_PATROL_FIND)

func village_defense_power() -> float:
	# no Orin, no meteors: until he walks out of the dungeon the village's
	# nightly defense is the adventurers and whatever warriors it has raised
	var power = SIEGE_DEF_WIZARD if orin_arrived() else 0.0
	# THE PATROLS ARE NOT HERE (dev design 2026-07-30). Every warrior posted into
	# the deep is a warrior off this wall -- that trade IS the decision the patrol
	# system exists to pose. Counted off the top so it bites siege math directly.
	var away := posted_warriors()
	for v in rescued_villagers:
		if v.get("role_title", "") == "Recruit":
			continue   # still in training -- doesn't fight yet (matches warrior_count)
		if v.get("stat_name", "") == "Warrior" or v.get("role_key", "") == "Barracks":
			if away > 0:
				away -= 1
				continue          # this one is holding a stretch of the deep tonight
			# 7.3: the on-shift holds the wall at full worth; the off-shift
			# scrambles from their bunks at half
			# THE STANDING WATCH (power): a grown Barracks overlaps its shifts, so
			# the off-shift no longer scrambles from their bunks at half worth
			power += SIEGE_DEF_PER_WARRIOR * (1.0 if (warrior_on_duty(v) or has_building_power("Barracks")) else 0.5)
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
	# THE MUSTER (Warchief): the horn calls EVERYONE. Every able adult who isn't
	# already a fighter takes up something and stands to the wall -- a militia is
	# worth a fraction of a trained warrior each, but a full town is a real wall.
	# (This is what a Warchief is FOR now; their old +15% training is a trickle.)
	if has_leader_power("Barracks"):
		var militia := 0
		for v in rescued_villagers:
			if v.get("is_kid", false) or v.get("shadow", false):
				continue
			if str(v.get("role_title", "")) == "Recruit":
				continue
			if str(v.get("stat_name", "")) == "Warrior" or str(v.get("role_key", "")) == "Barracks":
				continue          # already counted above as a fighter
			militia += 1
		power += MUSTER_PER_ABLE_ADULT * float(militia)
	# the RAMPART itself blunts the wave: a higher tier is taller stone with
	# traps set into it, worth real defense even before a body mans it
	power += wall_defense_bonus()
	# MORALE NO LONGER TOUCHES DEFENSE (dev 2026-07-29): "morale has to affect only
	# regular villagers, not combat people or leaders." Everything counted above is
	# a TRAINED fighter (Orin, warriors, heroes, adventurers, the Warchief) or the
	# stone wall itself -- none of them fight worse because the town is grieving.
	# Scaling this by morale also built a death SPIRAL the marathon sim exposed: a
	# siege kills villagers -> death-shock craters morale -> the multiplier (was
	# 0.5x at low morale) halved the town's defense -> the next wave killed more,
	# and casualties burn adventurers first (permanent). Morale still drives what
	# it should: villager output/income (village_morale_multiplier) and wellbeing.
	return power

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
	# the Weeping Hour holds the war clock: one night, one story at a time
	if weeping_tonight:
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
	resolve_siege_offline(tier, black)

# Kaldos, the Tidecaller (the Ten): the Dock's deep-catches haul MATERIALS as
# well as food -- one basic material per in-game day per staffed dock, dropped
# into the player's bag. (The dock has no food loop of its own yet, so this is
# the boon's material half wired to the real hook that exists.)
var _deep_catch_accum := 0.0
const DEEP_CATCH_MATERIALS = ["iron_shard", "slime", "resin"]

# THE TIDE TABLE (Harbormaster): they read the water, and the boats come back
# with something sealed. Runs on its own clock beside the Dock's food.
func tick_tide_table(hours_passed: float) -> void:
	if not has_leader_power("Fishing Dock") or dock_worker_count() == 0:
		return
	_tide_table_accum += hours_passed
	while _tide_table_accum >= TIDE_TABLE_DAYS * 24.0:
		_tide_table_accum -= TIDE_TABLE_DAYS * 24.0
		var crate: String = TIDE_TABLE_CRATES[randi() % TIDE_TABLE_CRATES.size()]
		var player = get_tree().get_first_node_in_group("player")
		if player and "inventory" in player and player.inventory:
			# the add_item-leftover family: never claim a haul the pack refused
			if player.inventory.add_item(crate, 1) == 0:
				log_event("economy", "The Harbormaster's boats landed %s from the deep water." % Inventory.get_display_name(crate))
				notify("⚓ The Tide Table: the boats brought back %s." % Inventory.get_display_name(crate))

func tick_deep_catches(hours_passed: float) -> void:
	# THE LONG HAUL (Fishing Dock power): a grown Dock sends its boats out past the
	# shallows on its own -- the deep catch no longer waits on Kaldos being freed.
	if not ten_freed("ten_kaldos") and not has_building_power("Fishing Dock"):
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
			# honest on a full bag (the add_item-leftover family, bug hunt
			# 2026-07-28): a discarded haul must say so, not vanish
			var mat: String = DEEP_CATCH_MATERIALS[randi() % DEEP_CATCH_MATERIALS.size()]
			if player.inventory.add_item(mat, 1) > 0:
				log_event("economy", "The Dock's deep-catch came up, but your bag was full -- the %s went back to the water." % Inventory.get_display_name(mat))

# Abstract off-screen resolution used while the player is away.
var maera_stabilized_this_siege := false

# === FISHING (renewability pillar 3, dev-chosen 2026-07-28) ===
# The data + rolls live in fishing.gd; the cast/bite/strike choreography in
# player.gd. This block owns the STARTER ROD (raising the Dock leaves a
# Willow Rod -- the ladder above it is FISHED, never dropped or sold) and
# the HARBORMASTER'S DAILY: once per in-game day, while the Dock stands
# staffed, Doran names an oddity that only bites while his quest is live.
# Turn-in logic lives HERE, not in the UI, so it tests headless.
var fishing_quest: Dictionary = {}     # {"id": odd_*, "name": ..., "posted_day": N}
var fishing_quests_done := 0
var fishing_last_post_day := -1        # one posting per day, turned in or not
var fishing_last_oddity := ""          # never the same ask twice running
var willow_rod_granted := false

const FISHING_QUEST_BASE_GOLD := 40
const FISHING_QUEST_GOLD_STEP := 15    # each landed oddity pays a little more
const FISHING_QUEST_GOLD_CAP := 160
const FISHING_PEARLBOUND_EVERY := 5    # every 5th oddity pays the epic crate

func fishing_quest_oddity() -> String:
	return str(fishing_quest.get("id", ""))

func tick_fishing() -> void:
	# the starter rod, once -- and self-healing: a bag already holding a rod
	# (a Rewound Hour carries everything you own) is never handed a second
	if not willow_rod_granted and is_building_operational("Fishing Dock"):
		var player = get_tree().get_first_node_in_group("player")
		if player and "inventory" in player and player.inventory:
			var owns_rod := false
			for rid in ["tool_rod_willow", "tool_rod_wyrmbone", "tool_rod_moonline"]:
				if player.inventory.get_count(rid) > 0:
					owns_rod = true
			if owns_rod:
				willow_rod_granted = true
			elif player.inventory.add_item("tool_rod_willow", 1) == 0:
				willow_rod_granted = true
				notify("🎣 The dockhands leave a WILLOW ROD for the one who raised the pier. Wield it and cast at the water.")
				log_event("village", "The Dock's first gift: a willow rod, and all the patience it asks.")
	# the daily posting -- at most one per day, and never while one hangs open
	if fishing_quest.is_empty() \
			and is_building_operational("Fishing Dock") and count_workers("Fishing Dock") > 0:
		var today := int(game_hours / 24.0)
		if today > fishing_last_post_day:
			fishing_last_post_day = today
			var pool: Array = []
			for odd in Fishing.QUEST_ODDITIES:
				if str(odd.get("id", "")) != fishing_last_oddity:
					pool.append(odd)
			var pick: Dictionary = pool[randi() % pool.size()]
			fishing_last_oddity = str(pick.get("id", ""))
			fishing_quest = {"id": pick.get("id", ""), "name": pick.get("name", ""), "posted_day": today}
			notify("🎣 Doran wants a strange catch: %s. (It only bites while he's asking.)" % str(pick.get("name", "")))
			log_event("village", "The Harbormaster posted his daily oddity: %s." % str(pick.get("name", "")))

# Turn-in, called by assign_ui's Dock section with the live player. Returns
# "" on success, else a short reason (the summon_event_boss contract).
func fishing_turn_in(player) -> String:
	var oid := fishing_quest_oddity()
	if oid == "":
		return "No catch is asked for today."
	if not (player and "inventory" in player and player.inventory):
		return "No one to pay."
	if player.inventory.get_count(oid) <= 0:
		return "You haven't landed %s yet." % str(fishing_quest.get("name", "the catch"))
	player.inventory.remove_item(oid, 1)
	var pay: int = mini(FISHING_QUEST_GOLD_CAP, FISHING_QUEST_BASE_GOLD + FISHING_QUEST_GOLD_STEP * fishing_quests_done)
	player.currency += pay
	if player.has_method("update_currency_display"):
		player.update_currency_display()
	fishing_quests_done += 1
	var crate := "crate_pearlbound" if fishing_quests_done % FISHING_PEARLBOUND_EVERY == 0 else "crate_driftwood"
	player.inventory.add_item(crate, 1)   # the oddity just left the bag, so its slot is free for the crate
	fishing_quest = {}
	notify("🎣 Doran pays %dg and a %s for the oddity." % [pay, Inventory.get_display_name(crate)])
	log_event("village", "An oddity landed and paid for: the Harbormaster's ledger grows (%d so far)." % fishing_quests_done)
	return ""

# === THE REAVER CARAVAN (renewability pillar 2, dev-chosen 2026-07-28) ===
# A Goblin-Army-INSPIRED marching invasion, never a copy: reavers want the
# ROADS, not the walls. Once the deep knows your name (floor 12+), a caravan
# rolls up the EAST road every few days -- announced an hour out (dust rises;
# no Watchtower needed, a caravan is VISIBLE), then three structured waves
# and a named captain. Repel it all and the REAVER CACHE pays out: gold,
# materials, and one themed weapon you don't own. It re-arms forever --
# a set-piece party with a loot table, not another siege.
const CARAVAN_FIRST_HOURS := 60.0        # the first rolls in late on day 3
const CARAVAN_GAP_MIN := 44.0            # then every ~2-4 days
const CARAVAN_GAP_MAX := 92.0
const CARAVAN_WARN_HOURS := 1.0          # dust on the road, an hour out
const CARAVAN_MIN_FLOOR := 12            # the roads only care once the deep does
const CARAVAN_WEAPON_POOL = ["wpn_hookbill", "wpn_ratterdart", "wpn_boarspit",
	"wpn_gutterbow", "wpn_bonepick", "wpn_tithegather", "wpn_marshlash",
	"wpn_reaperrebuke", "wpn_debtblade", "wpn_omenblade"]
const CARAVAN_CAPTAIN_NAMES = ["Grask Half-Hand", "Mora of the Long Whip",
	"Vell Ninefingers", "The Toll-Taker", "Brannoc Redcart", "Iron-Tooth Sella"]

var hours_until_caravan := CARAVAN_FIRST_HOURS
var caravan_warned := false
var caravans_seen := 0
var live_caravan_active := false

func caravan_tier() -> int:
	return maxi(2, current_siege_tier())

func tick_caravans(hours_passed: float) -> void:
	if despair_dead or harvest_at_home:
		return
	if not opening_done and not dev_mode:
		return
	if deepest_level_reached < CARAVAN_MIN_FLOOR:
		return
	if live_caravan_active:
		if in_dungeon:
			live_caravan_active = false   # abandoned mid-fight: resolves abstractly
		else:
			return
	# the road waits out a weeping night too
	if weeping_tonight:
		return
	hours_until_caravan -= hours_passed
	# the dust rises an hour out -- the one warning every eye can see
	if not caravan_warned and hours_until_caravan <= CARAVAN_WARN_HOURS and hours_until_caravan > 0.0:
		caravan_warned = true
		notify("☁ Dust on the east road — a reaver caravan, about an hour out.")
		log_event("combat", "Dust rose on the east road: reavers, coming to collect.")
	if hours_until_caravan <= 0.0:
		hours_until_caravan = randf_range(CARAVAN_GAP_MIN, CARAVAN_GAP_MAX)
		caravan_warned = false
		trigger_caravan()

func trigger_caravan() -> void:
	caravans_seen += 1
	var tier := caravan_tier()
	if not in_dungeon:
		var mgr = get_tree().get_first_node_in_group("siege_manager")
		if mgr and mgr.has_method("start_caravan"):
			mgr.start_caravan(tier)
			live_caravan_active = true
			return
	resolve_caravan_offline(tier)

# Away, the caravan resolves like any road story: held, or paid for.
func resolve_caravan_offline(tier: int) -> void:
	if village_defense_power() >= float(tier):
		grant_reaver_cache(tier, true)
		log_event("combat", "A reaver caravan rolled up the east road while you were away — the defense drove it off. Its cache waits by the gate.")
		return
	log_event("combat", "A reaver caravan struck while you were away — the east road paid the toll.")
	register_villager_deaths(1)
	var toll: int = mini(120, 25 * tier)
	var pl = get_tree().get_first_node_in_group("player")
	if pl and "currency" in pl:
		pl.currency = maxi(0, int(pl.currency) - toll)
		log_event("economy", "The reavers took %d gold in passage-toll." % toll)

# The Reaver Cache: gold, materials, and ONE themed weapon you don't own.
func grant_reaver_cache(tier: int, offline := false) -> void:
	var pl = get_tree().get_first_node_in_group("player")
	if pl == null or not "inventory" in pl or pl.inventory == null:
		return
	var gold: int = 40 + 25 * tier
	pl.currency += gold
	if pl.has_method("update_currency_display"):
		pl.update_currency_display()
	pl.inventory.add_item("iron_shard", 2 + tier / 2)
	if tier >= 6:
		pl.inventory.add_item("ember_crystal", 1)
	var pool := []
	for id in CARAVAN_WEAPON_POOL:
		if pl.inventory.get_count(id) == 0 and get_equipped_item_ids().find(id) == -1 \
				and pl.active_weapon_id != id:
			pool.append(id)
	var arm := ""
	if not pool.is_empty():
		arm = pool[randi() % pool.size()]
		pl.inventory.add_item(arm, 1)
	var line := "The Reaver Cache: %dg, materials%s." % [gold,
		(", and the %s" % Inventory.get_display_name(arm)) if arm != "" else ""]
	if offline:
		log_event("economy", line)
	else:
		notify("📦 " + line)
		log_event("economy", line)

# === THE WEEPING HOUR (night event, dev-chosen 2026-07-28) ===
# A rare whole NIGHT where the forest itself grieves -- Terraria's blood
# moon INSPIRED it, but Deepwood's night is sorrow made weather: pale
# weepers stream at the walls from both roads until dawn, many and quick
# but never heavy (the boss rule holds off the walls too: difficulty is
# pressure, not one-shots). It only happens while you are HOME -- it is a
# set-piece, not an away-punishment -- and it yields to every bigger
# story: never during the Harvest, a live siege, or a caravan. Surviving
# to dawn pays PALE TEARS (the Teardraught's only source) and the first
# survived night leaves THE MOURNER'S LOCKET. The roster stays closed:
# sorrow pays in relics and reagents, never weapons.
const WEEP_MIN_FLOOR := 8            # a home fight -- earlier than the roads care
const WEEP_CHANCE := 0.22            # per qualifying dusk
const WEEP_MIN_GAP_HOURS := 96.0     # the forest cannot weep twice in 4 days
const WEEP_DUSK_FROM := 20.0         # rolls at full dark...
const WEEP_DAWN := 5.0               # ...and dries its eyes at first light
const WEEP_LOCKET_KILLS := 5         # the Locket is EARNED: hide all night and it stays in the grass
var weeping_tonight := false
var hours_since_weeping := 0.0
var weepings_seen := 0
var weepings_survived := 0
var weeping_kills := 0               # tonight's tally, for the dawn word
var _weep_last_tod := -1.0

# Every gate EXCEPT the dice, separated so the suite can prove the gates
# without fighting randf().
func weeping_eligible() -> bool:
	if despair_dead or harvest_at_home or live_siege_active or live_caravan_active or lantern_tonight:
		return false
	if in_dungeon:
		return false
	if not opening_done and not dev_mode:
		return false
	if deepest_level_reached < WEEP_MIN_FLOOR:
		return false
	return hours_since_weeping >= WEEP_MIN_GAP_HOURS

func tick_weeping(hours_passed: float) -> void:
	hours_since_weeping += hours_passed
	var tod := time_of_day()
	var was: float = _weep_last_tod
	_weep_last_tod = tod
	if weeping_tonight:
		# dawn ends it -- STEP-PROOF (bug hunt 2026-07-28): the old "crossing
		# into [5,12)" check missed any catch-up tick that JUMPED the window
		# (leave at 4am, return at 2pm), leaving the night weeping through
		# the whole next day. If it is daytime at all, the night is over.
		if tod >= WEEP_DAWN and tod < WEEP_DUSK_FROM:
			end_weeping(false)
		return
	# the dice roll exactly once, at the crossing into full dark
	if not (was >= 0.0 and was < WEEP_DUSK_FROM and tod >= WEEP_DUSK_FROM):
		return
	if not weeping_eligible():
		return
	if randf() > WEEP_CHANCE:
		return
	start_weeping()

func start_weeping() -> void:
	weeping_tonight = true
	weeping_kills = 0
	hours_since_weeping = 0.0
	weepings_seen += 1
	notify_urgent("🌧 THE WEEPING HOUR — the forest itself grieves tonight. The pale ones walk until dawn. Hold your home.")
	log_event("combat", "The forest wept: pale ones walked against the walls all night.")
	var mgr = get_tree().get_first_node_in_group("siege_manager")
	if mgr and mgr.has_method("start_weeping_night"):
		mgr.start_weeping_night(maxi(1, current_siege_tier()))

# interrupted=true (a bigger story broke the night: the Harvest, a load)
# ends it quietly and pays NOTHING; dawn pays the tally.
func end_weeping(interrupted: bool) -> void:
	if not weeping_tonight:
		return
	weeping_tonight = false
	var mgr = get_tree().get_first_node_in_group("siege_manager")
	if mgr and mgr.has_method("end_weeping_night"):
		mgr.end_weeping_night()
	if interrupted:
		return
	weepings_survived += 1
	var pl = get_tree().get_first_node_in_group("player")
	if _has_inventory(pl):
		var tears: int = 2 + weeping_kills / 4
		pl.inventory.add_item("tear_pale", tears)
		var extra := ""
		# the first FOUGHT night leaves the Locket -- once, never a second
		# into a Rewound-Hour bag that already carries it, and never for
		# hiding indoors while the pale ones walked (bug hunt 2026-07-28)
		if weeping_kills >= WEEP_LOCKET_KILLS \
				and pl.inventory.get_count("relic_mourner") == 0 \
				and get_equipped_item_ids().find("relic_mourner") == -1:
			pl.inventory.add_item("relic_mourner", 1)
			extra = " Something glints in the wet grass: THE MOURNER'S LOCKET."
		notify("🌅 Dawn. The forest dries its eyes — %d pale ones laid to rest, %d Pale Tears gathered.%s" % [weeping_kills, tears, extra])
		log_event("combat", "The Weeping Hour passed: %d laid to rest by morning." % weeping_kills)

# === THE LANTERN NIGHT (festival event, 2026-07-28) ===
# The Weeping Hour's WARM MIRROR -- the first event where nothing attacks.
# On a rare dusk in a town doing WELL (morale 6/10+), Deepwood hangs its
# lanterns: the fair pitches by lantern light (a wanderer's cart arrives or
# stays the whole night, wares 15% kinder), sky lanterns rise over the
# roofs, and at dawn the shared joy EASES OLD GRIEF -- a one-time mend of
# morale_death_shock, because a night of light is how a town heals. It
# yields to every heavier story and never shares a dark with the weeping.
const LANTERN_CHANCE := 0.25
const LANTERN_MIN_MORALE := 60       # joy is EARNED: a struggling town hangs no lanterns
const LANTERN_MIN_GAP_HOURS := 120.0
const LANTERN_SHOCK_MEND := 0.35     # dawn forgives a third of the town's carried grief
const LANTERN_DISCOUNT := 0.85
var lantern_tonight := false
var hours_since_lantern := 0.0
var lanterns_seen := 0
var _lantern_last_tod := -1.0

func lantern_eligible() -> bool:
	if despair_dead or harvest_at_home or live_siege_active or live_caravan_active or weeping_tonight:
		return false
	if in_dungeon:
		return false
	if not opening_done and not dev_mode:
		return false
	if village_morale() < LANTERN_MIN_MORALE:
		return false
	return hours_since_lantern >= LANTERN_MIN_GAP_HOURS

func tick_lantern(hours_passed: float) -> void:
	hours_since_lantern += hours_passed
	# its OWN dusk sample: tick_weeping runs first and has already advanced
	# _weep_last_tod to the current tod, so reading theirs never sees a
	# crossing -- caught before it ever shipped
	var tod := time_of_day()
	var was: float = _lantern_last_tod
	_lantern_last_tod = tod
	if lantern_tonight:
		# step-proof like the weeping: daytime takes the lanterns down no
		# matter how large the tick that got us here
		if tod >= WEEP_DAWN and tod < WEEP_DUSK_FROM:
			end_lantern()
		return
	# the weeping rolled this same crossing first -- a grieving night wins
	if weeping_tonight:
		return
	if not (was >= 0.0 and was < WEEP_DUSK_FROM and tod >= WEEP_DUSK_FROM):
		return
	if not lantern_eligible():
		return
	if randf() > LANTERN_CHANCE:
		return
	start_lantern()

func start_lantern() -> void:
	lantern_tonight = true
	hours_since_lantern = 0.0
	lanterns_seen += 1
	notify("🏮 THE LANTERN NIGHT — Deepwood hangs its lights. The fair pitches by lantern glow, and nobody is afraid tonight.")
	log_event("village", "The town hung its lanterns and kept the night warm.")
	# the fair: a cart arrives for the night, or the one already here stays late
	if wanderer.is_empty():
		_wanderer_arrive()
	if not wanderer.is_empty():
		wanderer["dwell"] = maxf(float(wanderer.get("dwell", 12.0)), 14.0)
		# prices are BAKED at arrival (hunt round 3): a cart already standing
		# when the lanterns rise kept its old tags -- re-bake the whole board
		# so the festival's 15% reaches it too (dawn honours the kind prices
		# for as long as that cart stays; a deal lit is a deal kept)
		for e in wanderer.get("stock", []):
			# the showpiece is a flagged stock entry -- re-bake WITH its markup,
			# or the festival would sell the piece under the cloth at base price
			var mark: float = WANDERER_SHOWPIECE_MARKUP if e.get("showpiece", false) else 1.0
			e["price"] = maxi(2, int(round(float(_wanderer_price(str(e.get("id", "")))) * mark)))
		log_event("economy", "%s pitched by lantern light — staying the night, prices kind." % str(wanderer.get("name", "A wanderer")))

func end_lantern() -> void:
	if not lantern_tonight:
		return
	lantern_tonight = false
	# dawn: the shared joy eases the town's CARRIED grief, once
	var eased := morale_death_shock * LANTERN_SHOCK_MEND
	morale_death_shock = maxf(0.0, morale_death_shock - eased)
	if eased > 0.5:
		notify("🌅 The lanterns come down softly — old grief sits a little lighter on Deepwood.")
	else:
		notify("🌅 The lanterns come down softly. A good night.")
	log_event("village", "The Lantern Night ended at dawn; the town woke gentler.")

# Who was actually standing there, in the away-report's words. Counts real posted
# adventurers, the Barracks' soldiers and Orin -- so the diary names the defence
# the player chose, and an empty wall reads as the warning it is.
func _away_line_summary() -> String:
	ensure_adventurers()
	var on_wall := 0
	var on_patrol := 0
	for id in adventurers.keys():
		var a: Dictionary = adventurers[id]
		if not a["rescued"] or a["dead"]:
			continue
		if str(a["station"]) == "wall": on_wall += 1
		elif str(a["station"]) == "city": on_patrol += 1
	var soldiers := 0
	for v in rescued_villagers:
		if v.get("is_kid", false) or str(v.get("role_title", "")) == "Recruit":
			continue
		if str(v.get("stat_name", "")) == "Warrior" or str(v.get("role_key", "")) == "Barracks":
			soldiers += 1
	var parts := []
	if on_wall > 0: parts.append("%d on the wall" % on_wall)
	if on_patrol > 0: parts.append("%d on patrol" % on_patrol)
	if soldiers > 0: parts.append("%d of the Barracks" % soldiers)
	if orin_arrived(): parts.append("Orin")
	if wall_level > 1: parts.append("a tier-%d rampart" % wall_level)
	if parts.is_empty():
		return "nobody at all"
	return ", ".join(parts)

func resolve_siege_offline(tier: int, black := false) -> void:
	away_report.sieges += 1
	maera_stabilized_this_siege = false
	# THE STORY OF IT (dev ask 2026-07-29). An away siege can't be acted out -- the
	# village scene is unloaded while you're in the deep, so there are no bodies to
	# fight with -- but the report should still say WHO stood there and what came at
	# them, not just hand back a tally. Everything named here is real state: the
	# wave size uses siege_manager's own count curve, the line is who you actually
	# posted. (The OUTCOME stays the defense-power comparison below on purpose: the
	# live combat numbers are tuned around the PLAYER doing most of the killing, so
	# a literal round-by-round sim of the town fighting alone loses every time --
	# measured at tier 15, defenders need 26 rounds to clear a wave that wipes them
	# in 1.4. Narrate the fight faithfully; don't re-decide it with numbers that
	# assume someone who isn't there.)
	var wave: int = mini(3 + tier, 12 + (6 if black else 0))
	log_event("combat", "%s %d raiders came up the road, and %s stood to meet them." % [
		"🌑 A BLACK TIDE —" if black else "A tier-%d wave —" % tier, wave, _away_line_summary()])
	if village_defense_power() >= float(tier):
		away_report.repelled += 1
		log_event("combat", "The line held. Nobody was lost.")
		return
	log_event("combat", "A tier-%d siege struck while you were away — the wall could not hold it all." % tier)
	# THE ATTRITION CURVE (2026-07-29). This was `ceil(tier - defense)` -- ONE life
	# per single point of unmet threat, uncapped -- so a wall that ALMOST held bled
	# exactly as badly as one that folded, and a tier-21 wave against defense 15
	# took SIX souls. With a wave landing every 12 game-hours (~5 real minutes,
	# ~54 per session) and casualties spending ADVENTURERS FIRST and permanently,
	# defense only ever ratcheted down while depth pushed tier up: guaranteed
	# collapse. The marathon sim measured it -- the town peaked at 27 people around
	# floor 27, then fell to ~12-15 and could never recover, against the intended
	# city scale of 70-80.
	# A near-miss now costs far less than a rout, and no ORDINARY wave can gut the
	# town in one night. The Black Tide is exempt: it is the designed catastrophe,
	# and it is announced ahead of time so the player can come home for it.
	var shortfall := float(tier) - village_defense_power()
	var casualties = int(ceil(shortfall / SIEGE_SHORTFALL_PER_CASUALTY))
	if not black:
		casualties = mini(casualties, SIEGE_MAX_CASUALTIES)
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
	# a player-deleted hall stays down until rebuilt: remove_building never zeroes the
	# stage, so without this a deleted Bar/Blacksmith/etc. still inflates morale, fills
	# role slots and passes the finale gate. removed_buildings is erased on rebuild.
	if removed_buildings.has(building_key):
		return false
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
const STANDING_HARVEST_COOLDOWN := 72.0      # Farm power: hours before the reserve refills
var _harvest_reserve_cd := 0.0
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
	# children eat HALF (bible 12.17, decided 2026-07-17 -- built at last in
	# the numbers pass: every eater drew a full ration until S12 caught it)
	var plates := 0.0
	for v in rescued_villagers:
		if not v.get("shadow", false):
			plates += 0.5 if v.get("is_kid", false) else 1.0
	return plates * FOOD_PER_VILLAGER_PER_DAY / 24.0

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
	# building_output_multiplier folds in BOTH the upgrade level and the adjacency
	# synergy (Farm beside the Dock = one larder filled from field and water).
	# THE FULL TABLE (Harvestmaster): the master is worth a crew -- the fields are
	# worked even with nobody seated at them. (Their old +60% is now a trickle;
	# THIS is what a Harvestmaster is for.)
	var hands := float(farm_worker_count())
	if has_leader_power("Farm"):
		hands = maxf(hands, float(MASTER_ALONE_CREW))
	var farm := hands * FOOD_PER_FARMER_PER_DAY / 24.0 * (1.0 + HARVESTMASTER_FOOD_BONUS * seated_leaders("Farm")) * (2.0 if ten_freed("ten_sylvara") else 1.0) * building_output_multiplier("Farm")
	# The Fishing Dock is the economy's PREMIUM food source (its fish feed
	# fewer mouths per worker than the Farm's grain, but the sea never has a
	# bad harvest). This also makes Kaldos' boon honest end to end: the Dock
	# genuinely yields food, and with the Tidecaller freed, materials as well.
	var dock := float(dock_worker_count()) * FOOD_PER_FISHER_PER_DAY / 24.0 * (1.0 + HARVESTMASTER_FOOD_BONUS * seated_leaders("Fishing Dock")) * building_output_multiplier("Fishing Dock")
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
	# THE STANDING HARVEST (Farm power): a grown Farm holds grain back, and opens
	# the reserve rather than watch the town starve. It buys a day at a time and
	# needs STANDING_HARVEST_COOLDOWN hours to fill again -- so neglect still
	# bites, it just can't kill you the first time you're late home.
	_harvest_reserve_cd = maxf(0.0, _harvest_reserve_cd - hours_passed)
	if village_food <= 0.0 and _harvest_reserve_cd <= 0.0 and has_building_power("Farm") \
			and not rescued_villagers.is_empty():
		_harvest_reserve_cd = STANDING_HARVEST_COOLDOWN
		village_food = minf(food_capacity(), food_consumption_per_hour() * 24.0)
		food_empty_hours = 0.0
		log_event("village", "The Farm opened its reserve — the Standing Harvest kept Deepwood fed.")
		notify("🌾 The Standing Harvest opened the Farm's reserve.")
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
# Numbers pass 2026-07-28 (S8, tuned to the bible's stated shape 12.16:
# "5-6 deaths ~= a 10/10 town -> 1-2"): 2.0/kill left six funerals at a
# meter of 7.3 -- grief as a rounding error. At 13/kill five deaths land
# ~3, six land ~1.7, and the cap keeps the floor above zero. Decay is
# unchanged: ~3 days of mourning, half that under Seraphel's boon.
const DEATH_SHOCK_PER_KILL := 13.0       # morale points lost per villager killed (0-100)
const DEATH_SHOCK_MAX := 78.0            # one catastrophe can't zero morale outright
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
		# THE TEN ARE ABOVE THE DOMESTIC LOOP (audit fix): they can never pair
		# (find_available_parents skips unbreakable, by design) and never own a
		# cottage, so the solitude penalty + street housing capped a legend's
		# spirit at ~8.2 FOREVER -- and with all Ten freed (mandatory for the
		# finale) village morale could never round back to 100: the celebration
		# layer and the Chronicle's "peak" line were mathematically dead. A
		# freed legend stands content: housed by their own legend, whole alone.
		if v.get("unbreakable", false):
			t += 1.6
		else:
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
	# ...and MORE if you live or work in earshot of it (Phase 4 aura): the town-wide
	# lift above is having a Bar at all; this is having it at the end of your street.
	if in_aura("Bar", v):
		t += AURA_BAR_MORALE
	# the Dock's PREMIUM food (5.7): fish on the table lifts every spirit --
	# the quality-food edge, slack on top like the boons (never gate-required)
	if has_food() and is_building_operational("Fishing Dock") and count_workers("Fishing Dock") > 0:
		t += 0.3
	t += 0.4 * clampf(float(rescued_villagers.size()) / MORALE_POP_TARGET, 0.0, 1.0)
	t += (LEADER_MORALE_EACH / 10.0) * (seated_leaders("Tavern") + seated_leaders("Bar"))
	# ...and the BARMEN behind the counter, who were declared but never read: a
	# tavern with hands pouring is a warmer room than one with only a keeper.
	# Capped so a fully-staffed tavern is a real lift, not a morale cheat code.
	if is_building_operational("Tavern") and has_food():
		t += minf(BARMAN_MORALE_EACH * float(count_leader_holders("Tavern", "Barman")), 1.0)
	# Ilo, the Nameless Bard (the Ten): his songs lift the whole village
	if ten_freed("ten_ilo"):
		t += 1.0
	t -= morale_death_shock / 10.0                               # the town's grief weighs on everyone
	# A SICK TOWN IS A LOW TOWN (dev ruling 2026-08-06). For the ordinary illness
	# this IS the mechanic -- it cannot kill and it does no damage, so if the mood
	# did not land here it would cost the player literally nothing. Capped, because
	# a rough week should be a heavy town, not a morale wipe that tips a whole
	# village over the despair line and starts rotting people into demons.
	if not sick.is_empty():
		t -= minf(SICK_MORALE_PER_CASE * float(sick_count() - plague_count())
			+ PLAGUE_MORALE_PER_CASE * float(plague_count()), SICK_MORALE_CAP)
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
	# THE LONG NIGHT (Tavern power): somewhere warm to sit means no heart falls
	# ALL the way to nothing -- a floor under the town's spirit, not a bonus on top
	if has_building_power("Tavern") and has_food():
		avg100 = maxf(avg100, LONG_NIGHT_MORALE_FLOOR)
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
# Numbers pass 2026-07-28 (S8): the immediate hits carry the bible's
# devastation ("5-6 deaths ~= 10/10 -> 1-2" -- it lands regardless of
# witness); the town-shock target-depression above carries the DURATION
# of the grief. At 0.4/death six funerals only nicked the meter to ~7.
const DEATH_SHOCK_CLOSE := 1.9         # within the near ring, per death
const DEATH_SHOCK_NEAR_RADIUS := 260.0
const DEATH_SHOCK_FAR_RADIUS := 520.0
const DEATH_SHOCK_ABSTRACT := 1.2      # unwitnessed news, per death

func register_villager_deaths(n: int, epicenter: Vector2 = Vector2(INF, INF)) -> void:
	if n <= 0:
		return
	run_villager_deaths += n   # feeds the Grief-Eater's hidden trigger
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
		# reach entirely (pledged, needless); the Ten are UNBREAKABLE -- hope not even
		# a starving village can kill (every other loss path already exempts them).
		# None ever enters the rot.
		# THE UNBROKEN LIGHT (Shrine power): while the light holds, despair takes
		# root in nobody -- the Shrine stops corruption SPREADING, which is a
		# different mercy from cleansing someone it already took.
		if is_warrior_villager(v) or v.get("shadow", false) or v.get("unbreakable", false) \
				or has_building_power("Shrine"):
			villager_rot.erase(id)
			continue
		# HALLOWED GROUND (Phase 4 aura): the same mercy, but EARNED BY PLACEMENT
		# rather than by level. The Shrine's light reaches the homes and workplaces
		# around it, so despair cannot open its window there -- not a slower clock,
		# no clock. Stand it where the fragile live, not off in a corner. The
		# level-4 power above is this same protection extended to everyone.
		if in_aura("Shrine", v):
			if villager_rot.has(id):
				villager_rot.erase(id)
				log_event("people", "%s was pulled back — the Shrine's light reaches their door." % str(v.get("name", "?")))
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
			if not is_warrior_villager(v) and not v.get("unbreakable", false):
				pool.append(str(v.get("id", "")))
		pool.shuffle()
		near_ids = pool.slice(0, 2)
	for v in rescued_villagers:
		var vid := str(v.get("id", ""))
		if not near_ids.has(vid) or is_warrior_villager(v) or v.get("shadow", false) or v.get("unbreakable", false):
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

# ========================= FIRE (dev design 2026-08-06) =========================
# THE SECOND FACE OF ADJACENCY. Every placement rule so far has been pure upside:
# stand the Mine beside the forge and you are simply better off, so the optimal
# economic layout was also the only sane one and the "puzzle" had one answer.
# Fire spreads along the SAME neighbour map the synergies use -- so the tight,
# perfectly-paired row that earns the most is now also the row that burns whole.
# That is the tension the placement layer was missing.
#
# It scales with the town, like the sickness: a village of four halls rarely
# burns, a full city has hearths and forges everywhere. The buildings that carry
# a real flame are likelier to start it -- the smithy above all.
#
# FIGHTING IT IS THE BUILDERHOUSE'S JOB, which finally gives that crew something
# urgent to do; but a big blaze outruns a small crew, so it is your emergency
# too. Left alone a hall burns back down its build stages and must be raised
# again -- costly, never unrecoverable.
const FIRE_MIN_BUILDINGS := 5             # a hamlet of huts rarely goes up
const FIRE_CHANCE_PER_DAY := 0.018        # ...per standing hall beyond that
const FIRE_HEARTH_MULT := 3.0             # forges and hearths start most of them
const FIRE_HEARTHS := ["Blacksmith", "Tavern", "Bar", "Barracks"]
const FIRE_SPREAD_CHANCE_PER_DAY := 0.30  # to an IMMEDIATE neighbour
const FIRE_DAMAGE_PER_HOUR := 26.0
const FIRE_CREW_SUPPRESS := 0.22          # each Builderhouse hand fights it back
const FIRE_OUT_CHANCE_PER_DAY := 0.18     # a blaze can also simply burn itself out
const FIRE_OUT_CHANCE_CAP := 0.85         # even a full crew never guarantees it

var burning: Dictionary = {}              # building name -> game_hours it caught
var _fire_accum := 0.0

func fire_count() -> int:
	return burning.size()

func building_is_burning(name: String) -> bool:
	return burning.has(name)

# How hard the town is fighting: the crew that raises buildings also saves them.
func _fire_suppression() -> float:
	if not is_building_operational("Builderhouse"):
		return 0.0
	var hands := count_workers("Builderhouse") + seated_leaders("Builderhouse")
	return FIRE_CREW_SUPPRESS * float(hands)

func tick_fire(hours_passed: float) -> void:
	if hours_passed <= 0.0:
		return
	# the hourly half: a blaze eats the hall it is in, the crew fights it down
	var fought := clampf(_fire_suppression(), 0.0, 0.9)
	for bn in burning.keys():
		var name := str(bn)
		if not is_building_operational(name):
			burning.erase(name)      # already rubble: nothing left to burn
			continue
		var dmg := FIRE_DAMAGE_PER_HOUR * hours_passed * (1.0 - fought)
		var hp := float(building_health.get(name, BUILDING_MAX_HEALTH)) - dmg
		if hp <= 0.0:
			_fire_guts(name)
		else:
			building_health[name] = hp
	_fire_accum += hours_passed
	while _fire_accum >= 24.0:
		_fire_accum -= 24.0
		_fire_day()

func _fire_day() -> void:
	# ---- what goes out ----
	for bn in burning.keys():
		# CLAMPED, like the hourly half. Unclamped, four Builderhouse hands put
		# 0.18 + 4x0.22 = 1.06 on the roll and randf() can never beat it -- every
		# fire went out on its first day, forever, and the whole system quietly
		# switched itself off the moment the crew was staffed. A big crew should
		# make fire survivable, not impossible.
		if randf() < minf(FIRE_OUT_CHANCE_PER_DAY + _fire_suppression(), FIRE_OUT_CHANCE_CAP):
			burning.erase(bn)
			log_event("village", "The fire at the %s is out." % str(bn))
			SfxSynth.play_village(self, SfxSynth.SFX_FIRE_DOUSED)
	# ---- what catches from a neighbour: THE COST OF A TIGHT ROW ----
	if not burning.is_empty():
		var caught := []
		for bn2 in burning.keys():
			for side in building_neighbors.get(str(bn2), []):
				var nb := str(side)
				if nb == "" or burning.has(nb) or nb in caught:
					continue
				if not is_building_operational(nb):
					continue
				if randf() < FIRE_SPREAD_CHANCE_PER_DAY:
					caught.append(nb)
		for c in caught:
			burning[c] = game_hours
			log_event("village", "The fire jumped to the %s — they are built too close." % c)
		if not caught.is_empty():
			notify_urgent("🔥 The fire is spreading — %s alight!" % ", ".join(caught))
			SfxSynth.play_village(self, SfxSynth.SFX_FIRE_ALARM)
		return
	# ---- or a new one starts ----
	var standing := []
	for bn3 in STARTING_BUILDINGS:
		if is_building_operational(bn3):
			standing.append(bn3)
	if standing.size() < FIRE_MIN_BUILDINGS:
		return
	for name in standing:
		var odds := FIRE_CHANCE_PER_DAY
		if name in FIRE_HEARTHS:
			odds *= FIRE_HEARTH_MULT
		if randf() < odds:
			burning[name] = game_hours
			log_event("village", "Fire has broken out at the %s!" % name)
			notify_urgent("🔥 FIRE at the %s — it will spread to whatever stands beside it." % name)
			SfxSynth.play_village(self, SfxSynth.SFX_FIRE_ALARM)
			return                    # one at a time; a town does not combust at once

# A hall the fire finished: knocked back down its stages, to be raised again.
func _fire_guts(name: String) -> void:
	burning.erase(name)
	building_health[name] = BUILDING_MAX_HEALTH
	building_stage[name] = maxi(0, int(building_stage.get(name, TOTAL_BUILD_STAGES)) - 1)
	if int(building_stage[name]) <= 0:
		building_health[name] = 0
	log_event("village", "The %s has burned down to its frame." % name)
	notify_urgent("🔥 The %s burned down. The builders will have to raise it again." % name)
	_resync_building_node(name)

# The live node caches its stage and health from _ready and nothing re-reads them,
# so fire -- which writes GameState from the outside -- has to say so. Calling only
# refresh_visual() was not enough: it redraws from a `current_state` the node never
# recomputed, so a gutted hall kept drawing pristine, refused to offer a repair, and
# wrote its stale health back over the burn on the next hit.
func _resync_building_node(name: String) -> void:
	for node in get_tree().get_nodes_in_group("building"):
		if "role_key" in node and str(node.role_key) == name and node.has_method("sync_from_state"):
			node.sync_from_state()

# ======================= THE SICKNESS (dev design 2026-08-06) =======================
# THE TOWN'S OWN PROBLEM. Everything else the village produces, it produces FOR
# you; this it produces AT you. The answer to "what is there to do once it runs
# itself": a grown town does not become quiet, it becomes consequential.
#
# IT SCALES WITH SIZE AND TIGHTNESS. A hamlet never sickens -- below
# OUTBREAK_MIN_POP there is nobody to catch it from. A city of eighty living
# shoulder to shoulder catches it constantly. So the reward for growing is not
# idleness; it is that your town can now hurt.
#
# IT SPREADS HOUSE TO HOUSE, by the same homes-and-workplaces the auras read
# (villager_places). Cottages packed in a row pass it along fast; a town spread
# down the road resists it. That gives your cottage placement a SECOND meaning
# and makes where you set the Hospital the most consequential thing you ever
# placed -- its ward aura is the only standing defence.
#
# IT IS NOT CORRUPTION. Despair turns people into demons (tick_rot); this is
# physical and it is contagious. The Ten and the pledged are exempt here as they
# are from every other loss path.
#
# AND IT CANNOT BE FULLY AUTOMATED AWAY, which is the point: a ward dampens it,
# but an outbreak in a big town outruns a ward, and the news pierces the away-fog
# so you know to come home. That is the player's job -- not a chore, an emergency.
#
# ====================== TWO STRAINS (dev ruling 2026-08-06) ======================
# THE ILLNESS is the early one, and it CANNOT KILL. What it does is stop a body
# mending and drag the whole town's mood down -- and that is the entire cost. The
# dev's reasoning: at the point in the game where this first appears the player has
# no staffed Hospital, no doctors and no leader to answer it with, so a plague that
# took people then would be a punishment for being early rather than a problem to
# solve. An illness that freezes healing and sours the town is an ANNOYANCE you
# notice and work around. That is what it should be at that stage.
#
# THE PLAGUE is the real thing, and it is gated to PLAGUE_MIN_DEPTH on purpose: it
# only ever appears once the player is deep enough to have the tools to fight it
# properly. It drains, it spreads harder, it shrugs off an unaided recovery, and
# ignored long enough it takes people. Same system, late-game teeth.
#
# NOTE the ordinary illness carries NO hp drain at all rather than a drain tuned to
# cancel the regen. It is expressed as the regen suppression in tick_morale_effects
# instead, because the regen is not a fixed 3/hr -- doctors multiply it and the ward
# aura adds to it, so a fixed cancelling number would let a well-staffed town heal
# straight through the illness while an unstaffed one slowly died of it. Suppression
# gives the dev's stated effect ("will not regen health") under every staffing.
const OUTBREAK_MIN_POP := 12                  # a hamlet has nobody to catch it from
const OUTBREAK_CHANCE_PER_DAY := 0.05         # ...at the threshold; grows with the town
const OUTBREAK_CHANCE_PER_SOUL := 0.0016
const SICK_SPREAD_RADIUS := 900.0             # how near a home must be to catch it
const SICK_SPREAD_CHANCE_PER_DAY := 0.22
const SICK_CURE_CHANCE_PER_DAY := 0.10        # they can throw it off unaided...
const SICK_WARD_CURE_BONUS := 0.55            # ...far better under the ward's shadow
const SICK_WARD_DRAIN_RELIEF := 0.55          # and it costs them less while there
# the mood, which for the ordinary illness IS the whole mechanic
const SICK_MORALE_PER_CASE := 0.18
const PLAGUE_MORALE_PER_CASE := 0.5
const SICK_MORALE_CAP := 2.5                  # a bad week, never a morale wipe
# ---- the late strain ----
const PLAGUE_MIN_DEPTH := 30                  # the last blueprint floor: you are established
const PLAGUE_SHARE_ONCE_DEEP := 0.35          # ...and this share of outbreaks turn virulent
const PLAGUE_DRAIN_PER_HOUR := 0.6            # ~7 in-game days from full strength to gone
const PLAGUE_SPREAD_MULT := 1.7               # it runs through a packed row
const PLAGUE_CURE_MULT := 0.4                 # and will not be shaken off unaided

var sick: Dictionary = {}                     # villager id -> game_hours they fell ill
var plague_ids: Dictionary = {}               # ...and which of them carry the VIRULENT strain
var _sick_accum := 0.0

func sick_count() -> int:
	return sick.size()

func plague_count() -> int:
	return plague_ids.size()

func villager_has_plague(vid: String) -> bool:
	return plague_ids.has(vid)

# Has the player gone deep enough for the virulent strain to exist at all?
func plague_is_possible() -> bool:
	return deepest_level_reached >= PLAGUE_MIN_DEPTH

func villager_is_sick(vid: String) -> bool:
	return sick.has(vid)

# The pledged, the legends and the untraceable are never taken by plague -- the
# same exemption every other loss path carries.
func _can_sicken(v: Dictionary) -> bool:
	if v.get("unbreakable", false) or v.get("shadow", false):
		return false
	var vid := str(v.get("id", ""))
	return vid != "" and not sick.has(vid)

# Do these two lives touch? Home or work within reach of home or work.
func _lives_touch(a: Dictionary, b: Dictionary, r: float) -> bool:
	for pa in villager_places(a):
		for pb in villager_places(b):
			if absf(float(pa) - float(pb)) <= r:
				return true
	return false

func tick_sickness(hours_passed: float) -> void:
	# NOT gated on CORRUPTION_ENABLED. The header above this system argues at length
	# that sickness is not corruption -- despair turns people into demons, this is
	# physical and contagious -- and then the tick turned itself off with the
	# corruption kill-switch anyway. No live effect today (the flag is true), but the
	# next person to flip it to test something would have silently disabled the
	# plague too and never known.
	if hours_passed <= 0.0:
		return
	_sick_accum += hours_passed
	# THE HOURLY HALF, and only the PLAGUE has one. The ordinary illness costs no HP
	# at all: its whole cost is that a sick body does not mend (the villager_is_sick
	# guard in tick_morale_effects) and that the town's mood sours (village morale
	# reads sick_count/plague_count). Per the dev's ruling it must never take anyone.
	var ward := is_building_operational("Hospital") and count_workers("Hospital") > 0
	for vid in sick.keys():
		var v: Dictionary = find_villager_by_id(str(vid))
		if v.is_empty():
			sick.erase(vid)
			plague_ids.erase(vid)
			continue
		if not plague_ids.has(vid):
			continue
		var drain := PLAGUE_DRAIN_PER_HOUR * hours_passed
		if in_aura("Hospital", v):
			drain *= (1.0 - SICK_WARD_DRAIN_RELIEF)
		villager_hp[str(vid)] = get_villager_hp(str(vid)) - drain
	# THE DAY ROLLS COME BEFORE THE REAPER. Reaping first meant a villager whose HP
	# crossed zero inside a chunk was buried without ever being offered the cure roll
	# that same chunk would have given them -- worst on the paths that advance time in
	# a lump, where the ward's 65%-a-day recovery never got to fire at all.
	while _sick_accum >= 24.0:
		_sick_accum -= 24.0
		_sickness_day(ward)
	_reap_the_sick()

func _sickness_day(ward: bool) -> void:
	# ---- who throws it off ----
	for vid in sick.keys():
		var v: Dictionary = find_villager_by_id(str(vid))
		if v.is_empty():
			sick.erase(vid)
			plague_ids.erase(vid)
			continue
		var cure := SICK_CURE_CHANCE_PER_DAY
		if in_aura("Hospital", v):
			cure += SICK_WARD_CURE_BONUS
		elif ward:
			cure += SICK_WARD_CURE_BONUS * 0.35   # a staffed ward helps even at range
		# the virulent strain will not be shrugged off -- the ward is how you beat it
		if plague_ids.has(vid):
			cure *= PLAGUE_CURE_MULT
		if randf() < cure:
			sick.erase(vid)
			plague_ids.erase(vid)
			log_event("people", "%s has thrown off the sickness." % str(v.get("name", "?")))
	# ---- who catches it ----
	if not sick.is_empty():
		var fresh := []
		var fresh_plague := []
		for vid2 in sick.keys():
			var carrier: Dictionary = find_villager_by_id(str(vid2))
			if carrier.is_empty():
				continue
			# THE STRAIN TRAVELS WITH THE CARRIER: catching it off a plague case gives
			# you the plague, catching it off an ordinary case gives you the ordinary
			# illness. An outbreak cannot quietly escalate into the late-game strain.
			var carrier_plague: bool = plague_ids.has(vid2)
			for other in rescued_villagers:
				if not _can_sicken(other):
					continue
				if str(other.get("id", "")) in fresh:
					continue
				if not _lives_touch(carrier, other, SICK_SPREAD_RADIUS):
					continue
				var chance := SICK_SPREAD_CHANCE_PER_DAY
				if carrier_plague:
					chance *= PLAGUE_SPREAD_MULT
				if in_aura("Hospital", other):
					chance *= 0.4          # the ward's shadow shelters its neighbours
				if randf() < chance:
					fresh.append(str(other.get("id", "")))
					if carrier_plague:
						fresh_plague.append(str(other.get("id", "")))
		for nid in fresh:
			sick[nid] = game_hours
		for pid in fresh_plague:
			plague_ids[pid] = true
		if not fresh.is_empty():
			log_event("people", "The sickness spread to %d more in the night." % fresh.size())
			notify_urgent("🤒 The sickness spreads — %d more are down." % fresh.size())
			SfxSynth.play_village(self, SfxSynth.SFX_OUTBREAK, NAN, NAN, 1.12)
	# ---- or a new one begins ----
	elif rescued_villagers.size() >= OUTBREAK_MIN_POP:
		var odds := OUTBREAK_CHANCE_PER_DAY \
			+ OUTBREAK_CHANCE_PER_SOUL * float(rescued_villagers.size() - OUTBREAK_MIN_POP)
		if randf() < odds:
			_begin_outbreak()

func _begin_outbreak() -> void:
	var pool := []
	for v in rescued_villagers:
		if _can_sicken(v):
			pool.append(str(v.get("id", "")))
	if pool.is_empty():
		return
	var first: String = pool[randi() % pool.size()]
	sick[first] = game_hours
	# WHICH STRAIN. Below PLAGUE_MIN_DEPTH the virulent one does not exist at all --
	# an early town only ever gets the illness that cannot kill it. Once the player
	# is deep enough to hold a staffed ward, a share of outbreaks turn.
	var virulent: bool = plague_is_possible() and randf() < PLAGUE_SHARE_ONCE_DEEP
	if virulent:
		plague_ids[first] = true
	# PIERCES THE AWAY-FOG on purpose: an outbreak you cannot hear about is just a
	# silent tax. This is the town asking you to come home.
	if virulent:
		log_event("people", "%s has fallen ill, and it is not the usual sickness." % villager_name(first))
		notify_urgent("☠ PLAGUE in Deepwood — %s is down. This one kills." % villager_name(first))
	else:
		log_event("people", "%s has fallen ill — and it does not look like grief." % villager_name(first))
		notify_urgent("🤒 Sickness in Deepwood — %s is down. It will spread." % villager_name(first))
	SfxSynth.play_village(self, SfxSynth.SFX_OUTBREAK)

# The sickness can finish someone, but only after long neglect: the drain is slow
# enough that coming home and getting a ward standing always saves them.
func _reap_the_sick() -> void:
	var taken := []
	for vid in sick.keys():
		# ONLY THE PLAGUE REAPS. The ordinary illness carries no drain, so nobody
		# should ever reach this on it -- but guard on the strain rather than on the
		# HP alone, so that a villager who happens to be at zero for some OTHER
		# reason (a siege wound, a starving week) is never quietly recorded as a
		# plague death while merely having a cold.
		if plague_ids.has(vid) and get_villager_hp(str(vid)) <= 0.0:
			taken.append(str(vid))
	for vid2 in taken:
		sick.erase(vid2)
		plague_ids.erase(vid2)
		var v: Dictionary = find_villager_by_id(vid2)
		if v.is_empty():
			continue
		if v.get("unbreakable", false):
			villager_hp[vid2] = 1.0        # a legend sickens to the brink, never past
			continue
		# The same road every other death walks. remove_villager_by_id ALREADY calls
		# register_villager_deaths(1, death_pos) itself -- the second call this used
		# to make charged the town TWO funerals for one body: double morale shock, a
		# doubled log line, and run_villager_deaths counting twice, which armed the
		# Grief-Eater at two dead instead of three. Every other loss path (starvation,
		# rot, the Harvest) calls the remover alone. So does this one now.
		var gone := str(v.get("name", "?"))
		villager_hp.erase(vid2)
		remove_villager_by_id(vid2)
		log_event("people", "%s was taken by the sickness. Deepwood grieves." % gone)
		notify_urgent("✝ %s was taken by the sickness." % gone)

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
				# THE UNBREAKABLES CANNOT BE BROKEN: every other loss path
				# (sieges, rot, infection, the Harvest, random deaths) exempts
				# the Ten -- this drain was the one that didn't, so a freed
				# legend could quietly starve out of the roster and leave the
				# finale a legend short with no recovery. Hunger sickens them
				# to the brink and no further.
				if v.get("unbreakable", false):
					villager_hp[id] = 1.0
				elif CORRUPTION_ENABLED:
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
			# A SICK BODY DOES NOT MEND ITSELF. This regen runs in the SAME hourly tick
			# as tick_sickness's drain, and at 3/hr base it comfortably outran the
			# 2.4/hr the plague took -- so every sick villager sat pinned at full HP and
			# the entire sickness system could never take a single life. It was a
			# notification with no teeth. Being ill now means the trickle stops: what
			# lifts you is throwing it off, the ward's shadow, or the Hospital itself.
			if villager_is_sick(str(id)):
				continue
			# passive regen is a low trickle now (base 3); doctors still nudge it up, but
			# the REAL, fast recovery is the Hospital (the Sick Road)
			var regen := DESPAIR_HP_REGEN_PER_HOUR * (1.0 + 0.5 * float(doctors))
			# THE WARD'S SHADOW (Phase 4 aura): living or working within sight of the
			# ward mends you faster without ever being carried in -- the Sick Road
			# still exists for the badly hurt, this just means proximity is care.
			if in_aura("Hospital", v):
				regen += AURA_WARD_REGEN
			villager_hp[id] = minf(VILLAGER_MAX_HP, hp + hours_passed * regen)
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

# RETIRED 2026-07-29 (dev: "morale has to affect only regular villagers, not
# combat people or leaders"). This used to scale village_defense_power(), which
# made a grieving town's TRAINED fighters and its stone wall weaker -- and built a
# death spiral (deaths -> morale crash -> halved defense -> more deaths). Defense
# is now morale-independent; morale drives villager output via
# village_morale_multiplier() instead. Kept as a no-longer-called reading for the
# UI//save compat; do NOT reintroduce it into the defense maths.
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
		# a grander seat of government collects better -- each employee's own
		# building already scales their share, but the Government's OWN level was
		# the one term missing (2026-07-29)
		total += taxable * get_village_income_multiplier() * building_output_multiplier("Government")
	# THE BAR POURS FROM THE LARDER (chain link): no supplies, no drink, no
	# takings -- the Farm and the Dock are what keep the taps running.
	if is_building_operational("Bar") and has_food():
		total += BARKEEP_TRICKLE * float(count_workers("Bar")) * building_output_multiplier("Bar")
	# the TAVERN pours too, on the same chain (no larder, no drink, no takings) --
	# its Barmen were staffable and worthless before 2026-07-29
	if is_building_operational("Tavern") and has_food():
		total += BARMAN_TRICKLE * float(count_leader_holders("Tavern", "Barman")) \
			* building_output_multiplier("Tavern")
	if total <= 0.0:
		return
	# a happy village is a taxable village (0.75x .. 1.25x)
	total *= village_morale_multiplier()
	# THE BANK BANKS (City Machine B-slice): a staffed Bank sets aside a cut of
	# the tax take into the town's OWN purse, which pays wages before the
	# player's pocket is ever touched (see tick_wages)
	if is_building_operational("Bank") and count_workers("Bank") > 0:
		var cut := total * TREASURY_TAX_SHARE
		total -= cut
		_treasury_accum += cut
		if _treasury_accum >= 1.0:
			var banked := int(_treasury_accum)
			_treasury_accum -= float(banked)
			village_treasury += banked
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
		# the village share (supply chain): the crew hauls for the TOWN too --
		# straight into the stores, no bag to fill, on top of the player's cut.
		# The Lab's researchers make every seam go further (research_yield), and a
		# Mine standing beside the forge or the masons hauls more still (adjacency).
		# the PITMASTER reads the seam: a led crew cuts where the ore actually runs
		# (2026-07-29 -- the Mine was the one building with no leadership post)
		var ym := research_yield_multiplier() * (1.0 + PITMASTER_YIELD_BONUS * seated_leaders("Mine")) * building_output_multiplier("Mine")
		_add_to_store("stone", MINE_VILLAGE_STONE_PER_MINER * miners * ym)
		_add_to_store("iron_shard", MINE_VILLAGE_IRON_PER_MINER * miners * ym)
		# THE DEEP SEAM (Mine power): a grown Mine breaks through to ore the
		# shallow workings never touch -- a skill material the crew could not
		# otherwise bring up, straight into the village stores.
		if has_building_power("Mine"):
			var seam: String = DEEP_SEAM_MATERIALS[_mine_cycles % DEEP_SEAM_MATERIALS.size()]
			village_stockpile[seam] = int(village_stockpile.get(seam, 0)) + 1
			log_event("village", "The Deep Seam gave up %s — ore the shallow workings never reach." % Inventory.get_display_name(seam))
		# THE SOUNDING (Pitmaster): the master sounds the rock and sets the crew on
		# ore matched to how deep YOU have carved -- the Mine tracks the dungeon.
		if has_leader_power("Mine"):
			var deep: String = _sounding_material()
			village_stockpile[deep] = int(village_stockpile.get(deep, 0)) + 1
			log_event("village", "The Pitmaster sounded the rock — the crew brought up %s." % Inventory.get_display_name(deep))
		var player = get_tree().get_first_node_in_group("player")
		if player and "inventory" in player and player.inventory:
			# honest accounting: add_item returns the LEFTOVER, so log/announce only what the
			# pack actually took -- a full bag must not be told it received a haul it lost.
			var stone_got: int = 2 * miners - player.inventory.add_item("stone", 2 * miners)
			var iron_got: int = miners - player.inventory.add_item("iron_shard", 1 * miners)
			# EMBER too, at half the iron cadence. ember_crystal gates 28 skill nodes
			# -- the most of any material -- yet was cache-ONLY (scarce), while iron
			# (10 nodes) flowed from here. That left every ember-gated spec, and ALL
			# THREE Mage specs (their tier-4 forks are all ember), materially stalled
			# vs iron specs (marathon sim 2026-07-22: Mage 29% tree vs Sword 52%). The
			# mine now digs crystals too, so ember has a village source like iron does.
			if _mine_cycles % 2 == 0:
				var ember_got: int = miners - player.inventory.add_item("ember_crystal", 1 * miners)
				if ember_got > 0:
					log_event("economy", "The Mine's deep seam gave up %d ember crystal." % ember_got)
			if stone_got > 0 or iron_got > 0:
				log_event("economy", "The Mine's haul came up: %d stone, %d iron." % [stone_got, iron_got])
			else:
				notify("⛏ The Mine struck ore, but your pack is full — make room to carry the haul.")

# The wood leg of the supply chain: the Builderhouse crew fells timber into the
# village stores daily -- wood finally has a producer that isn't the player's
# hands, so the repair chain (wood+stone -> auto_repair_one) can close.
var _wood_accum := 0.0

func tick_wood_gathering(hours_passed: float) -> void:
	if not is_building_operational("Builderhouse"):
		return
	var crew := count_workers("Builderhouse")
	if crew == 0:
		return
	_wood_accum += hours_passed
	while _wood_accum >= 24.0:
		_wood_accum -= 24.0
		var felled := _add_to_store("wood",
			WOOD_PER_BUILDER_PER_DAY * crew * research_yield_multiplier() * building_output_multiplier("Builderhouse"))
		# ...and a little FIELDSTONE besides: the Mine (floor 13) is the real
		# quarry, but repairs need stone from day one -- without this trickle
		# the whole repair chain deadlocked until mid-game (no stone producer).
		var quarried := _add_to_store("stone", ceil(float(crew) / 2.0))
		if felled > 0 or quarried > 0:
			log_event("economy", "The builders' gathering run: %d wood, %d fieldstone into the stores." % [felled, quarried])

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
	# The lead can NEVER exceed the gap between waves. hours_until_next_siege is
	# capped at SIEGE_INTERVAL_HOURS (12), so a tier-3 lead of 24 made the re-arm
	# test `> 24` unsatisfiable: the top tier tolled once and then stayed silent
	# for the rest of the run -- strictly worse than the tier below it, for
	# 2 ember crystals. Clamp the lead so every tier still re-arms; the deepest
	# tier simply warns as early as the schedule physically allows.
	var lead: float = minf(watchtower_warning_hours(), SIEGE_INTERVAL_HOURS - 0.5)
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
# LOOT DEPTH (12.12, dev-chosen 2026-07-28): each named wanderer is a CART,
# not a coin-flip -- their stock draws from their own trade first (the
# creative directive: named identity over noise). `bias` = the categories
# their cart leans toward; `line` = how they greet the Post; `showline` =
# what they say of the piece under the cloth (visits 4+ carry a guaranteed
# SHOWPIECE: one epic -- the road's canon best -- at a steep premium).
const WANDERER_CARTS = {
	"Salla of the Long Road":  {"bias": ["consumable", "material"],
		"line": "Walked here from the sea. Everything's for sale but the boots.",
		"showline": "And under the cloth -- the thing I don't show just anyone."},
	"Bramble-cart Icky":       {"bias": ["material", "weapon"],
		"line": "Icky finds things. Icky sells things. Same things, mostly.",
		"showline": "This one Icky found in a DEAD place. Extra shiny. Extra gold."},
	"Vex the Peddler":         {"bias": ["weapon"],
		"line": "Every blade on this cart has a story. Most of them end badly.",
		"showline": "The wrapped one? That story hasn't ended yet. Costs accordingly."},
	"Odo Twicesold":           {"bias": ["armor", "relic"],
		"line": "Sold twice, worn once, guaranteed thrice. Odo's word is almost bond.",
		"showline": "Under the cloth: the piece I SHOULD have kept. Make it hurt me."},
	"Mirena Farshore":         {"bias": ["relic"],
		"line": "Charms and old promises. The sea gives them back, eventually.",
		"showline": "This one still hums. I'd rather it hummed in someone else's bag."},
	"The Quiet Tinker":        {"bias": ["armor", "consumable"],
		"line": "...",
		"showline": "(they lift the cloth an inch, and wait)"},
}
const WANDERER_SHOWPIECE_FROM := 4      # the road's trust, earned across visits
const WANDERER_SHOWPIECE_MARKUP := 1.6  # the best piece opens steep -- hospitality eats into it
const WANDERER_GAP_MIN := 12.0
const WANDERER_GAP_MAX := 30.0
const WANDERER_DISCOUNT_MAX := 0.25    # a happy town's slow markdown across the stay
const CARAVAN_ROAD_GAP_MULT := 0.35    # Marketplace power: the road brings carts ~3x as often
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
		# THE CARAVAN ROAD (Marketplace power): the road knows Deepwood now -- the
		# next cart is already on its way instead of maybe turning up in a day.
		var gap := randf_range(WANDERER_GAP_MIN, WANDERER_GAP_MAX)
		if has_building_power("Marketplace"):
			gap *= CARAVAN_ROAD_GAP_MULT
		wanderer_next_at_hours = game_hours + gap

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
	# lantern light makes every price kinder (the festival's whole economy)
	if lantern_tonight:
		base *= LANTERN_DISCOUNT
	return maxi(2, int(round(base)))

func _wanderer_arrive() -> void:
	wanderers_seen += 1
	var tier: int = mini(wanderers_seen / 2, 2)
	var pool := _wanderer_pool(tier)
	if pool.is_empty():
		return
	pool.shuffle()
	# the cart has a NAME, and the name has a trade: bias-first fill
	var wname: String = WANDERER_NAMES[randi() % WANDERER_NAMES.size()]
	var cart: Dictionary = WANDERER_CARTS.get(wname, {})
	var bias: Array = cart.get("bias", [])
	var favoured := []
	var rest := []
	for id in pool:
		if str(Inventory.get_item_def(id).get("category", "")) in bias:
			favoured.append(id)
		else:
			rest.append(id)
	var ordered := favoured + rest
	var slots: int = 4 + (1 if marketplace_merchant_staffed() else 0)
	var stock := []
	for i in range(mini(slots, ordered.size())):
		var id: String = ordered[i]
		var cat := str(Inventory.get_item_def(id).get("category", ""))
		stock.append({"id": id, "price": _wanderer_price(id),
			"count": 3 if (cat == "consumable" or cat == "material") else 1})
	# visits 4+: the SHOWPIECE under the cloth -- one guaranteed epic (the
	# road's canon ceiling), preferring the cart's own trade, priced steep
	if wanderers_seen >= WANDERER_SHOWPIECE_FROM:
		var epics := []
		var epics_biased := []
		for id in pool:
			if grade_rank(id) == 4:
				epics.append(id)
				if str(Inventory.get_item_def(id).get("category", "")) in bias:
					epics_biased.append(id)
		var pick_from: Array = epics_biased if not epics_biased.is_empty() else epics
		if not pick_from.is_empty():
			var sid: String = pick_from[randi() % pick_from.size()]
			# the piece under the cloth is not ALSO on the open table (EYES v6:
			# the same leggings sat at 992g and 292g on one cart)
			for k in range(stock.size() - 1, -1, -1):
				if str(stock[k].get("id", "")) == sid:
					stock.remove_at(k)
			stock.push_front({"id": sid,
				"price": int(round(float(_wanderer_price(sid)) * WANDERER_SHOWPIECE_MARKUP)),
				"count": 1, "showpiece": true})
	wanderer = {
		"name": wname, "arrived": game_hours, "dwell": _wanderer_dwell_hours(),
		"stock": stock, "tier": tier, "line": str(cart.get("line", "")),
		"showline": str(cart.get("showline", "")),
	}
	log_event("economy", "%s set up at the Wanderer's Post — %d wares on the cart." % [wname, stock.size()])
	notify("🛒 %s has set up at the Wanderer's Post. \"%s\"" % [wname, str(cart.get("line", "..."))])

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
		if str(v.get("role_key", "")) != "" and not school_enrollments.has(str(v.get("id", ""))) and is_building_operational(str(v.get("role_key", ""))):
			staff.append(v)
	if staff.is_empty():
		return
	var per := WAGE_PER_WORKER_PER_DAY
	if is_building_operational("Bank") and count_workers("Bank") > 0:
		per *= BANK_PAYROLL_DISCOUNT
	var player = get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("add_currency"):
		return
	# THE BANK PAYS FIRST (City Machine B-slice): payroll draws the town's own
	# treasury down to zero before it touches the player's pocket -- a Bank that
	# banked well makes payday free for the player entirely.
	var affordable: int = mini(staff.size(),
		int(floor(float(village_treasury + player.currency) / per)))
	if affordable > 0:
		var pay_total: int = int(round(per * float(affordable)))
		var from_treasury: int = mini(village_treasury, pay_total)
		village_treasury -= from_treasury
		# THE LEDGER THAT PAYS (Bank power): a grown Bank covers the shortfall on
		# its own books -- payday never reaches the player's purse again.
		if pay_total - from_treasury > 0 and not has_building_power("Bank"):
			player.add_currency(-(pay_total - from_treasury))
		elif pay_total - from_treasury > 0:
			log_event("economy", "The Ledger covered the shortfall — %d gold, none of it yours." % (pay_total - from_treasury))
		_bank_paid_full_payroll = affordable == staff.size() and from_treasury >= pay_total
		if _bank_paid_full_payroll:
			log_event("economy", "The Bank met the whole payroll — %d gold, not a coin from your purse." % pay_total)
	else:
		_bank_paid_full_payroll = false
	var unpaid: int = staff.size() - affordable
	if unpaid > 0:
		staff.shuffle()
		# a dry purse BLEEDS staff, it doesn't vaporise them: everyone unpaid
		# is angry (morale), but only a couple actually walk out per payday --
		# one bad day used to fire the entire town in a single tick, which
		# reads as a bug, not a consequence, and left nothing to recover with
		var quits: int = mini(unpaid, WAGE_MAX_QUITS_PER_DAY)
		for i in range(unpaid):
			var v: Dictionary = staff[i]
			v["morale"] = clampf(get_personal_morale(v) - 1.5, 0.0, 10.0)
			if i < quits:
				log_event("economy", "%s quit their post — the purse could not pay them." % str(v.get("name", "?")))
				v["role_key"] = ""
				v["role_title"] = ""
		play_sfx(SFX_NO, 0.8)
		if unpaid > quits:
			notify("%d worker%s quit unpaid — %d more stay on, unpaid and fuming." % [quits, "" if quits == 1 else "s", unpaid - quits])
		else:
			notify("%d worker%s quit unpaid — the treasury ran dry." % [quits, "" if quits == 1 else "s"])

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
	# THE TEACHERS TEACH (2026-07-29). The School declares 10 Teacher slots, and
	# until now graduation read the PRINCIPAL only -- a player could seat ten
	# villagers as Teachers and change nothing at all. A Teacher is worth less than
	# the Principal who runs the place, but a staffed schoolhouse must school faster
	# than an empty one. (count_leader_holders is a by-TITLE counter despite its
	# name; count_workers("School") would wrongly sweep in the Students, who are
	# enrolled under the same role_key.)
	return (1.0 + count_leader_holders("School", "Principal") * LEADER_BONUS_PER_HOLDER \
		+ count_leader_holders("School", "Teachers") * TEACHER_SPEED_PER_HEAD) \
		* building_output_multiplier("School")

func get_barracks_graduation_speed_multiplier() -> float:
	# Brannoc, the Wall That Stood (the Ten): warriors train twice as fast
	var ten_mult := 2.0 if ten_freed("ten_brannoc") else 1.0
	return (1.0 + count_leader_holders("Barracks", "Warchief") * LEADER_BONUS_PER_HOLDER) * ten_mult \
		* building_output_multiplier("Barracks")

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
const MUSTER_PER_ABLE_ADULT := 0.25     # Warchief's Muster: what an untrained townsfolk is worth at the wall
# SHRUNK 2026-07-29 (were 0.6 and 0.5). These leaders' worth is no longer a
# percentage -- it is The Full Table / The Tide Table / The Sounding in
# LEADER_POWERS. What's left is connective tissue so a seat isn't literally inert.
const HARVESTMASTER_FOOD_BONUS := 0.1   # Harvestmaster/Harbormaster: a trickle on top of their real power
const PITMASTER_YIELD_BONUS := 0.1      # Pitmaster: likewise
const LEADER_MORALE_EACH := 6           # Tavernkeeper/Publican: morale points added per seat

# --- THE SUPPLY CHAIN (City Machine pillar A, dev call 2026-07-29) ---
# The village's OWN stores, fed by working buildings and spent by others -- the
# chain that lets the town run without the player's bag: Mine crews haul a
# village share of stone+iron here (tick_mine_yield, ON TOP of the player's
# unchanged haul); Builderhouse workers fell wood into it daily
# (tick_wood_gathering); the repair crew SPENDS it per stage (auto_repair_one --
# repairs are no longer conjured free); the Forgemaster's smiths turn its iron
# into armory arms. More working buildings = a fuller store = a town that
# mends and arms itself.
var village_stockpile := {"wood": 0, "stone": 0, "iron_shard": 0}
# Fractional remainders, banked between cycles (same trick as _gold_accum). WITHOUT
# this every multiplier vanished at small scale: one miner hauling 1 stone/day times
# a 1.20 adjacency bonus rounds straight back to 1, so a well-placed early Mine
# gained literally nothing and the whole synergy layer was invisible until the
# crews got big. Now the 0.2 accrues and lands as a whole stone on the fifth day.
var _store_accum := {"wood": 0.0, "stone": 0.0, "iron_shard": 0.0}

# Add a fractional yield to a village store; returns the WHOLE units delivered now.
func _add_to_store(kind: String, amount: float) -> int:
	if not village_stockpile.has(kind):
		return 0
	_store_accum[kind] = float(_store_accum.get(kind, 0.0)) + amount
	var whole := int(floor(float(_store_accum[kind])))
	if whole > 0:
		_store_accum[kind] = float(_store_accum[kind]) - float(whole)
		village_stockpile[kind] = int(village_stockpile[kind]) + whole
	return whole
const MINE_VILLAGE_STONE_PER_MINER := 1   # per day, on top of the player's haul
const MINE_VILLAGE_IRON_PER_MINER := 1
const WOOD_PER_BUILDER_PER_DAY := 1
const REPAIR_STAGE_WOOD := 2              # what one auto-repair stage consumes
const REPAIR_STAGE_STONE := 1
const FORGE_IRON_PER_ARM := 1
# The Lab is the chain's TECH rung: researchers study what the crews haul and
# hand back better tools and methods, so every store yield rises with the seats
# filled. The Lab finally feeds something instead of only identifying loot.
const RESEARCH_YIELD_PER_SEAT := 0.15

func research_yield_multiplier() -> float:
	return (1.0 + RESEARCH_YIELD_PER_SEAT * float(seated_leaders("Science Lab"))) \
		* building_output_multiplier("Science Lab")

# --- THE DOMESTIC AUTOMATIONS (the automation ladder, dev law 2026-07-29) ---
# Every chore the player does BY HAND early must eventually be taken over by a
# building. The family loop is the clearest case:
#   raising a cottage   -- by hand from the B menu  -> the Builderhouse's leaders
#   pairing a couple    -- by hand, E on a cottage  -> the Bar's Publican
#   schooling a child   -- by hand in the assign UI -> the School's Principal
#                                                      (auto_enroll_children, already built)
# The rescue depths pace the ladder on their own: Publican at 20, Principal at
# 45, Master Builder at 55 -- so the family loop runs itself by the deep 50s.
const AUTO_COTTAGE_WOOD := 8
const AUTO_COTTAGE_STONE := 4
const AUTO_COTTAGE_SPACING := 170.0

# Cottages standing EMPTY right now: not a couple's home, not mid-pairing.
# Hand the town what you're carrying (assign_ui, Builderhouse panel). The crews
# fill the stores on their own, but early -- before the Mine, before a builder
# crew -- the player IS the supply line, and standing there holding forty logs
# while the repair crew idles for two was a dead end with no way out.
# Returns how many were actually given.
func donate_to_stores(player: Node, item_id: String) -> int:
	if player == null or not ("inventory" in player) or player.inventory == null:
		return 0
	if not village_stockpile.has(item_id):
		return 0
	var held: int = player.inventory.get_count(item_id)
	if held <= 0:
		return 0
	player.inventory.remove_item(item_id, held)
	village_stockpile[item_id] = int(village_stockpile[item_id]) + held
	log_event("village", "You gave %d %s to the village stores." % [held, item_id.replace("_", " ")])
	play_sfx(SFX_YES, 1.0)
	return held

# ===================== LODGING (dev design 2026-07-30) =====================
# A cottage may hold ONE person waiting for someone to share it with. That is the
# shape the dev asked for: an adult coming out of the School is given a roof
# FIRST -- an empty cottage, or one that already holds a single of the opposite
# sex -- and it is MOVING IN that makes the match, rather than a matchmaker
# pairing two strangers in the street. Then they start a family and the cycle turns.
#
# cottage_homes entries stay {a, b}; a lodger is simply an entry whose other slot
# is "". Everything that reads it already copes: villager_home_id matches either
# slot, and update_cottage_families skips any home whose second name comes back
# "someone", so a lone occupant can never conceive with nobody.
func cottage_occupant_ids(hid: String) -> Array:
	var out := []
	if not cottage_homes.has(hid):
		return out
	var h: Dictionary = cottage_homes[hid]
	for k in ["a", "b"]:
		var v := str(h.get(k, ""))
		if v != "":
			out.append(v)
	return out

func cottage_is_pair(hid: String) -> bool:
	return cottage_occupant_ids(hid).size() >= 2

# The one person living here alone, or "" if the cottage is empty or already full.
func cottage_lone_occupant(hid: String) -> String:
	var occ := cottage_occupant_ids(hid)
	return str(occ[0]) if occ.size() == 1 else ""

# Is this adult looking for a roof and someone to share it with?
func _seeking_home(v: Dictionary) -> bool:
	if v.get("is_kid", false) or v.get("unbreakable", false) or v.get("shadow", false):
		return false
	var vid := str(v.get("id", ""))
	if vid == "" or school_enrollments.has(vid):
		return false          # still in training -- not an adult out of the hall yet
	if is_villager_paired(vid) or villager_home_id(vid) != "":
		return false
	# 5.8: a widow(er) is not looking again until the mourning has passed
	if v.has("widowed_at_hours") and game_hours < float(v["widowed_at_hours"]) + WIDOW_MOURN_HOURS:
		return false
	return true

# THE ROOF FIRST. Every adult with nowhere to live gets a door: preferably one
# with a single of the opposite sex already behind it, because that completes a
# household; failing that an empty cottage, where they wait for company.
func house_unpaired_adults() -> void:
	for v in rescued_villagers:
		if not _seeking_home(v):
			continue
		var vid := str(v.get("id", ""))
		var sex := str(v.get("sex", ""))
		var moved := false
		for cid in extra_cottage_ids:
			var hid := str(cid)
			if mating_houses.has(hid):
				continue
			var lone := cottage_lone_occupant(hid)
			if lone == "":
				continue
			var other: Dictionary = find_villager_by_id(lone)
			if other.is_empty() or str(other.get("sex", "")) == sex:
				continue          # a housemate of the same sex makes no household
			var h: Dictionary = cottage_homes[hid]
			if str(h.get("a", "")) == "":
				h["a"] = vid
			else:
				h["b"] = vid
			cottage_homes[hid] = h
			log_event("people", "%s moved in with %s." % [
				str(v.get("name", "?")), str(other.get("name", "?"))])
			moved = true
			break
		if moved:
			continue
		var free := free_cottage_ids()
		if free.is_empty():
			continue              # nowhere to put them -- the builders will see to it
		cottage_homes[str(free[0])] = {"a": vid, "b": ""}
		log_event("people", "%s took a cottage, and waits for company." % str(v.get("name", "?")))

# ...and once two of them share a roof, they make a family of it.
func pair_housemates() -> void:
	for cid in extra_cottage_ids:
		var hid := str(cid)
		if mating_houses.has(hid) or not cottage_is_pair(hid):
			continue
		var occ := cottage_occupant_ids(hid)
		var a: Dictionary = find_villager_by_id(str(occ[0]))
		var b: Dictionary = find_villager_by_id(str(occ[1]))
		if a.is_empty() or b.is_empty():
			continue
		if is_villager_paired(str(a.get("id", ""))) or is_villager_paired(str(b.get("id", ""))):
			continue
		if str(a.get("sex", "")) == str(b.get("sex", "")):
			continue
		var a_male := str(a.get("sex", "")) == "Male"
		start_pairing(hid,
			str(a.get("id", "")) if a_male else str(b.get("id", "")),
			str(b.get("id", "")) if a_male else str(a.get("id", "")))

func free_cottage_ids() -> Array:
	var out := []
	for cid in extra_cottage_ids:
		var hid := str(cid)
		if not cottage_homes.has(hid) and not mating_houses.has(hid):
			out.append(hid)
	return out

# Where the builders put the next home: at the end of the row they already
# keep, else just past the village proper (the same ground generate_houses uses).
func _next_cottage_x() -> float:
	var best := -INF
	for p in extra_cottage_positions:
		best = maxf(best, float(p))
	var x := 6000.0
	if best > -INF:
		x = best + AUTO_COTTAGE_SPACING
	else:
		var scene = get_tree().current_scene
		if scene != null and "village_right_edge" in scene:
			x = float(scene.village_right_edge) + 240.0
	# NEVER PAVE THE SPECIAL GROUND (Phase 3): the cottage row marches east from
	# the end of the village, which runs straight over the outskirts plots -- the
	# builders would have quietly built houses on the Ore Vein and left the Mine
	# nowhere to stand. Step past any plot we land on.
	for _guard in range(SPECIAL_PLOTS.size() + 1):
		var on := plot_at(x)
		if on.is_empty():
			break
		x = float(on["x"]) + PLOT_RADIUS + AUTO_COTTAGE_SPACING
	return x

# THE BUILDERS RAISE HOMES THEMSELVES (Master Builder / Foreman). Only ever when
# the town actually NEEDS one -- a couple is waiting and no home stands empty --
# and only out of the village stores, so housing draws on the same chain as
# everything else. Works while the player is deep: the cottage is registered, and
# generate_houses rebuilds it on the ground chosen here when they walk back in.
func auto_build_cottage() -> bool:
	# a grown Builderhouse works unled (The Standing Crew); a grown Bar can also
	# call for a home when it has a couple waiting (The Matchmaker's Round)
	if seated_leaders("Builderhouse") <= 0 and not has_building_power("Builderhouse") \
			and not has_building_power("Bar"):
		return false
	if not free_cottage_ids().is_empty():
		return false                      # a home already waits -- don't sprawl
	var parents := find_available_parents()
	if str(parents.male_id) == "" or str(parents.female_id) == "":
		return false                      # build for a real couple, never on spec
	if int(village_stockpile["wood"]) < AUTO_COTTAGE_WOOD \
			or int(village_stockpile["stone"]) < AUTO_COTTAGE_STONE:
		return false                      # the stores decide the pace
	village_stockpile["wood"] = int(village_stockpile["wood"]) - AUTO_COTTAGE_WOOD
	village_stockpile["stone"] = int(village_stockpile["stone"]) - AUTO_COTTAGE_STONE
	var x := _next_cottage_x()
	var hid := register_cottage(x)
	var scene = get_tree().current_scene
	if scene != null and scene.has_method("spawn_cottage_node"):
		scene.spawn_cottage_node(hid, x)  # live village: it goes up in front of you
	log_event("village", "The builders raised a cottage — a home standing ready for a couple.")
	notify("🏠 The builders raised a cottage on their own.")
	return true

# THE PUBLICAN MAKES THE MATCH (the Bar is the village's social heart -- where
# else would couples meet?). Fills every empty cottage with a waiting pair, so
# the player never has to walk the row pressing E again.
func auto_pair_couples() -> void:
	# THE MATCHMAKER'S ROUND (Bar power): a grown Bar makes its own matches
	if seated_leaders("Bar") <= 0 and not has_building_power("Bar"):
		return
	# THE ROOF FIRST, then the match (dev design 2026-07-30). An adult out of the
	# School is given a door before anything else -- ideally one with a single of
	# the opposite sex behind it -- and sharing that roof is what makes the couple.
	house_unpaired_adults()
	pair_housemates()
	# ...and the old road still works for anyone left over: two unattached adults
	# matched straight into a standing empty cottage.
	for hid in free_cottage_ids():
		var parents := find_available_parents()
		if str(parents.male_id) == "" or str(parents.female_id) == "":
			return
		start_pairing(hid, str(parents.male_id), str(parents.female_id))
		log_event("people", "The Publican made a match — %s and %s took a cottage." % [
			villager_name(str(parents.male_id)), villager_name(str(parents.female_id))])

# --- THE VILLAGE TREASURY (City Machine, B-slice: "the Bank pays") ---
# A staffed Bank banks a cut of the tax take into the town's own purse, and
# payday draws from that purse BEFORE the player's pocket -- the first rung of
# the city funding itself.
var village_treasury := 0
const TREASURY_TAX_SHARE := 0.25
var _treasury_accum := 0.0
var _bank_paid_full_payroll := false      # last payday came wholly from the treasury

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
	# Don't DESTROY value: only accept the piece if its FULL arm value fits under the
	# cap. Previously it consumed the whole item and credited only the clamped
	# remainder, so depositing a grade-4 weapon at 98/99 gave +1 and burned the rest.
	# Refusing here keeps the gear in the player's bag instead (dev bug-sweep 2026-07-25).
	var v := arm_value_of(item_id)
	if barracks_arms + v > BARRACKS_ARMS_CAP:
		return 0
	player.inventory.remove_item(item_id, 1)
	barracks_arms += v
	return v

# How many VIP leaders are currently seated at a building's top post(s).
# A RAZED / not-yet-built building provides NOTHING even if its leader villager is
# still assigned: siege take_damage() zeroes the build stage but doesn't clear the
# leader's role_key, so without this gate a destroyed Bank kept minting gold, a
# ruined Hospital kept healing, a rubble Marketplace kept auto-selling (and silently
# spending) the player's materials, etc. Every leadership automation routes through
# here, so gating operational once fixes all of them (dev bug-sweep 2026-07-25).
func seated_leaders(role_key: String) -> int:
	if not is_building_operational(role_key):
		return 0
	var n := 0
	for rd in BuildingRoles.get_roles(role_key):
		if rd.get("leadership", false):
			n += count_leader_holders(role_key, str(rd.get("title", "")))
	return n

func apply_leadership_automation() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if seated_leaders("Government") > 0:
		auto_staff_villagers()                      # Chancellor: staff the town
	# THE STANDING ORDER (power): with a Chancellor in a hall this grand, nobody is
	# left in a trade they weren't trained for -- the wrongly-placed get moved.
	if has_building_power("Government"):
		reseat_mismatched_workers()
	if player and player.has_method("add_currency") and (seated_leaders("Bank") > 0 or (is_building_operational("Bank") and count_workers("Bank") > 0)):
		# 5.6: interest is the Bank's FUNCTION -- any staffed Financist grows
		# the treasury (half rate); the Treasurer leader runs it at full, and
		# Dorian Vail, the Coinbinder (the Ten), doubles whatever runs
		var rate: float = BANK_INTEREST_RATE * (1.0 if seated_leaders("Bank") > 0 else 0.5) \
			* building_output_multiplier("Bank")
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
	# THE OPEN DOORS (power): the Principal's hall takes every child, past its desks
	# THE CHILDREN ARE PLACED by whichever hall has someone to place them: the
	# Principal schools them, and a Warchief takes them into the yard. Gating this
	# on the Principal alone meant a town with a drill yard and no schoolmaster
	# never trained anybody automatically, which broke half the population loop.
	if seated_leaders("School") > 0 or seated_leaders("Barracks") > 0:
		auto_enroll_children(maxi(1, seated_leaders("School") + seated_leaders("Barracks")))
	# Grammar (5.1): a staffed Worker crew rebuilds on its own -- delegated,
	# at half the leaders' pace; Master Builder/Foreman run it every tick
	# (THE STANDING CREW rides inside auto_repair_one: with the Master Builder in a
	# hall this grand the crew scavenges its own materials, so a repair costs the
	# village stores nothing.)
	if seated_leaders("Builderhouse") > 0:
		auto_repair_one()                           # leaders: rebuild the ruins
	elif count_workers("Builderhouse") > 0:
		_builder_half_tick = not _builder_half_tick
		if _builder_half_tick:
			auto_repair_one()                       # the crew alone: slower, but real
	# THE FAMILY LOOP RUNS ITSELF (automation ladder): the builders raise the
	# homes, the Publican fills them, the Principal schools what comes of it.
	# THE MATCHMAKER'S ROUND (Bar power): a grown Bar doesn't let a waiting couple
	# stall for want of a roof -- the match is made and a home is raised for it,
	# with no Master Builder needed to order the work.
	if seated_leaders("Builderhouse") > 0 or has_building_power("Bar"):
		auto_build_cottage()
	auto_pair_couples()
	if seated_leaders("Marketplace") > 0:
		auto_sell_village_surplus()                 # Merchant Prince: stores -> treasury
	if forgemaster_supplying() and barracks_arms < BARRACKS_ARMS_CAP:
		# THE CHAIN: every arm is forged FROM village iron (Mine -> Forge ->
		# armory) -- an empty ore store means a cold forge, however grand the
		# Forgemaster. Seat miners to feed him.
		# THE SMITHS SWING TOO (2026-07-29): the Forgemaster opens the forge, but
		# every Blacksmith at a bench raises how much comes off it in a tick. The
		# ten smith slots were declared and never read before this.
		# ...and WHERE the forge stands multiplies the whole bench (adjacency): ore
		# at the door from the Mine, or the drill yard next door to carry arms to.
		# The two compose -- hands add to the bench, the ground scales it.
		var bench: int = FORGE_ARMS_PER_TICK + int(floor(
			SMITH_ARMS_PER_HEAD * float(count_leader_holders("Blacksmith", "Blacksmith"))))
		# THE NIGHT FORGE (power): the fires never bank. With the Forgemaster in a
		# hall this grand the bench runs a night shift too -- twice the arms a day
		# could turn out. Still spends village iron: the chain always binds.
		if has_building_power("Blacksmith"):
			bench *= 2
		var per_tick: int = int(round(float(bench) * building_output_multiplier("Blacksmith")))
		var forged: int = mini(per_tick,
			mini(int(village_stockpile["iron_shard"]) / FORGE_IRON_PER_ARM, BARRACKS_ARMS_CAP - barracks_arms))
		if forged > 0:
			village_stockpile["iron_shard"] = int(village_stockpile["iron_shard"]) - forged * FORGE_IRON_PER_ARM
			barracks_arms += forged

# Chancellor: seat every idle adult in an understaffed, operational worker role
# they qualify for (matching-stat first, then any open role). Leadership seats
# are never touched -- those stay unique to their rescued figure.
func auto_staff_villagers() -> void:
	for v in rescued_villagers:
		if v.get("is_kid", false) or str(v.get("role_key", "")) != "" or school_enrollments.has(v.get("id")):
			continue
		if not try_auto_place(v, true):
			try_auto_place(v, false)

# THE STANDING ORDER (Government power). The Chancellor alone SEATS the idle;
# with a hall this grand behind them they also correct the seating already done --
# a trained fisher shovelling in a mine is moved to work that fits. This is a real
# gain the leader cannot make alone: villager_needs scores "right_job" separately
# from "work", so a mismatched soul is quietly losing morale every hour they stay.
# Leadership seats and trainees are never touched.
func reseat_mismatched_workers() -> void:
	for v in rescued_villagers:
		if v.get("is_kid", false) or school_enrollments.has(v.get("id")):
			continue
		var stat := str(v.get("stat_name", ""))
		var rk := str(v.get("role_key", ""))
		if stat == "" or rk == "":
			continue
		var needs: Dictionary = villager_needs(v)
		if bool(needs.get("right_job", true)):
			continue                      # already where they belong
		var was := rk
		var was_title := str(v.get("role_title", ""))   # read BEFORE clearing, or the
		v["role_key"] = ""                              # restore below puts them back
		v["role_title"] = ""                            # in the job with no title
		if try_auto_place(v, true):
			log_event("village", "%s was moved from the %s to work that suits their training." % [
				str(v.get("name", "?")), was])
		else:
			v["role_key"] = was           # nowhere better to put them: leave it be
			v["role_title"] = was_title

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
	# THE WHISPER NETWORK (Science Lab power): a grown Lab knows every material on
	# sight -- nothing sits in the queue waiting to be identified.
	if has_building_power("Science Lab"):
		n = Inventory.ITEM_DEFS.size()
	var done := 0
	for item_id in Inventory.ITEM_DEFS.keys():
		if done >= n:
			return
		if Inventory.ITEM_DEFS[item_id].get("is_material", false) and not researched_materials.has(item_id):
			researched_materials.append(item_id)
			done += 1

# The Merchant Prince's automation must never sell what the game SPENDS. Skill
# nodes, wall tiers and crafting all draw on these, and the tier-4 rampart alone
# wants 20 iron shards -- with a 12-item cap firing every 20 seconds the player
# had a 20-second window to assemble any cost, and hard-won floor-80 relics were
# being dumped at 4 gold while they were still down there earning them.
const AUTO_SELL_NEVER := ["iron_shard", "ember_crystal", "void_essence",
	"ancient_relic", "sorrowshard"]

func auto_sell_surplus(player) -> void:
	if not ("inventory" in player) or player.inventory == null:
		return
	if in_dungeon:
		return          # never rifle the player's bag while they are still delving
	var earned := 0
	for item_id in Inventory.ITEM_DEFS.keys():
		if not Inventory.ITEM_DEFS[item_id].get("is_material", false):
			continue
		if AUTO_SELL_NEVER.has(item_id):
			continue
		var have = player.inventory.get_count(item_id)
		if have > AUTO_SELL_KEEP:
			var sell = have - AUTO_SELL_KEEP
			player.inventory.remove_item(item_id, sell)
			earned += sell * AUTO_SELL_PRICE
	if earned > 0 and player.has_method("add_currency"):
		player.add_currency(earned)

# THE MARKET SELLS THE TOWN'S OWN SURPLUS (chain link): stores above the keep
# line go out on the Merchant Prince's carts and come back as TREASURY gold --
# which pays the wages. Mine/Builderhouse -> Marketplace -> payroll, closed.
# The keep line is deliberately generous: repairs and the forge eat first.
const AUTO_SELL_VILLAGE_KEEP := 20

func auto_sell_village_surplus() -> void:
	var earned := 0
	for k in village_stockpile.keys():
		var have := int(village_stockpile[k])
		if have > AUTO_SELL_VILLAGE_KEEP:
			var sell := have - AUTO_SELL_VILLAGE_KEEP
			village_stockpile[k] = AUTO_SELL_VILLAGE_KEEP
			# a market beside the counting house gets a better price (adjacency)
			earned += int(round(float(sell * AUTO_SELL_PRICE) * building_output_multiplier("Marketplace")))
	if earned > 0:
		village_treasury += earned
		log_event("economy", "The Merchant Prince sold the surplus stores — %d gold into the treasury." % earned)

func auto_heal_villagers(physicians: int) -> void:
	var amount = AUTO_HEAL_PER_PHYSICIAN * float(physicians) * building_output_multiplier("Hospital")
	# THE WARD THAT NEVER SLEEPS (Hospital power): a grown ward doesn't trickle
	# healing -- whoever is carried in leaves it whole.
	var whole := has_building_power("Hospital")
	for id in villager_hp.keys():
		var hp = float(villager_hp[id])
		if hp < VILLAGER_MAX_HP:
			villager_hp[id] = VILLAGER_MAX_HP if whole else minf(VILLAGER_MAX_HP, hp + amount)

# ===================== THE SCHOOLING POLICY (dev design 2026-07-30) =====================
# What becomes of the children -- the hinge the whole population loop turns on.
# A kid grows up, is sent to the School or to the Barracks, comes out an adult
# with a trade or a warrior on the wall, gets housed, pairs, and has children of
# their own. This is the one decision in that cycle nobody else can make for you.
#
# BY HAND, CRUDELY: you write a number out of ten at the Government. 4 means four
# children in every ten go to the School and six to the drill yard. It is a blunt
# instrument on purpose -- it is what you have before you have anyone better.
#
# THEN THE CHANCELLOR TAKES IT OVER: once that chair is filled, they stop asking
# you and send children where the town actually needs them, reading the wall
# against the waves that are coming. Same ladder as every other chore -- you do it
# badly by hand, then a rescued figure does it better than you could.
const SCHOOL_SHARE_MAX := 10
var school_share := 10            # of every ten children; 10 = all to the School
var _kid_intake := 0              # position in the current block of ten

# Is the Chancellor deciding this instead of the player's dial?
func schooling_is_delegated() -> bool:
	return seated_leaders("Government") > 0

# The Chancellor's read: can the town hold what is coming? If the wall is short
# of the tier now landing, the next children train; otherwise they learn a trade.
# Self-balancing without a dial -- a siege that costs defenders pulls the next
# cohort into the yard on its own.
const CHANCELLOR_DEFENSE_MARGIN := 1.25

func chancellor_wants_warriors() -> bool:
	var tier := float(current_siege_tier())
	if tier <= 0.0:
		return false
	return village_defense_power() < tier * CHANCELLOR_DEFENSE_MARGIN

# Where does the NEXT child go? Returns "School" or "Barracks". Falls back to
# whichever hall actually stands, so a policy can never strand a child nowhere.
func next_schooling_destination() -> String:
	var school_ok := is_building_operational("School")
	var yard_ok := is_building_operational("Barracks")
	if not school_ok and not yard_ok:
		return ""
	var want_yard := false
	if schooling_is_delegated():
		want_yard = chancellor_wants_warriors()
	else:
		# the player's dial: the first `school_share` of every ten go to school
		want_yard = _kid_intake >= school_share
	if want_yard and not yard_ok:
		want_yard = false
	if not want_yard and not school_ok:
		want_yard = true
	return "Barracks" if want_yard else "School"

func _advance_intake() -> void:
	_kid_intake = (_kid_intake + 1) % SCHOOL_SHARE_MAX

func auto_enroll_children(principals: int) -> void:
	# EITHER hall will do now: a child is schooled OR trained, per the policy above.
	# (This used to feed the School alone, so half the population loop -- children
	# becoming warriors -- simply had no automatic path at all.)
	if not is_building_operational("School") and not is_building_operational("Barracks"):
		return
	# the Principal's automation obeys the same Student cap the assign UI
	# enforces by hand (audit fix: it used to over-enroll past the slots)
	var cap := 0
	for rd in BuildingRoles.get_roles("School"):
		if str(rd.get("title", "")) == "Student":
			cap = role_capacity("School", rd)
			break
	# THE OPEN DOORS (power): a hall this grand, with its Principal in it, turns
	# nobody away -- no child waits for a desk. cap 0 means "no ceiling" below.
	if has_building_power("School"):
		cap = 0
	var yard_cap := 0
	for rd2 in BuildingRoles.get_roles("Barracks"):
		if str(rd2.get("title", "")) == "Recruit":
			yard_cap = role_capacity("Barracks", rd2)
			break
	var budget = AUTO_ENROLL_PER_PRINCIPAL * maxi(1, principals)
	# count each hall's own trainees against its own ceiling: school_enrollments is
	# shared (every entry tagged by role_key), so a busy drill yard used to eat the
	# School's seats and the Principal stopped enrolling kids entirely
	var students := 0
	var recruits := 0
	for e in school_enrollments.values():
		if str(e.get("role_key", "School")) == "Barracks":
			recruits += 1
		else:
			students += 1
	for v in rescued_villagers:
		if budget <= 0:
			return
		if not v.get("is_kid", false) or str(v.get("role_key", "")) != "" or school_enrollments.has(v.get("id")):
			continue
		var dest := next_schooling_destination()
		if dest == "":
			return
		# a full hall doesn't turn the child away -- it sends them to the other one
		if dest == "School" and cap > 0 and students >= cap:
			dest = "Barracks" if is_building_operational("Barracks") else ""
		elif dest == "Barracks" and yard_cap > 0 and recruits >= yard_cap:
			dest = "School" if is_building_operational("School") else ""
		if dest == "":
			return
		if dest == "Barracks":
			enroll_villager(str(v.get("id")), "Barracks", "Recruit", "Warrior")
			recruits += 1
		else:
			enroll_villager(str(v.get("id")), "School", "Student", "random")
			students += 1
		_advance_intake()
		budget -= 1

# Builderhouse: advance the single most-ruined building one construction stage
# each tick, for free -- the crew slowly rebuilds Deepwood on its own.
var _builder_half_tick := false
var _builders_short_told := false   # one shortage notice per dry spell, not per tick

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
	# THE STANDING CREW (power): with the Master Builder in a hall this grand the
	# crew scavenges its own timber and stone off the ruin it is standing in, so a
	# stage costs the village stores nothing. This is the one thing the leader
	# could never do alone -- and it is what level 4 buys.
	if has_building_power("Builderhouse"):
		building_stage[worst] = worst_stage + 1
		_finish_repair_stage(worst)
		return
	# THE CHAIN: a stage costs real timber and stone from the village stores --
	# the crew no longer conjures repairs from nothing (City Machine pillar A).
	# Feed the stores with Mine crews and the builders' own timber runs.
	if int(village_stockpile["wood"]) < REPAIR_STAGE_WOOD \
			or int(village_stockpile["stone"]) < REPAIR_STAGE_STONE:
		if not _builders_short_told:
			_builders_short_told = true
			notify("🔨 The builders idle — the stores need wood and stone (timber runs + the Mine).")
			log_event("village", "Repairs stalled: the village stores ran out of wood and stone.")
		return
	_builders_short_told = false
	village_stockpile["wood"] = int(village_stockpile["wood"]) - REPAIR_STAGE_WOOD
	village_stockpile["stone"] = int(village_stockpile["stone"]) - REPAIR_STAGE_STONE
	building_stage[worst] = worst_stage + 1
	_finish_repair_stage(worst)

# The tail every repair path shares: bank the finished hall and refresh its body.
func _finish_repair_stage(worst: String) -> void:
	if int(building_stage.get(worst, 0)) >= TOTAL_BUILD_STAGES:
		building_health[worst] = BUILDING_MAX_HEALTH
		log_event("village", "The builders finished the %s — it stands again." % worst)
	var t := get_tree()
	if t == null:
		return
	for node in t.get_nodes_in_group("building"):
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
		{
			"key": "wages", "label": "Payroll",
			"handled": _bank_paid_full_payroll,
			"freed": "🏦 The Bank met the whole payroll from the town's own purse — your gold is yours again.",
		},
		{
			"key": "family", "label": "Homes & families",
			"handled": seated_leaders("Builderhouse") > 0 and seated_leaders("Bar") > 0,
			"freed": "🏠 The builders raise the homes and the Publican makes the matches — Deepwood grows without you now.",
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
	if dev_mode or selfsuf_celebrated.size() >= chore_domains().size() or not village_info_available():
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
# Wren/Castor, taken by the turning at the feast (12.6) -- SAVED, so a quit
# mid-finale resumes a horde that still holds them (bug hunt 2026-07-28)
var harvest_turned_defenders: Array = []

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
	harvest_turned_defenders = []   # the debt is settled with the army's rise
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack and raised > 0:
		stack.show_notification("★ SHADOW ARMY: %d souls rise — themselves, continued. Deepwood stands, and it is yours." % raised)

# If the player quit during the ending dialogue, the army never rose -- the
# debt is settled the moment they next stand in their village. Never fires
# mid-Harvest: despair_dead only becomes true at the final victory.
func settle_shadow_court() -> void:
	if despair_dead and harvested_villagers.size() > 0:
		raise_shadow_army()
	# Catch-up for the other half of a victory interrupted mid-ENDING: the
	# hourglass is granted before the dialogue now, but saves already written by
	# the old order (won, quit during the six lines, no relic) would stay locked
	# out of NG+ forever. Same guard as the grant itself, player-inventory
	# permitting (this runs from main._ready, after the save is applied).
	if despair_dead and not cycle_broken and not rewound_hour_granted:
		var tree := Engine.get_main_loop() as SceneTree
		var p = tree.get_first_node_in_group("player") if tree else null
		if p and "inventory" in p and p.inventory \
				and p.inventory.get_count("relic_rewound_hour") == 0:
			p.inventory.add_item("relic_rewound_hour", 1)
			rewound_hour_granted = true

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
# The "Deepwood sounds like a village again" milestone (healthy music theme) is
# announced once per run -- the theme may come and go with morale, the diary
# line must not (audit fix). Persisted; a New Game re-earns it.
var healthy_theme_celebrated := false
# One hourglass per WORLD, not per "inventory happens to be empty": every grant
# site used to re-check get_count() == 0, so banking the relic in a chest and
# re-entering the village farmed a fresh mythic each visit (sell fodder).
# Persisted; a New Game clears it and the rewind's state turn re-arms it for
# the next world's victory.
var rewound_hour_granted := false

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

# --- HOSPITAL PAID HEALING (4.1 enforcement, dev-chosen 2026-07-28) ---
# The staffed Hospital is Maren's SCALING SUCCESSOR: a flat full-heal price
# that more nurses talk DOWN (never below the floor). Maren stays the early
# lifeline with her escalating ledger; the ward undercuts her right where
# leaning on one mortal woman should stop being a plan. No staff, no service
# -- the Grammar (5.1) holds even for healing.
const HOSPITAL_HEAL_BASE := 35
const HOSPITAL_HEAL_PER_NURSE_OFF := 5
const HOSPITAL_HEAL_FLOOR := 20

func hospital_heal_available() -> bool:
	return is_building_operational("Hospital") and count_workers("Hospital") > 0

func hospital_heal_price() -> int:
	return maxi(HOSPITAL_HEAL_FLOOR,
		HOSPITAL_HEAL_BASE - HOSPITAL_HEAL_PER_NURSE_OFF * (count_workers("Hospital") - 1))

# Full heal for gold. Returns what happened so the UI can speak plainly.
func hospital_heal(player: Node) -> String:
	if not hospital_heal_available():
		return "unstaffed"
	if player == null or not "health" in player:
		return "no_patient"
	if int(player.health) >= int(player.get_max_health()):
		return "unhurt"
	var price := hospital_heal_price()
	if int(player.currency) < price:
		return "poor"
	player.currency -= price
	if player.has_method("update_currency_display"):
		player.update_currency_display()
	player.health = player.get_max_health()
	if player.has_method("update_health_display"):
		player.update_health_display()
	log_event("village", "The ward stitched the hero whole (-%dg)." % price)
	return "healed"

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
	# a fresh world every New Game (see world_seed)
	world_seed = abs(int(Time.get_unix_time_from_system() * 1000.0)) ^ (randi() & 0x7fffffff)
	life_crystals = 0
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
	# the opening's transient shield: left hot, entering the opening then Quit ->
	# New Game permanently suppressed the whole arrival cutscene for that run
	arrival_battle_active = false
	_arrival_shield_until = 0.0
	harvest_seed = 0        # re-rolled by the first village build of the new run
	harvest_states = {}
	wall_hp = {}
	waystone_home_pos = Vector2.ZERO   # a rewound world's shrines forget the old anchor
	_family_cycle_accum = 0.0
	_doctor_decay_accum = 0.0    # was missing here -> a stale value carried into a New Game
	# the Summoner's pack is PER-RUN: a fresh world starts with nobody at heel
	# and no post standing, or the last run's court walks into the prologue
	active_summons = []
	active_posts = []
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
	building_neighbors = {}   # the row is re-read when the village generates
	building_districts = {}
	building_plots = {}
	building_x = {}
	school_share = SCHOOL_SHARE_MAX   # a new town schools everyone until told otherwise
	sick = {}                         # a new town is a well town
	plague_ids = {}                   # ...and has never met the virulent strain
	burning = {}                      # ...and nothing is alight
	eclipse_at_hours = -1.0           # the sky has not yet gone wrong this run
	eclipses_seen = 0
	_eclipse_roll_accum = 0.0
	_eclipse_announced = false
	_fire_accum = 0.0
	_sick_accum = 0.0
	patrol_posts = {}                 # nobody is in the deep at the start of a run
	block_creep = {}
	_patrol_accum = 0.0
	_kid_intake = 0
	moving_building = ""
	pregnancies = {}
	school_enrollments = {}
	highest_unlocked_level = 999 if TEST_UNLOCK_ALL_LEVELS else 1
	floors_cleared = {}                        # a new run's deep is unswept
	# hidden event bosses re-arm and their run counters zero for the fresh run
	event_state = {}          # explicit reset (arm_hidden_events repopulates it)
	event_rematch_level = {}  # the rematch ladder starts at the bottom each run
	event_rearm_at = {}
	arm_hidden_events()
	run_kills = 0
	run_trees = 0
	run_rocks = 0
	run_gold_spent = 0
	run_villager_deaths = 0
	floors_since_death = 0
	event_bosses_ever_killed = []   # a brand-new game forgets the old hunt
	hunters_horn_announced = false
	waystone_unlocked = false                  # the Waystone is re-earned at floor 20
	village_last_hours_elapsed = 0.0
	game_hours = 0.0
	hours_until_next_siege = SIEGE_FIRST_HOURS
	live_siege_active = false
	# the caravan clock resets whole (the event_state reset-leak lesson)
	hours_until_caravan = CARAVAN_FIRST_HOURS
	caravan_warned = false
	caravans_seen = 0
	live_caravan_active = false
	# fishing resets whole too -- same lesson
	fishing_quest = {}
	fishing_quests_done = 0
	fishing_last_post_day = -1
	fishing_last_oddity = ""
	willow_rod_granted = false
	# and the weeping ledger with it
	weeping_tonight = false
	hours_since_weeping = 0.0
	weepings_seen = 0
	weepings_survived = 0
	weeping_kills = 0
	_weep_last_tod = -1.0
	# the lanterns come down for a new world too
	lantern_tonight = false
	hours_since_lantern = 0.0
	lanterns_seen = 0
	_lantern_last_tod = -1.0
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
	harvest_turned_defenders = []
	despair_dead = false
	_gold_accum = 0.0
	ng_plus_cycles = 0
	cycle_broken = false
	rewound_hour_granted = false
	healthy_theme_celebrated = false
	seen_chronicle_100 = false
	maera_stabilized_this_siege = false
	_deep_catch_accum = 0.0
	# the Dock's other clock, missed here for as long as it has existed: now that
	# it is SAVED, a leftover value would carry a previous life's tide count into
	# a brand-new village (reset audit, 2026-08-03)
	_tide_table_accum = 0.0
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
	came_from_underground = false
	active_dungeon_level = 1
	pre_dungeon_position = Vector2.ZERO
	income_timer = 0.0
	tribute_timer = 0.0
	# A fresh village opens with a full larder (computed after any test-populate,
	# so the starting food matches the starting headcount) -- the player has a
	# comfortable runway to rebuild the Farm before hunger bites.
	food_empty_hours = 0.0
	village_food = food_capacity()
	village_stockpile = {"wood": 0, "stone": 0, "iron_shard": 0}   # the chain starts empty
	_store_accum = {"wood": 0.0, "stone": 0.0, "iron_shard": 0.0}
	village_treasury = 0
	_treasury_accum = 0.0
	_bank_paid_full_payroll = false
	_builders_short_told = false
	_wood_accum = 0.0
	selfsuf_celebrated = []   # a fresh run earns every "your day is your own" beat again
	_peril_band = -1          # the fading-of-Deepwood dread starts quiet
	village_lost = false
	lost_souls = []
	has_whisperstone = false  # the Lab's far-speaker must be built anew each run
	sieges_seen = 0           # the Black Tide count restarts with the run
	_black_omen_armed = true

func has_save() -> bool:
	return FileAccess.file_exists(active_save_path()) \
		or FileAccess.file_exists(active_save_path() + ".tmp")

func save_game(player: Node) -> void:
	var save_pos = pre_dungeon_position if in_dungeon else player.global_position
	# Continue must land on the SURFACE, never in the Underdark (which lives in the
	# village scene). in_dungeon saves pre_dungeon_position -- but with doors-only
	# access that IS a deep Underdark door, and a plain walk in the caves saves the
	# live deep position. Either would drop the player underground on load (and into
	# the void before the deep is built). Persist a safe village spawn instead; the
	# in-session floor exit still uses the live pre_dungeon_position, unaffected.
	# Same threshold guards against writing a below-village-ground position at all:
	# the surface never sits below y=-50 (standing centre y=-63), so anything greater
	# is underground or an invalid spot that would drop the player through the floor.
	if save_pos.y > -50.0:
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
		"rewound_hour_granted": rewound_hour_granted,
		"healthy_theme_celebrated": healthy_theme_celebrated,
		"seen_chronicle_100": seen_chronicle_100,
		"harvested_villagers": harvested_villagers,
		"harvest_turned_defenders": harvest_turned_defenders,
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
		# persist the passive-birth + doctor-price timers so a full quit->Continue doesn't
		# silently discard progress toward the next cottage birth / price decay.
		"family_cycle_accum": _family_cycle_accum,
		"doctor_decay_accum": _doctor_decay_accum,
		# ...and the other daily/interval clocks for the same reason: the mine's
		# ore day, the Dock's deep catch and the Government tribute all sat at
		# 23.9h and restarted from zero on every Continue
		"mine_accum": _mine_accum,
		"mine_cycles": _mine_cycles,   # ember parity: every SECOND cycle pays
		"deep_catch_accum": _deep_catch_accum,
		"tribute_timer": tribute_timer,
		"villager_rot": villager_rot,
		"wanderer": wanderer,
		"wanderer_next_at_hours": wanderer_next_at_hours,
		"wanderers_seen": wanderers_seen,
		"watchtower_tier": watchtower_tier,
		"harvest_seed": harvest_seed,
		"harvest_states": harvest_states,
		"wall_hp": wall_hp,
		"blueprints": blueprints,
		"building_positions": building_positions,
		"building_neighbors": building_neighbors,
		"building_districts": building_districts,
		"building_plots": building_plots,
		"building_x": building_x,
		"school_share": school_share,
		"patrol_posts": patrol_posts,
		"sick": sick,
		"plague_ids": plague_ids,
		"burning": burning,
		# THE DAY-CLOCKS MUST TRAVEL WITH THEM. sick/burning survived a save but their
		# accumulators did not, so every Continue reset the countdown to the next daily
		# roll -- and a player who quits once a day would have the hourly damage run
		# forever while the cure roll and the burn-out roll never came up once.
		"sick_accum": _sick_accum,
		"fire_accum": _fire_accum,
		"eclipse_at_hours": eclipse_at_hours,
		"eclipses_seen": eclipses_seen,
		"block_creep": block_creep,
		"_kid_intake": _kid_intake,
		"pregnancies": pregnancies,
		"school_enrollments": school_enrollments,
		"highest_unlocked_level": highest_unlocked_level,
		"floors_cleared": floors_cleared,
		"world_seed": world_seed,
		"life_crystals": life_crystals,
		# hidden event bosses: which have fired/been looted + the run counters
		"event_state": event_state,
		"event_rematch_level": event_rematch_level,
		"event_rearm_at": event_rearm_at,
		"event_bosses_ever_killed": event_bosses_ever_killed,
		"hunters_horn_announced": hunters_horn_announced,
		"run_kills": run_kills,
		"run_trees": run_trees,
		"run_rocks": run_rocks,
		"run_gold_spent": run_gold_spent,
		"run_villager_deaths": run_villager_deaths,
		"floors_since_death": floors_since_death,
		"waystone_unlocked": waystone_unlocked,
		"player_xp": player_xp,
		"player_level": player_level,
		"skill_points": skill_points,
		"chosen_class": chosen_class,
		"unlocked_skills": unlocked_skills,
		"active_summons": active_summons,
		"active_posts": active_posts,
		"researched_materials": researched_materials,
		"equipment": equipment,
		"game_hours": game_hours,
		"hours_until_next_siege": hours_until_next_siege,
		"hours_until_caravan": hours_until_caravan,
		"caravans_seen": caravans_seen,
		"fishing_quest": fishing_quest,
		"fishing_quests_done": fishing_quests_done,
		"fishing_last_post_day": fishing_last_post_day,
		"fishing_last_oddity": fishing_last_oddity,
		"willow_rod_granted": willow_rod_granted,
		# a LIVE weeping night is deliberately not saved: a load lands on a
		# quiet dark, and the forest simply weeps another time
		"hours_since_weeping": hours_since_weeping,
		"weepings_seen": weepings_seen,
		"weepings_survived": weepings_survived,
		"hours_since_lantern": hours_since_lantern,
		"lanterns_seen": lanterns_seen,
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
		"village_stockpile": village_stockpile,
		"village_treasury": village_treasury,
		"food_empty_hours": food_empty_hours,
		"selfsuf_celebrated": selfsuf_celebrated,
		"lost_souls": lost_souls,
		"village_lost": village_lost,
		"has_whisperstone": has_whisperstone,
		"sieges_seen": sieges_seen,
		# THE LAST THREE SLOW CLOCKS (2026-08-03). Every other in-game-hour counter
		# is written above (family_cycle/doctor_decay/mine/deep_catch, saved when
		# the same bug was caught in them); these three were missed, so a Continue
		# threw their progress away and restarted the wait. The Lumberyard's day of
		# timber and the Dock's Tide Table were each losing up to a full cycle, and
		# the store banks its small crews' output in FRACTIONS -- a village earning
		# 0.9 wood a day banked nothing at all across a quit.
		# Deliberately NOT here: _gold_accum and _treasury_accum (sub-coin
		# fractions, genuinely noise) and _autosave_accum (real seconds, not game
		# time).
		"wood_accum": _wood_accum,
		"tide_table_accum": _tide_table_accum,
		"store_accum": _store_accum,
	}
	# ATOMIC-ish (global hunt 2026-07-28): open(WRITE) TRUNCATES at once, so
	# a crash mid-serialize used to leave a zero-byte save -- the whole world
	# gone. Write the sidecar fully first, only then replace the real file;
	# the worst crash window now leaves a complete .tmp that load_game reads.
	var tmp := active_save_path() + ".tmp"
	var file = FileAccess.open(tmp, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	DirAccess.remove_absolute(active_save_path())
	DirAccess.rename_absolute(tmp, active_save_path())

func load_game() -> Dictionary:
	if not has_save():
		return {}
	var path := active_save_path()
	if not FileAccess.file_exists(path):
		path = active_save_path() + ".tmp"   # the crash-window survivor
	var file = FileAccess.open(path, FileAccess.READ)
	var text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	# a CORRUPT save (power cut mid-write, disk hiccup) must never crash the
	# load nor wipe state -- try the .tmp survivor once, else load nothing
	if not (parsed is Dictionary) and path == active_save_path() \
			and FileAccess.file_exists(active_save_path() + ".tmp"):
		push_warning("savegame.json is corrupt -- falling back to the .tmp survivor")
		var f2 = FileAccess.open(active_save_path() + ".tmp", FileAccess.READ)
		parsed = JSON.parse_string(f2.get_as_text())
		f2.close()
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
		rewound_hour_granted = bool(parsed.get("rewound_hour_granted", false))
		healthy_theme_celebrated = bool(parsed.get("healthy_theme_celebrated", false))
		seen_chronicle_100 = bool(parsed.get("seen_chronicle_100", false))
		harvested_villagers = parsed.get("harvested_villagers", [])
		harvest_turned_defenders = parsed.get("harvest_turned_defenders", [])
		seen_orin_arrival = bool(parsed.get("seen_orin_arrival", false))
		seen_doctor_account = bool(parsed.get("seen_doctor_account", false))
		seen_failed_escape = bool(parsed.get("seen_failed_escape", false))
		seen_orin_glimpse = bool(parsed.get("seen_orin_glimpse", false))
		seen_kneel_echo = bool(parsed.get("seen_kneel_echo", false))
		seen_orin_taunt = bool(parsed.get("seen_orin_taunt", false))
		seen_arrival_battle = bool(parsed.get("seen_arrival_battle", true))   # old saves: don't replay
		seen_arrival_talk = bool(parsed.get("seen_arrival_talk", seen_arrival_battle))   # old saves heard it with the battle
		opening_done = bool(parsed.get("opening_done", true))   # old saves are long past the opening
		# REPAIR a save written by the old mid-chain quit bug: the talk was banked at
		# the START of the arrival chain, so quitting during it persisted
		# seen_arrival_talk=true with opening_done=false -- and tick_sieges() gates on
		# opening_done, silently disabling every siege for the rest of the run.
		# tutorial_begin() sets opening_done the moment the chain completes, so this
		# pair can only mean the chain never finished: un-bank the talk and let the
		# wall approach replay it.
		if seen_arrival_talk and not opening_done:
			seen_arrival_talk = false
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
		_family_cycle_accum = float(parsed.get("family_cycle_accum", 0.0))
		_doctor_decay_accum = float(parsed.get("doctor_decay_accum", 0.0))
		_mine_accum = float(parsed.get("mine_accum", 0.0))
		_mine_cycles = int(parsed.get("mine_cycles", 0))
		_deep_catch_accum = float(parsed.get("deep_catch_accum", 0.0))
		tribute_timer = float(parsed.get("tribute_timer", 0.0))
		harvest_seed = int(parsed.get("harvest_seed", 0))   # 0 = old save: rolled fresh on build
		harvest_states = parsed.get("harvest_states", {}) if parsed.get("harvest_states", {}) is Dictionary else {}
		wall_hp = parsed.get("wall_hp", {}) if parsed.get("wall_hp", {}) is Dictionary else {}
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
		# same grandfather for the Wall: it's a BLUEPRINT_STARTERS special like
		# the Cottage but the legacy fallback (STARTING_BUILDINGS) predates it,
		# so an old save could never raise its rampart again after a delete
		if not ("Wall" in blueprints):
			blueprints.append("Wall")
		building_positions = {}
		if parsed.has("building_positions") and parsed["building_positions"] is Dictionary:
			for k in parsed["building_positions"].keys():
				building_positions[k] = float(parsed["building_positions"][k])
		# the cached neighbour row (adjacency synergy). An older save has none --
		# generate_village rebuilds it the moment the village loads, so an absent
		# key just means "no synergy until you walk in", never a wrong bonus.
		building_neighbors = {}
		if parsed.has("building_neighbors") and parsed["building_neighbors"] is Dictionary:
			for k in parsed["building_neighbors"].keys():
				var sides = parsed["building_neighbors"][k]
				if sides is Array and sides.size() == 2:
					building_neighbors[str(k)] = [str(sides[0]), str(sides[1])]
		building_districts = {}
		if parsed.has("building_districts") and parsed["building_districts"] is Dictionary:
			for k in parsed["building_districts"].keys():
				building_districts[str(k)] = str(parsed["building_districts"][k])
		building_plots = {}
		if parsed.has("building_plots") and parsed["building_plots"] is Dictionary:
			for k in parsed["building_plots"].keys():
				building_plots[str(k)] = str(parsed["building_plots"][k])
		building_x = {}
		if parsed.has("building_x") and parsed["building_x"] is Dictionary:
			for k in parsed["building_x"].keys():
				building_x[str(k)] = float(parsed["building_x"][k])
		# an older save never chose a schooling policy: default to all-School, which
		# is exactly what the game did before the dial existed
		school_share = clampi(int(parsed.get("school_share", SCHOOL_SHARE_MAX)), 0, SCHOOL_SHARE_MAX)
		# the patrols (int keys survive JSON as strings, so rebuild them as ints or
		# every block lookup silently misses and the deep quietly stops creeping)
		patrol_posts = {}
		if parsed.has("patrol_posts") and parsed["patrol_posts"] is Dictionary:
			for k in parsed["patrol_posts"].keys():
				patrol_posts[int(str(k))] = int(parsed["patrol_posts"][k])
		# who is ill (an older save knows nothing of the sickness: a well town)
		sick = {}
		if parsed.has("sick") and parsed["sick"] is Dictionary:
			for ks in parsed["sick"].keys():
				sick[str(ks)] = float(parsed["sick"][ks])
		# which of them carry the virulent strain (an older save: none -- every case
		# it recorded predates the split and was, by definition, the harmless one)
		plague_ids = {}
		if parsed.has("plague_ids") and parsed["plague_ids"] is Dictionary:
			for kp in parsed["plague_ids"].keys():
				if sick.has(str(kp)):
					plague_ids[str(kp)] = true
		# what is alight (an older save is a town that never burned)
		burning = {}
		if parsed.has("burning") and parsed["burning"] is Dictionary:
			for kb in parsed["burning"].keys():
				burning[str(kb)] = float(parsed["burning"][kb])
		# ...and the clocks that decide when each of them next gets its daily roll
		_sick_accum = float(parsed.get("sick_accum", 0.0))
		_fire_accum = float(parsed.get("fire_accum", 0.0))
		# the eclipse clock (an older save has never seen one: -1 = never yet, which
		# hours_since_eclipse reads as "long ago", so the next roll is free to fire)
		eclipse_at_hours = float(parsed.get("eclipse_at_hours", -1.0))
		eclipses_seen = int(parsed.get("eclipses_seen", 0))
		_eclipse_announced = eclipse_is_active()   # don't re-announce one already up
		block_creep = {}
		if parsed.has("block_creep") and parsed["block_creep"] is Dictionary:
			for k2 in parsed["block_creep"].keys():
				block_creep[int(str(k2))] = clampf(float(parsed["block_creep"][k2]), 0.0, 1.0)
		_kid_intake = clampi(int(parsed.get("_kid_intake", 0)), 0, SCHOOL_SHARE_MAX - 1)
		if parsed.has("pregnancies"):
			pregnancies = parsed["pregnancies"]
		if parsed.has("school_enrollments"):
			school_enrollments = parsed["school_enrollments"]
		if parsed.has("highest_unlocked_level"):
			highest_unlocked_level = int(parsed["highest_unlocked_level"])
		if parsed.has("floors_cleared") and parsed["floors_cleared"] is Dictionary:
			floors_cleared = parsed["floors_cleared"]
		# a save from before world seeds keeps the original fixed map (seed 0), so
		# its already-dug tunnels still match the terrain they were cut from
		world_seed = int(parsed.get("world_seed", 0))
		life_crystals = int(parsed.get("life_crystals", 0))
		# hidden event bosses (older saves lack these -> arm fresh, counters 0)
		if parsed.has("event_state") and parsed["event_state"] is Dictionary:
			event_state = parsed["event_state"]
			for id in EventBoss.ids():
				# a save from before an event existed still arms it...
				if not event_state.has(id):
					event_state[id] = "armed"
				# ...and a fight left unresolved by a mid-battle QUIT (saved as
				# "triggered", but its director/boss are gone on reload) re-arms,
				# so the boss + its loot are never silently lost to a quit.
				elif event_state[id] == "triggered":
					event_state[id] = "armed"
			if parsed.has("event_rematch_level") and parsed["event_rematch_level"] is Dictionary:
				event_rematch_level = parsed["event_rematch_level"]
			if parsed.has("event_rearm_at") and parsed["event_rearm_at"] is Dictionary:
				event_rearm_at = parsed["event_rearm_at"]
		else:
			arm_hidden_events()
		if parsed.has("event_bosses_ever_killed") and parsed["event_bosses_ever_killed"] is Array:
			event_bosses_ever_killed = parsed["event_bosses_ever_killed"]
		hunters_horn_announced = bool(parsed.get("hunters_horn_announced", false))
		_event_omen_fired = {}   # loading a run lets the near-trigger omens play again
		run_kills = int(parsed.get("run_kills", 0))
		run_trees = int(parsed.get("run_trees", 0))
		run_rocks = int(parsed.get("run_rocks", 0))
		run_gold_spent = int(parsed.get("run_gold_spent", 0))
		run_villager_deaths = int(parsed.get("run_villager_deaths", 0))
		floors_since_death = int(parsed.get("floors_since_death", 0))
		waystone_unlocked = bool(parsed.get("waystone_unlocked", false))
		if TEST_UNLOCK_ALL_LEVELS:
			highest_unlocked_level = max(highest_unlocked_level, 999)
		player_xp = int(parsed.get("player_xp", player_xp))
		player_level = int(parsed.get("player_level", player_level))
		monarch_stage_announced = monarch_stage()   # already-reached stages don't re-toast
		skill_points = int(parsed.get("skill_points", skill_points))
		chosen_class = parsed.get("chosen_class", chosen_class)
		unlocked_skills = parsed.get("unlocked_skills", unlocked_skills)
		# a save written before the Summoner existed simply has no pack
		active_summons = parsed.get("active_summons", [])
		active_posts = parsed.get("active_posts", [])
		researched_materials = parsed.get("researched_materials", researched_materials)
		if parsed.has("equipment"):
			load_equipment(parsed["equipment"])
		game_hours = float(parsed.get("game_hours", 0.0))
		hours_until_next_siege = float(parsed.get("hours_until_next_siege", SIEGE_FIRST_HOURS))
		hours_until_caravan = float(parsed.get("hours_until_caravan", CARAVAN_FIRST_HOURS))
		caravans_seen = int(parsed.get("caravans_seen", 0))
		fishing_quest = parsed.get("fishing_quest", {})
		fishing_quests_done = int(parsed.get("fishing_quests_done", 0))
		fishing_last_post_day = int(parsed.get("fishing_last_post_day", -1))
		fishing_last_oddity = str(parsed.get("fishing_last_oddity", ""))
		willow_rod_granted = bool(parsed.get("willow_rod_granted", false))
		hours_since_weeping = float(parsed.get("hours_since_weeping", 0.0))
		weepings_seen = int(parsed.get("weepings_seen", 0))
		weepings_survived = int(parsed.get("weepings_survived", 0))
		weeping_tonight = false      # a live night never survives a load
		_weep_last_tod = -1.0
		hours_since_lantern = float(parsed.get("hours_since_lantern", 0.0))
		lanterns_seen = int(parsed.get("lanterns_seen", 0))
		lantern_tonight = false      # nor does a live festival
		_lantern_last_tod = -1.0
		caravan_warned = false          # the dust re-announces after a load
		live_caravan_active = false     # a live fight never survives a reload
		live_siege_active = false
		# Continue loads you standing in the VILLAGE -- but GameState is an autoload
		# that survives Quit-to-Menu, so transient run-flags from the pre-menu
		# session leak in (reset_for_new_game clears these; load_game must too).
		# Without this, quitting inside a dungeon left in_dungeon=true (live sieges
		# silently resolved off-screen, arrival suppressed); quitting mid-Harvest
		# left harvest_at_home/feast_glow set (finale soft-lock / morale pinned 100).
		in_dungeon = false
		# a floor entered from the tile underground sets this so exit_dungeon returns
		# THERE, not the village. It must NOT survive a Quit-to-Menu: else a later
		# village-launched floor would wrongly exit into the underground scene and drop
		# the player at a stale coord in the freshly-regenerated world.
		came_from_underground = false
		moving_building = ""   # a packed-for-relocation flag must not leak past Continue (else H hijacked)
		harvest_at_home = false
		feast_glow = false
		# the admin god-form toggle is a live-session convenience, never saved --
		# but it wasn't cleared here either, so it leaked across Quit -> Continue
		monarch_true_form_forced = false
		_warned_no_food = false
		_warned_low_morale = false
		# the remaining unsaved per-run clocks and latches, cleared for the same
		# reason: whatever the PREVIOUS session left in the autoload is not this
		# save's state. _peril_band leaking at a worse band swallowed the loaded
		# village's "only N souls remain" dread; a disarmed tower bell cost the
		# first siege its warning toll; the income fractions are just noise.
		income_timer = 0.0
		_gold_accum = 0.0
		_peril_band = -1
		_tower_bell_armed = true
		# ...but the SLOW clocks are RESTORED, not cleared (see save_game). The
		# other four are read further up with their neighbours; these are the three
		# that were never written at all. An older save carries none of these keys
		# and starts them at 0.0, which is exactly how it behaved before, so no
		# migration is needed.
		_wood_accum = float(parsed.get("wood_accum", 0.0))
		_tide_table_accum = float(parsed.get("tide_table_accum", 0.0))
		var saved_store = parsed.get("store_accum", {})
		if saved_store is Dictionary:
			for k in _store_accum.keys():
				_store_accum[k] = float(saved_store.get(k, 0.0))
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
		var vs: Dictionary = parsed.get("village_stockpile", {})
		for k in village_stockpile.keys():
			village_stockpile[k] = int(vs.get(k, 0))
		village_treasury = int(parsed.get("village_treasury", 0))
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
	if FileAccess.file_exists(active_save_path()):
		DirAccess.remove_absolute(active_save_path())
	if FileAccess.file_exists(active_save_path() + ".tmp"):
		DirAccess.remove_absolute(active_save_path() + ".tmp")

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
	# hidden-event kill counter piggybacks on the same slay call site. (Floor
	# clears are counted in mark_floor_cleared, NOT here -- "reach_level" also
	# fires on floor ARRIVAL, which is not a clear.)
	if kind == "slay":
		note_kill(amount)
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
	if str(def.get("kind", "")) == "reunite":
		# a reunion is a STATE, not an event: quest_event only fires at the
		# instant the partner is rescued, so a giver freed AFTER their partner
		# (free Bram on floor 8, then shatter Sena's road crystal) activated at
		# progress 0 with no event left to ever fire -- "Sena's Sister" could
		# never be claimed. Read the roster live instead.
		return int(v.get("quest_progress", 0)) >= count \
			or is_villager_rescued(str(def.get("key", "")))
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
		# add_item returns the UN-added leftover; a full bag was silently eating the
		# bond reward while the turn-in still reported success (dev sweep 2026-07-25).
		var _rleft: int = player.inventory.add_item(str(def.get("reward_item")), int(def.get("reward_count", 1)))
		if _rleft > 0:
			var _st = get_tree().get_first_node_in_group("notification_stack")
			if _st: _st.show_notification("Your bag was full — part of the bond's reward couldn't be carried.")
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
