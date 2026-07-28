class_name WeaponRoster
extends RefCounted

# ============================ THE GENERATED LADDER ============================
# The 350-weapon roster's engine (weapons overhaul wave 2, 2026-07-28).
# Hand-writing 350 full ITEM_DEFS dicts would drown inventory.gd, so ladder
# weapons live here as ONE COMPACT ROW each and expand at first use into
# exactly the def shape everything already reads. Inventory.get_item_def and
# get_grade consult this table after their own (see the choke points there),
# so to every other system a roster weapon IS an ordinary item.
#
# Row: [id, name, class, tier(1-8), behavior, damage, cooldown, extras{}]
#   class:    melee | spear | bow | wand | staff  (staff = melee + the Wukong
#             extending-reach special)
#   behavior: arc cleave crescent thrust jab_volley shot volley rapid seeker
#             lob_a bolt fire frost ricochet cluster lob tome sentry
#             orbiter lash staff
#   extras:   status: burn_w|slow_w|poison_w   count/shards/bounces/aoe/
#             radius/dur/dwell/p_damage/pierce/knockup -- behavior knobs
#
# Names are ALL fresh (dev: "don't do same names exactly"); Terraria is the
# mechanical reference, never the text. Tier maps straight onto the 8-grade
# ladder; drops ride pool_for_level() from dungeon_interior.roll_gear_drop.

const TIER_GRADE = ["", "common", "uncommon", "rare", "epic", "legendary",
	"mythic", "ascended", "monarch"]

# What floor bracket each tier drops in (lo, hi). Overlapping on purpose --
# a lucky shallow run can taste the next tier early, Terraria-style.
const TIER_FLOORS = [[0, 0], [1, 9], [5, 18], [12, 32], [24, 52], [42, 72],
	[58, 88], [70, 97], [88, 100]]

