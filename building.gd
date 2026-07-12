extends Area2D

@export var building_name: String = "Building"
@export var role_key: String = ""
@export var width: float = 100.0
@export var height: float = 80.0
@export var body_color: Color = Color(0.5, 0.4, 0.3, 1.0)

const NPC_SCRIPT = preload("res://npc.gd")
const HITBOX_SCRIPT = preload("res://building_hitbox.gd")

# --- Destructibility (see the damage note; HP persists in GameState) ---
const MAX_HEALTH = 400
const BUILDING_LAYER = 8   # player attacks mask layer 4, so they never hit this
enum State { PRISTINE, SLIGHT, HALF, DESTROYED }

# --- Upgrades ---
# Every building levels 1..MAX_LEVEL (so MAX_LEVEL-1 = 5 upgrades). Each level
# makes the building bigger, better-looking (more windows, a pennant, roof
# trim), employ more workers (effective_slots) and produce more (see
# GameState.building_output_multiplier). Cost is a flat 1 gold for now (test).
const MAX_LEVEL = 6
const UPGRADE_COST_GOLD = 1

# --- Repair ---
# Buildings start the game in ruins (health 0, non-operational). Repairing one
# consumes construction materials (gathered from enemies / the dungeon -- see
# GameState.roll_construction_drop) and instantly restores it to full so its
# roles/output come online. No gold cost. Flat bundle for now, easy to tune.
const REPAIR_MATERIALS = {"wood": 4, "stone": 3, "resin": 2}
const WIDTH_PER_LEVEL = 0.05
const HEIGHT_PER_LEVEL = 0.12
const SLOTS_PER_LEVEL = 2   # extra worker slots each level (not leaders/enrollment)

# Per-building silhouette so no two look alike. roof: gable/flat/domed/gambrel/
# battlement/awning. feature: an extra distinguishing prop.
const STYLES = {
	"Government": {"roof": "flat", "feature": "columns"},
	"School": {"roof": "gable", "feature": "bell"},
	"Farm": {"roof": "gambrel", "feature": "silo"},
	"Hospital": {"roof": "flat", "feature": "cross"},
	"Barracks": {"roof": "battlement", "feature": "banner"},
	"Fishing Dock": {"roof": "gable", "feature": "none"},
	"Science Lab": {"roof": "domed", "feature": "none"},
	"Bank": {"roof": "flat", "feature": "columns"},
	"Blacksmith": {"roof": "gable", "feature": "chimney"},
	"Tavern": {"roof": "gable", "feature": "sign"},
	"Marketplace": {"roof": "awning", "feature": "none"},
	"Builderhouse": {"roof": "gable", "feature": "scaffold"},
}

# Per-building window layout so each gets a sensible, tidy count (not a blind
# 6-grid). "pairs" = windows per side of centre per row (so pairs 1 = 2 windows,
# a row); windows are ALWAYS placed in symmetric side-bands with the centre
# left clear -- so they never sit on the door or a centre prop. Marketplace is
# an open-air stall, so no windows.
const WINDOWS = {
	"Government": {"pairs": 1, "rows": 2},
	"School": {"pairs": 2, "rows": 1},
	"Farm": {"pairs": 1, "rows": 1},
	"Hospital": {"pairs": 1, "rows": 2},
	"Barracks": {"pairs": 1, "rows": 1},
	"Fishing Dock": {"pairs": 2, "rows": 1},
	"Science Lab": {"pairs": 1, "rows": 1},
	"Bank": {"pairs": 1, "rows": 2},
	"Blacksmith": {"pairs": 1, "rows": 1},
	"Tavern": {"pairs": 2, "rows": 1},
	"Marketplace": {"pairs": 0, "rows": 0},
	"Builderhouse": {"pairs": 1, "rows": 1},
}

const SCORCH = Color(0.12, 0.1, 0.09, 1.0)

var health = MAX_HEALTH
var building_level = 1
var current_state = State.PRISTINE
var player_inside = false

var base_width: float
var base_height: float
var style: Dictionary

