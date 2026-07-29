class_name VillagerQuests
extends RefCounted

# Two things live here:
#  1) QUEST_DEFS -- per-villager "Bonds" (a personal quest tied to one named
#     rescued villager). Completing a bond reveals a HIDDEN stat, pays a
#     one-time reward, and marks the villager bonded (1.5x role income for
#     worker-role villagers -- see GameState.turn_in_villager_quest).
#  2) IMPORTANT_FIGURES -- the named LEADERSHIP VIPs, one per leadership slot in
#     building_roles.gd (19 total). Each carries the unique leader stat that is
#     the SOLE key to one building's top post (Chancellor/Harvestmaster/...),
#     and each is reserved to a dungeon BOSS level (5,10,...,95). The dungeon
#     spawns the matching one as a rescuable captive (dungeon_interior.
#     spawn_deep_rescue); freeing them auto-seats them in their leadership role.
#     Level 100 (Orin) is left for the separate 10-hostage finale capstone.
#
# Def fields (QUEST_DEFS): title, giver (one spoken line mid-quest), kind
# (gather|slay|reach_level|reunite), key (gather item / reunite villager id),
# count, reveal_stat/reveal_value (hidden stat unlocked), reward_gold,
# reward_item/reward_count, reward_line (spoken on completion).

const QUEST_DEFS = {
	# --- the starting six ---
	# THE SOUL SPLIT QUEST (12.2, dev-chosen framing 2026-07-28): Ada Brook,
	# day-one farmhand, carries her grandmother's "broken" wand -- the joke
	# item the Ten will one day reveal as the ONLY thing that can open the
	# Monarch of Despair (9.5's wand window). Her reward line half-quotes
	# Elenwe's finale words and trails off: the seed, never the spoiler.
	"farmer_ada": {
		"title": "Grandmother's Wand",
		"giver": "My grandmother left me a wand. It doesn't work -- it never worked. But she made me swear it would matter one day, and I'm tired of carrying the promise alone. Bring me four good lengths of wood for a case, and it's yours.",
		"kind": "gather", "key": "wood", "count": 4,
		"reveal_stat": "Farm", "reveal_value": 3,
		"reward_gold": 0, "reward_item": "wpn_soulsplit", "reward_count": 1,
		"reward_line": "There -- grandmother's wand, case and all, yours now. She always used to say... 'an undivided soul' -- something. I forget the rest. It's junk. But it's PROMISED junk.",
	},
	# --- starting village hostages (workers, hand-placed in main.tscn) ---
	"elin_riverside": {
		"title": "Elin's Orchard",
		"giver": "If I had some wild herbs, I could coax the dead orchard back to life...",
		"kind": "gather", "key": "herb", "count": 4,
		"reveal_stat": "Farm", "reveal_value": 2,
		"reward_gold": 40, "reward_item": "food_stew", "reward_count": 1,
		"reward_line": "The orchard will bloom again. I won't forget this.",
	},
	"milo_docks": {
		"title": "Milo's Reckoning",
		"giver": "The things that dragged us from the docks still crawl the deep. Thin them out for me.",
		"kind": "slay", "key": "", "count": 15,
		"reveal_stat": "Fishing", "reveal_value": 3,
		"reward_gold": 55, "reward_item": "potion_health", "reward_count": 1,
		"reward_line": "The water's ours again. Any catch you want, it's yours.",
	},
	"bram_hollow": {
		"title": "Bram's Proving",
		"giver": "Cut a path deep into the dungeon and I'll follow your example.",
		"kind": "reach_level", "key": "", "count": 5,
		"reveal_stat": "Warrior", "reveal_value": 3,
		"reward_gold": 60, "reward_item": "", "reward_count": 0,
		"reward_line": "You reached the fifth deep and returned. I'm ready to take up arms.",
	},
	"sena_ward": {
		"title": "Sena's Sister",
		"giver": "My sister Bram was taken the same night I was. If you find her, bring her home.",
		"kind": "reunite", "key": "bram_hollow", "count": 1,
		"reveal_stat": "Hospital", "reveal_value": 4,
		"reward_gold": 45, "reward_item": "potion_mana", "reward_count": 1,
		"reward_line": "You brought her back to me. Whatever healing this village needs, I'll give it.",
	},
	# === Leadership VIPs (IMPORTANT_FIGURES). Bonds themed to each post; the
	# deeper the rescue level, the harder the bond and the richer the reward. ===
	"maeve_harvest": {   # Farm Harvestmaster (Lv5)
		"title": "Maeve's First Sowing", "giver": "Bring me wild herbs and I'll turn this dust back into fields.",
		"kind": "gather", "key": "herb", "count": 5, "reveal_stat": "Farm", "reveal_value": 3,
		"reward_gold": 80, "reward_item": "food_stew", "reward_count": 1,
		"reward_line": "The Harvestmaster works again. Deepwood will not go hungry.",
	},
	"doran_tide": {   # Fishing Dock Harbormaster (Lv10)
		"title": "The Harbormaster's Nets", "giver": "Fetch me bait -- fresh meat -- and I'll have the whole fleet hauling again.",
		"kind": "gather", "key": "raw_meat", "count": 6, "reveal_stat": "Fishing", "reveal_value": 3,
		"reward_gold": 100, "reward_item": "potion_health", "reward_count": 1,
		"reward_line": "Every boat that's left answers to me now. The docks live.",
	},
	"bess_ironcask": {   # Tavern Tavernkeeper (Lv15)
		"title": "Bess's Barrels", "giver": "No ale without casks, no casks without timber. Bring me wood.",
		"kind": "gather", "key": "wood", "count": 8, "reveal_stat": "Tavern", "reveal_value": 3,
		"reward_gold": 110, "reward_item": "food_stew", "reward_count": 2,
		"reward_line": "First round's on the house -- forever. The Tavern's yours as much as mine.",
	},
	"fenn_publican": {   # Bar Publican (Lv20)
		"title": "Keeping the Peace", "giver": "A good house needs a hard door. Clear out thirty of those crawling things.",
		"kind": "slay", "key": "", "count": 30, "reveal_stat": "Tavern", "reveal_value": 2,
		"reward_gold": 120, "reward_item": "potion_health", "reward_count": 1,
		"reward_line": "The Bar's a haven again. Folk will drink and forget the dark a while.",
	},
	"sethric_gilt": {   # Marketplace Merchant Prince (Lv25)
		"title": "The Prince's Stock", "giver": "Luxury sells. Bring me ember crystals and I'll make Deepwood a trade road again.",
		"kind": "gather", "key": "ember_crystal", "count": 3, "reveal_stat": "Marketplace", "reveal_value": 3,
		"reward_gold": 160, "reward_item": "food_feast", "reward_count": 1,
		"reward_line": "Coin will flow through this village like a river. You'll want for nothing.",
	},
	"hilda_forge": {   # Blacksmith Forgemaster (Lv30)
		"title": "Relighting the Forge", "giver": "A cold forge is a dead one. Bring me iron and I'll wake it.",
		"kind": "gather", "key": "iron_shard", "count": 6, "reveal_stat": "Blacksmith", "reveal_value": 3,
		"reward_gold": 170, "reward_item": "potion_mana", "reward_count": 1,
		"reward_line": "Hear that ring? The Forgemaster's back. Every blade in Deepwood sharpens now.",
	},
	"orla_pitmaster": {   # Mine Pitmaster (Lv18)
		"title": "Reading the Seam", "giver": "That hill's full of iron and the crew's cutting blind. Bring me ore and I'll show them where it runs.",
		"kind": "gather", "key": "iron_shard", "count": 4, "reveal_stat": "Mine", "reveal_value": 3,
		"reward_gold": 130, "reward_item": "potion_health", "reward_count": 1,
		"reward_line": "The Pitmaster has the seam now — every pick in Deepwood bites deeper.",
	},
	"alric_ledger": {   # Bank Treasurer (Lv35)
		"title": "The Vault's Debt", "giver": "Reavers still circle the old vault. Break forty of them and the coin is safe.",
		"kind": "slay", "key": "", "count": 40, "reveal_stat": "Financist", "reveal_value": 3,
		"reward_gold": 200, "reward_item": "food_stew", "reward_count": 2,
		"reward_line": "The books balance again. Deepwood's wealth is under lock and Treasurer.",
	},
	"vesna_root": {   # Hospital Chief Physician (Lv40)
		"title": "The Physician's Stores", "giver": "I cannot heal without medicine. Bring me healing herbs -- eight should start us.",
		"kind": "gather", "key": "herb", "count": 8, "reveal_stat": "Hospital", "reveal_value": 3,
		"reward_gold": 210, "reward_item": "potion_health", "reward_count": 2,
		"reward_line": "The ward is open. No one in Deepwood dies of a wound I can mend.",
	},
	"ollin_quill": {   # School Principal (Lv45)
		"title": "Lessons of the Deep", "giver": "I'll not teach what I don't understand. Descend to the fifty-fifth level, then tell me what's down there.",
		"kind": "reach_level", "key": "", "count": 55, "reveal_stat": "Hospital", "reveal_value": 2,
		"reward_gold": 230, "reward_item": "food_sage", "reward_count": 1,
		"reward_line": "So that's the shape of the dark. The children will be ready for it. School's in.",
	},
	"ada_vell": {   # School Principal (Lv50)
		"title": "Ada's Specimens", "giver": "A curriculum needs proof. Bring me ten slime cores for the children to study.",
		"kind": "gather", "key": "slime", "count": 10, "reveal_stat": "Scientist", "reveal_value": 2,
		"reward_gold": 240, "reward_item": "food_feast", "reward_count": 1,
		"reward_line": "Wonderful, wonderful. Deepwood's young will out-think this darkness yet.",
	},
	"garrick_stone": {   # Builderhouse Master Builder (Lv55)
		"title": "The Master's Foundation", "giver": "You want walls that hold? Bring me twelve good stones and I'll show you a foundation.",
		"kind": "gather", "key": "stone", "count": 12, "reveal_stat": "Blacksmith", "reveal_value": 2,
		"reward_gold": 260, "reward_item": "food_feast", "reward_count": 1,
		"reward_line": "Give me stone and time and I'll raise Deepwood taller than it ever stood.",
	},
	"tomas_beam": {   # Builderhouse Foreman (Lv60)
		"title": "The Foreman's Crew", "giver": "A crew needs timber to work. Twelve lengths of wood and we'll start repairs today.",
		"kind": "gather", "key": "wood", "count": 12, "reveal_stat": "Farm", "reveal_value": 2,
		"reward_gold": 270, "reward_item": "potion_health", "reward_count": 2,
		"reward_line": "Hammers are swinging again. Point me at what's broken -- it won't be for long.",
	},
	"korrin_vale": {   # Barracks Warchief (Lv65)
		"title": "Korrin's War", "giver": "A Warchief is proven in blood, not words. Break fifty of the enemy and I'll raise your banner.",
		"kind": "slay", "key": "", "count": 50, "reveal_stat": "Warrior", "reveal_value": 3,
		"reward_gold": 280, "reward_item": "food_feast", "reward_count": 1,
		"reward_line": "Fifty fewer. Give me recruits and I'll forge them into a wall of spears.",
	},
	"callan_marshal": {   # Barracks Warchief (Lv70) -- the Last Marshal
		"title": "The Marshal's Muster", "giver": "Deepwood cannot stand while that host still marches. Break eighty of them and I'll rally what remains.",
		"kind": "slay", "key": "", "count": 80, "reveal_stat": "Warrior", "reveal_value": 4,
		"reward_gold": 320, "reward_item": "food_feast", "reward_count": 2,
		"reward_line": "Eighty fewer to fear. Raise the banner -- the village has a Marshal again.",
	},
	"wrenna_sooth": {   # Science Lab Lead Researcher (Lv75)
		"title": "Wrenna's Reagents", "giver": "True research needs true materials. Two shards of void-essence and I'll unseal my work.",
		"kind": "gather", "key": "void_essence", "count": 2, "reveal_stat": "Scientist", "reveal_value": 4,
		"reward_gold": 320, "reward_item": "potion_reset", "reward_count": 1,
		"reward_line": "The lab breathes again. There is nothing Deepwood cannot now learn to build.",
	},
	"ipsen_crole": {   # Science Lab Lead Researcher (Lv80)
		"title": "Crole's Crucible", "giver": "My crucible has been cold for a lifetime. Five ember crystals will light it.",
		"kind": "gather", "key": "ember_crystal", "count": 5, "reveal_stat": "Scientist", "reveal_value": 4,
		"reward_gold": 340, "reward_item": "food_sage", "reward_count": 2,
		"reward_line": "It burns again -- and so does my mind. Set me any riddle of the deep.",
	},
	"yorwen_archivist": {   # Science Lab Lead Researcher (Lv85)
		"title": "The Archivist's Price", "giver": "Knowledge has a cost. Bring me three relics of the old world and I'll unseal what I've kept hidden.",
		"kind": "gather", "key": "ancient_relic", "count": 3, "reveal_stat": "Scientist", "reveal_value": 5,
		"reward_gold": 360, "reward_item": "potion_reset", "reward_count": 1,
		"reward_line": "So. The lore is yours now too. Guard it better than the last age did.",
	},
	"sable_archmagus": {   # Science Lab Lead Researcher (Lv90) -- the Archmagus
		"title": "Sable's Fire", "giver": "I armed a kingdom's mages once. Bring me three cores of void-essence and I'll put fire in Deepwood's hands.",
		"kind": "gather", "key": "void_essence", "count": 3, "reveal_stat": "Scientist", "reveal_value": 5,
		"reward_gold": 400, "reward_item": "food_sage", "reward_count": 2,
		"reward_line": "Let them come now. Deepwood's mages will burn as bright as the old age ever did.",
	},
	"alaric_thorne": {   # Government Chancellor (Lv95) -- the deepest leadership rescue
		"title": "The Chancellor's Trial", "giver": "To lead the living you must know the deep that hunts them. Descend to the ninety-ninth gate and return to me.",
		"kind": "reach_level", "key": "", "count": 99, "reveal_stat": "Financist", "reveal_value": 4,
		"reward_gold": 500, "reward_item": "potion_reset", "reward_count": 1,
		"reward_line": "You stood at the last gate and walked back. Deepwood has a Chancellor worthy of it.",
	},
}