const ROWS = [
	# ---------------- TIER 1 - COMMON (floors 1-9) ----------------
	["wpn_oakcudgel",    "Oak Cudgel",           "melee", 1, "arc",       8,  0.55, {}],
	["wpn_mongrelknife", "Mongrel Knife",        "melee", 1, "arc",       5,  0.28, {}],
	["wpn_pitshovel",    "Pit Shovel",           "melee", 1, "cleave",    11, 0.85, {}],
	["wpn_barrelstave",  "Barrel Stave",         "melee", 1, "arc",       7,  0.45, {}],
	["wpn_rustfang",     "Rustfang",             "melee", 1, "arc",       6,  0.35, {"status": "poison_w"}],
	["wpn_fencepike",    "Fence Pike",           "spear", 1, "thrust",    9,  0.8,  {}],
	["wpn_eelspear",     "Eelcatcher",           "spear", 1, "thrust",    7,  0.6,  {}],
	["wpn_orchardbow",   "Orchard Bow",          "bow",   1, "shot",      7,  0.55, {}],
	["wpn_gutterbow",    "Gutter Bow",           "bow",   1, "shot",      6,  0.45, {}],
	["wpn_tallowwand",   "Tallow Wand",          "wand",  1, "bolt",      9,  0.6,  {}],
	["wpn_chalkwand",    "Chalk Wand",           "wand",  1, "bolt",      7,  0.45, {}],
	["wpn_willowswitch", "Willow Switch",        "staff", 1, "staff",     6,  0.4,  {}],
	# ---------------- TIER 2 - UNCOMMON (floors 5-18) ----------------
	["wpn_gravespade",   "Gravekeeper's Spade",  "melee", 2, "cleave",    14, 0.8,  {}],
	["wpn_lanternblade", "Lanternblade",         "melee", 2, "arc",       10, 0.45, {"status": "burn_w"}],
	["wpn_millsickle",   "Mill Sickle",          "melee", 2, "arc",       9,  0.32, {}],
	["wpn_bonepick",     "Bonepick",             "melee", 2, "arc",       12, 0.6,  {}],
	["wpn_coldiron",     "Cold Iron Edge",       "melee", 2, "arc",       11, 0.5,  {"status": "slow_w"}],
	["wpn_ratterdart",   "Ratter's Dart",        "melee", 2, "ricochet",  8,  0.7,  {"bounces": 2}],
	["wpn_boarspit",     "Boarspit",             "spear", 2, "thrust",    12, 0.75, {}],
	["wpn_wallpike",     "Wallwatcher's Pike",   "spear", 2, "thrust",    14, 0.95, {}],
	["wpn_reedjavelin",  "Reed Javelins",        "spear", 2, "jab_volley", 9, 0.9,  {"count": 2}],
	["wpn_ashbow",       "Ashwood Bow",          "bow",   2, "shot",      10, 0.5,  {}],
	["wpn_ferrybow",     "Ferryman's Bow",       "bow",   2, "volley",    7,  0.65, {"count": 2}],
	["wpn_stingerbow",   "Stinger",              "bow",   2, "rapid",     5,  0.22, {}],
	["wpn_mosswand",     "Mosslight Wand",       "wand",  2, "bolt",      12, 0.55, {}],
	["wpn_cinderrod",    "Cinder Rod",           "wand",  2, "fire",      14, 0.8,  {"aoe": 70}],
	["wpn_brookwand",    "Brookwand",            "wand",  2, "frost",     10, 0.5,  {"status": "slow_w"}],
	# ---------------- TIER 3 - RARE (floors 12-32) ----------------
	["wpn_watchmansword","Watchman's Justice",   "melee", 3, "arc",       15, 0.5,  {}],
	["wpn_furrowscythe", "Furrow Scythe",        "melee", 3, "cleave",    19, 0.9,  {}],
	["wpn_adderfang",    "Adderfang",            "melee", 3, "arc",       11, 0.3,  {"status": "poison_w"}],
	["wpn_bellhammer",   "Bell Hammer",          "melee", 3, "cleave",    22, 1.0,  {"knockup": true}],
	["wpn_squallblade",  "Squallblade",          "melee", 3, "crescent",  13, 0.55, {"p_damage": 11}],
	["wpn_thornwheel",   "Thornwheel",           "melee", 3, "orbiter",   12, 0.8,  {"dwell": 1.8}],
	["wpn_hookbill",     "Hookbill",             "melee", 3, "ricochet",  12, 0.65, {"bounces": 3}],
	["wpn_shrikelash",   "Shrike's Tail",        "melee", 3, "lash",      12, 0.85, {}],
	["wpn_gatecleaver",  "Gatecleaver",          "spear", 3, "thrust",    17, 0.85, {}],
	["wpn_heronlance",   "Heron Lance",          "spear", 3, "thrust",    14, 0.6,  {}],
	["wpn_stormprong",   "Stormprong",           "spear", 3, "jab_volley", 12, 0.95, {"count": 3}],
	["wpn_veilbow",      "Veilpiercer",          "bow",   3, "shot",      16, 0.6,  {"pierce": true}],
	["wpn_larkbow",      "Lark's Reply",         "bow",   3, "rapid",     7,  0.2,  {}],
	["wpn_twinnock",     "Twinnock Bow",         "bow",   3, "volley",    10, 0.6,  {"count": 2}],
	["wpn_emberarc",     "Emberarc Bow",         "bow",   3, "lob_a",     18, 0.95, {"aoe": 85}],
	["wpn_paleseeker",   "Pale Seeker",          "bow",   3, "seeker",    12, 0.7,  {}],
	["wpn_saltwand",     "Saltbinder",           "wand",  3, "bolt",      16, 0.55, {}],
	["wpn_marshlight",   "Marshlight Lantern",   "wand",  3, "cluster",   15, 0.8,  {"shards": 4}],
	["wpn_leadrod",      "Leaden Judgement",     "wand",  3, "lob",       21, 1.05, {"aoe": 95}],
	["wpn_finchbolt",    "Finchbolt",            "wand",  3, "ricochet",  13, 0.6,  {"bounces": 3}],
	["wpn_droverstaff",  "Drover's Crook",       "staff", 3, "staff",     12, 0.45, {}],
	# ---------------- TIER 4 - EPIC (floors 24-52) ----------------
	["wpn_duskrender",   "Duskrender",           "melee", 4, "arc",       19, 0.45, {}],
	["wpn_tolloftheend", "Toll of the End",      "melee", 4, "cleave",    28, 1.05, {"knockup": true}],
	["wpn_vespersting",  "Vesper Sting",         "melee", 4, "arc",       13, 0.26, {"status": "poison_w"}],
	["wpn_howlpiece",    "Howlpiece",            "melee", 4, "crescent",  17, 0.55, {"p_damage": 15}],
	["wpn_winterwheel",  "Winterwheel",          "melee", 4, "orbiter",   16, 0.8,  {"dwell": 2.4, "status": "slow_w"}],
	["wpn_gloamlash",    "Gloaming Lash",        "melee", 4, "lash",      17, 0.85, {"status": "burn_w"}],
	["wpn_reaperrebuke", "Reaper's Rebuke",      "melee", 4, "ricochet",  16, 0.6,  {"bounces": 4}],
	["wpn_sunderpike",   "Sunder Pike",          "spear", 4, "thrust",    23, 0.85, {}],
	["wpn_galeprong",    "Galeprong",            "spear", 4, "jab_volley", 15, 0.9, {"count": 4}],
	["wpn_midnightlance","Midnight Lance",       "spear", 4, "thrust",    19, 0.6,  {"status": "slow_w"}],
	["wpn_curfewbow",    "Curfew Bow",           "bow",   4, "shot",      21, 0.6,  {"pierce": true}],
	["wpn_choirbow",     "Choir of Points",      "bow",   4, "volley",    12, 0.6,  {"count": 3}],
	["wpn_hummingbow",   "Hummingbird",          "bow",   4, "rapid",     9,  0.18, {}],
	["wpn_falconoath",   "Falcon's Oath",        "bow",   4, "seeker",    16, 0.65, {}],
	["wpn_sapperanswer", "Sapper's Answer",      "bow",   4, "lob_a",     24, 1.0,  {"aoe": 100}],
	["wpn_prismbreak",   "Prismbreak",           "wand",  4, "cluster",   20, 0.8,  {"shards": 6}],
	["wpn_stormdebt",    "Stormcaller's Debt",   "wand",  4, "tome",      11, 1.4,  {"radius": 140}],
	["wpn_wispwarden",   "Wisp Warden",          "wand",  4, "sentry",    10, 1.2,  {"dur": 18}],
	["wpn_nightbolt",    "Nightbolt",            "wand",  4, "ricochet",  17, 0.6,  {"bounces": 4}],
	["wpn_magmawrit",    "Magma Writ",           "wand",  4, "fire",      26, 0.85, {"aoe": 120, "status": "burn_w"}],
	["wpn_pilgrimstaff", "Pilgrim's Milestone",  "staff", 4, "staff",     15, 0.45, {}],
	# ---------------- TIER 5 - LEGENDARY (floors 42-72) ----------------
	["wpn_daybreakedge", "Daybreak Edge",        "melee", 5, "arc",       24, 0.42, {"status": "burn_w"}],
	["wpn_worldtoll",    "Worldtoll Maul",       "melee", 5, "cleave",    36, 1.1,  {"knockup": true}],
	["wpn_quietwheel",   "Wheel of Quiet",       "melee", 5, "orbiter",   21, 0.8,  {"dwell": 2.8}],
	["wpn_serpentsermon","Serpent's Sermon",     "melee", 5, "lash",      22, 0.85, {"status": "poison_w"}],
	["wpn_finalverdict", "Final Verdict",        "spear", 5, "thrust",    29, 0.8,  {}],
	["wpn_skyquill",     "Sky of Quills",        "spear", 5, "jab_volley", 18, 0.9, {"count": 5}],
	["wpn_eventide",     "Eventide",             "bow",   5, "volley",    15, 0.55, {"count": 3}],
	["wpn_lastlark",     "The Last Lark",        "bow",   5, "rapid",     11, 0.16, {}],
	["wpn_omenseeker",   "Omen Seeker",          "bow",   5, "seeker",    20, 0.6,  {}],
	["wpn_starfallbow",  "Starfall Bow",         "bow",   5, "lob_a",     30, 1.0,  {"aoe": 115}],
	["wpn_grandrains",   "Grand Tome of Rains",  "wand",  5, "tome",      14, 1.35, {"radius": 155}],
	["wpn_twinburst",    "Twinburst Sceptre",    "wand",  5, "cluster",   25, 0.8,  {"shards": 7}],
	["wpn_kingsransom",  "King's Ransom",        "wand",  5, "ricochet",  22, 0.6,  {"bounces": 5}],
	["wpn_longwatch",    "Warden's Long Watch",  "wand",  5, "sentry",    14, 1.2,  {"dur": 22}],
	["wpn_summitstaff",  "Summit That Walks",    "staff", 5, "staff",     19, 0.42, {}],
	# ---------------- TIER 6 - MYTHIC (floors 58-88) ----------------
	["wpn_griefedge",    "Grief Made Sharp",     "melee", 6, "arc",       30, 0.4,  {}],
	["wpn_hushfall",     "Hushfall",             "melee", 6, "cleave",    44, 1.1,  {"knockup": true, "status": "slow_w"}],
	["wpn_eclipsewheel", "Eclipse Wheel",        "melee", 6, "orbiter",   27, 0.8,  {"dwell": 3.2}],
	["wpn_dawntongue",   "Dawn's Long Tongue",   "melee", 6, "lash",      28, 0.82, {"status": "burn_w"}],
	["wpn_horizonpike",  "Horizon Pike",         "spear", 6, "thrust",    36, 0.78, {}],
	["wpn_meteorquill",  "Meteor Quills",        "spear", 6, "jab_volley", 23, 0.88, {"count": 5, "status": "burn_w"}],
	["wpn_middaybow",    "Midday Massacre",      "bow",   6, "volley",    19, 0.52, {"count": 4}],
	["wpn_ghostrepeater","Ghost Repeater",       "bow",   6, "rapid",     14, 0.15, {}],
	["wpn_lodestar",     "Lodestar",             "bow",   6, "seeker",    25, 0.58, {}],
	["wpn_cometfall",    "Cometfall",            "bow",   6, "lob_a",     38, 1.0,  {"aoe": 130, "status": "burn_w"}],
	["wpn_deluge",       "The Deluge",           "wand",  6, "tome",      18, 1.3,  {"radius": 170}],
	["wpn_shatterhymn",  "Shatterhymn",          "wand",  6, "cluster",   31, 0.78, {"shards": 8}],
	["wpn_debtcollector","The Debt Collector",   "wand",  6, "ricochet",  27, 0.58, {"bounces": 6}],
	["wpn_twelfthpillar","Twelfth Pillar",       "staff", 6, "staff",     24, 0.4,  {}],
	# ---------------- TIER 7 - ASCENDED (floors 70-97) ----------------
	["wpn_afterlight",   "Afterlight",           "melee", 7, "arc",       37, 0.38, {"status": "burn_w"}],
	["wpn_worldsedge",   "Edge of the World",    "melee", 7, "crescent",  33, 0.55, {"p_damage": 30}],
	["wpn_ascendwheel",  "Wheel of Ascension",   "melee", 7, "orbiter",   33, 0.78, {"dwell": 3.6, "status": "slow_w"}],
	["wpn_novatongue",   "Nova Tongue",          "melee", 7, "lash",      35, 0.8,  {"status": "burn_w"}],
	["wpn_zenithpike",   "Zenith",               "spear", 7, "thrust",    44, 0.75, {}],
	["wpn_ninthcommand", "Ninth Commandment",    "bow",   7, "volley",    24, 0.5,  {"count": 4, "pierce": true}],
	["wpn_heavenstring", "Heavenstring",         "bow",   7, "seeker",    31, 0.55, {}],
	["wpn_highflood",    "The High Flood",       "wand",  7, "tome",      23, 1.25, {"radius": 185}],
	["wpn_riftburst",    "Riftburst Rod",        "wand",  7, "cluster",   38, 0.75, {"shards": 9}],
	["wpn_asphodelpost", "Asphodel Post",        "wand",  7, "sentry",    22, 1.15, {"dur": 26}],
	["wpn_skypillar",    "Pillar of the Sky",    "staff", 7, "staff",     30, 0.38, {}],
	# ---------------- TIER 8 - MONARCH (floors 88-100) ----------------
	["wpn_crownsorrow",  "The Crown's Sorrow",   "melee", 8, "arc",       46, 0.36, {"status": "slow_w"}],
	["wpn_kingdomwheel", "A Kingdom, Turning",   "melee", 8, "orbiter",   41, 0.75, {"dwell": 4.0}],
	["wpn_lastword",     "The Last Word",        "melee", 8, "lash",      44, 0.78, {"status": "burn_w"}],
	["wpn_regicide",     "Regicide",             "spear", 8, "thrust",    55, 0.72, {}],
	["wpn_thronestrings","Throne of Strings",    "bow",   8, "volley",    30, 0.48, {"count": 5, "pierce": true}],
	["wpn_soulflood",    "Flood of Souls",       "wand",  8, "tome",      29, 1.2,  {"radius": 200}],
	["wpn_skymeasure",   "Staff That Measures the Sky", "staff", 8, "staff", 38, 0.36, {}],
]

