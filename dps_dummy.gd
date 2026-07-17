extends CharacterBody2D

# The Proving Grounds training dummy: an invincible target that never dies and
# shows a live damage readout (DPS over a rolling window, last hit, total). It
# sits in the enemy groups + layer so every player weapon/relic hits it, but its
# take_damage only RECORDS -- it can't be killed.

const WINDOW := 3.0            # seconds the DPS average is measured over
const TOTAL_RESET := 25.0      # the running total zeroes out every 25s
var is_dead := false           # the attack code checks this; always false here
var health := 1_000_000_000
var max_health := 1_000_000_000
var facing_direction := -1     # faces the player's usual approach side

var _hits: Array = []          # [[t, dmg], ...] within WINDOW
var _total := 0
var _last := 0
var _peak_dps := 0.0
var _total_reset_at := 0.0     # wall-clock time the total next resets
var _label: Label = null

func _ready() -> void:
	add_to_group("dungeon_combatant")
	collision_layer = 4        # enemy layer -- the player's AttackArea + arrows hit layer 4
	collision_mask = 1
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(46, 92)
	cs.shape = rect
	cs.position = Vector2(0, -46)
	add_child(cs)
	# straw-dummy visual (origin at the feet)
	var post := ColorRect.new()
	post.size = Vector2(10, 92); post.position = Vector2(-5, -92); post.color = Color(0.45, 0.34, 0.2)
	add_child(post)
	var body := ColorRect.new()
	body.size = Vector2(40, 54); body.position = Vector2(-20, -84); body.color = Color(0.78, 0.64, 0.36)
	add_child(body)
	var head := ColorRect.new()
	head.size = Vector2(28, 26); head.position = Vector2(-14, -110); head.color = Color(0.82, 0.7, 0.42)
	add_child(head)
	# live readout above
	_label = Label.new()
	_label.position = Vector2(-95, -190)
	_label.size = Vector2(190, 70)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("outline_size", 4)
	_label.z_index = 60
	add_child(_label)
	_total_reset_at = Time.get_ticks_msec() / 1000.0 + TOTAL_RESET
	_refresh_label(0.0)

func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	var t := Time.get_ticks_msec() / 1000.0
	_hits.append([t, amount])
	_total += amount
	_last = amount
	health = max_health        # never dies

# accept-and-ignore everything else a weapon/relic might do to an enemy
func apply_knockback(_sign: int, _dist: float) -> void: pass
func apply_status(_kind: String, _dur: float = 0.0, _mag: float = 0.0) -> void: pass
func apply_slow(_dur: float, _factor: float) -> void: pass
func apply_petrify(_dur: float) -> bool: return true
func is_frozen() -> bool: return false
func is_petrified() -> bool: return false

func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	while _hits.size() > 0 and t - _hits[0][0] > WINDOW:
		_hits.remove_at(0)
	if t >= _total_reset_at:
		_total = 0
		_total_reset_at = t + TOTAL_RESET
	var sum := 0
	for h in _hits:
		sum += h[1]
	var dps := float(sum) / WINDOW
	_peak_dps = maxf(_peak_dps, dps)
	_refresh_label(dps, maxf(0.0, _total_reset_at - t))

func _refresh_label(dps: float, reset_in := TOTAL_RESET) -> void:
	if _label != null:
		_label.text = "TRAINING DUMMY\nDPS %d   (peak %d)\nlast %d   ·   total %d  (resets %ds)" % [
			int(round(dps)), int(round(_peak_dps)), _last, _total, int(ceil(reset_in))]
