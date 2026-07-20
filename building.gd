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

# --- Build / repair ---
# Buildings start in ruins and are raised over GameState.TOTAL_BUILD_STAGES (3)
# construction stages: each Press-F spends this SAME material bundle, plays a
# BUILD_TIME "rising from the ground" animation, and advances one stage
# (ruins -> frame -> walls -> finished). Only the final stage makes it
# operational. Combat that destroys a finished building knocks it back to ruins.
const REPAIR_MATERIALS = {"wood": 3, "stone": 2, "resin": 1}
const BUILD_TIME = 2.6   # seconds to construct one stage
const WIDTH_PER_LEVEL = 0.08
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

# PixelLab facade art (art/buildings/<file>.png) shown for FINISHED buildings;
# ruins, construction stages and the half-wrecked state keep the procedural
# rubble look. Missing art falls back to the procedural silhouette (zero-risk).
const BUILDING_ART = {
	"Government": "government", "School": "school", "Farm": "farm",
	"Hospital": "hospital", "Barracks": "barracks", "Fishing Dock": "fishing_dock",
	"Science Lab": "science_lab", "Bank": "bank", "Blacksmith": "smithy",
	"Tavern": "tavern", "Marketplace": "marketplace", "Builderhouse": "builderhouse",
	"Bar": "bar",
}

const SCORCH = Color(0.12, 0.1, 0.09, 1.0)

# Rows of CONTENT (art px, measured from the bottom of the content box) that are
# drawn BELOW the building's true base and must be buried in the dirt: the
# Government's front steps, the Builderhouse's painted ground patch. Without
# this the lowest painted pixel is what lands on the ground line, so the
# building hovers on its own steps. Everything else grounds on its own bottom
# row -- notably the Fishing Dock, whose pilings are SUPPOSED to reach the
# ground. Measure with tool_art_audit.gd / tool_ground_qc.gd.
const ART_SINK = {
	"Government": 2.0,
	"Builderhouse": 16.0,
}

# Content bounding box per facade PNG (transparent padding excluded), cached
# so every building of a type scans its art once.
static var _art_rects := {}
static func _art_content_rect(key: String, tex: Texture2D) -> Rect2:
	if _art_rects.has(key):
		return _art_rects[key]
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var used := img.get_used_rect()
	var r := Rect2(used) if used.size.x > 0 else Rect2(Vector2.ZERO, Vector2(tex.get_width(), tex.get_height()))
	_art_rects[key] = r
	return r
# Half-width of the Fishing Dock's water, as a multiple of its base width (each
# side). main.gd reserves this so the water never touches its neighbours.
const DOCK_WATER_HALF = 1.17

var health = MAX_HEALTH
var building_level = 1
var current_state = State.PRISTINE
var player_inside = false

# Wall torches that auto-light at night (see GameState.torches_lit). Live in
# their own layer so gfx rebuilds don't wipe them.
var torch_layer: Node2D = null
var torches_on = false

# Construction progress: 0 = ruins, GameState.TOTAL_BUILD_STAGES = finished.
var build_stage = 0
var constructing = false
var construction_timer = 0.0

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
	build_stage = int(GameState.building_stage.get(building_name, 0))
	building_level = int(GameState.building_levels.get(building_name, 1))
	if build_stage >= GameState.TOTAL_BUILD_STAGES:
		health = int(GameState.building_health.get(building_name, MAX_HEALTH))
		if health <= 0:
			health = MAX_HEALTH
	else:
		health = 0
	current_state = compute_visual_state()

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
	workers_layer = Node2D.new()   # after gfx so workers draw over the facade
	workers_layer.name = "Workers"
	add_child(workers_layer)
	build_work_area()
	build_torch_layer()
	update_bar_music()

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

# The Marketplace grows too, but flatter: full width growth (it earns a new
# stall SECTION each level, so the row must widen) with only a slight height
# gain so the low open-air stall stays proportionate. The Fishing Dock grows
# ONLY sideways (longer dock/jetty for future fishermen) -- taller water looked
# like it spilled off the ground.
const MARKET_HEIGHT_PER_LEVEL = 0.05
const DOCK_WATER_PER_LEVEL = 0.04   # water creeps out slightly per level

func eff_w() -> float:
	return base_width * (1.0 + (building_level - 1) * WIDTH_PER_LEVEL)

func eff_h() -> float:
	if building_name == "Fishing Dock":
		return base_height   # no vertical growth: the water level stays natural
	var per_level = MARKET_HEIGHT_PER_LEVEL if building_name == "Marketplace" else HEIGHT_PER_LEVEL
	return base_height * (1.0 + (building_level - 1) * per_level)

# The dock's water half-width: grows a touch sideways with each upgrade.
func dock_water_half() -> float:
	return base_width * DOCK_WATER_HALF * (1.0 + (building_level - 1) * DOCK_WATER_PER_LEVEL)

# Fully-upgraded width -- the village layout reserves THIS for every building's
# slot, so however wide a building gets, it can never overlap a neighbour.
func max_upgrade_width() -> float:
	return base_width * (1.0 + (MAX_LEVEL - 1) * WIDTH_PER_LEVEL)

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
	position_torches()
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

# Under construction the visual reuses the damage states as build stages
# (ruins -> half -> nearly-done); once finished the visual follows combat HP.
func state_for_stage(stage: int) -> State:
	match stage:
		0: return State.DESTROYED
		1: return State.HALF
		2: return State.SLIGHT
		_: return State.PRISTINE

func compute_visual_state() -> State:
	if build_stage >= GameState.TOTAL_BUILD_STAGES:
		return state_for_health(health)
	return state_for_stage(build_stage)

func is_operational() -> bool:
	return build_stage >= GameState.TOTAL_BUILD_STAGES and health > 0

func take_damage(amount: int) -> void:
	# only a FINISHED building can be damaged; ruins / building sites can't
	if build_stage < GameState.TOTAL_BUILD_STAGES or health <= 0:
		return
	health = max(0, health - amount)
	GameState.building_health[building_name] = health
	flash_body()
	spawn_hit_debris()
	var new_state: State
	if health <= 0:
		# razed -- back to ruins, must be rebuilt from stage 0 again
		build_stage = 0
		GameState.building_stage[building_name] = 0
		new_state = State.DESTROYED
		update_torches()
		update_prompt()
	else:
		new_state = state_for_health(health)
	update_health_bar()
	if new_state != current_state:
		current_state = new_state
		refresh_visual()
		if current_state == State.DESTROYED:
			var notif = get_node_or_null("../../CanvasLayer/NotificationStack")
			if notif:
				notif.show_notification(building_name + " has been destroyed!")

# --- build / repair (staged) ---

func is_ruined() -> bool:
	return build_stage < GameState.TOTAL_BUILD_STAGES

# "3 Wood · 2 Stone · 1 Resin" -- cost of ONE build stage.
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

# ["Wood 1/3", "Resin 0/1"] -- only the ones still short for one stage.
func missing_repair_materials(player: Node) -> Array:
	var missing = []
	for mat in REPAIR_MATERIALS:
		var have = player.inventory.get_count(mat)
		var need = int(REPAIR_MATERIALS[mat])
		if have < need:
			missing.append("%s %d/%d" % [Inventory.get_display_name(mat), have, need])
	return missing

# Spend one material bundle to raise the building one construction stage.
# Returns "ok" / "busy" / "built" / "materials".
func try_build(player: Node) -> String:
	if constructing:
		return "busy"
	if build_stage >= GameState.TOTAL_BUILD_STAGES:
		return "built"
	# the Forge is a mid-game unlock -- can't be raised until you've gone deep
	if role_key == "Blacksmith" and not GameState.blacksmith_unlocked():
		return "locked"
	if not has_repair_materials(player):
		return "materials"
	for mat in REPAIR_MATERIALS:
		player.inventory.remove_item(mat, int(REPAIR_MATERIALS[mat]))
	advance_build_stage()
	return "ok"

# Commit one stage of construction + play the "rising from the ground" build.
func advance_build_stage() -> void:
	build_stage += 1
	GameState.building_stage[building_name] = build_stage
	if build_stage >= GameState.TOTAL_BUILD_STAGES:
		health = MAX_HEALTH
		GameState.building_health[building_name] = health
		GameState.log_event("village", "The %s stands again." % building_name)
	current_state = compute_visual_state()
	update_health_bar()
	refresh_visual()
	play_construction_animation()
	update_torches()
	update_prompt()

func play_construction_animation() -> void:
	constructing = true
	construction_timer = BUILD_TIME
	if gfx:
		# grows up from the ground line (gfx origin sits at the base)
		gfx.scale = Vector2(1.0, 0.1)
		var t = gfx.create_tween()
		t.tween_property(gfx, "scale", Vector2.ONE, BUILD_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	spawn_build_dust()

# Dust + wood chips kicking up while the stage is raised.
func spawn_build_dust() -> void:
	var w = eff_w()
	var p = CPUParticles2D.new()
	p.position = Vector2(0, -6)
	p.z_index = 6
	p.amount = 20
	p.lifetime = BUILD_TIME
	p.explosiveness = 0.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(w * 0.5, 4.0)
	p.direction = Vector2(0, -1)
	p.spread = 60.0
	p.gravity = Vector2(0, 120)
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 60.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = Color(0.75, 0.68, 0.5, 0.7)
	gfx.add_child(p)
	p.emitting = true
	get_tree().create_timer(BUILD_TIME + 0.3).timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free())

# Fully build + repair a building instantly (admin "restore all", M key).
func restore_full() -> void:
	build_stage = GameState.TOTAL_BUILD_STAGES
	GameState.building_stage[building_name] = build_stage
	health = MAX_HEALTH
	GameState.building_health[building_name] = health
	constructing = false
	current_state = State.PRISTINE
	if gfx:
		gfx.scale = Vector2.ONE
	update_health_bar()
	refresh_visual()
	update_torches()
	update_prompt()

# Press-F build while standing in a ruined / half-built building.
func attempt_field_build() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var notif = get_tree().get_first_node_in_group("notification_stack")
	var result = try_build(player)
	if result == "ok" and notif:
		if build_stage >= GameState.TOTAL_BUILD_STAGES:
			notif.show_notification("%s fully built! Its roles are open now." % building_name)
		else:
			notif.show_notification("%s -- building... (stage %d/%d)" % [building_name, build_stage, GameState.TOTAL_BUILD_STAGES])
	elif result == "materials" and notif:
		notif.show_notification("%s needs: %s" % [building_name, ", ".join(missing_repair_materials(player))])
	var assign_ui = get_node_or_null("../../AssignUI")
	if assign_ui and assign_ui.current_building == self:
		assign_ui.refresh()
	update_prompt()

