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
	# ---------------- WAVE 3 - TIER 1 (8) ----------------
	["wpn_hearthpoker",  "Hearth Poker",         "melee", 1, "arc",       6,  0.4,  {}],
	["wpn_cellarmallet", "Cellar Mallet",        "melee", 1, "cleave",    10, 0.9,  {}],
	["wpn_thistleflail", "Thistle Knot",         "melee", 1, "chain_maul", 8, 0.9,  {}],
	["wpn_haypike",      "Haymaker's Pike",      "spear", 1, "thrust",    8,  0.7,  {}],
	["wpn_crowbow",      "Crowchaser",           "bow",   1, "shot",      6,  0.5,  {}],
	["wpn_sparrowbow",   "Sparrowhawk",          "bow",   1, "rapid",     4,  0.25, {}],
	["wpn_stubwand",     "Stubwand",             "wand",  1, "bolt",      8,  0.55, {}],
	["wpn_reedstaff",    "River Reed",           "staff", 1, "staff",     5,  0.38, {}],
	# ---------------- WAVE 3 - TIER 2 (14) ----------------
	["wpn_tannerknife",  "Tanner's Long Knife",  "melee", 2, "arc",       9,  0.3,  {}],
	["wpn_orchardaxe",   "Orchard Feller",       "melee", 2, "cleave",    15, 0.95, {}],
	["wpn_bellropeflail","Bellrope",             "melee", 2, "chain_maul", 11, 0.95, {}],
	["wpn_grindwheel",   "Grindstone Wheel",     "melee", 2, "orbiter",   9,  0.85, {"dwell": 1.5}],
	["wpn_ditchpike",    "Ditchwarden",          "spear", 2, "thrust",    13, 0.85, {}],
	["wpn_frostprong",   "Frostbitten Prong",    "spear", 2, "thrust",    11, 0.7,  {"status": "slow_w"}],
	["wpn_bramblebow",   "Bramblebow",           "bow",   2, "shot",      9,  0.5,  {"status": "poison_w"}],
	["wpn_paleflight",   "Pale Flight",          "bow",   2, "volley",    6,  0.6,  {"count": 2}],
	["wpn_emberdart",    "Emberdart",            "bow",   2, "shot",      8,  0.45, {"status": "burn_w"}],
	["wpn_foxfirewand",  "Foxfire Wand",         "wand",  2, "fire",      12, 0.75, {"aoe": 60}],
	["wpn_saltcaster",   "Saltcaster",           "wand",  2, "cluster",   10, 0.85, {"shards": 3}],
	["wpn_leechwand",    "Leechlight",           "wand",  2, "bolt",      10, 0.5,  {"status": "poison_w"}],
	["wpn_ferrypole",    "Ferryman's Pole",      "staff", 2, "staff",     9,  0.42, {}],
	["wpn_gooseherd",    "Gooseherd's Crook",    "staff", 2, "staff",     8,  0.36, {}],
	# ---------------- WAVE 3 - TIER 3 (24) ----------------
	["wpn_sextonblade",  "Sexton's Edge",        "melee", 3, "arc",       14, 0.45, {}],
	["wpn_quarrymaul",   "Quarry Maul",          "melee", 3, "cleave",    21, 1.05, {"knockup": true}],
	["wpn_chimefall",    "Chimefall",            "melee", 3, "chain_maul", 15, 0.95, {}],
	["wpn_lanternwheel", "Lantern Wheel",        "melee", 3, "orbiter",   11, 0.8,  {"dwell": 2.0, "status": "burn_w"}],
	["wpn_curseknife",   "Cursewright's Knife",  "melee", 3, "arc",       10, 0.28, {"status": "poison_w"}],
	["wpn_wardenblade",  "Warden of the Row",    "melee", 3, "crescent",  12, 0.55, {"p_damage": 10}],
	["wpn_marshlash",    "Marsh Tongue",         "melee", 3, "lash",      11, 0.85, {"status": "poison_w"}],
	["wpn_tithegather",  "Tithe Gatherer",       "melee", 3, "ricochet",  11, 0.65, {"bounces": 3}],
	["wpn_harrowpike",   "Harrower",             "spear", 3, "thrust",    16, 0.8,  {}],
	["wpn_lamplighter",  "Lamplighter's Reach",  "spear", 3, "thrust",    13, 0.6,  {"status": "burn_w"}],
	["wpn_gullprong",    "Gullwing Prong",       "spear", 3, "jab_volley", 11, 0.9, {"count": 3}],
	["wpn_reedvolley",   "Reedsong Volley",      "spear", 3, "jab_volley", 10, 0.85, {"count": 4}],
	["wpn_shrikebow",    "Shrikebow",            "bow",   3, "shot",      15, 0.55, {}],
	["wpn_finchvolley",  "Finchstorm",           "bow",   3, "volley",    9,  0.6,  {"count": 3}],
	["wpn_haleseeker",   "Hale Seeker",          "bow",   3, "seeker",    11, 0.68, {}],
	["wpn_bogmortar",    "Bog Belcher",          "bow",   3, "lob_a",     17, 1.0,  {"aoe": 80}],
	["wpn_lightstep",    "Lightstep",            "bow",   3, "rapid",     6,  0.19, {}],
	["wpn_hollowbolt",   "Hollowbolt",           "wand",  3, "bolt",      15, 0.5,  {}],
	["wpn_mirebook",     "The Mire Pages",       "wand",  3, "tome",      8,  1.45, {"radius": 120}],
	["wpn_shalewand",    "Shalebreaker",         "wand",  3, "cluster",   14, 0.85, {"shards": 5}],
	["wpn_pyrelight",    "Pyrelight",            "wand",  3, "fire",      18, 0.8,  {"aoe": 95, "status": "burn_w"}],
	["wpn_courierrod",   "Courier's Bad News",   "wand",  3, "ricochet",  12, 0.62, {"bounces": 3}],
	["wpn_shepherdstaff","Shepherd of Stones",   "staff", 3, "staff",     11, 0.42, {}],
	["wpn_wellstaff",    "Wellwalker",           "staff", 3, "staff",     13, 0.5,  {}],
	# ---------------- WAVE 3 - TIER 4 (28) ----------------
	["wpn_eveningblade", "Evening's Empire",     "melee", 4, "arc",       18, 0.42, {}],
	["wpn_barrowmaul",   "Barrow King's Maul",   "melee", 4, "cleave",    26, 1.0,  {"knockup": true}],
	["wpn_cometflail",   "Comet on a Chain",     "melee", 4, "chain_maul", 20, 0.95, {"status": "burn_w"}],
	["wpn_owlwheel",     "Owl-Eye Wheel",        "melee", 4, "orbiter",   15, 0.78, {"dwell": 2.2}],
	["wpn_palefang",     "Palefang",             "melee", 4, "arc",       12, 0.25, {"status": "slow_w"}],
	["wpn_riverrender",  "Riverrender",          "melee", 4, "crescent",  16, 0.55, {"p_damage": 14}],
	["wpn_smokelash",    "Smoke and Ash",        "melee", 4, "lash",      16, 0.82, {"status": "burn_w"}],
	["wpn_debtblade",    "Debt of the Deep",     "melee", 4, "ricochet",  15, 0.6,  {"bounces": 4}],
	["wpn_vigilpike",    "Vigil Unbroken",       "spear", 4, "thrust",    22, 0.82, {}],
	["wpn_winterreach",  "Winter's Reach",       "spear", 4, "thrust",    18, 0.6,  {"status": "slow_w"}],
	["wpn_hawkvolley",   "Hawks in Formation",   "spear", 4, "jab_volley", 14, 0.88, {"count": 4}],
	["wpn_marrowprong",  "Marrowsplitter",       "spear", 4, "jab_volley", 16, 0.95, {"count": 3}],
	["wpn_gravebow",     "The Polite Reminder",  "bow",   4, "shot",      20, 0.58, {"pierce": true}],
	["wpn_larkstorm",    "A Storm of Larks",     "bow",   4, "volley",    11, 0.58, {"count": 3}],
	["wpn_needlerain",   "Needlerain",           "bow",   4, "rapid",     8,  0.17, {}],
	["wpn_huntmaster",   "Huntmaster's Word",    "bow",   4, "seeker",    15, 0.62, {}],
	["wpn_sapperkiss",   "Sapper's Kiss",        "bow",   4, "lob_a",     23, 1.0,  {"aoe": 95, "status": "burn_w"}],
	["wpn_glasstring",   "Glasstring",           "bow",   4, "shot",      17, 0.5,  {"status": "slow_w"}],
	["wpn_covenbook",    "The Coven's Ledger",   "wand",  4, "tome",      10, 1.4,  {"radius": 135}],
	["wpn_frostwrit",    "Frost Writ",           "wand",  4, "frost",     19, 0.55, {"status": "slow_w"}],
	["wpn_gloamburst",   "Gloamburst",           "wand",  4, "cluster",   19, 0.8,  {"shards": 6}],
	["wpn_howlbolt",     "Howling Bolt",         "wand",  4, "ricochet",  16, 0.58, {"bounces": 4}],
	["wpn_candlepost",   "Candlekeeper",         "wand",  4, "sentry",    9,  1.2,  {"dur": 18}],
	["wpn_stormsliver",  "Stormsliver",          "wand",  4, "bolt",      21, 0.5,  {}],
	["wpn_paleobelisk",  "Pale Obelisk",         "staff", 4, "staff",     16, 0.46, {}],
	["wpn_fordstaff",    "Fordmaster",           "staff", 4, "staff",     14, 0.4,  {}],
	["wpn_inkbook",      "Inkwell of Storms",    "wand",  4, "tome",      12, 1.5,  {"radius": 150}],
	["wpn_driftwheel",   "Driftwheel",           "melee", 4, "orbiter",   17, 0.85, {"dwell": 2.6}],
	# ---------------- WAVE 3 - TIER 5 (26) ----------------
	["wpn_lastlantern",  "The Last Lantern",     "melee", 5, "arc",       23, 0.4,  {"status": "burn_w"}],
	["wpn_hourmaul",     "The Eleventh Hour",    "melee", 5, "cleave",    34, 1.08, {"knockup": true}],
	["wpn_gallowsflail", "Gallows Swing",        "melee", 5, "chain_maul", 26, 0.95, {}],
	["wpn_midwinterwheel","Midwinter Wheel",     "melee", 5, "orbiter",   20, 0.78, {"dwell": 2.8, "status": "slow_w"}],
	["wpn_asphodelknife","Asphodel Kiss",        "melee", 5, "arc",       15, 0.24, {"status": "poison_w"}],
	["wpn_seawallblade", "Seawall",              "melee", 5, "crescent",  21, 0.55, {"p_damage": 19}],
	["wpn_pilgrimlash",  "Pilgrim's Scourge",    "melee", 5, "lash",      21, 0.83, {}],
	["wpn_omenblade",    "Omen of Iron",         "melee", 5, "ricochet",  19, 0.58, {"bounces": 5}],
	["wpn_borderpike",   "Border of the Realm",  "spear", 5, "thrust",    28, 0.78, {}],
	["wpn_stormherd",    "Stormherd",            "spear", 5, "jab_volley", 17, 0.88, {"count": 5}],
	["wpn_moonreach",    "Moonreach",            "spear", 5, "thrust",    23, 0.58, {"status": "slow_w"}],
	["wpn_kestrelbow",   "Kestrel's Court",      "bow",   5, "volley",    14, 0.54, {"count": 3}],
	["wpn_quillrain",    "Quillrain",            "bow",   5, "rapid",     10, 0.16, {}],
	["wpn_wintermark",   "Wintermark",           "bow",   5, "shot",      26, 0.58, {"pierce": true, "status": "slow_w"}],
	["wpn_owlseeker",    "The Owl Remembers",    "bow",   5, "seeker",    19, 0.58, {}],
	["wpn_thunderhead",  "Thunderhead",          "bow",   5, "lob_a",     29, 1.0,  {"aoe": 110}],
	["wpn_sirensbook",   "The Siren's Appendix", "wand",  5, "tome",      13, 1.35, {"radius": 150}],
	["wpn_glacierwrit",  "Glacier Writ",         "wand",  5, "frost",     24, 0.55, {"status": "slow_w"}],
	["wpn_starsplinter", "Starsplinter",         "wand",  5, "cluster",   24, 0.78, {"shards": 7}],
	["wpn_omenbolt",     "The Third Omen",       "wand",  5, "ricochet",  21, 0.58, {"bounces": 5}],
	["wpn_beaconpost",   "Beacon of the Deep",   "wand",  5, "sentry",    13, 1.18, {"dur": 22}],
	["wpn_emberhymn",    "Emberhymn",            "wand",  5, "fire",      30, 0.82, {"aoe": 130, "status": "burn_w"}],
	["wpn_graniteway",   "The Granite Way",      "staff", 5, "staff",     20, 0.44, {}],
	["wpn_cloudcounter", "Cloudcounter",         "staff", 5, "staff",     18, 0.38, {}],
	["wpn_nightmortar",  "Midnight Post",        "bow",   5, "lob_a",     27, 0.95, {"aoe": 105}],
	["wpn_saintwheel",   "Saint's Reward",       "melee", 5, "orbiter",   22, 0.8,  {"dwell": 3.0}],
	# ---------------- WAVE 3 - TIER 6 (22) ----------------
	["wpn_requiemedge",  "Requiem Edge",         "melee", 6, "arc",       29, 0.38, {}],
	["wpn_worldanvil",   "The World-Anvil",      "melee", 6, "cleave",    42, 1.08, {"knockup": true}],
	["wpn_cinderchain",  "Cinderchain",          "melee", 6, "chain_maul", 32, 0.92, {"status": "burn_w"}],
	["wpn_voidwheel",    "Wheel of the Hollow",  "melee", 6, "orbiter",   26, 0.78, {"dwell": 3.2}],
	["wpn_sorrowfang",   "Sorrowfang",           "melee", 6, "arc",       19, 0.24, {"status": "poison_w"}],
	["wpn_horizonrender","Horizonrender",        "melee", 6, "crescent",  27, 0.54, {"p_damage": 25}],
	["wpn_nightlash",    "A Long Night's Tongue","melee", 6, "lash",      27, 0.8,  {"status": "slow_w"}],
	["wpn_griefcollect", "Grief, Collected",     "melee", 6, "ricochet",  24, 0.56, {"bounces": 6}],
	["wpn_worldspike",   "Worldspike",           "spear", 6, "thrust",    35, 0.76, {}],
	["wpn_ashherd",      "Herd of Ashes",        "spear", 6, "jab_volley", 22, 0.86, {"count": 5, "status": "burn_w"}],
	["wpn_griffvolley",  "Griffin Volley",       "bow",   6, "volley",    18, 0.5,  {"count": 4}],
	["wpn_silentchoir",  "The Silent Choir",     "bow",   6, "rapid",     13, 0.15, {}],
	["wpn_direseeker",   "Dire Portent",         "bow",   6, "seeker",    24, 0.56, {}],
	["wpn_sunmortar",    "A Piece of the Sun",   "bow",   6, "lob_a",     36, 1.0,  {"aoe": 125, "status": "burn_w"}],
	["wpn_wakebook",     "The Book of Wakes",    "wand",  6, "tome",      17, 1.3,  {"radius": 165}],
	["wpn_permafrost",   "Permafrost Decree",    "wand",  6, "frost",     29, 0.54, {"status": "slow_w"}],
	["wpn_novaburst",    "Novaburst Rod",        "wand",  6, "cluster",   30, 0.76, {"shards": 8}],
	["wpn_lastcourier",  "The Last Courier",     "wand",  6, "ricochet",  26, 0.56, {"bounces": 6}],
	["wpn_watchfire",    "Watchfire",            "wand",  6, "sentry",    17, 1.15, {"dur": 24}],
	["wpn_cindershelf",  "Cindershelf",          "wand",  6, "fire",      36, 0.8,  {"aoe": 140, "status": "burn_w"}],
	["wpn_skyladder",    "Ladder to Nowhere",    "staff", 6, "staff",     23, 0.42, {}],
	["wpn_stillmountain","The Still Mountain",   "staff", 6, "staff",     26, 0.48, {}],
	# ---------------- WAVE 3 - TIER 7 (14) ----------------
	["wpn_dawnchorus",   "Dawn Chorus",          "melee", 7, "arc",       36, 0.36, {"status": "burn_w"}],
	["wpn_finalanvil",   "Anvil of Endings",     "melee", 7, "cleave",    52, 1.05, {"knockup": true}],
	["wpn_cometchain",   "Chained Comet",        "melee", 7, "chain_maul", 40, 0.9, {"status": "burn_w"}],
	["wpn_silencelash",  "The Shape of Silence", "melee", 7, "lash",      34, 0.78, {"status": "slow_w"}],
	["wpn_worldthorn",   "Thorn of the World",   "spear", 7, "thrust",    43, 0.74, {}],
	["wpn_stormflock",   "Flock of Storms",      "spear", 7, "jab_volley", 27, 0.84, {"count": 6}],
	["wpn_choirstring",  "Choirstring",          "bow",   7, "volley",    23, 0.48, {"count": 4, "pierce": true}],
	["wpn_reckoningbow", "The Quiet Reckoning",  "bow",   7, "seeker",    30, 0.54, {}],
	["wpn_sunspill",     "Sunspill",             "bow",   7, "lob_a",     44, 0.98, {"aoe": 140, "status": "burn_w"}],
	["wpn_tidebook",     "The Tidal Codex",      "wand",  7, "tome",      22, 1.25, {"radius": 180}],
	["wpn_shardregent",  "The Shard Regent",     "wand",  7, "cluster",   37, 0.74, {"shards": 9}],
	["wpn_finaldebt",    "The Final Debt",       "wand",  7, "ricochet",  32, 0.54, {"bounces": 7}],
	["wpn_highlantern",  "Lantern of the High Road", "wand", 7, "sentry", 21, 1.12, {"dur": 26}],
	["wpn_bentheaven",   "Heaven, Bent",         "staff", 7, "staff",     29, 0.4,  {}],
	# ---------------- WAVE 3 - TIER 8 (10) ----------------
	["wpn_griefcrown",   "Grief Wears a Crown",  "melee", 8, "cleave",    62, 1.02, {"knockup": true, "status": "slow_w"}],
	["wpn_emberthrone",  "Throne of Embers",     "melee", 8, "chain_maul", 50, 0.88, {"status": "burn_w"}],
	["wpn_worldslash",   "A Cut Across the World","melee", 8, "crescent", 42, 0.52, {"p_damage": 40}],
	["wpn_courtwheel",   "The Whole Court, Spinning", "melee", 8, "orbiter", 39, 0.72, {"dwell": 4.2}],
	["wpn_edictpike",    "The Final Edict",      "spear", 8, "jab_volley", 33, 0.82, {"count": 6, "status": "burn_w"}],
	["wpn_hollowking",   "The Hollow King's Rain","bow",  8, "lob_a",     52, 0.95, {"aoe": 155, "status": "burn_w"}],
	["wpn_nightparade",  "Night Parade",         "bow",   8, "seeker",    37, 0.5,  {}],
	["wpn_worldsgrief",  "The World's Grief",    "wand",  8, "cluster",   45, 0.72, {"shards": 10}],
	["wpn_deepcrown",    "Crown of the Deep Court","wand", 8, "sentry",   27, 1.1,  {"dur": 30}],
	["wpn_mountainking", "The Mountain That Kneels","staff", 8, "staff",  36, 0.34, {}],
	# ---------------- WAVE 3 - FLAGSHIPS (11) ----------------
	["wpn_therumor",     "The Rumor",            "wand",  8, "ricochet",  38, 0.5,  {"bounces": 9, "rider": "grows"}],
	["wpn_choirofone",   "A Choir of One",       "bow",   8, "rapid",     19, 0.13, {"status": "burn_w", "rider": "choir"}],
	["wpn_smallsun",     "A Small Personal Sun", "wand",  8, "fire",      52, 0.78, {"aoe": 170, "status": "burn_w", "rider": "sunfall"}],
	["wpn_patientknife", "The Patient Knife",    "melee", 8, "arc",       24, 0.2,  {"status": "poison_w", "rider": "patient"}],
	["wpn_skysfare",     "What the Sky Charges", "wand",  8, "tome",      33, 1.15, {"radius": 220, "rider": "walker"}],
	["wpn_longgoodbye",  "The Long Goodbye",     "melee", 7, "lash",      40, 0.76, {"status": "poison_w", "rider": "goodbye"}],
	["wpn_borrowedstar", "A Borrowed Star",      "bow",   7, "lob_a",     48, 0.95, {"aoe": 150, "status": "burn_w", "rider": "borrow"}],
	["wpn_gravecourier", "Grave Courier",        "melee", 7, "ricochet",  30, 0.52, {"bounces": 7, "rider": "courier"}],
	["wpn_summerscoffin","Summer's Coffin",      "wand",  7, "frost",     36, 0.5,  {"status": "slow_w", "rider": "coffin"}],
	["wpn_kindlyend",    "The Kindly End",       "spear", 6, "thrust",    40, 0.7,  {"status": "poison_w", "rider": "kindly"}],
	["wpn_secondmoon",   "Second Moon",          "melee", 6, "chain_maul", 36, 0.85, {"status": "slow_w", "rider": "moon"}],
	["wpn_heavenpoint",  "The Heaven-Piercing Point", "spear", 7, "jab_volley", 29, 0.84, {"count": 5, "status": "slow_w"}],
	["wpn_unbentcolumn", "The Unbent Column",    "staff", 8, "staff",     40, 0.35, {}]
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
		# a flagship's card states its OWN promise, not the family line
		if ex.has("rider") and RIDER_DESC.has(str(ex["rider"])):
			d["unique_desc"] = RIDER_DESC[str(ex["rider"])]
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
		"chain_maul":
			s = {"type": "chain_maul", "damage": dmg, "speed": spd + 40.0, "range": 260.0 + float(tier) * 18.0}
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
	# flagship riders (polish 2026-07-28): one NAMED bespoke behavior per
	# crown weapon, read by weapon_projectile / player / storm_cloud
	if ex.has("rider"):
		s["rider"] = str(ex["rider"])
	return s

