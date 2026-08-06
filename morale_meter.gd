extends Control

# Village morale, shown in the TAB overlay directly BELOW the mana bar (kept
# clear of it so the two never overlap). It stays hidden until the whole village
# has been rebuilt (GameState.morale_meter_unlocked); after that it appears
# whenever the player opens the TAB view and hides again when TAB is closed.
#
# The bar's colour AND a little face both shift with the mood -- a deep red
# frown in misery, through a flat amber neutral, to a wide green grin when the
# town is thriving -- and the face rides along the bar at the current fill level,
# so it literally moves with the morale.

const BAR_X := 20.0
const BAR_Y := 126.0     # clears the mana bar AND its label (which reach y=112)
const BAR_W := 100.0
const BAR_H := 12.0

var fill: ColorRect = null
var label: Label = null
var glance: Label = null
var cur_morale := 50

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg = ColorRect.new()
	bg.position = Vector2(BAR_X, BAR_Y)
	bg.size = Vector2(BAR_W, BAR_H)
	bg.color = Color(0.06, 0.06, 0.09, 0.9)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	fill = ColorRect.new()
	fill.position = Vector2(BAR_X, BAR_Y)
	fill.size = Vector2(BAR_W, BAR_H)
	fill.color = Color(0.3, 0.8, 0.35)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)
	# readout sits past the face's furthest travel so they never collide
	label = Label.new()
	label.position = Vector2(BAR_X + BAR_W + 22.0, BAR_Y - 4.0)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	# THE VILLAGE AT A GLANCE (polish 2026-07-20): the meter answered "are
	# they happy" and nothing else -- you had to walk the whole town to
	# learn the food runway, the wage bill, or how many souls sleep rough.
	# Four lines under the bar, same fog rule as the meter.
	glance = Label.new()
	glance.position = Vector2(BAR_X, BAR_Y + BAR_H + 8.0)
	glance.add_theme_font_size_override("font_size", 12)
	glance.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	glance.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	glance.add_theme_constant_override("outline_size", 4)
	glance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glance)
	visible = false

func _process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	if not is_instance_valid(fill):
		return
	# The meter mirrors the ACTUAL inventory panel rather than tracking its own
	# TAB flag -- otherwise closing the bag by any other means (the X button, Esc)
	# left it stranded on screen, since only a TAB press cleared the old flag.
	var inv := get_tree().get_first_node_in_group("inventory_ui")
	var bag_open: bool = inv != null and inv.visible
	# hidden until the town is fully built, then only while the bag is open --
	# and only when the village is KNOWABLE (at home, or Telepathy): the
	# fog rule means the meter is something you check by being there
	visible = GameState.morale_meter_unlocked and bag_open and GameState.village_info_available()
	if not visible:
		return
	cur_morale = GameState.village_morale()
	fill.size.x = BAR_W * float(cur_morale) / 100.0
	fill.color = _mood_color(cur_morale)
	label.text = "Morale %.1f/10" % (float(cur_morale) / 10.0)
	_refresh_glance()
	queue_redraw()

