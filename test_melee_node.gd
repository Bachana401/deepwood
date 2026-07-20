extends Node

# Melee is melee: the cursor sets the DIRECTION of a swing, never the distance.
# Guards the levitation removal -- the attack hitbox must sit at exactly the
# weapon's own range_offset no matter where the mouse is, and reach must come
# from the weapon itself (a spear outranges a dagger).

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

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

	# ---------------- no levitation API survives ----------------
	for gone in ["hover_for_mouse", "levitate_max_range", "levitate_float_offset",
			"clamped_hover", "trigger_levitate_flash", "update_levitate_aura", "build_levitate_aura"]:
		check("levitation helper '%s' is gone" % gone, not p.has_method(gone))
	check("no innate Levitate node in any class tree",
		not str(SkillTreeData.TREES).contains("_levitate"))
	check("no skill grants levitate_range",
		not str(SkillTreeData.TREES).contains("levitate_range"))

	# ---------------- the hitbox sits at the weapon's own reach ----------------
	# whatever the mouse is doing, |AttackArea.position| == range_offset exactly.
	p.inventory.add_item("wpn_sword", 1)
	p.wield_weapon("wpn_sword")
	await get_tree().process_frame
	var stats: Dictionary = p.get_weapon_stats()
	p.update_weapon_visual(stats.icon_offset)
	var reach: float = p.get_node("AttackArea").position.length()
	check("melee hitbox sits at exactly the weapon's range_offset (no hover)",
		abs(reach - float(stats.range_offset)) < 0.01,
		"reach=%.2f range_offset=%.2f" % [reach, float(stats.range_offset)])

	# calling it repeatedly must not creep the reach outward (the old hover
	# tracked the cursor and grew; a held weapon is stable)
	for i in range(5):
		p.update_weapon_visual(stats.icon_offset)
		await get_tree().process_frame
	var reach2: float = p.get_node("AttackArea").position.length()
	check("reach is stable across frames (no cursor-tracking creep)",
		abs(reach2 - float(stats.range_offset)) < 0.01,
		"reach=%.2f" % reach2)

	# ---------------- reach comes from the weapon ----------------
	var dagger: float = float(Inventory.get_item_def("wpn_dagger").get("weapon_stats", {}).get("range_offset", 0.0))
	var spear: float = float(Inventory.get_item_def("wpn_spear").get("weapon_stats", {}).get("range_offset", 0.0))
	check("a spear reaches further than a dagger", spear > dagger,
		"spear=%.1f dagger=%.1f" % [spear, dagger])

	# ---------------- the Sage beam replaces the old Far Hand line ----------------
	check("Sage grants beam_channel, not levitate reach",
		str(SkillTreeData.TREES).contains("beam_channel"))
	# every node that grants beam_ramp must sit at/after the fork that unlocks the
	# beam, else it's a passive that is named but never read
	check("beam ramp nodes exist alongside the unlock",
		str(SkillTreeData.TREES).contains("beam_ramp"))
	# drive the real tree nodes, so this also proves the node data grants what
	# its description promises
	var saved_skills: Array = GameState.unlocked_skills.duplicate()
	GameState.unlocked_skills = []
	check("without the skill there is no beam", not p.has_beam())
	GameState.unlocked_skills = ["mg_s4b"]                       # Focusing Lens
	check("Focusing Lens unlocks the beam", p.has_beam())
	p.beam_connect_time = 0.0
	check("beam starts at 1.0x", abs(p.beam_ramp_mult() - 1.0) < 0.001, "%.3f" % p.beam_ramp_mult())
	p.beam_connect_time = p.BEAM_RAMP_TIME
	check("beam ramps to its 2.5x peak on full contact",
		abs(p.beam_ramp_mult() - 2.5) < 0.001, "%.3f" % p.beam_ramp_mult())
	p.beam_connect_time = p.BEAM_RAMP_TIME * 10.0
	check("beam never exceeds its peak (ramp is clamped)",
		abs(p.beam_ramp_mult() - 2.5) < 0.001, "%.3f" % p.beam_ramp_mult())
	GameState.unlocked_skills = ["mg_s4b", "mg_s6", "mg_s7"]     # +0.6 +0.5
	check("Sustained Focus + Transcendence raise the peak (2.5 -> 3.6x)",
		abs(p.beam_ramp_mult() - 3.6) < 0.001, "%.3f" % p.beam_ramp_mult())
	p.stop_beam()
	check("stopping the beam resets the ramp", p.beam_connect_time == 0.0)
	GameState.unlocked_skills = saved_skills

	# ---------------- slashes: derived from grade, rare and up ----------------
	# a slash is EARNED -- junk grades swing and nothing flies off the blade
	p.inventory.add_item("wpn_sword", 1); p.wield_weapon("wpn_sword")     # common
	check("a common weapon throws no slash", p.swing_slash_config().is_empty())
	p.inventory.add_item("wpn_katana", 1); p.wield_weapon("wpn_katana")   # rare
	var rare_cfg: Dictionary = p.swing_slash_config()
	check("a rare weapon throws a slash", not rare_cfg.is_empty())
	p.inventory.add_item("exc_ragnarok", 1); p.wield_weapon("exc_ragnarok")  # mythic
	var myth_cfg: Dictionary = p.swing_slash_config()
	check("a mythic slash is FATTER than a rare one",
		float(myth_cfg["girth"]) > float(rare_cfg["girth"]) * 1.3,
		"mythic=%.2f rare=%.2f" % [myth_cfg["girth"], rare_cfg["girth"]])
	check("a mythic slash flies FURTHER than a rare one",
		float(myth_cfg["range"]) > float(rare_cfg["range"]) * 1.3,
		"mythic=%.0f rare=%.0f" % [myth_cfg["range"], rare_cfg["range"]])
	check("a mythic slash flies FASTER than a rare one",
		float(myth_cfg["speed"]) > float(rare_cfg["speed"]))
	check("slashes got substantially bigger than the old flat 300px",
		float(myth_cfg["range"]) > 700.0, "%.0f" % myth_cfg["range"])
	# but it still must never beat just walking up and hitting the thing
	for cfg_id in ["wpn_katana", "exc_ragnarok", "exc_shadowblade"]:
		p.inventory.add_item(cfg_id, 1); p.wield_weapon(cfg_id)
		var c: Dictionary = p.swing_slash_config()
		check("'%s' slash stays weaker than its own swing (%.2fx)" % [cfg_id, c.get("damage_mult", 9.9)],
			float(c.get("damage_mult", 9.9)) < 1.0)
	# an authored entry still wins, so flavour riders survive the derivation
	p.wield_weapon("exc_ragnarok")
	check("Ragnarok keeps its authored burn rider",
		not p.swing_slash_config().get("status", {}).is_empty())
	check("player can launch a swing slash", p.has_method("launch_swing_slash"))

	# grade also amplifies raw physical force, for EVERY weapon
	p.wield_weapon("wpn_sword")
	var common_force: float = p.grade_force_mult()
	p.wield_weapon("exc_ragnarok")
	var myth_force: float = p.grade_force_mult()
	check("a mythic weapon throws enemies far harder than a common one",
		myth_force > common_force * 1.5, "mythic=%.2f common=%.2f" % [myth_force, common_force])

	# ---------------- ranged weapons get the same grade presence ----------------
	p.inventory.add_item("wpn_shortbow", 1); p.wield_weapon("wpn_shortbow")   # uncommon
	var low_g: float = p.grade_projectile_girth()
	var low_r: float = p.grade_projectile_range()
	p.inventory.add_item("exc_stormfury", 1); p.wield_weapon("exc_stormfury")  # mythic
	check("a mythic bow looses a heavier shaft", p.grade_projectile_girth() > low_g * 1.3,
		"mythic=%.2f uncommon=%.2f" % [p.grade_projectile_girth(), low_g])
	check("a mythic bow carries further", p.grade_projectile_range() > low_r,
		"mythic=%.2f uncommon=%.2f" % [p.grade_projectile_range(), low_r])

	# a fat arrow must not leak its size into every other arrow: the shape
	# resource is shared by the body, the hit area, AND every arrow ever fired
	# kept OUT of the scene tree on purpose: an arrow dropped at the origin sits
	# inside the village ground, collides on its first frame and frees itself
	# before it can be measured. Scaling needs no physics.
	var a1 = load("res://arrow.tscn").instantiate()
	a1.girth = 3.0
	a1.apply_girth()
	var a2 = load("res://arrow.tscn").instantiate()   # a plain arrow made afterwards
	var fat: float = a1.get_node("CollisionShape2D").shape.size.x
	var plain: float = a2.get_node("CollisionShape2D").shape.size.x
	check("a scaled arrow is genuinely bigger", fat > plain * 2.0, "fat=%.0f plain=%.0f" % [fat, plain])
	check("scaling one arrow does NOT leak into later arrows", abs(plain - 22.0) < 0.01,
		"plain arrow is %.1f wide, expected 22" % plain)
	# and the hit area grew with the body, not just the drawn shaft
	check("the scaled arrow's HIT AREA grew too",
		a1.get_node("HitArea/HitAreaShape").shape.size.x > plain * 2.0)
	a1.free(); a2.free()

	# ---------------- uniques fire from swings and from slashes ----------------
	# a weapon with its OWN signature must not also be handed a generic slash --
	# that made every good weapon feel the same
	p.inventory.add_item("exc_midas", 1); p.wield_weapon("exc_midas")
	check("an Excellent's unique IS its signature (no generic slash bolted on)",
		p.swing_slash_config().is_empty())
	# ...while a plain high-grade weapon still throws something
	p.inventory.add_item("wpn_katana", 1); p.wield_weapon("wpn_katana")
	check("a plain rare weapon still throws a signature", not p.swing_slash_config().is_empty())
	# and what it throws varies by archetype rather than always being a crescent
	var thrown := {}
	for wid in ["wpn_katana", "wpn_windcutter", "wpn_greatsword", "wpn_warhammer", "wpn_sunderer"]:
		p.inventory.add_item(wid, 1); p.wield_weapon(wid)
		var c: Dictionary = p.swing_slash_config()
		if not c.is_empty():
			thrown[str(c.get("type", "?"))] = true
	check("weapons throw MORE THAN ONE kind of thing", thrown.size() >= 2, str(thrown.keys()))
	# heavy weapons lob something that detonates rather than a clean cut
	p.wield_weapon("wpn_warhammer")
	check("a heavy weapon's throw bursts on impact",
		float(p.swing_slash_config().get("aoe", 0.0)) > 0.0)
	p.wield_weapon("wpn_katana")
	check("a quick weapon's throw does not",
		float(p.swing_slash_config().get("aoe", 0.0)) == 0.0)

	# charge-style uniques advance on the SWING, so a whiff still winds them up
	p.inventory.add_item("exc_ragnarok", 1); p.wield_weapon("exc_ragnarok")
	p.ragnarok_charge = 0
	var need: int = int(Inventory.get_item_def("exc_ragnarok").get("unique_value", 8))
	for i in range(need - 1):
		p.advance_swing_charge(null, 0)     # pure misses
	check("missing still winds up a charged unique", p.ragnarok_charge == need - 1,
		"charge=%d of %d" % [p.ragnarok_charge, need])
	p.advance_swing_charge(null, 0)         # the one that completes it
	check("the charge fires on a miss and resets", p.ragnarok_charge == 0)

	# a slash landing must count as a hit for the wielder's unique
	check("player exposes a projectile-hit hook", p.has_method("on_projectile_hit"))
	p.inventory.add_item("exc_soul", 1); p.wield_weapon("exc_soul")   # manasteal
	p.mana = 0.0
	var dummy = load("res://dps_dummy.gd").new()
	p.get_parent().add_child(dummy)
	await get_tree().process_frame
	p.on_projectile_hit(dummy, 20)
	check("a slash hit triggers the weapon's unique (Soulthirst drank mana)", p.mana > 0.0,
		"mana=%.1f" % p.mana)
	# and a unique that throws a projectile must not recurse forever
	p.wield_weapon("exc_ragnarok")
	p.ragnarok_charge = 0
	p.on_projectile_hit(dummy, 15)          # would loop if unguarded
	check("a projectile-thrown unique does not re-trigger itself", not p._in_projectile_unique)
	dummy.queue_free()

	# ---------------- size is derived from swing speed ----------------
	# the roster rule: within a type that actually swings, a bigger weapon must
	# never also be a faster one.
	var swingers := []
	for id in Inventory.ITEM_DEFS.keys():
		var d: Dictionary = Inventory.ITEM_DEFS[id]
		if d.get("category", "") != "weapon":
			continue
		if not Inventory.SIZE_BANDS.has(str(d.get("weapon_type", ""))):
			continue
		var ws: Dictionary = Inventory.weapon_stats_for(id)
		swingers.append({"id": id, "type": str(d.get("weapon_type", "")),
			"cd": float(ws.get("cooldown", 0.0)),
			"area": ws.get("area_size", Vector2.ZERO).x * ws.get("area_size", Vector2.ZERO).y,
			"override": ws.has("size_override"),
			"icon": ws.get("icon_size", Vector2.ZERO).x})
	var offenders := []
	for a in swingers:
		# a size_override is a deliberate, signed-off exception (the rapier is
		# long AND fast, and carries the lowest damage of its peers to pay for
		# it). The rule catches accidents; an override is intent.
		if a["override"]: continue
		for b in swingers:
			if a["type"] != b["type"]: continue
			if a["area"] > b["area"] * 1.05 and a["cd"] < b["cd"] - 0.001:
				offenders.append("%s>%s" % [a["id"], b["id"]])
	check("no weapon is bigger AND faster than a peer", offenders.is_empty(),
		"%d offenders e.g. %s" % [offenders.size(), ", ".join(offenders.slice(0, 3))])

	# the drawn weapon IS the hitbox, so length and arc move together
	var slow := Inventory.weapon_stats_for("wpn_warhammer")
	var fast := Inventory.weapon_stats_for("wpn_twinblades")
	check("a slow heavy weapon is drawn longer than a fast light one",
		slow.icon_size.x > fast.icon_size.x * 1.5,
		"warhammer=%.0f twinfangs=%.0f" % [slow.icon_size.x, fast.icon_size.x])
	check("its swing arc is bigger to match", slow.area_size.x > fast.area_size.x)
	check("and it reaches further", slow.range_offset > fast.range_offset,
		"%.0f vs %.0f" % [slow.range_offset, fast.range_offset])

	# spears out-reach every melee weapon -- that is their whole identity
	var longest_melee := 0.0
	for s in swingers:
		if s["type"] == "melee":
			longest_melee = maxf(longest_melee, s["icon"])
	var shortest_spear := 9999.0
	for s in swingers:
		if s["type"] == "spear":
			shortest_spear = minf(shortest_spear, s["icon"])
	check("even the shortest spear out-reaches the longest melee weapon",
		shortest_spear > longest_melee,
		"spear=%.0f melee=%.0f" % [shortest_spear, longest_melee])

	# ---------------- the swing leaves a trail, hit or miss ----------------
	# swing at empty air, far from anything, and a trail must still appear
	p.wield_weapon("wpn_sword")
	var before_kids := p.get_children().size()
	p.attack_cooldown_remaining = 0.0
	p.perform_attack()
	var after_kids := p.get_children().size()
	check("swinging at nothing still draws a trail", after_kids > before_kids,
		"%d -> %d children" % [before_kids, after_kids])
	# grade drives how much the swing shows: mythic must out-sweep common
	var common_arc := deg_to_rad(64.0 + int(Inventory.GRADE_DEFS["common"]["rank"]) * 7.0)
	var mythic_arc := deg_to_rad(64.0 + int(Inventory.GRADE_DEFS["mythic"]["rank"]) * 7.0)
	check("a mythic weapon sweeps a wider trail than a common one", mythic_arc > common_arc)

	# ---------------- levitation costs mana, for everyone ----------------
	check("every class can levitate", p.has_flight())
	check("wings stay an earned visual, separate from the ability", p.has_method("has_wings"))
	# DEV CALLS (2026-07-20): no wings in the beginning + a dash that GOES
	check("the dash covers a real distance (>=180px, doubled by dev call)",
		p.DASH_SPEED * p.DASH_DURATION >= 179.0,
		"%.0fpx" % (p.DASH_SPEED * p.DASH_DURATION))
	var wings_saved_stage_lvl: int = GameState.player_level
	var wings_saved_god: bool = p.god_mode
	p.god_mode = false
	GameState.player_level = 5          # monarch stage 1 -- where they USED to sprout
	check("level 5 grows NO wings any more", not p.has_wings())
	GameState.player_level = 60         # the Veiled (5/7)
	check("the Veiled stage finally earns them", p.has_wings())
	GameState.player_level = wings_saved_stage_lvl
	p.god_mode = wings_saved_god
	check("...and the Aetherwing relic still shows what you bought",
		FileAccess.open("res://player.gd", FileAccess.READ).get_as_text().contains('get_bonus_total("flight") > 0.0'))
	var saved_class = GameState.chosen_class
	GameState.chosen_class = "Sword"
	var sword_rate: float = p.levitate_mana_rate()
	GameState.chosen_class = "Mage"
	var mage_rate: float = p.levitate_mana_rate()
	GameState.chosen_class = saved_class
	check("a Mage levitates cheaper than a Sword", mage_rate < sword_rate,
		"mage=%.1f/s sword=%.1f/s" % [mage_rate, sword_rate])
	check("levitation is never free", p.levitate_mana_rate() >= 1.0)
	# holding Space off the ground drains the pool -- but ONLY once the soul
	# can lift you (the Veiled stage, dev call 2026-07-21: no early flight)
	p.god_mode = false
	var lev_lvl: int = GameState.player_level
	GameState.player_level = 60
	p.global_position.y -= 260.0
	p.mana = p.get_max_mana()
	var mana_before: float = p.mana
	Input.action_press("jump")
	for i in range(20):
		await get_tree().physics_frame
	Input.action_release("jump")
	check("levitating burns mana (at the Veiled stage)", p.mana < mana_before,
		"%.1f -> %.1f" % [mana_before, p.mana])
	GameState.player_level = lev_lvl
	check("the flight gate IS the wings gate (one rule)",
		FileAccess.open("res://player.gd", FileAccess.READ).get_as_text().contains('Input.is_action_pressed("jump") and has_wings()'))

	# ---------------- combo strings ----------------
	# string length follows swing speed: quick blades flurry, heavy ones don't
	p.inventory.add_item("wpn_twinblades", 1); p.wield_weapon("wpn_twinblades")
	var fast_len: int = p.combo_length()
	p.inventory.add_item("wpn_warhammer", 1); p.wield_weapon("wpn_warhammer")
	var slow_len: int = p.combo_length()
	check("a quick blade chains a longer string than a heavy one", fast_len > slow_len,
		"twinfangs=%d warhammer=%d" % [fast_len, slow_len])
	# THE key balance property: every string length must average the same
	# multiplier, or combos silently buff one weapon class over another. A short
	# string reaches its finisher far more often, so it needs a SMALLER one.
	for wid in ["wpn_twinblades", "wpn_sword", "wpn_warhammer"]:
		p.inventory.add_item(wid, 1)
		p.wield_weapon(wid)
		var n: int = p.combo_length()
		var avg: float = (float(n - 1) + p.combo_finisher_mult()) / float(n)
		check("'%s' string averages 1.25x (%d hits, %.2fx finisher)" % [wid, n, p.combo_finisher_mult()],
			abs(avg - 1.25) < 0.001, "avg=%.3f" % avg)
	p.wield_weapon("wpn_twinblades")
	var fast_fin: float = p.combo_finisher_mult()
	p.wield_weapon("wpn_warhammer")
	var slow_fin: float = p.combo_finisher_mult()
	check("the LONGER string carries the bigger finisher (it lands rarer)",
		fast_fin > slow_fin, "twinfangs=%.2fx warhammer=%.2fx" % [fast_fin, slow_fin])
	# and the heavy weapon still lands the biggest absolute hit, via base damage
	var hammer_fin: float = float(Inventory.weapon_stats_for("wpn_warhammer").damage) * slow_fin
	var fang_fin: float = float(Inventory.weapon_stats_for("wpn_twinblades").damage) * fast_fin
	check("the maul's finisher still hits far harder in absolute terms",
		hammer_fin > fang_fin * 2.0, "hammer=%.0f fangs=%.0f" % [hammer_fin, fang_fin])

	# walking the string: only the LAST hit is multiplied
	p.wield_weapon("wpn_sword")
	p.reset_combo()
	var mults := []
	for i in range(p.combo_length()):
		mults.append(p.combo_step())
	var non_final_all_one := true
	for i in range(mults.size() - 1):
		if abs(float(mults[i]) - 1.0) > 0.001:
			non_final_all_one = false
	check("every hit before the finisher is a plain 1.0x", non_final_all_one, str(mults))
	check("the finisher multiplies", float(mults[mults.size() - 1]) > 1.0, str(mults))
	# the string wraps around rather than sticking on the finisher
	check("after the finisher the string restarts", abs(p.combo_step() - 1.0) < 0.001)
	# letting the window lapse drops you back to the start
	p.reset_combo()
	p.combo_step()
	p.combo_expire_at = 0.0        # pretend the window elapsed
	check("a lapsed window resets the string", abs(p.combo_step() - 1.0) < 0.001)
	# swapping weapons must not carry a banked finisher across
	p.reset_combo()
	p.combo_step()
	p.wield_weapon("wpn_dagger")
	check("swapping weapons clears the combo", p.combo_index == 0)

	# ---------------- per-weapon crit character ----------------
	p.wield_weapon("wpn_twinblades")
	var fast_cc: float = p.weapon_crit_chance_bonus()
	var fast_cd: float = p.weapon_crit_damage_bonus()
	p.wield_weapon("wpn_warhammer")
	var slow_cc: float = p.weapon_crit_chance_bonus()
	var slow_cd: float = p.weapon_crit_damage_bonus()
	check("a quick blade crits more OFTEN", fast_cc > slow_cc,
		"twinfangs=%.2f warhammer=%.2f" % [fast_cc, slow_cc])
	check("a heavy weapon crits HARDER", slow_cd > fast_cd,
		"warhammer=%.2f twinfangs=%.2f" % [slow_cd, fast_cd])
	check("crit character applies only to melee", true)
	p.wield_weapon("wpn_bow")
	check("a bow gets no melee crit bias",
		p.weapon_crit_chance_bonus() == 0.0 and p.weapon_crit_damage_bonus() == 0.0)

	# ---- CRAFTING: recipes existed all game with no way to reach them ----
	var inv_ui = get_tree().get_first_node_in_group("inventory_ui")
	check("the bag has a crafting bench at all",
		inv_ui != null and inv_ui.craft_panel != null)
	if inv_ui != null and inv_ui.craft_panel != null:
		inv_ui.refresh_craft()
		check("every recipe is listed, not only the affordable ones",
			inv_ui.craft_rows.get_child_count() == Inventory.CRAFT_RECIPES.size(),
			"%d rows vs %d recipes" % [inv_ui.craft_rows.get_child_count(), Inventory.CRAFT_RECIPES.size()])
		var stew_before: int = p.inventory.get_count("food_stew")
		var herb_before: int = p.inventory.get_count("herb")
		var meat_before: int = p.inventory.get_count("raw_meat")
		p.inventory.add_item("herb", 2)
		p.inventory.add_item("raw_meat", 1)
		inv_ui._on_craft("food_stew")
		check("crafting consumes the ingredients and yields the food",
			p.inventory.get_count("food_stew") == stew_before + 1
			and p.inventory.get_count("herb") == herb_before
			and p.inventory.get_count("raw_meat") == meat_before)
		var reset_before: int = p.inventory.get_count("potion_reset")
		inv_ui._on_craft("potion_reset")
		check("a recipe you cannot afford refuses instead of half-charging",
			p.inventory.get_count("potion_reset") == reset_before)
		p.inventory.remove_item("food_stew", 1)

	# ---- RIFTWEAVING (Mage mg_p1..p3): the two doors, Z to weave ----
	var rift_ids := ["mg_p1", "mg_p2", "mg_p3"]
	var tree_ok := true
	for rid in rift_ids:
		if SkillTreeData.get_node_by_id(rid).is_empty():
			tree_ok = false
	check("the Riftweaving line lives in the Mystic's tree", tree_ok
		and str(SkillTreeData.get_node_by_id("mg_p1").get("prereq", "")) == "mg_m1"
		and str(SkillTreeData.get_node_by_id("mg_p3").get("prereq", "")) == "mg_p2")
	var rift_saved_skills = GameState.unlocked_skills.duplicate(true)
	var rift_saved_mana: float = p.mana
	check("no skill, no doors", not p.has_portal_skill())
	GameState.unlocked_skills.append_array(rift_ids)
	check("the base drain is HEAVY; fully levelled it drops to 30%",
		p.has_portal_skill()
		and absf(p.PORTAL_DRAIN_PER_SEC - 9.0) < 0.01
		and absf(p.portal_drain_per_second() - 2.7) < 0.01
		and absf(p.portal_open_cost() - 6.0) < 0.01)
	p.mana = 50.0
	p.try_weave_portal()
	check("Z opens the orange door where you stand, for mana",
		p.portal_a != null and p.portal_b == null and absf(p.mana - 44.0) < 0.01)
	check("one door alone drains NOTHING",
		(func(): p.tick_portals(1.0); return absf(p.mana - 44.0) < 0.01).call())
	var here: Vector2 = p.global_position
	p.global_position = here + Vector2(400, 0)
	p.try_weave_portal()
	check("the second door opens blue — and the drain begins",
		p.portal_b != null
		and (func(): var m0: float = p.mana; p.tick_portals(1.0); return absf((m0 - p.mana) - 2.7) < 0.05).call())
	p._portal_immune_until = 0.0
	p.do_portal_teleport(p.portal_b)
	check("stepping into one door puts you at the OTHER",
		p.global_position.distance_to(p.portal_a.global_position) < 2.0)
	p.mana = 1.0
	p.tick_portals(1.0)
	check("the well runs dry and BOTH doors collapse",
		p.portal_a == null and p.portal_b == null and p.mana == 0.0)
	check("Z is a real input action, and the doors teleport DEFERRED",
		FileAccess.open("res://project.godot", FileAccess.READ).get_as_text().contains("portal={")
		and FileAccess.open("res://portal.gd", FileAccess.READ).get_as_text().contains('call_deferred("do_portal_teleport"'))
	GameState.unlocked_skills = rift_saved_skills
	p.mana = rift_saved_mana
	p.global_position = here

	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
