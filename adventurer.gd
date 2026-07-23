extends CharacterBody2D

# A living adventurer defending Deepwood (GAME_BIBLE 2.4.1). Persistent between
# sieges, stationable by the player with E, and MORTAL: when one dies it is
# gone for the whole playthrough -- GameState.kill_adventurer marks the roster
# and nothing ever respawns it.
#
#   wall  -- plants near the village wall, the first thing a raider meets
#   city  -- patrols the village proper, a second line
#   house -- shelters indoors: no combat, no targeting, CANNOT die
#
# Raiders find fighting adventurers through the "village_defender" group
# (siege_enemy.DEFENDER_GROUPS); a housed adventurer leaves that group, so the
# horde has no claim on it. Visuals are procedural (art freeze).

const GRAVITY = 900.0
const WALK_SPEED = 74.0
const ATTACK_RANGE = 56.0
const BOW_RANGE = 420.0
const ATTACK_COOLDOWN = 1.0
const SEEK_RANGE = 760.0
const ARROW_SCENE = preload("res://arrow.tscn")
const SFX_SWORD = preload("res://audio/sword_swing.wav")
const SFX_SPEAR = preload("res://audio/spear_thrust.wav")
const SFX_BOW = preload("res://audio/bow_shot.wav")
const SFX_BLOCK = preload("res://audio/arrow_deflect.wav")
const SFX_BURST = preload("res://audio/explosion.wav")

func play_sfx(stream: AudioStream) -> void:
	var sp = AudioStreamPlayer2D.new()
	sp.stream = stream
	sp.global_position = global_position
	get_parent().add_child(sp)
	sp.play()
	sp.finished.connect(sp.queue_free)

var adventurer_id := ""
var def: Dictionary = {}
var station := "city"
var home_x := 0.0            # the anchor this station patrols around
var patrol_off := 0.0
var patrol_dir := 1.0
var _post_offset := 0.0       # a stable per-hero shift so co-stationed heroes don't stack
var attack_cd := 0.0
var is_dead := false
var player_near := false

var body_rect: ColorRect = null
var weapon_rect: ColorRect = null
var name_label: Label = null
var prompt: Label = null

# --- signature ability state (each adventurer runs a DIFFERENT mechanic) ---
var ability := ""
var _shot_count := 0          # Twin Nock: every 3rd draw doubles
var _swing_count := 0         # The Fifth Blade: every 5th swing erupts
var _grudge_armed := false    # Grudgekeeper: struck -> next hit lands double
var _daybreak_used := false   # Daybreak Pact: once per siege
var _block_ready_at := 0.0    # Shield Wall: one free block on a cooldown
var _hp_bg: ColorRect = null
var _hp_fill: ColorRect = null
var _bark_cooldown := 0.0

# Idle flavour by station, so the corps reads as people keeping a watch rather
# than statues with abilities. Their own rescue line mixes in as the rare one.
const STATION_BARKS = {
	"wall": [
		"Nothing on the treeline. Yet.",
		"They test the wall every night. So do I.",
		"Go on, hunter. This stretch is held.",
	],
	"city": [
		"Streets are quiet. I keep them that way.",
		"I walk the rounds. The rounds walk me back.",
		"Any of the taken come home today?",
	],
	"house": [
		"Patching up. I'll be no use to anyone dead.",
		"A roof. Forgot what one sounded like in the rain.",
	],
}
const SHIELD_WALL_CD := 6.0
const FIFTH_BLADE_RADIUS := 130.0
const EXECUTE_FRAC := 0.20    # Bottom-Seen finishes raiders under this

const WEAPON_COLORS = {
	"blade": Color(0.82, 0.84, 0.9),
	"bow": Color(0.45, 0.3, 0.14),
	"spear": Color(0.6, 0.45, 0.25),
}