var rng := RandomNumberGenerator.new()
var gfx: Node2D = null
var body_node: Polygon2D = null
var body_base_color: Color = Color.WHITE

var proximity_shape: CollisionShape2D = null
var hitbox: StaticBody2D = null
var hitbox_shape: CollisionShape2D = null
var name_label: Label = null
var prompt_label: Label = null
var health_bar_bg: ColorRect = null
var health_bar_fill: ColorRect = null

func _ready() -> void:
	base_width = width
	base_height = height
	style = STYLES.get(building_name, {"roof": "gable", "feature": "none"})

	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if role_key == "Hospital":
		GameState.child_produced.connect(_on_child_produced)
	if role_key != "":
		add_to_group("building_role_" + role_key)
	add_to_group("building")

	rng.seed = hash(building_name)
	health = int(GameState.building_health.get(building_name, MAX_HEALTH))
	building_level = int(GameState.building_levels.get(building_name, 1))
	current_state = state_for_health(health)

	proximity_shape = CollisionShape2D.new()
	proximity_shape.shape = RectangleShape2D.new()
	add_child(proximity_shape)

	hitbox = HITBOX_SCRIPT.new()
	hitbox.collision_layer = BUILDING_LAYER
	hitbox.collision_mask = 0
	hitbox_shape = CollisionShape2D.new()
	hitbox_shape.shape = RectangleShape2D.new()
	hitbox.add_child(hitbox_shape)
	add_child(hitbox)

	gfx = Node2D.new()
	add_child(gfx)

	name_label = _make_label(building_name, 13)
	add_child(name_label)
	prompt_label = _make_label("Press E", 13)
	prompt_label.name = "PromptLabel"
	prompt_label.visible = false
	add_child(prompt_label)

	build_health_bar()
	rebuild_geometry()

func _make_label(text: String, size: int) -> Label:
	var l = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	l.add_theme_constant_override("outline_size", 4)
	return l

# --- level-scaled dimensions ---

func eff_w() -> float:
	return base_width * (1.0 + (building_level - 1) * WIDTH_PER_LEVEL)

func eff_h() -> float:
	return base_height * (1.0 + (building_level - 1) * HEIGHT_PER_LEVEL)

# Resizes every collision box / bar / label to the current level and redraws.
func rebuild_geometry() -> void:
	var w = eff_w()
	var h = eff_h()
	proximity_shape.shape.size = Vector2(w, h + 40.0)
	proximity_shape.position = Vector2(0, -h / 2.0)
	hitbox_shape.shape.size = Vector2(w, h + 26.0)
	hitbox_shape.position = Vector2(0, -(h + 26.0) / 2.0)
	var bw = min(w, 70.0)
	health_bar_bg.size.x = bw
	health_bar_bg.position = Vector2(-bw / 2.0, -h - 50.0)
	health_bar_fill.position = Vector2(-bw / 2.0, -h - 50.0)
	name_label.position = Vector2(-w / 2.0, -h - 34.0)
	name_label.size = Vector2(w, 20.0)
	prompt_label.position = Vector2(-w / 2.0, -h - 14.0)
	prompt_label.size = Vector2(w, 18.0)
	update_health_bar()
	refresh_visual()

# --- damage ---

func state_for_health(hp: int) -> State:
	if hp <= 0:
		return State.DESTROYED
	if hp < int(MAX_HEALTH * 0.5):
		return State.HALF
	if hp < MAX_HEALTH:
		return State.SLIGHT
	return State.PRISTINE

func is_operational() -> bool:
	return health > 0

func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health = max(0, health - amount)
	GameState.building_health[building_name] = health
	flash_body()
	spawn_hit_debris()
	update_health_bar()
	var new_state = state_for_health(health)
	if new_state != current_state:
		current_state = new_state
		refresh_visual()
		if current_state == State.DESTROYED:
			var notif = get_node_or_null("../../CanvasLayer/NotificationStack")
			if notif:
				notif.show_notification(building_name + " has been destroyed!")

# --- repair ---

func is_ruined() -> bool:
	return health <= 0