# Prompt: mid-build shows "Building...", ruins/half show the F build cost + the
# stage counter, a finished building shows the E interact prompt.
func update_prompt() -> void:
	if not prompt_label:
		return
	if constructing:
		prompt_label.text = "Building..."
	elif is_ruined():
		prompt_label.text = "Press F to Build (%s)  —  stage %d/%d" % [repair_requirement_text(), build_stage, GameState.TOTAL_BUILD_STAGES]
	elif building_name == "Farm":
		prompt_label.text = "E: manage   •   Hold H: tend crops"
	else:
		prompt_label.text = "Press E"

# --- wall torches (auto day/night lighting) ---
const TORCH_ENERGY = 1.15
# Shared radial light texture for every torch's PointLight2D (lazy-built once).
static var torch_light_tex: GradientTexture2D = null

static func _torch_tex() -> GradientTexture2D:
	if torch_light_tex == null:
		# richer firelight falloff: hot white core -> pale gold -> warm amber ->
		# long soft tail (the old 3-stop version read flat and "sad")
		var grad = Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.14, 0.42, 1.0])
		grad.colors = PackedColorArray([
			Color(1.0, 1.0, 0.95, 1.0),
			Color(1.0, 0.9, 0.7, 0.85),
			Color(1.0, 0.7, 0.4, 0.38),
			Color(1.0, 0.6, 0.3, 0.0),
		])
		torch_light_tex = GradientTexture2D.new()
		torch_light_tex.gradient = grad
		torch_light_tex.width = 512
		torch_light_tex.height = 512
		torch_light_tex.fill = GradientTexture2D.FILL_RADIAL
		torch_light_tex.fill_from = Vector2(0.5, 0.5)
		torch_light_tex.fill_to = Vector2(1.0, 0.5)
	return torch_light_tex

func build_torch_layer() -> void:
	torch_layer = Node2D.new()
	torch_layer.name = "Torches"
	add_child(torch_layer)
	for i in range(2):
		var t = Node2D.new()
		torch_layer.add_child(t)
		var arm = ColorRect.new()
		arm.size = Vector2(9, 3); arm.position = Vector2(-4, -2); arm.color = Color(0.3, 0.2, 0.12)
		arm.mouse_filter = Control.MOUSE_FILTER_IGNORE; t.add_child(arm)
		var head = ColorRect.new()
		head.size = Vector2(5, 9); head.position = Vector2(-2.5, -11); head.color = Color(0.34, 0.24, 0.14)
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE; t.add_child(head)
		var glow = Polygon2D.new()
		glow.name = "Glow"
		glow.polygon = circle_poly(15.0, 16); glow.position = Vector2(0, -14)
		glow.color = Color(1.0, 0.62, 0.22, 0.13); glow.material = _add_mat(); t.add_child(glow)
		# REAL illumination: a 2D point light that adds warm light back on top of
		# the night CanvasModulate -- a soft ~250px pool of firelight per torch
		# (kept gentle so the night stays moody instead of blinding).
		var light = PointLight2D.new()
		light.name = "Light"
		light.position = Vector2(0, -14)
		light.texture = _torch_tex()
		light.texture_scale = 1.3   # 512px texture -> ~333px pool radius
		light.color = Color(1.0, 0.72, 0.38)
		light.energy = TORCH_ENERGY
		light.shadow_enabled = false
		light.enabled = false
		light.set_meta("flicker_phase", randf() * TAU)
		t.add_child(light)
		var fire = CPUParticles2D.new()
		fire.name = "Flame"; fire.position = Vector2(0, -13); fire.amount = 12; fire.lifetime = 0.5
		fire.direction = Vector2(0, -1); fire.spread = 12.0; fire.gravity = Vector2(0, -130)
		fire.initial_velocity_min = 14.0; fire.initial_velocity_max = 30.0
		fire.scale_amount_min = 1.6; fire.scale_amount_max = 3.0
		fire.color_ramp = _fire_gradient(); fire.emitting = false
		t.add_child(fire)
	update_torches()

# Per-building torch anchors -- {x, y} as fractions of eff_w half / eff_h --
# hand-placed so both torches sit ON that building's actual wall (mirrored,
# symmetric), clear of its windows/props: flanking the Government's portico,
# the Barracks gate, the dock hut's walls, the Marketplace's end posts, the
# Tavern door, etc.
const TORCH_SPECS = {
	"Government": {"x": 0.45, "y": 0.50},
	"School": {"x": 0.44, "y": 0.50},
	"Farm": {"x": 0.30, "y": 0.40},
	"Hospital": {"x": 0.44, "y": 0.60},
	"Barracks": {"x": 0.20, "y": 0.45},
	"Fishing Dock": {"x": 0.24, "y": 0.62},
	"Science Lab": {"x": 0.44, "y": 0.45},
	"Bank": {"x": 0.22, "y": 0.50},
	"Blacksmith": {"x": 0.45, "y": 0.32},
	"Tavern": {"x": 0.12, "y": 0.52},
	"Bar": {"x": 0.42, "y": 0.5},
	"Marketplace": {"x": 0.47, "y": 0.48},
	"Builderhouse": {"x": 0.28, "y": 0.40},
}

func position_torches() -> void:
	if not torch_layer:
		return
	var spec = TORCH_SPECS.get(building_name, {"x": 0.42, "y": 0.45})
	var w = eff_w()
	var h = eff_h()
	var kids = torch_layer.get_children()
	if kids.size() >= 2:
		kids[0].position = Vector2(-w * spec.x, -h * spec.y)
		kids[1].position = Vector2(w * spec.x, -h * spec.y)
		kids[1].scale.x = -1.0   # mirror the bracket so both face outward

# The torch bracket + head stay visible ALL the time (an unlit torch on the
# wall by day); only the flame, glow, and actual light toggle with night.
func update_torches() -> void:
	if not torch_layer:
		return
	torch_layer.visible = build_stage >= GameState.TOTAL_BUILD_STAGES
	for t in torch_layer.get_children():
		for c in t.get_children():
			if c is CPUParticles2D:
				c.emitting = torches_on
			elif c is PointLight2D:
				c.enabled = torches_on
			elif c is Polygon2D:   # the additive glow disc
				c.visible = torches_on

func _add_mat() -> CanvasItemMaterial:
	var m = CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m

func _fire_gradient() -> Gradient:
	var g = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	g.colors = PackedColorArray([Color(1, 0.95, 0.6, 1), Color(1, 0.55, 0.15, 1), Color(0.6, 0.1, 0.05, 0)])
	return g

# --- villagers at work (visible busy-ness once people are employed here) ---
# Window buildings show dark silhouettes pacing behind the glass (some rushing
# papers between offices, some strolling elegantly); outdoor buildings get
# little workers in a defined spot/strip: the smith hammers with sparks, the
# dock gets up to 6 fishing spots along the deck, vendors man market stalls,
# a guard patrols the Barracks gate, farmhands walk the yard.
const WORKER_SCRIPT = preload("res://worker_figure.gd")
const MAX_VISIBLE_WORKERS = 6

# window rects as fractions: [cx(of w, signed), top(of h, up), width(of w), height(of h)]
const WORK_WINDOWS = {
	"Government": [[-0.16, 0.55, 0.05, 0.20], [0.16, 0.55, 0.05, 0.20]],
	"School": [[-0.32, 0.55, 0.08, 0.26], [-0.16, 0.55, 0.08, 0.26], [0.16, 0.55, 0.08, 0.26], [0.32, 0.55, 0.08, 0.26]],
	"Hospital": [[-0.34, 0.5, 0.07, 0.12], [-0.2, 0.5, 0.07, 0.12], [0.2, 0.5, 0.07, 0.12], [0.34, 0.5, 0.07, 0.12], [-0.2, 0.32, 0.07, 0.12], [0.2, 0.32, 0.07, 0.12]],
	"Bank": [[-0.44, 0.5, 0.04, 0.15], [0.44, 0.5, 0.04, 0.15]],
	"Science Lab": [[-0.32, 0.475, 0.08, 0.09], [0.32, 0.475, 0.08, 0.09]],
	"Tavern": [[-0.19, 0.52, 0.11, 0.18], [0.19, 0.52, 0.11, 0.18]],
	"Bar": [[-0.22, 0.5, 0.12, 0.2], [0.22, 0.5, 0.12, 0.2]],
}
# Buildings whose whole workforce works a special structure (no side-yard):
# market stalls / dock fishing spots.
const WORK_OUTDOOR = {
	"Marketplace": {"mode": "vendor"},
	"Fishing Dock": {"mode": "fish"},
}

# --- attached work-yards ---
# Every other building gets a themed side-yard in the gap to its right (past
# its max-upgrade width, so upgrades never swallow it). Employed villagers are
# split: half inside behind the windows, half out here at the yard's stations
# (or pacing it). Props are drawn by build_work_area() per building.
# station entry: [mode, local_x] -- modes: stand / smith (gold sparks) /
# train (straw dust) / saw (wood chips).
const WORK_AREA = {
	"Government": {"stations": [["stand", -30.0], ["sweep", 8.0], ["carry", 0.0]]},
	"School": {"stations": [["stand", 27.0], ["sweep", -14.0], ["carry", 0.0]]},
	"Farm": {"stations": [["hoe", -40.0], ["stand", 52.0], ["carry", 0.0]]},
	"Hospital": {"stations": [["stand", -16.0], ["grind", 34.0], ["sweep", 8.0]]},
	"Barracks": {"stations": [["train", -2.0], ["stand", -46.0], ["carry", 0.0]]},
	"Science Lab": {"stations": [["stand", -8.0], ["grind", 40.0], ["carry", 0.0]]},
	"Bank": {"stations": [["stand", -14.0], ["carry", 0.0], ["sweep", 36.0]]},
	"Blacksmith": {"stations": [["smith", -20.0], ["carry", 0.0], ["smith", 44.0]]},
	"Tavern": {"stations": [["stand", -22.0], ["carry", 0.0], ["sweep", 48.0]]},
	"Bar": {"stations": [["stand", -22.0], ["sweep", -46.0], ["carry", 0.0]]},
	"Builderhouse": {"stations": [["saw", -20.0], ["carry", 0.0], ["stand", 44.0]]},
}
const AREA_HALF = 90.0    # yard DESIGN half-width (props are laid out in this space)
const AREA_SCALE = 1.5    # whole yard is drawn 1.5x so props/pads match NPC size

# World-space half-width of the (scaled) yard.
func area_world_half() -> float:
	return AREA_HALF * AREA_SCALE

# Yard centre in building-local x: just past the reserved max-upgrade width.
func area_offset_x() -> float:
	return base_width * 0.7 + 16.0 + area_world_half()
# the dock's 6 fishing spots: (x frac of w, y frac of h up, facing)
const DOCK_FISH_SPOTS = [
	[-0.38, 0.40, -1], [-0.32, 0.40, -1], [0.34, 0.40, 1],
	[0.40, 0.36, 1], [0.47, 0.36, 1], [0.53, 0.36, 1],
]

