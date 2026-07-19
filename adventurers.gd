class_name Adventurers
extends RefCounted

# The twelve adventurers (GAME_BIBLE §2.4.1 "The three defenders" + the deep
# nine). Three are already in Deepwood when the player arrives -- the trio found
# mid-battle in the opening, trapped for weeks because every attempt to leave
# makes the Despair Army swell. The other nine are found chained in the dungeon,
# one per marked depth, and join the defense once freed.
#
# Adventurers are DEFENDERS, not workers: they hold the village while the player
# is away (or right beside them), they can DIE, and they never respawn. The
# player stations each one with E:
#   wall  -- first line, on the wall approach; strongest defense, most exposed
#   city  -- patrols the village proper; solid defense, a step safer
#   house -- sheltered indoors; contributes nothing, can never be killed
#
# Registry only -- live state (rescued/dead/station/hp) lives in
# GameState.adventurers and is saved with the game.

const STATIONS = ["wall", "city", "house"]

# Rescue level 0 = present in the village from the start (the opening trio).
# Deep levels avoid boss floors (multiples of 5) and Bram's level 8.
const ROSTER = {
	# --- the Three Defenders (the opening battle, GAME_BIBLE 2.4.1) ---
	"adv_roland": {"name": "Roland Ashmark", "weapon": "blade", "level": 0, "hp": 140.0, "dmg": 16,
		"line": "We've held this clearing for weeks. Every road out just breeds more of them."},
	"adv_wren": {"name": "Wren Falkner", "weapon": "bow", "level": 0, "hp": 110.0, "dmg": 14,
		"line": "I count the horde every dawn. It counts us back."},
	"adv_castor": {"name": "Castor Hale", "weapon": "spear", "level": 0, "hp": 155.0, "dmg": 15,
		"line": "The way out isn't blocked. It's baited. Don't try it alone like we did."},
	# --- the deep nine, freed on the climb ---
	"adv_mira": {"name": "Mira Coldbrook", "weapon": "blade", "level": 7, "hp": 150.0, "dmg": 18,
		"line": "Three days in the dark. I owe the dark some pain."},
	"adv_jorun": {"name": "Jorun Pyke", "weapon": "spear", "level": 13, "hp": 175.0, "dmg": 20,
		"line": "They took my company one by one. I'm the ledger that's left."},
	"adv_essa": {"name": "Essa Nightbrook", "weapon": "bow", "level": 18, "hp": 140.0, "dmg": 22,
		"line": "I put out their eyes at two hundred paces. Point me at a wall."},
	"adv_darvin": {"name": "Darvin Mott", "weapon": "blade", "level": 23, "hp": 200.0, "dmg": 24,
		"line": "I was a caravan guard. The caravan's gone. The guarding isn't."},
	"adv_kessa": {"name": "Kessa Vayle", "weapon": "spear", "level": 33, "hp": 230.0, "dmg": 28,
		"line": "Chains don't hold a pikewoman with a grudge."},
	"adv_brannoc": {"name": "Brannoc Tor", "weapon": "blade", "level": 43, "hp": 280.0, "dmg": 33,
		"line": "I dulled four of their blades before they got mine off me. Get me a fifth."},
	"adv_liselle": {"name": "Liselle Dray", "weapon": "bow", "level": 53, "hp": 220.0, "dmg": 38,
		"line": "They kept me alive as bait. Turns out bait bites."},
	"adv_hakon": {"name": "Hakon Vey", "weapon": "spear", "level": 63, "hp": 330.0, "dmg": 42,
		"line": "This deep, the dark forgets what daylight costs. Remind it with me."},
	"adv_sorrel": {"name": "Sorrel Ka", "weapon": "blade", "level": 78, "hp": 380.0, "dmg": 50,
		"line": "I've seen what's at the bottom. You'll want every sword you can free."},
}

static func get_def(id: String) -> Dictionary:
	return ROSTER.get(id, {})

static func ids() -> Array:
	return ROSTER.keys()

# The adventurer (if any) chained at this dungeon level; {} when none.
static func for_level(level: int) -> Dictionary:
	for id in ROSTER.keys():
		if int(ROSTER[id].get("level", -1)) == level:
			var d: Dictionary = ROSTER[id].duplicate()
			d["id"] = id
			return d
	return {}

static func starters() -> Array:
	var out := []
	for id in ROSTER.keys():
		if int(ROSTER[id].get("level", -1)) == 0:
			out.append(id)
	return out
