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
	# THE SUMMONER'S FIRST THREE (batch 1). The engine is worth nothing until
	# something can hold it, so the class's starters land with the engine
	# rather than waiting for the full 38-row slice. All three are ordinary T1
	# drops for every class -- the Summoner just begins holding two of them.
	["smn_smallloyalty", "A Small Loyalty",      "scepter", 1, "minion", 5, 0.9,
		{"m_kind": "mudling", "m_gap": 1.9}],
	["whp_firstlesson",  "First Lesson",         "whip",  1, "whipcrack", 6, 0.5,
		{"frenzy": 0.08, "tag_fx": "lesson"}],
	# ---- THE WHIPS (batch 2b) -- 12 more, one tag rider each ----
	["whp_willowword",   "The Willow Word",      "whip",  2, "whipcrack", 8, 0.48,
		{"reach": 30.0, "tag_dmg": 3.0, "tag_fx": "bend"}],
	["whp_wordofiron",   "A Word of Iron",       "whip",  3, "whipcrack", 10, 0.46,
		{"tag_dmg": 4.0, "tag_crit": 0.05, "tag_fx": "iron"}],
	["whp_droversanswer", "The Drover's Answer", "whip",  3, "whipcrack", 14, 0.7,
		{"reach": 46.0, "tag_fx": "knock"}],
	["whp_candlewick",   "Candlewick",           "whip",  4, "whipcrack", 12, 0.5,
		{"tag_dmg": 3.0, "tag_fx": "detonate"}],
	["whp_coldrein",     "The Cold Rein",        "whip",  4, "whipcrack", 11, 0.5,
		{"tag_dmg": 3.0, "tag_fx": "chill"}],
	["whp_stormlash",    "Stormlash",            "whip",  5, "whipcrack", 14, 0.48,
		{"tag_dmg": 5.0, "tag_fx": "storm"}],
	["whp_tallystring",  "The Tallyman's String", "whip", 5, "whipcrack", 13, 0.46,
		{"tag_dmg": 5.0, "tag_fx": "coin"}],
	["whp_sunderpsalm",  "Sundering Psalm",      "whip",  6, "whipcrack", 15, 0.5,
		{"tag_dmg": 6.0, "frenzy": 0.20, "tag_fx": "psalm"}],
	["whp_mothersmercy", "Mother's Mercy",       "whip",  6, "whipcrack", 14, 0.48,
		{"tag_dmg": 6.0, "tag_fx": "mend"}],
	["whp_reapingverse", "The Reaping Verse",    "whip",  7, "whipcrack", 17, 0.46,
		{"tag_dmg": 9.0, "tag_fx": "propagate",
		"fx": [{"kind": "harvest", "hp": 2}]}],
	["whp_morningbell",  "Morning Bell",         "whip",  7, "whipcrack", 18, 0.52,
		{"tag_dmg": 12.0, "tag_crit": 0.08, "tag_fx": "toll",
		"fx": [{"kind": "echo", "pct": 0.3, "delay": 0.4}]}],
	["whp_tencourt",     "The Ten-Tongued Court", "whip", 8, "whipcrack", 20, 0.44,
		{"reach": 60.0, "tag_dmg": 18.0, "tag_crit": 0.10, "tag_dur": 2.0,
		"tag_fx": "tenfold", "frenzy": 0.12,
		"fx": [{"kind": "chain", "n": 3, "pct": 0.3, "range": 240.0}]}],
	# ---- THE TOTEMS (batch 2c) -- 7 more, one archetype each ----
	["pst_bramblepost",  "The Bramble Post",     "totem", 3, "post", 14, 1.1,
		{"s_kind": "bramble", "p_gap": 1.4}],
	["pst_standingthorn", "The Standing Thorn",  "totem", 4, "post", 16, 1.2,
		{"s_kind": "ballista", "p_gap": 1.2}],
	["pst_stormbell",    "The Storm Bell",       "totem", 5, "post", 7, 1.3,
		{"s_kind": "bell", "p_gap": 0.5}],
	["pst_quietsister",  "The Quiet Sister",     "totem", 5, "post", 7, 1.3,
		{"s_kind": "sister", "p_gap": 0.62}],
	["pst_eggkeeper",    "The Egg-Keeper",       "totem", 6, "post", 12, 1.4,
		{"s_kind": "eggkeeper", "p_gap": 1.05}],
	["pst_wintersthree", "Winter's Three Mouths", "totem", 7, "post", 18, 1.5,
		{"s_kind": "frostfount", "p_gap": 0.9, "status": "slow_w",
		"fx": [{"kind": "frostbloom", "radius": 120.0}]}],
	["pst_doorwatches",  "The Door That Watches", "totem", 8, "post", 24, 1.6,
		{"s_kind": "rift", "p_gap": 1.1,
		"fx": [{"kind": "splinter", "n": 2, "pct": 0.3, "range": 160.0}]}],
	["pst_watchingstone", "The Watching Stone",  "totem", 2, "post",      8, 1.0,
		{"s_kind": "watchstone", "p_gap": 1.1}],
	# ---- THE SUMMONER'S SCEPTERS (batch 2) -- 16 more, one body each ----
	["smn_fledgling",    "The Fledgling",        "scepter", 1, "minion", 6, 0.9,
		{"m_kind": "finch", "m_gap": 2.0}],
	["smn_quietpair",    "The Quiet Congregation", "scepter", 2, "minion", 7, 1.0,
		{"m_kind": "bat", "m_gap": 1.6, "m_style": "loop"}],
	["smn_keeperofone",  "Keeper of One",        "scepter", 2, "minion", 11, 1.1,
		{"m_kind": "warden", "m_gap": 1.8, "m_solo": true}],
	["smn_emberward",    "Emberward",            "scepter", 3, "minion", 9, 1.0,
		{"m_kind": "imp", "m_gap": 1.7, "m_style": "lob", "status": "burn_w"}],
	["smn_thestray",     "The Stray",            "scepter", 3, "minion", 12, 1.1,
		{"m_kind": "beast", "m_gap": 1.8}],
	["smn_broodmother",  "Thornmother's Brood",  "scepter", 4, "minion", 6, 1.0,
		{"m_kind": "spiderling", "m_gap": 0.85, "m_style": "latch", "status": "poison_w"}],
	["smn_ferrytoll",    "The Ferryman's Toll",  "scepter", 4, "minion", 12, 1.1,
		{"m_kind": "wisp", "m_gap": 1.7, "m_style": "lob"}],
	["smn_growinghunt",  "The Growing Hunt",     "scepter", 5, "minion", 16, 1.2,
		{"m_kind": "cub", "m_gap": 1.6, "m_solo": true}],
	["smn_twinsorrows",  "Twin Sorrows",         "scepter", 5, "minion", 10, 1.1,
		{"m_kind": "twin", "m_gap": 1.15}],
	["smn_blinklantern", "The Lantern That Blinks", "scepter", 6, "minion", 21, 1.2,
		{"m_kind": "lanterneye", "m_gap": 1.5, "m_style": "blink"}],
	["smn_sawpsalm",     "Sawtooth Psalm",       "scepter", 6, "minion", 18, 1.2,
		{"m_kind": "saw", "m_gap": 1.4, "m_style": "ram"}],
	["smn_clingchoir",   "The Clinging Choir",   "scepter", 7, "minion", 13, 1.1,
		{"m_kind": "cell", "m_gap": 0.9, "m_style": "latch",
		"fx": [{"kind": "soulwisp", "dmg": 4, "pct": 0.28}]}],
	["smn_deepkennel",   "Kennel of the Deep",   "scepter", 7, "minion", 24, 1.3,
		{"m_kind": "direhound", "m_gap": 1.6,
		"fx": [{"kind": "chain", "n": 2, "pct": 0.32, "range": 220.0}]}],
	["smn_procession",   "The Long Procession",  "scepter", 8, "minion", 28, 1.4,
		{"m_kind": "serpent", "m_gap": 1.5, "m_solo": true,
		"fx": [{"kind": "harvest", "hp": 2}]}],
	["smn_unerring",     "The Unerring",         "scepter", 8, "minion", 30, 1.4,
		{"m_kind": "lightblade", "m_gap": 1.3,
		"fx": [{"kind": "brand", "amp": 0.14, "dur": 4.0}]}],
	["smn_hundredthname", "The Hundredth Name",  "scepter", 8, "minion", 30, 1.4,
		{"m_kind": "namebearer", "m_gap": 1.5,
		"fx": [{"kind": "crowd", "pct_per": 0.04, "cap": 0.18}]}],
	["wpn_oakcudgel",    "Oak Cudgel",           "melee", 1, "arc",       8,  0.55, {"plain": true}],
	["wpn_mongrelknife", "Mongrel Knife",        "melee", 1, "arc",       5,  0.28, {"plain": true}],
	["wpn_pitshovel",    "Pit Shovel",           "melee", 1, "spadespray", 11, 0.85, {"rung": true}],
	["wpn_barrelstave",  "Barrel Stave",         "melee", 1, "arc",       7,  0.45, {"plain": true}],
	["wpn_rustfang",     "Rustfang",             "melee", 1, "arc",       6,  0.35, {"status": "poison_w", "plain": true}],
	["wpn_fencepike",    "Fence Pike",           "spear", 1, "thrust",    9,  0.8,  {"plain": true}],
	["wpn_eelspear",     "Eelcatcher",           "spear", 1, "thrust",    7,  0.6,  {"plain": true}],
	["wpn_orchardbow",   "Orchard Bow",          "bow",   1, "shot",      7,  0.55, {"plain": true}],
	["wpn_gutterbow",    "Gutter Bow",           "bow",   1, "shot",      6,  0.45, {"plain": true}],
	["wpn_tallowwand",   "Tallow Wand",          "wand",  1, "tallowdrip", 9, 0.6,  {"rung": true}],
	# was behavior "bolt" -> frost_shard. A wand named for CHALK fired an ice
	# dart, along with the tallow, moss, leech, salt, hollow and storm wands:
	# one match arm gave eleven differently-named weapons the same icicle.
	# "rung" (not "plain"): it keeps its place in the forge ladder -- Brookwand
	# still forges from it -- while no longer being featureless.
	["wpn_chalkwand",    "Chalk Wand",           "wand",  1, "chalkline", 7,  0.45, {"rung": true}],
	["wpn_willowswitch", "Willow Switch",        "staff", 1, "staff",     6,  0.4,  {"slam_fx": "spring"}],
	# ---------------- TIER 2 - UNCOMMON (floors 5-18) ----------------
	["wpn_gravespade",   "Gravekeeper's Spade",  "melee", 2, "opengrave", 14, 0.8,  {"rung": true}],
	["wpn_lanternblade", "Lanternblade",         "melee", 2, "arc",       10, 0.45, {"status": "burn_w", "plain": true}],
	["wpn_millsickle",   "Mill Sickle",          "melee", 2, "arc",       9,  0.32, {"plain": true}],
	["wpn_bonepick",     "Bonepick",             "melee", 2, "arc",       12, 0.6,  {"plain": true}],
	["wpn_coldiron",     "Cold Iron Edge",       "melee", 2, "arc",       11, 0.5,  {"status": "slow_w", "plain": true}],
	["wpn_ratterdart",   "Ratter's Dart",        "melee", 2, "ratterdart", 10, 0.7,  {"bounces": 2}],
	["wpn_boarspit",     "Boarspit",             "spear", 2, "thrust",    12, 0.75, {"plain": true}],
	["wpn_wallpike",     "Wallwatcher's Pike",   "spear", 2, "thrust",    14, 0.95, {"plain": true}],
	["wpn_reedjavelin",  "Reed Javelins",        "spear", 2, "reedcast",  9, 0.9,  {"count": 2}],
	["wpn_ashbow",       "Ashwood Bow",          "bow",   2, "shot",      10, 0.5,  {"plain": true}],
	["wpn_ferrybow",     "Ferryman's Bow",       "bow",   2, "ferrytwin", 7,  0.65, {"count": 2}],
	["wpn_stingerbow",   "Stinger",              "bow",   2, "rapid",     5,  0.22, {"plain": true}],
	["wpn_mosswand",     "Mosslight Wand",       "wand",  2, "sporepatch", 12, 0.55, {"rung": true}],
	["wpn_cinderrod",    "Cinder Rod",           "wand",  2, "fire",      14, 0.8,  {"aoe": 70, "plain": true}],
	["wpn_brookwand",    "Brookwand",            "wand",  2, "brookflow", 10, 0.5,  {"status": "slow_w", "rung": true}],
	# ---------------- TIER 3 - RARE (floors 12-32) ----------------
	["wpn_watchmansword","Watchman's Justice",   "melee", 3, "arc",       15, 0.5,  {"plain": true}],
	["wpn_furrowscythe", "Furrow Scythe",        "melee", 3, "reaprow",   19, 0.9,  {"rung": true}],
	["wpn_adderfang",    "Adderfang",            "melee", 3, "arc",       11, 0.3,  {"status": "poison_w", "plain": true}],
	["wpn_bellhammer",   "Bell Hammer",          "melee", 3, "belltoll",  22, 1.0,  {"knockup": true, "rung": true}],
	["wpn_squallblade",  "Squallblade",          "melee", 3, "crescent",  13, 0.55, {"p_damage": 11, "plain": true}],
	["wpn_thornwheel",   "Thornwheel",           "melee", 3, "orbiter",   12, 0.8,  {"dwell": 1.8}],
	["wpn_hookbill",     "Hookbill",             "melee", 3, "hookbill",  12, 0.65, {"bounces": 3}],
	["wpn_shrikelash",   "Shrike's Tail",        "melee", 3, "lash",      12, 0.85, {}],
	["wpn_gatecleaver",  "Gatecleaver",          "spear", 3, "thrust",    17, 0.85, {"plain": true}],
	["wpn_heronlance",   "Heron Lance",          "spear", 3, "thrust",    14, 0.6,  {"plain": true}],
	["wpn_stormprong",   "Stormprong",           "spear", 3, "stormprong", 12, 0.95, {"count": 3}],
	["wpn_veilbow",      "Veilpiercer",          "bow",   3, "shot",      16, 0.6,  {"pierce": true, "plain": true}],
	["wpn_larkbow",      "Lark's Reply",         "bow",   3, "rapid",     7,  0.2,  {"plain": true}],
	["wpn_twinnock",     "Twinnock Bow",         "bow",   3, "twinnock",  10, 0.6,  {"count": 2}],
	["wpn_emberarc",     "Emberarc Bow",         "bow",   3, "lob_a",     18, 0.95, {"aoe": 85, "status": "burn_w", "rider": "cinder"}],
	["wpn_paleseeker",   "Pale Seeker",          "bow",   3, "paleseek",    12, 0.7,  {}],
	["wpn_saltwand",     "Saltbinder",           "wand",  3, "saltring",  16, 0.55, {"rung": true}],
	["wpn_marshlight",   "Marshlight Lantern",   "wand",  3, "cluster",   15, 0.8,  {"shards": 4}],
	["wpn_leadrod",      "Leaden Judgement",     "wand",  3, "lob",       21, 1.05, {"aoe": 95, "rider": "lead"}],
	["wpn_finchbolt",    "Finchbolt",            "wand",  3, "finchbolt", 13, 0.6,  {"bounces": 3}],
	["wpn_droverstaff",  "Drover's Crook",       "staff", 3, "staff",     12, 0.45, {"slam_fx": "drive"}],
	# ---------------- TIER 4 - EPIC (floors 24-52) ----------------
	["wpn_duskrender",   "Duskrender",           "melee", 4, "duskrip",    8, 0.45, {}],
	["wpn_tolloftheend", "Toll of the End",      "melee", 4, "endtoll",   28, 1.05, {"knockup": true, "rung": true}],
	["wpn_vespersting",  "Vesper Sting",         "melee", 4, "arc",       13, 0.26, {"status": "poison_w", "plain": true}],
	["wpn_howlpiece",    "Howlpiece",            "melee", 4, "howlpiece", 17, 0.55, {"p_damage": 15}],
	["wpn_winterwheel",  "Winterwheel",          "melee", 4, "winterwheel", 16, 0.8,  {"dwell": 2.4, "status": "slow_w"}],
	["wpn_gloamlash",    "Gloaming Lash",        "melee", 4, "gloamlash", 17, 0.85, {"status": "burn_w"}],
	["wpn_reaperrebuke", "Reaper's Rebuke",      "melee", 4, "reaperrebuke", 16, 0.6,  {"bounces": 4}],
	["wpn_sunderpike",   "Sunder Pike",          "spear", 4, "sunderpoint", 15, 0.85, {}],
	["wpn_galeprong",    "Galeprong",            "spear", 4, "galeprong", 23, 0.9, {"count": 4}],
	["wpn_midnightlance","Midnight Lance",       "spear", 4, "thrust",    19, 0.6,  {"status": "slow_w", "plain": true}],
	["wpn_curfewbow",    "Curfew Bow",           "bow",   4, "shot",      21, 0.6,  {"pierce": true, "plain": true}],
	["wpn_choirbow",     "Choir of Points",      "bow",   4, "choirpoints", 12, 0.6, {"count": 3}],
	["wpn_hummingbow",   "Hummingbird",          "bow",   4, "hummingbird", 4, 0.18, {}],
	["wpn_falconoath",   "Falcon's Oath",        "bow",   4, "falconoath", 16, 0.65, {}],
	["wpn_sapperanswer", "Sapper's Answer",      "bow",   4, "lob_a",     24, 1.0,  {"aoe": 100, "rider": "fuse"}],
	["wpn_prismbreak",   "Prismbreak",           "wand",  4, "prismbreak", 20, 0.8,  {"shards": 6}],
	["wpn_stormdebt",    "Stormcaller's Debt",   "wand",  4, "stormdebt", 11, 1.4,  {"radius": 140}],
	["wpn_wispwarden",   "Wisp Warden",          "wand",  4, "wispwarden", 10, 1.2,  {"dur": 18}],
	["wpn_nightbolt",    "Nightbolt",            "wand",  4, "nightbolt", 17, 0.6,  {"bounces": 4}],
	["wpn_magmawrit",    "Magma Writ",           "wand",  4, "magmacrawl", 10, 0.85, {"status": "burn_w"}],
	["wpn_pilgrimstaff", "Pilgrim's Milestone",  "staff", 4, "staff",     15, 0.45, {"slam_fx": "mile"}],
	# ---------------- TIER 5 - LEGENDARY (floors 42-72) ----------------
	["wpn_daybreakedge", "Daybreak Edge",        "melee", 5, "daybreak",  24, 0.42, {"status": "burn_w", "count": 3, "aoe": 58}],
	["wpn_worldtoll",    "Worldtoll Maul",       "melee", 5, "worldtoll", 36, 1.1,  {"knockup": true}],
	["wpn_quietwheel",   "Wheel of Quiet",       "melee", 5, "quietwheel", 21, 0.8,  {"dwell": 2.8}],
	["wpn_serpentsermon","Serpent's Sermon",     "melee", 5, "serpentsermon", 22, 0.85, {"status": "poison_w"}],
	["wpn_finalverdict", "Final Verdict",        "spear", 5, "verdict",   25, 0.8,  {}],
	["wpn_skyquill",     "Sky of Quills",        "spear", 5, "skyquills", 18, 0.9, {"count": 5}],
	["wpn_eventide",     "Eventide",             "bow",   5, "eventide",  15, 0.55, {"count": 3}],
	["wpn_lastlark",     "The Last Lark",        "bow",   5, "larksong",   5, 0.16, {}],
	["wpn_omenseeker",   "Omen Seeker",          "bow",   5, "omenseek",  20, 0.6,  {}],
	["wpn_starfallbow",  "Starfall Bow",         "bow",   5, "starfall",  30, 1.0,  {"aoe": 115}],
	["wpn_grandrains",   "Grand Tome of Rains",  "wand",  5, "tomeofrains", 14, 1.35, {"radius": 155, "tome_kind": "twin"}],
	["wpn_twinburst",    "Twinburst Sceptre",    "wand",  5, "twinburst", 25, 0.8,  {"shards": 7}],
	["wpn_kingsransom",  "King's Ransom",        "wand",  5, "kingsransom", 22, 0.6,  {"bounces": 5}],
	["wpn_longwatch",    "Warden's Long Watch",  "wand",  5, "wardenwatch", 14, 1.2,  {"dur": 22}],
	["wpn_summitstaff",  "Summit That Walks",    "staff", 5, "walksummit", 7, 0.42, {}],
	# ---------------- TIER 6 - MYTHIC (floors 58-88) ----------------
	["wpn_griefedge",    "Grief Made Sharp",     "melee", 6, "griefsharp", 19, 0.4, {}],
	["wpn_hushfall",     "Hushfall",             "melee", 6, "hushfall",  44, 1.1,  {"knockup": true, "status": "slow_w"}],
	["wpn_eclipsewheel", "Eclipse Wheel",        "melee", 6, "eclipse",   27, 0.8,  {"dwell": 3.2}],
	["wpn_dawntongue",   "Dawn's Long Tongue",   "melee", 6, "longtongue", 28, 0.82, {"status": "burn_w"}],
	["wpn_horizonpike",  "Horizon Pike",         "spear", 6, "horizonreach", 36, 0.78, {}],
	["wpn_meteorquill",  "Meteor Quills",        "spear", 6, "meteorquill", 23, 0.88, {"count": 5, "status": "burn_w"}],
	["wpn_middaybow",    "Midday Massacre",      "bow",   6, "middaysun", 19, 0.52, {"count": 4}],
	["wpn_ghostrepeater","Ghost Repeater",       "bow",   6, "ghostbows", 11, 0.15, {"step": 4, "max": 3}],
	["wpn_lodestar",     "Lodestar",             "bow",   6, "lodestar",  25, 0.58, {}],
	["wpn_cometfall",    "Cometfall",            "bow",   6, "cometfall", 38, 1.0,  {"aoe": 130, "status": "burn_w"}],
	["wpn_deluge",       "The Deluge",           "wand",  6, "deluge",    18, 1.3,  {"radius": 170, "tome_kind": "column"}],
	["wpn_shatterhymn",  "Shatterhymn",          "wand",  6, "shatterhymn", 31, 0.78, {"shards": 8, "companion": "wisp", "c_damage": 11, "c_gap": 2.1}],
	["wpn_debtcollector","The Debt Collector",   "wand",  6, "debtmark",  27, 0.58, {"bounces": 6}],
	["wpn_twelfthpillar","Twelfth Pillar",       "staff", 6, "twelfthpillar", 24, 0.4, {}],
	# ---------------- TIER 7 - ASCENDED (floors 70-97) ----------------
	["wpn_afterlight",   "Afterlight",           "melee", 7, "afterlight", 29, 0.42, {"status": "burn_w",
		"fx": [{"kind": "echo", "pct": 0.34, "delay": 0.4}]}],
	["wpn_worldsedge",   "Edge of the World",    "melee", 7, "worldedge", 29, 0.6, {"p_damage": 26, "tint": [0.35, 0.95, 0.5],
		"fx": [{"kind": "splinter", "n": 4, "pct": 0.28, "range": 190.0}]}],
	["wpn_ascendwheel",  "Wheel of Ascension",   "melee", 7, "risingwheel", 27, 0.85, {"status": "slow_w",
		"fx": [{"kind": "frostbloom", "radius": 170.0, "dur": 3.0}]}],
	["wpn_novatongue",   "Nova Tongue",          "melee", 7, "nova", 29, 0.88, {"status": "burn_w",
		"fx": [{"kind": "quake", "radius": 140.0, "pct": 0.28}]}],
	# RENAMED from "Zenith" (2026-07-30). The dev asked four separate times where
	# the Zenith-like weapon was and could not find it -- because searching the
	# chests for "Zenith" turned up THIS: a plain thrust rung with no verb at
	# all. The actual homage is The Last Word (T8, behavior "zenith" ->
	# zenith_storm, nine ancestor blades). A plain rung must never wear the name
	# of a flagship; whoever goes looking for the famous thing will find the
	# wrong object and conclude the feature does not exist. Apogee means the
	# same thing and claims nothing. The ID is unchanged -- saves key on ids.
	["wpn_zenithpike",   "Apogee",               "spear", 7, "thrust", 40, 0.75, {
		"fx": [{"kind": "duelist", "pct_per": 0.05, "max": 6}]}],
	["wpn_ninthcommand", "Ninth Commandment",    "bow", 7, "commandment", 22, 0.52, {"pierce": true,
		"fx": [{"kind": "chain", "n": 2, "pct": 0.28, "range": 260.0}]}],
	["wpn_heavenstring", "Heavenstring",         "bow", 7, "heavenstring", 29, 0.6, {
		"fx": [{"kind": "brand", "amp": 0.15, "dur": 4.0}]}],
	["wpn_highflood",    "The High Flood",       "wand", 7, "tome", 21, 1.25, {"radius": 185,
		"fx": [{"kind": "crowd", "pct_per": 0.05, "cap": 0.55}]}],
	["wpn_riftburst",    "Riftburst Rod",        "wand", 7, "riftburst", 34, 1.0, {
		"fx": [{"kind": "splinter", "n": 5, "pct": 0.28, "range": 170.0}]}],
	["wpn_asphodelpost", "Asphodel Post",        "wand", 7, "asphodel", 19, 1.5, {
		"fx": [{"kind": "soulwisp", "dmg": 4, "pct": 0.28}]}],
	["wpn_skypillar",    "Pillar of the Sky",    "staff", 7, "skypillar", 34, 0.6, {
		"fx": [{"kind": "quake", "radius": 150.0, "pct": 0.28}]}],
	# ---------------- TIER 8 - MONARCH (floors 88-100) ----------------
	# CROWN TEN #6: a plain `arc` shared with 27 weapons becomes a POUR. Damage
	# 41 -> 11 with the cadence more than doubled: many small griefs, not one
	# big one -- the per-hit number is supposed to look modest.
	["wpn_crownsorrow",  "The Crown's Sorrow",   "melee", 8, "sorrow", 11, 0.15, {"status": "slow_w",
		"fx": [{"kind": "brand", "amp": 0.17, "dur": 5.0}]}],
	["wpn_kingdomwheel", "A Kingdom, Turning",   "melee", 8, "kingdomturning", 37, 0.75, {"dwell": 4.0,
		"fx": [{"kind": "gravity", "radius": 240.0, "pull": 180.0}]}],
	["wpn_lastword",     "The Last Word",        "melee", 8, "zenith", 34, 0.55, {"status": "burn_w",
		"fx": [{"kind": "legacy", "n": 2, "pct": 0.35, "range": 300.0}]}],
	# CROWN TEN #4: a plain thrust shared with 23 weapons becomes the weapon its
	# NAME always promised -- you do not stab a king once, you leave the blades
	# in. Damage 50 -> 21: the kill is the stack, not the throw.
	["wpn_regicide",     "Regicide",             "spear", 8, "regicide", 21, 0.62, {
		"fx": [{"kind": "duelist", "pct_per": 0.06, "max": 8}]}],
	["wpn_thronestrings","Throne of Strings",    "bow", 8, "thronestrings", 27, 0.48, {"count": 5, "pierce": true,
		"fx": [{"kind": "skyrain", "n": 3, "pct": 0.35, "spread": 140.0}]}],
	["wpn_soulflood",    "Flood of Souls",       "wand", 8, "souls", 26, 1.1,  {
		"fx": [{"kind": "soulwisp", "dmg": 6, "pct": 0.35}]}],
	["wpn_skymeasure",   "Staff That Measures the Sky", "staff", 8, "skymeasure", 34, 0.36, {
		"fx": [{"kind": "quake", "radius": 170.0, "pct": 0.35}]}],
	# ---------------- WAVE 3 - TIER 1 (8) ----------------
	["wpn_hearthpoker",  "Hearth Poker",         "melee", 1, "arc",       6,  0.4,  {"plain": true}],
	["wpn_cellarmallet", "Cellar Mallet",        "melee", 1, "hoopshunt", 10, 0.9,  {"rung": true}],
	["wpn_thistleflail", "Thistle Knot",         "melee", 1, "chain_maul", 8, 0.9,  {"plain": true}],
	["wpn_haypike",      "Haymaker's Pike",      "spear", 1, "thrust",    8,  0.7,  {"plain": true}],
	["wpn_crowbow",      "Crowchaser",           "bow",   1, "shot",      6,  0.5,  {"plain": true}],
	["wpn_sparrowbow",   "Sparrowhawk",          "bow",   1, "rapid",     4,  0.25, {"plain": true}],
	["wpn_stubwand",     "Stubwand",             "wand",  1, "stubmisfire", 8, 0.55, {"rung": true}],
	["wpn_reedstaff",    "River Reed",           "staff", 1, "staff",     5,  0.38, {"slam_fx": "splash"}],
	# ---------------- WAVE 3 - TIER 2 (14) ----------------
	["wpn_tannerknife",  "Tanner's Long Knife",  "melee", 2, "arc",       9,  0.3,  {"plain": true}],
	["wpn_orchardaxe",   "Orchard Feller",       "melee", 2, "fellblow",  15, 0.95, {"rung": true}],
	["wpn_bellropeflail","Bellrope",             "melee", 2, "chain_maul", 11, 0.95, {}],
	["wpn_grindwheel",   "Grindstone Wheel",     "melee", 2, "orbiter",   9,  0.85, {"dwell": 1.5}],
	["wpn_ditchpike",    "Ditchwarden",          "spear", 2, "thrust",    13, 0.85, {"plain": true}],
	["wpn_frostprong",   "Frostbitten Prong",    "spear", 2, "thrust",    11, 0.7,  {"status": "slow_w", "plain": true}],
	["wpn_bramblebow",   "Bramblebow",           "bow",   2, "shot",      9,  0.5,  {"status": "poison_w", "plain": true}],
	["wpn_paleflight",   "Pale Flight",          "bow",   2, "paleflight", 6,  0.6,  {"count": 2}],
	["wpn_emberdart",    "Emberdart",            "bow",   2, "shot",      8,  0.45, {"status": "burn_w", "plain": true}],
	["wpn_foxfirewand",  "Foxfire Wand",         "wand",  2, "fire",      12, 0.75, {"aoe": 60, "plain": true}],
	["wpn_saltcaster",   "Saltcaster",           "wand",  2, "cluster",   10, 0.85, {"shards": 3}],
	# cd 0.5 -> 0.9: measured 9 hits (four pulls plus the poison after) put a Tier-2
	# uncommon at 80 dps against a tier ceiling of 74. A tether that DRINKS and
	# heals you should not be spammable -- slow is the honest cost of sustain.
	["wpn_leechwand",    "Leechlight",           "wand",  2, "drinkthread", 10, 0.9, {"status": "poison_w", "rung": true}],
	["wpn_ferrypole",    "Ferryman's Pole",      "staff", 2, "staff",     9,  0.42, {"slam_fx": "shove"}],
	["wpn_gooseherd",    "Gooseherd's Crook",    "staff", 2, "staff",     8,  0.36, {"slam_fx": "herd"}],
	# ---------------- WAVE 3 - TIER 3 (24) ----------------
	["wpn_sextonblade",  "Sexton's Edge",        "melee", 3, "arc",       14, 0.45, {"plain": true}],
	["wpn_quarrymaul",   "Quarry Maul",          "melee", 3, "scoresplit", 21, 1.05, {"knockup": true, "rung": true}],
	["wpn_chimefall",    "Chimefall",            "melee", 3, "chain_maul", 15, 0.95, {}],
	["wpn_lanternwheel", "Lantern Wheel",        "melee", 3, "orbiter",   11, 0.8,  {"dwell": 2.0, "status": "burn_w"}],
	["wpn_curseknife",   "Cursewright's Knife",  "melee", 3, "arc",       10, 0.28, {"status": "poison_w", "plain": true}],
	["wpn_wardenblade",  "Warden of the Row",    "melee", 3, "rowsickle", 12, 0.30, {"p_damage": 10}],
	["wpn_marshlash",    "Marsh Tongue",         "melee", 3, "lash",      11, 0.85, {"status": "poison_w"}],
	["wpn_tithegather",  "Tithe Gatherer",       "melee", 3, "tithegather", 11, 0.65, {"bounces": 3}],
	["wpn_harrowpike",   "Harrower",             "spear", 3, "thrust",    16, 0.8,  {"plain": true}],
	["wpn_lamplighter",  "Lamplighter's Reach",  "spear", 3, "thrust",    13, 0.6,  {"status": "burn_w", "plain": true}],
	["wpn_gullprong",    "Gullwing Prong",       "spear", 3, "gullwing",  11, 0.9, {"count": 3}],
	["wpn_reedvolley",   "Reedsong Volley",      "spear", 3, "reedsong",  10, 0.85, {"count": 4}],
	["wpn_shrikebow",    "Shrikebow",            "bow",   3, "shot",      15, 0.55, {"plain": true}],
	["wpn_finchvolley",  "Finchstorm",           "bow",   3, "finchstorm", 9,  0.6,  {"count": 3}],
	["wpn_haleseeker",   "Hale Seeker",          "bow",   3, "haleseek",    11, 0.68, {}],
	["wpn_bogmortar",    "Bog Belcher",          "bow",   3, "lob_a",     17, 1.0,  {"aoe": 80, "rider": "bog"}],
	["wpn_lightstep",    "Lightstep",            "bow",   3, "rapid",     6,  0.19, {"plain": true}],
	["wpn_hollowbolt",   "Hollowbolt",           "wand",  3, "hollowring", 15, 0.5, {"rung": true}],
	["wpn_mirebook",     "The Mire Pages",       "wand",  3, "tome",      8,  1.45, {"radius": 120, "tome_kind": "mire"}],
	["wpn_shalewand",    "Shalebreaker",         "wand",  3, "cluster",   14, 0.85, {"shards": 5}],
	["wpn_pyrelight",    "Pyrelight",            "wand",  3, "fire",      18, 0.8,  {"aoe": 95, "status": "burn_w", "plain": true}],
	["wpn_courierrod",   "Courier's Bad News",   "wand",  3, "badnews",   12, 0.62, {"bounces": 3}],
	["wpn_shepherdstaff","Shepherd of Stones",   "staff", 3, "staff",     11, 0.42, {"slam_fx": "cairn"}],
	["wpn_wellstaff",    "Wellwalker",           "staff", 3, "staff",     13, 0.5,  {"slam_fx": "well"}],
	# ---------------- WAVE 3 - TIER 4 (28) ----------------
	["wpn_eveningblade", "Evening's Empire",     "melee", 4, "arc",       18, 0.42, {"plain": true}],
	["wpn_barrowmaul",   "Barrow King's Maul",   "melee", 4, "gravehands", 26, 1.0, {"knockup": true, "rung": true}],
	["wpn_cometflail",   "Comet on a Chain",     "melee", 4, "cometflail", 20, 0.95, {"status": "burn_w"}],
	["wpn_owlwheel",     "Owl-Eye Wheel",        "melee", 4, "owlwheel",  15, 0.78, {"dwell": 2.2}],
	["wpn_palefang",     "Palefang",             "melee", 4, "arc",       12, 0.25, {"status": "slow_w", "plain": true}],
	["wpn_riverrender",  "Riverrender",          "melee", 4, "riverrender", 16, 0.55, {"p_damage": 14}],
	["wpn_smokelash",    "Smoke and Ash",        "melee", 4, "smokelash", 16, 0.82, {"status": "burn_w"}],
	["wpn_debtblade",    "Debt of the Deep",     "melee", 4, "deepdebt",  15, 0.6,  {"bounces": 4}],
	["wpn_vigilpike",    "Vigil Unbroken",       "spear", 4, "thrust",    22, 0.82, {"plain": true}],
	["wpn_winterreach",  "Winter's Reach",       "spear", 4, "thrust",    18, 0.6,  {"status": "slow_w", "plain": true}],
	["wpn_hawkvolley",   "Hawks in Formation",   "spear", 4, "hawkline",  14, 0.88, {"count": 4}],
	["wpn_marrowprong",  "Marrowsplitter",       "spear", 4, "marrowsplit", 16, 0.95, {"count": 3}],
	["wpn_gravebow",     "The Polite Reminder",  "bow",   4, "shot",      20, 0.58, {"pierce": true, "plain": true}],
	["wpn_larkstorm",    "A Storm of Larks",     "bow",   4, "larkstorm", 15, 0.58, {"count": 3}],
	["wpn_needlerain",   "Needlerain",           "bow",   4, "rapid",     8,  0.17, {"plain": true}],
	["wpn_huntmaster",   "Huntmaster's Word",    "bow",   4, "huntword",  15, 0.62, {}],
	["wpn_sapperkiss",   "Sapper's Kiss",        "bow",   4, "lob_a",     23, 1.0,  {"aoe": 95, "status": "burn_w", "rider": "kiss"}],
	["wpn_glasstring",   "Glasstring",           "bow",   4, "shot",      17, 0.5,  {"status": "slow_w", "plain": true}],
	["wpn_covenbook",    "The Coven's Ledger",   "wand",  4, "covenledger", 10, 1.4,  {"radius": 135, "tome_kind": "coven"}],
	["wpn_frostwrit",    "Frost Writ",           "wand",  4, "writglyph", 19, 0.55, {"status": "slow_w", "rung": true}],
	["wpn_gloamburst",   "Gloamburst",           "wand",  4, "gloamburst", 19, 0.8,  {"shards": 6}],
	["wpn_howlbolt",     "Howling Bolt",         "wand",  4, "howlbolt",  16, 0.58, {"bounces": 4}],
	["wpn_candlepost",   "Candlekeeper",         "wand",  4, "candlekeeper", 9,  1.2,  {"dur": 18}],
	["wpn_stormsliver",  "Stormsliver",          "wand",  4, "forktree",  21, 0.5,  {"rung": true}],
	["wpn_paleobelisk",  "Pale Obelisk",         "staff", 4, "staff",     16, 0.46, {"slam_fx": "column"}],
	["wpn_fordstaff",    "Fordmaster",           "staff", 4, "staff",     14, 0.4,  {"slam_fx": "ford"}],
	["wpn_inkbook",      "Inkwell of Storms",    "wand",  4, "ink",       20, 0.9,  {}],
	["wpn_driftwheel",   "Driftwheel",           "melee", 4, "driftwheel", 17, 0.85, {"dwell": 2.6}],
	# ---------------- WAVE 3 - TIER 5 (26) ----------------
	["wpn_lastlantern",  "The Last Lantern",     "melee", 5, "lastlantern", 10, 0.4, {"status": "burn_w"}],
	["wpn_hourmaul",     "The Eleventh Hour",    "melee", 5, "stophour",  34, 1.08, {"knockup": true, "rung": true}],
	["wpn_gallowsflail", "Gallows Swing",        "melee", 5, "gallows",   26, 0.95, {}],
	["wpn_midwinterwheel","Midwinter Wheel",     "melee", 5, "midwinterwheel", 20, 0.78, {"dwell": 2.8, "status": "slow_w"}],
	["wpn_asphodelknife","Asphodel Kiss",        "melee", 5, "asphodelkiss", 7, 0.24, {"status": "poison_w"}],
	["wpn_seawallblade", "Seawall",              "melee", 5, "seawall",   21, 0.55, {"p_damage": 19}],
	["wpn_pilgrimlash",  "Pilgrim's Scourge",    "melee", 5, "pilgrimscourge", 21, 0.83, {}],
	["wpn_omenblade",    "Omen of Iron",         "melee", 5, "ironomen",  19, 0.58, {"bounces": 5}],
	["wpn_borderpike",   "Border of the Realm",  "spear", 5, "borderline", 18, 0.78, {}],
	["wpn_stormherd",    "Stormherd",            "spear", 5, "stormherd", 17, 0.88, {"count": 5}],
	["wpn_moonreach",    "Moonreach",            "spear", 5, "moonreach", 13, 0.58, {"status": "slow_w"}],
	["wpn_kestrelbow",   "Kestrel's Court",      "bow",   5, "kestrelcourt", 14, 0.54, {"count": 3}],
	["wpn_quillrain",    "Quillrain",            "bow",   5, "quillrain", 10, 0.16, {}],
	["wpn_wintermark",   "Wintermark",           "bow",   5, "wintermark", 11, 0.58, {"pierce": true, "status": "slow_w"}],
	["wpn_owlseeker",    "The Owl Remembers",    "bow",   5, "owlremembers", 19, 0.58, {}],
	["wpn_thunderhead",  "Thunderhead",          "bow",   5, "thunderhead", 29, 1.0,  {"aoe": 110}],
	["wpn_sirensbook",   "The Siren's Appendix", "wand",  5, "sirensong", 13, 1.35, {"radius": 150, "tome_kind": "lure"}],
	["wpn_glacierwrit",  "Glacier Writ",         "wand",  5, "glacierwrit", 24, 0.55, {"status": "slow_w"}],
	["wpn_starsplinter", "Starsplinter",         "wand",  5, "starsplinter", 24, 0.78, {"shards": 7}],
	["wpn_omenbolt",     "The Third Omen",       "wand",  5, "thirdomen", 21, 0.58, {"bounces": 5}],
	["wpn_beaconpost",   "Beacon of the Deep",   "wand",  5, "deepbeacon", 13, 1.18, {"dur": 22}],
	["wpn_emberhymn",    "Emberhymn",            "wand",  5, "emberhymn", 30, 0.82, {"aoe": 130, "status": "burn_w"}],
	["wpn_graniteway",   "The Granite Way",      "staff", 5, "graniteway", 7, 0.44, {"steps": 4}],
	["wpn_cloudcounter", "Cloudcounter",         "staff", 5, "cloudcount", 11, 0.38, {"clouds": 3}],
	["wpn_nightmortar",  "Midnight Post",        "bow",   5, "midnightpost", 27, 0.95, {"aoe": 105}],
	["wpn_saintwheel",   "Saint's Reward",       "melee", 5, "saintsreward", 22, 0.8,  {"dwell": 3.0}],
	# ---------------- WAVE 3 - TIER 6 (22) ----------------
	["wpn_requiemedge",  "Requiem Edge",         "melee", 6, "requiem",   13, 0.38, {}],
	["wpn_worldanvil",   "The World-Anvil",      "melee", 6, "anviltoll", 42, 1.08, {"knockup": true}],
	["wpn_cinderchain",  "Cinderchain",          "melee", 6, "cinderdrag", 32, 0.92, {"status": "burn_w"}],
	["wpn_voidwheel",    "Wheel of the Hollow",  "melee", 6, "hollowwheel", 26, 0.78, {"dwell": 3.2}],
	["wpn_sorrowfang",   "Sorrowfang",           "melee", 6, "sorrowfang", 8, 0.24, {"status": "poison_w", "bites": 3}],
	["wpn_horizonrender","Horizonrender",        "melee", 6, "horizonrend", 27, 0.54, {"p_damage": 25}],
	["wpn_nightlash",    "A Long Night's Tongue","melee", 6, "nightlash", 27, 0.8,  {"status": "slow_w", "companion": "blade", "c_damage": 13, "c_gap": 1.7}],
	["wpn_griefcollect", "Grief, Collected",     "melee", 6, "griefcollect", 24, 0.56, {"bounces": 6}],
	["wpn_worldspike",   "Worldspike",           "spear", 6, "worldstake", 21, 0.76, {}],
	["wpn_ashherd",      "Herd of Ashes",        "spear", 6, "ashherd",   22, 0.86, {"count": 5, "status": "burn_w"}],
	["wpn_griffvolley",  "Griffin Volley",       "bow",   6, "griffinvolley", 18, 0.5,  {"count": 4}],
	["wpn_silentchoir",  "The Silent Choir",     "bow",   6, "silentchoir", 13, 0.15, {}],
	["wpn_direseeker",   "Dire Portent",         "bow",   6, "direportent", 24, 0.56, {"companion": "beast", "c_damage": 14, "c_gap": 1.9}],
	["wpn_sunmortar",    "A Piece of the Sun",   "bow",   6, "sunpiece",  36, 1.0,  {"aoe": 125, "status": "burn_w"}],
	["wpn_wakebook",     "The Book of Wakes",    "wand",  6, "wake",      17, 0.85, {}],
	["wpn_permafrost",   "Permafrost Decree",    "wand",  6, "permafrost", 29, 0.54, {"status": "slow_w"}],
	["wpn_novaburst",    "Novaburst Rod",        "wand",  6, "novaburst", 30, 0.76, {"shards": 8}],
	["wpn_lastcourier",  "The Last Courier",     "wand",  6, "lastcourier", 26, 0.56, {"bounces": 6}],
	["wpn_watchfire",    "Watchfire",            "wand",  6, "watchfire", 17, 1.15, {"dur": 24}],
	["wpn_cindershelf",  "Cindershelf",          "wand",  6, "cindershelf", 36, 0.8,  {"aoe": 140, "status": "burn_w"}],
	["wpn_skyladder",    "Ladder to Nowhere",    "staff", 6, "skyladder", 23, 0.42, {"rungs": 3}],
	["wpn_stillmountain","The Still Mountain",   "staff", 6, "stillmountain", 26, 0.48, {}],
	# ---------------- WAVE 3 - TIER 7 (14) ----------------
	["wpn_dawnchorus",   "Dawn Chorus",          "melee", 7, "dawnline", 30, 0.42, {"status": "burn_w",
		"fx": [{"kind": "echo", "pct": 0.32, "delay": 0.35}]}],
	["wpn_finalanvil",   "Anvil of Endings",     "melee", 7, "anvil", 43, 1.15, {"knockup": true,
		"fx": [{"kind": "quake", "radius": 160.0, "pct": 0.28}]}],
	["wpn_cometchain",   "Chained Comet",        "melee", 7, "cometchain", 34, 0.95, {"status": "burn_w",
		"fx": [{"kind": "gravity", "radius": 200.0, "pull": 160.0}]}],
	["wpn_silencelash",  "The Shape of Silence", "melee", 7, "hush", 28, 0.84, {"status": "slow_w",
		"fx": [{"kind": "brand", "amp": 0.14, "dur": 4.5}]}],
	["wpn_worldthorn",   "Thorn of the World",   "spear", 7, "worldthorn", 34, 0.8, {
		"fx": [{"kind": "rend", "pct_per": 0.05, "max": 6}]}],
	# NINE birds, not six -- a flock should darken the row (2026-07-30)
	["wpn_stormflock",   "Flock of Storms",      "spear", 7, "stormflock", 20, 0.9, {"count": 12,
		"fx": [{"kind": "chain", "n": 2, "pct": 0.28, "range": 240.0}]}],
	["wpn_choirstring",  "Choirstring",          "bow", 7, "choirstring", 18, 0.62, {"count": 3, "pierce": true,
		"fx": [{"kind": "echo", "pct": 0.28, "delay": 0.4}]}],
	["wpn_reckoningbow", "The Quiet Reckoning",  "bow", 7, "reckoning", 29, 0.6, {
		"fx": [{"kind": "brand", "amp": 0.15, "dur": 4.0}]}],
	["wpn_sunspill",     "Sunspill",             "bow", 7, "sunspill", 34, 1.02, {"aoe": 130, "status": "burn_w",
		"fx": [{"kind": "splinter", "n": 4, "pct": 0.28, "range": 180.0}]}],
	["wpn_tidebook",     "The Tidal Codex",      "wand", 7, "tome", 20, 1.25, {"radius": 225,
		"fx": [{"kind": "gravity", "radius": 220.0, "pull": 150.0}]}],
	["wpn_shardregent",  "The Shard Regent",     "wand", 7, "shardregent", 29, 0.85, {"shards": 5,
		# fx must SUPPORT the verb, never overwrite it. skyrain drops sky-comets
		# -- that is the starfall weapons' signature, and on film it completely
		# buried this weapon's own crown-of-shards. splinter suits shards; haste
		# suits a regent whose court answers faster the better it goes.
		"fx": [{"kind": "splinter", "n": 5, "pct": 0.28, "range": 170.0}]}],
	["wpn_finaldebt",    "The Final Debt",       "wand", 7, "finaldebt", 25, 0.6, {"bounces": 7,
		"fx": [{"kind": "goldtouch", "chance": 0.12, "gold": 5}]}],
	["wpn_highlantern",  "Lantern of the High Road", "wand", 7, "sentry", 19, 1.12, {"dur": 26,
		"fx": [{"kind": "moonlit", "pct": 0.28}]}],
	["wpn_bentheaven",   "Heaven, Bent",         "staff", 7, "bentheaven", 27, 0.52, {
		"fx": [{"kind": "gravity", "radius": 210.0, "pull": 170.0}]}],
	# ---------------- WAVE 3 - TIER 8 (10) ----------------
	# CROWN TEN #7: a cleave shared with 14 becomes a blow the GROUND carries.
	["wpn_griefcrown",   "Grief Wears a Crown",  "melee", 8, "sunder", 34, 1.1,  {"knockup": true, "status": "slow_w",
		"fx": [{"kind": "quake", "radius": 180.0, "pct": 0.35}]}],
	# CROWN TEN #5: a chain_maul shared with 8 weapons, wearing three fx riders,
	# becomes the weapon its name describes -- put the throne DOWN and it burns.
	["wpn_emberthrone",  "Throne of Embers",     "melee", 8, "brazier", 30, 0.95, {"status": "burn_w",
		"fx": [{"kind": "stormcall", "every": 3, "pct": 0.56}]}],
	["wpn_worldslash",   "A Cut Across the World","melee", 8, "worldcut", 38, 0.52, {"p_damage": 40,
		"fx": [{"kind": "splinter", "n": 5, "pct": 0.35, "range": 200.0}]}],
	# THE CROWN TEN (overhaul wave, 2026-07-29): apex weapon #1. Three stacked
	# fx riders on a shared orbiter became ONE verb you can say in a sentence.
	["wpn_courtwheel",   "The Whole Court, Spinning", "melee", 8, "court", 33, 0.8, {"count": 4,
		"fx": [{"kind": "crowd", "pct_per": 0.05, "cap": 0.6}]}],
	# CROWN TEN #2: apex weapon. Six jabs + three fx riders became one arm of
	# law that reaches through rock -- the "walls do not apply to me" weapon.
	["wpn_edictpike",    "The Final Edict",      "spear", 8, "edict", 26, 1.05, {"status": "burn_w",
		"fx": [{"kind": "brand", "amp": 0.15, "dur": 5.0}]}],
	# CROWN TEN #8: nothing leaves the bow -- the arrows fall from the sky, and
	# a roof genuinely stops them (the balance dial is built into the fiction).
	# SEVEN, not three. At three falling arrows this was a 52 dps Monarch --
	# beaten by the Ascended median. A king's rain should darken the sky.
	["wpn_hollowking",   "The Hollow King's Rain","bow", 8, "skyfall_rain", 16, 0.62, {"count": 7, "status": "burn_w",
		"fx": [{"kind": "soulwisp", "dmg": 6, "pct": 0.35}]}],
	# CROWN TEN #9: every landed arrow calls one of the procession in from off
	# the edge of the world -- the crowd is ambushed by YOUR weapon.
	["wpn_nightparade",  "Night Parade",         "bow", 8, "parade", 14, 0.5,  {
		"fx": [{"kind": "moonlit", "pct": 0.35}]}],
	["wpn_worldsgrief",  "The World's Grief",    "wand", 8, "worldsgrief", 40, 0.72, {"shards": 10,
		"fx": [{"kind": "splinter", "n": 6, "pct": 0.35, "range": 190.0}]}],
	["wpn_deepcrown",    "Crown of the Deep Court","wand", 8, "deepcourt", 24, 1.1,  {"dur": 30,
		# THREE courtiers, as the card has always claimed. The companion system
		# reads these TOP-LEVEL keys, not the special -- this row carried none
		# of them, so the crown summoned nobody at all.
		# FIVE courtiers (2026-07-30). Three made the deep crown a 65 dps Monarch,
	# under the Ascended median -- a drowned COURT should crowd the screen.
	"companion": "wisp", "c_damage": 22, "c_gap": 1.3, "c_count": 5,
		"fx": [{"kind": "soulwisp", "dmg": 5, "pct": 0.35}]}],
	# CROWN TEN #10: a `staff` shared with 20 becomes a rolling stone whose
	# bite is its own gathered pace -- a hill is a damage multiplier.
	["wpn_mountainking", "The Mountain That Kneels","staff", 8, "boulder", 30, 1.3, {
		"fx": [{"kind": "bulwark", "dr": 0.08, "dur": 3.5}]}],
	# ---------------- WAVE 3 - FLAGSHIPS (11) ----------------
	["wpn_therumor",     "The Rumor",            "wand", 8, "rumor", 34, 0.5,  {"bounces": 9, "rider": "grows",
		"fx": [{"kind": "echo", "pct": 0.35, "delay": 0.4}]}],
	["wpn_choirofone",   "A Choir of One",       "bow", 8, "choirofone", 17, 0.13, {"status": "burn_w", "rider": "choir",
		"fx": [{"kind": "echo", "pct": 0.35, "delay": 0.3}]}],
	# CROWN TEN #3: apex weapon. A one-shot fire blast (three fx riders, 47 dmg)
	# became THE CHANNEL -- hold it and six beams narrow into a single column.
	# Damage per beam is small on purpose: the climb comes from CONVERGENCE
	# putting all six through one body, exactly as the film shows.
	# fx chosen for a CHANNEL: quake never suited a beam. Wounds that deepen the
	# longer you pour, and a kill that feeds the next second of burning.
	["wpn_smallsun",     "A Small Personal Sun", "wand", 8, "prism", 14, 0.5,  {"status": "burn_w",
		"fx": [{"kind": "rend", "pct_per": 0.04, "max": 8}]}],
	["wpn_patientknife", "The Patient Knife",    "melee", 8, "patientknife", 22, 0.2,  {"status": "poison_w", "rider": "patient",
		"fx": [{"kind": "rend", "pct_per": 0.05, "max": 8}]}],
	["wpn_skysfare",     "What the Sky Charges", "wand", 8, "skycharges", 30, 1.15, {"radius": 220, "rider": "walker",
		"fx": [{"kind": "stormcall", "every": 3, "pct": 0.56}]}],
	["wpn_longgoodbye",  "The Long Goodbye",     "melee", 7, "lash", 36, 0.76, {"status": "poison_w", "rider": "goodbye",
		"fx": [{"kind": "duelist", "pct_per": 0.05, "max": 7}]}],
	["wpn_borrowedstar", "A Borrowed Star",      "bow", 7, "lob_a", 43, 0.95, {"aoe": 150, "status": "burn_w", "rider": "borrow",
		"fx": [{"kind": "starfall", "pct": 0.29, "stars": 3}]}],
	["wpn_gravecourier", "Grave Courier",        "melee", 7, "ricochet", 27, 0.52, {"bounces": 7, "rider": "courier",
		"fx": [{"kind": "soulwisp", "dmg": 5, "pct": 0.28}]}],
	["wpn_summerscoffin","Summer's Coffin",      "wand", 7, "icecoffin", 32, 0.5,  {"status": "slow_w", "rider": "coffin",
		"fx": [{"kind": "frostbloom", "radius": 160.0, "dur": 3.0}]}],
	["wpn_kindlyend",    "The Kindly End",       "spear", 6, "horizonpike", 40, 0.7,  {"status": "poison_w", "rider": "kindly"}],
	["wpn_secondmoon",   "Second Moon",          "melee", 6, "secondmoon", 36, 0.85, {"status": "slow_w", "rider": "moon"}],
	["wpn_heavenpoint",  "The Heaven-Piercing Point", "spear", 7, "heavenpoint", 38, 0.8, { "status": "slow_w",
		"fx": [{"kind": "chain", "n": 2, "pct": 0.28, "range": 260.0}]}],
	["wpn_unbentcolumn", "The Unbent Column",    "staff", 8, "unbentcolumn", 36, 0.35, {
		"fx": [{"kind": "bulwark", "dr": 0.08, "dur": 3.5}]}]
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
	# THE SUMMONER (batch 1). "staff" was already taken by the Wukong melee
	# staff, so the caller is a SCEPTER. Scepters and totems both cast, so both
	# resolve to weapon_type "summon"; the whip is its own swinging type.
	elif klass == "scepter" or klass == "totem":
		wtype = "summon"
	var reach := 46.0
	var area := Vector2(60, 36)
	var icon := Vector2(52, 12)
	var icon_off := 20.0
	match klass:
		"spear":
			reach = 58.0
			area = Vector2(74, 38)
			icon = Vector2(78, 8)
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
		# ---- THE SUMMONER ----
		"whip":
			# long and thin: the lash reaches past a sword but weighs nothing
			reach = 74.0
			area = Vector2(120, 26)
			icon = Vector2(64, 5)
			icon_off = 16.0
		"scepter":
			reach = 30.0
			area = Vector2(10, 10)
			icon = Vector2(50, 9)
		"totem":
			reach = 30.0
			area = Vector2(10, 10)
			icon = Vector2(44, 12)
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
	# THE SOUL ON THE CARD (dev: "make sure weapons are not dumb and only
	# plain stats"): a unique effect the player cannot READ is stats with
	# extra steps. Every fx writes its own line onto the card.
	if ex.has("fx"):
		var soul := _fx_desc(ex["fx"] if ex["fx"] is Array else [ex["fx"]])
		if soul != "":
			d["unique_desc"] = (str(d.get("unique_desc", "")) + " " + soul).strip_edges()
	# COMPANIONS (light summoner 2026-07-29): a carrier row's extras name a
	# companion; the def carries it to player._reconcile_companions, and the
	# card SAYS it (the readable-soul rule).
	if ex.has("companion"):
		d["companion"] = str(ex["companion"])
		d["c_damage"] = int(ex.get("c_damage", 12))
		d["c_gap"] = float(ex.get("c_gap", 1.8))
		# how MANY it carries. Crown of the Deep Court promises three courtiers
		# and this key was not forwarded at all, so it summoned one.
		d["c_count"] = int(ex.get("c_count", 1))
		if COMPANION_DESC.has(d["companion"]):
			d["unique_desc"] = (str(d.get("unique_desc", "")) + " " + COMPANION_DESC[d["companion"]]).strip_edges()
	return d