var workers_layer: Node2D = null
var area_layer: Node2D = null
var worker_timer := 0.0
var last_employed := -1
var last_operational_state := false

# Farm-only: the crop field is redrawn to reflect the village larder (see
# GameState.village_food) -- lush when stocked, withered when empty. The player
# hand-tends it by holding the harvest key, filling the larder in +food chunks.
const FARM_HARVEST_INTERVAL := 0.4    # seconds between +food chunks while tending
const HOSPITAL_HEAL_PRICE := 12       # 5.5 Health: flat ward price, the Doctor's successor
var farm_crop_layer: Node2D = null
var harvest_cooldown := 0.0

func employed_count() -> int:
	var n = 0
	for v in GameState.rescued_villagers:
		if v.get("role_key", "") == role_key:
			n += 1
	return min(n, MAX_VISIBLE_WORKERS)

# A quick door-swing overlay at the entrance so villager entries/exits read
# visibly on the facade: the dark doorway shows, the panel swings open, holds
# a beat while the NPC slips through, then shuts. Self-cleaning.
func play_door_anim() -> void:
	var w = eff_w()
	var dw = clampf(w * 0.14, 14.0, 28.0)
	var dh = dw * 1.9
	var frame := ColorRect.new()
	frame.size = Vector2(dw, dh)
	frame.position = Vector2(-dw / 2.0, -dh)
	frame.color = Color(0.05, 0.045, 0.04, 0.95)
	frame.z_index = 3
	add_child(frame)
	var door := ColorRect.new()
	door.size = Vector2(dw, dh)
	door.position = Vector2(-dw / 2.0, -dh)
	door.color = Color(0.23, 0.15, 0.09)
	door.z_index = 4
	door.pivot_offset = Vector2(0.0, dh / 2.0)   # hinge on the left jamb
	add_child(door)
	var t := create_tween()
	t.tween_property(door, "scale:x", 0.12, 0.2).set_trans(Tween.TRANS_SINE)
	t.tween_interval(0.55)
	t.tween_property(door, "scale:x", 1.0, 0.2).set_trans(Tween.TRANS_SINE)
	t.tween_callback(frame.queue_free)
	t.tween_callback(door.queue_free)

func refresh_workers() -> void:
	if not workers_layer:
		return
	for c in workers_layer.get_children():
		workers_layer.remove_child(c)
		c.queue_free()
	var n = employed_count()
	if n <= 0 or not is_operational():
		return
	var w = eff_w()
	var h = eff_h()
	var windows = WORK_WINDOWS.get(building_name, [])
	var special = WORK_OUTDOOR.get(building_name, {})     # market stalls / dock
	var area = WORK_AREA.get(building_name, {})
	# split the crew: half behind the windows, half out in the attached yard
	# (buildings with no windows send everyone outside; the dock/market crews
	# all work their special structure instead)
	var inside_n = 0
	if windows.size() > 0 and special.is_empty():
		inside_n = int(ceil(n / 2.0)) if not area.is_empty() else n
	var stations = area.get("stations", [])
	var ax = area_offset_x()
	for i in range(n):
		var fig = WORKER_SCRIPT.new()
		if special.get("mode", "") == "vendor":
			fig.mode = "vendor"
			var sections = market_sections()
			var idx = i % sections
			fig.spot = Vector2(-w * 0.45 + (idx + 0.5) * (w * 0.9 / float(sections)), 0.0)
		elif special.get("mode", "") == "fish":
			fig.mode = "fish"
			var s = DOCK_FISH_SPOTS[i % DOCK_FISH_SPOTS.size()]
			fig.spot = Vector2(w * s[0], -h * s[1])
			fig.face = s[2]
		elif i < inside_n:
			var spec = windows[i % windows.size()]
			fig.mode = "window"
			fig.window_rect = Rect2(w * spec[0] - w * spec[2] / 2.0, -h * spec[1], w * spec[2], h * spec[3])
		else:
			var j = i - inside_n
			if j < stations.size():
				var st = stations[j]
				# Every trade below used to run the SAME hammer-rock with a
				# different chip colour -- the farmer, the sawyer and the soldier
				# were all miming the smith. `craft` names the real drawn motion;
				# a worker whose villager art has it performs it, and anyone whose
				# art doesn't falls back to the old rock (see worker_figure.gd).
				match st[0]:
					"smith":
						fig.mode = "anvil"; fig.craft = "smith"; fig.sparks = true
					"train":
						fig.mode = "anvil"; fig.craft = "train"; fig.sparks = false; fig.chip_color = Color(0.82, 0.72, 0.42)
					"saw":
						fig.mode = "anvil"; fig.craft = "saw"; fig.sparks = false; fig.chip_color = Color(0.72, 0.52, 0.3)
					"hoe":
						fig.mode = "anvil"; fig.craft = "hoe"; fig.sparks = false; fig.chip_color = Color(0.45, 0.34, 0.2)
					"grind":
						fig.mode = "anvil"; fig.craft = "grind"; fig.sparks = false; fig.chip_color = Color(0.45, 0.8, 0.5)
					"sweep":
						fig.mode = "sweep"; fig.craft = "sweep"
					"carry":
						fig.mode = "carry"
						fig.min_x = ax - area_world_half() + 14.0
						fig.max_x = ax + area_world_half() - 14.0
					_:
						fig.mode = "stand"
				fig.spot = Vector2(ax + st[1] * AREA_SCALE, 0.0)   # stations scale with the yard
			else:
				fig.mode = "walk"
				fig.min_x = ax - area_world_half() + 12.0
				fig.max_x = ax + area_world_half() - 12.0
		workers_layer.add_child(fig)

# --- attached work-yard props ---
func _a_rect(pos: Vector2, size: Vector2, col: Color) -> void:
	var r = ColorRect.new()
	r.position = pos
	r.size = size
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area_layer.add_child(r)

func _a_disc(c: Vector2, radius: float, col: Color, sides := 12) -> void:
	var p = Polygon2D.new()
	p.polygon = circle_poly(radius, sides)
	p.position = c
	p.color = col
	area_layer.add_child(p)

func _a_line(pts: PackedVector2Array, wdt: float, col: Color) -> void:
	var l = Line2D.new()
	l.points = pts
	l.width = wdt
	l.default_color = col
	area_layer.add_child(l)

# --- Farm crops (dynamic) ---
# Redraw the crop field to reflect how full the village larder is (0..1). A full
# larder = tall, lush, golden-topped stalks; a draining one shortens and pales;
# an empty larder leaves bare brown stubs -- an at-a-glance "the town is starving"
# cue that matches the HUD food gauge. Cheap: a handful of primitives per call.
func _update_farm_crops() -> void:
	if farm_crop_layer == null or not is_instance_valid(farm_crop_layer):
		return
	for c in farm_crop_layer.get_children():
		c.queue_free()
	var cap = GameState.food_capacity()
	var f = clampf(GameState.village_food / cap, 0.0, 1.0) if cap > 0.0 else 0.0
	for r in range(3):
		var rx = -58.0 + r * 34.0
		for s in range(3):
			_draw_crop(rx + 4.0 + s * 9.0, -3.0, f)

func _draw_crop(cx: float, base_y: float, f: float) -> void:
	if f <= 0.03:
		# barren: a small withered brown nub
		var nub = Polygon2D.new()
		nub.polygon = circle_poly(1.3, 5)
		nub.position = Vector2(cx, base_y - 1.0)
		nub.color = Color(0.5, 0.36, 0.2)
		farm_crop_layer.add_child(nub)
		return
	var height = lerpf(3.0, 11.0, f)
	# stalk pales when the larder is low, deepens to a healthy green when stocked
	var stalk_col = Color(0.55, 0.55, 0.24).lerp(Color(0.28, 0.62, 0.26), f)
	var stalk = Line2D.new()
	stalk.points = PackedVector2Array([Vector2(cx, base_y), Vector2(cx, base_y - height)])
	stalk.width = 1.6
	stalk.default_color = stalk_col
	farm_crop_layer.add_child(stalk)
	# grain head: green when growing, golden-ripe when the larder is near full
	var head = Polygon2D.new()
	head.polygon = circle_poly(lerpf(1.1, 2.3, f), 6)
	head.position = Vector2(cx, base_y - height)
	head.color = stalk_col.lightened(0.1) if f < 0.8 else Color(0.87, 0.75, 0.33)
	farm_crop_layer.add_child(head)

# A quick dirt puff at the field while the player tends it.
func _spawn_harvest_puff() -> void:
	if area_layer == null:
		return
	for i in range(4):
		var d = Polygon2D.new()
		d.polygon = circle_poly(randf_range(1.2, 2.4), 6)
		d.color = Color(0.5, 0.38, 0.24, 0.85)
		d.position = Vector2(randf_range(-58.0, -6.0), -3.0)
		area_layer.add_child(d)
		var tw = d.create_tween()
		tw.set_parallel(true)
		tw.tween_property(d, "position", d.position + Vector2(randf_range(-6, 6), randf_range(-10, -4)), 0.4)
		tw.tween_property(d, "modulate:a", 0.0, 0.4)
		tw.chain().tween_callback(d.queue_free)

# A small "+N" that floats up over the building when food is gained by hand.
func _spawn_harvest_float(text: String) -> void:
	var lbl = _make_label(text, 14)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.95, 0.4))
	lbl.position = Vector2(-14.0, -base_height - 24.0)
	add_child(lbl)
	var tw = lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 22.0, 0.7)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.7)
	tw.chain().tween_callback(lbl.queue_free)