# Named leadership VIPs reserved to dungeon BOSS levels (5..95). Each fills the
# matching unique leadership post in building_roles.gd on rescue (stat_name ==
# role_title == the role's required_stat). Tone is epic/mythic per STORY.md;
# backstories seed the fallen-world lore WITHOUT canonising the still-undecided
# way to stop the undying Wizard. Keyed by rescue level.
const IMPORTANT_FIGURES = {
	# Not a VIP -- Sena's sister, the target of the game's one "reunite" bond.
	# She sat in this registry as a quest def with NO spawn anywhere, so Sena's
	# quest could never even be attempted. Level 8: shallow enough to find her
	# while Sena's plea is still fresh. (spawn_deep_rescue runs on EVERY level,
	# not just boss floors, so a non-multiple-of-5 slot is fine.)
	8:  {"villager_id": "bram_hollow",     "villager_name": "Bram Hollow",             "stat_name": "Warrior",         "stat_value": 4, "role_key": "Barracks",     "role_title": "Warrior",         "sex": "Female", "backstory": "They dragged me down here the night the village fell. My sister Sena -- is she alive?"},
	5:  {"villager_id": "maeve_harvest",   "villager_name": "Maeve Greenhollow",       "stat_name": "Harvestmaster",   "stat_value": 5, "role_key": "Farm",         "role_title": "Harvestmaster",   "sex": "Female", "backstory": "I fed a province once, before the blight. Give me soil and I'll do it again."},
	10: {"villager_id": "doran_tide",      "villager_name": "Captain Doran Tide",      "stat_name": "Harbormaster",    "stat_value": 5, "role_key": "Fishing Dock", "role_title": "Harbormaster",    "sex": "Male",   "backstory": "Every ship in this harbor was mine to command. The sea still answers me."},
	15: {"villager_id": "bess_ironcask",   "villager_name": "Bess Ironcask",           "stat_name": "Tavernkeeper",    "stat_value": 5, "role_key": "Tavern",       "role_title": "Tavernkeeper",    "sex": "Female", "backstory": "A village with no tavern has already lost. Let me give them somewhere to laugh."},
	18: {"villager_id": "orla_pitmaster",  "villager_name": "Orla Deepdelve",          "stat_name": "Pitmaster",       "stat_value": 5, "role_key": "Mine",         "role_title": "Pitmaster",       "sex": "Female", "backstory": "I read a seam the way you read a page. Point me at that hill and I'll tell you what it's hiding."},
	20: {"villager_id": "fenn_publican",   "villager_name": "Fenn Merriman",           "stat_name": "Publican",        "stat_value": 5, "role_key": "Bar",          "role_title": "Publican",        "sex": "Male",   "backstory": "I kept the music playing while the world ended outside my door. I can do it here."},
	25: {"villager_id": "sethric_gilt",    "villager_name": "Sethric Gilt",            "stat_name": "Merchant Prince", "stat_value": 6, "role_key": "Marketplace",  "role_title": "Merchant Prince", "sex": "Male",   "backstory": "I traded across three kingdoms before they fell. Deepwood could be the fourth to rise."},
	30: {"villager_id": "hilda_forge",     "villager_name": "Hilda Emberhand",         "stat_name": "Forgemaster",     "stat_value": 6, "role_key": "Blacksmith",   "role_title": "Forgemaster",     "sex": "Female", "backstory": "I forged blades for a royal guard that no longer exists. My hammer doesn't care."},
	35: {"villager_id": "alric_ledger",    "villager_name": "Alric Ledger",            "stat_name": "Treasurer",       "stat_value": 6, "role_key": "Bank",         "role_title": "Treasurer",       "sex": "Male",   "backstory": "Gold outlasts kings. Let me steward Deepwood's and it will never starve or fall unarmed."},
	40: {"villager_id": "vesna_root",      "villager_name": "Doctor Vesna Root",       "stat_name": "Chief Physician", "stat_value": 6, "role_key": "Hospital",     "role_title": "Chief Physician", "sex": "Female", "backstory": "I closed the eyes of half a city. Let me open a ward instead, and save the next one."},
	45: {"villager_id": "ollin_quill",     "villager_name": "Master Ollin Quill",      "stat_name": "Principal",       "stat_value": 6, "role_key": "School",       "role_title": "Principal",       "sex": "Male",   "backstory": "Knowledge was the first thing the dark burned. I mean to teach it back into the world."},
	50: {"villager_id": "ada_vell",        "villager_name": "Mistress Ada Vell",       "stat_name": "Principal",       "stat_value": 6, "role_key": "School",       "role_title": "Principal",       "sex": "Female", "backstory": "Give me your children and a decade, and I'll give you a Deepwood that never needs rescuing again."},
	55: {"villager_id": "garrick_stone",   "villager_name": "Garrick Stonehand",       "stat_name": "Master Builder",  "stat_value": 7, "role_key": "Builderhouse", "role_title": "Master Builder",  "sex": "Male",   "backstory": "I raised the walls that held for a hundred years. They fell anyway. I'll build better."},
	60: {"villager_id": "tomas_beam",      "villager_name": "Tomas Beam",              "stat_name": "Foreman",         "stat_value": 6, "role_key": "Builderhouse", "role_title": "Foreman",         "sex": "Male",   "backstory": "Give me a crew and a sunrise and I'll have a ruin standing again by dark."},
	65: {"villager_id": "korrin_vale",     "villager_name": "Warchief Korrin Vale",    "stat_name": "Warchief",        "stat_value": 7, "role_key": "Barracks",     "role_title": "Warchief",        "sex": "Female", "backstory": "I never lost a shield-wall I stood in. I only ran out of people to stand beside me."},
	70: {"villager_id": "callan_marshal",  "villager_name": "Ser Callan, the Last Marshal", "stat_name": "Warchief",  "stat_value": 8, "role_key": "Barracks",     "role_title": "Warchief",        "sex": "Male",   "backstory": "I held the last wall while the cities burned. Give me a banner to raise again."},
	75: {"villager_id": "wrenna_sooth",    "villager_name": "Wrenna Sootheye",         "stat_name": "Lead Researcher", "stat_value": 7, "role_key": "Science Lab",  "role_title": "Lead Researcher", "sex": "Female", "backstory": "I saw the pattern in the calamity before anyone. No one listened. In a lab, they'll have to."},
	80: {"villager_id": "ipsen_crole",     "villager_name": "Doctor Ipsen Crole",      "stat_name": "Lead Researcher", "stat_value": 7, "role_key": "Science Lab",  "role_title": "Lead Researcher", "sex": "Male",   "backstory": "The old world's machines still whisper to me. Let me make them speak for Deepwood."},
	85: {"villager_id": "yorwen_archivist","villager_name": "Yorwen the Archivist",    "stat_name": "Lead Researcher", "stat_value": 8, "role_key": "Science Lab",  "role_title": "Lead Researcher", "sex": "Female", "backstory": "I remember the Age of Monarchs, when no living soul else does. That memory is worth more than you know."},
	90: {"villager_id": "sable_archmagus", "villager_name": "Sable the Archmagus",     "stat_name": "Lead Researcher", "stat_value": 8, "role_key": "Science Lab",  "role_title": "Lead Researcher", "sex": "Female", "backstory": "I armed a kingdom's mages once. I can put fire in Deepwood's hands, if you free me from this dark."},
	95: {"villager_id": "alaric_thorne",   "villager_name": "Chancellor Alaric Thorne","stat_name": "Chancellor",      "stat_value": 9, "role_key": "Government",   "role_title": "Chancellor",      "sex": "Male",   "backstory": "I governed a realm that no longer exists. Let me spend what's left of my life governing one that might."},
}