func _ready() -> void:
	def = Adventurers.get_def(adventurer_id)
	ability = str(def.get("ability", ""))
	var st = GameState.adventurer_state(adventurer_id)
	station = str(st.get("station", "city"))
	preload("res://char_shadow.gd").attach(self, 0.45, 0.0)  # grounding shadow (feet at y0)
	# Spread + desync (dev report: the three starters "stick to each other,
	# sometimes run away"). All three default to the "city" post, so they aimed
	# for the SAME village-centre point and paced it in perfect lockstep -- a
	# glued, jittering knot. Give each a stable offset off the shared anchor and
	# a random patrol phase, so they pace different stretches as three bodies.
	_post_offset = (float(hash(adventurer_id) % 5) - 2.0) * 48.0
	patrol_off = randf_range(-90.0, 90.0)
	patrol_dir = 1.0 if (hash(adventurer_id) % 2 == 0) else -1.0
	collision_mask = 1
	collision_layer = 0
	add_to_group("adventurer")
	_apply_station_groups()
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 44)
	cs.shape = rect
	cs.position = Vector2(0, -22)
	add_child(cs)
	_build_visual()
	# player proximity for the E prompt
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var acs := CollisionShape2D.new()
	var arect := RectangleShape2D.new()
	arect.size = Vector2(110, 90)
	acs.shape = arect
	acs.position = Vector2(0, -30)
	area.add_child(acs)
	add_child(area)
	area.body_entered.connect(func(b): if b.is_in_group("player"): player_near = true; _refresh_prompt())
	area.body_exited.connect(func(b): if b.is_in_group("player"): player_near = false; _refresh_prompt())

const ADV_ROOT := "res://art/villagers/"
const ADV_SPRITE_H := 58.0                 # heroes stand a head over the townsfolk (52)

# HEROES MUST READ AS HEROES (dev: "they look like other NPCs"). Sharing the
# villager art is fine -- what makes an adventurer is the SILHOUETTE around
# it: a cloak, a pauldron, a personal colour, and their weapon held out. Each
# of the three gets their own palette so you can name them across the street.
const ADV_SKINS := {"adv_roland": "man3", "adv_wren": "woman2", "adv_castor": "man4"}
const ADV_COLORS := {
	"adv_roland": Color(0.42, 0.55, 0.85),   # steel blue -- the shield that stood
	"adv_wren":   Color(0.35, 0.66, 0.42),   # hunter green -- the bow in the dark
	"adv_castor": Color(0.72, 0.32, 0.30),   # old crimson -- the spear line
}
var _skin_sprite: AnimatedSprite2D = null
var _cloak: Polygon2D = null

func hero_color() -> Color:
	return ADV_COLORS.get(adventurer_id, Color(0.55, 0.6, 0.8))