# Four lines the player would otherwise have to walk the town to learn:
# how long the larder lasts, what the payroll costs, who sleeps rough or
# jobless, and how many blueprints are still lost in the deep.
func _refresh_glance() -> void:
	if glance == null:
		return
	var eaten: float = GameState.food_consumption_per_hour()
	var made: float = GameState.food_production_per_hour()
	var net: float = made - eaten
	var food_line := "Food %.0f" % GameState.village_food
	if net < -0.001:
		food_line += "  (%.0fh left)" % (GameState.village_food / -net)
	elif net > 0.001:
		food_line += "  (+%.1f/day)" % (net * 24.0)
	else:
		food_line += "  (holding)"
	var employed := 0
	var homeless := 0
	var jobless := 0
	for v in GameState.rescued_villagers:
		if str(v.get("role_key", "")) != "":
			employed += 1
		elif not v.get("is_kid", false):
			jobless += 1
		if not v.get("is_kid", false) and GameState.villager_home_id(str(v.get("id", ""))) == "":
			homeless += 1
	var wage: float = float(employed) * GameState.WAGE_PER_WORKER_PER_DAY
	if GameState.is_building_operational("Bank") and GameState.count_workers("Bank") > 0:
		wage *= GameState.BANK_PAYROLL_DISCOUNT
	var lines := []
	# the one sentence that is always true and always useful
	lines.append("▶ NEXT: " + GameState.next_objective())
	lines.append(food_line)
	lines.append("Souls %d  (%d working, %d idle)" % [GameState.rescued_villagers.size(), employed, jobless])
	lines.append("Wages %.0fg/day%s" % [wage, "   ⚠ %d unhoused" % homeless if homeless > 0 else ""])
	# The time economy at a glance: how much of the day the village no longer
	# needs the player for. Climbs as chores get automated (see chore_domains).
	var ss: Dictionary = GameState.village_self_sufficiency()
	lines.append("🕊 Self-reliance %d%%  (%d/%d chores run themselves)" % [int(round(float(ss["fraction"]) * 100.0)), int(ss["handled"]), int(ss["total"])])
	# THE CHAIN AT A GLANCE (City Machine): the stores the crews fill and the
	# repairs/cottages/forge spend, plus the town's own purse. Without this the
	# whole supply chain was invisible -- "the builders idle, the stores need
	# wood" with nowhere to check. Donate at the Builderhouse (E).
	var st: Dictionary = GameState.village_stockpile
	var stores_line := "🪵 Stores  wood %d · stone %d · iron %d" % [
		int(st.get("wood", 0)), int(st.get("stone", 0)), int(st.get("iron_shard", 0))]
	if GameState.village_treasury > 0:
		stores_line += "   🏦 %dg" % GameState.village_treasury
	lines.append(stores_line)
	var rotting: int = GameState.villager_rot.size()
	if rotting > 0:
		lines.append("⚠ %d SLIPPING — mend their lives now" % rotting)
	# THE SICKNESS: the town's own emergency. Loud here, because an outbreak you
	# cannot see is just a silent tax on a town you thought was running itself.
	var alight: int = GameState.fire_count()
	if alight > 0:
		var crew := GameState.count_workers("Builderhouse") + GameState.seated_leaders("Builderhouse")
		lines.append("🔥 %d BURNING — %s" % [alight,
			("%d builders fighting it" % crew) if crew > 0 else "NOBODY IS FIGHTING IT"])
	var ill: int = GameState.sick_count()
	if ill > 0:
		var ward_note := "the ward is holding it" if (GameState.is_building_operational("Hospital") \
			and GameState.count_workers("Hospital") > 0) else "NO WARD — staff the Hospital"
		lines.append("🤒 %d SICK — %s" % [ill, ward_note])
	var missing_bp: int = GameState.STARTING_BUILDINGS.size() - GameState.blueprints.size()
	if missing_bp > 0:
		lines.append("📜 %d blueprint%s still lost below" % [missing_bp, "" if missing_bp == 1 else "s"])
	glance.text = "\n".join(lines)

# The face: a coloured disc riding at the fill tip, with a mouth that bends from
# a frown (low morale) through flat to a grin (high morale). Eyes droop when sad.
func _draw() -> void:
	if not visible:
		return
	var frac = float(cur_morale) / 100.0
	var cx = BAR_X + BAR_W * frac
	var cy = BAR_Y + BAR_H / 2.0
	var r = 9.0
	var col = _mood_color(cur_morale)
	draw_circle(Vector2(cx, cy), r, col)
	draw_arc(Vector2(cx, cy), r, 0.0, TAU, 24, Color(0, 0, 0, 0.85), 1.4)
	# curve: -1 = deep frown, 0 = flat, +1 = big grin
	var curve = frac * 2.0 - 1.0
	var eye_col = Color(0.1, 0.08, 0.08)
	var ex = 3.3
	var ey = cy - 2.4
	if curve < -0.1:
		# sad: eyes as downward-slanting brows
		draw_line(Vector2(cx - ex - 1.3, ey - 1.0), Vector2(cx - ex + 1.3, ey + 0.4), eye_col, 1.4)
		draw_line(Vector2(cx + ex - 1.3, ey + 0.4), Vector2(cx + ex + 1.3, ey - 1.0), eye_col, 1.4)
	else:
		draw_circle(Vector2(cx - ex, ey), 1.35, eye_col)
		draw_circle(Vector2(cx + ex, ey), 1.35, eye_col)
	# mouth: sampled parabola; middle dips down for a smile, up for a frown
	var pts = PackedVector2Array()
	var mw = 4.6
	var n = 9
	for i in range(n):
		var t = float(i) / float(n - 1) * 2.0 - 1.0
		var mx = cx + t * mw
		var my = cy + 3.1 + curve * 2.7 * (1.0 - t * t)
		pts.append(Vector2(mx, my))
	draw_polyline(pts, Color(0.1, 0.05, 0.05), 1.7)

func _mood_color(m: int) -> Color:
	if m >= 66:
		return Color(0.3, 0.8, 0.35)     # thriving
	elif m >= 33:
		return Color(0.9, 0.75, 0.2)     # strained
	return Color(0.85, 0.3, 0.2)          # suffering