# "4 Wood · 3 Stone · 2 Resin"
func repair_requirement_text() -> String:
	var parts = []
	for mat in REPAIR_MATERIALS:
		parts.append("%d %s" % [REPAIR_MATERIALS[mat], Inventory.get_display_name(mat)])
	return "  ".join(parts)

func has_repair_materials(player: Node) -> bool:
	for mat in REPAIR_MATERIALS:
		if player.inventory.get_count(mat) < REPAIR_MATERIALS[mat]:
			return false
	return true

# ["Wood 1/4", "Resin 0/2"] -- only the ones still short.
func missing_repair_materials(player: Node) -> Array:
	var missing = []
	for mat in REPAIR_MATERIALS:
		var have = player.inventory.get_count(mat)
		var need = int(REPAIR_MATERIALS[mat])
		if have < need:
			missing.append("%s %d/%d" % [Inventory.get_display_name(mat), have, need])
	return missing

# Spend construction materials to bring a ruined building back to full.
# Returns "ok" / "intact" / "materials".
func try_repair(player: Node) -> String:
	if health > 0:
		return "intact"
	if not has_repair_materials(player):
		return "materials"
	for mat in REPAIR_MATERIALS:
		player.inventory.remove_item(mat, int(REPAIR_MATERIALS[mat]))
	restore_full()
	return "ok"

# Snap the building back to full health + pristine look (used by repair and by
# the admin "restore all" key). Leaves the upgrade level untouched.
func restore_full() -> void:
	health = MAX_HEALTH
	GameState.building_health[building_name] = health
	current_state = State.PRISTINE
	update_health_bar()
	refresh_visual()
	update_prompt()

# Press-F repair while standing in a ruined building.
func attempt_field_repair() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var notif = get_tree().get_first_node_in_group("notification_stack")
	var result = try_repair(player)
	if result == "ok":
		if notif:
			notif.show_notification("%s repaired! Its roles are open now." % building_name)
	elif result == "materials" and notif:
		notif.show_notification("%s needs: %s" % [building_name, ", ".join(missing_repair_materials(player))])
	var assign_ui = get_node_or_null("../../AssignUI")
	if assign_ui and assign_ui.current_building == self:
		assign_ui.refresh()
	update_prompt()

# Ruined buildings prompt for an F repair (with the cost); intact ones prompt E.
func update_prompt() -> void:
	if not prompt_label:
		return
	if is_ruined():
		prompt_label.text = "Press F to Repair  (%s)" % repair_requirement_text()
	else:
		prompt_label.text = "Press E"

# --- upgrades ---

func can_upgrade() -> bool:
	return building_level < MAX_LEVEL and health > 0

func upgrade_cost() -> int:
	return UPGRADE_COST_GOLD

# Spend gold, bump the level, and grow/redecorate. Returns why it failed.
func try_upgrade(player: Node) -> String:
	if health <= 0:
		return "ruined"
	if building_level >= MAX_LEVEL:
		return "max"
	if player.currency < upgrade_cost():
		return "gold"
	player.currency -= upgrade_cost()
	player.update_currency_display()
	building_level += 1
	GameState.building_levels[building_name] = building_level
	rebuild_geometry()
	return "ok"

# Worker/income roles gain SLOTS_PER_LEVEL capacity each level; leadership and
# enrollment slots stay fixed.
func effective_slots(role_def: Dictionary) -> int:
	var base = int(role_def.slots)
	if role_def.get("title", "") in ["Leader", "Principal", "Warchief"] or role_def.get("is_enrollment", false):
		return base
	return base + (building_level - 1) * SLOTS_PER_LEVEL

# ---------------------------------------------------------------- visuals ---

func refresh_visual() -> void:
	if not gfx:
		return
	# detach immediately (queue_free is deferred, so several rebuilds in one
	# frame -- e.g. rapid upgrades -- would otherwise stack old visuals). The
	# gfx children are all plain drawables (no physics bodies), so removing them
	# mid-callback is safe.
	for c in gfx.get_children():
		gfx.remove_child(c)
		c.queue_free()
	match current_state:
		State.PRISTINE:
			build_intact(false)
		State.SLIGHT:
			build_intact(true)
		State.HALF:
			build_half()
		State.DESTROYED:
			build_destroyed()

