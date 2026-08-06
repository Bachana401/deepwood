extends Node2D
# THE VILLAGE MADE VISIBLE (dev call 2026-07-30: "i don't like these" -> the
# systems are real but INVISIBLE; they read as percentages in a panel instead of
# anything happening in the world).
#
# This layer draws what the town already does but never showed:
#   THE STORES    a real woodpile, stone stack and iron heap beside the
#                 Builderhouse that GROWS and SHRINKS with village_stockpile.
#   THE AURAS     the Bar's warmth, the Shrine's pale light and the ward's cool
#                 green -- laid on the ground as a LINE OF WARD STONES running
#                 out from the caster to a marked, named edge.
#   THE QUARTERS  gatefront / heart / outskirts, each with its own ground
#                 character and a waymarker where one ends and the next begins.
#   THE WORK      a yard of crates beside every staffed hall, and the muster
#                 ground where the watch that is down in the deep was set.
#
# All procedural (⛔ art gen freeze until 2026-08-14), no Light2D anywhere (the
# underground pass proved real lights cost more than they are worth here), and
# purely additive: this node draws, it never touches state. Delete the file and
# the game is unchanged.
#
# ⚠ WHY EVERYTHING HERE IS DRAWN SOLID. The first version of the auras was a
# five-band wash at alpha 0.03-0.09. The EYES walker photographed it and there
# was nothing on the frame at all -- because main.tscn's CanvasModulate multiplies
# the whole world by (0.16, 0.18, 0.34) at night, so a 3% wash lands at about
# half a percent of screen contrast. The lantern ropes in the SAME frame read
# fine, and the difference is that they are small SOLID shapes at alpha ~1. So:
# nothing important in this layer is a low-alpha wash. Reach is drawn as objects
# standing on the ground, which survive any hour of the day.

const REFRESH := 0.09         # seconds between redraws; the marks breathe gently
const PILE_FULL := 40.0       # stockpile amount that fills the yard visually
# far enough east to clear the hall itself: a building is ~500px wide, so a
# 250px offset stacked the timber ON the porch (first EYES pass). The yard is a
# yard -- beside the workshop, on open ground.
const YARD_OFFSET := 560.0
# Only draw what the player could plausibly see. The row is ~16,000px long and
# the camera shows ~1,900 of it, so a whole-row draw is ~90% waste every frame.
const VIEW_MARGIN := 2600.0
const CRESTS_SCRIPT := preload("res://village_crests.gd")
const PLIGHT := preload("res://presence_light.gd")

const STATE_REFRESH := 0.3    # how often the SLOW facts are re-read (see below)

var _t: float = 0.0
var _st: float = 99.0
var _phase: float = 0.0
var _font: Font = null
var _mod: Color = Color(1, 1, 1, 1)   # the hour's CanvasModulate, refreshed per draw
# ⚠ THE MARKS BREATHE AT 11Hz; THE FACTS DO NOT CHANGE THAT FAST. count_workers()
# walks the whole villager roster, and once-per-building-per-draw that is ~1,200
# roster steps a frame in a grown town for numbers that only move when the player
# hires somebody. Read them on a slow timer and let _draw be pure drawing.
var _yards: Array = []        # [{x: float, hands: int}, ...]
var _muster_x: float = 0.0
var _muster_posted: int = 0

# Anything that EMITS goes through this, so a ward light is as bright at midnight
# as at noon. Stone, wood and earth do NOT -- see presence_light.gd.
func _lit(c: Color, amount: float = 1.0) -> Color:
	return PLIGHT.lift(c, _mod, amount)

