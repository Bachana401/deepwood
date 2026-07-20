extends CanvasLayer

var current_building: Node = null

func _ready() -> void:
	visible = false
	add_to_group("esc_window")
	$Panel/CloseButton.pressed.connect(close)

func open_for_building(building: Node) -> void:
	current_building = building
	visible = true
	refresh()

func close() -> void:
	current_building = null
	visible = false

func esc_is_open() -> bool:
	return visible

func esc_close() -> void:
	close()

func refresh() -> void:
	var list = $Panel/ScrollContainer/VBoxContainer
	for child in list.get_children():
		child.queue_free()

	if not current_building:
		return
	$Panel/TitleLabel.text = "%s  (Lv %d)" % [current_building.building_name, current_building.building_level]

	# A ruined building can't be used or upgraded -- only repaired. Show just the
	# repair prompt until it's back on its feet.
	if current_building.is_ruined():
		add_repair_section(list)
		return

	add_upgrade_section(list)
	for role_def in current_building.get_roles():
		add_role_section(list, role_def)
	if current_building.role_key == "Science Lab":
		add_research_section(list)
	if current_building.role_key == "Blacksmith":
		add_smithy_section(list)
	if current_building.role_key == "Barracks":
		add_armory_section(list)

# Shown while a building is being raised: it takes several construction stages,
# each costing one material bundle and playing a build animation.
func add_repair_section(list: VBoxContainer) -> void:
	var b = current_building
	var total = GameState.TOTAL_BUILD_STAGES
	var header = Label.new()
	header.add_theme_font_size_override("font_size", 15)
	header.add_theme_color_override("font_color", Color(0.92, 0.55, 0.32, 1))
	header.text = "Under construction — stage %d / %d" % [b.build_stage, total]
	list.add_child(header)

	var info = Label.new()
	info.add_theme_font_size_override("font_size", 11)
	info.add_theme_color_override("font_color", Color(0.82, 0.8, 0.72, 1))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.custom_minimum_size = Vector2(300, 0)
	info.text = "  The %s is being rebuilt in %d stages. Press F here (or the button below) to raise the next stage; it opens for work only when fully built." % [b.building_name, total]
	list.add_child(info)

	var cost = Label.new()
	cost.add_theme_font_size_override("font_size", 12)
	cost.add_theme_color_override("font_color", Color(0.75, 0.85, 0.75, 1))
	cost.text = "  Each stage needs: " + b.repair_requirement_text()
	list.add_child(cost)

	# The Forge is a mid-game unlock -- gate its construction behind dungeon depth.
	var forge_locked = b.role_key == "Blacksmith" and not GameState.blacksmith_unlocked()
	if forge_locked:
		var lock = Label.new()
		lock.add_theme_font_size_override("font_size", 12)
		lock.add_theme_color_override("font_color", Color(0.95, 0.5, 0.45, 1))
		lock.autowrap_mode = TextServer.AUTOWRAP_WORD
		lock.custom_minimum_size = Vector2(300, 0)
		lock.text = "  🔒 The Forge can only be raised once you've braved the deep — clear your way to dungeon Lv %d (open to you now: Lv %d)." % [GameState.BLACKSMITH_UNLOCK_DEPTH, GameState.highest_unlocked_level]
		list.add_child(lock)

	var btn = Button.new()
	btn.text = "  Build stage %d / %d" % [b.build_stage + 1, total]
	btn.custom_minimum_size = Vector2(0, 32)
	if b.constructing:
		btn.text = "  Building..."
		btn.disabled = true
	elif forge_locked:
		btn.text = "  🔒 Locked until dungeon Lv %d" % GameState.BLACKSMITH_UNLOCK_DEPTH
		btn.disabled = true
	btn.pressed.connect(_on_repair)
	list.add_child(btn)

func _on_repair() -> void:
	var player = get_tree().get_first_node_in_group("player")
	var notif = get_tree().get_first_node_in_group("notification_stack")
	if not current_building or not player:
		return
	var result = current_building.try_build(player)
	if result == "ok" and notif:
		if current_building.build_stage >= GameState.TOTAL_BUILD_STAGES:
			notif.show_notification("%s fully built! Its roles are open now." % current_building.building_name)
		else:
			notif.show_notification("%s -- building... (stage %d/%d)" % [current_building.building_name, current_building.build_stage, GameState.TOTAL_BUILD_STAGES])
	elif result == "materials" and notif:
		notif.show_notification("Not enough materials -- need: " + ", ".join(current_building.missing_repair_materials(player)))
	elif result == "locked" and notif:
		notif.show_notification("The Forge can't be raised yet -- reach dungeon Lv %d first." % GameState.BLACKSMITH_UNLOCK_DEPTH)
	refresh()

