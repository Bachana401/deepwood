class_name Inventory
extends RefCounted

# Shared item catalog -- every item type in the game (currency included) is
# defined here so both the player's inventory and any chest's inventory read
# from the same source. gold/silver/bronze are independent items with no
# fixed conversion rate between them -- only coin_gold drives the shop,
# death-drop, and passive income (see player.gd's currency property). Future
# gear/skill-material items get added here too, not as special cases elsewhere.
# Every item declares a "category": currency / material / armor / relic /
# weapon. armor & relic items carry an "equip_effect" dict (stat bonuses
# folded into GameState.get_bonus_total once equipped); armor also has a
# "slot" (helmet/chest/pants). "weapon" items here are the classless
# "Excellent" weapons (excellent=true) -- equipped via the gear panel and
# used on key 5, they trade skill-tree stat scaling for a one-of-a-kind
# "unique_effect" (see player.gd). The base sword/spear/bow/wand are NOT
# items -- they stay the purchasable 1-4 kit.
const ITEM_DEFS = {
	"coin_gold": {"name": "Gold Coin", "category": "currency", "max_stack": 9999999, "color": Color(1.0, 0.85, 0.2, 1.0)},
	"coin_silver": {"name": "Silver Coin", "category": "currency", "max_stack": 999, "color": Color(0.78, 0.8, 0.84, 1.0)},
	"coin_bronze": {"name": "Bronze Coin", "category": "currency", "max_stack": 999, "color": Color(0.72, 0.45, 0.22, 1.0)},
	# Skill-tree materials, dropped rarely in the dungeon by level bracket
	# (see dungeon_interior.gd) -- their names stay hidden ("Unknown
	# Substance") until researched at the Science Lab, see
	# GameState.researched_materials and get_display_name() below.
	"slime": {"name": "Slime", "category": "material", "max_stack": 99, "color": Color(0.35, 0.75, 0.35, 1.0), "is_material": true},
	"iron_shard": {"name": "Iron Shard", "category": "material", "max_stack": 99, "color": Color(0.6, 0.62, 0.68, 1.0), "is_material": true},
	"ember_crystal": {"name": "Ember Crystal", "category": "material", "max_stack": 99, "color": Color(0.95, 0.45, 0.15, 1.0), "is_material": true},
	"void_essence": {"name": "Void Essence", "category": "material", "max_stack": 99, "color": Color(0.4, 0.2, 0.6, 1.0), "is_material": true},
	"ancient_relic": {"name": "Ancient Relic", "category": "material", "max_stack": 99, "color": Color(0.85, 0.75, 0.4, 1.0), "is_material": true},
	# --- Construction materials: gathered from enemies (low drop rate) and used
	# to repair ruined village buildings (see building.gd). Plainly named, NOT
	# research-gated like the skill-tree substances above (no "is_material").
	"wood": {"name": "Wood", "category": "material", "max_stack": 99, "color": Color(0.52, 0.34, 0.18, 1.0), "is_construction": true},
	"stone": {"name": "Stone", "category": "material", "max_stack": 99, "color": Color(0.6, 0.6, 0.63, 1.0), "is_construction": true},
	"resin": {"name": "Resin", "category": "material", "max_stack": 99, "color": Color(0.88, 0.62, 0.22, 1.0), "is_construction": true},
	# --- Armor (the "Leather" set; dungeon loot will add more later) ---
	"helm_leather": {"name": "Leather Helm", "category": "armor", "slot": "helmet", "set": "leather", "max_stack": 1, "color": Color(0.55, 0.4, 0.25, 1.0), "equip_effect": {"max_health": 15.0}},
	"armor_leather": {"name": "Leather Vest", "category": "armor", "slot": "chest", "set": "leather", "max_stack": 1, "color": Color(0.5, 0.36, 0.22, 1.0), "equip_effect": {"max_health": 25.0}},
	"pants_leather": {"name": "Leather Pants", "category": "armor", "slot": "pants", "set": "leather", "max_stack": 1, "color": Color(0.45, 0.32, 0.2, 1.0), "equip_effect": {"max_health": 10.0, "move_speed": 0.04}},
	# --- Class armor sets. Each one leans into a class's skill tree (Bulwark =
	# Sword's Might/Endurance/Frenzy, Windstalker = Archer's Precision/Agility/
	# Plunder, Runeweave = Mage's Spellcraft/Vitality + the mana pool). Wearing
	# all 3 pieces grants the set bonus; ALSO wielding the set's weapon stacks
	# the greater full_bonus on top (see SET_DEFS + GameState set logic). ---
	"helm_bulwark": {"name": "Bulwark Warhelm", "category": "armor", "slot": "helmet", "set": "bulwark", "max_stack": 1, "color": Color(0.66, 0.3, 0.2, 1.0), "equip_effect": {"max_health": 25.0, "melee_damage": 0.05}},
	"armor_bulwark": {"name": "Bulwark Breastplate", "category": "armor", "slot": "chest", "set": "bulwark", "max_stack": 1, "color": Color(0.58, 0.26, 0.17, 1.0), "equip_effect": {"max_health": 40.0}},
	"pants_bulwark": {"name": "Bulwark Greaves", "category": "armor", "slot": "pants", "set": "bulwark", "max_stack": 1, "color": Color(0.5, 0.23, 0.15, 1.0), "equip_effect": {"max_health": 20.0, "melee_cooldown": 0.05}},
	"helm_windstalker": {"name": "Windstalker Hood", "category": "armor", "slot": "helmet", "set": "windstalker", "max_stack": 1, "color": Color(0.3, 0.62, 0.32, 1.0), "equip_effect": {"bow_damage": 0.08}},
	"armor_windstalker": {"name": "Windstalker Cloak", "category": "armor", "slot": "chest", "set": "windstalker", "max_stack": 1, "color": Color(0.26, 0.55, 0.28, 1.0), "equip_effect": {"max_health": 10.0, "move_speed": 0.06}},
	"pants_windstalker": {"name": "Windstalker Striders", "category": "armor", "slot": "pants", "set": "windstalker", "max_stack": 1, "color": Color(0.22, 0.48, 0.25, 1.0), "equip_effect": {"move_speed": 0.05, "bow_cooldown": 0.05}},
	"helm_runeweave": {"name": "Runeweave Circlet", "category": "armor", "slot": "helmet", "set": "runeweave", "max_stack": 1, "color": Color(0.55, 0.4, 0.88, 1.0), "equip_effect": {"max_mana": 20.0, "xp_gain": 0.08}},
	"armor_runeweave": {"name": "Runeweave Robe", "category": "armor", "slot": "chest", "set": "runeweave", "max_stack": 1, "color": Color(0.48, 0.34, 0.8, 1.0), "equip_effect": {"max_mana": 25.0, "max_health": 15.0}},
	"pants_runeweave": {"name": "Runeweave Leggings", "category": "armor", "slot": "pants", "set": "runeweave", "max_stack": 1, "color": Color(0.42, 0.3, 0.72, 1.0), "equip_effect": {"max_mana": 15.0, "wand_cooldown": 0.06}},
	# --- Relics ---
	"relic_vigor": {"name": "Relic of Vigor", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.85, 0.25, 0.3, 1.0), "equip_effect": {"max_health": 30.0}},
	"relic_swiftness": {"name": "Relic of Swiftness", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.3, 0.8, 0.85, 1.0), "equip_effect": {"move_speed": 0.10}},
	"relic_greed": {"name": "Relic of Greed", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.9, 0.75, 0.2, 1.0), "equip_effect": {"gold_gain": 0.20}},
	"relic_wisdom": {"name": "Relic of Wisdom", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.5, 0.55, 0.9, 1.0), "equip_effect": {"xp_gain": 0.20}},
	# Class-aligned relics (one per tree) + the mana wellspring.
	"relic_berserker": {"name": "Relic of the Berserker", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.8, 0.2, 0.12, 1.0), "equip_effect": {"melee_damage": 0.10, "melee_cooldown": 0.05}},
	"relic_hawk": {"name": "Relic of the Hawk", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.35, 0.7, 0.3, 1.0), "equip_effect": {"bow_damage": 0.10, "bow_cooldown": 0.05}},
	"relic_archon": {"name": "Relic of the Archon", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.6, 0.4, 0.95, 1.0), "equip_effect": {"wand_cooldown": 0.08, "max_mana": 20.0}},
	"relic_wellspring": {"name": "Relic of the Wellspring", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.25, 0.55, 0.95, 1.0), "equip_effect": {"max_mana": 25.0, "mana_regen": 0.5}},
	# Gathering-exclusive relics: never drop in the dungeon -- rare finds while
	# mining rocks (Mountain) or felling trees (Sylvan). See harvest_node.gd.
	"relic_mountain": {"name": "Heart of the Mountain", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.55, 0.5, 0.6, 1.0), "equip_effect": {"max_health": 30.0, "gold_gain": 0.10}},
	"relic_sylvan": {"name": "Sylvan Charm", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.4, 0.75, 0.4, 1.0), "equip_effect": {"move_speed": 0.08, "xp_gain": 0.10}},
	# Movement/utility relics with boolean-flag effects (flight, fall_immunity):
	# the value is just a 1.0 marker read via GameState.get_bonus_total > 0 in
	# player.gd. Aetherwing grants FLIGHT (hold Space -- 10s budget) and also
	# negates fall damage; the Featherfall Charm only negates fall damage.
	"relic_wings": {"name": "Aetherwing", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.85, 0.9, 1.0, 1.0), "equip_effect": {"flight": 1.0, "fall_immunity": 1.0, "move_speed": 0.05}},
	"relic_feather": {"name": "Featherfall Charm", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.9, 0.95, 0.85, 1.0), "equip_effect": {"fall_immunity": 1.0, "max_health": 10.0}},
	# --- The Wukong runes (2026-07-28): relic-runes whose flags player.gd reads
	# (sanctuary ring / stone save / staff mastery). Marker-value effects, same
	# convention as flight and fall_immunity above. ---
	"rune_sanctuary": {"name": "Circle of Sanctuary", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.6, 0.85, 1.0, 1.0), "equip_effect": {"sanctuary": 1.0, "max_health": 15.0}, "relic_desc": "Stand truly still for a second and a ward ring rises: enemy shots DIE at its edge. One step breaks it."},
	"rune_stoneguise": {"name": "Stone Guise", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.66, 0.63, 0.58, 1.0), "equip_effect": {"stone_guise": 1.0, "damage_reduction": 0.03}, "relic_desc": "Once per floor, the killing blow lands on STONE instead: you stand as a statue for 1.5s, untouchable, at 1 HP."},
	"rune_riddlestaff": {"name": "The Riddle Staff", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.95, 0.8, 0.35, 1.0), "equip_effect": {"staff_mastery": 1.0}, "relic_desc": "For staff-wielders: the combo holds a beat longer (a FOURTH stage of reach) and the pillar slam falls a quarter harder."},
	# --- OP relics. Some are pure stat gods; others carry a "relic_power" -- a
	# TRIGGERED mechanic the player reads (see player.has_relic_power): revive on
	# death, reflect damage, auto-shield, lifesteal, low-HP damage ramp. ---
	"relic_godheart": {"name": "Godheart", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.92, 0.32, 0.38, 1.0), "equip_effect": {"max_health": 150.0, "max_mana": 60.0}},
	"relic_warlord": {"name": "Sigil of the Warlord", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.92, 0.5, 0.2, 1.0), "equip_effect": {"melee_damage": 0.25, "bow_damage": 0.25, "wand_damage": 0.25}},
	"relic_fortune": {"name": "Crown of Fortune", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.95, 0.8, 0.25, 1.0), "equip_effect": {"gold_gain": 0.60, "xp_gain": 0.60}},
	"relic_celerity": {"name": "Idol of Celerity", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.4, 0.9, 0.9, 1.0), "equip_effect": {"move_speed": 0.25, "melee_cooldown": 0.15, "bow_cooldown": 0.15, "wand_cooldown": 0.15}},
	"relic_phoenix": {"name": "Phoenix Heart", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(1.0, 0.5, 0.15, 1.0), "equip_effect": {"max_health": 40.0}, "relic_power": "phoenix", "relic_desc": "Cheat death: revive at 50% HP once every 45s."},
	"relic_thorns": {"name": "Thornmail", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.72, 0.35, 0.3, 1.0), "equip_effect": {"max_health": 50.0}, "relic_power": "thorns", "relic_value": 0.4, "relic_desc": "Reflect 40% of damage taken to all nearby enemies."},
	"relic_aegis": {"name": "Aegis Ward", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.6, 0.8, 1.0, 1.0), "equip_effect": {"max_health": 60.0}, "relic_power": "aegis", "relic_desc": "A shield fully blocks one hit every 6s."},
	"relic_vampire": {"name": "Vampire Lord's Signet", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.72, 0.1, 0.22, 1.0), "equip_effect": {"max_health": 30.0}, "relic_power": "omnivamp", "relic_value": 0.25, "relic_desc": "Heal for 25% of the melee damage you deal."},
	"relic_juggernaut": {"name": "Juggernaut Idol", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.6, 0.15, 0.15, 1.0), "equip_effect": {"max_health": 40.0}, "relic_power": "berserk", "relic_value": 0.5, "relic_desc": "The lower your HP, the more damage -- up to +50% near death."},
	"relic_blink": {"name": "Shadowstep Sigil", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.5, 0.4, 0.82, 1.0), "equip_effect": {"move_speed": 0.05}, "relic_power": "blink", "relic_desc": "Press T to blink-dash a short distance with a brief dodge of invulnerability."},
	# on-kill / defensive / economy relics
	"relic_reaper": {"name": "Reaper's Toll", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.35, 0.5, 0.4, 1.0), "equip_effect": {"max_health": 20.0}, "relic_power": "reaper", "relic_desc": "Every kill restores 8 HP and 5 Mana."},
	"relic_ward": {"name": "Wardstone", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.6, 0.7, 0.9, 1.0), "equip_effect": {"max_health": 30.0, "status_resistance": 0.6}, "relic_desc": "Shrugs off 60% of the duration of enemy slows and hexes."},
	"relic_steward": {"name": "Steward's Chain", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.85, 0.72, 0.35, 1.0), "equip_effect": {"gold_gain": 0.4, "xp_gain": 0.4, "max_health": 20.0}, "relic_desc": "The village prospers around you: +40% gold and XP."},
	# --- Creative relics (WEAPONS.md Ã‚Â§6): a mechanic, not a flat stat. ---
	"relic_gorgon": {"name": "Gorgon's Gaze", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.55, 0.6, 0.5, 1.0), "equip_effect": {"max_health": 25.0}, "relic_power": "petrify", "relic_value": 3.0, "relic_desc": "Your hits turn the struck foe to STONE for 3s -- it can't act and takes +50% damage. Long cooldown; apex/undying bosses resist."},
	# --- Gloves & Boots (the two new armor slots). Standalone pieces across
	# grades so the slots have real content to chase, plus a real "defense"
	# axis (damage_reduction, a fraction capped at 75% in player.take_damage)
	# and the game's crit stats. ---
	"gloves_leather": {"name": "Leather Gloves", "category": "armor", "slot": "gloves", "max_stack": 1, "color": Color(0.5, 0.36, 0.22, 1.0), "equip_effect": {"max_health": 8.0}},
	"gloves_iron": {"name": "Ironclad Gauntlets", "category": "armor", "slot": "gloves", "max_stack": 1, "color": Color(0.6, 0.62, 0.68, 1.0), "equip_effect": {"max_health": 15.0, "damage_reduction": 0.05}},
	"gloves_assassin": {"name": "Assassin's Grips", "category": "armor", "slot": "gloves", "max_stack": 1, "color": Color(0.35, 0.3, 0.4, 1.0), "equip_effect": {"crit_chance": 0.10, "crit_damage": 0.15}},
	"gloves_titan": {"name": "Titanfell Fists", "category": "armor", "slot": "gloves", "max_stack": 1, "color": Color(0.75, 0.4, 0.25, 1.0), "equip_effect": {"max_health": 45.0, "melee_damage": 0.12, "damage_reduction": 0.06}},
	"boots_leather": {"name": "Leather Boots", "category": "armor", "slot": "boots", "max_stack": 1, "color": Color(0.45, 0.32, 0.2, 1.0), "equip_effect": {"move_speed": 0.05}},
	"boots_swift": {"name": "Swift Treads", "category": "armor", "slot": "boots", "max_stack": 1, "color": Color(0.35, 0.7, 0.6, 1.0), "equip_effect": {"move_speed": 0.10, "damage_reduction": 0.03}},
	"boots_storm": {"name": "Stormrunner Boots", "category": "armor", "slot": "boots", "max_stack": 1, "color": Color(0.5, 0.6, 0.9, 1.0), "equip_effect": {"move_speed": 0.15, "bow_cooldown": 0.05}},
	"boots_titan": {"name": "Titanfell Sabatons", "category": "armor", "slot": "boots", "max_stack": 1, "color": Color(0.75, 0.4, 0.25, 1.0), "equip_effect": {"max_health": 35.0, "move_speed": 0.10, "damage_reduction": 0.06}},
	# --- Ranger's Leathers: a RARE mid-tier set filling the gap between Leather
	# (uncommon) and the Epic class sets. Helmet/chest/pants. ---
	"helm_ranger": {"name": "Ranger's Hood", "category": "armor", "slot": "helmet", "set": "ranger", "max_stack": 1, "color": Color(0.36, 0.5, 0.34, 1.0), "equip_effect": {"max_health": 20.0, "move_speed": 0.03}},
	"armor_ranger": {"name": "Ranger's Jerkin", "category": "armor", "slot": "chest", "set": "ranger", "max_stack": 1, "color": Color(0.32, 0.46, 0.3, 1.0), "equip_effect": {"max_health": 30.0, "damage_reduction": 0.05}},
	"pants_ranger": {"name": "Ranger's Trousers", "category": "armor", "slot": "pants", "set": "ranger", "max_stack": 1, "color": Color(0.3, 0.42, 0.28, 1.0), "equip_effect": {"max_health": 18.0, "move_speed": 0.04}},
	# --- Dragonscale: a MYTHIC 5-slot set (helmet/chest/pants/gloves/boots) --
	# the endgame armour chase, with partial and full bonuses. ---
	"helm_dragon": {"name": "Dragonscale Helm", "category": "armor", "slot": "helmet", "set": "dragonscale", "max_stack": 1, "color": Color(0.7, 0.2, 0.24, 1.0), "equip_effect": {"max_health": 45.0, "damage_reduction": 0.06}},
	"armor_dragon": {"name": "Dragonscale Cuirass", "category": "armor", "slot": "chest", "set": "dragonscale", "max_stack": 1, "color": Color(0.62, 0.16, 0.2, 1.0), "equip_effect": {"max_health": 70.0, "damage_reduction": 0.08}},
	"pants_dragon": {"name": "Dragonscale Greaves", "category": "armor", "slot": "pants", "set": "dragonscale", "max_stack": 1, "color": Color(0.55, 0.14, 0.18, 1.0), "equip_effect": {"max_health": 45.0, "melee_damage": 0.08}},
	"gloves_dragon": {"name": "Dragonscale Gauntlets", "category": "armor", "slot": "gloves", "set": "dragonscale", "max_stack": 1, "color": Color(0.68, 0.2, 0.22, 1.0), "equip_effect": {"crit_chance": 0.08, "crit_damage": 0.20}},
	"boots_dragon": {"name": "Dragonscale Sabatons", "category": "armor", "slot": "boots", "set": "dragonscale", "max_stack": 1, "color": Color(0.6, 0.18, 0.2, 1.0), "equip_effect": {"max_health": 40.0, "move_speed": 0.10}},
	# --- Voidwalker Raiment: the ASCENDED set (2026-07-28) -- dodge, speed
	# and mana; armor for those who'd rather not be where the blow lands. ---
	"helm_void": {"name": "Voidwalker Cowl", "category": "armor", "slot": "helmet", "set": "voidwalker", "max_stack": 1, "color": Color(0.3, 0.85, 0.95, 1.0), "equip_effect": {"max_mana": 35.0, "dodge_chance": 0.04}},
	"armor_void": {"name": "Voidwalker Shroud", "category": "armor", "slot": "chest", "set": "voidwalker", "max_stack": 1, "color": Color(0.24, 0.75, 0.88, 1.0), "equip_effect": {"max_health": 55.0, "max_mana": 30.0, "damage_reduction": 0.05}},
	"pants_void": {"name": "Voidwalker Striders", "category": "armor", "slot": "pants", "set": "voidwalker", "max_stack": 1, "color": Color(0.2, 0.66, 0.8, 1.0), "equip_effect": {"move_speed": 0.10, "dodge_chance": 0.04}},
	# --- The Sovereign's Regalia: the MONARCH set -- the deepest floors dress
	# their conqueror. All damage, unbowed. ---
	"helm_regal": {"name": "Crown of the Deep Court", "category": "armor", "slot": "helmet", "set": "regalia", "max_stack": 1, "color": Color(1.0, 0.5, 0.15, 1.0), "equip_effect": {"max_health": 50.0, "crit_chance": 0.06}},
	"armor_regal": {"name": "Mantle of the Last King", "category": "armor", "slot": "chest", "set": "regalia", "max_stack": 1, "color": Color(0.92, 0.42, 0.12, 1.0), "equip_effect": {"max_health": 90.0, "damage_reduction": 0.08}},
	"pants_regal": {"name": "Greaves of the Long March", "category": "armor", "slot": "pants", "set": "regalia", "max_stack": 1, "color": Color(0.85, 0.36, 0.1, 1.0), "equip_effect": {"max_health": 50.0, "move_speed": 0.06, "melee_damage": 0.06}},
	# --- Consumables. Right-click in the bag to USE. "use_effect" says what it
	# does: heal_hp / heal_mana (instant), buff (a timed stat boost via
	# player.active_buffs), or reset_skills. HP & Mana potions are DROP-ONLY
	# (no recipe); food + the reset potion are CRAFTED (see CRAFT_RECIPES). ---
	"potion_health": {"name": "Health Potion", "category": "consumable", "max_stack": 20, "color": Color(0.85, 0.2, 0.25, 1.0), "use_effect": {"heal_hp": 90}, "use_desc": "Restore 90 HP."},
	"potion_mana": {"name": "Mana Potion", "category": "consumable", "max_stack": 20, "color": Color(0.25, 0.45, 0.9, 1.0), "use_effect": {"heal_mana": 70}, "use_desc": "Restore 70 Mana."},
	"food_stew": {"name": "Hearty Stew", "category": "consumable", "max_stack": 20, "color": Color(0.8, 0.55, 0.25, 1.0), "use_effect": {"buff": "move_speed", "value": 0.15, "duration": 45.0}, "use_desc": "+15% Move Speed for 45s."},
	"food_feast": {"name": "Warrior's Feast", "category": "consumable", "max_stack": 20, "color": Color(0.75, 0.35, 0.2, 1.0), "use_effect": {"buff": "all_damage", "value": 0.20, "duration": 45.0}, "use_desc": "+20% ALL weapon damage for 45s."},
	"food_sage": {"name": "Sage's Supper", "category": "consumable", "max_stack": 20, "color": Color(0.5, 0.7, 0.4, 1.0), "use_effect": {"buff": "crit_chance", "value": 0.20, "duration": 45.0}, "use_desc": "+20% Crit Chance for 45s."},
	"potion_reset": {"name": "Reset Potion", "category": "consumable", "max_stack": 5, "color": Color(0.7, 0.4, 0.9, 1.0), "use_effect": {"reset_skills": true}, "use_desc": "Refund all skill points and re-pick your class."},
	# NG+ (GAME_BIBLE 11): among the victory spoils. The world rewinds for a
	# new run; the player and everything they carry are immune. Two uses to
	# confirm -- a world should not end on a misclick.
	"relic_rewound_hour": {"name": "The Rewound Hour", "category": "consumable", "max_stack": 1, "color": Color(0.95, 0.85, 0.35, 1.0), "use_effect": {"rewind_world": true}, "use_desc": "Turn the hourglass: the whole world rewinds for a new run. You, your gear, and everything you carry are immune. Use twice within 5s to confirm."},
	# Crafting ingredients (gathered): Herb from chopping trees, Raw Meat from
	# enemies. Plainly named like construction mats.
	"herb": {"name": "Wild Herb", "category": "material", "max_stack": 99, "color": Color(0.4, 0.72, 0.35, 1.0), "is_ingredient": true},
	# 4.2a (decided delegated): crystallized despair, left behind when a
	# Sorrow-Crystal shatters. The Shrine burns 3 to cleanse a fallen villager
	# -- despair inverted into the reagent that undoes it.
	"sorrowshard": {"name": "Sorrowshard", "category": "material", "max_stack": 20, "color": Color(0.62, 0.55, 0.9, 1.0), "is_ingredient": true},
	"raw_meat": {"name": "Raw Meat", "category": "material", "max_stack": 99, "color": Color(0.82, 0.4, 0.42, 1.0), "is_ingredient": true},
	# --- FISHING (pillar 3, 2026-07-28): what the water owes ---
	"fish_silverfin": {"name": "Silverfin Perch", "category": "consumable", "max_stack": 20, "color": Color(0.75, 0.85, 0.95, 1.0), "use_effect": {"heal_hp": 20}, "use_desc": "A clean river fish. Restores 20 HP."},
	"fish_mudwhisker": {"name": "Mudwhisker", "category": "consumable", "max_stack": 20, "color": Color(0.6, 0.5, 0.35, 1.0), "use_effect": {"heal_hp": 12}, "use_desc": "Ugly, honest food. Restores 12 HP."},
	"fish_lanterneel": {"name": "Lantern Eel", "category": "consumable", "max_stack": 20, "color": Color(0.55, 0.9, 0.7, 1.0), "use_effect": {"heal_mana": 25}, "use_desc": "It glows all the way down. Restores 25 mana."},
	"fish_kingsjaw": {"name": "Kingsjaw", "category": "consumable", "max_stack": 10, "color": Color(0.95, 0.8, 0.35, 1.0), "use_effect": {"buff": "all_damage", "value": 3.0, "duration": 90.0}, "use_desc": "The dock's pride. +3 ALL damage for 90s."},
	"fish_palegulper": {"name": "Pale Gulper", "category": "consumable", "max_stack": 10, "color": Color(0.85, 0.9, 0.85, 1.0), "use_effect": {"buff": "damage_reduction", "value": 0.08, "duration": 90.0}, "use_desc": "It swallowed the dark and lived. +8% DR for 90s."},
	"junk_boot": {"name": "Somebody's Boot", "category": "misc", "max_stack": 5, "color": Color(0.4, 0.32, 0.24, 1.0)},
	# --- THE WEEPING HOUR (night event, 2026-07-28): what the sorrow leaves ---
	"tear_pale": {"name": "Pale Tear", "category": "material", "max_stack": 99, "color": Color(0.75, 0.85, 0.95, 1.0), "is_material": true},
	"potion_tears": {"name": "Teardraught", "category": "consumable", "max_stack": 10, "color": Color(0.7, 0.82, 0.95, 1.0), "use_effect": {"heal_mana": 90, "buff": "all_damage", "value": 0.15, "duration": 60.0}, "use_desc": "Grief, distilled. Restore 90 Mana and +15% ALL damage for 60s."},
	"relic_mourner": {"name": "The Mourner's Locket", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.72, 0.78, 0.9, 1.0), "equip_effect": {"max_health": 25.0, "melee_damage": 0.08, "bow_damage": 0.08, "wand_cooldown": 0.05}, "unique_desc": "Every survived Weeping Hour hangs inside it. Grief, carried long enough, becomes strength in any hand."},
	"crate_driftwood": {"name": "Driftwood Crate", "category": "consumable", "max_stack": 10, "color": Color(0.6, 0.48, 0.3, 1.0), "use_effect": {"open_crate": true}, "use_desc": "Roped shut and river-worn. Right-click to pry it open."},
	"crate_pearlbound": {"name": "Pearlbound Crate", "category": "consumable", "max_stack": 5, "color": Color(0.8, 0.85, 0.95, 1.0), "use_effect": {"open_crate": true}, "use_desc": "Banded in nacre. Right-click to pry it open."},
	"tool_rod_willow": {"name": "Willow Rod", "category": "weapon", "weapon_type": "melee", "tool_type": "rod", "rod_tier": 1, "max_stack": 1, "color": Color(0.55, 0.65, 0.4, 1.0),
		"weapon_stats": {"damage": 1, "cooldown": 0.8, "range_offset": 40, "area_size": Vector2(30, 20), "knockback_min": 0.0, "knockback_max": 0.0, "icon_size": Vector2(70, 5), "icon_color": Color(0.55, 0.65, 0.4), "icon_offset": 16.0},
		"unique_desc": "A bent branch and patience. Cast at water; strike when the line BITES."},
	"tool_rod_wyrmbone": {"name": "Wyrmbone Rod", "category": "weapon", "weapon_type": "melee", "tool_type": "rod", "rod_tier": 2, "max_stack": 1, "color": Color(0.85, 0.8, 0.7, 1.0),
		"weapon_stats": {"damage": 2, "cooldown": 0.7, "range_offset": 40, "area_size": Vector2(30, 20), "knockback_min": 0.0, "knockback_max": 0.0, "icon_size": Vector2(74, 5), "icon_color": Color(0.85, 0.8, 0.7), "icon_offset": 16.0},
		"unique_desc": "Ribbed like something that once swam. Faster bites, and the shy fish trust it."},
	"tool_rod_moonline": {"name": "Moonline", "category": "weapon", "weapon_type": "melee", "tool_type": "rod", "rod_tier": 3, "max_stack": 1, "color": Color(0.8, 0.85, 1.0, 1.0),
		"weapon_stats": {"damage": 3, "cooldown": 0.6, "range_offset": 40, "area_size": Vector2(30, 20), "knockback_min": 0.0, "knockback_max": 0.0, "icon_size": Vector2(78, 5), "icon_color": Color(0.8, 0.85, 1.0), "icon_offset": 16.0},
		"unique_desc": "The line is silver and the night is short. What the deep hides, this finds."},
	"relic_tidewalker": {"name": "Tidewalker's Knot", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.4, 0.75, 0.85, 1.0), "equip_effect": {"move_speed": 0.12, "max_health": 25.0}, "relic_desc": "Pulled from a pool no river feeds. The tide remembers whoever wears it."},
	"odd_glassfin": {"name": "The Glassfin", "category": "misc", "max_stack": 1, "color": Color(0.85, 0.95, 1.0, 1.0)},
	"odd_inkmaw": {"name": "The Inkmaw", "category": "misc", "max_stack": 1, "color": Color(0.25, 0.22, 0.35, 1.0)},
	"odd_bellsnail": {"name": "The Bell-Snail", "category": "misc", "max_stack": 1, "color": Color(0.8, 0.7, 0.45, 1.0)},
	"odd_twicefish": {"name": "The Twice-Caught Fish", "category": "misc", "max_stack": 1, "color": Color(0.7, 0.8, 0.75, 1.0)},
	"odd_sorrowcarp": {"name": "The Sorrow-Carp", "category": "misc", "max_stack": 1, "color": Color(0.55, 0.6, 0.8, 1.0)},

	# ============================================================================
	# HIDDEN EVENT-BOSS LOOT (2026-07-28). Twenty exclusive weapons (two per boss,
	# one drops on a 50/50 coin-flip) + a signature relic, a few armour pieces and
	# a trophy material per boss. These NEVER appear in the ordinary dungeon drop
	# pools (GEAR_* / WeaponRoster) -- the only way to earn them is to find the
	# secret that wakes their boss. See event_boss.gd for the registry + triggers.
	# Grade tracks the boss's difficulty: Medium=Epic, Hard=Legendary,
	# VeryHard=Mythic, Expert=Ascended/Monarch. Every mechanic here is one already
	# proven in perform_attack / apply_excellent_effect (no new plumbing).
	# ---- MEDIUM (Epic) ----
	"evt_ledger": {"name": "Ledger's Edge", "category": "weapon", "weapon_type": "melee", "max_stack": 1, "color": Color(0.92, 0.8, 0.32, 1.0),
		"weapon_stats": {"damage": 17, "cooldown": 0.4, "range_offset": 46, "area_size": Vector2(60, 36), "knockback_min": 30.0, "knockback_max": 62.0, "icon_size": Vector2(54, 12), "icon_color": Color(0.92, 0.8, 0.32), "icon_offset": 20.0},
		"unique_effect": "gold_touch", "unique_value": 0.14,
		"unique_desc": "The Tallyman's own blade: every cut mints coin -- 14% of the damage dealt is paid back to you as gold."},
	"evt_coinbite": {"name": "Coinbite Crossbow", "category": "weapon", "weapon_type": "bow", "max_stack": 1, "color": Color(0.86, 0.72, 0.3, 1.0),
		"weapon_stats": {"damage": 15, "cooldown": 0.5, "range_offset": 90, "area_size": Vector2(110, 40), "knockback_min": 24.0, "knockback_max": 50.0, "icon_size": Vector2(15, 15), "icon_color": Color(0.86, 0.72, 0.3), "icon_offset": 18.0},
		"special": {"type": "multi_shot", "count": 2, "spread_deg": 7.0},
		"unique_desc": "Fires a biting pair of coin-tipped bolts with every pull of the string."},
	"evt_hoarfrost": {"name": "Hoarfrost Pick", "category": "weapon", "weapon_type": "melee", "max_stack": 1, "color": Color(0.66, 0.86, 0.98, 1.0),
		"weapon_stats": {"damage": 20, "cooldown": 0.55, "range_offset": 46, "area_size": Vector2(62, 36), "knockback_min": 34.0, "knockback_max": 66.0, "icon_size": Vector2(50, 14), "icon_color": Color(0.66, 0.86, 0.98), "icon_offset": 20.0},
		"special": {"status": {"kind": "slow", "dur": 2.6, "mag": 0.5}},
		"unique_desc": "A pick of black ice: every blow leaves the struck foe chilled to the bone (slowed)."},
	"evt_rimeglass": {"name": "Rimeglass Wand", "category": "weapon", "weapon_type": "wand", "max_stack": 1, "color": Color(0.7, 0.9, 1.0, 1.0), "mana_cost": 9,
		"weapon_stats": {"damage": 0, "cooldown": 0.55, "range_offset": 30, "area_size": Vector2(10, 10), "knockback_min": 0.0, "knockback_max": 0.0, "icon_size": Vector2(46, 8), "icon_color": Color(0.7, 0.9, 1.0), "icon_offset": 20.0},
		"special": {"type": "frost_shard", "damage": 20, "speed": 660.0, "range": 560.0, "pierce": true, "status": {"kind": "slow", "dur": 3.2, "mag": 0.55}},
		"unique_desc": "Looses a shard of everfrost that skewers a whole line of foes and freezes them in place (slow)."},
	"evt_bramblewhip": {"name": "Bramblewhip", "category": "weapon", "weapon_type": "melee", "max_stack": 1, "color": Color(0.42, 0.6, 0.3, 1.0),
		"weapon_stats": {"damage": 15, "cooldown": 0.85, "range_offset": 44, "area_size": Vector2(56, 34), "knockback_min": 24.0, "knockback_max": 48.0, "icon_size": Vector2(56, 10), "icon_color": Color(0.42, 0.6, 0.3), "icon_offset": 20.0},
		"special": {"type": "lash", "damage": 15, "speed": 560.0, "range": 340.0, "status": {"kind": "poison", "dur": 4.0, "mag": 6.0}},
		"unique_desc": "A living, thorned vine that weaves out through everything in its lane -- and rakes it all again, envenomed, on the way back."},
	"evt_thornvolley": {"name": "Thornvolley Bow", "category": "weapon", "weapon_type": "bow", "max_stack": 1, "color": Color(0.4, 0.56, 0.32, 1.0),
		"weapon_stats": {"damage": 12, "cooldown": 0.58, "range_offset": 90, "area_size": Vector2(110, 40), "knockback_min": 22.0, "knockback_max": 44.0, "icon_size": Vector2(15, 15), "icon_color": Color(0.4, 0.56, 0.32), "icon_offset": 18.0},
		"special": {"type": "multi_shot", "count": 3, "spread_deg": 11.0},
		"unique_desc": "Looses a fan of three barbed thorn-shafts with every draw."},
	# ---- HARD (Legendary) ----
	"evt_tiderender": {"name": "Tiderender", "category": "weapon", "weapon_type": "spear", "max_stack": 1, "color": Color(0.28, 0.62, 0.72, 1.0),
		"weapon_stats": {"damage": 16, "cooldown": 1.0, "range_offset": 55, "area_size": Vector2(70, 40), "knockback_min": 45.0, "knockback_max": 78.0, "icon_size": Vector2(112, 8), "icon_color": Color(0.28, 0.62, 0.72), "icon_offset": 16.0},
		"special": {"type": "javelin_volley", "count": 3, "spread_deg": 9.0, "damage": 18, "speed": 720.0, "range": 540.0},
		"unique_desc": "Instead of a thrust it hurls three spears of black water at once -- each pierces clean through the tide of foes."},
	"evt_deepcaller": {"name": "Deepcaller Conch", "category": "weapon", "weapon_type": "wand", "max_stack": 1, "color": Color(0.35, 0.55, 0.85, 1.0), "mana_cost": 13,
		"weapon_stats": {"damage": 0, "cooldown": 0.8, "range_offset": 30, "area_size": Vector2(10, 10), "knockback_min": 0.0, "knockback_max": 0.0, "icon_size": Vector2(48, 8), "icon_color": Color(0.35, 0.55, 0.85), "icon_offset": 20.0},
		"special": {"type": "cluster", "damage": 22, "speed": 540.0, "range": 440.0, "shards": 6},
		"unique_desc": "The call carries a mote of the drowned deep that bursts into a chorus of six biting wisps."},
	"evt_pyreblade": {"name": "Pyreblade", "category": "weapon", "weapon_type": "melee", "max_stack": 1, "color": Color(1.0, 0.55, 0.2, 1.0),
		"weapon_stats": {"damage": 26, "cooldown": 0.5, "range_offset": 48, "area_size": Vector2(64, 38), "knockback_min": 34.0, "knockback_max": 68.0, "icon_size": Vector2(58, 13), "icon_color": Color(1.0, 0.55, 0.2), "icon_offset": 20.0},
		"special": {"type": "flying_slash", "damage": 20, "speed": 540.0, "range": 440.0, "status": {"kind": "burn", "dur": 4.0, "mag": 7.0}},
		"unique_desc": "Every swing hurls a crescent of fire that flies ahead -- and everything the blade or the flame touches BURNS."},
	"evt_emberking": {"name": "Emberking Recurve", "category": "weapon", "weapon_type": "bow", "max_stack": 1, "color": Color(0.95, 0.5, 0.22, 1.0),
		"weapon_stats": {"damage": 24, "cooldown": 0.5, "range_offset": 90, "area_size": Vector2(110, 40), "knockback_min": 26.0, "knockback_max": 52.0, "icon_size": Vector2(15, 15), "icon_color": Color(0.95, 0.5, 0.22), "icon_offset": 18.0},
		"special": {"type": "homing"},
		"unique_desc": "Its ember-fletched arrows bend mid-flight, hunting the nearest living thing on their own."},
	"evt_vigil": {"name": "Vigil Lance", "category": "weapon", "weapon_type": "spear", "max_stack": 1, "color": Color(0.7, 0.75, 0.9, 1.0),
		"weapon_stats": {"damage": 30, "cooldown": 0.95, "range_offset": 58, "area_size": Vector2(74, 42), "knockback_min": 55.0, "knockback_max": 92.0, "icon_size": Vector2(116, 9), "icon_color": Color(0.7, 0.75, 0.9), "icon_offset": 16.0},
		"special": {"type": "javelin_volley", "count": 2, "spread_deg": 6.0, "damage": 22, "speed": 760.0, "range": 560.0},
		"unique_desc": "The Warden's lance never sleeps: instead of a thrust it looses a twin of piercing light down the line -- both punch clean through."},
	"evt_wakeful": {"name": "Wakeful Wand", "category": "weapon", "weapon_type": "wand", "max_stack": 1, "color": Color(0.85, 0.85, 0.45, 1.0), "mana_cost": 11,
		"weapon_stats": {"damage": 0, "cooldown": 0.6, "range_offset": 30, "area_size": Vector2(10, 10), "knockback_min": 0.0, "knockback_max": 0.0, "icon_size": Vector2(48, 8), "icon_color": Color(0.85, 0.85, 0.45), "icon_offset": 20.0},
		"special": {"type": "ricochet", "damage": 22, "speed": 720.0, "range": 500.0, "bounces": 4},
		"unique_desc": "A restless bolt that refuses to settle: it leaps foe to foe up to four times before it sleeps."},
	# ---- VERY HARD (Mythic) ----
	"evt_scythe": {"name": "Mourner's Scythe", "category": "weapon", "weapon_type": "melee", "max_stack": 1, "color": Color(0.5, 0.55, 0.62, 1.0),
		"weapon_stats": {"damage": 30, "cooldown": 0.8, "range_offset": 54, "area_size": Vector2(78, 46), "knockback_min": 50.0, "knockback_max": 88.0, "icon_size": Vector2(62, 16), "icon_color": Color(0.5, 0.55, 0.62), "icon_offset": 20.0},
		"special": {"type": "cleave"},
		"unique_desc": "The reaper's own tool: so wide it cleaves through EVERY foe in the arc, not just the nearest."},
	"evt_wail": {"name": "Wail Wand", "category": "weapon", "weapon_type": "wand", "max_stack": 1, "color": Color(0.6, 0.55, 0.75, 1.0), "mana_cost": 15,
		"weapon_stats": {"damage": 0, "cooldown": 0.9, "range_offset": 30, "area_size": Vector2(10, 10), "knockback_min": 0.0, "knockback_max": 0.0, "icon_size": Vector2(50, 8), "icon_color": Color(0.6, 0.55, 0.75), "icon_offset": 20.0},
		"special": {"type": "lob", "damage": 34, "speed": 500.0, "range": 520.0, "aoe": 120.0},
		"unique_desc": "Casts a grief-wail in a mourning arc that BLOSSOMS into a wide keening blast where it lands."},
	"evt_pretender": {"name": "Pretender's Greatsword", "category": "weapon", "weapon_type": "melee", "max_stack": 1, "color": Color(0.8, 0.7, 0.35, 1.0),
		"weapon_stats": {"damage": 34, "cooldown": 0.6, "range_offset": 52, "area_size": Vector2(72, 44), "knockback_min": 55.0, "knockback_max": 95.0, "icon_size": Vector2(64, 15), "icon_color": Color(0.8, 0.7, 0.35), "icon_offset": 20.0},
		"unique_effect": "shockwave", "unique_value": 0.55, "unique_radius": 240.0,
		"unique_desc": "The false crown's blade: every blow slams a quake through everything within 240px for 55% of the damage."},
	"evt_usurper": {"name": "Usurper's Bow", "category": "weapon", "weapon_type": "bow", "max_stack": 1, "color": Color(0.72, 0.62, 0.35, 1.0),
		"weapon_stats": {"damage": 28, "cooldown": 0.52, "range_offset": 90, "area_size": Vector2(110, 40), "knockback_min": 28.0, "knockback_max": 54.0, "icon_size": Vector2(15, 15), "icon_color": Color(0.72, 0.62, 0.35), "icon_offset": 18.0},
		"special": {"type": "storm_shot", "count": 3, "homing": true},
		"unique_desc": "The pretender's aim: three crowned shafts that curve to hunt what would depose you."},
	"evt_houndsfang": {"name": "Houndsfang", "category": "weapon", "weapon_type": "melee", "max_stack": 1, "color": Color(0.32, 0.3, 0.4, 1.0),
		"weapon_stats": {"damage": 14, "cooldown": 0.26, "range_offset": 42, "area_size": Vector2(52, 32), "knockback_min": 18.0, "knockback_max": 38.0, "icon_size": Vector2(44, 11), "icon_color": Color(0.32, 0.3, 0.4), "icon_offset": 18.0},
		"unique_effect": "lifesteal", "unique_value": 0.18,
		"unique_desc": "The hound's tooth: a blur of quick cuts that feeds -- each blow returns 18% of its damage as health."},
	"evt_coursing": {"name": "Coursing Bow", "category": "weapon", "weapon_type": "bow", "max_stack": 1, "color": Color(0.4, 0.4, 0.5, 1.0),
		"weapon_stats": {"damage": 20, "cooldown": 0.46, "range_offset": 90, "area_size": Vector2(110, 40), "knockback_min": 24.0, "knockback_max": 48.0, "icon_size": Vector2(15, 15), "icon_color": Color(0.4, 0.4, 0.5), "icon_offset": 18.0},
		"special": {"type": "storm_shot", "count": 4, "homing": true},
		"unique_desc": "The coursing hunt made manifest: a homing pack of four shafts runs down everything that flees."},
	# ---- EXPERT (Ascended / Monarch) ----
	"evt_endbringer": {"name": "Endbringer", "category": "weapon", "weapon_type": "melee", "max_stack": 1, "color": Color(1.0, 0.9, 0.5, 1.0),
		"weapon_stats": {"damage": 44, "cooldown": 0.5, "range_offset": 54, "area_size": Vector2(76, 46), "knockback_min": 60.0, "knockback_max": 105.0, "icon_size": Vector2(66, 16), "icon_color": Color(1.0, 0.9, 0.5), "icon_offset": 20.0},
		"unique_effect": "execute", "unique_value": 0.22, "boss_bonus": 0.6,
		"unique_desc": "Nihil's blade, the last word: it DELETES any non-boss below 22% HP outright, and tears an extra 60% into bosses."},
	"evt_stareater": {"name": "Star-Eater", "category": "weapon", "weapon_type": "wand", "max_stack": 1, "color": Color(0.3, 0.95, 1.0, 1.0), "mana_cost": 26,
		"weapon_stats": {"damage": 0, "cooldown": 1.0, "range_offset": 30, "area_size": Vector2(10, 10), "knockback_min": 0.0, "knockback_max": 0.0, "icon_size": Vector2(52, 8), "icon_color": Color(0.3, 0.95, 1.0), "icon_offset": 20.0},
		"special": {"type": "nuke", "damage": 420},
		"unique_desc": "It opens a hungry star that DEVOURS every enemy on screen at once (scales with Wand DMG)."},

	# ---- Signature relics (one per boss; guaranteed on the kill) ----
	"relic_usurer": {"name": "Usurer's Signet", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.9, 0.78, 0.3, 1.0), "equip_effect": {"gold_gain": 0.35, "max_health": 20.0}, "relic_desc": "The Tallyman's ring: every coin the world owes you comes back larger (+35% gold)."},
	"relic_rimeheart": {"name": "Rimeheart", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.66, 0.86, 0.98, 1.0), "equip_effect": {"max_health": 35.0, "status_resistance": 0.4}, "relic_desc": "A heart of everfrost: enemy chills and hexes slide off you (-40% status duration)."},
	"relic_verdant": {"name": "Verdant Heart", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.42, 0.72, 0.36, 1.0), "equip_effect": {"max_health": 30.0}, "relic_power": "reaper", "relic_desc": "The Glutton's seed: every kill you reap feeds you back 8 HP and 5 Mana."},
	"relic_pearl": {"name": "Pearl of the Deep", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.5, 0.75, 0.9, 1.0), "equip_effect": {"max_mana": 30.0, "max_health": 30.0}, "relic_power": "aegis", "relic_desc": "A bubble of the drowned deep fully blocks one hit every 6s."},
	"relic_effigy": {"name": "Effigy Ash", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.85, 0.45, 0.2, 1.0), "equip_effect": {"max_health": 45.0}, "relic_power": "thorns", "relic_value": 0.4, "relic_desc": "The wicker king's spite: reflect 40% of the damage you take back onto everything near you as fire."},
	"relic_unblinking": {"name": "The Unblinking Eye", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.8, 0.82, 0.55, 1.0), "equip_effect": {"crit_chance": 0.1, "crit_damage": 0.25}, "relic_desc": "The Warden never sleeps, and neither do your eyes: +10% crit, +25% crit damage."},
	"relic_widow": {"name": "Widow's Locket", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.5, 0.42, 0.55, 1.0), "equip_effect": {"max_health": 40.0}, "relic_power": "omnivamp", "relic_value": 0.3, "relic_desc": "Grief made sustenance: heal for 30% of the melee damage you deal."},
	"relic_hollow": {"name": "The Hollow Crown", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.82, 0.72, 0.38, 1.0), "equip_effect": {"melee_damage": 0.16, "bow_damage": 0.16, "wand_damage": 0.16}, "relic_desc": "The pretender's due: +16% to ALL of your weapon damage, deserved or not."},
	"relic_hound": {"name": "Hound's Collar", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(0.34, 0.32, 0.42, 1.0), "equip_effect": {"move_speed": 0.12}, "relic_power": "berserk", "relic_value": 0.5, "relic_desc": "The cornered hunt bites hardest: the lower your HP, the more damage -- up to +50% near death."},
	"relic_lasthour": {"name": "Crown of the Last Hour", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(1.0, 0.9, 0.5, 1.0), "equip_effect": {"max_health": 90.0, "max_mana": 45.0}, "relic_power": "phoenix", "relic_desc": "Nihil's crown: cheat the last hour -- revive at 50% HP once every 45s -- and carry +90 HP, +45 Mana besides."},

	# ---- Signature armour pieces (the harder bosses) ----
	"armor_ember": {"name": "Cinderweave Vest", "category": "armor", "slot": "chest", "max_stack": 1, "color": Color(0.85, 0.42, 0.2, 1.0), "equip_effect": {"max_health": 55.0, "damage_reduction": 0.06, "melee_damage": 0.05}},
	"helm_mourn": {"name": "Mourner's Veil", "category": "armor", "slot": "helmet", "max_stack": 1, "color": Color(0.48, 0.44, 0.55, 1.0), "equip_effect": {"max_health": 45.0, "max_mana": 25.0, "crit_chance": 0.05}},
	"armor_unmade": {"name": "Shroud of the Unmade", "category": "armor", "slot": "chest", "max_stack": 1, "color": Color(0.3, 0.9, 0.98, 1.0), "equip_effect": {"max_health": 80.0, "max_mana": 35.0, "damage_reduction": 0.08, "dodge_chance": 0.05}},

	# ---- Trophy materials (guaranteed on the kill; is_ingredient so they read
	# their real name, never "Unknown Substance"). ----
	"mat_debtcoin": {"name": "Tarnished Debt-Coin", "category": "material", "max_stack": 20, "color": Color(0.72, 0.62, 0.28, 1.0), "is_ingredient": true},
	"mat_everfrost": {"name": "Everfrost Shard", "category": "material", "max_stack": 20, "color": Color(0.7, 0.9, 1.0, 1.0), "is_ingredient": true},
	"mat_heartwood": {"name": "Heartwood Seed", "category": "material", "max_stack": 20, "color": Color(0.45, 0.7, 0.35, 1.0), "is_ingredient": true},
	"mat_brine": {"name": "Black Brine-Pearl", "category": "material", "max_stack": 20, "color": Color(0.3, 0.5, 0.7, 1.0), "is_ingredient": true},
	"mat_pyreash": {"name": "Pyre Ash", "category": "material", "max_stack": 20, "color": Color(0.7, 0.4, 0.25, 1.0), "is_ingredient": true},
	"mat_vigilember": {"name": "Sleepless Ember", "category": "material", "max_stack": 20, "color": Color(0.85, 0.82, 0.5, 1.0), "is_ingredient": true},
	"mat_grieftear": {"name": "Grief Tear", "category": "material", "max_stack": 20, "color": Color(0.55, 0.5, 0.68, 1.0), "is_ingredient": true},
	"mat_crownshard": {"name": "Crown Shard", "category": "material", "max_stack": 20, "color": Color(0.8, 0.7, 0.38, 1.0), "is_ingredient": true},
	"mat_sableichor": {"name": "Sable Ichor", "category": "material", "max_stack": 20, "color": Color(0.3, 0.28, 0.36, 1.0), "is_ingredient": true},
	"mat_unmade": {"name": "Fragment of the Unmade", "category": "material", "max_stack": 20, "color": Color(0.35, 0.92, 1.0, 1.0), "is_ingredient": true},

	# ---- Re-summon tokens (2026-07-28): crafted from a fallen event boss's
	# trophy, each wakes THAT boss again on demand -- a way to farm the 50/50
	# weapon you missed. use_effect.summon_event names the event. Consumables so
	# player.use_item accepts them; recipes in CRAFT_RECIPES. ----
	"token_tallyman":    {"name": "Effigy of the Tallyman",    "category": "consumable", "max_stack": 10, "color": Color(0.9, 0.78, 0.32, 1.0),  "use_effect": {"summon_event": "tallyman"},     "use_desc": "Wake the Tallyman again, here and now."},
	"token_firstfrost":  {"name": "Effigy of the First Frost", "category": "consumable", "max_stack": 10, "color": Color(0.66, 0.86, 0.98, 1.0), "use_effect": {"summon_event": "first_frost"},  "use_desc": "Call the First Frost back into the cold."},
	"token_gluttonroot": {"name": "Effigy of the Glutton Root","category": "consumable", "max_stack": 10, "color": Color(0.42, 0.6, 0.3, 1.0),   "use_effect": {"summon_event": "glutton_root"}, "use_desc": "Rouse the Glutton Root from the soil."},
	"token_drowned":     {"name": "Effigy of the Drowned",     "category": "consumable", "max_stack": 10, "color": Color(0.3, 0.5, 0.7, 1.0),    "use_effect": {"summon_event": "drowned_chorus"},"use_desc": "Ring the sunken bell once more."},
	"token_effigyking":  {"name": "Effigy of the Fire King",   "category": "consumable", "max_stack": 10, "color": Color(0.85, 0.45, 0.2, 1.0),  "use_effect": {"summon_event": "effigy_king"},  "use_desc": "Feed the fire; the Effigy King answers."},
	"token_warden":      {"name": "Effigy of the Warden",      "category": "consumable", "max_stack": 10, "color": Color(0.7, 0.75, 0.9, 1.0),   "use_effect": {"summon_event": "sleepless_warden"},"use_desc": "The Sleepless Warden never truly left."},
	"token_griefeater":  {"name": "Effigy of Grief",           "category": "consumable", "max_stack": 10, "color": Color(0.5, 0.42, 0.55, 1.0),  "use_effect": {"summon_event": "grief_eater"},  "use_desc": "Offer a fresh sorrow; the Grief-Eater comes."},
	"token_hollowcrown": {"name": "Effigy of the Pretender",   "category": "consumable", "max_stack": 10, "color": Color(0.82, 0.72, 0.38, 1.0), "use_effect": {"summon_event": "hollow_crown"}, "use_desc": "Challenge the shadow throne again."},
	"token_sablehound":  {"name": "Effigy of the Hound",       "category": "consumable", "max_stack": 10, "color": Color(0.34, 0.32, 0.42, 1.0), "use_effect": {"summon_event": "sable_hound"},  "use_desc": "Whistle, and the Sable Hound hunts you."},
	"token_nihil":       {"name": "Effigy of the Last Hour",   "category": "consumable", "max_stack": 10, "color": Color(0.3, 0.95, 1.0, 1.0),   "use_effect": {"summon_event": "nihil"},        "use_desc": "Turn the last hour back to its beginning Ã¢â‚¬â€ Nihil returns."},

	# ---- The Duskmoon Effigy: Nihil's FIRST rite. Use it while the sun and moon
	# BOTH ride the sky (dawn/dusk) and, four seconds later, the Last Hour comes.
	# Used at any other time, nothing happens and it is not spent. Crafted from
	# three other bosses' trophies (frost, fire, grief) -- so the deep-secret is
	# soft-gated behind hunting the others first. ----
	"duskmoon_effigy": {"name": "Duskmoon Effigy", "category": "consumable", "max_stack": 5, "color": Color(0.5, 0.55, 0.85, 1.0),
		"use_effect": {"summon_event": "nihil", "eclipse": true, "delay": 4.0},
		"use_desc": "Use it while the sun and moon share the sky. Something will answer in four heartbeats."},
	# ---- The Hunter's Horn: the CAPSTONE. Forged only when you hold a trophy of
	# ALL TEN hidden bosses (a feat spanning many runs). Sounding it calls the
	# eleventh, the Master of the Hunt. ----
	"hunters_horn": {"name": "The Hunter's Horn", "category": "consumable", "max_stack": 1, "color": Color(1.0, 0.85, 0.4, 1.0),
		"use_effect": {"summon_event": "huntsman", "delay": 4.0},
		"use_desc": "Sound it, and the Master of the Hunt answers the ten deaths you dealt."},

	# ---- The eleventh boss's loot (the capstone drops) ----
	"evt_huntcrown": {"name": "The Huntsman's Crownblade", "category": "weapon", "weapon_type": "melee", "max_stack": 1, "color": Color(1.0, 0.88, 0.45, 1.0),
		"weapon_stats": {"damage": 48, "cooldown": 0.5, "range_offset": 54, "area_size": Vector2(78, 46), "knockback_min": 62.0, "knockback_max": 108.0, "icon_size": Vector2(66, 16), "icon_color": Color(1.0, 0.88, 0.45), "icon_offset": 20.0},
		"unique_effect": "shockwave", "unique_value": 0.6, "unique_radius": 260.0,
		"unique_desc": "The Master's own blade: every blow detonates a golden quake through everything within 260px for 60% of the damage."},
	"evt_huntbow": {"name": "The Huntsman's Longbow", "category": "weapon", "weapon_type": "bow", "max_stack": 1, "color": Color(1.0, 0.82, 0.4, 1.0),
		"weapon_stats": {"damage": 34, "cooldown": 0.48, "range_offset": 90, "area_size": Vector2(110, 40), "knockback_min": 28.0, "knockback_max": 56.0, "icon_size": Vector2(15, 15), "icon_color": Color(1.0, 0.82, 0.4), "icon_offset": 18.0},
		"special": {"type": "storm_shot", "count": 5, "homing": true},
		"unique_desc": "The Master never misses: five gold-fletched shafts that curve to run down all who flee."},
	"relic_huntmaster": {"name": "Crown of the Hunt", "category": "relic", "slot": "relic", "max_stack": 1, "color": Color(1.0, 0.85, 0.4, 1.0),
		"equip_effect": {"max_health": 80.0, "melee_damage": 0.12, "bow_damage": 0.12, "wand_damage": 0.12, "crit_chance": 0.08},
		"relic_power": "reaper", "relic_desc": "Master of the ten secrets: +12% ALL damage, +80 HP, +8% crit, and every kill mends 8 HP / 5 Mana."},
	"mat_huntsign": {"name": "Sigil of the Hunt", "category": "material", "max_stack": 20, "color": Color(1.0, 0.85, 0.4, 1.0), "is_ingredient": true},

	# --- Weapons. Every weapon is an inventory item now; you wield one by
	# selecting its inventory slot with the hotbar keys (1-9, 0). "weapon_type"
	# tells the player how it attacks: melee / spear / bow / wand. The Excellent
	# ones are just melee weapons that also carry a "unique_effect". ---
	"wpn_sword": {
		"name": "Sword", "category": "weapon", "weapon_type": "melee", "max_stack": 1, "color": Color(0.75, 0.75, 0.8, 1.0),
		"weapon_stats": {"damage": 9, "cooldown": 0.3, "range_offset": 46, "area_size": Vector2(60, 36), "knockback_min": 30.0, "knockback_max": 60.0, "icon_size": Vector2(52, 12), "icon_color": Color(0.75, 0.75, 0.8), "icon_offset": 20.0},
	},
	"wpn_spear": {
		"name": "Spear", "category": "weapon", "weapon_type": "spear", "max_stack": 1, "color": Color(0.55, 0.35, 0.15, 1.0),
		"weapon_stats": {"damage": 28, "cooldown": 0.9, "range_offset": 55, "area_size": Vector2(70, 40), "knockback_min": 60.0, "knockback_max": 90.0, "icon_size": Vector2(114, 8), "icon_color": Color(0.55, 0.35, 0.15), "icon_offset": 16.0},
	},
	"wpn_bow": {
		"name": "Bow", "category": "weapon", "weapon_type": "bow", "max_stack": 1, "color": Color(0.45, 0.28, 0.1, 1.0),
		"weapon_stats": {"damage": 17, "cooldown": 0.5, "range_offset": 90, "area_size": Vector2(110, 40), "knockback_min": 24.0, "knockback_max": 48.0, "icon_size": Vector2(14, 14), "icon_color": Color(0.45, 0.28, 0.1), "icon_offset": 18.0},
	},
	# ADMIN/TEST ONLY -- this screen-nuke deletes EVERY enemy incl. bosses
	# (cast_wand deals 999999). Not sold, not in the starter kit; kept only as a
	# dev tool alongside the Ruin Wand. The real mage screen-wipe is the
	# Runeweave Scepter (finite AoE), and Emberstaff/Icicle are the loot wands.
	"wpn_wand": {
		"name": "Magic Wand (Admin)", "category": "weapon", "weapon_type": "wand", "max_stack": 1, "color": Color(0.65, 0.2, 0.85, 1.0), "mana_cost": 30,
		"weapon_stats": {"damage": 0, "cooldown": 1.0, "range_offset": 30, "area_size": Vector2(10, 10), "knockback_min": 0.0, "knockback_max": 0.0, "icon_size": Vector2(46, 8), "icon_color": Color(0.65, 0.2, 0.85), "icon_offset": 20.0},
		"unique_desc": "ADMIN: obliterates every enemy on screen, bosses included.",
	},
	# --- Set weapons: the 4th piece of each class set. Wielding one while the
	# 3 armor pieces are worn stacks the set's full_bonus on top. ---
	"wpn_claymore": {
		"name": "Bulwark Claymore", "category": "weapon", "weapon_type": "melee", "set": "bulwark", "max_stack": 1, "color": Color(0.85, 0.45, 0.3, 1.0),
		"weapon_stats": {"damage": 18, "cooldown": 0.45, "range_offset": 50, "area_size": Vector2(68, 40), "knockback_min": 45.0, "knockback_max": 80.0, "icon_size": Vector2(62, 13), "icon_color": Color(0.85, 0.5, 0.35), "icon_offset": 20.0},
		"unique_effect": "shockwave", "unique_value": 0.35, "unique_radius": 180.0,
		"unique_desc": "The Bulwark's own weapon: every blow slams a quake through everything within 180px for 35% of the damage.",
	},
	"wpn_recurve": {
		"name": "Windstalker Recurve", "category": "weapon", "weapon_type": "bow", "set": "windstalker", "max_stack": 1, "color": Color(0.3, 0.6, 0.3, 1.0),
		"weapon_stats": {"damage": 22, "cooldown": 0.42, "range_offset": 90, "area_size": Vector2(110, 40), "knockback_min": 26.0, "knockback_max": 50.0, "icon_size": Vector2(15, 15), "icon_color": Color(0.3, 0.6, 0.3), "icon_offset": 18.0},
		"special": {"type": "twin_shot", "count": 2, "spread_deg": 6.0},
		"unique_desc": "The Windstalker's own bow: looses a tight pair of shafts with every draw.",
	},
	"wpn_scepter": {
		"name": "Runeweave Scepter", "category": "weapon", "weapon_type": "wand", "set": "runeweave", "max_stack": 1, "color": Color(0.52, 0.36, 0.92, 1.0), "mana_cost": 20,
		"weapon_stats": {"damage": 0, "cooldown": 0.8, "range_offset": 30, "area_size": Vector2(10, 10), "knockback_min": 0.0, "knockback_max": 0.0, "icon_size": Vector2(50, 8), "icon_color": Color(0.52, 0.36, 0.92), "icon_offset": 20.0},
		"special": {"type": "nuke", "damage": 253},
		"unique_desc": "A woven-rune blast that scorches EVERY enemy on screen at once (scales with Wand DMG).",
	},
	# --- Class variant weapons: each has a "special" attack handled by
	# player.gd (projectiles live in weapon_projectile.gd). They scale with
	# their class's skill tree exactly like the basic kit: melee/spear specials
	# with melee_damage, arrows with bow_damage, wand projectiles with the
	# Mage tree's wand_damage. Dungeon boss loot from L10 (dungeon_interior).
	"wpn_windcutter": {
		"name": "Windcutter", "category": "weapon", "weapon_type": "melee", "max_stack": 1, "color": Color(0.7, 0.92, 1.0, 1.0),
		"weapon_stats": {"damage": 13, "cooldown": 0.5, "range_offset": 46, "area_size": Vector2(60, 36), "knockback_min": 28.0, "knockback_max": 55.0, "icon_size": Vector2(52, 12), "icon_color": Color(0.7, 0.92, 1.0), "icon_offset": 20.0},
		"special": {"type": "flying_slash", "damage": 12, "speed": 520.0, "range": 420.0},
		"unique_desc": "Every swing also hurls a slash of wind that flies ahead, cutting through everyone in its path.",
	},
	"wpn_sunderer": {
		"name": "Sunderer", "category": "weapon", "weapon_type": "melee", "max_stack": 1, "color": Color(0.8, 0.5, 0.25, 1.0),
		"weapon_stats": {"damage": 23, "cooldown": 0.85, "range_offset": 52, "area_size": Vector2(74, 44), "knockback_min": 55.0, "knockback_max": 95.0, "icon_size": Vector2(58, 15), "icon_color": Color(0.8, 0.5, 0.25), "icon_offset": 20.0},
		"special": {"type": "cleave"},
		"unique_desc": "So heavy it cleaves through EVERY enemy in the arc, not just the nearest.",
	},
	"wpn_stormlance": {
		"name": "Stormlance", "category": "weapon", "weapon_type": "spear", "max_stack": 1, "color": Color(0.85, 0.8, 0.5, 1.0),
		"weapon_stats": {"damage": 12, "cooldown": 1.0, "range_offset": 55, "area_size": Vector2(70, 40), "knockback_min": 40.0, "knockback_max": 70.0, "icon_size": Vector2(110, 8), "icon_color": Color(0.85, 0.8, 0.5), "icon_offset": 16.0},
		"special": {"type": "javelin_volley", "count": 3, "spread_deg": 10.0, "damage": 12, "speed": 700.0, "range": 520.0},
		"unique_desc": "Instead of thrusting, conjures 3 spectral javelins and hurls them all at once -- they pierce clean through.",
	},
	"wpn_stormvolley": {
		"name": "Stormvolley Bow", "category": "weapon", "weapon_type": "bow", "max_stack": 1, "color": Color(0.55, 0.42, 0.7, 1.0),
		"weapon_stats": {"damage": 10, "cooldown": 0.6, "range_offset": 90, "area_size": Vector2(110, 40), "knockback_min": 22.0, "knockback_max": 44.0, "icon_size": Vector2(14, 14), "icon_color": Color(0.55, 0.42, 0.7), "icon_offset": 18.0},
		"special": {"type": "multi_shot", "count": 3, "spread_deg": 12.0},
		"unique_desc": "Looses a fan of 3 arrows with every draw.",
	},
	"wpn_seeker": {
		"name": "Seeker Bow", "category": "weapon", "weapon_type": "bow", "max_stack": 1, "color": Color(0.3, 0.75, 0.55, 1.0),
		"weapon_stats": {"damage": 15, "cooldown": 0.55, "range_offset": 90, "area_size": Vector2(110, 40), "knockback_min": 24.0, "knockback_max": 48.0, "icon_size": Vector2(14, 14), "icon_color": Color(0.3, 0.75, 0.55), "icon_offset": 18.0},
		"special": {"type": "homing"},
		"unique_desc": "Its enchanted arrows bend mid-flight, hunting the nearest enemy on their own.",
	},
	"wpn_emberstaff": {
		"name": "Emberstaff", "category": "weapon", "weapon_type": "wand", "max_stack": 1, "color": Color(0.95, 0.5, 0.15, 1.0), "mana_cost": 12,
		"weapon_stats": {"damage": 0, "cooldown": 0.7, "range_offset": 30, "area_size": Vector2(10, 10), "knockback_min": 0.0, "knockback_max": 0.0, "icon_size": Vector2(50, 8), "icon_color": Color(0.95, 0.5, 0.15), "icon_offset": 20.0},
		"special": {"type": "fireball", "damage": 28, "aoe": 110.0, "speed": 460.0, "range": 600.0, "status": {"kind": "burn", "dur": 4.0, "mag": 6.0}},
		"unique_desc": "Launches a fireball that detonates on impact, scorching (burns) everything within 110px.",
	},
	"wpn_iciclewand": {
		"name": "Icicle Wand", "category": "weapon", "weapon_type": "wand", "max_stack": 1, "color": Color(0.6, 0.85, 1.0, 1.0), "mana_cost": 8,
		"weapon_stats": {"damage": 0, "cooldown": 0.5, "range_offset": 30, "area_size": Vector2(10, 10), "knockback_min": 0.0, "knockback_max": 0.0, "icon_size": Vector2(46, 8), "icon_color": Color(0.6, 0.85, 1.0), "icon_offset": 20.0},
		"special": {"type": "frost_shard", "damage": 16, "speed": 640.0, "range": 560.0, "pierce": true, "status": {"kind": "slow", "dur": 3.0, "mag": 0.5}},
		"unique_desc": "Fires a razor icicle that skewers (and chills/slows) every enemy along its line.",
	},
	# --- WAVE 1 of the weapons overhaul (2026-07-28): the first carriers of
	# the new behavior library. Terraria-INSPIRED mechanics, Deepwood names.
	"wpn_soulwheel": {
		"name": "Keening Soulwheel", "category": "weapon", "weapon_type": "melee", "max_stack": 1, "color": Color(0.65, 0.85, 1.0, 1.0),
		"weapon_stats": {"damage": 11, "cooldown": 0.75, "range_offset": 40, "area_size": Vector2(50, 32), "knockback_min": 20.0, "knockback_max": 40.0, "icon_size": Vector2(26, 26), "icon_color": Color(0.65, 0.85, 1.0), "icon_offset": 18.0},
		"special": {"type": "orbiter", "damage": 11, "speed": 620.0, "range": 260.0, "dwell": 2.2},
		"unique_desc": "A bound spirit-wheel on a soul-thread: it flies out, SPINS where it lands cutting everything around it, then threads home.",
	},
	"wpn_emberlash": {
		"name": "Cinderlash", "category": "weapon", "weapon_type": "melee", "max_stack": 1, "color": Color(1.0, 0.6, 0.25, 1.0),
		"weapon_stats": {"damage": 14, "cooldown": 0.9, "range_offset": 44, "area_size": Vector2(56, 34), "knockback_min": 26.0, "knockback_max": 50.0, "icon_size": Vector2(56, 10), "icon_color": Color(1.0, 0.6, 0.25), "icon_offset": 20.0},
		"special": {"type": "lash", "damage": 14, "speed": 560.0, "range": 340.0, "status": {"kind": "burn", "dur": 3.0, "mag": 4.0}},
		"unique_desc": "A ribbon of living fire that weaves out through everything in its lane -- and rakes it all AGAIN whipping back.",
	},
	"wpn_trickbolt": {
		"name": "Gambler's Bolt", "category": "weapon", "weapon_type": "wand", "max_stack": 1, "color": Color(1.0, 0.85, 0.4, 1.0), "mana_cost": 9,
		"weapon_stats": {"damage": 0, "cooldown": 0.6, "range_offset": 30, "area_size": Vector2(10, 10), "knockback_min": 0.0, "knockback_max": 0.0, "icon_size": Vector2(46, 8), "icon_color": Color(1.0, 0.85, 0.4), "icon_offset": 20.0},
		"special": {"type": "ricochet", "damage": 15, "speed": 700.0, "range": 480.0, "bounces": 3},
		"unique_desc": "The bolt refuses to stop at one debt: it leaps foe to foe up to three times, each hit a little lighter.",
	},
	"wpn_shardmother": {
		"name": "Shardmother Wand", "category": "weapon", "weapon_type": "wand", "max_stack": 1, "color": Color(0.6, 0.8, 1.0, 1.0), "mana_cost": 11,
		"weapon_stats": {"damage": 0, "cooldown": 0.75, "range_offset": 30, "area_size": Vector2(10, 10), "knockback_min": 0.0, "knockback_max": 0.0, "icon_size": Vector2(48, 8), "icon_color": Color(0.6, 0.8, 1.0), "icon_offset": 20.0},
		"special": {"type": "cluster", "damage": 18, "speed": 520.0, "range": 420.0, "shards": 5},
		"unique_desc": "The mother-bolt bursts on its first mark -- or at full reach -- into a fan of five biting shards.",
	},
	"wpn_petardcane": {
		"name": "Petard Cane", "category": "weapon", "weapon_type": "wand", "max_stack": 1, "color": Color(0.8, 0.55, 0.3, 1.0), "mana_cost": 13,
		"weapon_stats": {"damage": 0, "cooldown": 1.0, "range_offset": 30, "area_size": Vector2(10, 10), "knockback_min": 0.0, "knockback_max": 0.0, "icon_size": Vector2(50, 8), "icon_color": Color(0.8, 0.55, 0.3), "icon_offset": 20.0},
		"special": {"type": "lob", "damage": 24, "speed": 520.0, "range": 520.0, "aoe": 100.0},
		"unique_desc": "An alchemist's answer to a wall of enemies: the charge sails a mortar arc and BLOSSOMS where it lands.",
	},
	"wpn_stormtome": {
		"name": "Tome of the Low Sky", "category": "weapon", "weapon_type": "wand", "max_stack": 1, "color": Color(0.55, 0.75, 1.0, 1.0), "mana_cost": 18,
		"weapon_stats": {"damage": 0, "cooldown": 1.4, "range_offset": 30, "area_size": Vector2(10, 10), "knockback_min": 0.0, "knockback_max": 0.0, "icon_size": Vector2(34, 26), "icon_color": Color(0.55, 0.75, 1.0), "icon_offset": 18.0},
		"special": {"type": "tome_storm", "damage": 9, "range": 540.0, "radius": 130.0, "dur": 4.5, "gap": 0.4},
		"unique_desc": "Reads a stormlet down over the aimed ground: for a few seconds that patch of the world belongs to the lightning.",
	},
	"wpn_wardtotem": {
		"name": "Watcher's Rod", "category": "weapon", "weapon_type": "wand", "max_stack": 1, "color": Color(0.5, 0.8, 0.7, 1.0), "mana_cost": 16,
		"weapon_stats": {"damage": 0, "cooldown": 1.2, "range_offset": 30, "area_size": Vector2(10, 10), "knockback_min": 0.0, "knockback_max": 0.0, "icon_size": Vector2(46, 8), "icon_color": Color(0.5, 0.8, 0.7), "icon_offset": 20.0},
		"special": {"type": "sentry", "damage": 8, "dur": 16.0, "gap": 0.85},
		"unique_desc": "Plants ONE watching totem that snipes the nearest foe on its own clock. Planting again moves the watch.",
	},
	"wpn_boughstaff": {
		"name": "Bending Bough", "category": "weapon", "weapon_type": "melee", "max_stack": 1, "color": Color(0.55, 0.75, 0.4, 1.0),
		"weapon_stats": {"damage": 9, "cooldown": 0.45, "range_offset": 50, "area_size": Vector2(64, 30), "knockback_min": 24.0, "knockback_max": 46.0, "icon_size": Vector2(88, 7), "icon_color": Color(0.55, 0.75, 0.4), "icon_offset": 14.0},
		"special": {"type": "staff_extend"},
		"unique_desc": "A staff that remembers the old trickster-king: every landed blow in rhythm DRAWS IT LONGER, and the fourth strikes the earth as a pillar.",
	},
	# --- Admin test wand (dev only, granted with the starter kit, hotbar 7).
	# RIGHT-click, no aiming: sears 5% of MAX HP off every enemy within 280px,
	# ignoring all scaling -- so ~20 casts fell ANYTHING, sized exactly for
	# walking a final boss through all of its phases. Costs no mana.
	"wpn_admin_ruin": {
		"name": "Ruin Wand (Admin)", "category": "weapon", "weapon_type": "wand", "max_stack": 1, "color": Color(0.9, 0.2, 0.25, 1.0), "mana_cost": 0,
		"weapon_stats": {"damage": 0, "cooldown": 0.4, "range_offset": 30, "area_size": Vector2(10, 10), "knockback_min": 0.0, "knockback_max": 0.0, "icon_size": Vector2(48, 8), "icon_color": Color(0.9, 0.2, 0.25), "icon_offset": 20.0},
		"special": {"type": "percent_burst", "percent": 0.05, "radius": 280.0},
		"unique_desc": "ADMIN: right-click (no aim needed) to sear 5% of MAX HP off every enemy within 280px. 20 casts fell anything.",
	},
	# --- Gathering tools: wielded from the hotbar like any weapon. Weak in a
	# fight, but swinging one at a matching harvest node (tree/rock -- see
	# harvest_node.gd) gathers materials. tool_type gates which node it works on.
	"tool_axe": {
		"name": "Woodsman's Axe", "category": "weapon", "weapon_type": "melee", "tool_type": "axe", "max_stack": 1, "color": Color(0.72, 0.5, 0.3, 1.0),
		"weapon_stats": {"damage": 6, "cooldown": 0.5, "range_offset": 46, "area_size": Vector2(60, 36), "knockback_min": 20.0, "knockback_max": 40.0, "icon_size": Vector2(40, 10), "icon_color": Color(0.6, 0.42, 0.24), "icon_offset": 18.0},
		"unique_desc": "Chops trees for Wood and Resin.",
	},
	"tool_pickaxe": {
		"name": "Miner's Pickaxe", "category": "weapon", "weapon_type": "melee", "tool_type": "pickaxe", "pick_tier": 1, "max_stack": 1, "color": Color(0.6, 0.6, 0.66, 1.0),
		"weapon_stats": {"damage": 6, "cooldown": 0.5, "range_offset": 46, "area_size": Vector2(60, 36), "knockback_min": 20.0, "knockback_max": 40.0, "icon_size": Vector2(40, 10), "icon_color": Color(0.55, 0.55, 0.6), "icon_offset": 18.0},
		"unique_desc": "Mines rocks for Stone and rare minerals. Tier 1 Ã¢â‚¬â€ cuts down to the Fungal Hollow.",
	},
	# TIERED PICKAXES (2026-07-26): the deep biomes gate on pick_tier (see underground.gd
	# BIOMES). Each is FOUND in the deepest biome the previous tier can already mine, so you
	# earn your way down: Embersteel from Fungal Hollow chests opens the Emberdeep;
	# Blightbreaker from Emberdeep chests opens the Blightcore.
	"tool_pickaxe_ember": {
		"name": "Embersteel Pickaxe", "category": "weapon", "weapon_type": "melee", "tool_type": "pickaxe", "pick_tier": 2, "max_stack": 1, "color": Color(0.95, 0.5, 0.2, 1.0),
		"weapon_stats": {"damage": 10, "cooldown": 0.45, "range_offset": 46, "area_size": Vector2(62, 38), "knockback_min": 24.0, "knockback_max": 46.0, "icon_size": Vector2(42, 11), "icon_color": Color(0.95, 0.5, 0.2), "icon_offset": 18.0},
		"unique_desc": "Tier 2 Ã¢â‚¬â€ its heat-forged head bites the Emberdeep's scorched rock.",
	},
	"tool_pickaxe_blight": {
		"name": "Blightbreaker Pickaxe", "category": "weapon", "weapon_type": "melee", "tool_type": "pickaxe", "pick_tier": 3, "max_stack": 1, "color": Color(0.82, 0.42, 1.0, 1.0),
		"weapon_stats": {"damage": 14, "cooldown": 0.4, "range_offset": 48, "area_size": Vector2(64, 40), "knockback_min": 28.0, "knockback_max": 52.0, "icon_size": Vector2(44, 12), "icon_color": Color(0.82, 0.42, 1.0), "icon_offset": 18.0},
		"unique_desc": "Tier 3 Ã¢â‚¬â€ the only edge that breaks the cursed Blightcore stone at the world's bottom.",
	},
	# --- Excellent weapons (classless, unique effects, no skill scaling) ---
	"exc_vampiric": {
		"name": "Vampiric Fang", "category": "weapon", "weapon_type": "melee", "excellent": true, "max_stack": 1, "color": Color(0.7, 0.1, 0.2, 1.0),
		"weapon_stats": {"damage": 14, "cooldown": 0.38, "range_offset": 46, "area_size": Vector2(60, 36), "knockback_min": 30.0, "knockback_max": 60.0, "icon_size": Vector2(52, 12), "icon_color": Color(0.7, 0.1, 0.2), "icon_offset": 20.0},
		"unique_effect": "lifesteal", "unique_value": 0.35,
		"unique_desc": "Heals you for 35% of the melee damage it deals.",
	},
	"exc_thunder": {
		"name": "Thundercaller", "category": "weapon", "weapon_type": "melee", "excellent": true, "max_stack": 1, "color": Color(0.4, 0.6, 1.0, 1.0),
		"weapon_stats": {"damage": 16, "cooldown": 0.5, "range_offset": 50, "area_size": Vector2(66, 38), "knockback_min": 35.0, "knockback_max": 65.0, "icon_size": Vector2(56, 12), "icon_color": Color(0.4, 0.6, 1.0), "icon_offset": 20.0},
		"unique_effect": "chain", "unique_value": 12, "unique_radius": 150.0,
		"unique_desc": "Each hit also zaps every enemy within 150px for 12 damage.",
	},
	"exc_midas": {
		"name": "Midas Edge", "category": "weapon", "weapon_type": "melee", "excellent": true, "max_stack": 1, "color": Color(0.95, 0.78, 0.2, 1.0),
		"weapon_stats": {"damage": 12, "cooldown": 0.35, "range_offset": 46, "area_size": Vector2(60, 36), "knockback_min": 30.0, "knockback_max": 60.0, "icon_size": Vector2(52, 12), "icon_color": Color(0.95, 0.78, 0.2), "icon_offset": 20.0},
		"unique_effect": "gold_touch", "unique_value": 0.5,
		"unique_desc": "Turns pain into profit: each hit grants gold worth 50% of the damage dealt.",
	},
	"exc_echo": {
		"name": "Echo Rift", "category": "weapon", "weapon_type": "melee", "excellent": true, "max_stack": 1, "color": Color(0.4, 0.85, 0.9, 1.0),
		"weapon_stats": {"damage": 15, "cooldown": 0.45, "range_offset": 48, "area_size": Vector2(64, 38), "knockback_min": 32.0, "knockback_max": 62.0, "icon_size": Vector2(54, 12), "icon_color": Color(0.4, 0.85, 0.9), "icon_offset": 20.0},
		"unique_effect": "echo", "unique_value": 1.0,
		"unique_desc": "Every 3rd strike tears open a rift that repeats the blow's full damage.",
	},
	"exc_soul": {
		"name": "Soulthirst", "category": "weapon", "weapon_type": "melee", "excellent": true, "max_stack": 1, "color": Color(0.45, 0.3, 0.9, 1.0),
		"weapon_stats": {"damage": 12, "cooldown": 0.32, "range_offset": 46, "area_size": Vector2(60, 36), "knockback_min": 30.0, "knockback_max": 60.0, "icon_size": Vector2(52, 12), "icon_color": Color(0.55, 0.38, 0.95), "icon_offset": 20.0},
		"unique_effect": "manasteal", "unique_value": 12,
		"unique_desc": "Drinks the struck foe's spirit: restores 12 Mana per hit.",
	},
	"exc_hook": {
		"name": "Leviathan Hook", "category": "weapon", "weapon_type": "melee", "excellent": true, "max_stack": 1, "color": Color(0.55, 0.65, 0.72, 1.0),
		"weapon_stats": {"damage": 9, "cooldown": 0.8, "range_offset": 46, "area_size": Vector2(60, 36), "knockback_min": 0.0, "knockback_max": 0.0, "icon_size": Vector2(44, 12), "icon_color": Color(0.6, 0.68, 0.75), "icon_offset": 20.0},
		"special": {"type": "hook", "damage": 9, "speed": 780.0, "range": 420.0},
		"unique_desc": "Hurls a barbed hook on a rope -- the first enemy struck is DRAGGED to your feet.",
	},
	"exc_boomerang": {
		"name": "Galewing Glaive", "category": "weapon", "weapon_type": "melee", "excellent": true, "max_stack": 1, "color": Color(0.35, 0.8, 0.75, 1.0),
		"weapon_stats": {"damage": 13, "cooldown": 0.9, "range_offset": 46, "area_size": Vector2(60, 36), "knockback_min": 26.0, "knockback_max": 50.0, "icon_size": Vector2(46, 12), "icon_color": Color(0.35, 0.8, 0.75), "icon_offset": 20.0},
		"special": {"type": "boomerang", "damage": 13, "speed": 520.0, "range": 380.0},
		"unique_desc": "A whirling glaive that flies out and RETURNS -- striking every enemy on both passes.",
	},
	"exc_chrono": {
		"name": "Chrono Edge", "category": "weapon", "weapon_type": "melee", "excellent": true, "max_stack": 1, "color": Color(0.9, 0.85, 0.45, 1.0),
		"weapon_stats": {"damage": 14, "cooldown": 0.5, "range_offset": 46, "area_size": Vector2(60, 36), "knockback_min": 30.0, "knockback_max": 60.0, "icon_size": Vector2(52, 12), "icon_color": Color(0.9, 0.85, 0.45), "icon_offset": 20.0},
		"unique_effect": "chrono", "unique_value": 0.25,
		"unique_desc": "Each hit has a 25% chance to rewind time, instantly resetting your attack cooldown.",
	},
	# The boss-killer: a rune-etched greatblade forged to end the Fallen Wizard.
	# Deals +150% damage to BOSSES (and their echoes) -- which also punches
	# through the Wizard's Soul Ward -- and drinks 8 Mana on every hit so you can
	# keep flying and casting through the long fight. Rare deep-dungeon drop.
	"exc_wizardsbane": {
		"name": "Wizardsbane", "category": "weapon", "weapon_type": "melee", "excellent": true, "max_stack": 1, "color": Color(0.85, 0.9, 0.75, 1.0),
		"weapon_stats": {"damage": 25, "cooldown": 0.45, "range_offset": 52, "area_size": Vector2(70, 40), "knockback_min": 40.0, "knockback_max": 75.0, "icon_size": Vector2(64, 14), "icon_color": Color(0.88, 0.92, 0.72), "icon_offset": 20.0},
		"unique_effect": "bossbane", "unique_value": 1.5, "mana_on_hit": 8,
		"unique_desc": "Forged to slay the undying: +150% damage to bosses (cuts their wards), and drinks 8 Mana on every hit.",
	},
	# The showpiece: a builder-into-ultimate greatblade. Every hit throws a
	# flying slash AND charges the storm; the 8th hit ERUPTS -- a 12-way slash
	# nova, a meteor barrage, and a shockwave. A screen-clearing spectacle.
	"exc_ragnarok": {
		"name": "Ragnarok Blade", "category": "weapon", "weapon_type": "melee", "excellent": true, "max_stack": 1, "color": Color(1.0, 0.55, 0.15, 1.0),
		"weapon_stats": {"damage": 18, "cooldown": 0.4, "range_offset": 50, "area_size": Vector2(66, 40), "knockback_min": 35.0, "knockback_max": 70.0, "icon_size": Vector2(60, 13), "icon_color": Color(1.0, 0.6, 0.2), "icon_offset": 20.0},
		"swing_slash": {"status": {"kind": "burn", "dur": 3.0, "mag": 6.0}},
		"unique_effect": "ragnarok", "unique_value": 8,
		"unique_desc": "Every strike hurls a slash and stokes the storm; every 8th strike erupts into a 12-way slash nova, a meteor barrage, and a shockwave.",
	},
	# --- More crazy weapons ---
	"wpn_tempest": {
		"name": "Tempest Bow", "category": "weapon", "weapon_type": "bow", "excellent": true, "max_stack": 1, "color": Color(0.5, 0.85, 1.0, 1.0),
		"weapon_stats": {"damage": 16, "cooldown": 0.6, "range_offset": 90, "area_size": Vector2(110, 40), "knockback_min": 24.0, "knockback_max": 48.0, "icon_size": Vector2(15, 15), "icon_color": Color(0.5, 0.85, 1.0), "icon_offset": 18.0},
		"special": {"type": "storm_shot", "count": 5, "spread_deg": 22.0, "homing": true},
		"unique_desc": "A screaming gale of 5 self-guiding arrows -- they fan out and then hunt the nearest foes.",
	},
	"exc_doom": {
		"name": "Doombringer", "category": "weapon", "weapon_type": "melee", "excellent": true, "max_stack": 1, "color": Color(0.55, 0.06, 0.14, 1.0),
		"weapon_stats": {"damage": 21, "cooldown": 0.5, "range_offset": 50, "area_size": Vector2(66, 40), "knockback_min": 35.0, "knockback_max": 70.0, "icon_size": Vector2(60, 13), "icon_color": Color(0.62, 0.08, 0.16), "icon_offset": 20.0},
		"unique_effect": "execute", "unique_value": 0.18, "boss_bonus": 0.5,
		"unique_desc": "Instantly slays any non-boss below 18% health; bosses take +50% damage instead.",
	},
	"exc_singularity": {
		"name": "Singularity Edge", "category": "weapon", "weapon_type": "melee", "excellent": true, "max_stack": 1, "color": Color(0.5, 0.25, 0.75, 1.0),
		"weapon_stats": {"damage": 17, "cooldown": 0.5, "range_offset": 50, "area_size": Vector2(64, 38), "knockback_min": 20.0, "knockback_max": 40.0, "icon_size": Vector2(56, 12), "icon_color": Color(0.6, 0.32, 0.92), "icon_offset": 20.0},
		"unique_effect": "singularity", "unique_value": 5, "unique_radius": 320.0,
		"unique_desc": "Every 5th strike tears open a black hole that drags in every nearby enemy and implodes for heavy damage.",
	},
	"exc_worldsplitter": {
		"name": "Worldsplitter", "category": "weapon", "weapon_type": "melee", "excellent": true, "max_stack": 1, "color": Color(0.95, 0.6, 0.2, 1.0),
		"weapon_stats": {"damage": 23, "cooldown": 0.5, "range_offset": 52, "area_size": Vector2(70, 42), "knockback_min": 45.0, "knockback_max": 85.0, "icon_size": Vector2(64, 14), "icon_color": Color(0.95, 0.6, 0.2), "icon_offset": 20.0},
		"unique_effect": "shockwave", "unique_value": 0.6, "unique_radius": 260.0,
		"unique_desc": "Every blow sends a shockwave that rips through every enemy within 260px for 60% of the damage.",
	},
	"exc_dawnbreaker": {
		"name": "Dawnbreaker", "category": "weapon", "weapon_type": "melee", "excellent": true, "max_stack": 1, "color": Color(1.0, 0.95, 0.6, 1.0),
		"weapon_stats": {"damage": 17, "cooldown": 0.48, "range_offset": 48, "area_size": Vector2(64, 38), "knockback_min": 30.0, "knockback_max": 60.0, "icon_size": Vector2(56, 12), "icon_color": Color(1.0, 0.95, 0.6), "icon_offset": 20.0},
		"unique_effect": "radiance", "unique_value": 0.2,
		"unique_desc": "Blessed light: each swing hurls a piercing sun-slash and heals you for 20% of the damage dealt.",
	},
	# ======================= BATCH: 16 MORE WEAPONS =======================
	# New archetypes (mace/dagger/javelin), early-game fillers, and mythic
	# signature weapons for the caster classes. Effects reuse the existing
	# handlers where possible (cleave/shockwave/hook/javelin_volley/storm_shot/
	# fireball/lifesteal); "passive" overrides let daggers grant crit.
	# --- Early-game fillers (uncommon: the tier between the base kit and loot) ---
	"wpn_club": {"name": "Wooden Club", "category": "weapon", "weapon_type": "melee", "max_stack": 1, "color": Color(0.55, 0.4, 0.24, 1.0),
		"weapon_stats": {"damage": 13, "cooldown": 0.35, "range_offset": 46, "area_size": Vector2(58, 34), "knockback_min": 35.0, "knockback_max": 65.0, "icon_size": Vector2(48, 14), "icon_color": Color(0.55, 0.4, 0.24), "icon_offset": 20.0}},
	"wpn_shortbow": {"name": "Short Bow", "category": "weapon", "weapon_type": "bow", "max_stack": 1, "color": Color(0.5, 0.34, 0.18, 1.0),
		"weapon_stats": {"damage": 14, "cooldown": 0.42, "range_offset": 90, "area_size": Vector2(110, 40), "knockback_min": 18.0, "knockback_max": 36.0, "icon_size": Vector2(14, 14), "icon_color": Color(0.5, 0.34, 0.18), "icon_offset": 18.0}},
	"wpn_apprentice_wand": {"name": "Apprentice Wand", "category": "weapon", "weapon_type": "wand", "max_stack": 1, "color": Color(0.55, 0.45, 0.85, 1.0), "mana_cost": 6,
		"weapon_stats": {"damage": 0, "cooldown": 0.55, "range_offset": 30, "area_size": Vector2(10, 10), "knockback_min": 0.0, "knockback_max": 0.0, "icon_size": Vector2(44, 8), "icon_color": Color(0.55, 0.45, 0.85), "icon_offset": 20.0},
		"special": {"type": "frost_shard", "damage": 12, "speed": 560.0, "range": 480.0}, "unique_desc": "A starter caster's bolt of force."},
	"wpn_dagger": {"name": "Iron Dagger", "category": "weapon", "weapon_type": "melee", "max_stack": 1, "color": Color(0.75, 0.76, 0.82, 1.0),
		"weapon_stats": {"damage": 8, "cooldown": 0.22, "range_offset": 40, "area_size": Vector2(48, 32), "knockback_min": 15.0, "knockback_max": 30.0, "icon_size": Vector2(40, 10), "icon_color": Color(0.78, 0.78, 0.84), "icon_offset": 18.0},
		"passive": {"crit_chance": 0.10}, "unique_desc": "Fast strikes with a knack for finding the gap (+crit)."},
	# --- Maces / hammers (heavy melee) ---
	"wpn_mace": {"name": "Iron Mace", "category": "weapon", "weapon_type": "melee", "max_stack": 1, "color": Color(0.6, 0.6, 0.66, 1.0),
		"weapon_stats": {"damage": 21, "cooldown": 0.6, "range_offset": 48, "area_size": Vector2(60, 38), "knockback_min": 55.0, "knockback_max": 95.0, "icon_size": Vector2(50, 16), "icon_color": Color(0.62, 0.62, 0.68), "icon_offset": 20.0},
		"unique_desc": "A brutal crusher -- heavy hits, big knockback."},
	"wpn_greatsword": {"name": "Greatsword", "category": "weapon", "weapon_type": "melee", "max_stack": 1, "color": Color(0.78, 0.78, 0.84, 1.0),
		"weapon_stats": {"damage": 25, "cooldown": 0.7, "range_offset": 54, "area_size": Vector2(78, 44), "knockback_min": 45.0, "knockback_max": 80.0, "icon_size": Vector2(70, 14), "icon_color": Color(0.8, 0.8, 0.86), "icon_offset": 20.0},
		"special": {"type": "cleave"}, "unique_desc": "A wide blade that cleaves every enemy in the arc."},
	"wpn_katana": {"name": "Katana", "category": "weapon", "weapon_type": "melee", "max_stack": 1, "color": Color(0.85, 0.85, 0.9, 1.0),
		"weapon_stats": {"damage": 15, "cooldown": 0.32, "range_offset": 50, "area_size": Vector2(66, 34), "knockback_min": 28.0, "knockback_max": 55.0, "icon_size": Vector2(62, 10), "icon_color": Color(0.88, 0.88, 0.94), "icon_offset": 20.0},
		"passive": {"crit_chance": 0.08, "crit_damage": 0.15}, "unique_desc": "A keen, quick blade that rewards precise strikes (+crit)."},
	"wpn_warhammer": {"name": "Warhammer", "category": "weapon", "weapon_type": "melee", "max_stack": 1, "color": Color(0.55, 0.5, 0.5, 1.0),
		"weapon_stats": {"damage": 35, "cooldown": 0.9, "range_offset": 52, "area_size": Vector2(72, 46), "knockback_min": 80.0, "knockback_max": 140.0, "icon_size": Vector2(56, 18), "icon_color": Color(0.58, 0.52, 0.52), "icon_offset": 20.0},
		"unique_desc": "A slow, devastating blow with bone-breaking knockback."},
	# --- Javelins / spears (slightly ranged) ---
	"wpn_javelin": {"name": "Javelin", "category": "weapon", "weapon_type": "spear", "max_stack": 1, "color": Color(0.62, 0.5, 0.3, 1.0),
		"weapon_stats": {"damage": 14, "cooldown": 0.7, "range_offset": 55, "area_size": Vector2(70, 40), "knockback_min": 35.0, "knockback_max": 65.0, "icon_size": Vector2(100, 7), "icon_color": Color(0.62, 0.5, 0.3), "icon_offset": 16.0},
		"special": {"type": "javelin_volley", "count": 1, "spread_deg": 0.0, "damage": 18, "speed": 720.0, "range": 560.0}, "unique_desc": "Hurl a single hard-piercing javelin instead of thrusting."},
	"wpn_harpoon": {"name": "Harpoon", "category": "weapon", "weapon_type": "melee", "max_stack": 1, "color": Color(0.4, 0.6, 0.62, 1.0),
		"weapon_stats": {"damage": 16, "cooldown": 0.75, "range_offset": 48, "area_size": Vector2(60, 36), "knockback_min": 0.0, "knockback_max": 0.0, "icon_size": Vector2(58, 9), "icon_color": Color(0.4, 0.6, 0.62), "icon_offset": 20.0},
		"special": {"type": "hook", "damage": 16, "speed": 820.0, "range": 460.0}, "unique_desc": "Spears a foe from range and reels it to you."},
	# --- Excellent / mythic signature weapons (fill caster + top-end gaps) ---
	"exc_earthshaker": {"name": "Earthshaker Maul", "category": "weapon", "weapon_type": "melee", "excellent": true, "max_stack": 1, "color": Color(0.7, 0.45, 0.2, 1.0),
		"weapon_stats": {"damage": 28, "cooldown": 0.7, "range_offset": 52, "area_size": Vector2(74, 44), "knockback_min": 70.0, "knockback_max": 120.0, "icon_size": Vector2(58, 18), "icon_color": Color(0.72, 0.46, 0.2), "icon_offset": 20.0},
		"unique_effect": "shockwave", "unique_value": 0.7, "unique_radius": 300.0,
		"unique_desc": "Every blow erupts a quake that rips through everything within 300px for 70% of the damage."},
	"exc_gungnir": {"name": "Gungnir", "category": "weapon", "weapon_type": "spear", "excellent": true, "max_stack": 1, "color": Color(0.9, 0.85, 0.55, 1.0),
		"weapon_stats": {"damage": 16, "cooldown": 0.75, "range_offset": 55, "area_size": Vector2(70, 40), "knockback_min": 40.0, "knockback_max": 70.0, "icon_size": Vector2(112, 8), "icon_color": Color(0.9, 0.85, 0.55), "icon_offset": 16.0},
		"special": {"type": "javelin_volley", "count": 5, "spread_deg": 16.0, "damage": 18, "speed": 780.0, "range": 620.0},
		"unique_desc": "The spear that never misses: conjures 5 piercing spears and hurls the whole storm."},
	"exc_shadowblade": {"name": "Shadowblade", "category": "weapon", "weapon_type": "melee", "excellent": true, "max_stack": 1, "color": Color(0.35, 0.28, 0.45, 1.0),
		"weapon_stats": {"damage": 14, "cooldown": 0.3, "range_offset": 46, "area_size": Vector2(58, 34), "knockback_min": 20.0, "knockback_max": 40.0, "icon_size": Vector2(52, 10), "icon_color": Color(0.55, 0.4, 0.75), "icon_offset": 20.0},
		"passive": {"crit_chance": 0.25, "crit_damage": 0.5},
		"unique_desc": "A blade of pure night: sky-high crit, and every swing hurls a shadow-slash that flies onward."},
	"exc_frostmourne": {"name": "Frostmourne", "category": "weapon", "weapon_type": "melee", "excellent": true, "max_stack": 1, "color": Color(0.55, 0.8, 0.95, 1.0),
		"weapon_stats": {"damage": 21, "cooldown": 0.45, "range_offset": 50, "area_size": Vector2(66, 38), "knockback_min": 30.0, "knockback_max": 60.0, "icon_size": Vector2(64, 12), "icon_color": Color(0.6, 0.82, 0.98), "icon_offset": 20.0},
		"swing_slash": {"status": {"kind": "slow", "dur": 2.5, "mag": 0.45}},
		"unique_effect": "lifesteal", "unique_value": 0.4, "on_hit_status": {"kind": "slow", "dur": 3.0, "mag": 0.5},
		"unique_desc": "A cursed runeblade that drinks 40% of the damage it deals back as health -- and its frost chills (slows) what it strikes."},
	"exc_voidcaller": {"name": "Voidcaller", "category": "weapon", "weapon_type": "wand", "excellent": true, "max_stack": 1, "color": Color(0.45, 0.2, 0.7, 1.0), "mana_cost": 16,
		"weapon_stats": {"damage": 0, "cooldown": 0.65, "range_offset": 30, "area_size": Vector2(10, 10), "knockback_min": 0.0, "knockback_max": 0.0, "icon_size": Vector2(52, 8), "icon_color": Color(0.6, 0.3, 0.9), "icon_offset": 20.0},
		"special": {"type": "fireball", "damage": 48, "aoe": 180.0, "speed": 420.0, "range": 640.0, "status": {"kind": "poison", "dur": 5.0, "mag": 8.0}},
		"unique_desc": "Hurls a collapsing void-bomb: heavy damage in a huge 180px radius that also leaves a withering poison."},
	"exc_stormfury": {"name": "Stormfury Bow", "category": "weapon", "weapon_type": "bow", "excellent": true, "max_stack": 1, "color": Color(0.5, 0.8, 1.0, 1.0),
		"weapon_stats": {"damage": 18, "cooldown": 0.55, "range_offset": 90, "area_size": Vector2(110, 40), "knockback_min": 24.0, "knockback_max": 48.0, "icon_size": Vector2(15, 15), "icon_color": Color(0.5, 0.8, 1.0), "icon_offset": 18.0},
		"special": {"type": "storm_shot", "count": 6, "spread_deg": 26.0, "homing": true},
		"unique_desc": "Unleashes 6 homing storm-arrows in a screaming fan -- the sky itself hunts your foes."},
	# --- Grade-fill weapons (WEAPONS.md Ã‚Â§3): early variety, each distinct on the
	# existing dials -- hitbox shape (area_size), reach, attack speed, knockback.
	# Damage already at the +15% baseline. Icons render via the by-type fallback. ---
	# COMMON melee
	"wpn_shortsword": {"name": "Short Sword", "category": "weapon", "weapon_type": "melee", "max_stack": 1, "color": Color(0.78, 0.8, 0.85, 1.0),
		"weapon_stats": {"damage": 9, "cooldown": 0.24, "range_offset": 44, "area_size": Vector2(46, 30), "knockback_min": 18.0, "knockback_max": 38.0, "icon_size": Vector2(44, 12), "icon_color": Color(0.78, 0.8, 0.85), "icon_offset": 20.0},
		"unique_desc": "A light, quick blade -- fast jabs, low commitment."},
	"wpn_rapier": {"name": "Rapier", "category": "weapon", "weapon_type": "melee", "max_stack": 1, "color": Color(0.85, 0.86, 0.9, 1.0),
		# a rapier is the exception the derivation can't express: LONG and FAST.
		# Deriving length from swing speed alone would make it one of the
		# shortest weapons in the game, flatly contradicting its own text, so it
		# takes the size_override escape hatch -- long reach on a thin, precise
		# blade, exactly as described.
		"weapon_stats": {"damage": 8, "cooldown": 0.28, "range_offset": 60, "area_size": Vector2(40, 18), "size_override": Vector2(74, 20), "knockback_min": 8.0, "knockback_max": 20.0, "icon_size": Vector2(58, 8), "icon_color": Color(0.85, 0.86, 0.9), "icon_offset": 22.0},
		"unique_desc": "A long, thin point -- great reach, a tiny precise hitbox."},
	"wpn_cleaver": {"name": "Cleaver", "category": "weapon", "weapon_type": "melee", "max_stack": 1, "color": Color(0.7, 0.7, 0.72, 1.0),
		"weapon_stats": {"damage": 15, "cooldown": 0.55, "range_offset": 46, "area_size": Vector2(76, 46), "knockback_min": 45.0, "knockback_max": 80.0, "icon_size": Vector2(52, 20), "icon_color": Color(0.7, 0.7, 0.72), "icon_offset": 20.0},
		"unique_desc": "A broad, heavy chop -- a wide arc, but slow."},
	"wpn_hatchet": {"name": "Hand Hatchet", "category": "weapon", "weapon_type": "melee", "max_stack": 1, "color": Color(0.66, 0.55, 0.4, 1.0),
		"weapon_stats": {"damage": 12, "cooldown": 0.42, "range_offset": 44, "area_size": Vector2(54, 34), "knockback_min": 55.0, "knockback_max": 90.0, "icon_size": Vector2(46, 16), "icon_color": Color(0.66, 0.55, 0.4), "icon_offset": 20.0},
		"unique_desc": "A choppy little axe with a solid shove."},
	# COMMON spear / bow / wand
	"wpn_woodspear": {"name": "Woodspear", "category": "weapon", "weapon_type": "spear", "max_stack": 1, "color": Color(0.6, 0.48, 0.32, 1.0),
		"weapon_stats": {"damage": 18, "cooldown": 0.85, "range_offset": 60, "area_size": Vector2(72, 38), "knockback_min": 45.0, "knockback_max": 70.0, "icon_size": Vector2(66, 8), "icon_color": Color(0.6, 0.48, 0.32), "icon_offset": 24.0},
		"unique_desc": "A sharpened pole -- cheap, long, and slow."},
	"wpn_slingshot": {"name": "Slingshot", "category": "weapon", "weapon_type": "bow", "max_stack": 1, "color": Color(0.55, 0.42, 0.3, 1.0),
		"weapon_stats": {"damage": 8, "cooldown": 0.34, "range_offset": 78, "area_size": Vector2(100, 34), "knockback_min": 8.0, "knockback_max": 18.0, "icon_size": Vector2(15, 15), "icon_color": Color(0.55, 0.42, 0.3), "icon_offset": 18.0},
		"unique_desc": "Pelts stones fast -- weak, but relentless."},
	"wpn_huntingbow": {"name": "Hunting Bow", "category": "weapon", "weapon_type": "bow", "max_stack": 1, "color": Color(0.62, 0.5, 0.34, 1.0),
		"weapon_stats": {"damage": 15, "cooldown": 0.5, "range_offset": 92, "area_size": Vector2(110, 40), "knockback_min": 22.0, "knockback_max": 44.0, "icon_size": Vector2(15, 15), "icon_color": Color(0.62, 0.5, 0.34), "icon_offset": 18.0},
		"unique_desc": "A steady woodland bow."},
	# NOTE (audit fix): a wand with NO "special" key is routed to the ADMIN
	# screen-nuke by perform_attack -- these three loot wands shipped without one
	# and one-clicked the whole dungeon to death. Their damage now lives in a real
	# bolt special (weapon_stats.damage 0, like every other special wand).
	"wpn_sparkwand": {"name": "Spark Wand", "category": "weapon", "weapon_type": "wand", "max_stack": 1, "color": Color(0.6, 0.7, 0.95, 1.0), "mana_cost": 4,
		"weapon_stats": {"damage": 0, "cooldown": 0.44, "range_offset": 30, "area_size": Vector2(10, 10), "knockback_min": 0.0, "knockback_max": 0.0, "icon_size": Vector2(48, 8), "icon_color": Color(0.6, 0.7, 0.95), "icon_offset": 20.0},
		"special": {"type": "frost_shard", "damage": 10, "speed": 560.0, "range": 460.0},
		"unique_desc": "A cheap caster's spark -- light on mana."},
	# UNCOMMON melee
	"wpn_falchion": {"name": "Falchion", "category": "weapon", "weapon_type": "melee", "max_stack": 1, "color": Color(0.8, 0.72, 0.55, 1.0),
		"weapon_stats": {"damage": 16, "cooldown": 0.4, "range_offset": 50, "area_size": Vector2(66, 40), "knockback_min": 30.0, "knockback_max": 60.0, "icon_size": Vector2(54, 14), "icon_color": Color(0.8, 0.72, 0.55), "icon_offset": 20.0},
		"unique_desc": "A curved slasher -- wide and quick."},
	"wpn_warpick": {"name": "War Pick", "category": "weapon", "weapon_type": "melee", "max_stack": 1, "color": Color(0.55, 0.56, 0.6, 1.0),
		"weapon_stats": {"damage": 20, "cooldown": 0.72, "range_offset": 46, "area_size": Vector2(50, 30), "knockback_min": 65.0, "knockback_max": 105.0, "icon_size": Vector2(48, 12), "icon_color": Color(0.55, 0.56, 0.6), "icon_offset": 20.0},
		"unique_desc": "A brutal pick -- narrow, heavy, huge knockback."},
	"wpn_twinblades": {"name": "Twin Fangs", "category": "weapon", "weapon_type": "melee", "max_stack": 1, "color": Color(0.72, 0.74, 0.82, 1.0),
		"weapon_stats": {"damage": 6, "cooldown": 0.18, "range_offset": 42, "area_size": Vector2(46, 28), "knockback_min": 12.0, "knockback_max": 24.0, "icon_size": Vector2(42, 14), "icon_color": Color(0.72, 0.74, 0.82), "icon_offset": 20.0},
		"unique_desc": "Two blades in a blur -- the fastest strikes around."},
	"wpn_saber": {"name": "Cavalry Saber", "category": "weapon", "weapon_type": "melee", "max_stack": 1, "color": Color(0.82, 0.78, 0.6, 1.0),
		"weapon_stats": {"damage": 13, "cooldown": 0.32, "range_offset": 54, "area_size": Vector2(60, 32), "knockback_min": 28.0, "knockback_max": 52.0, "icon_size": Vector2(56, 12), "icon_color": Color(0.82, 0.78, 0.6), "icon_offset": 21.0},
		"unique_desc": "A long, curved saber -- quick and reaching."},
	# UNCOMMON spear / bow / wand
	"wpn_trident": {"name": "Trident", "category": "weapon", "weapon_type": "spear", "max_stack": 1, "color": Color(0.5, 0.7, 0.75, 1.0),
		"weapon_stats": {"damage": 17, "cooldown": 0.7, "range_offset": 55, "area_size": Vector2(80, 46), "knockback_min": 35.0, "knockback_max": 65.0, "icon_size": Vector2(64, 12), "icon_color": Color(0.5, 0.7, 0.75), "icon_offset": 24.0},
		"unique_desc": "Three prongs -- a wide, hard thrust."},
	"wpn_warglaive": {"name": "War Glaive", "category": "weapon", "weapon_type": "spear", "max_stack": 1, "color": Color(0.6, 0.6, 0.65, 1.0),
		"weapon_stats": {"damage": 18, "cooldown": 0.78, "range_offset": 55, "area_size": Vector2(86, 48), "knockback_min": 40.0, "knockback_max": 72.0, "icon_size": Vector2(68, 10), "icon_color": Color(0.6, 0.6, 0.65), "icon_offset": 24.0},
		"unique_desc": "A long polearm that sweeps a huge arc."},
	"wpn_crossbow": {"name": "Crossbow", "category": "weapon", "weapon_type": "bow", "max_stack": 1, "color": Color(0.5, 0.4, 0.32, 1.0),
		"weapon_stats": {"damage": 25, "cooldown": 0.85, "range_offset": 96, "area_size": Vector2(110, 40), "knockback_min": 30.0, "knockback_max": 58.0, "icon_size": Vector2(15, 15), "icon_color": Color(0.5, 0.4, 0.32), "icon_offset": 18.0},
		"unique_desc": "Slow to crank, but the bolt hits like a hammer."},
	"wpn_flatbow": {"name": "Flatbow", "category": "weapon", "weapon_type": "bow", "max_stack": 1, "color": Color(0.68, 0.56, 0.38, 1.0),
		"weapon_stats": {"damage": 12, "cooldown": 0.4, "range_offset": 92, "area_size": Vector2(110, 40), "knockback_min": 18.0, "knockback_max": 36.0, "icon_size": Vector2(15, 15), "icon_color": Color(0.68, 0.56, 0.38), "icon_offset": 18.0},
		"unique_desc": "A fast flatbow -- a quicker draw for less punch."},
	"wpn_frostwand": {"name": "Novice Frost Wand", "category": "weapon", "weapon_type": "wand", "max_stack": 1, "color": Color(0.6, 0.85, 1.0, 1.0), "mana_cost": 7,
		"weapon_stats": {"damage": 0, "cooldown": 0.5, "range_offset": 30, "area_size": Vector2(10, 10), "knockback_min": 0.0, "knockback_max": 0.0, "icon_size": Vector2(50, 8), "icon_color": Color(0.6, 0.85, 1.0), "icon_offset": 20.0},
		"special": {"type": "frost_shard", "damage": 13, "speed": 580.0, "range": 500.0, "status": {"kind": "slow", "dur": 1.6, "mag": 0.75}},
		"unique_desc": "A chill bolt for a beginner cryomancer -- briefly slows what it strikes."},
	# THE SOUL SPLIT WAND (GAME_BIBLE 9.7, design locked) -- a novelty that splits
	# anything into 7 harmless mini-clones for 4 seconds. Deliberately useless
	# against every creature in the game... except the one it was made for: the
	# Monarch of Despair's fragments ARE damageable (9.5). Ada Brook's bond
	# hands it over EARLY as her grandmother's junk (the joke phase, 12.2);
	# the Ten's gathering and the finale reveal what it is. Never drops,
	# never sold, never stocked -- and graded COMMON on purpose: a family
	# trinket must not glow. Toren's "reforging" at the gathering is the
	# story's upgrade; the wand window never read the grade anyway.
	"wpn_soulsplit": {
		"name": "Soul Split Wand", "category": "weapon", "weapon_type": "wand", "max_stack": 1,
		"color": Color(0.95, 0.8, 1.0, 1.0), "mana_cost": 15,
		"weapon_stats": {"damage": 0, "cooldown": 20.0, "range_offset": 30, "area_size": Vector2(10, 10), "knockback_min": 0.0, "knockback_max": 0.0, "icon_size": Vector2(46, 8), "icon_color": Color(0.95, 0.8, 1.0), "icon_offset": 18.0},
		"special": {"type": "soul_split", "speed": 640.0, "range": 620.0},
		"unique_desc": "It fires... something? Splits what it strikes into seven tiny spinning copies for a moment -- completely harmless. Somebody's grandmother swore it would matter one day."},
	"wpn_channelwand": {"name": "Channeling Wand", "category": "weapon", "weapon_type": "wand", "max_stack": 1, "color": Color(0.8, 0.6, 0.95, 1.0), "mana_cost": 3,
		"weapon_stats": {"damage": 0, "cooldown": 0.28, "range_offset": 30, "area_size": Vector2(10, 10), "knockback_min": 0.0, "knockback_max": 0.0, "icon_size": Vector2(48, 8), "icon_color": Color(0.8, 0.6, 0.95), "icon_offset": 20.0},
		"special": {"type": "frost_shard", "damage": 8, "speed": 620.0, "range": 440.0},
		"unique_desc": "Rapid little bolts -- cheap and fast."},
}