func _ready() -> void:
	# the terrain body is z 0 and its grass cap z 1, so anything lower is drawn
	# BEHIND the ground and may as well not exist (this layer shipped at -3 and was
	# invisible until the EYES walker photographed it). 2 clears the cap and stays
	# under the building bodies (frame z 3, door 4).
	z_index = 2
	add_to_group("village_presence")
	var f: Resource = load("res://art/fonts/PixelifySans.ttf")
	if f is Font:
		_font = f
	# The overhead half of the same job (roof standards, power sigils, aura
	# beacons) has to draw ABOVE the buildings, and a CanvasItem has exactly one
	# z_index -- so it is its own node, parented here so main.gd needs no change.
	var crests: Node2D = CRESTS_SCRIPT.new()
	add_child(crests)
	_refresh_state()          # so the very first frame is not a blank one

func _process(delta: float) -> void:
	_phase += delta
	_t += delta
	_st += delta
	if _st >= STATE_REFRESH:
		_st = 0.0
		_refresh_state()
	if _t >= REFRESH:
		_t = 0.0
		queue_redraw()

# The slow half: who is staffed, and how big the watch is. Everything in here
# walks a roster or the scene tree, so it happens on its own clock.
func _refresh_state() -> void:
	_yards.clear()
	for bn in GameState.building_x.keys():
		var bname: String = str(bn)
		if bname in YARD_SKIP:
			continue
		if not GameState.is_building_operational(bname):
			continue
		var hands: int = GameState.count_workers(bname)
		if hands <= 0:
			continue
		_yards.append({
			"x": float(GameState.building_x[bname]) - _building_half(bname) - 96.0,
			"hands": hands})
	_muster_posted = GameState.posted_warriors()
	_muster_x = GameState.SURFACE_WEST_FALLBACK_X + 300.0
	if GameState.building_x.has("Barracks"):
		_muster_x = float(GameState.building_x["Barracks"]) + _building_half("Barracks") + 190.0

# world x -> this node's local x
func _lx(wx: float) -> float:
	return wx - global_position.x

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
	var lo: float = centre - VIEW_MARGIN
	var hi: float = centre + VIEW_MARGIN
	_draw_quarters(lo, hi)
	_draw_auras(lo, hi)
	_draw_work_yards(lo, hi)
	_draw_muster(lo, hi)
	_draw_stores_yard()

# =========================================================== THE QUARTERS
# A district was pure arithmetic: district_at() bins an x into one of three
# names and building_output_multiplier folds 10% in. Standing in the road there
# was NOTHING -- no edge, no character, no sign you had crossed anything.
#
# Now each quarter has its own ground and its own boundary. The war quarter is
# rutted and studded with old caltrops, the civic heart is cobbled, the working
# land is tufted with grass -- and where one ends a waymarker stands with the
# name of what you are walking into. A district finally reads as a PLACE.
const QUARTER_COLOR := {
	"gatefront": Color(0.78, 0.34, 0.28),    # war
	"heart":     Color(0.92, 0.76, 0.34),    # rule, coin, learning
	"outskirts": Color(0.46, 0.72, 0.38),    # field and water
}
const QUARTER_SHORT := {
	"gatefront": "GATEFRONT",
	"heart": "THE HEART",
	"outskirts": "OUTSKIRTS",
}
const MOTIF_GAP := 230.0

# The gate is the origin every district boundary is measured from -- read the
# same way GameState.district_at reads it, so the drawn line and the scored line
# can never drift apart.
func _gate_x() -> float:
	var t: SceneTree = get_tree()
	if t != null:
		for w in t.get_nodes_in_group("village_wall"):
			if "flank" in w and str(w.flank) == "west":
				return float(w.global_position.x)
	return GameState.SURFACE_WEST_FALLBACK_X

