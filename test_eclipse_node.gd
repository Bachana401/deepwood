extends Node
# THE ECLIPSE + THE HOLLOW SUN (dev design 2026-08-06).
#
# The dev asked for a sky that goes wrong -- the moon takes the sun whole, the
# world drops to black silhouette under one hot red ring -- and for an item raised
# in that hour to call the hardest fight in Deepwood down onto the village floor.
#
# Three dev rulings this pins, because each one is easy to quietly break later:
#
#   1. RARE, BUT NEVER MISSABLE. 3% a day, never inside a 7-day cooldown. Miss one
#      and you have lost THIS one and nothing else -- another always comes. A
#      once-a-campaign spectacle must not be a once-a-campaign punishment, because
#      the fight is brutal AND it spawns on your village, so a single attempt would
#      mean risking the whole settlement on one roll of the sky.
#   2. IT IS NOT THE DAILY CROSSING. Nihil's older Duskmoon rite reads sun-and-moon-
#      both-up, which happens twice every single day. These two gates must never be
#      confused or the hardest boss in the game becomes a dusk chore.
#   3. IT BEGINS AT DAWN. Rolled at midnight and started on the spot, there would be
#      no sun in the sky to take -- no ring, nothing to look at. Snapped to sunrise,
#      the twelve hours land exactly on the daylight span.

var fails := 0
func check(n: String, ok: bool, d := "") -> void:
	if ok: printerr("PASS  ", n)
	else: fails += 1; printerr("FAIL  ", n, "   ", d)