# The themed side-yard beside each building (local origin = yard centre, ground
# y = 0). Built once; shown only while the building is operational.
func build_work_area() -> void:
	if not WORK_AREA.has(building_name):
		return
	area_layer = Node2D.new()
	area_layer.name = "WorkArea"
	area_layer.position = Vector2(area_offset_x(), 0.0)
	area_layer.scale = Vector2(AREA_SCALE, AREA_SCALE)
	add_child(area_layer)
	area_layer.visible = is_operational()
	# shared dirt pad + a couple of grass tufts
	_a_rect(Vector2(-AREA_HALF, -3), Vector2(AREA_HALF * 2.0, 5), Color(0.42, 0.34, 0.22, 0.85))
	_a_disc(Vector2(-AREA_HALF + 8, -3), 2.5, DEEP_GREEN, 6)
	_a_disc(Vector2(AREA_HALF - 10, -3), 2.5, DEEP_GREEN, 6)
	match building_name:
		"Government":
			# notice board + green state flag + a waiting bench: clerks post
			# decrees, sweep the plaza, and carry document chests across it
			_a_rect(Vector2(-30, -28), Vector2(3, 28), TIMBER)
			_a_rect(Vector2(-9, -28), Vector2(3, 28), TIMBER)
			_a_rect(Vector2(-34, -30), Vector2(32, 18), TIMBER_L)
			_a_rect(Vector2(-30, -27), Vector2(8, 10), Color(0.94, 0.93, 0.86))
			_a_rect(Vector2(-19, -26), Vector2(8, 8), Color(0.9, 0.88, 0.8))
			_a_rect(Vector2(34, -42), Vector2(3, 42), TIMBER)
			_a_line(PackedVector2Array([Vector2(37, -40), Vector2(52, -36), Vector2(37, -31)]), 2.0, DEEP_GREEN)
			_a_rect(Vector2(52, -9), Vector2(24, 3), Color(0.82, 0.8, 0.74))   # stone bench
			_a_rect(Vector2(54, -6), Vector2(4, 6), Color(0.7, 0.68, 0.62))
			_a_rect(Vector2(70, -6), Vector2(4, 6), Color(0.7, 0.68, 0.62))
		"School":
			# schoolyard: bench + play ball
			_a_rect(Vector2(8, -10), Vector2(28, 3), TIMBER_L)
			_a_rect(Vector2(10, -7), Vector2(3, 7), TIMBER)
			_a_rect(Vector2(30, -7), Vector2(3, 7), TIMBER)
			_a_disc(Vector2(-22, -4), 4.5, Color(0.82, 0.3, 0.25))
		"Farm":
			# tilled rows + a scarecrow + a stone well: hands hoe the rows and
			# haul produce crates between them. The CROPS themselves live in a
			# separate layer that's redrawn to track the village larder, so the
			# field visibly flourishes or withers with the town's food.
			for r in range(3):
				var rx = -58.0 + r * 34.0
				_a_rect(Vector2(rx, -2), Vector2(26, 4), Color(0.32, 0.24, 0.16))
			farm_crop_layer = Node2D.new()
			farm_crop_layer.name = "Crops"
			area_layer.add_child(farm_crop_layer)
			_update_farm_crops()
			_a_rect(Vector2(50, -30), Vector2(3, 30), TIMBER)
			_a_rect(Vector2(41, -24), Vector2(21, 3), TIMBER)
			_a_disc(Vector2(51.5, -33), 4.0, Color(0.85, 0.72, 0.4))
			_a_rect(Vector2(70, -12), Vector2(16, 12), Color(0.55, 0.55, 0.58))  # well
			_a_rect(Vector2(72, -22), Vector2(2, 10), TIMBER)
			_a_rect(Vector2(82, -22), Vector2(2, 10), TIMBER)
			_a_rect(Vector2(69, -25), Vector2(18, 4), Color(0.48, 0.28, 0.2))
		"Hospital":
			# recovery cot + red-cross banner
			_a_rect(Vector2(-34, -9), Vector2(34, 3), Color(0.92, 0.93, 0.94))
			_a_rect(Vector2(-33, -6), Vector2(3, 6), Color(0.5, 0.5, 0.55))
			_a_rect(Vector2(-4, -6), Vector2(3, 6), Color(0.5, 0.5, 0.55))
			_a_rect(Vector2(-33, -12), Vector2(9, 3), Color(0.8, 0.82, 0.9))
			_a_rect(Vector2(30, -38), Vector2(3, 38), TIMBER)
			_a_rect(Vector2(33, -36), Vector2(12, 9), Color(0.95, 0.95, 0.95))
			_a_rect(Vector2(37.5, -34.5), Vector2(3, 6), Color(0.85, 0.15, 0.15))
			_a_rect(Vector2(36, -33), Vector2(6, 3), Color(0.85, 0.15, 0.15))
		"Barracks":
			# training dummy + target board + weapon rack: a full drill yard
			_a_rect(Vector2(9, -26), Vector2(3.5, 26), TIMBER)
			_a_rect(Vector2(-1, -20), Vector2(23, 3), TIMBER_L)
			_a_disc(Vector2(10.5, -29), 4.5, Color(0.82, 0.72, 0.42))
			_a_disc(Vector2(-38, -18), 8.0, Color(0.9, 0.88, 0.8))
			_a_disc(Vector2(-38, -18), 5.0, Color(0.8, 0.3, 0.25))
			_a_disc(Vector2(-38, -18), 2.0, Color(0.95, 0.9, 0.85))
			_a_rect(Vector2(-39.5, -10), Vector2(3, 10), TIMBER)
			_a_rect(Vector2(46, -20), Vector2(28, 3), TIMBER)          # weapon rack
			_a_rect(Vector2(47, -17), Vector2(3, 17), TIMBER)
			_a_rect(Vector2(70, -17), Vector2(3, 17), TIMBER)
			_a_line(PackedVector2Array([Vector2(53, -18), Vector2(55, -2)]), 2.0, Color(0.75, 0.78, 0.84))
			_a_line(PackedVector2Array([Vector2(61, -18), Vector2(61, -2)]), 2.0, Color(0.55, 0.35, 0.15))
			_a_line(PackedVector2Array([Vector2(67, -18), Vector2(65, -2)]), 2.0, Color(0.75, 0.78, 0.84))
		"Science Lab":
			# experiment bench with flasks + a field telescope on a tripod
			_a_rect(Vector2(-28, -14), Vector2(38, 3), Color(0.55, 0.58, 0.66))
			_a_rect(Vector2(-26, -11), Vector2(3, 11), Color(0.4, 0.42, 0.5))
			_a_rect(Vector2(5, -11), Vector2(3, 11), Color(0.4, 0.42, 0.5))
			_a_disc(Vector2(-20, -17), 3.0, Color(0.4, 0.9, 0.6))
			_a_disc(Vector2(-11, -17), 3.0, Color(0.9, 0.6, 0.25))
			_a_disc(Vector2(-2, -17), 3.0, Color(0.45, 0.6, 0.95))
			_a_line(PackedVector2Array([Vector2(52, 0), Vector2(58, -14)]), 2.0, Color(0.35, 0.37, 0.44))
			_a_line(PackedVector2Array([Vector2(64, 0), Vector2(58, -14)]), 2.0, Color(0.35, 0.37, 0.44))
			_a_line(PackedVector2Array([Vector2(52, -22), Vector2(66, -12)]), 3.5, Color(0.5, 0.54, 0.64))   # scope tube
		"Bank":
			# guarded strongbox + coin sacks
			_a_rect(Vector2(-28, -13), Vector2(26, 13), TIMBER)
			_a_rect(Vector2(-28, -16), Vector2(26, 4), TIMBER.darkened(0.25))
			_a_disc(Vector2(-15, -9), 2.2, Color(0.9, 0.75, 0.25), 8)
			_a_disc(Vector2(18, -5), 5.0, Color(0.72, 0.62, 0.34))
			_a_disc(Vector2(30, -4), 4.0, Color(0.68, 0.58, 0.32))
		"Blacksmith":
			# two anvils, quench barrel + a glowing ingot stack
			_a_rect(Vector2(-16, -7), Vector2(13, 7), Color(0.3, 0.3, 0.34))
			_a_rect(Vector2(-6, -10), Vector2(9, 4), Color(0.34, 0.34, 0.38))
			_a_disc(Vector2(24, -8), 7.0, TIMBER_L)
			_a_disc(Vector2(24, -13), 5.0, Color(0.3, 0.5, 0.65))
			_a_rect(Vector2(48, -7), Vector2(13, 7), Color(0.3, 0.3, 0.34))    # second anvil
			_a_rect(Vector2(58, -10), Vector2(9, 4), Color(0.34, 0.34, 0.38))
			_a_rect(Vector2(70, -5), Vector2(10, 3), Color(0.85, 0.5, 0.2))    # hot ingots
			_a_rect(Vector2(72, -8), Vector2(8, 3), Color(0.7, 0.4, 0.18))
		"Tavern":
			# two outdoor tables with mugs
			for tx in [-30.0, 22.0]:
				_a_rect(Vector2(tx, -12), Vector2(26, 3), TIMBER_L)
				_a_rect(Vector2(tx + 2, -9), Vector2(3, 9), TIMBER)
				_a_rect(Vector2(tx + 21, -9), Vector2(3, 9), TIMBER)
				_a_disc(Vector2(tx + 8, -14), 2.2, Color(0.85, 0.65, 0.3), 8)
				_a_disc(Vector2(tx + 17, -14), 2.2, Color(0.85, 0.65, 0.3), 8)
		"Bar":
			# night terrace: table, stools, lantern post
			_a_rect(Vector2(-32, -12), Vector2(24, 3), TIMBER_L)
			_a_rect(Vector2(-30, -9), Vector2(3, 9), TIMBER)
			_a_rect(Vector2(-12, -9), Vector2(3, 9), TIMBER)
			_a_disc(Vector2(4, -6), 3.5, TIMBER_L, 8)
			_a_disc(Vector2(16, -6), 3.5, TIMBER_L, 8)
			_a_rect(Vector2(34, -34), Vector2(3, 34), TIMBER)
			_a_disc(Vector2(35.5, -36), 4.0, Color(1.0, 0.8, 0.4, 0.9))
		"Builderhouse":
			# sawhorse with a plank + toolbox + a crate stack to haul
			_a_line(PackedVector2Array([Vector2(-28, 0), Vector2(-22, -12)]), 2.5, TIMBER)
			_a_line(PackedVector2Array([Vector2(-16, 0), Vector2(-22, -12)]), 2.5, TIMBER)
			_a_line(PackedVector2Array([Vector2(-6, 0), Vector2(0, -12)]), 2.5, TIMBER)
			_a_line(PackedVector2Array([Vector2(6, 0), Vector2(0, -12)]), 2.5, TIMBER)
			_a_rect(Vector2(-30, -15), Vector2(38, 4), TIMBER_L)
			_a_rect(Vector2(22, -8), Vector2(14, 8), Color(0.66, 0.3, 0.2))
			_a_rect(Vector2(27, -10), Vector2(4, 2), Color(0.4, 0.2, 0.14))
			_a_rect(Vector2(48, -10), Vector2(12, 10), Color(0.62, 0.44, 0.26))  # crates
			_a_rect(Vector2(52, -19), Vector2(12, 9), Color(0.56, 0.4, 0.24))
			_a_rect(Vector2(66, -9), Vector2(11, 9), Color(0.6, 0.42, 0.25))

# --- the Bar's fun music + player morale ---
static var bar_tune_stream: AudioStreamWAV = null
var bar_music: AudioStreamPlayer2D = null