# Palette per class -- tinted toward the tier's grade colour so a monarch bow
# READS monarch in the hand and the hotbar alike (item-visual rule).
const CLASS_BASE_COLOR = {
	"melee": Color(0.78, 0.8, 0.86), "spear": Color(0.85, 0.8, 0.6),
	"bow": Color(0.62, 0.72, 0.5), "wand": Color(0.7, 0.62, 0.9),
	"staff": Color(0.6, 0.72, 0.45),
}

static var _defs: Dictionary = {}
static var _grades: Dictionary = {}
static var _pools: Array = []          # per tier: Array of ids

static func _ensure_built() -> void:
	if not _defs.is_empty():
		return
	_pools = []
	_pools.resize(9)
	for i in range(9):
		_pools[i] = []
	for row in ROWS:
		var id: String = row[0]
		var d := _expand(row)
		_defs[id] = d
		_grades[id] = TIER_GRADE[int(row[3])]
		_pools[int(row[3])].append(id)

static func defs() -> Dictionary:
	_ensure_built()
	return _defs

static func get_def(id: String) -> Dictionary:
	_ensure_built()
	return _defs.get(id, {})

static func get_grade(id: String) -> String:
	_ensure_built()
	return _grades.get(id, "")

static func has_id(id: String) -> bool:
	_ensure_built()
	return _defs.has(id)

