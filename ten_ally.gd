extends CharacterBody2D

# One of the Ten, fighting beside you at the Harvest (GAME_BIBLE 9.4) -- ten
# lights in a town gone dark. They hunt the transformed (every kill of theirs
# denies the Devourer fuel), they can be beaten down but not killed -- a legend
# at 0 HP falls back to the gate to breathe, then rejoins. Help, not a solution.
#
# Each legend now fights IN CHARACTER: their combat kit echoes the village boon
# their rescue granted (the bible's Brannoc-anchors / Maera-heals / Seraphel-
# slows note, generalised to all ten). See KITS below -- data-driven so the
# numbers stay easy to tune by feel. The behaviours reuse existing hooks only
# (enemy.apply_status / apply_knockback, player heal + add_currency), no new
# combat systems. Roland (override_name, no ten_id) gets the DEFAULT steel kit:
# a mortal hero standing among legends, unkillable HERE by the scene's rule.

const GRAVITY = 900.0
const BASE_HP = 900.0
const FALLBACK_SECONDS = 8.0

# Tunables shared by the support auras.
const AURA_TICK = 0.5             # how often an aura re-applies / re-checks
const RALLY_CD_MULT = 0.6         # Mirielle: nearby allies attack ~40% faster
const SONG_DMG_MULT = 1.4         # Ilo: nearby allies hit ~40% harder

# Every legend's kit. Missing fields fall back to _DEFAULT (Roland's kit).
#   mode:  "single" | "cleave" (all foes in reach) | "ranged" (long reach)
#   reach: attack reach in pixels
#   kb:    knockback pixels on hit (0 = none)
#   slow:  [factor<1, seconds] applied to what it hits (null = none)
#   aura:  "" | "heal" | "slow" | "rally" | "song"  (see _tick_aura)
#   gold:  currency handed to the player per kill (Dorian's Coinbinder echo)
const _DEFAULT = {
	"color": Color(0.65, 0.7, 0.85), "hp_mult": 1.0, "damage": 60, "cooldown": 0.9,
	"reach": 60.0, "speed": 96.0, "mode": "single", "kb": 0.0, "slow": null,
	"aura": "", "aura_range": 0.0, "gold": 0,
}
const KITS = {
	# Brannoc, the Wall That Stood -- the anchor: tankiest, holds a whole lane by
	# CLEAVING every foe pressed against him and shoving them off. (Wall boon.)
	"ten_brannoc": {"color": Color(0.6, 0.66, 0.72), "hp_mult": 1.7, "damage": 42,
		"cooldown": 1.0, "reach": 72.0, "speed": 86.0, "mode": "cleave", "kb": 45.0},
	# Maera, the Last Lightmender -- the medic: weak in the swing, but her light
	# knits the PLAYER back together while she stands near. (Doctor boon.)
	"ten_maera": {"color": Color(0.7, 0.95, 0.75), "hp_mult": 1.1, "damage": 28,
		"cooldown": 1.0, "reach": 60.0, "mode": "single", "aura": "heal", "aura_range": 280.0},
	# Toren Ashvale, the Forgefather -- the hammer: slow, enormous single blows
	# that hurl the struck body backward. (Forge boon.)
	"ten_toren": {"color": Color(0.9, 0.55, 0.3), "hp_mult": 1.2, "damage": 105,
		"cooldown": 1.7, "reach": 64.0, "speed": 90.0, "mode": "single", "kb": 165.0},
	# Sylvara, Warden of the Old Groves -- the entangler: wild roots seize what
	# she strikes, dragging it to a crawl. (Grove boon.)
	"ten_sylvara": {"color": Color(0.45, 0.8, 0.4), "hp_mult": 1.0, "damage": 48,
		"cooldown": 1.0, "reach": 66.0, "mode": "single", "slow": [0.35, 2.5]},
	# Kaldos, the Tidecaller -- the wave: a wide surge that hits everything in
	# front of him and washes it back. (Tide boon.)
	"ten_kaldos": {"color": Color(0.35, 0.7, 0.95), "hp_mult": 1.0, "damage": 40,
		"cooldown": 1.1, "reach": 96.0, "mode": "cleave", "kb": 120.0},
	# Elenwe, Archivist of the Broken Age -- the arcane sniper: strikes from far
	# off with a bolt of remembered lore. (Lore boon.)
	"ten_elenwe": {"color": Color(0.7, 0.5, 0.95), "hp_mult": 0.9, "damage": 74,
		"cooldown": 1.1, "reach": 260.0, "mode": "ranged"},
	# Dorian Vail, the Coinbinder -- the ranged financier: flings biting coin,
	# and every kill of his mints a little gold into your purse. (Bank boon.)
	"ten_dorian": {"color": Color(0.95, 0.82, 0.35), "hp_mult": 0.9, "damage": 46,
		"cooldown": 0.9, "reach": 220.0, "mode": "ranged", "gold": 6},
	# Mirielle, Voice of the Old Crown -- the commander: her order quickens every
	# legend near her. (Government boon.)
	"ten_mirielle": {"color": Color(0.75, 0.55, 0.85), "hp_mult": 1.0, "damage": 34,
		"cooldown": 1.0, "reach": 60.0, "mode": "single", "aura": "rally", "aura_range": 320.0},
	# Seraphel, the Lightkeeper -- the light: a standing radiance that slows all
	# the turned around her, just as it halved despair's withering. (Light boon.)
	"ten_seraphel": {"color": Color(1.0, 0.95, 0.7), "hp_mult": 1.0, "damage": 30,
		"cooldown": 1.0, "reach": 60.0, "mode": "single", "aura": "slow", "aura_range": 240.0},
	# Ilo, the Nameless Bard -- the song: a tune that lends every nearby legend a
	# harder edge. (Tavern boon.)
	"ten_ilo": {"color": Color(0.5, 0.85, 0.8), "hp_mult": 1.0, "damage": 34,
		"cooldown": 1.0, "reach": 60.0, "mode": "single", "aura": "song", "aura_range": 320.0},
}

