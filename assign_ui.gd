extends CanvasLayer

var current_building: Node = null
var _draft_armed := ""   # the villager warned about, awaiting a second click

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
	_draft_armed = ""   # a pending draft warning must not survive the panel closing
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
	# repair prompt until it's back on its feet. (It CAN still be relocated --
	# plan the town before you raise it.)
	if current_building.is_ruined():
		add_repair_section(list)
		add_relocate_section(list)
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
	if current_building.role_key == "Marketplace":
		add_market_stall_section(list)
	add_relocate_section(list)

# THE MARKET STALL (numbers pass 2026-07-20): gear could never be SOLD --
# anywhere, by anyone. The Merchant Prince's boon auto-sells surplus
# MATERIALS only, so every outgrown sword and second pair of boots just
# clogged the bags and chests forever. The Marketplace is literally a
# market: staff a trader and the stalls buy your old gear at grade prices.
# The wielded weapon, worn gear, and the never-sold relics are not listed.
func add_market_stall_section(list: VBoxContainer) -> void:
	var header = Label.new()
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5, 1))
	header.text = "The Stalls — they buy what you've outgrown"
	list.add_child(header)
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	if GameState.count_workers("Marketplace") == 0:
		var idle = Label.new()
		idle.text = "  The stalls stand empty — staff a Trader and they will buy."
		idle.add_theme_font_size_override("font_size", 12)
		idle.add_theme_color_override("font_color", Color(0.7, 0.65, 0.6, 1))
		list.add_child(idle)
		return
	var listed := 0
	for slot in player.inventory.slots:
		if slot == null:
			continue
		var item_id := str(slot.item_id)
		var cat: String = Inventory.get_item_def(item_id).get("category", "")
		if not (cat in ["weapon", "armor", "relic"]):
			continue
		if item_id in GameState.WANDERER_NEVER_SOLD:
			continue          # some things are not for sale, ever
		# worn gear lives in GameState.equipment, outside the bag -- so a
		# bag copy is a true duplicate; only the blade in your hand is held
		if item_id == str(player.active_weapon_id):
			continue
		var price: int = Inventory.sell_value(item_id)   # grade-scaled, one source of truth
		var row = Button.new()
		row.text = "  Sell %s  [%s]  —  %dg" % [Inventory.get_display_name(item_id), Inventory.get_grade_name(item_id), price]
		row.custom_minimum_size = Vector2(0, 26)
		row.pressed.connect(_on_stall_sell.bind(item_id, price))
		list.add_child(row)
		listed += 1
	if listed == 0:
		var bare = Label.new()
		bare.text = "  Nothing in your bag the traders want today."
		bare.add_theme_font_size_override("font_size", 12)
		bare.add_theme_color_override("font_color", Color(0.7, 0.65, 0.6, 1))
		list.add_child(bare)

func _on_stall_sell(item_id: String, price: int) -> void:
	var player = get_tree().get_first_node_in_group("player")
	var notif = get_node_or_null("../CanvasLayer/NotificationStack")
	if player == null:
		return
	if player.inventory.get_count(item_id) <= 0:
		refresh()
		return
	player.inventory.remove_item(item_id, 1)
	player.add_currency(price)
	GameState.play_sfx(GameState.SFX_YES, 1.0)
	if notif:
		notif.show_notification("Sold %s for %dg." % [Inventory.get_display_name(item_id), price])
	refresh()