# Every roster id whose tier bracket admits this floor -- the dungeon's
# roll_gear_drop unions this with its hand-authored pools.
static func pool_for_level(level: int) -> Array:
	_ensure_built()
	var out: Array = []
	for t in range(1, 9):
		var lo: int = TIER_FLOORS[t][0]
		var hi: int = TIER_FLOORS[t][1]
		if level >= lo and level <= hi:
			out += _pools[t]
	return out

static func all_ids() -> Array:
	_ensure_built()
	return _defs.keys()

# ---------------------------------------------------------------- expansion
static func _expand(row: Array) -> Dictionary:
	var id: String = row[0]
	var dname: String = row[1]
	var klass: String = row[2]
	var tier: int = int(row[3])
	var behavior: String = row[4]
	var dmg: int = int(row[5])
	var cd: float = float(row[6])
	var ex: Dictionary = row[7]

	var grade_col: Color = Inventory.GRADE_DEFS[TIER_GRADE[tier]]["color"]
	var base_col: Color = CLASS_BASE_COLOR.get(klass, Color(0.8, 0.8, 0.8))
	var col := base_col.lerp(grade_col, 0.45)

	var wtype := klass
	if klass == "staff":
		wtype = "melee"
	var reach := 46.0
	var area := Vector2(60, 36)
	var icon := Vector2(52, 12)
	var icon_off := 20.0
	match klass:
		"spear":
			reach = 58.0
			area = Vector2(74, 38)
			icon = Vector2(104, 8)
			icon_off = 16.0
		"bow":
			reach = 90.0
			area = Vector2(110, 40)
			icon = Vector2(14, 14)
			icon_off = 18.0
		"wand":
			reach = 30.0
			area = Vector2(10, 10)
			icon = Vector2(46, 8)
		"staff":
			reach = 50.0
			area = Vector2(64, 30)
			icon = Vector2(88, 7)
			icon_off = 14.0
	# heavier tiers read bigger in the hand, gently
	var tier_scale := 1.0 + float(tier - 1) * 0.05
	icon *= tier_scale

	var stats := {
		"damage": dmg if wtype != "wand" else 0,
		"cooldown": cd, "range_offset": reach, "area_size": area,
		"knockback_min": 20.0 + float(tier) * 4.0,
		"knockback_max": 40.0 + float(tier) * 7.0,
		"icon_size": icon, "icon_color": col, "icon_offset": icon_off,
	}

	var d := {
		"name": dname, "category": "weapon", "weapon_type": wtype,
		"max_stack": 1, "color": col, "weapon_stats": stats,
	}
	if klass == "wand":
		d["mana_cost"] = 6 + tier * 2 + (6 if behavior in ["tome", "sentry"] else 0)

	var special := _special_for(behavior, tier, dmg, ex)
	if not special.is_empty():
		d["special"] = special
		d["unique_desc"] = _desc_for(behavior, ex)
	return d