# ---------------------------------------------------------------------------
# GRADES / RARITY. Every weapon, armour piece, and relic has a grade -- a
# 6-rank ladder from Common to Mythic. Grade drives two things:
#   1. the rarity COLOUR shown on the item (name/border), and
#   2. a passive "upgrade-everything" bundle a WEAPON grants while wielded
#      (GRADE_PASSIVES) -- so higher-grade weapons make you universally
#      stronger, not just via their attack. Folded into GameState via
#      get_weapon_passive_total(). Materials/currency are ungraded.
# ---------------------------------------------------------------------------
const GRADE_DEFS = {
	# EIGHT TIERS (dev 2026-07-28, Terraria-ladder example, "make 8 tiers of
	# items"): the six familiar grades keep their ranks (no def or save ever
	# moves), crowned by two new deep-end tiers -- ASCENDED for the floors past
	# 70, MONARCH for the endgame peak (finale rewards, the flagships).
	"common":    {"name": "Common",    "rank": 1, "color": Color(0.72, 0.74, 0.78)},
	"uncommon":  {"name": "Uncommon",  "rank": 2, "color": Color(0.4, 0.82, 0.42)},
	"rare":      {"name": "Rare",      "rank": 3, "color": Color(0.35, 0.62, 1.0)},
	"epic":      {"name": "Epic",      "rank": 4, "color": Color(0.72, 0.42, 0.96)},
	"legendary": {"name": "Legendary", "rank": 5, "color": Color(1.0, 0.66, 0.16)},
	"mythic":    {"name": "Mythic",    "rank": 6, "color": Color(1.0, 0.32, 0.46)},
	"ascended":  {"name": "Ascended",  "rank": 7, "color": Color(0.3, 0.95, 1.0)},
	# Monarch was orange (1.0,0.45,0.12) -- nearly the same amber as Legendary, so
	# the flagship endgame tier read as legendary at a glance. A luminous royal
	# gold (the Shadow Monarch's crown) is unmistakable against every other tier
	# (polish 2026-07-28).
	"monarch":   {"name": "Monarch",   "rank": 8, "color": Color(1.0, 0.9, 0.5)},
}

