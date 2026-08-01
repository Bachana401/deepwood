extends Node2D
# ADJACENCY, MADE VISIBLE (dev call 2026-07-30). Of the four placement rules this
# was the most invisible: a plot is painted on the ground and an aura pools light,
# but a working neighbour pair was nothing at all -- a percentage in a panel and a
# toast you saw once when you placed the building.
#
# Now a live pair is STRUNG TOGETHER: a line of lanterns slung between the two
# roofs, sagging in the middle like a real rope, lit warm and breathing slightly.
# You can stand in the road and read your whole town's synergies at a glance, and
# when you move a building and the lanterns go dark, you know exactly what you
# just cost yourself.
#
# Procedural (⛔ gen freeze), additive, and read-only: it draws what
# GameState.adjacency_links already decides and never touches it.

const REFRESH := 1.5
const SAG := 42.0             # how far the rope droops at its middle
const ROOF_Y := -150.0        # roughly roof height on the village strip
const LANTERN_GAP := 90.0     # target spacing between lanterns along the rope

var _t := 0.0
var _phase := 0.0

func _ready() -> void:
	z_index = 3               # overhead: above the buildings they hang between
	add_to_group("synergy_lanterns")

func _process(delta: float) -> void:
	_phase += delta
	_t += delta
	if _t >= REFRESH:
		_t = 0.0
	queue_redraw()            # cheap, and the flames want to breathe

func _draw() -> void:
	var drawn := {}           # a pair is one rope, not two
	for bn in GameState.building_x.keys():
		for link in GameState.adjacency_links(str(bn)):
			var partner := str(link["partner"])
			var key: String = str(bn) + "|" + partner
			var mirror: String = partner + "|" + str(bn)
			if drawn.has(key) or drawn.has(mirror):
				continue
			if not GameState.building_x.has(partner):
				continue
			drawn[key] = true
			_draw_rope(float(GameState.building_x[bn]) - global_position.x,
				float(GameState.building_x[partner]) - global_position.x)

func _draw_rope(ax: float, bx: float) -> void:
	var left := minf(ax, bx)
	var right := maxf(ax, bx)
	var span := right - left
	if span <= 1.0 or span > 3000.0:
		return                # nonsense geometry: draw nothing rather than a mess
	var steps := maxi(6, int(span / 26.0))
	var rope := Color(0.28, 0.22, 0.16, 0.85)
	var pts := PackedVector2Array()
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var x := left + span * t
		# a catenary, near enough: deepest at the middle, flat at the posts
		var y := ROOF_Y + SAG * sin(t * PI)
		pts.append(Vector2(x, y))
	draw_polyline(pts, rope, 2.0)

	# lanterns hung along it, evenly spaced and each breathing on its own beat
	var count := maxi(2, int(span / LANTERN_GAP))
	for i in range(count + 1):
		var t2 := float(i) / float(count)
		var lx := left + span * t2
		var ly := ROOF_Y + SAG * sin(t2 * PI)
		var beat := 0.82 + 0.18 * sin(_phase * 2.1 + float(i) * 1.7)
		_draw_lantern(Vector2(lx, ly + 9.0), beat)

func _draw_lantern(p: Vector2, beat: float) -> void:
	var glow := Color(1.0, 0.72, 0.30, 0.16 * beat)
	draw_circle(p, 15.0, glow)                       # the light it throws
	draw_circle(p, 8.0, Color(1.0, 0.78, 0.36, 0.30 * beat))
	draw_line(p + Vector2(0, -9.0), p + Vector2(0, -4.0), Color(0.28, 0.22, 0.16, 0.9), 1.5)
	draw_circle(p, 3.4, Color(1.0, 0.90, 0.62, beat))  # the flame itself