# the companion, in the player's language (cards + the audit's readable rule)
const COMPANION_DESC = {
	"blade": "A BROTHER-BLADE walks with you while this is drawn, darting at whatever comes near.",
	"wisp": "A WATCH-CANDLE hovers at your shoulder while this is drawn, lobbing slow seeking motes.",
	"beast": "A SHADE-HOUND runs at your heel while this is drawn, pouncing on whatever you face.",
}

# the fx, in the player's language -- one short clause per soul
static func _fx_desc(fxl: Array) -> String:
	var parts := []
	for f in fxl:
		match str(f.get("kind", "")):
			"chain": parts.append("Hits arc to %d nearby foe%s." % [int(f.get("n", 2)), "s" if int(f.get("n", 2)) > 1 else ""])
			"echo": parts.append("Every blow repeats itself a beat later.")
			"rend": parts.append("Wounds stack, deepening every next hit.")
			"quake": parts.append("Strikes shake the ground around the mark.")
			"splinter": parts.append("Hits burst into shards that nick the near.")
			"brand": parts.append("Marks foes to suffer extra from your next blows.")
			"harvest": parts.append("Kills feed the wielder.")
			"goldtouch": parts.append("Blows can shake coin loose.")
			"stormcall": parts.append("Every %dth swing calls lightning down." % int(f.get("every", 4)))
			"gravity": parts.append("Blows drag the nearby dark inward.")
			"bulwark": parts.append("Striking true briefly steels you.")
			"haste": parts.append("Kills quicken your hands.")
			"moonlit": parts.append("Fiercer under the night sky.")
			"bloodprice": parts.append("Extra power, paid in your own blood.")
			"duelist": parts.append("Loyalty: repeated hits on one foe ramp ever higher.")
			"crowd": parts.append("Louder in a crowd -- bonus per foe standing near.")
			"frostbloom": parts.append("Crits bloom into slowing frost.")
			"soulwisp": parts.append("The fallen rise as wisps that fight for you.")
			"shove": parts.append("Blows batter foes back.")
			"sparkfly": parts.append("Sparks leap off wounds to find another foe.")
			"windup": parts.append("Every %dth swing lands far heavier." % int(f.get("every", 3)))
			"mendstrike": parts.append("True blows mend the wielder a little.")
			"farsight": parts.append("Fiercer at a distance.")
			"closequarters": parts.append("Fiercer nose to nose.")
			"starfall": parts.append("Every hit calls a star down onto the mark.")
			"skyrain": parts.append("The volley falls from the sky itself.")
			"legacy": parts.append("Each blow hurls ghost-echoes of the ladder's blades.")
	return " ".join(parts)

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
		# the "cleave" BEHAVIOR label lived here. All ten weapons that used it
		# now have their own follow-through, so it is unreachable and gone --
		# flagged by the dead-verb audit the moment the last one left.
		# The cleave TYPE survives: it is what the ten still share (a wide blade
		# really does hit everything in front of it) plus wpn_greatsword in
		# inventory.gd, which earned it honestly.
		"crescent":
			s = {"type": "flying_slash", "damage": int(ex.get("p_damage", dmg)), "speed": spd, "range": rng}
		# ("jab_volley" -- the plain ten-degree fan -- used to live here. All SEVEN
		# of its owners now throw shapes of their own, so the case had no weapon
		# left. Third verb to empty out this way, after "seeker" and "volley":
		# clearing a bucket of look-alikes always ends with the bucket itself
		# becoming dead code, and tool_deadverb_audit catches it every time.)
		# ---- THE SEVEN THAT WERE ONE THROW ----------------------------------
		# All seven declared "jab_volley": a fan of 2-4 spectral javelins at ten
		# degrees. Seven names, one throw. Each now owns the SHAPE of its cast --
		# how the shafts leave the hand, not how hard they land.
		"reedcast":
			# reeds are LIGHT. They go further and faster than anything this
			# cheap has a right to, and they land like reeds.
			s = {"type": "javelin_volley", "shape": "reed", "count": int(ex.get("count", 2)),
				"spread_deg": 6.0, "damage": maxi(1, int(round(float(dmg) * 0.8))),
				"speed": spd + 320.0, "range": rng + 200.0}
		"stormprong":
			# the prongs are CHARGED: where the volley lands, the sky answers.
			s = {"type": "javelin_volley", "shape": "storm", "count": int(ex.get("count", 3)),
				"spread_deg": 10.0, "damage": dmg, "speed": spd + 150.0, "range": rng}
		"galeprong":
			# a GALE does not aim. Four prongs thrown across a wide arc, and
			# every one of them SHOVES.
			s = {"type": "javelin_volley", "shape": "gale", "count": int(ex.get("count", 4)),
				"spread_deg": 34.0, "damage": dmg, "speed": spd + 150.0, "range": rng}
		"gullwing":
			# gulls BANK. The prongs leave wide and curve back in, meeting at a
			# point ahead -- the opposite of a fan.
			s = {"type": "javelin_volley", "shape": "gull", "count": int(ex.get("count", 3)),
				"spread_deg": 10.0, "damage": dmg, "speed": spd + 150.0, "range": rng,
				"focus": 230.0}
		"reedsong":
			# a SONG is a sequence, not a chord: the shafts leave one after
			# another on a beat rather than all at once.
			s = {"type": "javelin_song", "shape": "song", "count": int(ex.get("count", 4)),
				"spread_deg": 14.0, "damage": dmg, "speed": spd + 150.0, "range": rng,
				"beat": 0.09}
		"hawkline":
			# FORMATION. Almost no spread at all -- four shafts abreast, holding
			# the line, going through what they meet.
			s = {"type": "javelin_volley", "shape": "line", "count": int(ex.get("count", 4)),
				"spread_deg": 2.0, "damage": dmg, "speed": spd + 150.0, "range": rng,
				"pierce": true}
		"marrowsplit":
			# it SPLITS. Three shafts go, and a beat later each one is two.
			s = {"type": "javelin_volley", "shape": "marrow", "count": int(ex.get("count", 3)),
				"spread_deg": 8.0, "damage": maxi(1, int(round(float(dmg) * 0.8))),
				"speed": spd + 150.0, "range": rng, "split_after": 0.16}
		# ("volley" -- the plain 12-degree fan -- used to live here. All SIX of
		# its owners now have shapes of their own, so the case had no weapon
		# left and tool_deadverb_audit called it, exactly as it did for
		# "seeker". A verb nothing reaches is a verb that quietly rots.)
		# ---- THE SIX THAT WERE ONE BOW WEARING SIX NAMES --------------------
		# All six declared "volley" -> multi_shot, count 2-3, spread 12 degrees.
		# Identical fans, separated only by damage. The sameness audit put them
		# in one bucket and it was right. Each now owns a SHAPE the eye can read
		# from a single shot -- not a stat, a motion.
		"ferrytwin":
			# THE FERRYMAN'S BOW makes the crossing TWICE: one shaft goes, and a
			# second retraces its exact line a beat later. There and back.
			s = {"type": "ferry_twin", "count": 2, "delay": 0.22}
		"twinnock":
			# TWINNOCK: two arrows nocked as one. It leaves the string as a
			# SINGLE shaft and comes apart into two halfway down the lane.
			s = {"type": "twin_nock", "count": 2, "split_at": 0.45}
		"choirpoints":
			# A CHOIR OF POINTS sings in HARMONY, so its arrows do not spread --
			# they CONVERGE, three lines meeting at one spot ahead of you.
			s = {"type": "choir_points", "count": int(ex.get("count", 3)),
				"focus": 210.0}
		"paleflight":
			# PALE FLIGHT: ghost shafts. They pass THROUGH bodies instead of
			# stopping in them, and pay for it -- each one lands softer.
			s = {"type": "pale_flight", "count": 2, "soft": 0.65, "pierce_n": 4}
		"finchstorm":
			# FINCHSTORM: finches do not fly straight. Three shafts that FLIT --
			# each picks its own wandering line and drifts toward whatever it
			# passes near.
			s = {"type": "finch_storm", "count": int(ex.get("count", 3)),
				"jitter": 0.30}
		"larkstorm":
			# A STORM OF LARKS scatters. Not a tight fan but a WIDE front, 46
			# degrees of sky, so it covers a room rather than a lane.
			s = {"type": "lark_storm", "count": int(ex.get("count", 3)),
				"spread_deg": 46.0}
		"paleseek":
			# PALE SEEKER ignores the healthy and bends, unhurried, toward
			# whatever is already WOUNDED -- then comes apart on landing.
			s = {"type": "homing", "hunt": "wounded"}
		"haleseek":
			# HALE SEEKER flies dead straight and takes exactly ONE hard turn
			# onto the BIGGEST thing in the room, then never turns again. No
			# split: that belongs to the Pale one, and removing it here is
			# what makes the pair read as two weapons.
			s = {"type": "homing", "hunt": "biggest", "pierce": true}
		# ("seeker" -- plain nearest-target homing -- used to live here. Both of
		# its owners now hunt by their own rule, so the generic case had no
		# weapon left and tool_deadverb_audit called it: a case label nothing
		# reaches is exactly the kind of thing that quietly rots.)
		"lob_a", "lob":
			s = {"type": "lob", "damage": dmg, "speed": spd, "range": rng, "aoe": float(ex.get("aoe", 90.0))}
		# TWO WANDS THAT DEALT LITERALLY NOTHING (found 2026-07-30).
		# Both of these declared a behavior with NO CASE LABEL here, so they fell
		# through with an empty special -- and `_expand` hardcodes wand swing
		# damage to 0, so a Mythic wand costing 18 mana did no damage at all.
		# The cruel part: ink_jet and wake_scythe are FULLY BUILT in
		# weapon_projectile.gd -- art, motion, pierce, spin, the lot. The
		# projectiles existed the whole time; the roster just never named them.
		# I even "improved" both earlier today (the ink re-cut, the scythe's
		# return pass) -- edits to code that could never run.
		# This is the third instance of this exact failure in this file; see the
		# notes on `souls` and `storm_debt`. A behavior with no case is now
		# caught by tool_deadverb_audit.gd rather than by a player noticing.
		"ink":
			s = {"type": "ink_jet", "damage": dmg, "speed": spd, "range": rng}
		"wake":
			s = {"type": "wake_scythe", "damage": dmg, "speed": spd, "range": rng}
		# --- THE CLEAVE TEN ---------------------------------------------------
		# Their shared swing ARC is honest and stays: a wide blade really does
		# hit everything in front of it. What was dishonest is that all ten shed
		# the IDENTICAL generic carve crescent, so ten differently-named mauls
		# threw the same green arc. The arc stays shared; the FOLLOW-THROUGH is
		# what makes each one itself.
		"spadespray":
			# PIT SHOVEL scoops the floor and flings it. A tier-1 common with a
			# grounded/airborne dial: feet planted throws seven clods, airborne
			# throws two, because you cannot dig air.
			s = {"type": "cleave", "spray": "clod", "damage": dmg}
		"hoopshunt":
			# CELLAR MALLET is a cooper's flat blow: it SHUNTS the arc backwards
			# as one, and anything it slams into a wall pays again.
			s = {"type": "cleave", "spray": "hoop", "damage": dmg}
		"fellblow":
			# ORCHARD FELLER notches what it hits, and a beat later that body
			# TIPS -- felled like a tree, into whatever is beside it.
			s = {"type": "cleave", "spray": "fell", "damage": dmg}
		"reaprow":
			# FURROW SCYTHE: the cut leaves the blade and keeps RUNNING along
			# the floor. One ledge defeats it, which is the honest price.
			s = {"type": "cleave", "spray": "reap", "damage": dmg}
		"belltoll":
			# BELL HAMMER does not push, it RINGS: three brass rings leaving the
			# head at three radii.
			s = {"type": "cleave", "spray": "bell", "damage": dmg}
		"scoresplit":
			# QUARRY MAUL scores stone first and SPLITS it on the second blow --
			# a two-swing rhythm, the only cleave that asks you to set up.
			s = {"type": "cleave", "spray": "score", "damage": dmg}
		"endtoll":
			# TOLL OF THE END hangs a countdown on a body; when it runs out the
			# bill lands, and a kill JUMPS it to the next one.
			s = {"type": "cleave", "spray": "toll", "damage": dmg}
		"gravehands":
			# BARROW KING'S MAUL calls dead hands UP THROUGH THE FLOOR, in a row
			# marching away from the blow.
			s = {"type": "cleave", "spray": "hands", "damage": dmg}
		"stophour":
			# THE ELEVENTH HOUR stops the clock: the struck body freezes, the
			# damage it should have taken is STORED, and it all lands at once
			# when time restarts. The family's apex.
			s = {"type": "cleave", "spray": "hour", "damage": dmg}
		"opengrave":
			# GRAVEKEEPER'S SPADE takes a spadeful out of the WORLD -- an open
			# hole in front, and the sod it threw lands behind as cover.
			s = {"type": "cleave", "spray": "grave", "damage": dmg}
		"drinkthread":
			# LEECHLIGHT drinks. Nothing is thrown: a thread snaps taut to the
			# nearest foe and pulls, ticking damage and returning a little as
			# health. The only TETHER and the only self-heal of the eleven, and
			# structurally weak on purpose -- it needs a target already in range,
			# so it cannot open a fight.
			s = {"type": "leech_thread", "damage": dmg, "range": 320.0}
		"writglyph":
			# FROST WRIT writes a sentence in the air -- five ice-glyphs hanging
			# where written -- and a beat later every glyph EXECUTES, dropping an
			# icicle from itself. A writ is a written order, so it is written and
			# then carried out. The only wand whose damage arrives VERTICALLY.
			# no "count": the five glyphs are children of ONE projectile, so a
			# declared count would promise the dispatch audit five NODES and it
			# would be right to refuse. The sentence is one object.
			s = {"type": "writ_glyph", "damage": dmg, "range": 200.0}
		"icecoffin":
			# SUMMER'S COFFIN buries the season. A slab opens into a standing
			# coffin around the nearest foe, holds it in the cold, then cracks
			# and throws every panel outward as a splinter. The family's apex:
			# overwhelming, and still ONE clean idea.
			s = {"type": "ice_coffin", "damage": dmg, "speed": 620.0, "range": rng}
		"saltring":
			# SALTBINDER binds. A ring of grains on the ground; what is inside
			# cannot leave, and the salt burns it each time it tries. The only
			# CONTAINMENT verb in either family -- its job is to keep enemies
			# somewhere rather than to move, hurt or kill them. Salt-as-binding
			# is folklore-correct, so name, material and effect all agree.
			s = {"type": "salt_ring", "damage": dmg, "range": 78.0}
		"hollowring":
			# HOLLOWBOLT is empty. It passes through bodies AND TERRAIN hurting
			# nothing, remembers everyone it crossed, and when it reaches its end
			# it COLLAPSES and they all pay at once. The waiting IS the weapon.
			s = {"type": "hollow_ring", "damage": dmg, "speed": 300.0, "range": rng}
		"forktree":
			# STORMSLIVER splinters the air: one sliver forks, and each fork
			# forks again -- a lightning tree that arrives effectively instantly.
			# Against ten travelling projectiles, "it is already there" is a
			# silhouette all its own.
			s = {"type": "fork_tree", "damage": dmg, "range": 220.0}
		"brookflow":
			# THE BROOKWAND pours. A band of water runs along the FLOOR, over
			# ledges and down holes, soaking what it crosses. Keeps the cold
			# identity but as WATER, which is what a brook actually is. The only
			# terrain-following fluid in the roster, and the only projectile
			# that deliberately goes down a hole.
			s = {"type": "brook_band", "damage": dmg, "speed": 340.0, "range": rng}
		"sporepatch":
			# MOSSLIGHT seeds. A drifting spore sticks to the first thing it
			# touches and unfurls into a patch that pulses; patches near each
			# other link up. The only stick-and-grow denial of the eleven.
			s = {"type": "spore_light", "damage": dmg, "speed": 260.0, "range": rng * 0.7}
		"stubmisfire":
			# THE STUBWAND is BROKEN. Two to four ragged sparks in a wide fan,
			# and about one cast in six coughs a single fat one instead that
			# hits for triple and shoves YOU back a step. The only random-output
			# wand in the game -- its silhouette changes cast to cast.
			# deliberately NO "count": the number of sparks is random (2-4, or a
			# single fat one), so declaring a count would promise the dispatch
			# audit something this weapon cannot honour on any given cast.
			s = {"type": "stub_spark", "damage": dmg, "speed": 700.0,
				"range": 150.0}
		"tallowdrip":
			# THE TALLOW WAND throws hot candle-fat, not ice. A slow gravity lob
			# that splats and stands a small flame up out of the puddle. The
			# only lobbed wand in the eleven, and the honest counterweight to
			# the Chalk Wand's speed: short, slow, and it owns the ground.
			s = {"type": "lob", "damage": dmg, "speed": 300.0, "range": rng * 0.55,
				"aoe": 46.0, "rider": "tallow"}
		"chalkline":
			# THE CHALK WAND draws instead of throwing: a stroke that hangs in
			# the air and cuts whatever crosses it. The only zero-velocity wand
			# in the game, which is what makes it readable at a glance.
			s = {"type": "chalk_line", "damage": dmg, "range": 96.0}
		# "bolt" and "frost" USED TO LIVE HERE, and both resolved to
		# {"type": "frost_shard"}. Between them they gave eleven weapons named
		# for chalk, tallow, moss, leeches, salt, hollowness, storm, water,
		# writing and a coffin the SAME ice dart. All eleven now have their own
		# verb, so both labels are unreachable and are gone -- the dead-verb
		# audit flagged them the moment the last weapon left, which is exactly
		# the reverse check it exists for.
		# The frost_shard TYPE survives: six hand-authored ice weapons in
		# inventory.gd legitimately earned it.
		"fire":
			s = {"type": "fireball", "damage": dmg, "aoe": float(ex.get("aoe", 90.0)), "speed": spd - 40.0, "range": rng}
		# (the "frost" label lived here -- see the note above "chalkline")
		"ricochet":
			s = {"type": "ricochet", "damage": dmg, "speed": spd + 120.0, "range": rng, "bounces": int(ex.get("bounces", 3))}
		# ---- THE FIVE THAT WERE ONE DART ------------------------------------
		# Ratter's Dart, Hookbill, Finchbolt, Tithe Gatherer and Courier's Bad
		# News all declared "ricochet": leap, lose 15% a bounce, repeat. Five
		# names, one dart. The bounce ALREADY had a rider hook (The Rumor grows,
		# the Grave Courier fears, The Final Debt books) -- these five were
		# simply never given one.
		"ratterdart":
			# a ratter FINISHES things. Its leaps ignore the healthy and go for
			# whatever is already hurt.
			s = {"type": "ricochet", "damage": dmg, "speed": spd + 160.0,
				"range": rng, "bounces": int(ex.get("bounces", 2)), "rider": "ratter"}
		"hookbill":
			# a hook GATHERS. Every body it leaves is dragged a step toward the
			# place it was struck, so a chain pulls the room into a knot.
			s = {"type": "ricochet", "damage": dmg, "speed": spd + 120.0,
				"range": rng, "bounces": int(ex.get("bounces", 3)), "rider": "hook"}
		"finchbolt":
			# a finch keeps finding fresh birds: striking something UNTOUCHED
			# refunds the leap, so a full room carries it further than a hurt one.
			s = {"type": "ricochet", "damage": dmg, "speed": spd + 200.0,
				"range": rng, "bounces": int(ex.get("bounces", 3)), "rider": "finch"}
		"tithegather":
			# it COLLECTS. Every bounce mints a coin -- the only weapon in the
			# roster that pays you for the length of a chain.
			s = {"type": "ricochet", "damage": dmg, "speed": spd + 120.0,
				"range": rng, "bounces": int(ex.get("bounces", 3)), "rider": "tithe"}
		"badnews":
			# news travels quietly and lands hard: the leaps are ordinary, and
			# the LAST one -- the delivery -- hits for two and a half times.
			s = {"type": "ricochet", "damage": dmg, "speed": spd + 120.0,
				"range": rng, "bounces": int(ex.get("bounces", 3)), "rider": "badnews"}
		"cluster":
			s = {"type": "cluster", "damage": dmg, "speed": spd, "range": rng, "shards": int(ex.get("shards", 5))}
		"tome":
			s = {"type": "tome_storm", "damage": dmg, "range": rng + 60.0, "radius": float(ex.get("radius", 130.0)), "dur": 4.5, "gap": 0.4}
			# no two tomes cast the same shape: the row's tome_kind rides into
			# cast_storm_tome and picks the zone's whole character
			if ex.has("tome_kind"):
				s["tome_kind"] = str(ex["tome_kind"])
		"sentry":
			s = {"type": "sentry", "damage": dmg, "dur": float(ex.get("dur", 16.0)), "gap": 0.85}
		"orbiter":
			s = {"type": "orbiter", "damage": dmg, "speed": spd + 100.0, "range": 230.0 + float(tier) * 15.0, "dwell": float(ex.get("dwell", 2.2))}
		"chain_maul":
			s = {"type": "chain_maul", "damage": dmg, "speed": spd + 40.0, "range": 260.0 + float(tier) * 18.0}
		"lash":
			s = {"type": "lash", "damage": dmg, "speed": spd + 60.0, "range": 300.0 + float(tier) * 20.0}
		"zenith":
			# THE LAST WORD: the whole armoury in the air AT ONCE. Rebuilt
			# from a single ghost blade (a boomerang with a good name) into
			# a STORM of nine ancestor blades, swirling out and back in,
			# cutting continuously. Zenith-kin, never 1:1.
			s = {"type": "zenith_storm", "damage": dmg}
		"court":
			# THE WHOLE COURT, SPINNING alone: a RANK of ancestor-blade shades
			# arrives at once (First-Fractal-kin) -- the apex spectacle weapon
			s = {"type": "court_barrage", "damage": dmg, "count": int(ex.get("count", 4)), "range": rng + 60.0}
		"edict":
			# THE FINAL EDICT alone: the arm of the law extends THROUGH ROCK and
			# cuts along its whole length (Solar-Eruption-kin, never 1:1)
			s = {"type": "edict_lash", "damage": dmg, "range": rng + 300.0}
		"prism":
			# A SMALL PERSONAL SUN alone: a CHANNEL -- six sunbeams that converge
			# into one column the longer you hold (Last-Prism-kin, never 1:1)
			s = {"type": "prism_converge", "damage": dmg}
		"regicide":
			# REGICIDE alone: thrown crown-spears that STICK and stack, the sixth
			# pushing the first out in a burst (Daybreak-kin, never 1:1)
			s = {"type": "crown_spear", "damage": dmg, "speed": spd + 220.0, "range": rng}
		"brazier":
			# THRONE OF EMBERS alone: the flail head SITS where it lands and
			# burns as a brazier before you take it up (Flower-Pow-kin)
			s = {"type": "brazier_flail", "damage": dmg, "speed": spd + 40.0, "range": 240.0 + float(tier) * 16.0}
		"sorrow":
			# THE CROWN'S SORROW alone: a POUR of narrow piercing lances rather
			# than a swing (Starlight-kin: the identity is hit RATE)
			s = {"type": "grief_beam", "damage": dmg, "speed": spd + 420.0, "range": 300.0}
		"sunder":
			# GRIEF WEARS A CROWN alone: the blow runs out THROUGH the ground
			# and takes each body once as it passes (Golem-Fist-kin)
			s = {"type": "sunder_wave", "damage": dmg, "range": 520.0}
		"skyfall_rain":
			# THE HOLLOW KING'S RAIN alone: nothing leaves the bow -- the arrows
			# fall from above the aim, and a roof genuinely stops them
			s = {"type": "king_rain", "damage": dmg, "count": int(ex.get("count", 3)), "range": rng}
		"parade":
			# NIGHT PARADE alone: every landed arrow calls one of the procession
			# in from off the edge of the world (Horseman's-Blade-kin)
			# You do not fire an arrow -- you hang a MOON-LANTERN in the air and
			# it drifts forward calling the procession in, whether or not it has
			# touched anything.
			# Two things were wrong and both were serious: the most expensive bow
			# in the game fired the SAME ordinary shaft as two Tier-3 Seekers,
			# and call_a_marcher only ran from on_projectile_hit -- so the crown
			# weapon's entire signature could not happen unless you connected,
			# straight against the rule that a soul fires on the CLICK.
			s = {"type": "moon_lantern", "damage": dmg, "speed": 420.0,
				"range": 620.0, "parade": true}
		"boulder":
			# THE MOUNTAIN THAT KNEELS alone: a rolling stone whose bite is its
			# own gathered pace (Staff-of-Earth-kin)
			s = {"type": "kneeling_stone", "damage": dmg, "speed": spd - 120.0, "range": 900.0}
		# ---- T7 VERBS (batch 1). The aftermath family: something STAYS where
		# the attack happened and keeps working.
		"afterlight":
			s = {"type": "lingering_arc", "damage": maxi(1, int(round(float(dmg) * 0.42)))}
		"ghostbows":
			# GHOST REPEATER (T6): the name was doing nothing. Now KEEPING FIRE
			# UP is the weapon -- every few shots another spectral bow fades in
			# beside you and looses with you, and they all fade the moment you
			# stop. A verb that rewards holding the trigger, which no other bow
			# in the roster asks for.
			s = {"type": "ghost_bows", "damage": dmg,
				"step": int(ex.get("step", 4)), "max": int(ex.get("max", 3)),
				"ghost_pct": 0.35}
		"daybreak":
			# DAYBREAK EDGE (T5): the swing does not reach the mark -- the
			# LIGHT does. Star-Wrath-kin, at a Legendary's intensity: three
			# stars, not a sky full of them. The verb is the identity; the
			# COUNT is the tier.
			s = {"type": "sky_star",
				"damage": maxi(1, int(round(float(dmg) * 0.55))),
				"count": int(ex.get("count", 3)), "aoe": float(ex.get("aoe", 58.0))}
		"anvil":
			s = {"type": "anvil_drop", "damage": dmg}
		"worldthorn":
			s = {"type": "ground_thorn", "damage": maxi(1, int(round(float(dmg) * 0.5)))}
		"sunspill":
			# keeps the mortar arc it always had; the SPILL is what is new
			s = {"type": "lob", "damage": dmg, "speed": spd, "range": rng,
				"aoe": float(ex.get("aoe", 90.0)), "rider": "spill"}
		# ---- T7 VERBS (batch 2) ----
		"reckoning":
			# small now, the bill 1.5s later (Nail-Gun-kin)
			s = {"type": "debt_arrow", "damage": maxi(1, int(round(float(dmg) * 0.3))),
				"speed": spd + 260.0, "range": rng}
		"cometchain":
			# the maul it always was, but the head is a comet and leaves a crater
			s = {"type": "chain_maul", "damage": dmg, "speed": spd + 40.0,
				"range": 260.0 + float(tier) * 18.0, "rider": "comet"}
		"stormflock":
			# every jab looses a bird that turns and dives
			s = {"type": "storm_flock", "damage": dmg, "count": int(ex.get("count", 3)), "range": rng}
		"dawnline":
			# a bar of first light laid down, then rising through them
			s = {"type": "dawn_line", "damage": maxi(1, int(round(float(dmg) * 0.85)))}
		# ---- T7 VERBS (batch 3): the remaining melee ----
		"worldedge":
			# a sliver at the hilt, a horizon by the time it arrives
			s = {"type": "world_edge", "damage": int(ex.get("p_damage", dmg)),
				"speed": spd - 150.0, "range": rng, "tint": ex.get("tint", [0.35, 0.95, 0.5])}
		"risingwheel":
			s = {"type": "rising_wheel", "damage": dmg, "speed": spd, "range": 150.0}
		"nova":
			# the lash it was, but the TURN is a detonation
			s = {"type": "lash", "damage": dmg, "speed": spd + 60.0,
				"range": 280.0 + float(tier) * 18.0, "rider": "nova"}
		"hush":
			# the lash it was, and where it turns it leaves a still place
			s = {"type": "lash", "damage": dmg, "speed": spd + 40.0,
				"range": 290.0 + float(tier) * 18.0, "rider": "hush"}
		# ---- T7 VERBS (batch 4) ----
		"commandment":
			# metronome: ordinary shots, and every ninth is a RULING
			s = {"type": "commandment", "damage": dmg, "speed": spd + 300.0,
				"range": rng + 200.0, "every": 9}
		# ---- tier 4 begins ----
		"duskrip":
			# DUSKRENDER tears the air and the tear STAYS -- a standing blade
			# of dark that keeps cutting whatever stands in it. Afterlight (T7)
			# does this at the top of the ladder; this is the same idea at a
			# quarter of the scale, which is what a tier-4 version of a good
			# idea is supposed to be.
			s = {"type": "dusk_rip",
				"damage": maxi(1, int(round(float(dmg) * 0.5)))}
		"sunderpoint":
			# SUNDER PIKE: one point goes in and TWO come out. It splits on
			# what it hits, and the halves keep going past it.
			s = {"type": "sunder_point",
				"damage": maxi(1, int(round(float(dmg) * 0.7))),
				"speed": spd + 160.0, "range": rng}
		"hummingbird":
			# HUMMINGBIRD: out, HOVER, back. It darts to the end of its reach,
			# thrums there for a beat taking whatever is close, and returns --
			# so the shot is worth most at a specific distance, and nothing
			# else in the roster asks the player to find a range and hold it.
			s = {"type": "hummingbird",
				"damage": maxi(1, int(round(float(dmg) * 0.8))),
				"speed": spd + 200.0, "range": rng - 60.0}
		"magmacrawl":
			# MAGMA WRIT does not burst. It POURS: what lands crawls off along
			# the floor and keeps going, so the danger walks away from where
			# you aimed it.
			s = {"type": "magma_crawl",
				"damage": maxi(1, int(round(float(dmg) * 0.75))),
				"speed": spd, "range": rng}
		# ---- tier 5, the last seven plain rungs ----
		"larksong":
			# THE LAST LARK: the shaft RISES instead of falling, and sings at
			# the top of its climb. Every other arcing thing in this roster is
			# a mortar coming down; this one is the only thing going UP.
			s = {"type": "lark_song", "damage": maxi(1, int(round(float(dmg) * 0.8))),
				"speed": spd, "range": rng}
		"walksummit":
			# SUMMIT THAT WALKS: a standing stone that simply WALKS, at one
			# speed, through whatever is in front of it. Not the boulder --
			# that one rolls and the hill decides where it goes. This one
			# ignores the ground entirely, which is what makes it a summit.
			s = {"type": "walking_summit",
				"damage": maxi(1, int(round(float(dmg) * 0.9)))}
		"lastlantern":
			# THE LAST LANTERN: hangs a light where you swung, and there is
			# only ever ONE. Lighting a new one snuffs the old, so the weapon
			# is really a question about where you want the room lit.
			s = {"type": "hung_lantern",
				"damage": maxi(1, int(round(float(dmg) * 0.55)))}
		"asphodelkiss":
			# ASPHODEL KISS: the poison does nothing at all, and then it does
			# everything. It sticks where it lands, swells for a beat, and
			# blooms once. A DELAY is the whole weapon.
			s = {"type": "kiss_mark",
				"damage": maxi(1, int(round(float(dmg) * 1.4))),
				"speed": spd + 120.0, "range": rng - 80.0}
		"moonreach":
			# MOONREACH strikes UPWARD. Every other spear in the roster owns
			# the lane; this one owns the sky above you, which is the half of
			# a side-scroller nothing else covers.
			s = {"type": "moon_reach",
				"damage": maxi(1, int(round(float(dmg) * 0.85)))}
		"wintermark":
			# WINTERMARK: the arrow marks everything it passes and winter
			# arrives LATER -- when the shaft finally expires, every mark
			# shatters at once, wherever they have wandered to.
			s = {"type": "winter_mark",
				"damage": maxi(1, int(round(float(dmg) * 0.7))),
				"speed": spd + 80.0, "range": rng + 120.0}
		"graniteway":
			# THE GRANITE WAY lays a ROAD: four stones that rise out of the
			# floor one after another, away from you. The Ladder climbs; this
			# one goes forward, and the sequence is the point of both.
			s = {"type": "granite_step",
				"damage": maxi(1, int(round(float(dmg) * 0.45))),
				"steps": int(ex.get("steps", 4))}
		"verdict":
			# FINAL VERDICT reads the TARGET, and is the deliberate mirror of
			# Grief Made Sharp, which reads the player. One gets crueller as
			# YOU fail; this one gets crueller as THEY do. A verdict is passed
			# on the accused, not on the judge.
			s = {"type": "verdict_point",
				"damage": maxi(1, int(round(float(dmg) * 0.55))),
				"speed": spd + 120.0, "range": rng - 40.0}
		"borderline":
			# BORDER OF THE REALM draws a LINE and the line is the weapon. Not
			# a point that stands (Worldspike) -- a span, standing across the
			# lane, hurting and shoving back whatever tries to cross it.
			s = {"type": "border_line",
				"damage": maxi(1, int(round(float(dmg) * 0.5))),
				"speed": spd + 60.0, "range": rng - 90.0}
		"cloudcount":
			# CLOUDCOUNTER accumulates instead of firing. Every cast puts one
			# more cloud over your head and does nothing else; on the third the
			# sky opens. An ACCUMULATOR, not a metronome -- the Twelfth Pillar
			# counts your swings whether you like it or not, this one you can
			# choose to bank and spend.
			s = {"type": "banked_cloud",
				"damage": maxi(1, int(round(float(dmg) * 0.8))),
				"clouds": int(ex.get("clouds", 3))}
		"requiem":
			# REQUIEM EDGE sings a DESCENDING chord: three cuts leave the blade
			# at once but at different speeds, so they string out into a
			# sequence, and each one FALLS and GROWS as it travels. Everything
			# else in the roster that throws several things throws them in a
			# FAN; this one throws them in a cadence.
			s = {"type": "requiem_note",
				"damage": maxi(1, int(round(float(dmg) * 0.42))), "notes": 3}
		"sorrowfang":
			# SORROWFANG's poison does not spread, it TRAVELS. The fang bites,
			# leaves its poison in the wound, and LEAPS to the next nearest
			# body -- three bites, each weaker than the last. The chain is the
			# weapon; the poison is only what it leaves behind.
			s = {"type": "sorrow_fang",
				"damage": maxi(1, int(round(float(dmg) * 0.62))),
				"speed": spd + 240.0, "range": rng,
				"bites": int(ex.get("bites", 3))}
		"griefsharp":
			# GRIEF MADE SHARP reads the PLAYER, which nothing else in 350 does.
			# The worse you are doing, the more of it comes off the blade: one
			# shard at full health, four when you are nearly gone. Grief is not
			# a stat here, it is a state you are in.
			s = {"type": "grief_shard",
				"damage": maxi(1, int(round(float(dmg) * 0.30))), "max_shards": 4}
		"worldstake":
			# WORLDSPIKE does not cut, it PINS. The thrust drives a stake
			# through and the stake stays in the ground, holding what it caught
			# and hurting whatever else wanders onto it.
			s = {"type": "world_stake",
				"damage": maxi(1, int(round(float(dmg) * 0.55))),
				"speed": spd + 180.0, "range": rng - 60.0}
		# ---- the three plain STAFFS of tier 6, given their names back ----
		"twelfthpillar":
			# A METRONOME the player can count, like the Ninth Commandment --
			# but on a staff and on a longer beat, so the two never feel like
			# the same trick. Eleven ordinary blows, and the twelfth stands a
			# column of daylight where you pointed.
			# 0.71 because the column stands on top of the ordinary blow rather
			# than replacing it -- the twelfth swing is a swing AND a pillar.
			s = {"type": "twelfth_pillar",
				"damage": maxi(1, int(round(float(dmg) * 0.71))), "every": 12}
		"skyladder":
			# LADDER TO NOWHERE: not one bar of light but THREE, stacked one
			# above the other and climbing. It reuses the Dawn Chorus bar and
			# is not the Dawn Chorus: one rung rising is a sunrise, three rungs
			# stacked is a ladder, and the difference is the whole weapon.
			s = {"type": "sky_ladder",
				"damage": maxi(1, int(round(float(dmg) * 0.24))),
				"rungs": int(ex.get("rungs", 3))}
		"stillmountain":
			# THE STILL MOUNTAIN asks the player to STOP. Stand still a beat
			# and a mountain comes down on your next blow. The only weapon in
			# the roster that pays you for not moving, which in a side-scroller
			# full of dodging is a real decision rather than a stat.
			s = {"type": "still_mountain",
				"damage": maxi(1, int(round(float(dmg) * 1.11))), "still": 1.5}
		"skypillar":
			s = {"type": "sky_pillar", "damage": maxi(1, int(round(float(dmg) * 0.55)))}
		"finaldebt":
			# the ricochet it was; now every body it touches is BOOKED
			s = {"type": "ricochet", "damage": dmg, "speed": spd + 120.0,
				"range": rng, "bounces": int(ex.get("bounces", 5)), "rider": "debt"}
		# ---- T7 VERBS (batch 5): the wands and the bent staff ----
		"riftburst":
			s = {"type": "rift_bloom", "damage": dmg, "range": rng}
		"shardregent":
			s = {"type": "regent_shard", "damage": maxi(1, int(round(float(dmg) * 0.42))),
				"count": int(ex.get("shards", 5)), "speed": spd + 160.0, "range": rng}
		"bentheaven":
			s = {"type": "bent_ray", "damage": dmg, "speed": spd + 60.0, "range": rng + 120.0}
		# ---- T7 VERBS (batch 6): the tier's last four ----
		"heavenstring":
			s = {"type": "tether_arrow", "damage": dmg, "speed": spd + 240.0, "range": rng}
		"choirstring":
			s = {"type": "choir_note", "damage": maxi(1, int(round(float(dmg) * 0.5))),
				"count": int(ex.get("count", 3)), "speed": spd + 120.0, "range": rng}
		"horizonreach":
			# HORIZON PIKE (T6): the thrust does not stop at arm's length. The
			# POINT keeps going -- a hairline of light out to the edge of
			# sight, taking everything standing in it.
			# NOTE the behavior key: `horizonpike` is already taken, by THE
			# KINDLY END. The weapon whose name matches that key is not the
			# weapon that owns it, which is a trap this roster has sprung once
			# already -- do not "fix" it by renaming either one.
			s = {"type": "horizon_line",
				"damage": maxi(1, int(round(float(dmg) * 0.55))),
				"speed": spd + 520.0, "range": rng + 460.0}
		"heavenpoint":
			s = {"type": "piercing_point", "damage": dmg, "speed": spd + 340.0, "range": rng + 90.0}
		"asphodel":
			s = {"type": "asphodel_post", "damage": maxi(1, int(round(float(dmg) * 0.9)))}
		# ---- T6 batch 1 ----
		"hushfall":
			# a CLEAVE: the sound comes back to where the blade actually was,
			# not to bow range (rng * 0.55 put it 324px away, off the fight)
			s = {"type": "late_thunder", "damage": dmg, "reach": 78.0}
		"eclipse":
			s = {"type": "eclipse_disc", "damage": dmg,
				"speed": spd + 260.0, "range": rng}
		"cometfall":
			s = {"type": "comet", "damage": dmg, "speed": spd - 150.0,
				"range": rng + 20.0, "lift": 330.0}
		"watchfire":
			s = {"type": "watch_fire", "damage": maxi(1, int(round(float(dmg) * 0.85)))}
		# ---- T6 batch 2 ----
		"horizonpike":
			s = {"type": "stage_pike", "damage": dmg}
		"deluge":
			s = {"type": "flood_wave", "damage": maxi(1, int(round(float(dmg) * 0.8))),
				"speed": spd - 210.0, "range": rng}
		"lodestar":
			s = {"type": "lodestar", "damage": maxi(1, int(round(float(dmg) * 0.7))),
				"speed": spd + 40.0, "range": rng * 0.6}
		"secondmoon":
			s = {"type": "moon_orbit", "damage": maxi(1, int(round(float(dmg) * 0.42)))}
		"shatterhymn":
			s = {"type": "glass_note", "damage": dmg, "speed": spd - 40.0, "range": rng}
		"longtongue":
			s = {"type": "long_tongue", "damage": maxi(1, int(round(float(dmg) * 0.8))),
				"speed": spd - 130.0, "range": rng * 0.42}
		# ---- T6 batch 3 ----
		"anviltoll":
			s = {"type": "anvil_toll", "damage": dmg, "reach": 82.0}
		"horizonrend":
			s = {"type": "rend_half", "damage": maxi(1, int(round(float(dmg) * 0.72))),
				"speed": spd - 40.0, "range": rng * 0.75}
		"silentchoir":
			s = {"type": "silent_note", "damage": dmg, "speed": spd + 220.0, "range": rng}
		"sunpiece":
			s = {"type": "sun_piece", "damage": dmg, "speed": spd - 190.0,
				"range": rng * 0.5, "lift": 250.0}
		"permafrost":
			s = {"type": "ice_sheet", "damage": maxi(1, int(round(float(dmg) * 0.45)))}
		"novaburst":
			s = {"type": "nova_seed", "damage": maxi(1, int(round(float(dmg) * 0.72))),
				"speed": spd, "range": rng}
		# ---- T6 batch 4: the last ten ----
		"hollowwheel":
			s = {"type": "hollow_wheel", "damage": maxi(1, int(round(float(dmg) * 0.75)))}
		"direportent":
			s = {"type": "portent", "damage": dmg, "speed": spd + 60.0, "range": rng}
		"lastcourier":
			s = {"type": "courier_route", "damage": maxi(1, int(round(float(dmg) * 0.62))),
				"speed": spd - 60.0, "range": rng}
		"griffinvolley":
			s = {"type": "stoop_arrow", "damage": maxi(1, int(round(float(dmg) * 0.8))),
				"count": 3, "speed": spd - 60.0, "range": rng + 160.0}
		"meteorquill":
			s = {"type": "quill_fall", "damage": maxi(1, int(round(float(dmg) * 0.85))),
				"count": 5, "speed": spd - 210.0, "range": rng, "lift": 400.0}
		"ashherd":
			s = {"type": "ash_cloud", "damage": maxi(1, int(round(float(dmg) * 0.55))),
				"count": 3}
		"cindershelf":
			s = {"type": "cinder_shelf", "damage": maxi(1, int(round(float(dmg) * 0.35)))}
		"griefcollect":
			s = {"type": "grief_return", "damage": maxi(1, int(round(float(dmg) * 0.65))),
				"speed": spd - 90.0, "range": rng}
		"nightlash":
			s = {"type": "night_lash", "damage": maxi(1, int(round(float(dmg) * 0.7))),
				"speed": spd - 150.0, "range": rng * 0.4}
		"middaysun":
			s = {"type": "noon_shaft", "damage": maxi(1, int(round(float(dmg) * 0.8))),
				"count": 7, "speed": spd + 140.0, "range": rng}
		# ---- T5 batch 1 ----
		"seawall":
			s = {"type": "sea_wall", "damage": maxi(1, int(round(float(dmg) * 0.8))),
				"speed": spd - 300.0}
		"serpentsermon":
			s = {"type": "serpent_coil", "damage": dmg,
				"speed": spd - 180.0, "range": rng * 0.38}
		"twinburst":
			s = {"type": "twin_bolt", "damage": maxi(1, int(round(float(dmg) * 0.7))),
				"speed": spd - 70.0, "range": rng}
		"deepbeacon":
			s = {"type": "deep_beacon", "damage": maxi(1, int(round(float(dmg) * 0.9)))}
		"starfall":
			s = {"type": "star_fall", "damage": maxi(1, int(round(float(dmg) * 0.75))),
				"count": 3, "speed": spd - 250.0, "range": rng, "lift": 430.0}
		"worldtoll":
			s = {"type": "under_toll", "damage": maxi(1, int(round(float(dmg) * 0.85))),
				"speed": spd - 260.0, "range": rng * 0.55}
		# ---- T5 batch 2 ----
		"glacierwrit":
			s = {"type": "ice_floe", "damage": maxi(1, int(round(float(dmg) * 0.6))),
				"speed": spd - 330.0, "range": rng * 0.62}
		"owlremembers":
			s = {"type": "owl_pass", "damage": maxi(1, int(round(float(dmg) * 0.6))),
				"speed": spd - 120.0, "range": rng}
		"quillrain":
			s = {"type": "rain_quill", "damage": dmg, "count": 2,
				"speed": spd - 240.0, "range": rng, "lift": 210.0}
		"kingsransom":
			s = {"type": "ransom_seal", "damage": maxi(1, int(round(float(dmg) * 0.7))),
				"speed": spd, "range": rng}
		"gallows":
			s = {"type": "gallows_head", "damage": dmg, "range": rng * 0.5}
		"pilgrimscourge":
			s = {"type": "pilgrim_lash", "damage": maxi(1, int(round(float(dmg) * 0.85))),
				"speed": spd - 150.0, "range": rng * 0.4}
		# ---- T5 batch 3 ----
		"quietwheel":
			s = {"type": "quiet_wheel", "damage": dmg, "speed": spd - 280.0}
		"midwinterwheel":
			s = {"type": "winter_wheel", "damage": maxi(1, int(round(float(dmg) * 0.8)))}
		"skyquills":
			s = {"type": "sky_quill", "damage": maxi(1, int(round(float(dmg) * 0.9))),
				"count": 5}
		"eventide":
			s = {"type": "eventide", "damage": maxi(1, int(round(float(dmg) * 0.85))),
				"count": 3, "speed": spd - 90.0, "range": rng}
		"tomeofrains":
			s = {"type": "rain_cloud", "damage": maxi(1, int(round(float(dmg) * 0.8)))}
		"wardenwatch":
			s = {"type": "warden_post", "damage": maxi(1, int(round(float(dmg) * 1.35)))}
		# ---- THE SUMMONER (batch 1: the three starters) ----
		"minion":
			s = {"type": "minion", "damage": dmg,
				"m_kind": str(ex.get("m_kind", "mudling")),
				"m_gap": float(ex.get("m_gap", 1.8)),
				"m_style": str(ex.get("m_style", "")),
				# m_solo: a recast EMPOWERS the one you have instead of adding
				# a second. Keeper of One, the Growing Hunt and the Procession
				# are all "one thing that gets bigger", each in its own way.
				"m_solo": bool(ex.get("m_solo", false)),
				"mana": 10.0 + 3.0 * float(tier)}
		"whipcrack":
			# REACH CLIMBS WITH THE TIER (Kaleidoscope law, 2026-07-30): the
			# reference whip reaches ~6.5 player-heights and ours were all
			# pinned at 2.75 regardless of rung, which is a large part of why
			# the whip family reads as the weakest thing at every tier. The
			# per-weapon `reach` extra still stacks on top.
			s = {"type": "whipcrack", "damage": dmg, "tier": tier,
				"reach": float(ex.get("reach", 0.0)) + float(tier - 1) * 20.0,
				"tag_dmg": float(ex.get("tag_dmg", 0.0)),
				"tag_crit": float(ex.get("tag_crit", 0.0)),
				"tag_dur": float(ex.get("tag_dur", 0.0)),
				"tag_fx": str(ex.get("tag_fx", "")),
				"frenzy": float(ex.get("frenzy", 0.0))}
		"post":
			s = {"type": "post", "damage": dmg,
				"s_kind": str(ex.get("s_kind", "watchstone")),
				"p_gap": float(ex.get("p_gap", 1.1)),
				"mana": 14.0 + 3.0 * float(tier)}
		# ---- T4 batch 1 ----
		"rowsickle":
			# thrown FAST and travelling SLOW, so several are always in the air
			s = {"type": "sickle_glide", "damage": maxi(1, int(round(float(dmg) * 0.85))),
				"speed": spd - 330.0, "range": rng * 1.5}
		"howlpiece":
			s = {"type": "howl_crescent", "damage": maxi(1, int(round(float(dmg) * 0.85))),
				"speed": spd - 120.0, "range": rng * 0.8}
		"winterwheel":
			s = {"type": "frost_roller", "damage": dmg,
				"speed": spd - 260.0, "range": rng * 0.7, "status": "slow_w"}
		"reaperrebuke":
			s = {"type": "reaper_return", "damage": maxi(1, int(round(float(dmg) * 0.7))),
				"speed": spd - 90.0, "range": rng}
		"prismbreak":
			s = {"type": "prism_bolt", "damage": dmg, "speed": spd, "range": rng}
		"cometflail":
			s = {"type": "comet_chain", "damage": dmg, "range": rng * 0.55}
		"falconoath":
			s = {"type": "oath_arrow", "damage": maxi(1, int(round(float(dmg) * 1.15))),
				"speed": spd + 200.0, "range": rng}
		# ---- T4 batch 2 ----
		"gloamlash":
			s = {"type": "gloam_fork", "damage": maxi(1, int(round(float(dmg) * 0.8))),
				"count": 2, "speed": spd - 170.0, "range": rng * 0.4}
		"owlwheel":
			s = {"type": "owl_wheel", "damage": maxi(1, int(round(float(dmg) * 0.85)))}
		"riverrender":
			s = {"type": "river_cut", "damage": maxi(1, int(round(float(dmg) * 0.9))),
				"speed": spd - 200.0, "range": rng * 0.6}
		"smokelash":
			s = {"type": "smoke_pall", "damage": maxi(1, int(round(float(dmg) * 0.55)))}
		"driftwheel":
			s = {"type": "drift_wheel", "damage": maxi(1, int(round(float(dmg) * 0.7))),
				"speed": spd - 300.0}
		# ---- T4 batch 3: the last ten ----
		"nightbolt":
			s = {"type": "night_bolt", "damage": maxi(1, int(round(float(dmg) * 1.2))),
				"speed": spd + 160.0, "range": rng}
		"wispwarden":
			s = {"type": "wisp_post", "damage": maxi(1, int(round(float(dmg) * 0.9)))}
		"candlekeeper":
			s = {"type": "candle_row", "damage": maxi(1, int(round(float(dmg) * 0.9)))}
		"covenledger":
			s = {"type": "coven_ring", "damage": maxi(1, int(round(float(dmg) * 0.75)))}
		"gloamburst":
			s = {"type": "gloam_burst", "damage": dmg, "speed": spd, "range": rng}
		"howlbolt":
			s = {"type": "howl_bolt", "damage": maxi(1, int(round(float(dmg) * 0.75))),
				"bounces": 4, "speed": spd + 40.0, "range": rng}
		"deepdebt":
			s = {"type": "debt_deep", "damage": maxi(1, int(round(float(dmg) * 0.7))),
				"bounces": 4, "speed": spd - 40.0, "range": rng}
		"huntword":
			s = {"type": "hunt_word", "damage": maxi(1, int(round(float(dmg) * 0.85))),
				"count": 2, "speed": spd - 40.0, "range": rng + 140.0}
		"stormdebt":
			s = {"type": "storm_debt", "damage": maxi(1, int(round(float(dmg) * 0.8))),
				"speed": spd, "range": rng}
		# ---- T5 batch 4: the last eleven (incl. the OMEN TRIO) ----
		"omenseek":
			s = {"type": "omen_eye", "damage": maxi(1, int(round(float(dmg) * 0.5))),
				"speed": spd - 330.0}
		"ironomen":
			s = {"type": "omen_sigil", "damage": maxi(1, int(round(float(dmg) * 0.8))),
				"bounces": 4, "speed": spd - 60.0, "range": rng}
		"thirdomen":
			s = {"type": "omen_sigil", "damage": maxi(1, int(round(float(dmg) * 0.6))),
				"count": 3, "third": true, "speed": spd, "range": rng}
		"stormherd":
			# NOT type "marcher": that name has no dispatch of its own -- Night
			# Parade calls it from a HIT hook, so a weapon declaring it would
			# have fired nothing at all.
			s = {"type": "storm_beast", "damage": maxi(1, int(round(float(dmg) * 0.75))),
				"count": 4}
		"kestrelcourt":
			s = {"type": "kestrel", "damage": maxi(1, int(round(float(dmg) * 0.9))),
				"count": 4, "speed": spd - 130.0, "range": rng + 200.0}
		"thunderhead":
			s = {"type": "thunderhead", "damage": maxi(1, int(round(float(dmg) * 0.62)))}
		"midnightpost":
			s = {"type": "midnight_post", "damage": maxi(1, int(round(float(dmg) * 0.9)))}
		"sirensong":
			s = {"type": "siren_song", "damage": maxi(1, int(round(float(dmg) * 0.85)))}
		"starsplinter":
			s = {"type": "star_splinter", "damage": maxi(1, int(round(float(dmg) * 0.55))),
				"count": 8}
		"emberhymn":
			s = {"type": "ember_hymn", "damage": maxi(1, int(round(float(dmg) * 0.6)))}
		"saintsreward":
			s = {"type": "saint_halo", "damage": maxi(1, int(round(float(dmg) * 0.6)))}
		# ---- THE MONARCH ELEVEN: power in the VERB, not in stat riders ----
		"patientknife":
			s = {"type": "patient_storm", "damage": maxi(1, int(round(float(dmg) * 0.8)))}
		"kingdomturning":
			s = {"type": "kingdom_ring", "damage": maxi(1, int(round(float(dmg) * 0.55)))}
		"rumor":
			s = {"type": "rumor_bolt", "damage": maxi(1, int(round(float(dmg) * 0.62))),
				"speed": spd, "range": rng}
		"skymeasure":
			s = {"type": "sky_measure", "damage": maxi(1, int(round(float(dmg) * 0.7)))}
		"unbentcolumn":
			s = {"type": "colonnade", "damage": maxi(1, int(round(float(dmg) * 0.72)))}
		"choirofone":
			s = {"type": "harmonic", "damage": dmg, "speed": spd + 180.0, "range": rng}
		"thronestrings":
			s = {"type": "harp_string", "damage": maxi(1, int(round(float(dmg) * 0.62)))}
		"worldsgrief":
			s = {"type": "grief_tear", "damage": maxi(1, int(round(float(dmg) * 0.4))),
				"count": 12, "speed": spd - 140.0, "range": rng}
		"skycharges":
			s = {"type": "sky_charge", "damage": maxi(1, int(round(float(dmg) * 0.85)))}
		"souls":
			# FLOOD OF SOULS had NO branch here at all -- it fell through with an
			# empty special, so a Monarch wand cast an ordinary bolt and nothing
			# else, and the audit skipped it because a weapon with no special is
			# not something the dispatch audit can check. Second weapon this
			# batch found dead the same way (see storm_debt). Seven souls now,
			# each bending toward whatever is nearest.
			s = {"type": "soul_stream", "count": 7,
				"damage": maxi(1, int(round(float(dmg) * 0.55))),
				"speed": spd, "range": rng}
		"worldcut":
			s = {"type": "world_cut", "damage": dmg}
		"deepcourt":
			s = {"type": "companion", "kind": "wisp", "count": 3,
				"damage": maxi(1, int(round(float(dmg) * 0.9)))}
		"debtmark":
			s = {"type": "debt_mark", "damage": dmg, "speed": spd + 60.0, "range": rng}
		"cinderdrag":
			s = {"type": "cinder_drag", "damage": dmg, "range": rng + 40.0}
		"staff":
			# TEN STAFFS, ONE EXTEND, TEN SLAMS. staff_extend is the staff's
			# CLASS identity -- rhythm draws it longer, the fourth blow slams --
			# exactly as whipcrack is the whip's, and taking it away from nine of
			# them to make them "different" would have made them stop being
			# staffs. So they differ where the whips do: in the RIDER. What the
			# slam DOES is the weapon; the extend is the family.
			s = {"type": "staff_extend", "slam_fx": str(ex.get("slam_fx", ""))}
	if not st.is_empty():
		if s.is_empty():
			s = {"status": st}   # the typeless rider (plain swing/shot + status)
		else:
			s["status"] = st
	if bool(ex.get("pierce", false)):
		s["pierce"] = true
	# THE LADDER WEARS ITS SIZE (verb sweep 2026-07-29): a projectile special
	# grows with its tier -- visual AND hitbox together (weapon_projectile
	# girth) -- so a crown cluster is visibly a crown cluster before a single
	# number appears. Grade multiplies ON TOP for wand casts (the two axes
	# stack: what the weapon IS times how well this one was made).
	if s.has("type"):
		s["girth"] = minf(1.5, 0.9 + float(tier) * 0.08)
	# Terra standard: a crescent-thrower may paint its beam in the blade's own
	# colour (weapon_projectile beam_tint) instead of the stock wind-blue
	if ex.has("tint") and not s.is_empty():
		s["tint"] = ex["tint"]
	# THE WEAPON'S OWN SOUL (WeaponFx 2026-07-28): a row's extras carry its
	# unique fx, riding special.fx into the def the engine reads. A typeless
	# special (plain arc/shot + fx) falls through to the ordinary swing
	# exactly like the typeless status rider above it always has.
	if ex.has("fx"):
		s["fx"] = ex["fx"]
	# flagship riders (polish 2026-07-28): one NAMED bespoke behavior per
	# crown weapon, read by weapon_projectile / player / storm_cloud
	if ex.has("rider"):
		s["rider"] = str(ex["rider"])
	# VERB FORCE (2026-07-30). GRADE_PASSIVES is gone -- a weapon no longer
	# hands you +20% melee, +20% bow, +20% wand, +Max HP and +Gold for the
	# crime of being high-grade. The dev's instruction was to "compensate with
	# the effect being stronger on every weapon", so the power that used to
	# leak sideways into your whole character now goes where it belongs: into
	# this weapon's own verb. A Monarch weapon's effect lands 60% harder than a
	# Common one's, and buffs nothing you are not currently swinging.
	#
	# Applied LAST so it catches every branch above, and only to the SPECIAL --
	# the plain swing damage is the row's own number and stays untouched, or
	# the tier ladder would be scaled twice.
	var vf: float = verb_force(tier)
	if vf != 1.0:
		for k in s.keys():
			var ks := str(k)
			if ks == "damage" or ks.ends_with("_dmg") or ks.ends_with("_damage"):
				var raw = s[k]
				if raw is int:
					s[k] = maxi(1, int(round(float(raw) * vf)))
				elif raw is float:
					s[k] = float(raw) * vf
	return s