# Level + upgrade control. Upgrading grows the building, adds worker slots, and
# boosts its output. Flat 1 gold for now (test values).
func add_upgrade_section(list: VBoxContainer) -> void:
	var b = current_building
	var header = Label.new()
	header.add_theme_font_size_override("font_size", 14)
	header.text = "Level %d / %d" % [b.building_level, b.MAX_LEVEL]
	list.add_child(header)

	var info = Label.new()
	info.add_theme_font_size_override("font_size", 11)
	info.add_theme_color_override("font_color", Color(0.72, 0.82, 0.72, 1))
	var out_pct = int(round((GameState.building_output_multiplier(b.building_name) - 1.0) * 100.0))
	info.text = "  +%d worker slots · +%d%% output at this level" % [(b.building_level - 1) * b.SLOTS_PER_LEVEL, out_pct]
	list.add_child(info)

	if b.building_level >= b.MAX_LEVEL:
		var maxed = Label.new()
		maxed.add_theme_font_size_override("font_size", 11)
		maxed.add_theme_color_override("font_color", Color(0.85, 0.8, 0.5, 1))
		maxed.text = "  Fully upgraded."
		list.add_child(maxed)
	else:
		var btn = Button.new()
		btn.text = "  Upgrade to Level %d  —  %d gold" % [b.building_level + 1, b.upgrade_cost()]
		btn.custom_minimum_size = Vector2(0, 28)
		btn.pressed.connect(_on_upgrade)
		list.add_child(btn)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	list.add_child(spacer)

func _on_upgrade() -> void:
	var player = get_tree().get_first_node_in_group("player")
	var notif = get_tree().get_first_node_in_group("notification_stack")
	if not current_building or not player:
		return
	var result = current_building.try_upgrade(player)
	if result == "ok":
		if notif:
			notif.show_notification("%s upgraded to Level %d!" % [current_building.building_name, current_building.building_level])
	elif result == "gold" and notif:
		notif.show_notification("Not enough gold to upgrade (need %d)." % current_building.upgrade_cost())
	elif result == "ruined" and notif:
		notif.show_notification("Rebuild this ruined building before upgrading it.")
	refresh()

# The Science Lab doubles as the material-research bench: any skill-tree
# material the player is carrying that hasn't been identified yet can be
# researched here, which reveals its real name and lets skill nodes spend it.
func add_research_section(list: VBoxContainer) -> void:
	var header = Label.new()
	header.add_theme_font_size_override("font_size", 14)
	header.text = "Research"
	list.add_child(header)
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var found_any = false
	for item_id in Inventory.ITEM_DEFS.keys():
		if not Inventory.ITEM_DEFS[item_id].get("is_material", false):
			continue
		if GameState.researched_materials.has(item_id):
			continue
		if player.inventory.get_count(item_id) <= 0:
			continue
		found_any = true
		var row = Button.new()
		row.text = "  Research Unknown Substance (x%d held)" % player.inventory.get_count(item_id)
		row.custom_minimum_size = Vector2(0, 28)
		row.pressed.connect(_on_research.bind(item_id))
		list.add_child(row)
	if not found_any:
		var none_label = Label.new()
		none_label.add_theme_font_size_override("font_size", 11)
		none_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		none_label.text = "  (no unidentified materials in your inventory)"
		list.add_child(none_label)

func _on_research(item_id: String) -> void:
	GameState.researched_materials.append(item_id)
	var notif = get_tree().get_first_node_in_group("notification_stack")
	if notif:
		notif.show_notification("Research complete: it's " + Inventory.ITEM_DEFS[item_id].name + "! Usable in the skill tree now.")
	refresh()

# The Forge (Blacksmith) is Deepwood's reliable gear vendor: it stocks equippable
# gear of EVERY slot -- weapons of all types, helm/chest/pants, gloves, boots --
# but only up to Rare grade. The OP tiers (Epic+, set weapons, Excellents) stay
# dungeon-drop only, so the Forge fills gaps without spoiling the loot chase.
const SMITHY_PRICE_BY_GRADE = {"common": 25, "uncommon": 60, "rare": 130}
const SMITHY_MAX_RANK = 3   # rare (see Inventory.GRADE_DEFS ranks)