# The passive stat bundle a weapon of each grade grants while wielded. Common
# barely nudges one stat; Mythic significantly lifts almost everything. A
# weapon may override with its own "passive" dict, else it inherits its grade's.
const GRADE_PASSIVES = {
	"common":    {"max_health": 5.0},
	"uncommon":  {"max_health": 10.0, "move_speed": 0.02},
	"rare":      {"max_health": 18.0, "move_speed": 0.03, "melee_damage": 0.03, "bow_damage": 0.03, "wand_damage": 0.03},
	"epic":      {"max_health": 30.0, "max_mana": 15.0, "move_speed": 0.05, "melee_damage": 0.05, "bow_damage": 0.05, "wand_damage": 0.05, "gold_gain": 0.05},
	"legendary": {"max_health": 45.0, "max_mana": 25.0, "move_speed": 0.07, "melee_damage": 0.08, "bow_damage": 0.08, "wand_damage": 0.08, "gold_gain": 0.08, "xp_gain": 0.08},
	"mythic":    {"max_health": 70.0, "max_mana": 40.0, "move_speed": 0.10, "melee_damage": 0.12, "bow_damage": 0.12, "wand_damage": 0.12, "gold_gain": 0.10, "xp_gain": 0.10},
	"ascended":  {"max_health": 100.0, "max_mana": 55.0, "move_speed": 0.12, "melee_damage": 0.16, "bow_damage": 0.16, "wand_damage": 0.16, "gold_gain": 0.12, "xp_gain": 0.12},
	"monarch":   {"max_health": 140.0, "max_mana": 75.0, "move_speed": 0.15, "melee_damage": 0.20, "bow_damage": 0.20, "wand_damage": 0.20, "gold_gain": 0.15, "xp_gain": 0.15},
}

