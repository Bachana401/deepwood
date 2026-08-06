extends Node

# THE IMPROVISED HAND (dev, 2026-08-06: "PLAYER SHOULD BE ABLE TO HOLD ANY ITEM
# IN HAND, ANYTHING WHICH CAN BE PUT IN INVENTORY OR CHESTS, CAN BE HELD BY
# PLAYER, WHEN PLAYER CLICKS MOUSE HE JUST SWINGS THAT ITEM (UNLESS ITS
# CONSUMABLE OR WEAPON OR SIMILAR THINGS)").
#
# Three things this guards, in order of how badly they would hurt:
#
#   1. A HELD ITEM ACTUALLY SWINGS AND ACTUALLY HITS. Not "the flag was set" --
#      a live dummy is placed inside the hitbox and the damage it RECORDS is
#      read back. A hold that sets every field correctly and lands nothing is
#      the exact shape of failure this project keeps finding.
#   2. NOTHING ABOUT WEAPONS OR CONSUMABLES MOVED. The whole feature is
#      additive or it is a regression.
#   3. IT STAYS WEAK. A named "improvised" hold that quietly out-damages a real
#      tier-1 weapon is a balance bug nobody would think to look for, so the
#      comparison is measured off the LIVE weapon stats, never a magic number.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

const IMP = preload("res://improvised_hold.gd")