func _build_visual() -> void:
	var col := hero_color()
	var vskin: String = ADV_SKINS.get(adventurer_id, "man")
	# THE CLOAK -- drawn BEHIND the body, the instant "this one is a fighter"
	_cloak = Polygon2D.new()
	_cloak.polygon = PackedVector2Array([
		Vector2(-3, -50), Vector2(13, -46), Vector2(17, -16),
		Vector2(11, -2), Vector2(-2, -4), Vector2(-6, -30),
	])
	_cloak.color = col.darkened(0.28)
	_cloak.z_index = -1
	add_child(_cloak)
	if EnemySkins.is_per_frame(vskin, ADV_ROOT):
		_skin_sprite = AnimatedSprite2D.new()
		_skin_sprite.sprite_frames = EnemySkins.frames_for(vskin, ADV_ROOT)
		_skin_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var ch := EnemySkins.content_height(vskin, ADV_ROOT)
		var sc := ADV_SPRITE_H / ch
		_skin_sprite.scale = Vector2(sc, sc)
		_skin_sprite.offset = Vector2(-EnemySkins.hcenter_px(vskin, ADV_ROOT), -EnemySkins.feet_px(vskin, ADV_ROOT))
		# tinted toward their own colour, not a uniform blue wash
		_skin_sprite.modulate = col.lightened(0.35)
		if _skin_sprite.sprite_frames.has_animation("idle"):
			_skin_sprite.animation = "idle"
			_skin_sprite.play()
		add_child(_skin_sprite)
		body_rect = ColorRect.new()
		body_rect.visible = false          # stand-in for legacy references
		add_child(body_rect)
	else:
		body_rect = ColorRect.new()
		body_rect.size = Vector2(22, 46)
		body_rect.position = Vector2(-11, -48)
		body_rect.color = col.darkened(0.1)
		body_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(body_rect)
	# a pauldron: one bright plate at the shoulder, their colour, unmistakable
	var pauldron := Polygon2D.new()
	pauldron.polygon = PackedVector2Array([
		Vector2(-11, -46), Vector2(0, -49), Vector2(2, -40), Vector2(-10, -38),
	])
	pauldron.color = col.lightened(0.18)
	add_child(pauldron)
	# the weapon reads from across the street: longer, and each kind shaped
	# its own way (a spear outreaches a blade; a bow is a stave with a string)
	var wep := str(def.get("weapon", "blade"))
	weapon_rect = ColorRect.new()
	match wep:
		"spear":
			weapon_rect.size = Vector2(4, 52)
			weapon_rect.position = Vector2(12, -56)
		"bow":
			weapon_rect.size = Vector2(4, 34)
			weapon_rect.position = Vector2(13, -46)
		_:
			weapon_rect.size = Vector2(5, 36)
			weapon_rect.position = Vector2(12, -48)
	weapon_rect.color = WEAPON_COLORS.get(wep, Color.WHITE)
	weapon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(weapon_rect)
	# a blade catches the light at its tip; a spear has a head
	if wep != "bow":
		var tip := Polygon2D.new()
		var ty: float = -60.0 if wep == "spear" else -52.0
		tip.polygon = PackedVector2Array([
			Vector2(11, ty + 6), Vector2(14.5, ty), Vector2(18, ty + 6),
		])
		tip.color = Color(0.92, 0.94, 1.0)
		add_child(tip)
	name_label = Label.new()
	name_label.text = str(def.get("name", "Adventurer"))
	name_label.position = Vector2(-60, -78)
	name_label.size = Vector2(120, 16)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", col.lightened(0.45))
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	name_label.add_theme_constant_override("outline_size", 3)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_label)
	# the signature ability, worn like a title -- gold, under the name
	var abl := Label.new()
	abl.text = "« %s »" % str(def.get("ability_name", ""))
	abl.position = Vector2(-60, -67)
	abl.size = Vector2(120, 14)
	abl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	abl.add_theme_font_size_override("font_size", 8)
	abl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	abl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	abl.add_theme_constant_override("outline_size", 2)
	abl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(abl)
	prompt = Label.new()
	prompt.position = Vector2(-90, -84)
	prompt.size = Vector2(180, 16)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 10)
	prompt.add_theme_color_override("font_color", Color(1, 1, 0.8))
	prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	prompt.add_theme_constant_override("outline_size", 3)
	prompt.visible = false
	add_child(prompt)
	# a slim health bar: wounds persist between sieges, so the player needs to
	# SEE who is hurt to decide who gets housed before the next wave
	_hp_bg = ColorRect.new()
	_hp_bg.size = Vector2(30, 4)
	_hp_bg.position = Vector2(-15, -50)
	_hp_bg.color = Color(0.1, 0.08, 0.08, 0.85)
	_hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hp_bg)
	_hp_fill = ColorRect.new()
	_hp_fill.size = Vector2(30, 4)
	_hp_fill.position = Vector2(-15, -50)
	_hp_fill.color = Color(0.3, 0.85, 0.4)
	_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hp_fill)

func _refresh_prompt() -> void:
	if prompt == null:
		return
	prompt.visible = player_near
	prompt.text = "[E] Station: %s" % station.to_upper()

# Housed adventurers are untouchable and untargetable; fighting ones are
# village defenders the horde will come for.
func _apply_station_groups() -> void:
	if station == "house":
		if is_in_group("village_defender"):
			remove_from_group("village_defender")
	else:
		if not is_in_group("village_defender"):
			add_to_group("village_defender")

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if attack_cd > 0.0:
		attack_cd -= delta
	if player_near and Input.is_action_just_pressed("interact"):
		_cycle_station()
	var target: Node2D = null
	if station != "house":
		target = _nearest_raider()
	if target != null:
		_fight(target)
	else:
		_hold_station(delta)
	# play WALK while moving, IDLE at rest (the frames were always there -- the
	# hero just never left idle)
	_update_adv_anim(absf(velocity.x) > 8.0)
	_update_hp_bar()
	_tick_bark(delta, target != null)
	move_and_slide()
	_separate()   # AFTER the move, so the AI's pull can never undo it (dev x4)

# The villager skins carry idle + walk but NO attack frames, so: swap the sprite
# between walk/idle from movement, and sell the swing with a procedural lunge.
func _update_adv_anim(moving: bool) -> void:
	if _skin_sprite == null:
		return
	var sf: SpriteFrames = _skin_sprite.sprite_frames
	var want := "walk" if moving else "idle"
	if sf != null and sf.has_animation(want) and _skin_sprite.animation != want:
		_skin_sprite.play(want)