# MOVABLE BUILDINGS (5.2, dev decision): pack the building up, walk to the
# new ground, press H to plant it. Costs charge at the PLANT, so changing
# your mind is free.
func add_relocate_section(list: VBoxContainer) -> void:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 28)
	if GameState.moving_building == current_building.building_name:
		btn.text = "📦 Packed up — walk to the new ground and press H"
		btn.disabled = true
	else:
		btn.text = "📦 Relocate (%dg + %d wood at the plant)" % [GameState.RELOCATE_GOLD, GameState.RELOCATE_WOOD]
		# read the NAME FIRST: close() nulls current_building, so reading it after
		# the close threw ("Invalid access ... on a base object of type 'Nil'"),
		# the lambda aborted, and the one instruction the player ever gets about
		# H-to-plant was never shown -- while the building really was packed and
		# the Hospital/School/Marketplace H features had gone quiet.
		var bname := str(current_building.building_name)
		btn.pressed.connect(func():
			GameState.moving_building = bname
			close()
			var stack = get_tree().get_first_node_in_group("notification_stack")
			if stack:
				stack.show_notification("📦 The %s is packed. Walk to the new ground and press H to plant it." % bname))
	list.add_child(btn)

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
	# no "Press F" (audit fix): there is no F handler on a ruin -- building's
	# _process bails on is_ruined() before any key branch. The button below is
	# the one true path.
	info.text = "  The %s is being rebuilt in %d stages. Use the button below to raise the next stage; it opens for work only when fully built." % [b.building_name, total]
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
# boosts its output. The price squares with the level (30g for the first rung
# up to 750g for the last -- see building.upgrade_cost), so which building you
# grow, and when, is a real decision rather than a formality.
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
	# THE WHISPERSTONE (dev ask 2026-07-22): built once here, it lifts the away-fog
	# forever -- the village's live feed reaches you anywhere, the deep included.
	var ws_header = Label.new()
	ws_header.add_theme_font_size_override("font_size", 14)
	ws_header.add_theme_color_override("font_color", Color(0.55, 0.78, 0.96, 1))
	ws_header.text = "The Whisperstone"
	list.add_child(ws_header)
	if GameState.has_whisperstone:
		var built = Label.new()
		built.add_theme_font_size_override("font_size", 11)
		built.add_theme_color_override("font_color", Color(0.6, 0.85, 0.7, 1))
		built.text = "  Humming. Deepwood's news reaches you wherever you roam."
		list.add_child(built)
	else:
		var ws_btn = Button.new()
		ws_btn.text = "  Build the Whisperstone  (%s)" % GameState._cost_text(GameState.WHISPERSTONE_COST)
		ws_btn.custom_minimum_size = Vector2(0, 28)
		ws_btn.pressed.connect(_on_build_whisperstone)
		list.add_child(ws_btn)
		var ws_note = Label.new()
		ws_note.add_theme_font_size_override("font_size", 10)
		ws_note.add_theme_color_override("font_color", Color(0.6, 0.6, 0.66, 1))
		ws_note.text = "  Then the Log reaches you in the deep — no rune needed."
		list.add_child(ws_note)

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

func _on_build_whisperstone() -> void:
	var player = get_tree().get_first_node_in_group("player")
	var reason = GameState.try_build_whisperstone(player)
	var notif = get_tree().get_first_node_in_group("notification_stack")
	if notif:
		notif.show_notification(reason if reason != "" else "The Whisperstone hums to life — Deepwood can reach you anywhere now.")
	refresh()

func _on_research(item_id: String) -> void:
	# Grammar (5.1): the Lab's SERVICE is the scholar, not the bench -- an
	# empty lab identifies nothing (leaders auto-research on their own tick)
	var notif = get_tree().get_first_node_in_group("notification_stack")
	if GameState.count_workers("Science Lab") == 0 and GameState.seated_leaders("Science Lab") == 0:
		if notif:
			notif.show_notification("The bench sits cold — staff a Scientist at the Lab to identify materials.")
		return
	GameState.researched_materials.append(item_id)
	if notif:
		notif.show_notification("Research complete: it's " + Inventory.ITEM_DEFS[item_id].name + "! Usable in the skill tree now.")
	refresh()

# The Forge (Blacksmith) is Deepwood's reliable gear vendor: it stocks equippable
# gear of EVERY slot -- weapons of all types, helm/chest/pants, gloves, boots --
# but only up to Rare grade. The OP tiers (Epic+, set weapons, Excellents) stay
# dungeon-drop only, so the Forge fills gaps without spoiling the loot chase.
# Epic exists on the rack only with Toren at the anvil (see smithy_max_rank) --
# and it must be priced. The old table stopped at rare, so every Epic fell
# through to smithy_price's 40g default while the Marketplace stall PAYS 100g
# for an Epic: buy 40 / sell 100, an unbounded gold printer.
const SMITHY_PRICE_BY_GRADE = {"common": 25, "uncommon": 60, "rare": 130, "epic": 240}
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
		# Terraria-exact armor (2026-07-28): gloves/boots are RETIRED slots --
		# their surviving defs are bag curios and must never be SOLD as gear
		if cat == "armor" and str(def.get("slot", "")) in GameState.RETIRED_SLOTS:
			continue
		# SET pieces and set weapons stay dungeon-drop only at ANY rank -- Toren
		# raises the Forge's grade cap to Epic, not its exclusivity rules (the
		# file's own contract above). Without this, his boon put all three full
		# Epic sets and their set weapons on a reliable vendor rack.
		if def.has("set"):
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

# THE SEATS (dev 2026-07-24): a post is no longer a text roster but a row of
# square SEATS -- a filled seat wears its villager's icon, an empty seat is an
# open square. Below sits the BENCH of eligible villagers as icons; click one to
# drop them into the next open seat. All the assign/enroll/draft rules are
# unchanged -- only the presentation is (text lists -> icon squares).
const SEAT_SIZE := Vector2(46, 46)