# Every equippable item at or below the Forge's tier cap, tidy-sorted (grade,
# then name). Base starter kit + admin + all OP tiers are excluded by design.
# Toren Ashvale, the Forgefather (the Ten): with him at the anvil the Forge
# sells one grade higher -- Epic joins the rack.
func smithy_max_rank() -> int:
	return SMITHY_MAX_RANK + 1 if GameState.ten_freed("ten_toren") else SMITHY_MAX_RANK

func smithy_stock() -> Array:
	var base_kit = {"wpn_sword": true, "wpn_spear": true, "wpn_bow": true, "wpn_wand": true}
	var out := []
	for id in Inventory.ITEM_DEFS.keys():
		var def = Inventory.ITEM_DEFS[id]
		var cat = str(def.get("category", ""))
		if cat != "armor" and cat != "weapon":
			continue
		if base_kit.has(id) or id == "wpn_admin_ruin" or def.get("excellent", false):
			continue
		var grade = Inventory.get_grade(id)
		if not Inventory.GRADE_DEFS.has(grade) or int(Inventory.GRADE_DEFS[grade].rank) > smithy_max_rank():
			continue
		out.append(id)
	out.sort_custom(func(a, b):
		var ra = int(Inventory.GRADE_DEFS[Inventory.get_grade(a)].rank)
		var rb = int(Inventory.GRADE_DEFS[Inventory.get_grade(b)].rank)
		if ra != rb:
			return ra < rb
		return str(Inventory.ITEM_DEFS[a].name) < str(Inventory.ITEM_DEFS[b].name))
	return out

func smithy_price(item_id: String) -> int:
	return int(SMITHY_PRICE_BY_GRADE.get(Inventory.get_grade(item_id), 40))

func add_smithy_section(list: VBoxContainer) -> void:
	var header = Label.new()
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.95, 0.7, 0.4, 1))
	header.text = "The Forge — buy gear (up to %s)" % ("Epic" if GameState.ten_freed("ten_toren") else "Rare")
	list.add_child(header)
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	for item_id in smithy_stock():
		var price = smithy_price(item_id)
		var grade_name = Inventory.get_grade_name(item_id)
		var row = Button.new()
		row.text = "  %s  [%s]  —  %dg" % [Inventory.get_display_name(item_id), grade_name, price]
		row.custom_minimum_size = Vector2(0, 26)
		row.add_theme_color_override("font_color", Inventory.get_grade_color(item_id))
		row.pressed.connect(_on_buy_gear.bind(item_id, price))
		list.add_child(row)

func _on_buy_gear(item_id: String, price: int) -> void:
	var player = get_tree().get_first_node_in_group("player")
	var notif = get_tree().get_first_node_in_group("notification_stack")
	if not player:
		return
	if player.currency < price:
		if notif:
			notif.show_notification("Not enough gold for %s (need %dg, have %dg)." % [Inventory.get_display_name(item_id), price, player.currency])
		return
	if player.inventory.add_item(item_id, 1) > 0:   # >0 leftover == couldn't fit
		if notif:
			notif.show_notification("Your bag is full.")
		return
	player.currency -= price
	if player.has_method("update_currency_display"):
		player.update_currency_display()
	if notif:
		notif.show_notification("Forged: %s." % Inventory.get_display_name(item_id))
	refresh()