# A short forward jab of the body -- the attack "animation" for a skin that has no
# attack strip (dev: "no attack"). Reads as a swing without new art.
func _swing_lunge() -> void:
	var node: Node2D = _skin_sprite if _skin_sprite != null else body_rect
	if node == null:
		return
	var face := signf(_skin_sprite.scale.x) if _skin_sprite != null else 1.0
	if face == 0.0:
		face = 1.0
	var t := node.create_tween()
	t.tween_property(node, "position:x", 10.0 * face, 0.07)
	t.tween_property(node, "position:x", 0.0, 0.13)

# Two defenders converging on one raider used to end up standing INSIDE each
# other -- two cloaked sprites on the same pixel read as one glued blob (dev's
# report, FOUR times). This runs AFTER move_and_slide, so it is the final word on
# position: any two heroes closer than PERSONAL_SPACE are shoved to exactly that
# gap THIS frame (each moves half the overlap). The AI's pull toward a shared
# target can never undo it, so they can never stack -- they always read as three
# separate bodies. They still don't physically collide, so they slide past freely.
const PERSONAL_SPACE := 52.0     # a clear gap for the wide cloaked sprites

func _separate() -> void:
	for other in get_tree().get_nodes_in_group("adventurer"):
		if other == self or not is_instance_valid(other):
			continue
		if "is_dead" in other and other.is_dead:
			continue
		var dx: float = global_position.x - other.global_position.x
		if absf(dx) < PERSONAL_SPACE:
			# ties broken by name so the pair never shove each other the same way
			var push := signf(dx) if absf(dx) > 0.5 else (1.0 if adventurer_id > str(other.adventurer_id) else -1.0)
			# HARD: each moves half the overlap -> the pair ends a full gap apart
			global_position.x += push * (PERSONAL_SPACE - absf(dx)) * 0.5

# A line now and then, when the player is close and nothing is trying to kill
# anyone. Long random gaps so twelve of them never turn into a crowd scene.
func _tick_bark(delta: float, in_combat: bool) -> void:
	_bark_cooldown -= delta
	if _bark_cooldown > 0.0 or in_combat or not player_near:
		return
	_bark_cooldown = randf_range(45.0, 90.0)
	var pool: Array = STATION_BARKS.get(station, [])
	if pool.is_empty():
		return
	# their own rescue line is the rare one -- who they are, resurfacing
	var line: String = str(def.get("line", "")) if (randf() < 0.15 and str(def.get("line", "")) != "") else str(pool[randi() % pool.size()])
	SpeechText.spawn(self, line)

func _update_hp_bar() -> void:
	if _hp_fill == null:
		return
	var max_hp := maxf(1.0, float(def.get("hp", 100.0)))
	var hp := clampf(float(GameState.adventurer_state(adventurer_id).get("hp", max_hp)), 0.0, max_hp)
	var frac := hp / max_hp
	_hp_fill.size.x = 30.0 * frac
	_hp_fill.color = Color(0.3, 0.85, 0.4) if frac > 0.5 else (Color(0.9, 0.75, 0.25) if frac > 0.25 else Color(0.9, 0.3, 0.25))
	# full and safe reads clean: hide the bar entirely when untouched
	_hp_bg.visible = frac < 0.999
	_hp_fill.visible = _hp_bg.visible

func _cycle_station() -> void:
	var idx = Adventurers.STATIONS.find(station)
	station = Adventurers.STATIONS[(idx + 1) % Adventurers.STATIONS.size()]
	GameState.set_adventurer_station(adventurer_id, station)
	_apply_station_groups()
	home_x = _station_anchor_x()
	_refresh_prompt()
	var stack = get_tree().get_first_node_in_group("notification_stack")
	if stack:
		var how: String = {"wall": "holds the wall", "city": "patrols the village", "house": "shelters indoors (safe)"}[station]
		stack.show_notification("%s now %s." % [def.get("name", "The adventurer"), how])

