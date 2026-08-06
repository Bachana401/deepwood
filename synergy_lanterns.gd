extends Node2D
# ADJACENCY, MADE VISIBLE (dev call 2026-07-30). Of the four placement rules this
# was the most invisible: a plot is painted on the ground and an aura pools light,
# but a working neighbour pair was nothing at all -- a percentage in a panel and a
# toast you saw once when you placed the building.
#
# A live pair is STRUNG TOGETHER: a line slung between the two roofs, sagging in
# the middle like real rope, hung with lanterns -- and, the part that actually
# says WHY the pair exists, GOODS RUNNING ALONG IT. Ore crawls from the seam to
# the forge, coin from the counting house to the carts, casks from the bar to the
# beds above it. The richer the pairing, the more of it moves. You can stand in
# the road and read your whole town's supply chain without opening anything.
#
# ⚠ AND A DEAD PAIR IS DRAWN TOO. Two buildings that stand next to each other but
# are not BOTH working (a rubble forge beside the Mine) used to show nothing at
# all -- identical, on screen, to two buildings with no synergy between them.
# That is the exact information the player needs to act on, so a broken link now
# hangs there slack and unlit with its lanterns out. Repair the forge and the
# line lights while you watch.
#
# Procedural (⛔ gen freeze), no Light2D, additive, and read-only: it draws what
# GameState.ADJACENCY_PAIRS and building_neighbors already decide, and never
# touches them.

const SAG := 62.0             # how far the rope droops at its middle
const LANTERN_GAP := 105.0    # target spacing between lanterns along the rope
const VIEW_MARGIN := 2600.0
# ⚠ ROOFLINE, NOT MID-FACADE. This shipped with a flat ROOF_Y of -150 while a
# village hall stands ~230-300px tall, so every rope was strung ACROSS the front
# of the buildings it joined -- it read as a wire nailed to a wall, not as
# something spanning the gap. The height is read per building from its own
# eff_h() now, and the rope clears both roofs.
const ROOF_CLEAR := 54.0
const ROOF_FALLBACK := 250.0

# What actually travels each link. Keyed by the two names sorted, so it does not
# matter which side the player built first.
const CARGO := {
	"Blacksmith|Mine":        {"body": Color(0.46, 0.42, 0.40), "fleck": Color(1.00, 0.72, 0.32)},
	"Builderhouse|Mine":      {"body": Color(0.55, 0.55, 0.52), "fleck": Color(0.78, 0.78, 0.74)},
	"Barracks|Blacksmith":    {"body": Color(0.40, 0.44, 0.50), "fleck": Color(0.86, 0.90, 0.96)},
	"Farm|Fishing Dock":      {"body": Color(0.62, 0.50, 0.24), "fleck": Color(0.92, 0.84, 0.42)},
	"Bank|Marketplace":       {"body": Color(0.72, 0.56, 0.16), "fleck": Color(1.00, 0.90, 0.42)},
	"School|Science Lab":     {"body": Color(0.74, 0.70, 0.58), "fleck": Color(0.60, 0.80, 0.95)},
	"Bar|Tavern":             {"body": Color(0.44, 0.28, 0.14), "fleck": Color(0.95, 0.70, 0.30)},
	"Hospital|Shrine":        {"body": Color(0.82, 0.84, 0.82), "fleck": Color(0.55, 0.95, 0.70)},
}

const PLIGHT := preload("res://presence_light.gd")

const STATE_REFRESH := 0.3

var _phase: float = 0.0
var _st: float = 99.0
var _tops: Dictionary = {}
var _ropes: Array = []        # [{a, b, ax, bx, ay, by, bonus, live}, ...]
var _mod: Color = Color(1, 1, 1, 1)

# The flames are light and must survive the night CanvasModulate; the rope, the
# crates and the posts are objects and go dark with the rest of the town.
func _lit(c: Color, amount: float = 1.0) -> Color:
	return PLIGHT.lift(c, _mod, amount)

func _ready() -> void:
	z_index = 3               # overhead: above the buildings they hang between
	add_to_group("synergy_lanterns")
	_refresh_ropes()