static func figure_for_level(level: int) -> Dictionary:
	return IMPORTANT_FIGURES.get(level, {})

static func get_def(villager_id: String) -> Dictionary:
	return QUEST_DEFS.get(villager_id, {})

static func has_quest(villager_id: String) -> bool:
	return QUEST_DEFS.has(villager_id)

# The goal line ("Bring 4x Wild Herb", "Slay 15 foes", ...). One source of truth
# for the hover panel and any future quest log.
static func objective_text(def: Dictionary) -> String:
	match str(def.get("kind", "")):
		"gather":
			return "Bring %dx %s" % [int(def.get("count", 1)), Inventory.get_display_name(str(def.get("key", "")))]
		"slay":
			return "Slay %d foes" % int(def.get("count", 1))
		"reach_level":
			return "Reach dungeon Lv %d" % int(def.get("count", 1))
		"reunite":
			return "Rescue their kin"
	return ""

# Short progress readout for the hover panel, e.g. "7/15". gather reads the live
# inventory (progress isn't event-tracked for it); the rest use quest_progress.
static func progress_text(def: Dictionary, villager: Dictionary, player: Node) -> String:
	var count = int(def.get("count", 1))
	var have = 0
	if str(def.get("kind", "")) == "gather":
		if player and "inventory" in player and player.inventory:
			have = player.inventory.get_count(str(def.get("key", "")))
	else:
		have = int(villager.get("quest_progress", 0))
	return "%d/%d" % [min(have, count), count]