# Central grade assignment -- one place instead of a field on every def.
const ITEM_GRADES = {
	# weapons
	"wpn_sword": "common", "wpn_spear": "common", "wpn_bow": "common", "wpn_wand": "common",
	"tool_axe": "common", "tool_pickaxe": "common", "tool_pickaxe_ember": "rare", "tool_pickaxe_blight": "epic", "wpn_admin_ruin": "mythic",
	"wpn_windcutter": "rare", "wpn_sunderer": "rare", "wpn_stormlance": "rare",
	"wpn_stormvolley": "rare", "wpn_seeker": "rare", "wpn_emberstaff": "rare", "wpn_iciclewand": "rare",
	# wave-1 behavior carriers (weapons overhaul 2026-07-28)
	"wpn_boughstaff": "uncommon", "wpn_trickbolt": "rare", "wpn_shardmother": "rare",
	"wpn_petardcane": "rare", "wpn_wardtotem": "rare",
	"wpn_soulwheel": "epic", "wpn_emberlash": "epic", "wpn_stormtome": "epic",
	"wpn_claymore": "epic", "wpn_recurve": "epic", "wpn_scepter": "epic",
	"exc_vampiric": "legendary", "exc_thunder": "legendary", "exc_midas": "legendary",
	"exc_echo": "legendary", "exc_soul": "legendary", "exc_hook": "legendary",
	"exc_boomerang": "legendary", "exc_chrono": "legendary", "wpn_tempest": "legendary",
	"exc_wizardsbane": "mythic", "exc_ragnarok": "mythic", "exc_doom": "mythic", "exc_singularity": "mythic",
	"exc_worldsplitter": "mythic", "exc_dawnbreaker": "legendary",
	# armour
	"helm_leather": "uncommon", "armor_leather": "uncommon", "pants_leather": "uncommon",
	"helm_bulwark": "epic", "armor_bulwark": "epic", "pants_bulwark": "epic",
	"helm_windstalker": "epic", "armor_windstalker": "epic", "pants_windstalker": "epic",
	"helm_runeweave": "epic", "armor_runeweave": "epic", "pants_runeweave": "epic",
	# relics
	"relic_vigor": "uncommon", "relic_swiftness": "uncommon", "relic_greed": "uncommon", "relic_wisdom": "uncommon",
	"relic_berserker": "rare", "relic_hawk": "rare", "relic_archon": "rare", "relic_wellspring": "rare",
	"relic_mountain": "rare", "relic_sylvan": "rare", "relic_feather": "rare", "relic_wings": "legendary",
	"relic_godheart": "mythic", "relic_warlord": "mythic", "relic_fortune": "legendary", "relic_celerity": "mythic",
	"relic_phoenix": "mythic", "relic_thorns": "epic", "relic_aegis": "epic", "relic_vampire": "legendary", "relic_juggernaut": "legendary",
	"relic_blink": "rare", "relic_reaper": "legendary", "relic_ward": "rare", "relic_steward": "rare",
	"relic_gorgon": "epic",
	"rune_sanctuary": "epic", "rune_stoneguise": "legendary", "rune_riddlestaff": "mythic",
	# fishing (pillar 3)
	"fish_silverfin": "common", "fish_mudwhisker": "common", "fish_lanterneel": "uncommon",
	"fish_kingsjaw": "rare", "fish_palegulper": "rare", "junk_boot": "common",
	"crate_driftwood": "uncommon", "crate_pearlbound": "epic",
	"tear_pale": "uncommon", "potion_tears": "rare", "relic_mourner": "legendary",
	"tool_rod_willow": "common", "tool_rod_wyrmbone": "rare", "tool_rod_moonline": "legendary",
	"relic_tidewalker": "legendary",
	"odd_glassfin": "rare", "odd_inkmaw": "rare", "odd_bellsnail": "rare",
	"odd_twicefish": "rare", "odd_sorrowcarp": "rare",
	# batch: new armour
	"gloves_leather": "uncommon", "gloves_iron": "rare", "gloves_assassin": "epic", "gloves_titan": "mythic",
	"boots_leather": "uncommon", "boots_swift": "rare", "boots_storm": "epic", "boots_titan": "mythic",
	"helm_ranger": "rare", "armor_ranger": "rare", "pants_ranger": "rare",
	"helm_dragon": "mythic", "armor_dragon": "mythic", "pants_dragon": "mythic", "gloves_dragon": "mythic", "boots_dragon": "mythic",
	# the two peaks (2026-07-28)
	"helm_void": "ascended", "armor_void": "ascended", "pants_void": "ascended",
	"helm_regal": "monarch", "armor_regal": "monarch", "pants_regal": "monarch",
	# batch: new weapons
	"wpn_club": "common", "wpn_shortbow": "uncommon", "wpn_apprentice_wand": "uncommon", "wpn_dagger": "uncommon",
	"wpn_mace": "uncommon", "wpn_javelin": "uncommon", "wpn_greatsword": "rare", "wpn_katana": "rare",
	"wpn_warhammer": "rare", "wpn_harpoon": "rare",
	"exc_shadowblade": "legendary", "exc_earthshaker": "mythic", "exc_gungnir": "mythic",
	"exc_frostmourne": "mythic", "exc_voidcaller": "mythic", "exc_stormfury": "mythic",
	# grade-fill weapons (WEAPONS.md Ã‚Â§3) -- early variety
	"wpn_shortsword": "common", "wpn_rapier": "common", "wpn_cleaver": "common", "wpn_hatchet": "common",
	"wpn_woodspear": "common", "wpn_slingshot": "common", "wpn_huntingbow": "common", "wpn_sparkwand": "common",
	"wpn_falchion": "uncommon", "wpn_warpick": "uncommon", "wpn_twinblades": "uncommon", "wpn_saber": "uncommon",
	"wpn_trident": "uncommon", "wpn_warglaive": "uncommon", "wpn_crossbow": "uncommon", "wpn_flatbow": "uncommon",
	"wpn_frostwand": "uncommon", "wpn_channelwand": "uncommon",
	"wpn_soulsplit": "common",   # grandmother's junk must not glow (12.2)
	"relic_rewound_hour": "mythic",
	"sorrowshard": "epic",
	# --- hidden event-boss loot (grade tracks the boss's difficulty) ---
	# Medium = Epic
	"evt_ledger": "epic", "evt_coinbite": "epic", "evt_hoarfrost": "epic",
	"evt_rimeglass": "epic", "evt_bramblewhip": "epic", "evt_thornvolley": "epic",
	"relic_usurer": "epic", "relic_rimeheart": "epic", "relic_verdant": "epic",
	# Hard = Legendary
	"evt_tiderender": "legendary", "evt_deepcaller": "legendary", "evt_pyreblade": "legendary",
	"evt_emberking": "legendary", "evt_vigil": "legendary", "evt_wakeful": "legendary",
	"relic_pearl": "legendary", "relic_effigy": "legendary", "relic_unblinking": "legendary",
	"armor_ember": "legendary",
	# Very Hard = Mythic
	"evt_scythe": "mythic", "evt_wail": "mythic", "evt_pretender": "mythic",
	"evt_usurper": "mythic", "evt_houndsfang": "mythic", "evt_coursing": "mythic",
	"relic_widow": "mythic", "relic_hollow": "mythic", "relic_hound": "mythic",
	"helm_mourn": "mythic",
	# Expert = Ascended / Monarch
	"evt_endbringer": "monarch", "evt_stareater": "ascended",
	"relic_lasthour": "monarch", "armor_unmade": "ascended",
	# Master (11th capstone) = Monarch
	"evt_huntcrown": "monarch", "evt_huntbow": "monarch", "relic_huntmaster": "monarch",
}