static func _status_of(ex: Dictionary, tier: int) -> Dictionary:
	match str(ex.get("status", "")):
		"burn_w":   return {"kind": "burn", "dur": 3.0, "mag": 3.0 + float(tier)}
		"slow_w":   return {"kind": "slow", "dur": 2.2, "mag": 0.55}
		"poison_w": return {"kind": "poison", "dur": 4.0, "mag": 2.0 + float(tier) * 0.8}
	return {}

static func _special_for(behavior: String, tier: int, dmg: int, ex: Dictionary) -> Dictionary:
	var spd := 480.0 + float(tier) * 30.0
	var rng := 380.0 + float(tier) * 35.0
	var st := _status_of(ex, tier)
	var s: Dictionary = {}
	match behavior:
		"arc", "thrust", "shot", "rapid":
			# the plain-body behaviors: their voice is stats, not a special --
			# a rider status travels TYPELESS (the melee hit path and the
			# arrow spawner both read special.status directly; an empty type
			# falls through to the ordinary swing/shot, exactly as intended)
			pass
		"cleave":
			s = {"type": "cleave"}
		"crescent":
			s = {"type": "flying_slash", "damage": int(ex.get("p_damage", dmg)), "speed": spd, "range": rng}
		"jab_volley":
			s = {"type": "javelin_volley", "count": int(ex.get("count", 3)), "spread_deg": 10.0, "damage": dmg, "speed": spd + 150.0, "range": rng}
		"volley":
			s = {"type": "multi_shot", "count": int(ex.get("count", 2)), "spread_deg": 12.0}
		"seeker":
			s = {"type": "homing"}
		"lob_a", "lob":
			s = {"type": "lob", "damage": dmg, "speed": spd, "range": rng, "aoe": float(ex.get("aoe", 90.0))}
		"bolt":
			s = {"type": "frost_shard", "damage": dmg, "speed": spd + 100.0, "range": rng}
		"fire":
			s = {"type": "fireball", "damage": dmg, "aoe": float(ex.get("aoe", 90.0)), "speed": spd - 40.0, "range": rng}
		"frost":
			s = {"type": "frost_shard", "damage": dmg, "speed": spd + 120.0, "range": rng, "pierce": true}
		"ricochet":
			s = {"type": "ricochet", "damage": dmg, "speed": spd + 120.0, "range": rng, "bounces": int(ex.get("bounces", 3))}
		"cluster":
			s = {"type": "cluster", "damage": dmg, "speed": spd, "range": rng, "shards": int(ex.get("shards", 5))}
		"tome":
			s = {"type": "tome_storm", "damage": dmg, "range": rng + 60.0, "radius": float(ex.get("radius", 130.0)), "dur": 4.5, "gap": 0.4}
		"sentry":
			s = {"type": "sentry", "damage": dmg, "dur": float(ex.get("dur", 16.0)), "gap": 0.85}
		"orbiter":
			s = {"type": "orbiter", "damage": dmg, "speed": spd + 100.0, "range": 230.0 + float(tier) * 15.0, "dwell": float(ex.get("dwell", 2.2))}
		"lash":
			s = {"type": "lash", "damage": dmg, "speed": spd + 60.0, "range": 300.0 + float(tier) * 20.0}
		"staff":
			s = {"type": "staff_extend"}
	if not st.is_empty():
		if s.is_empty():
			s = {"status": st}   # the typeless rider (plain swing/shot + status)
		else:
			s["status"] = st
	if bool(ex.get("pierce", false)):
		s["pierce"] = true
	return s

