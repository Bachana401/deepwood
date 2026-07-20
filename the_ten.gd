class_name TheTen
extends RefCounted

# THE TEN (GAME_BIBLE §8) -- the capstone hostages, the truly unbreakable.
# Orin keeps them as trophies: ten legends of the broken age he has personally
# tried to break for years and never once cracked. Each hangs in a hidden
# Trophy Vault on a non-boss floor; each rescue permanently transforms one
# village system; and when the Harvest comes, the Ten are the ones who do not
# turn. Rescuing ALL TEN is part of the finale gate (§9.1) -- the door to
# floor 100 does not open while any of them still hangs in the dark.
#
# Names, titles, floors and boons are CANON (§8's table, transcribed exactly).
# Live state lives in GameState.the_ten and saves with the game.

const ROSTER = {
	"ten_brannoc": {"floor": 52, "name": "Brannoc", "title": "the Wall That Stood",
		"boon": "Warriors train twice as fast; the wall stands half again as strong.",
		"line": "Orin asked me every night for six years why I would not kneel. Tell him the wall is coming home."},
	"ten_maera": {"floor": 58, "name": "Maera", "title": "the Last Lightmender",
		"boon": "The Doctor's price mends twice as fast -- and once per siege, Maera pulls someone back from the brink.",
		"line": "He showed me every death I ever failed to stop. I stitched every one of them in my head, forever. I'm not done stitching."},
	"ten_toren": {"floor": 63, "name": "Toren Ashvale", "title": "the Forgefather",
		"boon": "The Forge sells up to EPIC grade; crafting costs a quarter less.",
		"line": "He melted my hammers in front of me. Hammers can be recast. So can I."},
	"ten_sylvara": {"floor": 69, "name": "Sylvara", "title": "Warden of the Old Groves",
		"boon": "Farm output doubled; wild herbs return to the overworld.",
		"line": "He salted the earth of my groves and made me watch. The earth forgives. So do I -- everything but him."},
	"ten_kaldos": {"floor": 74, "name": "Kaldos", "title": "the Tidecaller",
		"boon": "The Dock's deep-catches haul materials as well as food.",
		"line": "He drowned me a hundred times. The tide brought me back a hundred and one."},
	"ten_elenwe": {"floor": 79, "name": "Elenwe", "title": "Archivist of the Broken Age",
		"boon": "Every unknown material is understood at once; she speaks the lore of the Monarchs.",
		"line": "He burned my libraries page by page. He forgot I had read them."},
	"ten_dorian": {"floor": 84, "name": "Dorian Vail", "title": "the Coinbinder",
		"boon": "Bank interest doubled; half of any gold you drop in death is insured home.",
		"line": "He offered me kingdoms to despair. I told him his rates were terrible."},
	"ten_mirielle": {"floor": 89, "name": "Mirielle", "title": "Voice of the Old Crown",
		"boon": "The Government runs itself a step further; its leaders' hands are worth double.",
		"line": "Crowns fall. Order doesn't. Show me the ledgers -- we have a village to run."},
	"ten_seraphel": {"floor": 94, "name": "Seraphel", "title": "the Lightkeeper",
		"boon": "Grief passes through the village twice as fast beneath her light.",
		"line": "He built me a night that never ended. I lit a candle in it and waited."},
	"ten_ilo": {"floor": 99, "name": "Ilo", "title": "the Nameless Bard",
		"boon": "The tavern's spirit lifts the whole village -- and Ilo sings of the Age of Monarchs.",
		"line": "He took my name so no song would keep me. But I remember all the OTHER names. Shall I sing you one about a throne of shadow?"},
}

static func get_def(id: String) -> Dictionary:
	return ROSTER.get(id, {})

static func ids() -> Array:
	return ROSTER.keys()

# The trophy vault (if any) hidden on this dungeon floor; {} when none.
static func for_level(level: int) -> Dictionary:
	for id in ROSTER.keys():
		if int(ROSTER[id].get("floor", -1)) == level:
			var d: Dictionary = ROSTER[id].duplicate()
			d["id"] = id
			return d
	return {}