# Crafting recipes: item_id -> {ingredient_id: count}. Food + the Reset Potion
# are craftable; HP/Mana potions are deliberately DROP-ONLY (not here). See
# GameState.try_craft and the crafting popup in inventory_ui.
const CRAFT_RECIPES = {
	# --- THE PLAIN LADDERS (221/129 mix, resplit 2026-07-28: plains shifted
	# EARLIER per dev -- T1-T3 are ladder country, the late names keep souls).
	# 23 families; every rung forges from its predecessor + tier materials.
	"wpn_rustfang": {"wpn_barrelstave": 1, "iron_shard": 4},
	"wpn_millsickle": {"wpn_rustfang": 1, "iron_shard": 4},
	"wpn_curseknife": {"wpn_millsickle": 1, "iron_shard": 8, "stone": 6},
	"wpn_tithegather": {"wpn_curseknife": 1, "iron_shard": 8, "stone": 6},
	"wpn_tolloftheend": {"wpn_tithegather": 1, "ember_crystal": 4},
	"wpn_griefedge": {"wpn_tolloftheend": 1, "void_essence": 3},
	"wpn_thistleflail": {"wpn_cellarmallet": 1, "iron_shard": 4},
	"wpn_orchardaxe": {"wpn_thistleflail": 1, "iron_shard": 4},
	"wpn_furrowscythe": {"wpn_orchardaxe": 1, "iron_shard": 8, "stone": 6},
	"wpn_watchmansword": {"wpn_furrowscythe": 1, "iron_shard": 8, "stone": 6},
	"wpn_vespersting": {"wpn_watchmansword": 1, "ember_crystal": 4},
	"wpn_requiemedge": {"wpn_vespersting": 1, "void_essence": 3},
	"wpn_bonepick": {"wpn_hearthpoker": 1, "iron_shard": 4},
	"wpn_ratterdart": {"wpn_bonepick": 1, "iron_shard": 4},
	"wpn_hookbill": {"wpn_ratterdart": 1, "iron_shard": 8, "stone": 6},
	"wpn_barrowmaul": {"wpn_hookbill": 1, "ember_crystal": 4},
	"wpn_asphodelknife": {"wpn_barrowmaul": 1, "ember_crystal": 8},
	"wpn_sorrowfang": {"wpn_asphodelknife": 1, "void_essence": 3},
	"wpn_coldiron": {"wpn_mongrelknife": 1, "iron_shard": 4},
	"wpn_tannerknife": {"wpn_coldiron": 1, "iron_shard": 4},
	"wpn_quarrymaul": {"wpn_tannerknife": 1, "iron_shard": 8, "stone": 6},
	"wpn_duskrender": {"wpn_quarrymaul": 1, "ember_crystal": 4},
	"wpn_daybreakedge": {"wpn_duskrender": 1, "ember_crystal": 8},
	"wpn_gravespade": {"wpn_oakcudgel": 1, "iron_shard": 4},
	"wpn_adderfang": {"wpn_gravespade": 1, "iron_shard": 8, "stone": 6},
	"wpn_sextonblade": {"wpn_adderfang": 1, "iron_shard": 8, "stone": 6},
	"wpn_eveningblade": {"wpn_sextonblade": 1, "ember_crystal": 4},
	"wpn_hourmaul": {"wpn_eveningblade": 1, "ember_crystal": 8},
	"wpn_lanternblade": {"wpn_pitshovel": 1, "iron_shard": 4},
	"wpn_bellhammer": {"wpn_lanternblade": 1, "iron_shard": 8, "stone": 6},
	"wpn_squallblade": {"wpn_bellhammer": 1, "iron_shard": 8, "stone": 6},
	"wpn_palefang": {"wpn_squallblade": 1, "ember_crystal": 4},
	"wpn_lastlantern": {"wpn_palefang": 1, "ember_crystal": 8},
	"wpn_emberdart": {"wpn_crowbow": 1, "iron_shard": 4},
	"wpn_finchvolley": {"wpn_emberdart": 1, "iron_shard": 8, "stone": 6},
	"wpn_choirbow": {"wpn_finchvolley": 1, "ember_crystal": 4},
	"wpn_needlerain": {"wpn_choirbow": 1, "ember_crystal": 4},
	"wpn_ferrybow": {"wpn_gutterbow": 1, "iron_shard": 4},
	"wpn_larkbow": {"wpn_ferrybow": 1, "iron_shard": 8, "stone": 6},
	"wpn_curfewbow": {"wpn_larkbow": 1, "ember_crystal": 4},
	"wpn_sapperanswer": {"wpn_curfewbow": 1, "ember_crystal": 4},
	"wpn_paleflight": {"wpn_orchardbow": 1, "iron_shard": 4},
	"wpn_lightstep": {"wpn_paleflight": 1, "iron_shard": 8, "stone": 6},
	"wpn_glasstring": {"wpn_lightstep": 1, "ember_crystal": 4},
	"wpn_sapperkiss": {"wpn_glasstring": 1, "ember_crystal": 4},
	"wpn_stingerbow": {"wpn_sparrowbow": 1, "iron_shard": 4},
	"wpn_shrikebow": {"wpn_stingerbow": 1, "iron_shard": 8, "stone": 6},
	"wpn_gravebow": {"wpn_shrikebow": 1, "ember_crystal": 4},
	"wpn_lastlark": {"wpn_gravebow": 1, "ember_crystal": 8},
	"wpn_bogmortar": {"wpn_ashbow": 1, "iron_shard": 8, "stone": 6},
	"wpn_twinnock": {"wpn_bogmortar": 1, "iron_shard": 8, "stone": 6},
	"wpn_hummingbow": {"wpn_twinnock": 1, "ember_crystal": 4},
	"wpn_wintermark": {"wpn_hummingbow": 1, "ember_crystal": 8},
	"wpn_emberarc": {"wpn_bramblebow": 1, "iron_shard": 8, "stone": 6},
	"wpn_veilbow": {"wpn_emberarc": 1, "iron_shard": 8, "stone": 6},
	"wpn_larkstorm": {"wpn_veilbow": 1, "ember_crystal": 4},
	"wpn_ghostrepeater": {"wpn_larkstorm": 1, "void_essence": 3},
	"wpn_frostprong": {"wpn_eelspear": 1, "iron_shard": 4},
	"wpn_harrowpike": {"wpn_frostprong": 1, "iron_shard": 8, "stone": 6},
	"wpn_galeprong": {"wpn_harrowpike": 1, "ember_crystal": 4},
	"wpn_vigilpike": {"wpn_galeprong": 1, "ember_crystal": 4},
	"wpn_horizonpike": {"wpn_vigilpike": 1, "void_essence": 3},
	"wpn_reedjavelin": {"wpn_fencepike": 1, "iron_shard": 4},
	"wpn_heronlance": {"wpn_reedjavelin": 1, "iron_shard": 8, "stone": 6},
	"wpn_hawkvolley": {"wpn_heronlance": 1, "ember_crystal": 4},
	"wpn_winterreach": {"wpn_hawkvolley": 1, "ember_crystal": 4},
	"wpn_worldspike": {"wpn_winterreach": 1, "void_essence": 3},
	"wpn_wallpike": {"wpn_haypike": 1, "iron_shard": 4},
	"wpn_lamplighter": {"wpn_wallpike": 1, "iron_shard": 8, "stone": 6},
	"wpn_marrowprong": {"wpn_lamplighter": 1, "ember_crystal": 4},
	"wpn_borderpike": {"wpn_marrowprong": 1, "ember_crystal": 8},
	"wpn_gatecleaver": {"wpn_boarspit": 1, "iron_shard": 8, "stone": 6},
	"wpn_reedvolley": {"wpn_gatecleaver": 1, "iron_shard": 8, "stone": 6},
	"wpn_midnightlance": {"wpn_reedvolley": 1, "ember_crystal": 4},
	"wpn_finalverdict": {"wpn_midnightlance": 1, "ember_crystal": 8},
	"wpn_gullprong": {"wpn_ditchpike": 1, "iron_shard": 8, "stone": 6},
	"wpn_stormprong": {"wpn_gullprong": 1, "iron_shard": 8, "stone": 6},
	"wpn_sunderpike": {"wpn_stormprong": 1, "ember_crystal": 4},
	"wpn_moonreach": {"wpn_sunderpike": 1, "ember_crystal": 8},
	"wpn_brookwand": {"wpn_chalkwand": 1, "iron_shard": 4},
	"wpn_leechwand": {"wpn_brookwand": 1, "iron_shard": 4},
	"wpn_finchbolt": {"wpn_leechwand": 1, "iron_shard": 8, "stone": 6},
	"wpn_pyrelight": {"wpn_finchbolt": 1, "iron_shard": 8, "stone": 6},
	"wpn_magmawrit": {"wpn_pyrelight": 1, "ember_crystal": 4},
	"wpn_cinderrod": {"wpn_stubwand": 1, "iron_shard": 4},
	"wpn_mosswand": {"wpn_cinderrod": 1, "iron_shard": 4},
	"wpn_hollowbolt": {"wpn_mosswand": 1, "iron_shard": 8, "stone": 6},
	"wpn_saltwand": {"wpn_hollowbolt": 1, "iron_shard": 8, "stone": 6},
	"wpn_stormsliver": {"wpn_saltwand": 1, "ember_crystal": 4},
	"wpn_foxfirewand": {"wpn_tallowwand": 1, "iron_shard": 4},
	"wpn_courierrod": {"wpn_foxfirewand": 1, "iron_shard": 8, "stone": 6},
	"wpn_leadrod": {"wpn_courierrod": 1, "iron_shard": 8, "stone": 6},
	"wpn_frostwrit": {"wpn_leadrod": 1, "ember_crystal": 4},
	"wpn_gooseherd": {"wpn_reedstaff": 1, "iron_shard": 4},
	"wpn_wellstaff": {"wpn_gooseherd": 1, "iron_shard": 8, "stone": 6},
	"wpn_pilgrimstaff": {"wpn_wellstaff": 1, "ember_crystal": 4},
	"wpn_summitstaff": {"wpn_pilgrimstaff": 1, "ember_crystal": 8},
	"wpn_twelfthpillar": {"wpn_summitstaff": 1, "void_essence": 3},
	"wpn_droverstaff": {"wpn_willowswitch": 1, "iron_shard": 8, "stone": 6},
	"wpn_fordstaff": {"wpn_droverstaff": 1, "ember_crystal": 4},
	"wpn_cloudcounter": {"wpn_fordstaff": 1, "ember_crystal": 8},
	"wpn_skyladder": {"wpn_cloudcounter": 1, "void_essence": 3},
	"wpn_shepherdstaff": {"wpn_ferrypole": 1, "iron_shard": 8, "stone": 6},
	"wpn_paleobelisk": {"wpn_shepherdstaff": 1, "ember_crystal": 4},
	"wpn_graniteway": {"wpn_paleobelisk": 1, "ember_crystal": 8},
	"wpn_stillmountain": {"wpn_graniteway": 1, "void_essence": 3},
	"potion_tears": {"tear_pale": 3, "herb": 1},
	"food_stew": {"herb": 2, "raw_meat": 1},
	"food_feast": {"raw_meat": 3, "herb": 1},
	"food_sage": {"herb": 3, "slime": 1},
	"potion_reset": {"void_essence": 2, "slime": 5},
	# --- event-boss re-summon tokens: spend the boss's trophy (+ a binder) to
	# forge a token that wakes it again on demand (2026-07-28). ---
	"token_tallyman": {"mat_debtcoin": 1, "slime": 2},
	"token_firstfrost": {"mat_everfrost": 1, "slime": 2},
	"token_gluttonroot": {"mat_heartwood": 1, "slime": 2},
	"token_drowned": {"mat_brine": 1, "iron_shard": 2},
	"token_effigyking": {"mat_pyreash": 1, "iron_shard": 2},
	"token_warden": {"mat_vigilember": 1, "iron_shard": 2},
	"token_griefeater": {"mat_grieftear": 1, "ember_crystal": 2},
	"token_hollowcrown": {"mat_crownshard": 1, "ember_crystal": 2},
	"token_sablehound": {"mat_sableichor": 1, "ember_crystal": 2},
	"token_nihil": {"mat_unmade": 1, "void_essence": 2},
	# Nihil's FIRST rite: three other bosses' trophies bind the Duskmoon Effigy.
	"duskmoon_effigy": {"mat_everfrost": 1, "mat_pyreash": 1, "mat_grieftear": 1, "void_essence": 2},
	# THE CAPSTONE: a trophy of all ten hidden bosses forges the Hunter's Horn.
	"hunters_horn": {"mat_debtcoin": 1, "mat_everfrost": 1, "mat_heartwood": 1, "mat_brine": 1,
		"mat_pyreash": 1, "mat_vigilember": 1, "mat_grieftear": 1, "mat_crownshard": 1,
		"mat_sableichor": 1, "mat_unmade": 1, "ancient_relic": 2},
}