# A jaunty little chiptune jig, synthesized once: square-wave melody over a
# bouncing bass, ~3.4s, looped. Routed through the Music bus.
static func _bar_tune() -> AudioStreamWAV:
	if bar_tune_stream != null:
		return bar_tune_stream
	var rate := 22050
	var bpm := 150.0
	var note_len := 60.0 / bpm / 2.0   # eighth notes
	var mel = [392.0, 494.0, 587.0, 494.0, 523.0, 494.0, 440.0, 392.0,
		330.0, 392.0, 440.0, 494.0, 440.0, 392.0, 440.0, 494.0]
	var n_total := int(rate * note_len * mel.size())
	var data := PackedByteArray()
	data.resize(n_total * 2)
	for i in range(n_total):
		var tsec := float(i) / rate
		var ni := int(tsec / note_len) % mel.size()
		var nt := fmod(tsec, note_len)
		var f: float = mel[ni]
		var env := (1.0 - exp(-nt * 60.0)) * exp(-nt * 4.0)
		var lead := (1.0 if fmod(f * tsec, 1.0) < 0.5 else -1.0) * 0.16 * env
		var bass_f: float = f / 2.0 if ni % 2 == 0 else f / 3.0 * 2.0
		var bass := sin(TAU * bass_f * tsec) * 0.1 * env
		var v := clampf(lead + bass, -1.0, 1.0)
		var s16 := int(v * 30000.0)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	bar_tune_stream = AudioStreamWAV.new()
	bar_tune_stream.format = AudioStreamWAV.FORMAT_16_BITS
	bar_tune_stream.mix_rate = rate
	bar_tune_stream.stereo = false
	bar_tune_stream.data = data
	bar_tune_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	bar_tune_stream.loop_begin = 0
	bar_tune_stream.loop_end = n_total
	return bar_tune_stream

func update_bar_music() -> void:
	if building_name != "Bar":
		return
	if bar_music == null:
		bar_music = AudioStreamPlayer2D.new()
		bar_music.stream = _bar_tune()
		bar_music.bus = "Music"
		bar_music.volume_db = -6.0
		bar_music.max_distance = 900.0
		bar_music.position = Vector2(0, -eff_h() * 0.4)
		add_child(bar_music)
	if is_operational() and not bar_music.playing:
		bar_music.play()
	elif not is_operational() and bar_music.playing:
		bar_music.stop()

# --- upgrades ---

func can_upgrade() -> bool:
	return building_level < MAX_LEVEL and not is_ruined()

func upgrade_cost() -> int:
	return UPGRADE_COST_GOLD

# Spend gold, bump the level, and grow/redecorate. Returns why it failed.
func try_upgrade(player: Node) -> String:
	if is_ruined():
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
	if role_def.get("leadership", false) or role_def.get("is_enrollment", false):
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

# Pristine + slightly-damaged share the building's real silhouette (drawn to
# look like what its name says -- a schoolhouse, a barn, a hospital...); when
# `damaged` it just dims and adds a few cracks/scorch. A light Deepwood touch
# (mossy green trim, timber) runs through all of them.
func build_intact(damaged: bool) -> void:
	var w = eff_w()
	var h = eff_h()
	# PixelLab facade: stretch the painted front to the level-scaled footprint
	# with its base on the ground line. Damage dims it and adds cracks/scorch
	# on top; everything else (labels, torches, bars) is positioned by
	# rebuild_geometry as usual.
	var art_file: String = BUILDING_ART.get(building_name, "")
	if art_file != "" and ResourceLoader.exists("res://art/buildings/%s.png" % art_file):
		var tex: Texture2D = load("res://art/buildings/%s.png" % art_file)
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.centered = false
		# draw only the CONTENT box of the PNG (the canvas has transparent
		# padding after backdrop-stripping) so the art's true base sits exactly
		# on the ground line instead of levitating
		var content := _art_content_rect(art_file, tex)
		spr.region_enabled = true
		spr.region_rect = content
		# UNIFORM scale, driven by height: a per-axis fit stretched every facade
		# to a made-up footprint (the Dock came out 72% too wide). The sink rows
		# are scaled away first, so `h` is the height the building actually
		# stands ABOVE ground and the buried rows fall below y=0 on their own.
		var ch: float = maxf(content.size.y - float(ART_SINK.get(building_name, 0.0)), 1.0)
		var s: float = h / ch
		var dw: float = content.size.x * s
		spr.scale = Vector2(s, s)
		spr.position = Vector2(-dw / 2.0, -h)
		if damaged:
			spr.modulate = Color(0.68, 0.66, 0.64)
		gfx.add_child(spr)
		# living candle-light: the painted windows/fires flicker (see
		# building_lights.gd) -- skipped while damaged, the lights are out
		if not damaged:
			var lights := BuildingLights.new()
			gfx.add_child(lights)
			lights.build(tex, content, spr.position, spr.scale, building_name)
		body_node = null
		if building_level >= 4:
			add_pennant(w, h)
		if damaged:
			add_cracks(w, h, 3)
			add_scorch(w, h, 1, 7.0)
		return
	var lit = not damaged
	draw_named_building(w, h, lit, damaged)
	if building_level >= 4:
		add_pennant(w, h)
	if damaged:
		add_cracks(w, h, 3)
		add_scorch(w, h, 1, 7.0)

# --- shared tiny draw helpers for the named silhouettes ---
func _disc(c: Vector2, r: float, col: Color, sides := 16) -> void:
	var pts = PackedVector2Array()
	for i in range(sides):
		var a = TAU * float(i) / sides
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	add_poly(pts, col)