var ten_id := ""
# 12.6 (decided delegated): the ELEVENTH ally -- Roland at the gate of 100.
# A mortal hero standing among legends: named directly, scaled down, and
# still unkillable HERE (the fall-back rule is the scene's, not the Ten's --
# nobody dies in the player's last stand beside them).
var override_name := ""
var power_scale := 1.0

var kit := _DEFAULT
var _max_hp := BASE_HP
var hp := BASE_HP
var attack_cd := 0.0
var _aura_cd := 0.0
var _fallback_until := 0.0
# Set BY the aura-bearers on nearby allies; READ by each ally when it swings.
var _rally_until := 0.0
var _song_until := 0.0
var body_rect: ColorRect = null

func _resolve_kit() -> Dictionary:
	var k := _DEFAULT.duplicate()
	if ten_id != "" and KITS.has(ten_id):
		for key in KITS[ten_id]:
			k[key] = KITS[ten_id][key]
	return k

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	add_to_group("ten_ally")
	kit = _resolve_kit()
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 46)
	cs.shape = rect
	cs.position = Vector2(0, -23)
	add_child(cs)
	body_rect = ColorRect.new()
	body_rect.size = Vector2(20, 42)
	body_rect.position = Vector2(-10, -44)
	# Roland keeps his steel; a legend wears the colour of their gift.
	body_rect.color = Color(0.65, 0.7, 0.85) if override_name != "" else kit.color
	add_child(body_rect)
	_max_hp = BASE_HP * float(kit.hp_mult) * power_scale
	hp = _max_hp
	var def = TheTen.get_def(ten_id)
	var nl := Label.new()
	nl.text = override_name if override_name != "" else str(def.get("name", "?"))
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
		velocity.x = clampf(300.0 - global_position.x, -float(kit.speed), float(kit.speed))
		move_and_slide()
		return
	if hp <= 0.0:
		hp = _max_hp * 0.6
		if body_rect:
			body_rect.color = Color(0.65, 0.7, 0.85) if override_name != "" else kit.color
	# standing auras run whether or not there's prey in melee reach
	_aura_cd -= delta
	if _aura_cd <= 0.0:
		_aura_cd = AURA_TICK
		_tick_aura()
	var prey := _nearest_transformed()
	if prey != null:
		var dist := global_position.distance_to(prey.global_position)
		if dist > float(kit.reach):
			velocity.x = signf(prey.global_position.x - global_position.x) * float(kit.speed)
		else:
			velocity.x = 0.0
			if attack_cd <= 0.0:
				attack_cd = _effective_cooldown(now)
				_attack(prey, now)
	else:
		velocity.x = 0.0
	move_and_slide()

# Mirielle's order shortens the swing timer of any legend she's blessed.
func _effective_cooldown(now: float) -> float:
	var cd := float(kit.cooldown)
	if now < _rally_until:
		cd *= RALLY_CD_MULT
	return cd

