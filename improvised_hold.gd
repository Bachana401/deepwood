extends RefCounted

# =============================================================================
# THE IMPROVISED HAND
# =============================================================================
# Dev request, 2026-08-06, verbatim:
#
#   "PLAYER SHOULD BE ABLE TO HOLD ANY ITEM IN HAND, ANYTHING WHICH CAN BE PUT
#    IN INVENTORY OR CHESTS, CAN BE HELD BY PLAYER, WHEN PLAYER CLICKS MOUSE HE
#    JUST SWINGS THAT ITEM (UNLESS ITS CONSUMABLE OR WEAPON OR SIMILAR THINGS)"
#
# So a log, a stone, a fish, a gold coin, a leather helm, somebody's boot -- if
# it fits in a bag it fits in a hand, and clicking swings it. This file owns the
# ONE set of numbers that a held object fights with; player.gd owns the wielding
# and the swing itself (which is the ordinary melee path, unchanged, so the arc,
# the trail, the combo string and the hitbox all match the rest of the game).
#
# Preloaded as a const by player.gd rather than carrying a class_name: a global
# class registry entry is a thing a stray backup copy can hijack (it has already
# happened once in this repo), and nothing here needs to be globally visible.
# =============================================================================

# The two categories that are NOT held-and-swung, and why:
#   * "consumable" -- a potion is DRUNK. use_item owns it, and the hotbar key
#     still consumes it exactly as it did before.
#   * "weapon"     -- a weapon has real authored stats, a special, a verb.
#     wield_weapon owns it and this file must never touch it.
# Everything else -- material, armor, relic, currency, misc, and whatever
# category gets added next -- lands in the hand. Listing the EXCLUSIONS rather
# than the inclusions is deliberate: a new category ships holdable by default,
# which is what the dev asked for ("anything which can be put in inventory").
const NOT_HELD := ["weapon", "consumable"]

# ---------------------------------------------------------------------------
# THE NUMBER, and why it is this number.
#
# The weakest real weapons in the game are the Woodsman's Axe and the Miner's
# Pickaxe: 6 damage on a 0.5s swing = 12 dps. The starter Sword is 9 on 0.3s =
# 30 dps.
#
# A held log is HALF the weakest weapon's damage on a slower, clumsier swing:
# 3 on 0.6s = 5 dps, or 6.25 dps once the melee combo string's average 1.25x is
# folded in. That is roughly two fifths of the feeblest tier-1 weapon, and it
# stays two fifths at every character level -- an improvised hold runs through
# skill_damage_mult("melee") like any other melee swing, so both sides of the
# comparison scale by the same factor and a log can never overtake a real
# weapon no matter what the player builds.
#
# 3 is also small enough to READ as improvised: against anything past the first
# few floors the damage numbers are visibly pathetic, which is the point. This
# is a thing you do because your weapon broke or because it is funny, never
# because it is good.
const DAMAGE := 3
const COOLDOWN := 0.6

# ---------------------------------------------------------------------------
# Geometry. You are holding an object at arm's length, not swinging a blade:
# short reach, a small box, a feeble shove. (For scale: the starter Sword
# derives a 52x27 hitbox at 42px reach from Inventory.SIZE_BANDS, so an
# improvised hold gives up both reach and coverage as well as damage.)
const HELD_SIZE := Vector2(30.0, 30.0)      # drawn size of the thing in hand
const REACH := 34.0                         # where the hitbox sits along the aim
const AREA := Vector2(38.0, 32.0)           # the hitbox itself
const HOLD_OFFSET := 20.0                   # how far from the body the hand sits
const KNOCKBACK_MIN := 12.0
const KNOCKBACK_MAX := 24.0


# True when `item_id` is a real item that is neither a weapon nor a consumable,
# i.e. something the player may put in their hand and swing.
static func can_hold(item_id: String) -> bool:
	if item_id == "":
		return false
	var def: Dictionary = Inventory.get_item_def(item_id)
	if def.is_empty():
		return false
	return not (str(def.get("category", "misc")) in NOT_HELD)


# The stat block an improvised hold fights with. Same SHAPE as
# Inventory.weapon_stats_for returns, so the melee path cannot tell the
# difference -- every field the swing reads is present and typed.
static func stats_for(_item_id: String) -> Dictionary:
	return {
		"damage": DAMAGE,
		"cooldown": COOLDOWN,
		"range_offset": REACH,
		"area_size": AREA,
		"knockback_min": KNOCKBACK_MIN,
		"knockback_max": KNOCKBACK_MAX,
		"icon_size": HELD_SIZE,
		# transparent: the painted item symbol IS the look, so the fallback
		# weapon bar must not show through behind it
		"icon_color": Color(0.0, 0.0, 0.0, 0.0),
		"icon_offset": HOLD_OFFSET,
	}


# The stand-in item definition an improvised hold wields under. Deliberately
# NOT the item's real def: a def is where "special", "unique_effect",
# "tool_type", "mana_cost" and the rest live, and every one of those is a door
# into a weapon verb this thing has no business firing. A minimal def keeps the
# whole special-dispatch chain dead and drops the swing straight onto the plain
# melee path. The item's own colour comes along so the swing trail is the
# colour of the thing you swung -- a log smears brown, an ember crystal orange.
static func def_for(item_id: String) -> Dictionary:
	return {
		"color": Inventory.get_item_def(item_id).get("color", Color(1.0, 1.0, 1.0, 1.0)),
		"improvised": true,
	}
