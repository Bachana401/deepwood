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
# Leadership titles (Leader/Principal/Warchief) are deliberately unreachable
# through school -- GameState.REGULAR_STATS never includes them, so the
# only way to fill those slots is a rescued villager who already carries
# that exact stat_name. Same reasoning covers Party/Teachers: there's no
# matching graduate stat for those either, so they're just open to any
# assigned adult rather than gated.
const ROLE_DEFS = {
	"Government": [
		{"title": "Leader", "slots": 1, "required_stat": "Leader"},
		{"title": "Party", "slots": 10, "required_stat": ""},
	],
	"School": [
		{"title": "Principal", "slots": 2, "required_stat": "Principal"},
		{"title": "Teachers", "slots": 10, "required_stat": ""},
		{"title": "Student", "slots": 20, "required_stat": "", "is_enrollment": true, "requires_kid": true, "grants_stat": "random"},
	],
	"Farm": [
		{"title": "Leader", "slots": 1, "required_stat": "Leader"},
		{"title": "Farmer", "slots": 10, "required_stat": "Farm"},
	],
	"Hospital": [
		{"title": "Leader", "slots": 1, "required_stat": "Leader"},
		{"title": "Doctors", "slots": 10, "required_stat": "Hospital"},
	],
	"Barracks": [
		{"title": "Warchief", "slots": 2, "required_stat": "Warchief"},
		{"title": "Warrior", "slots": 10, "required_stat": "Warrior"},
		{"title": "Recruit", "slots": 20, "required_stat": "", "is_enrollment": true, "requires_sex": "Male", "grants_stat": "Warrior"},
	],
	# The remaining 6 buildings each match one of GameState.REGULAR_STATS
	# exactly, so every School graduate has a real, matching building to
	# work at (not just Farm) -- same Leader/Worker shape as Farm/Hospital.
	"Fishing Dock": [
		{"title": "Leader", "slots": 1, "required_stat": "Leader"},
		{"title": "Fisherman", "slots": 10, "required_stat": "Fishing"},
	],
	"Science Lab": [
		{"title": "Leader", "slots": 1, "required_stat": "Leader"},
		{"title": "Scientist", "slots": 10, "required_stat": "Scientist"},
	],
	"Bank": [
		{"title": "Leader", "slots": 1, "required_stat": "Leader"},
		{"title": "Financist", "slots": 10, "required_stat": "Financist"},
	],
	"Blacksmith": [
		{"title": "Leader", "slots": 1, "required_stat": "Leader"},
		{"title": "Blacksmith", "slots": 10, "required_stat": "Blacksmith"},
	],
	"Tavern": [
		{"title": "Leader", "slots": 1, "required_stat": "Leader"},
		{"title": "Barman", "slots": 10, "required_stat": "Tavern"},
	],
	# The Bar is the village's social heart: every NPC drops by now and then
	# (see npc.gd), fun music plays from it, and visiting lifts the player's
	# morale (see player.gd bar morale). Bartender is open to any adult.
	"Bar": [
		{"title": "Leader", "slots": 1, "required_stat": "Leader"},
		{"title": "Bartender", "slots": 6, "required_stat": ""},
	],
	"Marketplace": [
		{"title": "Leader", "slots": 1, "required_stat": "Leader"},
		{"title": "Trader", "slots": 10, "required_stat": "Marketplace"},
	],
}

# Builderhouse isn't detailed yet -- it's meant to power the village-defense
# wall-building/repair workforce, not passive income, so it'll get its own
# role list once that system exists rather than a generic income-style one.
const DEFAULT_ROLES = [
	{"title": "Worker", "slots": 20, "required_stat": ""},
]

static func get_roles(building_role_key: String) -> Array:
	return ROLE_DEFS.get(building_role_key, DEFAULT_ROLES)
