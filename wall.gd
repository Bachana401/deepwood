extends Node2D

# The village's west rampart -- the line the siege breaks against. It has no
# physics collision (the player walks through the gate freely); besieging
# enemies stop at its west face by logic (see siege_enemy.gd) and hammer it
# via take_damage(). At 0 HP it's breached: attackers pour past to the
# villagers/wizard until the siege is repelled, at which point the SiegeManager
# repairs it (see siege_manager.gd -> end_siege). Future: player-funded repairs
# with gold + materials.

# Base footprint of a TIER-1 rampart. It's a bigger, more imposing wall than the
# old 46x96 slab (dev ask 2026-07-22 "make WALLS bigger, in width and visually
# too, in height too"), and it GROWS with the tier on top of that (see _size_mult).
const WALL_WIDTH = 64.0
const WALL_HEIGHT = 132.0       # rises this far above the node origin (ground)
const GROWTH_PER_TIER = 0.13    # +13% footprint per tier over tier 1
const STONE = Color(0.5, 0.5, 0.55, 1.0)
const STONE_DARK = Color(0.38, 0.38, 0.44, 1.0)
const STONE_RUBBLE = Color(0.34, 0.33, 0.36, 1.0)
const IRON = Color(0.32, 0.34, 0.4, 1.0)          # the traps/spikes read metal
const HEALTH_BAR_WIDTH = 72.0
const HEALTH_BAR_HEIGHT = 6.0
const TRAP_RANGE = 42.0         # besiegers this close to the outer face get bled
var _trap_accum := 0.0          # traps tick once a second

# 7.2: the village is besieged from BOTH ends -- a rampart at each. "west"
# is the original gatehouse the wild road breaks against; "east" guards the
# cottage row's far end. Attackers plant on the OUTSIDE face of their wall.
@export var flank := "west"

# HP comes from the tier (GameState.wall_max_health, which also folds in Brannoc,
# the Wall That Stood). Weak at tier 1, a fortress at tier 4.
var max_health := 350
var health := 350
var breached = false

var intact_gfx: Node2D = null
var rubble_gfx: Node2D = null
var health_bar_bg: ColorRect = null
var health_bar_fill: ColorRect = null

# Walk up to the gate and press E to raise the rampart. A floating prompt shows
# the next tier's cost so the player knows the price before they pay it.
const INTERACT_RANGE = 130.0
var _prompt: Label = null
var _player_near := false

func _ready() -> void:
	add_to_group("village_wall")
	max_health = GameState.wall_max_health()
	# WOUNDS PERSIST across scene rebuilds (audit fix): _ready used to reset to
	# full, so stepping into a dungeon and straight back out repaired a
	# breached rampart for free. Absent entry = a fresh, whole wall.
	health = clampi(int(GameState.wall_hp.get(str(flank), max_health)), 0, max_health)
	build_visual()
	build_health_bar()
	_build_prompt()
	if health <= 0:
		# restore the breach SILENTLY (no fresh "breached!" alarm on reload)
		breached = true
		if intact_gfx:
			intact_gfx.visible = false
		if rubble_gfx:
			rubble_gfx.visible = true
		update_health_bar_fill()

func _process(delta: float) -> void:
	# the bar only matters once the wall is hurt or down
	var show_bar = breached or health < max_health
	if health_bar_bg:
		health_bar_bg.visible = show_bar
	if health_bar_fill:
		health_bar_fill.visible = show_bar
	_tick_traps(delta)
	_tick_interact()

# --- UPGRADE INTERACTION (press E at the gate) ---
func _build_prompt() -> void:
	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 13)
	_prompt.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_prompt.add_theme_constant_override("outline_size", 4)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.z_index = 62
	_prompt.visible = false
	add_child(_prompt)

func _prompt_text() -> String:
	if GameState.wall_level >= GameState.WALL_MAX_LEVEL:
		return "The Rampart — Tier %d (fully raised)" % GameState.wall_level
	var cost := GameState.wall_upgrade_cost()
	var parts := PackedStringArray()
	for k in cost.keys():
		var nm: String = "gold" if k == "coin_gold" else Inventory.get_display_name(k)
		parts.append("%d %s" % [int(cost[k]), nm])
	return "Raise the Rampart to Tier %d  [E]\n%s" % [GameState.wall_level + 1, ", ".join(parts)]