func _ready() -> void:
	var p: Node = null
	for i in range(600):
		if get_tree().paused: get_tree().paused = false
		await get_tree().process_frame
		p = get_tree().get_first_node_in_group("player")
		if p != null: break
	if p == null: printerr("no player"); get_tree().quit(1); return
	for n in get_tree().get_nodes_in_group("dialogue_box"):
		if n.has_method("finish") and n.has_method("show_line"): n.finish()
	if get_tree().paused: get_tree().paused = false

	var s_hours: float = GameState.game_hours
	var s_at: float = GameState.eclipse_at_hours
	var s_seen: int = GameState.eclipses_seen

	# ---------------- the schedule ----------------
	GameState.eclipse_at_hours = -1.0
	GameState.eclipses_seen = 0
	check("a fresh game is not under an eclipse", not GameState.eclipse_is_active())
	check("and nothing is pending", not GameState.eclipse_is_pending())
	check("the sky draws nothing when there is nothing to draw",
		is_equal_approx(GameState.eclipse_progress(), 0.0), str(GameState.eclipse_progress()))

	# It arrives on its own, and it KEEPS arriving -- the not-missable ruling. At 3%
	# a day with a 7-day floor between them, a long stretch must produce several.
	var seen_starts: Array[float] = []
	for day in range(4000):
		GameState.tick_eclipse(24.0)
		GameState.game_hours += 24.0
		if GameState.eclipse_at_hours > 0.0 and not seen_starts.has(GameState.eclipse_at_hours):
			seen_starts.append(GameState.eclipse_at_hours)
	check("over a long campaign the sky goes wrong more than once (never missable)",
		seen_starts.size() >= 3, "%d in 4000 days" % seen_starts.size())

	# never twice in a row: every gap clears the cooldown AND the eclipse itself
	var min_gap := 1e9
	for i in range(1, seen_starts.size()):
		min_gap = minf(min_gap, seen_starts[i] - seen_starts[i - 1])
	var floor_gap: float = GameState.ECLIPSE_COOLDOWN_DAYS * 24.0 + GameState.ECLIPSE_DURATION_HOURS
	check("no two eclipses fall inside the cooldown",
		seen_starts.size() < 2 or min_gap >= floor_gap, "min gap %.1fh, floor %.1fh" % [min_gap, floor_gap])

	# ---------------- it always opens at dawn ----------------
	var bad_hour := []
	for st in seen_starts:
		var tod: float = fposmod(GameState.START_TIME_OF_DAY + st, 24.0)
		if not is_equal_approx(tod, GameState.ECLIPSE_START_HOUR):
			bad_hour.append(tod)
	check("every eclipse opens at sunrise, never in the dead of night",
		bad_hour.is_empty(), str(bad_hour))

	# ---------------- the shape of the thing ----------------
	GameState.game_hours = 5000.0
	GameState.eclipse_at_hours = 5000.0
	check("first contact: the eclipse is on", GameState.eclipse_is_active())
	check("and the sky has barely begun to move",
		GameState.eclipse_progress() < 0.05, str(GameState.eclipse_progress()))
	GameState.game_hours = 5000.0 + GameState.ECLIPSE_DURATION_HOURS * 0.5
	check("totality is the peak", is_equal_approx(GameState.eclipse_progress(), 1.0),
		str(GameState.eclipse_progress()))
	GameState.game_hours = 5000.0 + GameState.ECLIPSE_DURATION_HOURS * 0.99
	check("it lets the sun go at the end", GameState.eclipse_progress() < 0.1,
		str(GameState.eclipse_progress()))
	GameState.game_hours = 5000.0 + GameState.ECLIPSE_DURATION_HOURS + 1.0
	check("and then it is over", not GameState.eclipse_is_active())
	check("the sky is clean again", is_equal_approx(GameState.eclipse_progress(), 0.0))

	# ---------------- announced, and counted once ----------------
	GameState.game_hours = 6000.0
	GameState.eclipse_at_hours = 6000.0
	GameState._eclipse_announced = false
	GameState.eclipses_seen = 0
	for i in range(6):
		GameState.tick_eclipse(0.5)
	check("it announces itself exactly ONCE, not every tick",
		GameState.eclipses_seen == 1, str(GameState.eclipses_seen))

	# ---------------- the gate ----------------
	# THE WHOLE POINT: this is not the twice-daily crossing.
	check("a true eclipse is not the same question as sun-and-moon-both-up",
		FileAccess.open("res://game_state.gd", FileAccess.READ).get_as_text()
			.contains("require_true_eclipse"))
	GameState.game_hours = 6000.0
	GameState.eclipse_at_hours = 6000.0
	check("during an eclipse, the gate opens", GameState.is_true_eclipse())
	GameState.eclipse_at_hours = -1.0
	check("on any ordinary day, it does not", not GameState.is_true_eclipse())

	# the Signet is refused OUT of the hour, and the item is NOT spent
	var refused: String = GameState.summon_event_boss("hollowsun", 0.0, false, true)
	check("raising the Signet under an ordinary sky is refused", refused != "", refused)
	check("...and the refusal does not tell you how (it stays a secret)",
		not refused.to_lower().contains("eclipse"), refused)

	# ---------------- the item ----------------
	var sig: Dictionary = Inventory.ITEM_DEFS.get("hollow_signet", {})
	check("the Hollow Signet exists", not sig.is_empty())
	var eff: Dictionary = sig.get("use_effect", {})
	check("it summons the Hollow Sun", str(eff.get("summon_event", "")) == "hollowsun")
	check("and it reads the TRUE eclipse, not the daily crossing",
		bool(eff.get("true_eclipse", false)) and not bool(eff.get("eclipse", false)))
	check("player.use_item actually forwards that flag (a named gate nothing reads is a lie)",
		FileAccess.open("res://player.gd", FileAccess.READ).get_as_text()
			.contains('eff.get("true_eclipse"'))

	# ---------------- the boss ----------------
	var ev: Dictionary = EventBoss.get_event("hollowsun")
	check("the Hollow Sun is a registered event", not ev.is_empty())
	check("it is item-only -- it can never wander in on its own",
		EventBoss.is_item_only("hollowsun"))
	check("it spawns in the VILLAGE: your town and your progress are the stake",
		str(ev.get("where", "")) == "village")
	check("it stands outside the ten-boss hunt",
		not EventBoss.hunt_ids().has("hollowsun"))
	check("...so the Hunter's Horn is NOT gated behind a 3%-a-day sky",
		EventBoss.hunt_ids().size() == 10, str(EventBoss.hunt_ids().size()))
	check("its boss def is real", preload("res://boss.gd").BOSSES.has(str(ev.get("boss_id", ""))))

	# it must be the hardest thing in the game, by the numbers and not by claim
	var mine: Dictionary = EventBoss.DIFF.get("eclipse", {})
	var hardest_other := 0.0
	for k in EventBoss.DIFF:
		if k == "eclipse": continue
		hardest_other = maxf(hardest_other, float(EventBoss.DIFF[k].get("hp", 0.0)))
	check("nothing in the game hits harder", float(mine.get("hp", 0.0)) > hardest_other,
		"eclipse %.2f vs best other %.2f" % [float(mine.get("hp", 0.0)), hardest_other])

	# ---------------- the sky is actually drawn ----------------
	var sky: String = FileAccess.open("res://day_night_cycle.gd", FileAccess.READ).get_as_text()
	check("the sky reads the eclipse", sky.contains("eclipse_progress()"))
	check("the world drops to silhouette rather than turning flat red",
		sky.contains("ECLIPSE_TINT_TOTAL"))
	check("the moon goes BLACK instead of counter-lighting to white",
		sky.contains("it is the hole"))
	check("the sun bleeds to a corona", sky.contains("ECLIPSE_CORONA"))
	# THE RING, and the two things that made it invisible until someone looked.
	# CanvasModulate multiplies, so nothing on the world canvas can ever be brighter
	# than the tint -- the corona has to live on its own layer or it is guaranteed to
	# come out the same colour as the sky it sits in. And the sky's parallax anchor is
	# player.x * 0.12 while the camera is at player.x, so a world-projected ring is
	# thousands of pixels off screen once you walk out to the village -- exactly where
	# this event happens. Both were found by screenshot, neither by any test.
	check("the ring is drawn on its OWN canvas layer (CanvasModulate cannot dim it)",
		sky.contains("_ring_layer") and sky.contains("CanvasLayer.new()"))
	check("...at layer 1, because a CanvasLayer at 0 loses the tie and hides behind the world",
		sky.contains("_ring_layer.layer = 1"))
	check("...and anchored to the SCREEN, so it is overhead in the village too",
		sky.contains("RING_SCREEN_Y"))
	var dn: Node = get_tree().get_first_node_in_group("day_night_cycle")
	check("the sky node is reachable to draw it", dn != null)
	if dn != null:
		# the corona must be a graded falloff, not a hard dartboard of rings
		var layers: Array = dn.RING_LAYERS
		check("the corona has enough steps to read as light, not as bands",
			layers.size() >= 6, "%d layers" % layers.size())
		var widest: float = float(layers[0][0])
		check("...and the outer glow is several times the disc",
			widest >= 2.5, "%.2f" % widest)
		# the innermost layer is the hot edge and must be the brightest of the set
		var hot: float = float(layers[layers.size() - 1][2])
		check("the inner edge burns hardest", hot >= float(layers[0][2]) * 2.0,
			"inner %.2f vs outer %.2f" % [hot, float(layers[0][2])])

	# ---------------- it survives a save ----------------
	GameState.game_hours = 7000.0
	GameState.eclipse_at_hours = 7000.0
	GameState.eclipses_seen = 4
	GameState.save_game(p)
	GameState.eclipse_at_hours = -1.0
	GameState.eclipses_seen = 0
	GameState.load_game()
	check("an eclipse in progress survives a save", is_equal_approx(GameState.eclipse_at_hours, 7000.0),
		str(GameState.eclipse_at_hours))
	check("and so does the tally", GameState.eclipses_seen == 4, str(GameState.eclipses_seen))

	# ---- restore ----
	GameState.game_hours = s_hours
	GameState.eclipse_at_hours = s_at
	GameState.eclipses_seen = s_seen

	printerr("test_eclipse : RESULT: ", "ALL PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)