func _process(delta: float) -> void:
	_phase += delta
	_st += delta
	if _st >= STATE_REFRESH:
		# WHICH ropes exist is a slow fact (it changes when a building is raised,
		# razed or moved); WHERE the goods are on them is a per-frame one. Walking
		# the building group and the pair table every single frame to re-derive an
		# unchanged answer was pure waste.
		_st = 0.0
		_refresh_ropes()
	queue_redraw()            # cheap, and the flames want to breathe

func _view_centre() -> float:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam != null:
		return cam.global_position.x
	var p: Node = get_tree().get_first_node_in_group("player")
	if p != null and p is Node2D:
		return (p as Node2D).global_position.x
	return global_position.x

# name -> the y its rope should hang at, read off the standing body so a hall
# that has been upgraded taller carries its line higher.
func _refresh_tops() -> void:
	_tops.clear()
	var t: SceneTree = get_tree()
	if t == null:
		return
	for b in t.get_nodes_in_group("building"):
		if not is_instance_valid(b) or not ("building_name" in b):
			continue
		var h: float = ROOF_FALLBACK
		if b.has_method("eff_h"):
			h = float(b.call("eff_h"))
		_tops[str(b.building_name)] = -h - ROOF_CLEAR

func _top_of(bname: String) -> float:
	return float(_tops.get(bname, -ROOF_FALLBACK - ROOF_CLEAR))

func _refresh_ropes() -> void:
	_refresh_tops()
	_ropes.clear()
	var drawn: Dictionary = {}
	for bn in GameState.building_neighbors.keys():
		var bname: String = str(bn)
		if not GameState.building_x.has(bname):
			continue
		var sides: Array = GameState.building_neighbors.get(bname, [])
		for side in sides:
			var partner: String = str(side)
			if partner == "" or not GameState.building_x.has(partner):
				continue
			var pair: Dictionary = _pair_for(bname, partner)
			if pair.is_empty():
				continue
			var key: String = _key(bname, partner)
			if drawn.has(key):
				continue
			drawn[key] = true
			_ropes.append({
				"a": bname, "b": partner,
				"ax": float(GameState.building_x[bname]),
				"bx": float(GameState.building_x[partner]),
				"bonus": float(pair["bonus"]),
				"live": GameState.is_building_operational(bname) \
					and GameState.is_building_operational(partner)})

func _draw() -> void:
	_mod = PLIGHT.canvas(self)
	var centre: float = _view_centre()
	for rope in _ropes:
		var ax: float = float(rope["ax"])
		var bx: float = float(rope["bx"])
		if maxf(ax, bx) < centre - VIEW_MARGIN or minf(ax, bx) > centre + VIEW_MARGIN:
			continue
		_draw_rope(str(rope["a"]), str(rope["b"]), ax, bx, float(rope["bonus"]), bool(rope["live"]))

func _key(a: String, b: String) -> String:
	return (a + "|" + b) if a < b else (b + "|" + a)

# The ADJACENCY_PAIRS entry these two would make, standing side by side --
# regardless of whether either of them is currently working.
func _pair_for(a: String, b: String) -> Dictionary:
	for pair in GameState.ADJACENCY_PAIRS:
		var pa: String = str(pair["a"])
		var pb: String = str(pair["b"])
		if (pa == a and pb == b) or (pb == a and pa == b):
			return pair
	return {}