func _draw_quarters(lo: float, hi: float) -> void:
	var gate: float = _gate_x()
	var b1: float = gate + GameState.DISTRICT_GATEFRONT_DEPTH
	var b2: float = gate + GameState.DISTRICT_HEART_DEPTH
	var spans: Array = [
		{"key": "gatefront", "from": gate - 1400.0, "to": b1},
		{"key": "heart", "from": b1, "to": b2},
		{"key": "outskirts", "from": b2, "to": b2 + 16000.0},
	]
	for span in spans:
		var key: String = str(span["key"])
		var from: float = maxf(float(span["from"]), lo)
		var to: float = minf(float(span["to"]), hi)
		if to <= from:
			continue
		var col: Color = QUARTER_COLOR.get(key, Color(0.6, 0.6, 0.6))
		# the quarter's own colour in the dirt: faint on purpose, it is the
		# MOTIFS that have to carry the read after dark
		draw_rect(Rect2(Vector2(_lx(from), -7.0), Vector2(to - from, 7.0)),
			Color(col.r, col.g, col.b, 0.10))
		var first: float = ceil(from / MOTIF_GAP) * MOTIF_GAP
		var x: float = first
		while x <= to:
			_draw_motif(key, _lx(x), col)
			x += MOTIF_GAP
	_draw_waymarker(b1, "gatefront", "heart", lo, hi)
	_draw_waymarker(b2, "heart", "outskirts", lo, hi)

func _draw_motif(key: String, x: float, col: Color) -> void:
	match key:
		"gatefront":                       # a spent caltrop trodden into the rut
			# mostly iron, only a breath of the quarter's red -- a saturated red X
			# on grass read as a UI marker rather than as something lying there
			var iron := Color(0.30 + col.r * 0.16, 0.29 + col.g * 0.12, 0.28 + col.b * 0.12, 0.95)
			draw_rect(Rect2(Vector2(x - 34, -4), Vector2(68, 4)), Color(0.13, 0.10, 0.09, 0.7))
			draw_line(Vector2(x - 14, -2), Vector2(x + 14, -20), iron, 3.4)
			draw_line(Vector2(x - 14, -20), Vector2(x + 14, -2), iron, 3.4)
		"heart":                           # set cobbles
			var stone := Color(col.r * 0.62 + 0.30, col.g * 0.62 + 0.28, col.b * 0.62 + 0.24, 0.95)
			for i in range(3):
				draw_rect(Rect2(Vector2(x - 42 + i * 30, -13), Vector2(26, 12)), stone, false, 2.2)
		"outskirts":                       # tufts of the working land
			var green := Color(col.r * 0.62, col.g * 0.92, col.b * 0.62, 0.95)
			draw_line(Vector2(x, -1), Vector2(x - 11, -22), green, 3.0)
			draw_line(Vector2(x, -1), Vector2(x + 2, -27), green, 3.0)
			draw_line(Vector2(x, -1), Vector2(x + 12, -19), green, 3.0)

# Two posts, a lintel and a board facing each way: the one thing that says out
# loud "this is where the quarter changes", at the exact x the bonus changes.
func _draw_waymarker(wx: float, west_key: String, east_key: String, lo: float, hi: float) -> void:
	if wx < lo - 400.0 or wx > hi + 400.0:
		return
	var x: float = _lx(wx)
	var post := Color(0.30, 0.28, 0.26, 1.0)
	var cap := Color(0.44, 0.42, 0.39, 1.0)
	for s in [-1.0, 1.0]:
		var px: float = x + s * 46.0
		draw_rect(Rect2(Vector2(px - 7.0, -132.0), Vector2(14.0, 132.0)), post)
		draw_rect(Rect2(Vector2(px - 11.0, -138.0), Vector2(22.0, 8.0)), cap)
	draw_rect(Rect2(Vector2(x - 57.0, -150.0), Vector2(114.0, 12.0)), post)
	draw_rect(Rect2(Vector2(x - 57.0, -150.0), Vector2(114.0, 4.0)), cap)
	# the road is scuffed bare where everyone stops to read it
	draw_rect(Rect2(Vector2(x - 90.0, -5.0), Vector2(180.0, 5.0)), Color(0.16, 0.14, 0.12, 0.75))
	_draw_board(Vector2(x - 175.0, -112.0), str(QUARTER_SHORT.get(west_key, "")),
		QUARTER_COLOR.get(west_key, Color(0.7, 0.7, 0.7)))
	_draw_board(Vector2(x + 175.0, -112.0), str(QUARTER_SHORT.get(east_key, "")),
		QUARTER_COLOR.get(east_key, Color(0.7, 0.7, 0.7)))