# The Barracks armory: warriors fight far harder once ARMED. Early game the
# player hand-carries spare weapons/armor here to stock it; once a Forgemaster
# is employed at the Blacksmith, his smiths keep it filled automatically.
func add_armory_section(list: VBoxContainer) -> void:
	var header = Label.new()
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.85, 0.6, 0.5, 1))
	header.text = "Armory — arm your warriors"
	list.add_child(header)

	var status = Label.new()
	status.add_theme_font_size_override("font_size", 12)
	status.add_theme_color_override("font_color", Color(0.8, 0.85, 0.8, 1))
	status.text = "  Armed: %d / %d warriors   (arms in store: %d)" % [GameState.armed_warriors(), GameState.warrior_count(), GameState.barracks_arms]
	list.add_child(status)

	var note = Label.new()
	note.add_theme_font_size_override("font_size", 11)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	note.custom_minimum_size = Vector2(300, 0)
	if GameState.forgemaster_supplying():
		note.add_theme_color_override("font_color", Color(0.55, 0.85, 0.55, 1))
		note.text = "  🔨 The Forgemaster's smiths are delivering arms automatically — no need to haul gear here anymore."
	else:
		note.add_theme_color_override("font_color", Color(0.75, 0.7, 0.6, 1))
		note.text = "  Bring spare weapons & armor here to arm the warriors. (Employ a Forgemaster at the Blacksmith to automate this.)"
	list.add_child(note)

	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var found = false
	for item_id in Inventory.ITEM_DEFS.keys():
		var cat = str(Inventory.ITEM_DEFS[item_id].get("category", ""))
		if cat != "weapon" and cat != "armor":
			continue
		var held = player.inventory.get_count(item_id)
		if held <= 0:
			continue
		found = true
		var row = Button.new()
		row.text = "  Give %s  (x%d)  →  +%d arms" % [Inventory.get_display_name(item_id), held, GameState.arm_value_of(item_id)]
		row.custom_minimum_size = Vector2(0, 26)
		row.add_theme_color_override("font_color", Inventory.get_grade_color(item_id))
		row.pressed.connect(_on_deposit_arm.bind(item_id))
		list.add_child(row)
	if not found:
		var none_label = Label.new()
		none_label.add_theme_font_size_override("font_size", 11)
		none_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		none_label.text = "  (no spare weapons or armor in your bag to donate)"
		list.add_child(none_label)

func _on_deposit_arm(item_id: String) -> void:
	var player = get_tree().get_first_node_in_group("player")
	var notif = get_tree().get_first_node_in_group("notification_stack")
	if not player:
		return
	var added = GameState.deposit_one_arm(player, item_id)
	if notif:
		if added > 0:
			notif.show_notification("Armed the warriors with %s (+%d arms)." % [Inventory.get_display_name(item_id), added])
		else:
			notif.show_notification("The armory is full.")
	refresh()

func add_role_section(list: VBoxContainer, role_def: Dictionary) -> void:
	var holders = current_building.get_role_holders(role_def.title)

	var header = Label.new()
	header.add_theme_font_size_override("font_size", 14)
	var req_text = ""
	if role_def.get("required_stat", "") != "":
		req_text = " [needs %s]" % role_def.required_stat
	elif role_def.get("is_enrollment", false):
		req_text = " [24 in-game hrs to graduate]"
	header.text = "%s (%d/%d)%s" % [role_def.title, holders.size(), current_building.effective_slots(role_def), req_text]
	list.add_child(header)

	if not holders.is_empty():
		var holder_names = []
		for h in holders:
			holder_names.append(str(h.get("name", "?")))
		var holder_label = Label.new()
		holder_label.add_theme_font_size_override("font_size", 11)
		holder_label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.75, 1))
		holder_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		holder_label.text = "  Currently: " + ", ".join(holder_names)
		list.add_child(holder_label)

	var eligible = current_building.get_eligible_villagers(role_def)
	if eligible.is_empty():
		var none_label = Label.new()
		none_label.add_theme_font_size_override("font_size", 11)
		none_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		none_label.text = "  (full)" if current_building.is_role_full(role_def) else "  (no eligible villagers)"
		list.add_child(none_label)
	else:
		for villager in eligible:
			var row = Button.new()
			var age_text = "Kid" if villager.get("is_kid", false) else "Adult"
			var stat_text = villager.get("stat_name", "") if villager.get("stat_name", "") != "" else "no stat"
			row.text = "  Assign %s (%s, %s, %s)" % [villager.get("name", "?"), villager.get("sex", "?"), age_text, stat_text]
			row.custom_minimum_size = Vector2(0, 28)
			row.pressed.connect(_on_assign.bind(villager.get("id", ""), role_def))
			list.add_child(row)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	list.add_child(spacer)

func _on_assign(villager_id: String, role_def: Dictionary) -> void:
	if not current_building:
		return
	var notif = get_node_or_null("../CanvasLayer/NotificationStack")
	if role_def.get("is_enrollment", false):
		GameState.enroll_villager(villager_id, current_building.role_key, role_def.title, role_def.get("grants_stat", "random"))
		if notif:
			notif.show_notification("Enrolled as " + role_def.title + "! Check back in 24 in-game hours.")
	else:
		if GameState.assign_villager_to_role(villager_id, current_building.role_key, role_def.title):
			if notif:
				notif.show_notification("Assigned as " + role_def.title + " at " + current_building.building_name + "!")
		elif notif:
			notif.show_notification("Only the rightful figure can hold the post of " + role_def.title + ".")
	refresh()