func _station_anchor_x() -> float:
	match station:
		"wall":
			# 7.2: two ramparts now -- wall-stationed adventurers split between
			# them by a coin that never changes (their id's hash), so both
			# flanks always have someone if you posted anyone at all
			var walls := get_tree().get_nodes_in_group("village_wall")
			if walls.is_empty():
				return global_position.x
			var wall = walls[hash(adventurer_id) % walls.size()]
			var inward := 160.0 if (not "flank" in wall or wall.flank == "west") else -160.0
			return wall.global_position.x - inward
		"house":
			# by the cottages -- DERIVED, not hardcoded. These used to be 1050
			# and 2200, magic numbers from an older, smaller map: the village
			# has long since sat at 4900+, so the corps patrolled empty road
			# ~2,700px west of the town they defend (dev: "too far away").
			# A house-stationed defender belongs AMONG THE BUILDINGS. The old
			# derivation took the furthest-east "village_structure", which the
			# group has since outgrown: the Underdark's 43 chests are all in it
			# (a kilometre down, out to x~36,500) and so are the east-road
			# markers (out past x~20,000). Either dragged the anchor clean off
			# the map -- the very "too far away" bug it was meant to cure. Clamp
			# to the real building span, so "east end of town" stays IN town.
			var lo := INF
			var hi := -INF
			for b in get_tree().get_nodes_in_group("building"):
				if is_instance_valid(b):
					lo = minf(lo, b.global_position.x)
					hi = maxf(hi, b.global_position.x)
			if hi < lo:
				return _village_center_x()
			# toward the east end of the housing, but never past the last hall
			return lerpf(lo, hi, 0.72)
		_:
			return _village_center_x()

# The middle of the standing village, measured from the buildings themselves.
func _village_center_x() -> float:
	var lo := INF
	var hi := -INF
	for b in get_tree().get_nodes_in_group("building"):
		if not is_instance_valid(b):
			continue
		lo = minf(lo, b.global_position.x)
		hi = maxf(hi, b.global_position.x)
	if lo == INF:
		return 0.0            # buildings not in the tree yet -> "unresolved"
	return (lo + hi) * 0.5

# _ready() can run BEFORE the village buildings are in the tree, which left
# home_x resolved to 0 -- the corps then tried to walk to the world origin
# instead of home (dev: "too far away from village"). Re-resolve until it
# lands on a real anchor.
func _ensure_anchor() -> void:
	if home_x != 0.0:
		return
	var a := _station_anchor_x()
	if a != 0.0:
		home_x = a

func _hold_station(delta: float) -> void:
	if home_x == 0.0:
		home_x = _station_anchor_x()
	# a housed adventurer stands still at the door; the rest pace their post
	if station == "city":
		patrol_off += patrol_dir * 24.0 * delta
		if absf(patrol_off) > 140.0:
			patrol_dir *= -1.0
	_ensure_anchor()
	var dest := home_x + (_post_offset + patrol_off if station == "city" else _post_offset * 0.5)
	# (mutual spacing is handled every frame by _separate(), called from
	# _physics_process -- see PERSONAL_SPACE)
	var dx := dest - global_position.x
	velocity.x = clampf(dx, -WALK_SPEED, WALK_SPEED) if absf(dx) > 6.0 else 0.0
	if absf(velocity.x) > 1.0:
		var face := 1.0 if velocity.x >= 0.0 else -1.0
		if _skin_sprite:
			_skin_sprite.scale.x = absf(_skin_sprite.scale.x) * face
		elif body_rect:
			body_rect.scale.x = face

# How far from their POST a hero will move to meet a threat. A SIEGE is the
# post's whole reason to exist, so they'll cross the watch to meet it; a WILD
# east-road mob is only their fight if it's right on top of them -- otherwise
# they'd sprint 760px down the road after it and abandon the town they guard
# (dev report: "sometimes running away"). They still defend themselves.
const DEFEND_RADIUS := 560.0
const SELF_DEFENSE_RADIUS := 150.0

func _nearest_raider() -> Node2D:
	var post_x: float = home_x if home_x != 0.0 else global_position.x
	var best: Node2D = null
	var best_d := SEEK_RANGE
	# a siege threatens the post -- meet it anywhere within the post's watch
	for r in get_tree().get_nodes_in_group("siege_enemy"):
		if not is_instance_valid(r) or ("is_dead" in r and r.is_dead):
			continue
		if absf(r.global_position.x - post_x) > DEFEND_RADIUS:
			continue
		var d: float = global_position.distance_to(r.global_position)
		if d < best_d:
			best_d = d
			best = r
	# a wild road mob: fought only when it comes right to them, never chased
	for r in get_tree().get_nodes_in_group("course_enemy"):
		if not is_instance_valid(r) or ("is_dead" in r and r.is_dead):
			continue
		var d2: float = global_position.distance_to(r.global_position)
		if d2 <= SELF_DEFENSE_RADIUS and d2 < best_d:
			best_d = d2
			best = r
	return best