func _tri(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	add_poly(PackedVector2Array([a, b, c]), col)

func _ln(pts: PackedVector2Array, wdt: float, col: Color) -> void:
	var l = Line2D.new()
	l.points = pts
	l.width = wdt
	l.default_color = col
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	gfx.add_child(l)

func _lit_col(lit: bool) -> Color:
	return Color(0.98, 0.86, 0.5, 0.96) if lit else Color(0.36, 0.4, 0.42, 1.0)

func _win(cx: float, cy: float, ww: float, hh: float, lit: bool) -> void:
	add_rect(Vector2(cx - ww * 0.5, cy), Vector2(ww, hh), _lit_col(lit))

# Deepwood accents
const DEEP_GREEN = Color(0.24, 0.4, 0.26)
const TIMBER = Color(0.4, 0.28, 0.16)
const TIMBER_L = Color(0.55, 0.4, 0.24)

func draw_named_building(w: float, h: float, lit: bool, damaged: bool) -> void:
	match building_name:
		"Government": _b_government(w, h, lit)
		"School": _b_school(w, h, lit)
		"Farm": _b_farm(w, h, lit)
		"Hospital": _b_hospital(w, h, lit)
		"Barracks": _b_barracks(w, h, lit)
		"Fishing Dock": _b_dock(w, h, lit)
		"Science Lab": _b_lab(w, h, lit)
		"Bank": _b_bank(w, h, lit)
		"Blacksmith": _b_blacksmith(w, h, lit)
		"Tavern": _b_tavern(w, h, lit)
		"Bar": _b_bar(w, h, lit)
		"Marketplace": _b_market(w, h, lit)
		"Builderhouse": _b_builder(w, h, lit)
		_:
			add_body(rect_poly(w, h), body_color)
			build_roof(w, h, body_color.darkened(0.32))
			add_door(body_color.darkened(0.5), h)
			add_window_grid(w, h, lit)
			build_feature(w, h)
	if damaged and body_node:
		body_node.color = body_node.color.darkened(0.14)

# GOVERNMENT -- neoclassical capitol: stone body, portico of columns, pediment,
# central dome, deepwood-green flag.
func _b_government(w: float, h: float, lit: bool) -> void:
	var stone = Color(0.82, 0.8, 0.74)
	add_body(rect_poly(w, h * 0.82), stone)
	add_rect(Vector2(-w * 0.52, -h * 0.06), Vector2(w * 1.04, h * 0.06), stone.darkened(0.18))  # steps
	add_rect(Vector2(-w * 0.47, -h * 0.12), Vector2(w * 0.94, h * 0.06), stone.darkened(0.08))
	var cols = 6
	for i in range(cols):
		var cx = lerp(-w * 0.4, w * 0.4, float(i) / float(cols - 1))
		add_rect(Vector2(cx - w * 0.018, -h * 0.7), Vector2(w * 0.036, h * 0.58), stone.lightened(0.12))
	add_rect(Vector2(-w * 0.47, -h * 0.78), Vector2(w * 0.94, h * 0.08), stone.darkened(0.12))  # entablature
	_tri(Vector2(-w * 0.47, -h * 0.78), Vector2(w * 0.47, -h * 0.78), Vector2(0, -h * 0.96), stone)  # pediment
	_disc(Vector2(0, -h * 0.96), w * 0.11, stone.lightened(0.06), 18)  # dome
	add_rect(Vector2(-1.5, -h * 1.18), Vector2(3, h * 0.16), TIMBER)   # flagpole
	_tri(Vector2(1.5, -h * 1.18), Vector2(w * 0.1, -h * 1.13), Vector2(1.5, -h * 1.08), DEEP_GREEN)
	add_rect(Vector2(-w * 0.05, -h * 0.44), Vector2(w * 0.1, h * 0.44), Color(0.3, 0.24, 0.16))  # door
	for sx in [-w * 0.16, w * 0.16]:   # mirrored, in the column gaps beside the door
		_win(sx, -h * 0.55, w * 0.05, h * 0.2, lit)

# SCHOOL -- brick schoolhouse: gable roof, bell cupola with a bell, flag, arched
# entrance, tall windows.
func _b_school(w: float, h: float, lit: bool) -> void:
	var brick = Color(0.7, 0.42, 0.34)
	add_body(rect_poly(w, h * 0.78), brick)
	_tri(Vector2(-w * 0.54, -h * 0.78), Vector2(w * 0.54, -h * 0.78), Vector2(0, -h * 1.0), brick.darkened(0.3))  # roof
	# bell cupola
	add_rect(Vector2(-w * 0.09, -h * 1.06), Vector2(w * 0.18, h * 0.12), Color(0.9, 0.88, 0.82))
	_tri(Vector2(-w * 0.1, -h * 1.06), Vector2(w * 0.1, -h * 1.06), Vector2(0, -h * 1.2), DEEP_GREEN)  # green roof
	_disc(Vector2(0, -h * 0.99), w * 0.03, Color(0.85, 0.68, 0.2), 10)  # bell
	add_rect(Vector2(-1.2, -h * 1.28), Vector2(2.4, h * 0.09), TIMBER)  # flagpole
	_tri(Vector2(1.2, -h * 1.28), Vector2(w * 0.09, -h * 1.25), Vector2(1.2, -h * 1.22), Color(0.8, 0.2, 0.2))
	# arched green door
	add_rect(Vector2(-w * 0.06, -h * 0.36), Vector2(w * 0.12, h * 0.36), DEEP_GREEN.darkened(0.1))
	_disc(Vector2(0, -h * 0.36), w * 0.06, DEEP_GREEN.darkened(0.1), 12)
	for sx in [-w * 0.32, -w * 0.16, w * 0.16, w * 0.32]:
		_win(sx, -h * 0.55, w * 0.08, h * 0.26, lit)

# FARM -- red barn: gambrel roof, big cross-braced doors, hayloft, plus a silo.
func _b_farm(w: float, h: float, lit: bool) -> void:
	var barn = Color(0.68, 0.24, 0.2)
	var bw = w * 0.78
	add_body(PackedVector2Array([Vector2(-bw / 2, 0), Vector2(bw / 2, 0), Vector2(bw / 2, -h * 0.55), Vector2(-bw / 2, -h * 0.55)]), barn)
	# gambrel (barn) roof
	add_poly(PackedVector2Array([
		Vector2(-bw / 2 - 4, -h * 0.55), Vector2(-bw * 0.28, -h * 0.8),
		Vector2(0, -h * 0.96), Vector2(bw * 0.28, -h * 0.8), Vector2(bw / 2 + 4, -h * 0.55)]), barn.darkened(0.28))
	# big barn doors
	add_rect(Vector2(-bw * 0.2, -h * 0.42), Vector2(bw * 0.4, h * 0.42), barn.darkened(0.42))
	_ln(PackedVector2Array([Vector2(-bw * 0.2, -h * 0.42), Vector2(bw * 0.2, 0)]), 2.0, TIMBER_L)
	_ln(PackedVector2Array([Vector2(bw * 0.2, -h * 0.42), Vector2(-bw * 0.2, 0)]), 2.0, TIMBER_L)
	_win(0, -h * 0.7, w * 0.08, h * 0.1, lit)  # hayloft
	# silo on the right
	var sx = bw / 2 + w * 0.12
	add_rect(Vector2(sx - w * 0.08, -h * 0.85), Vector2(w * 0.16, h * 0.85), Color(0.7, 0.72, 0.72))
	_disc(Vector2(sx, -h * 0.85), w * 0.08, Color(0.55, 0.57, 0.58), 14)
	# a little deepwood grass tuft
	_tri(Vector2(-bw / 2 - w * 0.06, 0), Vector2(-bw / 2 - w * 0.02, 0), Vector2(-bw / 2 - w * 0.04, -h * 0.08), DEEP_GREEN)

# HOSPITAL -- clean white block, flat roof, big red cross, entrance canopy.
func _b_hospital(w: float, h: float, lit: bool) -> void:
	var wall = Color(0.94, 0.95, 0.96)
	add_body(rect_poly(w, h * 0.86), wall)
	add_rect(Vector2(-w * 0.5, -h * 0.92), Vector2(w, h * 0.08), wall.darkened(0.12))  # flat parapet
	# big red cross
	var cs = w * 0.16
	add_rect(Vector2(-cs * 0.28, -h * 0.72), Vector2(cs * 0.56, cs), Color(0.85, 0.15, 0.15))
	add_rect(Vector2(-cs * 0.5, -h * 0.72 + cs * 0.22), Vector2(cs, cs * 0.56), Color(0.85, 0.15, 0.15))
	# entrance canopy
	add_rect(Vector2(-w * 0.16, -h * 0.34), Vector2(w * 0.32, h * 0.05), Color(0.3, 0.55, 0.75))
	add_rect(Vector2(-w * 0.08, -h * 0.32), Vector2(w * 0.16, h * 0.32), Color(0.55, 0.7, 0.78))  # glass door
	for row in [-h * 0.5, -h * 0.32]:
		for sx in [-w * 0.34, -w * 0.2, w * 0.2, w * 0.34]:
			_win(sx, row, w * 0.07, h * 0.12, lit)
	# deepwood touch: a small green shrub by the entrance
	_tri(Vector2(w * 0.42, 0), Vector2(w * 0.46, 0), Vector2(w * 0.44, -h * 0.07), DEEP_GREEN)

# BARRACKS -- stone keep: crenellated walls, a taller watchtower, war banner.
func _b_barracks(w: float, h: float, lit: bool) -> void:
	var stone = Color(0.5, 0.5, 0.52)
	add_body(rect_poly(w, h * 0.72), stone)
	# battlements
	var mx = -w * 0.5
	while mx < w * 0.5 - 1.0:
		add_rect(Vector2(mx, -h * 0.82), Vector2(w * 0.05, h * 0.1), stone.darkened(0.1))
		mx += w * 0.11
	# watchtower
	add_rect(Vector2(w * 0.28, -h * 1.05), Vector2(w * 0.22, h * 1.05), stone.darkened(0.06))
	var tx = w * 0.28
	while tx < w * 0.5:
		add_rect(Vector2(tx, -h * 1.15), Vector2(w * 0.05, h * 0.1), stone.darkened(0.14))
		tx += w * 0.09
	# banner (deepwood green)
	add_poly(PackedVector2Array([Vector2(-w * 0.06, -h * 0.62), Vector2(w * 0.06, -h * 0.62), Vector2(w * 0.06, -h * 0.28), Vector2(0, -h * 0.36), Vector2(-w * 0.06, -h * 0.28)]), DEEP_GREEN)
	# gate + arrow-slit windows (mirrored pair on the wall, one on the tower)
	add_rect(Vector2(-w * 0.09, -h * 0.34), Vector2(w * 0.18, h * 0.34), Color(0.25, 0.2, 0.16))
	for sx in [-w * 0.34, w * 0.34 - w * 0.02, w * 0.38]:
		add_rect(Vector2(sx, -h * 0.55), Vector2(w * 0.02, h * 0.14), _lit_col(lit))

# FISHING DOCK -- hut on stilts over water, a jetty, hanging net, a fish sign.
func _b_dock(w: float, h: float, lit: bool) -> void:
	# a body of water around the dock -- widens slightly per upgrade (sideways,
	# never deeper) and is reserved by main.gd so it can't touch the neighbours
	var half = dock_water_half()
	add_rect(Vector2(-half, -h * 0.05), Vector2(half * 2.0, h * 0.45), Color(0.22, 0.42, 0.55, 0.94))
	for wy in [-h * 0.02, h * 0.1, h * 0.21]:
		_ln(PackedVector2Array([Vector2(-half * 0.9, wy), Vector2(-half * 0.45, wy - h * 0.02), Vector2(0.0, wy), Vector2(half * 0.45, wy - h * 0.02), Vector2(half * 0.9, wy)]), 2.0, Color(0.4, 0.62, 0.72, 0.5))
	# stilts
	for sx in [-w * 0.3, -w * 0.1, w * 0.1, w * 0.3]:
		add_rect(Vector2(sx - w * 0.012, -h * 0.34), Vector2(w * 0.024, h * 0.34), TIMBER)
	# deck + hut
	add_rect(Vector2(-w * 0.4, -h * 0.4), Vector2(w * 0.8, h * 0.06), TIMBER_L)
	add_body(PackedVector2Array([Vector2(-w * 0.28, -h * 0.4), Vector2(w * 0.28, -h * 0.4), Vector2(w * 0.28, -h * 0.78), Vector2(-w * 0.28, -h * 0.78)]), Color(0.5, 0.55, 0.5))
	_tri(Vector2(-w * 0.32, -h * 0.78), Vector2(w * 0.32, -h * 0.78), Vector2(0, -h * 0.96), Color(0.34, 0.42, 0.4))
	# jetty extending right, over the water
	add_rect(Vector2(w * 0.28, -h * 0.36), Vector2(w * 0.28, h * 0.04), TIMBER_L)
	# hanging net + a fish
	_ln(PackedVector2Array([Vector2(-w * 0.24, -h * 0.4), Vector2(-w * 0.18, -h * 0.2), Vector2(-w * 0.1, -h * 0.4)]), 1.4, Color(0.7, 0.7, 0.6, 0.8))
	_disc(Vector2(w * 0.42, -h * 0.22), w * 0.03, Color(0.6, 0.66, 0.7), 10)
	_win(0, -h * 0.6, w * 0.1, h * 0.12, lit)

# SCIENCE LAB -- domed observatory: rounded dome with a telescope slit, a glowing
# flask emblem.
func _b_lab(w: float, h: float, lit: bool) -> void:
	var wall = Color(0.55, 0.58, 0.68)
	add_body(rect_poly(w, h * 0.62), wall)
	# dome
	var dome = PackedVector2Array()
	var r = w * 0.4
	for i in range(15):
		var a = PI * float(i) / 14.0
		dome.append(Vector2(-cos(a) * r, -h * 0.62 - sin(a) * r * 0.85))
	add_poly(dome, wall.lightened(0.08))
	# telescope slit
	add_rect(Vector2(-w * 0.02, -h * 1.0), Vector2(w * 0.04, h * 0.3), Color(0.12, 0.13, 0.18))
	# glowing flask emblem
	_tri(Vector2(-w * 0.05, -h * 0.42), Vector2(w * 0.05, -h * 0.42), Vector2(0, -h * 0.5), DEEP_GREEN.lightened(0.1))
	_disc(Vector2(0, -h * 0.34), w * 0.07, Color(0.4, 0.9, 0.6, 0.9) if lit else Color(0.3, 0.5, 0.4))
	add_rect(Vector2(-w * 0.06, -h * 0.28), Vector2(w * 0.12, h * 0.28), Color(0.3, 0.35, 0.45))  # door
	for sx in [-w * 0.32, w * 0.32]:
		_disc(Vector2(sx, -h * 0.4), w * 0.05, _lit_col(lit), 12)

# BANK -- stone vault: columns, pediment, a coin emblem, a round vault door.
func _b_bank(w: float, h: float, lit: bool) -> void:
	var marble = Color(0.87, 0.85, 0.78)
	var gold = Color(0.92, 0.76, 0.28)
	add_body(rect_poly(w, h * 0.76), marble)
	# marble steps
	add_rect(Vector2(-w * 0.5, -h * 0.05), Vector2(w, h * 0.05), marble.darkened(0.16))
	add_rect(Vector2(-w * 0.44, -h * 0.1), Vector2(w * 0.88, h * 0.05), marble.darkened(0.08))
	# fluted columns with capitals + bases
	for i in range(4):
		var cx = lerp(-w * 0.36, w * 0.36, float(i) / 3.0)
		add_rect(Vector2(cx - w * 0.028, -h * 0.64), Vector2(w * 0.056, h * 0.54), marble.lightened(0.12))
		add_rect(Vector2(cx - w * 0.04, -h * 0.66), Vector2(w * 0.08, h * 0.03), marble.darkened(0.1))
		add_rect(Vector2(cx - w * 0.04, -h * 0.12), Vector2(w * 0.08, h * 0.03), marble.darkened(0.1))
	# entablature, gold trim + pediment with a coin emblem
	add_rect(Vector2(-w * 0.46, -h * 0.7), Vector2(w * 0.92, h * 0.08), marble.darkened(0.1))
	add_rect(Vector2(-w * 0.46, -h * 0.7), Vector2(w * 0.92, h * 0.014), gold)
	_tri(Vector2(-w * 0.46, -h * 0.7), Vector2(w * 0.46, -h * 0.7), Vector2(0, -h * 0.92), marble.darkened(0.03))
	_disc(Vector2(0, -h * 0.8), w * 0.05, gold, 14)
	_disc(Vector2(0, -h * 0.8), w * 0.028, gold.lightened(0.25), 10)
	# grand round vault door with bolts
	_disc(Vector2(0, -h * 0.3), w * 0.13, Color(0.4, 0.4, 0.45), 20)
	_disc(Vector2(0, -h * 0.3), w * 0.095, Color(0.5, 0.5, 0.56), 16)
	_disc(Vector2(0, -h * 0.3), w * 0.04, Color(0.62, 0.62, 0.68), 12)
	for a in range(8):
		var ang = TAU * float(a) / 8.0
		add_rect(Vector2(cos(ang) * w * 0.11 - w * 0.008, -h * 0.3 + sin(ang) * w * 0.11 - w * 0.008), Vector2(w * 0.016, w * 0.016), Color(0.34, 0.34, 0.4))
	# money bags flanking the steps
	for sx in [-w * 0.42, w * 0.42]:
		_disc(Vector2(sx, -h * 0.07), w * 0.045, Color(0.72, 0.66, 0.46), 12)
		_disc(Vector2(sx, -h * 0.1), w * 0.016, gold, 8)
	for sx in [-w * 0.44, w * 0.44]:
		_win(sx, -h * 0.5, w * 0.04, h * 0.15, lit)

# BLACKSMITH -- a working forge: stone base, wooden lean-to, a big smoking stone
# chimney, a glowing hearth with sparks, anvil + hammer, horseshoes, a trough.
func _b_blacksmith(w: float, h: float, lit: bool) -> void:
	var stone = Color(0.5, 0.47, 0.44)
	add_body(rect_poly(w, h * 0.58), stone)
	# slanted wooden lean-to roof
	add_poly(PackedVector2Array([Vector2(-w * 0.56, -h * 0.58), Vector2(w * 0.56, -h * 0.72), Vector2(w * 0.56, -h * 0.62), Vector2(-w * 0.56, -h * 0.48)]), TIMBER)
	# tall stone chimney + smoke
	add_rect(Vector2(w * 0.3, -h * 1.12), Vector2(w * 0.16, h * 0.56), stone.darkened(0.12))
	add_rect(Vector2(w * 0.28, -h * 1.15), Vector2(w * 0.2, h * 0.04), stone.darkened(0.22))
	add_fire(Vector2(w * 0.38, -h * 1.14), 6, 0.5)
	# glowing open hearth with fire + sparks
	add_rect(Vector2(-w * 0.44, -h * 0.4), Vector2(w * 0.36, h * 0.4), Color(0.12, 0.1, 0.08))
	_disc(Vector2(-w * 0.26, -h * 0.18), w * 0.1, Color(1.0, 0.55, 0.12) if lit else Color(0.5, 0.28, 0.12))
	_disc(Vector2(-w * 0.26, -h * 0.18), w * 0.05, Color(1.0, 0.86, 0.42) if lit else Color(0.6, 0.35, 0.15))
	if lit:
		add_fire(Vector2(-w * 0.26, -h * 0.24), 8, 0.45)
	# anvil + hammer
	add_rect(Vector2(w * 0.03, -h * 0.14), Vector2(w * 0.2, h * 0.05), Color(0.28, 0.28, 0.32))
	add_rect(Vector2(w * 0.07, -h * 0.09), Vector2(w * 0.06, h * 0.09), Color(0.28, 0.28, 0.32))
	_tri(Vector2(w * 0.03, -h * 0.14), Vector2(w * 0.03, -h * 0.11), Vector2(-w * 0.02, -h * 0.125), Color(0.28, 0.28, 0.32))
	_ln(PackedVector2Array([Vector2(w * 0.15, -h * 0.14), Vector2(w * 0.22, -h * 0.28)]), 2.5, TIMBER)
	add_rect(Vector2(w * 0.2, -h * 0.32), Vector2(w * 0.06, h * 0.05), Color(0.36, 0.36, 0.4))
	# hanging horseshoes on the wall
	for sx in [w * 0.02, w * 0.14]:
		_disc(Vector2(sx, -h * 0.46), w * 0.026, stone.darkened(0.25), 10)
		_disc(Vector2(sx, -h * 0.45), w * 0.015, stone, 8)
	# water trough
	add_rect(Vector2(w * 0.28, -h * 0.08), Vector2(w * 0.16, h * 0.06), TIMBER)
	add_rect(Vector2(w * 0.29, -h * 0.075), Vector2(w * 0.14, h * 0.03), Color(0.3, 0.5, 0.62))

# TAVERN -- a cosy inn: half-timbered walls, shingled gable, a hanging mug sign,
# glowing cross-frame windows, a smoking chimney, a lantern, barrels + a bench.
func _b_tavern(w: float, h: float, lit: bool) -> void:
	var plaster = Color(0.87, 0.79, 0.63)
	add_body(rect_poly(w, h * 0.68), plaster)
	# shingled gable roof
	_tri(Vector2(-w * 0.58, -h * 0.68), Vector2(w * 0.58, -h * 0.68), Vector2(0, -h * 0.98), Color(0.42, 0.27, 0.18))
	add_rect(Vector2(-w * 0.58, -h * 0.7), Vector2(w * 1.16, h * 0.04), Color(0.32, 0.2, 0.14))
	# timber framing + braces (mirrored studs, braces angling into the door)
	_ln(PackedVector2Array([Vector2(-w * 0.5, -h * 0.4), Vector2(w * 0.5, -h * 0.4)]), 3.0, TIMBER)
	for sx in [-w * 0.32, w * 0.32]:
		_ln(PackedVector2Array([Vector2(sx, -h * 0.68), Vector2(sx, 0)]), 3.0, TIMBER)
	_ln(PackedVector2Array([Vector2(-w * 0.32, -h * 0.4), Vector2(-w * 0.07, 0)]), 2.0, TIMBER)
	_ln(PackedVector2Array([Vector2(w * 0.32, -h * 0.4), Vector2(w * 0.07, 0)]), 2.0, TIMBER)
	# chimney + smoke
	add_rect(Vector2(-w * 0.42, -h * 0.98), Vector2(w * 0.1, h * 0.34), Color(0.5, 0.32, 0.24))
	add_fire(Vector2(-w * 0.37, -h * 0.98), 4, 0.35)
	# glowing cross-frame windows, one mirrored pair flanking the door
	for sx in [-w * 0.19, w * 0.19]:
		_win(sx, -h * 0.52, w * 0.11, h * 0.18, lit)
		_ln(PackedVector2Array([Vector2(sx, -h * 0.52), Vector2(sx, -h * 0.34)]), 1.2, TIMBER.darkened(0.1))
		_ln(PackedVector2Array([Vector2(sx - w * 0.055, -h * 0.43), Vector2(sx + w * 0.055, -h * 0.43)]), 1.2, TIMBER.darkened(0.1))
	# arched door + lantern
	add_rect(Vector2(-w * 0.05, -h * 0.34), Vector2(w * 0.1, h * 0.34), TIMBER.darkened(0.2))
	_disc(Vector2(0, -h * 0.34), w * 0.05, TIMBER.darkened(0.2), 12)
	_disc(Vector2(w * 0.08, -h * 0.4), w * 0.02, Color(1.0, 0.82, 0.4) if lit else Color(0.4, 0.35, 0.2))
	# hanging mug sign on a bracket
	add_rect(Vector2(w * 0.4, -h * 0.62), Vector2(w * 0.02, h * 0.1), TIMBER)
	add_rect(Vector2(w * 0.28, -h * 0.62), Vector2(w * 0.14, h * 0.02), TIMBER)
	add_rect(Vector2(w * 0.3, -h * 0.6), Vector2(w * 0.1, h * 0.12), Color(0.35, 0.24, 0.15))
	add_rect(Vector2(w * 0.33, -h * 0.56), Vector2(w * 0.045, h * 0.055), Color(0.9, 0.86, 0.72))
	# barrels + bench + a deepwood hanging plant
	_disc(Vector2(-w * 0.44, -h * 0.05), w * 0.04, TIMBER_L, 12)
	_disc(Vector2(-w * 0.36, -h * 0.05), w * 0.04, TIMBER_L, 12)
	add_rect(Vector2(w * 0.34, -h * 0.04), Vector2(w * 0.12, h * 0.015), TIMBER)
	_disc(Vector2(w * 0.46, -h * 0.5), w * 0.03, DEEP_GREEN, 8)

# BAR -- the village's night spot: dark timber facade, a glowing "BAR" sign,
# string lights along the roofline, big warm windows with bottle shelves,
# stools and a barrel out front. Fun music pours out of it (see _bar_tune).
func _b_bar(w: float, h: float, lit: bool) -> void:
	var wall = Color(0.3, 0.24, 0.22)
	add_body(rect_poly(w, h * 0.72), wall)
	# flat roof + parapet
	add_rect(Vector2(-w * 0.54, -h * 0.78), Vector2(w * 1.08, h * 0.07), wall.darkened(0.25))
	# string lights along the roofline
	var bulbs = 9
	for i in range(bulbs):
		var bx = lerp(-w * 0.48, w * 0.48, float(i) / float(bulbs - 1))
		var bulb = Polygon2D.new()
		bulb.polygon = circle_poly(2.6, 8)
		bulb.position = Vector2(bx, -h * 0.7)
		bulb.color = [Color(1.0, 0.75, 0.3), Color(0.5, 0.9, 0.6), Color(0.95, 0.5, 0.5)][i % 3]
		bulb.color.a = 0.95 if lit else 0.45
		if lit:
			bulb.material = _add_mat()
		gfx.add_child(bulb)
	# glowing BAR sign over the door
	if lit:
		var sign_glow = Polygon2D.new()
		sign_glow.polygon = PackedVector2Array([
			Vector2(-w * 0.17, -h * 0.56), Vector2(w * 0.17, -h * 0.56),
			Vector2(w * 0.17, -h * 0.7), Vector2(-w * 0.17, -h * 0.7)])
		sign_glow.color = Color(0.45, 0.95, 0.6, 0.2)
		sign_glow.material = _add_mat()
		gfx.add_child(sign_glow)
	add_rect(Vector2(-w * 0.15, -h * 0.68), Vector2(w * 0.3, h * 0.1), Color(0.1, 0.08, 0.1))
	var sign_label = _make_label("B A R", 14)
	sign_label.position = Vector2(-w * 0.15, -h * 0.675)
	sign_label.size = Vector2(w * 0.3, h * 0.1)
	sign_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.7) if lit else Color(0.5, 0.55, 0.5))
	gfx.add_child(sign_label)
	# warm windows with bottle shelves
	for sx in [-w * 0.22, w * 0.22]:
		_win(sx, -h * 0.5, w * 0.12, h * 0.2, lit)
		_ln(PackedVector2Array([Vector2(sx - w * 0.05, -h * 0.4), Vector2(sx + w * 0.05, -h * 0.4)]), 1.5, TIMBER)
		for bi in range(3):
			var bx2 = sx - w * 0.035 + bi * w * 0.035
			add_rect(Vector2(bx2 - 1.5, -h * 0.455), Vector2(3.0, h * 0.05),
				[Color(0.35, 0.6, 0.35), Color(0.7, 0.5, 0.2), Color(0.6, 0.3, 0.3)][bi])
	# green double door + porch light
	add_rect(Vector2(-w * 0.06, -h * 0.34), Vector2(w * 0.12, h * 0.34), DEEP_GREEN.darkened(0.15))
	_ln(PackedVector2Array([Vector2(0, -h * 0.34), Vector2(0, 0)]), 1.4, DEEP_GREEN.darkened(0.35))
	# stools + barrel out front
	for sx in [-w * 0.3, -w * 0.22]:
		add_rect(Vector2(sx - 2.5, -h * 0.1), Vector2(5.0, h * 0.1), TIMBER)
		add_rect(Vector2(sx - 4.5, -h * 0.115), Vector2(9.0, h * 0.02), TIMBER_L)
	_disc(Vector2(w * 0.34, -h * 0.06), w * 0.045, TIMBER_L, 12)
	_ln(PackedVector2Array([Vector2(w * 0.3, -h * 0.06), Vector2(w * 0.38, -h * 0.06)]), 1.2, TIMBER.darkened(0.2))

