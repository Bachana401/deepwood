extends Area2D
# A travel shrine. The village WAYSTONE (is_waystone = true) and every woken DEEP
# SHRINE in the dungeon share this: a stone dais + a slender pillar crowned with a
# hovering, pulsing sigil. Stand near it and press E to open the fast-travel menu
# (shrine_menu.gd). Waystones glow warm gold; deep shrines glow otherworldly cyan.
const MENU := preload("res://shrine_menu.gd")

var is_waystone := false
var _inside := false
var prompt: Label = null

func _ready() -> void:
	collision_mask = 2                       # the player's body layer
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(160.0, 190.0)
	cs.shape = r
	cs.position = Vector2(0.0, -85.0)
	add_child(cs)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	_build_visual()

func _build_visual() -> void:
	var accent: Color = Color(1.0, 0.82, 0.35) if is_waystone else Color(0.4, 0.95, 1.0)
	var stone := Color(0.30, 0.29, 0.34)
	var dais := Polygon2D.new()
	dais.color = stone
	dais.polygon = PackedVector2Array([
		Vector2(-56, 0), Vector2(56, 0), Vector2(42, -22), Vector2(-42, -22)])
	add_child(dais)
	var pillar := Polygon2D.new()
	pillar.color = stone.lightened(0.09)
	pillar.polygon = PackedVector2Array([
		Vector2(-16, -22), Vector2(16, -22), Vector2(12, -124), Vector2(-12, -124)])
	add_child(pillar)
	var crown := Polygon2D.new()
	crown.color = stone.lightened(0.18)
	crown.polygon = _arch(Vector2(0, -140), 28.0, 8.0, 22)
	add_child(crown)
	var halo := Polygon2D.new()
	halo.color = Color(accent.r, accent.g, accent.b, 0.5)
	halo.polygon = _disc(36.0, 22)
	halo.position = Vector2(0, -140)
	halo.material = _add_mat()
	add_child(halo)
	var core := Polygon2D.new()
	core.color = accent
	core.polygon = _disc(12.0, 18)
	core.position = Vector2(0, -140)
	core.material = _add_mat()
	add_child(core)
	var tw := create_tween().set_loops()
	tw.tween_property(halo, "scale", Vector2(1.28, 1.28), 1.3).set_trans(Tween.TRANS_SINE)
	tw.tween_property(halo, "scale", Vector2(1.0, 1.0), 1.3).set_trans(Tween.TRANS_SINE)
	prompt = Label.new()
	prompt.add_theme_font_size_override("font_size", 13)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.position = Vector2(-130, -206)
	prompt.size = Vector2(260, 20)
	prompt.visible = false
	prompt.z_index = 5
	add_child(prompt)

func _add_mat() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m

func _disc(radius: float, sides: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(sides):
		var a := TAU * float(i) / float(sides)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts

func _arch(center: Vector2, radius: float, thick: float, sides: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(sides + 1):
		var a: float = lerp(PI, TAU, float(i) / float(sides))
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	for i in range(sides + 1):
		var a: float = lerp(TAU, PI, float(i) / float(sides))
		pts.append(center + Vector2(cos(a), sin(a)) * (radius - thick))
	return pts

func _on_enter(b: Node2D) -> void:
	if b.is_in_group("player"):
		_inside = true
		prompt.text = "[E]  %s — travel" % ("Waystone" if is_waystone else "Deep Shrine")
		prompt.visible = true

func _on_exit(b: Node2D) -> void:
	if b.is_in_group("player"):
		_inside = false
		prompt.visible = false

func _process(_delta: float) -> void:
	if _inside and Input.is_action_just_pressed("interact"):
		_open_menu()

func _open_menu() -> void:
	var m = MENU.new()
	get_tree().current_scene.add_child(m)
	# where "return home" / "leave the floor" should land you: the village Waystone
	# if one stands, else the default village spawn
	var ret: Vector2 = global_position
	if not is_waystone:
		ret = GameState.waystone_home_pos if GameState.waystone_home_pos != Vector2.ZERO else GameState.VILLAGE_SPAWN
	m.open(ret)