static func get_grade(item_id: String) -> String:
	# the generated ladder (weapon_roster.gd) answers for its own ids -- to
	# every caller a roster weapon is an ordinary graded item
	if not ITEM_GRADES.has(item_id) and WeaponRoster.has_id(item_id):
		return WeaponRoster.get_grade(item_id)
	return ITEM_GRADES.get(item_id, "")

static func get_grade_color(item_id: String) -> Color:
	var g = get_grade(item_id)
	return GRADE_DEFS.get(g, {}).get("color", Color(0.8, 0.8, 0.8))

static func get_grade_name(item_id: String) -> String:
	var g = get_grade(item_id)
	return GRADE_DEFS.get(g, {}).get("name", "")

# The passive stat bundle a weapon grants while wielded: its own "passive"
# override, else the bundle for its grade. Non-weapons return {}.
static func get_weapon_passive(item_id: String) -> Dictionary:
	var def = get_item_def(item_id)
	if def.get("category", "") != "weapon":
		return {}
	if def.has("passive"):
		return def.passive
	return GRADE_PASSIVES.get(get_grade(item_id), {})

# Materials masquerade as "Unknown Substance" until the Science Lab has
# researched that type -- the lookup lives here so every UI (inventory,
# skill tree, notifications) shows the same thing.
static func get_display_name(item_id: String) -> String:
	var def = get_item_def(item_id)
	if def.get("is_material", false) and not GameStateRef().researched_materials.has(item_id):
		return "Unknown Substance"
	return def.get("name", item_id)

# The item's name wrapped in its rarity colour as BBCode (name-plate pass
# 2026-07-28): every toast that speaks an item's name shows it the way the
# tooltip does -- a mythic drop reads mythic-red in the corner of your eye,
# Terraria-style. Ungraded items keep their own def colour, brightened for
# legibility on the dark HUD.
static func name_bbcode(item_id: String) -> String:
	var col: Color = get_grade_color(item_id) if get_grade(item_id) != "" \
		else get_item_def(item_id).get("color", Color(0.95, 0.93, 0.85))
	return "[color=#%s]%s[/color]" % [_hex(col.lightened(0.15)), get_display_name(item_id)]

# Item sets. Wearing every armor piece of a set at once grants its "bonus"
# (checked via GameState.is_set_complete / folded into GameState.
# get_bonus_total). A set may also name a "weapon": WIELDING it (hotbar) while
# the armor set is complete stacks the greater "full_bonus" on top -- so a
# full 4-piece class set pays out both tiers at once.
const SET_DEFS = {
	"leather": {
		"name": "Leather Set",
		"pieces": ["helm_leather", "armor_leather", "pants_leather"],
		"bonus_2pc": {"max_health": 10.0},
		"bonus_2pc_desc": "+10 Max HP",
		"bonus": {"max_health": 20.0, "move_speed": 0.05},
		"bonus_desc": "+20 Max HP, +5% Move Speed",
	},
	"bulwark": {
		"name": "Bulwark of the Warlord",
		"pieces": ["helm_bulwark", "armor_bulwark", "pants_bulwark"],
		"bonus_2pc": {"max_health": 20.0},
		"bonus_2pc_desc": "+20 Max HP",
		"bonus": {"max_health": 35.0, "melee_damage": 0.10},
		"bonus_desc": "+35 Max HP, +10% Melee DMG",
		"weapon": "wpn_claymore",
		"full_bonus": {"melee_damage": 0.15, "melee_cooldown": 0.10, "max_health": 25.0},
		"full_bonus_desc": "+15% Melee DMG, -10% Melee CD, +25 Max HP",
	},
	"windstalker": {
		"name": "Windstalker's Garb",
		"pieces": ["helm_windstalker", "armor_windstalker", "pants_windstalker"],
		"bonus_2pc": {"move_speed": 0.05},
		"bonus_2pc_desc": "+5% Move Speed",
		"bonus": {"bow_damage": 0.12, "move_speed": 0.08},
		"bonus_desc": "+12% Bow DMG, +8% Move Speed",
		"weapon": "wpn_recurve",
		"full_bonus": {"bow_damage": 0.15, "bow_cooldown": 0.12, "gold_gain": 0.15},
		"full_bonus_desc": "+15% Bow DMG, -12% Bow CD, +15% Gold",
	},
	"runeweave": {
		"name": "Runeweave Vestments",
		"pieces": ["helm_runeweave", "armor_runeweave", "pants_runeweave"],
		"bonus_2pc": {"max_mana": 20.0},
		"bonus_2pc_desc": "+20 Max Mana",
		"bonus": {"max_mana": 30.0, "mana_regen": 0.5},
		"bonus_desc": "+30 Max Mana, +50% Mana Regen",
		"weapon": "wpn_scepter",
		"full_bonus": {"wand_cooldown": 0.15, "max_mana": 40.0, "mana_regen": 0.5},
		"full_bonus_desc": "-15% Wand CD, +40 Max Mana, +50% Mana Regen",
	},
	# Rare mid-tier set (fills the Uncommon->Epic gap).
	"ranger": {
		"name": "Ranger's Leathers",
		"pieces": ["helm_ranger", "armor_ranger", "pants_ranger"],
		"bonus_2pc": {"max_health": 15.0},
		"bonus_2pc_desc": "+15 Max HP",
		"bonus": {"damage_reduction": 0.06, "move_speed": 0.05, "max_health": 20.0},
		"bonus_desc": "+6% Damage Reduction, +5% Move Speed, +20 HP",
		"weapon": "wpn_shrikebow",
		"full_bonus": {"bow_damage": 0.10, "crit_chance": 0.06, "move_speed": 0.05},
		"full_bonus_desc": "+10% Bow DMG, +6% Crit, +5% Move Speed",
	},
	# Mythic 5-slot endgame set (helmet/chest/pants/gloves/boots).
	"dragonscale": {
		"name": "Dragonscale Panoply",
		# 3 pieces like every set (Terraria-exact armor, 2026-07-28): the old
		# gauntlets/sabatons are bag curios now, and a 5-piece set with only 3
		# wearable slots could never complete
		"pieces": ["helm_dragon", "armor_dragon", "pants_dragon"],
		"bonus_2pc": {"damage_reduction": 0.05, "max_health": 30.0},
		"bonus_2pc_desc": "+5% Damage Reduction, +30 HP",
		"bonus": {"max_health": 80.0, "damage_reduction": 0.10, "melee_damage": 0.10, "crit_damage": 0.25},
		"bonus_desc": "+80 HP, +10% Damage Reduction, +10% Melee DMG, +25% Crit DMG",
		"weapon": "wpn_worldanvil",
		"full_bonus": {"on_hit_burn": 6.0, "melee_damage": 0.10, "max_health": 40.0},
		"full_bonus_desc": "DRAGON'S BREATH: your blows BURN (+6/s), +10% Melee DMG, +40 HP",
	},
	# --- The two peaks (2026-07-28): armor finally reaches the 8-tier
	# ladder's top. Ascended = the untouchable caster-skirmisher; Monarch =
	# all damage, unbowed. Pieces below with the other armor defs. ---
	"voidwalker": {
		"name": "Voidwalker Raiment",
		"pieces": ["helm_void", "armor_void", "pants_void"],
		"bonus_2pc": {"move_speed": 0.06},
		"bonus_2pc_desc": "+6% Move Speed",
		"bonus": {"dodge_chance": 0.08, "max_mana": 40.0, "max_health": 40.0},
		"bonus_desc": "+8% Dodge, +40 Max Mana, +40 HP",
		"weapon": "wpn_summerscoffin",
		"full_bonus": {"wand_damage": 0.15, "mana_regen": 0.5, "dodge_chance": 0.04},
		"full_bonus_desc": "+15% Wand DMG, +50% Mana Regen, +4% Dodge",
	},
	"regalia": {
		"name": "The Sovereign's Regalia",
		"pieces": ["helm_regal", "armor_regal", "pants_regal"],
		"bonus_2pc": {"max_health": 60.0},
		"bonus_2pc_desc": "+60 Max HP",
		"bonus": {"melee_damage": 0.12, "bow_damage": 0.12, "wand_damage": 0.12, "damage_reduction": 0.06},
		"bonus_desc": "+12% ALL DMG, +6% Damage Reduction",
		"weapon": "wpn_worldslash",
		"full_bonus": {"melee_damage": 0.10, "bow_damage": 0.10, "wand_damage": 0.10, "crit_chance": 0.08, "max_health": 50.0},
		"full_bonus_desc": "+10% ALL DMG, +8% Crit, +50 Max HP",
	},
}

const CATEGORY_LABELS = {
	"currency": "Currency", "material": "Material", "armor": "Armor",
	"relic": "Relic", "weapon": "Weapon", "consumable": "Consumable", "misc": "Item",
}
const EFFECT_LABELS = {
	"max_health": "Max HP", "move_speed": "Move Speed", "gold_gain": "Gold",
	"xp_gain": "XP", "melee_damage": "Melee DMG", "bow_damage": "Bow DMG",
	"melee_cooldown": "Melee CD", "bow_cooldown": "Bow CD", "wand_cooldown": "Wand CD",
	"max_mana": "Max Mana", "mana_regen": "Mana Regen", "wand_damage": "Wand DMG",
	"crit_chance": "Crit Chance", "crit_damage": "Crit DMG", "damage_reduction": "Damage Reduction",
	"status_resistance": "Status Resist",
}
# Cooldown effects REDUCE the cooldown, so their lines read "-12% Bow CD".
const COOLDOWN_EFFECT_KEYS = ["melee_cooldown", "bow_cooldown", "wand_cooldown"]
# Boolean-flag effects: shown as a plain phrase, not a "+N%" stat line.
const FLAG_EFFECT_TEXT = {
	"flight": "Flight: hold Space to soar (10s)",
	"fall_immunity": "Negates fall damage",
	# the Wukong runes (2026-07-28): phrases, never "+100% sanctuary"
	"sanctuary": "Ward ring while standing still: enemy shots die at its edge",
	"stone_guise": "Once per floor, the killing blow lands on STONE (1.5s statue, 1 HP)",
	"staff_mastery": "Staff combos hold a beat longer; the pillar slam falls +25%",
}
# The one-row version for tight lists (the equip picker's summary line): the
# full FLAG_EFFECT_TEXT phrases clipped mid-word at picker width (EYES s5).
const FLAG_EFFECT_SHORT = {
	"flight": "Flight",
	"fall_immunity": "No fall damage",
	"sanctuary": "Sanctuary ward",
	"stone_guise": "Stone save (1/floor)",
	"staff_mastery": "Staff mastery",
}

static func get_set(item_id: String) -> String:
	return get_item_def(item_id).get("set", "")

# Multi-line hover description used by the shared item tooltip (item_tooltip.gd)
# in the inventory, chest, and equipment panels.
static func build_tooltip_text(item_id: String) -> String:
	var def = get_item_def(item_id)
	if def.is_empty():
		return item_id
	var lines = []
	lines.append(get_display_name(item_id))
	var cat = get_category(item_id)
	var cat_line = CATEGORY_LABELS.get(cat, "Item")
	if cat == "armor":
		cat_line += " Ã‚Â· " + _slot_word(def.get("slot", ""))
	elif cat == "weapon":
		cat_line += " Ã‚Â· " + str(def.get("weapon_type", "")).capitalize()
		if def.get("excellent", false):
			cat_line += " Ã‚Â· Excellent"
	# lead with the grade so rarity reads first
	var grade_name = get_grade_name(item_id)
	if grade_name != "":
		cat_line = grade_name + " Ã‚Â· " + cat_line
	lines.append(cat_line)

	var set_id = get_set(item_id)
	if set_id != "" and SET_DEFS.has(set_id):
		var sd = SET_DEFS[set_id]
		var have = GameStateRef().set_pieces_equipped(set_id)
		lines.append("Set: %s (%d/%d worn)" % [sd.name, have, sd.pieces.size()])

	if cat == "weapon":
		var ws = def.get("weapon_stats", {})
		if not ws.is_empty():
			var stat_line = "DMG %d Ã‚Â· CD %.2fs" % [shown_damage(item_id), ws.get("cooldown", 0.0)]
			if def.has("mana_cost"):
				stat_line += " Ã‚Â· %d Mana" % int(def.mana_cost)
			lines.append(stat_line)
		if def.has("unique_desc"):
			lines.append("Unique: " + def.unique_desc)
		# the passive stat bundle it grants just for being wielded
		var passive = get_weapon_passive(item_id)
		if not passive.is_empty():
			var parts = []
			for key in passive.keys():
				parts.append(_effect_line(key, passive[key]).strip_edges())
			lines.append("While wielded: " + ", ".join(parts))
		lines.append("Wield from your hotbar (keys 1-0).")
	elif cat == "consumable":
		if def.has("use_desc"):
			lines.append(def.use_desc)
		if CRAFT_RECIPES.has(item_id):
			var parts = []
			for ing in CRAFT_RECIPES[item_id].keys():
				parts.append("%dx %s" % [CRAFT_RECIPES[item_id][ing], get_display_name(ing)])
			lines.append("Craft: " + ", ".join(parts))
		else:
			lines.append("Found as loot only.")
		lines.append("Right-click to use.")
	else:
		for key in def.get("equip_effect", {}).keys():
			lines.append(_effect_line(key, def.equip_effect[key]))
		# relics with a triggered power spell it out
		if def.has("relic_desc"):
			lines.append("Power: " + def.relic_desc)

	if set_id != "" and SET_DEFS.has(set_id):
		var sd2 = SET_DEFS[set_id]
		var full_n = sd2.pieces.size()
		if sd2.has("bonus_2pc_desc"):
			lines.append("Set (2 pc): " + sd2.bonus_2pc_desc)
		lines.append("Set (%d pc): %s" % [full_n, sd2.bonus_desc])
		if sd2.has("weapon"):
			var wpn_name = get_item_def(sd2.weapon).get("name", "set weapon")
			lines.append("+ wield %s: %s" % [wpn_name, sd2.get("full_bonus_desc", "")])

	if def.get("is_material", false) and not GameStateRef().researched_materials.has(item_id):
		lines.append("Unidentified -- research it at the Science Lab.")
	return "\n".join(lines)

static func _slot_word(slot: String) -> String:
	match slot:
		"helmet": return "Helmet"
		"chest": return "Chest"
		"pants": return "Legs"
		"gloves": return "Gloves"
		"boots": return "Boots"
	return slot.capitalize()

# What a piece sells for at a staffed Marketplace stall, by grade (6-rank
# ladder). ONE source of truth so the stall and the tooltip never disagree --
# the stall used to look this up by the lowercase grade KEY against a table
# keyed by NAME, so every item silently sold for 4g. Materials/currency (no
# grade) fall through to the base 4.
const SELL_VALUES = {"": 4, "common": 6, "uncommon": 15, "rare": 40, "epic": 100, "legendary": 250, "mythic": 600, "ascended": 1400, "monarch": 3200}
static func sell_value(item_id: String) -> int:
	return int(SELL_VALUES.get(get_grade(item_id), 4))

# --- TERRARIA-STYLE TOOLTIP (dev ask 2026-07-22) ---
# The plain one-colour text block became a proper item card: the name in its
# rarity colour, the base stats in white, every "+" bonus in green, specials in
# gold, and the sell value in coin-gold at the foot -- the read the dev liked in
# Terraria. Emitted as BBCode for a RichTextLabel (see item_tooltip.gd). The
# older build_tooltip_text stays for any plain-text caller.
const TT_SUB := "8f8f9c"     # grey subtitle (grade . type)
const TT_STAT := "e6e4d6"    # near-white base stat
const TT_PLUS := "74d074"    # green "+" bonus (Terraria's modifier green)
const TT_MANA := "6fc7e8"    # mana cyan
const TT_SPECIAL := "f0c674" # gold: unique / relic power / set
const TT_COIN := "e8c24a"    # coin gold (the value line)
const TT_WARN := "d98a4a"    # unidentified / caution
const TT_HINT := "71717c"    # dim usage hint

static func _hex(c: Color) -> String:
	return "%02x%02x%02x" % [int(round(c.r * 255)), int(round(c.g * 255)), int(round(c.b * 255))]

# cooldown -> a Terraria speed word (faster = lower cooldown)
# A wand's blow lives in its SPECIAL (weapon_stats.damage is 0 by design, so
# swings don't double-dip) -- but a card printing "0 magic damage" is a lie
# (EYES s4, 2026-07-28). Print the number the enemy actually feels.
static func shown_damage(item_id: String) -> int:
	var def = get_item_def(item_id)
	var d := int(def.get("weapon_stats", {}).get("damage", 0))
	if d <= 0:
		d = int(def.get("special", {}).get("damage", 0))
	return d

static func _speed_word(cd: float) -> String:
	if cd <= 0.20: return "Insanely fast"
	if cd <= 0.34: return "Very fast"
	if cd <= 0.55: return "Fast"
	if cd <= 0.80: return "Average"
	if cd <= 1.05: return "Slow"
	return "Very slow"

# weapon_type -> the damage word Terraria prints ("28 melee damage")
static func _dmg_word(wtype: String) -> String:
	match wtype:
		"bow": return "ranged"
		"wand": return "magic"
		"spear", "melee": return "melee"
	return "melee"

static func build_tooltip_bbcode(item_id: String) -> String:
	var def = get_item_def(item_id)
	if def.is_empty():
		return item_id
	var cat = get_category(item_id)
	var lines: Array = []
	# --- name, in its rarity colour, a shade bigger ---
	var name_col: Color = get_grade_color(item_id) if get_grade(item_id) != "" else def.get("color", Color(0.95, 0.93, 0.85))
	lines.append("[font_size=16][color=#%s]%s[/color][/font_size]" % [_hex(name_col.lightened(0.12)), get_display_name(item_id)])
	# --- subtitle: grade . category . type ---
	var sub := ""
	var grade_name = get_grade_name(item_id)
	if grade_name != "":
		sub = grade_name
	var tail: String = CATEGORY_LABELS.get(cat, "Item")
	if cat == "armor":
		tail = _slot_word(def.get("slot", "")) + " Armor"
	elif cat == "weapon":
		tail = str(def.get("weapon_type", "")).capitalize()
		if def.get("excellent", false):
			tail += " Ã‚Â· Excellent"
	sub = (sub + " Ã‚Â· " + tail) if sub != "" else tail
	lines.append("[color=#%s]%s[/color]" % [TT_SUB, sub])

	if cat == "weapon":
		var ws = weapon_stats_for(item_id)
		if not ws.is_empty():
			lines.append("[color=#%s]%d %s damage[/color]" % [TT_STAT, shown_damage(item_id), _dmg_word(str(def.get("weapon_type", "")))])
			lines.append("[color=#%s]%s speed[/color]" % [TT_STAT, _speed_word(float(ws.get("cooldown", 0.5)))])
		if def.has("mana_cost"):
			lines.append("[color=#%s]Uses %d mana[/color]" % [TT_MANA, int(def.mana_cost)])
		if def.has("unique_desc"):
			lines.append("[color=#%s]%s[/color]" % [TT_SPECIAL, def.unique_desc])
		# the passive bundle it grants just for being wielded -> green "+" lines
		var passive = get_weapon_passive(item_id)
		for key in passive.keys():
			lines.append("[color=#%s]%s (while wielded)[/color]" % [TT_PLUS, _effect_line(key, passive[key]).strip_edges()])
	elif cat == "consumable":
		if def.has("use_desc"):
			lines.append("[color=#%s]%s[/color]" % [TT_PLUS, def.use_desc])
		if CRAFT_RECIPES.has(item_id):
			var parts = []
			for ing in CRAFT_RECIPES[item_id].keys():
				parts.append("%dx %s" % [CRAFT_RECIPES[item_id][ing], get_display_name(ing)])
			lines.append("[color=#%s]Craft: %s[/color]" % [TT_HINT, ", ".join(parts)])
	elif cat == "armor" or cat == "relic":
		for key in def.get("equip_effect", {}).keys():
			lines.append("[color=#%s]%s[/color]" % [TT_PLUS, _effect_line(key, def.equip_effect[key]).strip_edges()])
		if def.has("relic_desc"):
			lines.append("[color=#%s]%s[/color]" % [TT_SPECIAL, def.relic_desc])

	# set membership + its bonuses (weapon or armour)
	var set_id = get_set(item_id)
	if set_id != "" and SET_DEFS.has(set_id):
		var sd = SET_DEFS[set_id]
		var have = GameStateRef().set_pieces_equipped(set_id)
		lines.append("[color=#%s]Set: %s (%d/%d worn)[/color]" % [TT_SPECIAL, sd.name, have, sd.pieces.size()])
		if sd.has("bonus_2pc_desc"):
			lines.append("[color=#%s]  2 pc: %s[/color]" % [TT_SPECIAL, sd.bonus_2pc_desc])
		lines.append("[color=#%s]  %d pc: %s[/color]" % [TT_SPECIAL, sd.pieces.size(), sd.bonus_desc])

	if def.get("is_material", false) and not GameStateRef().researched_materials.has(item_id):
		lines.append("[color=#%s]Unidentified Ã¢â‚¬â€ research it at the Science Lab[/color]" % TT_WARN)

	# --- footer: what it's worth, in coin gold (real stall price) ---
	if cat in ["weapon", "armor", "relic", "consumable", "material"] and not def.get("is_currency", false):
		lines.append("[color=#%s]Sells for %dg[/color]" % [TT_COIN, sell_value(item_id)])

	# --- footer: the one-line usage hint, dimmed ---
	var hint := ""
	if cat == "weapon": hint = "Wield from your hotbar (keys 1-0)"
	elif cat == "consumable": hint = "Right-click to use"
	elif cat == "armor" or cat == "relic": hint = "Equip from your gear panel (TAB)"
	if hint != "":
		lines.append("[color=#%s]%s[/color]" % [TT_HINT, hint])

	return "\n".join(lines)

