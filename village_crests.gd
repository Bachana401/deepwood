extends Node2D
# THE ROOFLINE: who is in charge here, and what they can do about it.
#
# The dev's complaint about this whole layer was "invisible / numbers not feel",
# and the leader powers were the worst of it. A named power (BUILDING_POWERS)
# needs a hall at level 4 AND the right person in the chair -- an expensive,
# deliberate thing -- and the entire feedback for it was a line in a menu. Seat
# a Chancellor, nothing happens on screen. Lose them, nothing happens either.
#
# So the town wears it. Every hall with its leader seated flies a STANDARD; the
# instant that leader's power is awake the standard gains a burning ring, and
# the power's real name hangs under it when you walk close. Pull the leader and
# the ring dies while you watch.
#
# Lives here rather than in village_presence because a CanvasItem has exactly
# one z_index and this half has to draw ABOVE the buildings (frame z 3, door 4)
# while the ground half has to draw below them. Parented by village_presence, so
# main.gd spawns one node and gets both.
#
# Procedural, additive, no Light2D (⛔ gen freeze; and the underground pass
# already proved real lights cost more here than they return). Reads state,
# never writes it.

const REFRESH := 0.06
const VIEW_MARGIN := 2400.0
# ⚠ ONE NAME AT A TIME. At the world's 0.6 zoom the screen is ~1,900px wide, so a
# 1,000px range put a name board over EVERY hall on screen at once and the sky
# filled with labels (first EYES pass). 400 means the hall you are standing at
# names its power and its neighbours stay quiet.
const NAME_RANGE := 400.0
const PLIGHT := preload("res://presence_light.gd")

const STATE_REFRESH := 0.3    # how often the SLOW facts are re-read (see below)

var _t: float = 0.0
var _st: float = 99.0
var _phase: float = 0.0
var _font: Font = null
var _mod: Color = Color(1, 1, 1, 1)
# ⚠ has_building_power() walks BuildingRoles AND the villager roster for every
# hall it is asked about. Asking fifteen halls sixteen times a second, for facts
# that change when the player seats somebody, is thousands of wasted roster steps
# a frame. The crest LIST is rebuilt on a slow clock; _draw only animates it.
var _crests: Array = []

# Flame and sigil are LIGHT and must survive the night CanvasModulate; the pole
# and the cloth are objects and darken with everything else. See presence_light.gd.
func _lit(c: Color, amount: float = 1.0) -> Color:
	return PLIGHT.lift(c, _mod, amount)

const AURA_TINT := {
	"Bar":      Color(1.00, 0.72, 0.26),
	"Shrine":   Color(0.74, 0.85, 1.00),
	"Hospital": Color(0.42, 0.98, 0.62),
}
# ⚠ MUST MATCH village_presence.QUARTER_COLOR. The waymarker on the road and the
# colours a hall flies are one statement: "this building belongs to that quarter".
# Two different palettes would silently break the only link between them.
const QUARTER_COLOR := {
	"gatefront": Color(0.78, 0.34, 0.28),
	"heart":     Color(0.92, 0.76, 0.34),
	"outskirts": Color(0.46, 0.72, 0.38),
}

func _ready() -> void:
	z_index = 5                # over the frame (3) and the door (4)
	add_to_group("village_crests")
	var f: Resource = load("res://art/fonts/PixelifySans.ttf")
	if f is Font:
		_font = f
	_refresh_crests()

func _process(delta: float) -> void:
	_phase += delta
	_t += delta
	_st += delta
	if _st >= STATE_REFRESH:
		_st = 0.0
		_refresh_crests()
	if _t >= REFRESH:
		_t = 0.0
		queue_redraw()