func _draw_rope(a: String, b: String, awx: float, bwx: float, bonus: float, live: bool) -> void:
	var lx: float = minf(awx, bwx) - global_position.x
	var rx: float = maxf(awx, bwx) - global_position.x
	var span: float = rx - lx
	if span <= 1.0 or span > 3000.0:
		return                # nonsense geometry: draw nothing rather than a mess
	var ly: float = _top_of(a if awx <= bwx else b)
	var ry: float = _top_of(b if awx <= bwx else a)
	# a dead line has nobody keeping it taut
	var sag: float = SAG if live else SAG * 2.1
	var rope: Color = Color(0.30, 0.24, 0.17, 0.9) if live else Color(0.20, 0.19, 0.18, 0.75)
	var steps: int = maxi(8, int(span / 26.0))
	var pts := PackedVector2Array()
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		pts.append(Vector2(lx + span * t, _rope_y(ly, ry, sag, t)))
	draw_polyline(pts, rope, 3.0 if live else 2.0)
	# the posts it is tied off to
	for e in [Vector2(lx, ly), Vector2(rx, ry)]:
		draw_rect(Rect2(e + Vector2(-3.0, 0.0), Vector2(6.0, 34.0)), rope)

	var count: int = maxi(2, int(span / LANTERN_GAP))
	for i in range(count + 1):
		var t2: float = float(i) / float(count)
		var p := Vector2(lx + span * t2, _rope_y(ly, ry, sag, t2) + 11.0)
		if live:
			_draw_lantern(p, 0.80 + 0.20 * sin(_phase * 2.1 + float(i) * 1.7))
		else:
			_draw_dead_lantern(p)
	if live:
		_draw_cargo(a, b, lx, rx, ly, ry, sag, bonus)

# The rope's height at t: the two ends interpolated, pulled down by its own
# weight in the middle.
func _rope_y(ly: float, ry: float, sag: float, t: float) -> float:
	return lerpf(ly, ry, t) + sag * sin(t * PI)

func _draw_lantern(p: Vector2, beat: float) -> void:
	draw_circle(p, 30.0, _lit(Color(1.0, 0.72, 0.30, 0.11 * beat), 0.85))   # the light it throws
	draw_circle(p, 15.0, _lit(Color(1.0, 0.78, 0.36, 0.34 * beat), 0.85))
	draw_line(p + Vector2(0, -13.0), p + Vector2(0, -6.0), Color(0.28, 0.22, 0.16, 0.9), 2.0)
	draw_rect(Rect2(p + Vector2(-5.0, -6.0), Vector2(10.0, 12.0)), Color(0.30, 0.23, 0.15, 0.95))
	draw_circle(p, 5.2, _lit(Color(1.0, 0.90, 0.62, beat), 0.9))            # the flame itself

func _draw_dead_lantern(p: Vector2) -> void:
	draw_line(p + Vector2(0, -12.0), p + Vector2(0, -6.0), Color(0.22, 0.20, 0.18, 0.8), 1.5)
	draw_rect(Rect2(p + Vector2(-4.0, -6.0), Vector2(8.0, 10.0)), Color(0.17, 0.16, 0.15, 0.9))

# WHAT THE LINK IS FOR. Crates run the rope, one way and back, and a richer
# pairing runs more of them -- so the 0.20 bond between the counting house and
# the carts is visibly busier than a 0.15 one without ever printing a number.
func _draw_cargo(a: String, b: String, lx: float, rx: float, ly: float, ry: float,
		sag: float, bonus: float) -> void:
	var spec: Dictionary = CARGO.get(_key(a, b), {"body": Color(0.5, 0.42, 0.3), "fleck": Color(0.9, 0.8, 0.5)})
	var body: Color = spec["body"]
	var fleck: Color = spec["fleck"]
	var n: int = clampi(1 + int(round(bonus / 0.07)), 2, 4)
	var span: float = rx - lx
	var speed: float = 0.16 + bonus * 0.5
	for i in range(n):
		var raw: float = fposmod(_phase * speed + float(i) / float(n), 1.0)
		# ping-pong, so the line runs both ways like a real hand-over-hand haul
		var t: float = raw * 2.0 if raw < 0.5 else (1.0 - raw) * 2.0
		var p := Vector2(lx + span * t, _rope_y(ly, ry, sag, t))
		# the runner that rides the rope, and the crate swinging under it
		draw_circle(p, 4.0, Color(0.34, 0.30, 0.26, 1.0))
		var c := p + Vector2(0.0, 20.0)
		draw_line(p, c + Vector2(0.0, -9.0), Color(0.30, 0.26, 0.22, 0.95), 1.6)
		draw_rect(Rect2(c + Vector2(-11.0, -9.0), Vector2(22.0, 18.0)), body)
		draw_rect(Rect2(c + Vector2(-11.0, -9.0), Vector2(22.0, 4.0)), body.lightened(0.25))
		draw_circle(c + Vector2(0.0, -1.0), 3.4, fleck)
