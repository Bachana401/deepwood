class_name BuildingRoles
extends RefCounted

# Role definitions per building (keyed by the building's role_key, e.g.
# "Farm", "Government"). Each role entry:
#   title: display name of the role
#   slots: how many villagers can hold this role at once
#   required_stat: villager.stat_name must match this exactly to qualify
#                  ("" means open to any adult, no stat requirement)
#   requires_sex: villager.sex must match this exactly ("" = either)
#   requires_kid: true if only children may take this slot
#   is_enrollment: true for School's Student / Barracks' Recruit -- taking
#                  this role doesn't assign a finished worker, it starts a
#                  graduation timer (see GameState.enroll_villager)
#   grants_stat: for enrollment roles only, what stat_name the villager
#                gets on graduation -- "random" (School) or a fixed name
#                (Barracks always grants "Warrior")
#
# Every building's TOP role is a unique, named leadership post ("leadership":
# true). Each carries a distinct required_stat equal to its title, so ONE
# rescued figure who carries that exact stat is the sole key to that one job
# (the Chancellor can only govern, the Forgemaster only runs the smithy) -- see
# VillagerQuests.IMPORTANT_FIGURES, the boss-level "important NPC" rescues.
# These leadership stats are deliberately absent from GameState.REGULAR_STATS,
# so School can never graduate one -- a leader is always a rescued VIP. The
# "leadership" flag (not the title) is what code keys off (fixed slot count in
# building.effective_slots, the leader-bonus multipliers in game_state).
const ROLE_DEFS = {
	"Government": [
		{"title": "Chancellor", "slots": 1, "required_stat": "Chancellor", "leadership": true},
		{"title": "Party", "slots": 10, "required_stat": ""},
	],
	"School": [
		{"title": "Principal", "slots": 2, "required_stat": "Principal", "leadership": true},
		{"title": "Teachers", "slots": 10, "required_stat": ""},
		{"title": "Student", "slots": 20, "required_stat": "", "is_enrollment": true, "requires_kid": true, "grants_stat": "random"},
	],
	"Farm": [
		{"title": "Harvestmaster", "slots": 1, "required_stat": "Harvestmaster", "leadership": true},
		{"title": "Farmer", "slots": 10, "required_stat": "Farm"},
	],
	"Hospital": [
		{"title": "Chief Physician", "slots": 1, "required_stat": "Chief Physician", "leadership": true},
		{"title": "Doctors", "slots": 10, "required_stat": "Hospital"},
	],
	"Barracks": [
		{"title": "Warchief", "slots": 2, "required_stat": "Warchief", "leadership": true},
		{"title": "Warrior", "slots": 10, "required_stat": "Warrior"},
		{"title": "Recruit", "slots": 20, "required_stat": "", "is_enrollment": true, "requires_sex": "Male", "grants_stat": "Warrior"},
	],
	# The remaining buildings each match one of GameState.REGULAR_STATS with
	# their WORKER role, so every School graduate has a real matching building
	# to work at -- same leadership/worker shape throughout.
	"Fishing Dock": [
		{"title": "Harbormaster", "slots": 1, "required_stat": "Harbormaster", "leadership": true},
		{"title": "Fisherman", "slots": 10, "required_stat": "Fishing"},
	],
	"Science Lab": [
		{"title": "Lead Researcher", "slots": 4, "required_stat": "Lead Researcher", "leadership": true},
		{"title": "Scientist", "slots": 10, "required_stat": "Scientist"},
	],
	"Bank": [
		{"title": "Treasurer", "slots": 1, "required_stat": "Treasurer", "leadership": true},
		{"title": "Financist", "slots": 10, "required_stat": "Financist"},
	],
	"Blacksmith": [
		{"title": "Forgemaster", "slots": 1, "required_stat": "Forgemaster", "leadership": true},
		{"title": "Blacksmith", "slots": 10, "required_stat": "Blacksmith"},
	],
	"Tavern": [
		{"title": "Tavernkeeper", "slots": 1, "required_stat": "Tavernkeeper", "leadership": true},
		{"title": "Barman", "slots": 10, "required_stat": "Tavern"},
	],
	# The Bar is the village's social heart: every NPC drops by now and then
	# (see npc.gd), fun music plays from it, and visiting lifts the player's
	# morale (see player.gd bar morale). Bartender is open to any adult.
	"Bar": [
		{"title": "Publican", "slots": 1, "required_stat": "Publican", "leadership": true},
		{"title": "Bartender", "slots": 6, "required_stat": ""},
	],
	"Marketplace": [
		{"title": "Merchant Prince", "slots": 1, "required_stat": "Merchant Prince", "leadership": true},
		{"title": "Trader", "slots": 10, "required_stat": "Marketplace"},
	],
	# Builderhouse powers the repair/defense workforce (not passive income). Its
	# two leaders -- Master Builder (design) and Foreman (labour) -- are rescued
	# VIPs like every other top post.
	"Builderhouse": [
		{"title": "Master Builder", "slots": 1, "required_stat": "Master Builder", "leadership": true},
		{"title": "Foreman", "slots": 1, "required_stat": "Foreman", "leadership": true},
		{"title": "Worker", "slots": 20, "required_stat": ""},
	],
	# The Mine (5.7, decided delegated): the delegated form of hand-mining --
	# staffed Miners haul stone + iron shards into the player's bag daily.
	"Mine": [
		{"title": "Miner", "slots": 3, "required_stat": "Mine"},
	],
	# The Shrine (10, decided delegated): corruption's only mercy. Healing at
	# its apex, so its keepers carry the HOSPITAL stat -- and its name honors
	# the one who boosts it, Seraphel the Lightkeeper.
	"Shrine": [
		{"title": "Lightkeeper", "slots": 2, "required_stat": "Hospital"},
	],
}

const DEFAULT_ROLES = [
	{"title": "Worker", "slots": 20, "required_stat": ""},
]

static func get_roles(building_role_key: String) -> Array:
	return ROLE_DEFS.get(building_role_key, DEFAULT_ROLES)
