extends Node

# THE TRUE ENDING (GAME_BIBLE 11/12) -- the Rewound Hour's two roads. Turn the
# glass and the world runs again (the existing prestige loop); or SHATTER it and
# break the cycle for good: no rewind, no new hourglass ever granted, the choice
# saved, and a true-ending beat that closes the whole story.

var fails := 0
func check(name: String, ok: bool, detail := "") -> void:
	if ok: printerr("PASS  ", name)
	else: fails += 1; printerr("FAIL  ", name, "   ", detail)

func _ready() -> void:
	for i in range(1200):
		await get_tree().process_frame
		if get_tree().get_first_node_in_group("player") != null: break
	get_tree().paused = false

	var saved_broken: bool = GameState.cycle_broken

	# ---- shattering breaks the cycle, and it stays broken ----
	GameState.cycle_broken = false
	GameState.break_the_cycle()
	check("shattering the hourglass breaks the cycle", GameState.cycle_broken)
	GameState.break_the_cycle()
	check("...and it is idempotent -- once broken, stays broken", GameState.cycle_broken)

	# ---- once broken, no victory ever hands out another hourglass ----
	var di := FileAccess.open("res://dungeon_interior.gd", FileAccess.READ).get_as_text()
	var hd := FileAccess.open("res://harvest_director.gd", FileAccess.READ).get_as_text()
	check("no new Rewound Hour is granted after the cycle is broken",
		di.contains('get_count("relic_rewound_hour") == 0 and not GameState.cycle_broken')
		and hd.contains('get_count("relic_rewound_hour") == 0 and not GameState.cycle_broken'))

	# ---- the broken cycle persists, and a fresh New Game clears it ----
	var gs := FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
	check("the broken cycle survives the save",
		gs.contains('"cycle_broken": cycle_broken') and gs.contains("cycle_broken = bool(parsed"))
	check("a fresh New Game starts the world whole again (cycle unbroken)",
		gs.contains("cycle_broken = false"))

	# ---- the true ending itself: spoken, and it lands the theme ----
	check("the true ending exists and is spoken in full", Story.TRUE_ENDING.size() >= 5)
	var whole := JSON.stringify(Story.TRUE_ENDING)
	check("...Ilo names the choice no crown ever made", whole.contains("Ilo"))
	check("...and it closes on the Monarch choosing to stay",
		str(Story.TRUE_ENDING[-1].get("text", "")).to_lower().contains("staying home"))

	# ---- the two-road prompt opens, offers the choices, and dismisses ----
	ChoicePrompt.open(self, "⌛ THE REWOUND HOUR", "Turn it, or shatter it?",
		[{"label": "Turn it", "cb": func(): return},
		 {"label": "Shatter it", "danger": true, "cb": func(): return},
		 {"label": "Not yet", "cb": func(): return}])
	await get_tree().process_frame
	var cp := get_tree().get_first_node_in_group("choice_prompt")
	check("the two-road choice opens and pauses the world", cp != null and get_tree().paused)
	var btns := 0
	if cp != null:
		for n in cp.find_children("*", "Button", true, false):
			btns += 1
	check("...and lays out the roads as buttons", btns >= 3, str(btns))
	if cp != null:
		cp.esc_close()
	await get_tree().process_frame
	check("...and closing it lets the world run again", not get_tree().paused)

	# ---- the player wires the item's use to the two roads ----
	var pl := FileAccess.open("res://player.gd", FileAccess.READ).get_as_text()
	check("using the Rewound Hour opens the turn-or-shatter choice",
		pl.contains("_open_hourglass_choice") and pl.contains("ChoicePrompt.open"))
	check("turn rewinds; shatter breaks the cycle and plays the true ending",
		pl.contains("GameState.new_game_plus(self)")
		and pl.contains("GameState.break_the_cycle(self)")
		and pl.contains("Story.TRUE_ENDING"))
	check("...and shattering is a doubled, deliberate yes",
		pl.contains("_confirm_shatter_hourglass"))

	# ---- restore ----
	GameState.cycle_broken = saved_broken
	get_tree().paused = false
	printerr("RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