func _tick_interact() -> void:
	var p = get_tree().get_first_node_in_group("player")
	var near := p != null and absf(p.global_position.x - global_position.x) <= INTERACT_RANGE \
		and absf(p.global_position.y - global_position.y) <= 200.0
	if near != _player_near:
		_player_near = near
		if _prompt:
			_prompt.visible = near
	if not near or _prompt == null:
		return
	# only ONE wall drives the prompt/press at a time (avoid a double-upgrade if
	# somehow both are in range): the nearest wall to the player wins
	if not _is_nearest_wall(p):
		_prompt.visible = false
		return
	# ONE PRESS, ONE ANSWER (audit fix): a rampart may legally stand right among
	# the gate's road markers and the Watchtower plot (placement allows it by
	# design), so their small E-zones can sit inside the wall's big 130px one.
	# When a POINT structure has the player standing in its own zone, the wall
	# yields -- otherwise a single keypress charged a wall tier AND a tower
	# tier, or upgraded the rampart mid-teleport.
	for s in get_tree().get_nodes_in_group("village_structure"):
		if is_instance_valid(s) and s != self and "player_inside" in s and s.player_inside \
				and s.global_position.distance_to(global_position) < 400.0:
			_prompt.visible = false
			return
	_prompt.visible = true
	_prompt.text = _prompt_text()
	_prompt.size = Vector2.ZERO   # let it shrink-wrap
	_prompt.position = Vector2(-90.0, -eff_height() - 58.0)
	_prompt.custom_minimum_size = Vector2(180.0, 0)
	if Input.is_action_just_pressed("interact"):
		_try_upgrade(p)

func _is_nearest_wall(p: Node) -> bool:
	var my_d: float = absf(p.global_position.x - global_position.x)
	for w in get_tree().get_nodes_in_group("village_wall"):
		if w == self or not is_instance_valid(w):
			continue
		if absf(p.global_position.x - w.global_position.x) < my_d:
			return false
	return true

func _try_upgrade(p: Node) -> void:
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if GameState.wall_level >= GameState.WALL_MAX_LEVEL:
		return
	if GameState.try_upgrade_wall(p):
		GameState.play_sfx(GameState.SFX_YES, 1.0)
		if stack:
			stack.show_notification("The rampart rises — Tier %d. Stronger stone, sharper traps, more posts." % GameState.wall_level)
	else:
		if stack:
			var cost := GameState.wall_upgrade_cost()
			var parts := PackedStringArray()
			for k in cost.keys():
				var nm: String = "gold" if k == "coin_gold" else Inventory.get_display_name(k)
				parts.append("%d %s" % [int(cost[k]), nm])
			stack.show_notification("Not enough to raise the wall. Need: %s." % ", ".join(parts))

# TRAPS (tier 2+): spikes and boiling oil set into the rampart bleed any besieger
# pressed against its OUTER face. A standing wall only -- a breached one can't.
func _tick_traps(delta: float) -> void:
	if breached:
		return
	var dps: float = GameState.wall_trap_dps()
	if dps <= 0.0:
		return
	_trap_accum += delta
	if _trap_accum < 1.0:
		return
	_trap_accum = 0.0
	var fx := outer_face_x()
	for e in get_tree().get_nodes_in_group("siege_enemy"):
		if not is_instance_valid(e) or ("is_dead" in e and e.is_dead):
			continue
		if absf(e.global_position.x - fx) <= TRAP_RANGE:
			if e.has_method("take_damage"):
				e.take_damage(int(round(dps)))

# The tier drives the footprint: a higher wall is visibly bigger stone.
func _size_mult() -> float:
	return 1.0 + (GameState.wall_level - 1) * GROWTH_PER_TIER

func eff_width() -> float:
	return WALL_WIDTH * _size_mult()

func eff_height() -> float:
	return WALL_HEIGHT * _size_mult()

# West face x -- besiegers stop just short of this to attack.
func west_face_x() -> float:
	return global_position.x - eff_width() / 2.0

func east_face_x() -> float:
	return global_position.x + eff_width() / 2.0

# The face the enemy hammers: the OUTSIDE of whichever end this wall guards.
func outer_face_x() -> float:
	return west_face_x() if flank == "west" else east_face_x()

func take_damage(amount: int) -> void:
	if breached:
		return
	health -= amount
	GameState.wall_hp[str(flank)] = maxi(health, 0)   # wounds survive scene swaps
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
		notif.show_notification("The %s wall is breached! Defend the village!" % flank)
	# a fallen rampart is a bad omen for every spirit -- but only an omen (10)
	GameState.on_wall_broken(flank)

# Called by the SiegeManager once a siege is fully repelled -- the villagers
# patch the rampart back up before the next assault.
func repair_fully() -> void:
	health = max_health
	breached = false
	GameState.wall_hp.erase(str(flank))   # whole again: no entry to carry
	if intact_gfx:
		intact_gfx.visible = true
	if rubble_gfx:
		rubble_gfx.visible = false
	update_health_bar_fill()

func update_health_bar_fill() -> void:
	if health_bar_fill:
		health_bar_fill.size.x = HEALTH_BAR_WIDTH * clamp(float(health) / max_health, 0.0, 1.0)

# Rebuild HP + visuals for the CURRENT tier -- called when the player upgrades
# the rampart so the change (taller, tougher, a fresh full bar) is immediate.
func refresh_from_level() -> void:
	max_health = GameState.wall_max_health()
	health = max_health
	breached = false
	GameState.wall_hp.erase(str(flank))   # an upgrade rebuilds it whole
	if intact_gfx:
		intact_gfx.queue_free()
		intact_gfx = null
	if rubble_gfx:
		rubble_gfx.queue_free()
		rubble_gfx = null
	build_visual()
	if health_bar_bg:
		health_bar_bg.position.y = -eff_height() - 26.0
	if health_bar_fill:
		health_bar_fill.position.y = -eff_height() - 26.0
	update_health_bar_fill()

