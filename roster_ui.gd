extends CanvasLayer

# THE ROSTER (polish 2026-07-20) -- every soul in Deepwood on one page.
#
# The village grew to twenty-odd people with a spirit, a job, a home, a
# partner and a bond EACH, and the only way to read any of it was to walk
# up to a wandering avatar and hover. Finding "who is about to rot" meant
# a search on foot. This is the management view that layer always needed:
# sorted by NEED so the people in trouble are always at the top, never
# buried under the content ones.

var panel: Panel = null
var rows: VBoxContainer = null
var header: Label = null

func _ready() -> void:
	layer = 47
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("esc_window")
	add_to_group("roster_ui")
	panel = Panel.new()
	panel.visible = false
	panel.position = Vector2(150, 40)
	panel.size = Vector2(860, 580)
	add_child(panel)
	var title := Label.new()
	title.text = "THE PEOPLE OF DEEPWOOD"
	title.add_theme_font_size_override("font_size", 20)
	title.position = Vector2(18, 8)
	panel.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.position = Vector2(756, 8)
	close_btn.custom_minimum_size = Vector2(84, 26)
	close_btn.pressed.connect(esc_close)
	panel.add_child(close_btn)
	header = Label.new()
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", Color(0.7, 0.68, 0.62, 1.0))
	header.position = Vector2(18, 36)
	header.size = Vector2(820, 18)
	panel.add_child(header)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(18, 60)
	scroll.size = Vector2(824, 504)
	panel.add_child(scroll)
	rows = VBoxContainer.new()
	rows.custom_minimum_size = Vector2(804, 0)
	rows.add_theme_constant_override("separation", 3)
	scroll.add_child(rows)

func esc_is_open() -> bool:
	return panel.visible

func esc_close() -> void:
	panel.visible = false

func open_page() -> void:
	# the fog rules the roster too: this is village knowledge
	if not GameState.village_info_available():
		var stack = get_tree().get_first_node_in_group("notification_stack")
		if stack:
			stack.show_notification("You cannot count souls you cannot see. Return home — or learn Telepathy.")
		return
	panel.visible = true
	refresh()

# Trouble first: rot, then the unmet needs, then everyone else. Within a
# band, the lowest spirit leads.
func _need_rank(v: Dictionary) -> int:
	var vid := str(v.get("id", ""))
	if GameState.villager_rot.has(vid):
		return 0
	if GameState.get_personal_morale(v) < 3.5:
		return 1
	if not v.get("is_kid", false) and GameState.villager_home_id(vid) == "":
		return 2
	if not v.get("is_kid", false) and str(v.get("role_key", "")) == "":
		return 3
	return 4

func refresh() -> void:
	for c in rows.get_children():
		c.queue_free()
	var roster: Array = GameState.rescued_villagers.duplicate()
	roster.sort_custom(func(a, b):
		var ra := _need_rank(a)
		var rb := _need_rank(b)
		if ra != rb:
			return ra < rb
		return GameState.get_personal_morale(a) < GameState.get_personal_morale(b))
	var jobless := 0
	var homeless := 0
	var rotting := 0
	for v in roster:
		var vid := str(v.get("id", ""))
		if GameState.villager_rot.has(vid):
			rotting += 1
		if not v.get("is_kid", false):
			if str(v.get("role_key", "")) == "":
				jobless += 1
			if GameState.villager_home_id(vid) == "":
				homeless += 1
	header.text = "%d souls  •  %d without work  •  %d without a home  •  %d in the dark  —  sorted by who needs you most" % [
		roster.size(), jobless, homeless, rotting]
	for v in roster:
		rows.add_child(_build_row(v))
	if roster.is_empty():
		var empty := Label.new()
		empty.text = "Nobody yet. They are all still down there."
		empty.add_theme_color_override("font_color", Color(0.6, 0.58, 0.54, 1.0))
		rows.add_child(empty)

func _build_row(v: Dictionary) -> HBoxContainer:
	var vid := str(v.get("id", ""))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var spirit: float = GameState.get_personal_morale(v)
	var rotting: bool = GameState.villager_rot.has(vid)
	# the spirit glyph carries the whole state at a glance
	var mark := Label.new()
	mark.text = "☠" if rotting else ("☀" if spirit >= 7.0 else ("☁" if spirit >= 3.5 else "⚠"))
	mark.custom_minimum_size = Vector2(20, 0)
	mark.add_theme_color_override("font_color",
		Color(0.95, 0.35, 0.35) if rotting else (
			Color(0.55, 0.9, 0.55) if spirit >= 7.0 else (
				Color(0.9, 0.85, 0.5) if spirit >= 3.5 else Color(0.95, 0.55, 0.35))))
	row.add_child(mark)
	var name_l := Label.new()
	var tag := ""
	if v.get("unbreakable", false):
		tag = " ★"
	elif v.get("hero_trained", false):
		tag = " ★HERO"
	elif v.get("hero", false):
		tag = " ★hero-born"
	elif v.get("is_kid", false):
		tag = " (child)"
	if v.get("shadow", false):
		tag += " ☾"
	name_l.text = str(v.get("name", "?")) + tag
	name_l.custom_minimum_size = Vector2(230, 0)
	row.add_child(name_l)
	var spirit_l := Label.new()
	spirit_l.text = "%.1f/10" % spirit
	spirit_l.custom_minimum_size = Vector2(56, 0)
	spirit_l.add_theme_font_size_override("font_size", 12)
	row.add_child(spirit_l)
	var job_l := Label.new()
	if v.get("is_kid", false):
		job_l.text = "at school" if GameState.school_enrollments.has(vid) else "a child"
	elif str(v.get("role_title", "")) != "":
		job_l.text = "%s, %s" % [str(v.get("role_title")), str(v.get("role_key"))]
	elif str(v.get("stat_name", "")) != "":
		job_l.text = "idle (%s)" % str(v.get("stat_name"))
	else:
		job_l.text = "idle, unskilled"
	job_l.custom_minimum_size = Vector2(220, 0)
	job_l.add_theme_font_size_override("font_size", 12)
	if str(v.get("role_key", "")) == "" and not v.get("is_kid", false):
		job_l.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	row.add_child(job_l)
	var home_l := Label.new()
	if v.get("is_kid", false):
		home_l.text = "with parents"
	elif GameState.villager_home_id(vid) != "":
		home_l.text = "housed"
	elif GameState.is_building_operational("Tavern"):
		home_l.text = "at the Tavern"
	else:
		home_l.text = "SLEEPS ROUGH"
		home_l.add_theme_color_override("font_color", Color(0.95, 0.6, 0.4))
	home_l.custom_minimum_size = Vector2(110, 0)
	home_l.add_theme_font_size_override("font_size", 12)
	row.add_child(home_l)
	var bond_l := Label.new()
	if str(v.get("quest_state", "")) == "done":
		bond_l.text = "♥ bonded"
		bond_l.add_theme_color_override("font_color", Color(0.85, 0.6, 0.8))
	elif str(v.get("quest_state", "")) == "active":
		bond_l.text = "bond open"
	bond_l.add_theme_font_size_override("font_size", 12)
	row.add_child(bond_l)
	return row
