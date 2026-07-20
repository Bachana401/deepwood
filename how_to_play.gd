extends CanvasLayer

# HOW TO PLAY -- the controls and the laws, one readable page, opened from
# the pause menu (both scenes get it for free, same as the Chronicle). The
# game grew DEEP: fog, watches, wages, rot, rifts -- toasts alone can't
# teach it. Design bar mirrors the Village Log: plain words, no walls.

const SECTIONS = [
	["MOVE & FIGHT", [
		["A / D", "walk;  SPACE jump (double-jump once bought);  double-tap A/D to dash (once bought)"],
		["Mouse", "your cursor AIMS: left-click swings/shoots toward it (combos chain, finishers hit harder)"],
		["Right-click", "your weapon's special attack, when it has one"],
		["1 – 0", "the hotbar: weapons and potions"],
		["Z", "Mage only, with Riftweaving: open the orange rift, then the blue one elsewhere; step in one, exit the other. Mana drains while both stand."],
	]],
	["THE VILLAGE", [
		["E", "talk / rescue / open a building's assign panel / turn in a bond"],
		["F", "at a ruin: pay gold + materials to raise its next construction stage"],
		["H", "the hands-on key: tend the Farm, get treated at the Hospital (12g), open the Wanderer's Post, steer the School's curriculum (level 2+)"],
		["Tab", "your bag and the village overlay (morale meter lives here, once the town is whole)"],
		["L", "THE VILLAGE LOG -- the town's diary. Everything that happened while you were away is written here."],
		["K", "the skill tree (your class is chosen here, once)"],
		["G", "plant a standing torch (wood + resin)"],
	]],
	["THE DEEP", [
		["F at the red zone", "the level select -- clearing a floor unlocks the next; every 5th is a boss"],
		["Sorrow-Crystals", "the taken hang frozen in crystals. Kill the pocket's guard, shatter the crystal (E) -- their talents stay hidden until they thaw at home."],
		["Blue gate", "always retreats a level (works mid-fight);  green gate advances once the floor is clear"],
		["Potions", "drop ONLY on the two floors before each boss, and every felled boss leaves a cache -- there is no potion-spam"],
	]],
	["THE LAWS", [
		["No free healing", "nothing regenerates. The Doctor (price climbs each same-day heal), the staffed Hospital ward, lifesteal, potions -- that's the whole list."],
		["Distance is ignorance", "away from the village you learn NOTHING of it -- no meter, no news. Come home and read the Log... or play Mage and learn Telepathy."],
		["Everyone is paid", "workers draw wages daily from YOUR purse. An empty purse means they quit, by name."],
		["Hope is the resource", "every villager carries their own spirit. Feed them, employ them, pair them, house them -- a spirit at zero ROTS, and rot untended turns them into the thing at your gates."],
		["The watches", "warriors split into Dawn and Dusk shifts. Only the on-shift answers a siege horn; the off-shift heals. Sieges hit BOTH gates."],
		["Foresight is earned", "no siege countdown exists until the Watchtower stands (a plot inside the west gate). Three tiers: 1h, 2h, a full day."],
	]],
]

var panel: Panel = null

func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("esc_window")
	add_to_group("how_to_play")
	panel = Panel.new()
	panel.visible = false
	panel.position = Vector2(180, 40)
	panel.size = Vector2(800, 560)
	add_child(panel)
	var title := Label.new()
	title.text = "HOW TO PLAY"
	title.add_theme_font_size_override("font_size", 20)
	title.position = Vector2(18, 8)
	panel.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(18, 38)
	scroll.size = Vector2(764, 508)
	panel.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.custom_minimum_size = Vector2(744, 0)
	rows.add_theme_constant_override("separation", 5)
	scroll.add_child(rows)
	for section in SECTIONS:
		var head := Label.new()
		head.text = str(section[0])
		head.add_theme_font_size_override("font_size", 15)
		head.add_theme_color_override("font_color", Color(0.9, 0.8, 0.55, 1.0))
		rows.add_child(head)
		for entry in section[1]:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			var key := Label.new()
			key.text = str(entry[0])
			key.custom_minimum_size = Vector2(130, 0)
			key.add_theme_font_size_override("font_size", 13)
			key.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95, 1.0))
			key.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			row.add_child(key)
			var what := Label.new()
			what.text = str(entry[1])
			what.add_theme_font_size_override("font_size", 13)
			what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			what.custom_minimum_size = Vector2(590, 0)
			row.add_child(what)
			rows.add_child(row)
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 8)
		rows.add_child(gap)

func esc_is_open() -> bool:
	return panel.visible

func esc_close() -> void:
	panel.visible = false

func open_page() -> void:
	panel.visible = true