# Pristine + slightly-damaged share the styled silhouette; `damaged` dims it,
# drops the shine, and adds cracks/scorch.
func build_intact(damaged: bool) -> void:
	var w = eff_w()
	var h = eff_h()
	var col = body_color.darkened(0.12) if damaged else body_color
	add_body(rect_poly(w, h), col)
	build_roof(w, h, col.darkened(0.32))
	add_door(col.darkened(0.5), h)
	add_window_grid(w, h, not damaged)
	build_feature(w, h)
	if building_level >= 4:
		add_pennant(w, h)
	if not damaged:
		build_shine(w, h)
	else:
		add_cracks(w, h, 3)
		add_scorch(w, h, 1, 7.0)

func build_half() -> void:
	var w = eff_w()
	var h = eff_h()
	add_body(ruined_body_poly(w, h, 0.4, 0.78), body_color.darkened(0.3))
	var roof = Polygon2D.new()
	roof.polygon = PackedVector2Array([
		Vector2(w / 2.0 + 6.0, -h * 0.7), Vector2(w * 0.1, -h * 0.7), Vector2(w / 2.0 - 4.0, -h * 0.92),
	])
	roof.color = body_color.darkened(0.5)
	gfx.add_child(roof)
	add_cracks(w, h, 5)
	add_scorch(w, h, 3, 11.0)
	add_fire(Vector2(rng.randf_range(-w * 0.2, w * 0.2), -h * 0.35), 12, 1.0)

func build_destroyed() -> void:
	var w = eff_w()
	var h = eff_h()
	add_body(ruined_body_poly(w, h, 0.12, 0.34), SCORCH.lerp(body_color, 0.25))
	for i in range(2):
		var frag = Polygon2D.new()
		var fx = rng.randf_range(-w * 0.4, w * 0.4)
		var fh = h * rng.randf_range(0.3, 0.5)
		frag.polygon = PackedVector2Array([
			Vector2(fx - 6, 0), Vector2(fx + 6, 0), Vector2(fx + 4, -fh), Vector2(fx - 5, -fh * 0.85),
		])
		frag.color = SCORCH.lerp(body_color, 0.15)
		gfx.add_child(frag)
	add_scorch(w, h, 4, 14.0)
	add_glow(w, Vector2(0, -h * 0.2))
	add_fire(Vector2(-w * 0.25, -h * 0.15), 16, 1.3)
	add_fire(Vector2(w * 0.22, -h * 0.2), 14, 1.1)

# --- body / roofs / features ---

func add_body(poly: PackedVector2Array, color: Color) -> void:
	body_node = Polygon2D.new()
	body_node.polygon = poly
	body_node.color = color
	body_base_color = color
	gfx.add_child(body_node)

func build_roof(w: float, h: float, color: Color) -> void:
	match style.get("roof", "gable"):
		"flat":
			add_poly(PackedVector2Array([
				Vector2(-w / 2.0 - 6, -h), Vector2(w / 2.0 + 6, -h),
				Vector2(w / 2.0 + 6, -h - 10), Vector2(-w / 2.0 - 6, -h - 10)]), color)
			# small parapet blocks
			for sx in [-w * 0.4, 0.0, w * 0.4]:
				add_rect(Vector2(sx - 4, -h - 16), Vector2(8, 6), color.darkened(0.1))
		"domed":
			var pts = PackedVector2Array()
			var r = w * 0.5
			for i in range(13):
				var a = PI * float(i) / 12.0
				pts.append(Vector2(-cos(a) * r, -h - sin(a) * r * 0.8))
			add_poly(pts, color)
		"gambrel":
			add_poly(PackedVector2Array([
				Vector2(-w / 2.0 - 6, -h), Vector2(-w * 0.28, -h - 16),
				Vector2(0, -h - 26), Vector2(w * 0.28, -h - 16), Vector2(w / 2.0 + 6, -h)]), color)
		"battlement":
			add_rect(Vector2(-w / 2.0 - 4, -h - 12), Vector2(w + 8, 12), color)
			var mx = -w / 2.0
			while mx < w / 2.0 - 1.0:
				add_rect(Vector2(mx, -h - 20), Vector2(9, 8), color)
				mx += 18.0
		"awning":
			# striped market canopy
			var stripes = max(3, int(w / 18.0))
			var sw = (w + 16.0) / stripes
			for i in range(stripes):
				var c = Color(0.8, 0.25, 0.22, 1) if i % 2 == 0 else Color(0.92, 0.88, 0.8, 1)
				add_poly(PackedVector2Array([
					Vector2(-w / 2.0 - 8 + i * sw, -h), Vector2(-w / 2.0 - 8 + (i + 1) * sw, -h),
					Vector2(-w / 2.0 - 8 + (i + 1) * sw, -h - 12), Vector2(-w / 2.0 - 8 + i * sw + sw * 0.5, -h - 20)]), c)
		_:  # gable
			add_poly(PackedVector2Array([
				Vector2(-w / 2.0 - 8, -h), Vector2(w / 2.0 + 8, -h), Vector2(0, -h - 26)]), color)

