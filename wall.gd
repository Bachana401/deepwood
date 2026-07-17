extends Node2D

# The village's west rampart -- the line the siege breaks against. It has no
# physics collision (the player walks through the gate freely); besieging
# enemies stop at its west face by logic (see siege_enemy.gd) and hammer it
# via take_damage(). At 0 HP it's breached: attackers pour past to the
# villagers/wizard until the siege is repelled, at which point the SiegeManager
# repairs it (see siege_manager.gd -> end_siege). Future: player-funded repairs
# with gold + materials.

const MAX_HEALTH = 800
const WALL_WIDTH = 46.0
const WALL_HEIGHT = 96.0        # rises this far above the node origin (ground)
const STONE = Color(0.5, 0.5, 0.55, 1.0)
const STONE_DARK = Color(0.38, 0.38, 0.44, 1.0)
const STONE_RUBBLE = Color(0.34, 0.33, 0.36, 1.0)
const HEALTH_BAR_WIDTH = 64.0
const HEALTH_BAR_HEIGHT = 6.0

var health = MAX_HEALTH
var breached = false

var intact_gfx: Node2D = null
var rubble_gfx: Node2D = null
var health_bar_bg: ColorRect = null
var health_bar_fill: ColorRect = null

func _ready() -> void:
	add_to_group("village_wall")
	build_visual()
	build_health_bar()

func _process(_delta: float) -> void:
	# the bar only matters once the wall is hurt or down
	var show_bar = breached or health < MAX_HEALTH
	if health_bar_bg:
		health_bar_bg.visible = show_bar
	if health_bar_fill:
		health_bar_fill.visible = show_bar

# West face x -- besiegers stop just short of this to attack.
func west_face_x() -> float:
	return global_position.x - WALL_WIDTH / 2.0

func take_damage(amount: int) -> void:
	if breached:
		return
	health -= amount
	update_health_bar_fill()
	if health <= 0:
		health = 0
		breach()

func breach() -> void:
	breached = true
	if intact_gfx:
		intact_gfx.visible = false
	if rubble_gfx:
		rubble_gfx.visible = true
	var notif = get_tree().get_first_node_in_group("notification_stack")
	if notif:
		notif.show_notification("The wall is breached! Defend the village!")

# Called by the SiegeManager once a siege is fully repelled -- the villagers
# patch the rampart back up before the next assault.
func repair_fully() -> void:
	health = MAX_HEALTH
	breached = false
	if intact_gfx:
		intact_gfx.visible = true
	if rubble_gfx:
		rubble_gfx.visible = false
	update_health_bar_fill()

func update_health_bar_fill() -> void:
	if health_bar_fill:
		health_bar_fill.size.x = HEALTH_BAR_WIDTH * clamp(float(health) / MAX_HEALTH, 0.0, 1.0)

func build_visual() -> void:
	intact_gfx = Node2D.new()
	add_child(intact_gfx)

	# PixelLab gatehouse facade (art/buildings/wall_gate.png) replaces the flat
	# stone rig when present; rubble state below stays procedural either way.
	if ResourceLoader.exists("res://art/buildings/wall_gate.png"):
		var tex: Texture2D = load("res://art/buildings/wall_gate.png")
		var img: Image = tex.get_image()
		if img.is_compressed():
			img.decompress()
		var content := Rect2(img.get_used_rect())
		if content.size.x <= 0:
			content = Rect2(Vector2.ZERO, Vector2(tex.get_width(), tex.get_height()))
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.centered = false
		spr.region_enabled = true
		spr.region_rect = content
		# a touch wider than the old wall so the gatehouse reads imposing
		var gw := WALL_WIDTH * 1.6
		var gh := (WALL_HEIGHT + 8.0) * 1.25
		spr.scale = Vector2(gw / content.size.x, gh / content.size.y)
		spr.position = Vector2(-gw / 2.0, -gh)
		intact_gfx.add_child(spr)
		_build_rubble()
		return

	# main stone body (origin at ground, rising upward = negative y)
	var body = ColorRect.new()
	body.size = Vector2(WALL_WIDTH, WALL_HEIGHT)
	body.position = Vector2(-WALL_WIDTH / 2.0, -WALL_HEIGHT)
	body.color = STONE
	intact_gfx.add_child(body)

	# horizontal block seams
	for i in range(1, 5):
		var seam = ColorRect.new()
		seam.size = Vector2(WALL_WIDTH, 2.0)
		seam.position = Vector2(-WALL_WIDTH / 2.0, -WALL_HEIGHT + i * (WALL_HEIGHT / 5.0))
		seam.color = STONE_DARK
		intact_gfx.add_child(seam)

	# crenellations (merlons) along the top
	var merlon_w = 8.0
	var x = -WALL_WIDTH / 2.0
	while x < WALL_WIDTH / 2.0 - 1.0:
		var merlon = ColorRect.new()
		merlon.size = Vector2(merlon_w, 8.0)
		merlon.position = Vector2(x, -WALL_HEIGHT - 8.0)
		merlon.color = STONE
		intact_gfx.add_child(merlon)
		x += merlon_w * 2.0

	# a dark timber gate set into the middle
	var gate = ColorRect.new()
	gate.size = Vector2(WALL_WIDTH * 0.5, WALL_HEIGHT * 0.55)
	gate.position = Vector2(-WALL_WIDTH * 0.25, -WALL_HEIGHT * 0.55)
	gate.color = Color(0.32, 0.22, 0.12, 1.0)
	intact_gfx.add_child(gate)

	_build_rubble()

func _build_rubble() -> void:
	# rubble state, hidden until breached
	rubble_gfx = Node2D.new()
	rubble_gfx.visible = false
	add_child(rubble_gfx)
	var pile = ColorRect.new()
	pile.size = Vector2(WALL_WIDTH, WALL_HEIGHT * 0.3)
	pile.position = Vector2(-WALL_WIDTH / 2.0, -WALL_HEIGHT * 0.3)
	pile.color = STONE_RUBBLE
	rubble_gfx.add_child(pile)
	for i in range(5):
		var chunk = ColorRect.new()
		var s = randf_range(6.0, 12.0)
		chunk.size = Vector2(s, s)
		chunk.position = Vector2(randf_range(-WALL_WIDTH / 2.0, WALL_WIDTH / 2.0 - s), -WALL_HEIGHT * 0.3 - randf_range(0.0, 8.0))
		chunk.color = STONE_DARK if i % 2 == 0 else STONE_RUBBLE
		rubble_gfx.add_child(chunk)

func build_health_bar() -> void:
	health_bar_bg = ColorRect.new()
	health_bar_bg.color = Color(0.15, 0.05, 0.05, 0.9)
	health_bar_bg.size = Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)
	health_bar_bg.position = Vector2(-HEALTH_BAR_WIDTH / 2.0, -WALL_HEIGHT - 26.0)
	health_bar_bg.z_index = 60
	health_bar_bg.visible = false
	add_child(health_bar_bg)

	health_bar_fill = ColorRect.new()
	health_bar_fill.color = Color(0.55, 0.55, 0.62, 1.0)
	health_bar_fill.size = Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)
	health_bar_fill.position = Vector2(-HEALTH_BAR_WIDTH / 2.0, -WALL_HEIGHT - 26.0)
	health_bar_fill.z_index = 61
	health_bar_fill.visible = false
	add_child(health_bar_fill)
