class_name SkillTreeData
extends RefCounted

# Each class is ONE tree that actually BRANCHES. A root trunk splits into 3
# named specs; every spec is a spine of nodes that FORKS at tier 4 into a
# mutually-exclusive KEYSTONE choice ("exclusive" group -- pick one, the other
# locks forever) and reconverges. That fork is the opportunity cost: even with
# unlimited points you can't have both. Keystones grant real MECHANICS and the
# later ones EVOLVE the earlier mechanic instead of just adding a bigger number.
# The tier-7 node of each spec is an ULTIMATE: a triggered/conditional effect
# (rampage-on-kill, survive-a-lethal-hit, contagion, spellblade...), not a stat
# bundle.
#
# Node fields:
#   id        unique string
#   branch    -1 root / 0-2 spec (drives colour + region)
#   col       layout lane (float, 0-5); spec spines sit on x.5, forks on the
#             two integer lanes either side. The UI positions purely from this.
#   tier      row: 0 root, 1-7 down the spec
#   name/desc shown on the card
#   cost      skill points
#   prereq    node id, OR an Array of ids meaning "any of these" (used where the
#             fork reconverges -- reachable from either chosen path)
#   materials {item_id: count} consumed (researched at the Science Lab)
#   effect    {effect_key: value} summed by GameState.get_skill_total
#   keystone  bool -- drawn with a gold border + star
#   exclusive optional group key -- only ONE node per group may ever be unlocked
#
# Effect keys -- STATS: melee_damage/melee_cooldown, bow_damage/bow_cooldown,
# wand_damage/wand_cooldown, max_health, max_mana, mana_regen, move_speed,
# crit_chance, crit_damage, damage_reduction, status_resistance.
# MECHANICS (player.gd / arrow.gd / weapon_projectile.gd read these):
#   lifesteal            heal % of melee damage dealt
#   thorns               reflect % of damage taken to nearby foes
#   dodge_chance         chance to negate a hit outright
#   execute_threshold    instakill a non-boss below this % HP
#   execute_heal         heal this % max HP when you execute
#   low_hp_damage_mult   bonus damage multiplier while under 40% HP
#   on_kill_rampage      each kill stacks this much bonus damage (5s, x10)
#   undying              (>0) survive one lethal hit per life at 20% HP
#   multishot            extra arrows per draw
#   arrow_pierce         arrows pass through this many enemies
#   arrow_homing         (>0) your arrows steer toward foes
#   poison_spread        (>0) arrows also poison enemies near the one they hit
#   on_hit_burn/poison   DoT/sec applied on hit; on_hit_slow (>0) chills
#   combustion           (>0) your burns leap to nearby foes on hit
#   mana_shield          % of a hit paid from Mana instead of HP
#   mana_to_damage       adds (value x max_mana) to your wand damage multiplier

const BRANCH_NAMES = {
	"Sword": ["Berserker", "Guardian", "Warlord"],
	"Archer": ["Marksman", "Ranger", "Warden"],
	"Mage": ["Elementalist", "Sage", "Mystic"],
	"Shadow Monarch": ["???", "???", "???"],
}