func build_feature(w: float, h: float) -> void:
	match style.get("feature", "none"):
		"columns":
			for sx in [-w * 0.34, 0.0, w * 0.34]:
				add_rect(Vector2(sx - 3, -h * 0.75), Vector2(6, h * 0.75), body_color.lightened(0.15))
		"cross":
			add_rect(Vector2(-4, -h * 0.9), Vector2(8, 22), Color(0.85, 0.2, 0.2, 1))
			add_rect(Vector2(-11, -h * 0.9 + 7), Vector2(22, 8), Color(0.85, 0.2, 0.2, 1))
		"chimney":
			add_rect(Vector2(w * 0.28, -h - 20), Vector2(12, 24), body_color.darkened(0.4))
			add_fire(Vector2(w * 0.34, -h - 22), 6, 0.5)  # doubles as smoke plume
		"banner":
			add_poly(PackedVector2Array([
				Vector2(-6, -h - 4), Vector2(6, -h - 4), Vector2(6, -h * 0.45), Vector2(0, -h * 0.55), Vector2(-6, -h * 0.45)]),
				Color(0.55, 0.15, 0.18, 1))
		"sign":
			add_rect(Vector2(w * 0.42, -h * 0.85), Vector2(3, h * 0.3), Color(0.3, 0.2, 0.12, 1))
			add_rect(Vector2(w * 0.42 - 14, -h * 0.62), Vector2(28, 16), Color(0.5, 0.36, 0.2, 1))
		"bell":
			add_rect(Vector2(-8, -h - 24), Vector2(16, 16), body_color.darkened(0.25))
			add_poly(PackedVector2Array([Vector2(-9, -h - 24), Vector2(9, -h - 24), Vector2(0, -h - 34)]), body_color.darkened(0.4))
			add_rect(Vector2(-3, -h - 18), Vector2(6, 7), Color(0.75, 0.6, 0.2, 1))
		"silo":
			add_rect(Vector2(w * 0.5, -h * 0.9), Vector2(18, h * 0.9), body_color.lightened(0.08))
			add_poly(PackedVector2Array([Vector2(w * 0.5, -h * 0.9), Vector2(w * 0.5 + 18, -h * 0.9), Vector2(w * 0.5 + 9, -h * 0.9 - 12)]), body_color.darkened(0.3))
		"scaffold":
			for sx in [-w * 0.35, w * 0.35]:
				add_rect(Vector2(sx, -h), Vector2(3, h), Color(0.55, 0.42, 0.24, 1))
			add_rect(Vector2(-w * 0.4, -h * 0.6), Vector2(w * 0.8, 4), Color(0.55, 0.42, 0.24, 1))
			add_rect(Vector2(-w * 0.4, -h * 0.3), Vector2(w * 0.8, 4), Color(0.55, 0.42, 0.24, 1))