func build_visual() -> void:
	var ew := eff_width()
	var eh := eff_height()
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
		# a touch wider than the footprint so the gatehouse reads imposing
		var gw := ew * 1.6
		var gh := (eh + 8.0) * 1.25
		spr.scale = Vector2(gw / content.size.x, gh / content.size.y)
		spr.position = Vector2(-gw / 2.0, -gh)
		intact_gfx.add_child(spr)
		_build_traps(ew, eh)
		_build_rubble()
		return

	# main stone body (origin at ground, rising upward = negative y)
	var body = ColorRect.new()
	body.size = Vector2(ew, eh)
	body.position = Vector2(-ew / 2.0, -eh)
	body.color = STONE
	intact_gfx.add_child(body)

	# horizontal block seams
	for i in range(1, 6):
		var seam = ColorRect.new()
		seam.size = Vector2(ew, 2.0)
		seam.position = Vector2(-ew / 2.0, -eh + i * (eh / 6.0))
		seam.color = STONE_DARK
		intact_gfx.add_child(seam)

	# crenellations (merlons) along the top
	var merlon_w = 10.0
	var x = -ew / 2.0
	while x < ew / 2.0 - 1.0:
		var merlon = ColorRect.new()
		merlon.size = Vector2(merlon_w, 11.0)
		merlon.position = Vector2(x, -eh - 11.0)
		merlon.color = STONE
		intact_gfx.add_child(merlon)
		x += merlon_w * 2.0

	# a reinforced timber gate + iron bands set into the middle -- the way through
	var gate = ColorRect.new()
	gate.size = Vector2(ew * 0.46, eh * 0.5)
	gate.position = Vector2(-ew * 0.23, -eh * 0.5)
	gate.color = Color(0.32, 0.22, 0.12, 1.0)
	intact_gfx.add_child(gate)
	for gy in [0.16, 0.34]:
		var band = ColorRect.new()
		band.size = Vector2(ew * 0.46, 3.0)
		band.position = Vector2(-ew * 0.23, -eh * gy)
		band.color = IRON
		intact_gfx.add_child(band)

	_build_traps(ew, eh)
	_build_rubble()

# Spikes jutting from the OUTER face at tier 2+ -- the visible tell of the traps.
func _build_traps(ew: float, eh: float) -> void:
	if GameState.wall_trap_dps() <= 0.0:
		return
	var dir := -1.0 if flank == "west" else 1.0
	var face := dir * ew / 2.0
	var n := 3 + GameState.wall_level          # more, nastier spikes each tier
	for i in range(n):
		var spike = Polygon2D.new()
		var sy := -eh * (0.25 + 0.5 * float(i) / float(max(n - 1, 1)))
		var spike_len := 12.0 + GameState.wall_level * 2.0
		spike.polygon = PackedVector2Array([
			Vector2(face, sy - 4.0),
			Vector2(face + dir * spike_len, sy),
			Vector2(face, sy + 4.0)])
		spike.color = IRON
		intact_gfx.add_child(spike)

func _build_rubble() -> void:
	var ew := eff_width()
	var eh := eff_height()
	# rubble state, hidden until breached
	rubble_gfx = Node2D.new()
	rubble_gfx.visible = false
	add_child(rubble_gfx)
	var pile = ColorRect.new()
	pile.size = Vector2(ew, eh * 0.3)
	pile.position = Vector2(-ew / 2.0, -eh * 0.3)
	pile.color = STONE_RUBBLE
	rubble_gfx.add_child(pile)
	for i in range(5):
		var chunk = ColorRect.new()
		var s = randf_range(6.0, 12.0)
		chunk.size = Vector2(s, s)
		chunk.position = Vector2(randf_range(-ew / 2.0, ew / 2.0 - s), -eh * 0.3 - randf_range(0.0, 8.0))
		chunk.color = STONE_DARK if i % 2 == 0 else STONE_RUBBLE
		rubble_gfx.add_child(chunk)

func build_health_bar() -> void:
	health_bar_bg = ColorRect.new()
	health_bar_bg.color = Color(0.15, 0.05, 0.05, 0.9)
	health_bar_bg.size = Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)
	health_bar_bg.position = Vector2(-HEALTH_BAR_WIDTH / 2.0, -eff_height() - 26.0)
	health_bar_bg.z_index = 60
	health_bar_bg.visible = false
	add_child(health_bar_bg)

	health_bar_fill = ColorRect.new()
	health_bar_fill.color = Color(0.55, 0.55, 0.62, 1.0)
	health_bar_fill.size = Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)
	health_bar_fill.position = Vector2(-HEALTH_BAR_WIDTH / 2.0, -eff_height() - 26.0)
	health_bar_fill.z_index = 61
	health_bar_fill.visible = false
	add_child(health_bar_fill)