func add_role_section(list: VBoxContainer, role_def: Dictionary) -> void:
	var holders = current_building.get_role_holders(role_def.title)
	var total: int = current_building.effective_slots(role_def)

	var header = Label.new()
	header.add_theme_font_size_override("font_size", 14)
	var req_text = ""
	if role_def.get("required_stat", "") != "":
		req_text = " [needs %s]" % role_def.required_stat
	elif role_def.get("is_enrollment", false):
		req_text = " [24 in-game hrs to graduate]"
	header.text = "%s  (%d/%d)%s" % [role_def.title, holders.size(), total, req_text]
	list.add_child(header)

	# the seats: one square per slot, filled first with the villagers on post
	var seats = HFlowContainer.new()
	seats.add_theme_constant_override("h_separation", 6)
	seats.add_theme_constant_override("v_separation", 6)
	for h in holders:
		seats.add_child(_villager_seat(h, false, role_def))
	for _i in range(maxi(total - holders.size(), 0)):
		seats.add_child(_empty_seat())
	list.add_child(seats)

	# the bench: eligible villagers as icons you can click into a seat
	var eligible = current_building.get_eligible_villagers(role_def)
	if eligible.is_empty():
		var none_label = Label.new()
		none_label.add_theme_font_size_override("font_size", 11)
		none_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		none_label.text = "  (full)" if current_building.is_role_full(role_def) else "  (no eligible villagers)"
		list.add_child(none_label)
	else:
		var bench_hint = Label.new()
		bench_hint.add_theme_font_size_override("font_size", 10)
		bench_hint.add_theme_color_override("font_color", Color(0.62, 0.62, 0.68, 1))
		bench_hint.text = "  Available — click to seat:"
		list.add_child(bench_hint)
		var bench = HFlowContainer.new()
		bench.add_theme_constant_override("h_separation", 6)
		bench.add_theme_constant_override("v_separation", 6)
		for villager in eligible:
			bench.add_child(_villager_seat(villager, true, role_def))
		list.add_child(bench)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	list.add_child(spacer)

# An open post: a plain "+" square, not clickable (you seat from the bench).
func _empty_seat() -> Control:
	var b = Button.new()
	b.custom_minimum_size = SEAT_SIZE
	b.text = "+"
	b.disabled = true
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.45, 0.52, 1))
	b.tooltip_text = "Open seat"
	_tint_seat(b, Color(0.18, 0.18, 0.22))
	return b

# One villager as a square icon: coloured by sex/age, stamped with their initial,
# full details on hover. `assignable` bench icons seat the villager on click;
# seated icons are shown disabled (display-only).
func _villager_seat(villager: Dictionary, assignable: bool, role_def: Dictionary) -> Control:
	var b = Button.new()
	b.custom_minimum_size = SEAT_SIZE
	var nm := str(villager.get("name", "?"))
	b.text = (nm.substr(0, 1).to_upper() if nm != "" else "?")
	b.add_theme_font_size_override("font_size", 18)
	var sex := str(villager.get("sex", ""))
	var is_kid: bool = villager.get("is_kid", false)
	var base := (Color(0.4, 0.5, 0.62) if sex == "Male" else Color(0.62, 0.44, 0.55))
	if is_kid:
		base = base.lightened(0.18)
	_tint_seat(b, base)
	b.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(0.95, 0.95, 0.95, 1))
	var age_text := ("Kid" if is_kid else "Adult")
	var stat_name := str(villager.get("stat_name", ""))
	var stat_text := (stat_name if stat_name != "" else "no stat")
	b.tooltip_text = "%s — %s, %s, %s" % [nm, (sex if sex != "" else "?"), age_text, stat_text]
	if assignable:
		b.tooltip_text += "\nClick to seat as %s" % role_def.title
		b.pressed.connect(_on_assign.bind(str(villager.get("id", "")), role_def))
	else:
		b.disabled = true
		b.tooltip_text += "\n(on post as %s)" % role_def.title
	return b

# Paint a seat square a solid colour across every button state (so filled seats
# keep their colour and don't grey out when shown disabled).
func _tint_seat(b: Button, col: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = (col.lightened(0.12) if state == "hover" else col)
		sb.corner_radius_top_left = 6
		sb.corner_radius_top_right = 6
		sb.corner_radius_bottom_left = 6
		sb.corner_radius_bottom_right = 6
		b.add_theme_stylebox_override(state, sb)

func _on_assign(villager_id: String, role_def: Dictionary) -> void:
	if not current_building:
		return
	var notif = get_node_or_null("../CanvasLayer/NotificationStack")
	if role_def.get("is_enrollment", false):
		# DRAFTING IS FOREVER (polish 2026-07-20): the Barracks deletes every
		# other profession a person has, permanently -- send a rescued Doctor
		# in and the Doctor is gone for good. That cannot be a single click.
		if current_building.role_key == "Barracks":
			var v: Dictionary = GameState.find_villager_by_id(villager_id)
			var had := str(v.get("stat_name", ""))
			if had != "" and had != "Warrior" and _draft_armed != villager_id:
				_draft_armed = villager_id
				if notif:
					notif.show_notification("⚠ Drafting %s DELETES their %s forever — they become a Warrior and nothing else. Click again to commit." % [
						str(v.get("name", "they")), had])
				return
		_draft_armed = ""
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