# The attack this swing will land, after the signature riders that scale it:
# Jorun's Ledger counts the fallen, Kessa's Grudge doubles a struck answer.
func _attack_damage() -> int:
	var dmg := float(def.get("dmg", 12))
	if ability == "ledger":
		var fallen := 0
		for id in GameState.adventurers.keys():
			if GameState.adventurers[id]["dead"]:
				fallen += 1
		dmg *= 1.0 + 0.25 * float(fallen)
	if ability == "grudge" and _grudge_armed:
		_grudge_armed = false
		dmg *= 2.0
		FloatingText.spawn_word(get_parent(), global_position + Vector2(0, -60), "GRUDGE!", Color(1.0, 0.6, 0.4))
	return int(round(dmg))

func _loose_arrow(at: Node2D, dmg: int) -> void:
	var arrow = ARROW_SCENE.instantiate()
	var dir = (at.global_position + Vector2(0, -14) - global_position).normalized()
	arrow.position = global_position + Vector2(0, -30) + dir * 16.0
	arrow.setup(dir, dmg, 20.0, 40.0, 4)
	# Essa's shafts punch through a rank; Liselle's carry the venom they fed her
	if ability == "eyeshot":
		arrow.pierce_count = 3
	if ability == "baited":
		arrow.enemy_statuses = [{"kind": "poison", "dur": 4.0, "mag": 6.0}]
	get_parent().add_child(arrow)

# The second-nearest raider, for Wren's Twin Nock.
func _second_raider(first: Node2D) -> Node2D:
	var best: Node2D = null
	var best_d := SEEK_RANGE
	for r in get_tree().get_nodes_in_group("siege_enemy"):
		if r == first or not is_instance_valid(r) or ("is_dead" in r and r.is_dead):
			continue
		var d: float = global_position.distance_to(r.global_position)
		if d < best_d:
			best_d = d
			best = r
	return best

func _fight(target: Node2D) -> void:
	# face the raider so the sprite (and the swing lunge) point the right way
	var tface := 1.0 if target.global_position.x >= global_position.x else -1.0
	if _skin_sprite:
		_skin_sprite.scale.x = absf(_skin_sprite.scale.x) * tface
	elif body_rect:
		body_rect.scale.x = tface
	var is_bow := str(def.get("weapon", "blade")) == "bow"
	var reach := BOW_RANGE if is_bow else ATTACK_RANGE
	# a COMBAT STAND-OFF SLOT (dev: "heroes glued"): don't march onto the raider's
	# exact x -- aim for a per-hero offset beside it, so several heroes attacking one
	# raider fan out along the reach instead of piling on the same pixel.
	var slot := clampf(_post_offset * 0.5, -reach * 0.7, reach * 0.7)
	var stand_x := target.global_position.x + slot
	var dist := absf(stand_x - global_position.x)
	if dist > reach * 0.6:
		velocity.x = signf(stand_x - global_position.x) * WALK_SPEED * 1.35
		return
	velocity.x = 0.0
	if attack_cd > 0.0:
		return
	attack_cd = ATTACK_COOLDOWN * (1.4 if is_bow else 1.0)
	var dmg := _attack_damage()
	if is_bow:
		play_sfx(SFX_BOW)
		_loose_arrow(target, dmg)
		# Twin Nock: every third draw looses a second shaft at a second raider
		if ability == "twin_nock":
			_shot_count += 1
			if _shot_count % 3 == 0:
				var second := _second_raider(target)
				if second != null:
					_loose_arrow(second, dmg)
	elif target.has_method("take_damage"):
		play_sfx(SFX_SPEAR if str(def.get("weapon", "blade")) == "spear" else SFX_SWORD)
		_swing_lunge()   # the swing, since the skin has no attack strip
		# Bottom-Seen: a wounded raider is not fought, it is FINISHED
		if ability == "bottom_seen" and "health" in target and "max_health" in target \
				and float(target.health) <= float(target.max_health) * EXECUTE_FRAC:
			target.take_damage(999999)
			FloatingText.spawn_word(get_parent(), target.global_position + Vector2(0, -40), "EXECUTED", Color(0.9, 0.3, 0.4))
		else:
			var was_alive: bool = not ("is_dead" in target and target.is_dead)
			target.take_damage(dmg)
			# Frostbrand chills; Phalanx hurls and staggers
			if ability == "frostbrand" and target.has_method("apply_status"):
				target.apply_status("slow", 2.5, 0.5)
			if ability == "phalanx":
				if target.has_method("apply_knockback"):
					target.apply_knockback(1 if target.global_position.x >= global_position.x else -1, 180.0)
				if target.has_method("apply_status"):
					target.apply_status("slow", 1.5, 0.4)
			# The Fifth Blade: every fifth swing erupts around the mark
			if ability == "fifth_blade":
				_swing_count += 1
				if _swing_count % 5 == 0:
					play_sfx(SFX_BURST)
					var burst := int(round(dmg * 0.6))
					for r in get_tree().get_nodes_in_group("siege_enemy"):
						if r != target and is_instance_valid(r) and r.has_method("take_damage") \
								and not ("is_dead" in r and r.is_dead) \
								and target.global_position.distance_to(r.global_position) <= FIFTH_BLADE_RADIUS:
							r.take_damage(burst)
					FloatingText.spawn_word(get_parent(), target.global_position + Vector2(0, -50), "THE FIFTH BLADE", Color(0.95, 0.85, 0.5))
			# Last Watch: a felled raider knits the guard's own wounds
			if ability == "last_watch" and was_alive and "is_dead" in target and target.is_dead:
				var st = GameState.adventurer_state(adventurer_id)
				var max_hp := float(def.get("hp", 100.0))
				GameState.adventurers[adventurer_id]["hp"] = minf(max_hp, float(st.get("hp", max_hp)) + 20.0)
		if weapon_rect:
			var t = create_tween()
			t.tween_property(weapon_rect, "rotation_degrees", 70.0 * body_rect.scale.x, 0.08)
			t.tween_property(weapon_rect, "rotation_degrees", 0.0, 0.1)