func _ready() -> void:
	var p: Node = null
	for i in range(1200):
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null: break
	if p == null: printerr("no player"); get_tree().quit(1); return
	for i in range(60):
		await get_tree().process_frame
		if not get_tree().paused: break
		for n in get_tree().root.find_children("*", "", true, false):
			if n.has_method("finish") and n.has_method("show_line"): n.finish(); break
	get_tree().paused = false

	# ---------------- the gate: what may go in the hand ----------------
	check("a material can be held", IMP.can_hold("wood"))
	check("a coin can be held", IMP.can_hold("coin_gold"))
	check("armour can be held", IMP.can_hold("armor_leather"))
	check("a relic can be held", IMP.can_hold("relic_vigor"))
	check("a misc oddity can be held", IMP.can_hold("junk_boot"))
	check("a WEAPON is never improvised", not IMP.can_hold("wpn_sword"))
	check("a CONSUMABLE is never improvised", not IMP.can_hold("potion_health"))
	check("the empty id is not holdable", not IMP.can_hold(""))
	check("an unknown id is not holdable", not IMP.can_hold("no_such_item_xyz"))
	# and the rule generalises: every non-weapon non-consumable in the catalog
	var unheldable: Array = []
	for id in Inventory.ITEM_DEFS.keys():
		var cat := str(Inventory.ITEM_DEFS[id].get("category", "misc"))
		if cat == "weapon" or cat == "consumable":
			continue
		if not IMP.can_hold(str(id)):
			unheldable.append(id)
	check("EVERY non-weapon non-consumable item in the catalog can be held",
		unheldable.is_empty(), str(unheldable))

	# ---------------- put a log in the hand ----------------
	p.inventory.add_item("wood", 5)
	var ok_hold: bool = p.wield_weapon("wood")
	await get_tree().process_frame
	check("wield_weapon routes a non-weapon into the hand", ok_hold)
	check("is_improvised is set", p.is_improvised)
	check("the held id is the log", str(p.active_weapon_id) == "wood", str(p.active_weapon_id))
	check("it swings as melee", str(p.active_weapon_type) == "melee")
	check("damage is the improvised constant",
		int(p.active_stats.damage) == int(IMP.DAMAGE),
		"got %s want %s" % [p.active_stats.damage, IMP.DAMAGE])
	check("the hitbox took the improvised size",
		p.get_node("AttackArea/CollisionShape2D").shape.size == IMP.AREA,
		str(p.get_node("AttackArea/CollisionShape2D").shape.size))
	# the safety property: a stand-in def means no weapon verb can fire from a
	# fish, and no log can chop a tree the way the axe does
	check("no weapon special/unique/tool can fire from a held item",
		not p.active_def.has("special") and not p.active_def.has("unique_effect")
		and not p.active_def.has("tool_type"))
	check("a held item grants no grade passive",
		Inventory.get_weapon_passive("wood").is_empty())

	# ---------------- it is DRAWN in the hand ----------------
	var icon: ColorRect = p.improvised_icon
	check("the held item has its own icon node", icon != null)
	if icon != null:
		check("the held icon is visible", icon.visible)
		# paint_icon resolves every item to a picture -- real art if art/items/<id>.png
		# exists, its procedural symbol otherwise. Either way SOMETHING is drawn.
		check("the held icon actually painted something", icon.get_child_count() > 0,
			"children=%d" % icon.get_child_count())
		check("the held icon is sized to the hand", icon.size == IMP.HELD_SIZE, str(icon.size))
		check("the icon node is a child of WeaponIcon, so it aims and swings with it",
			icon.get_parent() == p.get_node("WeaponIcon"))
	check("the fallback weapon bar is transparent behind it",
		p.get_node("WeaponIcon").color.a == 0.0)
	check("no crossguard on a log", not p.weapon_guard.visible)
	check("the diagonal blade-art path stays off for an upright item",
		not p.weapon_sprite.visible)

	# ---------------- SWING IT AT SOMETHING ----------------
	var here: Vector2 = p.global_position
	var dummy = load("res://dps_dummy.gd").new()
	p.get_parent().add_child(dummy)
	dummy.global_position = p.global_position + Vector2(34, 46)
	p.set_test_aim(Vector2.RIGHT)
	await get_tree().physics_frame
	await get_tree().physics_frame
	p.update_weapon_visual(p.active_stats.icon_offset)
	var reach: float = p.get_node("AttackArea").position.length()
	check("the hitbox sits at exactly the improvised reach",
		absf(reach - float(IMP.REACH)) < 0.01, "reach=%.2f" % reach)

	p.attack_cooldown_remaining = 0.0
	dummy._last = 0
	p.perform_attack()
	# read it all back SYNCHRONOUSLY -- the hit, the cooldown and the swing state
	# are all set inside perform_attack, and awaiting first would race the arc
	# tween's own completion callback on a slow frame
	check("swinging a log HIT the dummy", int(dummy._last) > 0, "last=%d" % int(dummy._last))
	check("the swing put the player on cooldown", float(p.attack_cooldown_remaining) > 0.0)
	check("the swing animated (the arc actually ran)", p.is_attacking)
	await get_tree().physics_frame

	# ---------------- and it stays feeble ----------------
	# measured off the LIVE weapon stats, so a later tuning pass to the axe or
	# the sword can never leave this assertion asserting a stale number
	var axe: Dictionary = Inventory.weapon_stats_for("tool_axe")
	var sword: Dictionary = Inventory.weapon_stats_for("wpn_sword")
	var imp_dps: float = float(IMP.DAMAGE) / float(IMP.COOLDOWN)
	var axe_dps: float = float(axe.damage) / float(axe.cooldown)
	var sword_dps: float = float(sword.damage) / float(sword.cooldown)
	check("improvised dps is below the WEAKEST real weapon", imp_dps < axe_dps,
		"improvised=%.2f axe=%.2f" % [imp_dps, axe_dps])
	check("improvised dps is far below the starter sword", imp_dps < sword_dps * 0.5,
		"improvised=%.2f sword=%.2f" % [imp_dps, sword_dps])
	check("a held item reaches less far than the starter sword",
		float(IMP.REACH) < float(sword.range_offset),
		"improvised=%.1f sword=%.1f" % [IMP.REACH, float(sword.range_offset)])

	# ---------------- a real weapon is untouched ----------------
	p.inventory.add_item("wpn_sword", 1)
	p.wield_weapon("wpn_sword")
	await get_tree().process_frame
	check("wielding a weapon clears is_improvised", not p.is_improvised)
	check("the held-item icon is hidden again", not p.improvised_icon.visible)
	check("the sword kept its own authored damage",
		int(p.active_stats.damage) == int(Inventory.weapon_stats_for("wpn_sword").damage),
		str(p.active_stats.damage))
	dummy._last = 0
	p.attack_cooldown_remaining = 0.0
	p.perform_attack()
	check("the sword still hits, and hits harder than a log",
		int(dummy._last) > int(IMP.DAMAGE), "sword=%d" % int(dummy._last))
	await get_tree().physics_frame

	# ---------------- the hotbar routes all three kinds ----------------
	var saved_slots: Array = p.inventory.slots.duplicate(true)
	for i in range(p.inventory.slots.size()):
		p.inventory.slots[i] = null
	p.inventory.add_item("stone", 3)          # slot 0
	p.inventory.add_item("potion_health", 2)  # slot 1
	p.inventory.add_item("wpn_sword", 1)      # slot 2
	p.health = 1
	p.select_hotbar_slot(0)
	await get_tree().process_frame
	check("hotbar 1 HOLDS a stone",
		p.is_improvised and str(p.active_weapon_id) == "stone", str(p.active_weapon_id))
	var before: int = p.inventory.get_count("potion_health")
	p.select_hotbar_slot(1)
	await get_tree().process_frame
	check("hotbar 2 DRINKS the potion instead of holding it",
		p.inventory.get_count("potion_health") < before and str(p.active_weapon_id) == "stone",
		"count %d->%d held=%s" % [before, p.inventory.get_count("potion_health"), p.active_weapon_id])
	p.select_hotbar_slot(2)
	await get_tree().process_frame
	check("hotbar 3 WIELDS the sword",
		not p.is_improvised and str(p.active_weapon_id) == "wpn_sword", str(p.active_weapon_id))

	# ---------------- spending the held stack empties the hand ----------------
	p.select_hotbar_slot(0)
	await get_tree().process_frame
	check("holding the stone again", p.is_improvised)
	p.inventory.remove_item("stone", p.inventory.get_count("stone"))
	await get_tree().physics_frame
	await get_tree().physics_frame
	check("spending the last stone empties the hand",
		not p.is_improvised and str(p.active_weapon_id) == "",
		"held=%s improvised=%s" % [p.active_weapon_id, p.is_improvised])
	check("nothing is drawn in an empty hand",
		not p.get_node("WeaponIcon").visible and not p.improvised_icon.visible)
	# Re-seat the dummy beside the player FIRST. Dozens of frames have passed
	# since it was placed and the player has drifted under gravity -- and the
	# first draft of this test proved the point: "an empty hand cannot swing"
	# passed while the dummy was simply out of reach, which is a green light for
	# nothing at all. The positive control below is what caught it.
	dummy.global_position = p.global_position + Vector2(34, 46)
	await get_tree().physics_frame
	await get_tree().physics_frame
	dummy._last = 0
	p.attack_cooldown_remaining = 0.0
	p.perform_attack()
	check("an empty hand cannot swing", int(dummy._last) == 0, "last=%d" % int(dummy._last))
	# POSITIVE CONTROL for the negative above: the same dummy, in the same place,
	# in the same frame, DOES take damage the moment the hand is refilled.
	p.inventory.add_item("wood", 1)
	p.wield_weapon("wood")
	p.attack_cooldown_remaining = 0.0
	p.perform_attack()
	check("...and the same dummy still takes a hit once the hand is refilled",
		int(dummy._last) > 0, "last=%d" % int(dummy._last))

	# ---------------- put the world back ----------------
	dummy.queue_free()
	for i in range(p.inventory.slots.size()):
		p.inventory.slots[i] = saved_slots[i] if i < saved_slots.size() else null
	p.set_test_aim(Vector2.ZERO)
	p.global_position = here
	p.wield_weapon("wpn_sword")

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