# Little level flag that appears from level 4 -- a quick "this place is thriving"
# read. Colour brightens toward max level.
func add_pennant(w: float, _h: float) -> void:
	var top_y = -eff_h() - (30.0 if style.get("roof") == "gable" else 14.0)
	add_rect(Vector2(-1.5, top_y - 22), Vector2(3, 22), Color(0.4, 0.3, 0.2, 1))
	var flag_col = Color(0.9, 0.7, 0.25, 1).lerp(Color(0.95, 0.85, 0.4, 1), float(building_level) / MAX_LEVEL)
	add_poly(PackedVector2Array([Vector2(1.5, top_y - 22), Vector2(20, top_y - 17), Vector2(1.5, top_y - 12)]), flag_col)

# Tidy, per-building windows: symmetric side-bands with the centre kept clear,
# always high on the facade above the door, and never on a centre prop. Only
# the shine is random -- window placement is fully deterministic.
func add_window_grid(w: float, h: float, lit: bool) -> void:
	var spec = WINDOWS.get(building_name, {"pairs": 1, "rows": 1})
	var pairs = int(spec.pairs)
	var rows = int(spec.rows)
	if pairs <= 0 or rows <= 0:
		return
	# an upgraded (bigger) building earns one extra row, still tidy
	if building_level >= 4 and rows < 2:
		rows += 1

	var ww = clamp(w * 0.1, 8.0, 12.0)
	var win_col = Color(0.95, 0.85, 0.5, 0.95) if lit else Color(0.45, 0.42, 0.35, 1.0)
	# innermost/outermost window CENTRES on the left side (centre band kept clear)
	var inner = w * 0.17 + ww * 0.5
	var outer = max(w * 0.42 - ww * 0.5, inner)

	# vertical rows -- columns buildings put windows in a single high strip above
	# their column tops so the two never overlap.
	var ys: Array
	if style.get("feature", "") == "columns":
		ys = [-h * 0.82]
	elif rows == 1:
		ys = [-h * 0.72]
	else:
		ys = [-h * 0.6, -h * 0.84]

	for ry in ys:
		for cx in _side_centers(pairs, inner, outer):
			add_rect(Vector2(cx - ww * 0.5, ry), Vector2(ww, ww), win_col)       # left
			add_rect(Vector2(-cx - ww * 0.5, ry), Vector2(ww, ww), win_col)      # mirror

# Evenly-spaced window centres on the LEFT side (negative x) between the inner
# (near centre) and outer (near edge) bounds.
func _side_centers(pairs: int, inner: float, outer: float) -> Array:
	var res = []
	if pairs == 1:
		res.append(-(inner + outer) * 0.5)
	else:
		for i in range(pairs):
			res.append(-lerp(inner, outer, float(i) / float(pairs - 1)))
	return res

func add_door(color: Color, h: float) -> void:
	var door_width = eff_w() * 0.2
	var dh = h * 0.42
	add_rect(Vector2(-door_width / 2.0, -dh), Vector2(door_width, dh), color)

func add_cracks(w: float, h: float, count: int) -> void:
	for i in range(count):
		var crack = Line2D.new()
		crack.width = 1.6
		crack.default_color = Color(0.1, 0.09, 0.08, 0.85)
		var ox = rng.randf_range(-w * 0.42, w * 0.42)
		var oy = -h * rng.randf_range(0.2, 0.9)
		var pts = PackedVector2Array([Vector2(ox, oy)])
		for s in range(3):
			ox += rng.randf_range(-8, 8)
			oy += rng.randf_range(6, 14)
			pts.append(Vector2(ox, min(oy, -2.0)))
		crack.points = pts
		gfx.add_child(crack)

func add_scorch(w: float, h: float, count: int, radius: float) -> void:
	for i in range(count):
		var s = Polygon2D.new()
		s.polygon = circle_poly(radius * rng.randf_range(0.7, 1.3), 9)
		s.position = Vector2(rng.randf_range(-w * 0.42, w * 0.42), -h * rng.randf_range(0.15, 0.85))
		s.color = Color(0.1, 0.08, 0.07, 0.6)
		gfx.add_child(s)