func take_damage(amount: int) -> void:
	if is_dead or station == "house":
		return
	# the arrival (2.4.1) is where the player LEARNS to fight, in company --
	# nobody is allowed to die in the tutorial wave
	if GameState.arrival_shield_on():
		return
	var now := Time.get_ticks_msec() / 1000.0
	# Shield Wall: Roland reads the blow and takes it on the boss -- one free
	# block, then the rhythm has to reset
	if ability == "shield_wall" and now >= _block_ready_at:
		_block_ready_at = now + SHIELD_WALL_CD
		play_sfx(SFX_BLOCK)
		FloatingText.spawn_word(get_parent(), global_position + Vector2(0, -50), "BLOCKED", Color(0.7, 0.85, 1.0))
		return
	# Grudgekeeper: the blow lands, and the answer is armed
	if ability == "grudge":
		_grudge_armed = true
	var st = GameState.adventurer_state(adventurer_id)
	var hp := float(st.get("hp", 100.0)) - float(amount)
	# Daybreak Pact: once per siege, brought to the brink, Hakon rises to FULL
	var max_hp := float(def.get("hp", 100.0))
	if ability == "daybreak" and not _daybreak_used and hp > 0.0 and hp <= max_hp * 0.3:
		_daybreak_used = true
		hp = max_hp
		FloatingText.spawn_word(get_parent(), global_position + Vector2(0, -56), "DAYBREAK", Color(1.0, 0.95, 0.6))
	GameState.adventurers[adventurer_id]["hp"] = hp
	FloatingText.spawn(get_parent(), global_position + Vector2(0, -40), amount)
	if body_rect:
		body_rect.color = Color(0.8, 0.3, 0.3)
		var t = create_tween()
		t.tween_property(body_rect, "color", Color(0.32, 0.36, 0.46), 0.25)
	if hp <= 0.0:
		die()

# The pact renews between sieges (called via the adventurer group when a live
# siege ends -- the same sweep that binds everyone's wounds).
func on_siege_ended() -> void:
	_daybreak_used = false

func die() -> void:
	if is_dead:
		return
	is_dead = true
	GameState.kill_adventurer(adventurer_id)
	if is_in_group("village_defender"):
		remove_from_group("village_defender")
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 1.2)
	t.tween_callback(queue_free)

func apply_knockback(direction_sign: int, distance: float) -> void:
	velocity.x += float(direction_sign) * distance * 2.0