func _refresh_crests() -> void:
	_crests.clear()
	var t: SceneTree = get_tree()
	if t == null:
		return
	for b in t.get_nodes_in_group("building"):
		if not is_instance_valid(b) or not ("building_name" in b):
			continue
		var node: Node2D = b as Node2D
		if node == null:
			continue
		var bname: String = str(b.building_name)
		if not GameState.is_building_operational(bname):
			continue
		var seated: bool = GameState.seated_leaders(bname) > 0
		var beacon: bool = AURA_TINT.has(bname)
		var home: bool = GameState.in_home_district(bname)
		if not seated and not beacon and not home:
			continue
		var top: float = 220.0
		if b.has_method("eff_h"):
			top = float(b.call("eff_h"))
		_crests.append({
			"x": node.global_position.x,
			# ⚠ ON the roof, not floating over it. eff_h() IS the height the facade
			# stands above the ground line (the art sprite is placed at -eff_h), so
			# a -66 offset hung every standard in mid-air with a gap under it.
			"roof": -top + 8.0,
			"beacon": beacon,
			"tint": AURA_TINT.get(bname, Color(1, 1, 1)),
			"seated": seated,
			"live": GameState.has_building_power(bname),
			"power": GameState.building_power_name(bname),
			"home": home,
			"quarter": QUARTER_COLOR.get(GameState.building_district(bname), Color(0.7, 0.7, 0.7)),
		})

func _view_centre() -> float:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam != null:
		return cam.global_position.x
	var p: Node = get_tree().get_first_node_in_group("player")
	if p != null and p is Node2D:
		return (p as Node2D).global_position.x
	return global_position.x

func _draw() -> void:
	_mod = PLIGHT.canvas(self)
	var centre: float = _view_centre()
	for c in _crests:
		var wx: float = float(c["x"])
		if absf(wx - centre) > VIEW_MARGIN:
			continue
		var x: float = wx - global_position.x
		var roof: float = float(c["roof"])
		if bool(c["home"]):
			var quarter: Color = c["quarter"]
			_draw_quarter_colours(x, roof, quarter)
		if bool(c["beacon"]):
			var tint: Color = c["tint"]
			_draw_beacon(x, roof, tint)
		if bool(c["seated"]):
			_draw_standard(x, roof, bool(c["live"]), str(c["power"]),
				absf(wx - centre) <= NAME_RANGE)

# AT HOME IN ITS QUARTER. The waymarkers on the road name the three quarters, but
# knowing you are standing in the Gatefront does not tell you that the BARRACKS
# belongs there -- and that half of the rule was the half the player could never
# see. A hall standing in its own quarter flies that quarter's colours off the
# ridge: bunting in the same red / gold / green as the boundary boards. Move it
# out and the colours come down. Positive-only, exactly like the bonus itself:
# the wrong quarter shows nothing rather than a mark of shame.
func _draw_quarter_colours(x: float, roof: float, col: Color) -> void:
	var line := Color(0.26, 0.22, 0.18, 0.9)
	var span: float = 96.0
	draw_line(Vector2(x - span, roof + 4.0), Vector2(x + span, roof - 10.0), line, 2.0)
	for i in range(7):
		var t: float = float(i) / 6.0
		var p := Vector2(x - span + span * 2.0 * t, lerpf(roof + 4.0, roof - 10.0, t))
		var sway: float = sin(_phase * 2.4 + float(i) * 0.8) * 3.0
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(-9.0, 0.0), p + Vector2(9.0, 0.0), p + Vector2(sway, 22.0)]),
			_lit(Color(col.r, col.g, col.b, 0.95), 0.35))