const TREES = {
	"Sword": [
		{"id": "sw_root", "branch": -1, "col": 2.5, "name": "Way of the Blade", "desc": "+5% melee damage", "tier": 0, "cost": 1, "prereq": "", "materials": {}, "effect": {"melee_damage": 0.05}},
		# === Berserker (0): bloodthirst vs blood-rage, ending in a kill-frenzy ===
		{"id": "sw_b1", "branch": 0, "col": 0.5, "name": "Reckless Edge", "desc": "+12% melee damage", "tier": 1, "cost": 1, "prereq": "sw_root", "materials": {}, "effect": {"melee_damage": 0.12}},
		{"id": "sw_b2", "branch": 0, "col": 0.5, "name": "Bloodletting", "desc": "-10% melee cooldown", "tier": 2, "cost": 1, "prereq": "sw_b1", "materials": {}, "effect": {"melee_cooldown": 0.10}},
		{"id": "sw_b3", "branch": 0, "col": 0.5, "name": "Bloodthirst", "desc": "KEYSTONE: melee hits heal you for 8% of the damage dealt", "tier": 3, "cost": 2, "prereq": "sw_b2", "materials": {"slime": 3}, "effect": {"lifesteal": 0.08}, "keystone": true},
		{"id": "sw_b4a", "branch": 0, "col": 0.0, "name": "Sanguine Pact", "desc": "FORK: +7% lifesteal, +10% melee damage — sustain through the fight", "tier": 4, "cost": 3, "prereq": "sw_b3", "materials": {"iron_shard": 2}, "effect": {"lifesteal": 0.07, "melee_damage": 0.10}, "keystone": true, "exclusive": "sw0"},
		{"id": "sw_b4b", "branch": 0, "col": 1.0, "name": "Blood Rage", "desc": "FORK: while below 40% HP, +40% melee damage — dance on the edge", "tier": 4, "cost": 3, "prereq": "sw_b3", "materials": {"iron_shard": 2}, "effect": {"low_hp_damage_mult": 0.40}, "keystone": true, "exclusive": "sw0"},
		{"id": "sw_b5", "branch": 0, "col": 0.5, "name": "Rampage", "desc": "+20% melee damage, +6% crit", "tier": 5, "cost": 2, "prereq": ["sw_b4a", "sw_b4b"], "materials": {"ember_crystal": 1}, "effect": {"melee_damage": 0.20, "crit_chance": 0.06}},
		{"id": "sw_b6", "branch": 0, "col": 0.5, "name": "Frenzy", "desc": "KEYSTONE: -18% melee cooldown, +10% melee damage", "tier": 6, "cost": 4, "prereq": "sw_b5", "materials": {"void_essence": 2}, "effect": {"melee_cooldown": 0.18, "melee_damage": 0.10}, "keystone": true},
		{"id": "sw_b7", "branch": 0, "col": 0.5, "name": "Avatar of Slaughter", "desc": "ULTIMATE: every kill stacks +6% damage for 5s (up to x10). +10% lifesteal, +60 HP.", "tier": 7, "cost": 6, "prereq": "sw_b6", "materials": {"void_essence": 3, "ancient_relic": 2}, "effect": {"on_kill_rampage": 0.06, "lifesteal": 0.10, "max_health": 60.0}, "keystone": true},
		# === Guardian (1): fortress vs riposte, ending in undying ===
		{"id": "sw_g1", "branch": 1, "col": 2.5, "name": "Toughness", "desc": "+25 max health", "tier": 1, "cost": 1, "prereq": "sw_root", "materials": {}, "effect": {"max_health": 25.0}},
		{"id": "sw_g2", "branch": 1, "col": 2.5, "name": "Iron Skin", "desc": "+5% damage reduction", "tier": 2, "cost": 1, "prereq": "sw_g1", "materials": {}, "effect": {"damage_reduction": 0.05}},
		{"id": "sw_g3", "branch": 1, "col": 2.5, "name": "Spiked Armor", "desc": "KEYSTONE: reflect 25% of damage taken to nearby enemies", "tier": 3, "cost": 2, "prereq": "sw_g2", "materials": {"slime": 3}, "effect": {"thorns": 0.25}, "keystone": true},
		{"id": "sw_g4a", "branch": 1, "col": 2.0, "name": "Aegis Wall", "desc": "FORK: +8% damage reduction, +40 HP — become an immovable object", "tier": 4, "cost": 3, "prereq": "sw_g3", "materials": {"ember_crystal": 2}, "effect": {"damage_reduction": 0.08, "max_health": 40.0}, "keystone": true, "exclusive": "sw1"},
		{"id": "sw_g4b", "branch": 1, "col": 3.0, "name": "Riposte", "desc": "FORK: 15% chance to dodge a hit entirely, +15% thorns — punish the miss", "tier": 4, "cost": 3, "prereq": "sw_g3", "materials": {"ember_crystal": 2}, "effect": {"dodge_chance": 0.15, "thorns": 0.15}, "keystone": true, "exclusive": "sw1"},
		{"id": "sw_g5", "branch": 1, "col": 2.5, "name": "Fortress", "desc": "+60 max health, +5% damage reduction", "tier": 5, "cost": 2, "prereq": ["sw_g4a", "sw_g4b"], "materials": {"ember_crystal": 1}, "effect": {"max_health": 60.0, "damage_reduction": 0.05}},
		{"id": "sw_g6", "branch": 1, "col": 2.5, "name": "Retribution", "desc": "KEYSTONE: +25% thorns, +40 max HP — every wound answered", "tier": 6, "cost": 4, "prereq": "sw_g5", "materials": {"void_essence": 2}, "effect": {"thorns": 0.25, "max_health": 40.0}, "keystone": true},
		{"id": "sw_g7", "branch": 1, "col": 2.5, "name": "Living Fortress", "desc": "ULTIMATE: survive one lethal hit per life (revive at 20% HP). +120 HP, +6% DR, +20% thorns.", "tier": 7, "cost": 6, "prereq": "sw_g6", "materials": {"void_essence": 3, "ancient_relic": 2}, "effect": {"undying": 1.0, "max_health": 120.0, "damage_reduction": 0.06, "thorns": 0.20}, "keystone": true},
		# === Warlord (2): execute vs overpower, ending in godslayer ===
		{"id": "sw_w1", "branch": 2, "col": 4.5, "name": "Sharpened", "desc": "+12% melee damage", "tier": 1, "cost": 1, "prereq": "sw_root", "materials": {}, "effect": {"melee_damage": 0.12}},
		{"id": "sw_w2", "branch": 2, "col": 4.5, "name": "Precision", "desc": "+8% crit chance", "tier": 2, "cost": 1, "prereq": "sw_w1", "materials": {}, "effect": {"crit_chance": 0.08}},
		{"id": "sw_w3", "branch": 2, "col": 4.5, "name": "Deathblow", "desc": "KEYSTONE: +30% crit damage, +6% crit chance", "tier": 3, "cost": 2, "prereq": "sw_w2", "materials": {"slime": 3}, "effect": {"crit_damage": 0.30, "crit_chance": 0.06}, "keystone": true},
		{"id": "sw_w4a", "branch": 2, "col": 4.0, "name": "Executioner", "desc": "FORK: instantly slay any non-boss below 15% HP", "tier": 4, "cost": 3, "prereq": "sw_w3", "materials": {"iron_shard": 2}, "effect": {"execute_threshold": 0.15}, "keystone": true, "exclusive": "sw2"},
		{"id": "sw_w4b", "branch": 2, "col": 5.0, "name": "Overpower", "desc": "FORK: +25% melee damage, +15% crit damage — brute lethality", "tier": 4, "cost": 3, "prereq": "sw_w3", "materials": {"iron_shard": 2}, "effect": {"melee_damage": 0.25, "crit_damage": 0.15}, "keystone": true, "exclusive": "sw2"},
		{"id": "sw_w5", "branch": 2, "col": 4.5, "name": "Warmonger", "desc": "+30% melee damage, +8% crit", "tier": 5, "cost": 2, "prereq": ["sw_w4a", "sw_w4b"], "materials": {"ember_crystal": 1}, "effect": {"melee_damage": 0.30, "crit_chance": 0.08}},
		{"id": "sw_w6", "branch": 2, "col": 4.5, "name": "Headhunter", "desc": "KEYSTONE: executes now heal 12% max HP; execute threshold +5%", "tier": 6, "cost": 4, "prereq": "sw_w5", "materials": {"void_essence": 2}, "effect": {"execute_heal": 0.12, "execute_threshold": 0.05}, "keystone": true},
		{"id": "sw_w7", "branch": 2, "col": 4.5, "name": "Godslayer", "desc": "ULTIMATE: +50% melee, +15% crit, +40% crit damage. Kills stack +5% damage (5s).", "tier": 7, "cost": 6, "prereq": "sw_w6", "materials": {"void_essence": 3, "ancient_relic": 2}, "effect": {"melee_damage": 0.50, "crit_chance": 0.15, "crit_damage": 0.40, "on_kill_rampage": 0.05}, "keystone": true},
	],
	"Archer": [
		{"id": "ar_root", "branch": -1, "col": 2.5, "name": "Way of the Hunt", "desc": "+5% bow damage", "tier": 0, "cost": 1, "prereq": "", "materials": {}, "effect": {"bow_damage": 0.05}},
		# === Marksman (0): pierce vs execute, ending in skyfall ===
		{"id": "ar_m1", "branch": 0, "col": 0.5, "name": "Barbed Arrows", "desc": "+12% bow damage", "tier": 1, "cost": 1, "prereq": "ar_root", "materials": {}, "effect": {"bow_damage": 0.12}},
		{"id": "ar_m2", "branch": 0, "col": 0.5, "name": "Steady Aim", "desc": "+8% crit chance", "tier": 2, "cost": 1, "prereq": "ar_m1", "materials": {}, "effect": {"crit_chance": 0.08}},
		{"id": "ar_m3", "branch": 0, "col": 0.5, "name": "Deadeye", "desc": "KEYSTONE: +12% crit chance, +30% crit damage", "tier": 3, "cost": 2, "prereq": "ar_m2", "materials": {"slime": 3}, "effect": {"crit_chance": 0.12, "crit_damage": 0.30}, "keystone": true},
		{"id": "ar_m4a", "branch": 0, "col": 0.0, "name": "Piercing Shot", "desc": "FORK: arrows punch THROUGH 2 enemies — line them up", "tier": 4, "cost": 3, "prereq": "ar_m3", "materials": {"iron_shard": 2}, "effect": {"arrow_pierce": 2.0}, "keystone": true, "exclusive": "ar0"},
		{"id": "ar_m4b", "branch": 0, "col": 1.0, "name": "Killshot", "desc": "FORK: instantly slay any non-boss below 18% HP", "tier": 4, "cost": 3, "prereq": "ar_m3", "materials": {"iron_shard": 2}, "effect": {"execute_threshold": 0.18}, "keystone": true, "exclusive": "ar0"},
		{"id": "ar_m5", "branch": 0, "col": 0.5, "name": "Deadshot", "desc": "+30% bow damage", "tier": 5, "cost": 2, "prereq": ["ar_m4a", "ar_m4b"], "materials": {"ember_crystal": 1}, "effect": {"bow_damage": 0.30}},
		{"id": "ar_m6", "branch": 0, "col": 0.5, "name": "Bullseye", "desc": "KEYSTONE: +12% crit chance, +40% crit damage", "tier": 6, "cost": 4, "prereq": "ar_m5", "materials": {"void_essence": 2}, "effect": {"crit_chance": 0.12, "crit_damage": 0.40}, "keystone": true},
		{"id": "ar_m7", "branch": 0, "col": 0.5, "name": "Skyfall", "desc": "ULTIMATE: +60% bow damage, +15% crit, arrows pierce +1 more foe.", "tier": 7, "cost": 6, "prereq": "ar_m6", "materials": {"void_essence": 3, "ancient_relic": 2}, "effect": {"bow_damage": 0.60, "crit_chance": 0.15, "arrow_pierce": 1.0}, "keystone": true},
		# === Ranger (1): seeker vs evasion, ending in tempest ===
		{"id": "ar_r1", "branch": 1, "col": 2.5, "name": "Light Feet", "desc": "+8% move speed", "tier": 1, "cost": 1, "prereq": "ar_root", "materials": {}, "effect": {"move_speed": 0.08}},
		{"id": "ar_r2", "branch": 1, "col": 2.5, "name": "Fast Nocking", "desc": "-10% bow cooldown", "tier": 2, "cost": 1, "prereq": "ar_r1", "materials": {}, "effect": {"bow_cooldown": 0.10}},
		{"id": "ar_r3", "branch": 1, "col": 2.5, "name": "Twin Shot", "desc": "KEYSTONE: every draw looses +1 arrow", "tier": 3, "cost": 2, "prereq": "ar_r2", "materials": {"slime": 3}, "effect": {"multishot": 1.0}, "keystone": true},
		{"id": "ar_r4a", "branch": 1, "col": 2.0, "name": "Seeker Arrows", "desc": "FORK: your arrows curve to hunt enemies mid-flight", "tier": 4, "cost": 3, "prereq": "ar_r3", "materials": {"ember_crystal": 2}, "effect": {"arrow_homing": 1.0}, "keystone": true, "exclusive": "ar1"},
		{"id": "ar_r4b", "branch": 1, "col": 3.0, "name": "Evasion", "desc": "FORK: 15% chance to dodge a hit entirely, +8% move speed", "tier": 4, "cost": 3, "prereq": "ar_r3", "materials": {"ember_crystal": 2}, "effect": {"dodge_chance": 0.15, "move_speed": 0.08}, "keystone": true, "exclusive": "ar1"},
		{"id": "ar_r5", "branch": 1, "col": 2.5, "name": "Windrunner", "desc": "+15% move speed, -12% bow cooldown", "tier": 5, "cost": 2, "prereq": ["ar_r4a", "ar_r4b"], "materials": {"ember_crystal": 1}, "effect": {"move_speed": 0.15, "bow_cooldown": 0.12}},
		{"id": "ar_r6", "branch": 1, "col": 2.5, "name": "Arrow Storm", "desc": "KEYSTONE: +1 more arrow per draw (3 with Twin Shot)", "tier": 6, "cost": 4, "prereq": "ar_r5", "materials": {"void_essence": 2}, "effect": {"multishot": 1.0}, "keystone": true},
		{"id": "ar_r7", "branch": 1, "col": 2.5, "name": "Tempest", "desc": "ULTIMATE: +1 arrow (4 total), -25% bow cd, +20% move, arrows home.", "tier": 7, "cost": 6, "prereq": "ar_r6", "materials": {"void_essence": 3, "ancient_relic": 2}, "effect": {"multishot": 1.0, "bow_cooldown": 0.25, "move_speed": 0.20, "arrow_homing": 1.0}, "keystone": true},
		# === Warden (2): PURE elemental DoT — venom, then frost OR flame, contagion ===
		{"id": "ar_wd1", "branch": 2, "col": 4.5, "name": "Toxic Coating", "desc": "+10% bow damage", "tier": 1, "cost": 1, "prereq": "ar_root", "materials": {}, "effect": {"bow_damage": 0.10}},
		{"id": "ar_wd2", "branch": 2, "col": 4.5, "name": "Barbed Tips", "desc": "+8% crit chance", "tier": 2, "cost": 1, "prereq": "ar_wd1", "materials": {}, "effect": {"crit_chance": 0.08}},
		{"id": "ar_wd3", "branch": 2, "col": 4.5, "name": "Venom Arrows", "desc": "KEYSTONE: your arrows poison what they hit (6 dmg/sec)", "tier": 3, "cost": 2, "prereq": "ar_wd2", "materials": {"slime": 3}, "effect": {"on_hit_poison": 6.0}, "keystone": true},
		{"id": "ar_wd4a", "branch": 2, "col": 4.0, "name": "Frost Arrows", "desc": "FORK: arrows also CHILL — slowed foes can't close on you", "tier": 4, "cost": 3, "prereq": "ar_wd3", "materials": {"iron_shard": 2}, "effect": {"on_hit_slow": 1.0}, "keystone": true, "exclusive": "ar2"},
		{"id": "ar_wd4b", "branch": 2, "col": 5.0, "name": "Flame Arrows", "desc": "FORK: arrows also BURN — poison + fire stack together", "tier": 4, "cost": 3, "prereq": "ar_wd3", "materials": {"iron_shard": 2}, "effect": {"on_hit_burn": 6.0}, "keystone": true, "exclusive": "ar2"},
		{"id": "ar_wd5", "branch": 2, "col": 4.5, "name": "Deep Wounds", "desc": "+4 poison/sec, +20% bow damage", "tier": 5, "cost": 2, "prereq": ["ar_wd4a", "ar_wd4b"], "materials": {"ember_crystal": 1}, "effect": {"on_hit_poison": 4.0, "bow_damage": 0.20}},
		{"id": "ar_wd6", "branch": 2, "col": 4.5, "name": "Plaguebearer", "desc": "KEYSTONE: +6 poison/sec, +8% crit", "tier": 6, "cost": 4, "prereq": "ar_wd5", "materials": {"void_essence": 2}, "effect": {"on_hit_poison": 6.0, "crit_chance": 0.08}, "keystone": true},
		{"id": "ar_wd7", "branch": 2, "col": 4.5, "name": "Contagion", "desc": "ULTIMATE: arrows spread poison to nearby foes on hit. +6 poison/sec, +30% bow dmg.", "tier": 7, "cost": 6, "prereq": "ar_wd6", "materials": {"void_essence": 3, "ancient_relic": 2}, "effect": {"poison_spread": 1.0, "on_hit_poison": 6.0, "bow_damage": 0.30}, "keystone": true},
	],
	"Mage": [
		{"id": "mg_root", "branch": -1, "col": 2.5, "name": "Way of the Arcane", "desc": "-5% wand cooldown", "tier": 0, "cost": 1, "prereq": "", "materials": {}, "effect": {"wand_cooldown": 0.05}},
		# === Elementalist (0): overcharge vs wildfire, ending in cataclysm ===
		{"id": "mg_e1", "branch": 0, "col": 0.5, "name": "Kindling", "desc": "+12% wand damage", "tier": 1, "cost": 1, "prereq": "mg_root", "materials": {}, "effect": {"wand_damage": 0.12}},
		{"id": "mg_e2", "branch": 0, "col": 0.5, "name": "Focused Mind", "desc": "-10% wand cooldown", "tier": 2, "cost": 1, "prereq": "mg_e1", "materials": {}, "effect": {"wand_cooldown": 0.10}},
		{"id": "mg_e3", "branch": 0, "col": 0.5, "name": "Ignite", "desc": "KEYSTONE: your wand hits set enemies ablaze (6 burn/sec)", "tier": 3, "cost": 2, "prereq": "mg_e2", "materials": {"slime": 3}, "effect": {"on_hit_burn": 6.0}, "keystone": true},
		{"id": "mg_e4a", "branch": 0, "col": 0.0, "name": "Overcharge", "desc": "FORK: +25% wand damage, +8% crit — raw arcane power", "tier": 4, "cost": 3, "prereq": "mg_e3", "materials": {"ember_crystal": 2}, "effect": {"wand_damage": 0.25, "crit_chance": 0.08}, "keystone": true, "exclusive": "mg0"},
		{"id": "mg_e4b", "branch": 0, "col": 1.0, "name": "Wildfire", "desc": "FORK: your burns LEAP to nearby foes on hit. +4 burn/sec", "tier": 4, "cost": 3, "prereq": "mg_e3", "materials": {"ember_crystal": 2}, "effect": {"combustion": 1.0, "on_hit_burn": 4.0}, "keystone": true, "exclusive": "mg0"},
		{"id": "mg_e5", "branch": 0, "col": 0.5, "name": "Arcane Surge", "desc": "-20% wand cooldown", "tier": 5, "cost": 2, "prereq": ["mg_e4a", "mg_e4b"], "materials": {"ember_crystal": 1}, "effect": {"wand_cooldown": 0.20}},
		{"id": "mg_e6", "branch": 0, "col": 0.5, "name": "Conflagration", "desc": "KEYSTONE: +8 burn/sec, +20% wand damage", "tier": 6, "cost": 4, "prereq": "mg_e5", "materials": {"void_essence": 2}, "effect": {"on_hit_burn": 8.0, "wand_damage": 0.20}, "keystone": true},
		{"id": "mg_e7", "branch": 0, "col": 0.5, "name": "Cataclysm", "desc": "ULTIMATE: burns leap to nearby foes. +55% wand dmg, +8 burn/sec, +15% crit.", "tier": 7, "cost": 6, "prereq": "mg_e6", "materials": {"void_essence": 3, "ancient_relic": 2}, "effect": {"combustion": 1.0, "wand_damage": 0.55, "on_hit_burn": 8.0, "crit_chance": 0.15}, "keystone": true},
		# === Sage (1): overflow-battery vs far-hand, ending in transcendence ===
		{"id": "mg_s1", "branch": 1, "col": 2.5, "name": "Scholar", "desc": "+25 max mana", "tier": 1, "cost": 1, "prereq": "mg_root", "materials": {}, "effect": {"max_mana": 25.0}},
		{"id": "mg_s2", "branch": 1, "col": 2.5, "name": "Channeling", "desc": "-12% wand cooldown", "tier": 2, "cost": 1, "prereq": "mg_s1", "materials": {}, "effect": {"wand_cooldown": 0.12}},
		{"id": "mg_s3", "branch": 1, "col": 2.5, "name": "Mana Flow", "desc": "KEYSTONE: +40 max mana, +40% mana regen", "tier": 3, "cost": 2, "prereq": "mg_s2", "materials": {"slime": 3}, "effect": {"max_mana": 40.0, "mana_regen": 0.40}, "keystone": true},
		{"id": "mg_s4a", "branch": 1, "col": 2.0, "name": "Overflow", "desc": "FORK: +50 max mana, +18% wand damage — a deep arcane battery", "tier": 4, "cost": 3, "prereq": "mg_s3", "materials": {"ember_crystal": 2}, "effect": {"max_mana": 50.0, "wand_damage": 0.18}, "keystone": true, "exclusive": "mg1"},
		{"id": "mg_s4b", "branch": 1, "col": 3.0, "name": "Focusing Lens", "desc": "FORK: HOLD attack with a wand to channel a beam. Its damage ramps the longer it stays on a target — moving or breaking line of sight cuts it.", "tier": 4, "cost": 3, "prereq": "mg_s3", "materials": {"ember_crystal": 2}, "effect": {"beam_channel": 1.0, "wand_damage": 0.10}, "keystone": true, "exclusive": "mg1"},
		{"id": "mg_s5", "branch": 1, "col": 2.5, "name": "Time Warp", "desc": "-20% wand cooldown, +50% mana regen", "tier": 5, "cost": 2, "prereq": ["mg_s4a", "mg_s4b"], "materials": {"ember_crystal": 1}, "effect": {"wand_cooldown": 0.20, "mana_regen": 0.50}},
		{"id": "mg_s6", "branch": 1, "col": 2.5, "name": "Sustained Focus", "desc": "KEYSTONE: +20% wand damage. If you channel, the beam ramps to a far higher peak (+0.6x).", "tier": 6, "cost": 4, "prereq": "mg_s5", "materials": {"void_essence": 2}, "effect": {"wand_damage": 0.20, "beam_ramp": 0.6}, "keystone": true},
		{"id": "mg_s7", "branch": 1, "col": 2.5, "name": "Transcendence", "desc": "ULTIMATE: +60 max mana, +100% regen, -20% wand cd, and +0.5x beam peak.", "tier": 7, "cost": 6, "prereq": "mg_s6", "materials": {"void_essence": 3, "ancient_relic": 2}, "effect": {"max_mana": 60.0, "mana_regen": 1.0, "wand_cooldown": 0.20, "beam_ramp": 0.5}, "keystone": true},
		# === Mystic (2): greater-barrier vs blink, ending in spellblade avatar ===
		{"id": "mg_m1", "branch": 2, "col": 4.5, "name": "Arcane Ward", "desc": "+20 max health", "tier": 1, "cost": 1, "prereq": "mg_root", "materials": {}, "effect": {"max_health": 20.0}},
		{"id": "mg_m2", "branch": 2, "col": 4.5, "name": "Mana Shell", "desc": "+25 max mana", "tier": 2, "cost": 1, "prereq": "mg_m1", "materials": {}, "effect": {"max_mana": 25.0}},
		{"id": "mg_m3", "branch": 2, "col": 4.5, "name": "Mana Barrier", "desc": "KEYSTONE: 40% of damage taken is paid from Mana, not HP", "tier": 3, "cost": 2, "prereq": "mg_m2", "materials": {"slime": 3}, "effect": {"mana_shield": 0.40}, "keystone": true},
		{"id": "mg_m4a", "branch": 2, "col": 4.0, "name": "Greater Barrier", "desc": "FORK: +20% barrier (60% total), +40 max mana — a wall of mana", "tier": 4, "cost": 3, "prereq": "mg_m3", "materials": {"ember_crystal": 2}, "effect": {"mana_shield": 0.20, "max_mana": 40.0}, "keystone": true, "exclusive": "mg2"},
		{"id": "mg_m4b", "branch": 2, "col": 5.0, "name": "Blink Step", "desc": "FORK: +12% move speed, 10% dodge — never be where the blow lands", "tier": 4, "cost": 3, "prereq": "mg_m3", "materials": {"ember_crystal": 2}, "effect": {"move_speed": 0.12, "dodge_chance": 0.10}, "keystone": true, "exclusive": "mg2"},
		{"id": "mg_m5", "branch": 2, "col": 4.5, "name": "Fortified Mind", "desc": "+40 max health, +5% damage reduction", "tier": 5, "cost": 2, "prereq": ["mg_m4a", "mg_m4b"], "materials": {"ember_crystal": 1}, "effect": {"max_health": 40.0, "damage_reduction": 0.05}},
		{"id": "mg_m6", "branch": 2, "col": 4.5, "name": "Spellblade", "desc": "KEYSTONE: your wand damage scales with max Mana (+0.2% per point)", "tier": 6, "cost": 4, "prereq": "mg_m5", "materials": {"void_essence": 2}, "effect": {"mana_to_damage": 0.002}, "keystone": true},
		{"id": "mg_m7", "branch": 2, "col": 4.5, "name": "Avatar of Magic", "desc": "ULTIMATE: +80 HP, +60 mana, +20% barrier, +0.1%/mana wand damage.", "tier": 7, "cost": 6, "prereq": "mg_m6", "materials": {"void_essence": 3, "ancient_relic": 2}, "effect": {"max_health": 80.0, "max_mana": 60.0, "mana_shield": 0.20, "mana_to_damage": 0.001}, "keystone": true},
	],
	# Unlockable only after finishing the game -- a locked teaser for now.
	"Shadow Monarch": [
		{"id": "nc_root", "branch": -1, "col": 2.5, "name": "Shadow's Pact", "desc": "???", "tier": 0, "cost": 1, "prereq": "", "materials": {}, "effect": {}},
		{"id": "nc_b1", "branch": 0, "col": 0.5, "name": "???", "desc": "???", "tier": 1, "cost": 1, "prereq": "nc_root", "materials": {}, "effect": {}},
		{"id": "nc_b2", "branch": 1, "col": 2.5, "name": "???", "desc": "???", "tier": 1, "cost": 1, "prereq": "nc_root", "materials": {}, "effect": {}},
		{"id": "nc_b3", "branch": 2, "col": 4.5, "name": "???", "desc": "???", "tier": 1, "cost": 1, "prereq": "nc_root", "materials": {}, "effect": {}},
	],
}