# How much harder a weapon's EFFECT hits, by tier. This replaces the passive
# stat bundle that every grade used to grant; see GRADE_PASSIVES in inventory.
static func verb_force(tier: int) -> float:
	return 1.0 + float(clampi(tier, 1, 8) - 1) * 0.085

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
	# the lob five (2026-07-31): every mortar in the game now lands differently
	"cinder":  "The ARC is the weapon: the shell sheds heat the whole way over, singeing and lighting everything it passes. Then it lands.",
	"lead":    "Judgement COMES DOWN. The higher you throw it, the harder it lands -- the fall itself is the bill, up to half again.",
	"fuse":    "It lands. It does not answer yet. The charge sits blinking while they stand over it, and the answer is half again as wide.",
	"bog":     "The blast is just how the MUD gets there: a slick that barely hurts and will not let go. What stands in it fights at half speed.",
	"kiss":    "It STICKS to the first body it touches and goes off ON them, half a second later. There is no walking away from a kiss.",
}

static func _desc_for(behavior: String, ex: Dictionary) -> String:
	match behavior:
		"cleave":     return "Heavy enough to cleave through EVERY enemy in the arc."
		"crescent":   return "Every swing also hurls a flying crescent down the lane."
		"reedcast":   return "Reeds are LIGHT. They go further and faster than anything this cheap has a right to."
		"stormprong": return "The prongs are CHARGED. Where the volley lands, the sky answers a beat later."
		"galeprong":  return "A gale does not aim. Four prongs across a wide arc, and every one of them SHOVES."
		"gullwing":   return "Gulls BANK. The prongs leave wide and curve back in, meeting at a point ahead of you -- the opposite of a fan."
		"reedsong":   return "A song is a sequence, not a chord. The shafts leave one after another, on a beat."
		"hawkline":   return "FORMATION. Four shafts abreast with barely a hand between them, holding the line and going through whatever they meet."
		"marrowsplit": return "It splits. Three shafts go out, and a beat later each of them is two."
		"ferrytwin":  return "Makes the crossing TWICE. One shaft goes, and a second retraces its exact line a beat behind it -- there, and back."
		"twinnock":   return "Two arrows nocked as one. It leaves the string as a SINGLE shaft and comes apart into two halfway down the lane."
		"choirpoints": return "A choir sings in HARMONY, so these do not spread -- three lines CONVERGE on one spot ahead of you, and whatever stands there takes all three."
		"paleflight": return "Ghost shafts. They pass THROUGH what they hit instead of stopping in it, and pay for the privilege: each one lands softer."
		"finchstorm": return "Finches do not fly straight. Three shafts FLIT -- each on its own wandering line, drifting toward whatever it passes near."
		"larkstorm":  return "Not a fan. A WIDE FRONT -- %d larks thrown across forty-six degrees of sky, covering a room instead of a lane." % int(ex.get("count", 3))
		"paleseek":   return "Ignores the healthy. Bends, unhurried, toward whatever is already WOUNDED -- and comes apart on landing into two more that hunt the same way."
		"haleseek":   return "Flies dead straight, then takes exactly ONE hard turn onto the BIGGEST thing in the room and never turns again. It pierces, and it does not reconsider."
		"lob_a", "lob": return "Sails a mortar arc and BLOSSOMS where it lands."
		"bolt":       return "A hard, fast bolt of force."
		"fire":       return "Detonates on impact, scorching everything close."
		"frost":      return "A razor sliver that skewers everyone along its line."
		"ricochet":   return "Leaps foe to foe up to %d times, each hit a little lighter." % int(ex.get("bounces", 3))
		"ratterdart": return "A ratter FINISHES things. Its leaps ignore the healthy and go straight for whatever is already hurt."
		"hookbill":   return "A hook GATHERS. Every body it leaves is dragged a step toward where it was struck, so a long chain pulls the room into a knot."
		"finchbolt":  return "A finch keeps finding fresh birds. Striking something UNTOUCHED refunds the leap, so a full room carries it further than a hurt one."
		"tithegather": return "It COLLECTS. Every bounce mints a coin -- the only thing you own that pays you by the length of the chain."
		"badnews":    return "News travels quietly and lands hard. The leaps are ordinary; the LAST one, the delivery, hits for two and a half times."
		"cluster":    return "Bursts on its first mark into a fan of %d biting shards." % int(ex.get("shards", 5))
		"tome":       return "Reads a stormlet down over the aimed ground for a few seconds."
		"sentry":     return "Plants ONE watching totem that snipes on its own clock."
		"orbiter":    return "Flies out, SPINS a cutting wheel at the far point, then threads home."
		"chain_maul": return "WHIRLS about you gathering speed, hurls itself as a comet, then hauls back on its chain."
		"lash":       return "A weaving ribbon that rakes its lane on BOTH passes."
		"zenith":     return "Every sword you have ever carried is in the air AT ONCE -- nine ancestor blades swirling out around you and back in, cutting everything the whole time. It does not throw a weapon. It becomes a storm."
		"court":      return "Every swing calls the COURT: %d shades of the people you brought home appear at your side, each carrying a different ancestor blade, and all of them sweep at once." % int(ex.get("count", 4))
		"edict":      return "The law REACHES: a jointed arm of light unfolds the length of the hall, cutting everything along it and blooming where it touches -- and stone does not stop a sentence."
		"heavenstring": return "Every shaft trails a THREAD, and when it lands the thread goes taut: what you hit comes to you, whether it meant to or not."
		"choirstring": return "Each shaft that lands plants a NOTE, humming where it stuck. Fill a room with notes and the room sings -- and singing hurts."
		"duskrip":     return "Tears the air, and the TEAR STAYS -- a standing sliver of dark that keeps cutting whatever is careless enough to stand in it."
		"sunderpoint": return "One point goes in and TWO come out. It splits on whatever it strikes and the halves carry on past, so the body you hit is rarely the last one."
		"hummingbird": return "Out, HOVER, back. The shaft darts to the end of its reach, thrums there taking whatever is close, and returns -- so there is a distance at which this bow is twice the weapon it is anywhere else."
		"magmacrawl":  return "It does not burst. It POURS -- what lands crawls off along the floor and keeps going, so the danger walks away from where you aimed it."
		"larksong":    return "The shaft CLIMBS instead of falling, and at the top of its climb it sings -- a ring of song that takes everything near it. The only thing in the armoury that goes up."
		"walksummit":  return "A standing stone that WALKS. One speed, no hurry, straight through whatever is in front of it. The ground has no say in where it goes."
		"lastlantern": return "Hangs a light where you swung, and burns whatever comes near it. There is only ever ONE -- lighting a new one snuffs the old, so the question is always where you want the room lit."
		"asphodelkiss": return "The poison does nothing. Then it does everything. It sticks where it lands, swells for a beat, and blooms once -- and the beat is the weapon."
		"moonreach":   return "It strikes UPWARD. Everything else you carry owns the lane in front of you; this owns the sky above you, and things in the air have got used to being safe."
		"wintermark":  return "The shaft marks everything it passes and keeps going. Winter arrives LATER: when the arrow is spent, every mark shatters at once, wherever they have wandered to."
		"graniteway":  return "Lays a ROAD -- %d stones rising out of the floor one after another, away from you. Standing on the way is not advised." % int(ex.get("steps", 4))
		"verdict":     return "It reads the ACCUSED. The thrust lands harder the worse shape they are already in -- a formality against the healthy, and something else entirely against the nearly-finished."
		"borderline":  return "Draws a LINE across the lane and leaves it there. Whatever tries to cross is hurt and shoved back to the side it came from. The realm ends here."
		"cloudcount":  return "Casting does nothing. Casting AGAIN does nothing. On the third the sky you have been gathering opens over whatever you are pointing at."
		"requiem":     return "Three cuts leave the blade at once and arrive one after another, each one falling lower and growing louder than the last. Not a fan. A CADENCE."
		"sorrowfang":  return "The poison does not spread -- it TRAVELS. The fang bites, leaves its sorrow in the wound, and leaps to the next nearest body. Three bites, each weaker, none of them where you aimed."
		"griefsharp":  return "It knows how badly you are doing. Every swing throws shards of the grief off the edge -- ONE while you are whole, and as many as four when you are nearly gone."
		"worldstake":  return "It does not cut. It PINS: the thrust drives a stake clean through and leaves it standing in the ground, holding what it caught and waiting for whatever wanders onto it next."
		"twelfthpillar": return "Count. Eleven blows are only blows -- and on the TWELFTH a column of daylight stands up where you pointed and keeps standing."
		"skyladder":   return "Lays a rung of light, and then another above it, and another. Three of them, climbing. It goes nowhere and everything caught between them is caught between them."
		"stillmountain": return "STOP MOVING. Stand a moment and the next blow brings a mountain down with it. Keep running and it is only a staff."
		"horizonreach": return "The thrust does not stop at arm's length. The point keeps GOING -- a hairline of light drawn out to the edge of sight, and everything standing in it is standing in the line."
		"heavenpoint": return "One lance, and everything standing in the line takes the SAME wound. It does not weaken for the second body, or the third."
		"asphodel":    return "Plants a pale marker in the ground. It stands there on its own and keeps sending wisps out after whatever is nearest, long after you have moved on."
		"hushfall":    return "The blow lands in SILENCE. The sound of it arrives a moment later, from where you struck, and the sound is the heavier half."
		"eclipse":     return "The wheel rolls out and goes DARK, and the shadow it throws is the weapon -- a long band of night that cuts everything standing in it."
		"cometfall":   return "Lobs high and comes down as a COMET, cratering where it lands and leaving the ground burning for whatever walks in next."
		"nightbolt":   return "It goes DARK halfway across. You see it leave and you see it arrive, and nothing in between can read where it will be."
		"wispwarden":  return "A warden post that keeps three slow wisps about it, sending them out one at a time at whatever comes near."
		"candlekeeper": return "Three candles stood in a row. They burn quietly and send their light out after anything that walks past."
		"covenledger": return "Draws a RING of candles on the floor and holds the circle. Everything standing inside the ring is on the ledger."
		"gloamburst":  return "It breaks into six dusk motes that hang a moment and then come DOWN, each one finding somebody."
		"howlbolt":    return "It HOWLS at every bounce, and the howl is wider than the bolt."
		"deepdebt":    return "Every body it touches is BOOKED -- a little of what is owed, ticking, and coming due whether the bolt is still there or not."
		"huntword":    return "The word goes out and TWO of them answer, each stooping on a different body."
		"stormdebt":   return "One bolt, and the storm settles the account behind it -- two more beats going off where you already were."
		"gloamlash":   return "The whip FORKS at the tip -- two tines bowing apart, so one crack covers two lanes at once."
		"owlwheel":    return "It does not orbit. It WATCHES -- hanging over the fight, drifting to whatever is nearest, and blinking once every time it strikes."
		"riverrender": return "The cut RUNS along the floor like water and SWELLS the further it goes."
		"smokelash":   return "Where the lash cracks it leaves a PALL -- ash hanging in the air that keeps working on anything standing in it."
		"driftwheel":  return "Thrown once and never returned: it DRIFTS on, turning slowly toward whatever is nearest, cutting the whole way."
		"minion":      return "Calls a bond into the world and it STAYS -- through weapon swaps, through floors, for as long as the scepter is in your bag."
		"whipcrack":   return "A fast thin lash that barely stings. What it does is TAG: the one it marks is the one your whole pack turns to look at."
		"post":        return "Plants a guardian where you stand and LEAVES it there -- not for a while, but until you plant another."
		"rowsickle":   return "A long pale scythe thrown FLAT down the row. It travels slowly and passes through everyone without slowing, and you throw them faster than they land -- three or four are always in the air."
		"howlpiece":   return "The crescent HOWLS as it flies -- every beat it throws a ring out across its own path, so the lane it cuts is far wider than the blade."
		"winterwheel": return "It ROLLS, and the floor freezes behind it. The lane it took stays cold long after the wheel is gone."
		"reaperrebuke": return "The scythe takes a round of the room and comes back HEAVIER for every visit, then returns to your hand."
		"prismbreak":  return "It goes in white and comes out in THREE COLOURS, each one going its own way."
		"cometflail":  return "The head is a comet on a chain, and the fire it sheds on the way out stays burning on the floor."
		"falconoath":  return "The shaft keeps the promise: where it lands, YOU ARE. You arrive at their shoulder before they hear it strike."
		"omenseek":    return "It drifts through the room and SEES them, one after another, and the seeing is the whole cost -- when the eye closes, everything it looked at pays at once."
		"ironomen":    return "The sigil bounces from body to body, and every place it touches down it leaves IRON standing in the ground behind it."
		"thirdomen":   return "Omens come in threes. The first two are warnings. The THIRD is not."
		"stormherd":   return "Each jab looses a beast of storm that runs on ahead of you. Enough jabs and there is a HERD out there trampling."
		"kestrelcourt": return "Four kestrels go up and HOLD, hanging on the air, and then they stoop one after another -- not together. A court takes its turns."
		"thunderhead": return "Lobs a cloud that parks overhead and throws lightning down four times before it is spent."
		"midnightpost": return "Plants a post that HAULS the dark in around it, tighter and tighter, and then throws all of it back out in eight directions."
		"sirensong":   return "It sings, and they COME -- walking toward the book whether or not they meant to. Then the book shuts."
		"starsplinter": return "The star breaks into eight splinters that fly out and HANG there a moment, and then all eight come back through the middle at once."
		"emberhymn":   return "Every verse without a pause builds the fire HIGHER -- a column that climbs as long as you keep singing."
		"saintsreward": return "A halo turns above your shoulder, striking on its own, and a saint's work comes back to the one who did it."
		"patientknife": return "It does not swing once. TWELVE knives come out of the dark around you at the same moment, and they are all patient, and they are all yours."
		"kingdomturning": return "A KINGDOM turns about you -- six crowned shades with spears, wheeling out and back, and every one of them is striking."
		"rumor":       return "It does not bounce, it SPREADS. Everyone it reaches tells two more, and it grows a little in every telling, until the whole room has heard."
		"skymeasure":  return "It surveys the sky, and then the sky comes DOWN along the marks -- six columns of starlight the whole height of the room."
		"unbentcolumn": return "A COLONNADE comes up out of the floor -- five pillars, one after another down the hall, and nothing that was standing there is standing now."
		"choirofone":  return "One voice that is a choir: every shaft splits into FIVE a moment after it leaves, and the cadence never stops."
		"thronestrings": return "Seven STRINGS stretch across the room, and plucking them makes the whole span ring -- everything standing on a string pays for the note."
		"worldsgrief": return "It breaks into TWELVE tears, and every one of them finds someone. Grief does not miss."
		"skycharges":  return "The sky sends the bill: EIGHT bolts down the field, one after another, and each one lands like a full stop."
		"worldcut":    return "One cut, and it does not stop at the edge of the screen. Everything in that line, however far, is already cut."
		"deepcourt":   return "Three drowned courtiers rise and STAY, drifting at your shoulder and striking on their own for as long as you hold the crown."
		"quietwheel":  return "It shows you NOTHING while it works -- no numbers, no noise, just a grey wheel turning in the middle of them. When it stops it bills you all at once."
		"midwinterwheel": return "Runs a wide circle around you laying a RING of rime on the floor, and anything caught in the track goes slow and cold."
		"skyquills":   return "The quills go up and HANG there quivering. A moment later the whole sky comes down at once."
		"eventide":    return "The volley goes out like a tide, turns, and comes back -- and it takes a second toll on the way home."
		"tomeofrains": return "Opens a cloud over the field and lets it RAIN. Nothing under it stays dry for four seconds."
		"wardenwatch": return "A hooded post that keeps watch down one lane and fires a single long shot every count -- and the shot goes through everything standing in that line."
		"glacierwrit": return "A slab of ice that ACCRETES as it drifts -- a shard when it leaves your hand, a wall by the end of the room, and then it breaks up."
		"owlremembers": return "It swoops, wheels around, and comes back -- three passes, and IT REMEMBERS: every visit hurts more than the last."
		"quillrain":   return "Not a volley. A DRIZZLE -- quills falling faster than you can count them, all over the ground in front of you."
		"kingsransom": return "Stamps a PRICE on them. The seal barely stings; what it is for is the gold it pays out if they die still wearing it."
		"gallows":     return "It does not knock them back. It takes them UP, holds them there swinging, and then the floor comes back."
		"pilgrimscourge": return "Every place the knots land becomes a WAYMARK. Walk your own road back and the stones give something to whoever laid them."
		"seawall":     return "The swing does not travel -- it STOPS and stands there, a wall of water on the wrong side of them, shoving anything that tries to cross."
		"serpentsermon": return "The lash finds one body and COILS around it, and then it stays and preaches, biting on every breath until it is done."
		"twinburst":   return "Two bolts winding around one another, and everywhere their paths CROSS the air goes off."
		"deepbeacon":  return "A lamp planted in the ground that PULSES on a slow count. Each ring shoves the room a little further away from it."
		"starfall":    return "The shot goes up and out of sight. Three stars come down where it was pointed."
		"worldtoll":   return "The blow goes DOWN. It runs under the floor and comes up somewhere out ahead of you, which is the last place they were watching."
		"hollowwheel": return "It is not thrown. It GUARDS -- a hollow wheel running a tight fast ring around you, shoving off anything that comes close."
		"direportent": return "The shaft does not kill. It FIXES an omen over them, and the sign sinks lower and shakes harder until the hour comes -- and then it falls."
		"lastcourier": return "A route, not a ricochet. It keeps a list, never knocks twice, and every delivery weighs the same as the first."
		"griffinvolley": return "The shafts CLIMB, then fold and stoop like birds -- each one picking its own body out of the room."
		"meteorquill": return "The volley goes UP. What comes down is a shower of burning quills across everything in front of you."
		"ashherd":     return "Every jab leaves a cloud of ash standing where it struck. Enough jabs and the ground ahead is a HERD of them, all smouldering."
		"cindershelf": return "Hangs a burning LEDGE in the air. Anything that shares that line keeps paying for it."
		"griefcollect": return "A ricochet loses an edge each bounce; this one GATHERS. It takes something from every body it visits, grows heavier for it, and brings the whole weight home to you."
		"nightlash":   return "The crack lands now. The DARK answers a moment later, from every place the whip passed through."
		"middaysun":   return "Noon has no shadows and this has no gaps -- seven shafts abreast, all arriving at once."
		"anviltoll":   return "Struck once, it RINGS DOWN -- three shockwaves out of the same blow, each tighter and quieter than the last, like a bell dying."
		"horizonrend": return "The crescent SPLITS. Two halves bow apart around whatever stands between, and close again on the far side."
		"silentchoir": return "The shafts barely wound. Each one leaves a VOICE in the body, and the fifth completes the chord -- then all of it sings at once."
		"sunpiece":    return "A fragment that HANGS where it stops and turns a beam around itself like a lighthouse. Standing still is not an option."
		"permafrost":  return "A sheet of ice that KEEPS SPREADING, and the longer it grows the deeper the cold bites and the slower they move."
		"novaburst":   return "One bolt, three bursts. The seed plants two more beats after itself, so the room keeps going off behind you."
		"horizonpike": return "It does not thrust, it TELESCOPES -- three lengths of pike shoved out one past the other down a single line, each one biting on its own."
		"deluge":      return "A wall of water that GROWS as it runs. It shoves harder than it wounds, and everything it reaches goes with it."
		"lodestar":    return "The first thing it strikes becomes TRUE NORTH: the rest of the room leans toward them for three seconds -- and then the star goes out, all at once, on the crowd it gathered."
		"secondmoon":  return "It never comes back. A second moon rises and ORBITS you, and it has PHASES -- full moon bites hard, new moon barely at all. A rhythm you read off the sky instead of a cooldown."
		"shatterhymn": return "The note does not land, it BREAKS -- a glass bell shattering into ringing splinters that scatter across the floor."
		"longtongue":  return "A whip of dawn that LENGTHENS every time it tastes something. Keep landing it and the reach you have earned is there in the strands."
		"watchfire":   return "Plants a low fire that WAITS. It burns quiet and does nothing at all until something walks into its light -- and then it answers all at once."
		"debtmark":    return "Marks a debtor. The debt bites while they live -- and if they die still owing, the book does not close: it passes to whoever is standing nearest."
		"cinderdrag":  return "The head drags as it goes, and everything the chain crosses catches. The floor keeps the shape of your swing in embers."
		"riftburst":   return "The bolt does not burst, it OPENS: a tear hangs in the air hauling everything toward its middle -- and then it shuts, and the shutting is what kills."
		"shardregent": return "The shards do not leave together. They CROWN you first, orbiting a moment, and then go one after another at whatever is nearest."
		"bentheaven":  return "The ray refuses to go straight. It climbs over whatever stands between and comes down on the far side, which makes cover an opinion rather than a fact."
		"commandment": return "Eight ordinary shafts, and the NINTH is a ruling: one heavy bolt that goes through everything standing in its way and does not slow down for any of it."
		"skypillar":   return "Stands a COLUMN of daylight where you pointed. It does not travel and it does not chase -- it is simply there, and briefly, and nothing inside it is comfortable."
		"finaldebt":   return "Every body it bounces off is BOOKED. The mark sits quietly and comes due on its own, so a long chain leaves a room full of accounts closing one after another."
		"worldedge":   return "It leaves the blade as a sliver and arrives as a HORIZON: the thrown edge widens the whole way out, so the far end of the room is where it is largest."
		"risingwheel": return "The wheel does not go out, it CLIMBS -- spinning upward in a widening turn, biting each pass, and carrying whatever it catches off the floor with it."
		"nova":        return "The tongue reaches its full length and the tip goes NOVA: the turn of the lash IS the detonation, and everything near the end of it is in the star."
		"hush":        return "Where the lash turns it leaves a HUSH -- a still, colourless place that holds whatever stands in it, long after the tongue has come home."
		"reckoning":   return "The arrow barely stings, and then it STAYS IN YOU. A second and a half later the reckoning arrives, and it is not quiet at all."
		"cometchain":  return "The head is a comet on a chain: it goes out burning, and where the throw ends it leaves a CRATER still alight when the chain comes home."
		"stormflock":  return "Every jab looses a bird. They turn in the air, pick their own targets, and come down on them -- a flock answering one thrust."
		"dawnline":    return "Lays a bar of first light along the floor, and then the dawn RISES: the line climbs through everything standing in it."
		"afterlight":  return "The swing does not END. Its shape hangs in the air behind it -- a blade of light standing where you cut, still cutting whatever walks into it."
		"ghostbows":   return "You are not alone while you keep firing. Every few shots another spectral bow fades in beside you and looses with you -- up to %d of them -- and they are gone the moment you stop." % int(ex.get("max", 3))
		"daybreak":    return "The blade never reaches them. Swing, and %d stars fall out of the sky onto the mark instead -- each one bursting where it lands. A roof is the only argument against it." % int(ex.get("count", 3))
		"anvil":       return "The ending arrives a beat LATE: the cleave lands, and then a mass comes down out of the dark onto the same spot. The shadow tells you where."
		"worldthorn":  return "The thrust wakes the GROUND. Where the point goes in, thorns come up -- a row of them, standing until they are done."
		"sunspill":    return "What it throws does not burst so much as SPILL: the shell arcs over and leaves a pool of burning daylight on the floor, and standing in it is a decision."
		"sunder":     return "The blow does not stop at the body. It runs out THROUGH the ground -- a front of broken force crossing the room, taking everything it passes once, and stone is no argument."
		"skyfall_rain": return "Nothing leaves the bow. The king's arrows fall from ABOVE wherever you aim -- %d of them -- so open sky is a slaughter and a low ceiling is an apology." % int(ex.get("count", 3))
		"parade":     return "Every arrow that lands calls one of the PROCESSION: a lantern-carrying shade walks in from beyond the edge of the world, through whatever stands between, and strikes the one you marked."
		"boulder":    return "Summons a boulder and lets the world do the rest. It rolls, it follows the slope, and it hits for whatever pace it has gathered -- a hill is worth more than an arm."
		"sorrow":     return "It does not swing so much as WEEP: narrow lances of grief leave the blade many times a second, each one passing clean through whatever stands in it. No single tear is much. There are a great many tears."
		"brazier":    return "Whirl it, hurl it -- and where the head comes to REST it stops being a weapon and becomes a THRONE, a brazier sitting in the dirt spitting embers at whatever comes near, until you take it up again."
		"regicide":   return "You do not stab a king once. Every throw leaves a crown-spear STANDING in them, biting while it stays -- five at a time, and the sixth shoves the first out in a burst."
		"prism":      return "HOLD IT. Six sunbeams open in a fan and draw slowly together; the longer you stand and pour, the tighter they close, until all six burn through the same body at once. Moving lets the sun go out."
		"staff":
			# the extend is the FAMILY; the slam is the weapon. Same shape as the
			# whips, whose card names their tag rather than the crack.
			var slam: String = {
				"spring": " Green wood gives back: every body the slam catches returns a little life to you.",
				"splash": " The slam leaves WATER underfoot, and what stands in it goes slow.",
				"shove":  " It PUNTS. Everything the slam touches leaves hard and does not come back soon.",
				"herd":   " It GATHERS -- the only slam that pulls inward instead of scattering.",
				"drive":  " It DRIVES: the whole herd goes the way you are facing, not outward.",
				"cairn":  " The slam raises a STONE, and the stone stays.",
				"well":   " The slam opens a WELL -- a dark mouth that keeps working after you walk away.",
				"mile":   " A milestone measures DISTANCE: this slam reaches half again as far as any other.",
				"column": " The slam stands a COLUMN of pale light where it struck.",
				"ford":   " The slam lays a CROSSING: water running out along the ground.",
			}.get(str(ex.get("slam_fx", "")), "")
			return "Landed blows in rhythm DRAW IT LONGER; the fourth strikes the earth as a pillar." + slam
		"arc", "thrust", "shot", "rapid":
			if ex.has("status"):
				return "Its edge carries a lingering hurt."
			return ""
	return ""