func add_glow(w: float, local_pos: Vector2) -> void:
	var glow = Polygon2D.new()
	glow.polygon = circle_poly(w * 0.42, 16)
	glow.position = local_pos
	glow.color = Color(1.0, 0.45, 0.12, 0.22)
	gfx.add_child(glow)
	var t = glow.create_tween()
	t.set_loops()
	t.tween_property(glow, "modulate:a", 0.5, 0.6).set_trans(Tween.TRANS_SINE)
	t.tween_property(glow, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)

func add_fire(local_pos: Vector2, amount: int, scale: float) -> void:
	var fire = CPUParticles2D.new()
	fire.position = local_pos
	fire.z_index = 6
	fire.amount = amount
	fire.lifetime = 0.6
	fire.direction = Vector2(0, -1)
	fire.spread = 22.0
	fire.gravity = Vector2(0, -70)
	fire.initial_velocity_min = 24.0 * scale
	fire.initial_velocity_max = 55.0 * scale
	fire.scale_amount_min = 2.0 * scale
	fire.scale_amount_max = 4.2 * scale
	fire.color = Color(1.0, 0.55, 0.15, 1.0)
	gfx.add_child(fire)
	fire.emitting = true
	var smoke = CPUParticles2D.new()
	smoke.position = local_pos + Vector2(0, -6)
	smoke.z_index = 7
	smoke.amount = int(amount * 0.6)
	smoke.lifetime = 1.3
	smoke.direction = Vector2(0, -1)
	smoke.spread = 30.0
	smoke.gravity = Vector2(0, -30)
	smoke.initial_velocity_min = 12.0
	smoke.initial_velocity_max = 30.0
	smoke.scale_amount_min = 3.0 * scale
	smoke.scale_amount_max = 6.0 * scale
	smoke.color = Color(0.25, 0.24, 0.24, 0.5)
	gfx.add_child(smoke)
	smoke.emitting = true

# The pristine gloss: a single soft diagonal light-streak so a fully-repaired
# building reads as clean/new -- no twinkling sparkle stars (those looked like
# stray white shapes). Position/angle vary per building seed so no two match.
func build_shine(w: float, h: float) -> void:
	var streak = Polygon2D.new()
	var length = h * rng.randf_range(0.55, 0.9)
	var thick = rng.randf_range(3.0, 5.0)
	streak.polygon = PackedVector2Array([
		Vector2(-thick, 0), Vector2(thick, 0), Vector2(thick, -length), Vector2(-thick, -length)])
	streak.color = Color(1, 1, 1, rng.randf_range(0.06, 0.10))
	streak.position = Vector2(rng.randf_range(-w * 0.28, w * 0.28), -h * rng.randf_range(0.35, 0.85))
	streak.rotation = deg_to_rad(rng.randf_range(22.0, 40.0))
	gfx.add_child(streak)

func flash_body() -> void:
	if not body_node:
		return
	body_node.color = Color(1, 1, 1)
	var t = body_node.create_tween()
	t.tween_property(body_node, "color", body_base_color, 0.15)

func spawn_hit_debris() -> void:
	var w = eff_w()
	var h = eff_h()
	var p = CPUParticles2D.new()
	p.position = Vector2(rng.randf_range(-w * 0.3, w * 0.3), -h * rng.randf_range(0.3, 0.7))
	p.z_index = 6
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 8
	p.lifetime = 0.5
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.gravity = Vector2(0, 300)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 90.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = body_color.darkened(0.3)
	gfx.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)

# --- small draw helpers ---

func add_poly(poly: PackedVector2Array, color: Color) -> void:
	var p = Polygon2D.new()
	p.polygon = poly
	p.color = color
	gfx.add_child(p)

func add_rect(pos: Vector2, size: Vector2, color: Color) -> void:
	var r = ColorRect.new()
	r.position = pos
	r.size = size
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gfx.add_child(r)

func rect_poly(w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-w / 2.0, 0), Vector2(w / 2.0, 0), Vector2(w / 2.0, -h), Vector2(-w / 2.0, -h)])