func _attack(prey: Node2D, now: float) -> void:
	var dmg := int(round(float(kit.damage) * power_scale))
	if now < _song_until:                       # Ilo's edge
		dmg = int(round(float(dmg) * SONG_DMG_MULT))
	var mode := str(kit.mode)
	if mode == "cleave":
		for t in _transformed_in_range(float(kit.reach)):
			_hit(t, dmg)
	else:
		_hit(prey, dmg)
		if mode == "ranged":
			_spawn_bolt(global_position + Vector2(0, -22), prey.global_position + Vector2(0, -20))

# One landed blow: damage + this legend's on-hit rider (knockback / root /
# Coinbinder gold on the kill).
func _hit(t: Node2D, dmg: int) -> void:
	if t == null or not is_instance_valid(t) or not t.has_method("take_damage"):
		return
	var was_alive: bool = not ("is_dead" in t and t.is_dead)
	t.take_damage(dmg)
	if float(kit.kb) > 0.0 and t.has_method("apply_knockback"):
		t.apply_knockback(int(signf(t.global_position.x - global_position.x)), float(kit.kb))
	if kit.slow != null and t.has_method("apply_status"):
		t.apply_status("slow", float(kit.slow[1]), float(kit.slow[0]))
	if int(kit.gold) > 0 and was_alive and ("is_dead" in t and t.is_dead):
		var p = get_tree().get_first_node_in_group("player")
		if p != null and p.has_method("add_currency"):
			p.add_currency(int(kit.gold))
			FloatingText.spawn_word(get_parent(), global_position + Vector2(0, -54),
				"+%dg" % int(kit.gold), Color(0.95, 0.82, 0.35))

# The support auras. Each re-applies on its own slow tick.
func _tick_aura() -> void:
	match str(kit.aura):
		"heal":
			var p = get_tree().get_first_node_in_group("player")
			if p != null and "health" in p and p.has_method("get_max_health"):
				var maxh: int = p.get_max_health()
				if p.health > 0 and p.health < maxh \
						and global_position.distance_to(p.global_position) <= float(kit.aura_range):
					var mend: int = maxi(1, int(round(maxh * 0.03)))   # ~6% / sec at AURA_TICK 0.5
					p.health = mini(maxh, p.health + mend)
					if p.has_method("update_health_display"):
						p.update_health_display()
					FloatingText.spawn_word(get_parent(), p.global_position + Vector2(0, -70),
						"+%d" % mend, Color(0.6, 0.95, 0.7))
		"slow":
			for t in _transformed_in_range(float(kit.aura_range)):
				if t.has_method("apply_status"):
					t.apply_status("slow", AURA_TICK + 1.0, 0.6)
		"rally":
			for a in _allies_in_range(float(kit.aura_range)):
				a._rally_until = maxf(a._rally_until, Time.get_ticks_msec() / 1000.0 + AURA_TICK + 0.3)
		"song":
			for a in _allies_in_range(float(kit.aura_range)):
				a._song_until = maxf(a._song_until, Time.get_ticks_msec() / 1000.0 + AURA_TICK + 0.3)

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

func _transformed_in_range(r: float) -> Array:
	var out: Array = []
	for t in get_tree().get_nodes_in_group("transformed"):
		if not is_instance_valid(t) or ("is_dead" in t and t.is_dead):
			continue
		if global_position.distance_to(t.global_position) <= r:
			out.append(t)
	return out

func _allies_in_range(r: float) -> Array:
	var out: Array = []
	for a in get_tree().get_nodes_in_group("ten_ally"):
		if is_instance_valid(a) and global_position.distance_to(a.global_position) <= r:
			out.append(a)
	return out

# A brief line for a ranged legend's shot, so the reach reads on screen.
func _spawn_bolt(from: Vector2, to: Vector2) -> void:
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = kit.color
	line.z_index = 15
	line.add_point(to_local(from))
	line.add_point(to_local(to))
	add_child(line)
	var tw := create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.14)
	tw.tween_callback(line.queue_free)

# A legend cannot be killed here -- despair already tried for years. Beaten to
# nothing, they fall back, breathe, and return at 60%.
func take_damage(amount: int) -> void:
	hp -= float(amount)
	if body_rect:
		body_rect.color = Color(0.85, 0.45, 0.35)
		var restore: Color = Color(0.65, 0.7, 0.85) if override_name != "" else kit.color
		var t = create_tween()
		t.tween_property(body_rect, "color", restore, 0.3)
	if hp <= 0.0:
		_fallback_until = Time.get_ticks_msec() / 1000.0 + FALLBACK_SECONDS
		FloatingText.spawn_word(get_parent(), global_position + Vector2(0, -50), "UNBROKEN — FALLING BACK", Color(1.0, 0.85, 0.4))
