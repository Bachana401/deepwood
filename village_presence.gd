extends Node2D
# THE VILLAGE MADE VISIBLE (dev call 2026-07-30: "i don't like these" -> the
# systems are real but INVISIBLE; they read as percentages in a panel instead of
# anything happening in the world).
#
# This layer draws three things the town already does but never showed:
#   THE STORES   a real woodpile, stone stack and iron heap beside the
#                Builderhouse that GROWS and SHRINKS with village_stockpile. The
#                supply chain stops being a number and becomes a yard you can
#                look at -- and an empty yard is why the crew is idle.
#   THE AURAS    the Bar's warmth, the Shrine's pale light and the ward's cool
#                green, pooled on the ground where they actually reach, so a
#                radius is something you SEE rather than read.
#
# All procedural (⛔ art gen freeze until 2026-08-14) and purely additive: this
# node draws, it never touches state. Delete the file and the game is unchanged.

const REFRESH := 1.5          # seconds between redraws; nothing here is urgent
const PILE_FULL := 40.0       # stockpile amount that fills the yard visually
# far enough east to clear the hall itself: a building is ~500px wide, so a
# 250px offset stacked the timber ON the porch (first EYES pass). The yard is a
# yard -- beside the workshop, on open ground.
const YARD_OFFSET := 560.0

var _t := 0.0

func _ready() -> void:
	# the terrain body is z 0 and its grass cap z 1, so anything lower is drawn
	# BEHIND the ground and may as well not exist (this layer shipped at -3 and was
	# invisible until the EYES walker photographed it). 2 clears the cap and stays
	# under the building bodies (frame z 3, door 4).
	z_index = 2
	add_to_group("village_presence")

func _process(delta: float) -> void:
	_t += delta
	if _t >= REFRESH:
		_t = 0.0
		queue_redraw()

func _draw() -> void:
	_draw_auras()
	_draw_stores_yard()

# ---------------------------------------------------------------- the auras
# A pool of light along the road, fading out at the edge of its true radius.
# Drawn as stacked bands rather than a circle: the village is a strip, and a
# soft horizontal wash reads as light on a street where a big disc reads as a
# coloured rectangle.
const AURA_TINT := {
	"Bar":      Color(1.00, 0.78, 0.36),   # lamplight and music
	"Shrine":   Color(0.82, 0.86, 1.00),   # pale, cold, clean
	"Hospital": Color(0.60, 0.92, 0.72),   # the ward's green
}

func _draw_auras() -> void:
	for bn in GameState.AURAS.keys():
		if not GameState.is_building_operational(bn):
			continue
		if not GameState.building_x.has(bn):
			continue
		var cx: float = float(GameState.building_x[bn]) - global_position.x
		var r: float = float(GameState.AURAS[bn]["radius"])
		var tint: Color = AURA_TINT.get(bn, Color(1, 1, 1))
		# five nested bands, each shorter and slightly stronger toward the middle
		for i in range(5):
			var f := 1.0 - float(i) / 5.0          # 1.0 at the rim, 0.2 at the core
			var half := r * f
			var h := 5.0 + float(i) * 3.0
			var a := 0.030 + 0.016 * float(i)
			draw_rect(Rect2(Vector2(cx - half, -h), Vector2(half * 2.0, h)),
				Color(tint.r, tint.g, tint.b, a))
		# a brighter seam right at the doorway, so the source is obvious
		draw_rect(Rect2(Vector2(cx - 70.0, -3.0), Vector2(140.0, 3.0)),
			Color(tint.r, tint.g, tint.b, 0.16))

# ------------------------------------------------------------ the stores yard
# Timber, stone and iron in a working yard. The whole point of the supply chain
# made physical: full stacks mean the crew can build, bare ground means they
# cannot, and you can tell which from across the road without opening a panel.
func _draw_stores_yard() -> void:
	if not GameState.building_x.has("Builderhouse"):
		return
	if not GameState.is_building_operational("Builderhouse"):
		return
	var ox: float = float(GameState.building_x["Builderhouse"]) - global_position.x + YARD_OFFSET
	var wood := int(GameState.village_stockpile.get("wood", 0))
	var stone := int(GameState.village_stockpile.get("stone", 0))
	var iron := int(GameState.village_stockpile.get("iron_shard", 0))
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