# MARKETPLACE -- open-air stalls. It grows by SECTIONS: 3 stalls at level 1,
# +1 per upgrade level. The footprint stays the same; the stalls just get
# denser/busier (see eff_w -- Marketplace ignores level scaling).
func market_sections() -> int:
	return 3 + (building_level - 1)

func _b_market(w: float, h: float, lit: bool) -> void:
	var sections = market_sections()
	# back stall wall (low)
	add_body(rect_poly(w, h * 0.34), Color(0.62, 0.52, 0.38))
	# posts -- one between/around each section
	for i in range(sections + 1):
		var px = lerp(-w * 0.47, w * 0.47, float(i) / float(sections))
		add_rect(Vector2(px - w * 0.01, -h * 0.6), Vector2(w * 0.02, h * 0.6), TIMBER)
	# striped awning
	var stripes = max(4, sections * 2)
	var sw = (w * 1.04) / stripes
	for i in range(stripes):
		var c = Color(0.82, 0.28, 0.22) if i % 2 == 0 else Color(0.94, 0.9, 0.82)
		add_poly(PackedVector2Array([
			Vector2(-w * 0.52 + i * sw, -h * 0.6), Vector2(-w * 0.52 + (i + 1) * sw, -h * 0.6),
			Vector2(-w * 0.52 + (i + 1) * sw, -h * 0.7), Vector2(-w * 0.52 + i * sw, -h * 0.7)]), c)
	# one crate of produce per section
	var cw = w * 0.9 / float(sections)
	for i in range(sections):
		var sx = -w * 0.45 + (i + 0.5) * (w * 0.9 / float(sections))
		add_rect(Vector2(sx - cw * 0.32, -h * 0.28), Vector2(cw * 0.64, h * 0.14), TIMBER_L)
		_disc(Vector2(sx - cw * 0.14, -h * 0.3), w * 0.016, DEEP_GREEN.lightened(0.1), 8)
		_disc(Vector2(sx + cw * 0.14, -h * 0.3), w * 0.016, Color(0.85, 0.5, 0.2), 8)