func ruined_body_poly(w: float, h: float, min_frac: float, max_frac: float) -> PackedVector2Array:
	var pts = PackedVector2Array()
	pts.append(Vector2(-w / 2.0, 0))
	pts.append(Vector2(w / 2.0, 0))
	pts.append(Vector2(w / 2.0, -h * rng.randf_range(max_frac * 0.8, max_frac)))
	for i in range(1, 4):
		pts.append(Vector2(w / 2.0 - float(i) / 4.0 * w, -h * rng.randf_range(min_frac, max_frac)))
	pts.append(Vector2(-w / 2.0, -h * rng.randf_range(min_frac, max_frac)))
	return pts

func circle_poly(radius: float, sides: int) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in range(sides):
		var ang = TAU * float(i) / sides
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	return pts

# --- health bar ---

func build_health_bar() -> void:
	health_bar_bg = ColorRect.new()
	health_bar_bg.color = Color(0.15, 0.05, 0.05, 0.9)
	health_bar_bg.size = Vector2(70.0, 6.0)
	health_bar_bg.z_index = 20
	health_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(health_bar_bg)
	health_bar_fill = ColorRect.new()
	health_bar_fill.size = Vector2(70.0, 6.0)
	health_bar_fill.z_index = 21
	health_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(health_bar_fill)

func update_health_bar() -> void:
	if not health_bar_bg or not health_bar_fill:
		return
	var frac = clamp(float(health) / MAX_HEALTH, 0.0, 1.0)
	var bw = min(eff_w(), 70.0)
	health_bar_fill.size.x = bw * frac
	health_bar_fill.color = Color(0.85, 0.2, 0.2, 1.0) if frac < 0.4 else Color(0.55, 0.55, 0.62, 1.0)
	var show = health < MAX_HEALTH
	health_bar_bg.visible = show
	health_bar_fill.visible = show

# ---------------------------------------------------------------- gameplay ---

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = true
		update_prompt()
		prompt_label.visible = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = false
		prompt_label.visible = false
		var assign_ui = get_node_or_null("../../AssignUI")
		if assign_ui and assign_ui.current_building == self:
			assign_ui.close()

func _process(_delta: float) -> void:
	if not player_inside:
		return
	# Ruined -> F repairs it (materials); intact -> E opens the assign panel.
	if is_ruined() and Input.is_action_just_pressed("enter_dungeon"):
		attempt_field_repair()
	elif Input.is_action_just_pressed("interact"):
		open_assign_ui()

func get_roles() -> Array:
	return BuildingRoles.get_roles(role_key)

func get_role_holders(role_title: String) -> Array:
	var holders = []
	for villager in GameState.rescued_villagers:
		if villager.get("role_key") == role_key and villager.get("role_title") == role_title:
			holders.append(villager)
	return holders

func is_role_full(role_def: Dictionary) -> bool:
	return get_role_holders(role_def.title).size() >= effective_slots(role_def)

func get_eligible_villagers(role_def: Dictionary) -> Array:
	if is_role_full(role_def):
		return []
	var eligible = []
	for villager in GameState.rescued_villagers:
		if villager.get("role_key", "") != "" or GameState.school_enrollments.has(villager.get("id")):
			continue
		if role_def.get("required_stat", "") != "" and villager.get("stat_name", "") != role_def.required_stat:
			continue
		if role_def.get("requires_sex", "") != "" and villager.get("sex", "") != role_def.requires_sex:
			continue
		if role_def.get("requires_kid", false) and not villager.get("is_kid", false):
			continue
		if not role_def.get("requires_kid", false) and not role_def.get("is_enrollment", false) and villager.get("is_kid", false):
			continue
		eligible.append(villager)
	return eligible

func open_assign_ui() -> void:
	var assign_ui = get_node_or_null("../../AssignUI")
	if assign_ui:
		assign_ui.open_for_building(self)

func _on_child_produced(child_id: String) -> void:
	var npc = NPC_SCRIPT.new()
	npc.villager_id = child_id
	npc.global_position = global_position + Vector2(randf_range(-18.0, 18.0), -60.0)
	get_parent().add_child(npc)
	var notif = get_node_or_null("../../CanvasLayer/NotificationStack")
	if notif:
		notif.show_notification("A new villager has been born at " + building_name + "!")
