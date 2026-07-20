extends CharacterBody2D

# One of the Ten, fighting beside you at the Harvest (GAME_BIBLE 9.4) -- ten
# lights in a town gone dark. They hunt the transformed (every kill of theirs
# denies the Devourer fuel), they can be beaten down but not killed -- a legend
# at 0 HP falls back to the gate to breathe, then rejoins. Help, not a solution.
# (First cut: shared kit with per-legend voice; in-character kits come with
# playtesting, per the bible's Brannoc-anchors/Maera-heals/Seraphel-slows note.)

const GRAVITY = 900.0
const WALK_SPEED = 96.0
const ATTACK_RANGE = 60.0
const ATTACK_COOLDOWN = 0.9
const DAMAGE = 60
const MAX_HP = 900.0
const FALLBACK_SECONDS = 8.0

var ten_id := ""
var hp := MAX_HP
var attack_cd := 0.0
var _fallback_until := 0.0
var body_rect: ColorRect = null

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	add_to_group("ten_ally")
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 46)
	cs.shape = rect
	cs.position = Vector2(0, -23)
	add_child(cs)
	body_rect = ColorRect.new()
	body_rect.size = Vector2(20, 42)
	body_rect.position = Vector2(-10, -44)
	body_rect.color = Color(0.9, 0.82, 0.55)   # trophy gold: unbreakable, visibly so
	add_child(body_rect)
	var def = TheTen.get_def(ten_id)
	var nl := Label.new()
	nl.text = str(def.get("name", "?"))
	nl.position = Vector2(-60, -66)
	nl.size = Vector2(120, 14)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.add_theme_font_size_override("font_size", 10)
	nl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	nl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	nl.add_theme_constant_override("outline_size", 3)
	add_child(nl)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if attack_cd > 0.0:
		attack_cd -= delta
	var now := Time.get_ticks_msec() / 1000.0
	if now < _fallback_until:
		# beaten to the ground, not out of the fight: breathe at the gate
		velocity.x = clampf(300.0 - global_position.x, -WALK_SPEED, WALK_SPEED)
		move_and_slide()
		return
	if hp <= 0.0:
		hp = MAX_HP * 0.6
		if body_rect:
			body_rect.color = Color(0.9, 0.82, 0.55)
	var prey := _nearest_transformed()
	if prey != null:
		var dist := global_position.distance_to(prey.global_position)
		if dist > ATTACK_RANGE:
			velocity.x = signf(prey.global_position.x - global_position.x) * WALK_SPEED
		else:
			velocity.x = 0.0
			if attack_cd <= 0.0:
				attack_cd = ATTACK_COOLDOWN
				if prey.has_method("take_damage"):
					prey.take_damage(DAMAGE)
	else:
		velocity.x = 0.0
	move_and_slide()

func _nearest_transformed() -> Node2D:
	var best: Node2D = null
	var best_d := 900.0
	for t in get_tree().get_nodes_in_group("transformed"):
		if not is_instance_valid(t) or ("is_dead" in t and t.is_dead):
			continue
		var d: float = global_position.distance_to(t.global_position)
		if d < best_d:
			best_d = d
			best = t
	return best

# A legend cannot be killed here -- despair already tried for years. Beaten to
# nothing, they fall back, breathe, and return at 60%.
func take_damage(amount: int) -> void:
	hp -= float(amount)
	if body_rect:
		body_rect.color = Color(0.85, 0.45, 0.35)
		var t = create_tween()
		t.tween_property(body_rect, "color", Color(0.9, 0.82, 0.55), 0.3)
	if hp <= 0.0:
		_fallback_until = Time.get_ticks_msec() / 1000.0 + FALLBACK_SECONDS
		FloatingText.spawn_word(get_parent(), global_position + Vector2(0, -50), "UNBROKEN — FALLING BACK", Color(1.0, 0.85, 0.4))