# BUILDERHOUSE -- a construction workshop mid-build: half-timbered frame with an
# exposed/scaffolded side, a proper tower crane hoisting lumber, brick & plank
# piles, a wheelbarrow and a hard-hat sign.
func _b_builder(w: float, h: float, lit: bool) -> void:
	var wall = Color(0.56, 0.49, 0.37)
	add_body(rect_poly(w, h * 0.56), wall)
	# partial roof + exposed studs (still under construction)
	_tri(Vector2(-w * 0.5, -h * 0.56), Vector2(w * 0.12, -h * 0.56), Vector2(-w * 0.2, -h * 0.82), Color(0.42, 0.3, 0.2))
	for sx in [-w * 0.4, -w * 0.15, w * 0.08]:
		_ln(PackedVector2Array([Vector2(sx, -h * 0.56), Vector2(sx, 0)]), 2.5, TIMBER)
	# scaffolding wrapping the right side
	for sx in [w * 0.16, w * 0.44]:
		add_rect(Vector2(sx, -h * 0.8), Vector2(w * 0.02, h * 0.8), TIMBER_L)
	for sy in [-h * 0.62, -h * 0.36, -h * 0.12]:
		add_rect(Vector2(w * 0.16, sy), Vector2(w * 0.3, h * 0.02), TIMBER_L)
	_ln(PackedVector2Array([Vector2(w * 0.16, -h * 0.62), Vector2(w * 0.46, -h * 0.36)]), 1.5, TIMBER_L)
	# tower crane: mast, jib, counterweight, cable + slung lumber
	add_rect(Vector2(-w * 0.46, -h * 1.18), Vector2(w * 0.04, h * 1.18), Color(0.92, 0.72, 0.2))
	add_rect(Vector2(-w * 0.5, -h * 1.18), Vector2(w * 0.52, w * 0.045), Color(0.92, 0.72, 0.2))
	add_rect(Vector2(-w * 0.54, -h * 1.18), Vector2(w * 0.07, w * 0.05), Color(0.7, 0.5, 0.15))
	_ln(PackedVector2Array([Vector2(-w * 0.02, -h * 1.15), Vector2(-w * 0.02, -h * 0.55)]), 1.4, Color(0.2, 0.2, 0.2))
	add_rect(Vector2(-w * 0.07, -h * 0.55), Vector2(w * 0.1, h * 0.06), Color(0.5, 0.4, 0.25))
	# brick stack + plank pile + wheelbarrow + hard-hat sign
	for i in range(3):
		add_rect(Vector2(-w * 0.42, -h * 0.06 - i * h * 0.03), Vector2(w * 0.12, h * 0.026), Color(0.72, 0.36, 0.28))
	add_rect(Vector2(-w * 0.24, -h * 0.05), Vector2(w * 0.16, h * 0.04), TIMBER_L)
	add_rect(Vector2(w * 0.22, -h * 0.08), Vector2(w * 0.1, h * 0.05), Color(0.62, 0.32, 0.2))
	_disc(Vector2(w * 0.22, -h * 0.03), w * 0.02, Color(0.2, 0.2, 0.2), 8)
	_disc(Vector2(w * 0.36, -h * 0.66), w * 0.04, Color(0.96, 0.8, 0.15), 12)
	add_rect(Vector2(w * 0.32, -h * 0.63), Vector2(w * 0.08, h * 0.012), Color(0.96, 0.8, 0.15))

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
	# only a finished building that has taken damage shows a health bar
	var show = build_stage >= GameState.TOTAL_BUILD_STAGES and health < MAX_HEALTH
	health_bar_bg.visible = show
	health_bar_fill.visible = show

# ---------------------------------------------------------------- gameplay ---

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = true
		update_prompt()
		prompt_label.visible = true
		# stepping into the Bar lifts the player's spirits (see player.gd)
		if building_name == "Bar" and is_operational() and body.has_method("grant_bar_morale"):
			body.grant_bar_morale()

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = false
		prompt_label.visible = false
		var assign_ui = get_node_or_null("../../AssignUI")
		if assign_ui and assign_ui.current_building == self:
			assign_ui.close()

func _process(delta: float) -> void:
	if constructing:
		construction_timer -= delta
		if construction_timer <= 0.0:
			constructing = false
			update_prompt()
	# torches follow the day/night clock (only on a finished building)
	var want_torch = build_stage >= GameState.TOTAL_BUILD_STAGES and GameState.torches_lit()
	if want_torch != torches_on:
		torches_on = want_torch
		update_torches()
	if torches_on and torch_layer:
		# living firelight: each torch flickers on its own irregular rhythm
		var tnow = Time.get_ticks_msec() / 1000.0
		for tn in torch_layer.get_children():
			for c in tn.get_children():
				if c is PointLight2D:
					var ph = float(c.get_meta("flicker_phase", 0.0))
					c.energy = TORCH_ENERGY * (0.92 + 0.08 * sin(tnow * 7.3 + ph) + 0.03 * sin(tnow * 12.7 + ph * 2.0))
	# keep the visible workforce in sync with who's employed here
	worker_timer -= delta
	if worker_timer <= 0.0:
		worker_timer = 1.5
		var emp = employed_count()
		var oper = is_operational()
		if emp != last_employed or oper != last_operational_state:
			last_employed = emp
			last_operational_state = oper
			refresh_workers()
			update_bar_music()
		if area_layer:
			area_layer.visible = oper   # the yard exists only once it's built
		# the crop field tracks the larder draining/refilling over time
		if building_name == "Farm":
			_update_farm_crops()
	if not player_inside:
		return
	# Ruined/half-built -> F builds the next stage (locked mid-construction);
	# a finished building -> E opens the assign panel.
	if is_ruined():
		if not constructing and Input.is_action_just_pressed("enter_dungeon"):
			attempt_field_build()
	else:
		if Input.is_action_just_pressed("interact"):
			open_assign_ui()
		# Hospital (5.5 Health): the hands-on key checks the PLAYER in for
		# treatment -- a flat mid-game price once the ward is staffed, the
		# successor to the Doctor's escalating early-game lifeline.
		if building_name == "Hospital" and is_operational() and Input.is_action_just_pressed("harvest"):
			var pl = get_tree().get_first_node_in_group("player")
			if pl != null and GameState.count_workers("Hospital") > 0:
				var notif2 = get_node_or_null("../CanvasLayer/NotificationStack")
				if pl.health >= pl.get_max_health():
					if notif2: notif2.show_notification("The nurses look you over — not a scratch on you.")
				elif pl.currency < HOSPITAL_HEAL_PRICE:
					if notif2: notif2.show_notification("Treatment costs %dg — the ward cannot work for free." % HOSPITAL_HEAL_PRICE)
				else:
					pl.add_currency(-HOSPITAL_HEAL_PRICE)
					pl.health = pl.get_max_health()
					pl.update_health_display()
					if notif2: notif2.show_notification("The ward's nurses knit you whole — %dg." % HOSPITAL_HEAL_PRICE)
		# Farm: hold the harvest key to hand-tend the field, filling the village
		# larder in +food chunks -- the early-game manual chore you later automate
		# by staffing the farm with farmers.
		if building_name == "Farm" and is_operational():
			harvest_cooldown -= delta
			if Input.is_action_pressed("harvest") and harvest_cooldown <= 0.0:
				var added = GameState.manual_harvest_food()
				if added > 0.0:
					harvest_cooldown = FARM_HARVEST_INTERVAL
					_spawn_harvest_float("+%d" % int(round(added)))
					_spawn_harvest_puff()
					_update_farm_crops()

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
		# a hero child never appears on the School's roll -- Barracks only
		if villager.get("hero", false) and building_name == "School":
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
