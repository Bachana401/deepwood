class_name EventBoss
extends RefCounted

# ===========================================================================
# HIDDEN EVENT BOSSES (2026-07-28). Ten secret bosses, woken by the player
# quietly DOING something -- no quest marker, no instruction, ever. Each is
# armed once per run (GameState.event_state), fires when its condition holds
# (GameState.tick_hidden_events), is staged into whatever scene the player is
# in (event_boss_director.gd, modelled on harvest_director), and pays a table
# of EXCLUSIVE loot on death (award()). The weapon is a 50/50 coin-flip so a
# single run can never assemble the whole armoury; the relic/armour/material
# are guaranteed. Difficulty (medium < hard < very_hard < expert) drives both
# the boss's scaling AND the grade of its drops.
#
# The boss's LOOK/kit lives in boss.gd BOSSES under the same `boss_id` (all
# procedural rigs -- no art needed); this file is pure data + drop logic. The
# trigger CONDITIONS live in GameState.tick_hidden_events (they need live
# world state); the `hint` field here is a human note of each, nothing more.
# ===========================================================================

# Per-difficulty combat scaling + the HUD accent. hp/dmg multiply the boss's
# base def hp/damage; `floor` is fed to boss.boss_floor purely to set how LONG
# its ability combos run (deeper = longer, nastier -- never a bigger number,
# per the forever boss rule). Damage stays bounded: difficulty is mechanics,
# not one-shots.
const DIFF := {
	"medium":    {"hp": 2.2, "dmg": 1.0,  "floor": 22,  "label": "Medium",    "accent": Color(0.55, 0.8, 0.5)},
	"hard":      {"hp": 3.4, "dmg": 1.25, "floor": 45,  "label": "Hard",      "accent": Color(0.95, 0.7, 0.25)},
	"very_hard": {"hp": 4.8, "dmg": 1.5,  "floor": 72,  "label": "Very Hard", "accent": Color(1.0, 0.32, 0.46)},
	"expert":    {"hp": 7.0, "dmg": 1.85, "floor": 100, "label": "Expert",    "accent": Color(0.3, 0.95, 1.0)},
	"master":    {"hp": 9.5, "dmg": 2.0,  "floor": 100, "label": "Master",    "accent": Color(1.0, 0.85, 0.4)},
}