const CLASS_COLORS = {
	"Sword": Color(0.78, 0.28, 0.18),
	"Archer": Color(0.28, 0.65, 0.3),
	"Mage": Color(0.5, 0.35, 0.85),
	"Shadow Monarch": Color(0.2, 0.55, 0.4),
}

static func get_node_by_id(node_id: String) -> Dictionary:
	for tree in TREES.values():
		for node in tree:
			if node.id == node_id:
				return node
	return {}

# Prereqs. `prereq` is a node id, "" (none), or an Array meaning "any of these"
# (used where a fork reconverges -- reachable from either chosen path).
static func prereq_met(node: Dictionary) -> bool:
	var pr = node.get("prereq", "")
	if pr is Array:
		if pr.is_empty():
			return true
		for pid in pr:
			if GameState.is_skill_unlocked(pid):
				return true
		return false
	if pr == "":
		return true
	return GameState.is_skill_unlocked(pr)

# Every node sharing an `exclusive` group key -- the fork siblings.
static func nodes_in_exclusive_group(grp: String) -> Array:
	var out := []
	if grp == "":
		return out
	for tree in TREES.values():
		for n in tree:
			if n.get("exclusive", "") == grp:
				out.append(n)
	return out

# True if a DIFFERENT node in this node's exclusive group is already unlocked --
# meaning this path is locked out forever (the opportunity cost of the fork).
# Enforced even in the sandbox: the whole point is that you can't have both.
static func is_exclusive_blocked(node: Dictionary) -> bool:
	var grp = node.get("exclusive", "")
	if grp == "":
		return false
	if GameState.is_skill_unlocked(node.id):
		return false
	for other in nodes_in_exclusive_group(grp):
		if other.id != node.id and GameState.is_skill_unlocked(other.id):
			return true
	return false