# The flagship promises: one line each, printed on the card in place of the
# family description. The mechanic behind each lives where its name says.
const RIDER_DESC = {
	"grows":   "Leaps NINE times, and a rumor GROWS in the telling -- every leap hits harder.",
	"choir":   "Rapid fire; every SEVENTH shot the whole choir answers with a three-arrow fan.",
	"sunfall": "The blast stays: a grounded sunlet keeps burning the spot after the flash.",
	"patient": "The FIRST cut is the deepest: +40% against a foe still at full health.",
	"walker":  "Reads a great storm down -- and the storm WALKS after them.",
	"goodbye": "A poisoned ribbon whose RETURN pass cuts double. It hurts most on the way out.",
	"borrow":  "At the top of its arc it sheds two smaller embers: three falling lights.",
	"courier": "Leaps seven bodies; a quarter are left FEARED, watching it go.",
	"coffin":  "A piercing cold sliver. What it KILLS shatters onto the mourners.",
	"kindly":  "Every poisoned foe it strikes gives one HP back. A mercy, flowing the wrong way.",
	"moon":    "A flail whose whirl has its own TIDE, dragging enemies into the blades.",
}

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
		"chain_maul": return "WHIRLS about you gathering speed, hurls itself as a comet, then hauls back on its chain."
		"lash":       return "A weaving ribbon that rakes its lane on BOTH passes."
		"staff":      return "Landed blows in rhythm DRAW IT LONGER; the fourth strikes the earth as a pillar."
		"arc", "thrust", "shot", "rapid":
			if ex.has("status"):
				return "Its edge carries a lingering hurt."
			return ""
	return ""