# A hung wooden board with a word burned into it. Centred on `c`.
func _draw_board(c: Vector2, text: String, edge: Color) -> void:
	if _font == null or text == "":
		return
	var size: int = 26
	var tw: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var w: float = tw + 34.0
	var h: float = 40.0
	var r := Rect2(c - Vector2(w * 0.5, h * 0.5), Vector2(w, h))
	draw_rect(r, Color(0.14, 0.11, 0.09, 0.94))
	# the border and the letters are the LIT part of a sign; the board is not
	draw_rect(r, _lit(Color(edge.r, edge.g, edge.b, 0.95), 0.75), false, 2.5)
	draw_string(_font, c + Vector2(-tw * 0.5, 9.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, _lit(Color(edge.r, edge.g, edge.b, 1.0), 0.75))

# ============================================================== THE AURAS
# An aura is the only rule in the settlement layer that points OUTWARD, and the
# only one the player cannot undo by moving one building -- the Hospital's ward
# is the whole standing defence against an outbreak. It has to be the clearest
# thing on the ground, and until now it was the faintest.
#
# Drawn as a LINE OF WARD STONES walking out from the caster, brightest at the
# source and dimmest at the rim, ending in a marked and NAMED edge. Follow the
# stones toward the bright end and you are looking at the building that casts it;
# stand past the last one and you are out of it. No panel, no number.
const AURA_TINT := {
	"Bar":      Color(1.00, 0.72, 0.26),   # lamplight and music
	"Shrine":   Color(0.74, 0.85, 1.00),   # pale, cold, clean
	"Hospital": Color(0.42, 0.98, 0.62),   # the ward's green
}
const WARD_STONE_GAP := 300.0

func _draw_auras(lo: float, hi: float) -> void:
	var idx: int = 0
	for bn in GameState.AURAS.keys():
		var bname: String = str(bn)
		var slot: int = idx
		idx += 1
		if not GameState.is_building_operational(bname):
			continue
		if not GameState.building_x.has(bname):
			continue
		var wx: float = float(GameState.building_x[bname])
		var r: float = float(GameState.AURAS[bname]["radius"])
		if wx + r < lo or wx - r > hi:
			continue
		var tint: Color = AURA_TINT.get(bname, Color(1, 1, 1))
		var cx: float = _lx(wx)
		# THE PAINTED LINE. One stripe per aura, stacked so three overlapping
		# reaches never hide each other. Solid enough to survive the night.
		var ly: float = -5.0 - float(slot) * 8.0
		draw_rect(Rect2(Vector2(cx - r, ly), Vector2(r * 2.0, 5.0)),
			_lit(Color(tint.r, tint.g, tint.b, 0.45), 0.6))
		# a wash under it -- texture only, it is never asked to carry the read
		for i in range(14):
			var f: float = 1.0 - float(i) / 14.0
			var half: float = r * f
			draw_rect(Rect2(Vector2(cx - half, -6.0 - float(i) * 1.6), Vector2(half * 2.0, 6.0 + float(i) * 1.6)),
				_lit(Color(tint.r, tint.g, tint.b, 0.016), 0.8))
		var title: String = str(GameState.AURAS[bname]["name"])
		_draw_ward_stones(cx, r, tint, wx, lo, hi)
		_draw_rim(cx - r, tint, title, wx - r, lo, hi)
		_draw_rim(cx + r, tint, title, wx + r, lo, hi)
		_draw_blessed_homes(wx, r, tint, slot, lo, hi)

func _draw_ward_stones(cx: float, r: float, tint: Color, wx: float, lo: float, hi: float) -> void:
	var stone := Color(0.24, 0.23, 0.26, 1.0)
	var n: int = int(r / WARD_STONE_GAP)
	for side in [-1.0, 1.0]:
		for k in range(n + 1):
			var off: float = float(k) * WARD_STONE_GAP
			var world: float = wx + side * off
			if world < lo or world > hi:
				continue
			if k == 0 and side < 0.0:
				continue                       # one stone at the source, not two
			var x: float = cx + side * off
			var f: float = clampf(1.0 - off / maxf(r, 1.0), 0.12, 1.0)
			var beat: float = 0.82 + 0.18 * sin(_phase * 1.5 + off * 0.004)
			var hgt: float = 26.0 + 22.0 * f
			draw_rect(Rect2(Vector2(x - 8.0, -hgt), Vector2(16.0, hgt)), stone)
			draw_rect(Rect2(Vector2(x - 8.0, -hgt), Vector2(16.0, 4.0)), stone.lightened(0.25))
			# the light it holds, and the pool it throws on the road
			draw_circle(Vector2(x, -hgt - 8.0), 18.0 + 12.0 * f,
				_lit(Color(tint.r, tint.g, tint.b, 0.10 * f * beat), 0.85))
			draw_circle(Vector2(x, -hgt - 8.0), 7.0 + 6.0 * f,
				_lit(Color(tint.r, tint.g, tint.b, (0.55 + 0.45 * f) * beat), 0.9))
			draw_rect(Rect2(Vector2(x - 26.0 - 20.0 * f, -4.0), Vector2(52.0 + 40.0 * f, 4.0)),
				_lit(Color(tint.r, tint.g, tint.b, (0.24 + 0.40 * f) * beat), 0.85))

# THE EDGE. The single most useful pixel in the whole layer: cross this and the
# ward stops holding you. A post, a pennant, a curtain of light and the aura's
# own name on a board, so the player learns what they just walked out of.
func _draw_rim(x: float, tint: Color, aura_name: String, world_x: float, lo: float, hi: float) -> void:
	if world_x < lo - 300.0 or world_x > hi + 300.0:
		return
	var beat: float = 0.86 + 0.14 * sin(_phase * 1.9)
	# the threshold burnt into the road, so the edge is legible looking straight down
	draw_rect(Rect2(Vector2(x - 7.0, -12.0), Vector2(14.0, 12.0)),
		_lit(Color(tint.r, tint.g, tint.b, 0.75 * beat), 0.9))
	# the curtain: stacked bands climbing off the ground, brightest at the base
	for i in range(11):
		var f: float = 1.0 - float(i) / 11.0
		draw_rect(Rect2(Vector2(x - 5.0 - f * 5.0, -17.0 * float(i + 1)), Vector2(10.0 + f * 10.0, 17.0)),
			_lit(Color(tint.r, tint.g, tint.b, 0.30 * f * beat), 0.85))
	draw_rect(Rect2(Vector2(x - 3.0, -150.0), Vector2(6.0, 150.0)), Color(0.22, 0.19, 0.17, 1.0))
	draw_colored_polygon(PackedVector2Array([
		Vector2(x + 3.0, -148.0), Vector2(x + 52.0, -135.0), Vector2(x + 3.0, -122.0)]),
		_lit(Color(tint.r, tint.g, tint.b, 0.95), 0.7))
	draw_circle(Vector2(x, -154.0), 8.0, _lit(Color(tint.r, tint.g, tint.b, beat), 0.9))
	draw_circle(Vector2(x, -154.0), 20.0, _lit(Color(tint.r, tint.g, tint.b, 0.14 * beat), 0.85))
	# ⚠ THE MIDDLE BAND. This board first sat at -190, twenty pixels from a special
	# plot's signboard, and the two overlapped into mush wherever a rim landed near
	# a plot. Dropping it to -95 fixed that and buried it in the Builderhouse's
	# woodpile instead. The plot signs went UP (special_plot.POST_H) and this sits
	# between them and the ground clutter: plot names high, aura edges at head
	# height, timber and stones below. Both halves were EYES findings.
	_draw_board(Vector2(x, -196.0), aura_name.to_upper(), tint)

# WHOSE LIFE THIS TOUCHES. in_aura() measures homes and workplaces, never
# wandering bodies -- so a cottage inside the reach is the decision the player
# actually made, and it gets a wisp on the roof to prove the choice paid.
func _draw_blessed_homes(wx: float, r: float, tint: Color, slot: int, lo: float, hi: float) -> void:
	for i in range(GameState.extra_cottage_positions.size()):
		var hx: float = float(GameState.extra_cottage_positions[i])
		if hx < lo or hx > hi:
			continue
		if absf(hx - wx) > r:
			continue
		var x: float = _lx(hx) + float(slot) * 15.0 - 15.0
		var bob: float = sin(_phase * 1.7 + float(i) * 0.9) * 6.0
		var y: float = -196.0 + bob
		# a RING, not another blob: the ward stones already fill this town with
		# glowing dots and a filled wisp read as one more of them
		draw_arc(Vector2(x, y), 13.0, 0.0, TAU, 22, _lit(Color(tint.r, tint.g, tint.b, 0.85), 0.85), 3.0)
		draw_circle(Vector2(x, y), 4.0, _lit(Color(tint.r, tint.g, tint.b, 0.95), 0.9))

# ========================================================== THE WORK YARDS
# A hall with people in it should not look like a hall with nobody in it. Crates
# and a lit hand-lantern pile up on the west flank of every staffed building,
# one crate a worker -- so an idle town is bare ground and a working one is
# cluttered with the evidence.
const YARD_SKIP := ["Builderhouse", "Fishing Dock"]   # both already own that ground

func _building_half(bname: String) -> float:
	var t: SceneTree = get_tree()
	if t == null:
		return 260.0
	for b in t.get_nodes_in_group("building"):
		if not is_instance_valid(b) or not ("building_name" in b):
			continue
		if str(b.building_name) != bname:
			continue
		if b.has_method("eff_w"):
			return float(b.call("eff_w")) * 0.5
		if "width" in b:
			return float(b.width) * 0.5
	return 260.0

func _draw_work_yards(lo: float, hi: float) -> void:
	for yard in _yards:
		var hands: int = int(yard["hands"])
		var wx: float = float(yard["x"])
		if wx < lo or wx > hi:
			continue
		var x: float = _lx(wx)
		draw_rect(Rect2(Vector2(x - 74.0, -6.0), Vector2(148.0, 6.0)), Color(0.19, 0.16, 0.12, 0.7))
		var crates: int = clampi(hands, 1, 6)
		for i in range(crates):
			var row: int = i / 3
			var col: int = i % 3
			var bx: float = x - 52.0 + float(col) * 44.0
			var by: float = -6.0 - float(row) * 34.0
			draw_rect(Rect2(Vector2(bx, by - 34.0), Vector2(38.0, 34.0)), Color(0.42, 0.30, 0.18))
			draw_rect(Rect2(Vector2(bx, by - 34.0), Vector2(38.0, 5.0)), Color(0.56, 0.41, 0.25))
			draw_line(Vector2(bx, by - 19.0), Vector2(bx + 38.0, by - 19.0), Color(0.28, 0.20, 0.12), 2.0)
		# a lantern set down on the job, so the yard reads after dark too
		var flicker: float = 0.78 + 0.22 * sin(_phase * 3.3 + x * 0.01)
		draw_circle(Vector2(x + 66.0, -18.0), 24.0, _lit(Color(1.0, 0.76, 0.36, 0.14 * flicker), 0.85))
		draw_circle(Vector2(x + 66.0, -18.0), 7.0, _lit(Color(1.0, 0.88, 0.55, flicker), 0.9))

# ========================================================== THE MUSTER GROUND
# Warriors posted into the deep are the town's single most abstract investment:
# they leave, a number changes, gold arrives. The yard they mustered in is the
# proof they went -- a watch-fire that climbs with the size of the watch, and
# one pennant per block being held, its pole taller the deeper that block is.
func _draw_muster(lo: float, hi: float) -> void:
	var posted: int = _muster_posted
	if posted <= 0:
		return
	if _muster_x < lo or _muster_x > hi:
		return
	var x: float = _lx(_muster_x)
	draw_rect(Rect2(Vector2(x - 260.0, -9.0), Vector2(520.0, 9.0)), Color(0.24, 0.19, 0.13, 0.9))
	# the watch-fire: a real bonfire, higher the more of the watch is out
	var big: float = clampf(float(posted) / 6.0, 0.5, 2.0)
	var flick: float = 0.85 + 0.15 * sin(_phase * 6.1)
	var fx0: float = x - 176.0
	for i in range(4):
		draw_rect(Rect2(Vector2(fx0 - 44.0 + float(i) * 22.0, -16.0), Vector2(34.0, 13.0)), Color(0.26, 0.17, 0.10))
	for i in range(6):
		var fx: float = fx0 - 32.0 + float(i) * 13.0
		var fh: float = (54.0 + 52.0 * big) * (0.60 + 0.40 * sin(_phase * 5.0 + float(i) * 2.1))
		draw_colored_polygon(PackedVector2Array([
			Vector2(fx - 12.0, -10.0), Vector2(fx + 12.0, -10.0), Vector2(fx, -fh)]),
			_lit(Color(0.98, 0.30 + 0.09 * float(i), 0.10, 0.9), 0.55))
	draw_circle(Vector2(fx0, -46.0), 48.0 + 34.0 * big, _lit(Color(1.0, 0.58, 0.22, 0.11 * flick), 0.8))
	# one pennant per block held; the deeper the block, the taller the pole
	var shown: int = 0
	for b in range(1, GameState.PATROL_BLOCKS + 1):
		if GameState.patrol_at(b) <= 0:
			continue
		var px: float = x - 60.0 + float(shown) * 74.0
		shown += 1
		var pole: float = 128.0 + float(b) * 17.0
		var sway: float = sin(_phase * 1.8 + float(b)) * 6.0
		draw_rect(Rect2(Vector2(px - 4.0, -pole), Vector2(8.0, pole)), Color(0.28, 0.23, 0.18))
		draw_colored_polygon(PackedVector2Array([
			Vector2(px + 3.0, -pole + 2.0),
			Vector2(px + 58.0 + sway, -pole + 20.0),
			Vector2(px + 3.0, -pole + 40.0)]),
			_lit(Color(0.80, 0.22, 0.20, 0.95), 0.55))
		draw_rect(Rect2(Vector2(px - 13.0, -9.0), Vector2(26.0, 9.0)), Color(0.32, 0.30, 0.28))
		# a spear stood beside it for each warrior holding that stretch
		var spears: int = clampi(GameState.patrol_at(b), 1, 4)
		for s in range(spears):
			var sx: float = px + 22.0 + float(s) * 11.0
			draw_line(Vector2(sx, -6.0), Vector2(sx + 5.0, -92.0), Color(0.34, 0.27, 0.19), 3.0)
			draw_colored_polygon(PackedVector2Array([
				Vector2(sx + 5.0, -108.0), Vector2(sx + 1.0, -92.0), Vector2(sx + 10.0, -92.0)]),
				Color(0.66, 0.68, 0.72, 1.0))

# ------------------------------------------------------------ the stores yard
# Timber, stone and iron in a working yard. The whole point of the supply chain
# made physical: full stacks mean the crew can build, bare ground means they
# cannot, and you can tell which from across the road without opening a panel.
func _draw_stores_yard() -> void:
	if not GameState.building_x.has("Builderhouse"):
		return
	if not GameState.is_building_operational("Builderhouse"):
		return
	var ox: float = _lx(float(GameState.building_x["Builderhouse"]) + YARD_OFFSET)
	var wood: int = int(GameState.village_stockpile.get("wood", 0))
	var stone: int = int(GameState.village_stockpile.get("stone", 0))
	var iron: int = int(GameState.village_stockpile.get("iron_shard", 0))
	# the beaten ground of a working yard, always there once the crew is
	draw_rect(Rect2(Vector2(ox - 330.0, -10.0), Vector2(660.0, 10.0)), Color(0.20, 0.17, 0.13, 0.6))
	_draw_logs(ox - 210.0, wood)
	_draw_blocks(ox + 30.0, stone)
	_draw_ingots(ox + 235.0, iron)

# ⚠ VILLAGE SCALE, not icon scale. These first drew at ~20px a log, which beside a
# 500px-wide hall is a matchstick nobody would ever notice -- the EYES walker's
# first frame showed a yard technically present and practically invisible. A log
# is now knee-high on a villager and the full pile reads from across the road.
const LOG_W := 46.0
const LOG_H := 30.0
const BLOCK_W := 54.0
const BLOCK_H := 32.0

func _draw_logs(x: float, amount: int) -> void:
	var rows := clampi(int(ceil(float(amount) / PILE_FULL * 4.0)), 0, 4)
	if rows == 0:
		return
	var bark := Color(0.34, 0.23, 0.14)
	var face := Color(0.68, 0.52, 0.33)
	var rim := Color(0.46, 0.34, 0.20)
	for r in range(rows):
		var n := 4 - r                       # a pile narrows as it rises
		for i in range(n):
			var lx := x - float(n - 1) * (LOG_W * 0.5) + float(i) * LOG_W
			var ly := -6.0 - float(r) * (LOG_H - 3.0)
			draw_rect(Rect2(Vector2(lx - LOG_W * 0.5, ly - LOG_H), Vector2(LOG_W, LOG_H)), bark)
			draw_rect(Rect2(Vector2(lx - LOG_W * 0.5, ly - LOG_H), Vector2(LOG_W, 4.0)), rim)
			draw_circle(Vector2(lx, ly - LOG_H * 0.5), LOG_H * 0.34, face)   # the cut end

func _draw_blocks(x: float, amount: int) -> void:
	var rows := clampi(int(ceil(float(amount) / PILE_FULL * 3.0)), 0, 3)
	if rows == 0:
		return
	var stone := Color(0.44, 0.44, 0.42)
	var lit := Color(0.62, 0.62, 0.58)
	for r in range(rows):
		var n := 3 - r
		for i in range(n):
			var bx := x - float(n - 1) * (BLOCK_W * 0.5) + float(i) * BLOCK_W
			var by := -6.0 - float(r) * (BLOCK_H - 2.0)
			draw_rect(Rect2(Vector2(bx - BLOCK_W * 0.5, by - BLOCK_H), Vector2(BLOCK_W, BLOCK_H)), stone)
			draw_rect(Rect2(Vector2(bx - BLOCK_W * 0.5, by - BLOCK_H), Vector2(BLOCK_W, 6.0)), lit)

func _draw_ingots(x: float, amount: int) -> void:
	var n := clampi(int(ceil(float(amount) / PILE_FULL * 5.0)), 0, 5)
	if n == 0:
		return
	var iron := Color(0.30, 0.32, 0.38)
	var sheen := Color(0.62, 0.66, 0.74)
	for i in range(n):
		var ix := x - float(n - 1) * 16.0 + float(i) * 32.0
		draw_rect(Rect2(Vector2(ix - 14.0, -30.0), Vector2(28.0, 20.0)), iron)
		draw_rect(Rect2(Vector2(ix - 14.0, -30.0), Vector2(28.0, 5.0)), sheen)