# THE BEACON. The aura's own colour, burning on the mast of the hall that casts
# it -- the one thing that ties a pool of green on the road three screens away
# back to the building responsible for it. Same tint as the ward stones on the
# ground; that shared colour IS the explanation.
func _draw_beacon(x: float, roof: float, tint: Color) -> void:
	var beat: float = 0.80 + 0.20 * sin(_phase * 1.6)
	var y: float = roof - 56.0
	draw_rect(Rect2(Vector2(x - 4.0, y), Vector2(8.0, 62.0)), Color(0.24, 0.20, 0.17, 1.0))
	# a soft body of light, built from rings rather than a Light2D
	draw_circle(Vector2(x, y), 62.0 * beat, _lit(Color(tint.r, tint.g, tint.b, 0.07), 0.85))
	draw_circle(Vector2(x, y), 34.0 * beat, _lit(Color(tint.r, tint.g, tint.b, 0.16), 0.85))
	draw_circle(Vector2(x, y), 17.0, _lit(Color(tint.r, tint.g, tint.b, 0.95 * beat), 0.9))
	# and eight short rays, so it reads as broadcasting rather than just glowing
	for i in range(8):
		var a: float = float(i) * PI / 4.0 + _phase * 0.35
		var inner: Vector2 = Vector2(x, y) + Vector2(cos(a), sin(a)) * 23.0
		var outer: Vector2 = Vector2(x, y) + Vector2(cos(a), sin(a)) * (42.0 + 14.0 * beat)
		draw_line(inner, outer, _lit(Color(tint.r, tint.g, tint.b, 0.6 * beat), 0.85), 3.5)

# THE STANDARD. Gold pennant = somebody is in that chair. A burning ring around
# its finial = that person's named power is AWAKE (has_building_power already
# demands both the hall at level 4 and the leader seated, which is the dev's own
# rule: a power without its holder means the holder lost their value).
func _draw_standard(x: float, roof: float, live: bool, power: String, near: bool) -> void:
	# clear of the aura beacon on the same roof -- at +46 the gold pennant sat
	# inside the beacon's glow and the two read as one confused smear (EYES)
	var px: float = x + 82.0
	var pole_h: float = 96.0
	var top: float = roof - pole_h
	draw_rect(Rect2(Vector2(px - 3.0, top), Vector2(6.0, pole_h)), Color(0.30, 0.24, 0.18, 1.0))
	var cloth: Color = _lit(Color(0.92, 0.76, 0.30, 0.96), 0.30)
	var wave: float = sin(_phase * 2.3 + x * 0.004) * 7.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(px + 3.0, top + 4.0),
		Vector2(px + 52.0, top + 14.0 + wave),
		Vector2(px + 38.0, top + 24.0 + wave * 0.5),
		Vector2(px + 52.0, top + 36.0 + wave),
		Vector2(px + 3.0, top + 30.0)]), cloth)
	if not live:
		# the chair is filled but the hall has not grown into its power yet: a
		# plain finial, and nothing burning
		draw_circle(Vector2(px, top), 6.0, Color(0.62, 0.56, 0.42, 1.0))
		return
	var beat: float = 0.72 + 0.28 * sin(_phase * 3.1)
	var fire := Color(1.0, 0.84, 0.38)
	draw_circle(Vector2(px, top), 34.0, _lit(Color(fire.r, fire.g, fire.b, 0.12 * beat), 0.85))
	draw_arc(Vector2(px, top), 19.0, 0.0, TAU, 26, _lit(Color(fire.r, fire.g, fire.b, 0.95), 0.9), 4.0)
	draw_arc(Vector2(px, top), 26.0 + 4.0 * beat, _phase * 1.4, _phase * 1.4 + PI * 1.3, 20,
		_lit(Color(fire.r, fire.g, fire.b, 0.8 * beat), 0.9), 3.0)
	draw_circle(Vector2(px, top), 8.0, _lit(Color(1.0, 0.95, 0.72, beat), 0.9))
	if not near or _font == null or power == "":
		return
	var size: int = 24
	var tw: float = _font.get_string_size(power, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var c := Vector2(x, top - 40.0)
	var r := Rect2(c - Vector2(tw * 0.5 + 15.0, 19.0), Vector2(tw + 30.0, 38.0))
	draw_rect(r, Color(0.12, 0.10, 0.08, 0.92))
	draw_rect(r, _lit(Color(fire.r, fire.g, fire.b, 0.9), 0.75), false, 2.0)
	draw_string(_font, c + Vector2(-tw * 0.5, 8.0), power,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, _lit(Color(1.0, 0.90, 0.60, 1.0), 0.75))