static func _effect_line(key: String, val) -> String:
	if FLAG_EFFECT_TEXT.has(key):
		return FLAG_EFFECT_TEXT[key]
	var label = EFFECT_LABELS.get(key, key.replace("_", " ").capitalize())
	if key == "max_health" or key == "max_mana":
		return "+%d %s" % [int(val), label]
	if key in COOLDOWN_EFFECT_KEYS:
		return "-%d%% %s" % [int(round(val * 100)), label]
	return "+%d%% %s" % [int(round(val * 100)), label]

# ---------------------------------------------------------------------------
# Weapon sizing is DERIVED from swing speed.
#
# The roster's rule is "a bigger weapon swings slower". Enforcing that by hand
# across 66 weapons meant re-tuning every damage number, so instead a weapon's
# LENGTH is computed from how slowly it swings, and both its hitbox and its
# drawn sprite follow from that length. Damage and cooldown are never touched --
# the balance pass stays exactly as tuned -- and the rule now holds by
# construction: you cannot author a weapon that is bigger AND faster than its
# peers, because size is not something you author at all.
#
# Which dials are real per type:
#   melee -- icon_size (the drawn blade), area_size (the swing arc) and
#            range_offset (where that arc sits) all matter.
#   spear -- thrusts hit with SpearTipArea, parked at icon_size.x, so a longer
#            spear genuinely reaches further. Spears occupy a length band above
#            every melee weapon, so a spear always out-reaches a sword.
#   bow / wand -- these fire projectiles; their hitbox never touches anything,
#            so nothing is derived and their authored values stand.
#
# A weapon may set "size_override": Vector2(length, height) to opt out.
const SIZE_BANDS = {
	"melee": {"cd_lo": 0.18, "cd_hi": 0.90, "len_lo": 34.0, "len_hi": 96.0, "h_lo": 22.0, "h_hi": 50.0},
	"spear": {"cd_lo": 0.65, "cd_hi": 1.00, "len_lo": 96.0, "len_hi": 142.0, "h_lo": 30.0, "h_hi": 46.0},
}

# Wands fire projectiles, so no hitbox rule binds them -- but they were all drawn
# at very nearly the same length (46-52px), which made the whole caster rack look
# like one item. Their DRAWN size now spreads with cast speed: a quick
# channelling baton is stubby, a slow ceremonial staff is long. Visual only, so
# this never becomes a balance dial.
const VISUAL_BANDS = {
	"wand": {"cd_lo": 0.28, "cd_hi": 1.00, "len_lo": 30.0, "len_hi": 80.0, "h_lo": 6.0, "h_hi": 14.0},
}

# The authored stats with size filled in. Everything that wields or inspects a
# weapon should go through here rather than reading "weapon_stats" raw.
static func weapon_stats_for(item_id: String) -> Dictionary:
	var def = get_item_def(item_id)
	var ws: Dictionary = def.get("weapon_stats", {})
	if ws.is_empty():
		return ws
	var wtype = str(def.get("weapon_type", "melee"))
	if VISUAL_BANDS.has(wtype):
		# drawn size only -- the hitbox stays exactly as authored
		var vb: Dictionary = VISUAL_BANDS[wtype]
		var vout: Dictionary = ws.duplicate(true)
		var vcd = float(ws.get("cooldown", 0.5))
		var vt = clampf((vcd - float(vb["cd_lo"])) / maxf(0.01, float(vb["cd_hi"]) - float(vb["cd_lo"])), 0.0, 1.0)
		vout["icon_size"] = Vector2(lerpf(float(vb["len_lo"]), float(vb["len_hi"]), vt),
			lerpf(float(vb["h_lo"]), float(vb["h_hi"]), vt))
		return vout
	if not SIZE_BANDS.has(wtype):
		return ws
	var band: Dictionary = SIZE_BANDS[wtype]
	var out: Dictionary = ws.duplicate(true)
	var cd = float(ws.get("cooldown", 0.4))
	var t = clampf((cd - float(band["cd_lo"])) / maxf(0.01, float(band["cd_hi"]) - float(band["cd_lo"])), 0.0, 1.0)
	var length = lerpf(float(band["len_lo"]), float(band["len_hi"]), t)
	var height = lerpf(float(band["h_lo"]), float(band["h_hi"]), t)
	if ws.has("size_override"):
		var o: Vector2 = ws["size_override"]
		length = o.x
		height = o.y
	var icon_off = float(ws.get("icon_offset", 20.0))
	# the drawn blade IS the hitbox: identical length, the arc a little taller
	# so a swing still connects just above and below the sprite
	out["icon_size"] = Vector2(length, maxf(8.0, height * 0.32))
	out["area_size"] = Vector2(length + 8.0, height)
	if wtype == "spear":
		# a spear thrusts with SpearTipArea, parked out at icon_size.x, so its
		# reach already follows its length; range_offset only positions the
		# shaft and stays as authored.
		return out
	out["range_offset"] = icon_off + length * 0.5
	return out

static func get_category(item_id: String) -> String:
	return get_item_def(item_id).get("category", "misc")

# Weapons are NOT gear-equippable anymore -- they're wielded from the hotbar
# (see player.gd). Only armor and relics go in the gear panel.
static func is_equippable(item_id: String) -> bool:
	return get_category(item_id) in ["armor", "relic"]

# Which equipment slot an item goes in: "helmet"/"chest"/"pants" for armor,
# "relic" for relics, "weapon" for excellent weapons.
static func get_equip_slot(item_id: String) -> String:
	return get_item_def(item_id).get("slot", "")

static func GameStateRef() -> Node:
	return Engine.get_main_loop().root.get_node("GameState")

# ---------------------------------------------------------------------------
# ELEMENTS (item-art overhaul 2026-07-28). One taxonomy that drives every
# weapon-connected visual from a single source: the slash tint, the projectile
# palette, the impact burst, and the on-hit status spark all read the element's
# colours here so a "fire" weapon looks fire from bag to swing to hit. This is
# the COLOUR/FX contract; the actual art sheets (slash/impact/status) get named
# per-element as the phases land. `status` maps the element to the mechanical
# status apply_status already understands, so the pretty and the real agree.
const ELEMENTS = ["physical", "fire", "ice", "lightning", "poison", "void", "holy", "arcane"]
const ELEMENT_FX = {
	"physical":  {"tint": Color(0.90, 0.92, 0.98), "glow": Color(0.80, 0.85, 0.95), "status": ""},
	"fire":      {"tint": Color(1.00, 0.55, 0.20), "glow": Color(1.00, 0.75, 0.30), "status": "burn"},
	"ice":       {"tint": Color(0.55, 0.85, 1.00), "glow": Color(0.75, 0.95, 1.00), "status": "freeze"},
	"lightning": {"tint": Color(1.00, 0.95, 0.45), "glow": Color(0.85, 0.90, 1.00), "status": "slow"},
	"poison":    {"tint": Color(0.55, 0.90, 0.35), "glow": Color(0.70, 1.00, 0.45), "status": "poison"},
	"void":      {"tint": Color(0.55, 0.30, 0.75), "glow": Color(0.70, 0.40, 0.95), "status": ""},
	"holy":      {"tint": Color(1.00, 0.93, 0.65), "glow": Color(1.00, 0.98, 0.80), "status": ""},
	"arcane":    {"tint": Color(0.45, 0.70, 1.00), "glow": Color(0.65, 0.85, 1.00), "status": ""},
}

# The element a weapon/projectile reads as. Explicit "element" on the def wins;
# otherwise infer from the on-hit status it carries (a burn weapon IS fire),
# else fall back to "physical". Kept forgiving so the 350-weapon roster gets a
# sensible element for free until each is tagged.
static func element_of(item_id: String) -> String:
	var d := get_item_def(item_id)
	var e := str(d.get("element", ""))
	if e in ELEMENTS:
		return e
	var st := str(d.get("special", {}).get("on_hit_status", {}).get("kind", "")) if d.get("special", {}) is Dictionary else ""
	if st == "":
		st = str(d.get("on_hit_status", {}).get("kind", "")) if d.get("on_hit_status", {}) is Dictionary else ""
	match st:
		"burn": return "fire"
		"freeze": return "ice"
		"poison": return "poison"
		"slow": return "lightning"
	return "physical"

# The FX colour/glow/status bundle for an element string (safe default).
static func element_fx(element: String) -> Dictionary:
	return ELEMENT_FX.get(element, ELEMENT_FX["physical"])

# ---------------------------------------------------------------------------
# Procedural item icons. Instead of a flat coloured square, each item draws a
# little symbol that hints at its name -- a sword looks like a sword, a coin
# like a coin, wood like a log. `target` is the slot's icon ColorRect used by
# inventory_ui / hotbar_ui / chest_ui; the symbol is painted as its children.
# A stopgap until real art (art/weapon_*.png ...) replaces these. Cheap to call
# every frame: it no-ops unless the slot's item actually changed.
# ---------------------------------------------------------------------------
# Item-art overhaul (2026-07-28): the one place that resolves an item's real
# pixel-art sprite. Returns the Texture2D at art/items/<id>.png, or null when
# none exists yet (the vast majority today) -- callers then draw procedurally.
# Both the inventory icon (paint_icon) AND the in-hand weapon (player.gd) load
# through here, so a weapon's bag icon and the thing in your hand are literally
# the same texture. Cached so repeated slot repaints don't re-hit the disk.
static var _icon_tex_cache := {}
static func icon_texture(item_id: String) -> Texture2D:
	if item_id == "":
		return null
	if _icon_tex_cache.has(item_id):
		return _icon_tex_cache[item_id]
	var path := "res://art/items/%s.png" % item_id
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_icon_tex_cache[item_id] = tex
	return tex

static func paint_icon(target: ColorRect, item_id: String) -> void:
	if str(target.get_meta("painted_id", "Ã¯Â¿Â¿")) == item_id:
		return
	target.set_meta("painted_id", item_id)
	for c in target.get_children():
		target.remove_child(c)
		c.queue_free()
	target.color = Color(0, 0, 0, 0)   # transparent tile; the symbol carries colour
	if item_id == "":
		return

	var w = target.size.x
	var h = target.size.y
	# Texture-first (item-art overhaul 2026-07-28): a real sprite at
	# art/items/<id>.png wins and skips the procedural draw entirely. The SAME
	# texture backs the in-hand weapon, so inventory and hand always match (the
	# standing item-visual rule). Anything without art falls through to the
	# procedural icons below -- safe to adopt one sprite at a time.
	var tex := icon_texture(item_id)
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size = Vector2(w, h)
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		target.add_child(tr)
		return
	var col: Color = get_item_def(item_id).get("color", Color.WHITE)
	match item_id:
		"wpn_sword": _icon_sword(target, w, h, Color(0.82, 0.85, 0.9), Color(0.85, 0.68, 0.25))
		"exc_thunder": _icon_thunder(target, w, h)
		"exc_vampiric": _icon_fang(target, w, h)
		"wpn_spear": _icon_spear(target, w, h)
		"wpn_bow": _icon_bow(target, w, h)
		"wpn_wand": _icon_wand(target, w, h)
		"tool_axe": _icon_axe(target, w, h)
		"tool_pickaxe": _icon_pickaxe(target, w, h)
		"tool_pickaxe_ember": _icon_pickaxe_ember(target, w, h)
		"tool_pickaxe_blight": _icon_pickaxe_blight(target, w, h)
		"exc_hook": _icon_hook(target, w, h)
		"exc_boomerang": _icon_boomerang(target, w, h)
		"exc_wizardsbane": _icon_runeblade(target, w, h)
		"exc_ragnarok": _icon_ragnarok(target, w, h)
		"relic_wings", "relic_feather": _icon_wing(target, w, h, get_item_def(item_id).get("color", Color.WHITE))
		"coin_gold", "coin_silver", "coin_bronze": _icon_coin(target, w, h, col)
		"wood": _icon_wood(target, w, h)
		"stone": _icon_stone(target, w, h)
		"resin": _icon_resin(target, w, h)
		"herb": _icon_leaf(target, w, h)
		"raw_meat": _icon_meat(target, w, h)
		"slime": _icon_blob(target, w, h, col)
		"iron_shard", "sorrowshard": _icon_shard(target, w, h, col)
		"ember_crystal": _icon_crystal(target, w, h, col)
		"void_essence": _icon_orb(target, w, h, col)
		"ancient_relic": _icon_runestone(target, w, h, col)
		# --- hidden event-boss trophy materials (drawn, never a flat tile) ---
		"mat_debtcoin": _icon_coin(target, w, h, col)
		"mat_everfrost", "mat_crownshard": _icon_shard(target, w, h, col)
		"mat_heartwood": _icon_leaf(target, w, h)
		"mat_brine", "mat_grieftear": _icon_orb(target, w, h, col)
		"mat_pyreash", "mat_vigilember", "mat_unmade": _icon_crystal(target, w, h, col)
		"mat_sableichor": _icon_blob(target, w, h, col)
		"mat_huntsign": _icon_runestone(target, w, h, col)
		# --- fishing (pillar 3): the water's own shapes ---
		"fish_silverfin", "fish_mudwhisker", "fish_lanterneel", "fish_kingsjaw", "fish_palegulper":
			_icon_fish(target, w, h, col)
		"odd_glassfin", "odd_inkmaw", "odd_bellsnail", "odd_twicefish", "odd_sorrowcarp":
			_icon_fish(target, w, h, col)
		"crate_driftwood", "crate_pearlbound": _icon_crate(target, w, h, col)
		"tear_pale": _icon_tear(target, w, h, col)
		"tool_rod_willow", "tool_rod_wyrmbone", "tool_rod_moonline": _icon_rod(target, w, h, col)
		"junk_boot": _icon_boot(target, w, h, col)
		_:
			if get_category(item_id) == "consumable":
				_icon_potion(target, w, h, col)
			elif get_category(item_id) == "relic":
				_icon_gem(target, w, h, col)
			elif get_category(item_id) == "weapon":
				# any weapon without a bespoke icon draws by its type, tinted
				# to the item colour (set weapons, new Excellents, ...)
				match get_item_def(item_id).get("weapon_type", "melee"):
					"bow": _icon_bow(target, w, h)
					"wand": _icon_wand(target, w, h)
					"spear": _icon_spear(target, w, h)
					_: _icon_blade(target, w, h, col, col.darkened(0.35))
			else:
				# ARMOUR USED TO BE A BLANK SQUARE (visual sweep 2026-07-21).
				# All 28 helms/chests/gloves/boots/pants fell through to a flat
				# coloured tile, so a bag full of gear was a bag full of
				# identical rectangles -- against the standing rule that an
				# icon must read as the thing you wear. Draw the silhouette and
				# keep the item's colour, so sets still read at a glance.
				match get_item_def(item_id).get("slot", ""):
					"helmet": _icon_helm(target, w, h, col)
					"chest": _icon_cuirass(target, w, h, col)
					"gloves": _icon_gauntlet(target, w, h, col)
					"boots": _icon_boot(target, w, h, col)
					"pants": _icon_greaves(target, w, h, col)
					_: target.color = col   # research mats keep the coloured tile

# --- tiny drawing primitives (children of the icon ColorRect) ---
static func _ipoly(t: Control, pts: PackedVector2Array, color: Color) -> void:
	var p = Polygon2D.new(); p.polygon = pts; p.color = color; t.add_child(p)
static func _irect(t: Control, pos: Vector2, size: Vector2, color: Color) -> void:
	var r = ColorRect.new(); r.position = pos; r.size = size; r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE; t.add_child(r)
static func _iline(t: Control, pts: PackedVector2Array, width: float, color: Color) -> void:
	var l = Line2D.new(); l.points = pts; l.width = width; l.default_color = color
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND; l.end_cap_mode = Line2D.LINE_CAP_ROUND
	l.joint_mode = Line2D.LINE_JOINT_ROUND; t.add_child(l)
static func _icircle(t: Control, c: Vector2, rad: float, color: Color, sides := 16) -> void:
	var pts = PackedVector2Array()
	for i in range(sides):
		var a = TAU * float(i) / sides
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	_ipoly(t, pts, color)

# --- armour silhouettes, one per equipment slot (tinted to the item colour) ---
static func _icon_helm(t: Control, w: float, h: float, col: Color) -> void:
	var dark = col.darkened(0.4)
	_ipoly(t, PackedVector2Array([
		Vector2(w * 0.22, h * 0.54), Vector2(w * 0.27, h * 0.28),
		Vector2(w * 0.50, h * 0.17), Vector2(w * 0.73, h * 0.28),
		Vector2(w * 0.78, h * 0.54)]), col)
	_irect(t, Vector2(w * 0.26, h * 0.45), Vector2(w * 0.48, h * 0.09), dark)   # visor slit
	_irect(t, Vector2(w * 0.24, h * 0.54), Vector2(w * 0.13, h * 0.20), col)    # cheek guards
	_irect(t, Vector2(w * 0.63, h * 0.54), Vector2(w * 0.13, h * 0.20), col)
	_iline(t, PackedVector2Array([Vector2(w * 0.5, h * 0.17), Vector2(w * 0.5, h * 0.30)]),
		max(1.0, w * 0.05), col.lightened(0.3))                                 # crest

static func _icon_cuirass(t: Control, w: float, h: float, col: Color) -> void:
	var dark = col.darkened(0.4)
	_icircle(t, Vector2(w * 0.25, h * 0.37), w * 0.11, dark)                    # pauldrons
	_icircle(t, Vector2(w * 0.75, h * 0.37), w * 0.11, dark)
	_ipoly(t, PackedVector2Array([
		Vector2(w * 0.30, h * 0.28), Vector2(w * 0.70, h * 0.28),
		Vector2(w * 0.66, h * 0.78), Vector2(w * 0.34, h * 0.78)]), col)
	_irect(t, Vector2(w * 0.43, h * 0.26), Vector2(w * 0.14, h * 0.07), dark)   # neck notch
	_irect(t, Vector2(w * 0.32, h * 0.64), Vector2(w * 0.36, h * 0.08), dark)   # belt
	_iline(t, PackedVector2Array([Vector2(w * 0.5, h * 0.36), Vector2(w * 0.5, h * 0.62)]),
		max(1.0, w * 0.03), col.lightened(0.25))                                # sternum ridge

static func _icon_gauntlet(t: Control, w: float, h: float, col: Color) -> void:
	var dark = col.darkened(0.4)
	_ipoly(t, PackedVector2Array([
		Vector2(w * 0.30, h * 0.62), Vector2(w * 0.30, h * 0.40),
		Vector2(w * 0.40, h * 0.28), Vector2(w * 0.62, h * 0.28),
		Vector2(w * 0.70, h * 0.42), Vector2(w * 0.70, h * 0.62)]), col)
	_icircle(t, Vector2(w * 0.75, h * 0.52), w * 0.08, col)                     # thumb
	_irect(t, Vector2(w * 0.27, h * 0.62), Vector2(w * 0.46, h * 0.14), dark)   # cuff
	for i in range(3):
		_irect(t, Vector2(w * (0.36 + i * 0.11), h * 0.34), Vector2(w * 0.07, h * 0.06),
			col.lightened(0.3))                                                 # knuckle studs

static func _icon_boot(t: Control, w: float, h: float, col: Color) -> void:
	var dark = col.darkened(0.4)
	_irect(t, Vector2(w * 0.34, h * 0.24), Vector2(w * 0.25, h * 0.38), col)    # shaft
	_ipoly(t, PackedVector2Array([
		Vector2(w * 0.34, h * 0.58), Vector2(w * 0.72, h * 0.60),
		Vector2(w * 0.74, h * 0.72), Vector2(w * 0.30, h * 0.72)]), col)        # foot
	_irect(t, Vector2(w * 0.28, h * 0.70), Vector2(w * 0.48, h * 0.07), dark)   # sole
	_irect(t, Vector2(w * 0.32, h * 0.24), Vector2(w * 0.29, h * 0.08),
		col.lightened(0.3))                                                     # cuff band

static func _icon_greaves(t: Control, w: float, h: float, col: Color) -> void:
	var dark = col.darkened(0.4)
	_irect(t, Vector2(w * 0.29, h * 0.26), Vector2(w * 0.42, h * 0.10), dark)   # waist
	_ipoly(t, PackedVector2Array([
		Vector2(w * 0.30, h * 0.34), Vector2(w * 0.48, h * 0.34),
		Vector2(w * 0.46, h * 0.78), Vector2(w * 0.32, h * 0.78)]), col)
	_ipoly(t, PackedVector2Array([
		Vector2(w * 0.52, h * 0.34), Vector2(w * 0.70, h * 0.34),
		Vector2(w * 0.68, h * 0.78), Vector2(w * 0.54, h * 0.78)]), col)

# --- per-item symbols (drawn in the target's 0..w / 0..h local space) ---
static func _icon_blade(t: Control, w: float, h: float, steel: Color, guard: Color) -> void:
	_ipoly(t, PackedVector2Array([
		Vector2(w * 0.5, h * 0.10), Vector2(w * 0.60, h * 0.30),
		Vector2(w * 0.56, h * 0.60), Vector2(w * 0.44, h * 0.60),
		Vector2(w * 0.40, h * 0.30)]), steel)
	_iline(t, PackedVector2Array([Vector2(w * 0.5, h * 0.16), Vector2(w * 0.5, h * 0.58)]), max(1.0, w * 0.02), steel.lightened(0.25))
	_irect(t, Vector2(w * 0.28, h * 0.58), Vector2(w * 0.44, h * 0.07), guard)      # crossguard
	_irect(t, Vector2(w * 0.45, h * 0.65), Vector2(w * 0.10, h * 0.20), Color(0.4, 0.28, 0.16))  # grip
	_icircle(t, Vector2(w * 0.5, h * 0.88), w * 0.06, guard)                        # pommel

static func _icon_sword(t: Control, w: float, h: float, steel: Color, guard: Color) -> void:
	_icon_blade(t, w, h, steel, guard)

static func _icon_thunder(t: Control, w: float, h: float) -> void:
	_icon_blade(t, w, h, Color(0.5, 0.72, 1.0), Color(0.55, 0.6, 0.72))
	_iline(t, PackedVector2Array([
		Vector2(w * 0.53, h * 0.16), Vector2(w * 0.44, h * 0.34),
		Vector2(w * 0.56, h * 0.40), Vector2(w * 0.46, h * 0.58)]),
		max(1.2, w * 0.03), Color(0.9, 0.97, 1.0))
	_icircle(t, Vector2(w * 0.5, h * 0.72), w * 0.055, Color(0.35, 0.6, 1.0))       # sapphire

static func _icon_fang(t: Control, w: float, h: float) -> void:
	# a curved crimson fang / dagger
	_ipoly(t, PackedVector2Array([
		Vector2(w * 0.52, h * 0.10), Vector2(w * 0.66, h * 0.38),
		Vector2(w * 0.58, h * 0.60), Vector2(w * 0.46, h * 0.58),
		Vector2(w * 0.45, h * 0.34)]), Color(0.72, 0.11, 0.16))
	_iline(t, PackedVector2Array([Vector2(w * 0.53, h * 0.16), Vector2(w * 0.5, h * 0.52)]), max(1.0, w * 0.02), Color(0.95, 0.4, 0.45))
	_irect(t, Vector2(w * 0.3, h * 0.58), Vector2(w * 0.4, h * 0.06), Color(0.3, 0.1, 0.1))
	_icircle(t, Vector2(w * 0.5, h * 0.62), w * 0.16, Color(0.9, 0.1, 0.15, 0.28))  # blood glow
	_ipoly(t, PackedVector2Array([                                                  # ruby
		Vector2(w * 0.5, h * 0.66), Vector2(w * 0.58, h * 0.74),
		Vector2(w * 0.5, h * 0.84), Vector2(w * 0.42, h * 0.74)]), Color(0.95, 0.15, 0.2))

static func _icon_spear(t: Control, w: float, h: float) -> void:
	_irect(t, Vector2(w * 0.46, h * 0.28), Vector2(w * 0.08, h * 0.62), Color(0.5, 0.34, 0.18))  # shaft
	_ipoly(t, PackedVector2Array([                                                  # leaf tip
		Vector2(w * 0.5, h * 0.08), Vector2(w * 0.63, h * 0.34),
		Vector2(w * 0.5, h * 0.42), Vector2(w * 0.37, h * 0.34)]), Color(0.82, 0.85, 0.9))
	_irect(t, Vector2(w * 0.43, h * 0.42), Vector2(w * 0.14, h * 0.04), Color(0.35, 0.24, 0.12))  # binding

static func _icon_bow(t: Control, w: float, h: float) -> void:
	_iline(t, PackedVector2Array([                                                  # limb (C arc)
		Vector2(w * 0.64, h * 0.12), Vector2(w * 0.44, h * 0.26),
		Vector2(w * 0.36, h * 0.5), Vector2(w * 0.44, h * 0.74),
		Vector2(w * 0.64, h * 0.88)]), max(1.5, w * 0.06), Color(0.5, 0.34, 0.18))
	_iline(t, PackedVector2Array([Vector2(w * 0.64, h * 0.12), Vector2(w * 0.64, h * 0.88)]), max(1.0, w * 0.02), Color(0.85, 0.85, 0.8))  # string

