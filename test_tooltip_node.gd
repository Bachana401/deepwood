extends Node

# TERRARIA-STYLE TOOLTIP (dev ask 2026-07-22) + the stall-price fix. Locks the
# item card's content: rarity name, white base stats, green "+" bonuses, gold
# specials, and an HONEST coin-gold sell value -- the same grade-scaled number
# the Marketplace stall now actually pays (it silently paid 4g for everything
# before, a grade-key vs grade-name lookup bug).

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	await get_tree().process_frame

	# ---- the value ladder is real again (grade -> gold), one source of truth ----
	check("a common weapon is worth the common price", Inventory.sell_value("wpn_sword") == 6, str(Inventory.sell_value("wpn_sword")))
	check("an uncommon piece is worth more", Inventory.sell_value("armor_leather") == 15, str(Inventory.sell_value("armor_leather")))
	check("a mythic blade is worth a fortune", Inventory.sell_value("exc_ragnarok") == 600, str(Inventory.sell_value("exc_ragnarok")))
	check("an ungraded material falls through to base", Inventory.sell_value("wood") == 4, str(Inventory.sell_value("wood")))
	var asrc := FileAccess.open("res://assign_ui.gd", FileAccess.READ).get_as_text()
	check("the stall prices through the shared sell_value (bug fixed)",
		asrc.contains("Inventory.sell_value(item_id)") and not asrc.contains("STALL_PRICES"))

	# ---- a mythic weapon card reads like Terraria ----
	# THE TOP RARITY'S NAME MUST CYCLE (dev reference clip, 2026-07-30).
	# Terraria colours the whole name one hue at a time and walks it round the
	# wheel; BBCode's [rainbow] stripes the spectrum across the letters instead,
	# which is a different effect. The custom [monarch] tag does the former --
	# but a tag nothing has INSTALLED renders as literal text, so the card would
	# read "[monarch]The Rumor[/monarch]". Both halves are checked.
	var mon_id := ""
	for wid_m in WeaponRoster.all_ids():
		if Inventory.get_grade(wid_m) == Inventory.MONARCH_GRADE:
			mon_id = str(wid_m)
			break
	check("a monarch weapon exists to test", mon_id != "")
	var mcard := Inventory.build_tooltip_bbcode(mon_id)
	check("a monarch name uses the cycling [monarch] tag", mcard.contains("[monarch]"))
	check("...and NOT the striped built-in [rainbow]", not mcard.contains("[rainbow]"))
	var tt_src := FileAccess.get_file_as_string("res://item_tooltip.gd")
	check("the tooltip INSTALLS the effect, or the tag prints as literal text",
		tt_src.contains("install_effect"))
	var fx_src := FileAccess.get_file_as_string("res://monarch_name_fx.gd")
	check("the effect answers to the same tag name the card emits",
		fx_src.contains('bbcode := "monarch"'))
	# the whole word must share one hue: a term derived from the character's
	# position would stripe it, which is the thing we are deliberately not doing
	# strip comments before scanning: the effect's own comment EXPLAINS that a
	# char_fx.range term would stripe the word, and a naive scan matched that
	# prose and failed the file for describing the mistake it avoids
	var fx_code := ""
	for fx_line in fx_src.split("\n"):
		var trimmed := str(fx_line).strip_edges()
		if trimmed.begins_with("#"):
			continue
		fx_code += str(fx_line).split("#")[0] + "\n"
	check("the cycle is driven by TIME alone, so the word stays one colour",
		fx_code.contains("elapsed_time") and not fx_code.contains("char_fx.range"))
	# a lower rarity must NOT cycle -- the whole point is that it marks the top
	check("a legendary name does not cycle",
		not Inventory.build_tooltip_bbcode("exc_dawnbreaker").contains("[monarch]"))

	var w := Inventory.build_tooltip_bbcode("exc_ragnarok")
	check("weapon card names the item big", w.contains("[font_size=16]") and w.contains(Inventory.get_display_name("exc_ragnarok")))
	check("weapon card shows a damage line", w.to_lower().contains("damage"))
	check("weapon card shows a speed word", w.to_lower().contains("speed"))
	# WAS: "weapon card paints while-wielded bonuses GREEN". That assertion
	# outlived the thing it described. GRADE_PASSIVES was emptied on 2026-07-30
	# (dev: "unnecessary stats -- delete all of it"), so no weapon grants a
	# while-wielded bundle any more and no card can print one. The check is
	# INVERTED rather than deleted: the green block coming back would mean the
	# stat bundle had crept back onto weapons, which is exactly what the dev
	# asked to be rid of.
	check("weapon card no longer prints a while-wielded stat block",
		not w.to_lower().contains("while wielded"))
	# ARMOUR still pays in stats -- that is the line we drew, and if this goes
	# quiet the budget has left the game rather than moved
	var arm := Inventory.build_tooltip_bbcode("armor_bulwark")
	check("armour cards still show their bonuses in green",
		arm.contains("#74d074"), "armour stopped paying")
	check("weapon card prints the coin-gold sell value", w.contains("#e8c24a") and w.contains("Sells for 600g"))
	check("weapon card dims the usage hint", w.contains("#71717c") and w.contains("hotbar"))

	# ---- a relic card: its power in gold, equip bonuses in green ----
	var r := Inventory.build_tooltip_bbcode("relic_phoenix")
	check("relic card shows a value and a category", r.contains("Sells for") and r.to_lower().contains("relic"))

	# ---- a consumable card: effect in green, base value ----
	var c := Inventory.build_tooltip_bbcode("food_stew")
	check("consumable card shows its effect", c.contains("#74d074"))
	check("consumable card is worth the base 4g", c.contains("Sells for 4g"))

	# ---- armour card: worth its grade, labelled as armour ----
	var a := Inventory.build_tooltip_bbcode("armor_leather")
	check("armour card labels the slot and grade", a.to_lower().contains("armor") and a.contains("Uncommon"))
	check("armour card is worth its grade", a.contains("Sells for 15g"))

	# ---- the renderer is BBCode in a RichTextLabel now, not a flat Label ----
	var tsrc := FileAccess.open("res://item_tooltip.gd", FileAccess.READ).get_as_text()
	check("the tooltip renders BBCode (rarity colours, green bonuses)",
		tsrc.contains("RichTextLabel") and tsrc.contains("bbcode_enabled") and tsrc.contains("build_tooltip_bbcode"))
	check("...and sizes the pixel box to its content", tsrc.contains("get_content_height"))

	printerr("test_tooltip : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails, "  (FAILs=%d)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