static func _desc_for(behavior: String, ex: Dictionary) -> String:
	match behavior:
		"cleave":     return "Heavy enough to cleave through EVERY enemy in the arc."
		"crescent":   return "Every swing also hurls a flying crescent down the lane."
		"jab_volley": return "Conjures a fan of %d spectral javelins and lets fly." % int(ex.get("count", 3))
		"volley":     return "Looses a fan of %d arrows with every draw." % int(ex.get("count", 2))
		"seeker":     return "Its shots bend mid-flight, hunting the nearest enemy."
		"lob_a", "lob": return "Sails a mortar arc and BLOSSOMS where it lands."
		"bolt":       return "A hard, fast bolt of force."
		"fire":       return "Detonates on impact, scorching everything close."
		"frost":      return "A razor sliver that skewers everyone along its line."
		"ricochet":   return "Leaps foe to foe up to %d times, each hit a little lighter." % int(ex.get("bounces", 3))
		"cluster":    return "Bursts on its first mark into a fan of %d biting shards." % int(ex.get("shards", 5))
		"tome":       return "Reads a stormlet down over the aimed ground for a few seconds."
		"sentry":     return "Plants ONE watching totem that snipes on its own clock."
		"orbiter":    return "Flies out, SPINS a cutting wheel at the far point, then threads home."
		"lash":       return "A weaving ribbon that rakes its lane on BOTH passes."
		"staff":      return "Landed blows in rhythm DRAW IT LONGER; the fourth strikes the earth as a pillar."
		"arc", "thrust", "shot", "rapid":
			if ex.has("status"):
				return "Its edge carries a lingering hurt."
			return ""
	return ""