# id -> event. `boss_id` keys boss.gd BOSSES. `weapons` is the 50/50 pair;
# `extras` are guaranteed. `where` is the intended stage (used only for the
# announce line -- the boss actually spawns wherever the player stands).
const EVENTS := {
	# ---- MEDIUM ----
	"tallyman": {
		"name": "The Tallyman", "difficulty": "medium", "boss_id": "evt_tallyman",
		"where": "village", "banner": "the debt comes due",
		"weapons": ["evt_ledger", "evt_coinbite"],
		"extras": ["relic_usurer", "mat_debtcoin"],
		"hint": "hoard >= 8000 gold on your person while home",
	},
	"first_frost": {
		"name": "The First Frost", "difficulty": "medium", "boss_id": "evt_firstfrost",
		"where": "wilderness", "banner": "something older than winter stirs",
		"weapons": ["evt_hoarfrost", "evt_rimeglass"],
		"extras": ["relic_rimeheart", "mat_everfrost"],
		"hint": "stand outside the dungeon in the coldest hour (00:00-02:30)",
	},
	"glutton_root": {
		"name": "The Glutton Root", "difficulty": "medium", "boss_id": "evt_gluttonroot",
		"where": "wilderness", "banner": "the woods take back what was taken",
		"weapons": ["evt_bramblewhip", "evt_thornvolley"],
		"extras": ["relic_verdant", "mat_heartwood"],
		"hint": "fell 50 trees in a run (over-harvest)",
	},
	# ---- HARD ----
	"drowned_chorus": {
		"name": "The Drowned Chorus", "difficulty": "hard", "boss_id": "evt_drowned",
		"where": "underdark", "banner": "you dug too greedily, and too deep",
		"weapons": ["evt_tiderender", "evt_deepcaller"],
		"extras": ["relic_pearl", "mat_brine"],
		"hint": "break 90 rocks in a run (dig too deep)",
	},
	"effigy_king": {
		"name": "The Effigy King", "difficulty": "hard", "boss_id": "evt_effigyking",
		"where": "dungeon", "banner": "the fire you fed answers",
		"weapons": ["evt_pyreblade", "evt_emberking"],
		"extras": ["relic_effigy", "armor_ember", "mat_pyreash"],
		"hint": "spend 15000 gold across a run (burn your wealth)",
	},
	"sleepless_warden": {
		"name": "The Sleepless Warden", "difficulty": "hard", "boss_id": "evt_warden",
		"where": "dungeon", "banner": "it has waited, unblinking, for you",
		"weapons": ["evt_vigil", "evt_wakeful"],
		"extras": ["relic_unblinking", "mat_vigilember"],
		"hint": "clear 6 floors in a row without dying",
	},
	# ---- VERY HARD ----
	"grief_eater": {
		"name": "The Grief-Eater", "difficulty": "very_hard", "boss_id": "evt_griefeater",
		"where": "village", "banner": "it has grown fat on your losses",
		"weapons": ["evt_scythe", "evt_wail"],
		"extras": ["relic_widow", "helm_mourn", "mat_grieftear"],
		"hint": "let 3 villagers fall in a run (feed it grief)",
	},
	"hollow_crown": {
		"name": "The Hollow Crown", "difficulty": "very_hard", "boss_id": "evt_hollowcrown",
		"where": "dungeon", "banner": "a pretender challenges the shadow throne",
		"weapons": ["evt_pretender", "evt_usurper"],
		"extras": ["relic_hollow", "mat_crownshard"],
		"hint": "reach Shadow-Monarch stage 4+ then enter a dungeon boss floor",
	},
	"sable_hound": {
		"name": "The Sable Hound", "difficulty": "very_hard", "boss_id": "evt_sablehound",
		"where": "dungeon", "banner": "the hunt has turned on the hunter",
		"weapons": ["evt_houndsfang", "evt_coursing"],
		"extras": ["relic_hound", "mat_sableichor"],
		"hint": "slay 300 foes in a run (a hunter's streak)",
	},
	# ---- EXPERT ----
	"nihil": {
		"name": "Nihil, the Last Hour", "difficulty": "expert", "boss_id": "evt_nihil",
		"where": "village", "banner": "the hour that unmakes all hours",
		"weapons": ["evt_endbringer", "evt_stareater"],
		"extras": ["relic_lasthour", "armor_unmade", "mat_unmade"],
		"trigger": "item",   # the Duskmoon Effigy, used while sun+moon share the sky
		"hint": "use the Duskmoon Effigy while the sun and moon both ride the sky",
	},
	# ---- MASTER: the 11th, the capstone. Only summonable once you've slain all
	# ten (their trophies forge the Hunter's Horn). ----
	"huntsman": {
		"name": "The Master of the Hunt", "difficulty": "master", "boss_id": "evt_huntsman",
		"where": "dungeon", "banner": "the ten deaths you dealt have a witness",
		"weapons": ["evt_huntcrown", "evt_huntbow"],
		"extras": ["relic_huntmaster", "mat_huntsign"],
		"trigger": "item",   # the Hunter's Horn
		"hint": "sound the Hunter's Horn (forged from all ten trophies)",
		"capstone": true,
	},
}

static func ids() -> Array:
	return EVENTS.keys()

# Item-only events (Nihil, the Master) are woken by a used item -- never by the
# ambient condition tick.
static func is_item_only(id: String) -> bool:
	return str(EVENTS.get(id, {}).get("trigger", "")) == "item"

# The ten to defeat for the capstone (everything that isn't the capstone itself).
static func hunt_ids() -> Array:
	var out: Array = []
	for id in EVENTS:
		if not EVENTS[id].get("capstone", false):
			out.append(id)
	return out

static func get_event(id: String) -> Dictionary:
	return EVENTS.get(id, {})

static func scaling_for(id: String) -> Dictionary:
	var ev: Dictionary = EVENTS.get(id, {})
	return DIFF.get(ev.get("difficulty", "medium"), DIFF["medium"])

# Roll and hand over an event boss's whole table onto a felled kill: ONE of the
# two exclusive weapons (a true 50/50), then every guaranteed extra. Returns the
# display names granted, most-wanted first, for the director's toast. Anything
# the bag can't hold is dropped silently rather than lost to a crash -- the
# director reports the shortfall.
static func award(player: Node, id: String) -> Array:
	var ev: Dictionary = EVENTS.get(id, {})
	if ev.is_empty() or player == null or not is_instance_valid(player):
		return []
	var granted: Array = []
	var weapons: Array = ev.get("weapons", [])
	if not weapons.is_empty():
		var pick: String = weapons[randi() % weapons.size()]
		if player.inventory.add_item(pick, 1) == 0:
			granted.append(Inventory.get_display_name(pick))
	for extra in ev.get("extras", []):
		if player.inventory.add_item(str(extra), 1) == 0:
			granted.append(Inventory.get_display_name(str(extra)))
	return granted

# Every id that could ever be granted by ANY event -- used by tests / dev tools
# to confirm the loot is all real and to keep it out of the ordinary pools.
static func all_loot_ids() -> Array:
	var out: Array = []
	for ev in EVENTS.values():
		for w in ev.get("weapons", []):
			out.append(w)
		for e in ev.get("extras", []):
			out.append(e)
	return out