static func _icon_wand(t: Control, w: float, h: float) -> void:
	_irect(t, Vector2(w * 0.46, h * 0.4), Vector2(w * 0.08, h * 0.5), Color(0.42, 0.3, 0.16))  # handle
	_icircle(t, Vector2(w * 0.5, h * 0.28), w * 0.21, Color(0.7, 0.35, 0.95, 0.3))  # glow
	_icircle(t, Vector2(w * 0.5, h * 0.28), w * 0.13, Color(0.72, 0.38, 0.96))      # orb
	_icircle(t, Vector2(w * 0.45, h * 0.23), w * 0.04, Color(1, 1, 1, 0.85))        # highlight

static func _icon_axe(t: Control, w: float, h: float) -> void:
	_irect(t, Vector2(w * 0.46, h * 0.2), Vector2(w * 0.09, h * 0.68), Color(0.48, 0.33, 0.18))  # haft
	_ipoly(t, PackedVector2Array([                                                  # axe head
		Vector2(w * 0.5, h * 0.14), Vector2(w * 0.78, h * 0.2),
		Vector2(w * 0.82, h * 0.4), Vector2(w * 0.5, h * 0.42)]), Color(0.78, 0.8, 0.85))
	_iline(t, PackedVector2Array([Vector2(w * 0.78, h * 0.22), Vector2(w * 0.8, h * 0.38)]), max(1.0, w * 0.03), Color(0.95, 0.96, 1.0))  # edge shine

static func _icon_pickaxe(t: Control, w: float, h: float) -> void:
	_irect(t, Vector2(w * 0.46, h * 0.18), Vector2(w * 0.09, h * 0.7), Color(0.48, 0.33, 0.18))  # haft
	_ipoly(t, PackedVector2Array([                                                  # curved pick head
		Vector2(w * 0.16, h * 0.3), Vector2(w * 0.5, h * 0.12),
		Vector2(w * 0.84, h * 0.3), Vector2(w * 0.78, h * 0.36),
		Vector2(w * 0.5, h * 0.24), Vector2(w * 0.22, h * 0.36)]), Color(0.72, 0.74, 0.8))

# The tiered pickaxes: same silhouette as the Miner's, but a coloured head with glowing
# tips so they read apart at a glance in the belt (procedural, no art asset).
static func _icon_pickaxe_ember(t: Control, w: float, h: float) -> void:
	_irect(t, Vector2(w * 0.46, h * 0.18), Vector2(w * 0.09, h * 0.7), Color(0.30, 0.20, 0.14))  # scorched haft
	_ipoly(t, PackedVector2Array([                                                  # ember-forged head
		Vector2(w * 0.16, h * 0.3), Vector2(w * 0.5, h * 0.12),
		Vector2(w * 0.84, h * 0.3), Vector2(w * 0.78, h * 0.36),
		Vector2(w * 0.5, h * 0.24), Vector2(w * 0.22, h * 0.36)]), Color(0.95, 0.5, 0.2))
	_icircle(t, Vector2(w * 0.17, h * 0.31), w * 0.055, Color(1.0, 0.72, 0.28, 0.92))   # molten left tip
	_icircle(t, Vector2(w * 0.83, h * 0.31), w * 0.055, Color(1.0, 0.72, 0.28, 0.92))   # molten right tip
	_icircle(t, Vector2(w * 0.5, h * 0.17), w * 0.045, Color(1.0, 0.86, 0.42, 0.9))     # heat at the crown

static func _icon_pickaxe_blight(t: Control, w: float, h: float) -> void:
	_irect(t, Vector2(w * 0.46, h * 0.18), Vector2(w * 0.09, h * 0.7), Color(0.22, 0.16, 0.28))  # tainted haft
	_ipoly(t, PackedVector2Array([                                                  # corrupted crystal head
		Vector2(w * 0.16, h * 0.3), Vector2(w * 0.5, h * 0.12),
		Vector2(w * 0.84, h * 0.3), Vector2(w * 0.78, h * 0.36),
		Vector2(w * 0.5, h * 0.24), Vector2(w * 0.22, h * 0.36)]), Color(0.82, 0.42, 1.0))
	_icircle(t, Vector2(w * 0.17, h * 0.31), w * 0.055, Color(0.72, 0.36, 1.0, 0.92))  # blight left tip
	_icircle(t, Vector2(w * 0.83, h * 0.31), w * 0.055, Color(0.72, 0.36, 1.0, 0.92))  # blight right tip
	_icircle(t, Vector2(w * 0.5, h * 0.17), w * 0.045, Color(0.92, 0.62, 1.0, 0.9))    # rune at the crown

static func _icon_ragnarok(t: Control, w: float, h: float) -> void:
	# a fiery blade ringed by little flame-sparks (the storm it carries)
	_icon_blade(t, w, h, Color(1.0, 0.62, 0.22), Color(0.85, 0.35, 0.1))
	for i in range(5):
		var a = TAU * float(i) / 5.0 - 0.4
		_icircle(t, Vector2(w * 0.5, h * 0.4) + Vector2(cos(a), sin(a)) * w * 0.3, w * 0.035, Color(1.0, 0.75, 0.3, 0.9))

static func _icon_runeblade(t: Control, w: float, h: float) -> void:
	# a pale greatblade with a glowing rune notch -- the Wizardsbane
	_icon_blade(t, w, h, Color(0.9, 0.94, 0.8), Color(0.7, 0.66, 0.4))
	_icircle(t, Vector2(w * 0.5, h * 0.34), w * 0.055, Color(0.6, 1.0, 0.85, 0.9))  # rune glow
	_iline(t, PackedVector2Array([Vector2(w * 0.5, h * 0.2), Vector2(w * 0.5, h * 0.5)]), max(1.0, w * 0.02), Color(0.85, 1.0, 0.9, 0.7))

static func _icon_hook(t: Control, w: float, h: float) -> void:
	_iline(t, PackedVector2Array([Vector2(w * 0.5, h * 0.12), Vector2(w * 0.5, h * 0.55)]), max(1.5, w * 0.05), Color(0.55, 0.45, 0.32))  # rope
	var pts = PackedVector2Array()   # J-curve hook
	for i in range(8):
		var a = lerp(-PI * 0.1, PI * 1.05, i / 7.0)
		pts.append(Vector2(w * 0.5, h * 0.62) + Vector2(cos(a), sin(a)) * w * 0.2)
	_iline(t, pts, max(1.8, w * 0.07), Color(0.72, 0.76, 0.82))

static func _icon_wing(t: Control, w: float, h: float, col: Color) -> void:
	# a single feathered wing, tinted to the relic colour
	_ipoly(t, PackedVector2Array([
		Vector2(w * 0.28, h * 0.34), Vector2(w * 0.74, h * 0.28),
		Vector2(w * 0.7, h * 0.44), Vector2(w * 0.78, h * 0.46),
		Vector2(w * 0.66, h * 0.58), Vector2(w * 0.74, h * 0.6),
		Vector2(w * 0.56, h * 0.72), Vector2(w * 0.34, h * 0.56)]), col)
	_iline(t, PackedVector2Array([Vector2(w * 0.32, h * 0.4), Vector2(w * 0.66, h * 0.4)]), max(1.0, w * 0.02), col.darkened(0.25))
	_iline(t, PackedVector2Array([Vector2(w * 0.36, h * 0.5), Vector2(w * 0.62, h * 0.5)]), max(1.0, w * 0.02), col.darkened(0.25))

static func _icon_boomerang(t: Control, w: float, h: float) -> void:
	var teal = Color(0.35, 0.8, 0.75)
	_ipoly(t, PackedVector2Array([                                                  # blade 1
		Vector2(w * 0.3, h * 0.68), Vector2(w * 0.42, h * 0.3), Vector2(w * 0.52, h * 0.34),
		Vector2(w * 0.42, h * 0.7)]), teal)
	_ipoly(t, PackedVector2Array([                                                  # blade 2
		Vector2(w * 0.42, h * 0.3), Vector2(w * 0.78, h * 0.42), Vector2(w * 0.74, h * 0.52),
		Vector2(w * 0.46, h * 0.4)]), teal.lightened(0.12))

static func _icon_coin(t: Control, w: float, h: float, col: Color) -> void:
	_icircle(t, Vector2(w * 0.5, h * 0.5), w * 0.34, col.darkened(0.2))
	_icircle(t, Vector2(w * 0.5, h * 0.5), w * 0.27, col)
	_icircle(t, Vector2(w * 0.5, h * 0.5), w * 0.18, col.lightened(0.12))
	_icircle(t, Vector2(w * 0.42, h * 0.42), w * 0.05, Color(1, 1, 1, 0.6))         # shine

static func _icon_wood(t: Control, w: float, h: float) -> void:
	var brown = Color(0.5, 0.34, 0.18)
	_irect(t, Vector2(w * 0.22, h * 0.4), Vector2(w * 0.56, h * 0.28), brown)       # log body
	_icircle(t, Vector2(w * 0.22, h * 0.54), h * 0.14, brown)                       # left end
	_icircle(t, Vector2(w * 0.78, h * 0.54), h * 0.14, brown.lightened(0.1))        # right end (rings)
	_icircle(t, Vector2(w * 0.78, h * 0.54), h * 0.08, brown.darkened(0.15))
	_iline(t, PackedVector2Array([Vector2(w * 0.3, h * 0.44), Vector2(w * 0.7, h * 0.44)]), max(1.0, h * 0.02), brown.darkened(0.2))  # bark

static func _icon_stone(t: Control, w: float, h: float) -> void:
	var grey = Color(0.6, 0.6, 0.63)
	_ipoly(t, PackedVector2Array([
		Vector2(w * 0.24, h * 0.66), Vector2(w * 0.32, h * 0.4),
		Vector2(w * 0.5, h * 0.32), Vector2(w * 0.68, h * 0.4),
		Vector2(w * 0.78, h * 0.62), Vector2(w * 0.62, h * 0.76),
		Vector2(w * 0.36, h * 0.76)]), grey)
	_ipoly(t, PackedVector2Array([                                                  # top facet
		Vector2(w * 0.32, h * 0.4), Vector2(w * 0.5, h * 0.32),
		Vector2(w * 0.54, h * 0.46), Vector2(w * 0.36, h * 0.5)]), grey.lightened(0.15))

static func _icon_resin(t: Control, w: float, h: float) -> void:
	_ipoly(t, PackedVector2Array([                                                  # amber droplet
		Vector2(w * 0.5, h * 0.16), Vector2(w * 0.63, h * 0.5),
		Vector2(w * 0.6, h * 0.7), Vector2(w * 0.5, h * 0.8),
		Vector2(w * 0.4, h * 0.7), Vector2(w * 0.37, h * 0.5)]), Color(0.88, 0.62, 0.22))
	_icircle(t, Vector2(w * 0.44, h * 0.46), w * 0.05, Color(1, 1, 1, 0.7))         # highlight

static func _icon_potion(t: Control, w: float, h: float, col: Color) -> void:
	_irect(t, Vector2(w * 0.42, h * 0.16), Vector2(w * 0.16, h * 0.14), Color(0.7, 0.66, 0.6))  # cork/neck
	_ipoly(t, PackedVector2Array([                                                  # flask body
		Vector2(w * 0.44, h * 0.3), Vector2(w * 0.56, h * 0.3),
		Vector2(w * 0.72, h * 0.7), Vector2(w * 0.62, h * 0.86),
		Vector2(w * 0.38, h * 0.86), Vector2(w * 0.28, h * 0.7)]), Color(0.85, 0.88, 0.92, 0.55))
	_ipoly(t, PackedVector2Array([                                                  # liquid
		Vector2(w * 0.34, h * 0.6), Vector2(w * 0.66, h * 0.6),
		Vector2(w * 0.62, h * 0.84), Vector2(w * 0.38, h * 0.84)]), col)
	_icircle(t, Vector2(w * 0.44, h * 0.44), w * 0.04, Color(1, 1, 1, 0.6))         # shine

static func _icon_leaf(t: Control, w: float, h: float) -> void:
	_ipoly(t, PackedVector2Array([
		Vector2(w * 0.5, h * 0.18), Vector2(w * 0.72, h * 0.5),
		Vector2(w * 0.5, h * 0.82), Vector2(w * 0.28, h * 0.5)]), Color(0.4, 0.72, 0.35))
	_iline(t, PackedVector2Array([Vector2(w * 0.5, h * 0.2), Vector2(w * 0.5, h * 0.8)]), max(1.0, w * 0.02), Color(0.28, 0.5, 0.24))

# --- fishing icons (pillar 3): a fish, a crate, a rod, a boot ---
static func _icon_fish(t: Control, w: float, h: float, col: Color) -> void:
	_ipoly(t, PackedVector2Array([
		Vector2(w * 0.18, h * 0.5), Vector2(w * 0.38, h * 0.3), Vector2(w * 0.68, h * 0.34),
		Vector2(w * 0.8, h * 0.5), Vector2(w * 0.68, h * 0.66), Vector2(w * 0.38, h * 0.7)]), col)
	_ipoly(t, PackedVector2Array([
		Vector2(w * 0.8, h * 0.5), Vector2(w * 0.94, h * 0.32), Vector2(w * 0.94, h * 0.68)]), col.darkened(0.25))
	_ipoly(t, PackedVector2Array([
		Vector2(w * 0.3, h * 0.42), Vector2(w * 0.36, h * 0.42),
		Vector2(w * 0.36, h * 0.48), Vector2(w * 0.3, h * 0.48)]), Color(0.1, 0.1, 0.12))

# a teardrop: pointed crown, round belly, one gleam (the Weeping Hour's tears)
static func _icon_tear(t: Control, w: float, h: float, col: Color) -> void:
	_ipoly(t, PackedVector2Array([
		Vector2(w * 0.5, h * 0.12), Vector2(w * 0.68, h * 0.45), Vector2(w * 0.72, h * 0.62),
		Vector2(w * 0.62, h * 0.8), Vector2(w * 0.38, h * 0.8), Vector2(w * 0.28, h * 0.62),
		Vector2(w * 0.32, h * 0.45)]), col)
	_ipoly(t, PackedVector2Array([
		Vector2(w * 0.4, h * 0.52), Vector2(w * 0.46, h * 0.52),
		Vector2(w * 0.46, h * 0.62), Vector2(w * 0.4, h * 0.62)]), Color(0.98, 0.99, 1.0, 0.9))

static func _icon_crate(t: Control, w: float, h: float, col: Color) -> void:
	_ipoly(t, PackedVector2Array([
		Vector2(w * 0.2, h * 0.3), Vector2(w * 0.8, h * 0.3),
		Vector2(w * 0.8, h * 0.8), Vector2(w * 0.2, h * 0.8)]), col)
	_ipoly(t, PackedVector2Array([
		Vector2(w * 0.2, h * 0.5), Vector2(w * 0.8, h * 0.5),
		Vector2(w * 0.8, h * 0.58), Vector2(w * 0.2, h * 0.58)]), col.darkened(0.35))
	_ipoly(t, PackedVector2Array([
		Vector2(w * 0.46, h * 0.3), Vector2(w * 0.54, h * 0.3),
		Vector2(w * 0.54, h * 0.8), Vector2(w * 0.46, h * 0.8)]), col.darkened(0.25))

static func _icon_rod(t: Control, w: float, h: float, col: Color) -> void:
	_ipoly(t, PackedVector2Array([
		Vector2(w * 0.16, h * 0.85), Vector2(w * 0.22, h * 0.85),
		Vector2(w * 0.78, h * 0.2), Vector2(w * 0.72, h * 0.16)]), col)
	_ipoly(t, PackedVector2Array([
		Vector2(w * 0.76, h * 0.18), Vector2(w * 0.79, h * 0.18),
		Vector2(w * 0.79, h * 0.6), Vector2(w * 0.76, h * 0.6)]), Color(0.85, 0.9, 0.95, 0.9))
	_ipoly(t, PackedVector2Array([
		Vector2(w * 0.74, h * 0.6), Vector2(w * 0.82, h * 0.6),
		Vector2(w * 0.78, h * 0.7)]), col.darkened(0.2))

static func _icon_meat(t: Control, w: float, h: float) -> void:
	_icircle(t, Vector2(w * 0.5, h * 0.52), w * 0.26, Color(0.82, 0.4, 0.42))
	_icircle(t, Vector2(w * 0.5, h * 0.52), w * 0.16, Color(0.9, 0.55, 0.55))
	_irect(t, Vector2(w * 0.2, h * 0.66), Vector2(w * 0.16, h * 0.06), Color(0.9, 0.87, 0.8))  # bone

static func _icon_gem(t: Control, w: float, h: float, col: Color) -> void:
	_ipoly(t, PackedVector2Array([
		Vector2(w * 0.5, h * 0.18), Vector2(w * 0.72, h * 0.44),
		Vector2(w * 0.5, h * 0.82), Vector2(w * 0.28, h * 0.44)]), col)
	_ipoly(t, PackedVector2Array([
		Vector2(w * 0.5, h * 0.18), Vector2(w * 0.72, h * 0.44),
		Vector2(w * 0.28, h * 0.44)]), col.lightened(0.22))
	_icircle(t, Vector2(w * 0.42, h * 0.34), w * 0.04, Color(1, 1, 1, 0.7))

# --- material symbols (drop-loot that used to render as a flat coloured square) ---
static func _icon_blob(t: Control, w: float, h: float, col: Color) -> void:
	_icircle(t, Vector2(w * 0.5, h * 0.57), w * 0.30, col)                          # gooey body
	_icircle(t, Vector2(w * 0.34, h * 0.43), w * 0.12, col.lightened(0.10))         # top-left bulge
	_icircle(t, Vector2(w * 0.66, h * 0.47), w * 0.10, col.lightened(0.05))         # top-right bulge
	_icircle(t, Vector2(w * 0.41, h * 0.49), w * 0.05, Color(1, 1, 1, 0.6))         # wet shine

static func _icon_shard(t: Control, w: float, h: float, col: Color) -> void:
	_ipoly(t, PackedVector2Array([                                                  # angular sliver
		Vector2(w * 0.46, h * 0.14), Vector2(w * 0.64, h * 0.5),
		Vector2(w * 0.54, h * 0.86), Vector2(w * 0.40, h * 0.6)]), col)
	_iline(t, PackedVector2Array([Vector2(w * 0.49, h * 0.22), Vector2(w * 0.51, h * 0.76)]),
		max(1.0, w * 0.02), col.lightened(0.32))                                    # facet ridge
	_icircle(t, Vector2(w * 0.5, h * 0.32), w * 0.035, Color(1, 1, 1, 0.6))         # glint

static func _icon_crystal(t: Control, w: float, h: float, col: Color) -> void:
	_ipoly(t, PackedVector2Array([                                                  # tall prism
		Vector2(w * 0.5, h * 0.12), Vector2(w * 0.66, h * 0.4),
		Vector2(w * 0.6, h * 0.82), Vector2(w * 0.4, h * 0.82),
		Vector2(w * 0.34, h * 0.4)]), col)
	_ipoly(t, PackedVector2Array([                                                  # bright facet
		Vector2(w * 0.5, h * 0.12), Vector2(w * 0.34, h * 0.4),
		Vector2(w * 0.42, h * 0.82), Vector2(w * 0.5, h * 0.4)]), col.lightened(0.25))
	_icircle(t, Vector2(w * 0.5, h * 0.16), w * 0.05, col.lightened(0.45))          # glowing tip

static func _icon_orb(t: Control, w: float, h: float, col: Color) -> void:
	_icircle(t, Vector2(w * 0.5, h * 0.5), w * 0.32, col.darkened(0.35))            # dark halo
	_icircle(t, Vector2(w * 0.5, h * 0.5), w * 0.24, col)                           # orb
	_icircle(t, Vector2(w * 0.5, h * 0.5), w * 0.11, col.lightened(0.35))           # inner glow
	_icircle(t, Vector2(w * 0.43, h * 0.43), w * 0.04, Color(1, 1, 1, 0.5))         # shine

static func _icon_runestone(t: Control, w: float, h: float, col: Color) -> void:
	_irect(t, Vector2(w * 0.30, h * 0.20), Vector2(w * 0.40, h * 0.60), col.darkened(0.25))  # tablet edge
	_irect(t, Vector2(w * 0.34, h * 0.24), Vector2(w * 0.32, h * 0.52), col)                 # face
	var glow := col.lightened(0.4)
	_iline(t, PackedVector2Array([Vector2(w * 0.40, h * 0.33), Vector2(w * 0.60, h * 0.33)]), max(1.0, w * 0.025), glow)
	_iline(t, PackedVector2Array([Vector2(w * 0.50, h * 0.33), Vector2(w * 0.50, h * 0.60)]), max(1.0, w * 0.025), glow)
	_iline(t, PackedVector2Array([Vector2(w * 0.42, h * 0.60), Vector2(w * 0.58, h * 0.60)]), max(1.0, w * 0.025), glow)

const DEFAULT_MAX_STACK = 99

var capacity: int
var slots: Array = []  # each entry: null, or {"item_id": String, "count": int}

func _init(cap: int = 15) -> void:
	capacity = cap
	slots.resize(cap)

static func get_item_def(item_id: String) -> Dictionary:
	# hand-authored defs first; the generated ladder answers for the rest
	if not ITEM_DEFS.has(item_id) and WeaponRoster.has_id(item_id):
		return WeaponRoster.get_def(item_id)
	return ITEM_DEFS.get(item_id, {})

static func get_max_stack(item_id: String) -> int:
	return get_item_def(item_id).get("max_stack", DEFAULT_MAX_STACK)

func get_count(item_id: String) -> int:
	var total = 0
	for slot in slots:
		if slot != null and slot.item_id == item_id:
			total += slot.count
	return total

# Adds up to `count` of item_id: tops up existing partial stacks first, then
# fills empty slots. Returns how much did NOT fit (0 if it all fit).
func add_item(item_id: String, count: int) -> int:
	if count <= 0:
		return 0
	# An undefined id used to be accepted in silence: it took a slot, showed a
	# blank grey icon, had no name and no use, and saved/reloaded forever. Refuse
	# it loudly instead -- a bad id is always a bug at the call site.
	# THE ROSTER IS REAL TOO (caravan test catch, 2026-07-28): this guard
	# predates the generated ladder and knew only ITEM_DEFS -- so EVERY grant
	# of a roster weapon was refused right here: boss drops (which then showed
	# a FALSE "bag is full -- left behind!"), the Forge's daily-import
	# purchases, and the new Reaver Cache. The 275 ladder weapons were
	# uncollectable in live play since wave 2. One existence truth now:
	# defs OR the roster.
	if not ITEM_DEFS.has(item_id) and not WeaponRoster.has_id(item_id):
		push_error("Inventory.add_item: no such item '%s' -- refusing" % item_id)
		return count
	var remaining = count
	var max_stack = get_max_stack(item_id)
	for i in range(slots.size()):
		if remaining <= 0:
			break
		var slot = slots[i]
		if slot != null and slot.item_id == item_id and slot.count < max_stack:
			var space = max_stack - slot.count
			var added = min(space, remaining)
			slot.count += added
			remaining -= added
	for i in range(slots.size()):
		if remaining <= 0:
			break
		if slots[i] == null:
			var added = min(max_stack, remaining)
			slots[i] = {"item_id": item_id, "count": added}
			remaining -= added
	return remaining

# Removes up to `count` of item_id. If fewer than `count` are available,
# removes nothing and returns false (all-or-nothing, so callers never need
# to reconcile a partial spend).
func remove_item(item_id: String, count: int) -> bool:
	if count <= 0:
		return true
	if get_count(item_id) < count:
		return false
	var remaining = count
	for i in range(slots.size()):
		if remaining <= 0:
			break
		var slot = slots[i]
		if slot != null and slot.item_id == item_id:
			var taken = min(slot.count, remaining)
			slot.count -= taken
			remaining -= taken
			if slot.count <= 0:
				slots[i] = null
	return true

# Moves up to `count` of item_id from this inventory into `other`. Returns
# how much was actually moved (may be less than requested if `other` doesn't
# have room, or this inventory doesn't have that much).
func transfer_to(other: Inventory, item_id: String, count: int) -> int:
	var available = min(get_count(item_id), count)
	if available <= 0:
		return 0
	var leftover = other.add_item(item_id, available)
	var moved = available - leftover
	if moved > 0:
		remove_item(item_id, moved)
	return moved

# Drag-and-drop primitive: moves the SPECIFIC stack sitting in from_index
# into to_index (which may be a slot in this same inventory, for reordering,
# or a slot in a different Inventory, for chest<->player transfers). Empty
# destination -> move outright. Same item_id -> merge up to max_stack,
# leaving any remainder behind in the source slot. Different item -> swap
# the two stacks. No-op if the source slot is empty or from==to on self.
func transfer_slot(from_index: int, other: Inventory, to_index: int) -> void:
	if other == self and from_index == to_index:
		return
	var from_slot = slots[from_index]
	if from_slot == null:
		return
	var to_slot = other.slots[to_index]
	if to_slot == null:
		other.slots[to_index] = from_slot
		slots[from_index] = null
	elif to_slot.item_id == from_slot.item_id:
		var max_stack = get_max_stack(from_slot.item_id)
		var space = max_stack - to_slot.count
		var moved = min(space, from_slot.count)
		to_slot.count += moved
		from_slot.count -= moved
		if from_slot.count <= 0:
			slots[from_index] = null
	else:
		slots[from_index] = to_slot
		other.slots[to_index] = from_slot

func to_save_data() -> Array:
	var data = []
	for slot in slots:
		if slot == null:
			data.append(null)
		else:
			data.append({"item_id": slot.item_id, "count": slot.count})
	return data

# Could one more `item_id` be banked right now? True if a stack of it already
# exists (stacks are effectively unbounded for coins) or any slot is free.
func can_accept(item_id: String) -> bool:
	if get_count(item_id) > 0:
		return true
	for s in slots:
		if s == null:
			return true
	return false

func from_save_data(data: Array) -> void:
	slots = []
	slots.resize(capacity)
	for i in range(min(data.size(), capacity)):
		var entry = data[i]
		if entry != null and typeof(entry) == TYPE_DICTIONARY:
			# the same hardening add_item has (audit fix): a save carrying a
			# since-renamed/removed id -- or a zero count -- used to reload
			# into a permanent PHANTOM slot (no name, no icon, uncleanable)
			# that survived every later save cycle and cost one of the 55.
			var iid := str(entry.get("item_id", ""))
			var cnt := int(entry.get("count", 0))
			if iid == "" or cnt <= 0 or not ITEM_DEFS.has(iid):
				if iid != "" and not ITEM_DEFS.has(iid):
					push_warning("save held unknown item '%s' x%d -- slot dropped" % [iid, cnt])
				continue
			slots[i] = {"item_id": iid, "count": cnt}
